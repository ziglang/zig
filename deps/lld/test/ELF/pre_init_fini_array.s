// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2
// RUN: ld.lld %t2 -o %t2.so -shared
// RUN: ld.lld %t %t2.so -o %t2
// RUN: llvm-readobj -r -symbols -sections -dynamic-table %t2 | FileCheck %s
// RUN: llvm-objdump -d %t2 | FileCheck --check-prefix=DISASM %s

.globl _start
_start:
  call __preinit_array_start
  call __preinit_array_end
  call __init_array_start
  call __init_array_end
  call __fini_array_start
  call __fini_array_end


.section .init_array,"aw",@init_array
  .quad 0

.section .preinit_array,"aw",@preinit_array
        .quad 0
        .byte 0

.section .fini_array,"aw",@fini_array
        .quad 0
        .short 0

// CHECK:      Name: .init_array
// CHECK-NEXT: Type: SHT_INIT_ARRAY
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: [[INIT_ADDR:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: [[INIT_SIZE:.*]]


// CHECK:     Name: .preinit_array
// CHECK-NEXT: Type: SHT_PREINIT_ARRAY
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT:    ]
// CHECK-NEXT: Address: [[PREINIT_ADDR:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: [[PREINIT_SIZE:.*]]


// CHECK:      Name: .fini_array
// CHECK-NEXT: Type: SHT_FINI_ARRAY
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: [[FINI_ADDR:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: [[FINI_SIZE:.*]]

// CHECK:      Relocations [
// CHECK-NEXT: ]

// CHECK:        Name: __fini_array_end
// CHECK-NEXT:   Value: 0x20201B
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .fini_array
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __fini_array_start
// CHECK-NEXT:   Value: [[FINI_ADDR]]
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .fini_array
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __init_array_end
// CHECK-NEXT:   Value: 0x202008
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .init_array
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __init_array_start
// CHECK-NEXT:   Value: [[INIT_ADDR]]
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .init_array
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __preinit_array_end
// CHECK-NEXT:   Value: 0x202011
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .preinit_array
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __preinit_array_start
// CHECK-NEXT:   Value: [[PREINIT_ADDR]]
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .preinit_array
// CHECK-NEXT: }

// CHECK: DynamicSection
// CHECK: PREINIT_ARRAY        [[PREINIT_ADDR]]
// CHECK: PREINIT_ARRAYSZ      [[PREINIT_SIZE]] (bytes)
// CHECK: INIT_ARRAY           [[INIT_ADDR]]
// CHECK: INIT_ARRAYSZ         [[INIT_SIZE]] (bytes)
// CHECK: FINI_ARRAY           [[FINI_ADDR]]
// CHECK: FINI_ARRAYSZ         [[FINI_SIZE]] (bytes)


// 0x202008 - (0x201000 + 5) = 4099
// 0x202011 - (0x201005 + 5) = 4103
// 0x202000 - (0x20100a + 5) = 4081
// 0x202008 - (0x20100f + 5) = 4084
// 0x202011 - (0x201014 + 5) = 4088
// 0x20201B - (0x201019 + 5) = 4093
// DISASM:      _start:
// DISASM-NEXT:   201000:  e8 {{.*}}  callq  4099
// DISASM-NEXT:   201005:  e8 {{.*}}  callq  4103
// DISASM-NEXT:   20100a:  e8 {{.*}}  callq  4081
// DISASM-NEXT:   20100f:  e8 {{.*}}  callq  4084
// DISASM-NEXT:   201014:  e8 {{.*}}  callq  4088
// DISASM-NEXT:   201019:  e8 {{.*}}  callq  4093
