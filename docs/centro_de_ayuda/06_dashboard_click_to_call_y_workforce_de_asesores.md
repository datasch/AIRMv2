# 06. Manual del Reporte de Click-to-call y Workforce de Vendedores

El módulo **Reporte de Click-to-call** proporciona una visión integral de la actividad telefónica de tu equipo comercial, permitiendo a líderes y supervisores medir la efectividad de contacto, los tiempos de conversación y la productividad individual de cada vendedor.

---

## 📍 1. Cómo Ingresar al Reporte

1. Inicia sesión con tu cuenta en AIRM.
2. En el menú lateral izquierdo, haz clic en **Informes** (icono de gráfico).
3. Selecciona la opción **Click-to-call**.

---

## 📊 2. Indicadores Principales (KPI Cards)

En la parte superior del tablero encontrarás 4 tarjetas clave:

1. **Total Llamadas:** Suma absoluta de todas las llamadas telefónicas emitidas en el rango de fechas seleccionado.
2. **Llamadas Efectivas (&ge; 6s):** Conteo de llamadas donde se confirmó contacto real con el cliente. Muestra al lado el **% de efectividad comercial**.
3. **No Efectivas / Pruebas:** Llamadas no atendidas, números ocupados o buzones de voz, junto con el desglose de llamadas de prueba de corta duración ($2-5$s).
4. **TMO Promedio (Tiempo Medio de Operación):** Duración media por llamada en formato `MM:SS`. Te permite identificar si las conversaciones son breves o si los asesores profundizan en la argumentación de venta.

---

## 📈 3. Gráficas de Análisis Temporal

### A. Llamadas por Día (Tendencia Diaria)
Compara en barras visuales de color esmeralda y azul el total de llamadas versus las llamadas efectivas en los últimos días, permitiendo evaluar si la calidad del contacto se mantiene constante a lo largo de la semana.

### B. Distribución Horaria (00:00 a 23:00)
Muestra un histograma interactivo de 24 columnas que representa el volumen de llamadas en cada hora del día:
- Te permite identificar las **horas punta** de mayor contacto con tus clientes (ej. 10:00 a 12:00 y 15:00 a 17:00).
- Útil para programar las jornadas de llamadas de los vendedores en los momentos con mayor probabilidad de respuesta.

---

## 👥 4. Matriz de Workforce y Productividad por Asesor

La tabla de Workforce detalla el rendimiento individual de cada vendedor:

| Columna | Significado | Objetivo Esperado |
| :--- | :--- | :--- |
| **Vendedor / Asesor** | Nombre y correo del agente | - |
| **Llamadas Totales** | Volumen de llamadas realizadas | Cumplir la meta diaria de prospección |
| **Efectivas (&ge; 6s)** | Llamadas donde hubo conversación | Maximizar el número de contactos reales |
| **% Efectividad** | Ratio entre efectivas y totales | **$\ge 50\%$** (Verde) |
| **TMO** | Tiempo promedio por llamada | Entre 2 y 4 minutos en ventas consultivas |
| **No Efectivas / Pruebas** | Llamadas sin respuesta o descartadas | Minimizar mediante depuración de base de datos |
| **Tipificaciones Destacadas** | Conteo de ventas, citas agendadas e interesados | Evaluar cierres efectivos del vendedor |

---

## 🎯 Recomendaciones para Supervisores
- **Auditoría Cruzada:** Selecciona a los asesores con mayor % de efectividad y escucha sus grabaciones en la tabla inferior para replicar sus mejores prácticas con el resto del equipo.
- **Detección de Cuellos de Botella:** Si un vendedor tiene muchas llamadas pero un TMO muy bajo (menor a 30 segundos), revisa si está teniendo problemas con prospectos no calificados o falta de argumentos de enganche.
