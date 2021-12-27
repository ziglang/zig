const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const Tag = std.meta.Tag;

test "@tagName" {
    try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(BareNumber.Three), "Three"));
}

fn testEnumTagNameBare(n: anytype) []const u8 {
    return @tagName(n);
}

const BareNumber = enum { One, Two, Three };

test "@tagName non-exhaustive enum" {
    try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
    comptime try expect(mem.eql(u8, testEnumTagNameBare(NonExhaustive.B), "B"));
}
const NonExhaustive = enum(u8) { A, B, _ };

test "@tagName is null-terminated" {
    const S = struct {
        fn doTheTest(n: BareNumber) !void {
            try expect(@tagName(n)[3] == 0);
        }
    };
    try S.doTheTest(.Two);
    try comptime S.doTheTest(.Two);
}

test "tag name with assigned enum values" {
    const LocalFoo = enum(u8) {
        A = 1,
        B = 0,
    };
    var b = LocalFoo.B;
    try expect(mem.eql(u8, @tagName(b), "B"));
}

const Bar = enum { A, B, C, D };

test "enum literal casting to optional" {
    var bar: ?Bar = undefined;
    bar = .B;

    try expect(bar.? == Bar.B);
}
