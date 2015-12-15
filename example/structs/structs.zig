export executable "structs";

use "std.zig";

export fn main(argc : isize, argv : &&u8, env : &&u8) -> i32 {
    var foo : Foo;

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
        print_str("OK\n" as string);
    }
}
