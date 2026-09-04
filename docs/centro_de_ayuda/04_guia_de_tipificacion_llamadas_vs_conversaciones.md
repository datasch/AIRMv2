# 04. Guía de Tipificación: Llamadas vs Conversaciones

En AIRM contamos con **dos métricas independientes de tipificación**:
1. **Tipificación de la Llamada Telefónica:** Evalúa el resultado específico de la llamada que acabas de realizar.
2. **Tipificación de la Conversación (Chat):** Evalúa la etapa comercial global del prospecto en el chat.

Esta separación permite saber si un asesor avanza a sus clientes mediante llamadas telefónicas o si los gestiona puramente por chat.

---

## 📋 Diccionario de Estados de Tipificación

A continuación se detalla el significado de cada estado disponible en el sistema:

### 💼 Grupo Comercial (Habilitado para Llamadas Efectivas)
- **Venta:** El cliente aceptó la propuesta comercial, realizó el pago o completó la compra con éxito.
- **Interesado:** El cliente mostró interés genuino en el producto/servicio y solicitó más detalles, cotización o catálogo.
- **Agendado:** Se programó una cita, reunión virtual o llamada de seguimiento para una fecha y hora acordada.
- **Volver a llamar:** El cliente solicitó ser contactado más tarde porque se encuentra manejando, en reunión o trabajando.

### 🔍 Grupo de Seguimiento y Casuísticas
- **Persona mayor:** El titular o quien atendió es una persona de la tercera edad que no toma decisiones de compra o requiere asistencia de un familiar.
- **Saturación:** El prospecto indica que ya ha sido contactado múltiples veces por otros asesores o campañas en un corto período.
- **No interesado:** El cliente rechaza explícitamente el producto o servicio y no desea recibir más información.
- **Buzón de voz:** La llamada fue desviada a la contestadora automática.
- **No contesta:** Timbró sin respuesta por parte del usuario.
- **Número equivocado:** El número telefónico no corresponde a la persona buscada o está fuera de servicio.

---

## 🔄 ¿Cómo Funciona la Sincronización Automática?

Al terminar una llamada en el marcador, verás la tarjeta de **Tipificación de Llamada**:

1. Seleccionas el estado correspondiente (ej. *Interesado*).
2. Verás una casilla marcada por defecto:  
   ☑️ **"Guardar también en conversación"**
3. Al hacer clic en **"Guardar Tipificación"**:
   - Se guarda el registro en el historial telefónico con su grabación y duración.
   - Si la casilla está activa, el atributo **Tipificación** de la conversación en el chat se actualiza automáticamente con el mismo valor, ahorrándote tiempo.
4. Si solo deseas registrar el resultado de la llamada sin alterar la etapa del chat, simplemente desmarca la casilla antes de guardar.

---

## 💬 Tipificación Manual en el Chat (Sin Llamada)

Si estás atendiendo a un cliente exclusivamente por WhatsApp, Instagram o Live Chat y no fue necesario llamarlo:

1. Ve al panel lateral derecho de la conversación.
2. En la sección **"Información de la conversación"**, busca el campo **Tipificación**.
3. Selecciona el estado comercial correspondiente en el menú desplegable.
4. El cambio se guarda automáticamente y se refleja en los reportes de conversación de la empresa.
