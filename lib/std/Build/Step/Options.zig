const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const Step = std.Build.Step;
const GeneratedFile = std.Build.GeneratedFile;
const LazyPath = std.Build.LazyPath;

const Options = @This();

pub const base_id: Step.Id = .options;
const indent_width = 4;

step: Step,
generated_file: GeneratedFile,

contents: std.ArrayListUnmanaged(u8),
args: std.ArrayListUnmanaged(Arg),
printed_types: std.StringHashMapUnmanaged(void),

pub fn create(owner: *std.Build) *Options {
    const options = owner.allocator.create(Options) catch @panic("OOM");
    options.* = .{
        .step = .init(.{
            .id = base_id,
            .name = "options",
            .owner = owner,
            .makeFn = make,
        }),
        .generated_file = undefined,
        .contents = .empty,
        .args = .empty,
        .printed_types = .empty,
    };
    options.generated_file = .{ .step = &options.step };

    return options;
}

pub fn addOption(options: *Options, comptime T: type, name: []const u8, value: T) void {
    return printDecl(options, T, name, value) catch @panic("unhandled error");
}

fn printDecl(options: *Options, comptime T: type, name: []const u8, value: T) !void {
    const gpa = options.step.owner.allocator;
    const out = &options.contents;
    try printTypeDefinition(options, T);
    try out.print(gpa, "pub const {f}: ", .{std.zig.fmtId(name)});
    try printTypeName(options, T, 0);
    try out.appendSlice(gpa, " = ");
    try printValue(options, T, value, 0);
    try out.appendSlice(gpa, ";\n\n");
}

fn printTypeDefinition(options: *Options, comptime T: type) !void {
    if (T == std.SemanticVersion) return;

    const type_info = @typeInfo(T);
    switch (type_info) {
        inline .array, .pointer, .optional => |info| return printTypeDefinition(options, info.child),
        .@"enum", .@"struct", .@"union" => {},
        else => return,
    }

    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    const gop = try options.printed_types.getOrPut(gpa, @typeName(T));
    if (gop.found_existing) return;

    switch (type_info) {
        .@"enum" => {
            try out.print(gpa, "pub const {f} = ", .{std.zig.fmtId(@typeName(T))});
            try printEnumDefinition(options, T);
            try out.appendSlice(gpa, ";\n\n");
        },
        .@"struct" => |@"struct"| {
            inline for (@"struct".fields) |field| {
                try printTypeDefinition(options, field.type);
            }

            if (@"struct".is_tuple) return;

            try out.print(gpa, "pub const {f} = ", .{std.zig.fmtId(@typeName(T))});
            try printStructDefinition(options, T, 0);
            try out.appendSlice(gpa, ";\n\n");
        },
        .@"union" => |@"union"| {
            inline for (@"union".fields) |field| {
                try printTypeDefinition(options, field.type);
            }

            try out.print(gpa, "pub const {f} = ", .{std.zig.fmtId(@typeName(T))});
            try printUnionDefinition(options, T);
            try out.appendSlice(gpa, ";\n\n");
        },
        else => comptime unreachable,
    }
}

fn printEnumDefinition(options: *Options, comptime T: type) !void {
    const @"enum" = @typeInfo(T).@"enum";
    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    try out.appendSlice(gpa, "enum(");
    try printTypeName(options, @"enum".tag_type, indent_width);
    try out.appendSlice(gpa, ")");
    if (@"enum".fields.len == 0 and @"enum".is_exhaustive) return out.appendSlice(gpa, " {}");
    try out.appendSlice(gpa, " {\n");

    inline for (@"enum".fields) |field| {
        try out.print(gpa, " " ** indent_width ++ "{f} = {d},\n", .{ std.zig.fmtIdFlags(field.name, .{ .allow_primitive = true }), field.value });
    }

    if (!@"enum".is_exhaustive) {
        try out.appendSlice(gpa, " " ** indent_width ++ "_,\n");
    }

    try out.appendSlice(gpa, "}");
}

