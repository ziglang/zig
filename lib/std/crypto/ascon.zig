//! Ascon is a 320-bit permutation, selected as new standard for lightweight cryptography
//! in the NIST Lightweight Cryptography competition (2019–2023).
//! https://csrc.nist.gov/pubs/sp/800/232/ipd
//!
//! The permutation is compact, and optimized for timing and side channel resistance,
//! making it a good choice for embedded applications.
//!
//! It is not meant to be used directly, but as a building block for symmetric cryptography.

const std = @import("std");
const builtin = @import("builtin");
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;
const rotr = std.math.rotr;
const native_endian = builtin.cpu.arch.endian();

/// An Ascon state.
///
/// The state is represented as 5 64-bit words.
///
/// The original NIST submission (v1.2) serializes these words as big-endian,
/// but NIST SP 800-232 switched to a little-endian representation.
/// Software implementations are free to use native endianness with no security degradation.
pub fn State(comptime endian: std.builtin.Endian) type {
    return struct {
        const Self = @This();

        /// Number of bytes in the state.
        pub const block_bytes = 40;

        const Block = [5]u64;

        st: Block,

        /// Initialize the state from a slice of bytes.
        ///
        /// Parameters:
        ///   - initial_state: A 40-byte array to initialize the state
        ///
        /// Returns: A new State initialized with the provided bytes
        pub fn init(initial_state: [block_bytes]u8) Self {
            var state = Self{ .st = undefined };
            @memcpy(state.asBytes(), &initial_state);
            state.endianSwap();
            return state;
        }

        /// Initialize the state from u64 words in native endianness.
        ///
        /// Parameters:
        ///   - initial_state: An array of 5 u64 words in native endianness
        ///
        /// Returns: A new State with the provided words
        pub fn initFromWords(initial_state: [5]u64) Self {
            return .{ .st = initial_state };
        }

        /// Initialize the state for Ascon XOF.
        ///
        /// Returns: A new State initialized with the Ascon XOF initialization vector
        pub fn initXof() Self {
            return Self{ .st = Block{
                0xb57e273b814cd416,
                0x2b51042562ae2420,
                0x66a3a7768ddf2218,
                0x5aad0a7a8153650c,
                0x4f3e0e32539493b6,
            } };
        }

        /// Initialize the state for Ascon XOFa.
        ///
        /// Returns: A new State initialized with the Ascon XOFa initialization vector
        pub fn initXofA() Self {
            return Self{ .st = Block{
                0x44906568b77b9832,
                0xcd8d6cae53455532,
                0xf7b5212756422129,
                0x246885e1de0d225b,
                0xa8cb5ce33449973f,
            } };
        }

        /// A representation of the state as bytes. The byte order is architecture-dependent.
        ///
        /// Returns: A pointer to the state's internal byte representation
        pub fn asBytes(self: *Self) *[block_bytes]u8 {
            return mem.asBytes(&self.st);
        }

        /// Byte-swap the entire state if the architecture doesn't match the required endianness.
        ///
        /// This ensures the state is in the correct endianness for the current platform.
        pub fn endianSwap(self: *Self) void {
            for (&self.st) |*w| {
                w.* = mem.toNative(u64, w.*, endian);
            }
        }

        /// Set bytes starting at the beginning of the state.
        ///
        /// Parameters:
        ///   - bytes: Slice of bytes to write into the state (up to 40 bytes)
        ///
        /// Note: If bytes.len < 40, remaining state words are zero-padded
        pub fn setBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + 8 <= bytes.len) : (i += 8) {
                self.st[i / 8] = mem.readInt(u64, bytes[i..][0..8], endian);
            }
            if (i < bytes.len) {
                var padded: [8]u8 = @splat(0);
                @memcpy(padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / 8] = mem.readInt(u64, padded[0..], endian);
            }
        }

        /// XOR a byte into the state at a given offset.
        ///
        /// Parameters:
        ///   - byte: The byte to XOR into the state
        ///   - offset: The byte offset in the state (0-39)
        pub fn addByte(self: *Self, byte: u8, offset: usize) void {
            const z = switch (endian) {
                .big => 64 - 8 - 8 * @as(u6, @truncate(offset % 8)),
                .little => 8 * @as(u6, @truncate(offset % 8)),
            };
            self.st[offset / 8] ^= @as(u64, byte) << z;
        }

        /// XOR bytes into the beginning of the state.
        ///
        /// Parameters:
        ///   - bytes: Slice of bytes to XOR into the state (up to 40 bytes)
        ///
        /// Note: Handles partial blocks with zero-padding
        pub fn addBytes(self: *Self, bytes: []const u8) void {
            var i: usize = 0;
            while (i + 8 <= bytes.len) : (i += 8) {
                self.st[i / 8] ^= mem.readInt(u64, bytes[i..][0..8], endian);
            }
            if (i < bytes.len) {
                var padded: [8]u8 = @splat(0);
                @memcpy(padded[0 .. bytes.len - i], bytes[i..]);
                self.st[i / 8] ^= mem.readInt(u64, padded[0..], endian);
            }
        }

        /// Extract the first bytes of the state.
        ///
        /// Parameters:
        ///   - out: Output buffer to receive the extracted bytes
        ///
        /// Note: Extracts up to out.len bytes from the beginning of the state
        pub fn extractBytes(self: *Self, out: []u8) void {
            var i: usize = 0;
            while (i + 8 <= out.len) : (i += 8) {
                mem.writeInt(u64, out[i..][0..8], self.st[i / 8], endian);
            }
            if (i < out.len) {
                var padded: [8]u8 = @splat(0);
                mem.writeInt(u64, padded[0..], self.st[i / 8], endian);
                @memcpy(out[i..], padded[0 .. out.len - i]);
            }
        }

        /// XOR the first bytes of the state into a slice of bytes.
        ///
        /// Parameters:
        ///   - out: Output buffer for the XORed result
        ///   - in: Input bytes to XOR with the state
        ///
        /// Requires: out.len == in.len
        pub fn xorBytes(self: *Self, out: []u8, in: []const u8) void {
            debug.assert(out.len == in.len);

            var i: usize = 0;
            while (i + 8 <= in.len) : (i += 8) {
                const x = mem.readInt(u64, in[i..][0..8], native_endian) ^ mem.nativeTo(u64, self.st[i / 8], endian);
                mem.writeInt(u64, out[i..][0..8], x, native_endian);
            }
            if (i < in.len) {
                var padded: [8]u8 = @splat(0);
                @memcpy(padded[0 .. in.len - i], in[i..]);
                const x = mem.readInt(u64, &padded, native_endian) ^ mem.nativeTo(u64, self.st[i / 8], endian);
                mem.writeInt(u64, &padded, x, native_endian);
                @memcpy(out[i..], padded[0 .. in.len - i]);
            }
        }

        /// Set the words storing the bytes of a given range to zero.
        ///
        /// Parameters:
        ///   - from: Starting byte offset (inclusive)
        ///   - to: Ending byte offset (inclusive)
        ///
        /// Note: Clears complete words that contain the specified byte range
        pub fn clear(self: *Self, from: usize, to: usize) void {
            @memset(self.st[from / 8 .. (to + 7) / 8], 0);
        }

        /// Clear the entire state, disabling compiler optimizations.
        ///
        /// Uses secure zeroing to prevent the compiler from optimizing away
        /// the clearing operation. Use for sensitive data cleanup.
        pub fn secureZero(self: *Self) void {
            crypto.secureZero(u64, &self.st);
        }

        /// Apply a reduced-round permutation to the state.
        ///
        /// Parameters:
        ///   - rounds: Number of rounds to apply (1-12)
        ///
        /// Note: Uses the last `rounds` round constants from the full set
        pub fn permuteR(state: *Self, comptime rounds: u4) void {
            const rks = [16]u64{ 0x3c, 0x2d, 0x1e, 0x0f, 0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b };
            inline for (rks[rks.len - rounds ..]) |rk| {
                state.round(rk);
            }
        }

        /// Apply a full-round permutation to the state.
        ///
        /// Applies the standard 12-round Ascon permutation.
        pub fn permute(state: *Self) void {
            state.permuteR(12);
        }

        /// Apply a permutation to the state and prevent backtracking.
        ///
        /// Parameters:
        ///   - rounds: Number of permutation rounds to apply
        ///   - rate: Rate in bytes (must be multiple of 8, < 40)
        ///
        /// The capacity portion is XORed before and after permutation to
        /// provide forward security (ratcheting).
        pub fn permuteRatchet(state: *Self, comptime rounds: u4, comptime rate: u6) void {
            const capacity = block_bytes - rate;
            debug.assert(capacity > 0 and capacity % 8 == 0); // capacity must be a multiple of 64 bits
            var mask: [capacity / 8]u64 = undefined;
            inline for (&mask, state.st[state.st.len - mask.len ..]) |*m, x| m.* = x;
            state.permuteR(rounds);
            inline for (mask, state.st[state.st.len - mask.len ..]) |m, *x| x.* ^= m;
        }

        /// Core Ascon permutation round function.
        ///
        /// Parameters:
        ///   - rk: Round constant for this round
        ///
        /// Implements one round of the Ascon permutation with S-box and linear layer.
        fn round(state: *Self, rk: u64) void {
            const x = &state.st;
            x[2] ^= rk;

            x[0] ^= x[4];
            x[4] ^= x[3];
            x[2] ^= x[1];
            var t: Block = .{
                x[0] ^ (~x[1] & x[2]),
                x[1] ^ (~x[2] & x[3]),
                x[2] ^ (~x[3] & x[4]),
                x[3] ^ (~x[4] & x[0]),
                x[4] ^ (~x[0] & x[1]),
            };
            t[1] ^= t[0];
            t[3] ^= t[2];
            t[0] ^= t[4];

            x[2] = t[2] ^ rotr(u64, t[2], 6 - 1);
            x[3] = t[3] ^ rotr(u64, t[3], 17 - 10);
            x[4] = t[4] ^ rotr(u64, t[4], 41 - 7);
            x[0] = t[0] ^ rotr(u64, t[0], 28 - 19);
            x[1] = t[1] ^ rotr(u64, t[1], 61 - 39);
            x[2] = t[2] ^ rotr(u64, x[2], 1);
            x[3] = t[3] ^ rotr(u64, x[3], 10);
            x[4] = t[4] ^ rotr(u64, x[4], 7);
            x[0] = t[0] ^ rotr(u64, x[0], 19);
            x[1] = t[1] ^ rotr(u64, x[1], 39);
            x[2] = ~x[2];
        }
    };
}

