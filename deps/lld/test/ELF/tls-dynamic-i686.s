// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t
// RUN: ld.lld -shared %t -o %tout
// RUN: llvm-readobj -sections -relocations %tout | FileCheck %s
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DIS

.type tls0,@object
.section .tbss,"awT",@nobits
.globl tls0
.align 4
tls0:
 .long 0
 .size tls0, 4

.type  tls1,@object
.globl tls1
.align 4
tls1:
 .long 0
 .size tls1, 4

.type  tls2,@object
.globl tls2
.hidden tls2
.align 4
tls2:
 .long 0
 .size tls2, 8

.section .text
.globl _start
_start:
leal tls0@tlsgd(,%ebx,1),%eax
call __tls_get_addr@plt

leal tls1@tlsgd(,%ebx,1),%eax
call __tls_get_addr@plt

leal tls2@tlsldm(%ebx),%eax
call __tls_get_addr@plt
leal tls2@dtpoff(%eax),%edx

leal tls2@tlsldm(%ebx),%eax
call __tls_get_addr@plt
leal tls2@dtpoff+4(%eax),%edx

movl %gs:0,%eax
addl tls0@gotntpoff(%ebx),%eax

movl %gs:0,%eax
addl tls1@gotntpoff(%ebx),%eax

// CHECK:      Name: .got (
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x3068
// CHECK-NEXT: Offset: 0x3068
// CHECK-NEXT: Size: 32
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize: 0

// CHECK: Relocations [
// CHECK:      Section ({{.+}}) .rel.dyn {
// CHECK-NEXT: 0x3078 R_386_TLS_DTPMOD32 - 0x0
// CHECK-NEXT: 0x3068 R_386_TLS_DTPMOD32 tls0 0x0
// CHECK-NEXT: 0x306C R_386_TLS_DTPOFF32 tls0 0x0
// CHECK-NEXT: 0x3080 R_386_TLS_TPOFF tls0 0x0
// CHECK-NEXT: 0x3070 R_386_TLS_DTPMOD32 tls1 0x0
// CHECK-NEXT: 0x3074 R_386_TLS_DTPOFF32 tls1 0x0
// CHECK-NEXT: 0x3084 R_386_TLS_TPOFF tls1 0x0
// CHECK-NEXT: }

// DIS:      Disassembly of section .text:
// DIS-NEXT: _start:
// General dynamic model:
// -32 and -24 are first and second GOT entries offsets.
// Each one is a pair of records.
// DIS-NEXT: 1000: 8d 04 1d e0 ff ff ff  leal -32(,%ebx), %eax
// DIS-NEXT: 1007: e8 64 00 00 00        calll 100
// DIS-NEXT: 100c: 8d 04 1d e8 ff ff ff  leal -24(,%ebx), %eax
// DIS-NEXT: 1013: e8 58 00 00 00        calll 88
// Local dynamic model:
// -16 is a local module tls index offset.
// DIS-NEXT: 1018: 8d 83 f0 ff ff ff leal -16(%ebx), %eax
// DIS-NEXT: 101e: e8 4d 00 00 00    calll 77
// DIS-NEXT: 1023: 8d 90 08 00 00 00 leal 8(%eax), %edx
// DIS-NEXT: 1029: 8d 83 f0 ff ff ff leal -16(%ebx), %eax
// DIS-NEXT: 102f: e8 3c 00 00 00    calll 60
// DIS-NEXT: 1034: 8d 90 0c 00 00 00 leal 12(%eax), %edx
// Initial exec model:
// DIS-NEXT: 103a: 65 a1 00 00 00 00 movl %gs:0, %eax
// DIS-NEXT: 1040: 03 83 f8 ff ff ff addl -8(%ebx), %eax
// DIS-NEXT: 1046: 65 a1 00 00 00 00 movl %gs:0, %eax
// DIS-NEXT: 104c: 03 83 fc ff ff ff addl -4(%ebx), %eax
