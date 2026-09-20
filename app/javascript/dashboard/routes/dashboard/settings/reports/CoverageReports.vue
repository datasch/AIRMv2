<script setup>
import {
  ref,
  onMounted,
  onBeforeUnmount,
  computed,
  watch,
  nextTick,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import CoverageAPI from 'dashboard/api/coverage';
import { emitter } from 'shared/helpers/mitt';
import { voipState, makeCall } from 'dashboard/helper/voipHelper';
import { useAlert } from 'dashboard/composables';
import peruGeoJson from './data/peru_departments.json';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId || 1);

// Estado general
const activeTab = ref('map'); // 'map' | 'metrics'
const isLoading = ref(true);
const isSyncing = ref(false);
const syncFeedback = ref('');

// Lead seleccionado para el Drawer estilo Google Maps
const selectedLead = ref(null);

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
const showChoropleth = ref(true);

// Referencias DOM y Leaflet
const mapContainer = ref(null);
let leafletMap = null;
let markersLayer = null;
let choroplethLayer = null;
const markersMap = new Map();
let fetchCoverageData = () => {};

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

// Normalizar nombres de departamento para cruce exacto con GeoJSON
const normalizeDepName = name => {
  return String(name || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .trim();
};

// Estadísticas agregadas por departamento para el mapa coroplético
const departmentStats = computed(() => {
  const stats = {};
  leads.value.forEach(l => {
    const key = normalizeDepName(l.departamento);
    if (!stats[key]) {
      stats[key] = {
        total: 0,
        contactados: 0,
        pendientes: 0,
        enviando: 0,
        sin_whatsapp: 0,
      };
    }
    stats[key].total += 1;
    if (l.estado_clean === 'Contactado') stats[key].contactados += 1;
    else if (l.estado_clean === 'Por Contactar') stats[key].pendientes += 1;
    else if (l.estado_clean === 'Enviando') stats[key].enviando += 1;
    else stats[key].sin_whatsapp += 1;
  });
  return stats;
});

// Escala cromática de intensidad para cada departamento
const getDepartmentColor = depName => {
  const key = normalizeDepName(depName);
  const stat = departmentStats.value[key];
  if (!stat || stat.total === 0) return '#94a3b8'; // gris suave neutro

  const count = stat.total;
  if (count >= 500) return '#1e3a8a'; // blue-900 (alta densidad)
  if (count >= 150) return '#2563eb'; // blue-600
  if (count >= 50) return '#3b82f6'; // blue-500
  if (count >= 15) return '#60a5fa'; // blue-400
  return '#93c5fd'; // blue-300
};

// Iconos SVG en línea según macro sector para los pines estilo Google Maps
const getSectorIconSvg = macroSector => {
  const s = String(macroSector || '').toLowerCase();
  if (
    s.includes('salud') ||
    s.includes('dental') ||
    s.includes('estética') ||
    s.includes('estetica')
  ) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg>';
  }
  if (s.includes('inmobilia') || s.includes('construc')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="4" y="2" width="16" height="20" rx="2"/><path d="M9 22v-4h6v4"/><path d="M8 6h.01"/><path d="M16 6h.01"/><path d="M8 10h.01"/><path d="M16 10h.01"/></svg>';
  }
  if (s.includes('software') || s.includes('tecnolog') || s.includes('ti')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>';
  }
  if (
    s.includes('logístic') ||
    s.includes('logistic') ||
    s.includes('courier') ||
    s.includes('transporte')
  ) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="1" y="3" width="15" height="13"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/></svg>';
  }
  if (s.includes('auto') || s.includes('taller')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.5 2.8C2.1 11.2 2 11.6 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>';
  }
  if (s.includes('educa') || s.includes('capacita')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/></svg>';
  }
  if (s.includes('market') || s.includes('publicidad')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg>';
  }
  if (s.includes('legal') || s.includes('abogad')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="M7 21h10"/><path d="M12 3v18"/></svg>';
  }
  if (s.includes('vet') || s.includes('mascot')) {
    return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a2.5 2.5 0 0 1-5 0V15a2 2 0 0 0-2-2 2 2 0 0 0-2 2v3.5a2.5 2.5 0 0 1-5 0V15a5 5 0 0 1 5-5z"/></svg>';
  }
  return '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>';
};

const getRingColor = status => {
  if (status === 'Contactado') return '#22c55e';
  if (status === 'Por Contactar') return '#f59e0b';
  return '#ef4444';
};

