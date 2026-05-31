extern fn printf(format: [*:0]const u8, ...) c_int;
extern fn strlen(str: [*:0]const u8) usize;

const msg = "Hello, world!\n";

pub export fn main(argc: c_int, argv: **u8) c_int {
    _ = argv;
    _ = argc;
    if (printf(msg) != @as(c_int, @intCast(strlen(msg)))) return -1;
    return 0;
}
