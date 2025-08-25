const Letter = enum {
    A,
    B,
    C,
};
const Payload = extern union(Letter) {
    A: i32,
    B: f64,
    C: bool,
};
export fn entry() void {
    const a: Payload = .{ .A = 1234 };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :6:30: error: extern union does not support enum tag type
