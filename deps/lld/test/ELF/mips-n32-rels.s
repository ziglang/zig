# REQUIRES: mips
# Check handling of N32 ABI relocation records.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         -target-abi n32 -o %t.o %s
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -t -d -s %t.exe | FileCheck %s
# RUN: llvm-readobj -h %t.exe | FileCheck -check-prefix=ELF %s

  .option pic2
  .text
  .type   __start, @function
  .global  __start
__start:
  lui     $gp,%hi(%neg(%gp_rel(__start)))     # R_MIPS_GPREL16
                                              # R_MIPS_SUB
                                              # R_MIPS_HI16
loc:
  daddiu  $gp,$gp,%lo(%neg(%gp_rel(__start))) # R_MIPS_GPREL16
                                              # R_MIPS_SUB
                                              # R_MIPS_LO16

  .section  .rodata,"a",@progbits
  .gpword(loc)                                # R_MIPS_GPREL32

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20000:  3c 1c 00 01  lui     $gp, 1
#                                                  ^-- 0x20000 - 0x37ff0
#                                                  ^-- 0 - 0xfffe8010
#                                                  ^-- %hi(0x17ff0)
# CHECK:      loc:
# CHECK-NEXT:    20004:  67 9c 7f f0  daddiu  $gp, $gp, 32752
#                                                       ^-- 0x20000 - 0x37ff0
#                                                       ^-- 0 - 0xfffe8010
#                                                       ^-- %lo(0x17ff0)

# CHECK:      Contents of section .rodata:
# CHECK-NEXT:  {{[0-9a-f]+}} fffe8014
#                            ^-- loc - _gp

# CHECK: 00020004      .text   00000000 loc
# CHECK: 00037ff0      .got    00000000 .hidden _gp
# CHECK: 00020000 g  F .text   00000000 __start

# ELF:      Format: ELF32-mips
# ELF-NEXT: Arch: mips
# ELF-NEXT: AddressSize: 32bit
# ELF-NEXT: LoadName:
# ELF-NEXT: ElfHeader {
# ELF-NEXT:   Ident {
# ELF-NEXT:     Magic: (7F 45 4C 46)
# ELF-NEXT:     Class: 32-bit (0x1)
# ELF-NEXT:     DataEncoding: BigEndian (0x2)
# ELF-NEXT:     FileVersion: 1
# ELF-NEXT:     OS/ABI: SystemV (0x0)
# ELF-NEXT:     ABIVersion: 0
# ELF-NEXT:     Unused: (00 00 00 00 00 00 00)
# ELF-NEXT:   }
# ELF-NEXT:   Type: Executable (0x2)
# ELF-NEXT:   Machine: EM_MIPS (0x8)
# ELF-NEXT:   Version: 1
# ELF-NEXT:   Entry: 0x20000
# ELF-NEXT:   ProgramHeaderOffset:
# ELF-NEXT:   SectionHeaderOffset:
# ELF-NEXT:   Flags [
# ELF-NEXT:     EF_MIPS_ABI2
# ELF-NEXT:     EF_MIPS_ARCH_64
# ELF-NEXT:     EF_MIPS_CPIC
# ELF-NEXT:     EF_MIPS_PIC
# ELF-NEXT:   ]
