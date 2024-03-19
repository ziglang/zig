const Foo = extern struct {
    derp: i32,
};
export fn foo(a: *i32) *Foo {
    return @fieldParentPtr("a", a);
}

// error
// backend=stage2
// target=native
//
// :5:28: error: no field named 'a' in struct 'tmp.Foo'
// :1:20: note: struct declared here
