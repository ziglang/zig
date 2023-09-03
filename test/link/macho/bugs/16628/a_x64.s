.globl _foo
_foo: 
  .cfi_startproc
  push    %rbp
  .cfi_def_cfa_offset 8
  .cfi_offset %rbp, -8
  mov     %rsp, %rbp
  .cfi_def_cfa_register %rbp
  call    _bar
  pop     %rbp
  .cfi_restore %rbp
  .cfi_def_cfa_offset 0
  ret
  .cfi_endproc

.globl _bar
_bar:
  .cfi_startproc
  push     %rbp
  .cfi_def_cfa_offset 8
  .cfi_offset %rbp, -8
  mov     %rsp, %rbp
  .cfi_def_cfa_register %rbp
  mov     $4, %rax
  pop     %rbp
  .cfi_restore %rbp
  .cfi_def_cfa_offset 0
  ret
  .cfi_endproc
