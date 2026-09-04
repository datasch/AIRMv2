# 05. Frontend Vue 3, Helper y Componentes de Reportería

Este documento detalla la lógica en el cliente web, la máquina de estados de `voipHelper.js`, el mecanismo de cancelación anticipada (*early hangup*) y la arquitectura de las vistas analíticas.

---

## 1. Máquina de Estados del Marcador (`voipHelper.js`)

El estado reactivo de la telefonía se centraliza en el objeto `voipState`:

```javascript
export const voipState = reactive({
  isConfigured: false,
  isEnabled: false,
  isRegistered: false,
  registrationError: null,
  activeCalls: [],
  currentSession: null,
  callState: 'idle', // 'idle' | 'calling' | 'ringing' | 'connected' | 'ended' | 'disposition'
  remoteNumber: '',
  remoteDisplayName: '',
  callDuration: 0,
  isMuted: false,
  isOnHold: false,
  isDialerOpen: false,
  conversationId: null,
  callId: null,
  lastCallDuration: 0,
  lastCallStatus: 'completed',
  lastCallCategory: 'ineffective',
});
```

### Transiciones de Estado:
1. `idle` $\rightarrow$ `calling`: Al disparar `makeCall(number, conversationId)`.
2. `calling` $\rightarrow$ `connected`: Al recibir el evento `accepted` de JsSIP.
3. `connected` $\rightarrow$ `disposition`: Al terminar la llamada si hubo duración o contacto.
4. `calling` $\rightarrow$ `idle`: Si el usuario cancela de inmediato antes de contestar.
5. `disposition` $\rightarrow$ `idle`: Al guardar u omitir la tipificación.

---

## 2. Cancelación Inmediata de Llamadas Salientes (*Early Hangup*)

### Problema Resuelto:
Cuando el asesor hacía clic en llamar, si el número era erróneo o deseaba colgar durante el timbrado, JsSIP esperaba la respuesta de red de Asterisk o el timeout de la troncal antes de permitir interacción, dejando la interfaz congelada.

### Solución en Código:
En [app/javascript/dashboard/helper/voipHelper.js](file:///home/giantucchi/Proyectos/chatwoot/app/javascript/dashboard/helper/voipHelper.js):

```javascript
export const hangupCall = () => {
  const wasCalling =
    voipState.callState === 'calling' || voipState.callState === 'ringing';
  const session = voipState.currentSession;

  if (session) {
    try {
      session.terminate({
        status_code: 487,
        reason_phrase: 'Request Terminated',
      });
    } catch (err) {
      // Sesión ya terminada
    }
  }

  // Si se cancela antes de contestar, terminar de inmediato sin esperar el roundtrip SIP
  if (wasCalling) {
    handleCallTermination('cancelled');
  } else if (!session) {
    handleCallTermination('ended');
  }
};
```

Adicionalmente, la función `handleCallTermination` implementa un guardián de idempotencia y apaga el audio de inmediato:
```javascript
const handleCallTermination = status => {
  if (
    voipState.callState === 'idle' ||
    voipState.callState === 'ended' ||
    voipState.callState === 'disposition'
  ) {
    return;
  }

  stopDurationTimer();
  stopRemoteAudio(); // Detiene tracks y silencia el elemento HTML5 de audio

  // Si fue cancelada en timbrado con duración 0, registrar y volver a idle al instante
  if (status === 'cancelled' && finalDuration === 0) {
    VoipAPI.logCall({ ... status: 'cancelled', disposition: 'Llamada cancelada' });
    voipState.callState = 'idle';
    return;
  }

  // Si conectó, pasar a la tarjeta de tipificación
  voipState.callState = 'disposition';
};
```

---

## 3. Componente [VoipDialer.vue](file:///home/giantucchi/Proyectos/chatwoot/app/javascript/dashboard/components/widgets/conversation/VoipDialer.vue)

### Estados Visuales:
- **Marcando / Timbrando:** Muestra animación con icono pulsante y botón rojo: **"Colgar / Cancelar llamada"**.
- **En Llamada:** Cronómetro en formato `MM:SS`, botón de silenciado (Mute con cambio visual de color), teclado numérico DTMF y botón de colgar.
- **Tipificación Post-Llamada:**
  - Badge de clasificación automática:
    - `🟢 Efectiva (>= 6s)`
    - `🟡 Prueba (2 a 5s)`
    - `🔴 No efectiva`
  - Dropdown interactivo con las 10 tipificaciones de negocio.
  - Checkbox para sincronizar automáticamente el resultado con la conversación de Chatwoot.
  - Botones "Guardar Tipificación" y "Omitir".

---

## 4. Vistas de Reportería en el Dashboard

### A. [ClickToCallReports.vue](file:///home/giantucchi/Proyectos/chatwoot/app/javascript/dashboard/routes/dashboard/settings/reports/ClickToCallReports.vue)
- Filtro rápido por períodos: *Hoy*, *Últimos 7 días*, *Últimos 30 días*, *Últimos 90 días*.
- 4 Tarjetas métricas principales (Total, Efectivas, No Efectivas/Pruebas, TMO).
- Gráficas CSS/Tailwind responsivas:
  - Comparativa diaria (volumen total vs efectivas).
  - Histograma de 24 horas para identificar horas punta.
- Tabla de **Workforce por Asesor** con desglose de tipificaciones.
- Tabla de **Grabaciones de Audio** con reproductor `<audio controls preload="none">`.

### B. [DatabaseReports.vue](file:///home/giantucchi/Proyectos/chatwoot/app/javascript/dashboard/routes/dashboard/settings/reports/DatabaseReports.vue)
- Filtro de resolución temporal: *Hora a hora (24h)*, *Días*, *Semanas*, *Meses*, *Años*.
- Medición de efectividad de base de datos (mensajes salientes, prospectos abordados, respuestas y ratio de efectividad %).
- **Vueltas de la Base de Datos:** Tarjetas de distribución porcentual para 1 vuelta, 2 vueltas, 3 vueltas y $\ge 4$ vueltas.
- Evolución cronológica tabular con cálculo de ratio de respuesta dinámico.
