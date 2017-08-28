# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-pc-linux %S/Inputs/gotpc-relax-und-dso.s -o %tdso.o
# RUN: ld.lld -shared %tdso.o -o %t.so
# RUN: ld.lld -shared %t.o %t.so -o %tout
# RUN: llvm-readobj -r -s %tout | FileCheck --check-prefix=RELOC %s
# RUN: llvm-objdump -d %tout | FileCheck --check-prefix=DISASM %s

# RELOC:      Relocations [
# RELOC-NEXT:   Section ({{.*}}) .rela.dyn {
# RELOC-NEXT:     R_X86_64_GLOB_DAT dsofoo 0x0
# RELOC-NEXT:     R_X86_64_GLOB_DAT foo 0x0
# RELOC-NEXT:     R_X86_64_GLOB_DAT und 0x0
# RELOC-NEXT:   }
# RELOC-NEXT: ]

# 0x101e + 7 - 36 = 0x1001
# 0x1025 + 7 - 43 = 0x1001
# DISASM:      Disassembly of section .text:
# DISASM-NEXT: foo:
# DISASM-NEXT:     nop
# DISASM:      hid:
# DISASM-NEXT:     nop
# DISASM:      _start:
# DISASM-NEXT:    movq    4247(%rip), %rax
# DISASM-NEXT:    movq    4240(%rip), %rax
# DISASM-NEXT:    movq    4241(%rip), %rax
# DISASM-NEXT:    movq    4234(%rip), %rax
# DISASM-NEXT:    leaq    -36(%rip), %rax
# DISASM-NEXT:    leaq    -43(%rip), %rax
# DISASM-NEXT:    movq    4221(%rip), %rax
# DISASM-NEXT:    movq    4214(%rip), %rax
# DISASM-NEXT:    movq    4191(%rip), %rax
# DISASM-NEXT:    movq    4184(%rip), %rax
# DISASM-NEXT:    movq    4185(%rip), %rax
# DISASM-NEXT:    movq    4178(%rip), %rax
# DISASM-NEXT:    leaq    -92(%rip), %rax
# DISASM-NEXT:    leaq    -99(%rip), %rax
# DISASM-NEXT:    movq    4165(%rip), %rax
# DISASM-NEXT:    movq    4158(%rip), %rax

.text
.globl foo
.type foo, @function
foo:
 nop

.globl hid
.hidden hid
.type hid, @function
hid:
 nop

.globl _start
.type _start, @function
_start:
 movq und@GOTPCREL(%rip), %rax
 movq und@GOTPCREL(%rip), %rax
 movq dsofoo@GOTPCREL(%rip), %rax
 movq dsofoo@GOTPCREL(%rip), %rax
 movq hid@GOTPCREL(%rip), %rax
 movq hid@GOTPCREL(%rip), %rax
 movq foo@GOTPCREL(%rip), %rax
 movq foo@GOTPCREL(%rip), %rax
 movq und@GOTPCREL(%rip), %rax
 movq und@GOTPCREL(%rip), %rax
 movq dsofoo@GOTPCREL(%rip), %rax
 movq dsofoo@GOTPCREL(%rip), %rax
 movq hid@GOTPCREL(%rip), %rax
 movq hid@GOTPCREL(%rip), %rax
 movq foo@GOTPCREL(%rip), %rax
 movq foo@GOTPCREL(%rip), %rax
