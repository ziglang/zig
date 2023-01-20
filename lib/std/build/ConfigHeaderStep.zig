const std = @import("../std.zig");
const ConfigHeaderStep = @This();
const Step = std.build.Step;
const Builder = std.build.Builder;

pub const base_id: Step.Id = .config_header;

pub const Style = enum {
    /// The configure format supported by autotools. It uses `#undef foo` to
    /// mark lines that can be substituted with different values.
    autoconf,
    /// The configure format supported by CMake. It uses `@@FOO@@` and
    /// `#cmakedefine` for template substitution.
    cmake,
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
builder: *Builder,
source: std.build.FileSource,
style: Style,
values: std.StringHashMap(Value),
max_bytes: usize = 2 * 1024 * 1024,
output_dir: []const u8,
output_basename: []const u8,

pub fn create(builder: *Builder, source: std.build.FileSource, style: Style) *ConfigHeaderStep {
    const self = builder.allocator.create(ConfigHeaderStep) catch @panic("OOM");
    const name = builder.fmt("configure header {s}", .{source.getDisplayName()});
    self.* = .{
        .builder = builder,
        .step = Step.init(base_id, name, builder.allocator, make),
        .source = source,
        .style = style,
        .values = std.StringHashMap(Value).init(builder.allocator),
        .output_dir = undefined,
        .output_basename = "config.h",
    };
    switch (source) {
        .path => |p| {
            const basename = std.fs.path.basename(p);
            if (std.mem.endsWith(u8, basename, ".h.in")) {
                self.output_basename = basename[0 .. basename.len - 3];
            }
        },
        else => {},
    }
    return self;
}

pub fn addValues(self: *ConfigHeaderStep, values: anytype) void {
    return addValuesInner(self, values) catch @panic("OOM");
}

fn addValuesInner(self: *ConfigHeaderStep, values: anytype) !void {
    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        switch (@typeInfo(field.type)) {
            .Null => {
                try self.values.put(field.name, .undef);
            },
            .Void => {
                try self.values.put(field.name, .defined);
            },
            .Bool => {
                try self.values.put(field.name, .{ .boolean = @field(values, field.name) });
            },
            .ComptimeInt => {
                try self.values.put(field.name, .{ .int = @field(values, field.name) });
            },
            .EnumLiteral => {
                try self.values.put(field.name, .{ .ident = @tagName(@field(values, field.name)) });
            },
            .Pointer => |ptr| {
                switch (@typeInfo(ptr.child)) {
                    .Array => |array| {
                        if (ptr.size == .One and array.child == u8) {
                            try self.values.put(field.name, .{ .string = @field(values, field.name) });
                            continue;
                        }
                    },
                    else => {},
                }

                @compileError("unsupported ConfigHeaderStep value type: " ++
                    @typeName(field.type));
            },
            else => @compileError("unsupported ConfigHeaderStep value type: " ++
                @typeName(field.type)),
        }
    }
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(ConfigHeaderStep, "step", step);
    const gpa = self.builder.allocator;
    const src_path = self.source.getPath(self.builder);
    const contents = try std.fs.cwd().readFileAlloc(gpa, src_path, self.max_bytes);

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
    var dir = std.fs.cwd().makeOpenPath(self.output_dir, .{}) catch |err| {
        std.debug.print("unable to make path {s}: {s}\n", .{ self.output_dir, @errorName(err) });
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
    }

    try dir.writeFile(self.output_basename, output.items);
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
