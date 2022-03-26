const Letter = enum {
    A,
    B,
    C,
};
const Payload = packed union(Letter) {
    A: i32,
    B: f64,
    C: bool,
};
export fn entry() void {
    var a = Payload { .A = 1234 };
    _ = a;
}

// packed union given enum tag type
//
// tmp.zig:6:30: error: packed union does not support enum tag type