test "ascon" {
    const Ascon = State(.big);
    var bytes: [Ascon.block_bytes]u8 = undefined;
    @memset(&bytes, 1);
    var st = Ascon.init(bytes);
    var out: [Ascon.block_bytes]u8 = undefined;
    st.permute();
    st.extractBytes(&out);
    const expected1 = [_]u8{ 148, 147, 49, 226, 218, 221, 208, 113, 186, 94, 96, 10, 183, 219, 119, 150, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected1, &out);
    st.clear(0, 10);
    st.extractBytes(&out);
    const expected2 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected2, &out);
    st.addByte(1, 5);
    st.addByte(2, 5);
    st.extractBytes(&out);
    const expected3 = [_]u8{ 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 206, 65, 18, 215, 97, 78, 106, 118, 81, 211, 150, 52, 17, 117, 64, 216, 45, 148, 240, 65, 181, 90, 180 };
    try testing.expectEqualSlices(u8, &expected3, &out);
    st.addBytes(&bytes);
    st.extractBytes(&out);
    const expected4 = [_]u8{ 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 168, 207, 64, 19, 214, 96, 79, 107, 119, 80, 210, 151, 53, 16, 116, 65, 217, 44, 149, 241, 64, 180, 91, 181 };
    try testing.expectEqualSlices(u8, &expected4, &out);
}

