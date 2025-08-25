const Foo = struct {
    derp: i32,
};
export fn foo() usize {
    return @offsetOf(
        Foo,
        "a",
    );
}

// error
// backend=stage2
// target=native
//
// :7:9: error: no field named 'a' in struct 'tmp.Foo'
// :1:13: note: struct declared here
