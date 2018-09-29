# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { mysym = .; }" > %t.script

# RUN: ld.lld %t.o -o %t-default.elf -T %t.script
# RUN: llvm-readobj --symbols %t-default.elf | FileCheck %s --check-prefix=DEFAULT
# DEFAULT: Name: mysym
# DEFAULT-NEXT: Value: 0x0

# RUN: ld.lld %t.o -o %t-switch.elf -T %t.script --image-base=0x100000
# RUN: llvm-readobj --symbols %t-switch.elf | FileCheck %s --check-prefix=SWITCH
# SWITCH: Name: mysym
# SWITCH-NEXT: Value: 0x100000

.global _start
_start:
    nop
