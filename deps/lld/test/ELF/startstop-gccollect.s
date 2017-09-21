# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Default run: sections foo and bar exist in output
# RUN: ld.lld %t -o %tout
# RUN: llvm-objdump -d %tout | FileCheck -check-prefix=DISASM %s

## Check that foo and bar sections are not garbage collected,
## we do not want to reclaim sections if they are referred
## by __start_* and __stop_* symbols.
# RUN: ld.lld %t --gc-sections -o %tout
# RUN: llvm-objdump -d %tout | FileCheck -check-prefix=DISASM %s

# DISASM:      _start:
# DISASM-NEXT: 201000:        e8 05 00 00 00  callq   5 <__start_foo>
# DISASM-NEXT: 201005:        e8 01 00 00 00  callq   1 <__start_bar>
# DISASM-NEXT: Disassembly of section foo:
# DISASM-NEXT: __start_foo:
# DISASM-NEXT: 20100a:        90      nop
# DISASM-NEXT: Disassembly of section bar:
# DISASM-NEXT: __start_bar:
# DISASM-NEXT: 20100b:        90      nop

.global _start
.text
_start:
 callq __start_foo
 callq __start_bar

.section foo,"ax"
 nop

.section bar,"ax"
 nop
