const Foo = packed struct(u32) {
    x: u1,
};
fn bar(_: Foo) callconv(.C) void {}
pub export fn entry() void {
    bar(.{ .x = 0 });
}

// error
// backend=stage2
// target=native
//
// :1:27: error: backing integer type 'u32' has bit size 32 but the struct fields have a total bit size of 1
