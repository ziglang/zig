const Set1 = error{A, C};
const Set2 = error{B, D};
export fn entry() void {
    foo(Set1.A);
}
fn foo(x: Set1) void {
    if (x == Set2.B) {

    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:11: error: error sets 'Set1' and 'Set2' have no common errors
