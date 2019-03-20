        .global         __imp_data

        # The data that is emitted into .idata$7 here is isn't needed for
        # the import data structures, but we need to emit something which
        # produces a relocation against _head_test_lib, to pull in the
        # header and trailer objects.

        .section        .idata$7
        .rva            _head_test_lib

        .section        .idata$5
__imp_data:
        .rva            .Lhint_name
        .long           0

        .section        .idata$4
        .rva            .Lhint_name
        .long           0

        .section        .idata$6
.Lhint_name:
        .short          0
        .asciz          "data"
