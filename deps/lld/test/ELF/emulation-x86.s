# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %tx64
# RUN: ld.lld -m elf_amd64_fbsd %tx64 -o %t2x64
# RUN: llvm-readobj -file-headers %t2x64 | FileCheck --check-prefix=AMD64 %s
# RUN: ld.lld %tx64 -o %t3x64
# RUN: llvm-readobj -file-headers %t3x64 | FileCheck --check-prefix=AMD64 %s
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.sysv
# RUN: ld.lld -m elf_amd64_fbsd %t.sysv -o %t.freebsd
# RUN: llvm-readobj -file-headers %t.freebsd | FileCheck --check-prefix=AMD64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-x86-64-freebsd)' > %t4x64.script
# RUN: ld.lld %t4x64.script %tx64 -o %t4x64
# RUN: llvm-readobj -file-headers %t4x64 | FileCheck --check-prefix=AMD64 %s
# AMD64:      ElfHeader {
# AMD64-NEXT:   Ident {
# AMD64-NEXT:     Magic: (7F 45 4C 46)
# AMD64-NEXT:     Class: 64-bit (0x2)
# AMD64-NEXT:     DataEncoding: LittleEndian (0x1)
# AMD64-NEXT:     FileVersion: 1
# AMD64-NEXT:     OS/ABI: FreeBSD (0x9)
# AMD64-NEXT:     ABIVersion: 0
# AMD64-NEXT:     Unused: (00 00 00 00 00 00 00)
# AMD64-NEXT:   }
# AMD64-NEXT:   Type: Executable (0x2)
# AMD64-NEXT:   Machine: EM_X86_64 (0x3E)
# AMD64-NEXT:   Version: 1
# AMD64-NEXT:   Entry:
# AMD64-NEXT:   ProgramHeaderOffset: 0x40
# AMD64-NEXT:   SectionHeaderOffset:
# AMD64-NEXT:   Flags [ (0x0)
# AMD64-NEXT:   ]
# AMD64-NEXT:   HeaderSize: 64
# AMD64-NEXT:   ProgramHeaderEntrySize: 56
# AMD64-NEXT:   ProgramHeaderCount:
# AMD64-NEXT:   SectionHeaderEntrySize: 64
# AMD64-NEXT:   SectionHeaderCount:
# AMD64-NEXT:   StringTableSectionIndex:
# AMD64-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tx64
# RUN: ld.lld -m elf_x86_64 %tx64 -o %t2x64
# RUN: llvm-readobj -file-headers %t2x64 | FileCheck --check-prefix=X86-64 %s
# RUN: ld.lld %tx64 -o %t3x64
# RUN: llvm-readobj -file-headers %t3x64 | FileCheck --check-prefix=X86-64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-x86-64)' > %t4x64.script
# RUN: ld.lld %t4x64.script %tx64 -o %t4x64
# RUN: ld.lld %tx64 -o %t4x64 %t4x64.script
# RUN: llvm-readobj -file-headers %t4x64 | FileCheck --check-prefix=X86-64 %s
# X86-64:      ElfHeader {
# X86-64-NEXT:   Ident {
# X86-64-NEXT:     Magic: (7F 45 4C 46)
# X86-64-NEXT:     Class: 64-bit (0x2)
# X86-64-NEXT:     DataEncoding: LittleEndian (0x1)
# X86-64-NEXT:     FileVersion: 1
# X86-64-NEXT:     OS/ABI: SystemV (0x0)
# X86-64-NEXT:     ABIVersion: 0
# X86-64-NEXT:     Unused: (00 00 00 00 00 00 00)
# X86-64-NEXT:   }
# X86-64-NEXT:   Type: Executable (0x2)
# X86-64-NEXT:   Machine: EM_X86_64 (0x3E)
# X86-64-NEXT:   Version: 1
# X86-64-NEXT:   Entry:
# X86-64-NEXT:   ProgramHeaderOffset: 0x40
# X86-64-NEXT:   SectionHeaderOffset:
# X86-64-NEXT:   Flags [ (0x0)
# X86-64-NEXT:   ]
# X86-64-NEXT:   HeaderSize: 64
# X86-64-NEXT:   ProgramHeaderEntrySize: 56
# X86-64-NEXT:   ProgramHeaderCount:
# X86-64-NEXT:   SectionHeaderEntrySize: 64
# X86-64-NEXT:   SectionHeaderCount:
# X86-64-NEXT:   StringTableSectionIndex:
# X86-64-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux-gnux32 %s -o %tx32
# RUN: ld.lld -m elf32_x86_64 %tx32 -o %t2x32
# RUN: llvm-readobj -file-headers %t2x32 | FileCheck --check-prefix=X32 %s
# RUN: ld.lld %tx32 -o %t3x32
# RUN: llvm-readobj -file-headers %t3x32 | FileCheck --check-prefix=X32 %s
# RUN: echo 'OUTPUT_FORMAT(elf32-x86-64)' > %t4x32.script
# RUN: ld.lld %t4x32.script %tx32 -o %t4x32
# RUN: llvm-readobj -file-headers %t4x32 | FileCheck --check-prefix=X32 %s
# X32:      ElfHeader {
# X32-NEXT:   Ident {
# X32-NEXT:     Magic: (7F 45 4C 46)
# X32-NEXT:     Class: 32-bit (0x1)
# X32-NEXT:     DataEncoding: LittleEndian (0x1)
# X32-NEXT:     FileVersion: 1
# X32-NEXT:     OS/ABI: SystemV (0x0)
# X32-NEXT:     ABIVersion: 0
# X32-NEXT:     Unused: (00 00 00 00 00 00 00)
# X32-NEXT:   }
# X32-NEXT:   Type: Executable (0x2)
# X32-NEXT:   Machine: EM_X86_64 (0x3E)
# X32-NEXT:   Version: 1
# X32-NEXT:   Entry:
# X32-NEXT:   ProgramHeaderOffset: 0x34
# X32-NEXT:   SectionHeaderOffset:
# X32-NEXT:   Flags [ (0x0)
# X32-NEXT:   ]
# X32-NEXT:   HeaderSize: 52
# X32-NEXT:   ProgramHeaderEntrySize: 32
# X32-NEXT:   ProgramHeaderCount:
# X32-NEXT:   SectionHeaderEntrySize: 40
# X32-NEXT:   SectionHeaderCount:
# X32-NEXT:   StringTableSectionIndex:
# X32-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %tx86
# RUN: ld.lld -m elf_i386 %tx86 -o %t2x86
# RUN: llvm-readobj -file-headers %t2x86 | FileCheck --check-prefix=X86 %s
# RUN: ld.lld %tx86 -o %t3x86
# RUN: llvm-readobj -file-headers %t3x86 | FileCheck --check-prefix=X86 %s
# RUN: echo 'OUTPUT_FORMAT(elf32-i386)' > %t4x86.script
# RUN: ld.lld %t4x86.script %tx86 -o %t4x86
# RUN: llvm-readobj -file-headers %t4x86 | FileCheck --check-prefix=X86 %s
# X86:      ElfHeader {
# X86-NEXT:   Ident {
# X86-NEXT:     Magic: (7F 45 4C 46)
# X86-NEXT:     Class: 32-bit (0x1)
# X86-NEXT:     DataEncoding: LittleEndian (0x1)
# X86-NEXT:     FileVersion: 1
# X86-NEXT:     OS/ABI: SystemV (0x0)
# X86-NEXT:     ABIVersion: 0
# X86-NEXT:     Unused: (00 00 00 00 00 00 00)
# X86-NEXT:   }
# X86-NEXT:   Type: Executable (0x2)
# X86-NEXT:   Machine: EM_386 (0x3)
# X86-NEXT:   Version: 1
# X86-NEXT:   Entry:
# X86-NEXT:   ProgramHeaderOffset: 0x34
# X86-NEXT:   SectionHeaderOffset:
# X86-NEXT:   Flags [ (0x0)
# X86-NEXT:   ]
# X86-NEXT:   HeaderSize: 52
# X86-NEXT:   ProgramHeaderEntrySize: 32
# X86-NEXT:   ProgramHeaderCount:
# X86-NEXT:   SectionHeaderEntrySize: 40
# X86-NEXT:   SectionHeaderCount:
# X86-NEXT:   StringTableSectionIndex:
# X86-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=i686-unknown-freebsd %s -o %tx86fbsd
# RUN: ld.lld -m elf_i386_fbsd %tx86fbsd -o %t2x86fbsd
# RUN: llvm-readobj -file-headers %t2x86fbsd | FileCheck --check-prefix=X86FBSD %s
# RUN: ld.lld %tx86fbsd -o %t3x86fbsd
# RUN: llvm-readobj -file-headers %t3x86fbsd | FileCheck --check-prefix=X86FBSD %s
# RUN: echo 'OUTPUT_FORMAT(elf32-i386-freebsd)' > %t4x86fbsd.script
# RUN: ld.lld %t4x86fbsd.script %tx86fbsd -o %t4x86fbsd
# RUN: llvm-readobj -file-headers %t4x86fbsd | FileCheck --check-prefix=X86FBSD %s
# X86FBSD:      ElfHeader {
# X86FBSD-NEXT:   Ident {
# X86FBSD-NEXT:     Magic: (7F 45 4C 46)
# X86FBSD-NEXT:     Class: 32-bit (0x1)
# X86FBSD-NEXT:     DataEncoding: LittleEndian (0x1)
# X86FBSD-NEXT:     FileVersion: 1
# X86FBSD-NEXT:     OS/ABI: FreeBSD (0x9)
# X86FBSD-NEXT:     ABIVersion: 0
# X86FBSD-NEXT:     Unused: (00 00 00 00 00 00 00)
# X86FBSD-NEXT:   }
# X86FBSD-NEXT:   Type: Executable (0x2)
# X86FBSD-NEXT:   Machine: EM_386 (0x3)
# X86FBSD-NEXT:   Version: 1
# X86FBSD-NEXT:   Entry:
# X86FBSD-NEXT:   ProgramHeaderOffset: 0x34
# X86FBSD-NEXT:   SectionHeaderOffset:
# X86FBSD-NEXT:   Flags [ (0x0)
# X86FBSD-NEXT:   ]
# X86FBSD-NEXT:   HeaderSize: 52
# X86FBSD-NEXT:   ProgramHeaderEntrySize: 32
# X86FBSD-NEXT:   ProgramHeaderCount:
# X86FBSD-NEXT:   SectionHeaderEntrySize: 40
# X86FBSD-NEXT:   SectionHeaderCount:
# X86FBSD-NEXT:   StringTableSectionIndex:
# X86FBSD-NEXT: }

