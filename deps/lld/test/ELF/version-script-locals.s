# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "VERSION_1.0 { local: foo1; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=EXACT %s
# EXACT:  DynamicSymbols [
# EXACT:      _start
# EXACT-NOT:  foo1
# EXACT:      foo2
# EXACT:      foo3

# RUN: echo "VERSION_1.0 { local: foo*; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=WC %s
# WC:  DynamicSymbols [
# WC:      _start
# WC-NOT:  foo1
# WC-NOT:  foo2
# WC-NOT:  foo3

# RUN: echo "VERSION_1.0 { global: *; local: foo*; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=MIX %s
# MIX:  DynamicSymbols [
# MIX:      _start@@VERSION_1.0
# MIX-NOT:  foo1
# MIX-NOT:  foo2
# MIX-NOT:  foo3

.globl foo1
foo1:
  ret

.globl foo2
foo2:
  ret

.globl foo3
foo3:
  ret

.globl _start
_start:
  ret
