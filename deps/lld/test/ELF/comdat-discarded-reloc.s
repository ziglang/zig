# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/comdat-discarded-reloc.s -o %t2.o
# RUN: ld.lld -gc-sections --noinhibit-exec %t2.o %t.o -o /dev/null
# RUN: ld.lld -r %t2.o %t.o -o %t 2>&1 | FileCheck --check-prefix=WARN %s
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s

## ELF spec doesn't allow a relocation to point to a deduplicated
## COMDAT section. Unfortunately this happens in practice (e.g. .eh_frame)
## Test case checks we do not crash.

# WARN: warning: relocation refers to a discarded section: .text.bar1
# WARN-NEXT: >>> referenced by {{.*}}.o:(.rela.text.bar2+0x0)
# WARN-NOT: warning

# RELOC:      .rela.eh_frame {
# RELOC-NEXT:   R_X86_64_NONE
# RELOC-NEXT: }
# RELOC-NEXT: .rela.debug_foo {
# RELOC-NEXT:   R_X86_64_NONE
# RELOC-NEXT: }
# RELOC-NEXT: .rela.gcc_except_table {
# RELOC-NEXT:   R_X86_64_NONE
# RELOC-NEXT: }

.section .text.bar1,"aG",@progbits,group,comdat

## .text.bar1 in this file is discarded. Warn on the relocation.
.section .text.bar2,"ax"
.globl bar
bar:
  .quad .text.bar1

## Don't warn on .eh_frame, .debug*, .zdebug*, or .gcc_except_table
.section .eh_frame,"a"
  .quad .text.bar1

.section .debug_foo
  .quad .text.bar1

.section .gcc_except_table,"a"
  .quad .text.bar1
