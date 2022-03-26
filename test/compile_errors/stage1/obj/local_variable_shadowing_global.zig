const Foo = struct {};
const Bar = struct {};

export fn entry() void {
    var Bar : i32 = undefined;
    _ = Bar;
}

// local variable shadowing global
//
// tmp.zig:5:9: error: local shadows declaration of 'Bar'
// tmp.zig:2:1: note: declared here
