// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %p/Inputs/tls-opt-iele-i686-nopic.s -o %tso.o
// RUN: ld.lld -shared %tso.o -o %tso
// RUN: ld.lld --hash-style=sysv -shared %t.o %tso -o %t1
// RUN: llvm-readobj -S -r -d %t1 | FileCheck --check-prefix=GOTRELSHARED %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASMSHARED %s

// GOTRELSHARED:     Section {
// GOTRELSHARED:      Index: 8
// GOTRELSHARED:      Name: .got
// GOTRELSHARED-NEXT:   Type: SHT_PROGBITS
// GOTRELSHARED-NEXT:   Flags [
// GOTRELSHARED-NEXT:     SHF_ALLOC
// GOTRELSHARED-NEXT:     SHF_WRITE
// GOTRELSHARED-NEXT:   ]
// GOTRELSHARED-NEXT:   Address: 0x2060
// GOTRELSHARED-NEXT:   Offset: 0x2060
// GOTRELSHARED-NEXT:   Size: 16
// GOTRELSHARED-NEXT:   Link: 0
// GOTRELSHARED-NEXT:   Info: 0
// GOTRELSHARED-NEXT:   AddressAlignment: 4
// GOTRELSHARED-NEXT:   EntrySize: 0
// GOTRELSHARED-NEXT: }
// GOTRELSHARED:      Relocations [
// GOTRELSHARED-NEXT:   Section ({{.*}}) .rel.dyn {
// GOTRELSHARED-NEXT:     0x1002 R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x100A R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x1013 R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x101C R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x1024 R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x102D R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x1036 R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x103F R_386_RELATIVE - 0x0
// GOTRELSHARED-NEXT:     0x2060 R_386_TLS_TPOFF tlslocal0 0x0
// GOTRELSHARED-NEXT:     0x2064 R_386_TLS_TPOFF tlslocal1 0x0
// GOTRELSHARED-NEXT:     0x2068 R_386_TLS_TPOFF tlsshared0 0x0
// GOTRELSHARED-NEXT:     0x206C R_386_TLS_TPOFF tlsshared1 0x0
// GOTRELSHARED-NEXT:   }
// GOTRELSHARED-NEXT: ]
// GOTRELSHARED:      0x6FFFFFFA RELCOUNT             8

// DISASMSHARED:       Disassembly of section test:
// DISASMSHARED-EMPTY:
// DISASMSHARED-NEXT:  _start:
// (.got)[0] = 0x2060 = 8288
// (.got)[1] = 0x2064 = 8292
// (.got)[2] = 0x2068 = 8296
// (.got)[3] = 0x206C = 8300
// DISASMSHARED-NEXT:  1000: {{.*}} movl  8288, %ecx
// DISASMSHARED-NEXT:  1006: {{.*}} movl  %gs:(%ecx), %eax
// DISASMSHARED-NEXT:  1009: {{.*}} movl  8288, %eax
// DISASMSHARED-NEXT:  100e: {{.*}} movl  %gs:(%eax), %eax
// DISASMSHARED-NEXT:  1011: {{.*}} addl  8288, %ecx
// DISASMSHARED-NEXT:  1017: {{.*}} movl  %gs:(%ecx), %eax
// DISASMSHARED-NEXT:  101a: {{.*}} movl  8292, %ecx
// DISASMSHARED-NEXT:  1020: {{.*}} movl  %gs:(%ecx), %eax
// DISASMSHARED-NEXT:  1023: {{.*}} movl  8292, %eax
// DISASMSHARED-NEXT:  1028: {{.*}} movl  %gs:(%eax), %eax
// DISASMSHARED-NEXT:  102b: {{.*}} addl  8292, %ecx
// DISASMSHARED-NEXT:  1031: {{.*}} movl  %gs:(%ecx), %eax
// DISASMSHARED-NEXT:  1034: {{.*}} movl  8296, %ecx
// DISASMSHARED-NEXT:  103a: {{.*}} movl  %gs:(%ecx), %eax
// DISASMSHARED-NEXT:  103d: {{.*}} addl  8300, %ecx
// DISASMSHARED-NEXT:  1043: {{.*}} movl  %gs:(%ecx), %eax

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

.section test, "axw"
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
