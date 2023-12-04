const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);
    if (args.len < 1) usageAndExit(std.io.getStdErr(), "update_x86_cpu_model_enums", 1);
    if (args.len == 1) usageAndExit(std.io.getStdErr(), args[0], 1);
    if (std.mem.eql(u8, args[1], "--help")) usageAndExit(std.io.getStdOut(), args[0], 0);
    if (args.len != 4) usageAndExit(std.io.getStdErr(), args[0], 1);

    const zig_exe = args[1];
    if (std.mem.startsWith(u8, zig_exe, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const llvm_src_root = args[2];
    if (std.mem.startsWith(u8, llvm_src_root, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const zig_src_root = args[3];
    if (std.mem.startsWith(u8, zig_src_root, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    var zig_src_dir = try std.fs.cwd().openDir(zig_src_root, .{});
    defer zig_src_dir.close();

    const def_file_path = try std.fs.path.join(arena, &.{
        llvm_src_root,
        "llvm/include/llvm/TargetParser/X86TargetParser.def",
    });

    var out_file = try zig_src_dir.createFile("lib/compiler_rt/cpu_model/x86.zig", .{});
    defer out_file.close();

    const vendor_enum = blk: {
        const raw_enum_names = try preprocessCPUEnum(arena, zig_exe, def_file_path, "X86_VENDOR(id, _1)=id");

        const enum_names = try arena.alloc([]const u8, raw_enum_names.len + 2);

        enum_names[0] = "unknown";
        for (enum_names[1..][0..raw_enum_names.len], raw_enum_names) |*name, raw| {
            std.debug.assert(std.mem.startsWith(u8, raw, "VENDOR_"));
            name.* = try llvmNameToZigName(arena, raw[7..]);
        }
        enum_names[1 + raw_enum_names.len] = "other";

        break :blk enum_names;
    };
    try writeEnum(out_file, "Vendor", vendor_enum);

    const type_enum = blk: {
        const raw_enum_names = try preprocessCPUEnum(arena, zig_exe, def_file_path, "X86_CPU_TYPE(id, _1)=id");

        const enum_names = try arena.alloc([]const u8, raw_enum_names.len + 1);

        enum_names[0] = "unknown";
        for (enum_names[1..][0..raw_enum_names.len], raw_enum_names) |*name, raw| {
            name.* = try llvmNameToZigName(arena, raw);
        }

        break :blk enum_names;
    };
    try writeEnum(out_file, "Type", type_enum);

    const subtype_enum = blk: {
        const raw_enum_names = try preprocessCPUEnum(arena, zig_exe, def_file_path, "X86_CPU_SUBTYPE(id, _1)=id");

        const enum_names = try arena.alloc([]const u8, raw_enum_names.len + 1);

        enum_names[0] = "unknown";
        for (enum_names[1..][0..raw_enum_names.len], raw_enum_names) |*name, raw| {
            name.* = try llvmNameToZigName(arena, raw);
        }

        break :blk enum_names;
    };
    try writeEnum(out_file, "Subtype", subtype_enum);

    const features_enum = blk: {
        const raw_enum_names = try preprocessCPUEnum(arena, zig_exe, def_file_path, "X86_FEATURE_COMPAT(_0,name,_2)=name");

        const enum_names = try arena.alloc([]const u8, raw_enum_names.len);

        for (enum_names, raw_enum_names) |*name, raw| {
            std.debug.assert(std.mem.startsWith(u8, raw, "\""));
            std.debug.assert(std.mem.endsWith(u8, raw, "\""));
            name.* = try llvmNameToZigName(arena, raw[1 .. raw.len - 1]);
        }

        break :blk enum_names;
    };
    try writeEnum(out_file, "Feature", features_enum);
}

fn usageAndExit(file: std.fs.File, arg0: []const u8, code: u8) noreturn {
    file.writer().print(
        \\Usage: {s} /path/to/zig-exe /path/to/llvm-project /path/to/zig-project
        \\
        \\Updates lib/compiler-rt/cpu_model/x86.zig from llvm/include/llvm/TargetParser/X86TargetParser.def
        \\
    , .{arg0}) catch std.process.exit(1);
    std.process.exit(code);
}

// `define` parameter is passed to the preprocessor as a `-D` and extract the enum names line by line
fn preprocessCPUEnum(arena: std.mem.Allocator, zig_exe: []const u8, def_path: []const u8, define: []const u8) ![]const []const u8 {
    const preprocessed = blk: {
        const argv = try arena.alloc([]const u8, 7);
        argv[0] = zig_exe;
        argv[1] = "cc";
        argv[2] = "-P";
        argv[3] = "-E";
        argv[4] = "-xc";
        argv[5] = try std.mem.concat(arena, u8, &.{ "-D", define });
        argv[6] = def_path;

        const result = try std.process.Child.run(.{
            .allocator = arena,
            .argv = argv,

            .max_output_bytes = 1024 * 1024,
        });
        if (result.stderr.len != 0) {
            std.debug.print("{s}\n", .{result.stderr});
            return error.ChildError;
        }
        if (result.term != .Exited) return error.ChildError;
        break :blk result.stdout;
    };

    var enum_fields = std.ArrayList([]const u8).init(arena);

    var lines = std.mem.tokenizeScalar(u8, preprocessed, '\n');
    while (lines.next()) |line| {
        try enum_fields.append(line);
    }

    return try enum_fields.toOwnedSlice();
}

fn writeEnum(file: std.fs.File, enum_name: []const u8, enum_field: []const []const u8) !void {
    var writer = file.writer();

    try writer.print(
        \\pub const {s} = enum(u32) {{
        \\
    , .{enum_name});
    for (enum_field) |f| {
        if (f.len == 0) continue;

        if (std.ascii.isAlphabetic(f[0]) or f[0] == '_') {
            try writer.print(
                \\    {s},
                \\
            , .{f});
        } else {
            try writer.print(
                \\    @"{s}",
                \\
            , .{f});
        }
    }
    try writer.writeAll(
        \\};
        \\
    );
}

fn llvmNameToZigName(arena: std.mem.Allocator, llvm_name: []const u8) ![]const u8 {
    const duped = try arena.dupe(u8, llvm_name);
    for (duped) |*byte| switch (byte.*) {
        '-', '.' => byte.* = '_',
        else => byte.* = std.ascii.toLower(byte.*),
    };
    return duped;
}
