import { ref } from 'vue';

let culqiScriptPromise = null;

export const loadCulqiScript = () => {
  if (typeof window === 'undefined') return Promise.resolve();
  if (window.Culqi) return Promise.resolve(window.Culqi);

  if (!culqiScriptPromise) {
    culqiScriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://checkout.culqi.com/js/v4';
      script.async = true;
      script.onload = () => resolve(window.Culqi);
      script.onerror = err => reject(err);
      document.head.appendChild(script);
    });
  }

  return culqiScriptPromise;
};

export const useCulqiCheckout = () => {
  const isOpening = ref(false);
  const isScriptLoaded = ref(false);

  const initCulqi = async publicKey => {
    try {
      await loadCulqiScript();
      if (window.Culqi) {
        window.Culqi.publicKey = publicKey || 'pk_live_airm_default';
        isScriptLoaded.value = true;
      }
    } catch {
      // Handle script loading error
    }
  };

  const openCheckout = ({
    title,
    currency,
    amountCents,
    orderId,
    onSuccess,
    onError,
  }) => {
    if (!window.Culqi) return;

    window.Culqi.settings({
      title: title || 'Activación Recepcionista IA',
      currency: currency || 'PEN',
      amount: amountCents || 1800,
      order: orderId || undefined,
    });

    window.Culqi.options({
      lang: 'es',
      installments: true,
      paymentMethods: {
        tarjeta: true,
        yape: currency === 'PEN',
        billetera: true,
        bancaMovil: true,
        agente: true,
        cuotealo: false,
      },
    });

    window.culqi = () => {
      if (window.Culqi.token) {
        onSuccess?.({
          type: 'token',
          token: window.Culqi.token.id,
          email: window.Culqi.token.email,
        });
      } else if (window.Culqi.order) {
        onSuccess?.({
          type: 'order',
          order: window.Culqi.order,
        });
      } else if (window.Culqi.error) {
        onError?.(window.Culqi.error);
      }
      window.Culqi.close();
    };

    window.Culqi.open();
  };

  return {
    isOpening,
    isScriptLoaded,
    initCulqi,
    openCheckout,
  };
};
