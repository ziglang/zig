# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { *(.text.1) } }" > %t.script

## Check we do not report orphans by default even with -verbose.
# RUN: ld.lld -shared -o %t.out --script %t.script %t.o 2>&1 -verbose \
# RUN:   | FileCheck %s --check-prefix=DEFAULT
# DEFAULT-NOT: placed

## Check --orphan-handling=place has the same behavior as default.
# RUN: ld.lld -shared --orphan-handling=place -o %t.out --script %t.script \
# RUN:   %t.o 2>&1 -verbose  -error-limit=0 | FileCheck %s --check-prefix=DEFAULT

## Check --orphan-handling=error reports errors about orphans.
# RUN: not ld.lld -shared --orphan-handling=error -o %t.out --script %t.script \
# RUN:   %t.o 2>&1 -verbose  -error-limit=0 | FileCheck %s --check-prefix=REPORT
# REPORT:      {{.*}}.o:(.text) is being placed in '.text'
# REPORT-NEXT: {{.*}}.o:(.text.2) is being placed in '.text'
# REPORT-NEXT: <internal>:(.comment) is being placed in '.comment'
# REPORT-NEXT: <internal>:(.bss) is being placed in '.bss'
# REPORT-NEXT: <internal>:(.bss.rel.ro) is being placed in '.bss.rel.ro'
# REPORT-NEXT: <internal>:(.dynsym) is being placed in '.dynsym'
# REPORT-NEXT: <internal>:(.gnu.version) is being placed in '.gnu.version'
# REPORT-NEXT: <internal>:(.gnu.version_r) is being placed in '.gnu.version_r'
# REPORT-NEXT: <internal>:(.gnu.hash) is being placed in '.gnu.hash'
# REPORT-NEXT: <internal>:(.hash) is being placed in '.hash'
# REPORT-NEXT: <internal>:(.dynamic) is being placed in '.dynamic'
# REPORT-NEXT: <internal>:(.dynstr) is being placed in '.dynstr'
# REPORT-NEXT: <internal>:(.rela.dyn) is being placed in '.rela.dyn'
# REPORT-NEXT: <internal>:(.got) is being placed in '.got'
# REPORT-NEXT: <internal>:(.got.plt) is being placed in '.got.plt'
# REPORT-NEXT: <internal>:(.got.plt) is being placed in '.got.plt'
# REPORT-NEXT: <internal>:(.rela.plt) is being placed in '.rela.plt'
# REPORT-NEXT: <internal>:(.rela.plt) is being placed in '.rela.plt'
# REPORT-NEXT: <internal>:(.plt) is being placed in '.plt'
# REPORT-NEXT: <internal>:(.plt) is being placed in '.plt'
# REPORT-NEXT: <internal>:(.eh_frame) is being placed in '.eh_frame'
# REPORT-NEXT: <internal>:(.symtab) is being placed in '.symtab'
# REPORT-NEXT: <internal>:(.symtab_shndxr) is being placed in '.symtab_shndxr'
# REPORT-NEXT: <internal>:(.shstrtab) is being placed in '.shstrtab'
# REPORT-NEXT: <internal>:(.strtab) is being placed in '.strtab'

## Check --orphan-handling=warn reports warnings about orphans.
# RUN: ld.lld -shared --orphan-handling=warn -o %t.out --script %t.script \
# RUN:   %t.o 2>&1 -verbose | FileCheck %s --check-prefix=REPORT

# RUN: not ld.lld --orphan-handling=foo -o %t.out --script %t.script %t.o 2>&1 \
# RUN:   | FileCheck %s --check-prefix=UNKNOWN
# UNKNOWN: unknown --orphan-handling mode: foo

.section .text.1,"a"
 nop

.section .text.2,"a"
 nop
