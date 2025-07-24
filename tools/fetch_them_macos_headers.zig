const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const process = std.process;
const assert = std.debug.assert;
const tmpDir = std.testing.tmpDir;
const fatal = std.process.fatal;
const info = std.log.info;

const Allocator = mem.Allocator;
const OsTag = std.Target.Os.Tag;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

const Arch = enum {
    aarch64,
    x86_64,
};

const Abi = enum { none };

const OsVer = enum(u32) {
    catalina = 10,
    big_sur = 11,
    monterey = 12,
    ventura = 13,
    sonoma = 14,
    sequoia = 15,
};

const Target = struct {
    arch: Arch,
    os: OsTag = .macos,
    os_ver: OsVer,
    abi: Abi = .none,

    fn name(self: Target, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            @tagName(self.arch),
            @tagName(self.os),
            @tagName(self.abi),
        });
    }

    fn fullName(self: Target, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}-{s}.{d}-{s}", .{
            @tagName(self.arch),
            @tagName(self.os),
            @intFromEnum(self.os_ver),
            @tagName(self.abi),
        });
    }
};

const headers_source_prefix: []const u8 = "headers";

const usage =
    \\fetch_them_macos_headers [options] [cc args]
    \\
    \\Options:
    \\  --sysroot     Path to macOS SDK
    \\
    \\General Options:
    \\-h, --help                    Print this help and exit
;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    var argv = std.ArrayList([]const u8).init(allocator);
    var sysroot: ?[]const u8 = null;

    var args_iter = ArgsIterator{ .args = args[1..] };
    while (args_iter.next()) |arg| {
        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return info(usage, .{});
        } else if (mem.eql(u8, arg, "--sysroot")) {
            sysroot = args_iter.nextOrFatal();
        } else try argv.append(arg);
    }

    const sysroot_path = sysroot orelse blk: {
        const target = try std.zig.system.resolveTargetQuery(.{});
        break :blk std.zig.system.darwin.getSdk(allocator, &target) orelse
            fatal("no SDK found; you can provide one explicitly with '--sysroot' flag", .{});
    };

    var sdk_dir = try std.fs.cwd().openDir(sysroot_path, .{});
    defer sdk_dir.close();
    const sdk_info = try sdk_dir.readFileAlloc(allocator, "SDKSettings.json", std.math.maxInt(u32));

    const parsed_json = try std.json.parseFromSlice(struct {
        DefaultProperties: struct { MACOSX_DEPLOYMENT_TARGET: []const u8 },
    }, allocator, sdk_info, .{ .ignore_unknown_fields = true });

    const version = Version.parse(parsed_json.value.DefaultProperties.MACOSX_DEPLOYMENT_TARGET) orelse
        fatal("don't know how to parse SDK version: {s}", .{
            parsed_json.value.DefaultProperties.MACOSX_DEPLOYMENT_TARGET,
        });
    const os_ver: OsVer = switch (version.major) {
        10 => .catalina,
        11 => .big_sur,
        12 => .monterey,
        13 => .ventura,
        14 => .sonoma,
        15 => .sequoia,
        else => unreachable,
    };
    info("found SDK deployment target macOS {f} aka '{s}'", .{ version, @tagName(os_ver) });

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    for (&[_]Arch{ .aarch64, .x86_64 }) |arch| {
        const target: Target = .{
            .arch = arch,
            .os_ver = os_ver,
        };
        try fetchTarget(allocator, argv.items, sysroot_path, target, version, tmp);
    }
}

