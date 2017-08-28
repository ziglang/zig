# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -f aaa --auxiliary bbb -o %t
# RUN: llvm-readobj --dynamic-table %t | FileCheck %s

# CHECK:      DynamicSection [
# CHECK-NEXT: Tag                Type          Name/Value
# CHECK-NEXT: 0x000000007FFFFFFD AUXILIARY     Auxiliary library: [aaa]
# CHECK-NEXT: 0x000000007FFFFFFD AUXILIARY     Auxiliary library: [bbb]

# RUN: not ld.lld %t.o -f aaa --auxiliary bbb -o %t 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR %s
# ERR: -f may not be used without -shared
