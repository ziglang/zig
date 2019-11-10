const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "@sliceToBytes packed struct at runtime and comptime" {
    const Foo = packed struct {
        a: u4,
        b: u4,
    };
    const S = struct {
        fn doTheTest() void {
            var foo: Foo = undefined;
            var slice = @sliceToBytes(@as(*[1]Foo, &foo)[0..1]);
            slice[0] = 0x13;
            switch (builtin.endian) {
                builtin.Endian.Big => {
                    expect(foo.a == 0x1);
                    expect(foo.b == 0x3);
                },
                builtin.Endian.Little => {
                    expect(foo.a == 0x3);
                    expect(foo.b == 0x1);
                },
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
