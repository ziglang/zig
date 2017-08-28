# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive.s -o %t2
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive2.s -o %t3
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive3.s -o %t4
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive4.s -o %t5
# RUN: llvm-ar rcs %tar %t2 %t3 %t4
# RUN: ld.lld %t %tar %t5 -o %tout
# RUN: llvm-nm %tout | FileCheck %s
# RUN: rm -f %tarthin
# RUN: llvm-ar --format=gnu rcsT %tarthin %t2 %t3 %t4
# RUN: ld.lld %t %tarthin %t5 -o %tout
# RUN: llvm-nm %tout | FileCheck %s
# REQUIRES: x86

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
# RUN: ld.lld %tar %t -o %tout
# RUN: llvm-nm %tout | FileCheck --check-prefix=AR-FIRST %s

# AR-FIRST:      T _start
# AR-FIRST-NEXT: w bar
# AR-FIRST-NEXT: T end
# AR-FIRST-NEXT: w foo
