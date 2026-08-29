<script setup>
import { computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';

const { attachments } = useMessageContext();

const $store = useStore();
const { t } = useI18n();

const attachment = computed(() => {
  return attachments.value[0];
});

const contactName = computed(() => {
  const { meta } = attachment.value ?? {};
  const { firstName, lastName, name, displayName } = meta ?? {};
  if (name) return name;
  if (displayName) return displayName;
  const combined = `${firstName ?? ''} ${lastName ?? ''}`.trim();
  return combined || 'Contacto';
});

const phoneNumber = computed(() => {
  const { meta } = attachment.value ?? {};
  return (
    attachment.value?.fallbackTitle ||
    meta?.phone ||
    meta?.phone_number ||
    meta?.formattedPhone ||
    ''
  );
});

const formattedPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\s|-|[A-Za-z]/g, '');
});

const rawPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\D/g, '');
});

function getContactObject() {
  const { meta } = attachment.value ?? {};
  const contactItem = {
    name: contactName.value,
    phone_number: `+${rawPhoneNumber.value}`,
    email: meta?.email || undefined,
  };
  return contactItem;
}

async function filterContactByNumber(searchCandidate) {
  const query = {
    attribute_key: 'phone_number',
    filter_operator: 'equal_to',
    values: [searchCandidate],
    attribute_model: 'standard',
    custom_attribute_type: '',
  };

  const queryPayload = { payload: [query] };
  const contacts = await $store.dispatch('contacts/filter', {
    queryPayload,
    resetState: false,
  });
  return contacts.shift();
}

function openContactNewTab(contactId) {
  const accountId = window.location.pathname.split('/')[3];
  const url = `/app/accounts/${accountId}/contacts/${contactId}`;
  window.open(url, '_blank');
}

async function addContact() {
  try {
    let contact = await filterContactByNumber(rawPhoneNumber);
    if (!contact) {
      contact = await $store.dispatch('contacts/create', getContactObject());
      useAlert(t('CONTACT_FORM.SUCCESS_MESSAGE'));
    }
    openContactNewTab(contact.id);
  } catch (error) {
    if (error instanceof DuplicateContactException) {
      if (error.data.includes('phone_number')) {
        useAlert(t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
      }
    } else if (error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t('CONTACT_FORM.ERROR_MESSAGE'));
    }
  }
}

const action = computed(() => ({
  label: t('CONVERSATION.SAVE_CONTACT'),
  onClick: addContact,
}));
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <BaseAttachmentBubble
      icon="i-teenyicons-user-circle-solid"
      icon-bg-color="bg-[#D6409F]"
      sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.CONTACT"
      :title="contactName"
      :content="phoneNumber"
      :action="formattedPhoneNumber ? action : null"
    />
    <div
      v-if="rawPhoneNumber"
      class="flex items-center gap-3 px-2.5 py-1 text-xs text-n-slate-11 bg-n-alpha-1 rounded-lg border border-n-border-weak"
    >
      <a
        :href="`https://wa.me/${rawPhoneNumber}`"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1 font-semibold text-green-600 hover:text-green-700 dark:text-green-400 hover:underline"
      >
        <span class="i-lucide-message-circle size-3.5" />
        <span>{{ t('CONVERSATION.WHATSAPP_CONTACT') }}</span>
      </a>
      <span class="i-lucide-dot size-4 text-n-slate-7" />
      <a
        :href="`tel:+${rawPhoneNumber}`"
        class="inline-flex items-center gap-1 font-medium text-n-blue hover:underline"
      >
        <span class="i-lucide-phone size-3.5" />
        <span>{{ t('CONVERSATION.CALL_CONTACT') }}</span>
      </a>
    </div>
  </div>
</template>