fn printStructDefinition(options: *Options, comptime T: type, indent: u8) !void {
    const @"struct" = @typeInfo(T).@"struct";
    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    switch (@"struct".layout) {
        .auto => try out.appendSlice(gpa, "struct"),
        .@"extern" => try out.appendSlice(gpa, "extern struct"),
        .@"packed" => {
            try out.appendSlice(gpa, "packed struct(");
            try printTypeName(options, @"struct".backing_integer.?, indent);
            try out.appendSlice(gpa, ")");
        },
    }
    if (@"struct".fields.len == 0) return out.appendSlice(gpa, " {}");
    try out.appendSlice(gpa, " {\n");

    inline for (@"struct".fields) |field| {
        const field_indent = indent +| indent_width;
        try out.appendNTimes(gpa, ' ', field_indent);
        if (field.is_comptime) try out.appendSlice(gpa, "comptime ");
        if (!@"struct".is_tuple) try out.print(gpa, "{f}: ", .{std.zig.fmtIdFlags(field.name, .{ .allow_underscore = true, .allow_primitive = true })});
        try printTypeName(options, field.type, field_indent);
        if (!@"struct".is_tuple and @"struct".layout != .@"packed" and field.alignment != @alignOf(field.type)) {
            try out.print(gpa, " align({})", .{field.alignment});
        }
        if (field.defaultValue()) |default_value| {
            try out.appendSlice(gpa, " = ");
            try printValue(options, field.type, default_value, field_indent);
        }
        try out.appendSlice(gpa, ",\n");
    }

    try out.appendNTimes(gpa, ' ', indent);
    try out.appendSlice(gpa, "}");
}

fn printUnionDefinition(options: *Options, comptime T: type) !void {
    const @"union" = @typeInfo(T).@"union";
    if (@"union".layout != .auto) {
        unsupported(@tagName(@"union".layout) ++ " union");
    }
    const tag_type = @"union".tag_type orelse unsupported("untagged union");

    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    try out.appendSlice(gpa, "union(");
    try printTypeName(options, tag_type, indent_width);
    try out.appendSlice(gpa, ")");
    if (@"union".fields.len == 0) return out.appendSlice(gpa, " {}");
    try out.appendSlice(gpa, " {\n");

    inline for (@"union".fields) |field| {
        try out.appendSlice(gpa, " " ** indent_width);
        try out.print(gpa, "{f}: ", .{std.zig.fmtIdFlags(field.name, .{ .allow_underscore = true, .allow_primitive = true })});
        try printTypeName(options, field.type, indent_width);
        if (field.alignment != @alignOf(field.type)) {
            try out.print(gpa, " align({})", .{field.alignment});
        }
        try out.appendSlice(gpa, ",\n");
    }

    try out.appendSlice(gpa, "}");
}

fn printTypeName(options: *Options, comptime T: type, indent: u8) !void {
    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    if (T == std.SemanticVersion) {
        return out.appendSlice(gpa, "@import(\"std\").SemanticVersion");
    }

    switch (@typeInfo(T)) {
        .array => |array| {
            try out.print(gpa, "[{}", .{array.len});
            if (array.sentinel()) |sentinel| {
                try out.appendSlice(gpa, ":");
                try printValue(options, array.child, sentinel, indent);
            }
            try out.appendSlice(gpa, "]");
            try printTypeName(options, array.child, indent);
        },
        .pointer => |pointer| {
            if (pointer.size != .slice) {
                unsupported("non-slice pointer");
            }

            try out.appendSlice(gpa, "[");
            if (pointer.sentinel()) |sentinel| {
                try out.appendSlice(gpa, ":");
                try printValue(options, pointer.child, sentinel, indent);
            }
            try out.appendSlice(gpa, "]const ");
            try printTypeName(options, pointer.child, indent);
        },
        .optional => |optional| {
            try out.appendSlice(gpa, "?");
            try printTypeName(options, optional.child, indent);
        },
        .void,
        .bool,
        .int,
        .float,
        .comptime_int,
        .comptime_float,
        .enum_literal,
        => try out.print(gpa, "{s}", .{@typeName(T)}),
        .@"enum" => try out.print(gpa, "{f}", .{std.zig.fmtId(@typeName(T))}),
        .@"struct" => |@"struct"| {
            if (@"struct".is_tuple) {
                try printStructDefinition(options, T, indent);
            } else {
                try out.print(gpa, "{f}", .{std.zig.fmtId(@typeName(T))});
            }
        },
        .@"union" => try out.print(gpa, "{f}", .{std.zig.fmtId(@typeName(T))}),
        else => |tag| unsupported(@tagName(tag)),
    }
}

