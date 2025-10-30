pub fn ParallelHasher(comptime Hasher: type) type {
    const hash_size = Hasher.digest_length;

    return struct {
        allocator: Allocator,
        io: Io,

        pub fn hash(self: Self, file: fs.File, out: [][hash_size]u8, opts: struct {
            chunk_size: u64 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            const tracy = trace(@src());
            defer tracy.end();

            const io = self.io;
            const gpa = self.allocator;

            const file_size = blk: {
                const file_size = opts.max_file_size orelse try file.getEndPos();
                break :blk std.math.cast(usize, file_size) orelse return error.Overflow;
            };
            const chunk_size = std.math.cast(usize, opts.chunk_size) orelse return error.Overflow;

            const buffer = try gpa.alloc(u8, chunk_size * out.len);
            defer gpa.free(buffer);

            const results = try gpa.alloc(fs.File.PReadError!usize, out.len);
            defer gpa.free(results);

            {
                var wg: Io.Group = .init;
                defer wg.wait(io);

                for (out, results, 0..) |*out_buf, *result, i| {
                    const fstart = i * chunk_size;
                    const fsize = if (fstart + chunk_size > file_size)
                        file_size - fstart
                    else
                        chunk_size;

                    wg.async(io, worker, .{
                        file,
                        fstart,
                        buffer[fstart..][0..fsize],
                        &(out_buf.*),
                        &(result.*),
                    });
                }
            }
            for (results) |result| _ = try result;
        }

        fn worker(
            file: fs.File,
            fstart: usize,
            buffer: []u8,
            out: *[hash_size]u8,
            err: *fs.File.PReadError!usize,
        ) void {
            const tracy = trace(@src());
            defer tracy.end();
            err.* = file.preadAll(buffer, fstart);
            Hasher.hash(buffer, out, .{});
        }

        const Self = @This();
    };
}

const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;

const trace = @import("../../tracy.zig").trace;
