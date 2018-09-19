# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-tls.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t3.so
# RUN: ld.lld  %t.o %t3.so -o %t
# RUN: llvm-objdump --section-headers %t | FileCheck --check-prefix=CheckGot %s
# RUN: llvm-objdump -D %t | FileCheck --check-prefix=Dis %s
# RUN: llvm-readelf -relocations --wide %t | FileCheck --check-prefix=OutputRelocs %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-tls.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t3.so
# RUN: ld.lld  %t.o %t3.so -o %t
# RUN: llvm-objdump --section-headers %t | FileCheck --check-prefix=CheckGot %s
# RUN: llvm-objdump -D %t | FileCheck --check-prefix=Dis %s
# RUN: llvm-readelf -relocations --wide %t | FileCheck --check-prefix=OutputRelocs %s

        .text
        .abiversion 2
        .globl _start
        .p2align        4
        .type   _start,@function
_start:
.Lfunc_gep0:
        addis 2, 12, .TOC.-.Lfunc_gep0@ha
        addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
        .localentry     _start, .Lfunc_lep0-.Lfunc_gep0
        mflr 0
        std 0, 16(1)
        stdu 1, -32(1)
        addis 3, 2, a@got@tlsgd@ha
        addi 3, 3, a@got@tlsgd@l
        bl __tls_get_addr(a@tlsgd)
        nop
        lwa 3, 0(3)
        addi 1, 1, 32
        ld 0, 16(1)
        mtlr 0
        blr


        .globl other_reg
        .p2align        4
        .type   other_reg,@function
other_reg:
.Lfunc_gep1:
        addis 2, 12, .TOC.-.Lfunc_gep1@ha
        addi 2, 2, .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
        .localentry     other_reg, .Lfunc_lep1-.Lfunc_gep1
        mflr 0
        std 0, 16(1)
        stdu 1, -32(1)
        addis 5, 2, a@got@tlsgd@ha
        addi 3, 5, a@got@tlsgd@l
        bl __tls_get_addr(a@tlsgd)
        nop
        lwa 4, 0(3)
        addis 30, 2, b@got@tlsgd@ha
        addi 3, 30, b@got@tlsgd@l
        bl __tls_get_addr(b@tlsgd)
        nop
        lwa 3, 0(3)
        add 3, 4, 3
        addi 1, 1, 32
        ld 0, 16(1)
        mtlr 0
        blr

        .globl __tls_get_addr
        .type __tls_get_addr,@function
__tls_get_addr:


# CheckGot: .got          00000018 00000000100200c0 DATA
# .got is at 0x100200c0 so the toc-base is 100280c0.
# `a` is at .got[1], we expect the offsets to be:
# Ha(a) = ((0x100200c8  - 0x100280c0) + 0x8000) >> 16 = 0
# Lo(a) = (0x100200c8  - 0x100280c0) = -32760

# Dis-LABEL: _start
# Dis:         addis 3, 2, 0
# Dis-NEXT:    ld 3, -32760(3)
# Dis-NEXT:    nop
# Dis-NEXT:    add 3, 3, 13

# Dis-LABEL: other_reg
# Dis:         addis 5, 2, 0
# Dis-NEXT:    ld 3, -32760(5)
# Dis-NEXT:    nop
# Dis-NEXT:    add 3, 3, 13
# Dis:         addis 30, 2, 0
# Dis:         ld 3, -32752(30)
# Dis-NEXT:    nop
# Dis-NEXT:    add 3, 3, 13

# Verify that the only dynamic relocations we emit are TPREL ones rather then
# the DTPMOD64/DTPREL64 pair for general-dynamic.
# OutputRelocs: Relocation section '.rela.dyn' at offset 0x{{[0-9a-f]+}} contains 2 entries:
# OutputRelocs-NEXT:    Offset             Info             Type               Symbol's Value  Symbol's Name + Addend
# OutputRelocs-NEXT:  {{[0-9a-f]+}}    {{[0-9a-f]+}}   R_PPC64_TPREL64        {{[0-9a-f]+}} a + 0
# OutputRelocs-NEXT:  {{[0-9a-f]+}}    {{[0-9a-f]+}}   R_PPC64_TPREL64        {{[0-9a-f]+}} b + 0