# RUN: llvm-mc -filetype=obj -triple=i586-intel-elfiamcu %s -o %tiamcu
# RUN: ld.lld -m elf_iamcu %tiamcu -o %t2iamcu
# RUN: llvm-readobj -file-headers %t2iamcu | FileCheck --check-prefix=IAMCU %s
# RUN: ld.lld %tiamcu -o %t3iamcu
# RUN: llvm-readobj -file-headers %t3iamcu | FileCheck --check-prefix=IAMCU %s
# RUN: echo 'OUTPUT_FORMAT(elf32-iamcu)' > %t4iamcu.script
# RUN: ld.lld %t4iamcu.script %tiamcu -o %t4iamcu
# RUN: llvm-readobj -file-headers %t4iamcu | FileCheck --check-prefix=IAMCU %s
# IAMCU:      ElfHeader {
# IAMCU-NEXT:   Ident {
# IAMCU-NEXT:     Magic: (7F 45 4C 46)
# IAMCU-NEXT:     Class: 32-bit (0x1)
# IAMCU-NEXT:     DataEncoding: LittleEndian (0x1)
# IAMCU-NEXT:     FileVersion: 1
# IAMCU-NEXT:     OS/ABI: SystemV (0x0)
# IAMCU-NEXT:     ABIVersion: 0
# IAMCU-NEXT:     Unused: (00 00 00 00 00 00 00)
# IAMCU-NEXT:   }
# IAMCU-NEXT:   Type: Executable (0x2)
# IAMCU-NEXT:   Machine: EM_IAMCU (0x6)
# IAMCU-NEXT:   Version: 1
# IAMCU-NEXT:   Entry:
# IAMCU-NEXT:   ProgramHeaderOffset: 0x34
# IAMCU-NEXT:   SectionHeaderOffset:
# IAMCU-NEXT:   Flags [ (0x0)
# IAMCU-NEXT:   ]
# IAMCU-NEXT:   HeaderSize: 52
# IAMCU-NEXT:   ProgramHeaderEntrySize: 32
# IAMCU-NEXT:   ProgramHeaderCount:
# IAMCU-NEXT:   SectionHeaderEntrySize: 40
# IAMCU-NEXT:   SectionHeaderCount:
# IAMCU-NEXT:   StringTableSectionIndex:
# IAMCU-NEXT: }

.globl _start
_start:
