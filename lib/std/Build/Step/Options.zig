const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const Step = std.Build.Step;
const GeneratedFile = std.Build.GeneratedFile;
const LazyPath = std.Build.LazyPath;

const Options = @This();

pub const base_id: Step.Id = .options;

step: Step,
generated_file: GeneratedFile,

contents: std.ArrayList(u8),
args: std.ArrayList(Arg),
encountered_types: std.StringHashMap(void),

pub fn create(owner: *std.Build) *Options {
    const options = owner.allocator.create(Options) catch @panic("OOM");
    options.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "options",
            .owner = owner,
            .makeFn = make,
        }),
        .generated_file = undefined,
        .contents = std.ArrayList(u8).init(owner.allocator),
        .args = std.ArrayList(Arg).init(owner.allocator),
        .encountered_types = std.StringHashMap(void).init(owner.allocator),
    };
    options.generated_file = .{ .step = &options.step };

    return options;
}

pub fn addOption(options: *Options, comptime T: type, name: []const u8, value: T) void {
    return addOptionFallible(options, T, name, value) catch @panic("unhandled error");
}

fn addOptionFallible(options: *Options, comptime T: type, name: []const u8, value: T) !void {
    const out = options.contents.writer();
    try printType(options, out, T, value, 0, name);
}

fn printType(options: *Options, out: anytype, comptime T: type, value: T, indent: u8, name: ?[]const u8) !void {
    switch (T) {
        []const []const u8 => {
            if (name) |payload| {
                try out.print("pub const {}: []const []const u8 = ", .{std.zig.fmtId(payload)});
            }

            try out.writeAll("&[_][]const u8{\n");

            for (value) |slice| {
                try out.writeByteNTimes(' ', indent);
                try out.print("    \"{}\",\n", .{std.zig.fmtEscapes(slice)});
            }

            if (name != null) {
                try out.writeAll("};\n");
            } else {
                try out.writeAll("},\n");
            }

            return;
        },
        []const u8 => {
            if (name) |some| {
                try out.print("pub const {}: []const u8 = \"{}\";", .{ std.zig.fmtId(some), std.zig.fmtEscapes(value) });
            } else {
                try out.print("\"{}\",", .{std.zig.fmtEscapes(value)});
            }
            return out.writeAll("\n");
        },
        [:0]const u8 => {
            if (name) |some| {
                try out.print("pub const {}: [:0]const u8 = \"{}\";", .{ std.zig.fmtId(some), std.zig.fmtEscapes(value) });
            } else {
                try out.print("\"{}\",", .{std.zig.fmtEscapes(value)});
            }
            return out.writeAll("\n");
        },
        ?[]const u8 => {
            if (name) |some| {
                try out.print("pub const {}: ?[]const u8 = ", .{std.zig.fmtId(some)});
            }

            if (value) |payload| {
                try out.print("\"{}\"", .{std.zig.fmtEscapes(payload)});
            } else {
                try out.writeAll("null");
            }

            if (name != null) {
                try out.writeAll(";\n");
            } else {
                try out.writeAll(",\n");
            }
            return;
        },
        ?[:0]const u8 => {
            if (name) |some| {
                try out.print("pub const {}: ?[:0]const u8 = ", .{std.zig.fmtId(some)});
            }

            if (value) |payload| {
                try out.print("\"{}\"", .{std.zig.fmtEscapes(payload)});
            } else {
                try out.writeAll("null");
            }

            if (name != null) {
                try out.writeAll(";\n");
            } else {
                try out.writeAll(",\n");
            }
            return;
        },
        std.SemanticVersion => {
            if (name) |some| {
                try out.print("pub const {}: @import(\"std\").SemanticVersion = ", .{std.zig.fmtId(some)});
            }

            try out.writeAll(".{\n");
            try out.writeByteNTimes(' ', indent);
            try out.print("    .major = {d},\n", .{value.major});
            try out.writeByteNTimes(' ', indent);
            try out.print("    .minor = {d},\n", .{value.minor});
            try out.writeByteNTimes(' ', indent);
            try out.print("    .patch = {d},\n", .{value.patch});

            if (value.pre) |some| {
                try out.writeByteNTimes(' ', indent);
                try out.print("    .pre = \"{}\",\n", .{std.zig.fmtEscapes(some)});
            }
            if (value.build) |some| {
                try out.writeByteNTimes(' ', indent);
                try out.print("    .build = \"{}\",\n", .{std.zig.fmtEscapes(some)});
            }

            if (name != null) {
                try out.writeAll("};\n");
            } else {
                try out.writeAll("},\n");
            }
            return;
        },
        else => {},
    }

    switch (@typeInfo(T)) {
        .array => {
            if (name) |some| {
                try out.print("pub const {}: {s} = ", .{ std.zig.fmtId(some), @typeName(T) });
            }

            try out.print("{s} {{\n", .{@typeName(T)});
            for (value) |item| {
                try out.writeByteNTimes(' ', indent + 4);
                try printType(options, out, @TypeOf(item), item, indent + 4, null);
            }
            try out.writeByteNTimes(' ', indent);
            try out.writeAll("}");

            if (name != null) {
                try out.writeAll(";\n");
            } else {
                try out.writeAll(",\n");
            }
            return;
        },
        .pointer => |p| {
            if (p.size != .Slice) {
                @compileError("Non-slice pointers are not yet supported in build options");
            }

            if (name) |some| {
                try out.print("pub const {}: {s} = ", .{ std.zig.fmtId(some), @typeName(T) });
            }

            try out.print("&[_]{s} {{\n", .{@typeName(p.child)});
            for (value) |item| {
                try out.writeByteNTimes(' ', indent + 4);
                try printType(options, out, @TypeOf(item), item, indent + 4, null);
            }
            try out.writeByteNTimes(' ', indent);
            try out.writeAll("}");

            if (name != null) {
                try out.writeAll(";\n");
            } else {
                try out.writeAll(",\n");
            }
            return;
        },
        .optional => {
            if (name) |some| {
                try out.print("pub const {}: {s} = ", .{ std.zig.fmtId(some), @typeName(T) });
            }

            if (value) |inner| {
                try printType(options, out, @TypeOf(inner), inner, indent + 4, null);
                // Pop the '\n' and ',' chars
                _ = options.contents.pop();
                _ = options.contents.pop();
            } else {
                try out.writeAll("null");
            }

            if (name != null) {
                try out.writeAll(";\n");
            } else {
                try out.writeAll(",\n");
            }
            return;
        },
        .void,
        .bool,
        .int,
        .comptime_int,
        .float,
        .null,
        => {
            if (name) |some| {
                try out.print("pub const {}: {s} = {any};\n", .{ std.zig.fmtId(some), @typeName(T), value });
            } else {
                try out.print("{any},\n", .{value});
            }
            return;
        },
        .@"enum" => |info| {
            try printEnum(options, out, T, info, indent);

            if (name) |some| {
                try out.print("pub const {}: {} = .{p_};\n", .{
                    std.zig.fmtId(some),
                    std.zig.fmtId(@typeName(T)),
                    std.zig.fmtId(@tagName(value)),
                });
            }
            return;
        },
        .@"struct" => |info| {
            try printStruct(options, out, T, info, indent);

            if (name) |some| {
                try out.print("pub const {}: {} = ", .{
                    std.zig.fmtId(some),
                    std.zig.fmtId(@typeName(T)),
                });
                try printStructValue(options, out, info, value, indent);
            }
            return;
        },
        else => @compileError(std.fmt.comptimePrint("`{s}` are not yet supported as build options", .{@tagName(@typeInfo(T))})),
    }
}

fn printUserDefinedType(options: *Options, out: anytype, comptime T: type, indent: u8) !void {
    switch (@typeInfo(T)) {
        .@"enum" => |info| {
            return try printEnum(options, out, T, info, indent);
        },
        .@"struct" => |info| {
            return try printStruct(options, out, T, info, indent);
        },
        else => {},
    }
}

fn printEnum(options: *Options, out: anytype, comptime T: type, comptime val: std.builtin.Type.Enum, indent: u8) !void {
    const gop = try options.encountered_types.getOrPut(@typeName(T));
    if (gop.found_existing) return;

    try out.writeByteNTimes(' ', indent);
    try out.print("pub const {} = enum ({s}) {{\n", .{ std.zig.fmtId(@typeName(T)), @typeName(val.tag_type) });

    inline for (val.fields) |field| {
        try out.writeByteNTimes(' ', indent);
        try out.print("    {p} = {d},\n", .{ std.zig.fmtId(field.name), field.value });
    }

    if (!val.is_exhaustive) {
        try out.writeByteNTimes(' ', indent);
        try out.writeAll("    _,\n");
    }

    try out.writeByteNTimes(' ', indent);
    try out.writeAll("};\n");
}

fn printStruct(options: *Options, out: anytype, comptime T: type, comptime val: std.builtin.Type.Struct, indent: u8) !void {
    const gop = try options.encountered_types.getOrPut(@typeName(T));
    if (gop.found_existing) return;

    try out.writeByteNTimes(' ', indent);
    try out.print("pub const {} = ", .{std.zig.fmtId(@typeName(T))});

    switch (val.layout) {
        .@"extern" => try out.writeAll("extern struct"),
        .@"packed" => try out.writeAll("packed struct"),
        else => try out.writeAll("struct"),
    }

    try out.writeAll(" {\n");

    inline for (val.fields) |field| {
        try out.writeByteNTimes(' ', indent);

        const type_name = @typeName(field.type);

        // If the type name doesn't contains a '.' the type is from zig builtins.
        if (std.mem.containsAtLeast(u8, type_name, 1, ".")) {
            try out.print("    {p_}: {}", .{ std.zig.fmtId(field.name), std.zig.fmtId(type_name) });
        } else {
            try out.print("    {p_}: {s}", .{ std.zig.fmtId(field.name), type_name });
        }

        if (field.default_value != null) {
            const default_value = @as(*field.type, @ptrCast(@alignCast(@constCast(field.default_value.?)))).*;

            try out.writeAll(" = ");
            switch (@typeInfo(@TypeOf(default_value))) {
                .@"enum" => try out.print(".{s},\n", .{@tagName(default_value)}),
                .@"struct" => |info| {
                    try printStructValue(options, out, info, default_value, indent + 4);
                },
                else => try printType(options, out, @TypeOf(default_value), default_value, indent, null),
            }
        } else {
            try out.writeAll(",\n");
        }
    }

    // TODO: write declarations

    try out.writeByteNTimes(' ', indent);
    try out.writeAll("};\n");

    inline for (val.fields) |field| {
        try printUserDefinedType(options, out, field.type, 0);
    }
}

