.globl _foo
.align 4
_foo: 
  .cfi_startproc
  stp     x29, x30, [sp, #-32]!
  .cfi_def_cfa_offset 32
  .cfi_offset w30, -24
  .cfi_offset w29, -32
  mov x29, sp
  .cfi_def_cfa w29, 32
  bl      _bar
  ldp     x29, x30, [sp], #32
  .cfi_restore w29
  .cfi_restore w30
  .cfi_def_cfa_offset 0
  ret
  .cfi_endproc

.globl _bar
.align 4
_bar:
  .cfi_startproc
  sub     sp, sp, #32
  .cfi_def_cfa_offset -32
  stp     x29, x30, [sp, #16]
  .cfi_offset w30, -24
  .cfi_offset w29, -32
  mov x29, sp
  .cfi_def_cfa w29, 32
  mov     w0, #4
  ldp     x29, x30, [sp, #16]
  .cfi_restore w29
  .cfi_restore w30
  add     sp, sp, #32
  .cfi_def_cfa_offset 0
  ret
  .cfi_endproc
