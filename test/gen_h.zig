const tests = @import("tests.zig");

pub fn addCases(cases: *tests.GenHContext) void {
    cases.add("declare enum",
        \\const Foo = extern enum { A, B, C };
        \\export fn entry(foo: Foo) void { }
    , &[_][]const u8{
        \\enum Foo {
        \\    A = 0,
        \\    B = 1,
        \\    C = 2
        \\};
    ,
        \\void entry(enum Foo foo);
    });

    cases.add("declare struct",
        \\const Foo = extern struct {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\    D: u64,
        \\    E: u64,
        \\    F: u64,
        \\};
        \\export fn entry(foo: Foo) void { }
    , &[_][]const u8{
        \\struct Foo {
        \\    int32_t A;
        \\    float B;
        \\    bool C;
        \\    uint64_t D;
        \\    uint64_t E;
        \\    uint64_t F;
        \\};
    ,
        \\void entry(struct Foo foo);
        \\
    });

    cases.add("declare union",
        \\const Big = extern struct {
        \\    A: u64,
        \\    B: u64,
        \\    C: u64,
        \\    D: u64,
        \\    E: u64,
        \\};
        \\const Foo = extern union {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\    D: Big,
        \\};
        \\export fn entry(foo: Foo) void {}
    , &[_][]const u8{
        \\struct Big {
        \\    uint64_t A;
        \\    uint64_t B;
        \\    uint64_t C;
        \\    uint64_t D;
        \\    uint64_t E;
        \\};
        \\
        \\union Foo {
        \\    int32_t A;
        \\    float B;
        \\    bool C;
        \\    struct Big D;
        \\};
    ,
        \\void entry(union Foo foo);
        \\
    });

    cases.add("declare opaque type",
        \\const Foo = opaque {};
        \\
        \\export fn entry(foo: ?*Foo) void { }
    , &[_][]const u8{
        \\struct Foo;
    ,
        \\void entry(struct Foo * foo);
    });

    cases.add("array field-type",
        \\const Foo = extern struct {
        \\    A: [2]i32,
        \\    B: [4]*u32,
        \\};
        \\export fn entry(foo: Foo, bar: [3]u8) void { }
    , &[_][]const u8{
        \\struct Foo {
        \\    int32_t A[2];
        \\    uint32_t * B[4];
        \\};
    ,
        \\void entry(struct Foo foo, uint8_t bar[]);
        \\
    });

    cases.add("ptr to zig struct",
        \\const S = struct {
        \\    a: u8,
        \\};
        \\
        \\export fn a(s: *S) u8 {
        \\    return s.a;
        \\}
    , &[_][]const u8{
        \\struct S;
    ,
        \\uint8_t a(struct S * s);
        \\
    });

    cases.add("ptr to zig union",
        \\const U = union(enum) {
        \\    A: u8,
        \\    B: u16,
        \\};
        \\
        \\export fn a(s: *U) u8 {
        \\    return s.A;
        \\}
    , &[_][]const u8{
        \\union U;
    ,
        \\uint8_t a(union U * s);
        \\
    });

    cases.add("ptr to zig enum",
        \\const E = enum(u8) {
        \\    A,
        \\    B,
        \\};
        \\
        \\export fn a(s: *E) u8 {
        \\    return @enumToInt(s.*);
        \\}
    , &[_][]const u8{
        \\enum E;
    ,
        \\uint8_t a(enum E * s);
        \\
    });
}
