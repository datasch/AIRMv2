<script setup>
import { computed, onMounted, ref } from 'vue';
import format from 'date-fns/format';
import parseISO from 'date-fns/parseISO';
import BarChart from 'shared/components/charts/BarChart.vue';

const stats = ref(null);
const failed = ref(false);

const loading = computed(() => !stats.value && !failed.value);

const pageTitle = 'Panel de Super Admin AIRM';
const pageSubtitle =
  'Métricas globales, gestión de empresas y supervisión del motor de inteligencia artificial.';
const systemStatus = 'Sistema Operativo 24/7';
const chartTitle = 'Volumen de Conversaciones';
const chartSubtitle =
  'Flujo diario de mensajes recibidos y procesados por agentes humanos e IA.';

onMounted(async () => {
  try {
    const response = await fetch(window.location.pathname, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    stats.value = await response.json();
  } catch {
    failed.value = true;
  }
});

const metrics = computed(() => [
  { label: 'Organizaciones / Cuentas', value: stats.value?.accountsCount },
  { label: 'Usuarios Registrados', value: stats.value?.usersCount },
  { label: 'Bandejas de Entrada', value: stats.value?.inboxesCount },
  { label: 'Conversaciones Totales', value: stats.value?.conversationsCount },
]);

const chartAriaLabel = 'Conversaciones creadas por día';

const chartData = computed(() => {
  const sourceData = stats.value?.chartData || [];
  return {
    categories: sourceData.map(([label]) => format(parseISO(label), 'dd-MMM')),
    series: [
      {
        id: 'conversations',
        label: 'Conversaciones',
        color: '#38bdf8',
        data: sourceData.map(([, value]) => value),
      },
    ],
  };
});
</script>

<template>
  <div class="w-full h-full p-6 lg:p-8 space-y-6">
    <!-- Header with AIRM Branding -->
    <div
      class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-4 border-b border-slate-200 dark:border-slate-800"
    >
      <div>
        <h1
          id="page-title"
          class="text-2xl font-bold tracking-tight text-slate-900 dark:text-white"
        >
          {{ pageTitle }}
        </h1>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
          {{ pageSubtitle }}
        </p>
      </div>
      <div
        class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-100 dark:bg-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700 w-fit"
      >
        <span class="size-2 rounded-full bg-emerald-500 animate-pulse" />
        {{ systemStatus }}
      </div>
    </div>

    <!-- Metric Cards Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div
        v-for="item in metrics"
        :key="item.label"
        class="p-5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#14161f] shadow-sm hover:border-slate-300 dark:hover:border-slate-700 transition-all duration-200 flex flex-col justify-between"
      >
        <div
          class="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400"
        >
          {{ item.label }}
        </div>
        <div
          class="mt-3 text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight"
        >
          <span
            v-if="loading"
            class="inline-block w-20 h-8 rounded bg-slate-200 dark:bg-slate-800 animate-pulse"
          />
          <template v-else>{{ item.value || '0' }}</template>
        </div>
      </div>
    </div>

    <!-- Chart Card -->
    <div
      class="p-6 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#14161f] shadow-sm"
    >
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-base font-bold text-slate-900 dark:text-white">
            {{ chartTitle }}
          </h2>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ chartSubtitle }}
          </p>
        </div>
      </div>

      <div
        v-if="loading"
        class="h-72 rounded-xl bg-slate-100 dark:bg-slate-800 animate-pulse"
      />
      <div v-else-if="!failed" class="w-full min-w-0">
        <BarChart
          :data="chartData"
          :height="360"
          timeseries
          :aria-label="chartAriaLabel"
        />
      </div>
    </div>
  </div>
</template>
