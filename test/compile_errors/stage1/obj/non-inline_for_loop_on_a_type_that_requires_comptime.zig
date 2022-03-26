const Foo = struct {
    name: []const u8,
    T: type,
};
export fn entry() void {
    const xx: [2]Foo = undefined;
    for (xx) |f| { _ = f;}
}

// non-inline for loop on a type that requires comptime
//
// tmp.zig:7:5: error: values of type 'Foo' must be comptime known, but index value is runtime known
