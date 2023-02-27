const Foo = i32;
export fn foo(a: *i32) *Foo {
    return @fieldParentPtr(Foo, "a", a);
}

// error
// backend=llvm
// target=native
//
// :3:28: error: expected struct or union type, found 'i32'
