const std = @import("std");
const ConfigHeader = @This();
const Step = std.Build.Step;
const Allocator = std.mem.Allocator;

pub const Style = union(enum) {
    /// A configure format supported by autotools that uses `#undef foo` to
    /// mark lines that can be substituted with different values.
    autoconf_undef: std.Build.LazyPath,
    /// Deprecated. Renamed to `autoconf_undef`.
    /// To be removed after 0.14.0 is tagged.
    autoconf: std.Build.LazyPath,
    /// A configure format supported by autotools that uses `@FOO@` output variables.
    autoconf_at: std.Build.LazyPath,
    /// The configure format supported by CMake. It uses `@FOO@`, `${}` and
    /// `#cmakedefine` for template substitution.
    cmake: std.Build.LazyPath,
    /// Instead of starting with an input file, start with nothing.
    blank,
    /// Start with nothing, like blank, and output a nasm .asm file.
    nasm,

    pub fn getPath(style: Style) ?std.Build.LazyPath {
        switch (style) {
            .autoconf_undef, .autoconf, .autoconf_at, .cmake => |s| return s,
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
include_guard_override: ?[]const u8,

pub const base_id: Step.Id = .config_header;

pub const Options = struct {
    style: Style = .blank,
    max_bytes: usize = 2 * 1024 * 1024,
    include_path: ?[]const u8 = null,
    first_ret_addr: ?usize = null,
    include_guard_override: ?[]const u8 = null,
};

pub fn create(owner: *std.Build, options: Options) *ConfigHeader {
    const config_header = owner.allocator.create(ConfigHeader) catch @panic("OOM");

    var include_path: []const u8 = "config.h";

    if (options.style.getPath()) |s| default_include_path: {
        const sub_path = switch (s) {
            .src_path => |sp| sp.sub_path,
            .generated => break :default_include_path,
            .cwd_relative => |sub_path| sub_path,
            .dependency => |dependency| dependency.sub_path,
        };
        const basename = std.fs.path.basename(sub_path);
        if (std.mem.endsWith(u8, basename, ".h.in")) {
            include_path = basename[0 .. basename.len - 3];
        }
    }

    if (options.include_path) |p| {
        include_path = p;
    }

    const name = if (options.style.getPath()) |s|
        owner.fmt("configure {s} header {s} to {s}", .{
            @tagName(options.style), s.getDisplayName(), include_path,
        })
    else
        owner.fmt("configure {s} header to {s}", .{ @tagName(options.style), include_path });

    config_header.* = .{
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
        .include_guard_override = options.include_guard_override,
        .output_file = .{ .step = &config_header.step },
    };

    return config_header;
}

pub fn addValue(config_header: *ConfigHeader, name: []const u8, comptime T: type, value: T) void {
    return addValueInner(config_header, name, T, value) catch @panic("OOM");
}

pub fn addValues(config_header: *ConfigHeader, values: anytype) void {
    inline for (@typeInfo(@TypeOf(values)).@"struct".fields) |field| {
        addValue(config_header, field.name, field.type, @field(values, field.name));
    }
}

pub fn getOutput(config_header: *ConfigHeader) std.Build.LazyPath {
    return .{ .generated = .{ .file = &config_header.output_file } };
}

fn addValueInner(config_header: *ConfigHeader, name: []const u8, comptime T: type, value: T) !void {
    switch (@typeInfo(T)) {
        .null => {
            try config_header.values.put(name, .undef);
        },
        .void => {
            try config_header.values.put(name, .defined);
        },
        .bool => {
            try config_header.values.put(name, .{ .boolean = value });
        },
        .int => {
            try config_header.values.put(name, .{ .int = value });
        },
        .comptime_int => {
            try config_header.values.put(name, .{ .int = value });
        },
        .@"enum", .enum_literal => {
            try config_header.values.put(name, .{ .ident = @tagName(value) });
        },
        .optional => {
            if (value) |x| {
                return addValueInner(config_header, name, @TypeOf(x), x);
            } else {
                try config_header.values.put(name, .undef);
            }
        },
        .pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .array => |array| {
                    if (ptr.size == .one and array.child == u8) {
                        try config_header.values.put(name, .{ .string = value });
                        return;
                    }
                },
                .int => {
                    if (ptr.size == .slice and ptr.child == u8) {
                        try config_header.values.put(name, .{ .string = value });
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

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const b = step.owner;
    const config_header: *ConfigHeader = @fieldParentPtr("step", step);
    if (config_header.style.getPath()) |lp| try step.singleUnchangingWatchInput(lp);

    const gpa = b.allocator;
    const arena = b.allocator;

    var man = b.graph.cache.obtain();
    defer man.deinit();

    // Random bytes to make ConfigHeader unique. Refresh this with new
    // random bytes when ConfigHeader implementation is modified in a
    // non-backwards-compatible way.
    man.hash.add(@as(u32, 0xdef08d23));
    man.hash.addBytes(config_header.include_path);
    man.hash.addOptionalBytes(config_header.include_guard_override);

    var output = std.ArrayList(u8).init(gpa);
    defer output.deinit();

    const header_text = "This file was generated by ConfigHeader using the Zig Build System.";
    const c_generated_line = "/* " ++ header_text ++ " */\n";
    const asm_generated_line = "; " ++ header_text ++ "\n";

    switch (config_header.style) {
        .autoconf_undef, .autoconf, .autoconf_at => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath2(b, step);
            const contents = std.fs.cwd().readFileAlloc(arena, src_path, config_header.max_bytes) catch |err| {
                return step.fail("unable to read autoconf input file '{s}': {s}", .{
                    src_path, @errorName(err),
                });
            };
            switch (config_header.style) {
                .autoconf_undef, .autoconf => try render_autoconf_undef(step, contents, &output, config_header.values, src_path),
                .autoconf_at => try render_autoconf_at(step, contents, &output, config_header.values, src_path),
                else => unreachable,
            }
        },
        .cmake => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath2(b, step);
            const contents = std.fs.cwd().readFileAlloc(arena, src_path, config_header.max_bytes) catch |err| {
                return step.fail("unable to read cmake input file '{s}': {s}", .{
                    src_path, @errorName(err),
                });
            };
            try render_cmake(step, contents, &output, config_header.values, src_path);
        },
        .blank => {
            try output.appendSlice(c_generated_line);
            try render_blank(&output, config_header.values, config_header.include_path, config_header.include_guard_override);
        },
        .nasm => {
            try output.appendSlice(asm_generated_line);
            try render_nasm(&output, config_header.values);
        },
    }

    man.hash.addBytes(output.items);

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        config_header.output_file.path = try b.cache_root.join(arena, &.{
            "o", &digest, config_header.include_path,
        });
        return;
    }

    const digest = man.final();

    // If output_path has directory parts, deal with them.  Example:
    // output_dir is zig-cache/o/HASH
    // output_path is libavutil/avconfig.h
    // We want to open directory zig-cache/o/HASH/libavutil/
    // but keep output_dir as zig-cache/o/HASH for -I include
    const sub_path = b.pathJoin(&.{ "o", &digest, config_header.include_path });
    const sub_path_dirname = std.fs.path.dirname(sub_path).?;

    b.cache_root.handle.makePath(sub_path_dirname) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, sub_path_dirname, @errorName(err),
        });
    };

    b.cache_root.handle.writeFile(.{ .sub_path = sub_path, .data = output.items }) catch |err| {
        return step.fail("unable to write file '{}{s}': {s}", .{
            b.cache_root, sub_path, @errorName(err),
        });
    };

    config_header.output_file.path = try b.cache_root.join(arena, &.{sub_path});
    try man.writeManifest();
}

