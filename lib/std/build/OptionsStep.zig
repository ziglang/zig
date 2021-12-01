const std = @import("../std.zig");
const builtin = @import("builtin");
const build = std.build;
const fs = std.fs;
const Step = build.Step;
const Builder = build.Builder;
const GeneratedFile = build.GeneratedFile;
const LibExeObjStep = build.LibExeObjStep;
const FileSource = build.FileSource;

const OptionsStep = @This();

step: Step,
generated_file: GeneratedFile,
builder: *Builder,

contents: std.ArrayList(u8),
artifact_args: std.ArrayList(OptionArtifactArg),
file_source_args: std.ArrayList(OptionFileSourceArg),

pub fn create(builder: *Builder) *OptionsStep {
    const self = builder.allocator.create(OptionsStep) catch unreachable;
    self.* = .{
        .builder = builder,
        .step = Step.init(.options, "options", builder.allocator, make),
        .generated_file = undefined,
        .contents = std.ArrayList(u8).init(builder.allocator),
        .artifact_args = std.ArrayList(OptionArtifactArg).init(builder.allocator),
        .file_source_args = std.ArrayList(OptionFileSourceArg).init(builder.allocator),
    };
    self.generated_file = .{ .step = &self.step };

    return self;
}

pub fn addOption(self: *OptionsStep, comptime T: type, name: []const u8, value: T) void {
    const out = self.contents.writer();
    switch (T) {
        []const []const u8 => {
            out.print("pub const {}: []const []const u8 = &[_][]const u8{{\n", .{std.zig.fmtId(name)}) catch unreachable;
            for (value) |slice| {
                out.print("    \"{}\",\n", .{std.zig.fmtEscapes(slice)}) catch unreachable;
            }
            out.writeAll("};\n") catch unreachable;
            return;
        },
        [:0]const u8 => {
            out.print("pub const {}: [:0]const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) }) catch unreachable;
            return;
        },
        []const u8 => {
            out.print("pub const {}: []const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) }) catch unreachable;
            return;
        },
        ?[:0]const u8 => {
            out.print("pub const {}: ?[:0]const u8 = ", .{std.zig.fmtId(name)}) catch unreachable;
            if (value) |payload| {
                out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)}) catch unreachable;
            } else {
                out.writeAll("null;\n") catch unreachable;
            }
            return;
        },
        ?[]const u8 => {
            out.print("pub const {}: ?[]const u8 = ", .{std.zig.fmtId(name)}) catch unreachable;
            if (value) |payload| {
                out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)}) catch unreachable;
            } else {
                out.writeAll("null;\n") catch unreachable;
            }
            return;
        },
        std.builtin.Version => {
            out.print(
                \\pub const {}: @import("std").builtin.Version = .{{
                \\    .major = {d},
                \\    .minor = {d},
                \\    .patch = {d},
                \\}};
                \\
            , .{
                std.zig.fmtId(name),

                value.major,
                value.minor,
                value.patch,
            }) catch unreachable;
            return;
        },
        std.SemanticVersion => {
            out.print(
                \\pub const {}: @import("std").SemanticVersion = .{{
                \\    .major = {d},
                \\    .minor = {d},
                \\    .patch = {d},
                \\
            , .{
                std.zig.fmtId(name),

                value.major,
                value.minor,
                value.patch,
            }) catch unreachable;
            if (value.pre) |some| {
                out.print("    .pre = \"{}\",\n", .{std.zig.fmtEscapes(some)}) catch unreachable;
            }
            if (value.build) |some| {
                out.print("    .build = \"{}\",\n", .{std.zig.fmtEscapes(some)}) catch unreachable;
            }
            out.writeAll("};\n") catch unreachable;
            return;
        },
        else => {},
    }
    switch (@typeInfo(T)) {
        .Enum => |enum_info| {
            out.print("pub const {} = enum {{\n", .{std.zig.fmtId(@typeName(T))}) catch unreachable;
            inline for (enum_info.fields) |field| {
                out.print("    {},\n", .{std.zig.fmtId(field.name)}) catch unreachable;
            }
            out.writeAll("};\n") catch unreachable;
            out.print("pub const {}: {s} = {s}.{s};\n", .{ std.zig.fmtId(name), @typeName(T), @typeName(T), std.zig.fmtId(@tagName(value)) }) catch unreachable;
            return;
        },
        else => {},
    }
    out.print("pub const {}: {s} = ", .{ std.zig.fmtId(name), @typeName(T) }) catch unreachable;
    printLiteral(out, value, 0) catch unreachable;
    out.writeAll(";\n") catch unreachable;
}

// TODO: non-recursive?
fn printLiteral(out: anytype, val: anytype, indent: u8) !void {
    const T = @TypeOf(val);
    switch (@typeInfo(T)) {
        .Array => {
            try out.print("{s} {{\n", .{@typeName(T)});
            for (val) |item| {
                try out.writeByteNTimes(' ', indent + 4);
                try printLiteral(out, item, indent + 4);
                try out.writeAll(",\n");
            }
            try out.writeByteNTimes(' ', indent);
            try out.writeAll("}");
        },
        .Pointer => |p| {
            if (p.size != .Slice) {
                @compileError("Non-slice pointers are not yet supported in build options");
            }
            try out.print("&[_]{s} {{\n", .{@typeName(p.child)});
            for (val) |item| {
                try out.writeByteNTimes(' ', indent + 4);
                try printLiteral(out, item, indent + 4);
                try out.writeAll(",\n");
            }
            try out.writeByteNTimes(' ', indent);
            try out.writeAll("}");
        },
        .Optional => {
            if (val) |inner| {
                return printLiteral(out, inner, indent);
            } else {
                return out.writeAll("null");
            }
        },
        .Void,
        .Bool,
        .Int,
        .Float,
        .Null,
        => try out.print("{any}", .{val}),
        else => @compileError(comptime std.fmt.comptimePrint("`{s}` are not yet supported as build options", .{@tagName(@typeInfo(T))})),
    }
}

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionFileSource(
    self: *OptionsStep,
    name: []const u8,
    source: FileSource,
) void {
    self.file_source_args.append(.{
        .name = name,
        .source = source.dupe(self.builder),
    }) catch unreachable;
    source.addStepDependencies(&self.step);
}

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionArtifact(self: *OptionsStep, name: []const u8, artifact: *LibExeObjStep) void {
    self.artifact_args.append(.{ .name = self.builder.dupe(name), .artifact = artifact }) catch unreachable;
    self.step.dependOn(&artifact.step);
}

pub fn getPackage(self: OptionsStep, package_name: []const u8) build.Pkg {
    return .{ .name = package_name, .path = self.getSource() };
}

pub fn getSource(self: OptionsStep) FileSource {
    return .{ .generated = &self.generated_file };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(OptionsStep, "step", step);

    for (self.artifact_args.items) |item| {
        self.addOption(
            []const u8,
            item.name,
            self.builder.pathFromRoot(item.artifact.getOutputSource().getPath(self.builder)),
        );
    }

    for (self.file_source_args.items) |item| {
        self.addOption(
            []const u8,
            item.name,
            item.source.getPath(self.builder),
        );
    }

    const options_directory = self.builder.pathFromRoot(
        try fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.builder.cache_root, "options" },
        ),
    );

    try fs.cwd().makePath(options_directory);

    const options_file = try fs.path.join(
        self.builder.allocator,
        &[_][]const u8{ options_directory, &self.hashContentsToFileName() },
    );

    try fs.cwd().writeFile(options_file, self.contents.items);

    self.generated_file.path = options_file;
}

fn hashContentsToFileName(self: *OptionsStep) [64]u8 {
    // This implementation is copied from `WriteFileStep.make`

    var hash = std.crypto.hash.blake2.Blake2b384.init(.{});

    // Random bytes to make OptionsStep unique. Refresh this with
    // new random bytes when OptionsStep implementation is modified
    // in a non-backwards-compatible way.
    hash.update("yL0Ya4KkmcCjBlP8");
    hash.update(self.contents.items);

    var digest: [48]u8 = undefined;
    hash.final(&digest);
    var hash_basename: [64]u8 = undefined;
    _ = fs.base64_encoder.encode(&hash_basename, &digest);
    return hash_basename;
}

const OptionArtifactArg = struct {
    name: []const u8,
    artifact: *LibExeObjStep,
};

const OptionFileSourceArg = struct {
    name: []const u8,
    source: FileSource,
};

test "OptionsStep" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var builder = try Builder.create(
        arena.allocator(),
        "test",
        "test",
        "test",
        "test",
    );
    defer builder.destroy();

    const options = builder.addOptions();

    const KeywordEnum = enum {
        @"0.8.1",
    };

    const nested_array = [2][2]u16{
        [2]u16{ 300, 200 },
        [2]u16{ 300, 200 },
    };
    const nested_slice: []const []const u16 = &[_][]const u16{ &nested_array[0], &nested_array[1] };

    options.addOption(usize, "option1", 1);
    options.addOption(?usize, "option2", null);
    options.addOption(?usize, "option3", 3);
    options.addOption([]const u8, "string", "zigisthebest");
    options.addOption(?[]const u8, "optional_string", null);
    options.addOption([2][2]u16, "nested_array", nested_array);
    options.addOption([]const []const u16, "nested_slice", nested_slice);
    options.addOption(KeywordEnum, "keyword_enum", .@"0.8.1");
    options.addOption(std.builtin.Version, "version", try std.builtin.Version.parse("0.1.2"));
    options.addOption(std.SemanticVersion, "semantic_version", try std.SemanticVersion.parse("0.1.2-foo+bar"));

    try std.testing.expectEqualStrings(
        \\pub const option1: usize = 1;
        \\pub const option2: ?usize = null;
        \\pub const option3: ?usize = 3;
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
        \\pub const KeywordEnum = enum {
        \\    @"0.8.1",
        \\};
        \\pub const keyword_enum: KeywordEnum = KeywordEnum.@"0.8.1";
        \\pub const version: @import("std").builtin.Version = .{
        \\    .major = 0,
        \\    .minor = 1,
        \\    .patch = 2,
        \\};
        \\pub const semantic_version: @import("std").SemanticVersion = .{
        \\    .major = 0,
        \\    .minor = 1,
        \\    .patch = 2,
        \\    .pre = "foo",
        \\    .build = "bar",
        \\};
        \\
    , options.contents.items);

    _ = try std.zig.parse(arena.allocator(), try options.contents.toOwnedSliceSentinel(0));
}
