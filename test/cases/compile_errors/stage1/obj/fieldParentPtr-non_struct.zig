const Foo = i32;
export fn foo(a: *i32) *Foo {
    return @fieldParentPtr(Foo, "a", a);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:28: error: expected struct type, found 'i32'
