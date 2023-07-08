fn foo(...) void {}
fn bar(a: anytype, ...) callconv(a) void {}
inline fn foo2(...) void {}

comptime {
    _ = foo;
}
comptime {
    _ = bar;
}
comptime {
    _ = foo2;
}

// error
// backend=stage2
// target=native
//
// :1:1: error: variadic function does not support '.Unspecified' calling convention
// :1:1: note: supported calling conventions: '.C'
// :2:1: error: generic function cannot be variadic
// :1:1: error: variadic function does not support '.Inline' calling convention
// :1:1: note: supported calling conventions: '.C'
