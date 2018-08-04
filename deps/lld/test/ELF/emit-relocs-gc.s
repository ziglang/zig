# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

## Show that we emit .rela.bar and .rela.text when GC is disabled.
# RUN: ld.lld --emit-relocs %t.o -o %t
# RUN: llvm-objdump %t -section-headers | FileCheck %s --check-prefix=NOGC
# NOGC: .rela.text
# NOGC: .rela.bar

## GC collects .bar section and we exclude .rela.bar from output. We keep
## .rela.text because we keep .text.
# RUN: ld.lld --gc-sections --emit-relocs --print-gc-sections %t.o -o %t \
# RUN:   | FileCheck --check-prefix=MSG %s
# MSG: removing unused section {{.*}}.o:(.bar)
# MSG: removing unused section {{.*}}.o:(.rela.bar)
# RUN: llvm-objdump %t -section-headers | FileCheck %s --check-prefix=GC
# GC-NOT:  rela.bar
# GC:      rela.text
# GC-NOT:  rela.bar

.section .bar,"a"
.quad .bar

.text
relocs:
.quad _start

.global _start
_start:
 nop
