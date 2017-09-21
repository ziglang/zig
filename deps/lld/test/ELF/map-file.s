// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file2.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file3.s -o %t3.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/map-file4.s -o %t4.o
// RUN: rm -f %t4.a
// RUN: llvm-ar rc %t4.a %t4.o
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -M | FileCheck -strict-whitespace %s
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -print-map | FileCheck -strict-whitespace %s
// RUN: ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -Map=%t.map
// RUN: FileCheck -strict-whitespace %s < %t.map

.global _start
_start:
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

// CHECK:      Address          Size             Align Out     In      Symbol
// CHECK-NEXT: 0000000000200158 0000000000000030     8 .eh_frame
// CHECK-NEXT: 0000000000200158 0000000000000030     8         <internal>:(.eh_frame)
// CHECK-NEXT: 0000000000201000 0000000000000015     4 .text
// CHECK-NEXT: 0000000000201000 000000000000000e     4         {{.*}}{{/|\\}}map-file.s.tmp1.o:(.text)
// CHECK-NEXT: 0000000000201000 0000000000000000     0                 _start
// CHECK-NEXT: 0000000000201005 0000000000000000     0                 f(int)
// CHECK-NEXT: 000000000020100e 0000000000000000     0                 local
// CHECK-NEXT: 0000000000201010 0000000000000002     4         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text)
// CHECK-NEXT: 0000000000201010 0000000000000000     0                 foo
// CHECK-NEXT: 0000000000201011 0000000000000000     0                 bar
// CHECK-NEXT: 0000000000201012 0000000000000000     1         {{.*}}{{/|\\}}map-file.s.tmp2.o:(.text.zed)
// CHECK-NEXT: 0000000000201012 0000000000000000     0                 zed
// CHECK-NEXT: 0000000000201014 0000000000000000     4         {{.*}}{{/|\\}}map-file.s.tmp3.o:(.text)
// CHECK-NEXT: 0000000000201014 0000000000000000     0                 bah
// CHECK-NEXT: 0000000000201014 0000000000000001     4         {{.*}}{{/|\\}}map-file.s.tmp4.a(map-file.s.tmp4.o):(.text)
// CHECK-NEXT: 0000000000201014 0000000000000000     0                 baz
// CHECK-NEXT: 0000000000202000 0000000000000004    16 .bss
// CHECK-NEXT: 0000000000202000 0000000000000004    16         <internal>:(COMMON)
// CHECK-NEXT: 0000000000000000 0000000000000008     1 .comment
// CHECK-NEXT: 0000000000000000 0000000000000008     1         <internal>:(.comment)
// CHECK-NEXT: 0000000000000000 00000000000000f0     8 .symtab
// CHECK-NEXT: 0000000000000000 00000000000000f0     8         <internal>:(.symtab)
// CHECK-NEXT: 0000000000000000 0000000000000039     1 .shstrtab
// CHECK-NEXT: 0000000000000000 0000000000000039     1         <internal>:(.shstrtab)
// CHECK-NEXT: 0000000000000000 000000000000002f     1 .strtab
// CHECK-NEXT: 0000000000000000 000000000000002f     1         <internal>:(.strtab)

// RUN: not ld.lld %t1.o %t2.o %t3.o %t4.a -o %t -Map=/ 2>&1 \
// RUN:  | FileCheck -check-prefix=FAIL %s
// FAIL: cannot open map file /