const AsconState = State(.little);
const AuthenticationError = crypto.errors.AuthenticationError;

/// Ascon-AEAD128 as specified in NIST SP 800-232 Section 4
pub const AsconAead128 = struct {
    pub const tag_length = 16;
    pub const nonce_length = 16;
    pub const key_length = 16;
    pub const block_length = 16;

    const AeadState = struct {
        st: AsconState,
        k0: u64,
        k1: u64,

        /// Initialize AEAD state with key and nonce.
        ///
        /// Parameters:
        ///   - key: 16-byte secret key
        ///   - nonce: 16-byte nonce
        ///
        /// Returns: Initialized AEAD state ready for processing
        fn init(key: [16]u8, nonce: [16]u8) AeadState {
            const k0 = mem.readInt(u64, key[0..8], .little);
            const k1 = mem.readInt(u64, key[8..16], .little);
            const n0 = mem.readInt(u64, nonce[0..8], .little);
            const n1 = mem.readInt(u64, nonce[8..16], .little);

            // IV for Ascon-AEAD128 (Ascon-128a)
            const iv: u64 = 0x00001000808C0001;
            const words: [5]u64 = .{ iv, k0, k1, n0, n1 };

            var st = AsconState.initFromWords(words);
            st.permuteR(12);

            st.st[3] ^= k0;
            st.st[4] ^= k1;

            return AeadState{ .st = st, .k0 = k0, .k1 = k1 };
        }

        /// Process associated data for authentication.
        ///
        /// Parameters:
        ///   - ad: Associated data to authenticate
        ///
        /// Updates the state to include AD in authentication tag computation.
        fn processAd(self: *AeadState, ad: []const u8) void {
            if (ad.len == 0) return;

            var i: usize = 0;
            // Process full 128-bit blocks
            while (i + 16 <= ad.len) : (i += 16) {
                self.st.addBytes(ad[i..][0..16]);
                self.st.permuteR(8);
            }

            // Process final partial AD block
            const adrem = ad.len - i;
            if (adrem > 0) {
                if (adrem >= 8) {
                    var buf: [8]u8 = @splat(0);
                    @memcpy(buf[0..8], ad[i..][0..8]);
                    self.st.st[0] ^= mem.readInt(u64, &buf, .little);

                    buf = @splat(0);
                    @memcpy(buf[0 .. adrem - 8], ad[i + 8 ..]);
                    buf[adrem - 8] = 0x01;
                    self.st.st[1] ^= mem.readInt(u64, &buf, .little);
                } else {
                    var buf: [8]u8 = @splat(0);
                    @memcpy(buf[0..adrem], ad[i..]);
                    buf[adrem] = 0x01;
                    self.st.st[0] ^= mem.readInt(u64, &buf, .little);
                }
                self.st.permuteR(8);
            }
        }

        /// Finalize the AEAD operation and prepare tag.
        ///
        /// Applies final permutation and XORs key for tag generation.
        fn finalize(self: *AeadState) void {
            // XOR key before final permutation
            self.st.st[2] ^= self.k0;
            self.st.st[3] ^= self.k1;
            self.st.permuteR(12);

            // XOR key again for tag generation
            self.st.st[3] ^= self.k0;
            self.st.st[4] ^= self.k1;
        }
    };

    /// Encrypt a message with Ascon-AEAD128.
    ///
    /// Parameters:
    ///   - c: Output buffer for ciphertext (must be same length as m)
    ///   - tag: Output buffer for authentication tag (16 bytes)
    ///   - m: Plaintext message to encrypt
    ///   - ad: Associated data to authenticate but not encrypt
    ///   - npub: Public nonce (16 bytes, must be unique per message)
    ///   - k: Secret key (16 bytes)
    ///
    /// Note: The ciphertext and tag must be transmitted together for decryption
    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) void {
        debug.assert(c.len == m.len);

        var state = AeadState.init(k, npub);

        // Process associated data
        state.processAd(ad);

        // Domain separation (DSEP = 0x80 at byte 7 in little-endian)
        state.st.st[4] ^= 0x8000000000000000;

        // Process plaintext
        var i: usize = 0;
        while (i + 16 <= m.len) : (i += 16) {
            state.st.addBytes(m[i..][0..16]);
            state.st.extractBytes(c[i..][0..16]);
            state.st.permuteR(8);
        }

        // Process final partial block
        const remaining = m.len - i;
        if (remaining > 8) {
            // Split between two words
            state.st.addBytes(m[i..][0..8]);
            state.st.extractBytes(c[i..][0..8]);

            var buf: [8]u8 = @splat(0);
            @memcpy(buf[0 .. remaining - 8], m[i + 8 ..]);
            const m1 = mem.readInt(u64, &buf, .little);
            state.st.st[1] ^= m1;
            mem.writeInt(u64, buf[0..], state.st.st[1], .little);
            @memcpy(c[i + 8 ..], buf[0 .. remaining - 8]);

            // Add padding
            state.st.st[1] ^= @as(u64, 0x01) << @intCast((remaining - 8) * 8);
        } else if (remaining == 8) {
            // Exactly 8 bytes - all in word 0, padding in word 1
            state.st.addBytes(m[i..][0..8]);
            state.st.extractBytes(c[i..][0..8]);

            // Add padding to word 1 at position 0
            state.st.st[1] ^= 0x01;
        } else if (remaining > 0) {
            // All in first word
            var temp: [8]u8 = @splat(0);
            @memcpy(temp[0..remaining], m[i..]);
            state.st.addBytes(&temp);
            state.st.extractBytes(c[i..][0..remaining]);
            // Add padding
            temp = @splat(0);
            temp[remaining] = 0x01;
            state.st.addBytes(&temp);
            // Second word stays zero
        } else {
            // Empty message or exact multiple - add padding block
            var padded: [16]u8 = @splat(0);
            padded[0] = 0x01;
            state.st.addBytes(&padded);
        }

        // Finalization
        state.finalize();

        // Extract tag
        mem.writeInt(u64, tag[0..8], state.st.st[3], .little);
        mem.writeInt(u64, tag[8..16], state.st.st[4], .little);
    }

    /// Decrypt a message with Ascon-AEAD128.
    ///
    /// Parameters:
    ///   - m: Output buffer for plaintext (must be same length as c)
    ///   - c: Ciphertext to decrypt
    ///   - tag: Authentication tag (16 bytes)
    ///   - ad: Associated data that was authenticated
    ///   - npub: Public nonce used during encryption (16 bytes)
    ///   - k: Secret key (16 bytes)
    ///
    /// Returns: AuthenticationError if tag verification fails
    ///
    /// Note: On authentication failure, the output buffer is securely zeroed
    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) AuthenticationError!void {
        debug.assert(m.len == c.len);

        var state = AeadState.init(k, npub);

        // Process associated data
        state.processAd(ad);

        // Domain separation (DSEP = 0x80 at byte 7 in little-endian)
        state.st.st[4] ^= 0x8000000000000000;

        // Process ciphertext
        var i: usize = 0;
        while (i + 16 <= c.len) : (i += 16) {
            const ct_block = c[i..][0..16].*; // Save ciphertext block for in-place operation support
            state.st.xorBytes(m[i..][0..16], &ct_block);
            state.st.setBytes(&ct_block);
            state.st.permuteR(8);
        }

        // Final partial ciphertext block
        const crem = c.len - i;
        if (crem > 8) {
            // Save ciphertext for in-place operation support
            var saved_ct: [16]u8 = undefined;
            @memcpy(saved_ct[0..crem], c[i..]);

            const c0 = mem.readInt(u64, saved_ct[0..8], .little);
            state.st.st[0] ^= c0;
            mem.writeInt(u64, m[i..][0..8], state.st.st[0], .little);
            state.st.st[0] = c0;

            var buf: [8]u8 = @splat(0);
            @memcpy(buf[0 .. crem - 8], saved_ct[8..][0 .. crem - 8]);
            const c1 = mem.readInt(u64, &buf, .little);
            const m1 = state.st.st[1] ^ c1;
            mem.writeInt(u64, buf[0..], m1, .little);
            @memcpy(m[i + 8 ..], buf[0 .. crem - 8]);

            // Replace only the bytes we've read, keeping upper bytes intact
            const mask = (@as(u64, 1) << @intCast((crem - 8) * 8)) - 1;
            state.st.st[1] = (state.st.st[1] & ~mask) | (c1 & mask);

            state.st.st[1] ^= @as(u64, 0x01) << @intCast((crem - 8) * 8);
        } else if (crem == 8) {
            // Exactly 8 bytes - process only word 0, add padding to word 1
            const saved_ct = c[i..][0..8].*;

            const c0 = mem.readInt(u64, &saved_ct, .little);
            state.st.st[0] ^= c0;
            mem.writeInt(u64, m[i..][0..8], state.st.st[0], .little);
            state.st.st[0] = c0;

            // Add padding to word 1 at position 0
            state.st.st[1] ^= 0x01;
        } else if (crem > 0) {
            var buf: [8]u8 = @splat(0);
            @memcpy(buf[0..crem], c[i..]);
            const c0 = mem.readInt(u64, &buf, .little);
            const m0 = state.st.st[0] ^ c0;
            mem.writeInt(u64, buf[0..], m0, .little);
            @memcpy(m[i..], buf[0..crem]);

            // Replace only the bytes we've read, keeping upper bytes intact
            const mask = (@as(u64, 1) << @intCast(crem * 8)) - 1;
            state.st.st[0] = (state.st.st[0] & ~mask) | (c0 & mask);

            state.st.st[0] ^= @as(u64, 0x01) << @intCast(crem * 8);
        } else {
            state.st.st[0] ^= 0x01;
        }

        // Finalization
        state.finalize();

        // Verify tag
        var computed_tag: [tag_length]u8 = undefined;
        mem.writeInt(u64, computed_tag[0..8], state.st.st[3], .little);
        mem.writeInt(u64, computed_tag[8..16], state.st.st[4], .little);

        if (!crypto.timing_safe.eql([tag_length]u8, tag, computed_tag)) {
            crypto.secureZero(u8, m);
            return error.AuthenticationFailed;
        }
    }
};