// Generar Pin POI estilo Google Maps
const createGoogleMapsPinIcon = (item, isSelected = false) => {
  const color =
    colorMode.value === 'status' ? item.status_color : item.sector_color;
  const ringColor = getRingColor(item.estado_clean);
  const iconSvg = getSectorIconSvg(item.macro_sector);

  const scaleClass = isSelected ? 'scale-125 z-50' : 'hover:scale-115';

  return window.L.divIcon({
    className: 'google-maps-pin-marker',
    html: `
      <div class="relative cursor-pointer flex flex-col items-center transition-transform ${scaleClass}">
        <div class="w-8 h-8 rounded-full shadow-lg flex items-center justify-center text-white border-2 transition-all"
             style="background: ${color}; border-color: ${isSelected ? '#ffffff' : ringColor}; box-shadow: 0 4px 10px ${color}77;">
          ${iconSvg}
        </div>
        <div class="w-2 h-2 -mt-1 rotate-45" style="background: ${color}"></div>
      </div>
    `,
    iconSize: [32, 36],
    iconAnchor: [16, 36],
    popupAnchor: [0, -36],
  });
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

// Leads filtrados en cliente
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
      const matchEmpresa = (item.empresa || '').toLowerCase().includes(q);
      const matchContacto = (item.contacto_sugerido || '')
        .toLowerCase()
        .includes(q);
      const matchUbi = (item.ubicacion || '').toLowerCase().includes(q);
      const matchCiudad = (item.ciudad_distrito || '')
        .toLowerCase()
        .includes(q);
      const matchDpto = (item.departamento || '').toLowerCase().includes(q);
      const matchAgente = (item.agente || '').toLowerCase().includes(q);
      const matchPhone = (item.phone_number || '').includes(q);
      return (
        matchEmpresa ||
        matchContacto ||
        matchUbi ||
        matchCiudad ||
        matchDpto ||
        matchAgente ||
        matchPhone
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
    { name: 'Contactado (WhatsApp Enviado)', color: '#27ae60' },
    { name: 'Por Contactar (Pendiente)', color: '#f39c12' },
    { name: 'Enviando (En Proceso)', color: '#3498db' },
    { name: 'Sin WhatsApp / Error', color: '#e74c3c' },
  ];
});

// Renderizar capa coroplética departamental
const renderChoropleth = () => {
  if (!leafletMap || !window.L || !peruGeoJson) return;

  if (choroplethLayer) {
    leafletMap.removeLayer(choroplethLayer);
  }

  if (!showChoropleth.value) return;

  choroplethLayer = window.L.geoJSON(peruGeoJson, {
    style: feature => {
      const depName = feature.properties.NOMBDEP;
      const isSelected =
        selectedRegion.value !== 'ALL' &&
        normalizeDepName(selectedRegion.value) === normalizeDepName(depName);

      return {
        fillColor: getDepartmentColor(depName),
        weight: isSelected ? 3 : 1.5,
        opacity: 1,
        color: isSelected ? '#0284c7' : '#475569',
        dashArray: isSelected ? '' : '3',
        fillOpacity: isSelected ? 0.65 : 0.35,
      };
    },
    onEachFeature: (feature, layer) => {
      const depName = feature.properties.NOMBDEP;
      const key = normalizeDepName(depName);
      const stat = departmentStats.value[key] || {
        total: 0,
        contactados: 0,
        pendientes: 0,
      };
      const pct =
        stat.total > 0 ? Math.round((stat.contactados / stat.total) * 100) : 0;

      const tooltipContent = `
        <div class="p-1 font-sans text-xs">
          <div class="font-bold text-sm text-slate-900">${depName}</div>
          <div class="text-slate-600 mt-1">Total Prospectos: <strong class="text-slate-900">${stat.total}</strong></div>
          <div class="text-emerald-700">Contactados: <strong>${stat.contactados} (${pct}%)</strong></div>
          <div class="text-amber-700">Por Contactar: <strong>${stat.pendientes}</strong></div>
          <div class="text-[10px] text-sky-600 mt-1 font-medium italic">${t('REPORT.COVERAGE.CLICK_DEPARTMENT')}</div>
        </div>
      `;
      layer.bindTooltip(tooltipContent, { sticky: true });

      layer.on({
        mouseover: e => {
          const l = e.target;
          l.setStyle({
            weight: 2.5,
            color: '#0284c7',
            fillOpacity: 0.6,
          });
          l.bringToFront();
          if (markersLayer) markersLayer.bringToFront();
        },
        mouseout: e => {
          choroplethLayer.resetStyle(e.target);
        },
        click: () => {
          const matchedLead = leads.value.find(
            l => normalizeDepName(l.departamento) === key
          );
          const targetName = matchedLead ? matchedLead.departamento : depName;
          selectedRegion.value =
            selectedRegion.value === targetName ? 'ALL' : targetName;
          selectedDistrict.value = 'ALL';

          leafletMap.fitBounds(layer.getBounds(), {
            padding: [30, 30],
            maxZoom: 11,
            animate: true,
          });
          fetchCoverageData();
        },
      });
    },
  });

  choroplethLayer.addTo(leafletMap);
  if (markersLayer) markersLayer.bringToFront();
};

