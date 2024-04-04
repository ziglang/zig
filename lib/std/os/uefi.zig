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

pub var global_page_allocator = PageAllocator{};

/// The EFI image's handle that is passed to its entry point.
pub var handle: bits.Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *table.System = undefined;

pub var working_directory: fd_t = .none;

pub const ino_t = u64;
pub const mode_t = u64;

pub const fd_t = union(enum) {
    file: *const protocol.File,
    simple_output: *const protocol.SimpleTextOutput,
    simple_input: *const protocol.SimpleTextInput,
    none: void, // used to refer to a file descriptor that is not open and cannot do anything
    cwd: void, // used to refer to the current working directory
};

fn unexpectedError(err: anyerror) error{Unexpected} {
    std.log.err("unexpected error: {}\n", .{err});
    return error.Unexpected;
}

pub fn cwd() fd_t {
    const uefi = std.os.uefi;

    if (uefi.system_table.boot_services) |boot_services| blk: {
        const loaded_image = boot_services.openProtocol(uefi.handle, uefi.protocol.LoadedImage, .{}) catch break :blk;

        const file_path = if (loaded_image.file_path.node()) |node| file_path: {
            if (node == .media and node.media == .file_path)
                break :file_path node.media.file_path.path();

            break :blk;
        } else break :blk;

        if (file_path.len + 4 > std.fs.max_path_bytes) break :blk;

        // required because device paths are not aligned
        var path_buffer: [std.fs.max_path_bytes]u16 = undefined;
        @memcpy(path_buffer[0..file_path.len], file_path);
        path_buffer[file_path.len] = '\\';
        path_buffer[file_path.len + 1] = '.';
        path_buffer[file_path.len + 2] = '.';
        path_buffer[file_path.len + 3] = 0;

        const file_system = boot_services.openProtocol(loaded_image.device_handle.?, uefi.protocol.SimpleFileSystem, .{}) catch break :blk;

        const volume = file_system.openVolume() catch break :blk;
        return .{ .file = volume.open(path_buffer[0 .. file_path.len + 3 :0], .{}, .{}) catch break :blk };
    }

    return .none;
}

pub fn close(fd: fd_t) void {
    switch (fd) {
        .file => |p| p.close(),
        .simple_output => |p| p.reset(true) catch {},
        .simple_input => |p| p.reset(true) catch {},
        .none => {},
        .cwd => {},
    }
}

pub fn openat(dirfd: fd_t, path: [:0]const u16, flags: protocol.File.OpenMode) !fd_t {
    switch (dirfd) {
        .file => |p| {
            const fd = p.open(path, flags, .{}) catch |err| switch (err) {
                error.NotFound => return error.FileNotFound,
                error.NoMedia => return error.NoDevice,
                error.MediaChanged => return error.NoDevice,
                error.DeviceError => return error.NoDevice,
                error.VolumeCorrupted => return error.NoDevice,
                error.WriteProtected => return error.AccessDenied,
                error.AccessDenied => return error.AccessDenied,
                error.OutOfResources => return error.SystemResources,
                error.InvalidParameter => return error.FileNotFound,
                else => |e| return unexpectedError(e),
            };
            return .{ .file = fd };
        },
        .simple_output => return error.NotDir,
        .simple_input => return error.NotDir,
        .none => return error.NotDir,
        .cwd => return openat(working_directory, path, flags),
    }
}

pub fn read(fd: fd_t, buf: []u8) std.posix.ReadError!usize {
    switch (fd) {
        .file => |p| {
            return p.read(buf) catch |err| switch (err) {
                error.NoMedia => return error.InputOutput,
                error.DeviceError => return error.InputOutput,
                error.VolumeCorrupted => return error.InputOutput,
                else => |e| return unexpectedError(e),
            };
        },
        .simple_input => |p| {
            var index: usize = 0;
            while (index == 0) {
                while (p.readKeyStroke() catch |err| switch (err) {
                    error.DeviceError => return error.InputOutput,
                    else => |e| return unexpectedError(e),
                }) |key| {
                    if (key.unicode_char != 0) {
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

pub fn write(fd: fd_t, buf: []const u8) std.posix.WriteError!usize {
    switch (fd) {
        .file => |p| {
            return p.write(buf) catch |err| switch (err) {
                error.Unsupported => return error.NotOpenForWriting,
                error.NoMedia => return error.InputOutput,
                error.DeviceError => return error.InputOutput,
                error.VolumeCorrupted => return error.InputOutput,
                error.WriteProtected => return error.NotOpenForWriting,
                error.AccessDenied => return error.AccessDenied,
                else => |e| return unexpectedError(e),
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
                    if (rune == '\n') {
                        utf16[index] = '\r';
                        index += 1;
                    }

                    utf16[index] = @intCast(rune);
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

pub fn getFileEndPosition(fd: fd_t) !u64 {
    switch (fd) {
        .file => |p| {
            return p.getEndPosition() catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn getFilePosition(fd: fd_t) !u64 {
    switch (fd) {
        .file => |p| {
            return p.getPosition() catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub fn setFilePosition(fd: fd_t, pos: u64) !void {
    switch (fd) {
        .file => |p| {
            return p.setPosition(pos) catch return error.Unseekable;
        },
        else => return error.Unseekable, // cannot read
    }
}

pub const PATH_MAX = 8192;

pub const O = packed struct {
    ACCMODE: std.posix.ACCMODE = .RDONLY,
    NONBLOCK: bool = false,
    CLOEXEC: bool = false,
    CREAT: bool = false,
    TRUNC: bool = false,
};

pub const AT = struct {
    pub const FDCWD: fd_t = .cwd;
};

test {
    _ = table;
    _ = protocol;
}
