const expect = @import("std").testing.expect;

test "@fieldParentPtr non-first field" {
    try testParentFieldPtr(&foo.c);
    comptime try testParentFieldPtr(&foo.c);
}

test "@fieldParentPtr first field" {
    try testParentFieldPtrFirst(&foo.a);
    comptime try testParentFieldPtrFirst(&foo.a);
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

fn testParentFieldPtr(c: *const i32) !void {
    try expect(c == &foo.c);

    const base = @fieldParentPtr(Foo, "c", c);
    try expect(base == &foo);
    try expect(&base.c == c);
}

fn testParentFieldPtrFirst(a: *const bool) !void {
    try expect(a == &foo.a);

    const base = @fieldParentPtr(Foo, "a", a);
    try expect(base == &foo);
    try expect(&base.a == a);
}