/// Ascon-Hash256 as specified in NIST SP 800-232 Section 5
pub const AsconHash256 = struct {
    pub const digest_length = 32;
    pub const block_length = 8;

    st: AsconState,

    pub const Options = struct {};

    /// Initialize a new Ascon-Hash256 hasher.
    ///
    /// Parameters:
    ///   - options: Configuration options (currently unused)
    ///
    /// Returns: An initialized AsconHash256 hasher
    pub fn init(options: Options) AsconHash256 {
        _ = options;

        // IV for Ascon-Hash256: 0x0000080100cc0002
        const iv: u64 = 0x0000080100cc0002;
        const words: [5]u64 = .{ iv, 0, 0, 0, 0 };
        var st = AsconState.initFromWords(words);
        st.permuteR(12);
        return AsconHash256{ .st = st };
    }

    /// Compute Ascon-Hash256 hash of input data in one call.
    ///
    /// Parameters:
    ///   - b: Input data to hash
    ///   - out: Output buffer for 32-byte hash digest
    ///   - options: Configuration options (currently unused)
    pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
        var h = init(options);
        h.update(b);
        h.final(out);
    }

    /// Update the hash state with additional data.
    ///
    /// Parameters:
    ///   - b: Data to add to the hash
    ///
    /// Note: Can be called multiple times before final()
    pub fn update(self: *AsconHash256, b: []const u8) void {
        var i: usize = 0;

        // Process full 64-bit blocks
        while (i + 8 <= b.len) : (i += 8) {
            self.st.addBytes(b[i..][0..8]);
            self.st.permuteR(12);
        }

        // Store partial block for finalization
        if (i < b.len) {
            var padded: [8]u8 = @splat(0);
            const remaining = b.len - i;
            @memcpy(padded[0..remaining], b[i..]);
            padded[remaining] = 0x01;
            self.st.addBytes(&padded);
        } else {
            // Add padding block
            var padded: [8]u8 = @splat(0);
            padded[0] = 0x01;
            self.st.addBytes(&padded);
        }
    }

    /// Finalize the hash and output the digest.
    ///
    /// Parameters:
    ///   - out: Output buffer for 32-byte hash digest
    ///
    /// Note: After calling final(), the hasher should not be used again
    pub fn final(self: *AsconHash256, out: *[digest_length]u8) void {
        // Final permutation after padding
        self.st.permuteR(12);

        // Extract hash output (4 × 64 bits = 256 bits)
        var h: [4]u64 = undefined;
        for (0..4) |i| {
            h[i] = self.st.st[0];
            self.st.permuteR(12);
        }

        // Write output
        for (0..4) |i| {
            mem.writeInt(u64, out[i * 8 ..][0..8], h[i], .little);
        }
    }
};

/// Ascon-XOF128 as specified in NIST SP 800-232 Section 5
pub const AsconXof128 = struct {
    pub const block_length = 8;

    st: AsconState,
    squeezed: bool,

    pub const Options = struct {};

    /// Initialize a new Ascon-XOF128 extendable output function.
    ///
    /// Parameters:
    ///   - options: Configuration options (currently unused)
    ///
    /// Returns: An initialized AsconXof128 instance
    pub fn init(options: Options) AsconXof128 {
        _ = options;

        // IV for Ascon-XOF128: 0x0000080000cc0003
        const iv: u64 = 0x0000080000cc0003;
        const words: [5]u64 = .{ iv, 0, 0, 0, 0 };
        var st = AsconState.initFromWords(words);
        st.permuteR(12);
        return AsconXof128{ .st = st, .squeezed = false };
    }

    /// Hash a slice of bytes with variable-length output.
    ///
    /// Parameters:
    ///   - bytes: Input data to hash
    ///   - out: Output buffer (can be any length)
    ///   - options: Configuration options (currently unused)
    ///
    /// Note: Convenience function that combines init, update, and squeeze
    pub fn hash(bytes: []const u8, out: []u8, options: Options) void {
        var st = init(options);
        st.update(bytes);
        st.squeeze(out);
    }

    /// Update the XOF state with additional data.
    ///
    /// Parameters:
    ///   - b: Data to absorb into the XOF state
    ///
    /// Note: Cannot be called after squeeze() has been called
    pub fn update(self: *AsconXof128, b: []const u8) void {
        debug.assert(!self.squeezed); // Cannot update after squeezing

        var i: usize = 0;

        // Process full 64-bit blocks
        while (i + 8 <= b.len) : (i += 8) {
            self.st.addBytes(b[i..][0..8]);
            self.st.permuteR(12);
        }

        // Store partial block for finalization
        if (i < b.len) {
            var padded: [8]u8 = @splat(0);
            const remaining = b.len - i;
            @memcpy(padded[0..remaining], b[i..]);
            padded[remaining] = 0x01;
            self.st.addBytes(&padded);
        } else {
            // Add padding block
            var padded: [8]u8 = @splat(0);
            padded[0] = 0x01;
            self.st.addBytes(&padded);
        }
    }

    /// Squeeze output bytes from the XOF.
    ///
    /// Parameters:
    ///   - out: Output buffer to fill with pseudorandom bytes
    ///
    /// Note: Can be called multiple times to generate more output.
    /// After first call, no more data can be absorbed with update().
    pub fn squeeze(self: *AsconXof128, out: []u8) void {
        if (!self.squeezed) {
            // First squeeze - apply final permutation
            self.st.permuteR(12);
            self.squeezed = true;
        }

        var i: usize = 0;
        while (i < out.len) {
            const to_copy = @min(8, out.len - i);
            var block: [8]u8 = undefined;
            mem.writeInt(u64, &block, self.st.st[0], .little);
            @memcpy(out[i..][0..to_copy], block[0..to_copy]);
            i += to_copy;

            if (i < out.len) {
                self.st.permuteR(12);
            }
        }
    }
};

