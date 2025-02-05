test "type coercion - const qualification" {
    var a: i32 = 1;
    const b: *i32 = &a;
    foo(b);
}

fn foo(_: *const i32) void {}

// test
