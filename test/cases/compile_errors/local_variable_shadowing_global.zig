const Foo = struct {};
const Bar = struct {};

export fn entry() void {
    var Bar: i32 = undefined;
    _ = Bar;
}

// error
//
// :5:9: error: local variable shadows declaration of 'Bar'
// :2:1: note: declared here
