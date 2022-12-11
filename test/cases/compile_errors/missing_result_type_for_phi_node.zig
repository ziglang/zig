fn foo() !void {
    return anyerror.Foo;
}
export fn entry() void {
    foo() catch 0;
}

// error
// backend=stage2
// target=native
//
// :5:11: error: incompatible types: 'void' and 'comptime_int'
