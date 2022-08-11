const std = @import("std");
const fifo = std.fifo;
const io = std.io;
const math = std.math;
const os = std.os;
const unicode = std.unicode;

pub fn ConsoleReader(comptime u16_max_buffer_size: usize) type {
    return struct {
        const Self = @This();
        const FifoType = fifo.LinearFifo(u8, fifo.LinearFifoBufferType{ .Static = 4 });
        pub const Error = os.ReadError || error{InvalidUTF16LE};
        pub const Reader = io.Reader(*Self, Error, read);

        handle: os.fd_t,
        surrogate: ?u16 = null,
        fifo_utf8: FifoType = FifoType.init(),

        pub fn read(self: *Self, dest: []u8) Error!usize {
            if (!os.isatty(self.handle)) {
                // Non console handles should go straight to reading like a file
                // Examples of this happening are when pipes are used as indicated in the docs
                // https://docs.microsoft.com/en-us/windows/console/readconsole
                return os.windows.ReadFile(self.handle, dest, null, .blocking);
            }

            var dest_index: usize = 0;
            while (dest_index < dest.len) {
                // Read from a utf8 buffer for any potential missing bytes needed for a codepoint
                const written = self.fifo_utf8.read(dest[dest_index..]);
                if (written != 0) {
                    dest_index += written;
                    continue;
                }
                const delta_len = dest.len - dest_index;
                if (delta_len < 4) {
                    // Not enough room is left in the destination buffer to handle larger codepoint lengths
                    // Read a character at a time and place the encoding utf8 bytes into a fifo buffer
                    self.fifo_utf8.realign();
                    const n = try self.readConsoleToUtf8(self.fifo_utf8.writableSlice(0), 1);
                    if (n == 0) return dest_index;
                    self.fifo_utf8.update(n);
                } else {
                    const n = try self.readConsoleToUtf8(dest[delta_len..], u16_max_buffer_size);
                    if (n == 0) return dest_index;
                    dest_index += n;
                }
            }
            return dest.len;
        }

        fn readConsoleToUtf8(self: *Self, dest: []u8, comptime u16_buffer_size: usize) Error!usize {
            var utf16_buffer: [u16_buffer_size]u16 = undefined;
            const end = if (u16_buffer_size > 1) math.min(dest.len / 3, u16_buffer_size) else u16_buffer_size;

            const n = try self.readConsole(utf16_buffer[0..end]);
            if (n == 0) return n;

            return unicode.utf16leToUtf8(dest, utf16_buffer[0..n]) catch return Error.InvalidUTF16LE;
        }

        fn readConsole(self: *Self, buffer: []u16) Error!usize {
            if (buffer.len == 0) return 0;
            var start: usize = 0;
            if (self.surrogate != null) {
                buffer[0] = self.surrogate.?;
                self.surrogate = null;
                start = 1;
            }

            var n = try os.windows.ReadConsoleW(self.handle, buffer[start..], null);

            if (n > 0) {
                const last_char = buffer[n - 1];
                if (0xd800 <= last_char and last_char <= 0xdfff) {
                    self.surrogate = last_char;
                    n -= 1;
                }
            }
            return n;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}
