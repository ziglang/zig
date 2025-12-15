const std = @import("std");

pub fn main() anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len < 2) return error.MissingArgs;

    const exe_path = args[1];

    const cwd_path = try std.process.getCwdAlloc(arena);
    const parsed_cwd_path = std.fs.path.parsePathWindows(u8, cwd_path);

    if (parsed_cwd_path.kind == .drive_absolute and !std.ascii.isAlphabetic(cwd_path[0])) {
        // Technically possible, but not worth supporting here
        return error.NonAlphabeticDriveLetter;
    }

    const alt_drive_letter = try getAltDriveLetter(cwd_path);
    const alt_drive_cwd_key = try std.fmt.allocPrint(arena, "={c}:", .{alt_drive_letter});
    const alt_drive_cwd = try std.fmt.allocPrint(arena, "{c}:\\baz", .{alt_drive_letter});
    var alt_drive_env_map = std.process.EnvMap.init(arena);
    try alt_drive_env_map.put(alt_drive_cwd_key, alt_drive_cwd);

    const empty_env = std.process.EnvMap.init(arena);

    {
        const drive_rel = try std.fmt.allocPrint(arena, "{c}:foo", .{alt_drive_letter});
        const drive_abs = try std.fmt.allocPrint(arena, "{c}:\\bar", .{alt_drive_letter});

        // With the special =X: environment variable set, drive-relative paths that
        // don't match the CWD's drive letter are resolved against that env var.
        try checkRelative(arena, "..\\..\\bar", &.{ exe_path, drive_rel, drive_abs }, null, &alt_drive_env_map);
        try checkRelative(arena, "..\\baz\\foo", &.{ exe_path, drive_abs, drive_rel }, null, &alt_drive_env_map);

        // Without that environment variable set, drive-relative paths that don't match the
        // CWD's drive letter are resolved against the root of the drive.
        try checkRelative(arena, "..\\bar", &.{ exe_path, drive_rel, drive_abs }, null, &empty_env);
        try checkRelative(arena, "..\\foo", &.{ exe_path, drive_abs, drive_rel }, null, &empty_env);

        // Bare drive-relative path with no components
        try checkRelative(arena, "bar", &.{ exe_path, drive_rel[0..2], drive_abs }, null, &empty_env);
        try checkRelative(arena, "..", &.{ exe_path, drive_abs, drive_rel[0..2] }, null, &empty_env);

        // Bare drive-relative path with no components, drive-CWD set
        try checkRelative(arena, "..\\bar", &.{ exe_path, drive_rel[0..2], drive_abs }, null, &alt_drive_env_map);
        try checkRelative(arena, "..\\baz", &.{ exe_path, drive_abs, drive_rel[0..2] }, null, &alt_drive_env_map);

        // Bare drive-relative path relative to the CWD should be equivalent if drive-CWD is set
        try checkRelative(arena, "", &.{ exe_path, alt_drive_cwd, drive_rel[0..2] }, null, &alt_drive_env_map);
        try checkRelative(arena, "", &.{ exe_path, drive_rel[0..2], alt_drive_cwd }, null, &alt_drive_env_map);

        // Bare drive-relative should always be equivalent to itself
        try checkRelative(arena, "", &.{ exe_path, drive_rel[0..2], drive_rel[0..2] }, null, &alt_drive_env_map);
        try checkRelative(arena, "", &.{ exe_path, drive_rel[0..2], drive_rel[0..2] }, null, &alt_drive_env_map);
        try checkRelative(arena, "", &.{ exe_path, drive_rel[0..2], drive_rel[0..2] }, null, &empty_env);
        try checkRelative(arena, "", &.{ exe_path, drive_rel[0..2], drive_rel[0..2] }, null, &empty_env);
    }

    if (parsed_cwd_path.kind == .unc_absolute) {
        const drive_abs_path = try std.fmt.allocPrint(arena, "{c}:\\foo\\bar", .{alt_drive_letter});

        {
            try checkRelative(arena, drive_abs_path, &.{ exe_path, cwd_path, drive_abs_path }, null, &empty_env);
            try checkRelative(arena, cwd_path, &.{ exe_path, drive_abs_path, cwd_path }, null, &empty_env);
        }
    } else if (parsed_cwd_path.kind == .drive_absolute) {
        const cur_drive_letter = parsed_cwd_path.root[0];
        const path_beyond_root = cwd_path[3..];
        const unc_cwd = try std.fmt.allocPrint(arena, "\\\\127.0.0.1\\{c}$\\{s}", .{ cur_drive_letter, path_beyond_root });

        {
            try checkRelative(arena, cwd_path, &.{ exe_path, unc_cwd, cwd_path }, null, &empty_env);
            try checkRelative(arena, unc_cwd, &.{ exe_path, cwd_path, unc_cwd }, null, &empty_env);
        }
        {
            const drive_abs = cwd_path;
            const drive_rel = parsed_cwd_path.root[0..2];
            try checkRelative(arena, "", &.{ exe_path, drive_abs, drive_rel }, null, &empty_env);
            try checkRelative(arena, "", &.{ exe_path, drive_rel, drive_abs }, null, &empty_env);
        }
    } else {
        return error.UnexpectedPathType;
    }
}

fn checkRelative(
    allocator: std.mem.Allocator,
    expected_stdout: []const u8,
    argv: []const []const u8,
    cwd: ?[]const u8,
    env_map: ?*const std.process.EnvMap,
) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .env_map = env_map,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try std.testing.expectEqualStrings("", result.stderr);
    try std.testing.expectEqualStrings(expected_stdout, result.stdout);
}

fn getAltDriveLetter(path: []const u8) !u8 {
    const parsed = std.fs.path.parsePathWindows(u8, path);
    return switch (parsed.kind) {
        .drive_absolute => {
            const cur_drive_letter = parsed.root[0];
            const next_drive_letter_index = (std.ascii.toUpper(cur_drive_letter) - 'A' + 1) % 26;
            const next_drive_letter = next_drive_letter_index + 'A';
            return next_drive_letter;
        },
        .unc_absolute => {
            return 'C';
        },
        else => return error.UnexpectedPathType,
    };
}

test getAltDriveLetter {
    try std.testing.expectEqual('D', try getAltDriveLetter("C:\\"));
    try std.testing.expectEqual('B', try getAltDriveLetter("a:\\"));
    try std.testing.expectEqual('A', try getAltDriveLetter("Z:\\"));
    try std.testing.expectEqual('C', try getAltDriveLetter("\\\\foo\\bar"));
}
