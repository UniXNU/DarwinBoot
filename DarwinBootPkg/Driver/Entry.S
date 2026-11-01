// SPDX-License-Identifier: BSD-2-Clause-Patent
#include <AsmMacroLib.h>

ASM_FUNC(DarwinCurrentEl)
  mrs x0, CurrentEL
  ret

// x0=boot_args PA, x1=entry PA, x2=owned PA, x3=owned size, x4=frame buffer
// PA (0 for none), x5=its size in bytes. EL1 only.
ASM_FUNC(DarwinEnter)
  msr daifset, #15
  // Paint the top 1/16 of the framebuffer green (BGRA 0xFF00FF00)
  // before cache maintenance, MMU shutdown and the branch to the kernel.
  cbz x4, 2f
  lsr x9, x5, #4
  bic x9, x9, #7
  mov w10, #0xFF00
  movk w10, #0xFF00, lsl #16
  mov x11, x4
3:
  stp w10, w10, [x11], #8
  subs x9, x9, #8
  b.hi 3b
  dsb sy
2:
  add x5, x2, x3
  mrs x6, ctr_el0
  ubfx x6, x6, #16, #4
  mov x7, #4
  lsl x6, x7, x6
  sub x7, x6, #1
  bic x4, x2, x7
  dsb sy
1:
  dc civac, x4
  add x4, x4, x6
  cmp x4, x5
  b.lo 1b
  dsb sy
  ic iallu
  dsb sy
  isb
  mrs x4, sctlr_el1
  bic x4, x4, #1
  bic x4, x4, #4
  bic x4, x4, #0x1000
  msr sctlr_el1, x4
  isb
  tlbi vmalle1
  dsb sy
  isb
  adr x2, DarwinVectors
  msr vbar_el1, x2
  isb
  br x1

// ---------------------------------------------------------------------------
// Exception capture. XNU installs its own vectors early, but anything that goes
// wrong before that used to land in the firmware's table, which ExitBootServices
// has torn down: the machine just stops. These vectors stay installed from the
// branch until XNU takes over, and paint what happened onto the framebuffer:
// the top band turns red, then ESR, ELR and FAR are drawn as 64-bit bar codes
// (white = 1, black = 0, one 16x60 block per bit, in that order top to bottom).
//
// The panel geometry is fixed for this unit: 1116x2480, 4464 bytes per row,
// BGRA8888.
//
E_STREAM    = 4464
E_BAND_ROWS = 120

.macro FAULT_ENTRY
  b DarwinFault
  .align 7
.endm

.align 12
.data
.align 3
.globl mDarwinFbBase
mDarwinFbBase:
  .quad 0

.text
ASM_FUNC(DarwinVectors)
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY
  FAULT_ENTRY

// x0 = framebuffer base, x1 = value, x2 = first row
DarwinBits:
  mov x3, #0
1:
  lsr x4, x1, x3
  and x4, x4, #1
  mov w5, #0xFF000000
  mov w6, #0x00FFFFFF
  madd w5, w4, w6, w5            // white when the bit is set, black otherwise
  lsl x7, x3, #4             // x = bit * 16 pixels
  mov x10, #0
2:
  add x11, x2, x10
  mov x12, #E_STREAM
  madd x12, x11, x12, x0
  add x12, x12, x7, lsl #2
  stp w5, w5, [x12]
  stp w5, w5, [x12, #8]
  stp w5, w5, [x12, #16]
  stp w5, w5, [x12, #24]
  add x10, x10, #1
  cmp x10, #60
  b.lo 2b
  add x3, x3, #1
  cmp x3, #64
  b.lo 1b
  ret

DarwinFault:
  mrs x19, esr_el1
  mrs x20, elr_el1
  mrs x21, far_el1
  adrp x22, mDarwinFbBase
  ldr  x22, [x22, #:lo12:mDarwinFbBase]
  cbz  x22, 9f
  mov w12, #0xFFFF0000           // red
  mov x13, x22
  mov x15, #E_BAND_ROWS
4:
  mov x16, #(E_STREAM / 8)
5:
  stp w12, w12, [x13], #8
  subs x16, x16, #1
  b.ne 5b
  subs x15, x15, #1
  b.ne 4b
  mov x0, x22
  mov x1, x19
  mov x2, #140
  bl DarwinBits                  // ESR
  mov x0, x22
  mov x1, x20
  mov x2, #220
  bl DarwinBits                  // ELR - the faulting PC
  mov x0, x22
  mov x1, x21
  mov x2, #300
  bl DarwinBits                  // FAR - the faulting address
9:
  wfi
  b 9b
