//! ./runner command0 [arg0 arg1 ...] [--then command1 arg0 arg1 ...] [--path path0 path1 ...] [--cwd cwd] [--delete file0 file1 ...] [--rename old0 new0 [old1 new1 ...]] -- [replacement0 replacement1 ... replacement9]
//! Replaces $0 through $9 in all non-option arguments with replacement0 through replacement9,
//! which have native path separators replaced with posix path separators.
//! Replaces @0 through @9 in all non-option arguments with the contents of the file
//! replacement0 through replacement9.
//! Then, executes the command before any option arguments with extra paths after --path and at optional cwd after --cwd.
//! Then, executes the command after --then with extra paths after --path and at optional cwd after --cwd.
//! Then, optionally deletes files after --delete.
//! Then, optionally renomes pairs of files after --rename.

const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    var first: [][]u8 = &.{};
    var then: [][]u8 = &.{};
    var cwd: [][]u8 = &.{};
    var path: [][]u8 = &.{};
    var delete: [][]u8 = &.{};
    var rename: [][]u8 = &.{};
    var replacements: [][]u8 = &.{};

    var prev_separator_index: usize = 0;
    var separator_index: usize = 1;
    while (separator_index < args.len) : (separator_index += 1) {
        if (!std.mem.startsWith(u8, args[separator_index], "--")) continue;
        const separated_args = args[prev_separator_index + 1 .. separator_index];
        if (prev_separator_index == 0)
            first = separated_args
        else if (std.mem.eql(u8, args[prev_separator_index], "--then"))
            then = separated_args
        else if (std.mem.eql(u8, args[prev_separator_index], "--cwd"))
            cwd = separated_args
        else if (std.mem.eql(u8, args[prev_separator_index], "--path"))
            path = separated_args
        else if (std.mem.eql(u8, args[prev_separator_index], "--delete"))
            delete = separated_args
        else if (std.mem.eql(u8, args[prev_separator_index], "--rename"))
            rename = separated_args
        else
            std.debug.panic("unexpected '{s}'", .{args[prev_separator_index]});
        if (args[separator_index].len == 2) {
            replacements = args[separator_index + 1 ..];
            break;
        }
        prev_separator_index = separator_index;
    } else std.debug.panic("expected '--'", .{});

    if (first.len == 0) std.debug.panic("expected arguments", .{});
    if (cwd.len > 1) std.debug.panic("expected at most 1 cwd argument", .{});
    if (rename.len % 2 != 0) std.debug.panic("expected even rename arguments", .{});

    for (replacements) |replacement| std.mem.replaceScalar(
        u8,
        replacement,
        std.fs.path.sep,
        std.fs.path.sep_posix,
    );
    for ([_][][]u8{ first, then, cwd, path, delete, rename }) |patterns| for (patterns) |*pattern| {
        var replaced = std.ArrayList(u8).init(allocator);
        var pos: usize = 0;
        while (std.mem.indexOfAnyPos(u8, pattern.*, pos, "$@")) |special_pos| {
            try replaced.appendSlice(pattern.*[pos..special_pos]);
            const special = pattern.*[special_pos..][0..2];
            if (std.fmt.charToDigit(special[1], 10)) |special_index| switch (special[0]) {
                '$' => try replaced.appendSlice(replacements[special_index]),
                '@' => {
                    const special_file = try std.fs.cwd().openFile(replacements[special_index], .{});
                    defer special_file.close();
                    try special_file.reader().readAllArrayList(&replaced, 1 << 12);
                    replaced.shrinkRetainingCapacity(std.mem.trimRight(u8, replaced.items, &std.ascii.whitespace).len);
                },
                else => unreachable,
            } else |_| switch (special[0]) {
                '$' => try replaced.append(special[1]),
                else => unreachable,
            }
            pos = special_pos + 2;
        }
        try replaced.appendSlice(pattern.*[pos..]);
        pattern.* = replaced.items;
    };

    var path_buffer = std.ArrayList(u8).init(allocator);
    for (path) |path_path| {
        try path_buffer.appendSlice(path_path);
        try path_buffer.append(std.fs.path.delimiter);
    }
    var env = try std.process.getEnvMap(allocator);
    if (env.getPtr("PATH")) |env_path| {
        try path_buffer.appendSlice(env_path.*);
        env_path.* = try path_buffer.toOwnedSlice();
    } else if (path_buffer.items.len > 0) try env.putMove(
        try allocator.dupe(u8, "PATH"),
        path_buffer.items[0 .. path_buffer.items.len - 1],
    );

    var first_child = std.process.Child.init(first, allocator);
    first_child.env_map = &env;
    if (cwd.len == 1) first_child.cwd = cwd[0];
    switch (try first_child.spawnAndWait()) {
        .Exited => |status| if (status != 0) std.process.exit(status),
        else => |term| std.debug.panic("{}", .{term}),
    }

    if (then.len > 0) {
        var then_child = std.process.Child.init(then, allocator);
        then_child.env_map = &env;
        if (cwd.len == 1) then_child.cwd = cwd[0];
        switch (try then_child.spawnAndWait()) {
            .Exited => |status| if (status != 0) std.process.exit(status),
            else => |term| std.debug.panic("{}", .{term}),
        }
    }

    for (delete) |delete_path| try std.fs.cwd().deleteFile(delete_path);

    var rename_index: usize = 0;
    while (rename_index < rename.len) : (rename_index += 2) try std.fs.cwd().rename(
        rename[rename_index + 0],
        rename[rename_index + 1],
    );
}
