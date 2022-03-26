pub fn main() void {
    var foo = true;
    _ = foo;
}
fn foo() void {}

// local shadows global that occurs later
//
// tmp.zig:2:9: error: local shadows declaration of 'foo'
// tmp.zig:5:1: note: declared here
