# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Check simple RAM-only memory region.

# RUN: echo "MEMORY { ram (rwx) : ORIGIN = 0x8000, LENGTH = 256K } \
# RUN: SECTIONS { \
# RUN:   .text : { *(.text) } > ram \
# RUN:   .data : { *(.data) } > ram \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck -check-prefix=RAM %s

# RAM:       1 .text         00000001 0000000000008000 TEXT
# RAM-NEXT:  2 .data         00001000 0000000000008001 DATA

## Check RAM and ROM memory regions.

# RUN: echo "MEMORY { \
# RUN:   ram (rwx) : ORIGIN = 0, LENGTH = 1024M \
# RUN:   rom (rx) : org = (0x80 * 0x1000 * 0x1000), len = 64M \
# RUN: } \
# RUN: SECTIONS { \
# RUN:   .text : { *(.text) } >rom \
# RUN:   .data : { *(.data) } >ram \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck -check-prefix=RAMROM %s

# RAMROM:       1 .text         00000001 0000000080000000 TEXT
# RAMROM-NEXT:  2 .data         00001000 0000000000000000 DATA

## Check memory region placement by attributes.

# RUN: echo "MEMORY { \
# RUN:   ram (!rx) : ORIGIN = 0, LENGTH = 1024M \
# RUN:   rom (rx) : o = 0x80000000, l = 64M \
# RUN: } \
# RUN: SECTIONS { \
# RUN:   .text : { *(.text) } \
# RUN:   .data : { *(.data) } > ram \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck -check-prefix=ATTRS %s

# ATTRS:  1 .text         00000001 0000000080000000 TEXT
# ATTRS:  2 .data         00001000 0000000000000000 DATA

## Check bad `ORIGIN`.

# RUN: echo "MEMORY { ram (rwx) : XYZ = 0x8000 } }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR1 %s
# ERR1: {{.*}}.script:1: expected one of: ORIGIN, org, or o

## Check bad `LENGTH`.

# RUN: echo "MEMORY { ram (rwx) : ORIGIN = 0x8000, XYZ = 256K } }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR2 %s
# ERR2: {{.*}}.script:1: expected one of: LENGTH, len, or l

## Check duplicate regions.

# RUN: echo "MEMORY { ram (rwx) : o = 8, l = 256K ram (rx) : o = 0, l = 256K }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR3 %s
# ERR3: {{.*}}.script:1: region 'ram' already defined

## Check no region available.

# RUN: echo "MEMORY { ram (!rx) : ORIGIN = 0x8000, LENGTH = 256K } \
# RUN: SECTIONS { \
# RUN:   .text : { *(.text) } \
# RUN:   .data : { *(.data) } > ram \
# RUN: }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR4 %s
# ERR4: {{.*}}: no memory region specified for section '.text'

## Check undeclared region.

# RUN: echo "SECTIONS { .text : { *(.text) } > ram }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR5 %s
# ERR5: {{.*}}: memory region 'ram' not declared

## Check region overflow.

# RUN: echo "MEMORY { ram (rwx) : ORIGIN = 0, LENGTH = 2K } \
# RUN: SECTIONS { \
# RUN:   .text : { *(.text) } > ram \
# RUN:   .data : { *(.data) } > ram \
# RUN: }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR6 %s
# ERR6: {{.*}}: section '.data' will not fit in region 'ram': overflowed by 2049 bytes

## Check invalid region attributes.

# RUN: echo "MEMORY { ram (abc) : ORIGIN = 8000, LENGTH = 256K } }" > %t.script
# RUN: not ld.lld -o %t2 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR7 %s
# ERR7: {{.*}}.script:1: invalid memory region attribute

.text
.global _start
_start:
  nop

.data
b:
  .long 1
  .zero 4092
