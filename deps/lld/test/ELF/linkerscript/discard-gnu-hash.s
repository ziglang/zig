# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: ld.lld --hash-style both -shared -o %t1 %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK: .gnu.hash
# CHECK: .hash

# RUN: echo "SECTIONS { /DISCARD/ : { *(.hash) } }" > %t.script
# RUN: ld.lld --hash-style both -shared -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 \
# RUN:   | FileCheck %s --check-prefix=HASH
# HASH-NOT: .hash
# HASH:     .gnu.hash
# HASH-NOT: .hash

# RUN: echo "SECTIONS { /DISCARD/ : { *(.gnu.hash) } }" > %t.script
# RUN: ld.lld --hash-style both -shared -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 \
# RUN:   | FileCheck %s --check-prefix=GNUHASH
# GNUHASH-NOT: .gnu.hash
# GNUHASH:     .hash
# GNUHASH-NOT: .gnu.hash
