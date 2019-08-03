# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-sort-small-cm-relocs-input2.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-sort-small-cm-relocs-input3.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-sort-small-cm-relocs-input4.s -o %t4.o

# RUN: ld.lld %t1.o %t2.o %t3.o %t4.o -o %t -Map=%t.map
# RUN: FileCheck %s < %t.map

# Test an alternate link order.
# RUN: ld.lld %t2.o %t3.o %t4.o %t1.o -o %t -Map=%t.map
# RUN: FileCheck %s -check-prefix=ALTERNATE < %t.map

# If a linker script has a sections command then allow that to override the
# default sorting behavior.
# RUN: echo "SECTIONS {          \
# RUN:         .toc : {          \
# RUN:            *ppc64-sort-small-cm-relocs.s.tmp4.o(.toc*) \
# RUN:            *ppc64-sort-small-cm-relocs.s.tmp1.o(.toc*)  \
# RUN:            *(.toc*)       \
# RUN:          }                \
# RUN:       } " > %t.script
# RUN: ld.lld %t1.o %t2.o %t3.o %t4.o -o %t -script %t.script -Map=%t.map
# RUN: FileCheck %s -check-prefix=SEC-CMD < %t.map

# RUN: echo "SECTIONS { .text : {*(.text*)} } " > %t.script
# RUN: ld.lld %t1.o %t2.o %t3.o %t4.o -o %t -script %t.script -Map=%t.map
# RUN: FileCheck %s -check-prefix=SEC-CMD2 < %t.map

# Default sort if the linker script does not have a sections command.
# RUN: echo "" > %t.script
# RUN: ld.lld %t1.o %t2.o %t3.o %t4.o -o %t -script %t.script -Map=%t.map
# RUN: FileCheck %s -check-prefix=NOSEC < %t.map
    .text

    .global _start
    .type _start,@function
_start:
    li 3, 55
    blr

    .type a,@object
    .data
    .global a
a:
    .long 10
    .size a, 4

    .type c,@object
    .data
    .global c
c:
    .long  55
    .size  c, 4

    .type   d,@object
    .global d
d:
    .long 33
    .size d, 4

    # .toc section contains only some constants.
    .section        .toc,"aw",@progbits
    .quad 0xa1a1a1a1a1a1a1a1
    .quad 0xb2b2b2b2b2b2b2b2

# Input files tmp3.o and tmp4.o contain small code model relocs.

# CHECK:      .got
# CHECK-NEXT:         <internal>:(.got)
# CHECK-NEXT: .toc
# CHECK-NEXT:         {{.*}}3.o:(.toc)
# CHECK-NEXT:         {{.*}}4.o:(.toc)
# CHECK-NEXT:         {{.*}}1.o:(.toc)
# CHECK-NEXT:         {{.*}}2.o:(.toc)

# ALTERNATE:      .got
# ALTERNATE-NEXT:         <internal>:(.got)
# ALTERNATE-NEXT: .toc
# ALTERNATE-NEXT:         {{.*}}3.o:(.toc)
# ALTERNATE-NEXT:         {{.*}}4.o:(.toc)
# ALTERNATE-NEXT:         {{.*}}2.o:(.toc)
# ALTERNATE-NEXT:         {{.*}}1.o:(.toc)

# SEC-CMD:      .got
# SEC-CMD-NEXT:         <internal>:(.got)
# SEC-CMD-NEXT: .toc
# SEC-CMD-NEXT:         {{.*}}4.o:(.toc)
# SEC-CMD-NEXT:         {{.*}}1.o:(.toc)
# SEC-CMD-NEXT:         {{.*}}2.o:(.toc)
# SEC-CMD-NEXT:         {{.*}}3.o:(.toc)

# SEC-CMD2:      .got
# SEC-CMD2-NEXT:         <internal>:(.got)
# SEC-CMD2-NEXT: .toc
# SEC-CMD2-NEXT:         {{.*}}1.o:(.toc)
# SEC-CMD2-NEXT:         {{.*}}2.o:(.toc)
# SEC-CMD2-NEXT:         {{.*}}3.o:(.toc)
# SEC-CMD2-NEXT:         {{.*}}4.o:(.toc)

# NOSEC:      .got
# NOSEC-NEXT:         <internal>:(.got)
# NOSEC-NEXT: .toc
# NOSEC-NEXT:         {{.*}}3.o:(.toc)
# NOSEC-NEXT:         {{.*}}4.o:(.toc)
# NOSEC-NEXT:         {{.*}}1.o:(.toc)
# NOSEC-NEXT:         {{.*}}2.o:(.toc)

