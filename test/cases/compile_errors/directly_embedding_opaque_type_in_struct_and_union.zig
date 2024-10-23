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
    _ = &foo;
}
export fn b() void {
    var bar: Bar = undefined;
    _ = &bar;
}
export fn c() void {
    const baz = @as(O, undefined);
    _ = baz;
}
export fn d() void {
    const ptr: *O = @ptrFromInt(0x1000);
    const x = .{ptr.*};
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :3:8: error: opaque types have unknown size and therefore cannot be directly embedded in structs
// :1:11: note: opaque declared here
// :7:10: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// :1:11: note: opaque declared here
// :18:24: error: cannot cast to opaque type 'tmp.O'
// :1:11: note: opaque declared here
// :23:20: error: cannot load opaque type 'tmp.O'
// :1:11: note: opaque declared here
