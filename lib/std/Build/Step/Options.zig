const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const Step = std.Build.Step;
const GeneratedFile = std.Build.GeneratedFile;
const LazyPath = std.Build.LazyPath;

const Options = @This();

pub const base_id = .options;

step: Step,
generated_file: GeneratedFile,

contents: std.ArrayList(u8),
args: std.ArrayList(Arg),

pub fn create(owner: *std.Build) *Options {
    const self = owner.allocator.create(Options) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "options",
            .owner = owner,
            .makeFn = make,
        }),
        .generated_file = undefined,
        .contents = std.ArrayList(u8).init(owner.allocator),
        .args = std.ArrayList(Arg).init(owner.allocator),
    };
    self.generated_file = .{ .step = &self.step };

    return self;
}

pub fn addOption(self: *Options, comptime T: type, name: []const u8, value: T) void {
    return addOptionFallible(self, T, name, value) catch @panic("unhandled error");
}

fn addOptionFallible(self: *Options, comptime T: type, name: []const u8, value: T) !void {
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

/// deprecated: use `addOptionPath`
pub const addOptionFileSource = addOptionPath;

/// The value is the path in the cache dir.
/// Adds a dependency automatically.
pub fn addOptionPath(
    self: *Options,
    name: []const u8,
    path: LazyPath,
) void {
    self.args.append(.{
        .name = self.step.owner.dupe(name),
        .path = path.dupe(self.step.owner),
    }) catch @panic("OOM");
    path.addStepDependencies(&self.step);
}

/// Deprecated: use `addOptionPath(options, name, artifact.getEmittedBin())` instead.
pub fn addOptionArtifact(self: *Options, name: []const u8, artifact: *Step.Compile) void {
    return addOptionPath(self, name, artifact.getEmittedBin());
}

pub fn createModule(self: *Options) *std.Build.Module {
    return self.step.owner.createModule(.{
        .source_file = self.getOutput(),
        .dependencies = &.{},
    });
}

/// deprecated: use `getOutput`
pub const getSource = getOutput;

pub fn getOutput(self: *Options) LazyPath {
    return .{ .generated = &self.generated_file };
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    // This step completes so quickly that no progress is necessary.
    _ = prog_node;

    const b = step.owner;
    const self = @fieldParentPtr(Options, "step", step);

    for (self.args.items) |item| {
        self.addOption(
            []const u8,
            item.name,
            item.path.getPath(b),
        );
    }

    const basename = "options.zig";

    // Hash contents to file name.
    var hash = b.cache.hash;
    // Random bytes to make unique. Refresh this with new random bytes when
    // implementation is modified in a non-backwards-compatible way.
    hash.add(@as(u32, 0xad95e922));
    hash.addBytes(self.contents.items);
    const sub_path = "c" ++ fs.path.sep_str ++ hash.final() ++ fs.path.sep_str ++ basename;

    self.generated_file.path = try b.cache_root.join(b.allocator, &.{sub_path});

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
                std.Build.hex64(rand_int) ++ fs.path.sep_str ++
                basename;
            const tmp_sub_path_dirname = fs.path.dirname(tmp_sub_path).?;

            b.cache_root.handle.makePath(tmp_sub_path_dirname) catch |err| {
                return step.fail("unable to make temporary directory '{}{s}': {s}", .{
                    b.cache_root, tmp_sub_path_dirname, @errorName(err),
                });
            };

            b.cache_root.handle.writeFile(tmp_sub_path, self.contents.items) catch |err| {
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
