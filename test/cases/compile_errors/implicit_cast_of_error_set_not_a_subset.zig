const Set1 = error{A, B};
const Set2 = error{A, C};
export fn entry() void {
    foo(Set1.B);
}
fn foo(set1: Set1) void {
    var x: Set2 = set1;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :7:19: error: expected type 'error{A,C}', found 'error{A,B}'
// :7:19: note: 'error.B' not a member of destination error set
