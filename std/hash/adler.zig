// Adler32 checksum.
//
// https://tools.ietf.org/html/rfc1950#section-9
// https://github.com/madler/zlib/blob/master/adler32.c

const std = @import("../index.zig");
const debug = std.debug;

pub const Adler32 = struct {
    const base = 65521;
    const nmax = 5552;

    adler: u32,

    pub fn init() Adler32 {
        return Adler32{ .adler = 1 };
    }

    // This fast variant is taken from zlib. It reduces the required modulos and unrolls longer
    // buffer inputs and should be much quicker.
    pub fn update(self: *Adler32, input: []const u8) void {
        var s1 = self.adler & 0xffff;
        var s2 = (self.adler >> 16) & 0xffff;

        if (input.len == 1) {
            s1 +%= input[0];
            if (s1 >= base) {
                s1 -= base;
            }
            s2 +%= s1;
            if (s2 >= base) {
                s2 -= base;
            }
        } else if (input.len < 16) {
            for (input) |b| {
                s1 +%= b;
                s2 +%= s1;
            }
            if (s1 >= base) {
                s1 -= base;
            }

            s2 %= base;
        } else {
            var i: usize = 0;
            while (i + nmax <= input.len) : (i += nmax) {
                const n = nmax / 16; // note: 16 | nmax

                var rounds: usize = 0;
                while (rounds < n) : (rounds += 1) {
                    comptime var j: usize = 0;
                    inline while (j < 16) : (j += 1) {
                        s1 +%= input[i + n * j];
                        s2 +%= s1;
                    }
                }
            }

            if (i < input.len) {
                while (i + 16 <= input.len) : (i += 16) {
                    comptime var j: usize = 0;
                    inline while (j < 16) : (j += 1) {
                        s1 +%= input[i + j];
                        s2 +%= s1;
                    }
                }
                while (i < input.len) : (i += 1) {
                    s1 +%= input[i];
                    s2 +%= s1;
                }

                s1 %= base;
                s2 %= base;
            }
        }

        self.adler = s1 | (s2 << 16);
    }

    pub fn final(self: *Adler32) u32 {
        return self.adler;
    }

    pub fn hash(input: []const u8) u32 {
        var c = Adler32.init();
        c.update(input);
        return c.final();
    }
};

test "adler32 sanity" {
    debug.assert(Adler32.hash("a") == 0x620062);
    debug.assert(Adler32.hash("example") == 0xbc002ed);
}

test "adler32 long" {
    const long1 = []u8{1} ** 1024;
    debug.assert(Adler32.hash(long1[0..]) == 0x06780401);

    const long2 = []u8{1} ** 1025;
    debug.assert(Adler32.hash(long2[0..]) == 0x0a7a0402);
}

test "adler32 very long" {
    const long = []u8{1} ** 5553;
    debug.assert(Adler32.hash(long[0..]) == 0x707f15b2);
}
