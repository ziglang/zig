// zig fmt: off
const Number = enum {
    a,
    b align(i32),
};
// zig fmt: on

export fn entry1() void {
    const x: Number = undefined;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :4:13: error: enum fields cannot be aligned
