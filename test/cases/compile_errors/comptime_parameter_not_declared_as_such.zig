fn f(_: anytype) void {}
const T = *const fn (anytype) void;
fn g(h: T) void {
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
// :3:6: error: parameter of type '*const fn(anytype) void' must be declared comptime
// :10:34: error: parameter of type 'comptime_int' must be declared comptime
