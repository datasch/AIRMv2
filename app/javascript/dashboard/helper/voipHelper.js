import JsSIP from 'jssip';
import { reactive } from 'vue';
import VoipAPI from '../api/voip';

// Turn off noisy debug logs in production
JsSIP.debug.disable();

export const voipState = reactive({
  isConfigured: false,
  isEnabled: false,
  isRegistered: false,
  registrationError: null,
  activeCalls: [],
  currentSession: null,
  callState: 'idle', // 'idle' | 'calling' | 'ringing' | 'connected' | 'ended'
  remoteNumber: '',
  remoteDisplayName: '',
  callDuration: 0,
  isMuted: false,
  isOnHold: false,
  isDialerOpen: false,
  conversationId: null,
});

let ua = null;
let durationTimer = null;
let remoteAudioElement = null;

const ensureAudioElement = () => {
  if (!remoteAudioElement) {
    remoteAudioElement = document.createElement('audio');
    remoteAudioElement.id = 'voip-remote-audio';
    remoteAudioElement.autoplay = true;
    document.body.appendChild(remoteAudioElement);
  }
  return remoteAudioElement;
};

const startDurationTimer = () => {
  clearInterval(durationTimer);
  voipState.callDuration = 0;
  durationTimer = setInterval(() => {
    voipState.callDuration += 1;
  }, 1000);
};

const stopDurationTimer = () => {
  clearInterval(durationTimer);
};

const handleCallTermination = status => {
  const finalDuration = voipState.callDuration;
  const phoneNumber = voipState.remoteNumber;
  const convId = voipState.conversationId;

  stopDurationTimer();
  voipState.callState = 'ended';
  voipState.currentSession = null;
  voipState.isMuted = false;
  voipState.isOnHold = false;

  VoipAPI.updateCallStatus({ event: 'ended', phoneNumber });

  if (convId && phoneNumber) {
    VoipAPI.logCall({
      conversationId: convId,
      phoneNumber,
      durationSeconds: finalDuration,
      status,
    });
  }

  setTimeout(() => {
    if (voipState.callState === 'ended') {
      voipState.callState = 'idle';
      voipState.remoteNumber = '';
      voipState.conversationId = null;
    }
  }, 2500);
};

const bindSessionEvents = session => {
  const audio = ensureAudioElement();

  const attachMedia = eventOrStream => {
    if (!eventOrStream) return;
    if (eventOrStream.streams && eventOrStream.streams[0]) {
      audio.srcObject = eventOrStream.streams[0];
    } else if (eventOrStream.track) {
      audio.srcObject = new MediaStream([eventOrStream.track]);
    } else if (eventOrStream instanceof MediaStream) {
      audio.srcObject = eventOrStream;
    }
    audio.play().catch(() => {});
  };

  session.on('progress', () => {
    voipState.callState = 'calling';
    VoipAPI.updateCallStatus({
      event: 'ringing',
      phoneNumber: voipState.remoteNumber,
    });
  });

  session.on('accepted', () => {
    voipState.callState = 'connected';
    startDurationTimer();
    VoipAPI.updateCallStatus({
      event: 'connected',
      phoneNumber: voipState.remoteNumber,
    });
    if (session.connection) {
      const streams = session.connection.getRemoteStreams ? session.connection.getRemoteStreams() : [];
      if (streams.length > 0) attachMedia(streams[0]);
    }
  });

  session.on('confirmed', () => {
    voipState.callState = 'connected';
    if (session.connection) {
      const streams = session.connection.getRemoteStreams ? session.connection.getRemoteStreams() : [];
      if (streams.length > 0) attachMedia(streams[0]);
    }
  });

  session.on('peerconnection', e => {
    const pc = e.peerconnection;
    pc.ontrack = attachMedia;
    pc.addEventListener('track', attachMedia);
  });

  session.on('ended', () => {
    handleCallTermination('completed');
  });

  session.on('failed', e => {
    handleCallTermination(e.cause === 'Busy' ? 'busy' : 'failed');
  });
};

const handleIncomingSession = session => {
  voipState.currentSession = session;
  voipState.remoteNumber = session.remote_identity.uri.user;
  voipState.remoteDisplayName =
    session.remote_identity.display_name || voipState.remoteNumber;
  voipState.callState = 'ringing';
  voipState.isDialerOpen = true;

  bindSessionEvents(session);
};

