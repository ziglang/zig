# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { . = SIZEOF_HEADERS; pfoo = foo; pbar = bar; }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-readobj -symbols %t1 | FileCheck %s

# CHECK:       Symbol {
# CHECK:         Name: bar
# CHECK-NEXT:     Value: 0x134
# CHECK-NEXT:     Size: 4
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Object
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .bss
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo
# CHECK-NEXT:     Value: 0x138
# CHECK-NEXT:     Size: 4
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Object
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .bss
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: pfoo
# CHECK-NEXT:     Value: 0x138
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .bss
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: pbar
# CHECK-NEXT:     Value: 0x134
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .bss
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.comm	foo,4,4
.comm	bar,4,4
movl	$1, foo(%rip)
movl	$2, bar(%rip)
