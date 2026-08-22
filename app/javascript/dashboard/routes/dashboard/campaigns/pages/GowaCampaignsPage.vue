<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import GowaCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/GowaCampaign/GowaCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import GowaCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/GowaCampaignEmptyState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const selectedCampaign = ref(null);
const [showGowaCampaignDialog, toggleGowaCampaignDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);

const gowaCampaigns = computed(() => getters['campaigns/getGOWACampaigns'].value);

const hasNoGowaCampaigns = computed(
  () => gowaCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.GOWA.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.GOWA.NEW_CAMPAIGN')"
    @click="toggleGowaCampaignDialog()"
    @close="toggleGowaCampaignDialog(false)"
  >
    <template #action>
      <GowaCampaignDialog
        v-if="showGowaCampaignDialog"
        @close="toggleGowaCampaignDialog(false)"
      />
    </template>
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoGowaCampaigns"
      :campaigns="gowaCampaigns"
      @delete="handleDelete"
    />
    <GowaCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.GOWA.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.GOWA.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
