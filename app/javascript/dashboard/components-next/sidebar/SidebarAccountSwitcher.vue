<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import ButtonNext from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import Logo from 'next/icon/Logo.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';

defineProps({
  isCollapsed: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['showCreateAccountModal']);

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');

const userAccounts = useMapGetter('getUserAccounts');

const showAccountSwitcher = computed(
  () => userAccounts.value.length > 1 && currentAccount.value.name
);

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};

const emitNewAccount = () => {
  emit('showCreateAccountModal');
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle, isOpen }">
      <!-- Collapsed view: Logo trigger -->
      <button
        v-if="isCollapsed"
        class="grid flex-shrink-0 place-content-center p-1.5 rounded-xl cursor-pointer hover:scale-105 transition-transform"
        :class="{ 'bg-n-alpha-1': isOpen }"
        :title="currentAccount.name"
        @click="toggle"
      >
        <div
          class="size-7 rounded-xl bg-black text-white dark:bg-black dark:text-white border border-slate-700/60 p-1 shadow-xs flex items-center justify-center"
        >
          <Logo class="size-5" />
        </div>
      </button>
      <!-- Expanded view: Account name trigger -->
      <button
        v-else
        id="sidebar-account-switcher"
        :data-account-id="accountId"
        aria-haspopup="listbox"
        aria-controls="account-options"
        class="flex items-center gap-2 justify-between w-full rounded-lg px-2 py-1 transition-all"
        :class="[
          isOpen && 'bg-n-alpha-2',
          showAccountSwitcher
            ? 'hover:bg-n-alpha-1 cursor-pointer'
            : 'cursor-default',
        ]"
        @click="() => showAccountSwitcher && toggle()"
      >
        <div class="flex items-center gap-1.5 min-w-0 flex-1">
          <span
            class="text-sm font-semibold leading-5 text-n-slate-12 truncate"
            aria-live="polite"
          >
            {{ currentAccount.name }}
          </span>
          <span
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 shrink-0"
          >
            <span class="size-1.5 rounded-full bg-emerald-500 animate-pulse" />
            {{ $t('SIDEBAR.AI_BADGE') }}
          </span>
        </div>

        <span
          v-if="showAccountSwitcher"
          aria-hidden="true"
          class="i-lucide-chevron-down size-3.5 text-n-slate-10 flex-shrink-0"
        />
      </button>
    </template>
    <DropdownBody
      v-if="showAccountSwitcher || isCollapsed"
      class="min-w-80 z-50"
    >
      <DropdownSection :title="t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')">
        <DropdownItem
          v-for="account in sortedCurrentUserAccounts"
          :id="`account-${account.id}`"
          :key="account.id"
          class="cursor-pointer"
          @click="onChangeAccount(account.id)"
        >
          <template #label>
            <div
              :for="account.name"
              class="text-left rtl:text-right flex gap-2 items-center"
            >
              <span
                class="text-n-slate-12 max-w-36 truncate min-w-0"
                :title="account.name"
              >
                {{ account.name }}
              </span>
              <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
              <span
                class="text-n-slate-11 max-w-24 truncate capitalize"
                :title="account.name"
              >
                {{
                  account.custom_role_id
                    ? account.custom_role.name
                    : account.role
                }}
              </span>
            </div>
            <Icon
              v-show="account.id === accountId"
              icon="i-lucide-check"
              class="text-n-teal-11 size-5"
            />
          </template>
        </DropdownItem>
      </DropdownSection>
      <DropdownItem v-if="globalConfig.createNewAccountFromDashboard">
        <ButtonNext
          color="slate"
          variant="faded"
          class="w-full"
          size="sm"
          @click="emitNewAccount"
        >
          {{ t('CREATE_ACCOUNT.NEW_ACCOUNT') }}
        </ButtonNext>
      </DropdownItem>
    </DropdownBody>
  </DropdownContainer>
</template>
