const c = @cImport({
    // See https://github.com/ziglang/zig/issues/515
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
});

export fn main(argc: c_int, argv: [*]?[*]u8) c_int {
    c.fprintf(c.stderr, c"Hello, world!\n");
    return 0;
}
