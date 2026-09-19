import JsSIP from 'jssip';
import { reactive } from 'vue';
import { useAlert } from 'dashboard/composables';
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
  callState: 'idle', // 'idle' | 'calling' | 'ringing' | 'connected' | 'ended' | 'disposition'
  remoteNumber: '',
  remoteDisplayName: '',
  callDuration: 0,
  isMuted: false,
  isOnHold: false,
  isDialerOpen: false,
  conversationId: null,
  callId: null,
  lastCallDuration: 0,
  lastCallStatus: 'completed',
  lastCallCategory: 'ineffective',
});

let ua = null;
let durationTimer = null;
let remoteAudioElement = null;
let ringbackAudioContext = null;
let ringbackInterval = null;

const createRingbackAudio = () => {
  if (ringbackAudioContext && ringbackAudioContext.state !== 'closed') return;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return;
  ringbackAudioContext = new AudioContextClass();
};

export const stopRingbackTone = () => {
  if (ringbackInterval) {
    clearInterval(ringbackInterval);
    ringbackInterval = null;
  }
  if (ringbackAudioContext) {
    try {
      ringbackAudioContext.close().catch(() => {});
    } catch (e) {
      // AudioContext already closed
    }
    ringbackAudioContext = null;
  }
};

export const playRingbackTone = () => {
  stopRingbackTone();
  try {
    createRingbackAudio();
    if (!ringbackAudioContext) return;

    if (ringbackAudioContext.state === 'suspended') {
      ringbackAudioContext.resume().catch(() => {});
    }

    const playToneBurst = () => {
      if (!ringbackAudioContext || ringbackAudioContext.state === 'closed')
        return;

      const now = ringbackAudioContext.currentTime;
      const gainNode = ringbackAudioContext.createGain();
      gainNode.connect(ringbackAudioContext.destination);

      const osc1 = ringbackAudioContext.createOscillator();
      const osc2 = ringbackAudioContext.createOscillator();
      osc1.type = 'sine';
      osc2.type = 'sine';
      osc1.frequency.setValueAtTime(440, now);
      osc2.frequency.setValueAtTime(480, now);

      osc1.connect(gainNode);
      osc2.connect(gainNode);

      gainNode.gain.setValueAtTime(0.0001, now);
      gainNode.gain.exponentialRampToValueAtTime(0.18, now + 0.05);
      gainNode.gain.setValueAtTime(0.18, now + 1.75);
      gainNode.gain.exponentialRampToValueAtTime(0.0001, now + 1.8);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 1.85);
      osc2.stop(now + 1.85);
    };

    playToneBurst();
    ringbackInterval = setInterval(() => {
      if (
        voipState.callState !== 'calling' &&
        voipState.callState !== 'ringing'
      ) {
        stopRingbackTone();
        return;
      }
      playToneBurst();
    }, 4000);
  } catch (err) {
    // Web Audio not available or autoplay blocked
  }
};

const ensureAudioElement = () => {
  if (!remoteAudioElement) {
    remoteAudioElement = document.createElement('audio');
    remoteAudioElement.id = 'voip-remote-audio';
    remoteAudioElement.autoplay = true;
    document.body.appendChild(remoteAudioElement);
  }
  return remoteAudioElement;
};

