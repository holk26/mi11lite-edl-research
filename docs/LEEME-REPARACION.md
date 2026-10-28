# Reparación Xiaomi Mi 11 Lite 5G (renoir) — estado y qué falta

Serial `<DEVICE_SERIAL>` · HWID `0x001590e1XXXXXXXX` (MSM_ID `0x001590e1`, CPU **cedros** = SM7350)
PK_HASH `1bebe3863a6781db4b01086063007334de4...` (raíz Xiaomi)
Estado: **solo EDL 9008 responde. Fastboot bloqueado. Sin imagen de arranque válida.**

## Diagnóstico en una línea
El slot A está marcado `slot-unbootable: yes` y `fastboot continue` responde
`Failed to load image from partition: Load Error` → el bootloader no puede cargar
el boot image. Bootloader **locked** (`unlocked:no`, `critical unlocked:false`,
`Verity mode:false`), así que no se puede flashear, ni cambiar de slot, ni
`fastboot boot`. No hay partición `recovery` (esquema A/B).

## Lo que SÍ funciona
- Entrada a **EDL 9008** por test points: aparece como `05c6:9008`,
  `QUSB_BULK_CID:0425_SN:<EDL_SESSION_SN>`.
- El programmer oficial (`prog_firehose_ddr.elf` de la ROM) **carga** por Sahara:
  Sahara v2, 64-bit, HWID/PK_HASH leídos correctamente.

## Lo que BLOQUEA
Toda operación tras cargar el programmer muere en:
```
firehose - [LIB]: Error on EDL Authentification
```
Probado y descartado: `printgpt`, `qfil`, lectura de sectores (`rs`), `peek`,
`secureboot`, con `--skipstorageinit`, con `prog_firehose_lite.elf`,
y con el loader exacto del HWID (`001590e1XXXXXXXX_..._fhprg_edlauth.bin`).

Loaders SIN auth probados (de github.com/bkerler/Loaders, mismo PK_HASH):
| Loader | Resultado |
|---|---|
| `000c30e1…` LAHAINA SM8250 | Sahara NAK `0x12` (dirección de destino inválida — incompatible con cedros) |
| `qc_factory_sd765` SM7150 | no sube |
| `0014d0e1…` SM6150/7150 | no sube |
→ **No existe loader no-auth público para cedros/renoir** (confirmado también en
  github.com/bkerler/Loaders/issues/133, abierto por otro dueño de renoir brickeado).

## Qué necesita el técnico (una de estas dos)
1. **Cuenta Xiaomi autorizada (MiFlash/EDL auth)** — lo estándar en talleres.
2. **Loader no-auth específico para `HWID 001590e1XXXXXXXX` + PK `1bebe386…`**
   (los servicios de unbrick remoto lo tienen; con eso se flashea desde Linux
   con `edlclient`, sin Windows).

## Material ya listo en esta carpeta
- `renoir_global_images_V14.0.7.0.TKIMIXM_…tgz` (6.3 GB) — MD5 `e21e2a7d857b7cbf294da846089ce577`
  ✅ coincide con el hash del nombre → **es la ROM correcta** (global, Android 13).
- `fw_full/images/` — ROM extraída (87 archivos), con `prog_firehose_ddr.elf`,
  `rawprogram0-5.xml`, `patch0-5.xml`, `super.img`, `boot.img`…
- `miui_RENOIRGlobal_V14.0.7.0.TKIMIXM_…zip` — recovery ROM, MD5 ✅ (no aplicable: sin recovery).
- `edl_probe.sh` — sonda de solo lectura.
- `edl_flash.sh --si-de-verdad` — flasheo completo por LUN (listo, sin ejecutar).
- `DIAGNOSTICO-mi11lite.txt` — todas las pruebas y errores literales.

## Cómo se flashearía (una vez con acceso)
```bash
cd "fw_full/images"
for lun in 0 1 2 3 4 5; do
  edl qfil rawprogram$lun.xml patch$lun.xml . \
      --loader=prog_firehose_ddr.elf --memory=ufs
done
edl reset --loader=prog_firehose_ddr.elf --memory=ufs --resetmode=reset
```
Duración ~10-20 min. **Borra `userdata`** (los datos ya son inaccesibles).
**NO** toca `persist`, `modemst1/2`, `fsc`, `fsg` → **el IMEI se conserva**
(verificado leyendo los 6 `rawprogram`).

## Riesgo residual
`version-bootloader` y `version-baseband` vacíos y `battery-voltage: 0` en fastboot.
No se descarta fallo de UFS: si tras el flasheo EDL el equipo sigue sin arrancar,
el problema es hardware (almacenamiento), no software.

## Anexo: ingeniería inversa del auth (REA + Ghidra) — intento de parche
Ver `REA-analisis-auth.md`. Resumen: se localizó la verificación
(`0x14825280`, flag `DAT_148cc71d`, clave `0x148a0738`), se construyó un parche
de 3 bytes que fuerza "EDL Authenticated", y se probó en el equipo:
**el PBL rechaza cualquier loader modificado** (probado también con 1 byte
cosmético en un string). La integridad del loader está firmada → no se puede
parchear ni firmar sin las claves de Xiaomi/Qualcomm.
