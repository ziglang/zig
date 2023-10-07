//! CSPRNG based on the ChaCha8 stream cipher, with forward security.
//!
//! References:
//! - Fast-key-erasure random-number generators https://blog.cr.yp.to/20170723-random.html

const std = @import("std");
const mem = std.mem;
const Random = std.rand.Random;
const Self = @This();

const Cipher = std.crypto.stream.chacha.ChaCha8IETF;

const State = [8 * Cipher.block_length]u8;

state: State,
offset: usize,

const nonce = [_]u8{0} ** Cipher.nonce_length;

pub const secret_seed_length = Cipher.key_length;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Self {
    var self = Self{ .state = undefined, .offset = 0 };
    Cipher.stream(&self.state, 0, secret_seed, nonce);
    return self;
}

/// Inserts entropy to refresh the internal state.
pub fn addEntropy(self: *Self, bytes: []const u8) void {
    var i: usize = 0;
    while (i + Cipher.key_length <= bytes.len) : (i += Cipher.key_length) {
        Cipher.xor(
            self.state[0..Cipher.key_length],
            self.state[0..Cipher.key_length],
            0,
            bytes[i..][0..Cipher.key_length].*,
            nonce,
        );
    }
    if (i < bytes.len) {
        var k = [_]u8{0} ** Cipher.key_length;
        const src = bytes[i..];
        @memcpy(k[0..src.len], src);
        Cipher.xor(
            self.state[0..Cipher.key_length],
            self.state[0..Cipher.key_length],
            0,
            k,
            nonce,
        );
    }
    self.refill();
}

/// Returns a `std.rand.Random` structure backed by the current RNG.
pub fn random(self: *Self) Random {
    return Random.init(self, fill);
}

// Refills the buffer with random bytes, overwriting the previous key.
fn refill(self: *Self) void {
    Cipher.stream(&self.state, 0, self.state[0..Cipher.key_length].*, nonce);
    self.offset = 0;
}

/// Fills the buffer with random bytes.
pub fn fill(self: *Self, buf_: []u8) void {
    const bytes = self.state[Cipher.key_length..];
    var buf = buf_;

    const avail = bytes.len - self.offset;
    if (avail > 0) {
        // Bytes from the current block
        const n = @min(avail, buf.len);
        @memcpy(buf[0..n], bytes[self.offset..][0..n]);
        @memset(bytes[self.offset..][0..n], 0);
        buf = buf[n..];
        self.offset += n;
    }
    if (buf.len == 0) return;

    self.refill();

    // Full blocks
    while (buf.len >= bytes.len) {
        @memcpy(buf[0..bytes.len], bytes);
        buf = buf[bytes.len..];
        self.refill();
    }

    // Remaining bytes
    if (buf.len > 0) {
        @memcpy(buf, bytes[0..buf.len]);
        @memset(bytes[0..buf.len], 0);
        self.offset = buf.len;
    }
}
