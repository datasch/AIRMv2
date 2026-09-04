# 02. Cómo Realizar y Cancelar Llamadas al Instante

Este artículo te explica el flujo completo de una llamada saliente y la nueva función de **cancelación inmediata**, diseñada para que puedas colgar en el mismo segundo si marcaste por error o si el cliente no está disponible.

---

## 📲 1. Estados de la Llamada en el Marcador

Cuando inicias una llamada, el marcador pasará por las siguientes etapas:

```
[ Marcando / Timbrando ] ---> [ En Llamada / Conectado ] ---> [ Tipificación ]
            |
            v (Si presionas Cancelar)
     [ Cancelación Inmediata / Idle ]
```

---

## ⚡ 2. Cancelación Inmediata Durante el Timbrado (*Early Hangup*)

### ¿Qué ocurría antes?
Si marcabas a un número equivocado, debías esperar varios segundos hasta que el operador telefónico respondiera, diera ocupado o saltara la contestadora de voz.

### ¿Cómo funciona ahora?
Apenas inicias la llamada, mientras ves en pantalla el mensaje **"Marcando / Timbrando..."**, tienes a tu disposición un botón rojo claramente visible:

> **[ ⏹️ Colgar / Cancelar llamada ]**

Al hacer clic en este botón:
1. La llamada se **cancela al instante** en la red telefónica (no continuará timbrando en el teléfono del cliente).
2. El audio y los tonos de llamada se cortan de inmediato.
3. El marcador queda libre de inmediato para que puedas continuar atendiendo otros chats o marcar nuevamente.
4. El sistema registra internamente una llamada cancelada con 0 segundos de duración.

---

## 🎙️ 3. Controles Durante la Llamada Activa

Una vez que el cliente contesta tu llamada, el cronómetro empezará a contar y tendrás tres controles principales:

| Botón | Función | ¿Cuándo usarlo? |
| :---: | :--- | :--- |
| 🎤 **Mute / Silenciar** | Apaga tu micrófono temporalmente. El botón cambiará a color amarillo/ámbar indicando que tu audio está en silencio. | Si necesitas estornudar, consultar un dato en voz alta con un compañero o revisar el sistema. |
| 🔢 **Teclado DTMF** | Despliega un teclado numérico táctil para emitir tonos de marcación. | Si llamas a un conmutador o centralita que te pide *"Presione 1 para ventas o 2 para soporte"*. |
| 🔴 **Colgar** | Finaliza la llamada inmediatamente. | Cuando concluyas la conversación con el cliente. |

---

## 💡 Consejo Pro
Si la llamada se corta inesperadamente debido a baja señal del cliente, no te preocupes: el sistema registrará los segundos que duró la llamada y te permitirá tipificar el motivo antes de volver a intentar la comunicación.
