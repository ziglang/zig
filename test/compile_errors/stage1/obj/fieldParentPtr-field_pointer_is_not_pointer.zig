const Foo = extern struct {
    a: i32,
};
export fn foo(a: i32) *Foo {
    return @fieldParentPtr(Foo, "a", a);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:38: error: expected pointer, found 'i32'
