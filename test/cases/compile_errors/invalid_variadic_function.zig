fn foo(...) void {}
fn bar(a: anytype, ...) callconv(a) void {}

comptime { _ = foo; }
comptime { _ = bar; }

// error
// backend=stage2
// target=native
//
// :1:1: error: variadic function must have 'C' calling convention
// :2:1: error: generic function cannot be variadic
