const Set1 = error{ A, B };
const Set2 = error{ A, C };
export fn entry() void {
    foo(Set1.B);
}
fn foo(set1: Set1) void {
    const x: Set2 = set1;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :7:21: error: expected type 'error{C,A}', found 'error{A,B}'
// :7:21: note: 'error.B' not a member of destination error set
