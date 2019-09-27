# REQUIRES: x86
# Check reading PC values of FDEs and writing lookup table in the .eh_frame_hdr
# if CIE augmentation string has 'L' token and PC values are encoded using
# absolute (not relative) format.

# RUN: llvm-mc -filetype=obj -triple x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --eh-frame-hdr %t.o -o %t
# RUN: llvm-objdump -s -dwarf=frames %t | FileCheck %s

# CHECK:      Contents of section .eh_frame_hdr:
# CHECK-NEXT:  200190 011b033b 14000000 01000000 700e0000
#                                                ^-- 0x201000 - 0x200190
#                                                    .text    - .eh_frame_hdr
# CHECK-NEXT:  2001a0 30000000
# CHECK:      Contents of section .text:
# CHECK-NEXT:  201000 90

# CHECK: Augmentation:          "zLR"
# CHECK: Augmentation data:     00 1B
#                                  ^-- DW_EH_PE_pcrel | DW_EH_PE_udata4 | DW_EH_PE_signed

	.text
  .globl __start
__start:
	.cfi_startproc
  .cfi_lsda 0, _ex
  nop
	.cfi_endproc

  .data
_ex:
  .word 0
