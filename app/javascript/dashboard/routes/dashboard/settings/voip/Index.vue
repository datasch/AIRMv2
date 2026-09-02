<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import PageHeader from '../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoipAPI from 'dashboard/api/voip';
import { useAlert } from 'dashboard/composables';
import { initVoIP } from 'dashboard/helper/voipHelper';

const { t } = useI18n();

const isSavingConfig = ref(false);
const isSavingAgent = ref({});
const isCopied = ref(false);

const voipConfig = ref({
  enabled: true,
  ws_url: 'wss://voip.giantucchi.com:8089/ws',
  sip_domain: 'giantucchi.com',
  caller_id: '51913086096',
  concurrency_limit: 1,
  trunk_provider: 'voiprabbit',
  trunk_host: '149.20.185.4',
  trunk_port: 5060,
  trunk_user: 'JoseMaster',
  trunk_password: '',
  trunk_auth_mode: 'credentials',
  gateway_ip: '',
});

const agents = ref([]);

const fetchVoipData = async () => {
  try {
    const [configRes, agentsRes] = await Promise.all([
      VoipAPI.getConfig(),
      VoipAPI.getAgents(),
    ]);

    if (configRes.data) {
      voipConfig.value = {
        enabled: configRes.data.enabled !== false,
        ws_url: configRes.data.ws_url || 'wss://voip.giantucchi.com:8089/ws',
        sip_domain: configRes.data.sip_domain || 'giantucchi.com',
        caller_id: configRes.data.caller_id || '51913086096',
        concurrency_limit: configRes.data.concurrency_limit || 1,
        trunk_provider: configRes.data.trunk_provider || 'voiprabbit',
        trunk_host: configRes.data.trunk_host || '149.20.185.4',
        trunk_port: configRes.data.trunk_port || 5060,
        trunk_user: configRes.data.trunk_user || 'JoseMaster',
        trunk_password: configRes.data.trunk_password || '',
        trunk_auth_mode: configRes.data.trunk_auth_mode || 'credentials',
        gateway_ip: configRes.data.gateway_ip || window.location.hostname,
      };
    }

    if (agentsRes.data?.agents) {
      agents.value = agentsRes.data.agents.map(a => ({
        ...a,
        extension: a.extension || '',
        password: '',
      }));
    }
  } catch (error) {
    useAlert(error.message || 'Error');
  }
};

const saveConfig = async () => {
  isSavingConfig.value = true;
  try {
    await VoipAPI.updateConfig(voipConfig.value);
    useAlert(t('VOIP_SETTINGS.SAVE_SUCCESS'));
    initVoIP();
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isSavingConfig.value = false;
  }
};

const saveAgent = async agent => {
  isSavingAgent.value[agent.id] = true;
  try {
    await VoipAPI.updateAgent({
      userId: agent.id,
      extension: agent.extension,
      password: agent.password,
    });
    useAlert(t('VOIP_SETTINGS.SAVE_AGENT_SUCCESS'));
    initVoIP();
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isSavingAgent.value[agent.id] = false;
  }
};

const copyGatewayIp = () => {
  if (!voipConfig.value.gateway_ip) return;
  navigator.clipboard.writeText(voipConfig.value.gateway_ip);
  isCopied.value = true;
  setTimeout(() => {
    isCopied.value = false;
  }, 2500);
};

onMounted(() => {
  fetchVoipData();
});
</script>

