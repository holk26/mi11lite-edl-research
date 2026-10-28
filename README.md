# Mi 11 Lite 5G (renoir) — ingeniería de la reparación por EDL

Notas y herramientas de una sesión real de recuperación de un **Xiaomi Mi 11 Lite 5G
(`renoir`, SM7350 "cedros")** que quedó bloqueado: solo modo **EDL 9008**, bootloader
de fábrica bloqueado, sin `recovery` (esquema A/B) y sin imagen de arranque válida.

El objetivo del repo es documentar **qué se probó, qué falló con qué error literal y
por qué**, para que otro dueño de un renoir brickeado no repita el camino.

## Resultado en una línea

Todas las vías offline están cerradas criptográficamente: el PBL verifica la firma del
loader, el auth EDL de Xiaomi usa **RSA-2048 con nonce por sesión**, no hay loader
no-auth público para `HWID 001590e1…` y no existe `recovery`. Las salidas reales son
**cuenta Xiaomi autorizada (MiFlash)**, **programador UFS por ISP** (EasyJTAG/UFI) o
**cambio de placa**.

## Contenido

```
docs/
  LEEME-REPARACION.md     estado del equipo, qué funciona y qué bloquea
  REA-analisis-auth.md    ingeniería inversa del auth (REA + Ghidra): mapa, parches,
                          por qué el PBL los rechaza, PKCS#1 v1.5 verificado
  TABLA-particiones.md    tabla completa de particiones/LUN/sectores/MD5
  TECNICO-briefing.md     briefing para taller: opciones A (MiFlash) y B (ISP)
diagnostics/
  DIAGNOSTICO-mi11lite.txt  salidas literales de fastboot, Sahara, firehose y edlclient
scripts/
  edl_probe.sh        sonda SOLO lectura (GPT, boot_a, misc, respaldo de identidad)
  edl_flash.sh        flasheo completo por LUN (requiere loader autorizado)
  edl_try_loaders.sh  prueba loaders no-auth candidatos (solo printgpt)
  try_iqloaders.sh    prueba loaders de terceros en orden
```

## Lo que NO está en el repo

Por tamaño y por ser material propietario: ROMs oficiales (`*.tgz`, `*.zip`),
loaders `prog_firehose*.elf`, imágenes de particiones y volcados (`edl_dump/`).
Las notas indican la ROM exacta y su MD5 para verificarla antes de usarla.

## Datos saneados

Este repositorio **no** contiene datos del equipo ni personales: el serial del
dispositivo, el `SN` de la sesión EDL, el sufijo del HWID y las rutas locales están
sustituidos por marcadores (`<DEVICE_SERIAL>`, `<EDL_SESSION_SN>`, `$HOME/...`).

## Aviso

Uso educativo/diagnóstico sobre hardware propio. Flashear borra los datos del
equipo; algunos procedimientos (ISP, glitching) implican riesgo de daño físico.
