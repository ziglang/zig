//! This is a standalone tool that can print the strings stored inside a corpus
//! (buffer + meta file pair in the .zig-cache/v/ directory)

const std = @import("std");
const fatal = std.process.fatal;

const InputPool = @import("input_pool.zig").InputPool;

pub fn main() void {
    var args = std.process.args();
    const bin = args.next();
    const cache_dir_path = args.next();
    const pc_digest_str = args.next();

    if (cache_dir_path == null or pc_digest_str == null or args.next() != null) {
        fatal("usage: {s} CACHE_DIR PC_DIGEST\n", .{bin.?});
    }

    // std.fmt.hex actually produces the hex number in the opposite order than
    // parseInt reads...
    const pc_digest = @byteSwap(std.fmt.parseInt(u64, pc_digest_str.?, 16) catch |e|
        fatal("invalid pc digest: {}", .{e}));

    const cache_dir = std.fs.cwd().makeOpenPath(cache_dir_path.?, .{}) catch |e|
        fatal("invalid cache dir: {}", .{e});

    std.log.info("cache_dir: {s}", .{cache_dir_path.?});
    std.log.info("pc_digest: {x}", .{@byteSwap(pc_digest)});

    var input_pool = InputPool.init(cache_dir, pc_digest);

    const len = input_pool.len();

    std.log.info("There are {} strings in the corpus:", .{len});

    for (0..len) |i| {
        const str = input_pool.getString(@intCast(i));

        // Only writing to this buffer has side effects.
        const str2: []const u8 = @volatileCast(str);

        std.log.info("\"{}\"", .{std.zig.fmtEscapes(str2)});
    }
}
