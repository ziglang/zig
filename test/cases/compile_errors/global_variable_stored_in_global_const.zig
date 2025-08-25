var a: u32 = 2;
const b = a;
pub export fn entry() void {
    _ = b;
}

// error
//
// :2:11: error: unable to resolve comptime value
// :2:11: note: initializer of container-level variable must be comptime-known
