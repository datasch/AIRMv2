<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import VoipAPI from 'dashboard/api/voip';
import ReportHeader from './components/ReportHeader.vue';

const { t } = useI18n();

const isLoading = ref(true);
const selectedPeriod = ref('30');
const reportsData = ref({
  metrics: {
    total_calls: 0,
    effective_calls: 0,
    test_calls: 0,
    ineffective_calls: 0,
    effective_percentage: 0,
    tmo_seconds: 0,
    tmo_formatted: '00:00',
  },
  calls_by_day: [],
  calls_by_hour: [],
  dispositions_summary: [],
  agent_workforce: [],
  recent_calls: [],
});

const periods = computed(() => [
  { value: '1', label: t('REPORT.DATE_RANGE.TODAY') || 'Hoy' },
  { value: '7', label: t('REPORT.DATE_RANGE.LAST_7_DAYS') || 'Últimos 7 días' },
  {
    value: '30',
    label: t('REPORT.DATE_RANGE.LAST_30_DAYS') || 'Últimos 30 días',
  },
  {
    value: '90',
    label: t('REPORT.DATE_RANGE.LAST_3_MONTHS') || 'Últimos 90 días',
  },
]);

const fetchReports = async () => {
  try {
    isLoading.value = true;
    const now = new Date();
    const days = parseInt(selectedPeriod.value, 10);
    const sinceDate = new Date();
    sinceDate.setDate(now.getDate() - (days === 1 ? 0 : days));
    if (days === 1) sinceDate.setHours(0, 0, 0, 0);

    const response = await VoipAPI.getClickToCallReports({
      since: sinceDate.toISOString(),
      until: now.toISOString(),
      all_agents: true,
    });

    reportsData.value = response.data;
  } catch {
    // Handled in UI
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchReports();
});

const maxHourlyCount = computed(() => {
  const counts = reportsData.value.calls_by_hour.map(h => h.count);
  return Math.max(...counts, 1);
});

const maxDailyCount = computed(() => {
  const counts = reportsData.value.calls_by_day.map(d => d.total);
  return Math.max(...counts, 1);
});
</script>

