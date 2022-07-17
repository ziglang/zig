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
    var x: Value = l;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :11:20: error: runtime coercion from enum 'tmp.Letter' to union 'tmp.Value' which has non-void fields
// :3:5: note: field 'A' has type 'i32'
// :4:5: note: field 'B' has type 'void'
// :5:5: note: field 'C' has type 'void'
// :2:15: note: union declared here
