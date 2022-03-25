const Foobar = struct {
    myTypes: [128]type,
    str: [1024]u8,

    fn foo() @This() {
        comptime var foobar: Foobar = undefined;
        foobar.str = [_]u8{'a'} ** 1024;
        return foobar;
    }
};

fn foo(arg: anytype) void {
    _ = arg;
}

test {
    if (@import("builtin").zig_backend != .stage1) return error.SkipZigTest; // TODO

    comptime var foobar = Foobar.foo();
    foo(foobar.str[0..10]);
}
