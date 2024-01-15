const builtin = @import("builtin");
const std = @import("../std.zig");

/// A protocol is an interface identified by a GUID.
pub const protocol = @import("uefi/protocol.zig");
pub const hii = @import("uefi/hii.zig");
pub const bits = @import("uefi/bits.zig");

/// Status codes returned by EFI interfaces
pub const Status = @import("uefi/status.zig").Status;
pub const table = @import("uefi/table.zig");

const allocator = @import("uefi/allocator.zig");
pub const PageAllocator = allocator.PageAllocator;
pub const PoolAllocator = allocator.PoolAllocator;
pub const RawPoolAllocator = allocator.RawPoolAllocator;

/// The EFI image's handle that is passed to its entry point.
pub var handle: bits.Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *table.System = undefined;

pub const fd_t = union(enum) {
    file: *const protocol.File,
    simple_output: *const protocol.SimpleTextOutput,
    simple_input: *const protocol.SimpleTextInput,
};

pub fn close(fd: fd_t) void {
    switch (fd) {
        .file => |p| p.close(fd.file),
        .simple_output => |p| p.reset(true) catch {},
        .simple_input => |p| p.reset(true) catch {},
    }
}

pub fn read(fd: fd_t, buf: []u8) std.os.ReadError!usize {
    switch (fd) {
        .file => |p| {
            return p.read(fd.file, buf) catch |err| switch (err) {
                error.NoMedia => return error.InputOutput,
                error.DeviceError => return error.InputOutput,
                error.VolumeCorrupted => return error.InputOutput,
                else => return error.Unexpected,
            };
        },
        .simple_input => |p| {
            var index: usize = 0;
            while (index == 0) {
                while (p.readKeyStroke() catch |err| switch (err) {
                    error.DeviceError => return error.InputOutput,
                    else => return error.Unexpected,
                }) |key| {
                    if (key.unicodeChar != 0) {
                        // this definitely isn't the right way to handle this, and it may fail on towards the limit of a single utf16 item.
                        index += std.unicode.utf16leToUtf8(buf, &.{key.unicode_char}) catch continue;
                    }
                }
            }
            return @intCast(index);
        },
        else => return error.NotOpenForReading, // cannot read
    }
}

pub fn write(fd: fd_t, buf: []const u8) std.os.WriteError!usize {
    switch (fd) {
        .file => |p| {
            return p.write(fd.file, buf) catch |err| switch (err) {
                error.Unsupported => return error.NotOpenForWriting,
                error.NoMedia => return error.InputOutput,
                error.DeviceError => return error.InputOutput,
                error.VolumeCorrupted => return error.InputOutput,
                error.WriteProtected => return error.NotOpenForWriting,
                error.AccessDenied => return error.AccessDenied,
                else => return error.Unexpected,
            };
        },
        .simple_output => |p| {
            const view = std.unicode.Utf8View.init(buf) catch unreachable;
            var iter = view.iterator();

            // rudimentary utf16 writer
            var index: usize = 0;
            var utf16: [256]u16 = undefined;
            while (iter.nextCodepoint()) |rune| {
                if (index + 1 >= utf16.len) {
                    utf16[index] = 0;
                    p.outputString(utf16[0..index :0]) catch |err| switch (err) {
                        error.DeviceError => return error.InputOutput,
                        error.Unsupported => return error.NotOpenForWriting,
                        else => return error.Unexpected,
                    };
                    index = 0;
                }

                if (rune < 0x10000) {
                    utf16[index] = rune;
                    index += 1;
                } else {
                    const high = @as(u16, @intCast((rune - 0x10000) >> 10)) + 0xD800;
                    const low = @as(u16, @intCast(rune & 0x3FF)) + 0xDC00;
                    switch (builtin.cpu.arch.endian()) {
                        .little => {
                            utf16[index] = high;
                            utf16[index] = low;
                        },
                        .big => {
                            utf16[index] = low;
                            utf16[index] = high;
                        },
                    }
                    index += 2;
                }
            }

            if (index != 0) {
                utf16[index] = 0;
                p.outputString(utf16[0..index :0]) catch |err| switch (err) {
                    error.DeviceError => return error.InputOutput,
                    error.Unsupported => return error.NotOpenForWriting,
                    else => return error.Unexpected,
                };
            }

            return @intCast(buf.len);
        },
        else => return error.NotOpenForWriting, // cannot write
    }
}

test {
    _ = table;
    _ = protocol;
}
