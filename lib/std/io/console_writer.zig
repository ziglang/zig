const std = @import("std");
const fifo = std.fifo;
const io = std.io;
const os = std.os;
const unicode = std.unicode;

const File = std.fs.File;

pub fn ConsoleWriter(comptime u16_max_buffer_size: usize) type {
    return struct {
        const Self = @This();
        pub const Error = os.WriteError || error{InvalidUtf8};
        pub const Writer = io.Writer(*Self, Error, write);

        handle: os.fd_t = undefined,

        pub fn isTty(self: Self) bool {
            return os.isatty(self.handle);
        }

        pub fn supportsAnsiEscapeCodes(self: Self) bool {
            return os.isCygwinPty(self.handle);
        }

        pub fn write(self: *Self, data: []const u8) Error!usize {
            if (data.len == 0) return @as(usize, 0);

            if (!os.isatty(self.handle)) {
                // Non console handles should go straight to reading like a file
                // Examples of this happening are when pipes are used as indicated in the docs
                // https://docs.microsoft.com/en-us/windows/console/writeconsole
                return os.windows.WriteFile(self.handle, data, null, .blocking);
            }

            var utf16 = [_]u16{0} ** u16_max_buffer_size;
            const max_data_len = unicode.getClampedUtf8SizeForUtf16LeSize(data, utf16.len) catch return Error.InvalidUtf8;
            const n = unicode.utf8ToUtf16Le(utf16[0..], data[0..max_data_len]) catch return Error.InvalidUtf8;
            const m = try os.windows.WriteConsoleW(self.handle, utf16[0..n]);

            if (n != m) {
                // If the number of u16s don't match between converted utf8 chars and what's written to console,
                // We need to calculate the number of bytes written provided from Windows.
                return unicode.getClampedUtf8SizeForUtf16LeSize(data, m) catch unreachable;
            }
            return max_data_len;
        }

        pub fn writeAll(self: *Self, bytes: []const u8) Error!void {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try self.write(bytes[index..]);
            }
        }

        pub fn writeFileAll(self: *Self, in_file: File, args: File.WriteFileOptions) File.WriteFileError!void {
            return (File{ .handle = self.handle }).writeFileAll(in_file, args);
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}
