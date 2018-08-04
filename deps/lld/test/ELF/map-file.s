// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file2.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file3.s -o %t3.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file4.s -o %t4.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file5.s -o %t5.o
// RUN: ld.lld -shared %t5.o -o %t5.so -soname dso
// RUN: rm -f %t4.a
// RUN: llvm-ar rc %t4.a %t4.o
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a %t5.so -o %t -M | FileCheck -strict-whitespace %s
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a %t5.so -o %t -print-map | FileCheck -strict-whitespace %s
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a %t5.so -o %t -Map=%t.map
// RUN: FileCheck -strict-whitespace %s < %t.map

.global _start
_start:
.cfi_startproc
.cfi_endproc
 .quad sharedFoo
 .quad sharedBar
 .byte 0xe8
 .long sharedFunc1 - .
 .byte 0xe8
 .long sharedFunc2 - .
 .byte 0xe8
 .long baz - .
.global _Z1fi
_Z1fi:
.cfi_startproc
nop
.cfi_endproc
.weak bar
bar:
.long bar - .
.long zed - .
local:
.comm   common,4,16
.global abs
abs = 0xAB5
labs = 0x1AB5

// CHECK:         VMA              LMA     Size Align Out     In      Symbol
// CHECK-NEXT: 2001c8           2001c8       78     8 .dynsym
// CHECK-NEXT: 2001c8           2001c8       78     8         <internal>:(.dynsym)
// CHECK-NEXT: 200240           200240       2c     8 .gnu.hash
// CHECK-NEXT: 200240           200240       2c     8         <internal>:(.gnu.hash)
// CHECK-NEXT: 20026c           20026c       30     4 .hash
// CHECK-NEXT: 20026c           20026c       30     4         <internal>:(.hash)
// CHECK-NEXT: 20029c           20029c       31     1 .dynstr
// CHECK-NEXT: 20029c           20029c       31     1         <internal>:(.dynstr)
// CHECK-NEXT: 2002d0           2002d0       30     8 .rela.dyn
// CHECK-NEXT: 2002d0           2002d0       30     8         <internal>:(.rela.dyn)
// CHECK-NEXT: 200300           200300       30     8 .rela.plt
// CHECK-NEXT: 200300           200300       30     8         <internal>:(.rela.plt)
// CHECK-NEXT: 200330           200330       64     8 .eh_frame
// CHECK-NEXT: 200330           200330       2c     1         {{.*}}{{/|\\}}map-file.s.tmp1.o:(.eh_frame+0x0)
// CHECK-NEXT: 200360           200360       14     1         {{.*}}{{/|\\}}map-file.s.tmp1.o:(.eh_frame+0x2c)
// CHECK-NEXT: 200378           200378       18     1         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.eh_frame+0x18)
// CHECK-NEXT: 201000           201000       2d     4 .text
// CHECK-NEXT: 201000           201000       28     4         {{.*}}{{/|\\}}map-file.s.tmp1.o:(.text)
// CHECK-NEXT: 201000           201000        0     1                 _start
// CHECK-NEXT: 20101f           20101f        0     1                 f(int)
// CHECK-NEXT: 201028           201028        0     1                 local
// CHECK-NEXT: 201028           201028        2     4         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text)
// CHECK-NEXT: 201028           201028        0     1                 foo
// CHECK-NEXT: 201029           201029        0     1                 bar
// CHECK-NEXT: 20102a           20102a        0     1         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text.zed)
// CHECK-NEXT: 20102a           20102a        0     1                 zed
// CHECK-NEXT: 20102c           20102c        0     4         {{.*}}{{/|\\}}map-file.s.tmp3.o:(.text)
// CHECK-NEXT: 20102c           20102c        0     1                 bah
// CHECK-NEXT: 20102c           20102c        1     4         {{.*}}{{/|\\}}map-file.s.tmp4.a(map-file.s.tmp4.o):(.text)
// CHECK-NEXT: 20102c           20102c        0     1                 baz
// CHECK-NEXT: 201030           201030       30    16 .plt
// CHECK-NEXT: 201030           201030       30    16         <internal>:(.plt)
// CHECK-NEXT: 201040           201040        0     1                 sharedFunc1
// CHECK-NEXT: 201050           201050        0     1                 sharedFunc2
// CHECK-NEXT: 202000           202000       28     8 .got.plt
// CHECK-NEXT: 202000           202000       28     8         <internal>:(.got.plt)
// CHECK-NEXT: 203000           203000      100     8 .dynamic
// CHECK-NEXT: 203000           203000      100     8         <internal>:(.dynamic)
// CHECK-NEXT: 204000           204000       10    16 .bss
// CHECK-NEXT: 204000           204000        4    16         {{.*}}{{/|\\}}map-file.s.tmp1.o:(COMMON)
// CHECK-NEXT: 204000           204000        4     1                 common
// CHECK-NEXT: 204004           204004        4     1         <internal>:(.bss)
// CHECK-NEXT: 204004           204004        4     1                 sharedFoo
// CHECK-NEXT: 204008           204008        8     1         <internal>:(.bss)
// CHECK-NEXT: 204008           204008        8     1                 sharedBar
// CHECK-NEXT:      0                0        8     1 .comment
// CHECK-NEXT:      0                0        8     1         <internal>:(.comment)
// CHECK-NEXT:      0                0      198     8 .symtab
// CHECK-NEXT:      0                0      198     8         <internal>:(.symtab)
// CHECK-NEXT:      0                0       84     1 .shstrtab
// CHECK-NEXT:      0                0       84     1         <internal>:(.shstrtab)
// CHECK-NEXT:      0                0       6d     1 .strtab
// CHECK-NEXT:      0                0       6d     1         <internal>:(.strtab)


// RUN: not ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -Map=/ 2>&1 \
// RUN:  | FileCheck -check-prefix=FAIL %s
// FAIL: cannot open map file /