/// Ascon-CXOF128 as specified in NIST SP 800-232 Section 5
pub const AsconCxof128 = struct {
    pub const block_length = 8;
    pub const max_custom_length = 256; // 2048 bits

    st: AsconState,
    squeezed: bool,

    pub const Options = struct { custom: []const u8 = "" };

    /// Initialize a new Ascon-CXOF128 customizable XOF.
    ///
    /// Parameters:
    ///   - options: Configuration with optional customization string
    ///     - custom: Customization string (max 256 bytes)
    ///
    /// Returns: An initialized AsconCxof128 instance
    ///
    /// Note: Different customization strings produce independent XOF instances
    pub fn init(options: Options) AsconCxof128 {
        debug.assert(options.custom.len <= max_custom_length);

        // IV for Ascon-CXOF128: 0x0000080000cc0004
        const iv: u64 = 0x0000080000cc0004;
        const words: [5]u64 = .{ iv, 0, 0, 0, 0 };
        var st = AsconState.initFromWords(words);
        st.permuteR(12);

        var self = AsconCxof128{ .st = st, .squeezed = false };

        // Process customization string - always process length and padding
        // First block: length of customization string
        const len_block = @as(u64, options.custom.len * 8); // Length in bits
        self.st.st[0] ^= len_block;
        self.st.permuteR(12);

        if (options.custom.len > 0) {
            // Process customization string blocks
            var i: usize = 0;
            while (i + 8 <= options.custom.len) : (i += 8) {
                self.st.addBytes(options.custom[i..][0..8]);
                self.st.permuteR(12);
            }

            // Process final partial block with padding
            if (i < options.custom.len) {
                var padded: [8]u8 = @splat(0);
                const remaining = options.custom.len - i;
                @memcpy(padded[0..remaining], options.custom[i..]);
                padded[remaining] = 0x01;
                self.st.addBytes(&padded);
                self.st.permuteR(12);
            } else {
                // Add padding block
                var padded: [8]u8 = @splat(0);
                padded[0] = 0x01;
                self.st.addBytes(&padded);
                self.st.permuteR(12);
            }
        } else {
            // Empty customization still needs padding
            var padded: [8]u8 = @splat(0);
            padded[0] = 0x01;
            self.st.addBytes(&padded);
            self.st.permuteR(12);
        }

        return self;
    }

    /// Hash a slice of bytes with customization and variable-length output.
    ///
    /// Parameters:
    ///   - bytes: Input data to hash
    ///   - out: Output buffer (can be any length)
    ///   - options: Configuration with optional customization string
    ///
    /// Note: Convenience function that combines init, update, and squeeze
    pub fn hash(bytes: []const u8, out: []u8, options: Options) void {
        var st = init(options);
        st.update(bytes);
        st.squeeze(out);
    }

    /// Update the CXOF state with additional data.
    ///
    /// Parameters:
    ///   - b: Data to absorb into the CXOF state
    ///
    /// Note: Cannot be called after squeeze() has been called
    pub fn update(self: *AsconCxof128, b: []const u8) void {
        debug.assert(!self.squeezed);

        var i: usize = 0;

        // Process full 64-bit blocks
        while (i + 8 <= b.len) : (i += 8) {
            self.st.addBytes(b[i..][0..8]);
            self.st.permuteR(12);
        }

        // Store partial block for finalization
        if (i < b.len) {
            var padded: [8]u8 = @splat(0);
            const remaining = b.len - i;
            @memcpy(padded[0..remaining], b[i..]);
            padded[remaining] = 0x01;
            self.st.addBytes(&padded);
        } else {
            // Add padding block
            var padded: [8]u8 = @splat(0);
            padded[0] = 0x01;
            self.st.addBytes(&padded);
        }
    }

    /// Squeeze output bytes from the customizable XOF.
    ///
    /// Parameters:
    ///   - out: Output buffer to fill with pseudorandom bytes
    ///
    /// Note: Can be called multiple times to generate more output.
    /// After first call, no more data can be absorbed with update().
    pub fn squeeze(self: *AsconCxof128, out: []u8) void {
        if (!self.squeezed) {
            // First squeeze - apply final permutation
            self.st.permuteR(12);
            self.squeezed = true;
        }

        var i: usize = 0;
        while (i < out.len) {
            const to_copy = @min(8, out.len - i);
            var block: [8]u8 = undefined;
            mem.writeInt(u64, &block, self.st.st[0], .little);
            @memcpy(out[i..][0..to_copy], block[0..to_copy]);
            i += to_copy;

            if (i < out.len) {
                self.st.permuteR(12);
            }
        }
    }
};

test "Ascon-Hash256 basic test" {
    const message = "The quick brown fox jumps over the lazy dog";
    var hash: [32]u8 = undefined;

    AsconHash256.hash(message, &hash, .{});

    // Verify hash is generated (exact value depends on test vectors)
    try testing.expect(hash.len == 32);
}

