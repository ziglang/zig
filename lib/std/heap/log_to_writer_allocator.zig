const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

/// This allocator is used in front of another allocator and logs to the provided writer
/// on every call to the allocator. Writer errors are ignored.
pub fn LogToWriterAllocator(comptime Writer: type) type {
    return struct {
        parent_allocator: Allocator,
        writer: Writer,

        const Self = @This();

        pub fn init(parent_allocator: Allocator, writer: Writer) Self {
            return Self{
                .parent_allocator = parent_allocator,
                .writer = writer,
            };
        }

        pub fn allocator(self: *Self) Allocator {
            return Allocator.init(self, alloc, resize, free);
        }

        fn alloc(
            self: *Self,
            len: usize,
            ptr_align: u29,
            len_align: u29,
            ra: usize,
        ) error{OutOfMemory}![]u8 {
            self.writer.print("alloc : {}", .{len}) catch {};
            const result = self.parent_allocator.rawAlloc(len, ptr_align, len_align, ra);
            if (result) |_| {
                self.writer.print(" success!\n", .{}) catch {};
            } else |_| {
                self.writer.print(" failure!\n", .{}) catch {};
            }
            return result;
        }

        fn resize(
            self: *Self,
            buf: []u8,
            buf_align: u29,
            new_len: usize,
            len_align: u29,
            ra: usize,
        ) ?usize {
            if (new_len <= buf.len) {
                self.writer.print("shrink: {} to {}\n", .{ buf.len, new_len }) catch {};
            } else {
                self.writer.print("expand: {} to {}", .{ buf.len, new_len }) catch {};
            }

            if (self.parent_allocator.rawResize(buf, buf_align, new_len, len_align, ra)) |resized_len| {
                if (new_len > buf.len) {
                    self.writer.print(" success!\n", .{}) catch {};
                }
                return resized_len;
            }

            std.debug.assert(new_len > buf.len);
            self.writer.print(" failure!\n", .{}) catch {};
            return null;
        }

        fn free(
            self: *Self,
            buf: []u8,
            buf_align: u29,
            ra: usize,
        ) void {
            self.writer.print("free  : {}\n", .{buf.len}) catch {};
            self.parent_allocator.rawFree(buf, buf_align, ra);
        }
    };
}

/// This allocator is used in front of another allocator and logs to the provided writer
/// on every call to the allocator. Writer errors are ignored.
pub fn logToWriterAllocator(
    parent_allocator: Allocator,
    writer: anytype,
) LogToWriterAllocator(@TypeOf(writer)) {
    return LogToWriterAllocator(@TypeOf(writer)).init(parent_allocator, writer);
}

test "LogToWriterAllocator" {
    var log_buf: [255]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&log_buf);

    var allocator_buf: [10]u8 = undefined;
    var fixedBufferAllocator = std.mem.validationWrap(std.heap.FixedBufferAllocator.init(&allocator_buf));
    const allocator = logToWriterAllocator(fixedBufferAllocator.allocator(), fbs.writer()).allocator();

    var a = try allocator.alloc(u8, 10);
    a = allocator.shrink(a, 5);
    try std.testing.expect(a.len == 5);
    try std.testing.expect(allocator.resize(a, 20) == null);
    allocator.free(a);

    try std.testing.expectEqualSlices(u8,
        \\alloc : 10 success!
        \\shrink: 10 to 5
        \\expand: 5 to 20 failure!
        \\free  : 5
        \\
    , fbs.getWritten());
}
