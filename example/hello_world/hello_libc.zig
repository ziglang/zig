const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("string.h");
});

const msg = c"Hello, world!\n";

export fn main(argc: c_int, argv: &&u8) -> c_int {
    if (c.printf(msg) != c_int(c.strlen(msg)))
        return -1;

    return 0;
}
