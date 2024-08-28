//! A cross-platform abstraction for memory-mapping files.
//!
//! The API here implements the common subset of functionality present in the supported operating
//! systems. Presently, Windows and all POSIX environments are supported.
//!
//! Operating system specific behavior is intended to be minimized; however, the following leak
//! through the abstraction:
//!
//! - Child processes sharing:
//!   - POSIX: Shared with child processes upon `fork` and unshared upon `exec*`.
//!   - Windows: Not shared with child processes.

const std = @import("../std.zig");
const builtin = @import("builtin");

const MemoryMap = @This();

/// An OS-specific reference to a kernel object for this mapping.
handle: switch (builtin.os.tag) {
    .windows => std.os.windows.HANDLE,
    else => void,
},
/// The region of virtual memory in which the file is mapped.
///
/// Accesses to this are subject to the protection semantics specified upon
/// initialization of the mapping. Failure to abide by those semantics has undefined
/// behavior (though should be well-defined by the OS).
mapped: []align(std.mem.page_size) volatile u8,

test MemoryMap {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("mmap.bin", .{
        .exclusive = true,
        .truncate = true,
        .read = true,
    });
    defer file.close();

    const magic = "\xde\xca\xfb\xad";
    try file.writeAll(magic);

    const len = try file.getEndPos();

    var view = try MemoryMap.init(file, .{ .length = @intCast(len) });
    defer view.deinit();

    try std.testing.expectEqualSlices(u8, magic, @volatileCast(view.mapped));
}

pub const InitOptions = struct {
    protection: ProtectionFlags = .{},
    /// Whether changes to the memory-mapped region should be propogated into the backing file.
    ///
    /// This only refers to the exclusivity of the memory-mapped region with respect to *other*
    /// instances of `MemoryMap` of that same file. A single `MemoryMap` instance can be shared
    /// within a process regardless of this option. Whether a single `MemoryMap` instance is shared
    /// with child processes is operating system specific and independent of this option.
    exclusivity: Exclusivity = .private,
    /// The desired length of the mapping.
    ///
    /// The backing file must be of at least `offset + length` size.
    length: usize,
    /// The desired offset of the mapping.
    ///
    /// The backing file must be of at least `offset` size.
    offset: usize = 0,
    hint: ?[*]align(std.mem.page_size) u8 = null,
};

/// A description of OS protections to be applied to a memory-mapped region.
pub const ProtectionFlags = struct {
    write: bool = false,
    execute: bool = false,
};

pub const Exclusivity = enum {
    /// The file's content may be read or written by external processes.
    shared,
    /// The file's content is exclusive to this process.
    private,
};

/// Create a memory-mapped view into `file`.
///
/// Asserts `opts.length` is non-zero.
pub fn init(file: std.fs.File, opts: InitOptions) !MemoryMap {
    std.debug.assert(opts.length > 0);
    switch (builtin.os.tag) {
        .wasi => @compileError("MemoryMap not supported on WASI OS; see also " ++
            "https://github.com/WebAssembly/WASI/issues/304"),
        .windows => {
            // Create the kernel resource for the memory mapping.
            var access: std.os.windows.ACCESS_MASK =
                std.os.windows.STANDARD_RIGHTS_REQUIRED |
                std.os.windows.SECTION_QUERY |
                std.os.windows.SECTION_MAP_READ;
            var page_attributes: std.os.windows.ULONG = 0;
            if (opts.protection.execute) {
                access |= std.os.windows.SECTION_MAP_EXECUTE;
                if (opts.protection.write) {
                    access |= std.os.windows.SECTION_MAP_WRITE;
                    page_attributes = switch (opts.exclusivity) {
                        .shared => std.os.windows.PAGE_EXECUTE_READWRITE,
                        .private => std.os.windows.PAGE_EXECUTE_WRITECOPY,
                    };
                } else {
                    page_attributes = std.os.windows.PAGE_EXECUTE_READ;
                }
            } else {
                if (opts.protection.write) {
                    access |= std.os.windows.SECTION_MAP_WRITE;
                    page_attributes = switch (opts.exclusivity) {
                        .shared => std.os.windows.PAGE_READWRITE,
                        .private => std.os.windows.PAGE_WRITECOPY,
                    };
                } else {
                    page_attributes = std.os.windows.PAGE_READONLY;
                }
            }
            const handle = try std.os.windows.CreateSection(.{
                .file = file.handle,
                .access = access,
                .size = opts.length,
                .page_attributes = page_attributes,
            });
            errdefer std.os.windows.CloseHandle(handle);

            // Create the mapping.
            const mapped = try std.os.windows.MapViewOfSection(handle, .{
                .inheritance = .ViewUnmap,
                .protection = page_attributes,
                .offset = opts.offset,
                .length = opts.length,
                .hint = opts.hint,
            });

            return .{
                .handle = handle,
                .mapped = mapped,
            };
        },
        else => {
            // The man page indicates the flags must be either `NONE` or an OR of the
            // flags. That doesn't explicitly state that the absence of those flags is
            // the same as `NONE`, so this static assertion is made. That'll break the
            // build rather than behaving unexpectedly if some weird system comes up.
            comptime std.debug.assert(std.posix.PROT.NONE == 0);

            // Convert the public options into POSIX specific options.
            var prot: u32 = std.posix.PROT.READ;
            if (opts.protection.write)
                prot |= std.posix.PROT.WRITE;
            if (opts.protection.execute)
                prot |= std.posix.PROT.EXEC;
            const flags: std.posix.MAP = .{
                .TYPE = switch (opts.exclusivity) {
                    .shared => .SHARED,
                    .private => .PRIVATE,
                },
            };

            // Create the mapping.
            const mapped = try std.posix.mmap(
                opts.hint,
                opts.length,
                prot,
                @bitCast(flags),
                file.handle,
                opts.offset,
            );

            return .{
                .handle = {},
                .mapped = mapped,
            };
        },
    }
}

/// Unmap the file from virtual memory and deallocate kernel resources.
///
/// Invalidates references to `self.mapped`.
pub fn deinit(self: MemoryMap) void {
    switch (builtin.os.tag) {
        .windows => {
            std.os.windows.UnmapViewOfSection(@volatileCast(self.mapped.ptr));
            std.os.windows.CloseHandle(self.handle);
        },
        else => {
            std.posix.munmap(@volatileCast(self.mapped));
        },
    }
}

/// Reinterpret `self.mapped` as `T`.
///
/// The returned pointer is aligned to the beginning of the mapping. The mapping may be
/// larger than `T`. The caller is responsible for determining whether volatility can be
/// stripped away through external synchronization.
pub inline fn cast(self: MemoryMap, comptime T: type) *align(std.mem.page_size) volatile T {
    return std.mem.bytesAsValue(T, self.mapped[0..@sizeOf(T)]);
}
