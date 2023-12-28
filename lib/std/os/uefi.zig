const builtin = @import("builtin");
const std = @import("../std.zig");

/// A protocol is an interface identified by a GUID.
pub const protocol = @import("uefi/protocol.zig");
pub const hii = @import("uefi/hii.zig");
pub const bits = @import("uefi/bits.zig");

/// Status codes returned by EFI interfaces
pub const Status = @import("uefi/status.zig").Status;
pub const table = @import("uefi/table.zig");

/// The memory type to allocate when using the pool
/// Defaults to .LoaderData, the default data allocation type
/// used by UEFI applications to allocate pool memory.
pub var efi_pool_memory_type: bits.MemoryDescriptor.Type = .LoaderData;
pub const pool_allocator = @import("uefi/pool_allocator.zig").pool_allocator;
pub const raw_pool_allocator = @import("uefi/pool_allocator.zig").raw_pool_allocator;

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

pub const ReadError = Status.EfiError;

pub fn read(fd: fd_t, buf: []u8) ReadError!usize {
    switch (fd) {
        .file => |p| p.read(fd.file, buf),
        .simple_input => |p| {
            var index: usize = 0;
            while (index == 0) {
                while (try p.readKeyStroke()) |key| {
                    if (key.unicodeChar != 0) {
                        index += try std.unicode.utf16leToUtf8(buf, &.{key.unicode_char});
                    }
                }
            }
            return index;
        },
        else => return error.EndOfFile,
    }
}

pub const WriteError = Status.EfiError || error{InvalidUtf8};

pub fn write(fd: fd_t, buf: []const u8) WriteError!usize {
    switch (fd) {
        .file => |p| p.write(fd.file, buf),
        .simple_output => |p| {
            const view = try std.unicode.Utf8View.init(buf);
            var iter = view.iterator();

            // rudimentary utf16 writer
            var index: usize = 0;
            var utf16: [256]u16 = undefined;
            while (iter.nextCodepoint()) |rune| {
                if (index + 1 >= utf16.len) {
                    utf16[index] = 0;
                    try p.outputString(utf16[0..index :0]);
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
                try p.outputString(utf16[0..index :0]);
            }
        },
        else => return error.EndOfFile,
    }
}

test {
    _ = table;
    _ = protocol;
}
