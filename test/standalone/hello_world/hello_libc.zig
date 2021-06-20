const c = @cImport({
    // See https://github.com/ziglang/zig/issues/515
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
    @cInclude("string.h");
});

const msg = "Hello, world!\n";

pub export fn main(argc: c_int, argv: **u8) c_int {
    _ = argv;
    _ = argc;
    if (c.printf(msg) != @intCast(c_int, c.strlen(msg))) return -1;
    return 0;
}
