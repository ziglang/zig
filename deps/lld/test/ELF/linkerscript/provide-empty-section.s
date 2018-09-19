# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tundefined.o
# RUN: echo "foo=42" | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %tdefined.o
# RUN: echo "call foo" | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %treference.o

# RUN: echo "SECTIONS { .bar : { PROVIDE(foo = .); } }" > %t.script

# Case 1: Provided symbol is undefined and not referenced - empty section should be removed.
# RUN: ld.lld %tundefined.o -T %t.script -o %t1.elf
# RUN: llvm-readobj -sections %t1.elf | FileCheck %s --check-prefix=NOSECTION

# Case 2: Provided symbol is undefined and referenced - empty section should not be removed.
# RUN: ld.lld %tundefined.o %treference.o -T %t.script -o %t2.elf
# RUN: llvm-readobj -sections %t2.elf | FileCheck %s --check-prefix=SECTION

# Case 3: Provided symbol is defined and not referenced - empty section should be removed.
# RUN: ld.lld %tdefined.o -T %t.script -o %t3.elf
# RUN: llvm-readobj -sections %t3.elf | FileCheck %s --check-prefix=NOSECTION

# Case 4: Provided symbol is defined and referenced - empty section should not be removed.
# RUN: ld.lld %tdefined.o %treference.o -T %t.script -o %t4.elf
# RUN: llvm-readobj -sections %t4.elf | FileCheck %s --check-prefix=SECTION

.global _start
_start:
    ret

# SECTION: .bar
# NOSECTION-NOT: .bar
