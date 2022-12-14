const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;

const Allocator = mem.Allocator;
const ThreadPool = @import("../../ThreadPool.zig");
const WaitGroup = @import("../../WaitGroup.zig");

pub fn ParallelHasher(comptime Hasher: type) type {
    const hash_size = Hasher.digest_length;

    return struct {
        pub fn hash(self: @This(), gpa: Allocator, pool: *ThreadPool, file: fs.File, out: [][hash_size]u8, opts: struct {
            chunk_size: u16 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            _ = self;

            var wg: WaitGroup = .{};

            const file_size = opts.max_file_size orelse try file.getEndPos();
            const total_num_chunks = mem.alignForward(file_size, opts.chunk_size) / opts.chunk_size;
            assert(out.len >= total_num_chunks);

            const buffer = try gpa.alloc(u8, opts.chunk_size * total_num_chunks);
            defer gpa.free(buffer);

            const results = try gpa.alloc(fs.File.PReadError!usize, total_num_chunks);
            defer gpa.free(results);

            {
                wg.reset();
                defer wg.wait();

                var i: usize = 0;
                while (i < total_num_chunks) : (i += 1) {
                    const fstart = i * opts.chunk_size;
                    const fsize = if (fstart + opts.chunk_size > file_size) file_size - fstart else opts.chunk_size;
                    wg.start();
                    try pool.spawn(worker, .{ file, fstart, buffer[fstart..][0..fsize], &out[i], &results[i], &wg });
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
            wg: *WaitGroup,
        ) void {
            defer wg.finish();
            err.* = file.preadAll(buffer, fstart);
            Hasher.hash(buffer, out, .{});
        }
    };
}
