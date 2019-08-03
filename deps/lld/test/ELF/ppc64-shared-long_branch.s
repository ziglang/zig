# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld --no-toc-optimize -shared %t.o -o %t
# RUN: llvm-objdump -d -start-address=0x10000 -stop-address=0x10018  %t | FileCheck %s -check-prefix=CALLEE_DUMP
# RUN: llvm-objdump -d -start-address=0x2010020 -stop-address=0x2010070  %t | FileCheck %s -check-prefix=CALLER_DUMP
# RUN: llvm-readelf --sections %t | FileCheck %s -check-prefix=SECTIONS
# RUN: llvm-readelf --relocations %t | FileCheck %s -check-prefix=DYNRELOC


# _start calls protected function callee. Since callee is protected no plt stub
# is needed. The binary however has been padded out with space so that the call
# distance is further then a bl instrution can reach.

        .text
        .abiversion 2
        .protected callee
        .global callee
        .p2align 4
        .type callee,@function
callee:
.Lfunc_gep0:
    addis 2, 12, .TOC.-.Lfunc_gep0@ha
    addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
    .localentry callee, .Lfunc_lep0-.Lfunc_gep0
    addis 4, 2, .LC0@toc@ha
    ld    4, .LC0@toc@l(4)
    lwz   3, 0(4)
    blr

        .space 0x2000000

        .protected _start
        .globl _start
        .p2align 4
        .type _start,@function
_start:
.Lfunc_begin1:
.Lfunc_gep1:
    addis 2, 12, .TOC.-.Lfunc_gep1@ha
    addi 2, 2, .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
    .localentry _start, .Lfunc_lep1-.Lfunc_gep1
    mflr 0
    std  0, 16(1)
    stdu 1, -32(1)
    bl callee
    bl ext_callee
    nop
    addi 1, 1, 32
    ld   0, 16(1)
    mtlr 0

    addis 4, 2, .LC1@toc@ha
    ld    4, .LC1@toc@l(4)
    lwz   4, 0(4)
    add   3, 3, 4
    blr


        .section        .toc,"aw",@progbits
.LC0:
       .tc a[TC],a
.LC1:
       .tc b[TC],b


        .data
        .type a,@object
        .globl a
        .p2align 2
a:
        .long 11
        .size a, 4

        .type b,@object
        .globl b
        .p2align 2
b:
        .long 33
        .size b, 4

# Verify address of the callee
# CALLEE_DUMP: callee:
# CALLEE_DUMP:   10000:  {{.*}}  addis 2, 12, 514
# CALLEE_DUMP:   10004:  {{.*}}  addi 2, 2, -32528
# CALLEE_DUMP:   10008:  {{.*}}  addis 4, 2, 0

# Verify the address of _start, and the call to the long-branch thunk.
# CALLER_DUMP: _start:
# CALLER_DUMP:   2010020:  {{.*}}  addis 2, 12, 2
# CALLER_DUMP:   2010038:  {{.*}}  bl .+56

# Verify the thunks contents: TOC-pointer + offset = .branch_lt[0]
#                             0x20280F0   + 32560  = 0x2030020
# CALLER_DUMP: __long_branch_callee:
# CALLER_DUMP:   2010060:  {{.*}}  addis 12, 2, 0
# CALLER_DUMP:   2010064:  {{.*}}  ld 12, 32560(12)
# CALLER_DUMP:   2010068:  {{.*}}  mtctr 12
# CALLER_DUMP:   201006c:  {{.*}}  bctr

# .got section is at address 0x20300f0 so TOC pointer points to 0x20400F0.
# .plt section has a 2 entry header and a single entry for the long branch.
#            [Nr] Name        Type            Address          Off     Size
# SECTIONS:  [10] .got        PROGBITS        00000000020200f0 20200f0 000008
# SECTIONS:  [13] .plt        NOBITS          0000000002030008 2030008 000018
# SECTIONS:  [14] .branch_lt  NOBITS          0000000002030020 2030008 000008

# There is a relative dynamic relocation for (.plt + 16 bytes), with a base
# address equal to callees local entry point (0x10000 + 8).
# DYNRELOC: Relocation section '.rela.dyn' at offset 0x{{[0-9a-f]+}} contains 3 entries:
# DYNRELOC:    Offset             Info             Type               Symbol's Value
# DYNRELOC:    0000000002030020   0000000000000016 R_PPC64_RELATIVE   10008
