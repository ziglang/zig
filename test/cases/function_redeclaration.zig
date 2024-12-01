// dummy comment
fn entry() void {}
fn entry() void {}

fn foo() void {
    var foo = 1234;
}

// error
//
// :2:4: error: duplicate struct member name 'entry'
// :3:4: note: duplicate name here
// :2:1: note: struct declared here
// :6:9: error: local variable shadows declaration of 'foo'
// :5:1: note: declared here
