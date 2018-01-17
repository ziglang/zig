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
 .quad sharedFoo
 .quad sharedBar
 callq sharedFunc1
 callq sharedFunc2
        call baz
.global _Z1fi
_Z1fi:
.cfi_startproc
.cfi_endproc
nop
.weak bar
bar:
.long bar - .
.long zed - .
local:
.comm   common,4,16
.global abs
abs = 0xAB5
labs = 0x1AB5

// CHECK:      Address          Size             Align Out     In      Symbol
// CHECK-NEXT: 00000000002001c8 0000000000000078     8 .dynsym
// CHECK-NEXT: 00000000002001c8 0000000000000078     8         <internal>:(.dynsym)
// CHECK-NEXT: 0000000000200240 000000000000002c     8 .gnu.hash
// CHECK-NEXT: 0000000000200240 000000000000002c     8         <internal>:(.gnu.hash)
// CHECK-NEXT: 000000000020026c 0000000000000030     4 .hash
// CHECK-NEXT: 000000000020026c 0000000000000030     4         <internal>:(.hash)
// CHECK-NEXT: 000000000020029c 0000000000000031     1 .dynstr
// CHECK-NEXT: 000000000020029c 0000000000000031     1         <internal>:(.dynstr)
// CHECK-NEXT: 00000000002002d0 0000000000000030     8 .rela.dyn
// CHECK-NEXT: 00000000002002d0 0000000000000030     8         <internal>:(.rela.dyn)
// CHECK-NEXT: 0000000000200300 0000000000000030     8 .rela.plt
// CHECK-NEXT: 0000000000200300 0000000000000030     8         <internal>:(.rela.plt)
// CHECK-NEXT: 0000000000200330 0000000000000030     8 .eh_frame
// CHECK-NEXT: 0000000000200330 0000000000000030     8         <internal>:(.eh_frame)
// CHECK-NEXT: 0000000000201000 000000000000002d     4 .text
// CHECK-NEXT: 0000000000201000 0000000000000028     4         {{.*}}{{/|\\}}map-file.s.tmp1.o:(.text)
// CHECK-NEXT: 0000000000201000 0000000000000000     0                 _start
// CHECK-NEXT: 000000000020101f 0000000000000000     0                 f(int)
// CHECK-NEXT: 0000000000201028 0000000000000000     0                 local
// CHECK-NEXT: 0000000000201028 0000000000000002     4         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text)
// CHECK-NEXT: 0000000000201028 0000000000000000     0                 foo
// CHECK-NEXT: 0000000000201029 0000000000000000     0                 bar
// CHECK-NEXT: 000000000020102a 0000000000000000     1         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text.zed)
// CHECK-NEXT: 000000000020102a 0000000000000000     0                 zed
// CHECK-NEXT: 000000000020102c 0000000000000000     4         {{.*}}{{/|\\}}map-file.s.tmp3.o:(.text)
// CHECK-NEXT: 000000000020102c 0000000000000000     0                 bah
// CHECK-NEXT: 000000000020102c 0000000000000001     4         {{.*}}{{/|\\}}map-file.s.tmp4.a(map-file.s.tmp4.o):(.text)
// CHECK-NEXT: 000000000020102c 0000000000000000     0                 baz
// CHECK-NEXT: 0000000000201030 0000000000000030    16 .plt
// CHECK-NEXT: 0000000000201030 0000000000000030    16         <internal>:(.plt)
// CHECK-NEXT: 0000000000201040 0000000000000000     0                 sharedFunc1
// CHECK-NEXT: 0000000000201050 0000000000000000     0                 sharedFunc2
// CHECK-NEXT: 0000000000202000 0000000000000028     8 .got.plt
// CHECK-NEXT: 0000000000202000 0000000000000028     8         <internal>:(.got.plt)
// CHECK-NEXT: 0000000000203000 0000000000000100     8 .dynamic
// CHECK-NEXT: 0000000000203000 0000000000000100     8         <internal>:(.dynamic)
// CHECK-NEXT: 0000000000204000 0000000000000010    16 .bss
// CHECK-NEXT: 0000000000204000 0000000000000004    16         {{.*}}{{/|\\}}map-file.s.tmp1.o:(COMMON)
// CHECK-NEXT: 0000000000204000 0000000000000004     0                 common
// CHECK-NEXT: 0000000000204004 0000000000000004     1         <internal>:(.bss)
// CHECK-NEXT: 0000000000204004 0000000000000004     0                 sharedFoo
// CHECK-NEXT: 0000000000204008 0000000000000008     1         <internal>:(.bss)
// CHECK-NEXT: 0000000000204008 0000000000000008     0                 sharedBar
// CHECK-NEXT: 0000000000000000 0000000000000008     1 .comment
// CHECK-NEXT: 0000000000000000 0000000000000008     1         <internal>:(.comment)
// CHECK-NEXT: 0000000000000000 0000000000000198     8 .symtab
// CHECK-NEXT: 0000000000000000 0000000000000198     8         <internal>:(.symtab)
// CHECK-NEXT: 0000000000000000 0000000000000084     1 .shstrtab
// CHECK-NEXT: 0000000000000000 0000000000000084     1         <internal>:(.shstrtab)
// CHECK-NEXT: 0000000000000000 000000000000006d     1 .strtab
// CHECK-NEXT: 0000000000000000 000000000000006d     1         <internal>:(.strtab)

// RUN: not ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -Map=/ 2>&1 \
// RUN:  | FileCheck -check-prefix=FAIL %s
// FAIL: cannot open map file /
