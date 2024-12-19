const std = @import("../std.zig");
const mem = std.mem;

/// This allocator is used in front of another allocator and logs to the provided writer
/// on every call to the allocator. Writer errors are ignored.
pub fn Allocator(comptime Writer: type) type {
    return struct {
        parent_allocator: mem.Allocator,
        writer: Writer,

        const Self = @This();

        pub fn init(parent_allocator: mem.Allocator, writer: Writer) Self {
            return Self{
                .parent_allocator = parent_allocator,
                .writer = writer,
            };
        }

        pub fn allocator(self: *Self) mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        fn alloc(
            ctx: *anyopaque,
            len: usize,
            log2_ptr_align: u8,
            ra: usize,
        ) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.writer.print("alloc : {}", .{len}) catch {};
            const result = self.parent_allocator.rawAlloc(len, log2_ptr_align, ra);
            if (result != null) {
                self.writer.print(" success!\n", .{}) catch {};
            } else {
                self.writer.print(" failure!\n", .{}) catch {};
            }
            return result;
        }

        fn resize(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            new_len: usize,
            ra: usize,
        ) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            if (new_len <= buf.len) {
                self.writer.print("shrink: {} to {}\n", .{ buf.len, new_len }) catch {};
            } else {
                self.writer.print("expand: {} to {}", .{ buf.len, new_len }) catch {};
            }

            if (self.parent_allocator.rawResize(buf, log2_buf_align, new_len, ra)) {
                if (new_len > buf.len) {
                    self.writer.print(" success!\n", .{}) catch {};
                }
                return true;
            }

            std.debug.assert(new_len > buf.len);
            self.writer.print(" failure!\n", .{}) catch {};
            return false;
        }

        fn free(
            ctx: *anyopaque,
            buf: []u8,
            log2_buf_align: u8,
            ra: usize,
        ) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.writer.print("free  : {}\n", .{buf.len}) catch {};
            self.parent_allocator.rawFree(buf, log2_buf_align, ra);
        }
    };
}

/// This allocator is used in front of another allocator and logs to the provided writer
/// on every call to the allocator. Writer errors are ignored.
pub fn allocator(
    parent_allocator: mem.Allocator,
    writer: anytype,
) Allocator(@TypeOf(writer)) {
    return Allocator(@TypeOf(writer)).init(parent_allocator, writer);
}

test Allocator {
    var log_buf: [255]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&log_buf);

    var allocator_buf: [10]u8 = undefined;
    var fixedBufferAllocator = std.mem.validationWrap(std.alloc.FixedBuffer.init(&allocator_buf));
    var allocator_state = allocator(fixedBufferAllocator.allocator(), fbs.writer());
    const alloc = allocator_state.allocator();

    var a = try alloc.alloc(u8, 10);
    try std.testing.expect(alloc.resize(a, 5));
    a = a[0..5];
    try std.testing.expect(!alloc.resize(a, 20));
    alloc.free(a);

    try std.testing.expectEqualSlices(u8,
        \\alloc : 10 success!
        \\shrink: 10 to 5
        \\expand: 5 to 20 failure!
        \\free  : 5
        \\
    , fbs.getWritten());
}
