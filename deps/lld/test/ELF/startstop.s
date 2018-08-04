// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld --hash-style=sysv %t -o %tout -shared
// RUN: llvm-objdump -d %tout | FileCheck -check-prefix=DISASM %s
// RUN: llvm-readobj -symbols -r %tout | FileCheck -check-prefix=SYMBOL %s

// DISASM: _start:
// DISASM:    1000:       {{.*}}  callq   10
// DISASM:    1005:       {{.*}}  callq   8
// DISASM:    100a:       {{.*}}  callq   3
// DISASM: Disassembly of section foo:
// DISASM: __start_foo:
// DISASM:    100f:       90      nop
// DISASM:    1010:       90      nop
// DISASM:    1011:       90      nop
// DISASM: Disassembly of section bar:
// DISASM: __start_bar:
// DISASM:    1012:       90      nop
// DISASM:    1013:       90      nop
// DISASM:    1014:       90      nop

// SYMBOL:      Relocations [
// SYMBOL-NEXT:   Section ({{.*}}) .rela.dyn {
// SYMBOL-NEXT:     R_X86_64_RELATIVE
// SYMBOL-NEXT:     R_X86_64_RELATIVE
// SYMBOL-NEXT:     R_X86_64_RELATIVE
// SYMBOL-NEXT:     R_X86_64_RELATIVE
// SYMBOL-NEXT:   }
// SYMBOL-NEXT: ]

// SYMBOL: Symbol {
// SYMBOL:   Name: __start_bar
// SYMBOL:   Value: 0x1012
// SYMBOL:   STV_HIDDEN
// SYMBOL:   Section: bar
// SYMBOL: }
// SYMBOL-NOT:   Section: __stop_bar
// SYMBOL: Symbol {
// SYMBOL:   Name: __start_foo
// SYMBOL:   Value: 0x100F
// SYMBOL:   STV_HIDDEN
// SYMBOL:   Section: foo
// SYMBOL: }
// SYMBOL: Symbol {
// SYMBOL:   Name: __stop_foo
// SYMBOL:   Value: 0x1012
// SYMBOL:   STV_HIDDEN
// SYMBOL:   Section: foo
// SYMBOL: }

// SYMBOL: Symbol {
// SYMBOL:   Name: __stop_zed1
// SYMBOL:   Value: 0x2010
// SYMBOL:   STV_PROTECTED
// SYMBOL:   Section: zed1
// SYMBOL: }
// SYMBOL: Symbol {
// SYMBOL:   Name: __stop_zed2
// SYMBOL:   Value: 0x2020
// SYMBOL:   STV_PROTECTED
// SYMBOL:   Section: zed2
// SYMBOL: }

.hidden __start_foo
.hidden __stop_foo
.hidden __start_bar
.global _start
.text
_start:
	call __start_foo
	call __stop_foo
	call __start_bar

.section foo,"ax"
	nop
	nop
	nop

.section bar,"ax"
	nop
	nop
	nop

.section zed1, "aw"
        .quad __stop_zed2
        .quad __stop_zed2 + 1

.section zed2, "aw"
        .quad __stop_zed1
        .quad __stop_zed1 + 1