const centerOnLead = item => {
  selectedLead.value = item;
  const marker = markersMap.get(item.id);
  if (marker && leafletMap) {
    if (markersLayer.zoomToShowLayer) {
      markersLayer.zoomToShowLayer(marker, () => {
        leafletMap.setView([item.lat, item.lon], 16, { animate: true });
      });
    } else {
      leafletMap.setView([item.lat, item.lon], 16, { animate: true });
    }
  } else if (leafletMap) {
    leafletMap.setView([item.lat, item.lon], 16, { animate: true });
  }
};

// Renderizar pines POI estilo Google Maps en el mapa
const renderMapMarkers = () => {
  if (!leafletMap || !markersLayer || !window.L) return;

  markersLayer.clearLayers();
  markersMap.clear();

  filteredLeads.value.forEach(item => {
    const isSelected = selectedLead.value?.id === item.id;
    const icon = createGoogleMapsPinIcon(item, isSelected);

    const marker = window.L.marker([item.lat, item.lon], { icon });

    marker.on('click', () => {
      selectedLead.value = item;
      centerOnLead(item);
    });

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
fetchCoverageData = async () => {
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
      renderChoropleth();
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
      maxClusterRadius: 35,
      spiderfyOnMaxZoom: true,
      showCoverageOnHover: false,
      zoomToBoundsOnClick: true,
    });
  } else {
    markersLayer = window.L.layerGroup();
  }

  leafletMap.addLayer(markersLayer);
  renderChoropleth();
  renderMapMarkers();
};

const closeDrawer = () => {
  selectedLead.value = null;
};

// Acciones de contacto estilo Google Maps
const handleCallLead = lead => {
  if (!lead.phone_number) return;
  const cleanPhone = lead.phone_number.replace(/\D/g, '');
  if (voipState.isConfigured || voipState.isEnabled) {
    makeCall(
      cleanPhone,
      lead.conversation_id,
      null,
      lead.empresa || cleanPhone
    );
  } else {
    window.location.href = `tel:${cleanPhone}`;
  }
};

const handleOpenWhatsApp = lead => {
  if (!lead.phone_number) return;
  const cleanPhone = lead.phone_number.replace(/\D/g, '');
  window.open(`https://wa.me/${cleanPhone}`, '_blank');
};

const handleOpenChat = lead => {
  if (lead.conversation_id) {
    window.location.href = `/app/accounts/${accountId.value}/conversations/${lead.conversation_id}`;
  } else if (lead.contact_id) {
    window.location.href = `/app/accounts/${accountId.value}/contacts/${lead.contact_id}`;
  } else if (lead.phone_number) {
    handleOpenWhatsApp(lead);
  }
};

const handleOpenGoogleMaps = lead => {
  if (lead.lat && lead.lon) {
    window.open(
      `https://www.google.com/maps/search/?api=1&query=${lead.lat},${lead.lon}`,
      '_blank'
    );
  } else {
    const q = encodeURIComponent(
      `${lead.empresa} ${lead.ubicacion || ''} ${lead.ciudad_distrito || ''} Peru`
    );
    window.open(
      `https://www.google.com/maps/search/?api=1&query=${q}`,
      '_blank'
    );
  }
};

