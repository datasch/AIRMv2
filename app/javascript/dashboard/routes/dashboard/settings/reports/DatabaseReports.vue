<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import VoipAPI from 'dashboard/api/voip';
import ReportHeader from './components/ReportHeader.vue';

const { t } = useI18n();

const isLoading = ref(true);
const selectedRange = ref('month');

const reportData = ref({
  summary: {
    total_outbound: 0,
    total_incoming: 0,
    total_prospects_contacted: 0,
    total_prospects_replied: 0,
    response_rate: 0,
    total_resolutions: 0,
    multi_turn_conversations: 0,
    avg_turns: 1.0,
    max_turns: 1,
    range_type: 'month',
  },
  turns_distribution: {
    '1_vuelta': 0,
    '2_vueltas': 0,
    '3_vueltas': 0,
    '4_mas_vueltas': 0,
  },
  time_series: [],
});

const ranges = computed(() => [
  { value: 'hour', label: t('REPORT.DATE_RANGE.LAST_24_HOURS') || '24h' },
  { value: 'day', label: t('REPORT.DATE_RANGE.LAST_7_DAYS') || '7d' },
  { value: 'week', label: t('REPORT.DATE_RANGE.LAST_30_DAYS') || '30d' },
  { value: 'month', label: t('REPORT.DATE_RANGE.LAST_3_MONTHS') || 'Meses' },
  { value: 'year', label: t('REPORT.DATE_RANGE.LAST_YEAR') || 'Años' },
]);

const fetchDatabaseReport = async () => {
  try {
    isLoading.value = true;
    const response = await VoipAPI.getDatabaseReports({
      range: selectedRange.value,
    });
    reportData.value = response.data;
  } catch {
    // Handled in UI
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchDatabaseReport();
});

const getTurnPercentage = count => {
  const total =
    (reportData.value.turns_distribution['1_vuelta'] || 0) +
    (reportData.value.turns_distribution['2_vueltas'] || 0) +
    (reportData.value.turns_distribution['3_vueltas'] || 0) +
    (reportData.value.turns_distribution['4_mas_vueltas'] || 0);
  if (!total) return 0;
  return Math.round((count / total) * 100);
};
</script>

