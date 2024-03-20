// Website: romu-random.org
// Reference paper:   http://arxiv.org/abs/2002.11331
// Beware: this PRNG is trivially predictable. While fast, it should *never* be used for cryptographic purposes.

const std = @import("std");
const math = std.math;
const RomuTrio = @This();

x_state: u64,
y_state: u64,
z_state: u64, // set to nonzero seed

pub fn init(init_s: u64) RomuTrio {
    var x = RomuTrio{ .x_state = undefined, .y_state = undefined, .z_state = undefined };
    x.seed(init_s);
    return x;
}

pub fn random(self: *RomuTrio) std.Random {
    return std.Random.init(self, fill);
}

fn next(self: *RomuTrio) u64 {
    const xp = self.x_state;
    const yp = self.y_state;
    const zp = self.z_state;
    self.x_state = 15241094284759029579 *% zp;
    self.y_state = yp -% xp;
    self.y_state = std.math.rotl(u64, self.y_state, 12);
    self.z_state = zp -% yp;
    self.z_state = std.math.rotl(u64, self.z_state, 44);
    return xp;
}

pub fn seedWithBuf(self: *RomuTrio, buf: [24]u8) void {
    const seed_buf = @as([3]u64, @bitCast(buf));
    self.x_state = seed_buf[0];
    self.y_state = seed_buf[1];
    self.z_state = seed_buf[2];
}

pub fn seed(self: *RomuTrio, init_s: u64) void {
    // RomuTrio requires 192-bits of seed.
    var gen = std.Random.SplitMix64.init(init_s);

    self.x_state = gen.next();
    self.y_state = gen.next();
    self.z_state = gen.next();
}

pub fn fill(self: *RomuTrio, buf: []u8) void {
    var i: usize = 0;
    const aligned_len = buf.len - (buf.len & 7);

    // Complete 8 byte segments.
    while (i < aligned_len) : (i += 8) {
        var n = self.next();
        comptime var j: usize = 0;
        inline while (j < 8) : (j += 1) {
            buf[i + j] = @as(u8, @truncate(n));
            n >>= 8;
        }
    }

    // Remaining. (cuts the stream)
    if (i != buf.len) {
        var n = self.next();
        while (i < buf.len) : (i += 1) {
            buf[i] = @as(u8, @truncate(n));
            n >>= 8;
        }
    }
}

test "sequence" {
    // Unfortunately there does not seem to be an official test sequence.
    var r = RomuTrio.init(0);

    const seq = [_]u64{
        16294208416658607535,
        13964609475759908645,
        4703697494102998476,
        3425221541186733346,
        2285772463536419399,
        9454187757529463048,
        13695907680080547496,
        8328236714879408626,
        12323357569716880909,
        12375466223337721820,
    };

    for (seq) |s| {
        try std.testing.expectEqual(s, r.next());
    }
}

test fill {
    // Unfortunately there does not seem to be an official test sequence.
    var r = RomuTrio.init(0);

    const seq = [_]u64{
        16294208416658607535,
        13964609475759908645,
        4703697494102998476,
        3425221541186733346,
        2285772463536419399,
        9454187757529463048,
        13695907680080547496,
        8328236714879408626,
        12323357569716880909,
        12375466223337721820,
    };

    for (seq) |s| {
        var buf0: [8]u8 = undefined;
        var buf1: [7]u8 = undefined;
        std.mem.writeInt(u64, &buf0, s, .little);
        r.fill(&buf1);
        try std.testing.expect(std.mem.eql(u8, buf0[0..7], buf1[0..]));
    }
}

test "buf seeding test" {
    const buf0 = @as([24]u8, @bitCast([3]u64{ 16294208416658607535, 13964609475759908645, 4703697494102998476 }));
    const resulting_state = .{ .x = 16294208416658607535, .y = 13964609475759908645, .z = 4703697494102998476 };
    var r = RomuTrio.init(0);
    r.seedWithBuf(buf0);
    try std.testing.expect(r.x_state == resulting_state.x);
    try std.testing.expect(r.y_state == resulting_state.y);
    try std.testing.expect(r.z_state == resulting_state.z);
}
