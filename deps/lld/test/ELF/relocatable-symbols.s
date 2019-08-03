# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -r %t -o %tout
# RUN: llvm-objdump -d %tout | FileCheck -check-prefix=DISASM %s
# RUN: llvm-readobj -r %t | FileCheck -check-prefix=RELOC %s
# RUN: llvm-readobj --symbols -r %tout | FileCheck -check-prefix=SYMBOL %s

# DISASM:      _start:
# DISASM-NEXT:   0: {{.*}} callq 0
# DISASM-NEXT:   5: {{.*}} callq 0
# DISASM-NEXT:   a: {{.*}} callq 0
# DISASM-NEXT:   f: {{.*}} callq 0
# DISASM-NEXT:  14: {{.*}} callq 0
# DISASM-NEXT:  19: {{.*}} callq 0
# DISASM-NEXT:  1e: {{.*}} callq 0
# DISASM-NEXT:  23: {{.*}} callq 0
# DISASM-NEXT:  28: {{.*}} callq 0
# DISASM-NEXT:  2d: {{.*}} callq 0
# DISASM-NEXT:  32: {{.*}} callq 0
# DISASM-NEXT:  37: {{.*}} callq 0
# DISASM-EMPTY:
# DISASM-NEXT: Disassembly of section foo:
# DISASM-EMPTY:
# DISASM-NEXT: foo:
# DISASM-NEXT:  0: 90 nop
# DISASM-NEXT:  1: 90 nop
# DISASM-NEXT:  2: 90 nop
# DISASM-EMPTY:
# DISASM-NEXT: Disassembly of section bar:
# DISASM-EMPTY:
# DISASM-NEXT: bar:
# DISASM-NEXT:  0: 90 nop
# DISASM-NEXT:  1: 90 nop
# DISASM-NEXT:  2: 90 nop

# RELOC:      Relocations [
# RELOC-NEXT:   Section ({{.*}}) .rela.text {
# RELOC-NEXT:     0x1 R_X86_64_PC32 __start_foo 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x6 R_X86_64_PC32 __stop_foo 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0xB R_X86_64_PC32 __start_bar 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x10 R_X86_64_PC32 __stop_bar 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x15 R_X86_64_PC32 __start_doo 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x1A R_X86_64_PC32 __stop_doo 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x1F R_X86_64_PC32 __preinit_array_start 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x24 R_X86_64_PC32 __preinit_array_end 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x29 R_X86_64_PC32 __init_array_start 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x2E R_X86_64_PC32 __init_array_end 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x33 R_X86_64_PC32 __fini_array_start 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:     0x38 R_X86_64_PC32 __fini_array_end 0xFFFFFFFFFFFFFFFC
# RELOC-NEXT:   }
# RELOC-NEXT: ]

# SYMBOL:      Relocations [
# SYMBOL-NEXT:  Section ({{.*}}) .rela.text {
# SYMBOL-NEXT:     0x1 R_X86_64_PC32 __start_foo 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x6 R_X86_64_PC32 __stop_foo 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0xB R_X86_64_PC32 __start_bar 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x10 R_X86_64_PC32 __stop_bar 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x15 R_X86_64_PC32 __start_doo 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x1A R_X86_64_PC32 __stop_doo 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x1F R_X86_64_PC32 __preinit_array_start 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x24 R_X86_64_PC32 __preinit_array_end 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x29 R_X86_64_PC32 __init_array_start 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x2E R_X86_64_PC32 __init_array_end 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x33 R_X86_64_PC32 __fini_array_start 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:     0x38 R_X86_64_PC32 __fini_array_end 0xFFFFFFFFFFFFFFFC
# SYMBOL-NEXT:   }
# SYMBOL-NEXT: ]
# SYMBOL:      Symbol {
# SYMBOL:        Name: __fini_array_end
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __fini_array_start
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __init_array_end
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __init_array_start
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __preinit_array_end
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __preinit_array_start
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __start_bar
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __start_doo
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __start_foo
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __stop_bar
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __stop_doo
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }
# SYMBOL-NEXT: Symbol {
# SYMBOL-NEXT:   Name: __stop_foo
# SYMBOL-NEXT:   Value: 0x0
# SYMBOL-NEXT:   Size: 0
# SYMBOL-NEXT:   Binding: Global
# SYMBOL-NEXT:   Type: None
# SYMBOL-NEXT:   Other: 0
# SYMBOL-NEXT:   Section: Undefined
# SYMBOL-NEXT: }

.global _start
.text
_start:
 .byte 0xe8
 .long __start_foo - . -4
 .byte 0xe8
 .long __stop_foo - . -4

 .byte 0xe8
 .long __start_bar - . -4
 .byte 0xe8
 .long __stop_bar - . -4

 .byte 0xe8
 .long __start_doo - . -4
 .byte 0xe8
 .long __stop_doo - . -4

 .byte 0xe8
 .long __preinit_array_start - . -4
 .byte 0xe8
 .long __preinit_array_end - . -4
 .byte 0xe8
 .long __init_array_start - . -4
 .byte 0xe8
 .long __init_array_end - . -4
 .byte 0xe8
 .long __fini_array_start - . -4
 .byte 0xe8
 .long __fini_array_end - . -4

.section foo,"ax"
 nop
 nop
 nop

.section bar,"ax"
 nop
 nop
 nop
