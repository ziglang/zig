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

// runtime cast to union which has non-void fields
//
// tmp.zig:11:20: error: runtime cast to union 'Value' which has non-void fields
// tmp.zig:3:5: note: field 'A' has type 'i32'
