<script setup>
import { reactive, computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getGOWAInboxes'),
  teams: useMapGetter('teams/getTeams'),
};

const fileInputRef = ref(null);

const initialState = {
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  audienceType: 'labels', // 'labels' | 'file'
  selectedAudience: [],
  parsedContacts: [],
  selectedFileName: '',
  fileError: '',
  teamId: null,
  delayInterval: 5,
};

const state = reactive({ ...initialState });

onMounted(() => {
  if (!formState.teams.value?.length) {
    store.dispatch('teams/get');
  }
});

// Auto-detect team 'ventas' / 'sales' for the current account
watch(
  () => formState.teams.value,
  newTeams => {
    if (newTeams?.length && state.teamId === null) {
      const salesTeam = newTeams.find(team =>
        ['ventas', 'sales', 'equipo ventas', 'sales team', 'comercial'].includes(
          team.name?.trim().toLowerCase()
        )
      );
      if (salesTeam) {
        state.teamId = salesTeam.id;
      }
    }
  },
  { immediate: true }
);

const rules = {
  title: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const teamOptions = computed(() => {
  const teamsList = formState.teams.value?.map(team => ({
    value: team.id,
    label: team.name,
  })) || [];
  return teamsList;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.GOWA.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience:
    state.audienceType === 'labels' && state.selectedAudience.length === 0
      ? t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE.ERROR')
      : '',
  file:
    state.audienceType === 'file' && state.parsedContacts.length === 0
      ? state.fileError || t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.NO_VALID_CONTACTS_ERROR')
      : '',
}));

const isAudienceValid = computed(() => {
  if (state.audienceType === 'labels') {
    return state.selectedAudience.length > 0;
  }
  return state.parsedContacts.length > 0;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !isAudienceValid.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  if (fileInputRef.value) {
    fileInputRef.value.value = '';
  }
};

const handleCancel = () => emit('cancel');

const insertVariable = variable => {
  state.message = `${state.message} {{ ${variable} }}`;
};

const handleTriggerFileSelect = () => {
  fileInputRef.value?.click();
};

const handleRemoveFile = () => {
  state.selectedFileName = '';
  state.parsedContacts = [];
  state.fileError = '';
  if (fileInputRef.value) {
    fileInputRef.value.value = '';
  }
};

const parseCSVLine = (text, delimiter) => {
  const result = [];
  let row = [''];
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    const nextChar = text[i + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        row[row.length - 1] += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === delimiter && !inQuotes) {
      row.push('');
    } else if ((char === '\r' || char === '\n') && !inQuotes) {
      if (char === '\r' && nextChar === '\n') {
        i += 1;
      }
      result.push(row);
      row = [''];
    } else {
      row[row.length - 1] += char;
    }
  }

  if (row.length > 1 || row[0] !== '') {
    result.push(row);
  }

  return result;
};

