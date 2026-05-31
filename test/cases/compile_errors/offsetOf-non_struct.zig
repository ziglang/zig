const Foo = i32;
export fn foo() usize {
    return @offsetOf(Foo, "a");
}

// error
//
// :3:22: error: expected struct type, found 'i32'
