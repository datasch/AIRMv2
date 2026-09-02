<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import IanLogo from 'dashboard/components-next/captain/IanLogo.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();

const assistantId = computed(() => route.params.assistantId);

const studioActions = computed(() => [
  {
    name: 'documentos',
    label: t('CAPTAIN.OVERVIEW.IAN_HERO.DOCS'),
    icon: 'i-lucide-file-text',
    desc: t('CAPTAIN.OVERVIEW.IAN_HERO.DOCS_DESC'),
    to: accountScopedRoute('captain_assistants_index', {
      assistantId: assistantId.value,
      navigationPath: 'captain_assistants_documents_index',
    }),
  },
  {
    name: 'escenarios',
    label: t('CAPTAIN.OVERVIEW.IAN_HERO.PROMPT'),
    icon: 'i-lucide-sparkles',
    desc: t('CAPTAIN.OVERVIEW.IAN_HERO.PROMPT_DESC'),
    to: accountScopedRoute('captain_assistants_index', {
      assistantId: assistantId.value,
      navigationPath: 'captain_assistants_scenarios_index',
    }),
  },
  {
    name: 'playground',
    label: t('CAPTAIN.OVERVIEW.IAN_HERO.PLAYGROUND'),
    icon: 'i-lucide-play-circle',
    desc: t('CAPTAIN.OVERVIEW.IAN_HERO.PLAYGROUND_DESC'),
    to: accountScopedRoute('captain_assistants_index', {
      assistantId: assistantId.value,
      navigationPath: 'captain_assistants_playground_index',
    }),
  },
  {
    name: 'canales',
    label: t('CAPTAIN.OVERVIEW.IAN_HERO.INBOXES'),
    icon: 'i-lucide-message-square',
    desc: t('CAPTAIN.OVERVIEW.IAN_HERO.INBOXES_DESC'),
    to: accountScopedRoute('captain_assistants_index', {
      assistantId: assistantId.value,
      navigationPath: 'captain_assistants_inboxes_index',
    }),
  },
]);
</script>

<template>
  <div
    class="relative overflow-hidden rounded-2xl border border-n-strong bg-gradient-to-b from-n-solid-2 via-n-solid-1 to-n-background p-6 shadow-sm"
  >
    <!-- AMBIENT GLOW -->
    <div
      class="absolute -top-24 -right-24 h-64 w-64 rounded-full bg-violet-500/15 blur-3xl pointer-events-none"
    />
    <div
      class="absolute -bottom-24 -left-24 h-64 w-64 rounded-full bg-cyan-500/15 blur-3xl pointer-events-none"
    />

    <div
      class="relative z-10 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6"
    >
      <!-- IAN IDENTITY SECTION -->
      <div class="flex items-start gap-4 max-w-xl">
        <div
          class="relative w-16 h-16 rounded-2xl bg-black text-white dark:bg-black dark:text-white border border-slate-700/50 shadow-md flex items-center justify-center shrink-0 p-2 group hover:scale-105 transition-transform"
        >
          <IanLogo class="w-12 h-12" />
        </div>

        <div class="flex flex-col gap-1">
          <div class="flex items-center gap-2 flex-wrap">
            <h1 class="text-xl font-bold text-n-slate-12 tracking-tight">
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.TITLE') }}
            </h1>
            <span
              class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20"
            >
              <span
                class="size-1.5 rounded-full bg-emerald-500 animate-pulse"
              />
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STATUS') }}
            </span>
          </div>

          <p class="text-xs text-n-slate-11 leading-relaxed">
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.DESCRIPTION') }}
          </p>

          <div
            class="flex items-center gap-3 mt-1 text-[11px] text-n-slate-10 flex-wrap"
          >
            <span class="inline-flex items-center gap-1">
              <Icon icon="i-lucide-cpu" class="size-3.5 text-n-brand" />
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.MODEL') }}
            </span>
            <span
              aria-hidden="true"
              class="size-1 rounded-full bg-n-slate-8 inline-block"
            />
            <span class="inline-flex items-center gap-1">
              <Icon
                icon="i-lucide-shield-check"
                class="size-3.5 text-emerald-500"
              />
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.RAG') }}
            </span>
          </div>
        </div>
      </div>

      <!-- STUDIO ACTIONS QUICK MATRIX -->
      <div
        class="grid grid-cols-2 sm:grid-cols-2 gap-2.5 w-full lg:w-auto shrink-0"
      >
        <RouterLink
          v-for="action in studioActions"
          :key="action.name"
          :to="action.to"
          class="flex items-center gap-2.5 p-2.5 rounded-xl border border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2 hover:border-n-brand/40 transition-all duration-150 group shadow-2xs"
        >
          <div
            class="size-8 rounded-lg bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform"
          >
            <Icon :icon="action.icon" class="size-4" />
          </div>
          <div class="min-w-0 pr-2">
            <div
              class="text-xs font-semibold text-n-slate-12 group-hover:text-n-brand transition-colors truncate"
            >
              {{ action.label }}
            </div>
            <div class="text-[10px] text-n-slate-10 truncate">
              {{ action.desc }}
            </div>
          </div>
        </RouterLink>
      </div>
    </div>
  </div>
</template>
