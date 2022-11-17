var a: u32 = 2;
const b = a;
pub export fn entry() void {
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: unable to resolve comptime value
// :2:11: note: global variable initializer must be comptime-known
