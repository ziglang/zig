pub var bss: u32 = undefined;

fn foo() callconv(.c) u32 {
    return bss;
}

comptime {
    @export(&foo, .{ .name = "foo", .visibility = .hidden });
}
