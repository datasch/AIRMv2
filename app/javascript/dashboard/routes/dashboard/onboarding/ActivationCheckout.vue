<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  PLANS,
  CURRENCIES,
  detectDefaultCurrency,
} from './shared/pricingConfig';
import { useCulqiCheckout } from 'dashboard/composables/useCulqiCheckout';

defineProps({
  salespersonName: {
    type: String,
    default: '',
  },
  companyName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['completed', 'skip']);

const { t } = useI18n();
const { initCulqi, openCheckout } = useCulqiCheckout();

const selectedCurrency = ref(detectDefaultCurrency());
const selectedPlanId = ref('pilot_3_days');
const isProcessing = ref(false);
const isPaidSuccess = ref(false);

onMounted(() => {
  const culqiKey =
    window.chatwootConfig?.culqiPublicKey || 'pk_live_airm_default';
  initCulqi(culqiKey);
});

const selectedPlan = computed(() => PLANS[selectedPlanId.value]);

const currentPrice = computed(() => {
  const plan = selectedPlan.value;
  return plan.pricing[selectedCurrency.value] || plan.pricing.PEN;
});

const changeCurrency = code => {
  selectedCurrency.value = code;
  try {
    sessionStorage.setItem('airm_preferred_currency', code);
  } catch {
    // Ignore error
  }
};

const handlePayment = () => {
  isProcessing.value = true;
  const price = currentPrice.value;

  openCheckout({
    title: t(selectedPlan.value.titleKey),
    currency: selectedCurrency.value,
    amountCents: price.amountCents,
    onSuccess: () => {
      isProcessing.value = false;
      isPaidSuccess.value = true;
      setTimeout(() => {
        emit('completed', {
          planId: selectedPlanId.value,
          currency: selectedCurrency.value,
          amount: price.amount,
        });
      }, 1200);
    },
    onError: () => {
      isProcessing.value = false;
    },
  });
};
</script>

<template>
  <div class="max-w-2xl mx-auto py-4 px-2">
    <!-- SUCCESS STATE -->
    <div
      v-if="isPaidSuccess"
      class="text-center py-12 bg-white dark:bg-n-solid-2 border border-n-strong rounded-2xl p-8 shadow-sm"
    >
      <div
        class="w-16 h-16 bg-emerald-100 dark:bg-emerald-950/50 text-emerald-600 rounded-full flex items-center justify-center mx-auto mb-4"
      >
        <Icon icon="i-lucide-check-circle" class="w-10 h-10" />
      </div>
      <h2 class="text-2xl font-bold text-n-slate-12 mb-2">
        {{ $t('REGISTER.ACTIVATION.SUCCESS_TITLE') }}
      </h2>
      <p class="text-n-slate-11 text-sm max-w-md mx-auto mb-6">
        {{ $t('REGISTER.ACTIVATION.SUCCESS_DESC') }}
      </p>
      <div class="flex justify-center">
        <NextButton
          lg
          class="font-semibold"
          :label="$t('REGISTER.ACTIVATION.CONTINUE_BUTTON')"
          @click="emit('completed', { planId: selectedPlanId })"
        />
      </div>
    </div>

    <!-- MAIN CHECKOUT PAYWALL -->
    <div
      v-else
      class="bg-white dark:bg-n-solid-2 border border-n-strong rounded-2xl p-6 sm:p-8 shadow-sm"
    >
      <!-- HEADER -->
      <div
        class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-n-weak"
      >
        <div>
          <span
            class="text-[11px] font-bold text-n-brand uppercase tracking-wider bg-n-brand/10 px-2.5 py-1 rounded-full"
          >
            {{ $t('REGISTER.ACTIVATION.BADGE') }}
          </span>
          <h1 class="text-xl sm:text-2xl font-bold text-n-slate-12 mt-2">
            {{ $t('REGISTER.ACTIVATION.TITLE') }}
          </h1>
          <p class="text-xs sm:text-sm text-n-slate-11 mt-0.5">
            <span v-if="companyName" class="font-medium text-n-slate-12 mr-1">
              {{ companyName }}
            </span>
            {{ $t('REGISTER.ACTIVATION.SUBTITLE') }}
          </p>
        </div>

        <!-- CURRENCY SWITCHER -->
        <div
          class="flex items-center bg-n-alpha-1 border border-n-strong rounded-xl p-1 shrink-0 self-start sm:self-auto"
        >
          <button
            type="button"
            class="px-3 py-1 rounded-lg text-xs font-semibold transition-colors"
            :class="
              selectedCurrency === CURRENCIES.PEN.code
                ? 'bg-white dark:bg-n-solid-3 text-n-brand shadow-sm'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="changeCurrency(CURRENCIES.PEN.code)"
          >
            {{ $t('REGISTER.ACTIVATION.CURRENCY_PEN') }}
          </button>
          <button
            type="button"
            class="px-3 py-1 rounded-lg text-xs font-semibold transition-colors"
            :class="
              selectedCurrency === CURRENCIES.USD.code
                ? 'bg-white dark:bg-n-solid-3 text-n-brand shadow-sm'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="changeCurrency(CURRENCIES.USD.code)"
          >
            {{ $t('REGISTER.ACTIVATION.CURRENCY_USD') }}
          </button>
        </div>
      </div>

      <!-- SALESPERSON ASSIGNED BANNER -->
      <div
        v-if="salespersonName"
        class="my-5 p-3.5 bg-n-alpha-1 border border-n-strong rounded-xl flex items-center gap-3 text-sm text-n-slate-12"
      >
        <div
          class="w-8 h-8 rounded-full bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0 font-bold"
        >
          <Icon icon="i-lucide-user-check" class="w-4 h-4 text-n-brand" />
        </div>
        <div class="flex-1 min-w-0">
          <div
            class="text-[11px] uppercase tracking-wider text-n-slate-11 font-medium"
          >
            {{ $t('REGISTER.SALESPERSON.ASSIGNED_LABEL') }}
          </div>
          <div class="font-semibold text-n-slate-12 truncate">
            {{ salespersonName }}
          </div>
        </div>
        <span
          class="text-xs bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 px-2.5 py-0.5 rounded-full font-medium"
        >
          {{ $t('REGISTER.ACTIVATION.PROMO_APPLIED') }}
        </span>
      </div>

      <!-- PLAN CARD (FEATURED) -->
      <div
        class="mt-6 border-2 border-n-brand rounded-2xl p-5 bg-n-brand/5 relative"
      >
        <div
          class="absolute -top-3 right-4 bg-n-brand text-white text-[11px] font-bold uppercase tracking-wider px-3 py-0.5 rounded-full shadow-sm"
        >
          {{ $t('REGISTER.ACTIVATION.RECOMMENDED') }}
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4"
        >
          <div>
            <h3 class="text-lg font-bold text-n-slate-12">
              {{ $t(selectedPlan.titleKey) }}
            </h3>
            <p class="text-xs text-n-slate-11 mt-0.5">
              {{ $t(selectedPlan.descKey) }}
            </p>
          </div>
          <div class="text-left sm:text-right">
            <div class="text-2xl font-black text-n-slate-12">
              {{ currentPrice.formatted }}
            </div>
            <div class="text-[11px] text-n-slate-10 font-medium">
              {{ $t(currentPrice.periodKey) }}
            </div>
          </div>
        </div>

        <ul class="space-y-2 border-t border-n-brand/20 pt-4 mb-2">
          <li
            v-for="(feat, idx) in selectedPlan.features"
            :key="idx"
            class="flex items-center gap-2 text-xs sm:text-sm text-n-slate-12"
          >
            <Icon
              icon="i-lucide-check"
              class="w-4 h-4 text-emerald-600 shrink-0"
            />
            <span>{{ $t(feat) }}</span>
          </li>
        </ul>
      </div>

      <!-- PAYMENT METHODS BADGES -->
      <div
        class="mt-6 p-4 bg-n-alpha-1 rounded-xl border border-n-weak text-xs text-n-slate-11"
      >
        <div
          class="font-semibold text-n-slate-12 mb-2 flex items-center gap-1.5"
        >
          <Icon icon="i-lucide-shield-check" class="w-4 h-4 text-n-brand" />
          <span>{{ $t('REGISTER.ACTIVATION.PAYMENT_METHODS_TITLE') }}</span>
        </div>
        <div class="flex flex-wrap items-center gap-2 text-[11px]">
          <span
            v-if="selectedCurrency === 'PEN'"
            class="px-2 py-1 bg-purple-100 text-purple-800 dark:bg-purple-950/60 dark:text-purple-300 font-bold rounded-md"
          >
            {{ $t('REGISTER.ACTIVATION.METHOD_YAPE') }}
          </span>
          <span
            class="px-2 py-1 bg-white dark:bg-n-solid-3 border border-n-weak font-medium rounded-md text-n-slate-12"
          >
            {{ $t('REGISTER.ACTIVATION.METHOD_CARDS') }}
          </span>
          <span
            v-if="selectedCurrency === 'PEN'"
            class="px-2 py-1 bg-white dark:bg-n-solid-3 border border-n-weak font-medium rounded-md text-n-slate-12"
          >
            {{ $t('REGISTER.ACTIVATION.METHOD_TRANSFER') }}
          </span>
        </div>
      </div>

      <!-- ACTION BUTTONS -->
      <div class="mt-6 space-y-3">
        <NextButton
          lg
          class="w-full font-bold text-base shadow-sm"
          :label="
            selectedCurrency === 'PEN'
              ? $t('REGISTER.ACTIVATION.PAY_BUTTON_PEN', {
                  amount: currentPrice.formatted,
                })
              : $t('REGISTER.ACTIVATION.PAY_BUTTON_USD', {
                  amount: currentPrice.formatted,
                })
          "
          :is-loading="isProcessing"
          @click="handlePayment"
        />
        <div class="text-center">
          <button
            type="button"
            class="text-xs text-n-slate-10 hover:text-n-slate-12 transition-colors underline"
            @click="emit('skip')"
          >
            {{ $t('REGISTER.ACTIVATION.SKIP_OR_EXPLORE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
