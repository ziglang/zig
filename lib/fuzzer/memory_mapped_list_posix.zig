//! Growable shared memory backed by a file
//!
//! We mmap the fd but overshoot the allocation size to the maximum file size
//! we support. Then when we want to grow the file, we can ftruncate the fd and
//! the previously mmaped pages become automatically valid without needing to
//! mremap.
//!
//! The most amazing part is that some other process can do the ftruncate and
//! our memory region grows without the need to synchronize. The only thing
//! needed is an atomic size inside the file that other threads use to find out
//! the current size. Nobody needs to remap anything ever.

const std = @import("std");
const assert = std.debug.assert;
const fatal = std.process.fatal;

pub fn MemoryMappedList(comptime T: type) type {
    return struct {
        // The entire allocated region
        items: []align(std.mem.page_size) volatile T,
        file: std.fs.File,

        const Self = @This();

        pub fn init(f: std.fs.File, max_count: usize) Self {
            const max_size_bytes: usize = max_count * @sizeOf(T);

            const slice: []align(std.mem.page_size) u8 = std.posix.mmap(
                null,
                max_size_bytes,
                std.posix.PROT.READ | std.posix.PROT.WRITE,
                .{ .TYPE = .SHARED, .NORESERVE = true },
                f.handle,
                0,
            ) catch |e| fatal("mmap(len={},fd={}) failed: {}", .{ max_size_bytes, f.handle, e });

            assert(slice.len == max_size_bytes);

            const items_start: [*]align(std.mem.page_size) volatile T = @ptrCast(slice.ptr);

            return .{
                .items = items_start[0..max_count],
                .file = f,
            };
        }

        pub fn deinit(self: *Self) void {
            // volatileCast is safe. ptr is never used to actually write to or
            // read from
            const startT: [*]align(std.mem.page_size) T = @volatileCast(self.items.ptr);
            const start8: [*]align(std.mem.page_size) u8 = @ptrCast(startT);
            const len8: usize = self.items.len * @sizeOf(T);
            const memory: []align(std.mem.page_size) u8 = start8[0..len8];

            std.posix.msync(memory, std.posix.MSF.ASYNC) catch {
                // well...
            };

            std.posix.munmap(memory);
        }

        pub fn fileLen(self: *Self) usize {
            return self.file.getEndPos() catch |e| fatal("getendpos failed: {}", .{e});
        }

        pub fn setFileLen(self: *Self, new_size_bytes: usize) void {
            std.posix.ftruncate(self.file.handle, new_size_bytes) catch |e| fatal("ftruncate failed: {}", .{e});
        }

        /// Not thread safe
        pub fn append(self: *Self, item: T) void {
            return self.appendSlice(&[1]T{item});
        }

        /// Not thread safe
        pub fn appendSlice(self: *Self, items: []const T) void {
            const space = self.makeSpace(items.len);
            @memcpy(space, items);
        }

        /// Not thread safe
        pub fn appendNTimes(self: *Self, value: T, count: usize) void {
            const space = self.makeSpace(count);
            @memset(space, value);
        }

        /// Not thread safe
        /// Grows the file, not the mapping. Returns the new space at the end of the file
        pub fn makeSpace(self: *Self, additional_count: usize) []volatile T {
            const current_size_bytes = self.fileLen();
            const new_size_bytes: usize = current_size_bytes + additional_count * @sizeOf(T);

            const new_slice = self.items[@divExact(current_size_bytes, @sizeOf(T))..][0..additional_count];

            if (new_size_bytes > (self.items.len * @sizeOf(T))) {
                fatal("List grew beyond the maximum size ({} >= {})", .{ new_size_bytes, self.items.len * @sizeOf(T) });
            }

            self.setFileLen(new_size_bytes);

            return new_slice;
        }
    };
}
