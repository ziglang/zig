fn f(b: bool) void {
    const x: i32 = if (b) h: {
        break :h 1;
    };
    _ = x;
}
fn g(b: bool) void {
    const y = if (b) h: {
        break :h @as(i32, 1);
    };
    _ = y;
}
fn h() void {
    // https://github.com/ziglang/zig/issues/12743
    const T = struct { oh_no: *u32 };
    var x: T = if (false) {};
    _ = &x;
}
fn k(b: bool) void {
    // block_ptr case
    const T = struct { oh_no: u32 };
    var x = if (b) blk: {
        break :blk if (false) T{ .oh_no = 2 };
    } else T{ .oh_no = 1 };
    _ = &x;
}
export fn entry() void {
    f(true);
    g(true);
    h();
    k(true);
}
// error
// backend=stage2
// target=native
//
// :2:20: error: expected type 'i32', found 'void'
// :8:15: error: incompatible types: 'i32' and 'void'
// :8:25: note: type 'i32' here
// :16:16: error: expected type 'tmp.h.T', found 'void'
// :15:15: note: struct declared here
// :22:13: error: incompatible types: 'void' and 'tmp.k.T'
// :22:25: note: type 'void' here
// :24:13: note: type 'tmp.k.T' here
