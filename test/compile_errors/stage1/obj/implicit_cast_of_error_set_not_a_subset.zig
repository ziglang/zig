const Set1 = error{A, B};
const Set2 = error{A, C};
export fn entry() void {
    foo(Set1.B);
}
fn foo(set1: Set1) void {
    var x: Set2 = set1;
    _ = x;
}

// implicit cast of error set not a subset
//
// tmp.zig:7:19: error: expected type 'Set2', found 'Set1'
// tmp.zig:1:23: note: 'error.B' not a member of destination error set
