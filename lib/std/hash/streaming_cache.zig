const std = @import("std");

/// Abstracts buffer management for unaligned input blocks for hash and crypto functions.
pub fn StreamingCache(comptime round_length: usize) type {
    return struct {
        buf: [round_length]u8 = undefined,
        buf_len: usize = 0,

        pub fn update(self: *@This(), context: anytype, round_fn: anytype, input: []const u8) void {
            if (input.len < round_length - self.buf_len) {
                @memcpy(self.buf[self.buf_len..][0..input.len], input);
                self.buf_len += input.len;
                return;
            }

            var i: usize = 0;

            if (self.buf_len > 0) {
                i = round_length - self.buf_len;
                @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
                round_fn(context, &self.buf);
                self.buf_len = 0;
            }

            while (i + round_length <= input.len) : (i += round_length) {
                round_fn(context, input[i..][0..round_length]);
            }

            const remaining_bytes = input[i..];
            @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
            self.buf_len = remaining_bytes.len;
        }
    };
}
