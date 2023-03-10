const O = opaque {};
const Foo = struct {
    o: O,
};
const Bar = union {
    One: i32,
    Two: O,
};
export fn a() void {
    var foo: Foo = undefined;
    _ = foo;
}
export fn b() void {
    var bar: Bar = undefined;
    _ = bar;
}
export fn c() void {
    const baz = &@as(opaque {}, undefined);
    const qux = .{baz.*};
    _ = qux;
}
export fn d() void {
    const baz = &@as(opaque {}, undefined);
    const qux = .{ .a = baz.* };
    _ = qux;
}

// error
// backend=stage2
// target=native
//
// :3:8: error: opaque types have unknown size and therefore cannot be directly embedded in structs
// :1:11: note: opaque declared here
// :7:10: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// :1:11: note: opaque declared here
// :19:18: error: opaque types have unknown size and therefore cannot be directly embedded in structs
// :18:22: note: opaque declared here
// :24:23: error: opaque types have unknown size and therefore cannot be directly embedded in structs
// :23:22: note: opaque declared here
