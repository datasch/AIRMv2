<script setup>
import { ref, onMounted, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import CoverageAPI from 'dashboard/api/coverage';

const { t } = useI18n();

// Estado general
const activeTab = ref('map'); // 'map' | 'metrics'
const isLoading = ref(true);
const isSyncing = ref(false);
const syncFeedback = ref('');

// Datos del backend
const summary = ref({
  total: 0,
  contactados: 0,
  pendientes: 0,
  enviando: 0,
  sin_whatsapp: 0,
  tasa_contacto: 0,
  total_departamentos: 0,
  total_ciudades: 0,
  last_synced_at: '',
});

const leads = ref([]);
const regionsDistribution = ref([]);
const sectorsDistribution = ref([]);
const timeline = ref([]);
const agentsMetrics = ref([]);
const filterOptions = ref({
  regions: [],
  sectors: [],
  agents: [],
});

// Filtros interactivos
const searchQuery = ref('');
const selectedRegion = ref('ALL');
const selectedDistrict = ref('ALL');
const selectedSector = ref('ALL');
const selectedStatus = ref('ALL');
const selectedAgent = ref('ALL');
const dateStart = ref('');
const dateEnd = ref('');
const colorMode = ref('sector'); // 'sector' | 'status'

// Referencias DOM
const mapContainer = ref(null);
let leafletMap = null;
let markersLayer = null;
const markersMap = new Map();

// Gráficos Chart.js
let chartRegions = null;
let chartStatus = null;
let chartSectors = null;
let chartTimeline = null;

// Cargar librerías externas Leaflet y Chart.js de forma dinámica
const loadExternalAssets = async () => {
  const loadStyle = href => {
    if (document.querySelector(`link[href="${href}"]`))
      return Promise.resolve();
    return new Promise(resolve => {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = href;
      link.onload = resolve;
      document.head.appendChild(link);
    });
  };

  const loadScript = src => {
    if (document.querySelector(`script[src="${src}"]`))
      return Promise.resolve();
    return new Promise(resolve => {
      const script = document.createElement('script');
      script.src = src;
      script.onload = resolve;
      document.head.appendChild(script);
    });
  };

  await Promise.all([
    loadStyle('https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'),
    loadStyle(
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css'
    ),
    loadStyle(
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css'
    ),
  ]);

  if (!window.L) {
    await loadScript('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js');
  }
  if (!window.L?.markerClusterGroup) {
    await loadScript(
      'https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js'
    );
  }
  if (!window.Chart) {
    await loadScript(
      'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'
    );
  }
};

// Distritos calculados según la región seleccionada
const availableDistricts = computed(() => {
  const filtered =
    selectedRegion.value === 'ALL'
      ? leads.value
      : leads.value.filter(l => l.departamento === selectedRegion.value);
  const set = new Set(filtered.map(l => l.ciudad_distrito).filter(Boolean));
  return Array.from(set).sort();
});

// Leads filtrados en cliente (para búsqueda y filtros locales inmediatos)
const filteredLeads = computed(() => {
  const q = searchQuery.value.toLowerCase().trim();
  return leads.value.filter(item => {
    if (
      selectedRegion.value !== 'ALL' &&
      item.departamento !== selectedRegion.value
    )
      return false;
    if (
      selectedDistrict.value !== 'ALL' &&
      item.ciudad_distrito !== selectedDistrict.value
    )
      return false;
    if (
      selectedSector.value !== 'ALL' &&
      item.macro_sector !== selectedSector.value
    )
      return false;
    if (
      selectedStatus.value !== 'ALL' &&
      item.estado_clean !== selectedStatus.value
    )
      return false;
    if (selectedAgent.value !== 'ALL' && item.agente !== selectedAgent.value)
      return false;

    if (dateStart.value || dateEnd.value) {
      if (!item.fecha_dia) return false;
      if (dateStart.value && item.fecha_dia < dateStart.value) return false;
      if (dateEnd.value && item.fecha_dia > dateEnd.value) return false;
    }

    if (q) {
      const matchEmpresa = item.empresa.toLowerCase().includes(q);
      const matchContacto = (item.contacto_sugerido || '')
        .toLowerCase()
        .includes(q);
      const matchUbi = (item.ubicacion || '').toLowerCase().includes(q);
      const matchCiudad = (item.ciudad_distrito || '')
        .toLowerCase()
        .includes(q);
      const matchDpto = (item.departamento || '').toLowerCase().includes(q);
      const matchAgente = (item.agente || '').toLowerCase().includes(q);
      return (
        matchEmpresa ||
        matchContacto ||
        matchUbi ||
        matchCiudad ||
        matchDpto ||
        matchAgente
      );
    }

    return true;
  });
});

// Leyenda del mapa
const legendItems = computed(() => {
  if (colorMode.value === 'sector') {
    const map = new Map();
    filteredLeads.value.forEach(l => map.set(l.macro_sector, l.sector_color));
    return Array.from(map.entries()).map(([name, color]) => ({ name, color }));
  }
  return [
    { name: 'Contactado (Enviado)', color: '#27ae60' },
    { name: 'Por Contactar (Pendiente)', color: '#f39c12' },
    { name: 'Enviando (En Proceso)', color: '#3498db' },
    { name: 'Sin WhatsApp / Error', color: '#e74c3c' },
  ];
});

const renderMapMarkers = () => {
  if (!leafletMap || !markersLayer || !window.L) return;

  markersLayer.clearLayers();
  markersMap.clear();

  filteredLeads.value.forEach(item => {
    const color =
      colorMode.value === 'status' ? item.status_color : item.sector_color;

    const marker = window.L.circleMarker([item.lat, item.lon], {
      radius: 7,
      fillColor: color,
      color: '#ffffff',
      weight: 2,
      opacity: 1,
      fillOpacity: 0.85,
    });

    let dateFormatted = '';
    if (item.fecha_envio) {
      dateFormatted = `<div class="flex items-center gap-1.5 text-xs text-slate-600"><i class="i-lucide-calendar-check text-blue-500"></i><span><strong>Envío:</strong> ${item.fecha_envio}</span></div>`;
    } else if (item.fecha_ingreso) {
      dateFormatted = `<div class="flex items-center gap-1.5 text-xs text-slate-600"><i class="i-lucide-calendar text-slate-400"></i><span><strong>Ingreso:</strong> ${item.fecha_ingreso}</span></div>`;
    }

    const agentFormatted =
      item.agente && item.agente !== 'Sin Asignar'
        ? `<div class="flex items-center gap-1.5 text-xs font-semibold text-emerald-700 bg-emerald-50 px-2 py-1 rounded-md border border-emerald-200"><i class="i-lucide-user-check text-emerald-600"></i><span>Asesor: ${item.agente}</span></div>`
        : `<div class="flex items-center gap-1.5 text-xs text-slate-500 bg-slate-100 px-2 py-1 rounded-md"><i class="i-lucide-user-x"></i><span>Asesor: Sin Asignar</span></div>`;

    const popupHtml = `
      <div class="p-3 font-sans w-72">
        <div class="bg-slate-900 text-white p-2.5 -m-3 mb-2.5 rounded-t-lg">
          <h3 class="font-bold text-sm leading-tight">${item.empresa}</h3>
          <div class="flex gap-1.5 mt-1.5 flex-wrap">
            <span class="text-[10px] px-1.5 py-0.5 rounded font-medium text-white" style="background:${item.sector_color}">${item.macro_sector}</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded font-medium text-white" style="background:${item.status_color}">${item.estado_clean}</span>
          </div>
        </div>
        <div class="space-y-1.5 text-xs text-slate-700 mt-3">
          <div class="flex items-start gap-1.5"><i class="i-lucide-user text-slate-400 mt-0.5"></i><div><strong>Contacto:</strong> ${item.contacto_sugerido}</div></div>
          <div class="flex items-start gap-1.5"><i class="i-lucide-map-pin text-slate-400 mt-0.5"></i><div>${item.ubicacion || ''} (<em>${item.ciudad_distrito}, ${item.departamento}</em>)</div></div>
          ${dateFormatted}
          ${agentFormatted}
          ${item.oferta_solucion ? `<div class="bg-slate-50 p-2 rounded border-l-2 border-blue-500 text-[11px] mt-2"><strong>Propuesta:</strong> ${item.oferta_solucion}</div>` : ''}
        </div>
      </div>
    `;

    marker.bindPopup(popupHtml);
    markersLayer.addLayer(marker);
    markersMap.set(item.id, marker);
  });
};

// Renderizar gráficos de Chart.js
const renderCharts = () => {
  if (!window.Chart) return;

  if (chartRegions) chartRegions.destroy();
  if (chartStatus) chartStatus.destroy();
  if (chartSectors) chartSectors.destroy();
  if (chartTimeline) chartTimeline.destroy();

  // 1. Regiones
  const ctxReg = document
    .getElementById('chartRegionsCanvas')
    ?.getContext('2d');
  if (ctxReg && regionsDistribution.value.length) {
    chartRegions = new window.Chart(ctxReg, {
      type: 'bar',
      data: {
        labels: regionsDistribution.value.slice(0, 12).map(r => r.region),
        datasets: [
          {
            label: 'Comercios',
            data: regionsDistribution.value.slice(0, 12).map(r => r.total),
            backgroundColor: '#3b82f6',
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: { legend: { display: false } },
      },
    });
  }

  // 2. Estados
  const ctxStat = document
    .getElementById('chartStatusCanvas')
    ?.getContext('2d');
  if (ctxStat) {
    chartStatus = new window.Chart(ctxStat, {
      type: 'doughnut',
      data: {
        labels: ['Contactado', 'Por Contactar', 'Sin WhatsApp / Error'],
        datasets: [
          {
            data: [
              summary.value.contactados,
              summary.value.pendientes,
              summary.value.sin_whatsapp,
            ],
            backgroundColor: ['#22c55e', '#f59e0b', '#ef4444'],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom' } },
      },
    });
  }

  // 3. Macro Sectores
  const ctxSec = document
    .getElementById('chartSectorsCanvas')
    ?.getContext('2d');
  if (ctxSec && sectorsDistribution.value.length) {
    chartSectors = new window.Chart(ctxSec, {
      type: 'bar',
      data: {
        labels: sectorsDistribution.value.slice(0, 10).map(s => s.sector),
        datasets: [
          {
            label: 'Comercios',
            data: sectorsDistribution.value.slice(0, 10).map(s => s.total),
            backgroundColor: sectorsDistribution.value
              .slice(0, 10)
              .map(s => s.color || '#8b5cf6'),
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: { legend: { display: false } },
      },
    });
  }

  // 4. Serie Temporal
  const ctxTime = document
    .getElementById('chartTimelineCanvas')
    ?.getContext('2d');
  if (ctxTime && timeline.value.length) {
    chartTimeline = new window.Chart(ctxTime, {
      type: 'line',
      data: {
        labels: timeline.value.map(pt => pt.date),
        datasets: [
          {
            label: 'Registros / Envíos',
            data: timeline.value.map(pt => pt.count),
            borderColor: '#f59e0b',
            backgroundColor: 'rgba(245, 158, 11, 0.15)',
            fill: true,
            tension: 0.3,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
      },
    });
  }
};

// Carga de datos desde la API
const fetchCoverageData = async () => {
  try {
    isLoading.value = true;
    const response = await CoverageAPI.getReports({
      departamento: selectedRegion.value,
      ciudad: selectedDistrict.value,
      macro_sector: selectedSector.value,
      estado: selectedStatus.value,
      agente: selectedAgent.value,
      start_date: dateStart.value,
      end_date: dateEnd.value,
      search: searchQuery.value,
    });

    const data = response.data;
    summary.value = data.summary || summary.value;
    leads.value = data.leads || [];
    regionsDistribution.value = data.regions_distribution || [];
    sectorsDistribution.value = data.sectors_distribution || [];
    timeline.value = data.timeline || [];
    agentsMetrics.value = data.agents_metrics || [];

    if (data.filter_options) {
      filterOptions.value.regions = data.filter_options.regions || [];
      filterOptions.value.sectors = data.filter_options.sectors || [];
      filterOptions.value.agents = data.filter_options.agents || [];
    }

    await nextTick();
    if (activeTab.value === 'map') {
      renderMapMarkers();
    } else if (activeTab.value === 'metrics') {
      renderCharts();
    }
  } catch {
    // Manejado en UI
  } finally {
    isLoading.value = false;
  }
};

// Sincronización manual / forzada
const triggerManualSync = async () => {
  try {
    isSyncing.value = true;
    syncFeedback.value = t('REPORT.COVERAGE.SYNCING');
    await CoverageAPI.triggerSync();
    syncFeedback.value = t('REPORT.COVERAGE.SYNC_SUCCESS');
    await fetchCoverageData();
  } catch {
    syncFeedback.value = t('REPORT.COVERAGE.SYNC_ERROR');
  } finally {
    isSyncing.value = false;
    setTimeout(() => {
      syncFeedback.value = '';
    }, 4000);
  }
};

// Inicialización de Leaflet
const initMap = async () => {
  await loadExternalAssets();
  if (!window.L || !mapContainer.value) return;

  if (leafletMap) {
    leafletMap.remove();
  }

  leafletMap = window.L.map(mapContainer.value, {
    center: [-9.5, -75.0],
    zoom: 6,
    zoomControl: false,
  });

  window.L.control.zoom({ position: 'topright' }).addTo(leafletMap);

  window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors',
    maxZoom: 19,
  }).addTo(leafletMap);

  if (window.L.markerClusterGroup) {
    markersLayer = window.L.markerClusterGroup({
      maxClusterRadius: 40,
      spiderfyOnMaxZoom: true,
      showCoverageOnHover: false,
      zoomToBoundsOnClick: true,
    });
  } else {
    markersLayer = window.L.layerGroup();
  }

  leafletMap.addLayer(markersLayer);
  renderMapMarkers();
};

const centerOnLead = item => {
  const marker = markersMap.get(item.id);
  if (marker && leafletMap) {
    if (markersLayer.zoomToShowLayer) {
      markersLayer.zoomToShowLayer(marker, () => {
        leafletMap.setView([item.lat, item.lon], 16, { animate: true });
        marker.openPopup();
      });
    } else {
      leafletMap.setView([item.lat, item.lon], 16, { animate: true });
      marker.openPopup();
    }
  }
};

const clearDates = () => {
  dateStart.value = '';
  dateEnd.value = '';
  fetchCoverageData();
};

const setTab = tab => {
  activeTab.value = tab;
  nextTick(() => {
    if (tab === 'map') {
      setTimeout(() => {
        if (leafletMap) leafletMap.invalidateSize();
      }, 100);
    } else if (tab === 'metrics') {
      renderCharts();
    }
  });
};

watch(filteredLeads, () => {
  if (activeTab.value === 'map') {
    renderMapMarkers();
  }
});

watch(colorMode, () => {
  renderMapMarkers();
});

onMounted(async () => {
  await fetchCoverageData();
  await initMap();
});
</script>

<template>
  <div
    class="flex flex-col h-[calc(100vh-4rem)] w-full overflow-hidden bg-slate-50 dark:bg-slate-900"
  >
    <!-- Barra superior / Header -->
    <header
      class="h-14 bg-slate-900 text-white flex items-center justify-between px-5 shadow-sm shrink-0 z-30"
    >
      <div class="flex items-center gap-3">
        <i class="i-lucide-map-pin text-sky-400 text-lg" />
        <span class="font-bold text-sm tracking-wide">{{
          t('REPORT.COVERAGE.TITLE')
        }}</span>
      </div>

      <!-- Pestañas de navegación interna -->
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all"
          :class="
            activeTab === 'map'
              ? 'bg-sky-400 text-slate-900 shadow-sm'
              : 'bg-white/10 text-slate-200 hover:bg-white/20'
          "
          @click="setTab('map')"
        >
          <i class="i-lucide-globe text-sm" />
          <span>{{ t('REPORT.COVERAGE.TAB_MAP') }}</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all"
          :class="
            activeTab === 'metrics'
              ? 'bg-sky-400 text-slate-900 shadow-sm'
              : 'bg-white/10 text-slate-200 hover:bg-white/20'
          "
          @click="setTab('metrics')"
        >
          <i class="i-lucide-bar-chart-3 text-sm" />
          <span>{{ t('REPORT.COVERAGE.TAB_METRICS') }}</span>
        </button>
      </div>

      <!-- Metadatos y acciones -->
      <div class="flex items-center gap-3 text-xs">
        <span
          v-if="summary.last_synced_at"
          class="inline-flex items-center gap-1.5 bg-emerald-500/15 text-emerald-400 px-2.5 py-1 rounded-full font-medium"
        >
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span
            >{{ t('REPORT.COVERAGE.LIVE') }}: {{ summary.last_synced_at }}</span
          >
        </span>

        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-1 rounded-lg border border-slate-700 font-medium transition"
          :disabled="isSyncing"
          @click="triggerManualSync"
        >
          <i
            class="i-lucide-refresh-cw text-xs"
            :class="{ 'animate-spin': isSyncing }"
          />
          <span>{{
            isSyncing ? t('REPORT.COVERAGE.SYNCING') : t('REPORT.COVERAGE.SYNC')
          }}</span>
        </button>

        <a
          href="https://docs.google.com/spreadsheets/d/1UTSjZ90lnCzE3wsFTtkjMr6onxbAlcZRD-JromHJl8A/edit?gid=0#gid=0"
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center gap-1.5 text-sky-400 hover:underline font-medium ml-2"
        >
          <i class="i-lucide-external-link text-xs" />
          <span>{{ t('REPORT.COVERAGE.SHEETS_LINK') }}</span>
        </a>
      </div>
    </header>

    <!-- Feedback banner -->
    <div
      v-if="syncFeedback"
      class="bg-blue-600 text-white text-xs px-4 py-1.5 text-center font-medium shadow-inner"
    >
      {{ syncFeedback }}
    </div>

    <!-- Contenido Principal -->
    <main class="flex-1 flex overflow-hidden relative">
      <!-- PESTAÑA 1: MAPA NACIONAL -->
      <div v-show="activeTab === 'map'" class="w-full h-full flex">
        <!-- Sidebar lateral de filtros y prospectos -->
        <aside
          class="w-[420px] min-w-[360px] h-full bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 flex flex-col z-20 shadow-sm"
        >
          <!-- KPIs rápidos -->
          <div
            class="grid grid-cols-4 gap-1.5 p-3 bg-slate-100 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700"
          >
            <div
              class="bg-white dark:bg-slate-700 p-2 rounded border border-slate-200 dark:border-slate-600 text-center"
            >
              <div
                class="text-[10px] uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.TOTAL_LEADS') }}
              </div>
              <div
                class="text-sm font-extrabold text-slate-800 dark:text-white"
              >
                {{ filteredLeads.length }}
              </div>
            </div>
            <div
              class="bg-white dark:bg-slate-700 p-2 rounded border border-slate-200 dark:border-slate-600 text-center"
            >
              <div
                class="text-[10px] uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.CONTACTED') }}
              </div>
              <div class="text-sm font-extrabold text-emerald-600">
                {{
                  filteredLeads.filter(l => l.estado_clean === 'Contactado')
                    .length
                }}
              </div>
            </div>
            <div
              class="bg-white dark:bg-slate-700 p-2 rounded border border-slate-200 dark:border-slate-600 text-center"
            >
              <div
                class="text-[10px] uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.PENDING') }}
              </div>
              <div class="text-sm font-extrabold text-amber-600">
                {{
                  filteredLeads.filter(l => l.estado_clean === 'Por Contactar')
                    .length
                }}
              </div>
            </div>
            <div
              class="bg-white dark:bg-slate-700 p-2 rounded border border-slate-200 dark:border-slate-600 text-center"
            >
              <div
                class="text-[10px] uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.INVALID_WA') }}
              </div>
              <div class="text-sm font-extrabold text-rose-600">
                {{
                  filteredLeads.filter(l =>
                    l.estado_clean.includes('Sin WhatsApp')
                  ).length
                }}
              </div>
            </div>
          </div>

          <!-- Controles y Filtros -->
          <div
            class="p-3 border-b border-slate-200 dark:border-slate-700 space-y-2 bg-white dark:bg-slate-800 text-xs"
          >
            <!-- Buscador -->
            <div class="relative">
              <i
                class="i-lucide-search absolute left-2.5 top-2.5 text-slate-400 text-xs"
              />
              <input
                v-model="searchQuery"
                type="text"
                :placeholder="t('REPORT.COVERAGE.SEARCH_PLACEHOLDER')"
                class="w-full pl-8 pr-3 py-1.5 rounded-md border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white text-xs focus:ring-1 focus:ring-sky-500 focus:outline-none"
              />
            </div>

            <!-- Filtro Región y Ciudad -->
            <div class="grid grid-cols-2 gap-2">
              <select
                v-model="selectedRegion"
                class="p-1.5 rounded-md border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white text-xs"
                @change="
                  selectedDistrict = 'ALL';
                  fetchCoverageData();
                "
              >
                <option value="ALL">
                  {{ t('REPORT.COVERAGE.ALL_REGIONS') }}
                </option>
                <option v-for="r in filterOptions.regions" :key="r" :value="r">
                  {{ r }}
                </option>
              </select>

              <select
                v-model="selectedDistrict"
                class="p-1.5 rounded-md border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white text-xs"
                @change="fetchCoverageData"
              >
                <option value="ALL">
                  {{ t('REPORT.COVERAGE.ALL_DISTRICTS') }}
                </option>
                <option v-for="d in availableDistricts" :key="d" :value="d">
                  {{ d }}
                </option>
              </select>
            </div>

            <!-- Filtro Sector y Estado -->
            <div class="grid grid-cols-2 gap-2">
              <select
                v-model="selectedSector"
                class="p-1.5 rounded-md border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white text-xs"
                @change="fetchCoverageData"
              >
                <option value="ALL">
                  {{ t('REPORT.COVERAGE.ALL_SECTORS') }}
                </option>
                <option v-for="s in filterOptions.sectors" :key="s" :value="s">
                  {{ s }}
                </option>
              </select>

              <select
                v-model="selectedStatus"
                class="p-1.5 rounded-md border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white text-xs"
                @change="fetchCoverageData"
              >
                <option value="ALL">
                  {{ t('REPORT.COVERAGE.ALL_STATUSES') }}
                </option>
                <option value="Contactado">
                  {{ t('REPORT.COVERAGE.STATUS_CONTACTED') }}
                </option>
                <option value="Por Contactar">
                  {{ t('REPORT.COVERAGE.STATUS_PENDING') }}
                </option>
                <option value="Enviando">
                  {{ t('REPORT.COVERAGE.STATUS_SENDING') }}
                </option>
                <option value="Sin WhatsApp / Error">
                  {{ t('REPORT.COVERAGE.STATUS_INVALID') }}
                </option>
              </select>
            </div>

            <!-- Rango de fechas -->
            <div
              class="bg-slate-50 dark:bg-slate-700/50 p-2 rounded-md border border-slate-200 dark:border-slate-600 space-y-1.5"
            >
              <div
                class="flex items-center justify-between text-[11px] font-semibold text-slate-600 dark:text-slate-300"
              >
                <span class="flex items-center gap-1"
                  ><i class="i-lucide-calendar text-xs" />
                  {{ t('REPORT.COVERAGE.DATE_RANGE') }}</span
                >
                <button
                  type="button"
                  class="text-sky-600 hover:underline text-[10px]"
                  @click="clearDates"
                >
                  {{ t('REPORT.COVERAGE.CLEAR') }}
                </button>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <div>
                  <label class="block text-[10px] text-slate-500">{{
                    t('REPORT.COVERAGE.DATE_FROM')
                  }}</label>
                  <input
                    v-model="dateStart"
                    type="date"
                    class="w-full p-1 border rounded text-xs dark:bg-slate-700"
                    @change="fetchCoverageData"
                  />
                </div>
                <div>
                  <label class="block text-[10px] text-slate-500">{{
                    t('REPORT.COVERAGE.DATE_TO')
                  }}</label>
                  <input
                    v-model="dateEnd"
                    type="date"
                    class="w-full p-1 border rounded text-xs dark:bg-slate-700"
                    @change="fetchCoverageData"
                  />
                </div>
              </div>
            </div>

            <!-- Modo de color de marcadores -->
            <div
              class="flex items-center justify-between p-1.5 bg-slate-50 dark:bg-slate-700/50 rounded-md border border-slate-200 dark:border-slate-600 text-[11px]"
            >
              <span class="font-medium text-slate-600 dark:text-slate-300">{{
                t('REPORT.COVERAGE.COLOR_BY')
              }}</span>
              <div class="flex gap-1">
                <button
                  type="button"
                  class="px-2 py-0.5 rounded text-[11px] font-semibold transition"
                  :class="
                    colorMode === 'sector'
                      ? 'bg-slate-900 text-white dark:bg-sky-500'
                      : 'bg-white dark:bg-slate-600 text-slate-700 dark:text-slate-200'
                  "
                  @click="colorMode = 'sector'"
                >
                  {{ t('REPORT.COVERAGE.SECTOR') }}
                </button>
                <button
                  type="button"
                  class="px-2 py-0.5 rounded text-[11px] font-semibold transition"
                  :class="
                    colorMode === 'status'
                      ? 'bg-slate-900 text-white dark:bg-sky-500'
                      : 'bg-white dark:bg-slate-600 text-slate-700 dark:text-slate-200'
                  "
                  @click="colorMode = 'status'"
                >
                  {{ t('REPORT.COVERAGE.STATUS') }}
                </button>
              </div>
            </div>
          </div>

          <!-- Cabecera de la lista -->
          <div
            class="px-3 py-2 bg-slate-100 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center text-[11px] text-slate-500 font-medium"
          >
            <span>{{
              t('REPORT.COVERAGE.SHOWING_COUNT', {
                count: filteredLeads.length,
                total: summary.total,
              })
            }}</span>
            <span class="text-slate-400">{{
              t('REPORT.COVERAGE.CLICK_TO_CENTER')
            }}</span>
          </div>

          <!-- Lista de prospectos scrolleable -->
          <div class="flex-1 overflow-y-auto p-2 space-y-2">
            <div
              v-for="item in filteredLeads.slice(0, 200)"
              :key="item.id"
              class="bg-white dark:bg-slate-700 p-2.5 rounded-lg border border-slate-200 dark:border-slate-600 cursor-pointer hover:shadow-md transition-all border-l-4"
              :style="{
                borderLeftColor:
                  colorMode === 'status'
                    ? item.status_color
                    : item.sector_color,
              }"
              @click="centerOnLead(item)"
            >
              <div class="flex items-start justify-between gap-2">
                <h4
                  class="font-bold text-xs text-slate-800 dark:text-white truncate"
                >
                  {{ item.empresa }}
                </h4>
                <span
                  class="text-[10px] px-1.5 py-0.5 rounded font-semibold text-white shrink-0"
                  :style="{ background: item.status_color }"
                >
                  {{ item.estado_clean }}
                </span>
              </div>

              <div
                class="flex items-center gap-1.5 text-[11px] text-slate-600 dark:text-slate-300 mt-1"
              >
                <span
                  class="w-2 h-2 rounded-full shrink-0"
                  :style="{ background: item.sector_color }"
                />
                <span class="truncate">{{ item.sector }}</span>
              </div>

              <div
                class="flex items-center gap-1.5 text-[11px] text-slate-500 dark:text-slate-400 mt-0.5"
              >
                <i class="i-lucide-map-pin text-xs shrink-0" />
                <span class="font-medium text-slate-700 dark:text-slate-200">{{
                  item.departamento
                }}</span>
                <span>&bull;</span>
                <span class="truncate">{{ item.ciudad_distrito }}</span>
              </div>

              <!-- Asesor que lo atiende -->
              <div
                class="flex items-center justify-between text-[10px] text-slate-500 mt-1.5 pt-1.5 border-t border-slate-100 dark:border-slate-600/50"
              >
                <div
                  class="flex items-center gap-1 text-slate-600 dark:text-slate-300 font-medium"
                >
                  <i class="i-lucide-user-check text-emerald-600 text-xs" />
                  <span class="truncate"
                    >{{ t('REPORT.COVERAGE.ADVISOR') }} {{ item.agente }}</span
                  >
                </div>
                <div
                  v-if="item.fecha_envio || item.fecha_ingreso"
                  class="text-slate-400 text-[10px]"
                >
                  {{ item.fecha_envio || item.fecha_ingreso }}
                </div>
              </div>
            </div>

            <div
              v-if="filteredLeads.length === 0"
              class="p-8 text-center text-slate-400 text-xs"
            >
              {{ t('REPORT.COVERAGE.NO_LEADS_FOUND') }}
            </div>
          </div>
        </aside>

        <!-- Mapa de Leaflet -->
        <div class="flex-1 h-full relative">
          <div ref="mapContainer" class="w-full h-full z-10" />

          <!-- Leyenda flotante -->
          <div
            class="absolute bottom-5 right-5 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm p-3 rounded-lg border border-slate-200 dark:border-slate-700 shadow-lg z-20 max-w-xs text-xs"
          >
            <div
              class="font-bold text-slate-800 dark:text-white border-b border-slate-200 dark:border-slate-700 pb-1 mb-2"
            >
              {{
                colorMode === 'sector'
                  ? t('REPORT.COVERAGE.LEGEND_SECTORS')
                  : t('REPORT.COVERAGE.LEGEND_STATUS')
              }}
            </div>
            <div class="space-y-1 max-h-48 overflow-y-auto pr-1">
              <div
                v-for="item in legendItems"
                :key="item.name"
                class="flex items-center gap-2"
              >
                <span
                  class="w-2.5 h-2.5 rounded-full shrink-0"
                  :style="{ background: item.color }"
                />
                <span
                  class="text-[11px] text-slate-700 dark:text-slate-200 truncate"
                  >{{ item.name }}</span
                >
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- PESTAÑA 2: MÉTRICAS Y RENDIMIENTO -->
      <div
        v-show="activeTab === 'metrics'"
        class="w-full h-full overflow-y-auto p-6 space-y-6 bg-slate-50 dark:bg-slate-900"
      >
        <!-- Encabezado de métricas -->
        <div class="flex justify-between items-center">
          <div>
            <h2 class="text-xl font-extrabold text-slate-900 dark:text-white">
              {{ t('REPORT.COVERAGE.METRICS_TITLE') }}
            </h2>
            <p class="text-xs text-slate-500 mt-1">
              {{ t('REPORT.COVERAGE.METRICS_SUBTITLE') }}
            </p>
          </div>
        </div>

        <!-- 4 Big KPI Cards -->
        <div class="grid grid-cols-4 gap-4">
          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex justify-between items-center"
          >
            <div>
              <div
                class="text-xs uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.TOTAL_PROSPECTS') }}
              </div>
              <div
                class="text-2xl font-black text-slate-900 dark:text-white mt-1"
              >
                {{ summary.total }}
              </div>
              <div class="text-[11px] text-slate-400 mt-1">
                {{ t('REPORT.COVERAGE.TOTAL_PROSPECTS_SUB') }}
              </div>
            </div>
            <div
              class="w-12 h-12 rounded-xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 flex items-center justify-center text-xl"
            >
              <i class="i-lucide-building" />
            </div>
          </div>

          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex justify-between items-center"
          >
            <div>
              <div
                class="text-xs uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.CONTACT_RATE') }}
              </div>
              <div class="text-2xl font-black text-emerald-600 mt-1">
                {{ summary.tasa_contacto }}%
              </div>
              <div class="text-[11px] text-slate-400 mt-1">
                {{
                  t('REPORT.COVERAGE.CONTACT_RATE_SUB', {
                    contacted: summary.contactados,
                    invalid: summary.sin_whatsapp,
                  })
                }}
              </div>
            </div>
            <div
              class="w-12 h-12 rounded-xl bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 flex items-center justify-center text-xl"
            >
              <i class="i-lucide-send" />
            </div>
          </div>

          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex justify-between items-center"
          >
            <div>
              <div
                class="text-xs uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.REGIONS_COUNT') }}
              </div>
              <div class="text-2xl font-black text-purple-600 mt-1">
                {{ summary.total_departamentos }}
              </div>
              <div class="text-[11px] text-slate-400 mt-1">
                {{ t('REPORT.COVERAGE.REGIONS_COUNT_SUB') }}
              </div>
            </div>
            <div
              class="w-12 h-12 rounded-xl bg-purple-50 dark:bg-purple-900/30 text-purple-600 flex items-center justify-center text-xl"
            >
              <i class="i-lucide-map" />
            </div>
          </div>

          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm flex justify-between items-center"
          >
            <div>
              <div
                class="text-xs uppercase font-bold text-slate-500 dark:text-slate-400"
              >
                {{ t('REPORT.COVERAGE.DISTRICTS_COUNT') }}
              </div>
              <div class="text-2xl font-black text-amber-600 mt-1">
                {{ summary.total_ciudades }}
              </div>
              <div class="text-[11px] text-slate-400 mt-1">
                {{ t('REPORT.COVERAGE.DISTRICTS_COUNT_SUB') }}
              </div>
            </div>
            <div
              class="w-12 h-12 rounded-xl bg-amber-50 dark:bg-amber-900/30 text-amber-600 flex items-center justify-center text-xl"
            >
              <i class="i-lucide-map-pin" />
            </div>
          </div>
        </div>

        <!-- 4 Gráficos interactivos -->
        <div class="grid grid-cols-3 gap-5">
          <div
            class="col-span-2 bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3
              class="font-bold text-sm text-slate-800 dark:text-white flex items-center gap-2 mb-4"
            >
              <i class="i-lucide-map-pin text-blue-500" />
              {{ t('REPORT.COVERAGE.CHART_REGIONS_TITLE') }}
            </h3>
            <div class="h-64 relative">
              <canvas id="chartRegionsCanvas" />
            </div>
          </div>

          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3
              class="font-bold text-sm text-slate-800 dark:text-white flex items-center gap-2 mb-4"
            >
              <i class="i-lucide-pie-chart text-emerald-500" />
              {{ t('REPORT.COVERAGE.CHART_STATUS_TITLE') }}
            </h3>
            <div class="h-64 relative">
              <canvas id="chartStatusCanvas" />
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-5">
          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3
              class="font-bold text-sm text-slate-800 dark:text-white flex items-center gap-2 mb-4"
            >
              <i class="i-lucide-briefcase text-purple-500" />
              {{ t('REPORT.COVERAGE.CHART_SECTORS_TITLE') }}
            </h3>
            <div class="h-64 relative">
              <canvas id="chartSectorsCanvas" />
            </div>
          </div>

          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3
              class="font-bold text-sm text-slate-800 dark:text-white flex items-center gap-2 mb-4"
            >
              <i class="i-lucide-trending-up text-amber-500" />
              {{ t('REPORT.COVERAGE.CHART_TIMELINE_TITLE') }}
            </h3>
            <div class="h-64 relative">
              <canvas id="chartTimelineCanvas" />
            </div>
          </div>
        </div>

        <!-- 3 Tablas de Rendimiento -->
        <div class="grid grid-cols-2 gap-5">
          <!-- Rendimiento por Región -->
          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3 class="font-bold text-sm text-slate-800 dark:text-white mb-3">
              {{ t('REPORT.COVERAGE.TABLE_REGIONS_TITLE') }}
            </h3>
            <div class="max-h-72 overflow-y-auto">
              <table class="w-full text-xs text-left">
                <thead
                  class="bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 font-semibold sticky top-0"
                >
                  <tr>
                    <th class="p-2.5">{{ t('REPORT.COVERAGE.TH_REGION') }}</th>
                    <th class="p-2.5 text-center">
                      {{ t('REPORT.COVERAGE.TH_TOTAL') }}
                    </th>
                    <th class="p-2.5 text-center">
                      {{ t('REPORT.COVERAGE.TH_CONTACTED') }}
                    </th>
                    <th class="p-2.5">
                      {{ t('REPORT.COVERAGE.TH_PROGRESS') }}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                  <tr
                    v-for="r in regionsDistribution"
                    :key="r.region"
                    class="hover:bg-slate-50 dark:hover:bg-slate-700/50"
                  >
                    <td
                      class="p-2.5 font-medium text-slate-800 dark:text-white"
                    >
                      {{ r.region }}
                    </td>
                    <td class="p-2.5 text-center font-bold">{{ r.total }}</td>
                    <td
                      class="p-2.5 text-center text-emerald-600 font-semibold"
                    >
                      {{ r.contactados }}
                    </td>
                    <td class="p-2.5 w-36">
                      <div class="flex items-center gap-2">
                        <div
                          class="flex-1 h-2 bg-slate-200 dark:bg-slate-600 rounded-full overflow-hidden"
                        >
                          <div
                            class="h-full bg-emerald-500 rounded-full"
                            :style="{ width: `${r.pct}%` }"
                          />
                        </div>
                        <span class="text-[11px] font-semibold w-8 text-right"
                          >{{ r.pct }}%</span
                        >
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Rendimiento por Sector -->
          <div
            class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
          >
            <h3 class="font-bold text-sm text-slate-800 dark:text-white mb-3">
              {{ t('REPORT.COVERAGE.TABLE_SECTORS_TITLE') }}
            </h3>
            <div class="max-h-72 overflow-y-auto">
              <table class="w-full text-xs text-left">
                <thead
                  class="bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 font-semibold sticky top-0"
                >
                  <tr>
                    <th class="p-2.5">{{ t('REPORT.COVERAGE.TH_SECTOR') }}</th>
                    <th class="p-2.5 text-center">
                      {{ t('REPORT.COVERAGE.TH_TOTAL') }}
                    </th>
                    <th class="p-2.5 text-center">
                      {{ t('REPORT.COVERAGE.TH_CONTACTED') }}
                    </th>
                    <th class="p-2.5">
                      {{ t('REPORT.COVERAGE.TH_PROGRESS') }}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                  <tr
                    v-for="s in sectorsDistribution"
                    :key="s.sector"
                    class="hover:bg-slate-50 dark:hover:bg-slate-700/50"
                  >
                    <td
                      class="p-2.5 font-medium text-slate-800 dark:text-white flex items-center gap-2"
                    >
                      <span
                        class="w-2 h-2 rounded-full shrink-0"
                        :style="{ background: s.color || '#3b82f6' }"
                      />
                      <span class="truncate">{{ s.sector }}</span>
                    </td>
                    <td class="p-2.5 text-center font-bold">{{ s.total }}</td>
                    <td
                      class="p-2.5 text-center text-emerald-600 font-semibold"
                    >
                      {{ s.contactados }}
                    </td>
                    <td class="p-2.5 w-36">
                      <div class="flex items-center gap-2">
                        <div
                          class="flex-1 h-2 bg-slate-200 dark:bg-slate-600 rounded-full overflow-hidden"
                        >
                          <div
                            class="h-full bg-emerald-500 rounded-full"
                            :style="{ width: `${s.pct}%` }"
                          />
                        </div>
                        <span class="text-[11px] font-semibold w-8 text-right"
                          >{{ s.pct }}%</span
                        >
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Tabla: Métricas de Asesores / Agentes -->
        <div
          class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
        >
          <div class="flex items-center justify-between mb-4">
            <div>
              <h3
                class="font-bold text-sm text-slate-800 dark:text-white flex items-center gap-2"
              >
                <i class="i-lucide-user-check text-blue-500" />
                {{ t('REPORT.COVERAGE.TABLE_AGENTS_TITLE') }}
              </h3>
              <p class="text-xs text-slate-500 mt-0.5">
                {{ t('REPORT.COVERAGE.TABLE_AGENTS_SUB') }}
              </p>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-xs text-left">
              <thead
                class="bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 font-semibold"
              >
                <tr>
                  <th class="p-3">{{ t('REPORT.COVERAGE.TH_AGENT') }}</th>
                  <th class="p-3 text-center">
                    {{ t('REPORT.COVERAGE.TH_ASSIGNED') }}
                  </th>
                  <th class="p-3 text-center">
                    {{ t('REPORT.COVERAGE.TH_CONTACTED') }}
                  </th>
                  <th class="p-3 text-center">
                    {{ t('REPORT.COVERAGE.TH_REPLIED') }}
                  </th>
                  <th class="p-3 text-center">
                    {{ t('REPORT.COVERAGE.TH_RESPONSE_RATE') }}
                  </th>
                  <th class="p-3 text-center">
                    {{ t('REPORT.COVERAGE.TH_STATUS') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <tr
                  v-for="a in agentsMetrics"
                  :key="a.agente"
                  class="hover:bg-slate-50 dark:hover:bg-slate-700/50"
                >
                  <td
                    class="p-3 font-semibold text-slate-800 dark:text-white flex items-center gap-2"
                  >
                    <div
                      class="w-7 h-7 rounded-full bg-sky-100 text-sky-700 flex items-center justify-center font-bold text-xs"
                    >
                      {{ a.agente.charAt(0) }}
                    </div>
                    <span>{{ a.agente }}</span>
                  </td>
                  <td class="p-3 text-center font-bold">{{ a.leads }}</td>
                  <td class="p-3 text-center text-emerald-600 font-semibold">
                    {{ a.contactados }}
                  </td>
                  <td class="p-3 text-center text-blue-600 font-semibold">
                    {{ a.respondidos }}
                  </td>
                  <td class="p-3 text-center">
                    <span
                      class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-bold"
                      :class="
                        a.tasa_respuesta > 20
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-amber-100 text-amber-800'
                      "
                    >
                      {{ a.tasa_respuesta }}%
                    </span>
                  </td>
                  <td class="p-3 text-center">
                    <span
                      class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                      <span>{{ t('REPORT.COVERAGE.STATUS_ACTIVE') }}</span>
                    </span>
                  </td>
                </tr>
                <tr v-if="agentsMetrics.length === 0">
                  <td colspan="6" class="p-6 text-center text-slate-400">
                    {{ t('REPORT.COVERAGE.NO_AGENTS') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>