fn fetchTarget(
    arena: Allocator,
    args: []const []const u8,
    sysroot: []const u8,
    target: Target,
    ver: Version,
    tmp: std.testing.TmpDir,
) !void {
    const tmp_filename = "macos-headers";
    const headers_list_filename = "macos-headers.o.d";
    const tmp_path = try tmp.dir.realpathAlloc(arena, ".");
    const tmp_file_path = try fs.path.join(arena, &[_][]const u8{ tmp_path, tmp_filename });
    const headers_list_path = try fs.path.join(arena, &[_][]const u8{ tmp_path, headers_list_filename });

    const macos_version = try std.fmt.allocPrint(arena, "-mmacosx-version-min={d}.{d}", .{
        ver.major,
        ver.minor,
    });

    var cc_argv = std.ArrayList([]const u8).init(arena);
    try cc_argv.appendSlice(&[_][]const u8{
        "cc",
        "-arch",
        switch (target.arch) {
            .x86_64 => "x86_64",
            .aarch64 => "arm64",
        },
        macos_version,
        "-isysroot",
        sysroot,
        "-iwithsysroot",
        "/usr/include",
        "-o",
        tmp_file_path,
        "macos-headers.c",
        "-MD",
        "-MV",
        "-MF",
        headers_list_path,
    });
    try cc_argv.appendSlice(args);

    const res = try std.process.Child.run(.{
        .allocator = arena,
        .argv = cc_argv.items,
    });

    if (res.stderr.len != 0) {
        std.log.err("{s}", .{res.stderr});
    }

    // Read in the contents of `macos-headers.o.d`
    const headers_list_file = try tmp.dir.openFile(headers_list_filename, .{});
    defer headers_list_file.close();

    var headers_dir = fs.cwd().openDir(headers_source_prefix, .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        => fatal("path '{s}' not found or not a directory. Did you accidentally delete it?", .{
            headers_source_prefix,
        }),
        else => return err,
    };
    defer headers_dir.close();

    const dest_path = try target.fullName(arena);
    try headers_dir.deleteTree(dest_path);

    var dest_dir = try headers_dir.makeOpenPath(dest_path, .{});
    var dirs = std.StringHashMap(fs.Dir).init(arena);
    try dirs.putNoClobber(".", dest_dir);

    const headers_list_str = try headers_list_file.deprecatedReader().readAllAlloc(arena, std.math.maxInt(usize));
    const prefix = "/usr/include";

    var it = mem.splitScalar(u8, headers_list_str, '\n');
    while (it.next()) |line| {
        if (mem.lastIndexOf(u8, line, "clang") != null) continue;
        if (mem.lastIndexOf(u8, line, prefix[0..])) |idx| {
            const out_rel_path = line[idx + prefix.len + 1 ..];
            const out_rel_path_stripped = mem.trim(u8, out_rel_path, " \\");
            const dirname = fs.path.dirname(out_rel_path_stripped) orelse ".";
            const maybe_dir = try dirs.getOrPut(dirname);
            if (!maybe_dir.found_existing) {
                maybe_dir.value_ptr.* = try dest_dir.makeOpenPath(dirname, .{});
            }
            const basename = fs.path.basename(out_rel_path_stripped);

            const line_stripped = mem.trim(u8, line, " \\");
            const abs_dirname = fs.path.dirname(line_stripped).?;
            var orig_subdir = try fs.cwd().openDir(abs_dirname, .{});
            defer orig_subdir.close();

            try orig_subdir.copyFile(basename, maybe_dir.value_ptr.*, basename, .{});
        }
    }

    var dir_it = dirs.iterator();
    while (dir_it.next()) |entry| {
        entry.value_ptr.close();
    }
}

const ArgsIterator = struct {
    args: []const []const u8,
    i: usize = 0,

    fn next(it: *@This()) ?[]const u8 {
        if (it.i >= it.args.len) {
            return null;
        }
        defer it.i += 1;
        return it.args[it.i];
    }

    fn nextOrFatal(it: *@This()) []const u8 {
        const arg = it.next() orelse fatal("expected parameter after '{s}'", .{it.args[it.i - 1]});
        return arg;
    }
};

const Version = struct {
    major: u16,
    minor: u8,
    patch: u8,

    fn parse(raw: []const u8) ?Version {
        var parsed: [3]u16 = [_]u16{0} ** 3;
        var count: usize = 0;
        var it = std.mem.splitAny(u8, raw, ".");
        while (it.next()) |comp| {
            if (count >= 3) return null;
            parsed[count] = std.fmt.parseInt(u16, comp, 10) catch return null;
            count += 1;
        }
        if (count == 0) return null;
        const major = parsed[0];
        const minor = std.math.cast(u8, parsed[1]) orelse return null;
        const patch = std.math.cast(u8, parsed[2]) orelse return null;
        return .{ .major = major, .minor = minor, .patch = patch };
    }

    pub fn format(
        v: Version,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{d}.{d}.{d}", .{ v.major, v.minor, v.patch });
    }
};
