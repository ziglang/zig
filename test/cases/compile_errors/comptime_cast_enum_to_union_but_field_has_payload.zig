const Letter = enum { A, B, C };
const Value = union(Letter) {
    A: i32,
    B,
    C,
};
export fn entry() void {
    var x: Value = Letter.A;
    _ = &x;
}

// error
// backend=stage2
// target=native
//
// :8:26: error: coercion from enum 'tmp.Letter' to union 'tmp.Value' must initialize 'i32' field 'A'
// :3:5: note: field 'A' declared here
// :2:15: note: union declared here
