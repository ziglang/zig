const std = @import("std");
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const zig_exe = args[1];
    const input_file_name = args[2];

    const input_file_bytes = try std.fs.cwd().readFileAlloc(arena, input_file_name, std.math.maxInt(u32));
    const case = try Case.parse(arena, input_file_bytes);

    const prog_node = std.Progress.start(.{});
    defer prog_node.end();

    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_path = "tmp_" ++ std.fmt.hex(rand_int);
    const local_cache_path = tmp_dir_path ++ std.fs.path.sep_str ++ ".local-cache";
    const global_cache_path = tmp_dir_path ++ std.fs.path.sep_str ++ ".global-cache";
    const tmp_dir = try std.fs.cwd().makeOpenPath(tmp_dir_path, .{});

    const child_prog_node = prog_node.start("zig build-exe", 0);
    defer child_prog_node.end();

    var child = std.process.Child.init(&.{
        zig_exe,
        "build-exe",
        case.root_source_file,
        "-fno-llvm",
        "-fno-lld",
        "-fincremental",
        "--listen=-",
        "-target",
        case.target_query,
        "--cache-dir",
        local_cache_path,
        "--global-cache-dir",
        global_cache_path,
    }, arena);

    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.progress_node = child_prog_node;

    var eval: Eval = .{
        .case = case,
        .tmp_dir = tmp_dir,
        .child = &child,
    };

    eval.write(case.updates[0]);

    try child.spawn();

    var poller = std.io.poll(arena, enum { stdout, stderr }, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    try eval.check(case.updates[0]);

    for (case.updates[1..]) |update| {
        eval.write(update);
        try eval.requestIncrementalUpdate();
        try eval.check(update);
    }
}

const Eval = struct {
    case: Case,
    tmp_dir: std.fs.Dir,
    child: *std.process.Child,

    /// Currently this function assumes the previous updates have already been written.
    fn write(eval: *Eval, update: Case.Update) void {
        for (update.changes) |full_contents| {
            eval.tmp_dir.writeFile(.{
                .sub_path = full_contents.name,
                .data = full_contents.bytes,
            }) catch |err| {
                fatal("failed to update '{s}': {s}", .{ full_contents.name, @errorName(err) });
            };
        }
        for (update.deletes) |doomed_name| {
            eval.tmp_dir.deleteFile(doomed_name) catch |err| {
                fatal("failed to delete '{s}': {s}", .{ doomed_name, @errorName(err) });
            };
        }
    }

    fn check(eval: *Eval, update: Case.Update) !void {
        _ = eval;
        _ = update;
        @panic("TODO: read messages from the compiler");
    }

    fn requestIncrementalUpdate(eval: *Eval) !void {
        _ = eval;
        @panic("TODO: send update request to the compiler");
    }
};

const Case = struct {
    updates: []Update,
    root_source_file: []const u8,
    target_query: []const u8,

    const Update = struct {
        name: []const u8,
        outcome: Outcome,
        changes: []const FullContents = &.{},
        deletes: []const []const u8 = &.{},
    };

    const FullContents = struct {
        name: []const u8,
        bytes: []const u8,
    };

    const Outcome = union(enum) {
        unknown,
        compile_errors: []const ExpectedError,
        stdout: []const u8,
        exit_code: u8,
    };

    const ExpectedError = struct {
        file_name: ?[]const u8 = null,
        line: ?u32 = null,
        column: ?u32 = null,
        msg_exact: ?[]const u8 = null,
        msg_substring: ?[]const u8 = null,
    };

    fn parse(arena: Allocator, bytes: []const u8) !Case {
        var updates: std.ArrayListUnmanaged(Update) = .{};
        var changes: std.ArrayListUnmanaged(FullContents) = .{};
        var target_query: ?[]const u8 = null;
        var it = std.mem.splitScalar(u8, bytes, '\n');
        var line_n: usize = 1;
        var root_source_file: ?[]const u8 = null;
        while (it.next()) |line| : (line_n += 1) {
            if (std.mem.startsWith(u8, line, "#")) {
                var line_it = std.mem.splitScalar(u8, line, '=');
                const key = line_it.first()[1..];
                const val = line_it.rest();
                if (val.len == 0) {
                    fatal("line {d}: missing value", .{line_n});
                } else if (std.mem.eql(u8, key, "target")) {
                    if (target_query != null) fatal("line {d}: duplicate target", .{line_n});
                    target_query = val;
                } else if (std.mem.eql(u8, key, "update")) {
                    if (updates.items.len > 0) {
                        const last_update = &updates.items[updates.items.len - 1];
                        last_update.changes = try changes.toOwnedSlice(arena);
                    }
                    try updates.append(arena, .{
                        .name = val,
                        .outcome = .unknown,
                    });
                } else if (std.mem.eql(u8, key, "file")) {
                    if (updates.items.len == 0) fatal("line {d}: expect directive before update", .{line_n});

                    if (root_source_file == null)
                        root_source_file = val;

                    const start_index = it.index.?;
                    const src = while (true) : (line_n += 1) {
                        const old = it;
                        const next_line = it.next() orelse fatal("line {d}: unexpected EOF", .{line_n});
                        if (std.mem.startsWith(u8, next_line, "#")) {
                            const end_index = old.index.?;
                            const src = bytes[start_index..end_index];
                            it = old;
                            break src;
                        }
                    };

                    try changes.append(arena, .{
                        .name = val,
                        .bytes = src,
                    });
                } else if (std.mem.eql(u8, key, "expect_stdout")) {
                    if (updates.items.len == 0) fatal("line {d}: expect directive before update", .{line_n});
                    const last_update = &updates.items[updates.items.len - 1];
                    if (last_update.outcome != .unknown) fatal("line {d}: conflicting expect directive", .{line_n});
                    last_update.outcome = .{
                        .stdout = std.zig.string_literal.parseAlloc(arena, val) catch |err| {
                            fatal("line {d}: bad string literal: {s}", .{ line_n, @errorName(err) });
                        },
                    };
                } else {
                    fatal("line {d}: unrecognized key '{s}'", .{ line_n, key });
                }
            }
        }

        if (changes.items.len > 0) {
            const last_update = &updates.items[updates.items.len - 1];
            last_update.changes = try changes.toOwnedSlice(arena);
        }

        return .{
            .updates = updates.items,
            .root_source_file = root_source_file orelse fatal("missing root source file", .{}),
            .target_query = target_query orelse fatal("missing target", .{}),
        };
    }
};
