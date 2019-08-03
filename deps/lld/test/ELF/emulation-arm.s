# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=armv7-unknown-linux %s -o %tarm
# RUN: ld.lld -m armelf %tarm -o %t2arm
# RUN: llvm-readobj --file-headers %t2arm | FileCheck --check-prefix=ARM %s
# RUN: ld.lld -m armelf_linux_eabi %tarm -o %t3arm
# RUN: llvm-readobj --file-headers %t3arm | FileCheck --check-prefix=ARM %s
# RUN: ld.lld %tarm -o %t4arm
# RUN: llvm-readobj --file-headers %t4arm | FileCheck --check-prefix=ARM %s
# RUN: echo 'OUTPUT_FORMAT(elf32-littlearm)' > %t5arm.script
# RUN: ld.lld %t5arm.script %tarm -o %t5arm
# RUN: llvm-readobj --file-headers %t5arm | FileCheck --check-prefix=ARM %s
# ARM:      ElfHeader {
# ARM-NEXT:   Ident {
# ARM-NEXT:     Magic: (7F 45 4C 46)
# ARM-NEXT:     Class: 32-bit (0x1)
# ARM-NEXT:     DataEncoding: LittleEndian (0x1)
# ARM-NEXT:     FileVersion: 1
# ARM-NEXT:     OS/ABI: SystemV (0x0)
# ARM-NEXT:     ABIVersion: 0
# ARM-NEXT:     Unused: (00 00 00 00 00 00 00)
# ARM-NEXT:   }
# ARM-NEXT:   Type: Executable (0x2)
# ARM-NEXT:   Machine: EM_ARM (0x28)
# ARM-NEXT:   Version: 1

.globl _start
_start:
