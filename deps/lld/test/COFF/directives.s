# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows %s -filetype=obj -o %t.obj

# RUN: lld-link -dll -out:%t.dll -entry:entry %t.obj -subsystem:console
# RUN: llvm-objdump -p %t.dll | FileCheck %s

# CHECK:      Export Table:
# CHECK:      DLL name: directives.s.tmp.dll
# CHECK:      Ordinal      RVA  Name
# CHECK-NEXT:       0        0
# CHECK-NEXT:       1   0x1000  exportfn1
# CHECK-NEXT:       2   0x1000  exportfn2
# CHECK-NEXT:       3   0x1000  exportfn3
# CHECK-NEXT:       4   0x1000  exportfn4
# CHECK-NEXT:       5   0x1000  exportfn5
# CHECK-NEXT:       6   0x1000  exportfn6

  .global entry
  .global exportfn1
  .global exportfn2
  .global exportfn3
  .global exportfn4
  .global exportfn5
  .global exportfn6
  .text
entry:
exportfn1:
exportfn2:
exportfn3:
exportfn4:
exportfn5:
exportfn6:
  ret
  .section .drectve
# Test that directive strings can be separated by any combination of
# spaces and null bytes.
  .ascii "-export:exportfn1 "
  .asciz "-export:exportfn2"
  .asciz "-export:exportfn3"
  .asciz "-export:exportfn4 "
  .byte 0
  .ascii " "
  .byte 0
  .asciz "-export:exportfn5"
  .asciz " -export:exportfn6"
