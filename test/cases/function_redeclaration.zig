// dummy comment
fn entry() void {}
fn entry() void {}

fn foo() void {
    var foo = 1234;
}

// error
//
// :3:1: error: redeclaration of 'entry'
// :2:1: note: other declaration here
// :6:9: error: local variable shadows declaration of 'foo'
// :5:1: note: declared here
