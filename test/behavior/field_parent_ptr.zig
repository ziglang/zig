const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@fieldParentPtr non-first field" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    try testParentFieldPtr(&foo.c);
    comptime try testParentFieldPtr(&foo.c);
}

test "@fieldParentPtr first field" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
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

test "@fieldParentPtr untagged union" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testFieldParentPtrUnion(&bar.c);
    comptime try testFieldParentPtrUnion(&bar.c);
}

const Bar = union(enum) {
    a: bool,
    b: f32,
    c: i32,
    d: i32,
};

const bar = Bar{ .c = 42 };

fn testFieldParentPtrUnion(c: *const i32) !void {
    try expect(c == &bar.c);

    const base = @fieldParentPtr(Bar, "c", c);
    try expect(base == &bar);
    try expect(&base.c == c);
}

test "@fieldParentPtr tagged union" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testFieldParentPtrTaggedUnion(&bar_tagged.c);
    comptime try testFieldParentPtrTaggedUnion(&bar_tagged.c);
}

const BarTagged = union(enum) {
    a: bool,
    b: f32,
    c: i32,
    d: i32,
};

const bar_tagged = BarTagged{ .c = 42 };

fn testFieldParentPtrTaggedUnion(c: *const i32) !void {
    try expect(c == &bar_tagged.c);

    const base = @fieldParentPtr(BarTagged, "c", c);
    try expect(base == &bar_tagged);
    try expect(&base.c == c);
}

test "@fieldParentPtr extern union" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testFieldParentPtrExternUnion(&bar_extern.c);
    comptime try testFieldParentPtrExternUnion(&bar_extern.c);
}

const BarExtern = extern union {
    a: bool,
    b: f32,
    c: i32,
    d: i32,
};

const bar_extern = BarExtern{ .c = 42 };

fn testFieldParentPtrExternUnion(c: *const i32) !void {
    try expect(c == &bar_extern.c);

    const base = @fieldParentPtr(BarExtern, "c", c);
    try expect(base == &bar_extern);
    try expect(&base.c == c);
}
