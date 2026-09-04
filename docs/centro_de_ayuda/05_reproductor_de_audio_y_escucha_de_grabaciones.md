# 05. Reproductor de Audio y Escucha de Grabaciones

Todas las llamadas salientes y entrantes que alcancen la condición de **Efectiva** ($\ge 6$ segundos) o **Prueba** ($2-5$ segundos) son grabadas automáticamente por nuestra central PBX Asterisk para fines de calidad, seguridad y auditoría.

---

## 🎧 1. ¿Dónde Puedo Escuchar la Grabación de una Llamada?

Tienes dos lugares dentro de AIRM para escuchar y revisar cualquier llamada:

### Método 1: En el Hilo del Chat (Conversación)
Apenas finaliza una llamada, el sistema inserta un mensaje de actividad visible para ti y tu equipo dentro del chat del cliente:

```
📞 Llamada finalizada • 🟢 Efectiva (>= 6s)
• Agente: Juan Pérez
• Número: +51913***096
• Duración: 02:45
• Tipificación de llamada: Venta

🎧 Grabación de llamada:
[ ▶️ || ──────────●───── 02:45 🔊 ]
```

Solo debes hacer clic en el botón **Play (▶️)** para escuchar la conversación directamente en el navegador.

---

### Método 2: En el Reporte de Click-to-call (Supervisores y Asesores)
1. En el menú lateral izquierdo, dirígete a **Informes** $\rightarrow$ **Click-to-call**.
2. Desplázate hacia la sección inferior: **"Historial y Grabaciones de Llamadas"**.
3. Encontrarás la tabla cronológica con:
   - Fecha y hora exacta.
   - Nombre del asesor.
   - Teléfono marcado.
   - Duración de la llamada.
   - Clasificación (`🟢 Efectiva`, `🟡 Prueba`, `🔴 No efectiva`).
   - Tipificación comercial.
   - Reproductor interactivo de audio integrado en la columna derecha.

---

## ⚙️ 2. Controles del Reproductor de Audio

El reproductor soporta todas las funciones estándar de HTML5:
- **Reproducir / Pausar:** Inicia o detiene la reproducción del audio.
- **Barra de Desplazamiento (Seek):** Permite avanzar o retroceder a cualquier segundo de la llamada.
- **Control de Volumen:** Ajusta el nivel de audio o siléncialo.
- **Menú de Tres Puntos (Opciones):** Permite cambiar la velocidad de reproducción ($1.5\times$, $2\times$) para auditar llamadas extensas en menor tiempo, o descargar el archivo de audio (`.wav`) si cuentas con permisos habilitados.

---

## 🔒 3. Seguridad y Privacidad de los Audios

- Los archivos de audio están protegidos dentro de la infraestructura privada del servidor Asterisk.
- Solo los usuarios autenticados pertenecientes a tu organización pueden reproducir los audios.
- El sistema cuenta con mecanismos de protección que impiden el acceso a grabaciones de otras empresas o cuentas.
