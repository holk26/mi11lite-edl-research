# Briefing técnico — Xiaomi Mi 11 Lite 5G (renoir), serial <DEVICE_SERIAL>

**Estado:** solo EDL 9008 (test points). Bootloader **bloqueado de fábrica**
(`unlocked: no`, `critical unlocked: false`). Slot A marcado `slot-unbootable: yes`
y `fastboot continue` → `Failed to load image from partition: Load Error`.
No existe partición `recovery` (esquema A/B). EDL pide auth de Xiaomi
(`Error on EDL Authentification`), probado a fondo: ver `REA-analisis-auth.md`.

**ROM correcta (verificada):** `renoir_global_images_V14.0.7.0.TKIMIXM_…tgz`
(MD5 `e21e2a7d857b7cbf294da846089ce577`), extraída en `fw_full/images/`.

---

## Opción A — Flasheo EDL con cuenta Xiaomi autorizada (lo más rápido)

Abrir **MiFlash** (con cuenta autorizada), seleccionar la carpeta descomprimida
de la ROM y flashear. No hace falta nada más; MiFlash usa `rawprogram0-5.xml`.

---

## Opción B — Programador UFS por ISP (EasyJTAG Plus / UFI Box / Medusa)

Escribir las particiones **directo al chip UFS**, sin pasar por el SoC: no hay
auth que saltar. Sector = 4096 B. Direcciones exactas (de `rawprogram*.xml`):

| Partición | LUN | start_sector | sectores | archivo |
|---|---|---|---|---|
| PrimaryGPT | 0 | 0 | 6 | `gpt_main0.bin` |
| misc | 0 | 33536 | 1024 | `misc.img` |
| cust | 0 | 147456 | 262144 | `cust.img` |
| **super** | 0 | 409600 | 2228224 | `super.img` (5.9 GB sparse) |
| vbmeta_system_a | 0 | 2637824 | 32 | `vbmeta_system.img` |
| metadata | 0 | 2646016 | 4096 | `metadata.img` |
| xbl_a | 1 | 6 | 2048 | `xbl.elf` |
| xbl_config_a | 1 | 2054 | 128 | `xbl_config.elf` |
| aop_a | 4 | 6 | 128 | `aop.mbn` |
| tz_a | 4 | 134 | 1024 | `tz.mbn` |
| hyp_a | 4 | 1158 | 2048 | `hypvm.mbn` |
| modem_a | 4 | 3206 | 114688 | `NON-HLOS.bin` |
| bluetooth_a | 4 | 117894 | 512 | `BTFM.bin` |
| abl_a | 4 | 127622 | 512 | `abl.elf` |
| dsp_a | 4 | 128134 | 16384 | `dspso.bin` |
| keymaster_a | 4 | 144518 | 256 | `km41.mbn` |
| **boot_a** | 4 | 144774 | 49152 | `boot.img` |
| devcfg_a | 4 | 193926 | 64 | `devcfg.mbn` |
| qupfw_a | 4 | 193990 | 32 | `qupv3fw.elf` |
| vbmeta_a | 4 | 194022 | 32 | `vbmeta.img` |
| dtbo_a | 4 | 194054 | 6144 | `dtbo.img` |
| uefisecapp_a | 4 | 200198 | 512 | `uefi_sec.mbn` |
| shrm_a | 4 | 201222 | 32 | `shrm.elf` |
| multiimgoem_a | 4 | 201254 | 8 | `multi_image.mbn` |
| cpucp_a | 4 | 201262 | 256 | `cpucp.elf` |
| featenabler_a | 4 | 201518 | 32 | `featenabler.mbn` |
| **vendor_boot_a** | 4 | 201550 | 24576 | `vendor_boot.img` |
| logo | 4 | 460374 | 16384 | `logo.img` |
| GPT backup | 0/1/2/3/4/5 | `NUM_DISK_SECTORS-5` | 5 | `gpt_backupN.bin` |

Tabla completa con MD5 en `TABLA-particiones.md`.

### NO tocar (IMEI / calibración)
`persist`, `modemst1`, `modemst2`, `fsc`, `fsg` — **ninguno aparece en los
`rawprogram`, así que el flasheo estándar ya los respeta**. Si el ISP los
reescribe, se pierde el IMEI y la calibración de RF.

### Notas para el técnico
- MD5 de `super.img`: `5c89729e7d47315059cc78125dd23b40`.
- La ROM escribe solo el **slot A** (es lo normal y es lo que hace MiFlash).
- Tras escribir, primer arranque: 3-5 minutos.
- Si tras el flasheo sigue sin arrancar, el problema es **hardware (UFS)**, no
  software: `version-bootloader` y `version-baseband` salían vacíos en fastboot
  y `battery-voltage: 0`, lo que apunta a lectura de storage defectuosa.

---

## Alternativa sin taller
Placa base de renoir de segunda mano: los datos ya son inaccesibles, así que
sustituir la placa resuelve el teléfono igual que un flasheo.