const stopRemoteAudio = () => {
  if (remoteAudioElement) {
    remoteAudioElement.pause();
    remoteAudioElement.srcObject = null;
  }
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
  stopRingbackTone();
  if (
    voipState.callState === 'idle' ||
    voipState.callState === 'ended' ||
    voipState.callState === 'disposition'
  ) {
    return;
  }

  const finalDuration = voipState.callDuration;
  const phoneNumber = voipState.remoteNumber;
  const convId = voipState.conversationId;
  const currentCallId = voipState.callId;

  stopDurationTimer();
  stopRemoteAudio();
  voipState.currentSession = null;
  voipState.isMuted = false;
  voipState.isOnHold = false;
  voipState.lastCallDuration = finalDuration;
  voipState.lastCallStatus = status;

  // Clasificación de efectividad según reglas de negocio:
  // Efectiva: >= 6 segundos
  // Prueba: entre 2 y 5 segundos (> 1 y <= 5)
  // No efectiva: < 2 segundos, buzón de voz o sin contacto
  let category = 'ineffective';
  if (finalDuration >= 6) {
    category = 'effective';
  } else if (finalDuration >= 2 && finalDuration <= 5) {
    category = 'test';
  }
  voipState.lastCallCategory = category;

  VoipAPI.updateCallStatus({ event: 'ended', phoneNumber });

  // Si se canceló durante el timbrado/marcado antes de contestar (duración 0)
  if (status === 'cancelled' && finalDuration === 0) {
    if (convId && phoneNumber) {
      VoipAPI.logCall({
        conversationId: convId,
        phoneNumber,
        durationSeconds: 0,
        status: 'cancelled',
        callId: currentCallId,
        disposition: 'Llamada cancelada',
        updateConversationTipificacion: false,
      }).catch(() => {});
    }
    voipState.callState = 'idle';
    voipState.remoteNumber = '';
    voipState.callId = null;
    return;
  }

  // Si hubo llamada a un contacto o número, pasar a pantalla de tipificación
  if (phoneNumber) {
    voipState.callState = 'disposition';
  } else {
    voipState.callState = 'ended';
    setTimeout(() => {
      if (voipState.callState === 'ended') {
        voipState.callState = 'idle';
        voipState.remoteNumber = '';
        voipState.conversationId = null;
        voipState.callId = null;
      }
    }, 2000);
  }
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
    playRingbackTone();
    VoipAPI.updateCallStatus({
      event: 'ringing',
      phoneNumber: voipState.remoteNumber,
    });
  });

  session.on('accepted', () => {
    stopRingbackTone();
    voipState.callState = 'connected';
    startDurationTimer();
    VoipAPI.updateCallStatus({
      event: 'connected',
      phoneNumber: voipState.remoteNumber,
    });
    if (session.connection) {
      const streams = session.connection.getRemoteStreams
        ? session.connection.getRemoteStreams()
        : [];
      if (streams.length > 0) attachMedia(streams[0]);
    }
  });

  session.on('confirmed', () => {
    stopRingbackTone();
    voipState.callState = 'connected';
    if (session.connection) {
      const streams = session.connection.getRemoteStreams
        ? session.connection.getRemoteStreams()
        : [];
      if (streams.length > 0) attachMedia(streams[0]);
    }
  });

  session.on('peerconnection', e => {
    const pc = e.peerconnection;
    pc.ontrack = attachMedia;
    pc.addEventListener('track', attachMedia);
  });

  session.on('ended', () => {
    stopRingbackTone();
    handleCallTermination('completed');
  });

  session.on('failed', e => {
    stopRingbackTone();
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
      register: false,
    };

    ua = new JsSIP.UA(configuration);

    ua.on('connected', () => {
      /* eslint-disable no-underscore-dangle */
      if (ua._registrator) {
        try {
          ua._registrator._to_uri = new JsSIP.URI(
            'sip',
            `${agent.extension}-aor`,
            sip_domain
          );
        } catch (e) {
          // fallback
        }
      }
      /* eslint-enable no-underscore-dangle */
      ua.register();
    });

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
      if (e.cause === 'Authentication Error' || e.cause === 'Not Found') {
        ua?.stop();
      }
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

const sleep = ms =>
  new Promise(resolve => {
    setTimeout(resolve, ms);
  });

export const makeCall = async (
  targetNumber,
  conversationId = null,
  customCallerId = null,
  displayLabel = null
) => {
  if (!ua || !voipState.isRegistered) {
    await initVoIP();
    const startWait = Date.now();
    while (!voipState.isRegistered && Date.now() - startWait < 3500) {
      // eslint-disable-next-line no-await-in-loop
      await sleep(200);
      if (voipState.registrationError) break;
    }
  }

  if (!targetNumber) return;

  if (navigator?.mediaDevices?.getUserMedia) {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach(track => track.stop());
    } catch (micErr) {
      // Ignore mic pre-warm error
    }
  }

  let dialTarget = targetNumber;
  let labelToShow = displayLabel || targetNumber;

  const rawStr = targetNumber.toString().trim();
  const isMaskedOrRef =
    rawStr.includes('*') ||
    rawStr.includes('•') ||
    rawStr.startsWith('#') ||
    rawStr.includes('/conversations/') ||
    /^\d{1,6}$/.test(rawStr);

  if (isMaskedOrRef || conversationId) {
    try {
      const res = await VoipAPI.callContact({
        phoneNumber: rawStr,
        conversationId,
      });
      const data = res.data || {};
      if (data.destination) {
        dialTarget = data.destination;
      }
      if (data.contact?.phone_number) {
        labelToShow = displayLabel || data.contact.phone_number;
      } else if (data.display_conversation_id) {
        labelToShow =
          displayLabel || `/conversations/${data.display_conversation_id}`;
      }
      if (data.contact?.display_name || data.contact?.name) {
        voipState.remoteDisplayName =
          data.contact.display_name || data.contact.name;
      }
      if (data.conversation_id) {
        voipState.conversationId = data.conversation_id;
      }
    } catch (err) {
      // Fallback to dialTarget if resolution fails
    }
  }

  const cleanNumber = dialTarget.toString().replace(/[^0-9+]/g, '');
  if (!cleanNumber) return;

  if (!ua || !voipState.isRegistered) {
    stopRingbackTone();
    voipState.callState = 'idle';
    if (voipState.isEnabled) {
      useAlert(
        voipState.registrationError
          ? `Error de telefonía VoIP: ${voipState.registrationError}. Verifica la extensión o conexión a Asterisk.`
          : 'El servicio de telefonía VoIP no está conectado con Asterisk. Verifica la extensión del asesor.'
      );
    } else {
      window.location.href = `tel:${cleanNumber}`;
    }
    return;
  }

  const callerId = customCallerId || voipState.caller_id;
  const callId = `call_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  voipState.callId = callId;
  voipState.remoteNumber = labelToShow;
  voipState.conversationId = conversationId || voipState.conversationId;
  voipState.callState = 'calling';
  voipState.isDialerOpen = true;

  playRingbackTone();

  const extraHeaders = [`X-Call-ID: ${callId}`];
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

  VoipAPI.updateCallStatus({ event: 'started', phoneNumber: labelToShow });

  try {
    const session = ua.call(
      `sip:${cleanNumber}@${voipState.sip_domain || 'pbx'}`,
      eventOptions
    );
    voipState.currentSession = session;
    bindSessionEvents(session);
  } catch (err) {
    stopRingbackTone();
    voipState.callState = 'idle';
    useAlert(err.message || 'Error al conectar la llamada WebRTC');
  }
};

export const answerCall = () => {
  stopRingbackTone();
  if (voipState.currentSession && voipState.callState === 'ringing') {
    voipState.currentSession.answer({
      mediaConstraints: { audio: true, video: false },
    });
  }
};

export const hangupCall = () => {
  stopRingbackTone();
  const wasCalling =
    voipState.callState === 'calling' || voipState.callState === 'ringing';
  const session = voipState.currentSession;

  if (session) {
    try {
      session.terminate({
        status_code: 487,
        reason_phrase: 'Request Terminated',
      });
    } catch (err) {
      // Session already ended or cancelled
    }
  }

  // Si se cuelga durante el timbrado/marcado antes de contestar, cancelar y detener inmediatamente sin esperar
  if (wasCalling) {
    handleCallTermination('cancelled');
  } else if (!session) {
    handleCallTermination('ended');
  }
};

export const submitCallDisposition = async ({
  disposition,
  updateConversationTipificacion = false,
}) => {
  const convId = voipState.conversationId;
  const phoneNumber = voipState.remoteNumber;
  const durationSeconds = voipState.lastCallDuration;
  const status = voipState.lastCallStatus || 'completed';
  const callId = voipState.callId;

  if (phoneNumber) {
    try {
      await VoipAPI.logCall({
        conversationId: convId,
        phoneNumber,
        durationSeconds,
        status,
        callId,
        disposition,
        updateConversationTipificacion,
      });
    } catch (err) {
      // Best-effort call logging
    }
  }

  voipState.callState = 'idle';
  voipState.remoteNumber = '';
  voipState.callId = null;
  voipState.conversationId = null;
  voipState.isDialerOpen = false;
};

export const skipCallDisposition = async () => {
  const convId = voipState.conversationId;
  const phoneNumber = voipState.remoteNumber;
  const durationSeconds = voipState.lastCallDuration;
  const status = voipState.lastCallStatus || 'completed';
  const callId = voipState.callId;

  if (phoneNumber) {
    try {
      await VoipAPI.logCall({
        conversationId: convId,
        phoneNumber,
        durationSeconds,
        status,
        callId,
        disposition: null,
        updateConversationTipificacion: false,
      });
    } catch (err) {
      // Best-effort call logging
    }
  }

  voipState.callState = 'idle';
  voipState.remoteNumber = '';
  voipState.callId = null;
  voipState.conversationId = null;
  voipState.isDialerOpen = false;
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
