<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import IanLogo from 'dashboard/components-next/captain/IanLogo.vue';

const route = useRoute();

const { uiSettings, updateUISettings } = useUISettings();

const isConversationRoute = computed(() => {
  const CONVERSATION_ROUTES = [
    'inbox_conversation',
    'conversation_through_inbox',
    'conversations_through_label',
    'team_conversations_through_label',
    'conversations_through_folders',
    'conversation_through_mentions',
    'conversation_through_unattended',
    'conversation_through_participating',
    'inbox_view_conversation',
  ];
  return CONVERSATION_ROUTES.includes(route.name);
});

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showCopilotLauncher = computed(() => {
  const isCaptainEnabled = isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN
  );
  return (
    isCaptainEnabled &&
    !uiSettings.value.is_copilot_panel_open &&
    !isConversationRoute.value
  );
});

const toggleSidebar = () => {
  updateUISettings({
    is_copilot_panel_open: !uiSettings.value.is_copilot_panel_open,
    is_contact_sidebar_open: false,
  });
};
</script>

<template>
  <div
    v-if="showCopilotLauncher"
    class="fixed bottom-4 ltr:right-4 rtl:left-4 z-50"
  >
    <div
      class="rounded-full bg-n-alpha-2 backdrop-blur-lg p-1 shadow-lg hover:shadow-xl transition-all duration-200"
    >
      <button
        type="button"
        class="size-11 rounded-full bg-black text-white dark:bg-black dark:text-white border border-slate-700/80 flex items-center justify-center p-2 transition-all duration-200 hover:scale-105 hover:border-slate-500 shadow-md group cursor-pointer"
        :title="$t('CAPTAIN.NAME')"
        @click="toggleSidebar"
      >
        <IanLogo
          class="size-6 text-white group-hover:scale-110 transition-transform"
        />
      </button>
    </div>
  </div>
  <template v-else />
</template>