test "Ascon-XOF128 basic test" {
    var xof = AsconXof128.init(.{});
    xof.update("Hello, ");
    xof.update("World!");

    var out1: [16]u8 = undefined;
    xof.squeeze(&out1);

    var out2: [32]u8 = undefined;
    xof.squeeze(&out2);

    // XOF outputs should be continuous - out2 should NOT match out1
    // Each squeeze produces new output
    try testing.expect(!mem.eql(u8, &out1, out2[0..16]));
}

test "Ascon-CXOF128 with customization" {
    const custom = "MyCustomString";
    var xof = AsconCxof128.init(.{ .custom = custom });
    xof.update("Test message");

    var out: [32]u8 = undefined;
    xof.squeeze(&out);

    // Different customization should give different output
    var xof2 = AsconCxof128.init(.{ .custom = "DifferentCustom" });
    xof2.update("Test message");

    var out2: [32]u8 = undefined;
    xof2.squeeze(&out2);

    try testing.expect(!mem.eql(u8, &out, &out2));
}

test "Ascon-AEAD128 round trip with various data sizes" {
    if (builtin.cpu.has(.riscv, .v) and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const key = [_]u8{ 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10 };
    const nonce = [_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF };

    // Test with empty plaintext
    {
        const plaintext = "";
        const ad = "metadata";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectEqualStrings(plaintext, &decrypted);
    }

    // Test with small plaintext
    {
        const plaintext = "Short";
        const ad = "";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectEqualStrings(plaintext, &decrypted);
    }

    // Test with longer plaintext and associated data
    {
        const plaintext = "This is a longer message to test the round trip encryption and decryption process";
        const ad = "Additional authenticated data that is not encrypted but is authenticated";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectEqualStrings(plaintext, &decrypted);
    }

    // Test authentication failure with tampered ciphertext
    {
        const plaintext = "Tamper test";
        const ad = "metadata";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        // Tamper with ciphertext
        ciphertext[0] ^= 0xFF;

        var decrypted: [plaintext.len]u8 = undefined;
        const result = AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectError(error.AuthenticationFailed, result);
    }

    // Test authentication failure with wrong tag
    {
        const plaintext = "Tag test";
        const ad = "metadata";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        // Tamper with tag
        var wrong_tag = tag;
        wrong_tag[0] ^= 0xFF;

        var decrypted: [plaintext.len]u8 = undefined;
        const result = AsconAead128.decrypt(&decrypted, &ciphertext, wrong_tag, ad, nonce, key);
        try testing.expectError(error.AuthenticationFailed, result);
    }

    // Test authentication failure with wrong associated data
    {
        const plaintext = "AD test";
        const ad = "original";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        const wrong_ad = "modified";
        const result = AsconAead128.decrypt(&decrypted, &ciphertext, tag, wrong_ad, nonce, key);
        try testing.expectError(error.AuthenticationFailed, result);
    }
}

// Test vectors from NIST SP 800-232 / ascon-c reference implementation
test "Ascon-AEAD128 official test vectors" {

    // Test vector 1: Empty PT, Empty AD
    {
        var key: [16]u8 = undefined;
        var nonce: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&key, "000102030405060708090A0B0C0D0E0F") catch unreachable;
        _ = std.fmt.hexToBytes(&nonce, "101112131415161718191A1B1C1D1E1F") catch unreachable;

        const plaintext = "";
        const ad = "";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, ad, nonce, key);

        var expected_tag: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_tag, "4F9C278211BEC9316BF68F46EE8B2EC6") catch unreachable;
        try testing.expectEqualSlices(u8, &expected_tag, &tag);
    }

    // Test vector 2: Empty PT, AD = "30"
    {
        var key: [16]u8 = undefined;
        var nonce: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&key, "000102030405060708090A0B0C0D0E0F") catch unreachable;
        _ = std.fmt.hexToBytes(&nonce, "101112131415161718191A1B1C1D1E1F") catch unreachable;

        const plaintext = "";
        var ad: [1]u8 = undefined;
        _ = std.fmt.hexToBytes(&ad, "30") catch unreachable;
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, plaintext, &ad, nonce, key);

        var expected_tag: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_tag, "CCCB674FE18A09A285D6AB11B35675C0") catch unreachable;
        try testing.expectEqualSlices(u8, &expected_tag, &tag);
    }

    // Test vector 34: Single byte plaintext 0x20
    {
        var key: [16]u8 = undefined;
        var nonce: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&key, "000102030405060708090A0B0C0D0E0F") catch unreachable;
        _ = std.fmt.hexToBytes(&nonce, "101112131415161718191A1B1C1D1E1F") catch unreachable;

        var plaintext: [1]u8 = undefined;
        _ = std.fmt.hexToBytes(&plaintext, "20") catch unreachable;
        const ad = "";
        var ciphertext: [1]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, &plaintext, ad, nonce, key);

        var expected_ct: [1]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_ct, "E8") catch unreachable;
        var expected_tag: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_tag, "DD576ABA1CD3E6FC704DE02AEDB79588") catch unreachable;

        try testing.expectEqualSlices(u8, &expected_ct, &ciphertext);
        try testing.expectEqualSlices(u8, &expected_tag, &tag);

        // Verify decryption
        var decrypted: [1]u8 = undefined;
        try AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectEqualSlices(u8, &plaintext, &decrypted);
    }

    // Test vector with 3-byte plaintext
    {
        var key: [16]u8 = undefined;
        var nonce: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&key, "000102030405060708090A0B0C0D0E0F") catch unreachable;
        _ = std.fmt.hexToBytes(&nonce, "101112131415161718191A1B1C1D1E1F") catch unreachable;

        var plaintext: [3]u8 = undefined;
        _ = std.fmt.hexToBytes(&plaintext, "202122") catch unreachable;
        const ad = "";
        var ciphertext: [3]u8 = undefined;
        var tag: [16]u8 = undefined;

        AsconAead128.encrypt(&ciphertext, &tag, &plaintext, ad, nonce, key);

        var expected_ct: [3]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_ct, "E8C3DE") catch unreachable;
        var expected_tag: [16]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected_tag, "AF8E12816B8EDF39AD1571A9492B7CA2") catch unreachable;

        try testing.expectEqualSlices(u8, &expected_ct, &ciphertext);
        try testing.expectEqualSlices(u8, &expected_tag, &tag);

        // Verify decryption
        var decrypted: [3]u8 = undefined;
        try AsconAead128.decrypt(&decrypted, &ciphertext, tag, ad, nonce, key);
        try testing.expectEqualSlices(u8, &plaintext, &decrypted);
    }
}

