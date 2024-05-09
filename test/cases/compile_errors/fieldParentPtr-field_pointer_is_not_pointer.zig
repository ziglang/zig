const Foo = extern struct {
    a: i32,
};
export fn foo(a: i32) *const Foo {
    return @fieldParentPtr("a", a);
}

// error
// backend=stage2
// target=native
//
// :5:33: error: expected pointer type, found 'i32'
