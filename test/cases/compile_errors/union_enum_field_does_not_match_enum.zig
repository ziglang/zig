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
    const a: Payload = .{ .A = 1234 };
    _ = a;
}

// error
//
// :10:5: error: no field named 'D' in enum 'tmp.Letter'
// :1:16: note: enum declared here
