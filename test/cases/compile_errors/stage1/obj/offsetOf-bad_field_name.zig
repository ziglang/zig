const Foo = struct {
    derp: i32,
};
export fn foo() usize {
    return @offsetOf(Foo, "a",);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:27: error: struct 'Foo' has no field 'a'
