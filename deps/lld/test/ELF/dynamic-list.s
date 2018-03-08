# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld --hash-style=sysv -shared %t2.o -soname shared -o %t2.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Check exporting only one symbol.
# RUN: echo "{ foo1; };" > %t.list
# RUN: ld.lld --hash-style=sysv --dynamic-list %t.list %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck %s

## And now using quoted strings (the output is the same since it does
## use any wildcard character).
# RUN: echo "{ \"foo1\"; };" > %t.list
# RUN: ld.lld --hash-style=sysv --dynamic-list %t.list %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck %s

## And now using --export-dynamic-symbol.
# RUN: ld.lld --hash-style=sysv --export-dynamic-symbol foo1 %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck %s
# RUN: ld.lld --hash-style=sysv --export-dynamic-symbol=foo1 %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck %s

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: @
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo1@
# CHECK-NEXT:     Value: 0x201000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text (0x4)
# CHECK-NEXT:   }
# CHECK-NEXT: ]


## Now export all the foo1, foo2, and foo31 symbols
# RUN: echo "{ foo1; foo2; foo31; };" > %t.list
# RUN: ld.lld --hash-style=sysv --dynamic-list %t.list %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck -check-prefix=CHECK2 %s
# RUN: echo "{ foo1; foo2; };" > %t1.list
# RUN: echo "{ foo31; };" > %t2.list
# RUN: ld.lld --hash-style=sysv --dynamic-list %t1.list --dynamic-list %t2.list %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck -check-prefix=CHECK2 %s

# CHECK2:      DynamicSymbols [
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: @
# CHECK2-NEXT:     Value: 0x0
# CHECK2-NEXT:     Size: 0
# CHECK2-NEXT:     Binding: Local
# CHECK2-NEXT:     Type: None
# CHECK2-NEXT:     Other: 0
# CHECK2-NEXT:     Section: Undefined
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: foo1@
# CHECK2-NEXT:     Value: 0x201000
# CHECK2-NEXT:     Size: 0
# CHECK2-NEXT:     Binding: Global (0x1)
# CHECK2-NEXT:     Type: None (0x0)
# CHECK2-NEXT:     Other: 0
# CHECK2-NEXT:     Section: .text (0x4)
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: foo2@
# CHECK2-NEXT:     Value: 0x201001
# CHECK2-NEXT:     Size: 0
# CHECK2-NEXT:     Binding: Global (0x1)
# CHECK2-NEXT:     Type: None (0x0)
# CHECK2-NEXT:     Other: 0
# CHECK2-NEXT:     Section: .text (0x4)
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: foo31@
# CHECK2-NEXT:     Value: 0x201002
# CHECK2-NEXT:     Size: 0
# CHECK2-NEXT:     Binding: Global (0x1)
# CHECK2-NEXT:     Type: None (0x0)
# CHECK2-NEXT:     Other: 0
# CHECK2-NEXT:     Section: .text (0x4)
# CHECK2-NEXT:   }
# CHECK2-NEXT: ]


## --export-dynamic overrides --dynamic-list, i.e. --export-dynamic with an
## incomplete dynamic-list still exports everything.
# RUN: echo "{ foo2; };" > %t.list
# RUN: ld.lld --hash-style=sysv --dynamic-list %t.list --export-dynamic %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck -check-prefix=CHECK3 %s

## The same with --export-dynamic-symbol.
# RUN: ld.lld --hash-style=sysv --export-dynamic-symbol=foo2 --export-dynamic %t %t2.so -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck -check-prefix=CHECK3 %s

# CHECK3:      DynamicSymbols [
# CHECK3-NEXT:   Symbol {
# CHECK3-NEXT:     Name: @
# CHECK3-NEXT:     Value: 0x0
# CHECK3-NEXT:     Size: 0
# CHECK3-NEXT:     Binding: Local
# CHECK3-NEXT:     Type: None
# CHECK3-NEXT:     Other: 0
# CHECK3-NEXT:     Section: Undefined
# CHECK3-NEXT:   }
# CHECK3-NEXT:   Symbol {
# CHECK3-NEXT:     Name: _start@
# CHECK3-NEXT:     Value: 0x201003
# CHECK3-NEXT:     Size: 0
# CHECK3-NEXT:     Binding: Global (0x1)
# CHECK3-NEXT:     Type: None (0x0)
# CHECK3-NEXT:     Other: 0
# CHECK3-NEXT:     Section: .text (0x4)
# CHECK3-NEXT:   }
# CHECK3-NEXT:   Symbol {
# CHECK3-NEXT:     Name: foo1@
# CHECK3-NEXT:     Value: 0x201000
# CHECK3-NEXT:     Size: 0
# CHECK3-NEXT:     Binding: Global (0x1)
# CHECK3-NEXT:     Type: None (0x0)
# CHECK3-NEXT:     Other: 0
# CHECK3-NEXT:     Section: .text (0x4)
# CHECK3-NEXT:   }
# CHECK3-NEXT:   Symbol {
# CHECK3-NEXT:     Name: foo2@
# CHECK3-NEXT:     Value: 0x201001
# CHECK3-NEXT:     Size: 0
# CHECK3-NEXT:     Binding: Global (0x1)
# CHECK3-NEXT:     Type: None (0x0)
# CHECK3-NEXT:     Other: 0
# CHECK3-NEXT:     Section: .text (0x4)
# CHECK3-NEXT:   }
# CHECK3-NEXT:   Symbol {
# CHECK3-NEXT:     Name: foo31@
# CHECK3-NEXT:     Value: 0x201002
# CHECK3-NEXT:     Size: 0
# CHECK3-NEXT:     Binding: Global (0x1)
# CHECK3-NEXT:     Type: None (0x0)
# CHECK3-NEXT:     Other: 0
# CHECK3-NEXT:     Section: .text (0x4)
# CHECK3-NEXT:   }
# CHECK3-NEXT: ]

.globl foo1
foo1:
  ret

.globl foo2
foo2:
  ret

.globl foo31
foo31:
  ret

.globl _start
_start:
  retq
