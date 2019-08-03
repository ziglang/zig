# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %taarch64
# RUN: ld.lld -m aarch64linux %taarch64 -o %t2aarch64
# RUN: llvm-readobj --file-headers %t2aarch64 | FileCheck --check-prefix=AARCH64 %s
# RUN: ld.lld -m aarch64elf %taarch64 -o %t3aarch64
# RUN: llvm-readobj --file-headers %t3aarch64 | FileCheck --check-prefix=AARCH64 %s
# RUN: ld.lld -m aarch64_elf64_le_vec %taarch64 -o %t4aarch64
# RUN: llvm-readobj --file-headers %t4aarch64 | FileCheck --check-prefix=AARCH64 %s
# RUN: ld.lld %taarch64 -o %t5aarch64
# RUN: llvm-readobj --file-headers %t5aarch64 | FileCheck --check-prefix=AARCH64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-littleaarch64)' > %t4aarch64.script
# RUN: ld.lld %t4aarch64.script %taarch64 -o %t4aarch64
# RUN: llvm-readobj --file-headers %t4aarch64 | FileCheck --check-prefix=AARCH64 %s
# AARCH64:      ElfHeader {
# AARCH64-NEXT:   Ident {
# AARCH64-NEXT:     Magic: (7F 45 4C 46)
# AARCH64-NEXT:     Class: 64-bit (0x2)
# AARCH64-NEXT:     DataEncoding: LittleEndian (0x1)
# AARCH64-NEXT:     FileVersion: 1
# AARCH64-NEXT:     OS/ABI: SystemV (0x0)
# AARCH64-NEXT:     ABIVersion: 0
# AARCH64-NEXT:     Unused: (00 00 00 00 00 00 00)
# AARCH64-NEXT:   }
# AARCH64-NEXT:   Type: Executable (0x2)
# AARCH64-NEXT:   Machine: EM_AARCH64 (0xB7)
# AARCH64-NEXT:   Version: 1
# AARCH64-NEXT:   Entry:
# AARCH64-NEXT:   ProgramHeaderOffset: 0x40
# AARCH64-NEXT:   SectionHeaderOffset:
# AARCH64-NEXT:   Flags [ (0x0)
# AARCH64-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %taarch64fbsd
# RUN: echo 'OUTPUT_FORMAT(elf64-aarch64-freebsd)' > %taarch64fbsd.script
# RUN: ld.lld %taarch64fbsd.script %taarch64fbsd -o %t2aarch64fbsd
# RUN: llvm-readobj --file-headers %t2aarch64fbsd | FileCheck --check-prefix=AARCH64-FBSD %s
# AARCH64-FBSD:      ElfHeader {
# AARCH64-FBSD-NEXT:   Ident {
# AARCH64-FBSD-NEXT:     Magic: (7F 45 4C 46)
# AARCH64-FBSD-NEXT:     Class: 64-bit (0x2)
# AARCH64-FBSD-NEXT:     DataEncoding: LittleEndian (0x1)
# AARCH64-FBSD-NEXT:     FileVersion: 1
# AARCH64-FBSD-NEXT:     OS/ABI: FreeBSD (0x9)
# AARCH64-FBSD-NEXT:     ABIVersion: 0
# AARCH64-FBSD-NEXT:     Unused: (00 00 00 00 00 00 00)
# AARCH64-FBSD-NEXT:   }
# AARCH64-FBSD-NEXT:   Type: Executable (0x2)
# AARCH64-FBSD-NEXT:   Machine: EM_AARCH64 (0xB7)
# AARCH64-FBSD-NEXT:   Version: 1
# AARCH64-FBSD-NEXT:   Entry:
# AARCH64-FBSD-NEXT:   ProgramHeaderOffset: 0x40
# AARCH64-FBSD-NEXT:   SectionHeaderOffset:
# AARCH64-FBSD-NEXT:   Flags [ (0x0)
# AARCH64-FBSD-NEXT:   ]

.globl _start
_start:
