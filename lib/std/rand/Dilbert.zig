//! Dilbert PRNG
//! Do not use this PRNG! It is meant to be predictable, for the purposes of test reproducibility and coverage. 
//! Its output is just a repeat of a user-specified byte pattern.
//! Name is a reference to this comic: https://dilbert.com/strip/2001-10-25

const std = @import("std");
const Random = std.rand.Random;
const math = std.math;
const Dilbert = @This();

pattern: []const u8 = undefined,
curr_idx: usize = 0,

pub fn init(pattern: []const u8) !Dilbert {
    if (pattern.len == 0)
        return error.EmptyPattern;
    var self = Dilbert{};
    self.pattern = pattern;
    self.curr_idx = 0;
    return self;
}

pub fn random(self: *Dilbert) Random {
    return Random.init(self, fill);
}

pub fn fill(self: *Dilbert, buf: []u8) void {
    for (buf) |*byte| {
        byte.* = self.pattern[self.curr_idx];
        self.curr_idx = (self.curr_idx + 1) % self.pattern.len;
    }
}

test "Dilbert fill" {
    var r = try Dilbert.init("9nine");

    const seq = [_]u64{
        0x396E696E65396E69,
        0x6E65396E696E6539,
        0x6E696E65396E696E,
        0x65396E696E65396E,
        0x696E65396E696E65,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [8]u8 = undefined;
        std.mem.writeIntBig(u64, &buf0, s);
        r.fill(&buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..], buf1[0..]));
    }
}
