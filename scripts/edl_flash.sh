#!/usr/bin/env bash
# FLASHEO COMPLETO EDL - Mi 11 Lite 5G (renoir) - ROM V14.0.7.0.TKIMIXM global
# ESTO BORRA LOS DATOS. Uso: ./edl_flash.sh --si-de-verdad
set -u
[ "${1:-}" = "--si-de-verdad" ] || { echo "Falta confirmacion: ./edl_flash.sh --si-de-verdad"; exit 1; }

BASE="$HOME/mi11lite/fw_full/images"
LOADER="$BASE/prog_firehose_ddr.elf"
LOG="$HOME/mi11lite/edl_dump/flash_$(date +%H%M).log"
mkdir -p "$(dirname "$LOG")"

lsusb | grep -qi '05c6:9008' || { echo "NO hay dispositivo 9008. Conecta en EDL primero."; exit 1; }
[ -f "$LOADER" ] || { echo "Falta el loader $LOADER"; exit 1; }

echo "=== FLASHEO renoir V14.0.7.0.TKIMIXM (6 LUNs) -> $LOG ==="
for lun in 0 1 2 3 4 5; do
  echo "--- LUN $lun ---"
  timeout 1800 edl qfil "$BASE/rawprogram$lun.xml" "$BASE/patch$lun.xml" "$BASE" \
      --loader="$LOADER" --memory=ufs 2>&1 | tee -a "$LOG" | tail -6
  rc=${PIPESTATUS[0]}
  echo "LUN $lun rc=$rc"
  [ "$rc" -ne 0 ] && { echo "!! FALLO en LUN $lun - NO seguir, revisar $LOG"; exit 1; }
done
echo "=== Flasheo terminado. Reiniciando dispositivo ==="
timeout 60 edl reset --loader="$LOADER" --memory=ufs --resetmode=reset 2>&1 | tail -3
echo "Listo. Desconecta el cable y enciende con POWER (la primera vez tarda 3-5 min)."