<template>
  <div class="space-y-6 pb-12">
    <ReportHeader
      :header-title="t('REPORT.DATABASE.TITLE')"
      :header-description="t('REPORT.DATABASE.DESCRIPTION')"
    >
      <div class="flex items-center gap-2">
        <select
          v-model="selectedRange"
          class="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm focus:border-blue-500 focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200"
          @change="fetchDatabaseReport"
        >
          <option v-for="r in ranges" :key="r.value" :value="r.value">
            {{ r.label }}
          </option>
        </select>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
          :disabled="isLoading"
          @click="fetchDatabaseReport"
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
      <!-- Top Metrics Grid -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <!-- Outbound Messages -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.DATABASE.OUTBOUND_MESSAGES') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-blue-50 text-blue-600 dark:bg-blue-950 dark:text-blue-400"
            >
              <i class="i-lucide-send text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-slate-800 dark:text-slate-100">
              {{ reportData.summary.total_outbound }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{
              t('REPORT.DATABASE.OUTBOUND_SUB', {
                count: reportData.summary.total_prospects_contacted,
              })
            }}
          </p>
        </div>

        <!-- Replies & Conversion Rate -->
        <div
          class="rounded-2xl border border-emerald-200/80 bg-emerald-50/40 p-4 shadow-sm dark:border-emerald-900/50 dark:bg-emerald-950/20"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold text-emerald-800 dark:text-emerald-300"
            >
              {{ t('REPORT.DATABASE.RESPONSE_RATE') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300"
            >
              <i class="i-lucide-message-square-text text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-2xl font-bold text-emerald-700 dark:text-emerald-300"
            >
              {{ reportData.summary.response_rate }}%
            </span>
          </div>
          <p
            class="mt-1 text-[11px] text-emerald-600/80 dark:text-emerald-400/80"
          >
            {{
              t('REPORT.DATABASE.RESPONSE_SUB', {
                count: reportData.summary.total_prospects_replied,
              })
            }}
          </p>
        </div>

        <!-- Resolutions / Closed Tickets -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.DATABASE.RESOLUTIONS') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-purple-50 text-purple-600 dark:bg-purple-950 dark:text-purple-400"
            >
              <i class="i-lucide-check-circle-2 text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span
              class="text-2xl font-bold text-purple-700 dark:text-purple-300"
            >
              {{ reportData.summary.total_resolutions }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{ t('REPORT.DATABASE.RESOLUTIONS_SUB') }}
          </p>
        </div>

        <!-- Database Turns / Recycling -->
        <div
          class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ t('REPORT.DATABASE.AVG_TURNS') }}
            </span>
            <div
              class="flex h-8 w-8 items-center justify-center rounded-xl bg-amber-50 text-amber-600 dark:bg-amber-950 dark:text-amber-400"
            >
              <i class="i-lucide-repeat text-base" />
            </div>
          </div>
          <div class="mt-3 flex items-baseline gap-2">
            <span class="text-2xl font-bold text-amber-600 dark:text-amber-400">
              {{ reportData.summary.avg_turns }}
            </span>
          </div>
          <p class="mt-1 text-[11px] text-slate-400">
            {{
              t('REPORT.DATABASE.AVG_TURNS_SUB', {
                count: reportData.summary.multi_turn_conversations,
              })
            }}
          </p>
        </div>
      </div>

      <!-- Vueltas de la Base de Datos -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
              {{ t('REPORT.DATABASE.TURNS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500">
              {{ t('REPORT.DATABASE.TURNS_SUB') }}
            </p>
          </div>
          <span
            class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700 dark:bg-slate-800 dark:text-slate-300"
          >
            {{
              t('REPORT.DATABASE.MAX_RECORDED', {
                count: reportData.summary.max_turns,
              })
            }}
          </span>
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 pt-2">
          <!-- 1 Vuelta -->
          <div
            class="rounded-xl border border-slate-100 bg-slate-50/60 p-4 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ t('REPORT.DATABASE.TURN_1') }}
              </span>
              <span class="text-sm font-bold text-blue-600 dark:text-blue-400">
                {{ reportData.turns_distribution['1_vuelta'] }}
              </span>
            </div>
            <p class="text-[11px] text-slate-400 mt-1">
              {{ t('REPORT.DATABASE.TURN_1_SUB') }}
            </p>
            <div
              class="mt-3 h-2 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
            >
              <div
                class="h-full bg-blue-500 rounded-full"
                :style="{
                  width: `${getTurnPercentage(reportData.turns_distribution['1_vuelta'])}%`,
                }"
              />
            </div>
          </div>

          <!-- 2 Vueltas -->
          <div
            class="rounded-xl border border-slate-100 bg-slate-50/60 p-4 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ t('REPORT.DATABASE.TURN_2') }}
              </span>
              <span
                class="text-sm font-bold text-emerald-600 dark:text-emerald-400"
              >
                {{ reportData.turns_distribution['2_vueltas'] }}
              </span>
            </div>
            <p class="text-[11px] text-slate-400 mt-1">
              {{ t('REPORT.DATABASE.TURN_2_SUB') }}
            </p>
            <div
              class="mt-3 h-2 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
            >
              <div
                class="h-full bg-emerald-500 rounded-full"
                :style="{
                  width: `${getTurnPercentage(reportData.turns_distribution['2_vueltas'])}%`,
                }"
              />
            </div>
          </div>

          <!-- 3 Vueltas -->
          <div
            class="rounded-xl border border-slate-100 bg-slate-50/60 p-4 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ t('REPORT.DATABASE.TURN_3') }}
              </span>
              <span
                class="text-sm font-bold text-amber-600 dark:text-amber-400"
              >
                {{ reportData.turns_distribution['3_vueltas'] }}
              </span>
            </div>
            <p class="text-[11px] text-slate-400 mt-1">
              {{ t('REPORT.DATABASE.TURN_3_SUB') }}
            </p>
            <div
              class="mt-3 h-2 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
            >
              <div
                class="h-full bg-amber-500 rounded-full"
                :style="{
                  width: `${getTurnPercentage(reportData.turns_distribution['3_vueltas'])}%`,
                }"
              />
            </div>
          </div>

          <!-- 4+ Vueltas -->
          <div
            class="rounded-xl border border-slate-100 bg-slate-50/60 p-4 dark:border-slate-800 dark:bg-slate-800/40"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-xs font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ t('REPORT.DATABASE.TURN_4_PLUS') }}
              </span>
              <span
                class="text-sm font-bold text-purple-600 dark:text-purple-400"
              >
                {{ reportData.turns_distribution['4_mas_vueltas'] }}
              </span>
            </div>
            <p class="text-[11px] text-slate-400 mt-1">
              {{ t('REPORT.DATABASE.TURN_4_PLUS_SUB') }}
            </p>
            <div
              class="mt-3 h-2 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700"
            >
              <div
                class="h-full bg-purple-500 rounded-full"
                :style="{
                  width: `${getTurnPercentage(reportData.turns_distribution['4_mas_vueltas'])}%`,
                }"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Time Series Table -->
      <div
        class="rounded-2xl border border-slate-200/80 bg-white shadow-sm overflow-hidden dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="border-b border-slate-100 bg-slate-50/70 p-4 dark:border-slate-800 dark:bg-slate-800/50"
        >
          <h3 class="text-sm font-bold text-slate-800 dark:text-slate-100">
            {{ t('REPORT.DATABASE.CHRONOLOGICAL_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500">
            {{ t('REPORT.DATABASE.CHRONOLOGICAL_SUB') }}
          </p>
        </div>

        <div
          v-if="reportData.time_series.length === 0"
          class="py-12 text-center text-xs text-slate-400"
        >
          {{ t('REPORT.DATABASE.NO_ACTIVITY') }}
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-left text-xs">
            <thead
              class="border-b border-slate-100 bg-slate-50/40 text-slate-500 dark:border-slate-800 dark:bg-slate-800/30"
            >
              <tr>
                <th class="px-4 py-3 font-semibold">
                  {{ t('REPORT.DATABASE.TABLE_PERIOD') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.DATABASE.TABLE_OUTBOUND') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.DATABASE.TABLE_INCOMING') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.DATABASE.TABLE_RESOLUTIONS') }}
                </th>
                <th class="px-4 py-3 font-semibold text-center">
                  {{ t('REPORT.DATABASE.TABLE_RATIO') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
              <tr
                v-for="row in reportData.time_series"
                :key="row.timestamp"
                class="hover:bg-slate-50/50 dark:hover:bg-slate-800/50 transition-colors"
              >
                <td
                  class="px-4 py-3 font-medium text-slate-800 dark:text-slate-200 whitespace-nowrap"
                >
                  {{ row.timestamp }}
                </td>
                <td
                  class="px-4 py-3 text-center font-bold text-blue-600 dark:text-blue-400"
                >
                  {{ row.outbound }}
                </td>
                <td
                  class="px-4 py-3 text-center font-bold text-emerald-600 dark:text-emerald-400"
                >
                  {{ row.incoming }}
                </td>
                <td
                  class="px-4 py-3 text-center font-medium text-purple-600 dark:text-purple-400"
                >
                  {{ row.resolutions }}
                </td>
                <td class="px-4 py-3 text-center font-bold">
                  <span
                    class="inline-flex rounded-full px-2 py-0.5 text-[11px]"
                    :class="
                      row.outbound > 0 && row.incoming / row.outbound >= 0.2
                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                        : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'
                    "
                  >
                    {{
                      row.outbound > 0
                        ? Math.round((row.incoming / row.outbound) * 100)
                        : 0
                    }}%
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
