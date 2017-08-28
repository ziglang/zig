# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# Simple symbol assignment within input section list. The '.' symbol
# is not location counter but offset from the beginning of output
# section .foo
# RUN: echo "SECTIONS { \
# RUN:          . = SIZEOF_HEADERS; \
# RUN:          .foo : { \
# RUN:              begin_foo = .; \
# RUN:              PROVIDE(_begin_sec = .); \
# RUN:              *(.foo) \
# RUN:              end_foo = .; \
# RUN:              PROVIDE_HIDDEN(_end_sec = .); \
# RUN:              PROVIDE(_end_sec_abs = ABSOLUTE(.)); \
# RUN:              size_foo_1 = SIZEOF(.foo); \
# RUN:              size_foo_1_abs = ABSOLUTE(SIZEOF(.foo)); \
# RUN:              . = ALIGN(0x1000); \
# RUN:              begin_bar = .; \
# RUN:              *(.bar) \
# RUN:              end_bar = .; \
# RUN:              size_foo_2 = SIZEOF(.foo); } \
# RUN:          size_foo_3 = SIZEOF(.foo); \
# RUN:          .eh_frame_hdr : { \
# RUN:             __eh_frame_hdr_start = .; \
# RUN:             __eh_frame_hdr_start2 = ABSOLUTE(ALIGN(0x10)); \
# RUN:             *(.eh_frame_hdr) \
# RUN:             __eh_frame_hdr_end = .; \
# RUN:             __eh_frame_hdr_end2 = ABSOLUTE(ALIGN(0x10)); } \
# RUN:          .eh_frame : { } \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=SIMPLE %s

# Check that the following script is processed without errors
# RUN: echo "SECTIONS { \
# RUN:          .eh_frame_hdr : { \
# RUN:             PROVIDE_HIDDEN(_begin_sec = .); \
# RUN:             *(.eh_frame_hdr) \
# RUN:             *(.eh_frame_hdr) \
# RUN:             PROVIDE_HIDDEN(_end_sec_abs = ABSOLUTE(.)); \
# RUN:             PROVIDE_HIDDEN(_end_sec = .); } \
# RUN:         }" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t

# Check that we can specify synthetic symbols without defining SECTIONS.
# RUN: echo "PROVIDE_HIDDEN(_begin_sec = _start); \
# RUN:       PROVIDE_HIDDEN(_end_sec = ADDR(.text) + SIZEOF(.text));" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=NO-SEC %s

# Check that we can do the same as above inside SECTIONS block.
# RUN: echo "SECTIONS { \
# RUN:        . = 0x201000; \
# RUN:        .text : { *(.text) } \
# RUN:        PROVIDE_HIDDEN(_begin_sec = ADDR(.text)); \
# RUN:        PROVIDE_HIDDEN(_end_sec = ADDR(.text) + SIZEOF(.text)); }" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=IN-SEC %s

# SIMPLE:      0000000000000128         .foo    00000000 .hidden _end_sec
# SIMPLE-NEXT: 0000000000000120         .foo    00000000 _begin_sec
# SIMPLE-NEXT: 0000000000000128         *ABS*   00000000 _end_sec_abs
# SIMPLE-NEXT: 0000000000001048         .text   00000000 _start
# SIMPLE-NEXT: 0000000000000120         .foo    00000000 begin_foo
# SIMPLE-NEXT: 0000000000000128         .foo    00000000 end_foo
# SIMPLE-NEXT: 0000000000000008         *ABS*   00000000 size_foo_1
# SIMPLE-NEXT: 0000000000000008         *ABS*   00000000 size_foo_1_abs
# SIMPLE-NEXT: 0000000000001000         .foo    00000000 begin_bar
# SIMPLE-NEXT: 0000000000001004         .foo    00000000 end_bar
# SIMPLE-NEXT: 0000000000000ee4         *ABS*   00000000 size_foo_2
# SIMPLE-NEXT: 0000000000000ee4         *ABS*   00000000 size_foo_3
# SIMPLE-NEXT: 0000000000001004         .eh_frame_hdr     00000000 __eh_frame_hdr_start
# SIMPLE-NEXT: 0000000000001010         *ABS*             00000000 __eh_frame_hdr_start2
# SIMPLE-NEXT: 0000000000001018         .eh_frame_hdr     00000000 __eh_frame_hdr_end
# SIMPLE-NEXT: 0000000000001020         *ABS*             00000000 __eh_frame_hdr_end2

# NO-SEC:       0000000000201000         .text     00000000 .hidden _begin_sec
# NO-SEC-NEXT:  0000000000201001         .text     00000000 .hidden _end_sec

# IN-SEC:       0000000000201000         .text     00000000 .hidden _begin_sec
# IN-SEC-NEXT:  0000000000201001         .text     00000000 .hidden _end_sec

.global _start
_start:
 nop

.section .foo,"a"
 .quad 0

.section .bar,"a"
 .long 0

.section .dah,"ax",@progbits
 .cfi_startproc
 nop
 .cfi_endproc

.global _begin_sec, _end_sec, _end_sec_abs
