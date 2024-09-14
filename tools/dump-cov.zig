//! Reads a Zig coverage file and prints human-readable information to stdout,
//! including file:line:column information for each PC.

const std = @import("std");
const fatal = std.process.fatal;
const Path = std.Build.Cache.Path;
const assert = std.debug.assert;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
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

    var coverage = std.debug.Coverage.init;
    defer coverage.deinit(gpa);

    var debug_info = std.debug.Info.load(gpa, exe_path, &coverage) catch |err| {
        fatal("failed to load debug info for {}: {s}", .{ exe_path, @errorName(err) });
    };
    defer debug_info.deinit(gpa);

    const cov_bytes = cov_path.root_dir.handle.readFileAllocOptions(
        arena,
        cov_path.sub_path,
        1 << 30,
        null,
        @alignOf(SeenPcsHeader),
        null,
    ) catch |err| {
        fatal("failed to load coverage file {}: {s}", .{ cov_path, @errorName(err) });
    };

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    const header: *SeenPcsHeader = @ptrCast(cov_bytes);
    try stdout.print("{any}\n", .{header.*});
    const pcs = header.pcAddrs();

    var indexed_pcs: std.AutoArrayHashMapUnmanaged(usize, void) = .empty;
    try indexed_pcs.entries.resize(arena, pcs.len);
    @memcpy(indexed_pcs.entries.items(.key), pcs);
    try indexed_pcs.reIndex(arena);

    const sorted_pcs = try arena.dupe(usize, pcs);
    std.mem.sortUnstable(usize, sorted_pcs, {}, std.sort.asc(usize));

    const source_locations = try arena.alloc(std.debug.Coverage.SourceLocation, sorted_pcs.len);
    try debug_info.resolveAddresses(gpa, sorted_pcs, source_locations);

    const seen_pcs = header.seenBits();

    for (sorted_pcs, source_locations) |pc, sl| {
        if (sl.file == .invalid) {
            try stdout.print(" {x}: invalid\n", .{pc});
            continue;
        }
        const file = debug_info.coverage.fileAt(sl.file);
        const dir_name = debug_info.coverage.directories.keys()[file.directory_index];
        const dir_name_slice = debug_info.coverage.stringAt(dir_name);
        const seen_i = indexed_pcs.getIndex(pc).?;
        const hit: u1 = @truncate(seen_pcs[seen_i / @bitSizeOf(usize)] >> @intCast(seen_i % @bitSizeOf(usize)));
        try stdout.print("{c}{x}: {s}/{s}:{d}:{d}\n", .{
            "-+"[hit], pc, dir_name_slice, debug_info.coverage.stringAt(file.basename), sl.line, sl.column,
        });
    }

    try bw.flush();
}
