const Foo = extern struct {
    a: i32,
};
export fn foo(a: i32) *Foo {
    return @fieldParentPtr(Foo, "a", a);
}

// error
// backend=stage2
// target=native
//
// :5:38: error: expected pointer type, found 'i32'
