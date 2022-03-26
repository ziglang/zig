const Letter = enum {
    A,
    B,
    C,
};
const Payload = union(Letter) {
    A: i32,
    B: f64,
    C: bool,
    D: bool,
};
export fn entry() void {
    var a = Payload {.A = 1234};
    _ = a;
}

// union enum field does not match enum
//
// tmp.zig:10:5: error: enum field not found: 'D'
// tmp.zig:1:16: note: enum declared here
