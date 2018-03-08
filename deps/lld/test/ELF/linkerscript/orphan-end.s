# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# Test that .orphan_rx is placed after __stack_end. This matches bfd's
# behavior when the orphan section is the last one.

# RUN: echo "SECTIONS {             \
# RUN:        __start_text = .;     \
# RUN:        .text : { *(.text*) } \
# RUN:        __end_text = .;       \
# RUN:        __stack_start = .;    \
# RUN:        . = . + 0x1000;       \
# RUN:        __stack_end = .;      \
# RUN:      }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S --symbols %t | FileCheck %s

# CHECK-DAG: .text             PROGBITS        0000000000000000
# CHECK-DAG: .orphan_rx        PROGBITS        0000000000001004

# CHECK-DAG: 0000000000000000 {{.*}} __start_text
# CHECK-DAG: 0000000000000004 {{.*}} __end_text
# CHECK-DAG: 0000000000000004 {{.*}} __stack_start
# CHECK-DAG: 0000000000001004 {{.*}} __stack_end

# Test that .orphan_rx is now placed before __stack_end. This matches bfd's
# behavior when the orphan section is not the last one.

# RUN: echo "SECTIONS {             \
# RUN:        __start_text = .;     \
# RUN:        .text : { *(.text*) } \
# RUN:        __end_text = .;       \
# RUN:        __stack_start = .;    \
# RUN:        . = . + 0x1000;       \
# RUN:        __stack_end = .;      \
# RUN:        .orphan_rw : { *(.orphan_rw*) } \
# RUN:      }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S --symbols %t | FileCheck --check-prefix=MIDDLE %s

# MIDDLE-DAG: .text             PROGBITS        0000000000000000
# MIDDLE-DAG: .orphan_rx        PROGBITS        0000000000000004

# MIDDLE-DAG: 0000000000000000 {{.*}} __start_text
# MIDDLE-DAG: 0000000000000004 {{.*}} __end_text
# MIDDLE-DAG: 0000000000000004 {{.*}} __stack_start
# MIDDLE-DAG: 0000000000001008 {{.*}} __stack_end

        .global _start
_start:
        .zero 4

        .section .orphan_rx,"ax"
        .zero 4

        .section .orphan_rw,"aw"
        .zero 4
