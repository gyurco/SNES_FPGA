# SNES for MiST with the SDRAM at ~86 MHz (SNES_MiST_LC)

*(Versión en español más abajo)*

Revision `SNES_MiST_LC` of `SNES_MiST.qpf`: the same core as `SNES_MiST`, with
a different SDRAM controller. The normal build runs the SDRAM at ~129 MHz
(6 x clk_sys, CAS latency 3, `sdram_cl3.sv`), close to the limit of the
MT48LC16M16A2-75 and beyond what some boards handle. This one runs it at
85.9 MHz (4 x clk_sys, CAS latency 2), which gives much better SDRAM stability:
tested on MiST, on Mistica (a MiST clone with a different SDRAM) and on other
MiST-like FPGA boards.

The memory works as in the Calypso port ([teiram/calypso-ports](https://github.com/teiram/calypso-ports/tree/master/snes))
and in SNESTang (nand2mario): a 3 channel interleaved controller, each channel
in its own bank(s) of the 32MB SDRAM:

| Channel | Bank | Contents |
|---|---|---|
| 0 | 0 | Cartridge ROM (up to 8MB) |
| 0 | 1 | WRAM (128KB), BSRAM (up to 512KB) |
| 1 | 2 | ARAM |
| 2 | 3 | VRAM |

Files: `SNES_LC.sv` (top level), `sdram_lc.sv`, `mist/pll_lc.v`,
`pll_phase.sv`, `sector_buf.sv`, `SNES_MiST_LC.qsf`, `SNES_MiST_LC.sdc`.
`rtl/` and `SNES_MiST` are not changed.

### OSD

* **SDRAM Clock Phase**: moves the SDRAM clock from -1.06 ns to +0.79 ns
  (steps of 264 ps) while the core runs; the SDRAM is initialized again after
  each change. 0 works on all the boards tested so far.

No GSU Turbo option (as in the normal MiST build).

### Build

Quartus 13.1: `quartus_sh --flow compile SNES_MiST -c SNES_MiST_LC`.
Timing is met in all the corners (slow 85C, slow 0C, fast 0C).

---

## SNES para MiST con la SDRAM a ~86 MHz (SNES_MiST_LC)

Revisión `SNES_MiST_LC` de `SNES_MiST.qpf`: el mismo core que `SNES_MiST` con
otro controlador de SDRAM. La versión normal lleva la SDRAM a ~129 MHz (6 x
clk_sys, latencia CAS 3), muy cerca del límite de la memoria; esta la lleva a
85,9 MHz (4 x clk_sys, latencia CAS 2), con mucha más estabilidad: probada en
MiST, en Mistica (clon de MiST con otra SDRAM) y en otras placas FPGA tipo MiST.

La memoria funciona como en el port de Calypso y en SNESTang: tres canales
intercalados, cada uno en su banco (o bancos) de la SDRAM de 32 MB. Admite ROMs
de hasta 8 MB.

En el OSD, **SDRAM Clock Phase** mueve la fase del reloj de la SDRAM entre
-1,06 y +0,79 ns sin parar el core. Con 0 va en todas las placas probadas.

Se compila con Quartus 13.1: `quartus_sh --flow compile SNES_MiST -c SNES_MiST_LC`.

---

Shaeon (Carlos Palmero), 2026. The SDRAM controller and the top level were
adapted with the help of Claude (Anthropic).
