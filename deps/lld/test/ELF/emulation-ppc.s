# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %tppc64
# RUN: ld.lld -m elf64ppc %tppc64 -o %t2ppc64
# RUN: llvm-readobj -file-headers %t2ppc64 | FileCheck --check-prefix=PPC64 %s
# RUN: ld.lld %tppc64 -o %t3ppc64
# RUN: llvm-readobj -file-headers %t3ppc64 | FileCheck --check-prefix=PPC64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-powerpc)' > %tppc64.script
# RUN: ld.lld %tppc64.script  %tppc64 -o %t4ppc64
# RUN: llvm-readobj -file-headers %t4ppc64 | FileCheck --check-prefix=PPC64 %s

# PPC64:      ElfHeader {
# PPC64-NEXT:   Ident {
# PPC64-NEXT:     Magic: (7F 45 4C 46)
# PPC64-NEXT:     Class: 64-bit (0x2)
# PPC64-NEXT:     DataEncoding: BigEndian (0x2)
# PPC64-NEXT:     FileVersion: 1
# PPC64-NEXT:     OS/ABI: SystemV (0x0)
# PPC64-NEXT:     ABIVersion: 0
# PPC64-NEXT:     Unused: (00 00 00 00 00 00 00)
# PPC64-NEXT:   }
# PPC64-NEXT:   Type: Executable (0x2)
# PPC64-NEXT:   Machine: EM_PPC64 (0x15)
# PPC64-NEXT:   Version: 1
# PPC64-NEXT:   Entry:
# PPC64-NEXT:   ProgramHeaderOffset: 0x40
# PPC64-NEXT:   SectionHeaderOffset:
# PPC64-NEXT:   Flags [ (0x2)
# PPC64-NEXT:     0x2
# PPC64-NEXT:   ]
# PPC64-NEXT:   HeaderSize: 64
# PPC64-NEXT:   ProgramHeaderEntrySize: 56
# PPC64-NEXT:   ProgramHeaderCount:
# PPC64-NEXT:   SectionHeaderEntrySize: 64
# PPC64-NEXT:   SectionHeaderCount:
# PPC64-NEXT:   StringTableSectionIndex:
# PPC64-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-freebsd %s -o %tppc64fbsd
# RUN: echo 'OUTPUT_FORMAT(elf64-powerpc-freebsd)' > %tppc64fbsd.script
# RUN: ld.lld %tppc64fbsd.script  %tppc64fbsd -o %t2ppc64fbsd
# RUN: llvm-readobj -file-headers %t2ppc64fbsd | FileCheck --check-prefix=PPC64-FBSD %s

# PPC64-FBSD:      ElfHeader {
# PPC64-FBSD-NEXT:   Ident {
# PPC64-FBSD-NEXT:     Magic: (7F 45 4C 46)
# PPC64-FBSD-NEXT:     Class: 64-bit (0x2)
# PPC64-FBSD-NEXT:     DataEncoding: BigEndian (0x2)
# PPC64-FBSD-NEXT:     FileVersion: 1
# PPC64-FBSD-NEXT:     OS/ABI: FreeBSD (0x9)
# PPC64-FBSD-NEXT:     ABIVersion: 0
# PPC64-FBSD-NEXT:     Unused: (00 00 00 00 00 00 00)
# PPC64-FBSD-NEXT:   }
# PPC64-FBSD-NEXT:   Type: Executable (0x2)
# PPC64-FBSD-NEXT:   Machine: EM_PPC64 (0x15)
# PPC64-FBSD-NEXT:   Version: 1
# PPC64-FBSD-NEXT:   Entry:
# PPC64-FBSD-NEXT:   ProgramHeaderOffset: 0x40
# PPC64-FBSD-NEXT:   SectionHeaderOffset:
# PPC64-FBSD-NEXT:   Flags [ (0x2)
# PPC64-FBSD-NEXT:     0x2
# PPC64-FBSD-NEXT:   ]
# PPC64-FBSD-NEXT:   HeaderSize: 64
# PPC64-FBSD-NEXT:   ProgramHeaderEntrySize: 56
# PPC64-FBSD-NEXT:   ProgramHeaderCount:
# PPC64-FBSD-NEXT:   SectionHeaderEntrySize: 64
# PPC64-FBSD-NEXT:   SectionHeaderCount:
# PPC64-FBSD-NEXT:   StringTableSectionIndex:
# PPC64-FBSD-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %tppc64le
# RUN: ld.lld -m elf64lppc %tppc64le -o %t2ppc64le
# RUN: llvm-readobj -file-headers %t2ppc64le | FileCheck --check-prefix=PPC64LE %s
# RUN: ld.lld %tppc64le -o %t3ppc64le
# RUN: llvm-readobj -file-headers %t3ppc64le | FileCheck --check-prefix=PPC64LE %s
# RUN: echo 'OUTPUT_FORMAT(elf64-powerpcle)' > %tppc64le.script
# RUN: ld.lld %tppc64le.script  %tppc64le -o %t4ppc64le
# RUN: llvm-readobj -file-headers %t4ppc64le | FileCheck --check-prefix=PPC64LE %s

# PPC64LE:      ElfHeader {
# PPC64LE-NEXT:   Ident {
# PPC64LE-NEXT:     Magic: (7F 45 4C 46)
# PPC64LE-NEXT:     Class: 64-bit (0x2)
# PPC64LE-NEXT:     DataEncoding: LittleEndian (0x1)
# PPC64LE-NEXT:     FileVersion: 1
# PPC64LE-NEXT:     OS/ABI: SystemV (0x0)
# PPC64LE-NEXT:     ABIVersion: 0
# PPC64LE-NEXT:     Unused: (00 00 00 00 00 00 00)
# PPC64LE-NEXT:   }
# PPC64LE-NEXT:   Type: Executable (0x2)
# PPC64LE-NEXT:   Machine: EM_PPC64 (0x15)
# PPC64LE-NEXT:   Version: 1
# PPC64LE-NEXT:   Entry:
# PPC64LE-NEXT:   ProgramHeaderOffset: 0x40
# PPC64LE-NEXT:   SectionHeaderOffset:
# PPC64LE-NEXT:   Flags [ (0x2)
# PPC64LE-NEXT:     0x2
# PPC64LE-NEXT:   ]
# PPC64LE-NEXT:   HeaderSize: 64
# PPC64LE-NEXT:   ProgramHeaderEntrySize: 56
# PPC64LE-NEXT:   ProgramHeaderCount:
# PPC64LE-NEXT:   SectionHeaderEntrySize: 64
# PPC64LE-NEXT:   SectionHeaderCount:
# PPC64LE-NEXT:   StringTableSectionIndex:
# PPC64LE-NEXT: }

.globl _start
_start:
