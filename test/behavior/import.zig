const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    try expect(@as(i32, 1234) == a_namespace.foo());
}

test "importing the same thing gives the same import" {
    try expect(@import("std") == @import("std"));
}

test "import in non-toplevel scope" {
    const S = struct {
        usingnamespace @import("import/a_namespace.zig");
    };
    try expect(@as(i32, 1234) == S.foo());
}

test "import empty file" {
    _ = @import("import/empty.zig");
}