fn printValue(options: *Options, comptime T: type, value: T, indent: u8) !void {
    const gpa = options.step.owner.allocator;
    const out = &options.contents;

    if (T == []const u8 or T == [:0]const u8) {
        return out.print(gpa, "\"{f}\"", .{std.zig.fmtString(value)});
    }

    switch (@typeInfo(T)) {
        inline .array, .pointer => |type_info, tag| {
            if (tag == .pointer) try out.appendSlice(gpa, "&");
            if (value.len == 0) return out.appendSlice(gpa, ".{}");

            try out.appendSlice(gpa, ".{\n");
            for (value) |item| {
                const elem_indent = indent +| indent_width;
                try out.appendNTimes(gpa, ' ', elem_indent);
                try printValue(options, type_info.child, item, elem_indent);
                try out.appendSlice(gpa, ",\n");
            }
            try out.appendNTimes(gpa, ' ', indent);
            try out.appendSlice(gpa, "}");
        },
        .optional => |optional| {
            if (value) |inner| {
                try printValue(options, optional.child, inner, indent);
            } else {
                try out.appendSlice(gpa, "@as(");
                try printTypeName(options, T, indent);
                try out.appendSlice(gpa, ", null)");
            }
        },
        .void,
        .bool,
        .int,
        .float,
        .comptime_int,
        .comptime_float,
        .enum_literal,
        => try out.print(gpa, "{any}", .{value}),
        .@"enum" => |@"enum"| {
            if (@"enum".is_exhaustive) {
                try out.print(gpa, ".{f}", .{std.zig.fmtIdFlags(@tagName(value), .{ .allow_underscore = true, .allow_primitive = true })});
            } else {
                if (std.enums.tagName(T, value)) |name| {
                    try out.print(gpa, ".{f}", .{std.zig.fmtIdFlags(name, .{ .allow_underscore = true, .allow_primitive = true })});
                } else {
                    try out.print(gpa, "@enumFromInt({})", .{@intFromEnum(value)});
                }
            }
        },
        .@"struct" => |@"struct"| {
            if (@"struct".fields.len == 0) return out.appendSlice(gpa, ".{}");

            try out.appendSlice(gpa, ".{\n");
            inline for (@"struct".fields) |field| {
                const field_indent = indent +| indent_width;
                try out.appendNTimes(gpa, ' ', field_indent);
                if (!@"struct".is_tuple) try out.print(gpa, ".{f} = ", .{std.zig.fmtIdFlags(field.name, .{ .allow_primitive = true, .allow_underscore = true })});
                try printValue(options, field.type, @field(value, field.name), field_indent);
                try out.appendSlice(gpa, ",\n");
            }
            try out.appendNTimes(gpa, ' ', indent);
            try out.appendSlice(gpa, "}");
        },
        .@"union" => {
            try out.appendSlice(gpa, ".{ ");
            switch (value) {
                inline else => |payload, tag| {
                    try out.print(gpa, ".{f} = ", .{std.zig.fmtIdFlags(@tagName(tag), .{ .allow_primitive = true, .allow_underscore = true })});
                    try printValue(options, @TypeOf(payload), payload, indent);
                },
            }
            try out.appendSlice(gpa, " }");
        },
        else => |tag| unsupported(@tagName(tag)),
    }
}

inline fn unsupported(comptime str: []const u8) noreturn {
    @compileError(std.fmt.comptimePrint("'{s}' not supported within build options", .{str}));
}

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionPath(
    options: *Options,
    name: []const u8,
    path: LazyPath,
) void {
    const arena = options.step.owner.allocator;
    options.args.append(arena, .{
        .name = options.step.owner.dupe(name),
        .path = path.dupe(options.step.owner),
    }) catch @panic("OOM");
    path.addStepDependencies(&options.step);
}

pub fn createModule(options: *Options) *std.Build.Module {
    return options.step.owner.createModule(.{
        .root_source_file = options.getOutput(),
    });
}

/// Returns the main artifact of this Build Step which is a Zig source file
/// generated from the key-value pairs of the Options.
pub fn getOutput(options: *Options) LazyPath {
    return .{ .generated = .{ .file = &options.generated_file } };
}

