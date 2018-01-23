const tests = @import("tests.zig");

pub fn addCases(cases: &tests.GenHContext) {
    cases.add("declare enum",
        \\const Foo = extern enum { A, B, C };
        \\export fn entry(foo: Foo) { }
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
        \\export fn entry(foo: Foo) { }
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
        \\export fn entry(foo: Foo) { }
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
}
