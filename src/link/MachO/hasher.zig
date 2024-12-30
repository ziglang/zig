pub fn ParallelHasher(comptime Hasher: type) type {
    const hash_size = Hasher.digest_length;

    return struct {
        allocator: Allocator,
        thread_pool: *ThreadPool,

        pub fn hash(self: Self, file: fs.File, out: [][hash_size]u8, opts: struct {
            chunk_size: u64 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            const tracy = trace(@src());
            defer tracy.end();

            var wg: WaitGroup = .{};

            const file_size = blk: {
                const file_size = opts.max_file_size orelse try file.getEndPos();
                break :blk std.math.cast(usize, file_size) orelse return error.Overflow;
            };
            const chunk_size = std.math.cast(usize, opts.chunk_size) orelse return error.Overflow;

            const buffer = try self.allocator.alloc(u8, chunk_size * out.len);
            defer self.allocator.free(buffer);

            const results = try self.allocator.alloc(fs.File.PReadError!usize, out.len);
            defer self.allocator.free(results);

            {
                wg.reset();
                defer wg.wait();

                for (out, results, 0..) |*out_buf, *result, i| {
                    const fstart = i * chunk_size;
                    const fsize = if (fstart + chunk_size > file_size)
                        file_size - fstart
                    else
                        chunk_size;
                    self.thread_pool.spawnWg(&wg, worker, .{
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

const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
