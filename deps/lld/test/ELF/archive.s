# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive.s -o %t2
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive2.s -o %t3
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive3.s -o %t4
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive4.s -o %t5

# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %t2 %t3 %t4

# RUN: ld.lld %t %t.a %t5 -o %t.out
# RUN: llvm-nm %t.out | FileCheck %s

# RUN: rm -f %t.thin
# RUN: llvm-ar --format=gnu rcsT %t.thin %t2 %t3 %t4

# RUN: ld.lld %t %t.thin %t5 -o %t.out
# RUN: llvm-nm %t.out | FileCheck %s

# Nothing here. Just needed for the linker to create a undefined _start symbol.

.quad end

.weak foo
.quad foo

.weak bar
.quad bar


# CHECK:      T _start
# CHECK-NEXT: T bar
# CHECK-NEXT: T end
# CHECK-NEXT: w foo


# Test that the hitting the first object file after having a lazy symbol for
# _start is handled correctly.
# RUN: ld.lld %t.a %t -o %t.out
# RUN: llvm-nm %t.out | FileCheck --check-prefix=AR-FIRST %s

# AR-FIRST:      T _start
# AR-FIRST-NEXT: w bar
# AR-FIRST-NEXT: T end
# AR-FIRST-NEXT: w foo
