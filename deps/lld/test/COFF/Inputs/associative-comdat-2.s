# Defines foo and foo_assoc globals. foo is comdat, and foo_assoc is comdat
# associative with it. foo_assoc should be discarded iff foo is discarded,
# either by linker GC or normal comdat merging.

        .section        .rdata,"dr",associative,foo
        .p2align        3
        .quad   foo

        .section        .data,"dw",discard,foo
        .globl  foo                     # @foo
        .p2align        2
foo:
        .long   42
