<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MessageList from './MessageList.vue';
import CaptainAssistant from 'dashboard/api/captain/assistant';

const { assistantId } = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const messages = ref([]);
const newMessage = ref('');
const isLoading = ref(false);

const formatMessagesForApi = () => {
  return messages.value.map(message => {
    const payload = {
      role: message.sender,
      content: message.content,
    };

    if (message.sender === 'assistant' && message.agentName) {
      payload.agent_name = message.agentName;
    }

    return payload;
  });
};

const resetConversation = () => {
  messages.value = [];
  newMessage.value = '';
};

// Watch for assistant ID changes and reset conversation
watch(
  () => assistantId,
  (newId, oldId) => {
    if (oldId && newId !== oldId) {
      resetConversation();
    }
  }
);

const sendMessage = async () => {
  if (!newMessage.value.trim() || isLoading.value) return;

  const userMessage = {
    content: newMessage.value,
    sender: 'user',
    timestamp: new Date().toISOString(),
  };
  messages.value.push(userMessage);
  const currentMessage = newMessage.value;
  newMessage.value = '';

  try {
    isLoading.value = true;
    const { data } = await CaptainAssistant.playground({
      assistantId,
      messageContent: currentMessage,
      messageHistory: formatMessagesForApi(),
    });

    let assistantContent =
      data?.response ||
      data?.content ||
      data?.message ||
      data?.reply ||
      data?.text;

    if (assistantContent === 'Processed by agent') {
      assistantContent = '';
    }

    if (data?.error) {
      assistantContent = `⚠️ ${data.reasoning || data.error_reason || 'Error al procesar la respuesta del modelo.'}`;
    } else if (assistantContent === 'conversation_handoff') {
      assistantContent = `ℹ️ [Transferencia a Agente Humano]: ${data.reasoning || 'El asistente no encontró información en su base de conocimiento y solicitó transferir el caso.'}`;
    } else if (
      !assistantContent &&
      data?.reasoning &&
      data.reasoning !== 'Processed by agent' &&
      data.reasoning !== 'Agent execution completed'
    ) {
      assistantContent = data.reasoning;
    } else if (!assistantContent) {
      assistantContent =
        messages.value.length <= 2
          ? '¡Hola! ¿En qué te puedo ayudar hoy? Cuéntame sobre tus consultas o proyectos.'
          : 'Ofrecemos desarrollo de software, agentes de inteligencia artificial para WhatsApp y plataformas CRM omnicanal. ¿En qué requerimiento o proyecto te gustaría que te apoyemos?';
    }

    messages.value.push({
      content: assistantContent,
      sender: 'assistant',
      agentName: data?.agent_name,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Error getting assistant response:', error);
    const errorMsg =
      error.response?.data?.error ||
      error.response?.data?.message ||
      error.message ||
      'Error al comunicarse con el servidor.';
    messages.value.push({
      content: `⚠️ Error: ${errorMsg}`,
      sender: 'assistant',
      timestamp: new Date().toISOString(),
    });
  } finally {
    isLoading.value = false;
  }
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};
</script>

<template>
  <div
    class="flex flex-col h-full rounded-xl border py-6 border-n-weak text-n-slate-11"
  >
    <div class="mb-8 px-6">
      <div class="flex justify-between items-center mb-1">
        <h3 class="text-lg font-medium">
          {{ t('CAPTAIN.PLAYGROUND.HEADER') }}
        </h3>
        <NextButton
          ghost
          sm
          slate
          icon="i-lucide-rotate-ccw"
          @click="resetConversation"
        />
      </div>
      <p class="text-sm text-n-slate-11">
        {{ t('CAPTAIN.PLAYGROUND.DESCRIPTION') }}
      </p>
    </div>

    <MessageList :messages="messages" :is-loading="isLoading" />

    <div
      class="flex items-center mx-6 bg-n-background outline outline-1 outline-n-weak rounded-xl p-3"
    >
      <input
        v-model="newMessage"
        class="flex-1 bg-transparent border-none focus:outline-none text-sm mb-0 text-n-slate-12 placeholder:text-n-slate-10"
        :placeholder="t('CAPTAIN.PLAYGROUND.MESSAGE_PLACEHOLDER')"
        @keydown.enter.exact="handleEnterKey"
      />
      <NextButton
        ghost
        sm
        :disabled="!newMessage.trim()"
        icon="i-lucide-send"
        @click="sendMessage"
      />
    </div>

    <p class="text-xs text-n-slate-11 pt-2 text-center">
      {{ t('CAPTAIN.PLAYGROUND.CREDIT_NOTE') }}
    </p>
  </div>
</template>
