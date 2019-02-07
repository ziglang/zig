# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %p/Inputs/aarch64-tstbr14-reloc.s -o %t1
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %t2
# RUN: ld.lld %t1 %t2 -o %t
# RUN: llvm-objdump -d %t | FileCheck %s
# RUN: ld.lld -shared %t1 %t2 -o %t3
# RUN: llvm-objdump -d %t3 | FileCheck -check-prefix=DSO %s
# RUN: llvm-readobj -s -r %t3 | FileCheck -check-prefix=DSOREL %s

# 0x1101c - 28 = 0x20000
# 0x11020 - 16 = 0x20010
# 0x11024 - 36 = 0x20000
# 0x11028 - 24 = 0x20010
# CHECK:      Disassembly of section .text:
# CHECK-NEXT: _foo:
# CHECK-NEXT:  210000: {{.*}} nop
# CHECK-NEXT:  210004: {{.*}} nop
# CHECK-NEXT:  210008: {{.*}} nop
# CHECK-NEXT:  21000c: {{.*}} nop
# CHECK:      _bar:
# CHECK-NEXT:  210010: {{.*}} nop
# CHECK-NEXT:  210014: {{.*}} nop
# CHECK-NEXT:  210018: {{.*}} nop
# CHECK:      _start:
# CHECK-NEXT:  21001c: {{.*}} tbnz w3, #15, #-28
# CHECK-NEXT:  210020: {{.*}} tbnz w3, #15, #-16
# CHECK-NEXT:  210024: {{.*}} tbz x6, #45, #-36
# CHECK-NEXT:  210028: {{.*}} tbz x6, #45, #-24

#DSOREL:      Section {
#DSOREL:        Index:
#DSOREL:        Name: .got.plt
#DSOREL-NEXT:   Type: SHT_PROGBITS
#DSOREL-NEXT:   Flags [
#DSOREL-NEXT:     SHF_ALLOC
#DSOREL-NEXT:     SHF_WRITE
#DSOREL-NEXT:   ]
#DSOREL-NEXT:   Address: 0x20000
#DSOREL-NEXT:   Offset: 0x20000
#DSOREL-NEXT:   Size: 40
#DSOREL-NEXT:   Link: 0
#DSOREL-NEXT:   Info: 0
#DSOREL-NEXT:   AddressAlignment: 8
#DSOREL-NEXT:   EntrySize: 0
#DSOREL-NEXT:  }
#DSOREL:      Relocations [
#DSOREL-NEXT:  Section ({{.*}}) .rela.plt {
#DSOREL-NEXT:    0x20018 R_AARCH64_JUMP_SLOT _foo
#DSOREL-NEXT:    0x20020 R_AARCH64_JUMP_SLOT _bar
#DSOREL-NEXT:  }
#DSOREL-NEXT:]

#DSO:      Disassembly of section .text:
#DSO-NEXT: _foo:
#DSO-NEXT:  10000: {{.*}} nop
#DSO-NEXT:  10004: {{.*}} nop
#DSO-NEXT:  10008: {{.*}} nop
#DSO-NEXT:  1000c: {{.*}} nop
#DSO:      _bar:
#DSO-NEXT:  10010: {{.*}} nop
#DSO-NEXT:  10014: {{.*}} nop
#DSO-NEXT:  10018: {{.*}} nop
#DSO:      _start:
# 0x1001c + 52 = 0x10050 = PLT[1]
# 0x10020 + 64 = 0x10060 = PLT[2]
# 0x10024 + 44 = 0x10050 = PLT[1]
# 0x10028 + 56 = 0x10060 = PLT[2]
#DSO-NEXT:  1001c: {{.*}} tbnz w3, #15, #52
#DSO-NEXT:  10020: {{.*}} tbnz w3, #15, #64
#DSO-NEXT:  10024: {{.*}} tbz x6, #45, #44
#DSO-NEXT:  10028: {{.*}} tbz x6, #45, #56
#DSO-NEXT: Disassembly of section .plt:
#DSO-NEXT: .plt:
#DSO-NEXT:  10030: {{.*}} stp x16, x30, [sp, #-16]!
#DSO-NEXT:  10034: {{.*}} adrp x16, #65536
#DSO-NEXT:  10038: {{.*}} ldr x17, [x16, #16]
#DSO-NEXT:  1003c: {{.*}} add x16, x16, #16
#DSO-NEXT:  10040: {{.*}} br x17
#DSO-NEXT:  10044: {{.*}} nop
#DSO-NEXT:  10048: {{.*}} nop
#DSO-NEXT:  1004c: {{.*}} nop
#DSO-EMPTY:
#DSO-NEXT:   _foo@plt:
#DSO-NEXT:  10050: {{.*}} adrp x16, #65536
#DSO-NEXT:  10054: {{.*}} ldr x17, [x16, #24]
#DSO-NEXT:  10058: {{.*}} add x16, x16, #24
#DSO-NEXT:  1005c: {{.*}} br x17
#DSO-EMPTY:
#DSO-NEXT:   _bar@plt:
#DSO-NEXT:  10060: {{.*}} adrp x16, #65536
#DSO-NEXT:  10064: {{.*}} ldr x17, [x16, #32]
#DSO-NEXT:  10068: {{.*}} add x16, x16, #32
#DSO-NEXT:  1006c: {{.*}} br x17

.globl _start
_start:
 tbnz w3, #15, _foo
 tbnz w3, #15, _bar
 tbz x6, #45, _foo
 tbz x6, #45, _bar
