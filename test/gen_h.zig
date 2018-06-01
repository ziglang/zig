const tests = @import("tests.zig");

pub fn addCases(cases: *tests.GenHContext) void {
    cases.add("declare enum",
        \\const Foo = extern enum { A, B, C };
        \\export fn entry(foo: Foo) void { }
    ,
        \\enum Foo {
        \\    A = 0,
        \\    B = 1,
        \\    C = 2
        \\};
        \\
        \\TEST_EXPORT void entry(enum Foo foo);
        \\
    );

    cases.add("declare struct",
        \\const Foo = extern struct {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\};
        \\export fn entry(foo: Foo) void { }
    ,
        \\struct Foo {
        \\    int32_t A;
        \\    float B;
        \\    bool C;
        \\};
        \\
        \\TEST_EXPORT void entry(struct Foo foo);
        \\
    );

    cases.add("declare union",
        \\const Foo = extern union {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\};
        \\export fn entry(foo: Foo) void { }
    ,
        \\union Foo {
        \\    int32_t A;
        \\    float B;
        \\    bool C;
        \\};
        \\
        \\TEST_EXPORT void entry(union Foo foo);
        \\
    );

    cases.add("declare opaque type",
        \\export const Foo = @OpaqueType();
        \\
        \\export fn entry(foo: ?*Foo) void { }
    ,
        \\struct Foo;
        \\
        \\TEST_EXPORT void entry(struct Foo * foo);
    );

    cases.add("array field-type",
        \\const Foo = extern struct {
        \\    A: [2]i32,
        \\    B: [4]*u32,
        \\};
        \\export fn entry(foo: Foo, bar: [3]u8) void { }
    ,
        \\struct Foo {
        \\    int32_t A[2];
        \\    uint32_t * B[4];
        \\};
        \\
        \\TEST_EXPORT void entry(struct Foo foo, uint8_t bar[]);
        \\
    );
}
