const Foo = i32;
export fn foo(a: *i32) Foo {
    return @fieldParentPtr("a", a);
}

// error
//
// :3:12: error: expected pointer type, found 'i32'
