# 02. Grabaciones de Audio, MixMonitor y Streaming

Este documento describe la arquitectura de grabación de llamadas en tiempo real mediante Asterisk PBX, el almacenamiento compartido en volúmenes Docker y la entrega en streaming HTTP seguro hacia el navegador del asesor y supervisor.

---

## 1. Pipeline de Grabación en Asterisk PBX

Para garantizar que cada llamada quede grabada y correlacionada con exactitud con los registros de la base de datos de Chatwoot/AIRM:

1. El frontend genera un UUID único para la llamada antes del marcado:
   ```javascript
   const callId = `call_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
   ```
2. Este identificador se inyecta como encabezado SIP personalizado en el `INVITE`:
   ```javascript
   extraHeaders.push(`X-Call-ID: ${callId}`);
   ```
3. El Dialplan de Asterisk ejecuta la subrutina `[sub-start-recording]` antes del comando `Dial`:
   ```ini
   [sub-start-recording]
   exten => s,1,NoOp(--- Iniciando grabacion automatica de llamada ---)
    same => n,Set(CALL_UUID=${PJSIP_HEADER(read,X-Call-ID)})
    same => n,ExecIf($[${LEN(${CALL_UUID})} < 3]?Set(CALL_UUID=${UNIQUEID}))
    same => n,Set(REC_FILE=/var/spool/asterisk/monitor/${CALL_UUID})
    same => n,NoOp(Archivo de grabacion: ${REC_FILE}.wav)
    same => n,MixMonitor(${REC_FILE}.wav,b)
    same => n,Return()
   ```

### Parámetros de MixMonitor:
- `${REC_FILE}.wav`: Ruta completa del archivo generado.
- Flag `b`: Inicia la grabación únicamente cuando los canales de audio se encuentran enlazados (evita grabar silencios prolongados de red). Ambos canales (voz del cliente y voz del asesor) son mezclados en un archivo estéreo/mono estándar PCM WAV de 8 kHz / 16-bit.

---

## 2. Almacenamiento y Volúmenes Docker

Para que los contenedores de Rails y Sidekiq puedan acceder a los archivos de audio generados por el contenedor de Asterisk sin exponer puertos ni sockets inseguros, se utiliza un volumen compartido gestionado por Docker:

En [docker-compose.prod.yaml](file:///home/giantucchi/Proyectos/chatwoot/docker-compose.prod.yaml):

```yaml
services:
  asterisk:
    volumes:
      - 'asterisk_spool:/var/spool/asterisk/monitor'
      - './asterisk:/etc/asterisk'

  rails:
    volumes:
      - 'storage_data:/app/storage'
      - 'asterisk_spool:/var/spool/asterisk/monitor:ro'

  sidekiq:
    volumes:
      - 'storage_data:/app/storage'
      - 'asterisk_spool:/var/spool/asterisk/monitor:ro'

volumes:
  storage_data:
  asterisk_spool:
```

> [!NOTE]
> El montaje en `rails` y `sidekiq` es en modo lectura estricta (`:ro`), garantizando la integridad de los archivos ante cualquier operación de la aplicación web.

---

## 3. Controlador de Streaming Seguro (`VoipController#recording`)

El endpoint expuesto en la API permite servir el audio directamente en streaming hacia el reproductor del navegador:

- **Ruta:** `GET /api/v1/accounts/:account_id/voip/recordings/:id`
- **Controlador:** [Api::V1::Accounts::VoipController#recording](file:///home/giantucchi/Proyectos/chatwoot/app/controllers/api/v1/accounts/voip_controller.rb)

### Implementación y Medidas de Seguridad:
```ruby
def recording
  # 1. Sanitización estricta para evitar Path Traversal (evita ../ o caracteres de escape)
  call_id = params[:id].to_s.gsub(/[^a-zA-Z0-9_\-]/, '')
  filename = "#{call_id}.wav"

  # 2. Rutas de búsqueda seguras
  search_paths = [
    "/var/spool/asterisk/monitor/#{filename}",
    Rails.root.join('storage', 'recordings', filename).to_s,
    Rails.root.join('tmp', 'recordings', filename).to_s
  ]

  file_path = search_paths.find { |p| File.exist?(p) }

  # 3. Envío inline para reproducción directa en navegador (HTML5 <audio>)
  if file_path.present?
    send_file file_path, type: 'audio/wav', disposition: 'inline'
  else
    render plain: 'Audio recording not found', status: :not_found
  end
end
```

---

## 4. Renderizado en Mensajes y en la UI

### A. Mensaje de Actividad en la Conversación
Cuando la llamada finaliza y fue catalogada como **Efectiva** ($\ge 6$s) o **Prueba** ($2-5$s), Rails inserta automáticamente un mensaje de tipo `activity` en el chat:

```html
🎧 **Grabación de llamada:**
<audio controls class="w-full mt-2 rounded border border-slate-700 bg-slate-900/50" preload="none">
  <source src="/api/v1/accounts/1/voip/recordings/call_1788460000_a1b2c3" type="audio/wav">
  Tu navegador no soporta el reproductor de audio.
</audio>
```

### B. Tabla del Reporte Click-to-call
En [ClickToCallReports.vue](file:///home/giantucchi/Proyectos/chatwoot/app/javascript/dashboard/routes/dashboard/settings/reports/ClickToCallReports.vue), cada fila de llamada cuenta con su reproductor compacto:

```html
<audio
  v-if="call.recording_url && (call.call_category === 'effective' || call.call_category === 'test')"
  controls
  preload="none"
  class="h-8 max-w-[220px] rounded-lg"
>
  <source :src="call.recording_url" type="audio/wav" />
</audio>
```
El atributo `preload="none"` asegura que el navegador no descargue el audio hasta que el usuario haga clic en reproducir, optimizando el consumo de ancho de banda del servidor.
