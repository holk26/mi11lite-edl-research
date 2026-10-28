#!/usr/bin/env bash
# Sonda SOLO-LECTURA para Mi 11 Lite 5G (renoir) en modo EDL 9008.
# No escribe nada en el telefono: solo lee GPT, boot_a, misc y respalda
# las particiones de identidad (persist/modemst/fsc/fsg) por seguridad.
set -u
FW="$HOME/mi11lite/fw_full/images"
OUT="$HOME/mi11lite/edl_dump"
LOADER="$FW/prog_firehose_ddr.elf"
mkdir -p "$OUT"

echo "== 1. Dispositivo 9008 presente? =="
lsusb | grep -i '05c6:9008' || { echo "NO hay 9008 en USB"; exit 1; }

echo "== 2. printgpt (lectura de GPT, sin escribir) =="
timeout 120 edl printgpt --loader="$LOADER" --memory=ufs > "$OUT/gpt_lun0.txt" 2>&1
echo "rc=$? -> $OUT/gpt_lun0.txt"; head -15 "$OUT/gpt_lun0.txt"

echo "== 3. Respaldo de identidad (persist/modemst/fsc/fsg) =="
for p in persist modemst1 modemst2 fsc fsg; do
  printf 'leyendo %-9s ' "$p"
  timeout 180 edl r "$p" "$OUT/$p.img" --loader="$LOADER" --memory=ufs --lun=0 >/dev/null 2>&1 \
    && echo "OK $(stat -c%s "$OUT/$p.img" 2>/dev/null) bytes" || echo "FALLO"
done

echo "== 4. Lectura de boot_a (para ver si esta corrupto) =="
timeout 240 edl r boot_a "$OUT/boot_a.img" --loader="$LOADER" --memory=ufs --lun=0 2>&1 | tail -3
if [ -f "$OUT/boot_a.img" ]; then
  ls -l "$OUT/boot_a.img"
  if [ "$(xxd -l 16 -p "$OUT/boot_a.img")" = "00000000000000000000000000000000" ]; then
    echo "boot_a: TODO CEROS -> particion vacia/borrada"
  else
    echo "boot_a magic: $(head -c 8 "$OUT/boot_a.img")  (esperado: ANDROID!)"
  fi
fi

echo "== 5. Lectura de misc (por si guarda un comando de arranque) =="
timeout 120 edl r misc "$OUT/misc.img" --loader="$LOADER" --memory=ufs --lun=0 2>&1 | tail -2
[ -f "$OUT/misc.img" ] && xxd -l 64 "$OUT/misc.img"

echo "== FIN sonda: NADA escrito en el telefono =="
