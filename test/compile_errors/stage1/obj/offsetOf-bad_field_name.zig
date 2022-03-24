const Foo = struct {
    derp: i32,
};
export fn foo() usize {
    return @offsetOf(Foo, "a",);
}

// @offsetOf - bad field name
//
// tmp.zig:5:27: error: struct 'Foo' has no field 'a'
