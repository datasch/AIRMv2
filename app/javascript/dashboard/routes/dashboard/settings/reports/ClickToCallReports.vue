<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import VoipAPI from 'dashboard/api/voip';
import BarChart from 'shared/components/charts/BarChart.vue';
import { PercentageChart } from '@chatwoot/viz';
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
  reporting_timezone: 'America/Lima',
  calls_by_day: [],
  calls_by_hour: [],
  dispositions_summary: [],
  agent_workforce: [],
  recent_calls: [],
});

const periods = computed(() => [
  { value: '1', label: t('REPORT.DATE_RANGE_OPTIONS.TODAY') },
  { value: '7', label: t('REPORT.DATE_RANGE_OPTIONS.LAST_7_DAYS') },
  { value: '30', label: t('REPORT.DATE_RANGE_OPTIONS.LAST_30_DAYS') },
  { value: '90', label: t('REPORT.DATE_RANGE_OPTIONS.LAST_3_MONTHS') },
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

// Chart: Calls by day (Stacked / Dual Bar)
const dailyChartData = computed(() => {
  const days = reportsData.value.calls_by_day || [];
  if (!days.length) return { categories: [], series: [] };

  return {
    categories: days.map(d => {
      try {
        const parts = d.date.split('-');
        if (parts.length === 3) {
          const dateObj = new Date(
            parseInt(parts[0], 10),
            parseInt(parts[1], 10) - 1,
            parseInt(parts[2], 10)
          );
          return dateObj.toLocaleDateString('es-PE', {
            day: '2-digit',
            month: 'short',
          });
        }
        return d.date;
      } catch {
        return d.date;
      }
    }),
    series: [
      {
        id: 'effective',
        label: t('REPORT.CLICK_TO_CALL.CHART_EFFECTIVE'),
        color: '#10b981',
        data: days.map(d => d.effective),
      },
      {
        id: 'ineffective',
        label: t('REPORT.CLICK_TO_CALL.CHART_INEFFECTIVE'),
        color: '#f43f5e',
        data: days.map(
          d => d.ineffective ?? Math.max(0, d.total - d.effective)
        ),
      },
    ],
  };
});

// Chart: Hourly distribution in Lima time (00:00 - 23:00)
const hourlyChartData = computed(() => {
  const hours = reportsData.value.calls_by_hour || [];
  if (!hours.length) return { categories: [], series: [] };

  return {
    categories: hours.map(h => h.hour),
    series: [
      {
        id: 'calls',
        label: t('REPORT.CLICK_TO_CALL.TOTAL_CALLS'),
        color: '#3b82f6',
        data: hours.map(h => h.count),
      },
    ],
  };
});

// Hourly axis label formatter (Show clean intervals)
const formatHourlyCategoryLabel = cat => {
  if (typeof cat !== 'string') return '';
  const hourNum = parseInt(cat, 10);
  return hourNum % 3 === 0 ? cat : '';
};

// Peak hour in Lima time
const peakHour = computed(() => {
  const hours = reportsData.value.calls_by_hour || [];
  if (!hours.length) return null;
  const max = hours.reduce(
    (acc, curr) => (curr.count > (acc?.count || 0) ? curr : acc),
    null
  );
  return max && max.count > 0 ? max : null;
});

// Semantic colors for dispositions
const dispositionColorMap = {
  Venta: '#10b981',
  Interesado: '#06b6d4',
  Agendado: '#3b82f6',
  'Volver a llamar': '#f59e0b',
  Saturación: '#eab308',
  'No interesado': '#f43f5e',
  'No contesta': '#ec4899',
  'Buzón de voz': '#8b5cf6',
  'Llamada cancelada': '#64748b',
  'Número equivocado': '#94a3b8',
};

const paletteFallback = [
  '#10b981',
  '#3b82f6',
  '#06b6d4',
  '#f59e0b',
  '#8b5cf6',
  '#ec4899',
  '#f43f5e',
  '#64748b',
];

const getDispositionColor = (disp, index = 0) => {
  return (
    dispositionColorMap[disp] || paletteFallback[index % paletteFallback.length]
  );
};

const totalDispositionsCount = computed(() => {
  const summary = reportsData.value.dispositions_summary || [];
  return summary.reduce((acc, item) => acc + item.count, 0);
});

const dispositionsChartData = computed(() => {
  const summary = reportsData.value.dispositions_summary || [];
  return {
    total: totalDispositionsCount.value,
    segments: summary.map((item, idx) => ({
      id: item.disposition,
      label: item.disposition,
      value: item.count,
      color: getDispositionColor(item.disposition, idx),
    })),
  };
});

const getAgentInitial = agent => {
  if (agent?.name && typeof agent.name === 'string') {
    return agent.name.trim().charAt(0).toUpperCase();
  }
  return 'A';
};
</script>

<template>
  <div class="space-y-6 pb-12">
    <!-- Header with Lima Timezone Indicator and Period Selector -->
    <ReportHeader
      :header-title="t('REPORT.CLICK_TO_CALL.TITLE')"
      :header-description="t('REPORT.CLICK_TO_CALL.DESCRIPTION')"
    >
      <div class="flex flex-wrap items-center gap-2">
        <div
          class="hidden sm:inline-flex items-center gap-1.5 rounded-xl border border-slate-200/80 bg-slate-50 px-3 py-1.5 text-xs font-medium text-slate-600 dark:border-slate-800 dark:bg-slate-800/80 dark:text-slate-300"
        >
          <i class="i-lucide-clock text-xs text-blue-500" />
          <span>{{ t('REPORT.CLICK_TO_CALL.TIMEZONE_NOTE') }}</span>
        </div>

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
          class="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700 cursor-pointer"
          :disabled="isLoading"
          @click="fetchReports"
        >
          <i
            class="i-lucide-refresh-cw text-xs"
            :class="{ 'animate-spin': isLoading }"
          />
          <span>{{ t('REPORT.REFRESH') }}</span>
        </button>
      </div>
    </ReportHeader>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex h-72 items-center justify-center">
      <div class="flex flex-col items-center gap-3">
        <i class="i-lucide-loader-2 text-3xl text-blue-600 animate-spin" />
        <span class="text-xs font-medium text-slate-500">{{
          t('REPORT.LOADING_CHART')
        }}</span>
      </div>
    </div>

    <!-- Main Content -->
    <div v-else class="space-y-6">
      <!-- KPI Metric Cards Grid -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <!-- 1. Total Calls -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.TOTAL_CALLS') }}
            </span>
            <div
              class="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-50 text-blue-600 dark:bg-blue-950/60 dark:text-blue-400"
            >
              <i class="i-lucide-phone-call text-lg" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-3xl font-extrabold tracking-tight text-slate-900 dark:text-slate-100"
            >
              {{ reportsData.metrics.total_calls }}
            </span>
          </div>
          <p class="mt-1.5 text-xs text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.TOTAL_CALLS_SUB') }}
          </p>
        </div>

        <!-- 2. Effective Calls -->
        <div
          class="rounded-2xl border border-emerald-200/90 bg-emerald-50/40 p-5 shadow-sm dark:border-emerald-900/50 dark:bg-emerald-950/20"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold uppercase tracking-wider text-emerald-800 dark:text-emerald-300"
            >
              {{ t('REPORT.CLICK_TO_CALL.EFFECTIVE_CALLS') }}
            </span>
            <div
              class="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700 dark:bg-emerald-900/80 dark:text-emerald-300"
            >
              <i class="i-lucide-check-check text-lg" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2.5">
            <span
              class="text-3xl font-extrabold tracking-tight text-emerald-700 dark:text-emerald-300"
            >
              {{ reportsData.metrics.effective_calls }}
            </span>
            <span
              class="inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-bold text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200"
            >
              {{ `${reportsData.metrics.effective_percentage}%` }}
            </span>
          </div>
          <p
            class="mt-1.5 text-xs text-emerald-700/80 dark:text-emerald-400/80"
          >
            {{ t('REPORT.CLICK_TO_CALL.EFFECTIVE_CALLS_SUB') }}
          </p>
        </div>

        <!-- 3. Ineffective / Test Calls -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.INEFFECTIVE_CALLS') }}
            </span>
            <div
              class="flex h-9 w-9 items-center justify-center rounded-xl bg-rose-50 text-rose-600 dark:bg-rose-950/60 dark:text-rose-400"
            >
              <i class="i-lucide-phone-missed text-lg" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2.5">
            <span
              class="text-3xl font-extrabold tracking-tight text-rose-600 dark:text-rose-400"
            >
              {{ reportsData.metrics.ineffective_calls }}
            </span>
            <span
              v-if="reportsData.metrics.test_calls > 0"
              class="inline-flex items-center rounded-full bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:bg-amber-950/50 dark:text-amber-300"
            >
              {{
                t('REPORT.CLICK_TO_CALL.TEST_CALLS_COUNT', {
                  count: reportsData.metrics.test_calls,
                })
              }}
            </span>
          </div>
          <p class="mt-1.5 text-xs text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.INEFFECTIVE_CALLS_SUB') }}
          </p>
        </div>

        <!-- 4. Average Handling Time (TMO) -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.TMO') }}
            </span>
            <div
              class="flex h-9 w-9 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600 dark:bg-indigo-950/60 dark:text-indigo-400"
            >
              <i class="i-lucide-clock text-lg" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-3xl font-extrabold font-mono tracking-tight text-slate-900 dark:text-slate-100"
            >
              {{ reportsData.metrics.tmo_formatted }}
            </span>
            <span class="text-xs text-slate-400">
              {{ t('REPORT.CLICK_TO_CALL.TMO_UNIT') }}
            </span>
          </div>
          <p class="mt-1.5 text-xs text-slate-400">
            {{ t('REPORT.CLICK_TO_CALL.TMO_SUB') }}
          </p>
        </div>
      </div>

      <!-- Charts Section: Daily Trend & Hourly Distribution -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- 1. Interactive Calls by Day Chart -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900 flex flex-col justify-between"
        >
          <div>
            <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
              <div>
                <h3
                  class="text-sm font-bold text-slate-900 dark:text-slate-100"
                >
                  {{ t('REPORT.CLICK_TO_CALL.CALLS_BY_DAY') }}
                </h3>
                <p class="text-xs text-slate-500 mt-0.5">
                  {{ t('REPORT.CLICK_TO_CALL.CALLS_BY_DAY_SUB') }}
                </p>
              </div>

              <!-- Legend badges -->
              <div class="flex items-center gap-3 text-xs">
                <span class="inline-flex items-center gap-1.5">
                  <span class="h-2.5 w-2.5 rounded-full bg-emerald-500" />
                  <span class="text-slate-600 dark:text-slate-300 font-medium">
                    {{ t('REPORT.CLICK_TO_CALL.CHART_EFFECTIVE') }}
                  </span>
                </span>
                <span class="inline-flex items-center gap-1.5">
                  <span class="h-2.5 w-2.5 rounded-full bg-rose-500" />
                  <span class="text-slate-600 dark:text-slate-300 font-medium">
                    {{ t('REPORT.CLICK_TO_CALL.CHART_INEFFECTIVE') }}
                  </span>
                </span>
              </div>
            </div>

            <!-- Empty state -->
            <div
              v-if="reportsData.calls_by_day.length === 0"
              class="flex h-64 items-center justify-center text-xs text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.NO_DATA') }}
            </div>

            <!-- Viz BarChart -->
            <div v-else class="h-64 pt-2">
              <BarChart
                :data="dailyChartData"
                stacked
                :height="240"
                :aria-label="t('REPORT.CLICK_TO_CALL.CALLS_BY_DAY')"
              />
            </div>
          </div>
        </div>

        <!-- 2. Hourly Distribution (Hora Lima, 00:00 - 23:00) Chart -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900 flex flex-col justify-between"
        >
          <div>
            <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
              <div>
                <h3
                  class="text-sm font-bold text-slate-900 dark:text-slate-100"
                >
                  {{ t('REPORT.CLICK_TO_CALL.HOURLY_DISTRIBUTION') }}
                </h3>
                <p class="text-xs text-slate-500 mt-0.5">
                  {{ t('REPORT.CLICK_TO_CALL.HOURLY_DISTRIBUTION_SUB') }}
                </p>
              </div>

              <!-- Peak Hour Pill -->
              <div
                v-if="peakHour"
                class="inline-flex items-center gap-1.5 rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700 dark:bg-blue-950/60 dark:text-blue-300"
              >
                <i class="i-lucide-flame text-xs text-amber-500" />
                <span>{{ t('REPORT.CLICK_TO_CALL.PEAK_HOUR') }}</span>
                <strong class="font-bold">{{ peakHour.hour }}</strong>
                <span class="text-blue-500">{{ `(${peakHour.count})` }}</span>
              </div>
            </div>

            <!-- Empty State -->
            <div
              v-if="reportsData.metrics.total_calls === 0"
              class="flex h-64 items-center justify-center text-xs text-slate-400"
            >
              {{ t('REPORT.CLICK_TO_CALL.NO_DATA_HOURLY') }}
            </div>

            <!-- Viz BarChart for 24 hours -->
            <div v-else class="h-64 pt-2">
              <BarChart
                :data="hourlyChartData"
                :height="240"
                :category-label="formatHourlyCategoryLabel"
                :aria-label="t('REPORT.CLICK_TO_CALL.HOURLY_DISTRIBUTION')"
              />
            </div>
          </div>

          <div
            class="mt-3 flex items-center justify-end text-[11px] text-slate-400"
          >
            <i class="i-lucide-clock text-xs text-blue-500 mr-1" />
            <span>{{ t('REPORT.CLICK_TO_CALL.TIMEZONE_NOTE') }}</span>
          </div>
        </div>
      </div>

      <!-- Dispositions (Tipificación) Breakdown -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
          <div>
            <h3 class="text-sm font-bold text-slate-900 dark:text-slate-100">
              {{ t('REPORT.CLICK_TO_CALL.DISPOSITIONS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500 mt-0.5">
              {{ t('REPORT.CLICK_TO_CALL.DISPOSITIONS_SUB') }}
            </p>
          </div>

          <span
            v-if="totalDispositionsCount > 0"
            class="text-xs font-medium text-slate-500"
          >
            {{
              t('REPORT.CLICK_TO_CALL.CALLS_COUNT', {
                count: totalDispositionsCount,
              })
            }}
          </span>
        </div>

        <!-- Empty state -->
        <div
          v-if="reportsData.dispositions_summary.length === 0"
          class="py-8 text-center text-xs text-slate-400"
        >
          {{ t('REPORT.CLICK_TO_CALL.NO_DISPOSITIONS') }}
        </div>

        <div v-else class="space-y-6">
          <!-- Visual Percentage Segmented Bar -->
          <div
            class="rounded-xl border border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <PercentageChart
              :data="dispositionsChartData"
              :aria-label="t('REPORT.CLICK_TO_CALL.DISPOSITIONS_TITLE')"
            >
              <template
                #legend-item="{ label, formattedPercentage, formattedValue }"
              >
                <span
                  class="text-xs font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ label }}
                </span>
                <span
                  class="text-xs font-bold text-slate-900 dark:text-slate-100"
                >
                  {{ formattedPercentage }}
                </span>
                <span class="text-[11px] text-slate-400">
                  {{ `(${formattedValue})` }}
                </span>
              </template>
            </PercentageChart>
          </div>

          <!-- Cards Grid for each Disposition -->
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div
              v-for="(item, idx) in reportsData.dispositions_summary"
              :key="item.disposition"
              class="rounded-xl border border-slate-100 bg-slate-50/60 p-3.5 dark:border-slate-800 dark:bg-slate-800/40 transition-shadow hover:shadow-sm"
            >
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span
                    class="h-2.5 w-2.5 rounded-full"
                    :style="{
                      backgroundColor: getDispositionColor(
                        item.disposition,
                        idx
                      ),
                    }"
                  />
                  <span
                    class="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate max-w-[180px]"
                  >
                    {{ item.disposition }}
                  </span>
                </div>
                <span
                  class="text-xs font-bold text-slate-900 dark:text-slate-100"
                >
                  {{ item.count }}
                  <span class="text-slate-400 font-normal">
                    {{ `(${item.percentage}%)` }}
                  </span>
                </span>
              </div>
              <div
                class="mt-2.5 h-1.5 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
              >
                <div
                  class="h-full rounded-full transition-all duration-500"
                  :style="{
                    width: `${item.percentage}%`,
                    backgroundColor: getDispositionColor(item.disposition, idx),
                  }"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Agent Workforce Productivity Table -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white shadow-sm overflow-hidden dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="border-b border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/50"
        >
          <h3 class="text-sm font-bold text-slate-900 dark:text-slate-100">
            {{ t('REPORT.CLICK_TO_CALL.WORKFORCE_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500 mt-0.5">
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
                      {{ getAgentInitial(agent) }}
                    </div>
                    <div>
                      <span
                        class="font-semibold text-slate-900 dark:text-slate-100"
                      >
                        {{ agent.name }}
                      </span>
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
                    class="inline-flex items-center rounded-full px-2.5 py-0.5 font-bold"
                    :class="
                      agent.effective_percentage >= 30
                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                        : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'
                    "
                  >
                    {{ `${agent.effective_percentage}%` }}
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
                  <span class="mx-1">{{
                    t('REPORT.CLICK_TO_CALL.RATIO_SEPARATOR')
                  }}</span>
                  <span class="text-amber-600">{{ agent.test_calls }}</span>
                </td>
                <td class="px-4 py-3">
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="(count, disp) in agent.dispositions"
                      :key="disp"
                      class="inline-flex items-center gap-1 rounded-md bg-slate-100 px-1.5 py-0.5 text-[10px] font-medium text-slate-600 dark:bg-slate-800 dark:text-slate-300"
                    >
                      <span>{{ `${disp}: ` }}</span>
                      <strong>{{ count }}</strong>
                    </span>
                    <span
                      v-if="Object.keys(agent.dispositions || {}).length === 0"
                      class="text-slate-400 text-[11px]"
                    >
                      {{ t('REPORT.CLICK_TO_CALL.EMPTY_VALUE') }}
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Recent Calls & Audio Recordings Table -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white shadow-sm overflow-hidden dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="border-b border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/50"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 class="text-sm font-bold text-slate-900 dark:text-slate-100">
                {{ t('REPORT.CLICK_TO_CALL.RECORDINGS_TITLE') }}
              </h3>
              <p class="text-xs text-slate-500 mt-0.5">
                {{ t('REPORT.CLICK_TO_CALL.RECORDINGS_SUB') }}
              </p>
            </div>
            <span
              class="inline-flex items-center gap-1 text-[11px] font-medium text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 px-2.5 py-1 rounded-lg"
            >
              <i class="i-lucide-clock text-xs text-blue-500" />
              <span>{{ t('REPORT.CLICK_TO_CALL.TIMEZONE_NOTE') }}</span>
            </span>
          </div>
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
                  class="px-4 py-3 font-mono text-slate-600 dark:text-slate-300 whitespace-nowrap"
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
