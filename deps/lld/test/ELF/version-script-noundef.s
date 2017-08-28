# REQUIRES: x86

# RUN: echo "VERSION_1.0 { global: bar; };" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld --version-script %t.script -shared --no-undefined-version \
# RUN:   %t.o -o %t.so 2>&1 | FileCheck -check-prefix=ERR1 %s
# ERR1: version script assignment of 'VERSION_1.0' to symbol 'bar' failed: symbol not defined

# RUN: echo "VERSION_1.0 { global: und; };" > %t2.script
# RUN: not ld.lld --version-script %t2.script -shared --no-undefined-version \
# RUN:   %t.o -o %t.so 2>&1 | FileCheck -check-prefix=ERR2 %s
# ERR2: version script assignment of 'VERSION_1.0' to symbol 'und' failed: symbol not defined

# RUN: echo "VERSION_1.0 { local: und; };" > %t3.script
# RUN: not ld.lld --version-script %t3.script -shared --no-undefined-version \
# RUN:   %t.o -o %t.so 2>&1 | FileCheck -check-prefix=ERR3 %s
# ERR3: version script assignment of 'local' to symbol 'und' failed: symbol not defined

.text
.globl foo
.type foo,@function
foo:
callq und@PLT
