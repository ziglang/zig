const expectEqual = @import("std").testing.expectEqual;

const FILE = extern struct { dummy_field: u8, };
extern fn printf([*c]const u8, ...) c_int;
extern fn fputs([*c]const u8, noalias [*c]FILE) c_int;
extern fn ftell([*c]FILE) c_long;

test "Extern function call in @TypeOf" {
    const Test = struct {
        fn test_fn(a: var, b: var) @TypeOf(printf("%d %s\n", a, b)) {
            return 0;
        }

        fn doTheTest() void {
            expectEqual(c_int, @TypeOf(test_fn(0, 42)));
        }
    };

    Test.doTheTest();
    comptime Test.doTheTest();
}

test "Peer resolution of extern function calls in @TypeOf" {
    const Test = struct {
        fn test_fn() @TypeOf(ftell(null), fputs(null, null)) {
            return 0;
        }

        fn doTheTest() void {
            expectEqual(c_long, @TypeOf(test_fn()));
        }
    };

    Test.doTheTest();
    comptime Test.doTheTest();
}
