<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import GowaAPI from 'dashboard/api/gowa';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();

const channelName = ref('');
const deviceId = ref('');
const isGeneratingQR = ref(false);
const isCreatingInbox = ref(false);
const qrLink = ref('');
const qrDuration = ref(30);
const qrCountdown = ref(30);
const isConnected = ref(false);
const step = ref(1); // 1: Name input, 2: QR scan & pair
let countdownInterval = null;
let pollStatusInterval = null;

const isValidName = computed(() => channelName.value.trim().length > 0);

const generateDeviceId = () => {
  const accId = accountId.value || '';
  const randomSuffix = Math.random().toString(36).substring(2, 8);
  return accId ? `acc_${accId}_${randomSuffix}` : `gowa_device_${randomSuffix}`;
};

const startCountdown = duration => {
  clearInterval(countdownInterval);
  qrCountdown.value = duration || 30;
  countdownInterval = setInterval(() => {
    if (qrCountdown.value > 0) {
      qrCountdown.value -= 1;
    } else {
      clearInterval(countdownInterval);
    }
  }, 1000);
};

const pollConnectionStatus = () => {
  clearInterval(pollStatusInterval);
  pollStatusInterval = setInterval(async () => {
    if (!deviceId.value || step.value !== 2) return;
    try {
      const response = await GowaAPI.getStatus(deviceId.value);
      const state = response.data?.state || '';
      const isReady = response.data?.connected ||
                      response.data?.is_logged_in ||
                      response.data?.is_connected ||
                      ['open', 'connected'].includes(state.toLowerCase());

      if (isReady) {
        isConnected.value = true;
        clearInterval(pollStatusInterval);
        clearInterval(countdownInterval);
        useAlert(
          t(
            'INBOX_MGMT.ADD.GOWA.CONNECTED_SUCCESS',
            '¡WhatsApp conectado exitosamente!'
          )
        );
        // Automatically proceed to finish inbox creation
        await createGowaInbox();
      }
    } catch {
      // Keep polling silently
    }
  }, 3000);
};

const requestQRCode = async () => {
  if (!isValidName.value) return;

  if (!deviceId.value) {
    deviceId.value = generateDeviceId();
  }

  isGeneratingQR.value = true;
  step.value = 2;

  try {
    const response = await GowaAPI.getPairingQR(deviceId.value);
    if (response.data?.success && response.data?.qr_link) {
      qrLink.value = response.data.qr_link;
      qrDuration.value = response.data.qr_duration || 40;
      startCountdown(qrDuration.value);
      pollConnectionStatus();
    } else {
      useAlert(
        response.data?.error ||
          t(
            'INBOX_MGMT.ADD.GOWA.QR_ERROR',
            'No se pudo generar el código QR. Verifique que la pasarela Evolution API esté activa.'
          )
      );
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        error.message ||
        t(
          'INBOX_MGMT.ADD.GOWA.QR_ERROR',
          'Error al conectar con la pasarela de WhatsApp.'
        )
    );
  } finally {
    isGeneratingQR.value = false;
  }
};

const createGowaInbox = async () => {
  if (isCreatingInbox.value) return;
  isCreatingInbox.value = true;

  try {
    const response = await GowaAPI.createInbox({
      name: channelName.value.trim(),
      deviceId: deviceId.value,
    });

    if (response.data?.success && response.data?.inbox_id) {
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: {
          page: 'new',
          inbox_id: response.data.inbox_id,
        },
      });
    } else {
      useAlert(
        response.data?.error ||
          t('INBOX_MGMT.ADD.GOWA.CREATE_ERROR', 'Error al crear la bandeja')
      );
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        error.message ||
        t('INBOX_MGMT.ADD.GOWA.CREATE_ERROR', 'Error al crear la bandeja')
    );
  } finally {
    isCreatingInbox.value = false;
  }
};

onMounted(() => {
  deviceId.value = generateDeviceId();
});

onUnmounted(() => {
  clearInterval(countdownInterval);
  clearInterval(pollStatusInterval);
});
</script>

