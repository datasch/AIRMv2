<script setup>
import { ref, computed, reactive } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import VueHcaptcha from '@hcaptcha/vue3-hcaptcha';
import FormInput from '../../../../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PasswordRequirements from './PasswordRequirements.vue';
import { isValidPassword } from 'shared/helpers/Validators';
import GoogleOAuthButton from '../../../../../components/GoogleOauth/Button.vue';
import { register } from '../../../../../api/auth';
import * as CompanyEmailValidator from 'company-email-validator';

const MIN_PASSWORD_LENGTH = 6;

const store = useStore();
const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const hCaptcha = ref(null);
const isPasswordFocused = ref(false);
const isSignupInProgress = ref(false);

const credentials = reactive({
  email: '',
  password: '',
  hCaptchaClientResponse: '',
});

const formatSalespersonName = raw => {
  if (!raw) return '';
  return decodeURIComponent(String(raw))
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase())
    .trim();
};

const detectedSalesperson = computed(() => {
  const queryParam = route.query.salesperson || route.query.ref;
  if (queryParam) {
    const formatted = formatSalespersonName(queryParam);
    try {
      sessionStorage.setItem('airm_salesperson_name', formatted);
      sessionStorage.setItem(
        'airm_referral_code',
        String(route.query.referral_code || queryParam)
      );
    } catch {
      // Ignore sessionStorage if unavailable
    }
    return formatted;
  }
  try {
    return sessionStorage.getItem('airm_salesperson_name') || '';
  } catch {
    return '';
  }
});

const detectedReferralCode = computed(() => {
  const queryParam = route.query.referral_code || route.query.ref;
  if (queryParam) return String(queryParam);
  try {
    return sessionStorage.getItem('airm_referral_code') || '';
  } catch {
    return '';
  }
});

const rules = {
  credentials: {
    email: {
      required,
      email,
      businessEmailValidator(value) {
        return CompanyEmailValidator.isCompanyEmail(value);
      },
    },
    password: {
      required,
      isValidPassword,
      minLength: minLength(MIN_PASSWORD_LENGTH),
    },
  },
};

const v$ = useVuelidate(rules, { credentials });

const globalConfig = computed(() => store.getters['globalConfig/get']);

const termsLink = computed(() =>
  t('REGISTER.TERMS_ACCEPT')
    .replace('https://www.chatwoot.com/terms', globalConfig.value.termsURL)
    .replace(
      'https://www.chatwoot.com/privacy-policy',
      globalConfig.value.privacyURL
    )
    .replace('https://giantucchi.com/terms', globalConfig.value.termsURL)
    .replace('https://giantucchi.com/privacy', globalConfig.value.privacyURL)
);

const allowedLoginMethods = computed(
  () => window.chatwootConfig.allowedLoginMethods || ['email']
);

const showGoogleOAuth = computed(
  () =>
    allowedLoginMethods.value.includes('google_oauth') &&
    Boolean(window.chatwootConfig.googleOAuthClientId)
);

const isFormValid = computed(() => !v$.value.$invalid);

const performRegistration = async () => {
  isSignupInProgress.value = true;
  try {
    await register({
      ...credentials,
      salespersonName: detectedSalesperson.value || undefined,
      referralCode: detectedReferralCode.value || undefined,
      referralSource: detectedSalesperson.value ? 'sales_referral' : undefined,
    });
    router.push({
      name: 'auth_verify_email',
      state: { email: credentials.email },
    });
  } catch (error) {
    const errorMessage = error?.message || t('REGISTER.API.ERROR_MESSAGE');
    if (globalConfig.value.hCaptchaSiteKey) {
      hCaptcha.value.reset();
      credentials.hCaptchaClientResponse = '';
    }
    useAlert(errorMessage);
  } finally {
    isSignupInProgress.value = false;
  }
};

const submit = () => {
  if (isSignupInProgress.value) return;
  v$.value.$touch();
  if (v$.value.$invalid) return;
  isSignupInProgress.value = true;
  if (globalConfig.value.hCaptchaSiteKey) {
    hCaptcha.value.execute();
  } else {
    performRegistration();
  }
};

