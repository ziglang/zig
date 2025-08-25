const std = @import("std");
const expect = std.testing.expect;

const Foo = struct {
    nope: i32,

    pub var blah = "xxx";
    const hi = 1;
};

test "@hasDecl" {
    try expect(@hasDecl(Foo, "blah"));

    // Even though `hi` is private, @hasDecl returns true because this test is
    // in the same file scope as Foo. It would return false if Foo was declared
    // in a different file.
    try expect(@hasDecl(Foo, "hi"));

    // @hasDecl is for declarations; not fields.
    try expect(!@hasDecl(Foo, "nope"));
    try expect(!@hasDecl(Foo, "nope1234"));
}

// test
