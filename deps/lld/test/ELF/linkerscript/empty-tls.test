# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux /dev/null -o %t.o
# RUN: ld.lld -o %t.so -T %s %t.o -shared
# RUN: llvm-readobj -l %t.so | FileCheck %s

PHDRS {
  ph_tls PT_TLS;
}

# Test that we don't crash with an empty PT_TLS

# CHECK:      Type: PT_TLS
# CHECK-NEXT: Offset: 0x0
# CHECK-NEXT: VirtualAddress: 0x0
# CHECK-NEXT: PhysicalAddress: 0x0
# CHECK-NEXT: FileSize: 0
# CHECK-NEXT: MemSize: 0
