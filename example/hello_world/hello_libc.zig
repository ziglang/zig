const c = @cImport(@cInclude("stdio.h"));

export fn main(argc: c_int, argv: &&u8) -> c_int {
    c.printf(c"Hello, world!\n");
    return 0;
}
