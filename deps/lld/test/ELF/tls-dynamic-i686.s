// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t
// RUN: ld.lld --hash-style=sysv -shared -z norelro %t -o %tout
// RUN: llvm-readobj --sections -r %tout | FileCheck %s
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
// CHECK-NEXT: Address: 0x2070
// CHECK-NEXT: Offset: 0x2070
// CHECK-NEXT: Size: 32
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize: 0

// CHECK: Relocations [
// CHECK:      Section ({{.+}}) .rel.dyn {
// CHECK-NEXT: 0x2080 R_386_TLS_DTPMOD32 - 0x0
// CHECK-NEXT: 0x2070 R_386_TLS_DTPMOD32 tls0 0x0
// CHECK-NEXT: 0x2074 R_386_TLS_DTPOFF32 tls0 0x0
// CHECK-NEXT: 0x2088 R_386_TLS_TPOFF tls0 0x0
// CHECK-NEXT: 0x2078 R_386_TLS_DTPMOD32 tls1 0x0
// CHECK-NEXT: 0x207C R_386_TLS_DTPOFF32 tls1 0x0
// CHECK-NEXT: 0x208C R_386_TLS_TPOFF tls1 0x0
// CHECK-NEXT: }

// DIS:      Disassembly of section .text:
// DIS-EMPTY:
// DIS-NEXT: _start:
// General dynamic model:
// -32 and -24 are first and second GOT entries offsets.
// Each one is a pair of records.
// DIS-NEXT: 1000: {{.*}} leal -32(,%ebx), %eax
// DIS-NEXT: 1007: {{.*}} calll 100
// DIS-NEXT: 100c: {{.*}} leal -24(,%ebx), %eax
// DIS-NEXT: 1013: {{.*}} calll 88
// Local dynamic model:
// -16 is a local module tls index offset.
// DIS-NEXT: 1018: {{.*}} leal -16(%ebx), %eax
// DIS-NEXT: 101e: {{.*}} calll 77
// DIS-NEXT: 1023: {{.*}} leal 8(%eax), %edx
// DIS-NEXT: 1029: {{.*}} leal -16(%ebx), %eax
// DIS-NEXT: 102f: {{.*}} calll 60
// DIS-NEXT: 1034: {{.*}} leal 12(%eax), %edx
// Initial exec model:
// DIS-NEXT: 103a: {{.*}} movl %gs:0, %eax
// DIS-NEXT: 1040: {{.*}} addl -8(%ebx), %eax
// DIS-NEXT: 1046: {{.*}} movl %gs:0, %eax
// DIS-NEXT: 104c: {{.*}} addl -4(%ebx), %eax
