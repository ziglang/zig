// REQUIRES: x86

// Checks whether the TLS optimizations match the cases in Chapter 11 of
// https://raw.githubusercontent.com/wiki/hjl-tools/x86-psABI/x86-64-psABI-1.0.pdf

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/tls-opt-gdie.s -o %tso.o
// RUN: ld.lld -shared %tso.o -o %t.so
// RUN: ld.lld %t.o %t.so -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=RELOC %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s

// RELOC:      Relocations [
// RELOC-NEXT:  Section {{.*}} .rela.dyn {
// RELOC-NEXT:    0x2020C0 R_X86_64_TPOFF64 tlsshared0 0x0
// RELOC-NEXT:    0x2020C8 R_X86_64_TPOFF64 tlsshared1 0x0
// RELOC-NEXT:  }
// RELOC-NEXT: ]

// DISASM:      _start:

// Table 11.5: GD -> IE Code Transition (LP64)
// DISASM-NEXT: 201000: 64 48 8b 04 25 00 00 00 00      movq %fs:0, %rax
// DISASM-NEXT: 201009: 48 03 05 b0 10 00 00            addq 4272(%rip), %rax
// DISASM-NEXT: 201010: 64 48 8b 04 25 00 00 00 00      movq %fs:0, %rax
// DISASM-NEXT: 201019: 48 03 05 a8 10 00 00            addq 4264(%rip), %rax

// Table 11.7: GD -> LE Code Transition (LP64)
// DISASM-NEXT: 201020: 64 48 8b 04 25 00 00 00 00      movq %fs:0, %rax
// DISASM-NEXT: 201029: 48 8d 80 f8 ff ff ff            leaq -8(%rax), %rax
// DISASM-NEXT: 201030: 64 48 8b 04 25 00 00 00 00      movq %fs:0, %rax
// DISASM-NEXT: 201039: 48 8d 80 fc ff ff ff            leaq -4(%rax), %rax


// Table 11.9: LD -> LE Code Transition (LP64)
// DISASM-NEXT: 201040: 66 66 66 66 64 48 8b 04 25 00 00 00 00  movq %fs:0, %rax
// DISASM-NEXT: 20104d: 66 66 66 66 64 48 8b 04 25 00 00 00 00  movq %fs:0, %rax

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

.section .text
.globl _start
_start:
 // Table 11.5: GD -> IE Code Transition (LP64)
 .byte  0x66
 leaq   tlsshared0@tlsgd(%rip),%rdi
 .byte  0x66
 rex64
 call   *__tls_get_addr@GOTPCREL(%rip)

 .byte  0x66
 leaq   tlsshared1@tlsgd(%rip),%rdi
 .byte  0x66
 rex64
 call   *__tls_get_addr@GOTPCREL(%rip)

 // Table 11.7: GD -> LE Code Transition (LP64)
 .byte  0x66
 leaq   tls0@tlsgd(%rip),%rdi
 .byte  0x66
 rex64
 call   *__tls_get_addr@GOTPCREL(%rip)

 .byte  0x66
 leaq   tls1@tlsgd(%rip),%rdi
 .byte  0x66
 rex64
 call   *__tls_get_addr@GOTPCREL(%rip)

 // Table 11.9: LD -> LE Code Transition (LP64)
 leaq   tls0@tlsld(%rip),%rdi
 call   *__tls_get_addr@GOTPCREL(%rip)

 leaq   tls1@tlsld(%rip),%rdi
 call   *__tls_get_addr@GOTPCREL(%rip)