fn printStructValue(options: *Options, out: anytype, comptime struct_val: std.builtin.Type.Struct, val: anytype, indent: u8) !void {
    try out.writeAll(".{\n");

    if (struct_val.is_tuple) {
        inline for (struct_val.fields) |field| {
            try out.writeByteNTimes(' ', indent);
            try printType(options, out, @TypeOf(@field(val, field.name)), @field(val, field.name), indent, null);
        }
    } else {
        inline for (struct_val.fields) |field| {
            try out.writeByteNTimes(' ', indent);
            try out.print("    .{p_} = ", .{std.zig.fmtId(field.name)});

            const field_name = @field(val, field.name);
            switch (@typeInfo(@TypeOf(field_name))) {
                .@"enum" => try out.print(".{s},\n", .{@tagName(field_name)}),
                .@"struct" => |struct_info| {
                    try printStructValue(options, out, struct_info, field_name, indent + 4);
                },
                else => try printType(options, out, @TypeOf(field_name), field_name, indent, null),
            }
        }
    }

    if (indent == 0) {
        try out.writeAll("};\n");
    } else {
        try out.writeByteNTimes(' ', indent);
        try out.writeAll("},\n");
    }
}

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionPath(
    options: *Options,
    name: []const u8,
    path: LazyPath,
) void {
    options.args.append(.{
        .name = options.step.owner.dupe(name),
        .path = path.dupe(options.step.owner),
    }) catch @panic("OOM");
    path.addStepDependencies(&options.step);
}

/// Deprecated: use `addOptionPath(options, name, artifact.getEmittedBin())` instead.
pub fn addOptionArtifact(options: *Options, name: []const u8, artifact: *Step.Compile) void {
    return addOptionPath(options, name, artifact.getEmittedBin());
}

pub fn createModule(options: *Options) *std.Build.Module {
    return options.step.owner.createModule(.{
        .root_source_file = options.getOutput(),
    });
}

