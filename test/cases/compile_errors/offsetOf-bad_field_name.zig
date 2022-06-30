const Foo = struct {
    derp: i32,
};
export fn foo() usize {
    return @offsetOf(Foo, "a",);
}

// error
// backend=stage2
// target=native
//
// :5:27: error: struct 'tmp.Foo' has no field 'a'
// :1:13: note: struct declared here
