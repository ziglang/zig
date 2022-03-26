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
    var a = Payload { .A = 1234 };
    _ = a;
}

// extern union given enum tag type
//
// tmp.zig:6:30: error: extern union does not support enum tag type
