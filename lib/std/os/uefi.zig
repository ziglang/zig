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
pub var global_pool_allocator = PoolAllocator{};

/// The EFI image's handle that is passed to its entry point.
pub var handle: bits.Handle = undefined;

/// A pointer to the EFI System Table that is passed to the EFI image's entry point.
pub var system_table: *table.System = undefined;

pub var working_directory: fd_t = .none;

pub const posix = @import("uefi/posix.zig");

pub const fd_t = posix.fd_t;
pub const ino_t = posix.ino_t;
pub const mode_t = posix.mode_t;

pub const timespec = posix.timespec;
pub const utsname = posix.utsname;
pub const Stat = posix.Stat;

pub const AT = posix.AT;
pub const CLOCK = posix.CLOCK;
pub const LOCK = posix.LOCK;
pub const NAME_MAX = posix.NAME_MAX;
pub const O = posix.O;
pub const PATH_MAX = posix.PATH_MAX;
pub const PATH_MAX_WIDE = posix.PATH_MAX_WIDE;
pub const S = posix.S;

pub const F_OK = posix.F_OK;
pub const R_OK = posix.R_OK;
pub const W_OK = posix.W_OK;

pub fn cwd() fd_t {
    if (system_table.boot_services) |boot_services| blk: {
        const loaded_image = boot_services.openProtocol(handle, protocol.LoadedImage, .{}) catch break :blk;

        const file_path = if (loaded_image.file_path.node()) |node| file_path: {
            if (node == .media and node.media == .file_path)
                break :file_path node.media.file_path.path();

            break :blk;
        } else break :blk;

        if (file_path.len + 4 > posix.PATH_MAX) break :blk;

        // required because device paths are not aligned
        var path_buffer: [posix.PATH_MAX]u16 = undefined;
        @memcpy(path_buffer[0..file_path.len], file_path);
        path_buffer[file_path.len] = '\\';
        path_buffer[file_path.len + 1] = '.';
        path_buffer[file_path.len + 2] = '.';
        path_buffer[file_path.len + 3] = 0;

        const file_system = boot_services.openProtocol(loaded_image.device_handle.?, protocol.SimpleFileSystem, .{}) catch break :blk;

        const volume = file_system.openVolume() catch break :blk;
        return .{ .file = volume.open(path_buffer[0 .. file_path.len + 3 :0], .{}, .{}) catch break :blk };
    }

    return .none;
}

pub const ListEntry = struct {
    forward_link: ?*ListEntry,
    backward_link: ?*ListEntry,
};

const uctx = @import("uefi/ucontext.zig");
pub const getcontext = uctx.getcontext;
pub const ucontext_t = uctx.ucontext_t;
pub const REG = uctx.REG;

test {
    _ = table;
    _ = protocol;
}
