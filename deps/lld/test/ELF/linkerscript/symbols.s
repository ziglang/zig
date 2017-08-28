# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# Simple symbol assignment. Should raise conflict in case we
# have duplicates in any input section, but currently simply
# replaces the value.
# RUN: echo "SECTIONS {.text : {*(.text.*)} text_end = .;}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=SIMPLE %s
# SIMPLE:                               .text    00000000 text_end

# The symbol is not referenced. Don't provide it.
# RUN: echo "SECTIONS { PROVIDE(newsym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=PROVIDE1 %s
# PROVIDE1-NOT: 0000000000000001         *ABS*    00000000 newsym

# The symbol is not referenced. Don't provide it.
# RUN: echo "SECTIONS { PROVIDE_HIDDEN(newsym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN1 %s
# HIDDEN1-NOT: 0000000000000001         *ABS*    00000000 .hidden newsym

# Provide existing symbol. The value should be 0, even though we
# have value of 1 in PROVIDE()
# RUN: echo "SECTIONS { PROVIDE(somesym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=PROVIDE2 %s
# PROVIDE2: 0000000000000000         *ABS*    00000000 somesym

# Provide existing symbol. The value should be 0, even though we
# have value of 1 in PROVIDE_HIDDEN(). Visibility should not change
# RUN: echo "SECTIONS { PROVIDE_HIDDEN(somesym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN2 %s
# HIDDEN2: 0000000000000000         *ABS*    00000000 somesym

# Hidden symbol assignment.
# RUN: echo "SECTIONS { HIDDEN(newsym = 1);}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN3 %s
# HIDDEN3: 0000000000000001         *ABS*    00000000 .hidden newsym

# The symbol is not referenced. Don't provide it.
# RUN: echo "PROVIDE(newsym = 1);" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=PROVIDE4 %s
# PROVIDE4-NOT: 0000000000000001         *ABS*    00000000 newsym

# The symbol is not referenced. Don't provide it.
# RUN: echo "PROVIDE_HIDDEN(newsym = 1);" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN4 %s
# HIDDEN4-NOT: 0000000000000001         *ABS*    00000000 .hidden newsym

# Provide existing symbol. The value should be 0, even though we
# have value of 1 in PROVIDE()
# RUN: echo "PROVIDE(somesym = 1);" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=PROVIDE5 %s
# PROVIDE5: 0000000000000000         *ABS*    00000000 somesym

# Provide existing symbol. The value should be 0, even though we
# have value of 1 in PROVIDE_HIDDEN(). Visibility should not change
# RUN: echo "PROVIDE_HIDDEN(somesym = 1);" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=HIDDEN5 %s
# HIDDEN5: 0000000000000000         *ABS*    00000000 somesym

# Simple symbol assignment. All three symbols should have the
# same value.
# RUN: echo "foo = 0x100; SECTIONS { bar = foo; } baz = bar;" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=SIMPLE2 %s
# SIMPLE2: 0000000000000100         *ABS*    00000000 foo
# SIMPLE2: 0000000000000100         *ABS*    00000000 bar
# SIMPLE2: 0000000000000100         *ABS*    00000000 baz

.global _start
_start:
 nop

.global somesym
somesym = 0
