fn foo(...) void {}
inline fn foo2(...) void {}

comptime {
    _ = foo;
}
comptime {
    _ = foo2;
}

// error
// target=x86_64-linux
//
// :1:8: error: variadic function does not support 'auto' calling convention
// :1:8: note: supported calling conventions: 'x86_64_sysv', 'x86_64_win'
// :2:16: error: variadic function does not support 'inline' calling convention
// :2:16: note: supported calling conventions: 'x86_64_sysv', 'x86_64_win'
