const expect = @import("std").testing.expect;
const builtin = @import("builtin");

const FILE = extern struct {
    dummy_field: u8,
};

extern fn printf([*c]const u8, ...) c_int;
extern fn fputs([*c]const u8, noalias [*c]FILE) c_int;
extern fn ftell([*c]FILE) c_long;
extern fn fopen([*c]const u8, [*c]const u8) [*c]FILE;

const S = extern struct {
    state: c_short,

    extern fn s_do_thing([*c]const S, b: c_int) c_short;
};

test "Extern function calls in @TypeOf" {
    const Test = struct {
        fn test_fn_1(a: anytype, b: anytype) @TypeOf(printf("%d %s\n", a, b)) {
            return 0;
        }

        fn test_fn_2(s: anytype, a: anytype) @TypeOf(s.s_do_thing(a)) {
            return 1;
        }

        fn doTheTest() !void {
            try expect(@TypeOf(test_fn_1(0, 42)) == c_int);
            try expect(@TypeOf(test_fn_2(&S{ .state = 1 }, 0)) == c_short);
        }
    };

    try Test.doTheTest();
    comptime try Test.doTheTest();
}

test "Peer resolution of extern function calls in @TypeOf" {
    const Test = struct {
        fn test_fn() @TypeOf(ftell(null), fputs(null, null)) {
            return 0;
        }

        fn doTheTest() !void {
            try expect(@TypeOf(test_fn()) == c_long);
        }
    };

    try Test.doTheTest();
    comptime try Test.doTheTest();
}

test "Extern function calls, dereferences and field access in @TypeOf" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const Test = struct {
        fn test_fn_1(a: c_long) @TypeOf(fopen("test", "r").*) {
            _ = a;
            return .{ .dummy_field = 0 };
        }

        fn test_fn_2(a: anytype) @TypeOf(fopen("test", "r").*.dummy_field) {
            _ = a;
            return 255;
        }

        fn doTheTest() !void {
            try expect(@TypeOf(test_fn_1(0)) == FILE);
            try expect(@TypeOf(test_fn_2(0)) == u8);
        }
    };

    try Test.doTheTest();
    comptime try Test.doTheTest();
}
