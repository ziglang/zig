//! Reads a Zig coverage file and prints human-readable information to stdout,
//! including file:line:column information for each PC.

const std = @import("std");
const fatal = std.process.fatal;
const Path = std.Build.Cache.Path;
const assert = std.debug.assert;

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = general_purpose_allocator.deinit();
    const gpa = general_purpose_allocator.allocator();

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const exe_file_name = args[1];
    const cov_file_name = args[2];

    const exe_path: Path = .{
        .root_dir = std.Build.Cache.Directory.cwd(),
        .sub_path = exe_file_name,
    };
    const cov_path: Path = .{
        .root_dir = std.Build.Cache.Directory.cwd(),
        .sub_path = cov_file_name,
    };

    const prog_node = std.Progress.start(.{});
    defer prog_node.end();

    var debug_info = std.debug.Info.load(gpa, exe_path, prog_node) catch |err| {
        fatal("failed to load debug info for {}: {s}", .{ exe_path, @errorName(err) });
    };
    defer debug_info.deinit(gpa);

    const cov_bytes = cov_path.root_dir.handle.readFileAlloc(arena, cov_path.sub_path, 1 << 30) catch |err| {
        fatal("failed to load coverage file {}: {s}", .{ cov_path, @errorName(err) });
    };

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    const header: *align(1) SeenPcsHeader = @ptrCast(cov_bytes);
    try stdout.print("{any}\n", .{header.*});
    //const n_bitset_elems = (header.pcs_len + 7) / 8;
    const pcs_bytes = cov_bytes[@sizeOf(SeenPcsHeader)..][0 .. header.pcs_len * @sizeOf(usize)];
    const pcs = try arena.alloc(usize, header.pcs_len);
    for (0..pcs_bytes.len / @sizeOf(usize), pcs) |i, *pc| {
        pc.* = std.mem.readInt(usize, pcs_bytes[i * @sizeOf(usize) ..][0..@sizeOf(usize)], .little);
    }
    assert(std.sort.isSorted(usize, pcs, {}, std.sort.asc(usize)));

    const source_locations = try arena.alloc(std.debug.SourceLocation, pcs.len);
    try debug_info.resolveSourceLocations(gpa, pcs, source_locations, prog_node);
    defer for (source_locations) |sl| {
        gpa.free(sl.file_name);
    };

    for (pcs, source_locations) |pc, sl| {
        try stdout.print("{x}: {s}:{d}:{d}\n", .{
            pc, sl.file_name, sl.line, sl.column,
        });
    }

    try bw.flush();
}

const SeenPcsHeader = extern struct {
    n_runs: usize,
    deduplicated_runs: usize,
    pcs_len: usize,
    lowest_stack: usize,
};
