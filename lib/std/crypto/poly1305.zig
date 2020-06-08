// Translated from monocypher which is licensed under CC-0/BSD-3.
//
// https://monocypher.org/

const std = @import("../std.zig");
const builtin = std.builtin;

const Endian = builtin.Endian;
const readIntLittle = std.mem.readIntLittle;
const writeIntLittle = std.mem.writeIntLittle;

pub const Poly1305 = struct {
    const Self = @This();

    pub const mac_length = 16;
    pub const minimum_key_length = 32;

    // constant multiplier (from the secret key)
    r: [4]u32,
    // accumulated hash
    h: [5]u32,
    // chunk of the message
    c: [5]u32,
    // random number added at the end (from the secret key)
    pad: [4]u32,
    // How many bytes are there in the chunk.
    c_idx: usize,

    fn secureZero(self: *Self) void {
        std.mem.secureZero(u8, @ptrCast([*]u8, self)[0..@sizeOf(Poly1305)]);
    }

    pub fn create(out: []u8, msg: []const u8, key: []const u8) void {
        std.debug.assert(out.len >= mac_length);
        std.debug.assert(key.len >= minimum_key_length);

        var ctx = Poly1305.init(key);
        ctx.update(msg);
        ctx.final(out);
    }

    // Initialize the MAC context.
    //   - key.len is sufficient size.
    pub fn init(key: []const u8) Self {
        var ctx: Poly1305 = undefined;

        // Initial hash is zero
        {
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                ctx.h[i] = 0;
            }
        }
        // add 2^130 to every input block
        ctx.c[4] = 1;
        polyClearC(&ctx);

        // load r and pad (r has some of its bits cleared)
        {
            var i: usize = 0;
            while (i < 1) : (i += 1) {
                ctx.r[0] = readIntLittle(u32, key[0..4]) & 0x0fffffff;
            }
        }
        {
            var i: usize = 1;
            while (i < 4) : (i += 1) {
                ctx.r[i] = readIntLittle(u32, key[i * 4 ..][0..4]) & 0x0ffffffc;
            }
        }
        {
            var i: usize = 0;
            while (i < 4) : (i += 1) {
                ctx.pad[i] = readIntLittle(u32, key[i * 4 + 16 ..][0..4]);
            }
        }

        return ctx;
    }

    // h = (h + c) * r
    // preconditions:
    //   ctx->h <= 4_ffffffff_ffffffff_ffffffff_ffffffff
    //   ctx->c <= 1_ffffffff_ffffffff_ffffffff_ffffffff
    //   ctx->r <=   0ffffffc_0ffffffc_0ffffffc_0fffffff
    // Postcondition:
    //   ctx->h <= 4_ffffffff_ffffffff_ffffffff_ffffffff
    fn polyBlock(ctx: *Self) void {
        // s = h + c, without carry propagation
        const s0 = @as(u64, ctx.h[0]) + ctx.c[0]; // s0 <= 1_fffffffe
        const s1 = @as(u64, ctx.h[1]) + ctx.c[1]; // s1 <= 1_fffffffe
        const s2 = @as(u64, ctx.h[2]) + ctx.c[2]; // s2 <= 1_fffffffe
        const s3 = @as(u64, ctx.h[3]) + ctx.c[3]; // s3 <= 1_fffffffe
        const s4 = @as(u64, ctx.h[4]) + ctx.c[4]; // s4 <=          5

        // Local all the things!
        const r0 = ctx.r[0]; // r0  <= 0fffffff
        const r1 = ctx.r[1]; // r1  <= 0ffffffc
        const r2 = ctx.r[2]; // r2  <= 0ffffffc
        const r3 = ctx.r[3]; // r3  <= 0ffffffc
        const rr0 = (r0 >> 2) * 5; // rr0 <= 13fffffb // lose 2 bits...
        const rr1 = (r1 >> 2) + r1; // rr1 <= 13fffffb // rr1 == (r1 >> 2) * 5
        const rr2 = (r2 >> 2) + r2; // rr2 <= 13fffffb // rr1 == (r2 >> 2) * 5
        const rr3 = (r3 >> 2) + r3; // rr3 <= 13fffffb // rr1 == (r3 >> 2) * 5

        // (h + c) * r, without carry propagation
        const x0 = s0 * r0 + s1 * rr3 + s2 * rr2 + s3 * rr1 + s4 * rr0; //<=97ffffe007fffff8
        const x1 = s0 * r1 + s1 * r0 + s2 * rr3 + s3 * rr2 + s4 * rr1; //<=8fffffe20ffffff6
        const x2 = s0 * r2 + s1 * r1 + s2 * r0 + s3 * rr3 + s4 * rr2; //<=87ffffe417fffff4
        const x3 = s0 * r3 + s1 * r2 + s2 * r1 + s3 * r0 + s4 * rr3; //<=7fffffe61ffffff2
        const x4 = s4 * (r0 & 3); // ...recover 2 bits      //<=               f

        // partial reduction modulo 2^130 - 5
        const _u5 = @truncate(u32, x4 + (x3 >> 32)); // u5 <= 7ffffff5
        const _u0 = (_u5 >> 2) * 5 + (x0 & 0xffffffff);
        const _u1 = (_u0 >> 32) + (x1 & 0xffffffff) + (x0 >> 32);
        const _u2 = (_u1 >> 32) + (x2 & 0xffffffff) + (x1 >> 32);
        const _u3 = (_u2 >> 32) + (x3 & 0xffffffff) + (x2 >> 32);
        const _u4 = (_u3 >> 32) + (_u5 & 3);

        // Update the hash
        ctx.h[0] = @truncate(u32, _u0); // u0 <= 1_9ffffff0
        ctx.h[1] = @truncate(u32, _u1); // u1 <= 1_97ffffe0
        ctx.h[2] = @truncate(u32, _u2); // u2 <= 1_8fffffe2
        ctx.h[3] = @truncate(u32, _u3); // u3 <= 1_87ffffe4
        ctx.h[4] = @truncate(u32, _u4); // u4 <=          4
    }

    // (re-)initializes the input counter and input buffer
    fn polyClearC(ctx: *Self) void {
        ctx.c[0] = 0;
        ctx.c[1] = 0;
        ctx.c[2] = 0;
        ctx.c[3] = 0;
        ctx.c_idx = 0;
    }

    fn polyTakeInput(ctx: *Self, input: u8) void {
        const word = ctx.c_idx >> 2;
        const byte = ctx.c_idx & 3;
        ctx.c[word] |= std.math.shl(u32, input, byte * 8);
        ctx.c_idx += 1;
    }

    fn polyUpdate(ctx: *Self, msg: []const u8) void {
        for (msg) |b| {
            polyTakeInput(ctx, b);
            if (ctx.c_idx == 16) {
                polyBlock(ctx);
                polyClearC(ctx);
            }
        }
    }

    fn alignTo(x: usize, block_size: usize) usize {
        return ((~x) +% 1) & (block_size - 1);
    }

    // Feed data into the MAC context.
    pub fn update(ctx: *Self, msg: []const u8) void {
        // Align ourselves with block boundaries
        const alignm = std.math.min(alignTo(ctx.c_idx, 16), msg.len);
        polyUpdate(ctx, msg[0..alignm]);

        var nmsg = msg[alignm..];

        // Process the msg block by block
        const nb_blocks = nmsg.len >> 4;
        var i: usize = 0;
        while (i < nb_blocks) : (i += 1) {
            ctx.c[0] = readIntLittle(u32, nmsg[0..4]);
            ctx.c[1] = readIntLittle(u32, nmsg[4..8]);
            ctx.c[2] = readIntLittle(u32, nmsg[8..12]);
            ctx.c[3] = readIntLittle(u32, nmsg[12..16]);
            polyBlock(ctx);
            nmsg = nmsg[16..];
        }
        if (nb_blocks > 0) {
            polyClearC(ctx);
        }

        // remaining bytes
        polyUpdate(ctx, nmsg[0..]);
    }

    // Finalize the MAC and output into buffer provided by caller.
    pub fn final(ctx: *Self, out: []u8) void {
        // Process the last block (if any)
        if (ctx.c_idx != 0) {
            // move the final 1 according to remaining input length
            // (We may add less than 2^130 to the last input block)
            ctx.c[4] = 0;
            polyTakeInput(ctx, 1);
            // one last hash update
            polyBlock(ctx);
        }

        // check if we should subtract 2^130-5 by performing the
        // corresponding carry propagation.
        const _u0 = @as(u64, 5) + ctx.h[0]; // <= 1_00000004
        const _u1 = (_u0 >> 32) + ctx.h[1]; // <= 1_00000000
        const _u2 = (_u1 >> 32) + ctx.h[2]; // <= 1_00000000
        const _u3 = (_u2 >> 32) + ctx.h[3]; // <= 1_00000000
        const _u4 = (_u3 >> 32) + ctx.h[4]; // <=          5
        // u4 indicates how many times we should subtract 2^130-5 (0 or 1)

        // h + pad, minus 2^130-5 if u4 exceeds 3
        const uu0 = (_u4 >> 2) * 5 + ctx.h[0] + ctx.pad[0]; // <= 2_00000003
        const uu1 = (uu0 >> 32) + ctx.h[1] + ctx.pad[1]; // <= 2_00000000
        const uu2 = (uu1 >> 32) + ctx.h[2] + ctx.pad[2]; // <= 2_00000000
        const uu3 = (uu2 >> 32) + ctx.h[3] + ctx.pad[3]; // <= 2_00000000

        writeIntLittle(u32, out[0..4], @truncate(u32, uu0));
        writeIntLittle(u32, out[4..8], @truncate(u32, uu1));
        writeIntLittle(u32, out[8..12], @truncate(u32, uu2));
        writeIntLittle(u32, out[12..16], @truncate(u32, uu3));

        ctx.secureZero();
    }
};

test "poly1305 rfc7439 vector1" {
    const expected_mac = "\xa8\x06\x1d\xc1\x30\x51\x36\xc6\xc2\x2b\x8b\xaf\x0c\x01\x27\xa9";

    const msg = "Cryptographic Forum Research Group";
    const key = "\x85\xd6\xbe\x78\x57\x55\x6d\x33\x7f\x44\x52\xfe\x42\xd5\x06\xa8" ++
        "\x01\x03\x80\x8a\xfb\x0d\xb2\xfd\x4a\xbf\xf6\xaf\x41\x49\xf5\x1b";

    var mac: [16]u8 = undefined;
    Poly1305.create(mac[0..], msg, key);

    std.testing.expectEqualSlices(u8, expected_mac, &mac);
}
