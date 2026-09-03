<script setup>
import { computed, nextTick, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import IanLogo from 'dashboard/components-next/captain/IanLogo.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';

const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();

const createAssistantDialogRef = ref(null);
const assistantId = computed(() => route.params.assistantId);

const openCreateAssistantModal = () => {
  nextTick(() => {
    createAssistantDialogRef.value?.dialogRef?.open?.();
  });
};

const documentsRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_assistants_documents_index',
  })
);

const responsesRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_assistants_responses_index',
  })
);

const playgroundRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_assistants_playground_index',
  })
);

const inboxesRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_assistants_inboxes_index',
  })
);

const rulesRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_assistants_scenarios_index',
  })
);

const toolsRoute = computed(() =>
  accountScopedRoute('captain_assistants_index', {
    assistantId: assistantId.value,
    navigationPath: 'captain_tools_index',
  })
);
</script>

<template>
  <div
    class="relative overflow-hidden rounded-2xl border border-n-strong bg-gradient-to-b from-n-solid-2 via-n-solid-1 to-n-background p-6 shadow-sm flex flex-col gap-6"
  >
    <!-- AMBIENT NEURAL GLOWS -->
    <div
      class="absolute -top-32 -right-32 h-80 w-80 rounded-full bg-violet-600/15 blur-3xl pointer-events-none"
    />
    <div
      class="absolute -bottom-32 -left-32 h-80 w-80 rounded-full bg-emerald-500/15 blur-3xl pointer-events-none"
    />

    <!-- TOP ROW: IAN NEURAL IDENTITY & TELEMETRY -->
    <div
      class="relative z-10 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6"
    >
      <div class="flex items-start gap-4 max-w-2xl">
        <!-- ANIMATED NEURAL AVATAR -->
        <div class="relative group shrink-0">
          <div
            class="absolute -inset-1 rounded-2xl bg-gradient-to-r from-violet-600 via-cyan-500 to-emerald-500 opacity-60 blur-sm group-hover:opacity-100 transition duration-300"
          />
          <div
            class="relative w-16 h-16 rounded-2xl bg-black text-white border border-slate-700/60 shadow-md flex items-center justify-center p-2"
          >
            <IanLogo class="w-12 h-12" />
          </div>
        </div>

        <div class="flex flex-col gap-1.5">
          <div class="flex items-center gap-2.5 flex-wrap">
            <h1 class="text-xl font-bold text-n-slate-12 tracking-tight">
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.TITLE') }}
            </h1>
            <span
              class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20"
            >
              <span class="size-2 rounded-full bg-emerald-500 animate-ping" />
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
              <Icon icon="i-lucide-cpu" class="size-3.5 text-violet-500" />
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
            <span
              aria-hidden="true"
              class="size-1 rounded-full bg-n-slate-8 inline-block"
            />
            <span class="inline-flex items-center gap-1 text-n-brand">
              <Icon icon="i-lucide-sparkles" class="size-3.5" />
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.AUTOSERVICE_BADGE') }}
            </span>
          </div>
        </div>
      </div>

      <!-- CREATE NEW AGENT QUICK BUTTON -->
      <div class="w-full lg:w-auto shrink-0 flex items-center gap-3">
        <Button
          :label="t('CAPTAIN.OVERVIEW.IAN_HERO.CREATE_NEW_AGENT')"
          icon="i-lucide-plus"
          size="sm"
          class="w-full lg:w-auto shadow-sm"
          @click="openCreateAssistantModal"
        />
      </div>
    </div>

    <!-- MIDDLE ROW: 3-STEP AUTOSERVICIO PIPELINE -->
    <div class="relative z-10 grid grid-cols-1 md:grid-cols-3 gap-4">
      <!-- PASO 1: ENTRENA LA NEURONA -->
      <div
        class="flex flex-col justify-between p-4 rounded-xl border border-n-weak bg-n-alpha-1 hover:border-violet-500/40 hover:bg-n-alpha-2 transition-all duration-200 group"
      >
        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-violet-500/10 text-violet-600 dark:text-violet-400 border border-violet-500/20"
            >
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_SUBTITLE') }}
            </span>
            <span class="text-xs font-black text-violet-500/60 font-mono">
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_NUM') }}
            </span>
          </div>
          <h3
            class="text-sm font-semibold text-n-slate-12 group-hover:text-violet-500 transition-colors flex items-center gap-1.5"
          >
            <Icon
              icon="i-lucide-brain"
              class="size-4 text-violet-500 shrink-0"
            />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_TITLE') }}
          </h3>
          <p class="text-[11px] text-n-slate-11 leading-relaxed">
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_DESC') }}
          </p>
        </div>

        <div class="flex items-center gap-2 mt-4 pt-3 border-t border-n-weak">
          <RouterLink
            :to="documentsRoute"
            class="flex-1 inline-flex items-center justify-center gap-1.5 py-1.5 px-2.5 rounded-lg text-xs font-medium bg-n-alpha-2 hover:bg-violet-500/15 hover:text-violet-500 text-n-slate-12 transition-colors border border-n-weak"
          >
            <Icon icon="i-lucide-file-up" class="size-3.5" />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_ACTION_PDF') }}
          </RouterLink>
          <RouterLink
            :to="responsesRoute"
            class="flex-1 inline-flex items-center justify-center gap-1.5 py-1.5 px-2.5 rounded-lg text-xs font-medium bg-n-alpha-2 hover:bg-violet-500/15 hover:text-violet-500 text-n-slate-12 transition-colors border border-n-weak"
          >
            <Icon icon="i-lucide-message-circle-question" class="size-3.5" />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_1_ACTION_FAQ') }}
          </RouterLink>
        </div>
      </div>

      <!-- PASO 2: PRUEBA EN EL SIMULADOR -->
      <div
        class="flex flex-col justify-between p-4 rounded-xl border border-n-brand/30 bg-n-brand/5 hover:border-n-brand/60 hover:bg-n-brand/10 transition-all duration-200 group relative overflow-hidden"
      >
        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-n-brand/15 text-n-brand border border-n-brand/20"
            >
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_2_SUBTITLE') }}
            </span>
            <span class="text-xs font-black text-n-brand/60 font-mono">
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_2_NUM') }}
            </span>
          </div>
          <h3
            class="text-sm font-semibold text-n-slate-12 group-hover:text-n-brand transition-colors flex items-center gap-1.5"
          >
            <Icon
              icon="i-lucide-play-circle"
              class="size-4 text-n-brand shrink-0 animate-pulse"
            />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_2_TITLE') }}
          </h3>
          <p class="text-[11px] text-n-slate-11 leading-relaxed">
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_2_DESC') }}
          </p>
        </div>

        <div class="mt-4 pt-3 border-t border-n-brand/20">
          <RouterLink
            :to="playgroundRoute"
            class="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-semibold bg-n-brand text-white hover:brightness-110 shadow-sm transition-all"
          >
            <Icon icon="i-lucide-sparkles" class="size-4" />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_2_ACTION') }}
          </RouterLink>
        </div>
      </div>

      <!-- PASO 3: ACTIVA EN TUS CANALES -->
      <div
        class="flex flex-col justify-between p-4 rounded-xl border border-n-weak bg-n-alpha-1 hover:border-emerald-500/40 hover:bg-n-alpha-2 transition-all duration-200 group"
      >
        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20"
            >
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_3_SUBTITLE') }}
            </span>
            <span class="text-xs font-black text-emerald-500/60 font-mono">
              {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_3_NUM') }}
            </span>
          </div>
          <h3
            class="text-sm font-semibold text-n-slate-12 group-hover:text-emerald-500 transition-colors flex items-center gap-1.5"
          >
            <Icon
              icon="i-lucide-radio"
              class="size-4 text-emerald-500 shrink-0"
            />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_3_TITLE') }}
          </h3>
          <p class="text-[11px] text-n-slate-11 leading-relaxed">
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_3_DESC') }}
          </p>
        </div>

        <div class="mt-4 pt-3 border-t border-n-weak">
          <RouterLink
            :to="inboxesRoute"
            class="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-semibold bg-n-alpha-2 hover:bg-emerald-500/15 hover:text-emerald-500 text-n-slate-12 transition-colors border border-n-weak"
          >
            <Icon icon="i-lucide-message-square" class="size-3.5" />
            {{ t('CAPTAIN.OVERVIEW.IAN_HERO.STEP_3_ACTION') }}
          </RouterLink>
        </div>
      </div>
    </div>

    <!-- BOTTOM ROW: QUICK ADVANCED CONFIGS (RULES & TOOLS) -->
    <div
      class="relative z-10 flex items-center justify-between pt-2 border-t border-n-weak text-xs text-n-slate-10 flex-wrap gap-3"
    >
      <span class="text-[11px]">
        {{ t('CAPTAIN.OVERVIEW.IAN_HERO.ADVANCED_LABEL') }}
      </span>
      <div class="flex items-center gap-2 flex-wrap">
        <RouterLink
          :to="rulesRoute"
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-n-alpha-1 hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 border border-n-weak transition-colors"
        >
          <Icon icon="i-lucide-sliders" class="size-3" />
          {{ t('CAPTAIN.OVERVIEW.IAN_HERO.PROMPT') }}
        </RouterLink>
        <RouterLink
          :to="toolsRoute"
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-n-alpha-1 hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 border border-n-weak transition-colors"
        >
          <Icon icon="i-lucide-wrench" class="size-3" />
          {{ t('CAPTAIN.OVERVIEW.IAN_HERO.TOOLS_LABEL') }}
        </RouterLink>
      </div>
    </div>

    <!-- CREATE ASSISTANT MODAL INSTANCE -->
    <CreateAssistantDialog ref="createAssistantDialogRef" type="create" />
  </div>
</template>
