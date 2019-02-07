        .section        .idata$2
        .global         _head_test_lib
_head_test_lib:
        .rva            hname
        .long           0
        .long           0
        .rva            __test_lib_iname
        .rva            fthunk

        .section        .idata$5
fthunk:
        .section        .idata$4
hname:
