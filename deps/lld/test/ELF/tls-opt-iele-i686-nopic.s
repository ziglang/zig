// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %p/Inputs/tls-opt-iele-i686-nopic.s -o %tso.o
// RUN: ld.lld -shared %tso.o -o %tso
// RUN: ld.lld --hash-style=sysv %t.o %tso -o %t1
// RUN: llvm-readobj -s -r %t1 | FileCheck --check-prefix=GOTREL %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s

// GOTREL:      Section {
// GOTREL:        Index:
// GOTREL:        Name: .got
// GOTREL-NEXT:   Type: SHT_PROGBITS
// GOTREL-NEXT:   Flags [
// GOTREL-NEXT:     SHF_ALLOC
// GOTREL-NEXT:     SHF_WRITE
// GOTREL-NEXT:   ]
// GOTREL-NEXT:   Address: 0x12058
// GOTREL-NEXT:   Offset: 0x2058
// GOTREL-NEXT:   Size: 8
// GOTREL-NEXT:   Link: 0
// GOTREL-NEXT:   Info: 0
// GOTREL-NEXT:   AddressAlignment: 4
// GOTREL-NEXT:   EntrySize: 0
// GOTREL-NEXT: }
// GOTREL:      Relocations [
// GOTREL-NEXT: Section ({{.*}}) .rel.dyn {
// GOTREL-NEXT:   0x12058 R_386_TLS_TPOFF tlsshared0 0x0
// GOTREL-NEXT:   0x1205C R_386_TLS_TPOFF tlsshared1 0x0
// GOTREL-NEXT:  }
// GOTREL-NEXT: ]

// DISASM:      Disassembly of section .text:
// DISASM-NEXT: _start:
// 4294967288 = 0xFFFFFFF8
// 4294967292 = 0xFFFFFFFC
// 73808 = (.got)[0] = 0x12058
// 73812 = (.got)[1] = 0x1205C
// DISASM-NEXT: 11000: c7 c1 f8 ff ff ff movl $4294967288, %ecx
// DISASM-NEXT: 11006: 65 8b 01          movl %gs:(%ecx), %eax
// DISASM-NEXT: 11009: b8 f8 ff ff ff    movl $4294967288, %eax
// DISASM-NEXT: 1100e: 65 8b 00          movl %gs:(%eax), %eax
// DISASM-NEXT: 11011: 81 c1 f8 ff ff ff addl $4294967288, %ecx
// DISASM-NEXT: 11017: 65 8b 01          movl %gs:(%ecx), %eax
// DISASM-NEXT: 1101a: c7 c1 fc ff ff ff movl $4294967292, %ecx
// DISASM-NEXT: 11020: 65 8b 01          movl %gs:(%ecx), %eax
// DISASM-NEXT: 11023: b8 fc ff ff ff    movl $4294967292, %eax
// DISASM-NEXT: 11028: 65 8b 00          movl %gs:(%eax), %eax
// DISASM-NEXT: 1102b: 81 c1 fc ff ff ff addl $4294967292, %ecx
// DISASM-NEXT: 11031: 65 8b 01          movl %gs:(%ecx), %eax
// DISASM-NEXT: 11034: 8b 0d 58 20 01 00 movl 73816, %ecx
// DISASM-NEXT: 1103a: 65 8b 01          movl %gs:(%ecx), %eax
// DISASM-NEXT: 1103d: 03 0d 5c 20 01 00 addl 73820, %ecx
// DISASM-NEXT: 11043: 65 8b 01          movl %gs:(%ecx), %eax

.type tlslocal0,@object
.section .tbss,"awT",@nobits
.globl tlslocal0
.align 4
tlslocal0:
 .long 0
 .size tlslocal0, 4

.type tlslocal1,@object
.section .tbss,"awT",@nobits
.globl tlslocal1
.align 4
tlslocal1:
 .long 0
 .size tlslocal1, 4

.section .text
.globl ___tls_get_addr
.type ___tls_get_addr,@function
___tls_get_addr:

.section .text
.globl _start
_start:
movl tlslocal0@indntpoff,%ecx
movl %gs:(%ecx),%eax

movl tlslocal0@indntpoff,%eax
movl %gs:(%eax),%eax

addl tlslocal0@indntpoff,%ecx
movl %gs:(%ecx),%eax

movl tlslocal1@indntpoff,%ecx
movl %gs:(%ecx),%eax

movl tlslocal1@indntpoff,%eax
movl %gs:(%eax),%eax

addl tlslocal1@indntpoff,%ecx
movl %gs:(%ecx),%eax

movl tlsshared0@indntpoff,%ecx
movl %gs:(%ecx),%eax

addl tlsshared1@indntpoff,%ecx
movl %gs:(%ecx),%eax
