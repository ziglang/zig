// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld --hash-style=sysv -shared %t -o %tout
// RUN: llvm-readobj -sections -relocations %tout | FileCheck %s
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DIS

  leaq  a@tlsld(%rip), %rdi
  callq __tls_get_addr@PLT
  leaq  b@tlsld(%rip), %rdi
  callq __tls_get_addr@PLT
  leaq  a@dtpoff(%rax), %rcx
  leaq  b@dtpoff(%rax), %rcx
  .long b@dtpoff, 0
  leaq  c@tlsgd(%rip), %rdi
  rex64
  callq __tls_get_addr@PLT
  leaq  a@dtpoff(%rax), %rcx
  // Initial Exec Model Code Sequence, II
  movq c@gottpoff(%rip),%rax
  movq %fs:(%rax),%rax
  movabs $a@dtpoff, %rax
  movabs $b@dtpoff, %rax
  movabs $a@dtpoff, %rax

  .global a
  .hidden a
  .section .tbss,"awT",@nobits
  .align 4
a:
  .long 0

  .section .tbss,"awT",@nobits
  .align 4
b:
  .long 0
  .global c
  .section .tbss,"awT",@nobits
  .align 4
c:
  .long 0

// Get the address of the got, and check that it has 4 entries.

// CHECK:      Sections [
// CHECK:          Name: .got (
// CHECK-NEXT:     Type: SHT_PROGBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x30D0
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 40

// CHECK:      Relocations [
// CHECK:        Section ({{.+}}) .rela.dyn {
// CHECK-NEXT:     0x30D0 R_X86_64_DTPMOD64 - 0x0
// CHECK-NEXT:     0x30E0 R_X86_64_DTPMOD64 c 0x0
// CHECK-NEXT:     0x30E8 R_X86_64_DTPOFF64 c 0x0
// CHECK-NEXT:     0x30F0 R_X86_64_TPOFF64 c 0x0
// CHECK-NEXT:   }

// 4297 = (0x20D0 + -4) - (0x1000 + 3) // PC relative offset to got entry.
// 4285 = (0x20D0 + -4) - (0x100c + 3) // PC relative offset to got entry.
// 4267 = (0x20E0 + -4) - (0x102e + 3) // PC relative offset to got entry.
// 4263 = (0x20F0 + -4) - (0x1042 + 3) // PC relative offset to got entry.

// DIS:      Disassembly of section .text:
// DIS-NEXT: .text:
// DIS-NEXT:     1000: {{.+}} leaq    8393(%rip), %rdi
// DIS-NEXT:     1007: {{.+}} callq
// DIS-NEXT:     100c: {{.+}} leaq    8381(%rip), %rdi
// DIS-NEXT:     1013: {{.+}} callq
// DIS-NEXT:     1018: {{.+}} leaq    (%rax), %rcx
// DIS-NEXT:     101f: {{.+}} leaq    4(%rax), %rcx
// DIS-NEXT:     1026: 04 00
// DIS-NEXT:     1028: 00 00
// DIS-NEXT:     102a: 00 00
// DIS-NEXT:     102c: 00 00
// DIS-NEXT:     102e: {{.+}} leaq    8363(%rip), %rdi
// DIS-NEXT:     1035: {{.+}} callq
// DIS-NEXT:     103b: {{.+}} leaq    (%rax), %rcx
// DIS-NEXT:     1042: {{.+}} movq    8359(%rip), %rax
// DIS-NEXT:     1049: {{.+}} movq    %fs:(%rax), %rax
// DIS-NEXT:     104d: {{.+}} movabsq $0, %rax
// DIS-NEXT:     1057: {{.+}} movabsq $4, %rax
// DIS-NEXT:     1061: {{.+}} movabsq $0, %rax
