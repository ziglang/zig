const expect = @import("std").testing.expect;

test "@fieldParentPtr non-first field" {
    testParentFieldPtr(&foo.c);
    comptime testParentFieldPtr(&foo.c);
}

test "@fieldParentPtr first field" {
    testParentFieldPtrFirst(&foo.a);
    comptime testParentFieldPtrFirst(&foo.a);
}

const Foo = struct {
    a: bool,
    b: f32,
    c: i32,
    d: i32,
};

const foo = Foo{
    .a = true,
    .b = 0.123,
    .c = 1234,
    .d = -10,
};

fn testParentFieldPtr(c: *const i32) void {
    expect(c == &foo.c);

    const base = @fieldParentPtr(Foo, "c", c);
    expect(base == &foo);
    expect(&base.c == c);
}

fn testParentFieldPtrFirst(a: *const bool) void {
    expect(a == &foo.a);

    const base = @fieldParentPtr(Foo, "a", a);
    expect(base == &foo);
    expect(&base.a == a);
}