const onRecaptchaVerified = token => {
  credentials.hCaptchaClientResponse = token;
  performRegistration();
};

const onCaptchaError = () => {
  isSignupInProgress.value = false;
  credentials.hCaptchaClientResponse = '';
  hCaptcha.value.reset();
};
</script>

<template>
  <div class="flex-1">
    <div
      v-if="detectedSalesperson"
      class="flex items-center gap-3 p-3 bg-n-alpha-1 border border-n-strong rounded-xl mb-4 text-n-slate-12 text-sm"
    >
      <div
        class="w-7 h-7 rounded-full bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0"
      >
        <Icon icon="i-lucide-user-check" class="w-4 h-4 text-n-brand" />
      </div>
      <div class="flex-1 min-w-0">
        <div
          class="text-[11px] font-semibold text-n-slate-11 uppercase tracking-wider"
        >
          {{ $t('REGISTER.SALESPERSON.ASSIGNED_LABEL') }}
        </div>
        <div class="font-semibold text-n-slate-12 truncate text-sm">
          {{ detectedSalesperson }}
        </div>
      </div>
      <span
        class="text-xs bg-n-brand/10 text-n-brand px-2.5 py-0.5 rounded-full font-medium shrink-0"
      >
        {{ $t('REGISTER.SALESPERSON.REFERRAL_BADGE') }}
      </span>
    </div>

    <form class="space-y-3" @submit.prevent="submit">
      <FormInput
        v-model="credentials.email"
        type="email"
        name="email_address"
        :class="{ error: v$.credentials.email.$error }"
        :label="$t('REGISTER.EMAIL.LABEL')"
        :placeholder="$t('REGISTER.EMAIL.PLACEHOLDER')"
        :has-error="v$.credentials.email.$error"
        :error-message="$t('REGISTER.EMAIL.ERROR')"
        @blur="v$.credentials.email.$touch"
      />
      <div class="relative">
        <FormInput
          v-model="credentials.password"
          type="password"
          name="password"
          :class="{ error: v$.credentials.password.$error }"
          :label="$t('LOGIN.PASSWORD.LABEL')"
          :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
          :has-error="v$.credentials.password.$error"
          @focus="isPasswordFocused = true"
          @blur="
            isPasswordFocused = false;
            v$.credentials.password.$touch();
          "
        />
        <Transition
          enter-active-class="transition duration-200 ease-out origin-left"
          enter-from-class="opacity-0 scale-90 translate-x-1"
          enter-to-class="opacity-100 scale-100 translate-x-0"
          leave-active-class="transition duration-150 ease-in origin-left"
          leave-from-class="opacity-100 scale-100 translate-x-0"
          leave-to-class="opacity-0 scale-90 translate-x-1"
        >
          <PasswordRequirements
            v-if="isPasswordFocused"
            :password="credentials.password"
          />
        </Transition>
      </div>
      <VueHcaptcha
        v-if="globalConfig.hCaptchaSiteKey"
        ref="hCaptcha"
        size="invisible"
        :sitekey="globalConfig.hCaptchaSiteKey"
        @verify="onRecaptchaVerified"
        @error="onCaptchaError"
        @expired="onCaptchaError"
        @challenge-expired="onCaptchaError"
        @closed="onCaptchaError"
      />
      <NextButton
        lg
        type="submit"
        data-testid="submit_button"
        class="w-full font-medium"
        :label="$t('REGISTER.SUBMIT')"
        :disabled="isSignupInProgress || !isFormValid"
        :is-loading="isSignupInProgress"
      />
    </form>
    <GoogleOAuthButton v-if="showGoogleOAuth" class="mt-3">
      {{ $t('REGISTER.OAUTH.GOOGLE_SIGNUP') }}
    </GoogleOAuthButton>
    <p
      class="text-sm mt-5 mb-0 text-n-slate-11 [&>a]:text-n-blue-10 [&>a]:font-medium [&>a]:hover:text-n-blue-11"
      v-html="termsLink"
    />
  </div>
</template>
