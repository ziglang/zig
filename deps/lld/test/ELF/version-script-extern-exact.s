# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "FOO { global: extern \"C++\" { \"aaa*\"; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck %s --check-prefix=NOMATCH

# NOMATCH:     DynamicSymbols [
# NOMATCH-NOT:   _Z3aaaPf@@FOO
# NOMATCH-NOT:   _Z3aaaPi@@FOO
# NOMATCH:     ]

# RUN: echo "FOO { global: extern \"C++\" { \"aaa*\"; aaa*; }; };" > %t2.script
# RUN: ld.lld --version-script %t2.script -shared %t.o -o %t2.so
# RUN: llvm-readobj -dyn-symbols %t2.so | FileCheck %s --check-prefix=MATCH
# MATCH:   DynamicSymbols [
# MATCH:     _Z3aaaPf@@FOO
# MATCH:     _Z3aaaPi@@FOO
# MATCH:   ]

.text
.globl _Z3aaaPi
.type _Z3aaaPi,@function
_Z3aaaPi:
retq

.globl _Z3aaaPf
.type _Z3aaaPf,@function
_Z3aaaPf:
retq
