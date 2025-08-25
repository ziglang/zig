const Letter = enum { A, B, C };
const Value = union(Letter) {
    A: i32,
    B,
    C,
};
export fn entry() void {
    foo(Letter.A);
}
fn foo(l: Letter) void {
    const x: Value = l;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :11:22: error: runtime coercion from enum 'tmp.Letter' to union 'tmp.Value' which has non-void fields
// :3:5: note: field 'A' has type 'i32'
// :2:15: note: union declared here