<template>
  <div class="overflow-auto col-span-6 p-6 w-full h-full">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.GOWA.TITLE', 'Conectar WhatsApp (Código QR / Evolution API)')"
      :header-content="
        $t(
          'INBOX_MGMT.ADD.GOWA.DESC',
          'Vincule cualquier cuenta de WhatsApp escaneando un código QR utilizando la pasarela multidispositivo de alta estabilidad Evolution API.'
        )
      "
    />

    <!-- Step 1: Channel Information -->
    <div v-if="step === 1" class="max-w-xl">
      <form class="flex flex-col gap-5" @submit.prevent="requestQRCode">
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1.5">
            {{ $t('INBOX_MGMT.ADD.GOWA.CHANNEL_NAME.LABEL', 'Nombre de la Bandeja') }}
            <span class="text-red-500">*</span>
          </label>
          <input
            v-model="channelName"
            type="text"
            class="block w-full rounded-md border border-slate-200 px-3 py-2.5 text-sm outline-none focus:border-woot-500 focus:ring-1 focus:ring-woot-500 dark:bg-slate-800 dark:border-slate-700 dark:text-white"
            :placeholder="
              $t('INBOX_MGMT.ADD.GOWA.CHANNEL_NAME.PLACEHOLDER', 'ej. WhatsApp Ventas o Atención al Cliente')
            "
            required
            autofocus
          />
          <p class="mt-1 text-xs text-n-slate-10">
            {{
              $t(
                'INBOX_MGMT.ADD.GOWA.CHANNEL_NAME.SUBTITLE',
                'Un nombre identificativo para esta línea de WhatsApp dentro de AIRM.'
              )
            }}
          </p>
        </div>

        <div class="p-4 bg-cyan-50/50 border border-cyan-200 rounded-xl dark:bg-cyan-950/20 dark:border-cyan-800">
          <div class="flex items-start gap-3">
            <span class="text-xl">📱</span>
            <div class="text-sm text-cyan-900 dark:text-cyan-200">
              <strong class="font-semibold block mb-1">
                {{ $t('INBOX_MGMT.ADD.GOWA.INFO_TITLE', 'Conexión Directa Multidispositivo') }}
              </strong>
              {{
                $t(
                  'INBOX_MGMT.ADD.GOWA.INFO_DESC',
                  'No requiere cuenta de desarrollador de Meta ni aprobación de plantillas. Al hacer clic en Continuar, se generará un código QR que podrá escanear directamente con la cámara de WhatsApp en su teléfono (Dispositivos Vinculados).'
                )
              }}
            </div>
          </div>
        </div>

        <div class="mt-2">
          <NextButton
            type="submit"
            solid
            blue
            :disabled="!isValidName || isGeneratingQR"
            :is-loading="isGeneratingQR"
            :label="$t('INBOX_MGMT.ADD.GOWA.PROCEED_BUTTON', 'Generar Código QR')"
          />
        </div>
      </form>
    </div>

    <!-- Step 2: Live QR Scanner -->
    <div v-else-if="step === 2" class="max-w-xl">
      <div class="bg-white dark:bg-slate-800 rounded-2xl border border-n-weak p-6 shadow-sm flex flex-col items-center text-center">
        <h3 class="text-base font-semibold text-n-slate-12 mb-1">
          {{ $t('INBOX_MGMT.ADD.GOWA.SCAN_TITLE', 'Escanee el Código QR con WhatsApp') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-6 max-w-md">
          {{
            $t(
              'INBOX_MGMT.ADD.GOWA.SCAN_INSTRUCTION',
              'Abra WhatsApp en su teléfono > Ajustes o Menú (tres puntos) > Dispositivos Vinculados > Vincular un dispositivo, y apunte la cámara al siguiente código.'
            )
          }}
        </p>

        <!-- QR Box -->
        <div class="relative flex items-center justify-center size-64 bg-slate-50 dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-700 p-4 mb-4 shadow-inner">
          <Spinner v-if="isGeneratingQR" class="size-8 text-woot-500" />
          <img
            v-else-if="qrLink"
            :src="qrLink"
            alt="WhatsApp QR Code"
            class="size-full object-contain rounded-lg"
          />
          <div v-else class="text-sm text-slate-400">
            {{ $t('INBOX_MGMT.ADD.GOWA.NO_QR', 'Esperando código...') }}
          </div>
        </div>

        <!-- Timer & Controls -->
        <div class="flex items-center gap-3 mb-6">
          <div
            class="flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium"
            :class="qrCountdown > 0 ? 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200' : 'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200'"
          >
            <span class="size-2 rounded-full bg-current animate-pulse" />
            <span>
              {{
                qrCountdown > 0
                  ? `${$t('INBOX_MGMT.ADD.GOWA.QR_EXPIRES_IN', 'Expira en:')} ${qrCountdown}s`
                  : $t('INBOX_MGMT.ADD.GOWA.QR_EXPIRED', 'Código expirado')
              }}
            </span>
          </div>

          <button
            type="button"
            class="text-xs text-woot-500 hover:text-woot-600 font-medium underline cursor-pointer"
            :disabled="isGeneratingQR"
            @click="requestQRCode"
          >
            {{ $t('INBOX_MGMT.ADD.GOWA.REFRESH_QR', 'Actualizar Código') }}
          </button>
        </div>

        <!-- Connection Status Indicator -->
        <div v-if="isConnected" class="flex items-center gap-2 p-3 bg-green-50 text-green-800 border border-green-200 rounded-xl text-sm font-medium mb-4 dark:bg-green-950/40 dark:border-green-800 dark:text-green-200">
          <span>✅</span>
          <span>{{ $t('INBOX_MGMT.ADD.GOWA.CONNECTED', '¡Dispositivo conectado con éxito! Finalizando configuración...') }}</span>
        </div>

        <!-- Action buttons -->
        <div class="flex gap-3 w-full justify-center">
          <NextButton
            outline
            slate
            :label="$t('INBOX_MGMT.ADD.GOWA.BACK', 'Volver')"
            @click="step = 1"
          />
          <NextButton
            solid
            blue
            :is-loading="isCreatingInbox"
            :disabled="isCreatingInbox"
            :label="$t('INBOX_MGMT.ADD.GOWA.FINISH_BUTTON', 'Crear Bandeja y Asignar Agentes')"
            @click="createGowaInbox"
          />
        </div>
      </div>
    </div>
  </div>
</template>
