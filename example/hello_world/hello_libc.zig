#link("c")
export executable "hello";

c_import {
    @c_include("stdio.h");
}

export fn main(argc: c_int, argv: &&u8) -> c_int {
    printf(c"Hello, world!\n");
    return 0;
}
