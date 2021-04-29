const std = @import("std");
const expect = std.testing.expect;

const Foo = @import("hasdecl/foo.zig");

const Bar = struct {
    nope: i32,

    const hi = 1;
    pub var blah = "xxx";
};

test "@hasDecl" {
    expect(@hasDecl(Foo, "public_thing"));
    expect(!@hasDecl(Foo, "private_thing"));
    expect(!@hasDecl(Foo, "no_thing"));

    expect(@hasDecl(Bar, "hi"));
    expect(@hasDecl(Bar, "blah"));
    expect(!@hasDecl(Bar, "nope"));
}