fn render_autoconf_undef(
    step: *Step,
    contents: []const u8,
    output: *std.ArrayList(u8),
    values: std.StringArrayHashMap(Value),
    src_path: []const u8,
) !void {
    const build = step.owner;
    const allocator = build.allocator;

    var is_used: std.DynamicBitSetUnmanaged = try .initEmpty(allocator, values.count());
    defer is_used.deinit(allocator);

    var any_errors = false;
    var line_index: u32 = 0;
    var line_it = std.mem.splitScalar(u8, contents, '\n');
    while (line_it.next()) |line| : (line_index += 1) {
        if (!std.mem.startsWith(u8, line, "#")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        var it = std.mem.tokenizeAny(u8, line[1..], " \t\r");
        const undef = it.next().?;
        if (!std.mem.eql(u8, undef, "undef")) {
            try output.appendSlice(line);
            try output.appendSlice("\n");
            continue;
        }
        const name = it.next().?;
        const index = values.getIndex(name) orelse {
            try step.addError("{s}:{d}: error: unspecified config header value: '{s}'", .{
                src_path, line_index + 1, name,
            });
            any_errors = true;
            continue;
        };
        is_used.set(index);
        try renderValueC(output, name, values.values()[index]);
    }

    var unused_value_it = is_used.iterator(.{ .kind = .unset });
    while (unused_value_it.next()) |index| {
        try step.addError("{s}: error: config header value unused: '{s}'", .{ src_path, values.keys()[index] });
        any_errors = true;
    }

    if (any_errors) {
        return error.MakeFailed;
    }
}

fn render_autoconf_at(
    step: *Step,
    contents: []const u8,
    output: *std.ArrayList(u8),
    values: std.StringArrayHashMap(Value),
    src_path: []const u8,
) !void {
    const build = step.owner;
    const allocator = build.allocator;

    const used = allocator.alloc(bool, values.count()) catch @panic("OOM");
    for (used) |*u| u.* = false;
    defer allocator.free(used);

    var any_errors = false;
    var line_index: u32 = 0;
    var line_it = std.mem.splitScalar(u8, contents, '\n');
    while (line_it.next()) |line| : (line_index += 1) {
        const last_line = line_it.index == line_it.buffer.len;

        const old_len = output.items.len;
        expand_variables_autoconf_at(output, line, values, used) catch |err| switch (err) {
            error.MissingValue => {
                const name = output.items[old_len..];
                defer output.shrinkRetainingCapacity(old_len);
                try step.addError("{s}:{d}: error: unspecified config header value: '{s}'", .{
                    src_path, line_index + 1, name,
                });
                any_errors = true;
                continue;
            },
            else => {
                try step.addError("{s}:{d}: unable to substitute variable: error: {s}", .{
                    src_path, line_index + 1, @errorName(err),
                });
                any_errors = true;
                continue;
            },
        };
        if (!last_line) {
            try output.append('\n');
        }
    }

    for (values.unmanaged.entries.slice().items(.key), used) |name, u| {
        if (!u) {
            try step.addError("{s}: error: config header value unused: '{s}'", .{ src_path, name });
            any_errors = true;
        }
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
    const build = step.owner;
    const allocator = build.allocator;

    var values_copy = try values.clone();
    defer values_copy.deinit();

    var any_errors = false;
    var line_index: u32 = 0;
    var line_it = std.mem.splitScalar(u8, contents, '\n');
    while (line_it.next()) |raw_line| : (line_index += 1) {
        const last_line = line_it.index == line_it.buffer.len;

        const line = expand_variables_cmake(allocator, raw_line, values) catch |err| switch (err) {
            error.InvalidCharacter => {
                try step.addError("{s}:{d}: error: invalid character in a variable name", .{
                    src_path, line_index + 1,
                });
                any_errors = true;
                continue;
            },
            else => {
                try step.addError("{s}:{d}: unable to substitute variable: error: {s}", .{
                    src_path, line_index + 1, @errorName(err),
                });
                any_errors = true;
                continue;
            },
        };
        defer allocator.free(line);

        if (!std.mem.startsWith(u8, line, "#")) {
            try output.appendSlice(line);
            if (!last_line) {
                try output.appendSlice("\n");
            }
            continue;
        }
        var it = std.mem.tokenizeAny(u8, line[1..], " \t\r");
        const cmakedefine = it.next().?;
        if (!std.mem.eql(u8, cmakedefine, "cmakedefine") and
            !std.mem.eql(u8, cmakedefine, "cmakedefine01"))
        {
            try output.appendSlice(line);
            if (!last_line) {
                try output.appendSlice("\n");
            }
            continue;
        }

        const booldefine = std.mem.eql(u8, cmakedefine, "cmakedefine01");

        const name = it.next() orelse {
            try step.addError("{s}:{d}: error: missing define name", .{
                src_path, line_index + 1,
            });
            any_errors = true;
            continue;
        };
        var value = values_copy.get(name) orelse blk: {
            if (booldefine) {
                break :blk Value{ .int = 0 };
            }
            break :blk Value.undef;
        };

        value = blk: {
            switch (value) {
                .boolean => |b| {
                    if (!b) {
                        break :blk Value.undef;
                    }
                },
                .int => |i| {
                    if (i == 0) {
                        break :blk Value.undef;
                    }
                },
                .string => |string| {
                    if (string.len == 0) {
                        break :blk Value.undef;
                    }
                },

                else => {},
            }
            break :blk value;
        };

        if (booldefine) {
            value = blk: {
                switch (value) {
                    .undef => {
                        break :blk Value{ .boolean = false };
                    },
                    .defined => {
                        break :blk Value{ .boolean = false };
                    },
                    .boolean => |b| {
                        break :blk Value{ .boolean = b };
                    },
                    .int => |i| {
                        break :blk Value{ .boolean = i != 0 };
                    },
                    .string => |string| {
                        break :blk Value{ .boolean = string.len != 0 };
                    },

                    else => {
                        break :blk Value{ .boolean = false };
                    },
                }
            };
        } else if (value != Value.undef) {
            value = Value{ .ident = it.rest() };
        }

        try renderValueC(output, name, value);
    }

    if (any_errors) {
        return error.HeaderConfigFailed;
    }
}

fn render_blank(
    output: *std.ArrayList(u8),
    defines: std.StringArrayHashMap(Value),
    include_path: []const u8,
    include_guard_override: ?[]const u8,
) !void {
    const include_guard_name = include_guard_override orelse blk: {
        const name = try output.allocator.dupe(u8, include_path);
        for (name) |*byte| {
            switch (byte.*) {
                'a'...'z' => byte.* = byte.* - 'a' + 'A',
                'A'...'Z', '0'...'9' => continue,
                else => byte.* = '_',
            }
        }
        break :blk name;
    };

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
            try output.appendSlice(if (b) " 1\n" else " 0\n");
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

fn expand_variables_autoconf_at(
    output: *std.ArrayList(u8),
    contents: []const u8,
    values: std.StringArrayHashMap(Value),
    used: []bool,
) !void {
    const valid_varname_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";

    var curr: usize = 0;
    var source_offset: usize = 0;
    while (curr < contents.len) : (curr += 1) {
        if (contents[curr] != '@') continue;
        if (std.mem.indexOfScalarPos(u8, contents, curr + 1, '@')) |close_pos| {
            if (close_pos == curr + 1) {
                // closed immediately, preserve as a literal
                continue;
            }
            const valid_varname_end = std.mem.indexOfNonePos(u8, contents, curr + 1, valid_varname_chars) orelse 0;
            if (valid_varname_end != close_pos) {
                // contains invalid characters, preserve as a literal
                continue;
            }

            const key = contents[curr + 1 .. close_pos];
            const index = values.getIndex(key) orelse {
                // Report the missing key to the caller.
                try output.appendSlice(key);
                return error.MissingValue;
            };
            const value = values.unmanaged.entries.slice().items(.value)[index];
            used[index] = true;
            try output.appendSlice(contents[source_offset..curr]);
            switch (value) {
                .undef, .defined => {},
                .boolean => |b| {
                    try output.append(if (b) '1' else '0');
                },
                .int => |i| {
                    try output.writer().print("{d}", .{i});
                },
                .ident, .string => |s| {
                    try output.appendSlice(s);
                },
            }

            curr = close_pos;
            source_offset = close_pos + 1;
        }
    }

    try output.appendSlice(contents[source_offset..]);
}

fn expand_variables_cmake(
    allocator: Allocator,
    contents: []const u8,
    values: std.StringArrayHashMap(Value),
) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    const valid_varname_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/_.+-";
    const open_var = "${";

    var curr: usize = 0;
    var source_offset: usize = 0;
    const Position = struct {
        source: usize,
        target: usize,
    };
    var var_stack = std.ArrayList(Position).init(allocator);
    defer var_stack.deinit();
    loop: while (curr < contents.len) : (curr += 1) {
        switch (contents[curr]) {
            '@' => blk: {
                if (std.mem.indexOfScalarPos(u8, contents, curr + 1, '@')) |close_pos| {
                    if (close_pos == curr + 1) {
                        // closed immediately, preserve as a literal
                        break :blk;
                    }
                    const valid_varname_end = std.mem.indexOfNonePos(u8, contents, curr + 1, valid_varname_chars) orelse 0;
                    if (valid_varname_end != close_pos) {
                        // contains invalid characters, preserve as a literal
                        break :blk;
                    }

                    const key = contents[curr + 1 .. close_pos];
                    const value = values.get(key) orelse return error.MissingValue;
                    const missing = contents[source_offset..curr];
                    try result.appendSlice(missing);
                    switch (value) {
                        .undef, .defined => {},
                        .boolean => |b| {
                            try result.append(if (b) '1' else '0');
                        },
                        .int => |i| {
                            try result.writer().print("{d}", .{i});
                        },
                        .ident, .string => |s| {
                            try result.appendSlice(s);
                        },
                    }

                    curr = close_pos;
                    source_offset = close_pos + 1;

                    continue :loop;
                }
            },
            '$' => blk: {
                const next = curr + 1;
                if (next == contents.len or contents[next] != '{') {
                    // no open bracket detected, preserve as a literal
                    break :blk;
                }
                const missing = contents[source_offset..curr];
                try result.appendSlice(missing);
                try result.appendSlice(open_var);

                source_offset = curr + open_var.len;
                curr = next;
                try var_stack.append(Position{
                    .source = curr,
                    .target = result.items.len - open_var.len,
                });

                continue :loop;
            },
            '}' => blk: {
                if (var_stack.items.len == 0) {
                    // no open bracket, preserve as a literal
                    break :blk;
                }
                const open_pos = var_stack.pop().?;
                if (source_offset == open_pos.source) {
                    source_offset += open_var.len;
                }
                const missing = contents[source_offset..curr];
                try result.appendSlice(missing);

                const key_start = open_pos.target + open_var.len;
                const key = result.items[key_start..];
                if (key.len == 0) {
                    return error.MissingKey;
                }
                const value = values.get(key) orelse return error.MissingValue;
                result.shrinkRetainingCapacity(result.items.len - key.len - open_var.len);
                switch (value) {
                    .undef, .defined => {},
                    .boolean => |b| {
                        try result.append(if (b) '1' else '0');
                    },
                    .int => |i| {
                        try result.writer().print("{d}", .{i});
                    },
                    .ident, .string => |s| {
                        try result.appendSlice(s);
                    },
                }

                source_offset = curr + 1;

                continue :loop;
            },
            '\\' => {
                // backslash is not considered a special character
                continue :loop;
            },
            else => {},
        }

        if (var_stack.items.len > 0 and std.mem.indexOfScalar(u8, valid_varname_chars, contents[curr]) == null) {
            return error.InvalidCharacter;
        }
    }

    if (source_offset != contents.len) {
        const missing = contents[source_offset..];
        try result.appendSlice(missing);
    }

    return result.toOwnedSlice();
}

fn testReplaceVariablesAutoconfAt(
    allocator: Allocator,
    contents: []const u8,
    expected: []const u8,
    values: std.StringArrayHashMap(Value),
) !void {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const used = try allocator.alloc(bool, values.count());
    for (used) |*u| u.* = false;
    defer allocator.free(used);

    try expand_variables_autoconf_at(&output, contents, values, used);

    for (used) |u| if (!u) return error.UnusedValue;
    try std.testing.expectEqualStrings(expected, output.items);
}

fn testReplaceVariablesCMake(
    allocator: Allocator,
    contents: []const u8,
    expected: []const u8,
    values: std.StringArrayHashMap(Value),
) !void {
    const actual = try expand_variables_cmake(allocator, contents, values);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "expand_variables_autoconf_at simple cases" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    // empty strings are preserved
    try testReplaceVariablesAutoconfAt(allocator, "", "", values);

    // line with misc content is preserved
    try testReplaceVariablesAutoconfAt(allocator, "no substitution", "no substitution", values);

    // empty @ sigils are preserved
    try testReplaceVariablesAutoconfAt(allocator, "@", "@", values);
    try testReplaceVariablesAutoconfAt(allocator, "@@", "@@", values);
    try testReplaceVariablesAutoconfAt(allocator, "@@@", "@@@", values);
    try testReplaceVariablesAutoconfAt(allocator, "@@@@", "@@@@", values);

    // simple substitution
    try values.putNoClobber("undef", .undef);
    try testReplaceVariablesAutoconfAt(allocator, "@undef@", "", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("defined", .defined);
    try testReplaceVariablesAutoconfAt(allocator, "@defined@", "", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("true", Value{ .boolean = true });
    try testReplaceVariablesAutoconfAt(allocator, "@true@", "1", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("false", Value{ .boolean = false });
    try testReplaceVariablesAutoconfAt(allocator, "@false@", "0", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("int", Value{ .int = 42 });
    try testReplaceVariablesAutoconfAt(allocator, "@int@", "42", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("ident", Value{ .string = "value" });
    try testReplaceVariablesAutoconfAt(allocator, "@ident@", "value", values);
    values.clearRetainingCapacity();

    try values.putNoClobber("string", Value{ .string = "text" });
    try testReplaceVariablesAutoconfAt(allocator, "@string@", "text", values);
    values.clearRetainingCapacity();

    // double packed substitution
    try values.putNoClobber("string", Value{ .string = "text" });
    try testReplaceVariablesAutoconfAt(allocator, "@string@@string@", "texttext", values);
    values.clearRetainingCapacity();

    // triple packed substitution
    try values.putNoClobber("int", Value{ .int = 42 });
    try values.putNoClobber("string", Value{ .string = "text" });
    try testReplaceVariablesAutoconfAt(allocator, "@string@@int@@string@", "text42text", values);
    values.clearRetainingCapacity();

    // double separated substitution
    try values.putNoClobber("int", Value{ .int = 42 });
    try testReplaceVariablesAutoconfAt(allocator, "@int@.@int@", "42.42", values);
    values.clearRetainingCapacity();

    // triple separated substitution
    try values.putNoClobber("true", Value{ .boolean = true });
    try values.putNoClobber("int", Value{ .int = 42 });
    try testReplaceVariablesAutoconfAt(allocator, "@int@.@true@.@int@", "42.1.42", values);
    values.clearRetainingCapacity();

    // misc prefix is preserved
    try values.putNoClobber("false", Value{ .boolean = false });
    try testReplaceVariablesAutoconfAt(allocator, "false is @false@", "false is 0", values);
    values.clearRetainingCapacity();

    // misc suffix is preserved
    try values.putNoClobber("true", Value{ .boolean = true });
    try testReplaceVariablesAutoconfAt(allocator, "@true@ is true", "1 is true", values);
    values.clearRetainingCapacity();

    // surrounding content is preserved
    try values.putNoClobber("int", Value{ .int = 42 });
    try testReplaceVariablesAutoconfAt(allocator, "what is 6*7? @int@!", "what is 6*7? 42!", values);
    values.clearRetainingCapacity();

    // incomplete key is preserved
    try testReplaceVariablesAutoconfAt(allocator, "@undef", "@undef", values);

    // unknown key leads to an error
    try std.testing.expectError(error.MissingValue, testReplaceVariablesAutoconfAt(allocator, "@bad@", "", values));

    // unused key leads to an error
    try values.putNoClobber("int", Value{ .int = 42 });
    try values.putNoClobber("false", Value{ .boolean = false });
    try std.testing.expectError(error.UnusedValue, testReplaceVariablesAutoconfAt(allocator, "@int", "", values));
    values.clearRetainingCapacity();
}

test "expand_variables_autoconf_at edge cases" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    // @-vars resolved only when they wrap valid characters, otherwise considered literals
    try values.putNoClobber("string", Value{ .string = "text" });
    try testReplaceVariablesAutoconfAt(allocator, "@@string@@", "@text@", values);
    values.clearRetainingCapacity();

    // expanded variables are considered strings after expansion
    try values.putNoClobber("string_at", Value{ .string = "@string@" });
    try testReplaceVariablesAutoconfAt(allocator, "@string_at@", "@string@", values);
    values.clearRetainingCapacity();
}

test "expand_variables_cmake simple cases" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    try values.putNoClobber("undef", .undef);
    try values.putNoClobber("defined", .defined);
    try values.putNoClobber("true", Value{ .boolean = true });
    try values.putNoClobber("false", Value{ .boolean = false });
    try values.putNoClobber("int", Value{ .int = 42 });
    try values.putNoClobber("ident", Value{ .string = "value" });
    try values.putNoClobber("string", Value{ .string = "text" });

    // empty strings are preserved
    try testReplaceVariablesCMake(allocator, "", "", values);

    // line with misc content is preserved
    try testReplaceVariablesCMake(allocator, "no substitution", "no substitution", values);

    // empty ${} wrapper leads to an error
    try std.testing.expectError(error.MissingKey, testReplaceVariablesCMake(allocator, "${}", "", values));

    // empty @ sigils are preserved
    try testReplaceVariablesCMake(allocator, "@", "@", values);
    try testReplaceVariablesCMake(allocator, "@@", "@@", values);
    try testReplaceVariablesCMake(allocator, "@@@", "@@@", values);
    try testReplaceVariablesCMake(allocator, "@@@@", "@@@@", values);

    // simple substitution
    try testReplaceVariablesCMake(allocator, "@undef@", "", values);
    try testReplaceVariablesCMake(allocator, "${undef}", "", values);
    try testReplaceVariablesCMake(allocator, "@defined@", "", values);
    try testReplaceVariablesCMake(allocator, "${defined}", "", values);
    try testReplaceVariablesCMake(allocator, "@true@", "1", values);
    try testReplaceVariablesCMake(allocator, "${true}", "1", values);
    try testReplaceVariablesCMake(allocator, "@false@", "0", values);
    try testReplaceVariablesCMake(allocator, "${false}", "0", values);
    try testReplaceVariablesCMake(allocator, "@int@", "42", values);
    try testReplaceVariablesCMake(allocator, "${int}", "42", values);
    try testReplaceVariablesCMake(allocator, "@ident@", "value", values);
    try testReplaceVariablesCMake(allocator, "${ident}", "value", values);
    try testReplaceVariablesCMake(allocator, "@string@", "text", values);
    try testReplaceVariablesCMake(allocator, "${string}", "text", values);

    // double packed substitution
    try testReplaceVariablesCMake(allocator, "@string@@string@", "texttext", values);
    try testReplaceVariablesCMake(allocator, "${string}${string}", "texttext", values);

    // triple packed substitution
    try testReplaceVariablesCMake(allocator, "@string@@int@@string@", "text42text", values);
    try testReplaceVariablesCMake(allocator, "@string@${int}@string@", "text42text", values);
    try testReplaceVariablesCMake(allocator, "${string}@int@${string}", "text42text", values);
    try testReplaceVariablesCMake(allocator, "${string}${int}${string}", "text42text", values);

    // double separated substitution
    try testReplaceVariablesCMake(allocator, "@int@.@int@", "42.42", values);
    try testReplaceVariablesCMake(allocator, "${int}.${int}", "42.42", values);

    // triple separated substitution
    try testReplaceVariablesCMake(allocator, "@int@.@true@.@int@", "42.1.42", values);
    try testReplaceVariablesCMake(allocator, "@int@.${true}.@int@", "42.1.42", values);
    try testReplaceVariablesCMake(allocator, "${int}.@true@.${int}", "42.1.42", values);
    try testReplaceVariablesCMake(allocator, "${int}.${true}.${int}", "42.1.42", values);

    // misc prefix is preserved
    try testReplaceVariablesCMake(allocator, "false is @false@", "false is 0", values);
    try testReplaceVariablesCMake(allocator, "false is ${false}", "false is 0", values);

    // misc suffix is preserved
    try testReplaceVariablesCMake(allocator, "@true@ is true", "1 is true", values);
    try testReplaceVariablesCMake(allocator, "${true} is true", "1 is true", values);

    // surrounding content is preserved
    try testReplaceVariablesCMake(allocator, "what is 6*7? @int@!", "what is 6*7? 42!", values);
    try testReplaceVariablesCMake(allocator, "what is 6*7? ${int}!", "what is 6*7? 42!", values);

    // incomplete key is preserved
    try testReplaceVariablesCMake(allocator, "@undef", "@undef", values);
    try testReplaceVariablesCMake(allocator, "${undef", "${undef", values);
    try testReplaceVariablesCMake(allocator, "{undef}", "{undef}", values);
    try testReplaceVariablesCMake(allocator, "undef@", "undef@", values);
    try testReplaceVariablesCMake(allocator, "undef}", "undef}", values);

    // unknown key leads to an error
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "@bad@", "", values));
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "${bad}", "", values));
}

test "expand_variables_cmake edge cases" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    // special symbols
    try values.putNoClobber("at", Value{ .string = "@" });
    try values.putNoClobber("dollar", Value{ .string = "$" });
    try values.putNoClobber("underscore", Value{ .string = "_" });

    // basic value
    try values.putNoClobber("string", Value{ .string = "text" });

    // proxy case values
    try values.putNoClobber("string_proxy", Value{ .string = "string" });
    try values.putNoClobber("string_at", Value{ .string = "@string@" });
    try values.putNoClobber("string_curly", Value{ .string = "{string}" });
    try values.putNoClobber("string_var", Value{ .string = "${string}" });

    // stack case values
    try values.putNoClobber("nest_underscore_proxy", Value{ .string = "underscore" });
    try values.putNoClobber("nest_proxy", Value{ .string = "nest_underscore_proxy" });

    // @-vars resolved only when they wrap valid characters, otherwise considered literals
    try testReplaceVariablesCMake(allocator, "@@string@@", "@text@", values);
    try testReplaceVariablesCMake(allocator, "@${string}@", "@text@", values);

    // @-vars are resolved inside ${}-vars
    try testReplaceVariablesCMake(allocator, "${@string_proxy@}", "text", values);

    // expanded variables are considered strings after expansion
    try testReplaceVariablesCMake(allocator, "@string_at@", "@string@", values);
    try testReplaceVariablesCMake(allocator, "${string_at}", "@string@", values);
    try testReplaceVariablesCMake(allocator, "$@string_curly@", "${string}", values);
    try testReplaceVariablesCMake(allocator, "$${string_curly}", "${string}", values);
    try testReplaceVariablesCMake(allocator, "${string_var}", "${string}", values);
    try testReplaceVariablesCMake(allocator, "@string_var@", "${string}", values);
    try testReplaceVariablesCMake(allocator, "${dollar}{${string}}", "${text}", values);
    try testReplaceVariablesCMake(allocator, "@dollar@{${string}}", "${text}", values);
    try testReplaceVariablesCMake(allocator, "@dollar@{@string@}", "${text}", values);

    // when expanded variables contain invalid characters, they prevent further expansion
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "${${string_var}}", "", values));
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "${@string_var@}", "", values));

    // nested expanded variables are expanded from the inside out
    try testReplaceVariablesCMake(allocator, "${string${underscore}proxy}", "string", values);
    try testReplaceVariablesCMake(allocator, "${string@underscore@proxy}", "string", values);

    // nested vars are only expanded when ${} is closed
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "@nest@underscore@proxy@", "", values));
    try testReplaceVariablesCMake(allocator, "${nest${underscore}proxy}", "nest_underscore_proxy", values);
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "@nest@@nest_underscore@underscore@proxy@@proxy@", "", values));
    try testReplaceVariablesCMake(allocator, "${nest${${nest_underscore${underscore}proxy}}proxy}", "nest_underscore_proxy", values);

    // invalid characters lead to an error
    try std.testing.expectError(error.InvalidCharacter, testReplaceVariablesCMake(allocator, "${str*ing}", "", values));
    try std.testing.expectError(error.InvalidCharacter, testReplaceVariablesCMake(allocator, "${str$ing}", "", values));
    try std.testing.expectError(error.InvalidCharacter, testReplaceVariablesCMake(allocator, "${str@ing}", "", values));
}

test "expand_variables_cmake escaped characters" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    try values.putNoClobber("string", Value{ .string = "text" });

    // backslash is an invalid character for @ lookup
    try testReplaceVariablesCMake(allocator, "\\@string\\@", "\\@string\\@", values);

    // backslash is preserved, but doesn't affect ${} variable expansion
    try testReplaceVariablesCMake(allocator, "\\${string}", "\\text", values);

    // backslash breaks ${} opening bracket identification
    try testReplaceVariablesCMake(allocator, "$\\{string}", "$\\{string}", values);

    // backslash is skipped when checking for invalid characters, yet it mangles the key
    try std.testing.expectError(error.MissingValue, testReplaceVariablesCMake(allocator, "${string\\}", "", values));
}
