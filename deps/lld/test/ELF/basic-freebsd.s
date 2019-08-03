# REQUIRES: x86
# Verify that OSABI is set to the correct value.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-readobj --file-headers %t2 | FileCheck %s

.globl _start
_start:
  mov $1, %rax
  mov $42, %rdi
  syscall

# CHECK: ElfHeader {
# CHECK-NEXT:   Ident {
# CHECK-NEXT:     Magic: (7F 45 4C 46)
# CHECK-NEXT:     Class: 64-bit (0x2)
# CHECK-NEXT:     DataEncoding: LittleEndian (0x1)
# CHECK-NEXT:     FileVersion: 1
# CHECK-NEXT:     OS/ABI: FreeBSD (0x9)
# CHECK-NEXT:     ABIVersion: 0
# CHECK-NEXT:     Unused: (00 00 00 00 00 00 00)
# CHECK-NEXT:   }
# CHECK-NEXT:   Type: Executable (0x2)
# CHECK-NEXT:   Machine: EM_X86_64 (0x3E)
