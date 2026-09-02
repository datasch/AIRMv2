# Configuración Asterisk PBX WebRTC + VoIPRabbit para AIRM

Este directorio contiene la configuración lista para que el contenedor de Asterisk funcione con:
1. **WebRTC WebSocket (WSS / WS)** en el puerto `8089`.
2. **Troncal SIP VoIPRabbit** en `149.20.185.4:5060` (autenticación por IP).
3. **Identificador / Caller ID**: `51913086096`.
4. **Extensiones WebRTC**: `1001`, `1011`, `1012`, `1013`, `1014`.

---

## Archivos incluidos
* `http.conf`: Habilita el servidor HTTP y WebSocket de Asterisk en el puerto 8089.
* `pjsip.conf`: Define los transportes (`transport-ws` y `transport-udp`), la troncal hacia VoIPRabbit y las extensiones WebRTC con soporte DTLS-SRTP.
* `extensions.conf`: Plan de marcado (Dialplan) que normaliza los números telefónicos de Perú (anteponiendo `51` a los números de 9 dígitos) y envía las llamadas a través de VoIPRabbit con la máscara `51913086096`.
* `rtp.conf`: Rango de puertos RTP (10000-10050) alineado con `docker-compose.prod.yaml`.

---

## Cómo aplicar en tu VPS / Coolify

### Opción A: Copiar directamente al contenedor de Asterisk corriendo en tu VPS
Si tienes acceso SSH a tu servidor VPS (`95.216.197.185`):
```bash
# Copiar los 4 archivos al contenedor
docker cp asterisk/http.conf $(docker ps -qf name=asterisk):/etc/asterisk/
docker cp asterisk/rtp.conf $(docker ps -qf name=asterisk):/etc/asterisk/
docker cp asterisk/extensions.conf $(docker ps -qf name=asterisk):/etc/asterisk/
docker cp asterisk/pjsip.conf $(docker ps -qf name=asterisk):/etc/asterisk/

# Recargar Asterisk
docker exec $(docker ps -qf name=asterisk) asterisk -rx "core reload"
```

### Opción B: Montar la carpeta en `docker-compose.prod.yaml`
En el servicio `asterisk` de tu `docker-compose.prod.yaml`, puedes mapear:
```yaml
    volumes:
      - './asterisk:/etc/asterisk'
```
Y reiniciar el servicio en Coolify.
