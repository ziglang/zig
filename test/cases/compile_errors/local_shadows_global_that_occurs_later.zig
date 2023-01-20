pub fn main() void {
    var foo = true;
    _ = foo;
}
fn foo() void {}

// error
// backend=stage2
// target=native
//
// :2:9: error: local variable shadows declaration of 'foo'
// :5:1: note: declared here