fn make(step: *Step, make_options: Step.MakeOptions) !void {
    // This step completes so quickly that no progress reporting is necessary.
    _ = make_options;

    const b = step.owner;
    const options: *Options = @fieldParentPtr("step", step);

    for (options.args.items) |item| {
        options.addOption(
            []const u8,
            item.name,
            item.path.getPath2(b, step),
        );
    }
    if (!step.inputs.populated()) for (options.args.items) |item| {
        try step.addWatchInput(item.path);
    };

    const basename = "options.zig";

    // Hash contents to file name.
    var hash = b.graph.cache.hash;
    // Random bytes to make unique. Refresh this with new random bytes when
    // implementation is modified in a non-backwards-compatible way.
    hash.add(@as(u32, 0xad95e922));
    hash.addBytes(options.contents.items);
    const sub_path = "c" ++ fs.path.sep_str ++ hash.final() ++ fs.path.sep_str ++ basename;

    options.generated_file.path = try b.cache_root.join(b.allocator, &.{sub_path});

    // Optimize for the hot path. Stat the file, and if it already exists,
    // cache hit.
    if (b.cache_root.handle.access(sub_path, .{})) |_| {
        // This is the hot path, success.
        step.result_cached = true;
        return;
    } else |outer_err| switch (outer_err) {
        error.FileNotFound => {
            const sub_dirname = fs.path.dirname(sub_path).?;
            b.cache_root.handle.makePath(sub_dirname) catch |e| {
                return step.fail("unable to make path '{f}{s}': {s}", .{
                    b.cache_root, sub_dirname, @errorName(e),
                });
            };

            const rand_int = std.crypto.random.int(u64);
            const tmp_sub_path = "tmp" ++ fs.path.sep_str ++
                std.fmt.hex(rand_int) ++ fs.path.sep_str ++
                basename;
            const tmp_sub_path_dirname = fs.path.dirname(tmp_sub_path).?;

            b.cache_root.handle.makePath(tmp_sub_path_dirname) catch |err| {
                return step.fail("unable to make temporary directory '{f}{s}': {s}", .{
                    b.cache_root, tmp_sub_path_dirname, @errorName(err),
                });
            };

            b.cache_root.handle.writeFile(.{ .sub_path = tmp_sub_path, .data = options.contents.items }) catch |err| {
                return step.fail("unable to write options to '{f}{s}': {s}", .{
                    b.cache_root, tmp_sub_path, @errorName(err),
                });
            };

            b.cache_root.handle.rename(tmp_sub_path, sub_path) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    // Other process beat us to it. Clean up the temp file.
                    b.cache_root.handle.deleteFile(tmp_sub_path) catch |e| {
                        try step.addError("warning: unable to delete temp file '{f}{s}': {s}", .{
                            b.cache_root, tmp_sub_path, @errorName(e),
                        });
                    };
                    step.result_cached = true;
                    return;
                },
                else => {
                    return step.fail("unable to rename options from '{f}{s}' to '{f}{s}': {s}", .{
                        b.cache_root,    tmp_sub_path,
                        b.cache_root,    sub_path,
                        @errorName(err),
                    });
                },
            };
        },
        else => |e| return step.fail("unable to access options file '{f}{s}': {s}", .{
            b.cache_root, sub_path, @errorName(e),
        }),
    }
}

const Arg = struct {
    name: []const u8,
    path: LazyPath,
};

test Options {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var graph: std.Build.Graph = .{
        .arena = arena.allocator(),
        .cache = .{
            .gpa = arena.allocator(),
            .manifest_dir = std.fs.cwd(),
        },
        .zig_exe = "test",
        .env_map = std.process.EnvMap.init(arena.allocator()),
        .global_cache_root = .{ .path = "test", .handle = std.fs.cwd() },
        .host = .{
            .query = .{},
            .result = try std.zig.system.resolveTargetQuery(.{}),
        },
        .zig_lib_directory = std.Build.Cache.Directory.cwd(),
        .time_report = false,
    };

    var builder = try std.Build.create(
        &graph,
        .{ .path = "test", .handle = std.fs.cwd() },
        .{ .path = "test", .handle = std.fs.cwd() },
        &.{},
    );

    const options = builder.addOptions();

    const KeywordEnum = enum {
        @"0.8.1",
    };

    const NormalEnum = enum {
        foo,
        bar,
    };

    const nested_array = [2][2]u16{
        [2]u16{ 300, 200 },
        [2]u16{ 300, 200 },
    };
    const nested_slice: []const []const u16 = &[_][]const u16{ &nested_array[0], &nested_array[1] };

    const NormalStruct = struct {
        hello: ?[]const u8,
        world: bool = true,
    };

    const NestedStruct = struct {
        normal_struct: NormalStruct,
        normal_enum: NormalEnum = .foo,
    };

    options.addOption(usize, "option1", 1);
    options.addOption(?usize, "option2", null);
    options.addOption(?usize, "option3", 3);
    options.addOption(comptime_int, "option4", 4);
    options.addOption([]const u8, "string", "zigisthebest");
    options.addOption(?[]const u8, "optional_string", null);
    options.addOption([2][2]u16, "nested_array", nested_array);
    options.addOption([]const []const u16, "nested_slice", nested_slice);
    options.addOption(KeywordEnum, "keyword_enum", .@"0.8.1");
    options.addOption(std.SemanticVersion, "semantic_version", try std.SemanticVersion.parse("0.1.2-foo+bar"));
    options.addOption(NormalEnum, "normal1_enum", NormalEnum.foo);
    options.addOption(NormalEnum, "normal2_enum", NormalEnum.bar);
    options.addOption(NormalStruct, "normal1_struct", NormalStruct{
        .hello = "foo",
    });
    options.addOption(NormalStruct, "normal2_struct", NormalStruct{
        .hello = null,
        .world = false,
    });
    options.addOption(NestedStruct, "nested_struct", NestedStruct{
        .normal_struct = .{ .hello = "bar" },
    });

    try std.testing.expectEqualStrings(
        \\pub const option1: usize = 1;
        \\
        \\pub const option2: ?usize = @as(?usize, null);
        \\
        \\pub const option3: ?usize = 3;
        \\
        \\pub const option4: comptime_int = 4;
        \\
        \\pub const string: []const u8 = "zigisthebest";
        \\
        \\pub const optional_string: ?[]const u8 = @as(?[]const u8, null);
        \\
        \\pub const nested_array: [2][2]u16 = .{
        \\    .{
        \\        300,
        \\        200,
        \\    },
        \\    .{
        \\        300,
        \\        200,
        \\    },
        \\};
        \\
        \\pub const nested_slice: []const []const u16 = &.{
        \\    &.{
        \\        300,
        \\        200,
        \\    },
        \\    &.{
        \\        300,
        \\        200,
        \\    },
        \\};
        \\
        \\pub const @"Build.Step.Options.decltest.Options.KeywordEnum" = enum(u0) {
        \\    @"0.8.1" = 0,
        \\};
        \\
        \\pub const keyword_enum: @"Build.Step.Options.decltest.Options.KeywordEnum" = .@"0.8.1";
        \\
        \\pub const semantic_version: @import("std").SemanticVersion = .{
        \\    .major = 0,
        \\    .minor = 1,
        \\    .patch = 2,
        \\    .pre = "foo",
        \\    .build = "bar",
        \\};
        \\
        \\pub const @"Build.Step.Options.decltest.Options.NormalEnum" = enum(u1) {
        \\    foo = 0,
        \\    bar = 1,
        \\};
        \\
        \\pub const normal1_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .foo;
        \\
        \\pub const normal2_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .bar;
        \\
        \\pub const @"Build.Step.Options.decltest.Options.NormalStruct" = struct {
        \\    hello: ?[]const u8,
        \\    world: bool = true,
        \\};
        \\
        \\pub const normal1_struct: @"Build.Step.Options.decltest.Options.NormalStruct" = .{
        \\    .hello = "foo",
        \\    .world = true,
        \\};
        \\
        \\pub const normal2_struct: @"Build.Step.Options.decltest.Options.NormalStruct" = .{
        \\    .hello = @as(?[]const u8, null),
        \\    .world = false,
        \\};
        \\
        \\pub const @"Build.Step.Options.decltest.Options.NestedStruct" = struct {
        \\    normal_struct: @"Build.Step.Options.decltest.Options.NormalStruct",
        \\    normal_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .foo,
        \\};
        \\
        \\pub const nested_struct: @"Build.Step.Options.decltest.Options.NestedStruct" = .{
        \\    .normal_struct = .{
        \\        .hello = "bar",
        \\        .world = true,
        \\    },
        \\    .normal_enum = .foo,
        \\};
        \\
        \\
    , options.contents.items);

    _ = try std.zig.Ast.parse(arena.allocator(), try options.contents.toOwnedSliceSentinel(arena.allocator(), 0), .zig);
}