const handleCopyPhone = lead => {
  if (!lead.phone_number) return;
  navigator.clipboard.writeText(lead.phone_number);
  useAlert(t('REPORT.COVERAGE.PHONE_COPIED'));
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

// Suscripción reactiva WebSocket ActionCable a coverage.lead_updated
const onLeadUpdated = data => {
  const updated = data.lead || data;
  if (!updated || !updated.id) return;

  const idx = leads.value.findIndex(
    l =>
      l.id === updated.id ||
      (updated.phone_number && l.phone_number === updated.phone_number)
  );

  if (idx !== -1) {
    leads.value[idx] = { ...leads.value[idx], ...updated };
  } else {
    leads.value.unshift(updated);
  }

  // Actualizar drawer si está viendo este lead
  if (
    selectedLead.value &&
    (selectedLead.value.id === updated.id ||
      (updated.phone_number &&
        selectedLead.value.phone_number === updated.phone_number))
  ) {
    selectedLead.value = { ...selectedLead.value, ...updated };
  }

  renderChoropleth();
  renderMapMarkers();
};

watch(filteredLeads, () => {
  if (activeTab.value === 'map') {
    renderMapMarkers();
  }
});

watch(colorMode, () => {
  renderMapMarkers();
});

watch(showChoropleth, () => {
  renderChoropleth();
});

onMounted(async () => {
  emitter.on('coverage:lead_updated', onLeadUpdated);
  await fetchCoverageData();
  await initMap();
});

onBeforeUnmount(() => {
  emitter.off('coverage:lead_updated', onLeadUpdated);
});
</script>

<template>
  <div
    class="flex flex-col h-[calc(100vh-4rem)] w-full overflow-hidden bg-slate-50 dark:bg-slate-900 font-sans"
  >
    <!-- Barra superior / Header -->
    <header
      class="h-14 bg-slate-900 text-white flex items-center justify-between px-5 shadow-sm shrink-0 z-30"
    >
      <div class="flex items-center gap-3">
        <div
          class="w-8 h-8 rounded-lg bg-sky-500/20 text-sky-400 flex items-center justify-center border border-sky-500/30"
        >
          <i class="i-lucide-map-pin text-base" />
        </div>
        <div>
          <h1 class="font-bold text-sm tracking-wide leading-tight">
            {{ t('REPORT.COVERAGE.TITLE') }}
          </h1>
          <p class="text-[10px] text-slate-400">
            {{ t('REPORT.COVERAGE.DESCRIPTION') }}
          </p>
        </div>
      </div>

      <!-- Pestañas de navegación interna -->
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all"
          :class="
            activeTab === 'map'
              ? 'bg-sky-400 text-slate-900 shadow-sm font-bold'
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
              ? 'bg-sky-400 text-slate-900 shadow-sm font-bold'
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
          <span>
            {{ `${t('REPORT.COVERAGE.LIVE')}: ${summary.last_synced_at}` }}
          </span>
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
      <!-- PESTAÑA 1: MAPA NACIONAL HÍBRIDO -->
      <div v-show="activeTab === 'map'" class="w-full h-full flex relative">
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
                <span class="flex items-center gap-1">
                  <i class="i-lucide-calendar text-xs" />
                  {{ t('REPORT.COVERAGE.DATE_RANGE') }}
                </span>
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

            <!-- Controles de Capas y Colores del Mapa -->
            <div
              class="flex items-center justify-between p-1.5 bg-slate-50 dark:bg-slate-700/50 rounded-md border border-slate-200 dark:border-slate-600 text-[11px]"
            >
              <label
                class="flex items-center gap-1.5 cursor-pointer text-slate-700 dark:text-slate-200"
              >
                <input
                  v-model="showChoropleth"
                  type="checkbox"
                  class="rounded text-sky-600 focus:ring-0"
                />
                <span class="font-medium">{{
                  t('REPORT.COVERAGE.CHOROPLETH_LAYER')
                }}</span>
              </label>

              <div class="flex items-center gap-1">
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
              :class="{
                'ring-2 ring-sky-500 shadow-md': selectedLead?.id === item.id,
              }"
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
                <span class="font-medium text-slate-700 dark:text-slate-200">
                  {{ item.departamento }}
                </span>
                <span
                  class="w-1 h-1 rounded-full bg-slate-300 dark:bg-slate-600"
                />
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
                  <span class="truncate">
                    {{ `${t('REPORT.COVERAGE.ADVISOR')} ${item.agente}` }}
                  </span>
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

        <!-- Área del Mapa y Drawer Google Maps -->
        <div class="flex-1 h-full relative overflow-hidden">
          <div ref="mapContainer" class="w-full h-full z-10" />

          <!-- Banner indicador regional superior -->
          <div
            class="absolute top-4 left-4 bg-white/95 dark:bg-slate-800/95 backdrop-blur-md px-3.5 py-2 rounded-xl shadow-md border border-slate-200 dark:border-slate-700 z-20 flex items-center gap-3 text-xs"
          >
            <div class="w-2.5 h-2.5 rounded-full bg-sky-500 animate-pulse" />
            <div>
              <span class="font-bold text-slate-800 dark:text-white">
                {{
                  selectedRegion === 'ALL'
                    ? t('REPORT.COVERAGE.ALL_PERU_NATIONAL')
                    : selectedRegion
                }}
              </span>
              <span class="text-slate-400 ml-1">
                {{
                  t('REPORT.COVERAGE.BUSINESSES_COUNT', {
                    count: filteredLeads.length,
                  })
                }}
              </span>
            </div>
            <button
              v-if="selectedRegion !== 'ALL'"
              type="button"
              class="text-sky-600 dark:text-sky-400 hover:underline font-semibold text-[11px] ml-1"
              @click="
                selectedRegion = 'ALL';
                fetchCoverageData();
              "
            >
              {{ t('REPORT.COVERAGE.VIEW_ALL') }}
            </button>
          </div>

          <!-- Leyenda flotante -->
          <div
            class="absolute bottom-5 left-5 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm p-3 rounded-xl border border-slate-200 dark:border-slate-700 shadow-lg z-20 max-w-xs text-xs"
          >
            <div
              class="font-bold text-slate-800 dark:text-white border-b border-slate-200 dark:border-slate-700 pb-1 mb-2 flex items-center justify-between"
            >
              <span>{{
                colorMode === 'sector'
                  ? t('REPORT.COVERAGE.LEGEND_SECTORS')
                  : t('REPORT.COVERAGE.LEGEND_STATUS')
              }}</span>
              <span class="text-[10px] text-slate-400 font-normal">{{
                t('REPORT.COVERAGE.POI_PINS')
              }}</span>
            </div>
            <div class="space-y-1 max-h-40 overflow-y-auto pr-1">
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
                >
                  {{ item.name }}
                </span>
              </div>
            </div>
          </div>

          <!-- FICHA LATERAL DE NEGOCIO (DRAWER ESTILO GOOGLE MAPS) -->
          <transition
            enter-active-class="transition-transform duration-300 ease-out"
            enter-from-class="translate-x-full"
            enter-to-class="translate-x-0"
            leave-active-class="transition-transform duration-200 ease-in"
            leave-from-class="translate-x-0"
            leave-to-class="translate-x-full"
          >
            <aside
              v-if="selectedLead"
              class="absolute top-3 right-3 bottom-3 w-[400px] max-w-[calc(100%-1.5rem)] bg-white dark:bg-slate-800 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-700 z-30 flex flex-col overflow-hidden backdrop-blur-md"
            >
              <!-- Cabecera de la ficha comercial -->
              <div
                class="p-4 text-white relative shadow-sm shrink-0"
                :style="{
                  background: `linear-gradient(135deg, ${selectedLead.sector_color || '#1e293b'} 0%, #0f172a 100%)`,
                }"
              >
                <button
                  type="button"
                  class="absolute top-3 right-3 w-7 h-7 rounded-full bg-black/30 hover:bg-black/50 text-white flex items-center justify-center transition"
                  :title="t('REPORT.COVERAGE.CLOSE')"
                  @click="closeDrawer"
                >
                  <i class="i-lucide-x text-sm" />
                </button>

                <div class="flex items-center gap-2 mb-1.5">
                  <span
                    class="text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider bg-white/20 text-white border border-white/30"
                  >
                    {{ selectedLead.macro_sector }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1 text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider text-white"
                    :style="{ background: selectedLead.status_color }"
                  >
                    <span
                      class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"
                    />
                    {{ selectedLead.estado_clean }}
                  </span>
                </div>

                <h2
                  class="text-base font-extrabold leading-tight text-white pr-6"
                >
                  {{ selectedLead.empresa }}
                </h2>

                <div
                  class="flex items-center gap-1.5 text-xs text-white/80 mt-1"
                >
                  <i class="i-lucide-map-pin text-xs text-sky-300" />
                  <span>
                    {{
                      `${selectedLead.ciudad_distrito}, ${selectedLead.departamento}`
                    }}
                  </span>
                </div>
              </div>

              <!-- BARRA DE ACCIONES RÁPIDAS ESTILO GOOGLE MAPS -->
              <div
                class="grid grid-cols-4 gap-1 p-2 bg-slate-50 dark:bg-slate-700/60 border-b border-slate-200 dark:border-slate-700 shrink-0 text-center"
              >
                <!-- Botón Llamar VoIP -->
                <button
                  type="button"
                  class="flex flex-col items-center justify-center py-2 px-1 rounded-xl hover:bg-blue-50 dark:hover:bg-slate-600 text-blue-600 dark:text-sky-400 transition group"
                  :title="t('REPORT.COVERAGE.CALL')"
                  @click="handleCallLead(selectedLead)"
                >
                  <div
                    class="w-9 h-9 rounded-full bg-blue-100 dark:bg-blue-900/40 flex items-center justify-center group-hover:scale-110 transition shadow-sm mb-1"
                  >
                    <i
                      class="i-lucide-phone text-base text-blue-600 dark:text-sky-400"
                    />
                  </div>
                  <span class="text-[10px] font-bold">{{
                    t('REPORT.COVERAGE.CALL')
                  }}</span>
                </button>

                <!-- Botón Abrir Chat AIRM -->
                <button
                  type="button"
                  class="flex flex-col items-center justify-center py-2 px-1 rounded-xl hover:bg-indigo-50 dark:hover:bg-slate-600 text-indigo-600 dark:text-indigo-400 transition group"
                  :title="t('REPORT.COVERAGE.CHAT')"
                  @click="handleOpenChat(selectedLead)"
                >
                  <div
                    class="w-9 h-9 rounded-full bg-indigo-100 dark:bg-indigo-900/40 flex items-center justify-center group-hover:scale-110 transition shadow-sm mb-1"
                  >
                    <i
                      class="i-lucide-message-circle text-base text-indigo-600 dark:text-indigo-400"
                    />
                  </div>
                  <span class="text-[10px] font-bold">{{
                    t('REPORT.COVERAGE.CHAT')
                  }}</span>
                </button>

                <!-- Botón WhatsApp -->
                <button
                  type="button"
                  class="flex flex-col items-center justify-center py-2 px-1 rounded-xl hover:bg-emerald-50 dark:hover:bg-slate-600 text-emerald-600 dark:text-emerald-400 transition group"
                  :title="t('REPORT.COVERAGE.WHATSAPP')"
                  @click="handleOpenWhatsApp(selectedLead)"
                >
                  <div
                    class="w-9 h-9 rounded-full bg-emerald-100 dark:bg-emerald-900/40 flex items-center justify-center group-hover:scale-110 transition shadow-sm mb-1"
                  >
                    <i
                      class="i-lucide-share-2 text-base text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span class="text-[10px] font-bold">{{
                    t('REPORT.COVERAGE.WHATSAPP')
                  }}</span>
                </button>

                <!-- Botón Google Maps -->
                <button
                  type="button"
                  class="flex flex-col items-center justify-center py-2 px-1 rounded-xl hover:bg-amber-50 dark:hover:bg-slate-600 text-amber-600 dark:text-amber-400 transition group"
                  :title="t('REPORT.COVERAGE.MAPS')"
                  @click="handleOpenGoogleMaps(selectedLead)"
                >
                  <div
                    class="w-9 h-9 rounded-full bg-amber-100 dark:bg-amber-900/40 flex items-center justify-center group-hover:scale-110 transition shadow-sm mb-1"
                  >
                    <i
                      class="i-lucide-map text-base text-amber-600 dark:text-amber-400"
                    />
                  </div>
                  <span class="text-[10px] font-bold">{{
                    t('REPORT.COVERAGE.MAPS')
                  }}</span>
                </button>
              </div>

              <!-- Cuerpo de la ficha con scroll -->
              <div class="flex-1 overflow-y-auto p-4 space-y-3.5 text-xs">
                <!-- Información de Contacto Directo -->
                <div
                  class="bg-slate-50 dark:bg-slate-700/40 p-3 rounded-xl border border-slate-200 dark:border-slate-600 space-y-2"
                >
                  <div class="flex items-center justify-between">
                    <div
                      class="flex items-center gap-2 text-slate-700 dark:text-slate-200 font-semibold"
                    >
                      <i class="i-lucide-user text-slate-400" />
                      <span>{{ selectedLead.contacto_sugerido }}</span>
                    </div>
                  </div>

                  <div
                    class="flex items-center justify-between pt-1 border-t border-slate-200/60 dark:border-slate-600/60"
                  >
                    <div
                      class="flex items-center gap-2 text-slate-800 dark:text-white font-mono font-bold"
                    >
                      <i class="i-lucide-phone text-xs text-blue-500" />
                      <span>{{
                        selectedLead.phone_number ||
                        t('REPORT.COVERAGE.NO_PHONE')
                      }}</span>
                    </div>
                    <button
                      v-if="selectedLead.phone_number"
                      type="button"
                      class="text-sky-600 hover:text-sky-700 p-1 rounded hover:bg-slate-200 dark:hover:bg-slate-600 transition"
                      :title="t('REPORT.COVERAGE.COPY_PHONE')"
                      @click="handleCopyPhone(selectedLead)"
                    >
                      <i class="i-lucide-copy text-xs" />
                    </button>
                  </div>

                  <div
                    class="flex items-start gap-2 text-slate-600 dark:text-slate-300 pt-1 border-t border-slate-200/60 dark:border-slate-600/60"
                  >
                    <i
                      class="i-lucide-map-pin text-xs text-rose-500 mt-0.5 shrink-0"
                    />
                    <div>
                      {{
                        selectedLead.ubicacion ||
                        t('REPORT.COVERAGE.NO_ADDRESS')
                      }}
                    </div>
                  </div>

                  <div
                    v-if="selectedLead.sitio_web"
                    class="flex items-center gap-2 pt-1 border-t border-slate-200/60 dark:border-slate-600/60"
                  >
                    <i class="i-lucide-globe text-xs text-slate-400" />
                    <a
                      :href="
                        selectedLead.sitio_web.startsWith('http')
                          ? selectedLead.sitio_web
                          : 'https://' + selectedLead.sitio_web
                      "
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sky-600 dark:text-sky-400 hover:underline truncate"
                    >
                      {{ selectedLead.sitio_web }}
                    </a>
                  </div>
                </div>

                <!-- Oferta / Propuesta de Valor Giantucchi -->
                <div
                  v-if="selectedLead.oferta_solucion"
                  class="bg-sky-50 dark:bg-sky-950/40 p-3 rounded-xl border border-sky-200 dark:border-sky-800/60 space-y-1.5"
                >
                  <div
                    class="flex items-center gap-1.5 text-sky-900 dark:text-sky-300 font-bold text-[11px] uppercase tracking-wider"
                  >
                    <i class="i-lucide-sparkles text-sky-500 text-xs" />
                    <span>{{ t('REPORT.COVERAGE.PROPOSAL') }}</span>
                  </div>
                  <p
                    class="text-slate-700 dark:text-slate-200 leading-relaxed text-[11px]"
                  >
                    {{ selectedLead.oferta_solucion }}
                  </p>
                </div>

                <!-- Mensaje de WhatsApp Enviado -->
                <div
                  v-if="selectedLead.mensaje_whatsapp"
                  class="bg-emerald-50 dark:bg-emerald-950/40 p-3 rounded-xl border border-emerald-200 dark:border-emerald-800/60 space-y-1.5"
                >
                  <div
                    class="flex items-center justify-between text-emerald-900 dark:text-emerald-300 font-bold text-[11px] uppercase tracking-wider"
                  >
                    <span class="flex items-center gap-1.5">
                      <i
                        class="i-lucide-message-circle text-emerald-600 text-xs"
                      />
                      <span>{{ t('REPORT.COVERAGE.SENT_MESSAGE') }}</span>
                    </span>
                    <span class="text-[10px] text-emerald-600 font-normal">{{
                      t('REPORT.COVERAGE.WHATSAPP')
                    }}</span>
                  </div>
                  <div
                    class="bg-white dark:bg-slate-800 p-2.5 rounded-lg border border-emerald-100 dark:border-emerald-900 text-slate-800 dark:text-slate-200 text-[11px] leading-relaxed italic"
                  >
                    {{ `"${selectedLead.mensaje_whatsapp}"` }}
                  </div>
                </div>

                <!-- Trazabilidad Comercial & Tiempos en Tiempo Real -->
                <div
                  class="bg-slate-50 dark:bg-slate-700/40 p-3 rounded-xl border border-slate-200 dark:border-slate-600 space-y-2"
                >
                  <div
                    class="text-[10px] font-bold uppercase tracking-wider text-slate-500"
                  >
                    {{ t('REPORT.COVERAGE.TRACEABILITY_TITLE') }}
                  </div>

                  <div class="grid grid-cols-2 gap-2 text-[11px]">
                    <div>
                      <span class="text-slate-400 block text-[10px]">{{
                        t('REPORT.COVERAGE.DATE_ENTERED')
                      }}</span>
                      <span
                        class="font-semibold text-slate-700 dark:text-slate-200"
                      >
                        {{ selectedLead.fecha_ingreso || '—' }}
                      </span>
                    </div>
                    <div>
                      <span class="text-slate-400 block text-[10px]">{{
                        t('REPORT.COVERAGE.DATE_SENT')
                      }}</span>
                      <span class="font-semibold text-emerald-600">
                        {{ selectedLead.fecha_envio || '—' }}
                      </span>
                    </div>
                  </div>

                  <div
                    class="grid grid-cols-2 gap-2 text-[11px] pt-1.5 border-t border-slate-200 dark:border-slate-600/50"
                  >
                    <div>
                      <span class="text-slate-400 block text-[10px]">{{
                        t('REPORT.COVERAGE.DATE_REPLIED')
                      }}</span>
                      <span class="font-semibold text-blue-600">
                        {{
                          selectedLead.fecha_respuesta ||
                          t('REPORT.COVERAGE.PENDING_RESPONSE')
                        }}
                      </span>
                    </div>
                    <div>
                      <span class="text-slate-400 block text-[10px]">{{
                        t('REPORT.COVERAGE.OPERATING_TIME')
                      }}</span>
                      <span
                        class="inline-flex items-center gap-1 font-bold text-slate-800 dark:text-white"
                      >
                        <i class="i-lucide-clock text-xs text-amber-500" />
                        {{ selectedLead.tiempo_operativo || '—' }}
                      </span>
                    </div>
                  </div>

                  <!-- Asesor Comercial Asignado -->
                  <div
                    class="pt-2 border-t border-slate-200 dark:border-slate-600/50 flex items-center justify-between"
                  >
                    <div class="flex items-center gap-2">
                      <div
                        class="w-6 h-6 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-[10px]"
                      >
                        {{ (selectedLead.agente || 'A').charAt(0) }}
                      </div>
                      <div>
                        <span
                          class="text-[10px] text-slate-400 block leading-tight"
                        >
                          {{ t('REPORT.COVERAGE.COMMERCIAL_ADVISOR') }}
                        </span>
                        <span
                          class="font-bold text-slate-800 dark:text-white leading-tight"
                        >
                          {{ selectedLead.agente }}
                        </span>
                      </div>
                    </div>

                    <span
                      class="px-2 py-0.5 rounded text-[10px] font-semibold"
                      :class="
                        selectedLead.contact_id
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-slate-200 text-slate-700'
                      "
                    >
                      {{
                        selectedLead.contact_id
                          ? t('REPORT.COVERAGE.LINKED_AIRM')
                          : t('REPORT.COVERAGE.SYNCED')
                      }}
                    </span>
                  </div>
                </div>
              </div>

              <!-- Pie de la ficha -->
              <div
                class="p-3 bg-slate-100 dark:bg-slate-700/80 border-t border-slate-200 dark:border-slate-600 shrink-0 flex gap-2"
              >
                <button
                  type="button"
                  class="flex-1 py-2 px-3 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-sm transition"
                  @click="handleOpenChat(selectedLead)"
                >
                  <i class="i-lucide-message-circle text-sm text-sky-400" />
                  <span>{{ t('REPORT.COVERAGE.OPEN_CHAT_IN_AIRM') }}</span>
                </button>
              </div>
            </aside>
          </transition>
        </div>
      </div>

      <!-- PESTAÑA 2: MÉTRICAS Y RENDIMIENTO NACIONAL -->
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
                {{ `${summary.tasa_contacto}%` }}
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
                        <span class="text-[11px] font-semibold w-8 text-right">
                          {{ `${r.pct}%` }}
                        </span>
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
                        <span class="text-[11px] font-semibold w-8 text-right">
                          {{ `${s.pct}%` }}
                        </span>
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
                      {{ `${a.tasa_respuesta}%` }}
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
