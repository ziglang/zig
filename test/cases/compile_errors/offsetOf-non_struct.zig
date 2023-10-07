const Foo = i32;
export fn foo() usize {
    return @offsetOf(Foo, "a");
}

// error
// backend=stage2
// target=native
//
// :3:22: error: expected struct type, found 'i32'
