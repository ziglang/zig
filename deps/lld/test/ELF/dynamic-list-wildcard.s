# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "{ foo1*; };" > %t.list
# RUN: ld.lld --hash-style=sysv -pie --dynamic-list %t.list %t -o %t.exe
# RUN: llvm-readobj -dyn-symbols %t.exe | FileCheck %s

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value:	 0x0
# CHECK-NEXT:     Size:	 0
# CHECK-NEXT:     Binding:	 Local (0x0)
# CHECK-NEXT:     Type:	 None (0x0)
# CHECK-NEXT:     Other:	 0
# CHECK-NEXT:     Section:	 Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:	 foo1
# CHECK-NEXT:     Value:	 0x1000
# CHECK-NEXT:     Size:	 0
# CHECK-NEXT:     Binding:	 Global (0x1)
# CHECK-NEXT:     Type:	 None (0x0)
# CHECK-NEXT:     Other:	 0
# CHECK-NEXT:     Section:	 .text (0x4)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:	 foo11
# CHECK-NEXT:     Value:	 0x1001
# CHECK-NEXT:     Size:	 0
# CHECK-NEXT:     Binding:	 Global (0x1)
# CHECK-NEXT:     Type:	 None (0x0)
# CHECK-NEXT:     Other:	 0
# CHECK-NEXT:     Section:	 .text (0x4)
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.globl foo1
foo1:
  ret

.globl foo11
foo11:
  ret

.globl foo2
foo2:
  ret

.globl _start
_start:
  retq
