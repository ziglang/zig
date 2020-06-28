const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

/// This allocator is used in front of another allocator and logs to the provided writer
/// on every call to the allocator. Writer errors are ignored.
/// If https://github.com/ziglang/zig/issues/2586 is implemented, this API can be improved.
pub fn LoggingAllocator(comptime WriterType: type) type {
    return struct {
        allocator: Allocator,
        parent_allocator: *Allocator,
        writer: WriterType,

        const Self = @This();

        pub fn init(parent_allocator: *Allocator, writer: WriterType) Self {
            return Self{
                .allocator = Allocator{
                    .allocFn = alloc,
                    .resizeFn = resize,
                },
                .parent_allocator = parent_allocator,
                .writer = writer,
            };
        }

        fn alloc(allocator: *Allocator, len: usize, ptr_align: u29, len_align: u29) error{OutOfMemory}![]u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            self.writer.print("alloc : {}", .{len}) catch {};
            const result = self.parent_allocator.callAllocFn(len, ptr_align, len_align);
            if (result) |buff| {
                self.writer.print(" success!\n", .{}) catch {};
            } else |err| {
                self.writer.print(" failure!\n", .{}) catch {};
            }
            return result;
        }

        fn resize(allocator: *Allocator, buf: []u8, new_len: usize, len_align: u29) error{OutOfMemory}!usize {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            if (new_len == 0) {
                self.writer.print("free  : {}\n", .{buf.len}) catch {};
            } else if (new_len <= buf.len) {
                self.writer.print("shrink: {} to {}\n", .{buf.len, new_len}) catch {};
            } else {
                self.writer.print("expand: {} to {}", .{ buf.len, new_len }) catch {};
            }
            if (self.parent_allocator.callResizeFn(buf, new_len, len_align)) |resized_len| {
                if (new_len > buf.len) {
                    self.writer.print(" success!\n", .{}) catch {};
                }
                return resized_len;
            } else |e| {
                std.debug.assert(new_len > buf.len);
                self.writer.print(" failure!\n", .{}) catch {};
                return e;
            }
        }
    };
}

pub fn loggingAllocator(
    parent_allocator: *Allocator,
    writer: var,
) LoggingAllocator(@TypeOf(writer)) {
    return LoggingAllocator(@TypeOf(writer)).init(parent_allocator, writer);
}

test "LoggingAllocator" {
    var log_buf: [255]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&log_buf);

    var allocator_buf: [10]u8 = undefined;
    var fixedBufferAllocator = std.mem.validationWrap(std.heap.FixedBufferAllocator.init(&allocator_buf));
    const allocator = &loggingAllocator(&fixedBufferAllocator.allocator, fbs.writer()).allocator;

    var a = try allocator.alloc(u8, 10);
    a.len = allocator.shrinkBytes(a, 5, 0);
    std.debug.assert(a.len == 5);
    std.testing.expectError(error.OutOfMemory, allocator.callResizeFn(a, 20, 0));
    allocator.free(a);

    std.testing.expectEqualSlices(u8,
        \\alloc : 10 success!
        \\shrink: 10 to 5
        \\expand: 5 to 20 failure!
        \\free  : 5
        \\
    , fbs.getWritten());
}