const handleFileUpload = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  state.selectedFileName = file.name;
  state.fileError = '';
  state.parsedContacts = [];

  try {
    const content = await file.text();
    const cleanContent = content.replace(/^\uFEFF/, ''); // Remove BOM

    // Detect delimiter
    const firstLine = cleanContent.split(/[\r\n]+/)[0] || '';
    let delimiter = ',';
    if (firstLine.includes(';') && (firstLine.match(/;/g) || []).length >= (firstLine.match(/,/g) || []).length) {
      delimiter = ';';
    } else if (firstLine.includes('\t')) {
      delimiter = '\t';
    }

    const rows = parseCSVLine(cleanContent, delimiter);
    if (!rows || rows.length < 2) {
      state.fileError = t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.INVALID_FILE_ERROR');
      return;
    }

    const rawHeaders = rows[0].map(h => h.trim().toLowerCase().replace(/['"]/g, ''));

    // Map column indices
    const phoneIdx = rawHeaders.findIndex(h => /phone|tel[eé]fono|celular|m[oó]vil|numero|number/i.test(h));
    const nameIdx = rawHeaders.findIndex(h => /name|nombre|cliente|contacto/i.test(h));
    const emailIdx = rawHeaders.findIndex(h => /email|correo|mail/i.test(h));
    const companyIdx = rawHeaders.findIndex(h => /company|empresa|organizaci[oó]n|negocio/i.test(h));
    const custom1Idx = rawHeaders.findIndex(h => /custom_attribute_1|atributo_1|var1|variable1/i.test(h));
    const custom2Idx = rawHeaders.findIndex(h => /custom_attribute_2|atributo_2|var2|variable2/i.test(h));

    if (phoneIdx === -1) {
      state.fileError = t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.NO_VALID_CONTACTS_ERROR');
      return;
    }

    const contactsList = [];

    for (let r = 1; r < rows.length; r += 1) {
      const row = rows[r];
      if (!row || row.length === 0) continue;

      const rawPhone = row[phoneIdx]?.trim() || '';
      const cleanDigits = rawPhone.replace(/\D/g, '');

      if (cleanDigits.length >= 7) {
        const formattedPhone = rawPhone.startsWith('+') ? `+${cleanDigits}` : `+${cleanDigits}`;
        const name = nameIdx !== -1 ? row[nameIdx]?.trim() : '';
        const email = emailIdx !== -1 ? row[emailIdx]?.trim() : '';
        const company = companyIdx !== -1 ? row[companyIdx]?.trim() : '';
        const custom1 = custom1Idx !== -1 ? row[custom1Idx]?.trim() : '';
        const custom2 = custom2Idx !== -1 ? row[custom2Idx]?.trim() : '';

        contactsList.push({
          phone_number: formattedPhone,
          name: name || '',
          email: email || '',
          company_name: company || '',
          custom_attribute_1: custom1 || '',
          custom_attribute_2: custom2 || '',
        });
      }
    }

    if (contactsList.length === 0) {
      state.fileError = t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.NO_VALID_CONTACTS_ERROR');
    } else {
      state.parsedContacts = contactsList;
    }
  } catch (error) {
    state.fileError = t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.INVALID_FILE_ERROR');
  }
};

const prepareCampaignDetails = () => {
  let audiencePayload = [];

  if (state.audienceType === 'labels') {
    audiencePayload = state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    }));
  } else {
    audiencePayload = state.parsedContacts.map(contact => ({
      type: 'Contact',
      phone_number: contact.phone_number,
      name: contact.name,
      email: contact.email,
      company_name: contact.company_name,
      custom_attribute_1: contact.custom_attribute_1,
      custom_attribute_2: contact.custom_attribute_2,
    }));
  }

  return {
    title: state.title,
    message: state.message,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: audiencePayload,
    trigger_rules: {
      team_id: state.teamId,
      delay_interval: Number(state.delayInterval) || 5,
      audience_type: state.audienceType,
    },
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid || !isAudienceValid.value) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.GOWA.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <TextArea
        v-model="state.message"
        :label="t('CAMPAIGN.GOWA.CREATE.FORM.MESSAGE.LABEL')"
        :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.MESSAGE.PLACEHOLDER')"
        show-character-count
        :message="formErrors.message"
        :message-type="formErrors.message ? 'error' : 'info'"
      />
      <!-- Dynamic variables helper chips -->
      <div class="flex flex-wrap items-center gap-1.5 mt-1 text-xs">
        <span class="text-n-slate-10 font-medium mr-1">{{ t('CAMPAIGN.GOWA.CREATE.FORM.VARIABLES_LABEL') }}:</span>
        <button
          type="button"
          class="px-2 py-0.5 rounded bg-n-alpha-2 hover:bg-n-alpha-3 text-n-iris-11 transition-colors"
          @click="insertVariable('contact.name')"
          v-text="'{{ contact.name }}'"
        />
        <button
          type="button"
          class="px-2 py-0.5 rounded bg-n-alpha-2 hover:bg-n-alpha-3 text-n-iris-11 transition-colors"
          @click="insertVariable('contact.phone_number')"
          v-text="'{{ contact.phone_number }}'"
        />
        <button
          type="button"
          class="px-2 py-0.5 rounded bg-n-alpha-2 hover:bg-n-alpha-3 text-n-iris-11 transition-colors"
          @click="insertVariable('contact.email')"
          v-text="'{{ contact.email }}'"
        />
        <button
          type="button"
          class="px-2 py-0.5 rounded bg-n-alpha-2 hover:bg-n-alpha-3 text-n-iris-11 transition-colors"
          @click="insertVariable('contact.company_name')"
          v-text="'{{ contact.company_name }}'"
        />
        <button
          type="button"
          class="px-2 py-0.5 rounded bg-n-alpha-2 hover:bg-n-alpha-3 text-n-iris-11 transition-colors"
          @click="insertVariable('contact.custom_attribute_1')"
          v-text="'{{ contact.custom_attribute_1 }}'"
        />
      </div>
    </div>

    <!-- Inbox Line Selector -->
    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.GOWA.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <!-- Audience Source Selection -->
    <div class="flex flex-col gap-2 p-3.5 rounded-lg bg-n-alpha-1 border border-n-weak">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE_TYPE.LABEL') }}
      </label>
      <div class="grid grid-cols-2 gap-2">
        <button
          type="button"
          class="flex items-center justify-center gap-2 py-2 px-3 text-xs font-medium rounded-lg border transition-all"
          :class="state.audienceType === 'labels'
            ? 'bg-n-brand/10 border-n-brand text-n-brand dark:bg-n-brand/20 dark:text-n-brand'
            : 'bg-n-solid-2 dark:bg-n-solid-1 border-n-weak text-n-slate-11 hover:text-n-slate-12 hover:border-n-slate-6'"
          @click="state.audienceType = 'labels'"
        >
          <span class="i-lucide-tags w-4 h-4" />
          {{ t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE_TYPE.LABELS') }}
        </button>
        <button
          type="button"
          class="flex items-center justify-center gap-2 py-2 px-3 text-xs font-medium rounded-lg border transition-all"
          :class="state.audienceType === 'file'
            ? 'bg-n-brand/10 border-n-brand text-n-brand dark:bg-n-brand/20 dark:text-n-brand'
            : 'bg-n-solid-2 dark:bg-n-solid-1 border-n-weak text-n-slate-11 hover:text-n-slate-12 hover:border-n-slate-6'"
          @click="state.audienceType = 'file'"
        >
          <span class="i-lucide-file-spreadsheet w-4 h-4" />
          {{ t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE_TYPE.FILE') }}
        </button>
      </div>

      <!-- Mode 1: Labels multi-select -->
      <div v-if="state.audienceType === 'labels'" class="flex flex-col gap-1 mt-2">
        <TagMultiSelectComboBox
          v-model="state.selectedAudience"
          :options="audienceList"
          :label="t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE.LABEL')"
          :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
          :has-error="!!formErrors.audience"
          :message="formErrors.audience"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <!-- Mode 2: CSV / Excel Upload & Template Download -->
      <div v-else class="flex flex-col gap-3 mt-2">
        <div class="flex items-center justify-between">
          <span class="text-xs text-n-slate-11">
            {{ t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.HELP_TEXT') }}
          </span>
          <a
            href="/downloads/campaign-contacts-template.csv"
            download="plantilla_campana_contactos.csv"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-1.5 text-xs text-n-brand hover:underline font-medium shrink-0 ml-2"
          >
            <span class="i-lucide-download w-3.5 h-3.5" />
            {{ t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.DOWNLOAD_TEMPLATE') }}
          </a>
        </div>

        <div
          class="border-2 border-dashed rounded-lg p-4 flex flex-col items-center justify-center gap-2 transition-colors cursor-pointer"
          :class="state.parsedContacts.length > 0
            ? 'border-emerald-500/50 bg-emerald-500/5'
            : state.fileError
              ? 'border-ruby-500/50 bg-ruby-500/5'
              : 'border-n-weak hover:border-n-slate-6 bg-n-solid-2 dark:bg-n-solid-1'"
          @click="handleTriggerFileSelect"
        >
          <input
            ref="fileInputRef"
            type="file"
            accept=".csv, .xlsx, .xls, text/csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel"
            class="hidden"
            @change="handleFileUpload"
          />

          <template v-if="state.parsedContacts.length > 0">
            <div class="flex items-center gap-2 text-emerald-600 dark:text-emerald-400 font-medium text-sm">
              <span class="i-lucide-check-circle-2 w-5 h-5" />
              <span>{{ state.selectedFileName }}</span>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 font-medium">
                {{ t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.VALID_CONTACTS_COUNT', { count: state.parsedContacts.length }) }}
              </span>
              <button
                type="button"
                class="text-xs text-ruby-600 hover:text-ruby-700 dark:text-ruby-400 p-1 flex items-center gap-1"
                @click.stop="handleRemoveFile"
              >
                <span class="i-lucide-trash-2 w-3.5 h-3.5" />
              </button>
            </div>
          </template>

          <template v-else>
            <span class="i-lucide-upload-cloud w-8 h-8 text-n-slate-9" />
            <div class="text-center">
              <span class="text-xs font-medium text-n-slate-12 block">
                {{ t('CAMPAIGN.GOWA.CREATE.FORM.FILE_UPLOAD.CHOOSE_FILE') }}
              </span>
              <span class="text-[11px] text-n-slate-10">CSV, XLSX (.csv, .xlsx, .xls)</span>
            </div>
          </template>
        </div>

        <p v-if="formErrors.file" class="text-xs text-ruby-600 dark:text-ruby-400">
          {{ formErrors.file }}
        </p>
      </div>
    </div>

    <!-- Team Assignment Selector -->
    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between">
        <label for="team" class="text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.GOWA.CREATE.FORM.TEAM.LABEL') }}
        </label>
        <span class="text-[11px] text-n-slate-10 flex items-center gap-1">
          <span class="i-lucide-info w-3 h-3 text-n-brand" />
          {{ t('CAMPAIGN.GOWA.CREATE.FORM.TEAM.AUTO_VENTAS') }}
        </span>
      </div>
      <ComboBox
        id="team"
        v-model="state.teamId"
        :options="teamOptions"
        :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.TEAM.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="text-[11px] text-n-slate-10">
        {{ t('CAMPAIGN.GOWA.CREATE.FORM.TEAM.INFO') }}
      </p>
    </div>

    <!-- Anti-ban Safe Delay Mechanism -->
    <div class="flex flex-col gap-1.5 p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/20">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-1.5 text-xs font-semibold text-emerald-700 dark:text-emerald-400">
          <span class="i-lucide-shield-check w-4 h-4" />
          {{ t('CAMPAIGN.GOWA.CREATE.FORM.ANTIBAN.SAFE_BADGE') }}
        </div>
        <div class="flex items-center gap-1">
          <label for="delayInterval" class="text-xs text-n-slate-11">
            {{ t('CAMPAIGN.GOWA.CREATE.FORM.ANTIBAN.INTERVAL_LABEL') }}:
          </label>
          <input
            id="delayInterval"
            v-model.number="state.delayInterval"
            type="number"
            min="3"
            max="60"
            class="w-14 px-1.5 py-0.5 text-xs rounded border border-n-weak bg-n-solid-2 dark:bg-n-solid-1 text-center text-n-slate-12 font-medium"
          />
        </div>
      </div>
      <p class="text-[11px] text-n-slate-11">
        {{ t('CAMPAIGN.GOWA.CREATE.FORM.ANTIBAN.INFO') }}
      </p>
    </div>

    <!-- Scheduled At Input -->
    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.GOWA.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.GOWA.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <!-- Action Buttons -->
    <div class="flex items-center justify-between w-full gap-3 mt-2">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.GOWA.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.GOWA.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
