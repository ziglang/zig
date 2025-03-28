const std = @import("../../std.zig");
const Directory = std.Build.Cache.Directory;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const fatal = std.process.fatal;

const Templates = @This();

zig_lib_directory: Directory,
dir: fs.Dir,
buffer: std.ArrayListUnmanaged(u8),

fn find(gpa: Allocator, zig_lib_directory: Directory) Templates {
    const s = fs.path.sep_str;
    const template_sub_path = "init";
    const template_dir = zig_lib_directory.handle.openDir(template_sub_path, .{}) catch |err| {
        const path = zig_lib_directory.path orelse ".";
        fatal("unable to open zig project template directory '{s}{s}{s}': {s}", .{
            path, s, template_sub_path, @errorName(err),
        });
    };

    return .{
        .zig_lib_directory = zig_lib_directory,
        .dir = template_dir,
        .buffer = std.ArrayListUnmanaged(u8).init(gpa),
    };
}

fn deinit(templates: *Templates, gpa: Allocator) void {
    templates.zig_lib_directory.handle.close();
    templates.dir.close();
    templates.buffer.deinit(gpa);
    templates.* = undefined;
}

fn write(
    templates: *Templates,
    gpa: Allocator,
    out_dir: fs.Dir,
    root_name: []const u8,
    template_path: []const u8,
    fingerprint: std.zig.Package.Fingerprint,
    zig_version_string: []const u8,
) !void {
    if (fs.path.dirname(template_path)) |dirname| {
        out_dir.makePath(dirname) catch |err| {
            fatal("unable to make path '{s}': {s}", .{ dirname, @errorName(err) });
        };
    }

    const max_bytes = 10 * 1024 * 1024;
    const contents = templates.dir.readFileAlloc(gpa, template_path, max_bytes) catch |err| {
        fatal("unable to read template file '{s}': {s}", .{ template_path, @errorName(err) });
    };
    defer gpa.free(contents);
    templates.buffer.clearRetainingCapacity();
    try templates.buffer.ensureUnusedCapacity(gpa, contents.len);
    var i: usize = 0;
    while (i < contents.len) {
        if (contents[i] == '.') {
            if (std.mem.startsWith(u8, contents[i..], ".LITNAME")) {
                try templates.buffer.append(gpa, '.');
                try templates.buffer.appendSlice(gpa, root_name);
                i += ".LITNAME".len;
                continue;
            } else if (std.mem.startsWith(u8, contents[i..], ".NAME")) {
                try templates.buffer.appendSlice(gpa, root_name);
                i += ".NAME".len;
                continue;
            } else if (std.mem.startsWith(u8, contents[i..], ".FINGERPRINT")) {
                try templates.buffer.writer(gpa).print("0x{x}", .{fingerprint.int()});
                i += ".FINGERPRINT".len;
                continue;
            } else if (std.mem.startsWith(u8, contents[i..], ".ZIGVER")) {
                try templates.buffer.appendSlice(gpa, zig_version_string);
                i += ".ZIGVER".len;
                continue;
            }
        }
        try templates.buffer.append(gpa, contents[i]);
        i += 1;
    }

    return out_dir.writeFile(.{
        .sub_path = template_path,
        .data = templates.buffer.items,
        .flags = .{ .exclusive = true },
    });
}
