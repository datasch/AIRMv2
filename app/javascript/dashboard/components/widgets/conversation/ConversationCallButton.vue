<script setup>
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import {
  getVoiceCallProvider,
  VOICE_CALL_PROVIDERS,
} from 'dashboard/helper/inbox';
import {
  VOICE_CALL_DIRECTION,
  VOICE_CALL_OUTBOUND_INIT_STATUS,
} from 'dashboard/components-next/message/constants';
import { useWhatsappCallSession } from 'dashboard/composables/useWhatsappCallSession';
import { useCallsStore } from 'dashboard/stores/calls';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAlert } from 'dashboard/composables';
import { voipState, makeCall, openDialer } from 'dashboard/helper/voipHelper';
import VoipAPI from 'dashboard/api/voip';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const callsStore = useCallsStore();
const whatsappCallSession = useWhatsappCallSession();
const contactsUiFlags = useMapGetter('contacts/getUIFlags');
const { isCloudFeatureEnabled } = useAccount();

const voiceCallProvider = computed(() => getVoiceCallProvider(props.inbox));
const isVoiceCallInbox = computed(
  () =>
    voiceCallProvider.value !== null &&
    isCloudFeatureEnabled(FEATURE_FLAGS.CHANNEL_VOICE)
);
const isWhatsappVoiceInbox = computed(
  () => voiceCallProvider.value === VOICE_CALL_PROVIDERS.WHATSAPP
);

const contactPhone = computed(() => {
  return (
    props.chat?.meta?.sender?.phone_number ||
    props.chat?.contact?.phone_number ||
    store.getters['contacts/getContact'](props.chat?.meta?.sender?.id)
      ?.phone_number ||
    store.getters['contacts/getContact'](props.chat?.contact?.id)
      ?.phone_number ||
    ''
  );
});

const hasVoipEnabled = computed(
  () => voipState.isConfigured || voipState.isEnabled
);

const isCallable = computed(
  () => isVoiceCallInbox.value || !!contactPhone.value || hasVoipEnabled.value
);

const isCallButtonDisabled = computed(() => {
  if (callsStore.hasActiveCall || callsStore.hasIncomingCall) return true;
  if (isWhatsappVoiceInbox.value) {
    return whatsappCallSession.isInitiating.value;
  }
  return contactsUiFlags.value?.isInitiatingCall || false;
});

const isCallButtonLoading = computed(() =>
  isWhatsappVoiceInbox.value
    ? whatsappCallSession.isInitiating.value
    : !!contactsUiFlags.value?.isInitiatingCall
);

const callButtonTooltip = computed(() => {
  if (isWhatsappVoiceInbox.value) {
    return t('CONVERSATION.HEADER.WHATSAPP_CALL');
  }
  if (hasVoipEnabled.value) {
    return t('VOIP_SETTINGS.DIALER.CALL', 'Llamar');
  }
  return t('CONVERSATION.HEADER.VOICE_CALL');
});

const startWhatsappCall = async () => {
  if (whatsappCallSession.isInitiating.value) return;
  try {
    const response = await whatsappCallSession.initiateOutboundCall({
      conversationId: props.chat.id,
    });

    // Composable returns LOCKED when init is already in flight or a call is
    // active; soft no-op so a parallel click doesn't trigger a banner.
    if (response?.status === VOICE_CALL_OUTBOUND_INIT_STATUS.LOCKED) return;
    // Permission template path returns no call id — show banner, no widget yet.
    if (!response?.id) {
      const status = response?.status;
      const message =
        status === VOICE_CALL_OUTBOUND_INIT_STATUS.PERMISSION_PENDING
          ? t('CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_PENDING')
          : t('CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_REQUESTED');
      useAlert(message);
      return;
    }

    // Stay non-active until Meta delivers the connect webhook (sdp_answer);
    // flipping to active here would start the duration timer before pickup.
    callsStore.addCall({
      callSid: response.call_id,
      callId: response.id,
      conversationId: props.chat.id,
      inboxId: props.inbox?.id,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
      provider: VOICE_CALL_PROVIDERS.WHATSAPP,
    });
  } catch (error) {
    useAlert(error?.message || t('CONVERSATION.HEADER.WHATSAPP_CALL_FAILED'));
  }
};

const startTwilioCall = async () => {
  if (contactsUiFlags.value?.isInitiatingCall) return;
  try {
    const response = await store.dispatch('contacts/initiateCall', {
      contactId: props.chat?.meta?.sender?.id,
      inboxId: props.inbox?.id,
      conversationId: props.chat.id,
    });

    callsStore.addCall({
      callSid: response?.call_sid,
      conversationId: response?.conversation_id ?? props.chat.id,
      inboxId: props.inbox?.id,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
    });
  } catch (error) {
    useAlert(error?.message || t('CONVERSATION.HEADER.VOICE_CALL_FAILED'));
  }
};

const startCall = async () => {
  if (isWhatsappVoiceInbox.value) {
    await startWhatsappCall();
    return;
  }
  if (isVoiceCallInbox.value) {
    await startTwilioCall();
    return;
  }

  if (hasVoipEnabled.value) {
    const contactId = props.chat?.meta?.sender?.id || props.chat?.contact?.id;
    const customCallerId = props.inbox?.phone_number;

    if (contactId) {
      try {
        const response = await VoipAPI.callContact({
          contactId,
          conversationId: props.chat.id,
        });
        const data = response.data || {};
        const dest = data.destination || contactPhone.value;
        const displayName = data.contact?.name || contactPhone.value;
        const displayPhone = data.contact?.phone_number || contactPhone.value;

        voipState.remoteDisplayName = displayName;
        voipState.remoteNumber = displayPhone;

        if (voipState.isRegistered && dest) {
          makeCall(dest, props.chat.id, customCallerId, displayPhone);
        } else {
          openDialer(displayPhone, props.chat.id);
        }
        return;
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            error.message ||
            t('CONVERSATION.HEADER.VOICE_CALL_FAILED')
        );
        return;
      }
    }

    if (voipState.isRegistered && contactPhone.value) {
      makeCall(
        contactPhone.value,
        props.chat.id,
        customCallerId,
        contactPhone.value
      );
    } else {
      openDialer(contactPhone.value, props.chat.id);
    }
    return;
  }

  if (contactPhone.value) {
    window.location.href = `tel:${contactPhone.value}`;
  }
};
</script>

<template>
  <NextButton
    v-if="isCallable"
    v-tooltip.bottom="callButtonTooltip"
    sm
    ghost
    slate
    icon="i-lucide-phone"
    :is-loading="isCallButtonLoading"
    :disabled="isCallButtonDisabled"
    @click="startCall"
  />
  <template v-else />
</template>
