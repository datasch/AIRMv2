<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { until } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { isVoiceCallEnabled } from 'dashboard/helper/inbox';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useCallHistoryStore } from 'dashboard/stores/callHistory';

import VoipDialer from 'dashboard/components/widgets/conversation/VoipDialer.vue';
import { voipState, initVoIP } from 'dashboard/helper/voipHelper';
import CallListItem from 'dashboard/components-next/Calls/CallListItem.vue';
import CallsEmptyState from 'dashboard/components-next/Calls/CallsEmptyState.vue';
import CallsFilterBar from 'dashboard/components-next/Calls/CallsFilterBar.vue';
import { CALL_ACTIVITY_PARAMS } from 'dashboard/components-next/Calls/constants';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const RESULTS_PER_PAGE = 25;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const callHistoryStore = useCallHistoryStore();

const inboxes = useMapGetter('inboxes/getInboxes');
const accountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');
const agents = useMapGetter('agents/getVerifiedAgents');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

// CallFinder scopes non-admins to their own accepted calls, so the assignee
// filter is only meaningful for admins; everyone else defaults to themselves.
const { isAdmin } = useAdmin();
const showAdminDialer = ref(false);

const voiceInboxes = computed(() => inboxes.value.filter(isVoiceCallEnabled));

const isVoiceEnabled = computed(
  () =>
    (isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.CHANNEL_VOICE
    ) &&
      voiceInboxes.value.length > 0) ||
    voipState.isEnabled ||
    voipState.isConfigured ||
    !isAdmin.value
);

const calls = computed(() => callHistoryStore.records);
const meta = computed(() => callHistoryStore.meta);
const isFetching = computed(() => callHistoryStore.uiFlags.isFetching);
const accountUiFlags = useMapGetter('accounts/getUIFlags');

const isInitializing = ref(true);

// Filters are seeded from the URL so a shared link restores the same view.
const activity = ref(
  CALL_ACTIVITY_PARAMS[route.query.activity] ? route.query.activity : null
);

const assigneeId = ref(
  isAdmin.value ? Number(route.query.assignee_id) || null : currentUserId.value
);
const inboxId = ref(Number(route.query.inbox_id) || null);
const currentPage = ref(Number(route.query.page) || 1);

const syncFiltersToUrl = () => {
  router.replace({
    query: {
      ...(activity.value && { activity: activity.value }),
      ...(isAdmin.value &&
        assigneeId.value && { assignee_id: assigneeId.value }),
      ...(inboxId.value && { inbox_id: inboxId.value }),
      ...(currentPage.value > 1 && { page: currentPage.value }),
    },
  });
};

const fetchCalls = async () => {
  syncFiltersToUrl();
  try {
    await callHistoryStore.fetchCalls({
      page: currentPage.value,
      ...(CALL_ACTIVITY_PARAMS[activity.value] || {}),
      ...(assigneeId.value ? { agent_id: assigneeId.value } : {}),
      ...(inboxId.value ? { inbox_id: inboxId.value } : {}),
    });
  } catch (error) {
    useAlert(error.message);
  }
};

watch([activity, assigneeId, inboxId], () => {
  currentPage.value = 1;
  fetchCalls();
});

const onPageChange = page => {
  currentPage.value = page;
  fetchCalls();
};

const totalCallsCount = computed(() => {
  if (isFetching.value) return '...';
  return meta.value.count || calls.value.length;
});

onMounted(async () => {
  try {
    initVoIP();
    await Promise.all([
      store.dispatch('inboxes/get'),
      until(() => accountUiFlags.value.isFetchingItem).toBe(false),
    ]);
    if (!isVoiceEnabled.value) return;
    // Only admins see the assignee filter, so only they need the agent list.
    if (isAdmin.value) store.dispatch('agents/get');
    await fetchCalls();
  } finally {
    isInitializing.value = false;
  }
});
</script>

