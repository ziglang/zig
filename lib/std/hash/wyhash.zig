const std = @import("std");

pub const Wyhash = struct {
    const secret = [_]u64{
        0xa0761d6478bd642f,
        0xe7037ed1a0b428db,
        0x8ebc6af09c88c6e3,
        0x589965cc75374cc3,
    };

    a: u64,
    b: u64,
    state: [3]u64,
    total_len: usize,

    buf: [48]u8,
    buf_len: usize,

    pub fn init(seed: u64) Wyhash {
        var self = Wyhash{
            .a = undefined,
            .b = undefined,
            .state = undefined,
            .total_len = 0,
            .buf = undefined,
            .buf_len = 0,
        };

        self.state[0] = seed ^ mix(seed ^ secret[0], secret[1]);
        self.state[1] = self.state[0];
        self.state[2] = self.state[0];
        return self;
    }

    // This is subtly different from other hash function update calls. Wyhash requires the last
    // full 48-byte block to be run through final1 if is exactly aligned to 48-bytes.
    pub fn update(self: *Wyhash, input: []const u8) void {
        self.total_len += input.len;

        if (input.len <= 48 - self.buf_len) {
            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        var i: usize = 0;

        if (self.buf_len > 0) {
            i = 48 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
            self.round(&self.buf);
            self.buf_len = 0;
        }

        while (i + 48 < input.len) : (i += 48) {
            self.round(input[i..][0..48]);
        }

        const remaining_bytes = input[i..];
        @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
        self.buf_len = remaining_bytes.len;
    }

    pub fn final(self: *Wyhash) u64 {
        var input = self.buf[0..self.buf_len];
        var newSelf = self.shallowCopy(); // ensure idempotency

        if (self.total_len <= 16) {
            newSelf.smallKey(input);
        } else {
            var offset: usize = 0;
            if (self.buf_len < 16) {
                var scratch: [16]u8 = undefined;
                const rem = 16 - self.buf_len;
                @memcpy(scratch[0..rem], self.buf[self.buf.len - rem ..][0..rem]);
                @memcpy(scratch[rem..][0..self.buf_len], self.buf[0..self.buf_len]);

                // Same as input but with additional bytes preceeding start in case of a short buffer
                input = &scratch;
                offset = rem;
            }

            newSelf.final0();
            newSelf.final1(input, offset);
        }

        return newSelf.final2();
    }

    // Copies the core wyhash state but not any internal buffers.
    inline fn shallowCopy(self: *Wyhash) Wyhash {
        return .{
            .a = self.a,
            .b = self.b,
            .state = self.state,
            .total_len = self.total_len,
            .buf = undefined,
            .buf_len = undefined,
        };
    }

    inline fn smallKey(self: *Wyhash, input: []const u8) void {
        std.debug.assert(input.len <= 16);

        if (input.len >= 4) {
            const end = input.len - 4;
            const quarter = (input.len >> 3) << 2;
            self.a = (read(4, input[0..]) << 32) | read(4, input[quarter..]);
            self.b = (read(4, input[end..]) << 32) | read(4, input[end - quarter ..]);
        } else if (input.len > 0) {
            self.a = (@as(u64, input[0]) << 16) | (@as(u64, input[input.len >> 1]) << 8) | input[input.len - 1];
            self.b = 0;
        } else {
            self.a = 0;
            self.b = 0;
        }
    }

    inline fn round(self: *Wyhash, input: *const [48]u8) void {
        inline for (0..3) |i| {
            const a = read(8, input[8 * (2 * i) ..]);
            const b = read(8, input[8 * (2 * i + 1) ..]);
            self.state[i] = mix(a ^ secret[i + 1], b ^ self.state[i]);
        }
    }

    inline fn read(comptime bytes: usize, data: []const u8) u64 {
        std.debug.assert(bytes <= 8);
        const T = std.meta.Int(.unsigned, 8 * bytes);
        return @as(u64, std.mem.readIntLittle(T, data[0..bytes]));
    }

    inline fn mum(a: *u64, b: *u64) void {
        const x = @as(u128, a.*) *% b.*;
        a.* = @as(u64, @truncate(x));
        b.* = @as(u64, @truncate(x >> 64));
    }

    inline fn mix(a_: u64, b_: u64) u64 {
        var a = a_;
        var b = b_;
        mum(&a, &b);
        return a ^ b;
    }

    inline fn final0(self: *Wyhash) void {
        self.state[0] ^= self.state[1] ^ self.state[2];
    }

    // input_lb must be at least 16-bytes long (in shorter key cases the smallKey function will be
    // used instead). We use an index into a slice to for comptime processing as opposed to if we
    // used pointers.
    inline fn final1(self: *Wyhash, input_lb: []const u8, start_pos: usize) void {
        std.debug.assert(input_lb.len >= 16);
        std.debug.assert(input_lb.len - start_pos <= 48);
        const input = input_lb[start_pos..];

        var i: usize = 0;
        while (i + 16 < input.len) : (i += 16) {
            self.state[0] = mix(read(8, input[i..]) ^ secret[1], read(8, input[i + 8 ..]) ^ self.state[0]);
        }

        self.a = read(8, input_lb[input_lb.len - 16 ..][0..8]);
        self.b = read(8, input_lb[input_lb.len - 8 ..][0..8]);
    }

    inline fn final2(self: *Wyhash) u64 {
        self.a ^= secret[1];
        self.b ^= self.state[0];
        mum(&self.a, &self.b);
        return mix(self.a ^ secret[0] ^ self.total_len, self.b ^ secret[1]);
    }

    pub fn hash(seed: u64, input: []const u8) u64 {
        var self = Wyhash.init(seed);

        if (input.len <= 16) {
            self.smallKey(input);
        } else {
            var i: usize = 0;
            if (input.len >= 48) {
                while (i + 48 < input.len) : (i += 48) {
                    self.round(input[i..][0..48]);
                }
                self.final0();
            }
            self.final1(input, i);
        }

        self.total_len = input.len;
        return self.final2();
    }
};

const expectEqual = std.testing.expectEqual;

const TestVector = struct {
    expected: u64,
    seed: u64,
    input: []const u8,
};

// Run https://github.com/wangyi-fudan/wyhash/blob/77e50f267fbc7b8e2d09f2d455219adb70ad4749/test_vector.cpp directly.
const vectors = [_]TestVector{
    .{ .seed = 0, .expected = 0x409638ee2bde459, .input = "" },
    .{ .seed = 1, .expected = 0xa8412d091b5fe0a9, .input = "a" },
    .{ .seed = 2, .expected = 0x32dd92e4b2915153, .input = "abc" },
    .{ .seed = 3, .expected = 0x8619124089a3a16b, .input = "message digest" },
    .{ .seed = 4, .expected = 0x7a43afb61d7f5f40, .input = "abcdefghijklmnopqrstuvwxyz" },
    .{ .seed = 5, .expected = 0xff42329b90e50d58, .input = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" },
    .{ .seed = 6, .expected = 0xc39cab13b115aad3, .input = "12345678901234567890123456789012345678901234567890123456789012345678901234567890" },
};

test "test vectors" {
    for (vectors) |e| {
        try expectEqual(e.expected, Wyhash.hash(e.seed, e.input));
    }
}

test "test vectors at comptime" {
    comptime {
        inline for (vectors) |e| {
            try expectEqual(e.expected, Wyhash.hash(e.seed, e.input));
        }
    }
}

test "test vectors streaming" {
    const step = 5;

    for (vectors) |e| {
        var wh = Wyhash.init(e.seed);
        var i: usize = 0;
        while (i < e.input.len) : (i += step) {
            const len = if (i + step > e.input.len) e.input.len - i else step;
            wh.update(e.input[i..][0..len]);
        }
        try expectEqual(e.expected, wh.final());
    }
}

test "test ensure idempotent final call" {
    const e: TestVector = .{ .seed = 6, .expected = 0xc39cab13b115aad3, .input = "12345678901234567890123456789012345678901234567890123456789012345678901234567890" };
    var wh = Wyhash.init(e.seed);
    wh.update(e.input);

    for (0..10) |_| {
        try expectEqual(e.expected, wh.final());
    }
}

test "iterative non-divisible update" {
    var buf: [8192]u8 = undefined;
    for (&buf, 0..) |*e, i| {
        e.* = @as(u8, @truncate(i));
    }

    const seed = 0x128dad08f;

    var end: usize = 32;
    while (end < buf.len) : (end += 32) {
        const non_iterative_hash = Wyhash.hash(seed, buf[0..end]);

        var wy = Wyhash.init(seed);
        var i: usize = 0;
        while (i < end) : (i += 33) {
            wy.update(buf[i..@min(i + 33, end)]);
        }
        const iterative_hash = wy.final();

        try std.testing.expectEqual(iterative_hash, non_iterative_hash);
    }
}
