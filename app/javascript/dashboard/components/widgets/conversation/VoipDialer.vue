<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  voipState,
  makeCall,
  answerCall,
  hangupCall,
  toggleMute,
  sendDTMF,
  closeDialer,
  submitCallDisposition,
  skipCallDisposition,
} from 'dashboard/helper/voipHelper';

const { t } = useI18n();
const dialerNumber = ref('');
const isDTMFOpen = ref(false);
const selectedDisposition = ref('');
const syncWithConversation = ref(true);

const dispositionsList = [
  { value: 'Venta', label: 'Venta', effectiveOnly: true },
  { value: 'Interesado', label: 'Interesado', effectiveOnly: true },
  { value: 'Agendado', label: 'Agendado', effectiveOnly: true },
  { value: 'Volver a llamar', label: 'Volver a llamar', effectiveOnly: false },
  { value: 'Persona mayor', label: 'Persona mayor', effectiveOnly: false },
  { value: 'Saturación', label: 'Saturación', effectiveOnly: false },
  { value: 'No interesado', label: 'No interesado', effectiveOnly: false },
  { value: 'Buzón de voz', label: 'Buzón de voz', effectiveOnly: false },
  { value: 'No contesta', label: 'No contesta', effectiveOnly: false },
  {
    value: 'Número equivocado',
    label: 'Número equivocado',
    effectiveOnly: false,
  },
];

watch(
  () => voipState.remoteNumber,
  newVal => {
    if (newVal) dialerNumber.value = newVal;
  },
  { immediate: true }
);

watch(
  () => voipState.callState,
  state => {
    if (state === 'disposition') {
      if (voipState.lastCallCategory === 'ineffective') {
        selectedDisposition.value = 'No contesta';
      } else {
        selectedDisposition.value = '';
      }
    }
  }
);

const keypad = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['*', '0', '#'],
];

const formattedDuration = computed(() => {
  const mins = Math.floor(voipState.callDuration / 60);
  const secs = voipState.callDuration % 60;
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
});

const formattedLastDuration = computed(() => {
  const mins = Math.floor(voipState.lastCallDuration / 60);
  const secs = voipState.lastCallDuration % 60;
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
});

const isEffectiveCall = computed(
  () => voipState.lastCallCategory === 'effective'
);
const isTestCall = computed(() => voipState.lastCallCategory === 'test');

const isBusyByOther = computed(() => {
  const otherCalls = voipState.activeCalls.filter(
    c => c.status !== 'ended' && c.status !== 'failed'
  );
  return otherCalls.length > 0;
});

const activeCallInfo = computed(() => {
  return voipState.activeCalls.find(
    c => c.status !== 'ended' && c.status !== 'failed'
  );
});

const handleKeypadPress = key => {
  if (voipState.callState === 'connected') {
    sendDTMF(key);
  } else {
    dialerNumber.value += key;
  }
};

const handleBackspace = () => {
  dialerNumber.value = dialerNumber.value.slice(0, -1);
};

const handleCall = () => {
  const number = dialerNumber.value || voipState.remoteNumber;
  if (number) {
    makeCall(number, voipState.conversationId);
  }
};

const handleSaveDisposition = () => {
  submitCallDisposition({
    disposition: selectedDisposition.value,
    updateConversationTipificacion: syncWithConversation.value,
  });
  selectedDisposition.value = '';
};

const handleSkipDisposition = () => {
  skipCallDisposition();
  selectedDisposition.value = '';
};
</script>

