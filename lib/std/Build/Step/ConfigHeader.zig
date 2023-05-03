const std = @import("std");
const ConfigHeader = @This();
const Step = std.Build.Step;

pub const Style = union(enum) {
    /// The configure format supported by autotools. It uses `#undef foo` to
    /// mark lines that can be substituted with different values.
    autoconf: std.Build.FileSource,
    /// The configure format supported by CMake. It uses `@@FOO@@` and
    /// `#cmakedefine` for template substitution.
    cmake: std.Build.FileSource,
    /// Instead of starting with an input file, start with nothing.
    blank,
    /// Start with nothing, like blank, and output a nasm .asm file.
    nasm,

    pub fn getFileSource(style: Style) ?std.Build.FileSource {
        switch (style) {
            .autoconf, .cmake => |s| return s,
            .blank, .nasm => return null,
        }
    }
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
values: std.StringArrayHashMap(Value),
output_file: std.Build.GeneratedFile,

style: Style,
max_bytes: usize,
include_path: []const u8,

pub const base_id: Step.Id = .config_header;

pub const Options = struct {
    style: Style = .blank,
    max_bytes: usize = 2 * 1024 * 1024,
    include_path: ?[]const u8 = null,
    first_ret_addr: ?usize = null,
};

pub fn create(owner: *std.Build, options: Options) *ConfigHeader {
    const self = owner.allocator.create(ConfigHeader) catch @panic("OOM");

    var include_path: []const u8 = "config.h";

    if (options.style.getFileSource()) |s| switch (s) {
        .path => |p| {
            const basename = std.fs.path.basename(p);
            if (std.mem.endsWith(u8, basename, ".h.in")) {
                include_path = basename[0 .. basename.len - 3];
            }
        },
        else => {},
    };

    if (options.include_path) |p| {
        include_path = p;
    }

    const name = if (options.style.getFileSource()) |s|
        owner.fmt("configure {s} header {s} to {s}", .{
            @tagName(options.style), s.getDisplayName(), include_path,
        })
    else
        owner.fmt("configure {s} header to {s}", .{ @tagName(options.style), include_path });

    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = name,
            .owner = owner,
            .makeFn = make,
            .first_ret_addr = options.first_ret_addr orelse @returnAddress(),
        }),
        .style = options.style,
        .values = std.StringArrayHashMap(Value).init(owner.allocator),

        .max_bytes = options.max_bytes,
        .include_path = include_path,
        .output_file = .{ .step = &self.step },
    };

    return self;
}

pub fn addValues(self: *ConfigHeader, values: anytype) void {
    return addValuesInner(self, values) catch @panic("OOM");
}

pub fn getFileSource(self: *ConfigHeader) std.Build.FileSource {
    return .{ .generated = &self.output_file };
}

fn addValuesInner(self: *ConfigHeader, values: anytype) !void {
    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        try putValue(self, field.name, field.type, @field(values, field.name));
    }
}

fn putValue(self: *ConfigHeader, field_name: []const u8, comptime T: type, v: T) !void {
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
                .Int => {
                    if (ptr.size == .Slice and ptr.child == u8) {
                        try self.values.put(field_name, .{ .string = v });
                        return;
                    }
                },
                else => {},
            }

            @compileError("unsupported ConfigHeader value type: " ++ @typeName(T));
        },
        else => @compileError("unsupported ConfigHeader value type: " ++ @typeName(T)),
    }
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const self = @fieldParentPtr(ConfigHeader, "step", step);
    const gpa = b.allocator;
    const arena = b.allocator;

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make ConfigHeader unique. Refresh this with new
    // random bytes when ConfigHeader implementation is modified in a
    // non-backwards-compatible way.
    man.hash.add(@as(u32, 0xdef08d23));

    var output = std.ArrayList(u8).init(gpa);
    defer output.deinit();

    const header_text = "This file was generated by ConfigHeader using the Zig Build System.";
    const c_generated_line = "/* " ++ header_text ++ " */\n";
    const asm_generated_line = "; " ++ header_text ++ "\n";

    switch (self.style) {
        .autoconf => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath(b);
            const contents = try std.fs.cwd().readFileAlloc(arena, src_path, self.max_bytes);
            try render_autoconf(step, contents, &output, self.values, src_path);
        },
        .cmake => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath(b);
            const contents = try std.fs.cwd().readFileAlloc(arena, src_path, self.max_bytes);
            try render_cmake(step, contents, &output, self.values, src_path);
        },
        .blank => {
            try output.appendSlice(c_generated_line);
            try render_blank(&output, self.values, self.include_path);
        },
        .nasm => {
            try output.appendSlice(asm_generated_line);
            try render_nasm(&output, self.values);
        },
    }

    man.hash.addBytes(output.items);

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(arena, &.{
            "o", &digest, self.include_path,
        });
        return;
    }

    const digest = man.final();

    // If output_path has directory parts, deal with them.  Example:
    // output_dir is zig-cache/o/HASH
    // output_path is libavutil/avconfig.h
    // We want to open directory zig-cache/o/HASH/libavutil/
    // but keep output_dir as zig-cache/o/HASH for -I include
    const sub_path = try std.fs.path.join(arena, &.{ "o", &digest, self.include_path });
    const sub_path_dirname = std.fs.path.dirname(sub_path).?;

    b.cache_root.handle.makePath(sub_path_dirname) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, sub_path_dirname, @errorName(err),
        });
    };

    b.cache_root.handle.writeFile(sub_path, output.items) catch |err| {
        return step.fail("unable to write file '{}{s}': {s}", .{
            b.cache_root, sub_path, @errorName(err),
        });
    };

    self.output_file.path = try b.cache_root.join(arena, &.{sub_path});
    try man.writeManifest();
}

