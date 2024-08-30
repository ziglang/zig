// Similar to ArrayList but backed by a memory mapped file.
//
// We mmap the fd but overshoot the allocation size to the maximum file size we
// support. Then when we want to grow the file, we can ftruncate the fd and the
// previously mmaped pages become automatically valid without needing to
// mremap.
//

const std = @import("std");
const assert = std.debug.assert;
const check = @import("main.zig").check;

pub fn MemoryMappedList(comptime T: type) type {
    return struct {
        /// View of the mapped memory. Cropped to valid indexes inside the
        /// file. In reality we know maximum file size and allocate it
        items: []align(std.mem.page_size) volatile T,

        file: std.fs.File,

        const Self = @This();

        pub fn init(f: std.fs.File, size: usize) Self {
            const slice_cap = check(@src(), f.getEndPos(), .{});
            const items_cap = @divExact(slice_cap, @sizeOf(T)); // crash here is probably a corrupt file

            assert(size >= slice_cap);

            const slice: []align(std.mem.page_size) u8 = check(@src(), std.posix.mmap(
                null,
                size, // unused virtual address space on linux is cheap
                std.posix.PROT.READ | std.posix.PROT.WRITE,
                .{ .TYPE = .SHARED },
                f.handle,
                0,
            ), .{ .len = size, .fd = f.handle });

            assert(slice.len == size);

            const items_start: [*]align(std.mem.page_size) volatile T = @ptrCast(slice.ptr);

            return .{
                .items = items_start[0..items_cap],
                .file = f,
            };
        }

        pub fn deinit(self: *Self) void {
            // volatileCast is safe. mem is never used to actually write to or
            // read from
            const startT: [*]align(std.mem.page_size) T = @volatileCast(self.items.ptr);
            const start8: [*]align(std.mem.page_size) u8 = @ptrCast(startT);
            const len8: usize = self.items.len * @sizeOf(T);
            // We don't bother munmaping since all current uses of this struct
            // use it until the end of the program. Even this msync is more of
            // a politeness than a necessity:
            // https://stackoverflow.com/questions/31539208/posix-shared-memory-and-msync
            check(@src(), std.posix.msync(start8[0..len8], std.posix.MSF.ASYNC), .{
                .ptr = start8,
                .len = len8,
            });
        }

        pub fn append(self: *Self, item: T) void {
            return self.appendSlice(&[1]T{item});
        }

        pub fn appendSlice(self: *Self, items: []const T) void {
            self.ensureUnusedCapacity(items.len);
            const old_len = self.items.len;
            self.items.len += items.len;
            @memcpy(self.items[old_len..][0..items.len], items);
        }

        pub fn appendNTimes(self: *Self, value: u8, n: usize) void {
            self.ensureUnusedCapacity(n);
            const new_len = self.items.len + n;
            @memset(self.items.ptr[self.items.len..new_len], value);
            self.items.len = new_len;
        }

        /// Grows the file, not the mapping
        pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) void {
            const total = self.items.len + additional_count;

            const new_size = total * @sizeOf(T);
            check(@src(), std.posix.ftruncate(self.file.handle, new_size), .{ .size = new_size });
        }
    };
}
