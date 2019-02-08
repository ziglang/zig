const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "casting random address to function pointer" {
    randomAddressToFunction();
    comptime randomAddressToFunction();
}

fn randomAddressToFunction() void {
    var addr: usize = 0xdeadbeef;
    var ptr = @intToPtr(fn () void, addr);
}

test "mutate through ptr initialized with constant intToPtr value" {
    forceCompilerAnalyzeBranchHardCodedPtrDereference(false);
}

fn forceCompilerAnalyzeBranchHardCodedPtrDereference(x: bool) void {
    const hardCodedP = @intToPtr(*volatile u8, 0xdeadbeef);
    if (x) {
        hardCodedP.* = hardCodedP.* | 10;
    } else {
        return;
    }
}
