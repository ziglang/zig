// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-freebsd %S/Inputs/shared2-x86-64.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=i686-pc-freebsd %s -o %t.o
// RUN: ld.lld -z ifunc-noplt -z notext --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d --no-show-raw-insn %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r --dynamic-table %tout | FileCheck %s

// Check that we emitted relocations for the ifunc calls
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rel.dyn {
// CHECK-NEXT:     0x401008 R_386_PLT32 bar
// CHECK-NEXT:     0x401003 R_386_PLT32 foo
// CHECK-NEXT:   }
// CHECK-NEXT:   Section (5) .rel.plt {
// CHECK-NEXT:     0x40300C R_386_JUMP_SLOT bar2
// CHECK-NEXT:     0x403010 R_386_JUMP_SLOT zed2
// CHECK-NEXT:   }

// Check that ifunc call sites still require relocation
// DISASM: Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: 00401000 foo:
// DISASM-NEXT:   401000:      	retl
// DISASM-EMPTY:
// DISASM-NEXT: 00401001 bar:
// DISASM-NEXT:   401001:      	retl
// DISASM-EMPTY:
// DISASM-NEXT: 00401002 _start:
// DISASM-NEXT:   401002:      	calll	-4 <_start+0x1>
// DISASM-NEXT:   401007:      	calll	-4 <_start+0x6>
// DISASM-NEXT:   40100c:      	calll	31 <bar2@plt>
// DISASM-NEXT:   401011:      	calll	42 <zed2@plt>
// DISASM-EMPTY:
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: 00401020 .plt:
// DISASM-NEXT:   401020:      	pushl	4206596
// DISASM-NEXT:   401026:      	jmpl	*4206600
// DISASM-NEXT:   40102c:      	nop
// DISASM-NEXT:   40102d:      	nop
// DISASM-NEXT:   40102e:      	nop
// DISASM-NEXT:   40102f:      	nop
// DISASM-EMPTY:
// DISASM-NEXT: 00401030 bar2@plt:
// DISASM-NEXT:   401030:      	jmpl	*4206604
// DISASM-NEXT:   401036:      	pushl	$0
// DISASM-NEXT:   40103b:      	jmp	-32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT: 00401040 zed2@plt:
// DISASM-NEXT:   401040:      	jmpl	*4206608
// DISASM-NEXT:   401046:      	pushl	$8
// DISASM-NEXT:   40104b:      	jmp	-48 <.plt>

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
 call foo@plt
 call bar@plt
 call bar2@plt
 call zed2@plt
