# REQUIRES: mips
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %tmips
# RUN: ld.lld -m elf32btsmip -e _start %tmips -o %t2mips
# RUN: llvm-readobj -file-headers %t2mips | FileCheck --check-prefix=MIPS %s
# RUN: ld.lld %tmips -e _start -o %t3mips
# RUN: llvm-readobj -file-headers %t3mips | FileCheck --check-prefix=MIPS %s
# RUN: echo 'OUTPUT_FORMAT(elf32-tradbigmips)' > %tmips.script
# RUN: ld.lld %tmips.script -e _start %tmips -o %t4mips
# RUN: llvm-readobj -file-headers %t4mips | FileCheck --check-prefix=MIPS %s
# MIPS:      ElfHeader {
# MIPS-NEXT:   Ident {
# MIPS-NEXT:     Magic: (7F 45 4C 46)
# MIPS-NEXT:     Class: 32-bit (0x1)
# MIPS-NEXT:     DataEncoding: BigEndian (0x2)
# MIPS-NEXT:     FileVersion: 1
# MIPS-NEXT:     OS/ABI: SystemV (0x0)
# MIPS-NEXT:     ABIVersion: 1
# MIPS-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPS-NEXT:   }
# MIPS-NEXT:   Type: Executable (0x2)
# MIPS-NEXT:   Machine: EM_MIPS (0x8)
# MIPS-NEXT:   Version: 1
# MIPS-NEXT:   Entry:
# MIPS-NEXT:   ProgramHeaderOffset: 0x34
# MIPS-NEXT:   SectionHeaderOffset:
# MIPS-NEXT:   Flags [
# MIPS-NEXT:     EF_MIPS_ABI_O32
# MIPS-NEXT:     EF_MIPS_ARCH_32
# MIPS-NEXT:     EF_MIPS_CPIC
# MIPS-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux %s -o %tmipsel
# RUN: ld.lld -m elf32ltsmip -e _start %tmipsel -o %t2mipsel
# RUN: llvm-readobj -file-headers %t2mipsel | FileCheck --check-prefix=MIPSEL %s
# RUN: ld.lld -melf32ltsmip -e _start %tmipsel -o %t2mipsel
# RUN: llvm-readobj -file-headers %t2mipsel | FileCheck --check-prefix=MIPSEL %s
# RUN: ld.lld %tmipsel -e _start -o %t3mipsel
# RUN: llvm-readobj -file-headers %t3mipsel | FileCheck --check-prefix=MIPSEL %s
# RUN: echo 'OUTPUT_FORMAT(elf32-tradlittlemips)' > %tmipsel.script
# RUN: ld.lld %tmipsel.script -e _start %tmipsel -o %t4mipsel
# RUN: llvm-readobj -file-headers %t4mipsel | FileCheck --check-prefix=MIPSEL %s
# MIPSEL:      ElfHeader {
# MIPSEL-NEXT:   Ident {
# MIPSEL-NEXT:     Magic: (7F 45 4C 46)
# MIPSEL-NEXT:     Class: 32-bit (0x1)
# MIPSEL-NEXT:     DataEncoding: LittleEndian (0x1)
# MIPSEL-NEXT:     FileVersion: 1
# MIPSEL-NEXT:     OS/ABI: SystemV (0x0)
# MIPSEL-NEXT:     ABIVersion: 1
# MIPSEL-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPSEL-NEXT:   }
# MIPSEL-NEXT:   Type: Executable (0x2)
# MIPSEL-NEXT:   Machine: EM_MIPS (0x8)
# MIPSEL-NEXT:   Version: 1
# MIPSEL-NEXT:   Entry:
# MIPSEL-NEXT:   ProgramHeaderOffset: 0x34
# MIPSEL-NEXT:   SectionHeaderOffset:
# MIPSEL-NEXT:   Flags [
# MIPSEL-NEXT:     EF_MIPS_ABI_O32
# MIPSEL-NEXT:     EF_MIPS_ARCH_32
# MIPSEL-NEXT:     EF_MIPS_CPIC
# MIPSEL-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux-gnuabin32 %s -o %tmipsn32
# RUN: ld.lld -m elf32btsmipn32 -e _start %tmipsn32 -o %t2mipsn32
# RUN: llvm-readobj -file-headers %t2mipsn32 | FileCheck --check-prefix=MIPSN32 %s
# RUN: ld.lld %tmipsn32 -e _start -o %t3mipsn32
# RUN: llvm-readobj -file-headers %t3mipsn32 | FileCheck --check-prefix=MIPSN32 %s
# RUN: echo 'OUTPUT_FORMAT(elf32-ntradbigmips)' > %tmipsn32.script
# RUN: ld.lld %tmipsn32.script -e _start %tmipsn32 -o %t4mipsn32
# RUN: llvm-readobj -file-headers %t4mipsn32 | FileCheck --check-prefix=MIPSN32 %s
# MIPSN32:      ElfHeader {
# MIPSN32-NEXT:   Ident {
# MIPSN32-NEXT:     Magic: (7F 45 4C 46)
# MIPSN32-NEXT:     Class: 32-bit (0x1)
# MIPSN32-NEXT:     DataEncoding: BigEndian (0x2)
# MIPSN32-NEXT:     FileVersion: 1
# MIPSN32-NEXT:     OS/ABI: SystemV (0x0)
# MIPSN32-NEXT:     ABIVersion: 1
# MIPSN32-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPSN32-NEXT:   }
# MIPSN32-NEXT:   Type: Executable (0x2)
# MIPSN32-NEXT:   Machine: EM_MIPS (0x8)
# MIPSN32-NEXT:   Version: 1
# MIPSN32-NEXT:   Entry:
# MIPSN32-NEXT:   ProgramHeaderOffset: 0x34
# MIPSN32-NEXT:   SectionHeaderOffset:
# MIPSN32-NEXT:   Flags [
# MIPSN32-NEXT:     EF_MIPS_ABI2
# MIPSN32-NEXT:     EF_MIPS_ARCH_64
# MIPSN32-NEXT:     EF_MIPS_CPIC
# MIPSN32-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=mips64el-unknown-linux-gnuabin32 %s -o %tmipsn32el
# RUN: ld.lld -m elf32ltsmipn32 -e _start %tmipsn32el -o %t2mipsn32el
# RUN: llvm-readobj -file-headers %t2mipsn32el | FileCheck --check-prefix=MIPSN32EL %s
# RUN: ld.lld -melf32ltsmipn32 -e _start %tmipsn32el -o %t2mipsn32el
# RUN: llvm-readobj -file-headers %t2mipsn32el | FileCheck --check-prefix=MIPSN32EL %s
# RUN: ld.lld %tmipsn32el -e _start -o %t3mipsn32el
# RUN: llvm-readobj -file-headers %t3mipsn32el | FileCheck --check-prefix=MIPSN32EL %s
# RUN: echo 'OUTPUT_FORMAT(elf32-ntradlittlemips)' > %tmipsn32el.script
# RUN: ld.lld %tmipsn32el.script -e _start %tmipsn32el -o %t4mipsn32el
# RUN: llvm-readobj -file-headers %t4mipsn32el | FileCheck --check-prefix=MIPSN32EL %s
# MIPSN32EL:      ElfHeader {
# MIPSN32EL-NEXT:   Ident {
# MIPSN32EL-NEXT:     Magic: (7F 45 4C 46)
# MIPSN32EL-NEXT:     Class: 32-bit (0x1)
# MIPSN32EL-NEXT:     DataEncoding: LittleEndian (0x1)
# MIPSN32EL-NEXT:     FileVersion: 1
# MIPSN32EL-NEXT:     OS/ABI: SystemV (0x0)
# MIPSN32EL-NEXT:     ABIVersion: 1
# MIPSN32EL-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPSN32EL-NEXT:   }
# MIPSN32EL-NEXT:   Type: Executable (0x2)
# MIPSN32EL-NEXT:   Machine: EM_MIPS (0x8)
# MIPSN32EL-NEXT:   Version: 1
# MIPSN32EL-NEXT:   Entry:
# MIPSN32EL-NEXT:   ProgramHeaderOffset: 0x34
# MIPSN32EL-NEXT:   SectionHeaderOffset:
# MIPSN32EL-NEXT:   Flags [
# MIPSN32EL-NEXT:     EF_MIPS_ABI2
# MIPSN32EL-NEXT:     EF_MIPS_ARCH_64
# MIPSN32EL-NEXT:     EF_MIPS_CPIC
# MIPSN32EL-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -position-independent \
# RUN:         %s -o %tmips64
# RUN: ld.lld -m elf64btsmip -e _start %tmips64 -o %t2mips64
# RUN: llvm-readobj -file-headers %t2mips64 | FileCheck --check-prefix=MIPS64 %s
# RUN: ld.lld %tmips64 -e _start -o %t3mips64
# RUN: llvm-readobj -file-headers %t3mips64 | FileCheck --check-prefix=MIPS64 %s
# RUN: echo 'OUTPUT_FORMAT(elf64-tradbigmips)' > %tmips64.script
# RUN: ld.lld %tmips64.script -e _start %tmips64 -o %t4mips64
# RUN: llvm-readobj -file-headers %t4mips64 | FileCheck --check-prefix=MIPS64 %s
# MIPS64:      ElfHeader {
# MIPS64-NEXT:   Ident {
# MIPS64-NEXT:     Magic: (7F 45 4C 46)
# MIPS64-NEXT:     Class: 64-bit (0x2)
# MIPS64-NEXT:     DataEncoding: BigEndian (0x2)
# MIPS64-NEXT:     FileVersion: 1
# MIPS64-NEXT:     OS/ABI: SystemV (0x0)
# MIPS64-NEXT:     ABIVersion: 0
# MIPS64-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPS64-NEXT:   }
# MIPS64-NEXT:   Type: Executable (0x2)
# MIPS64-NEXT:   Machine: EM_MIPS (0x8)
# MIPS64-NEXT:   Version: 1
# MIPS64-NEXT:   Entry:
# MIPS64-NEXT:   ProgramHeaderOffset: 0x40
# MIPS64-NEXT:   SectionHeaderOffset:
# MIPS64-NEXT:   Flags [
# MIPS64-NEXT:     EF_MIPS_ARCH_64
# MIPS64-NEXT:     EF_MIPS_CPIC
# MIPS64-NEXT:     EF_MIPS_PIC
# MIPS64-NEXT:   ]

