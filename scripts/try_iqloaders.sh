#!/usr/bin/env bash
# Prueba en orden los loaders candidatos de Iqinix/Qualcomm-firehoses.
# Se detiene en el primero que lea el GPT. Solo lectura.
set -u
BASE="$HOME/mi11lite"
OUT="$BASE/edl_dump"
mkdir -p "$OUT"

# orden: primero los que están en la carpeta "No Auth"
CANDIDATES=(
  "/tmp/iqloaders/noauth_778g_2.elf|No Auth 778G (CEDROS+KODIAK)"
  "/tmp/iqloaders/skip_renoir.elf|Auth Skip MI 11 LITE 5G"
  "/tmp/iqloaders/skip_lite_fh.elf|Auth Skip MI 11 LITE 5G (LITE FIREHOSE)"
)

for entry in "${CANDIDATES[@]}"; do
  L="${entry%%|*}"; DESC="${entry##*|}"
  name=$(basename "$L")
  echo "=================================================="
  echo ">>> Probando: $DESC  ($name)"
  log="$OUT/try2_${name}.log"
  timeout 180 edl printgpt --loader="$L" --memory=ufs > "$log" 2>&1
  tail -14 "$log"

  if grep -qiE 'PARTITION|GPT|LUN|partitions' "$log"; then
    echo ">>> *** GPT LEIDO CON $name ***"
    exit 0
  fi
  if grep -qi 'Error on EDL Authentification\|Only nop and sig' "$log"; then
    echo ">>> este loader CARGA pero pide auth -> hace falta otro ciclo de pines para el siguiente"
    exit 2
  fi
  if grep -qiE 'NAK|Invalid data size|not accepted|DeviceClass.*Timed out' "$log"; then
    echo ">>> loader rechazado por Sahara; si el equipo re-enumeró, se prueba el siguiente"
    sleep 3
    if ! lsusb | grep -qi 05c6; then
      echo ">>> el equipo desapareció del USB; hay que re-puentear"
      exit 3
    fi
    continue
  fi
  echo ">>> resultado incierto; revisar $log"
  exit 4
done
echo ">>> ningún candidato funcionó"
exit 1
