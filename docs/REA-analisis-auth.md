# Ingeniería inversa del EDL auth de Xiaomi (renoir / SM7350 "cedros")

Objetivo: saltar `Error on EDL Authentification` del firehose para poder flashear
el equipo bloqueado. Herramientas: REA (rea-agents 6.7.0) + Ghidra 12.1.2, y
`edlclient` contra el dispositivo real.

## 1. Mapa del auth (REA / Ghidra)

Binario: `prog_firehose_ddr.elf` (oficial, extraído de la ROM)
SHA-256 `e2489f0bd398beb55c592883f441c956aa0564913b184626ab3d7321c74a317c`
ELF64 ARM aarch64, base de carga `0x1481d000`, 2545 funciones, 1354 strings.

Función del handler de auth: **`0x14825280`**. Pseudocódigo real (Ghidra):

```c
iVar2 = FUN_1482fc68(lVar6, lVar8, &DAT_148cc71e, uVar5, &DAT_148a0738);  // verifica firma
if (iVar2 != 0) {                                  // 0x148252ec: cbz w0, 0x14825340
    FUN_14826794(2,"Signature Verification Failed%c",0x2e);
    DAT_148cc71d = 0;                              // flag autenticado = 0
    goto LAB_148250b8;
}
DAT_148cc71d = 1;                                  // flag autenticado = 1
FUN_14826794(4,"EDL Authenticated%c",0x2e);
```

- Flag de autenticación: **`DAT_148cc71d`** (byte), en assembly `[x24,#0x71d]`.
- Clave/estructura de verificación: **`0x148a0738`**.
- Buffer de la firma recibida: **`0x148cc71e`**, tamaño `size_in_bytes` del XML (256).
- Gate previo: `"Only nop and sig tag can be recevied before authentication"` →
  antes de autenticar solo se aceptan los tags `nop` y `sig`.
- El nonce lo genera el dispositivo: `"Sig tag random number generation failed"`
  → la firma es de Xiaomi sobre un reto aleatorio, no reutilizable.

## 2. Parche construido

`patch/prog_firehose_ddr_noauth.elf` — 3 bytes, en `0x148252ec` (offset `0xb2ec`):

| | bytes | instrucción |
|---|---|---|
| original | `a0 02 00 34` | `cbz w0, 0x14825340` |
| parcheado | `15 00 00 14` | `b 0x14825340` |

Efecto: el bloque de fallo queda inalcanzable → `DAT_148cc71d = 1` siempre.
Tamaño idéntico (936512 B). MD5 `9b5b78441462ac2f5fd8ed4e2c627c6f`.

## 3. Verificación empírica contra el dispositivo (lo que decide)

| Prueba | Resultado |
|---|---|
| Loader **oficial** | carga, Sahara v2 64-bit OK, luego `Error on EDL Authentification` |
| Loader **parcheado** (3 bytes en código) | **desconecta y re-enumera** (Device 15 → 16), sin respuesta |
| **Control**: 1 byte cambiado en un string (`V`→`v`, offset `0x76bb4`) | **desconecta y re-enumera** (Device 16 → 17) |

Conclusión: el PBL verifica el hash firmado de la **imagen completa del loader**.
Cualquier modificación — incluso cosmética, fuera del flujo de ejecución — es
rechazada antes de ejecutar. Parchear el loader **no es viable**, y firmar uno
propio exige la clave privada de Xiaomi/Qualcomm (RSA-2048).

## 4. Lo que sí queda como salida