export const initVoIP = async () => {
  try {
    const response = await VoipAPI.getConfig();
    const { enabled, ws_url, sip_domain, caller_id, agent, active_calls } =
      response.data || {};

    voipState.isEnabled = !!enabled;
    voipState.activeCalls = active_calls || [];

    if (
      !enabled ||
      !ws_url ||
      !sip_domain ||
      !agent?.extension ||
      !agent?.password
    ) {
      voipState.isConfigured = false;
      return;
    }

    voipState.isConfigured = true;
    voipState.caller_id = caller_id || '';
    voipState.sip_domain = sip_domain || '';

    if (ua && ua.isRegistered()) {
      ua.stop();
    }

    const socket = new JsSIP.WebSocketInterface(ws_url);
    const configuration = {
      sockets: [socket],
      uri: `sip:${agent.extension}@${sip_domain}`,
      password: agent.password,
      display_name: agent.display_name || agent.extension,
      session_timers: false,
      register: true,
    };

    ua = new JsSIP.UA(configuration);

    ua.on('registered', () => {
      voipState.isRegistered = true;
      voipState.registrationError = null;
    });

    ua.on('unregistered', () => {
      voipState.isRegistered = false;
    });

    ua.on('registrationFailed', e => {
      voipState.isRegistered = false;
      voipState.registrationError = e.cause || 'Registration Failed';
    });

    ua.on('newRTCSession', data => {
      const session = data.session;
      if (session.direction === 'incoming') {
        handleIncomingSession(session);
      }
    });

    ua.start();
  } catch (error) {
    voipState.isRegistered = false;
    voipState.registrationError = error.message;
  }
};

export const makeCall = async (
  targetNumber,
  conversationId = null,
  customCallerId = null
) => {
  if (!ua || !voipState.isRegistered) {
    initVoIP();
  }

  if (!targetNumber) return;

  if (navigator?.mediaDevices?.getUserMedia) {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach(track => track.stop());
    } catch (micErr) {
      console.warn('[VoIP] Microphone access error:', micErr);
    }
  }

  const cleanNumber = targetNumber.toString().replace(/[^0-9+]/g, '');
  const callerId = customCallerId || voipState.caller_id;

  voipState.remoteNumber = cleanNumber;
  voipState.conversationId = conversationId;
  voipState.callState = 'calling';
  voipState.isDialerOpen = true;

  const extraHeaders = [];
  if (callerId) {
    extraHeaders.push(`X-Caller-ID: ${callerId}`);
    extraHeaders.push(
      `P-Asserted-Identity: <sip:${callerId}@${voipState.sip_domain || 'pbx'}>`
    );
  }

  const eventOptions = {
    mediaConstraints: { audio: true, video: false },
    rtcOfferConstraints: { offerToReceiveAudio: 1, offerToReceiveVideo: 0 },
    extraHeaders,
  };

  VoipAPI.updateCallStatus({ event: 'started', phoneNumber: cleanNumber });

  const session = ua.call(
    `sip:${cleanNumber}@${voipState.sip_domain || 'pbx'}`,
    eventOptions
  );
  voipState.currentSession = session;
  bindSessionEvents(session);
};

export const answerCall = () => {
  if (voipState.currentSession && voipState.callState === 'ringing') {
    voipState.currentSession.answer({
      mediaConstraints: { audio: true, video: false },
    });
  }
};

export const hangupCall = () => {
  if (voipState.currentSession) {
    voipState.currentSession.terminate();
  } else {
    handleCallTermination('ended');
  }
};

export const toggleMute = () => {
  if (!voipState.currentSession) return;
  if (voipState.isMuted) {
    voipState.currentSession.unmute({ audio: true });
    voipState.isMuted = false;
  } else {
    voipState.currentSession.mute({ audio: true });
    voipState.isMuted = true;
  }
};

export const sendDTMF = tone => {
  if (voipState.currentSession && voipState.callState === 'connected') {
    voipState.currentSession.sendDTMF(tone);
  }
};

export const openDialer = (initialNumber = '', conversationId = null) => {
  if (initialNumber) {
    voipState.remoteNumber = initialNumber;
  }
  if (conversationId) {
    voipState.conversationId = conversationId;
  }
  voipState.isDialerOpen = true;
};

export const closeDialer = () => {
  if (voipState.callState === 'idle') {
    voipState.isDialerOpen = false;
  }
};