# RUN: llvm-mc -filetype=obj -triple=mips64el-unknown-linux \
# RUN:         -position-independent %s -o %tmips64el
# RUN: ld.lld -m elf64ltsmip -e _start %tmips64el -o %t2mips64el
# RUN: llvm-readobj -file-headers %t2mips64el | FileCheck --check-prefix=MIPS64EL %s
# RUN: ld.lld %tmips64el -e _start -o %t3mips64el
# RUN: llvm-readobj -file-headers %t3mips64el | FileCheck --check-prefix=MIPS64EL %s
# RUN: echo 'OUTPUT_FORMAT(elf64-tradlittlemips)' > %tmips64el.script
# RUN: ld.lld %tmips64el.script -e _start %tmips64el -o %t4mips64el
# RUN: llvm-readobj -file-headers %t4mips64el | FileCheck --check-prefix=MIPS64EL %s
# MIPS64EL:      ElfHeader {
# MIPS64EL-NEXT:   Ident {
# MIPS64EL-NEXT:     Magic: (7F 45 4C 46)
# MIPS64EL-NEXT:     Class: 64-bit (0x2)
# MIPS64EL-NEXT:     DataEncoding: LittleEndian (0x1)
# MIPS64EL-NEXT:     FileVersion: 1
# MIPS64EL-NEXT:     OS/ABI: SystemV (0x0)
# MIPS64EL-NEXT:     ABIVersion: 0
# MIPS64EL-NEXT:     Unused: (00 00 00 00 00 00 00)
# MIPS64EL-NEXT:   }
# MIPS64EL-NEXT:   Type: Executable (0x2)
# MIPS64EL-NEXT:   Machine: EM_MIPS (0x8)
# MIPS64EL-NEXT:   Version: 1
# MIPS64EL-NEXT:   Entry:
# MIPS64EL-NEXT:   ProgramHeaderOffset: 0x40
# MIPS64EL-NEXT:   SectionHeaderOffset:
# MIPS64EL-NEXT:   Flags [
# MIPS64EL-NEXT:     EF_MIPS_ARCH_64
# MIPS64EL-NEXT:     EF_MIPS_CPIC
# MIPS64EL-NEXT:     EF_MIPS_PIC
# MIPS64EL-NEXT:   ]

.globl _start
_start:
