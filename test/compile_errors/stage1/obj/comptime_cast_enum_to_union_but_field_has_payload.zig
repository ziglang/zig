const Letter = enum { A, B, C };
const Value = union(Letter) {
    A: i32,
    B,
    C,
};
export fn entry() void {
    var x: Value = Letter.A;
    _ = x;
}

// comptime cast enum to union but field has payload
//
// tmp.zig:8:26: error: cast to union 'Value' must initialize 'i32' field 'A'
// tmp.zig:3:5: note: field 'A' declared here
