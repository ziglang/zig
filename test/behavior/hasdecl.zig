const std = @import("std");
const expect = std.testing.expect;

const Foo = @import("hasdecl/foo.zig");

const Bar = struct {
    nope: i32,

    const hi = 1;
    pub var blah = "xxx";
};

test "@hasDecl" {
    try expect(@hasDecl(Foo, "public_thing"));
    try expect(!@hasDecl(Foo, "private_thing"));
    try expect(!@hasDecl(Foo, "no_thing"));

    try expect(@hasDecl(Bar, "hi"));
    try expect(@hasDecl(Bar, "blah"));
    try expect(!@hasDecl(Bar, "nope"));
}
