const x: i32 = 42;
export fn foo() i32 {
    return x;
}
comptime {
    @export(foo, .{ .name = "bar", .linkage = .Strong });
}
