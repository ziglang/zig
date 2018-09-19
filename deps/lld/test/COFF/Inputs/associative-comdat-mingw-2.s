        .section        .xdata$foo,"dr"
        .linkonce       discard
        .p2align        3
        .long           42

        .section        .xdata$bar,"dr"
        .linkonce       discard
        .p2align        3
        .long           43

        .section        .xdata$baz,"dr"
        .linkonce       discard
        .p2align        3
        .long           44

        .def            foo;
        .scl            2;
        .type           32;
        .endef
        .section        .text$foo,"xr",discard,foo
        .globl          foo
        .p2align        4
foo:
        ret

        .def            bar;
        .scl            2;
        .type           32;
        .endef
        .section        .text$bar,"xr",discard,bar
        .globl          bar
        .p2align        4
bar:
        ret
