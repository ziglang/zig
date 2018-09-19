# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "bar = foo; VERSION { V { global: foo; bar; local: *; }; }" > %t.script
# RUN: ld.lld -T %t.script -shared --no-undefined-version %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s

# RUN: echo "SECTIONS { .text : { bar = foo; *(.text) } }" > %t.script
# RUN: echo "VERSION { V { global: foo; bar; local: *; }; }" >> %t.script
# RUN: ld.lld -T %t.script -shared --no-undefined-version %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s

## Check that we are able to version symbols defined in script.
# CHECK:      Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name: @
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name: und@
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 2
# CHECK-NEXT:     Name: foo@@V
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 2
# CHECK-NEXT:     Name: bar@@V
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# RUN: echo "bar = und; VERSION { V { global: foo; bar; local: *; }; }" > %t.script
# RUN: not ld.lld -T %t.script -shared --no-undefined-version %t.o -o %t.so \
# RUN:   2>&1 | FileCheck --check-prefix=ERR %s
# ERR: symbol not found: und

# RUN: echo "und = 0x1; VERSION { V { global: und; local: *; }; }" > %t.script
# RUN: ld.lld -T %t.script -shared --no-undefined-version %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s --check-prefix=UNDEF
# UNDEF:      Symbols [
# UNDEF-NEXT:   Symbol {
# UNDEF-NEXT:     Version: 0
# UNDEF-NEXT:     Name: @
# UNDEF-NEXT:   }
# UNDEF-NEXT:   Symbol {
# UNDEF-NEXT:     Version: 2
# UNDEF-NEXT:     Name: und@@V
# UNDEF-NEXT:   }
# UNDEF-NEXT: ]

.global und

.text
.globl foo
.type foo,@function
foo:
