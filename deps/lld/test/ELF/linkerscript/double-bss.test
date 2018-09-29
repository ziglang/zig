# REQUIRES: x86
# RUN: echo '.short 0; .bss; .zero 4; .comm q,128,8' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t
# RUN: ld.lld -o %t1 --script %s %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK:      .bss1          00000004 0000000000000122 BSS
# CHECK-NEXT: .bss2          00000080 0000000000000128 BSS

SECTIONS {
  . = SIZEOF_HEADERS;
  .text : { *(.text*) }
  .bss1 : { *(.bss) }
  .bss2 : { *(COMMON) }
}
