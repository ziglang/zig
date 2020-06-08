const std = @import("std");

const B = union(enum) {
    c: C,
    None,
};

const A = struct {
    b: B,
};

const C = struct {};

test "tagged union with all void fields but a meaningful tag" {
    var a: A = A{ .b = B{ .c = C{} } };
    std.testing.expect(@as(@TagType(B), a.b) == @TagType(B).c);
    a = A{ .b = B.None };
    std.testing.expect(@as(@TagType(B), a.b) == @TagType(B).None);
}
