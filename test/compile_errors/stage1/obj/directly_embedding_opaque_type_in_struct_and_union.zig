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
    var baz: *opaque {} = undefined;
    const qux = .{baz.*};
    _ = qux;
}

// directly embedding opaque type in struct and union
//
// tmp.zig:3:5: error: opaque types have unknown size and therefore cannot be directly embedded in structs
// tmp.zig:7:5: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// tmp.zig:19:22: error: opaque types have unknown size and therefore cannot be directly embedded in structs
