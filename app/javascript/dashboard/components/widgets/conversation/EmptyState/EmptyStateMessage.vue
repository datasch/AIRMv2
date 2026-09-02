<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';
import IanLogo from 'dashboard/components-next/captain/IanLogo.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FeaturePlaceholder from './FeaturePlaceholder.vue';

defineProps({
  message: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const quickActions = computed(() => [
  {
    icon: 'i-woot-captain',
    title: t('CONVERSATION.EMPTY_STATE.QUICK_AI'),
    desc: t('CONVERSATION.EMPTY_STATE.QUICK_AI_DESC'),
    to: accountScopedRoute('captain_assistants_index', {
      navigationPath: 'captain_assistants_overview_index',
    }),
  },
  {
    icon: 'i-lucide-phone',
    title: t('CONVERSATION.EMPTY_STATE.QUICK_VOIP'),
    desc: t('CONVERSATION.EMPTY_STATE.QUICK_VOIP_DESC'),
    to: accountScopedRoute('calls_dashboard_index'),
  },
  {
    icon: 'i-lucide-contact',
    title: t('CONVERSATION.EMPTY_STATE.QUICK_CONTACTS'),
    desc: t('CONVERSATION.EMPTY_STATE.QUICK_CONTACTS_DESC'),
    to: accountScopedRoute('contacts_dashboard_index'),
  },
]);
</script>

<template>
  <div
    class="flex flex-col items-center justify-center h-full max-w-xl mx-auto px-6 py-8 text-center select-none"
  >
    <!-- EMBLEM WITH GLOW -->
    <div class="relative mb-6">
      <div
        class="absolute -inset-4 bg-gradient-to-tr from-cyan-500/20 via-violet-500/20 to-pink-500/20 rounded-full blur-xl opacity-75 animate-pulse"
      />
      <div
        class="relative w-16 h-16 rounded-2xl bg-black text-white dark:bg-black dark:text-white border border-slate-700/60 shadow-lg flex items-center justify-center p-2.5 group hover:scale-105 transition-transform"
      >
        <IanLogo class="w-11 h-11" />
      </div>
    </div>

    <h2 class="text-xl font-bold text-n-slate-12 tracking-tight mb-1">
      {{ t('CONVERSATION.EMPTY_STATE.AIRM_TITLE') }}
    </h2>
    <p class="text-xs text-n-slate-11 max-w-sm mb-6">
      {{ message || t('CONVERSATION.EMPTY_STATE.AIRM_SUBTITLE') }}
    </p>

    <!-- QUICK ACCESS CARDS -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 w-full mb-6 text-left">
      <RouterLink
        v-for="action in quickActions"
        :key="action.title"
        :to="action.to"
        class="p-3 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak hover:border-n-brand/40 rounded-xl transition-all duration-150 group shadow-xs"
      >
        <div class="flex items-center gap-2 mb-1.5">
          <div
            class="w-6 h-6 rounded-lg bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform"
          >
            <Icon :icon="action.icon" class="w-3.5 h-3.5" />
          </div>
          <span
            class="text-xs font-semibold text-n-slate-12 truncate group-hover:text-n-brand transition-colors"
          >
            {{ action.title }}
          </span>
        </div>
        <p class="text-[11px] text-n-slate-10 line-clamp-2 leading-relaxed">
          {{ action.desc }}
        </p>
      </RouterLink>
    </div>

    <!-- KEYBOARD SHORTCUTS FOOTER -->
    <FeaturePlaceholder />
  </div>
</template>
