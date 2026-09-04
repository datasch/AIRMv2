# 07. Manual del Reporte de Efectividad de Base de Datos y Vueltas

El **Informe de Efectividad de Base de Datos** te permite evaluar qué tan rentable y receptiva es la base de contactos de tu empresa: cuántos mensajes salientes se enviaron en prospección, cuántos prospectos respondieron realmente y **cuántas vueltas (ciclos de reapertura y cierre)** ha dado cada ticket.

---

## 📍 1. Cómo Acceder al Reporte

1. En el menú lateral izquierdo de AIRM, haz clic en **Informes**.
2. Selecciona la opción **Base de Datos**.

---

## 🧭 2. Ajuste del Rango Temporal

En la parte superior derecha encontrarás el selector de escala temporal para adaptar la vista a tus necesidades de análisis:
- **Hora a hora (Últimas 24h):** Análisis minuto a minuto ideal para lanzamientos de campañas masivas de WhatsApp.
- **Por Días (Últimos 7 días):** Monitoreo semanal de rendimiento.
- **Por Semanas (Último mes):** Evaluación mensual de cohortes de prospección.
- **Por Meses (Histórico reciente):** Visión macro de evolución del negocio.
- **Por Años:** Comparativa anual de volumen y retención.

---

## 📊 3. Indicadores de Prospección y Conversión

1. **Mensajes Salientes:** Total de mensajes enviados por tus agentes y chatbots hacia prospectos en el período.
2. **Prospectos Contactados:** Cantidad de contactos únicos abordados con mensajes salientes.
3. **Prospectos que Respondieron:** Contactos que enviaron al menos un mensaje de respuesta interactiva tras la prospección.
4. **Tasa de Respuesta (%):** Porcentaje de conversión de contacto:
   $$\text{Tasa de Respuesta} = \left( \frac{\text{Prospectos que Respondieron}}{\text{Prospectos Contactados}} \right) \times 100$$
   *Un ratio superior al 30% indica una base de datos de alta calidad y un mensaje inicial atractivo.*
5. **Tickets Resueltos (Cierres):** Número total de eventos en que una conversación fue marcada como resuelta.

---

## 🔄 4. ¿Qué son las "Vueltas que ha dado la Base de Datos"?

Una **"vuelta"** representa un ciclo completo de vida de un ticket de atención: **Apertura $\rightarrow$ Gestión $\rightarrow$ Cierre (Resolución) $\rightarrow$ Reapertura**.

Medir las vueltas te ayuda a entender si tus clientes compran una sola vez o si reabren la conversación repetidamente para nuevas compras o consultas:

```
[ Prospecto Ingresa ] ──> [ Gestión ] ──> [ 1er Cierre ]  (1 Vuelta)
                                                │
                 ┌──────────────────────────────┘ (Cliente vuelve a escribir)
                 ▼
          [ Reapertura ] ──> [ Gestión ] ──> [ 2do Cierre ]  (2 Vueltas)
                                                │
                 ┌──────────────────────────────┘
                 ▼
          [ Reapertura ] ──> [ Gestión ] ──> [ 3er Cierre ]  (3 Vueltas)
```

### Segmentación de Vueltas en el Tablero:
- **1 Vuelta (Cierre inicial):** El cliente fue contactado, atendido y su consulta o compra se resolvió en una sola interacción.
- **2 Vueltas (Reabierto 1 vez):** El cliente volvió a escribir días después, reactivando el ticket para una segunda compra o seguimiento.
- **3 Vueltas (Reabierto 2 veces):** Base recurrente con múltiples compras o atenciones periódicas.
- **$\ge$ 4 Vueltas (Alta rotación / Reciclado):** Contactos VIP o altamente fidelizados que interactúan de manera constante con la empresa.

---

## 📅 5. Tabla de Evolución Cronológica

En la sección inferior del reporte, la tabla cronológica te muestra la evolución histórica:
- **Período / Fecha:** Marca temporal de acuerdo con el filtro seleccionado.
- **Mensajes Salientes Enviados:** Volumen de outbound generado.
- **Respuestas Recibidas:** Nivel de interacción entrante del público.
- **Cierres Realizados:** Capacidad del equipo para liquidar y resolver casos.
- **% Ratio Respuesta:** Eficiencia neta de cada día, semana o mes.

---

## 💡 ¿Cómo Aprovechar este Informe?
- **Depurar Listas Frías:** Si un segmento de base de datos tiene una tasa de respuesta inferior al 5%, es recomendable filtrar y depurar los números no válidos para evitar saturación de tu canal de WhatsApp.
- **Identificar Recompra:** Analiza cuántos contactos tienen 2 o más vueltas para medir la tasa de retención (*LTV*) de tus clientes sin necesidad de herramientas externas.
