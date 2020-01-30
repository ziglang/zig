const std = @import("../std.zig");
const Allocator = std.mem.Allocator;

const AnyErrorOutStream = std.io.OutStream(anyerror);

/// This allocator is used in front of another allocator and logs to the provided stream
/// on every call to the allocator. Stream errors are ignored.
/// If https://github.com/ziglang/zig/issues/2586 is implemented, this API can be improved.
pub const LoggingAllocator = struct {
    allocator: Allocator,
    parent_allocator: *Allocator,
    out_stream: *AnyErrorOutStream,

    const Self = @This();

    pub fn init(parent_allocator: *Allocator, out_stream: *AnyErrorOutStream) Self {
        return Self{
            .allocator = Allocator{
                .reallocFn = realloc,
                .shrinkFn = shrink,
            },
            .parent_allocator = parent_allocator,
            .out_stream = out_stream,
        };
    }

    fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) ![]u8 {
        const self = @fieldParentPtr(Self, "allocator", allocator);
        if (old_mem.len == 0) {
            self.out_stream.print("allocation of {} ", .{new_size}) catch {};
        } else {
            self.out_stream.print("resize from {} to {} ", .{ old_mem.len, new_size }) catch {};
        }
        const result = self.parent_allocator.reallocFn(self.parent_allocator, old_mem, old_align, new_size, new_align);
        if (result) |buff| {
            self.out_stream.print("success!\n", .{}) catch {};
        } else |err| {
            self.out_stream.print("failure!\n", .{}) catch {};
        }
        return result;
    }

    fn shrink(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
        const self = @fieldParentPtr(Self, "allocator", allocator);
        const result = self.parent_allocator.shrinkFn(self.parent_allocator, old_mem, old_align, new_size, new_align);
        if (new_size == 0) {
            self.out_stream.print("free of {} bytes success!\n", .{old_mem.len}) catch {};
        } else {
            self.out_stream.print("shrink from {} bytes to {} bytes success!\n", .{ old_mem.len, new_size }) catch {};
        }
        return result;
    }
};

test "LoggingAllocator" {
    var buf: [255]u8 = undefined;
    var slice_stream = std.io.SliceOutStream.init(buf[0..]);
    const stream = &slice_stream.stream;

    const allocator = &LoggingAllocator.init(std.testing.allocator, @ptrCast(*AnyErrorOutStream, stream)).allocator;

    const ptr = try allocator.alloc(u8, 10);
    allocator.free(ptr);

    std.testing.expectEqualSlices(u8,
        \\allocation of 10 success!
        \\free of 10 bytes success!
        \\
    , slice_stream.getWritten());
}
