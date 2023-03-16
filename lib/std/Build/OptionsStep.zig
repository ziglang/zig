const std = @import("../std.zig");
const builtin = @import("builtin");
const fs = std.fs;
const Step = std.Build.Step;
const GeneratedFile = std.Build.GeneratedFile;
const CompileStep = std.Build.CompileStep;
const FileSource = std.Build.FileSource;

const OptionsStep = @This();

pub const base_id = .options;

step: Step,
generated_file: GeneratedFile,

contents: std.ArrayList(u8),
artifact_args: std.ArrayList(OptionArtifactArg),
file_source_args: std.ArrayList(OptionFileSourceArg),

pub fn create(owner: *std.Build) *OptionsStep {
    const self = owner.allocator.create(OptionsStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "options",
            .owner = owner,
            .makeFn = make,
        }),
        .generated_file = undefined,
        .contents = std.ArrayList(u8).init(owner.allocator),
        .artifact_args = std.ArrayList(OptionArtifactArg).init(owner.allocator),
        .file_source_args = std.ArrayList(OptionFileSourceArg).init(owner.allocator),
    };
    self.generated_file = .{ .step = &self.step };

    return self;
}

pub fn addOption(self: *OptionsStep, comptime T: type, name: []const u8, value: T) void {
    return addOptionFallible(self, T, name, value) catch @panic("unhandled error");
}

fn addOptionFallible(self: *OptionsStep, comptime T: type, name: []const u8, value: T) !void {
    const out = self.contents.writer();
    switch (T) {
        []const []const u8 => {
            try out.print("pub const {}: []const []const u8 = &[_][]const u8{{\n", .{std.zig.fmtId(name)});
            for (value) |slice| {
                try out.print("    \"{}\",\n", .{std.zig.fmtEscapes(slice)});
            }
            try out.writeAll("};\n");
            return;
        },
        [:0]const u8 => {
            try out.print("pub const {}: [:0]const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) });
            return;
        },
        []const u8 => {
            try out.print("pub const {}: []const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) });
            return;
        },
        ?[:0]const u8 => {
            try out.print("pub const {}: ?[:0]const u8 = ", .{std.zig.fmtId(name)});
            if (value) |payload| {
                try out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)});
            } else {
                try out.writeAll("null;\n");
            }
            return;
        },
        ?[]const u8 => {
            try out.print("pub const {}: ?[]const u8 = ", .{std.zig.fmtId(name)});
            if (value) |payload| {
                try out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)});
            } else {
                try out.writeAll("null;\n");
            }
            return;
        },
        std.builtin.Version => {
            try out.print(
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
            });
            return;
        },
        std.SemanticVersion => {
            try out.print(
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
            });
            if (value.pre) |some| {
                try out.print("    .pre = \"{}\",\n", .{std.zig.fmtEscapes(some)});
            }
            if (value.build) |some| {
                try out.print("    .build = \"{}\",\n", .{std.zig.fmtEscapes(some)});
            }
            try out.writeAll("};\n");
            return;
        },
        else => {},
    }
    switch (@typeInfo(T)) {
        .Enum => |enum_info| {
            try out.print("pub const {} = enum {{\n", .{std.zig.fmtId(@typeName(T))});
            inline for (enum_info.fields) |field| {
                try out.print("    {},\n", .{std.zig.fmtId(field.name)});
            }
            try out.writeAll("};\n");
            try out.print("pub const {}: {s} = {s}.{s};\n", .{
                std.zig.fmtId(name),
                std.zig.fmtId(@typeName(T)),
                std.zig.fmtId(@typeName(T)),
                std.zig.fmtId(@tagName(value)),
            });
            return;
        },
        else => {},
    }
    try out.print("pub const {}: {s} = ", .{ std.zig.fmtId(name), @typeName(T) });
    try printLiteral(out, value, 0);
    try out.writeAll(";\n");
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
        .ComptimeInt,
        .Float,
        .Null,
        => try out.print("{any}", .{val}),
        else => @compileError(std.fmt.comptimePrint("`{s}` are not yet supported as build options", .{@tagName(@typeInfo(T))})),
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
        .source = source.dupe(self.step.owner),
    }) catch @panic("OOM");
    source.addStepDependencies(&self.step);
}

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionArtifact(self: *OptionsStep, name: []const u8, artifact: *CompileStep) void {
    self.artifact_args.append(.{ .name = self.step.owner.dupe(name), .artifact = artifact }) catch @panic("OOM");
    self.step.dependOn(&artifact.step);
}

pub fn createModule(self: *OptionsStep) *std.Build.Module {
    return self.step.owner.createModule(.{
        .source_file = self.getSource(),
        .dependencies = &.{},
    });
}

pub fn getSource(self: *OptionsStep) FileSource {
    return .{ .generated = &self.generated_file };
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    // This step completes so quickly that no progress is necessary.
    _ = prog_node;

    const b = step.owner;
    const self = @fieldParentPtr(OptionsStep, "step", step);

    for (self.artifact_args.items) |item| {
        self.addOption(
            []const u8,
            item.name,
            b.pathFromRoot(item.artifact.getOutputSource().getPath(b)),
        );
    }

    for (self.file_source_args.items) |item| {
        self.addOption(
            []const u8,
            item.name,
            item.source.getPath(b),
        );
    }

    var options_dir = try b.cache_root.handle.makeOpenPath("options", .{});
    defer options_dir.close();

    const basename = self.hashContentsToFileName();

    try options_dir.writeFile(&basename, self.contents.items);

    self.generated_file.path = try b.cache_root.join(b.allocator, &.{ "options", &basename });
}

fn hashContentsToFileName(self: *OptionsStep) [64]u8 {
    // TODO update to use the cache system instead of this
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
    artifact: *CompileStep,
};

const OptionFileSourceArg = struct {
    name: []const u8,
    source: FileSource,
};

test "OptionsStep" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const host = try std.zig.system.NativeTargetInfo.detect(.{});

    var cache: std.Build.Cache = .{
        .gpa = arena.allocator(),
        .manifest_dir = std.fs.cwd(),
    };

    var builder = try std.Build.create(
        arena.allocator(),
        "test",
        .{ .path = "test", .handle = std.fs.cwd() },
        .{ .path = "test", .handle = std.fs.cwd() },
        .{ .path = "test", .handle = std.fs.cwd() },
        host,
        &cache,
    );
    defer builder.destroy();

    const options = builder.addOptions();

    // TODO this regressed at some point
    //const KeywordEnum = enum {
    //    @"0.8.1",
    //};

    const nested_array = [2][2]u16{
        [2]u16{ 300, 200 },
        [2]u16{ 300, 200 },
    };
    const nested_slice: []const []const u16 = &[_][]const u16{ &nested_array[0], &nested_array[1] };

    options.addOption(usize, "option1", 1);
    options.addOption(?usize, "option2", null);
    options.addOption(?usize, "option3", 3);
    options.addOption(comptime_int, "option4", 4);
    options.addOption([]const u8, "string", "zigisthebest");
    options.addOption(?[]const u8, "optional_string", null);
    options.addOption([2][2]u16, "nested_array", nested_array);
    options.addOption([]const []const u16, "nested_slice", nested_slice);
    //options.addOption(KeywordEnum, "keyword_enum", .@"0.8.1");
    options.addOption(std.builtin.Version, "version", try std.builtin.Version.parse("0.1.2"));
    options.addOption(std.SemanticVersion, "semantic_version", try std.SemanticVersion.parse("0.1.2-foo+bar"));

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
        //\\pub const KeywordEnum = enum {
        //\\    @"0.8.1",
        //\\};
        //\\pub const keyword_enum: KeywordEnum = KeywordEnum.@"0.8.1";
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

    _ = try std.zig.Ast.parse(arena.allocator(), try options.contents.toOwnedSliceSentinel(0), .zig);
}