<template>
  <div v-show="voipState.isDialerOpen">
    <div
      class="fixed bottom-6 right-6 z-50 w-80 rounded-2xl bg-white shadow-2xl ring-1 ring-black/10 dark:bg-slate-900 dark:ring-white/10"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between border-b border-slate-100 bg-slate-50/80 px-4 py-3 dark:border-slate-800 dark:bg-slate-800/50 rounded-t-2xl"
      >
        <div class="flex items-center gap-2">
          <div
            class="h-2.5 w-2.5 rounded-full"
            :class="
              voipState.isRegistered
                ? 'bg-emerald-500 animate-pulse'
                : 'bg-rose-500'
            "
          />
          <span
            class="text-xs font-semibold text-slate-700 dark:text-slate-200"
          >
            {{
              voipState.isRegistered
                ? t('VOIP_SETTINGS.DIALER.CONNECTED')
                : t('VOIP_SETTINGS.DIALER.DISCONNECTED')
            }}
          </span>
        </div>
        <button
          v-if="
            voipState.callState === 'idle' ||
            voipState.callState === 'disposition'
          "
          type="button"
          class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
          @click="
            voipState.callState === 'disposition'
              ? handleSkipDisposition()
              : closeDialer()
          "
        >
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Active Calls Banner (Concurrency Alert) -->
      <div
        v-if="isBusyByOther && voipState.callState === 'idle'"
        class="border-b border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/40 dark:text-amber-300"
      >
        <div class="flex items-center gap-1.5 font-medium">
          <i class="i-lucide-phone-call text-amber-600 dark:text-amber-400" />
          <span>
            {{
              t('VOIP_SETTINGS.DIALER.LINE_BUSY', {
                name: activeCallInfo?.agent_name,
              })
            }}
          </span>
        </div>
        <p class="mt-0.5 text-[11px] opacity-80">
          {{
            t('VOIP_SETTINGS.DIALER.CALLING_TO', {
              phone: activeCallInfo?.phone_number,
            })
          }}
        </p>
      </div>

      <!-- Screen / Status Section -->
      <div class="p-4 text-center">
        <!-- Incoming Call State -->
        <div v-if="voipState.callState === 'ringing'" class="space-y-3 py-2">
          <div
            class="inline-flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100 text-emerald-600 animate-bounce dark:bg-emerald-950 dark:text-emerald-400"
          >
            <i class="i-lucide-phone-incoming text-2xl" />
          </div>
          <div>
            <h4 class="text-sm font-bold text-slate-800 dark:text-slate-100">
              {{ t('VOIP_SETTINGS.DIALER.INCOMING_CALL') }}
            </h4>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ voipState.remoteDisplayName || voipState.remoteNumber }}
            </p>
          </div>
          <div class="flex justify-center gap-3 pt-2">
            <button
              type="button"
              class="flex items-center gap-1 rounded-full bg-emerald-600 px-4 py-2 text-xs font-semibold text-white shadow-md hover:bg-emerald-700"
              @click="answerCall"
            >
              <i class="i-lucide-phone text-sm" />
              <span>{{ t('VOIP_SETTINGS.DIALER.ANSWER') }}</span>
            </button>
            <button
              type="button"
              class="flex items-center gap-1 rounded-full bg-rose-600 px-4 py-2 text-xs font-semibold text-white shadow-md hover:bg-rose-700"
              @click="hangupCall"
            >
              <i class="i-lucide-phone-off text-sm" />
              <span>{{ t('VOIP_SETTINGS.DIALER.REJECT') }}</span>
            </button>
          </div>
        </div>

        <!-- Calling State (Early cancel button enabled instantly) -->
        <div
          v-else-if="voipState.callState === 'calling'"
          class="space-y-3 py-2"
        >
          <div
            class="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100 text-blue-600 animate-pulse dark:bg-blue-950 dark:text-blue-400"
          >
            <i class="i-lucide-phone-outgoing text-2xl animate-spin" />
          </div>
          <div>
            <h4 class="text-base font-bold text-slate-800 dark:text-slate-100">
              {{ voipState.remoteNumber }}
            </h4>
            <p class="text-xs font-medium text-blue-600 dark:text-blue-400">
              {{ t('VOIP_SETTINGS.DIALER.DIALING') }}
            </p>
          </div>
          <div class="pt-2">
            <button
              type="button"
              class="flex w-full items-center justify-center gap-2 rounded-xl bg-rose-600 py-2.5 text-xs font-bold text-white shadow-md transition hover:bg-rose-700 active:scale-95"
              @click="hangupCall"
            >
              <i class="i-lucide-phone-off text-base" />
              <span>{{ t('VOIP_SETTINGS.DIALER.CANCEL_CALL') }}</span>
            </button>
          </div>
        </div>

        <!-- In-Call Connected State -->
        <div
          v-else-if="voipState.callState === 'connected'"
          class="space-y-3 py-1"
        >
          <div
            class="inline-flex h-12 w-12 items-center justify-center rounded-full bg-blue-100 text-blue-600 dark:bg-blue-950 dark:text-blue-400"
          >
            <i class="i-lucide-phone text-2xl" />
          </div>
          <div>
            <h4 class="text-base font-bold text-slate-800 dark:text-slate-100">
              {{ voipState.remoteNumber }}
            </h4>
            <p
              class="text-xs font-mono font-medium text-emerald-600 dark:text-emerald-400"
            >
              {{ formattedDuration }}
            </p>
          </div>

          <!-- In-Call Actions -->
          <div class="flex items-center justify-center gap-3 pt-2">
            <button
              type="button"
              class="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 text-slate-600 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
              :class="{
                'bg-amber-100 border-amber-300 text-amber-700':
                  voipState.isMuted,
              }"
              @click="toggleMute"
            >
              <i
                :class="voipState.isMuted ? 'i-lucide-mic-off' : 'i-lucide-mic'"
                class="text-lg"
              />
            </button>

            <button
              type="button"
              class="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 text-slate-600 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
              :class="{
                'bg-blue-100 border-blue-300 text-blue-700': isDTMFOpen,
              }"
              @click="isDTMFOpen = !isDTMFOpen"
            >
              <i class="i-lucide-grid text-lg" />
            </button>

            <button
              type="button"
              class="flex h-10 w-10 items-center justify-center rounded-full bg-rose-600 text-white shadow-md hover:bg-rose-700"
              :title="t('VOIP_SETTINGS.DIALER.HANGUP')"
              @click="hangupCall"
            >
              <i class="i-lucide-phone-off text-lg" />
            </button>
          </div>
        </div>

        <!-- Post-Call Disposition Card State -->
        <div
          v-else-if="voipState.callState === 'disposition'"
          class="space-y-3 text-left py-1"
        >
          <div
            class="text-center pb-2 border-b border-slate-100 dark:border-slate-800"
          >
            <div class="flex items-center justify-center gap-1.5 mb-1">
              <span
                v-if="isEffectiveCall"
                class="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[11px] font-bold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
              >
                <i class="i-lucide-check-circle text-xs" />
                {{ t('VOIP_SETTINGS.DIALER.EFFECTIVE_BADGE') }}
              </span>
              <span
                v-else-if="isTestCall"
                class="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-800 dark:bg-amber-950 dark:text-amber-300"
              >
                <i class="i-lucide-alert-circle text-xs" />
                {{ t('VOIP_SETTINGS.DIALER.TEST_BADGE') }}
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 rounded-full bg-rose-100 px-2 py-0.5 text-[11px] font-bold text-rose-800 dark:bg-rose-950 dark:text-rose-300"
              >
                <i class="i-lucide-x-circle text-xs" />
                {{ t('VOIP_SETTINGS.DIALER.INEFFECTIVE_BADGE') }}
              </span>
              <span class="text-xs font-mono font-semibold text-slate-500">
                {{ formattedLastDuration }}
              </span>
            </div>
            <h4 class="text-sm font-bold text-slate-800 dark:text-slate-100">
              {{ t('VOIP_SETTINGS.DIALER.DISPOSITION_TITLE') }}
            </h4>
            <p class="text-[11px] text-slate-500 dark:text-slate-400">
              {{ voipState.remoteNumber }}
            </p>
          </div>

          <div>
            <label
              class="block text-[11px] font-semibold text-slate-700 dark:text-slate-300 mb-1"
            >
              {{ t('VOIP_SETTINGS.DIALER.DISPOSITION_LABEL') }}
            </label>
            <select
              v-model="selectedDisposition"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-2.5 py-1.5 text-xs text-slate-800 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
            >
              <option value="" disabled>
                {{ t('VOIP_SETTINGS.DIALER.DISPOSITION_PLACEHOLDER') }}
              </option>
              <optgroup :label="t('VOIP_SETTINGS.DIALER.COMMERCIAL_GROUP')">
                <option
                  v-for="disp in dispositionsList.filter(d => d.effectiveOnly)"
                  :key="disp.value"
                  :value="disp.value"
                >
                  {{ disp.label }}
                  {{
                    !isEffectiveCall
                      ? t('VOIP_SETTINGS.DIALER.NOT_EFFECTIVE_HINT')
                      : ''
                  }}
                </option>
              </optgroup>
              <optgroup :label="t('VOIP_SETTINGS.DIALER.CASUISTICS_GROUP')">
                <option
                  v-for="disp in dispositionsList.filter(d => !d.effectiveOnly)"
                  :key="disp.value"
                  :value="disp.value"
                >
                  {{ disp.label }}
                </option>
              </optgroup>
            </select>
          </div>

          <div
            v-if="voipState.conversationId"
            class="flex items-center gap-2 pt-1"
          >
            <input
              id="sync-conversation-tipificacion"
              v-model="syncWithConversation"
              type="checkbox"
              class="h-3.5 w-3.5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
            />
            <label
              for="sync-conversation-tipificacion"
              class="text-[11px] font-medium text-slate-600 dark:text-slate-300 cursor-pointer"
            >
              {{ t('VOIP_SETTINGS.DIALER.SYNC_CONVERSATION') }}
            </label>
          </div>

          <div class="flex items-center gap-2 pt-2">
            <button
              type="button"
              :disabled="!selectedDisposition"
              class="flex-1 rounded-xl bg-blue-600 py-2 text-xs font-bold text-white shadow transition hover:bg-blue-700 disabled:opacity-50"
              @click="handleSaveDisposition"
            >
              {{ t('VOIP_SETTINGS.DIALER.SAVE_DISPOSITION') }}
            </button>
            <button
              type="button"
              class="rounded-xl border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
              @click="handleSkipDisposition"
            >
              {{ t('VOIP_SETTINGS.DIALER.SKIP') }}
            </button>
          </div>
        </div>

        <!-- Call Ended State -->
        <div v-else-if="voipState.callState === 'ended'" class="py-4">
          <p class="text-sm font-semibold text-rose-600 dark:text-rose-400">
            {{ t('VOIP_SETTINGS.DIALER.CALL_ENDED') }}
          </p>
        </div>

        <!-- Idle / Dialing Pad State -->
        <div v-else class="space-y-3">
          <div class="relative">
            <input
              v-model="dialerNumber"
              type="text"
              :placeholder="t('VOIP_SETTINGS.DIALER.DIAL_PLACEHOLDER')"
              class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 pr-9 text-center text-lg font-semibold tracking-wider text-slate-800 focus:border-blue-500 focus:bg-white focus:outline-none dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100"
              @keydown.enter="handleCall"
            />
            <button
              v-if="dialerNumber"
              type="button"
              class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
              @click="handleBackspace"
            >
              <i class="i-lucide-delete text-base" />
            </button>
          </div>

          <!-- Keypad Grid -->
          <div class="grid grid-cols-3 gap-2 px-2">
            <template v-for="(row, rIdx) in keypad" :key="rIdx">
              <button
                v-for="key in row"
                :key="key"
                type="button"
                class="flex h-10 items-center justify-center rounded-xl bg-slate-100 text-base font-bold text-slate-700 transition hover:bg-blue-50 hover:text-blue-600 active:scale-95 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
                @click="handleKeypadPress(key)"
              >
                {{ key }}
              </button>
            </template>
          </div>

          <!-- Call Button -->
          <div class="pt-2">
            <button
              type="button"
              :disabled="!dialerNumber && !voipState.remoteNumber"
              class="flex w-full items-center justify-center gap-2 rounded-xl bg-emerald-600 py-2.5 font-bold text-white shadow-md transition hover:bg-emerald-700 disabled:opacity-50"
              @click="handleCall"
            >
              <i class="i-lucide-phone text-lg" />
              <span>{{ t('VOIP_SETTINGS.DIALER.CALL') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
