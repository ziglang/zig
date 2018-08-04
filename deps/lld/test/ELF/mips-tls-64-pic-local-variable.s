# REQUIRES: mips
# MIPS TLS variables that are marked as local by a version script were previously
# writing values to the GOT that caused runtime crashes. This was happending when
# linking jemalloc_tsd.c in FreeBSD libc. Check that we do the right thing now:

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-freebsd %s -o %t.o
# RUN: echo "{ global: foo; local: *; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-objdump --section=.got -s %t.so | FileCheck %s -check-prefix GOT
# RUN: llvm-readobj -r %t.so | FileCheck %s -check-prefix RELOCS

# GOT:        Contents of section .got:
# GOT-NEXT:   20000 00000000 00000000 80000000 00000000
# GOT-NEXT:   20010 00000000 00000000 00000000 00000000
# GOT-NEXT:   20020 ffffffff ffff8000

# RELOCS:      Section ({{.+}}) .rel.dyn {
# RELOCS-NEXT:  0x20018 R_MIPS_TLS_DTPMOD64/R_MIPS_NONE/R_MIPS_NONE
# RELOCS-NEXT: }

# Test case generated using clang -mcpu=mips4 -target mips64-unknown-freebsd12.0 -fpic -O -G0 -EB -mabi=n64 -msoft-float -std=gnu99 -S %s -o %t.s
# from the following source:
#
# _Thread_local int x;
# int foo() { return x; }
#
        .text
        .globl  foo
        .p2align        3
        .type   foo,@function
        .ent    foo
foo:
        lui     $1, %hi(%neg(%gp_rel(foo)))
        daddu   $1, $1, $25
        daddiu  $gp, $1, %lo(%neg(%gp_rel(foo)))
        ld      $25, %call16(__tls_get_addr)($gp)
        jalr    $25
        daddiu  $4, $gp, %tlsgd(x)
        .end    foo

        .type   x,@object
        .section        .tbss,"awT",@nobits
        .globl  x
        .p2align        2
x:
        .4byte  0
        .size   x, 4


