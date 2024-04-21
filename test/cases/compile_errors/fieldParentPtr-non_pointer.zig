const Foo = i32;
export fn foo(a: *i32) Foo {
    return @fieldParentPtr("a", a);
}

// error
// backend=llvm
// target=native
//
// :3:12: error: expected pointer type, found 'i32'
