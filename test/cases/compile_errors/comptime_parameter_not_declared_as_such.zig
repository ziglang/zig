fn f(_: anytype) void {}
fn g(h: *const fn (anytype) void) void {
    h({});
}
pub export fn entry() void {
    g(f);
}

pub fn comptimeMod(num: anytype, denom: comptime_int) void {
    _ = num;
    _ = denom;
}

pub export fn entry1() void {
    _ = comptimeMod(1, 2);
}

// error
// backend=stage2
// target=native
//
// :2:6: error: parameter of type '*const fn(anytype) void' must be declared comptime
// :9:34: error: parameter of type 'comptime_int' must be declared comptime
