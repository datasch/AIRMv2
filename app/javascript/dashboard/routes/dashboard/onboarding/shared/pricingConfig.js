export const CURRENCIES = {
  PEN: {
    code: 'PEN',
    symbol: 'S/',
    label: 'Soles (PEN)',
    country: 'PE',
  },
  USD: {
    code: 'USD',
    symbol: '$',
    label: 'Dólares (USD)',
    country: 'US',
  },
};

export const PLANS = {
  pilot_3_days: {
    id: 'pilot_3_days',
    titleKey: 'REGISTER.ACTIVATION.PLANS.PILOT_TITLE',
    descKey: 'REGISTER.ACTIVATION.PLANS.PILOT_DESC',
    pricing: {
      PEN: {
        amount: 18,
        amountCents: 1800,
        formatted: 'S/ 18.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.ONCE_3_DAYS',
      },
      USD: {
        amount: 5,
        amountCents: 500,
        formatted: '$5.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.ONCE_3_DAYS',
      },
    },
    features: [
      'REGISTER.ACTIVATION.FEATURES.PILOT_1',
      'REGISTER.ACTIVATION.FEATURES.PILOT_2',
      'REGISTER.ACTIVATION.FEATURES.PILOT_3',
    ],
  },
  full_setup: {
    id: 'full_setup',
    titleKey: 'REGISTER.ACTIVATION.PLANS.SETUP_TITLE',
    descKey: 'REGISTER.ACTIVATION.PLANS.SETUP_DESC',
    pricing: {
      PEN: {
        amount: 1500,
        amountCents: 150000,
        formatted: 'S/ 1,500.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.ONE_TIME',
      },
      USD: {
        amount: 399,
        amountCents: 39900,
        formatted: '$399.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.ONE_TIME',
      },
    },
    features: [
      'REGISTER.ACTIVATION.FEATURES.SETUP_1',
      'REGISTER.ACTIVATION.FEATURES.SETUP_2',
      'REGISTER.ACTIVATION.FEATURES.SETUP_3',
      'REGISTER.ACTIVATION.FEATURES.SETUP_4',
    ],
  },
  monthly_maintenance: {
    id: 'monthly_maintenance',
    titleKey: 'REGISTER.ACTIVATION.PLANS.MAINTENANCE_TITLE',
    descKey: 'REGISTER.ACTIVATION.PLANS.MAINTENANCE_DESC',
    pricing: {
      PEN: {
        amount: 300,
        amountCents: 30000,
        formatted: 'S/ 300.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.MONTHLY',
      },
      USD: {
        amount: 79,
        amountCents: 7900,
        formatted: '$79.00',
        periodKey: 'REGISTER.ACTIVATION.PERIODS.MONTHLY',
      },
    },
    features: [
      'REGISTER.ACTIVATION.FEATURES.MAINT_1',
      'REGISTER.ACTIVATION.FEATURES.MAINT_2',
      'REGISTER.ACTIVATION.FEATURES.MAINT_3',
    ],
  },
};

export const detectDefaultCurrency = () => {
  if (typeof window === 'undefined') return CURRENCIES.PEN.code;

  const urlParams = new URLSearchParams(window.location.search);
  const paramCurrency = urlParams.get('currency');
  if (paramCurrency && CURRENCIES[paramCurrency.toUpperCase()]) {
    return paramCurrency.toUpperCase();
  }

  try {
    const saved = sessionStorage.getItem('airm_preferred_currency');
    if (saved && CURRENCIES[saved]) return saved;
  } catch {
    // Ignore error
  }

  // Detect timezone or language for Peru
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
  const language = navigator.language || '';
  if (timeZone.includes('Lima') || language.toLowerCase() === 'es-pe') {
    return CURRENCIES.PEN.code;
  }

  return CURRENCIES.PEN.code; // Default to PEN for domestic focus
};