<template>
  <div
    v-if="isInitializing"
    class="flex items-center justify-center w-full h-full bg-n-surface-1"
  >
    <Spinner :size="24" />
  </div>
  <CallsEmptyState v-else-if="!isVoiceEnabled" />

  <!-- Non-admin layout: Embedded Interactive Phone + My Calls Log -->
  <section
    v-else-if="!isAdmin"
    class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1"
  >
    <header
      class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-surface-1 shrink-0"
    >
      <div>
        <h1 class="text-xl font-bold text-n-slate-12">
          {{ t('CALLS_PAGE.HEADER') }}
        </h1>
        <p class="text-xs text-n-slate-11 mt-0.5">
          {{ t('CALLS_PAGE.PHONE_TITLE') }}
        </p>
      </div>
      <div
        v-if="voipState.caller_id"
        class="text-xs font-mono text-n-slate-11 bg-n-alpha-1 px-3 py-1 rounded-full border border-n-weak"
      >
        {{ t('CALLS_PAGE.CALLER_ID', { id: voipState.caller_id }) }}
      </div>
    </header>

    <main class="flex-1 px-6 py-6 overflow-y-auto">
      <div
        class="flex flex-col lg:flex-row gap-6 items-start max-w-7xl mx-auto w-full"
      >
        <!-- Phone / Dialpad Column -->
        <div class="w-full lg:w-80 shrink-0">
          <VoipDialer embedded />
        </div>

        <!-- My Calls Log Column -->
        <div
          class="flex-1 min-w-0 w-full flex flex-col rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-sm overflow-hidden"
        >
          <div
            class="flex items-center justify-between px-5 py-3.5 border-b border-slate-100 dark:border-slate-800 bg-slate-50/70 dark:bg-slate-800/40"
          >
            <h2
              class="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2"
            >
              <i class="i-lucide-history text-base text-slate-500" />
              {{ t('CALLS_PAGE.MY_CALLS_TITLE') }}
            </h2>
            <span
              class="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-slate-200/70 text-slate-700 dark:bg-slate-800 dark:text-slate-300 tabular-nums"
            >
              {{ totalCallsCount }}
            </span>
          </div>

          <div class="flex-1 overflow-y-auto px-5 divide-y divide-n-weak">
            <div
              v-if="isFetching"
              class="flex items-center justify-center py-16"
            >
              <Spinner :size="24" />
            </div>
            <div
              v-else-if="!calls.length"
              class="flex flex-col items-center justify-center py-16 text-center text-n-slate-11"
            >
              <i class="i-lucide-phone-incoming text-3xl mb-2 opacity-50" />
              <p class="text-sm max-w-sm">
                {{ t('CALLS_PAGE.AGENT_EMPTY_STATE') }}
              </p>
            </div>
            <template v-else>
              <CallListItem v-for="call in calls" :key="call.id" :call="call" />
            </template>
          </div>

          <footer
            v-if="calls.length"
            class="shrink-0 border-t border-slate-100 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/20"
          >
            <PaginationFooter
              :current-page="currentPage"
              :total-items="meta.count"
              :items-per-page="RESULTS_PER_PAGE"
              @update:current-page="onPageChange"
            />
          </footer>
        </div>
      </div>
    </main>
  </section>

  <!-- Admin View with Full Filters & Optional Dialer Toggle -->
  <section
    v-else
    class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1"
  >
    <header class="shrink-0">
      <div class="w-full px-6 pt-6 flex items-center justify-between">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('CALLS_PAGE.HEADER') }}
        </h1>
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 shadow-sm transition cursor-pointer"
          @click="showAdminDialer = !showAdminDialer"
        >
          <i class="i-lucide-phone text-xs" />
          {{
            showAdminDialer
              ? t('CALLS_PAGE.CLOSE_DIALER')
              : t('CALLS_PAGE.OPEN_DIALER')
          }}
        </button>
      </div>
      <CallsFilterBar
        v-model:activity="activity"
        v-model:assignee-id="assigneeId"
        v-model:inbox-id="inboxId"
        class="mt-5 pb-4 border-b border-n-weak mx-6"
        :total-count="isFetching ? null : meta.count"
        :agents="agents"
        :inboxes="voiceInboxes"
        :show-assignee="isAdmin"
      />
    </header>
    <main class="flex-1 px-6 overflow-y-auto">
      <div
        class="w-full py-4"
        :class="{
          'flex flex-col lg:flex-row gap-6 items-start': showAdminDialer,
        }"
      >
        <div v-if="showAdminDialer" class="w-full lg:w-80 shrink-0">
          <VoipDialer embedded />
        </div>
        <div class="flex-1 min-w-0 w-full">
          <div v-if="isFetching" class="flex items-center justify-center py-16">
            <Spinner :size="24" />
          </div>
          <div
            v-else-if="!calls.length"
            class="flex items-center justify-center py-16"
          >
            <span class="text-base text-n-slate-11">
              {{ t('CALLS_PAGE.EMPTY_STATE') }}
            </span>
          </div>
          <template v-else>
            <CallListItem v-for="call in calls" :key="call.id" :call="call" />
          </template>
        </div>
      </div>
    </main>
    <footer v-if="calls.length" class="sticky bottom-0 shrink-0">
      <PaginationFooter
        :current-page="currentPage"
        :total-items="meta.count"
        :items-per-page="RESULTS_PER_PAGE"
        @update:current-page="onPageChange"
      />
    </footer>
  </section>
</template>
