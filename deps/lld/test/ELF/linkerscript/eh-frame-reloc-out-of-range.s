## Check that error is correctly reported when .eh_frame reloc
## is out of range

# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { eh PT_LOAD; text PT_LOAD; }  \
# RUN:       SECTIONS { . = 0x10000; \
# RUN:         .eh_frame_hdr : { *(.eh_frame_hdr*) } : eh \
# RUN:         .eh_frame : { *(.eh_frame) } : eh \
# RUN:         . = 0xF00000000; \
# RUN:         .text : { *(.text*) } : text \
# RUN:       }" > %t.script
# RUN: not ld.lld %t.o -T %t.script -o %t 2>&1 | FileCheck %s

# CHECK: error: {{.*}}:(.eh_frame+0x20): relocation R_X86_64_PC32 out of range: 64424443872 is not in [-2147483648, 2147483647]

	.text
  .globl _start
_start:
	.cfi_startproc
  .cfi_lsda 0, _ex
  nop
	.cfi_endproc

  .data
_ex:
  .word 0
