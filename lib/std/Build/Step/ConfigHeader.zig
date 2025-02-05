const std = @import("std");
const ConfigHeader = @This();
const Step = std.Build.Step;
const Allocator = std.mem.Allocator;

const ConfigError = error{
    InvalidCharacter,
    MissingName,
    UndefinedVariable,
};

pub const Style = union(enum) {
    /// The configure format supported by autotools. It uses `#undef foo` to
    /// mark lines that can be substituted with different values.
    autoconf: std.Build.LazyPath,
    /// The configure format supported by CMake. It uses `@FOO@`, `${}` and
    /// `#cmakedefine` for template substitution.
    cmake: std.Build.LazyPath,
    /// Instead of starting with an input file, start with nothing.
    blank,
    /// Start with nothing, like blank, and output a nasm .asm file.
    nasm,

    pub fn getPath(style: Style) ?std.Build.LazyPath {
        switch (style) {
            .autoconf, .cmake => |s| return s,
            .blank, .nasm => return null,
        }
    }
};

/// Diagnostic data wrapper, complementing returned `ConfigError`s
const Diagnostics = struct {
    allocator: std.mem.Allocator,

    /// 1-based line number
    line_number: u64 = 1,
    /// 1-based column number, indicates start column of the error
    column_number: usize = 1,
    /// optional metadata accompanying the `ConfigError`
    metadata: ?[]u8 = null,

    pub fn deinit(self: *@This()) void {
        if (self.metadata) |m| {
            self.allocator.free(m);
        }
        self.metadata = undefined;
    }

    /// Set or reset metadata, should be called whenever `ConfigError` is being returned
    pub fn setMetadata(self: *@This(), value: ?[]const u8) void {
        if (self.metadata) |m| {
            self.allocator.free(m);
            self.metadata = null;
        }

        if (value) |v| {
            self.metadata = self.allocator.dupe(u8, v) catch null;
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
fallback_value: ?Value,

pub const base_id: Step.Id = .config_header;

pub const Options = struct {
    style: Style = .blank,
    max_bytes: usize = 2 * 1024 * 1024,
    include_path: ?[]const u8 = null,
    first_ret_addr: ?usize = null,
    include_guard_override: ?[]const u8 = null,
    fallback_value: ?Value = null,
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
        .fallback_value = options.fallback_value,
        .output_file = .{ .step = &config_header.step },
    };

    return config_header;
}

pub fn addValues(config_header: *ConfigHeader, values: anytype) void {
    return addValuesInner(config_header, values) catch @panic("OOM");
}

pub fn getOutput(config_header: *ConfigHeader) std.Build.LazyPath {
    return .{ .generated = .{ .file = &config_header.output_file } };
}

fn addValuesInner(config_header: *ConfigHeader, values: anytype) !void {
    inline for (@typeInfo(@TypeOf(values)).@"struct".fields) |field| {
        try putValue(config_header, field.name, field.type, @field(values, field.name));
    }
}

fn putValue(config_header: *ConfigHeader, field_name: []const u8, comptime T: type, v: T) !void {
    switch (@typeInfo(T)) {
        .null => {
            try config_header.values.put(field_name, .undef);
        },
        .void => {
            try config_header.values.put(field_name, .defined);
        },
        .bool => {
            try config_header.values.put(field_name, .{ .boolean = v });
        },
        .int => {
            try config_header.values.put(field_name, .{ .int = v });
        },
        .comptime_int => {
            try config_header.values.put(field_name, .{ .int = v });
        },
        .enum_literal => {
            try config_header.values.put(field_name, .{ .ident = @tagName(v) });
        },
        .optional => {
            if (v) |x| {
                return putValue(config_header, field_name, @TypeOf(x), x);
            } else {
                try config_header.values.put(field_name, .undef);
            }
        },
        .pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .array => |array| {
                    if (ptr.size == .one and array.child == u8) {
                        try config_header.values.put(field_name, .{ .string = v });
                        return;
                    }
                },
                .int => {
                    if (ptr.size == .slice and ptr.child == u8) {
                        try config_header.values.put(field_name, .{ .string = v });
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
        .autoconf => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath2(b, step);
            const contents = std.fs.cwd().readFileAlloc(arena, src_path, config_header.max_bytes) catch |err| {
                return step.fail("unable to read autoconf input file '{s}': {s}", .{
                    src_path, @errorName(err),
                });
            };
            try render_autoconf(step, contents, &output, config_header.values, src_path);
        },
        .cmake => |file_source| {
            try output.appendSlice(c_generated_line);
            const src_path = file_source.getPath2(b, step);
            const contents = std.fs.cwd().readFileAlloc(arena, src_path, config_header.max_bytes) catch |err| {
                return step.fail("unable to read cmake input file '{s}': {s}", .{
                    src_path, @errorName(err),
                });
            };
            try render_cmake(step, contents, &output, config_header.values, config_header.fallback_value, src_path);
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
    fallback_value: ?Value,
    src_path: []const u8,
) !void {
    const build = step.owner;
    const allocator = build.allocator;

    var any_errors = false;
    var line_it = std.mem.splitScalar(u8, contents, '\n');

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var unused_values = try values.cloneWithAllocator(arena_allocator);
    var diagnostics: Diagnostics = .{ .allocator = arena_allocator };

    while (line_it.next()) |raw_line| : (diagnostics.line_number += 1) {
        diagnostics.column_number = 1;
        const last_line = line_it.index == line_it.buffer.len;

        const line = expand_variables_cmake(allocator, raw_line, values, &unused_values, fallback_value, &diagnostics) catch |err| {
            try step.addError("{s}:{d}:{d}: unable to substitute variable: {s}: {s}", .{
                src_path,
                diagnostics.line_number,
                diagnostics.column_number,
                @errorName(err),
                diagnostics.metadata orelse "",
            });
            any_errors = true;
            continue;
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
                src_path, diagnostics.line_number,
            });
            any_errors = true;
            continue;
        };
        var value = values.get(name) orelse blk: {
            if (booldefine) {
                break :blk Value{ .int = 0 };
            }
            break :blk Value.undef;
        };
        _ = unused_values.swapRemove(name);

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

    if (unused_values.keys().len > 0) {
        try step.addError("{s}: error: unused variables: {s}", .{
            src_path, unused_values.keys(),
        });
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

fn expand_variables_cmake(
    allocator: Allocator,
    contents: []const u8,
    values: std.StringArrayHashMap(Value),
    unused_values: *std.StringArrayHashMap(Value),
    fallback_value: ?Value,
    diagnostics: *Diagnostics,
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

                    errdefer {
                        diagnostics.column_number = curr + 1;
                        diagnostics.setMetadata(key);
                    }

                    const value = values.get(key) orelse fallback_value orelse return ConfigError.UndefinedVariable;
                    _ = unused_values.swapRemove(key);

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
                const open_pos = var_stack.pop();
                errdefer {
                    diagnostics.column_number = open_pos.source;
                }
                if (source_offset == open_pos.source) {
                    source_offset += open_var.len;
                }
                const missing = contents[source_offset..curr];
                try result.appendSlice(missing);

                const key_start = open_pos.target + open_var.len;
                const key = result.items[key_start..];
                if (key.len == 0) {
                    diagnostics.setMetadata(null);
                    return ConfigError.MissingName;
                }
                const value = values.get(key) orelse fallback_value orelse {
                    diagnostics.setMetadata(key);
                    return ConfigError.UndefinedVariable;
                };
                _ = unused_values.swapRemove(key);
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
            diagnostics.column_number = curr + 1;
            diagnostics.setMetadata(&[_]u8{contents[curr]});
            return ConfigError.InvalidCharacter;
        }
    }

    if (source_offset != contents.len) {
        const missing = contents[source_offset..];
        try result.appendSlice(missing);
    }

    return result.toOwnedSlice();
}

fn testReplaceVariables(
    allocator: Allocator,
    contents: []const u8,
    expected: []const u8,
    values: std.StringArrayHashMap(Value),
) !void {
    try testReplaceVariablesWithFallback(allocator, contents, expected, values, null);
}

fn testReplaceVariablesWithFallback(
    allocator: Allocator,
    contents: []const u8,
    expected: []const u8,
    values: std.StringArrayHashMap(Value),
    fallback_value: ?Value,
) !void {
    var diagnostics: Diagnostics = .{ .allocator = allocator };
    defer diagnostics.deinit();

    var unused = try values.clone();
    defer unused.deinit();

    const actual = try expand_variables_cmake(allocator, contents, values, &unused, fallback_value, &diagnostics);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
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
    try testReplaceVariables(allocator, "", "", values);

    // line with misc content is preserved
    try testReplaceVariables(allocator, "no substitution", "no substitution", values);

    // empty ${} wrapper leads to an error
    try std.testing.expectError(ConfigError.MissingName, testReplaceVariables(allocator, "${}", "", values));

    // empty @ sigils are preserved
    try testReplaceVariables(allocator, "@", "@", values);
    try testReplaceVariables(allocator, "@@", "@@", values);
    try testReplaceVariables(allocator, "@@@", "@@@", values);
    try testReplaceVariables(allocator, "@@@@", "@@@@", values);

    // simple substitution
    try testReplaceVariables(allocator, "@undef@", "", values);
    try testReplaceVariables(allocator, "${undef}", "", values);
    try testReplaceVariables(allocator, "@defined@", "", values);
    try testReplaceVariables(allocator, "${defined}", "", values);
    try testReplaceVariables(allocator, "@true@", "1", values);
    try testReplaceVariables(allocator, "${true}", "1", values);
    try testReplaceVariables(allocator, "@false@", "0", values);
    try testReplaceVariables(allocator, "${false}", "0", values);
    try testReplaceVariables(allocator, "@int@", "42", values);
    try testReplaceVariables(allocator, "${int}", "42", values);
    try testReplaceVariables(allocator, "@ident@", "value", values);
    try testReplaceVariables(allocator, "${ident}", "value", values);
    try testReplaceVariables(allocator, "@string@", "text", values);
    try testReplaceVariables(allocator, "${string}", "text", values);

    // double packed substitution
    try testReplaceVariables(allocator, "@string@@string@", "texttext", values);
    try testReplaceVariables(allocator, "${string}${string}", "texttext", values);

    // triple packed substitution
    try testReplaceVariables(allocator, "@string@@int@@string@", "text42text", values);
    try testReplaceVariables(allocator, "@string@${int}@string@", "text42text", values);
    try testReplaceVariables(allocator, "${string}@int@${string}", "text42text", values);
    try testReplaceVariables(allocator, "${string}${int}${string}", "text42text", values);

    // double separated substitution
    try testReplaceVariables(allocator, "@int@.@int@", "42.42", values);
    try testReplaceVariables(allocator, "${int}.${int}", "42.42", values);

    // triple separated substitution
    try testReplaceVariables(allocator, "@int@.@true@.@int@", "42.1.42", values);
    try testReplaceVariables(allocator, "@int@.${true}.@int@", "42.1.42", values);
    try testReplaceVariables(allocator, "${int}.@true@.${int}", "42.1.42", values);
    try testReplaceVariables(allocator, "${int}.${true}.${int}", "42.1.42", values);

    // misc prefix is preserved
    try testReplaceVariables(allocator, "false is @false@", "false is 0", values);
    try testReplaceVariables(allocator, "false is ${false}", "false is 0", values);

    // misc suffix is preserved
    try testReplaceVariables(allocator, "@true@ is true", "1 is true", values);
    try testReplaceVariables(allocator, "${true} is true", "1 is true", values);

    // surrounding content is preserved
    try testReplaceVariables(allocator, "what is 6*7? @int@!", "what is 6*7? 42!", values);
    try testReplaceVariables(allocator, "what is 6*7? ${int}!", "what is 6*7? 42!", values);

    // incomplete key is preserved
    try testReplaceVariables(allocator, "@undef", "@undef", values);
    try testReplaceVariables(allocator, "${undef", "${undef", values);
    try testReplaceVariables(allocator, "{undef}", "{undef}", values);
    try testReplaceVariables(allocator, "undef@", "undef@", values);
    try testReplaceVariables(allocator, "undef}", "undef}", values);

    // unknown key leads to an error
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "@bad@", "", values));
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "${bad}", "", values));

    // fallback_value suppresses an error
    try testReplaceVariablesWithFallback(allocator, "@bad@", "fallback", values, .{ .string = "fallback" });
    try testReplaceVariablesWithFallback(allocator, "${bad}", "fallback", values, .{ .string = "fallback" });
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
    try testReplaceVariables(allocator, "@@string@@", "@text@", values);
    try testReplaceVariables(allocator, "@${string}@", "@text@", values);

    // @-vars are resolved inside ${}-vars
    try testReplaceVariables(allocator, "${@string_proxy@}", "text", values);

    // expanded variables are considered strings after expansion
    try testReplaceVariables(allocator, "@string_at@", "@string@", values);
    try testReplaceVariables(allocator, "${string_at}", "@string@", values);
    try testReplaceVariables(allocator, "$@string_curly@", "${string}", values);
    try testReplaceVariables(allocator, "$${string_curly}", "${string}", values);
    try testReplaceVariables(allocator, "${string_var}", "${string}", values);
    try testReplaceVariables(allocator, "@string_var@", "${string}", values);
    try testReplaceVariables(allocator, "${dollar}{${string}}", "${text}", values);
    try testReplaceVariables(allocator, "@dollar@{${string}}", "${text}", values);
    try testReplaceVariables(allocator, "@dollar@{@string@}", "${text}", values);

    // when expanded variables contain invalid characters, they prevent further expansion
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "${${string_var}}", "", values));
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "${@string_var@}", "", values));

    // nested expanded variables are expanded from the inside out
    try testReplaceVariables(allocator, "${string${underscore}proxy}", "string", values);
    try testReplaceVariables(allocator, "${string@underscore@proxy}", "string", values);

    // nested vars are only expanded when ${} is closed
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "@nest@underscore@proxy@", "", values));
    try testReplaceVariables(allocator, "${nest${underscore}proxy}", "nest_underscore_proxy", values);
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "@nest@@nest_underscore@underscore@proxy@@proxy@", "", values));
    try testReplaceVariables(allocator, "${nest${${nest_underscore${underscore}proxy}}proxy}", "nest_underscore_proxy", values);

    // invalid characters lead to an error
    try std.testing.expectError(ConfigError.InvalidCharacter, testReplaceVariables(allocator, "${str*ing}", "", values));
    try std.testing.expectError(ConfigError.InvalidCharacter, testReplaceVariables(allocator, "${str$ing}", "", values));
    try std.testing.expectError(ConfigError.InvalidCharacter, testReplaceVariables(allocator, "${str@ing}", "", values));
}

test "expand_variables_cmake escaped characters" {
    const allocator = std.testing.allocator;
    var values = std.StringArrayHashMap(Value).init(allocator);
    defer values.deinit();

    try values.putNoClobber("string", Value{ .string = "text" });

    // backslash is an invalid character for @ lookup
    try testReplaceVariables(allocator, "\\@string\\@", "\\@string\\@", values);

    // backslash is preserved, but doesn't affect ${} variable expansion
    try testReplaceVariables(allocator, "\\${string}", "\\text", values);

    // backslash breaks ${} opening bracket identification
    try testReplaceVariables(allocator, "$\\{string}", "$\\{string}", values);

    // backslash is skipped when checking for invalid characters, yet it mangles the key
    try std.testing.expectError(ConfigError.UndefinedVariable, testReplaceVariables(allocator, "${string\\}", "", values));
}
