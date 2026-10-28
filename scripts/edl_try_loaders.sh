#!/usr/bin/env bash
# Intenta loaders SIN AUTH sobre el renoir. Solo lectura (printgpt).
# Cada loader necesita estar en modo SAHARA (recien puenteado), no en firehose.
set -u
BASE="$HOME/mi11lite/fw_full/images"
OUT="$HOME/mi11lite/edl_dump"
mkdir -p "$OUT"

CANDIDATES=(
  "/tmp/loaders/000c30e100720000_1bebe3863a6781db_fhprg.bin"     # LAHAINA  SM8250 (sin auth)
  "/tmp/loaders/qc_factory_sd765.bin"                            # Qualcomm factory SD765 (sin auth)
  "/tmp/loaders/0014d0e100720000_1bebe3863a6781db_fhprg.bin"     # SM6150/7150 (sin auth)
)

for L in "${CANDIDATES[@]}"; do
  name=$(basename "$L")
  echo "================ $name ================"
  log="$OUT/try_$(basename "$L" .bin).log"
  timeout 150 edl printgpt --loader="$L" --memory=ufs > "$log" 2>&1
  rc=$?
  tail -12 "$log"
  if grep -qi 'Error on EDL Authentification' "$log"; then
    echo ">>> RESULTADO: este loader TAMBIEN pide auth. Necesita ciclo de energia para el siguiente."
    echo ">>> ESTADO: firehose (auth bloqueada)"
    exit 2
  fi
  if grep -qiE 'Partition name|LUN|GPT' "$log" && [ $rc -eq 0 ]; then
    echo ">>> RESULTADO: *** GPT LEIDO OK *** loader aceptado: $name"
    echo ">>> ESTADO: EXITO"
    exit 0
  fi
  if grep -qiE 'sahara|not accepted|Failed to load|Invalid' "$log"; then
    echo ">>> RESULTADO: el loader no cargo (sahara). El siguiente SI se puede probar sin ciclo."
    continue
  fi
  echo ">>> RESULTADO incierto (rc=$rc). Revisar $log"
  exit 3
done
echo ">>> Ningun candidato funciono."
