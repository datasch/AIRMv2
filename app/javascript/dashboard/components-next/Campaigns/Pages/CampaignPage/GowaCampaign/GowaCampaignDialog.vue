<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import GowaCampaignForm from './GowaCampaignForm.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const addCampaign = async campaignDetails => {
  try {
    await store.dispatch('campaigns/create', campaignDetails);

    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });

    useAlert(t('CAMPAIGN.GOWA.CREATE.FORM.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAMPAIGN.GOWA.CREATE.FORM.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const handleSubmit = campaignDetails => {
  addCampaign(campaignDetails);
};

const handleClose = () => emit('close');
</script>

<template>
  <div
    class="w-[30rem] max-w-[95vw] max-h-[calc(100vh-5rem)] overflow-y-auto z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-solid-2 dark:bg-n-solid-1 p-6 rounded-xl border border-n-weak shadow-2xl flex flex-col gap-6"
  >
    <div
      class="flex items-center justify-between sticky -top-6 -mx-6 px-6 py-4 bg-n-solid-2 dark:bg-n-solid-1 border-b border-n-weak z-10"
    >
      <h3 class="text-base font-medium text-n-slate-12">
        {{ t('CAMPAIGN.GOWA.CREATE.TITLE') }}
      </h3>
      <button
        type="button"
        class="text-n-slate-10 hover:text-n-slate-12 p-1 rounded-md transition-colors"
        @click="handleClose"
      >
        <span class="i-lucide-x w-5 h-5 block" />
      </button>
    </div>
    <GowaCampaignForm @submit="handleSubmit" @cancel="handleClose" />
  </div>
</template>
