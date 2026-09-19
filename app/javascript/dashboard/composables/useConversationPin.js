import { computed, getCurrentInstance, ref } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

/**
 * Composable for managing user-specific pinned conversations.
 * Persists in user's ui_settings.pinned_conversation_ids via Chatwoot's native preference sync.
 */
export function useConversationPin() {
  const vm = getCurrentInstance();
  if (!vm?.proxy?.$store) {
    const dummyPinned = ref([]);
    return {
      pinnedConversationIds: dummyPinned,
      isPinned: () => false,
      togglePin: () => {},
    };
  }

  const { uiSettings, updateUISettings } = useUISettings();

  const pinnedConversationIds = computed(() => {
    return uiSettings.value?.pinned_conversation_ids || [];
  });

  const isPinned = conversationId => {
    if (!conversationId) return false;
    return pinnedConversationIds.value.includes(Number(conversationId));
  };

  const togglePin = conversationId => {
    if (!conversationId) return;
    const id = Number(conversationId);
    const current = pinnedConversationIds.value;
    const isCurrentlyPinned = current.includes(id);

    const updated = isCurrentlyPinned
      ? current.filter(item => item !== id)
      : [id, ...current.filter(item => item !== id)];

    updateUISettings({
      pinned_conversation_ids: updated,
    });
  };

  return {
    pinnedConversationIds,
    isPinned,
    togglePin,
  };
}
