const std = @import("std");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.skip();
    const first_path = args.next().?;
    const first_file = try std.fs.cwd().openFile(first_path, .{});
    const second_path = args.next().?;
    const second_file = try std.fs.cwd().openFile(second_path, .{});

    var first_buffer: [1 << 18]u8 = undefined;
    var second_buffer: [1 << 18]u8 = undefined;
    var offset: u64 = 0;
    while (true) {
        const first_data = first_buffer[0..try first_file.reader().readAll(&first_buffer)];
        const second_data = second_buffer[0..try second_file.reader().readAll(&second_buffer)];
        if (std.mem.indexOfDiff(u8, first_data, second_data)) |diff_index| {
            try std.io.getStdErr().writer().print("{s} {s} differ: byte {d}\n", .{
                first_path,
                second_path,
                offset + diff_index + 1,
            });
            std.process.exit(1);
        }
        offset += first_data.len;
        if (first_data.len < first_buffer.len) break;
    }
}
