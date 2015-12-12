export executable "structs";

use "std.zig";

export fn main(argc : isize, argv : *mut *mut u8, env : *mut *mut u8) -> i32 {
    let mut foo : Foo;

    foo.a = foo.a + 1;

    foo.b = foo.a == 1;

    test_foo(foo);

    return 0;
}

struct Foo {
    a : i32,
    b : bool,
    c : f32,
}

fn test_foo(foo : Foo) {
    if foo.b {
        print_str("OK");
    }
}
