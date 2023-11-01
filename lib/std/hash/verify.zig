const std = @import("std");

fn hashMaybeSeed(comptime hash_fn: anytype, seed: anytype, buf: []const u8) @typeInfo(@TypeOf(hash_fn)).Fn.return_type.? {
    const HashFn = @typeInfo(@TypeOf(hash_fn)).Fn;
    if (HashFn.params.len > 1) {
        if (@typeInfo(HashFn.params[0].type.?) == .Int) {
            return hash_fn(@intCast(seed), buf);
        } else {
            return hash_fn(buf, @intCast(seed));
        }
    } else {
        return hash_fn(buf);
    }
}

fn initMaybeSeed(comptime Hash: anytype, seed: anytype) Hash {
    const HashFn = @typeInfo(@TypeOf(Hash.init)).Fn;
    if (HashFn.params.len == 1) {
        return Hash.init(@intCast(seed));
    } else {
        return Hash.init();
    }
}

// Returns a verification code, the same as used by SMHasher.
//
// Hash keys of the form {0}, {0,1}, {0,1,2}... up to N=255, using 256-N as seed.
// First four-bytes of the hash, interpreted as little-endian is the verification code.
pub fn smhasher(comptime hash_fn: anytype) u32 {
    const HashFnTy = @typeInfo(@TypeOf(hash_fn)).Fn;
    const HashResult = HashFnTy.return_type.?;
    const hash_size = @sizeOf(HashResult);

    var buf: [256]u8 = undefined;
    var buf_all: [256 * hash_size]u8 = undefined;

    for (0..256) |i| {
        buf[i] = @intCast(i);
        const h = hashMaybeSeed(hash_fn, 256 - i, buf[0..i]);
        std.mem.writeInt(HashResult, buf_all[i * hash_size ..][0..hash_size], h, .little);
    }

    return @truncate(hashMaybeSeed(hash_fn, 0, buf_all[0..]));
}

pub fn iterativeApi(comptime Hash: anytype) !void {
    // Sum(1..32) = 528
    var buf: [528]u8 = [_]u8{0} ** 528;
    var len: usize = 0;
    const seed = 0;

    var hasher = initMaybeSeed(Hash, seed);
    for (1..32) |i| {
        const r = hashMaybeSeed(Hash.hash, seed, buf[0 .. len + i]);
        hasher.update(buf[len..][0..i]);
        const f1 = hasher.final();
        const f2 = hasher.final();
        if (f1 != f2) return error.IterativeHashWasNotIdempotent;
        if (f1 != r) return error.IterativeHashDidNotMatchDirect;
        len += i;
    }
}
