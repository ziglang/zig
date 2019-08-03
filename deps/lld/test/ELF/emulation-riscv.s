# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV32 %s
# RUN: ld.lld -m elf32lriscv %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV32 %s
# RUN: echo 'OUTPUT_FORMAT(elf32-littleriscv)' > %t.script
# RUN: ld.lld %t.script %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV32 %s

# RV32:      ElfHeader {
# RV32-NEXT:   Ident {
# RV32-NEXT:     Magic: (7F 45 4C 46)
# RV32-NEXT:     Class: 32-bit (0x1)
# RV32-NEXT:     DataEncoding: LittleEndian (0x1)
# RV32-NEXT:     FileVersion: 1
# RV32-NEXT:     OS/ABI: SystemV (0x0)
# RV32-NEXT:     ABIVersion: 0
# RV32-NEXT:     Unused: (00 00 00 00 00 00 00)
# RV32-NEXT:   }
# RV32-NEXT:   Type: Executable (0x2)
# RV32-NEXT:   Machine: EM_RISCV (0xF3)
# RV32-NEXT:   Version: 1
# RV32-NEXT:   Entry:
# RV32-NEXT:   ProgramHeaderOffset: 0x34
# RV32-NEXT:   SectionHeaderOffset:
# RV32-NEXT:   Flags [ (0x0)
# RV32-NEXT:   ]
# RV32-NEXT:   HeaderSize: 52
# RV32-NEXT:   ProgramHeaderEntrySize: 32
# RV32-NEXT:   ProgramHeaderCount:
# RV32-NEXT:   SectionHeaderEntrySize: 40
# RV32-NEXT:   SectionHeaderCount:
# RV32-NEXT:   StringTableSectionIndex:
# RV32-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV64 %s
# RUN: ld.lld -m elf64lriscv %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-littleriscv)' > %t.script
# RUN: ld.lld %t.script %t.o -o %t
# RUN: llvm-readobj --file-headers %t | FileCheck --check-prefix=RV64 %s

# RV64:      ElfHeader {
# RV64-NEXT:   Ident {
# RV64-NEXT:     Magic: (7F 45 4C 46)
# RV64-NEXT:     Class: 64-bit (0x2)
# RV64-NEXT:     DataEncoding: LittleEndian (0x1)
# RV64-NEXT:     FileVersion: 1
# RV64-NEXT:     OS/ABI: SystemV (0x0)
# RV64-NEXT:     ABIVersion: 0
# RV64-NEXT:     Unused: (00 00 00 00 00 00 00)
# RV64-NEXT:   }
# RV64-NEXT:   Type: Executable (0x2)
# RV64-NEXT:   Machine: EM_RISCV (0xF3)
# RV64-NEXT:   Version: 1
# RV64-NEXT:   Entry:
# RV64-NEXT:   ProgramHeaderOffset: 0x40
# RV64-NEXT:   SectionHeaderOffset:
# RV64-NEXT:   Flags [ (0x0)
# RV64-NEXT:   ]
# RV64-NEXT:   HeaderSize: 64
# RV64-NEXT:   ProgramHeaderEntrySize: 56
# RV64-NEXT:   ProgramHeaderCount:
# RV64-NEXT:   SectionHeaderEntrySize: 64
# RV64-NEXT:   SectionHeaderCount:
# RV64-NEXT:   StringTableSectionIndex:
# RV64-NEXT: }

.globl _start
_start:
