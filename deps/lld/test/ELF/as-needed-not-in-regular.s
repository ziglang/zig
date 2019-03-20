# REQUIRES: x86

# RUN: echo '.globl a1, a2; .type a1, @function; .type a2, @function; a1: a2: ret' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %ta.o
# RUN: ld.lld %ta.o --shared --soname=a.so -o %ta.so

# RUN: echo '.globl b; .type b, @function; b: jmp a1@PLT' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %tb.o
# RUN: ld.lld %tb.o %ta.so --shared --soname=b.so -o %tb.so

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %tb.so --as-needed %ta.so -o %t
# RUN: llvm-readelf -d %t | FileCheck %s

# RUN: ld.lld %t.o %tb.so --as-needed %ta.so --gc-sections -o %t
# RUN: llvm-readelf -d %t | FileCheck %s

# The symbol a1 (defined in a.so) is not referenced by a regular object,
# the reference to a2 is weak, don't add a DT_NEEDED entry for a.so.
# CHECK-NOT: a.so

# RUN: ld.lld %t.o %tb.so --as-needed %ta.so --no-as-needed %ta.so -o %t
# RUN: llvm-readelf -d %t | FileCheck %s -check-prefix=NEEDED

# a.so is needed because one of its occurrences is needed.
# NEEDED: a.so

.global _start
.weak a2
_start:
  jmp b@PLT
  jmp a2
