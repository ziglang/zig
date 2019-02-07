// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t1.o
// RUN: ld.lld %t1.o -o /dev/null -M | FileCheck -strict-whitespace %s

.global _start
_start:
 nop

// CHECK:         VMA      LMA     Size Align Out     In      Symbol
// CHECK-NEXT: 401000   401000        1     4 .text
// CHECK-NEXT: 401000   401000        1     4         {{.*}}{{/|\\}}map-file-i686.s.tmp1.o:(.text)
// CHECK-NEXT: 401000   401000        0     1                 _start
// CHECK-NEXT:      0        0        8     1 .comment
// CHECK-NEXT:      0        0        8     1         <internal>:(.comment)
// CHECK-NEXT:      0        0       20     4 .symtab
// CHECK-NEXT:      0        0       20     4         <internal>:(.symtab)
// CHECK-NEXT:      0        0       2a     1 .shstrtab
// CHECK-NEXT:      0        0       2a     1         <internal>:(.shstrtab)
// CHECK-NEXT:      0        0        8     1 .strtab
// CHECK-NEXT:      0        0        8     1         <internal>:(.strtab)