La firma se verifica **dentro** del loader, pero el loader debe ser legítimo.
Por tanto solo sirve un loader **ya firmado** que no exija auth, es decir un
programmer de fábrica/ingeniería para `HWID 001590e1XXXXXXXX` (cedros).
No existe público (verificado en borkeler/Loaders: solo la variante `EDLAuth`,
y el issue #133 de otro renoir brickeado sigue sin respuesta).

Alternativas reales: cuenta Xiaomi autorizada (MiFlash), o servicio que
proporcione loader no-auth firmado para este HWID. Con cualquiera de las dos,
el flasheo se hace aquí en Linux con `fw_full/images` y `edl_flash.sh`.

## 5. Segundo camino evaluado: falsificar la firma (en vez de parchear)

Función de verificación: `0x1482fc68` (decompilada). Es **PKCS#1 v1.5 correcta**:

```c
if ((local_148[0] == 0) && (local_148[1] == 0x01)) {     // 00 01
    ... recorre 0xFF ... y exige el 0x00 separador ...
    ... compara el resto con el hash esperado ...
    uVar6 = uVar10 != 0x100;                             // fallo -> código != 0
```

- Módulo: 256 bytes = **RSA-2048** (bloque completo de 0x100).
- Hash esperado: **64 bytes** (SHA-512); el primer dword de la estructura en
  `0x148a0738` es `0x40` = 64.
- El padding se valida completo: no hay atajo tipo "ignora el padding" ni
  comparación parcial.
- El nonce lo genera el dispositivo en cada sesión → no hay replay posible.

Conclusión: falsificar la firma exige la clave privada de Xiaomi (RSA-2048).
Ambas vías están cerradas criptográficamente, no por falta de análisis.

## 6. Veredicto

| Vía | Estado |
|---|---|
| Parchear el loader (auth bypass) | imposible: el PBL verifica la imagen firmada (probado con 1 byte cosmético) |
| Firmar un loader propio | imposible: RSA-2048, clave privada de Xiaomi/Qualcomm |
| Falsificar la firma del nonce | imposible: PKCS#1 v1.5 correcta, RSA-2048, nonce aleatorio |
| Loader no-auth firmado para cedros | no existe público (borkeler/Loaders issue #133 abierto) |
| Cuenta Xiaomi autorizada (MiFlash) | **única vía viable**, con la ROM ya verificada de esta carpeta |

## 7. Tercera vía: el truco del "challenge vacío" (sig.bin) — tampoco

Referencia: `HsOjo/edl-noauth-kit` documenta que el challenge solo se genera al
recibir `<sig TargetName="req">`; en 9008 recién iniciado el bucle de comparación
se salta y bastaría un blob que descifre a padding puro. `edlclient` ya trae dos
blobs así en `Library/Modules/xiaomi.py` (`xiaomi_authdata`).

Probado en el equipo (sesión 9008 limpia, loader oficial cargado, firehose
arriba: UFS SKhynix, 15 funciones):

```
Xiaomi EDL Auth detected.
  blob 1 -> ERROR: Signature Verification Failed.
  blob 2 -> ERROR: Signature Verification Failed.
```

Clave recuperada del propio programmer (estructura deducida de `FUN_1482fc68`):

```
@ 0x148a0738:
  +0x000  u32  palabras = 64
  +0x108  64 x u32  módulo (palabra big-endian dentro del u32) -> 2048 bits
  +0x208  u32  exponente = 0x10001
```

Comprobación: `pow(int(blob1), 0x10001, n)` = `2ed71e91d0951c3d…` → **sin**
prefijo `00 01 FF..` ⇒ la clave es distinta a la de los blobs filtrados.
Con e = 65537 no hay atajo de exponente pequeño ni de Bleichenbacher.

## 8. Cierre

Ninguna vía offline funciona en cedros: imagen del loader firmada (PBL),
auth RSA-2048/e=65537 con clave propia, blobs públicos inservibles y sin loader
no-auth firmado para `HWID 001590e1`. Publicado en
`github.com/bkerler/Loaders/issues/133` (2 comentarios con todos los datos).

## 9. Camino 4: desbordamiento del buffer de firma (pre-auth)

`size_in_bytes` del tag `<sig>` llega sin validación aparente al buffer fijo de
0x148cc71e (flag de auth en 0x148cc71d). Sonda con escalera de tamaños:

```
size=256   payload -> ERROR: Signature Verification Failed
size=272   payload -> ERROR: Signature Verification Failed
size=320   payload -> ERROR: Signature Verification Failed
size=512   payload -> ACK     (sin mensaje de error, estado raro)
size=1024  -> el loader rechaza el tamaño
```

El equipo **no crashea** y la auth sigue fallando después. Hay un
comportamiento anómalo en 512 (ACK en vez de error) pero no concede acceso.
Convertirlo en bypass exigiría desarrollo de exploit a ciegas (sin debugger,
sin mapa de BSS fiable) — no es viable en una sesión de reparación.

## 10. Caminos que quedan (ninguno es software puro)

| Vía | Viabilidad |
|---|---|
| **ISP/UF S programmer** (EasyJTAG Plus, UFI Box, Medusa): escribir `boot_a/b`, `super`… directo al chip, sin pasar por el SoC | **La más realista**. No necesita auth ni loader. Taller con caja; ~30-80 USD |
| **Loader no-auth reubicado** (`patch/lahaina_reloc_1481d000.elf`, base movida de 0x14815000 a 0x1481d000) | Prueba de 1 ciclo de pines. Si el PBL no firma las cabeceras ELF, carga; luego el driver UFS de SM8250 tendría que entenderse con el UFS SKhynix. Largo tiro |
| **Glitching** (fallo de tensión/reloj sobre el PBL para saltar la firma) | Técnica real de laboratorio; hardware tipo Pico Glitcher. Días de trabajo y suerte |
| **Cambio de placa base** de segunda mano | Pragmático: los datos ya son inaccesibles, así que sustituir la placa "arregla" el teléfono |
| **Servicio con cuenta autorizada** (p.ej. hyperunlock, que responde ese mismo hilo de xiaomi.eu) | Fiable, coste bajo; nosotros ya tenemos la ROM verificada |

## 11. Verificación del verificador, a nivel de instrucciones (2026-10-28)

Desensamblado con `llvm-objdump -d --triple=aarch64` sobre `prog_firehose_ddr.elf`
(base `0x1481d000`). Función `0x1482fc68` = verificador RSA de la firma del nonce.

Comprobaciones literales encontradas:

| Chequeo | Offsets | Instrucción clave |
|---|---|---|
| firma nula → error | `0x1482fc94` | `cbz x8` |
| largo de firma **exactamente** 256 | `0x1482fc98` | `cmp x1, #0x100; b.ne` |
| hash no nulo, largo 1..245 | `0x1482fca8`/`0x1482fcb4` | `cbz x2` / `cmp x9,#0xf4; b.hi` |
| copia de la firma a pila | `0x1482fccc` | bucle 256 bytes |
| prefijo `00 01` | `0x1482fe8c`/`0x1482fe98` | `cbnz` + `cmp #0x1` |
| relleno `FF…FF` completo | `0x1482fec0` | `ldrb; cmp #0xff; b.ne error` |
| separador `00` | `0x1482fee0` | `ldrb [x9,x8]; cbz` |
| comparación de hash **completa** | `0x1482ff2c` | bucle hasta `x10 == 0x100` |

Conclusión medida: PKCS#1 v1.5 **estricto** (sin parser laxo: no hay BERserk),
largo forzado a 256 B (sin ataque de firma corta), hash comparado entero (64 B,
SHA-512) y exponente `0x10001` (sin ataque de cubo). Cualquier falsificación
requiere la clave privada; los caminos restantes son físicos (glitch,
side-channel) o de cadena de suministro (loader de ingeniería firmado), no
criptográficos.