/// deprecated: use `getOutput`
pub const getSource = getOutput;

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
                return step.fail("unable to make path '{}{s}': {s}", .{
                    b.cache_root, sub_dirname, @errorName(e),
                });
            };

            const rand_int = std.crypto.random.int(u64);
            const tmp_sub_path = "tmp" ++ fs.path.sep_str ++
                std.fmt.hex(rand_int) ++ fs.path.sep_str ++
                basename;
            const tmp_sub_path_dirname = fs.path.dirname(tmp_sub_path).?;

            b.cache_root.handle.makePath(tmp_sub_path_dirname) catch |err| {
                return step.fail("unable to make temporary directory '{}{s}': {s}", .{
                    b.cache_root, tmp_sub_path_dirname, @errorName(err),
                });
            };

            b.cache_root.handle.writeFile(.{ .sub_path = tmp_sub_path, .data = options.contents.items }) catch |err| {
                return step.fail("unable to write options to '{}{s}': {s}", .{
                    b.cache_root, tmp_sub_path, @errorName(err),
                });
            };

            b.cache_root.handle.rename(tmp_sub_path, sub_path) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    // Other process beat us to it. Clean up the temp file.
                    b.cache_root.handle.deleteFile(tmp_sub_path) catch |e| {
                        try step.addError("warning: unable to delete temp file '{}{s}': {s}", .{
                            b.cache_root, tmp_sub_path, @errorName(e),
                        });
                    };
                    step.result_cached = true;
                    return;
                },
                else => {
                    return step.fail("unable to rename options from '{}{s}' to '{}{s}': {s}", .{
                        b.cache_root,    tmp_sub_path,
                        b.cache_root,    sub_path,
                        @errorName(err),
                    });
                },
            };
        },
        else => |e| return step.fail("unable to access options file '{}{s}': {s}", .{
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
        \\pub const option2: ?usize = null;
        \\pub const option3: ?usize = 3;
        \\pub const option4: comptime_int = 4;
        \\pub const string: []const u8 = "zigisthebest";
        \\pub const optional_string: ?[]const u8 = null;
        \\pub const nested_array: [2][2]u16 = [2][2]u16 {
        \\    [2]u16 {
        \\        300,
        \\        200,
        \\    },
        \\    [2]u16 {
        \\        300,
        \\        200,
        \\    },
        \\};
        \\pub const nested_slice: []const []const u16 = &[_][]const u16 {
        \\    &[_]u16 {
        \\        300,
        \\        200,
        \\    },
        \\    &[_]u16 {
        \\        300,
        \\        200,
        \\    },
        \\};
        \\pub const @"Build.Step.Options.decltest.Options.KeywordEnum" = enum (u0) {
        \\    @"0.8.1" = 0,
        \\};
        \\pub const keyword_enum: @"Build.Step.Options.decltest.Options.KeywordEnum" = .@"0.8.1";
        \\pub const semantic_version: @import("std").SemanticVersion = .{
        \\    .major = 0,
        \\    .minor = 1,
        \\    .patch = 2,
        \\    .pre = "foo",
        \\    .build = "bar",
        \\};
        \\pub const @"Build.Step.Options.decltest.Options.NormalEnum" = enum (u1) {
        \\    foo = 0,
        \\    bar = 1,
        \\};
        \\pub const normal1_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .foo;
        \\pub const normal2_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .bar;
        \\pub const @"Build.Step.Options.decltest.Options.NormalStruct" = struct {
        \\    hello: ?[]const u8,
        \\    world: bool = true,
        \\};
        \\pub const normal1_struct: @"Build.Step.Options.decltest.Options.NormalStruct" = .{
        \\    .hello = "foo",
        \\    .world = true,
        \\};
        \\pub const normal2_struct: @"Build.Step.Options.decltest.Options.NormalStruct" = .{
        \\    .hello = null,
        \\    .world = false,
        \\};
        \\pub const @"Build.Step.Options.decltest.Options.NestedStruct" = struct {
        \\    normal_struct: @"Build.Step.Options.decltest.Options.NormalStruct",
        \\    normal_enum: @"Build.Step.Options.decltest.Options.NormalEnum" = .foo,
        \\};
        \\pub const nested_struct: @"Build.Step.Options.decltest.Options.NestedStruct" = .{
        \\    .normal_struct = .{
        \\        .hello = "bar",
        \\        .world = true,
        \\    },
        \\    .normal_enum = .foo,
        \\};
        \\
    , options.contents.items);

    _ = try std.zig.Ast.parse(arena.allocator(), try options.contents.toOwnedSliceSentinel(0), .zig);
}
