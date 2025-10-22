export fn foo() void {
    const S = struct {
        f: u8,
    };
    _ = @as([@sizeOf(S)]u8, @bitCast([1]S{undefined}));
}

export fn bar() void {
    const S = struct {
        f: u8,
    };
    _ = @as([1]S, @bitCast(@as([@sizeOf(S)]u8, undefined)));
}

export fn baz() void {
    _ = @as([1]u32, @bitCast([1]comptime_int{0}));
}

// error
//
// :5:29: error: cannot @bitCast from '[1]tmp.foo.S'
// :5:29: note: array element type 'tmp.foo.S' does not have a guaranteed in-memory layout
// :12:19: error: cannot @bitCast to '[1]tmp.bar.S'
// :12:19: note: array element type 'tmp.bar.S' does not have a guaranteed in-memory layout
// :16:21: error: cannot @bitCast from '[1]comptime_int'
// :16:21: note: array element type 'comptime_int' does not have a guaranteed in-memory layout
