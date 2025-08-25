pub export fn entry() void {
    _ = foo();
}
const A = struct {
    a: u32,
};
fn foo() A {
    return bar();
}
const B = struct {
    a: u32,
};
fn bar() B {
    unreachable;
}

// error
// backend=stage2
// target=native
//
// :8:15: error: expected type 'tmp.A', found 'tmp.B'
// :10:11: note: struct declared here
// :4:11: note: struct declared here
// :7:10: note: function return type declared here