fn render_autoconf(
    step: *Step,
    contents: []const u8,
    output: *std.ArrayList(u8),
    values: std.StringArrayHashMap(Value),
    src_path: []const u8,
) !void {
    var values_copy = try values.clone();
    defer values_copy.deinit();

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
        const kv = values_copy.fetchSwapRemove(name) orelse {
            try step.addError("{s}:{d}: error: unspecified config header value: '{s}'", .{
                src_path, line_index + 1, name,
            });
            any_errors = true;
            continue;
        };
        try renderValueC(output, name, kv.value);
    }

    for (values_copy.keys()) |name| {
        try step.addError("{s}: error: config header value unused: '{s}'", .{ src_path, name });
        any_errors = true;
    }

    if (any_errors) {
        return error.MakeFailed;
    }
}

fn render_cmake(
    step: *Step,
    contents: []const u8,
    output: *std.ArrayList(u8),
    values: std.StringArrayHashMap(Value),
    src_path: []const u8,
) !void {
    var values_copy = try values.clone();
    defer values_copy.deinit();

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
            try step.addError("{s}:{d}: error: missing define name", .{
                src_path, line_index + 1,
            });
            any_errors = true;
            continue;
        };
        const kv = values_copy.fetchSwapRemove(name) orelse {
            try step.addError("{s}:{d}: error: unspecified config header value: '{s}'", .{
                src_path, line_index + 1, name,
            });
            any_errors = true;
            continue;
        };
        try renderValueC(output, name, kv.value);
    }

    for (values_copy.keys()) |name| {
        try step.addError("{s}: error: config header value unused: '{s}'", .{ src_path, name });
        any_errors = true;
    }

    if (any_errors) {
        return error.HeaderConfigFailed;
    }
}

fn render_blank(
    output: *std.ArrayList(u8),
    defines: std.StringArrayHashMap(Value),
    include_path: []const u8,
) !void {
    const include_guard_name = try output.allocator.dupe(u8, include_path);
    for (include_guard_name) |*byte| {
        switch (byte.*) {
            'a'...'z' => byte.* = byte.* - 'a' + 'A',
            'A'...'Z', '0'...'9' => continue,
            else => byte.* = '_',
        }
    }

    try output.appendSlice("#ifndef ");
    try output.appendSlice(include_guard_name);
    try output.appendSlice("\n#define ");
    try output.appendSlice(include_guard_name);
    try output.appendSlice("\n");

    const values = defines.values();
    for (defines.keys(), 0..) |name, i| {
        try renderValueC(output, name, values[i]);
    }

    try output.appendSlice("#endif /* ");
    try output.appendSlice(include_guard_name);
    try output.appendSlice(" */\n");
}

fn render_nasm(output: *std.ArrayList(u8), defines: std.StringArrayHashMap(Value)) !void {
    const values = defines.values();
    for (defines.keys(), 0..) |name, i| {
        try renderValueNasm(output, name, values[i]);
    }
}

fn renderValueC(output: *std.ArrayList(u8), name: []const u8, value: Value) !void {
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

fn renderValueNasm(output: *std.ArrayList(u8), name: []const u8, value: Value) !void {
    switch (value) {
        .undef => {
            try output.appendSlice("; %undef ");
            try output.appendSlice(name);
            try output.appendSlice("\n");
        },
        .defined => {
            try output.appendSlice("%define ");
            try output.appendSlice(name);
            try output.appendSlice("\n");
        },
        .boolean => |b| {
            try output.appendSlice("%define ");
            try output.appendSlice(name);
            try output.appendSlice(if (b) " 1\n" else " 0\n");
        },
        .int => |i| {
            try output.writer().print("%define {s} {d}\n", .{ name, i });
        },
        .ident => |ident| {
            try output.writer().print("%define {s} {s}\n", .{ name, ident });
        },
        .string => |string| {
            // TODO: use nasm-specific escaping instead of zig string literals
            try output.writer().print("%define {s} \"{}\"\n", .{ name, std.zig.fmtEscapes(string) });
        },
    }
}
