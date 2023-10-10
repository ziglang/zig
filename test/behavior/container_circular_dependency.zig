const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

const UnionInner = extern struct {
    outer: UnionOuter = std.mem.zeroes(UnionOuter),
};

const Union = extern union {
    outer: ?*UnionOuter,
    inner: ?*UnionInner,
};

const UnionOuter = extern struct {
    u: Union = std.mem.zeroes(Union),
};

test "circular dependency through pointer field of a union" {
    var outer: UnionOuter = .{};
    try expect(outer.u.outer == null);
    try expect(outer.u.inner == null);
}

const StructInner = extern struct {
    outer: StructOuter = std.mem.zeroes(StructOuter),
};

const StructMiddle = extern struct {
    outer: ?*StructInner,
    inner: ?*StructOuter,
};

const StructOuter = extern struct {
    middle: StructMiddle = std.mem.zeroes(StructMiddle),
};

test "circular dependency through pointer field of a struct" {
    var outer: StructOuter = .{};
    try expect(outer.middle.outer == null);
    try expect(outer.middle.inner == null);
}
