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

// error
// backend=stage2
// target=native
//
// :10:8: error: no field named 'D' in enum 'tmp.Letter'
// :1:16: note: enum declared here
