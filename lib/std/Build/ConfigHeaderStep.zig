const std = @import("../std.zig");
const ConfigHeaderStep = @This();
const Step = std.Build.Step;

pub const base_id: Step.Id = .config_header;

pub const Style = enum {
    /// The configure format supported by autotools. It uses `#undef foo` to
    /// mark lines that can be substituted with different values.
    autoconf,
    /// The configure format supported by CMake. It uses `@@FOO@@` and
    /// `#cmakedefine` for template substitution.
    cmake,
    /// Generate a c header from scratch with the values passed.
    generated,
};

pub const Value = union(enum) {
    undef,
    defined,
    boolean: bool,
    int: i64,
    ident: []const u8,
    string: []const u8,
};

step: Step,
builder: *std.Build,
source: std.Build.FileSource,
style: Style,
values: std.StringHashMap(Value),
max_bytes: usize = 2 * 1024 * 1024,
output_dir: []const u8,
output_path: []const u8,
output_gen: std.build.GeneratedFile,

pub fn create(builder: *std.Build, source: std.Build.FileSource, style: Style) *ConfigHeaderStep {
    const self = builder.allocator.create(ConfigHeaderStep) catch @panic("OOM");
    const name = builder.fmt("configure header {s}", .{source.getDisplayName()});
    self.* = .{
        .builder = builder,
        .step = Step.init(base_id, name, builder.allocator, make),
        .source = source,
        .style = style,
        .values = std.StringHashMap(Value).init(builder.allocator),
        .output_dir = undefined,
        .output_path = "config.h",
        .output_gen = std.build.GeneratedFile{ .step = &self.step },
    };

    switch (source) {
        .path => |p| {
            self.output_path = p;

            switch (style) {
                .autoconf, .cmake => {
                    if (std.mem.endsWith(u8, p, ".h.in")) {
                        self.output_path = p[0 .. p.len - 3];
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    return self;
}

pub fn getOutputSource(self: *ConfigHeaderStep) std.build.FileSource {
    return std.build.FileSource{ .generated = &self.output_gen };
}

pub fn addValues(self: *ConfigHeaderStep, values: anytype) void {
    return addValuesInner(self, values) catch @panic("OOM");
}

fn addValuesInner(self: *ConfigHeaderStep, values: anytype) !void {
    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        try putValue(self, field.name, field.type, @field(values, field.name));
    }
}

fn putValue(self: *ConfigHeaderStep, field_name: []const u8, comptime T: type, v: T) !void {
    switch (@typeInfo(T)) {
        .Null => {
            try self.values.put(field_name, .undef);
        },
        .Void => {
            try self.values.put(field_name, .defined);
        },
        .Bool => {
            try self.values.put(field_name, .{ .boolean = v });
        },
        .Int => {
            try self.values.put(field_name, .{ .int = v });
        },
        .ComptimeInt => {
            try self.values.put(field_name, .{ .int = v });
        },
        .EnumLiteral => {
            try self.values.put(field_name, .{ .ident = @tagName(v) });
        },
        .Optional => {
            if (v) |x| {
                return putValue(self, field_name, @TypeOf(x), x);
            } else {
                try self.values.put(field_name, .undef);
            }
        },
        .Pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .Array => |array| {
                    if (ptr.size == .One and array.child == u8) {
                        try self.values.put(field_name, .{ .string = v });
                        return;
                    }
                },
                else => {},
            }

            @compileError("unsupported ConfigHeaderStep value type: " ++ @typeName(T));
        },
        else => @compileError("unsupported ConfigHeaderStep value type: " ++ @typeName(T)),
    }
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(ConfigHeaderStep, "step", step);
    const gpa = self.builder.allocator;
    const src_path = self.source.getPath(self.builder);
    const contents = switch (self.style) {
        .generated => src_path,
        else => try std.fs.cwd().readFileAlloc(gpa, src_path, self.max_bytes),
    };

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put ConfigHeaderStep
    // files, then two ConfigHeaderStep executing in parallel might clobber each other.

    // TODO port the cache system from the compiler to zig std lib. Until then
    // we construct the path directly, and no "cache hit" detection happens;
    // the files are always written.
    // Note there is very similar code over in WriteFileStep
    const Hasher = std.crypto.auth.siphash.SipHash128(1, 3);
    // Random bytes to make ConfigHeaderStep unique. Refresh this with new
    // random bytes when ConfigHeaderStep implementation is modified in a
    // non-backwards-compatible way.
    var hash = Hasher.init("X1pQzdDt91Zlh7Eh");
    hash.update(self.source.getDisplayName());
    hash.update(contents);

    var digest: [16]u8 = undefined;
    hash.final(&digest);
    var hash_basename: [digest.len * 2]u8 = undefined;
    _ = std.fmt.bufPrint(
        &hash_basename,
        "{s}",
        .{std.fmt.fmtSliceHexLower(&digest)},
    ) catch unreachable;

    self.output_dir = try std.fs.path.join(gpa, &[_][]const u8{
        self.builder.cache_root, "o", &hash_basename,
    });

    // If output_path has directory parts, deal with them.  Example:
    // output_dir is zig-cache/o/HASH
    // output_path is libavutil/avconfig.h
    // We want to open directory zig-cache/o/HASH/libavutil/
    // but keep output_dir as zig-cache/o/HASH for -I include
    var outdir = self.output_dir;
    var outpath = self.output_path;
    if (std.fs.path.dirname(self.output_path)) |d| {
        outdir = try std.fs.path.join(gpa, &[_][]const u8{ self.output_dir, d });
        outpath = std.fs.path.basename(self.output_path);
    }

    var dir = std.fs.cwd().makeOpenPath(outdir, .{}) catch |err| {
        std.debug.print("unable to make path {s}: {s}\n", .{ outdir, @errorName(err) });
        return err;
    };
    defer dir.close();

    var values_copy = try self.values.clone();
    defer values_copy.deinit();

    var output = std.ArrayList(u8).init(gpa);
    defer output.deinit();
    try output.ensureTotalCapacity(contents.len);

    try output.appendSlice("/* This file was generated by ConfigHeaderStep using the Zig Build System. */\n");

    switch (self.style) {
        .autoconf => try render_autoconf(contents, &output, &values_copy, src_path),
        .cmake => try render_cmake(contents, &output, &values_copy, src_path),
        .generated => try render_generated(gpa, &output, &values_copy, self.source.getDisplayName()),
    }

    try dir.writeFile(outpath, output.items);

    self.output_gen.path = try std.fs.path.join(gpa, &[_][]const u8{ self.output_dir, self.output_path });
}

fn render_autoconf(
    contents: []const u8,
    output: *std.ArrayList(u8),
    values_copy: *std.StringHashMap(Value),
    src_path: []const u8,
) !void {
    var any_errors = false;
    var line_index: u32 = 0;
    var line_it = std.mem.split(u8, contents, "\n");
    while (line_it.next()) |line| : (line_index += 1) {
        if (!std.mem.startsWith(u8, line, "#")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        var it = std.mem.tokenize(u8, line[1..], " \t\r");
        const undef = it.next().?;
        if (!std.mem.eql(u8, undef, "undef")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        const name = it.rest();
        const kv = values_copy.fetchRemove(name) orelse {
            std.debug.print("{s}:{d}: error: unspecified config header value: '{s}'\n", .{
                src_path, line_index + 1, name,
            });
            any_errors = true;
            continue;
        };
        try renderValue(output, name, kv.value);
    }

    {
        var it = values_copy.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            std.debug.print("{s}: error: config header value unused: '{s}'\n", .{ src_path, name });
        }
    }

    if (any_errors) {
        return error.HeaderConfigFailed;
    }
}

fn render_cmake(
    contents: []const u8,
    output: *std.ArrayList(u8),
    values_copy: *std.StringHashMap(Value),
    src_path: []const u8,
) !void {
    var any_errors = false;
    var line_index: u32 = 0;
    var line_it = std.mem.split(u8, contents, "\n");
    while (line_it.next()) |line| : (line_index += 1) {
        if (!std.mem.startsWith(u8, line, "#")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        var it = std.mem.tokenize(u8, line[1..], " \t\r");
        const cmakedefine = it.next().?;
        if (!std.mem.eql(u8, cmakedefine, "cmakedefine")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        const name = it.next() orelse {
            std.debug.print("{s}:{d}: error: missing define name\n", .{
                src_path, line_index + 1,
            });
            any_errors = true;
            continue;
        };
        const kv = values_copy.fetchRemove(name) orelse {
            std.debug.print("{s}:{d}: error: unspecified config header value: '{s}'\n", .{
                src_path, line_index + 1, name,
            });
            any_errors = true;
            continue;
        };
        try renderValue(output, name, kv.value);
    }

    {
        var it = values_copy.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            std.debug.print("{s}: error: config header value unused: '{s}'\n", .{ src_path, name });
        }
    }

    if (any_errors) {
        return error.HeaderConfigFailed;
    }
}

fn renderValue(output: *std.ArrayList(u8), name: []const u8, value: Value) !void {
    switch (value) {
        .undef => {
            try output.appendSlice("/* #undef ");
            try output.appendSlice(name);
            try output.appendSlice(" */\n");
        },
        .defined => {
            try output.appendSlice("#define ");
            try output.appendSlice(name);
            try output.appendSlice("\n");
        },
        .boolean => |b| {
            try output.appendSlice("#define ");
            try output.appendSlice(name);
            try output.appendSlice(" ");
            try output.appendSlice(if (b) "true\n" else "false\n");
        },
        .int => |i| {
            try output.writer().print("#define {s} {d}\n", .{ name, i });
        },
        .ident => |ident| {
            try output.writer().print("#define {s} {s}\n", .{ name, ident });
        },
        .string => |string| {
            // TODO: use C-specific escaping instead of zig string literals
            try output.writer().print("#define {s} \"{}\"\n", .{ name, std.zig.fmtEscapes(string) });
        },
    }
}

fn render_generated(
    gpa: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values_copy: *std.StringHashMap(Value),
    src_path: []const u8,
) !void {
    var include_guard = try gpa.dupe(u8, src_path);
    defer gpa.free(include_guard);

    for (include_guard) |*ch| {
        if (ch.* == '.' or std.fs.path.isSep(ch.*)) {
            ch.* = '_';
        } else {
            ch.* = std.ascii.toUpper(ch.*);
        }
    }

    try output.writer().print("#ifndef {s}\n", .{include_guard});
    try output.writer().print("#define {s}\n", .{include_guard});

    var it = values_copy.iterator();
    while (it.next()) |kv| {
        try renderValue(output, kv.key_ptr.*, kv.value_ptr.*);
    }

    try output.writer().print("#endif /* {s} */\n", .{include_guard});
}
