// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-freebsd %S/Inputs/shared2-x86-64.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-freebsd %s -o %t.o
// RUN: ld.lld -z ifunc-noplt -z notext --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d --no-show-raw-insn %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r --dynamic-table %tout | FileCheck %s

// Check that we emitted relocations for the ifunc calls
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rela.dyn {
// CHECK-NEXT:     0x201008 R_X86_64_PLT32 bar 0xFFFFFFFFFFFFFFFC
// CHECK-NEXT:     0x201003 R_X86_64_PLT32 foo 0xFFFFFFFFFFFFFFFC
// CHECK-NEXT:   }
// CHECK-NEXT:   Section (5) .rela.plt {
// CHECK-NEXT:     0x203018 R_X86_64_JUMP_SLOT bar2 0x0
// CHECK-NEXT:     0x203020 R_X86_64_JUMP_SLOT zed2 0x0
// CHECK-NEXT:   }

// Check that ifunc call sites still require relocation
// DISASM: Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201000 foo:
// DISASM-NEXT:   201000:      	retq
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201001 bar:
// DISASM-NEXT:   201001:      	retq
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201002 _start:
// DISASM-NEXT:   201002:      	callq	0 <_start+0x5>
// DISASM-NEXT:   201007:      	callq	0 <_start+0xa>
// DISASM-NEXT:   20100c:      	callq	31 <bar2@plt>
// DISASM-NEXT:   201011:      	callq	42 <zed2@plt>
// DISASM-EMPTY:
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201020 .plt:
// DISASM-NEXT:   201020:      	pushq	8162(%rip)
// DISASM-NEXT:   201026:      	jmpq	*8164(%rip)
// DISASM-NEXT:   20102c:      	nopl	(%rax)
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201030 bar2@plt:
// DISASM-NEXT:   201030:      	jmpq	*8162(%rip)
// DISASM-NEXT:   201036:      	pushq	$0
// DISASM-NEXT:   20103b:      	jmp	-32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT: 0000000000201040 zed2@plt:
// DISASM-NEXT:   201040:      	jmpq	*8154(%rip)
// DISASM-NEXT:   201046:      	pushq	$1
// DISASM-NEXT:   20104b:      	jmp	-48 <.plt>

.text
.type foo STT_GNU_IFUNC
.globl foo
foo:
 ret

.type bar STT_GNU_IFUNC
.globl bar
bar:
 ret

.globl _start
_start:
 call foo
 call bar
 call bar2
 call zed2