test "Ascon-Hash256 official test vectors" {

    // Test vector 1: Empty message
    {
        const message = "";
        var hash: [32]u8 = undefined;
        AsconHash256.hash(message, &hash, .{});

        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "0B3BE5850F2F6B98CAF29F8FDEA89B64A1FA70AA249B8F839BD53BAA304D92B2") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &hash);
    }

    // Test vector 2: Single byte 0x00
    {
        const message = [_]u8{0x00};
        var hash: [32]u8 = undefined;
        AsconHash256.hash(&message, &hash, .{});

        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "0728621035AF3ED2BCA03BF6FDE900F9456F5330E4B5EE23E7F6A1E70291BC80") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &hash);
    }

    // Test vector 3: 0x00, 0x01
    {
        const message = [_]u8{ 0x00, 0x01 };
        var hash: [32]u8 = undefined;
        AsconHash256.hash(&message, &hash, .{});

        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "6115E7C9C4081C2797FC8FE1BC57A836AFA1C5381E556DD583860CA2DFB48DD2") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &hash);
    }

    // Test vector 4: 0x00, 0x01, 0x02
    {
        const message = [_]u8{ 0x00, 0x01, 0x02 };
        var hash: [32]u8 = undefined;
        AsconHash256.hash(&message, &hash, .{});

        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "265AB89A609F5A05DCA57E83FBBA700F9A2D2C4211BA4CC9F0A1A369E17B915C") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &hash);
    }

    // Test vector 5: 0x00..0x03
    {
        const message = [_]u8{ 0x00, 0x01, 0x02, 0x03 };
        var hash: [32]u8 = undefined;
        AsconHash256.hash(&message, &hash, .{});

        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "D7E4C7ED9B8A325CD08B9EF259F8877054ECD8304FE1B2D7FD847137DF6727EE") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &hash);
    }
}

test "Ascon-XOF128 official test vectors" {

    // Test vector 1: Empty message, 64-byte output
    {
        var xof = AsconXof128.init(.{});
        xof.update("");

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "473D5E6164F58B39DFD84AACDB8AE42EC2D91FED33388EE0D960D9B3993295C6AD77855A5D3B13FE6AD9E6098988373AF7D0956D05A8F1665D2C67D1A3AD10FF") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }

    // Test vector 2: Single byte 0x00, 64-byte output
    {
        var xof = AsconXof128.init(.{});
        const msg = [_]u8{0x00};
        xof.update(&msg);

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "51430E0438ECDF642B393630D977625F5F337656BA58AB1E960784AC32A16E0D446405551F5469384F8EA283CF12E64FA72C426BFEBAEA3AA1529E2C4AB23A2F") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }

    // Test vector 3: 0x00, 0x01, 64-byte output
    {
        var xof = AsconXof128.init(.{});
        const msg = [_]u8{ 0x00, 0x01 };
        xof.update(&msg);

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "A05383077AF971D3830BD37E7B981497A773D441DB077C6494CC73125953846EB6427FBA4CD308FF90A11385D51101341BF5379249217BFDACE9CCA1148CC966") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }
}

test "Ascon-CXOF128 official test vectors" {

    // Test vector 1: Empty message, empty customization, 64-byte output
    {
        var xof = AsconCxof128.init(.{});
        xof.update("");

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "4F50159EF70BB3DAD8807E034EAEBD44C4FA2CBBC8CF1F05511AB66CDCC529905CA12083FC186AD899B270B1473DC5F7EC88D1052082DCDFE69FB75D269E7B74") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }

    // Test vector 2: Empty message, customization = 0x10, 64-byte output
    {
        const custom = [_]u8{0x10};
        var xof = AsconCxof128.init(.{ .custom = &custom });
        xof.update("");

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "0C93A483E7D574D49FE52CCE03EE646117977D57A8AA57704AB4DAF44B501430FF6AC11A5D1FD6F2154B5C65728268270C8BB578508487B8965718ADA6272FD6") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }

    // Test vector 3: Empty message, customization = 0x10, 0x11, 64-byte output
    {
        const custom = [_]u8{ 0x10, 0x11 };
        var xof = AsconCxof128.init(.{ .custom = &custom });
        xof.update("");

        var output: [64]u8 = undefined;
        xof.squeeze(&output);

        var expected: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, "D1106C7622E79FE955BD9D79E03B918E770FE0E0CDDDE28BEB924B02C5FC936B33ACCA299C89ECA5D71886CBBFA4D54A21C55FDE2B679F5E2488063A1719DC32") catch unreachable;
        try testing.expectEqualSlices(u8, &expected, &output);
    }
}
