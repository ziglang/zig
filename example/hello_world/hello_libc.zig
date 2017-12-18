const c = @cImport({
    // See https://github.com/zig-lang/zig/issues/515
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
    @cInclude("string.h");
});

comptime {
    @export("main", main);
}

extern fn main(argc: c_int, argv: &&u8) -> c_int {
    const msg = c"Hello, world!\n";

    if (c.printf(msg) != c_int(c.strlen(msg)))
        return -1;

    return 0;
}
