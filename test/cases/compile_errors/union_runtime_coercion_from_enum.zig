const E = enum {
    a,
    b,
};
const U = union(E) {
    a: u32,
    b: u64,
};
fn foo() E {
    return E.b;
}
export fn doTheTest() u64 {
    var u: U = foo();
    return (&u).b;
}

// error
// target=native
//
// :13:19: error: runtime coercion from enum 'tmp.E' to union 'tmp.U' which has non-void fields
// :6:5: note: field 'a' has type 'u32'
// :7:5: note: field 'b' has type 'u64'
// :5:11: note: union declared here
