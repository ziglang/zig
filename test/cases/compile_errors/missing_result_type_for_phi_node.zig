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
// :5:11: note: type 'void' here
// :5:17: note: type 'comptime_int' here