<template>
  <div class="space-y-6 pb-12">
    <ReportHeader
      :header-title="t('REPORT.CLICK_TO_CALL.TITLE')"
      :header-description="t('REPORT.CLICK_TO_CALL.DESCRIPTION')"
    >
      <div class="flex items-center gap-2">
        <select
          v-model="selectedPeriod"
          class="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm focus:border-blue-500 focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
          @change="fetchReports"
        >
          <option
            v-for="period in periods"
            :key="period.value"
            :value="period.value"
          >
            {{ period.label }}
          </option>
        </select>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
          :disabled="isLoading"
          @click="fetchReports"
        >
          <i
            class="i-lucide-refresh-cw text-xs"
            :class="{ 'animate-spin': isLoading }"
          />
          <span>{{ t('REPORT.REFRESH') || 'Actualizar' }}</span>
        </button>
      </div>
    </ReportHeader>

    <div v-if="isLoading" class="flex h-64 items-center justify-center">
      <div class="flex flex-col items-center gap-2">
        <i class="i-lucide-loader-2 text-3xl text-blue-600 animate-spin" />
        <span class="text-xs text-slate-500">{{
          t('REPORT.LOADING_CHART')
        }}</span>
      </div>
    </div>

    <div v-else class="space-y-6">
      <!-- KPI Metric Cards Grid -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <!-- Total Calls -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.TOTAL_CALLS') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-blue-50 text-blue-600 dark:bg-blue-950 dark:text-blue-400"
            >
              <i class="i-lucide-phone-call text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-slate-800 dark:text-slate-100">
              {{ reportsData.metrics.total_calls }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.TOTAL_CALLS_SUB') }}
          </p>
        </div>

        <!-- Effective Calls -->
        <div
          class="rounded-2xl border border-emerald-200/80 bg-emerald-50/40 p-4 shadow-sm dark:border-emerald-900/50 dark:bg-emerald-950/20"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold text-emerald-800 dark:text-emerald-300"
            >
              {{ t('REPORT.CLICK_TO_CALL.EFFECTIVE_CALLS') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300"
            >
              <i class="i-lucide-check-check text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-2xl font-bold text-emerald-700 dark:text-emerald-300"
            >
              {{ reportsData.metrics.effective_calls }}
            </span>
            <span
              class="inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-bold text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200"
            >
              {{ reportsData.metrics.effective_percentage }}%
            </span>
          </div>
          <p
            class="mt-1 text-[11px] text-emerald-600/80 dark:text-emerald-400/80"
          >
            {{ t('REPORT.CLICK_TO_CALL.EFFECTIVE_CALLS_SUB') }}
          </p>
        </div>

        <!-- Ineffective / Test Calls -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.INEFFECTIVE_CALLS') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-rose-50 text-rose-600 dark:bg-rose-950 dark:text-rose-400"
            >
              <i class="i-lucide-phone-missed text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-rose-600 dark:text-rose-400">
              {{ reportsData.metrics.ineffective_calls }}
            </span>
            <span class="text-xs text-amber-600 dark:text-amber-400">
              {{
                t('REPORT.CLICK_TO_CALL.TEST_CALLS_COUNT', {
                  count: reportsData.metrics.test_calls,
                })
              }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.INEFFECTIVE_CALLS_SUB') }}
          </p>
        </div>

        <!-- TMO (Average Handling Time) -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.TMO') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600 dark:bg-indigo-950 dark:text-indigo-400"
            >
              <i class="i-lucide-clock text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-2xl font-bold font-mono text-slate-800 dark:text-slate-100"
            >
              {{ reportsData.metrics.tmo_formatted }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.TMO_SUB') }}
          </p>
        </div>
      </div>

      <!-- Charts Row -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- Calls by Day -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between mb-4">
            <div>
              <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
                {{ t('REPORT.CLICK_TO_CALL.CALLS_BY_DAY') }}
              </h3>
              <p class="text-xs text-slate-500">
                {{ t('REPORT.CLICK_TO_CALL.CALLS_BY_DAY_SUB') }}
              </p>
            </div>
          </div>

          <div
            v-if="reportsData.calls_by_day.length === 0"
            class="flex h-48 items-center justify-center text-xs text-slate-400"
          >
            {{ t('REPORT.CLICK_TO_CALL.NO_DATA') }}
          </div>
          <div v-else class="space-y-2 pt-2">
            <div
              v-for="day in reportsData.calls_by_day.slice(-14)"
              :key="day.date"
              class="space-y-1"
            >
              <div
                class="flex justify-between text-xs text-slate-600 dark:text-slate-400"
              >
                <span>{{ day.date }}</span>
                <span class="font-medium text-slate-800 dark:text-slate-200">
                  {{ day.effective }} / {{ day.total }} ({{
                    day.effective_pct
                  }}%)
                </span>
              </div>
              <div
                class="flex h-3 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800"
              >
                <div
                  class="h-full bg-emerald-500 transition-all duration-500"
                  :style="{
                    width: `${(day.effective / maxDailyCount) * 100}%`,
                  }"
                />
                <div
                  class="h-full bg-blue-400 opacity-60 transition-all duration-500"
                  :style="{
                    width: `${((day.total - day.effective) / maxDailyCount) * 100}%`,
                  }"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- 24-Hour Distribution -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between mb-4">
            <div>
              <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
                {{ t('REPORT.CLICK_TO_CALL.HOURLY_DISTRIBUTION') }}
              </h3>
              <p class="text-xs text-slate-500">
                {{ t('REPORT.CLICK_TO_CALL.HOURLY_DISTRIBUTION_SUB') }}
              </p>
            </div>
          </div>

          <div class="flex h-56 items-end gap-1 pt-6 px-1">
            <div
              v-for="item in reportsData.calls_by_hour"
              :key="item.hour"
              class="group relative flex flex-1 flex-col items-center h-full justify-end"
            >
              <div
                class="absolute -top-7 hidden rounded bg-slate-800 px-1.5 py-0.5 text-[10px] text-white shadow group-hover:block dark:bg-slate-700 whitespace-nowrap z-10"
              >
                {{ item.hour }}: {{ item.count }}
              </div>
              <div
                class="w-full rounded-t transition-all duration-300 group-hover:bg-blue-600"
                :class="
                  item.count > 0
                    ? 'bg-blue-500'
                    : 'bg-slate-100 dark:bg-slate-800'
                "
                :style="{
                  height: `${Math.max((item.count / maxHourlyCount) * 100, item.count > 0 ? 8 : 2)}%`,
                }"
              />
              <span
                class="mt-1 text-[9px] text-slate-400 transform -rotate-45 origin-top-left"
              >
                {{ item.hour.split(':')[0] }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Dispositions Breakdown -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
              {{ t('REPORT.CLICK_TO_CALL.DISPOSITIONS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500">
              {{ t('REPORT.CLICK_TO_CALL.DISPOSITIONS_SUB') }}
            </p>
          </div>
        </div>

        <div
          v-if="reportsData.dispositions_summary.length === 0"
          class="py-8 text-center text-xs text-slate-400"
        >
          {{ t('REPORT.CLICK_TO_CALL.NO_DISPOSITIONS') }}
        </div>
        <div
          v-else
          class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div
            v-for="item in reportsData.dispositions_summary"
            :key="item.disposition"
            class="rounded-xl border border-slate-100 bg-slate-50/60 p-3 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ item.disposition }}
              </span>
              <span class="text-xs font-bold text-blue-600 dark:text-blue-400">
                {{ item.count }} ({{ item.percentage }}%)
              </span>
            </div>
            <div
              class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
            >
              <div
                class="h-full bg-blue-500 rounded-full"
                :style="{ width: `${item.percentage}%` }"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Workforce Table -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white shadow-sm overflow-hidden dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="border-b border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/50"
        >
          <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
            {{ t('REPORT.CLICK_TO_CALL.WORKFORCE_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500">
            {{ t('REPORT.CLICK_TO_CALL.WORKFORCE_SUB') }}
          </p>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs">
            <thead
              class="border-b border-slate-100 bg-slate-50/40 text-slate-500 dark:border-slate-800 dark:bg-slate-800/30"
            >
              <tr>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_AGENT') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_TOTAL') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_EFFECTIVE') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_EFFECTIVE_PCT') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_TMO') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_INEFFECTIVE') }}
                </th>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_DISPOSITIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
              <tr
                v-for="agent in reportsData.agent_workforce"
                :key="agent.id"
                class="hover:bg-slate-50/50 dark:hover:bg-slate-800/50 transition-colors"
              >
                <td class="px-4 py-3">
                  <div class="flex items-center gap-2.5">
                    <div
                      class="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100 font-bold text-blue-700 dark:bg-blue-950 dark:text-blue-300"
                    >
                      {{
                        agent.name ? agent.name.charAt(0).toUpperCase() : 'A'
                      }}
                    </div>
                    <div>
                      <span
                        class="font-semibold text-slate-800 dark:text-slate-100"
                        >{{ agent.name }}</span
                      >
                      <p class="text-[11px] text-slate-400">
                        {{ agent.email }}
                      </p>
                    </div>
                  </div>
                </td>
                <td
                  class="px-4 py-3 text-center font-bold text-slate-800 dark:text-slate-200"
                >
                  {{ agent.total_calls }}
                </td>
                <td
                  class="px-4 py-3 text-center font-bold text-emerald-600 dark:text-emerald-400"
                >
                  {{ agent.effective_calls }}
                </td>
                <td class="px-4 py-3 text-center">
                  <span
                    class="inline-flex items-center rounded-full px-2 py-0.5 font-bold"
                    :class="
                      agent.effective_percentage >= 50
                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                        : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'
                    "
                  >
                    {{ agent.effective_percentage }}%
                  </span>
                </td>
                <td
                  class="px-4 py-3 text-center font-mono font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ agent.tmo_formatted }}
                </td>
                <td class="px-4 py-3 text-center text-slate-500">
                  <span class="text-rose-600 font-semibold">{{
                    agent.ineffective_calls
                  }}</span>
                  /
                  <span class="text-amber-600">{{ agent.test_calls }}</span>
                </td>
                <td class="px-4 py-3">
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="(count, disp) in agent.dispositions"
                      :key="disp"
                      class="inline-flex items-center gap-1 rounded-md bg-slate-100 px-1.5 py-0.5 text-[10px] font-medium text-slate-600 dark:bg-slate-800 dark:text-slate-300"
                    >
                      {{ disp }}: <strong>{{ count }}</strong>
                    </span>
                    <span
                      v-if="Object.keys(agent.dispositions || {}).length === 0"
                      class="text-slate-400 text-[11px]"
                    >
                      -
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Recent Calls & Recordings -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white shadow-sm overflow-hidden dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="border-b border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/50"
        >
          <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
            {{ t('REPORT.CLICK_TO_CALL.RECORDINGS_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500">
            {{ t('REPORT.CLICK_TO_CALL.RECORDINGS_SUB') }}
          </p>
        </div>

        <div
          v-if="reportsData.recent_calls.length === 0"
          class="py-12 text-center text-xs text-slate-400"
        >
          {{ t('REPORT.CLICK_TO_CALL.NO_RECORDINGS') }}
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-left text-xs">
            <thead
              class="border-b border-slate-100 bg-slate-50/40 text-slate-500 dark:border-slate-800 dark:bg-slate-800/30"
            >
              <tr>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_DATETIME') }}
                </th>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_AGENT') }}
                </th>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_PHONE') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_DURATION') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_CATEGORY') }}
                </th>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_DISPOSITION') }}
                </th>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.CLICK_TO_CALL.TABLE_PLAYER') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
              <tr
                v-for="call in reportsData.recent_calls"
                :key="call.id"
                class="hover:bg-slate-50/50 dark:hover:bg-slate-800/50 transition-colors"
              >
                <td
                  class="px-4 py-3 text-slate-600 dark:text-slate-400 whitespace-nowrap"
                >
                  {{ call.created_at }}
                </td>
                <td
                  class="px-4 py-3 font-medium text-slate-800 dark:text-slate-200"
                >
                  {{ call.agent_name }}
                </td>
                <td
                  class="px-4 py-3 font-mono text-slate-700 dark:text-slate-300"
                >
                  {{ call.phone_number }}
                </td>
                <td
                  class="px-4 py-3 text-center font-mono font-semibold text-slate-800 dark:text-slate-200"
                >
                  {{ call.duration_formatted }}
                </td>
                <td class="px-4 py-3 text-center">
                  <span
                    v-if="call.call_category === 'effective'"
                    class="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
                  >
                    {{ t('REPORT.CLICK_TO_CALL.BADGE_EFFECTIVE') }}
                  </span>
                  <span
                    v-else-if="call.call_category === 'test'"
                    class="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-800 dark:bg-amber-950 dark:text-amber-300"
                  >
                    {{ t('REPORT.CLICK_TO_CALL.BADGE_TEST') }}
                  </span>
                  <span
                    v-else
                    class="inline-flex items-center gap-1 rounded-full bg-rose-100 px-2 py-0.5 text-[10px] font-bold text-rose-800 dark:bg-rose-950 dark:text-rose-300"
                  >
                    {{ t('REPORT.CLICK_TO_CALL.BADGE_INEFFECTIVE') }}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <span
                    class="inline-flex rounded-lg px-2 py-0.5 text-[11px] font-medium"
                    :class="
                      call.disposition !== 'Sin tipificar'
                        ? 'bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300'
                        : 'text-slate-400'
                    "
                  >
                    {{ call.disposition }}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <audio
                    v-if="
                      call.recording_url &&
                      (call.call_category === 'effective' ||
                        call.call_category === 'test')
                    "
                    controls
                    preload="none"
                    class="h-8 max-w-[220px] rounded-lg"
                  >
                    <source :src="call.recording_url" type="audio/wav" />
                  </audio>
                  <span v-else class="text-slate-400 text-[11px] italic">
                    {{ t('REPORT.CLICK_TO_CALL.NO_RECORDING') }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
