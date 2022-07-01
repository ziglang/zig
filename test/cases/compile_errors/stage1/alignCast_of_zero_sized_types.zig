export fn foo() void {
    const a: *void = undefined;
    _ = @alignCast(2, a);
}
export fn bar() void {
    const a: ?*void = undefined;
    _ = @alignCast(2, a);
}
export fn baz() void {
    const a: []void = undefined;
    _ = @alignCast(2, a);
}
export fn qux() void {
    const a = struct {
        fn a(comptime b: u32) void { _ = b; }
    }.a;
    _ = @alignCast(2, a);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:23: error: cannot adjust alignment of zero sized type '*void'
// tmp.zig:7:23: error: cannot adjust alignment of zero sized type '?*void'
// tmp.zig:11:23: error: cannot adjust alignment of zero sized type '[]void'
// tmp.zig:17:23: error: cannot adjust alignment of zero sized type 'fn(u32) anytype'