<template>
  <div class="h-full overflow-y-auto p-6">
    <PageHeader
      :header-title="t('VOIP_SETTINGS.HEADER_TITLE')"
      :header-content="t('VOIP_SETTINGS.HEADER_CONTENT')"
    />

    <div class="mt-6 max-w-4xl space-y-8">
      <!-- Banner informativo / Instrucciones de Troncal -->
      <div
        class="rounded-2xl border border-blue-500/20 bg-blue-500/5 p-6 dark:border-blue-500/30 dark:bg-blue-500/10"
      >
        <div class="flex items-start gap-4">
          <div
            class="flex items-center justify-center w-10 h-10 rounded-xl bg-blue-500/10 text-blue-500 shrink-0"
          >
            <i class="i-lucide-globe text-xl" />
          </div>
          <div class="flex-1">
            <h4 class="text-sm font-bold text-slate-900 dark:text-slate-100">
              {{ t('VOIP_SETTINGS.GATEWAY_IP_TITLE') }}
            </h4>
            <p class="mt-1 text-xs text-slate-600 dark:text-slate-300">
              {{ t('VOIP_SETTINGS.GATEWAY_IP_DESC') }}
            </p>
            <div class="mt-3 flex items-center gap-3">
              <div
                class="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3.5 py-1.5 font-mono text-xs font-semibold text-slate-900 shadow-sm dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
              >
                <span>{{ voipConfig.gateway_ip }}</span>
              </div>
              <button
                type="button"
                class="inline-flex items-center gap-1.5 rounded-xl border border-blue-600/30 bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-blue-700 transition-colors"
                @click="copyGatewayIp"
              >
                <span>
                  {{
                    isCopied
                      ? t('VOIP_SETTINGS.GATEWAY_IP_COPIED')
                      : t('VOIP_SETTINGS.GATEWAY_IP_COPY')
                  }}
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Troncal SIP Proveedor (VoIPRabbit / Asterisk / Vicidial) -->
      <div
        class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div class="border-b border-slate-100 pb-4 dark:border-slate-800">
          <h3 class="text-base font-bold text-slate-900 dark:text-slate-100">
            {{ t('VOIP_SETTINGS.TRUNK_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ t('VOIP_SETTINGS.TRUNK_DESC') }}
          </p>
        </div>

        <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.TRUNK_HOST_LABEL') }}
            </label>
            <input
              v-model="voipConfig.trunk_host"
              type="text"
              :placeholder="t('VOIP_SETTINGS.TRUNK_HOST_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.TRUNK_PORT_LABEL') }}
            </label>
            <input
              v-model.number="voipConfig.trunk_port"
              type="number"
              :placeholder="t('VOIP_SETTINGS.TRUNK_PORT_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.TRUNK_USER_LABEL') }}
            </label>
            <input
              v-model="voipConfig.trunk_user"
              type="text"
              :placeholder="t('VOIP_SETTINGS.TRUNK_USER_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.TRUNK_PASS_LABEL') }}
            </label>
            <input
              v-model="voipConfig.trunk_password"
              type="password"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
          </div>
        </div>
      </div>

      <!-- General PBX Settings Card -->
      <div
        class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div
          class="flex items-center justify-between border-b border-slate-100 pb-4 dark:border-slate-800"
        >
          <div>
            <h3 class="text-base font-bold text-slate-900 dark:text-slate-100">
              {{ t('VOIP_SETTINGS.PBX_SERVER_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('VOIP_SETTINGS.PBX_SERVER_DESC') }}
            </p>
          </div>
          <label class="relative inline-flex cursor-pointer items-center">
            <input
              v-model="voipConfig.enabled"
              type="checkbox"
              class="peer sr-only"
            />
            <div
              class="peer h-6 w-11 rounded-full bg-slate-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-slate-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-600 peer-checked:after:translate-x-full peer-checked:after:border-white dark:bg-slate-700"
            />
            <span
              class="ml-2 text-xs font-semibold text-slate-700 dark:text-slate-300"
            >
              {{
                voipConfig.enabled
                  ? t('VOIP_SETTINGS.ACTIVE')
                  : t('VOIP_SETTINGS.INACTIVE')
              }}
            </span>
          </label>
        </div>

        <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.CALLER_ID_LABEL') }}
            </label>
            <input
              v-model="voipConfig.caller_id"
              type="text"
              :placeholder="t('VOIP_SETTINGS.CALLER_ID_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
            <p class="mt-1 text-[11px] text-slate-400">
              {{ t('VOIP_SETTINGS.CALLER_ID_HELP') }}
            </p>
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.CONCURRENCY_LIMIT_LABEL') }}
            </label>
            <input
              v-model.number="voipConfig.concurrency_limit"
              type="number"
              min="1"
              max="100"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
            <p class="mt-1 text-[11px] text-slate-400">
              {{ t('VOIP_SETTINGS.CONCURRENCY_LIMIT_HELP') }}
            </p>
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.WS_URL_LABEL') }}
            </label>
            <input
              v-model="voipConfig.ws_url"
              type="text"
              :placeholder="t('VOIP_SETTINGS.WS_URL_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
            <p class="mt-1 text-[11px] text-slate-400">
              {{ t('VOIP_SETTINGS.WS_URL_HELP') }}
            </p>
          </div>

          <div>
            <label
              class="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.SIP_DOMAIN_LABEL') }}
            </label>
            <input
              v-model="voipConfig.sip_domain"
              type="text"
              :placeholder="t('VOIP_SETTINGS.SIP_DOMAIN_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            />
            <p class="mt-1 text-[11px] text-slate-400">
              {{ t('VOIP_SETTINGS.SIP_DOMAIN_HELP') }}
            </p>
          </div>
        </div>

        <div class="mt-6 flex justify-end">
          <NextButton
            :label="t('VOIP_SETTINGS.SAVE_PBX')"
            :is-loading="isSavingConfig"
            @click="saveConfig"
          />
        </div>
      </div>

      <!-- Agent Extensions Table Card -->
      <div
        class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <div class="border-b border-slate-100 pb-4 dark:border-slate-800">
          <h3 class="text-base font-bold text-slate-900 dark:text-slate-100">
            {{ t('VOIP_SETTINGS.AGENT_EXTENSIONS_TITLE') }}
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ t('VOIP_SETTINGS.AGENT_EXTENSIONS_DESC') }}
          </p>
        </div>

        <div class="mt-4 divide-y divide-slate-100 dark:divide-slate-800">
          <div
            v-for="agent in agents"
            :key="agent.id"
            class="flex flex-col gap-4 py-4 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="min-w-[180px]">
              <div class="font-semibold text-slate-900 dark:text-slate-100">
                {{ agent.name }}
              </div>
              <div class="text-xs text-slate-400">
                {{ `${agent.email} (${agent.role})` }}
              </div>
            </div>

            <div class="flex flex-wrap items-center gap-3">
              <input
                v-model="agent.extension"
                type="text"
                :placeholder="t('VOIP_SETTINGS.EXT_PLACEHOLDER')"
                class="w-32 rounded-xl border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
              />
              <input
                v-model="agent.password"
                type="password"
                :placeholder="t('VOIP_SETTINGS.PASS_PLACEHOLDER')"
                class="w-36 rounded-xl border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs text-slate-900 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
              />
              <NextButton
                size="sm"
                :label="t('VOIP_SETTINGS.SAVE_AGENT')"
                :is-loading="isSavingAgent[agent.id]"
                @click="saveAgent(agent)"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
