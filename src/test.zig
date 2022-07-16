const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const CrossTarget = std.zig.CrossTarget;
const print = std.debug.print;
const assert = std.debug.assert;

const link = @import("link.zig");
const Compilation = @import("Compilation.zig");
const Package = @import("Package.zig");
const introspect = @import("introspect.zig");
const build_options = @import("build_options");
const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const zig_h = link.File.C.zig_h;

const enable_qemu: bool = build_options.enable_qemu;
const enable_wine: bool = build_options.enable_wine;
const enable_wasmtime: bool = build_options.enable_wasmtime;
const enable_darling: bool = build_options.enable_darling;
const enable_rosetta: bool = build_options.enable_rosetta;
const glibc_runtimes_dir: ?[]const u8 = build_options.glibc_runtimes_dir;
const skip_stage1 = build_options.skip_stage1;

const hr = "=" ** 80;

test {
    if (build_options.is_stage1) {
        @import("stage1.zig").os_init();
    }

    const use_gpa = build_options.force_gpa or !builtin.link_libc;
    const gpa = gpa: {
        if (use_gpa) {
            break :gpa std.testing.allocator;
        }
        // We would prefer to use raw libc allocator here, but cannot
        // use it if it won't support the alignment we need.
        if (@alignOf(std.c.max_align_t) < @alignOf(i128)) {
            break :gpa std.heap.c_allocator;
        }
        break :gpa std.heap.raw_c_allocator;
    };

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var ctx = TestContext.init(gpa, arena);
    defer ctx.deinit();

    {
        const dir_path = try std.fs.path.join(arena, &.{
            std.fs.path.dirname(@src().file).?, "..", "test", "cases",
        });

        var dir = try std.fs.cwd().openIterableDir(dir_path, .{});
        defer dir.close();

        ctx.addTestCasesFromDir(dir);
    }

    try @import("test_cases").addCases(&ctx);

    try ctx.run();
}

const ErrorMsg = union(enum) {
    src: struct {
        src_path: []const u8,
        msg: []const u8,
        // maxint means match anything
        // this is a workaround for stage1 compiler bug I ran into when making it ?u32
        line: u32,
        // maxint means match anything
        // this is a workaround for stage1 compiler bug I ran into when making it ?u32
        column: u32,
        kind: Kind,
        count: u32,
    },
    plain: struct {
        msg: []const u8,
        kind: Kind,
        count: u32,
    },

    const Kind = enum {
        @"error",
        note,
    };

    fn init(other: Compilation.AllErrors.Message, kind: Kind) ErrorMsg {
        switch (other) {
            .src => |src| return .{
                .src = .{
                    .src_path = src.src_path,
                    .msg = src.msg,
                    .line = @intCast(u32, src.line),
                    .column = @intCast(u32, src.column),
                    .kind = kind,
                    .count = src.count,
                },
            },
            .plain => |plain| return .{
                .plain = .{
                    .msg = plain.msg,
                    .kind = kind,
                    .count = plain.count,
                },
            },
        }
    }

    pub fn format(
        self: ErrorMsg,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .src => |src| {
                if (!std.mem.eql(u8, src.src_path, "?") or
                    src.line != std.math.maxInt(u32) or
                    src.column != std.math.maxInt(u32))
                {
                    try writer.print("{s}:", .{src.src_path});
                    if (src.line != std.math.maxInt(u32)) {
                        try writer.print("{d}:", .{src.line + 1});
                    } else {
                        try writer.writeAll("?:");
                    }
                    if (src.column != std.math.maxInt(u32)) {
                        try writer.print("{d}: ", .{src.column + 1});
                    } else {
                        try writer.writeAll("?: ");
                    }
                }
                try writer.print("{s}: {s}", .{ @tagName(src.kind), src.msg });
                if (src.count != 1) {
                    try writer.print(" ({d} times)", .{src.count});
                }
            },
            .plain => |plain| {
                try writer.print("{s}: {s}", .{ @tagName(plain.kind), plain.msg });
                if (plain.count != 1) {
                    try writer.print(" ({d} times)", .{plain.count});
                }
            },
        }
    }
};

/// Default config values for known test manifest key-value pairings.
/// Currently handled defaults are:
/// * backend
/// * target
/// * output_mode
/// * is_test
const TestManifestConfigDefaults = struct {
    /// Asserts if the key doesn't exist - yep, it's an oversight alright.
    fn get(@"type": TestManifest.Type, key: []const u8) []const u8 {
        if (std.mem.eql(u8, key, "backend")) {
            return "stage2";
        } else if (std.mem.eql(u8, key, "target")) {
            comptime {
                var defaults: []const u8 = "";
                // TODO should we only return "mainstream" targets by default here?
                // TODO we should also specify ABIs explicitly as the backends are
                // getting more and more complete
                // Linux
                inline for (&[_][]const u8{ "x86_64", "arm", "aarch64" }) |arch| {
                    defaults = defaults ++ arch ++ "-linux" ++ ",";
                }
                // macOS
                inline for (&[_][]const u8{ "x86_64", "aarch64" }) |arch| {
                    defaults = defaults ++ arch ++ "-macos" ++ ",";
                }
                // Wasm
                defaults = defaults ++ "wasm32-wasi";
                return defaults;
            }
        } else if (std.mem.eql(u8, key, "output_mode")) {
            return switch (@"type") {
                .@"error" => "Obj",
                .run => "Exe",
                .cli => @panic("TODO test harness for CLI tests"),
            };
        } else if (std.mem.eql(u8, key, "is_test")) {
            return "0";
        } else unreachable;
    }
};

/// Manifest syntax example:
/// (see https://github.com/ziglang/zig/issues/11288)
///
/// error
/// backend=stage1,stage2
/// output_mode=exe
///
/// :3:19: error: foo
///
/// run
/// target=x86_64-linux,aarch64-macos
///
/// I am expected stdout! Hello!
///
/// cli
///
/// build test
const TestManifest = struct {
    @"type": Type,
    config_map: std.StringHashMap([]const u8),
    trailing_bytes: []const u8 = "",

    const Type = enum {
        @"error",
        run,
        cli,
    };

    const TrailingIterator = struct {
        inner: std.mem.TokenIterator(u8),

        fn next(self: *TrailingIterator) ?[]const u8 {
            const next_inner = self.inner.next() orelse return null;
            return std.mem.trim(u8, next_inner[2..], " \t");
        }
    };

    fn ConfigValueIterator(comptime T: type) type {
        return struct {
            inner: std.mem.SplitIterator(u8),
            parse_fn: ParseFn(T),

            fn next(self: *@This()) !?T {
                const next_raw = self.inner.next() orelse return null;
                return try self.parse_fn(next_raw);
            }
        };
    }

    fn parse(arena: Allocator, bytes: []const u8) !TestManifest {
        // The manifest is the last contiguous block of comments in the file
        // We scan for the beginning by searching backward for the first non-empty line that does not start with "//"
        var start: ?usize = null;
        var end: usize = bytes.len;
        if (bytes.len > 0) {
            var cursor: usize = bytes.len - 1;
            while (true) {
                // Move to beginning of line
                while (cursor > 0 and bytes[cursor - 1] != '\n') cursor -= 1;

                if (std.mem.startsWith(u8, bytes[cursor..], "//")) {
                    start = cursor; // Contiguous comment line, include in manifest
                } else {
                    if (start != null) break; // Encountered non-comment line, end of manifest

                    // We ignore all-whitespace lines following the comment block, but anything else
                    // means that there is no manifest present.
                    if (std.mem.trim(u8, bytes[cursor..end], " \r\n\t").len == 0) {
                        end = cursor;
                    } else break; // If it's not whitespace, there is no manifest
                }

                // Move to previous line
                if (cursor != 0) cursor -= 1 else break;
            }
        }

        const actual_start = start orelse return error.MissingTestManifest;
        const manifest_bytes = bytes[actual_start..end];

        var it = std.mem.tokenize(u8, manifest_bytes, "\r\n");

        // First line is the test type
        const tt: Type = blk: {
            const line = it.next() orelse return error.MissingTestCaseType;
            const raw = std.mem.trim(u8, line[2..], " \t");
            if (std.mem.eql(u8, raw, "error")) {
                break :blk .@"error";
            } else if (std.mem.eql(u8, raw, "run")) {
                break :blk .run;
            } else if (std.mem.eql(u8, raw, "cli")) {
                break :blk .cli;
            } else {
                std.log.warn("unknown test case type requested: {s}", .{raw});
                return error.UnknownTestCaseType;
            }
        };

        var manifest: TestManifest = .{
            .@"type" = tt,
            .config_map = std.StringHashMap([]const u8).init(arena),
        };

        // Any subsequent line until a blank comment line is key=value(s) pair
        while (it.next()) |line| {
            const trimmed = std.mem.trim(u8, line[2..], " \t");
            if (trimmed.len == 0) break;

            // Parse key=value(s)
            var kv_it = std.mem.split(u8, trimmed, "=");
            const key = kv_it.next() orelse return error.MissingKeyForConfig;
            try manifest.config_map.putNoClobber(key, kv_it.next() orelse return error.MissingValuesForConfig);
        }

        // Finally, trailing is expected output
        manifest.trailing_bytes = manifest_bytes[it.index..];

        return manifest;
    }

    fn getConfigForKeyCustomParser(
        self: TestManifest,
        key: []const u8,
        comptime T: type,
        parse_fn: ParseFn(T),
    ) ConfigValueIterator(T) {
        const bytes = self.config_map.get(key) orelse TestManifestConfigDefaults.get(self.@"type", key);
        return ConfigValueIterator(T){
            .inner = std.mem.split(u8, bytes, ","),
            .parse_fn = parse_fn,
        };
    }

    fn getConfigForKey(
        self: TestManifest,
        key: []const u8,
        comptime T: type,
    ) ConfigValueIterator(T) {
        return self.getConfigForKeyCustomParser(key, T, getDefaultParser(T));
    }

    fn getConfigForKeyAlloc(
        self: TestManifest,
        allocator: Allocator,
        key: []const u8,
        comptime T: type,
    ) ![]const T {
        var out = std.ArrayList(T).init(allocator);
        defer out.deinit();
        var it = self.getConfigForKey(key, T);
        while (try it.next()) |item| {
            try out.append(item);
        }
        return out.toOwnedSlice();
    }

    fn getConfigForKeyAssertSingle(self: TestManifest, key: []const u8, comptime T: type) !T {
        var it = self.getConfigForKey(key, T);
        const res = (try it.next()) orelse unreachable;
        assert((try it.next()) == null);
        return res;
    }

    fn trailing(self: TestManifest) TrailingIterator {
        return .{
            .inner = std.mem.tokenize(u8, self.trailing_bytes, "\r\n"),
        };
    }

    fn trailingAlloc(self: TestManifest, allocator: Allocator) error{OutOfMemory}![]const []const u8 {
        var out = std.ArrayList([]const u8).init(allocator);
        defer out.deinit();
        var it = self.trailing();
        while (it.next()) |line| {
            try out.append(line);
        }
        return out.toOwnedSlice();
    }

    fn ParseFn(comptime T: type) type {
        return fn ([]const u8) anyerror!T;
    }

    fn getDefaultParser(comptime T: type) ParseFn(T) {
        switch (@typeInfo(T)) {
            .Int => return struct {
                fn parse(str: []const u8) anyerror!T {
                    return try std.fmt.parseInt(T, str, 0);
                }
            }.parse,
            .Bool => return struct {
                fn parse(str: []const u8) anyerror!T {
                    const as_int = try std.fmt.parseInt(u1, str, 0);
                    return as_int > 0;
                }
            }.parse,
            .Enum => return struct {
                fn parse(str: []const u8) anyerror!T {
                    return std.meta.stringToEnum(T, str) orelse {
                        std.log.err("unknown enum variant for {s}: {s}", .{ @typeName(T), str });
                        return error.UnknownEnumVariant;
                    };
                }
            }.parse,
            .Struct => if (comptime std.mem.eql(u8, @typeName(T), "CrossTarget")) return struct {
                fn parse(str: []const u8) anyerror!T {
                    var opts = CrossTarget.ParseOptions{
                        .arch_os_abi = str,
                    };
                    return try CrossTarget.parse(opts);
                }
            }.parse else @compileError("no default parser for " ++ @typeName(T)),
            else => @compileError("no default parser for " ++ @typeName(T)),
        }
    }
};

const TestStrategy = enum {
    /// Execute tests as independent compilations, unless they are explicitly
    /// incremental ("foo.0.zig", "foo.1.zig", etc.)
    independent,
    /// Execute all tests as incremental updates to a single compilation. Explicitly
    /// incremental tests ("foo.0.zig", "foo.1.zig", etc.) still execute in order
    incremental,
};

/// Iterates a set of filenames extracting batches that are either incremental
/// ("foo.0.zig", "foo.1.zig", etc.) or independent ("foo.zig", "bar.zig", etc.).
/// Assumes filenames are sorted.
const TestIterator = struct {
    start: usize = 0,
    end: usize = 0,
    filenames: []const []const u8,
    /// reset on each call to `next`
    index: usize = 0,

    const Error = error{InvalidIncrementalTestIndex};

    fn next(it: *TestIterator) Error!?[]const []const u8 {
        try it.nextInner();
        if (it.start == it.end) return null;
        return it.filenames[it.start..it.end];
    }

    fn nextInner(it: *TestIterator) Error!void {
        it.start = it.end;
        if (it.end == it.filenames.len) return;
        if (it.end + 1 == it.filenames.len) {
            it.end += 1;
            return;
        }

        const remaining = it.filenames[it.end..];
        it.index = 0;
        while (it.index < remaining.len - 1) : (it.index += 1) {
            // First, check if this file is part of an incremental update sequence
            // Split filename into "<base_name>.<index>.<file_ext>"
            const prev_parts = getTestFileNameParts(remaining[it.index]);
            const new_parts = getTestFileNameParts(remaining[it.index + 1]);

            // If base_name and file_ext match, these files are in the same test sequence
            // and the new one should be the incremented version of the previous test
            if (std.mem.eql(u8, prev_parts.base_name, new_parts.base_name) and
                std.mem.eql(u8, prev_parts.file_ext, new_parts.file_ext))
            {
                // This is "foo.X.zig" followed by "foo.Y.zig". Make sure that X = Y + 1
                if (prev_parts.test_index == null)
                    return error.InvalidIncrementalTestIndex;
                if (new_parts.test_index == null)
                    return error.InvalidIncrementalTestIndex;
                if (new_parts.test_index.? != prev_parts.test_index.? + 1)
                    return error.InvalidIncrementalTestIndex;
            } else {
                // This is not the same test sequence, so the new file must be the first file
                // in a new sequence ("*.0.zig") or an independent test file ("*.zig")
                if (new_parts.test_index != null and new_parts.test_index.? != 0)
                    return error.InvalidIncrementalTestIndex;

                it.end += it.index + 1;
                break;
            }
        } else {
            it.end += remaining.len;
        }
    }

    /// In the event of an `error.InvalidIncrementalTestIndex`, this function can
    /// be used to find the current filename that was being processed.
    /// Asserts the iterator hasn't reached the end.
    fn currentFilename(it: TestIterator) []const u8 {
        assert(it.end != it.filenames.len);
        const remaining = it.filenames[it.end..];
        return remaining[it.index + 1];
    }
};

/// For a filename in the format "<filename>.X.<ext>" or "<filename>.<ext>", returns
/// "<filename>", "<ext>" and X parsed as a decimal number. If X is not present, or
/// cannot be parsed as a decimal number, it is treated as part of <filename>
fn getTestFileNameParts(name: []const u8) struct {
    base_name: []const u8,
    file_ext: []const u8,
    test_index: ?usize,
} {
    const file_ext = std.fs.path.extension(name);
    const trimmed = name[0 .. name.len - file_ext.len]; // Trim off ".<ext>"
    const maybe_index = std.fs.path.extension(trimmed); // Extract ".X"

    // Attempt to parse index
    const index: ?usize = if (maybe_index.len > 0)
        std.fmt.parseInt(usize, maybe_index[1..], 10) catch null
    else
        null;

    // Adjust "<filename>" extent based on parsing success
    const base_name_end = trimmed.len - if (index != null) maybe_index.len else 0;
    return .{
        .base_name = name[0..base_name_end],
        .file_ext = if (file_ext.len > 0) file_ext[1..] else file_ext,
        .test_index = index,
    };
}

/// Sort test filenames in-place, so that incremental test cases ("foo.0.zig",
/// "foo.1.zig", etc.) are contiguous and appear in numerical order.
fn sortTestFilenames(filenames: [][]const u8) void {
    const Context = struct {
        pub fn lessThan(_: @This(), a: []const u8, b: []const u8) bool {
            const a_parts = getTestFileNameParts(a);
            const b_parts = getTestFileNameParts(b);

            // Sort "<base_name>.X.<file_ext>" based on "<base_name>" and "<file_ext>" first
            return switch (std.mem.order(u8, a_parts.base_name, b_parts.base_name)) {
                .lt => true,
                .gt => false,
                .eq => switch (std.mem.order(u8, a_parts.file_ext, b_parts.file_ext)) {
                    .lt => true,
                    .gt => false,
                    .eq => {
                        // a and b differ only in their ".X" part

                        // Sort "<base_name>.<file_ext>" before any "<base_name>.X.<file_ext>"
                        if (a_parts.test_index) |a_index| {
                            if (b_parts.test_index) |b_index| {
                                // Make sure that incremental tests appear in linear order
                                return a_index < b_index;
                            } else {
                                return false;
                            }
                        } else {
                            return b_parts.test_index != null;
                        }
                    },
                },
            };
        }
    };
    std.sort.sort([]const u8, filenames, Context{}, Context.lessThan);
}

pub const TestContext = struct {
    gpa: Allocator,
    arena: Allocator,
    cases: std.ArrayList(Case),

    pub const Update = struct {
        /// The input to the current update. We simulate an incremental update
        /// with the file's contents changed to this value each update.
        ///
        /// This value can change entirely between updates, which would be akin
        /// to deleting the source file and creating a new one from scratch; or
        /// you can keep it mostly consistent, with small changes, testing the
        /// effects of the incremental compilation.
        src: [:0]const u8,
        name: []const u8,
        case: union(enum) {
            /// Check the main binary output file against an expected set of bytes.
            /// This is most useful with, for example, `-ofmt=c`.
            CompareObjectFile: []const u8,
            /// An error update attempts to compile bad code, and ensures that it
            /// fails to compile, and for the expected reasons.
            /// A slice containing the expected errors *in sequential order*.
            Error: []const ErrorMsg,
            /// An execution update compiles and runs the input, testing the
            /// stdout against the expected results
            /// This is a slice containing the expected message.
            Execution: []const u8,
            /// A header update compiles the input with the equivalent of
            /// `-femit-h` and tests the produced header against the
            /// expected result
            Header: []const u8,
        },
    };

    pub const File = struct {
        /// Contents of the importable file. Doesn't yet support incremental updates.
        src: [:0]const u8,
        path: []const u8,
    };

    pub const Backend = enum {
        stage1,
        stage2,
        llvm,
    };

    /// A `Case` consists of a list of `Update`. The same `Compilation` is used for each
    /// update, so each update's source is treated as a single file being
    /// updated by the test harness and incrementally compiled.
    pub const Case = struct {
        /// The name of the test case. This is shown if a test fails, and
        /// otherwise ignored.
        name: []const u8,
        /// The platform the test targets. For non-native platforms, an emulator
        /// such as QEMU is required for tests to complete.
        target: CrossTarget,
        /// In order to be able to run e.g. Execution updates, this must be set
        /// to Executable.
        output_mode: std.builtin.OutputMode,
        optimize_mode: std.builtin.Mode = .Debug,
        updates: std.ArrayList(Update),
        object_format: ?std.Target.ObjectFormat = null,
        emit_h: bool = false,
        is_test: bool = false,
        expect_exact: bool = false,
        backend: Backend = .stage2,
        link_libc: bool = false,

        files: std.ArrayList(File),

        result: anyerror!void = {},

        pub fn addSourceFile(case: *Case, name: []const u8, src: [:0]const u8) void {
            case.files.append(.{ .path = name, .src = src }) catch @panic("out of memory");
        }

        /// Adds a subcase in which the module is updated with `src`, and a C
        /// header is generated.
        pub fn addHeader(self: *Case, src: [:0]const u8, result: [:0]const u8) void {
            self.emit_h = true;
            self.updates.append(.{
                .src = src,
                .name = "update",
                .case = .{ .Header = result },
            }) catch @panic("out of memory");
        }

        /// Adds a subcase in which the module is updated with `src`, compiled,
        /// run, and the output is tested against `result`.
        pub fn addCompareOutput(self: *Case, src: [:0]const u8, result: []const u8) void {
            self.updates.append(.{
                .src = src,
                .name = "update",
                .case = .{ .Execution = result },
            }) catch @panic("out of memory");
        }

        /// Adds a subcase in which the module is updated with `src`, compiled,
        /// and the object file data is compared against `result`.
        pub fn addCompareObjectFile(self: *Case, src: [:0]const u8, result: []const u8) void {
            self.updates.append(.{
                .src = src,
                .name = "update",
                .case = .{ .CompareObjectFile = result },
            }) catch @panic("out of memory");
        }

        pub fn addError(self: *Case, src: [:0]const u8, errors: []const []const u8) void {
            return self.addErrorNamed("update", src, errors);
        }

        /// Adds a subcase in which the module is updated with `src`, which
        /// should contain invalid input, and ensures that compilation fails
        /// for the expected reasons, given in sequential order in `errors` in
        /// the form `:line:column: error: message`.
        pub fn addErrorNamed(
            self: *Case,
            name: []const u8,
            src: [:0]const u8,
            errors: []const []const u8,
        ) void {
            var array = self.updates.allocator.alloc(ErrorMsg, errors.len) catch @panic("out of memory");
            for (errors) |err_msg_line, i| {
                if (std.mem.startsWith(u8, err_msg_line, "error: ")) {
                    array[i] = .{
                        .plain = .{
                            .msg = err_msg_line["error: ".len..],
                            .kind = .@"error",
                            .count = 1,
                        },
                    };
                    continue;
                } else if (std.mem.startsWith(u8, err_msg_line, "note: ")) {
                    array[i] = .{
                        .plain = .{
                            .msg = err_msg_line["note: ".len..],
                            .kind = .note,
                            .count = 1,
                        },
                    };
                    continue;
                }
                // example: "file.zig:1:2: error: bad thing happened"
                var it = std.mem.split(u8, err_msg_line, ":");
                const src_path = it.next() orelse @panic("missing colon");
                const line_text = it.next() orelse @panic("missing line");
                const col_text = it.next() orelse @panic("missing column");
                const kind_text = it.next() orelse @panic("missing 'error'/'note'");
                var msg = it.rest()[1..]; // skip over the space at end of "error: "

                const line: ?u32 = if (std.mem.eql(u8, line_text, "?"))
                    null
                else
                    std.fmt.parseInt(u32, line_text, 10) catch @panic("bad line number");
                const column: ?u32 = if (std.mem.eql(u8, line_text, "?"))
                    null
                else
                    std.fmt.parseInt(u32, col_text, 10) catch @panic("bad column number");
                const kind: ErrorMsg.Kind = if (std.mem.eql(u8, kind_text, " error"))
                    .@"error"
                else if (std.mem.eql(u8, kind_text, " note"))
                    .note
                else
                    @panic("expected 'error'/'note'");

                const line_0based: u32 = if (line) |n| blk: {
                    if (n == 0) {
                        print("{s}: line must be specified starting at one\n", .{self.name});
                        return;
                    }
                    break :blk n - 1;
                } else std.math.maxInt(u32);

                const column_0based: u32 = if (column) |n| blk: {
                    if (n == 0) {
                        print("{s}: line must be specified starting at one\n", .{self.name});
                        return;
                    }
                    break :blk n - 1;
                } else std.math.maxInt(u32);

                const suffix = " times)";
                const count = if (std.mem.endsWith(u8, msg, suffix)) count: {
                    const lparen = std.mem.lastIndexOfScalar(u8, msg, '(').?;
                    const count = std.fmt.parseInt(u32, msg[lparen + 1 .. msg.len - suffix.len], 10) catch @panic("bad error note count number");
                    msg = msg[0 .. lparen - 1];
                    break :count count;
                } else 1;

                array[i] = .{
                    .src = .{
                        .src_path = src_path,
                        .msg = msg,
                        .line = line_0based,
                        .column = column_0based,
                        .kind = kind,
                        .count = count,
                    },
                };
            }
            self.updates.append(.{
                .src = src,
                .name = name,
                .case = .{ .Error = array },
            }) catch @panic("out of memory");
        }

        /// Adds a subcase in which the module is updated with `src`, and
        /// asserts that it compiles without issue
        pub fn compiles(self: *Case, src: [:0]const u8) void {
            self.addError(src, &[_][]const u8{});
        }
    };

    pub fn addExe(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .files = std.ArrayList(File).init(ctx.arena),
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    /// Adds a test case for Zig input, producing an executable
    pub fn exe(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addExe(name, target);
    }

    pub fn exeFromCompiledC(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        const prefixed_name = std.fmt.allocPrint(ctx.arena, "CBE: {s}", .{name}) catch
            @panic("out of memory");
        ctx.cases.append(Case{
            .name = prefixed_name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .object_format = .c,
            .files = std.ArrayList(File).init(ctx.arena),
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    /// Adds a test case that uses the LLVM backend to emit an executable.
    /// Currently this implies linking libc, because only then we can generate a testable executable.
    pub fn exeUsingLlvmBackend(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .files = std.ArrayList(File).init(ctx.arena),
            .backend = .llvm,
            .link_libc = true,
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn addObj(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Obj,
            .files = std.ArrayList(File).init(ctx.arena),
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn addTest(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .is_test = true,
            .files = std.ArrayList(File).init(ctx.arena),
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    /// Adds a test case for Zig input, producing an object file.
    pub fn obj(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addObj(name, target);
    }

    /// Adds a test case for ZIR input, producing an object file.
    pub fn objZIR(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addObj(name, target, .ZIR);
    }

    /// Adds a test case for Zig or ZIR input, producing C code.
    pub fn addC(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Obj,
            .object_format = .c,
            .files = std.ArrayList(File).init(ctx.arena),
        }) catch @panic("out of memory");
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn c(ctx: *TestContext, name: []const u8, target: CrossTarget, src: [:0]const u8, comptime out: [:0]const u8) void {
        ctx.addC(name, target).addCompareObjectFile(src, zig_h ++ out);
    }

    pub fn h(ctx: *TestContext, name: []const u8, target: CrossTarget, src: [:0]const u8, comptime out: [:0]const u8) void {
        ctx.addC(name, target).addHeader(src, zig_h ++ out);
    }

    pub fn objErrStage1(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        if (skip_stage1) return;

        const case = ctx.addObj(name, .{});
        case.backend = .stage1;
        case.addError(src, expected_errors);
    }

    pub fn testErrStage1(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        if (skip_stage1) return;

        const case = ctx.addTest(name, .{});
        case.backend = .stage1;
        case.addError(src, expected_errors);
    }

    pub fn exeErrStage1(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        if (skip_stage1) return;

        const case = ctx.addExe(name, .{});
        case.backend = .stage1;
        case.addError(src, expected_errors);
    }

    pub fn addCompareOutput(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.addExe(name, .{}).addCompareOutput(src, expected_stdout);
    }

    /// Adds a test case that compiles the Zig source given in `src`, executes
    /// it, runs it, and tests the output against `expected_stdout`
    pub fn compareOutput(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        return ctx.addCompareOutput(name, src, expected_stdout);
    }

    /// Adds a test case that compiles the ZIR source given in `src`, executes
    /// it, runs it, and tests the output against `expected_stdout`
    pub fn compareOutputZIR(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.addCompareOutput(name, .ZIR, src, expected_stdout);
    }

    pub fn addTransform(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addObj(name, target).addTransform(src, result);
    }

    /// Adds a test case that compiles the Zig given in `src` to ZIR and tests
    /// the ZIR against `result`
    pub fn transform(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addTransform(name, target, src, result);
    }

    pub fn addError(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addObj(name, target).addError(src, expected_errors);
    }

    /// Adds a test case that ensures that the Zig given in `src` fails to
    /// compile for the expected reasons, given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`.
    pub fn compileError(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, src, expected_errors);
    }

    /// Adds a test case that ensures that the ZIR given in `src` fails to
    /// compile for the expected reasons, given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`.
    pub fn compileErrorZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, .ZIR, src, expected_errors);
    }

    pub fn addCompiles(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addObj(name, target).compiles(src);
    }

    /// Adds a test case that asserts that the Zig given in `src` compiles
    /// without any errors.
    pub fn compiles(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, src);
    }

    /// Adds a test case that asserts that the ZIR given in `src` compiles
    /// without any errors.
    pub fn compilesZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, .ZIR, src);
    }

    /// Adds a test case that first ensures that the Zig given in `src` fails
    /// to compile for the reasons given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`, then
    /// asserts that fixing the source (updating with `fixed_src`) isn't broken
    /// by incremental compilation.
    pub fn incrementalFailure(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    /// Adds a test case that first ensures that the ZIR given in `src` fails
    /// to compile for the reasons given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`, then
    /// asserts that fixing the source (updating with `fixed_src`) isn't broken
    /// by incremental compilation.
    pub fn incrementalFailureZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target, .ZIR);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    /// Adds a test for each file in the provided directory.
    /// Testing strategy (TestStrategy) is inferred automatically from filenames.
    /// Recurses nested directories.
    ///
    /// Each file should include a test manifest as a contiguous block of comments at
    /// the end of the file. The first line should be the test type, followed by a set of
    /// key-value config values, followed by a blank line, then the expected output.
    pub fn addTestCasesFromDir(ctx: *TestContext, dir: std.fs.IterableDir) void {
        var current_file: []const u8 = "none";
        ctx.addTestCasesFromDirInner(dir, &current_file) catch |err| {
            std.debug.panic("test harness failed to process file '{s}': {s}\n", .{
                current_file, @errorName(err),
            });
        };
    }

    fn addTestCasesFromDirInner(
        ctx: *TestContext,
        iterable_dir: std.fs.IterableDir,
        /// This is kept up to date with the currently being processed file so
        /// that if any errors occur the caller knows it happened during this file.
        current_file: *[]const u8,
    ) !void {
        var it = try iterable_dir.walk(ctx.arena);
        var filenames = std.ArrayList([]const u8).init(ctx.arena);

        while (try it.next()) |entry| {
            if (entry.kind != .File) continue;

            // Ignore stuff such as .swp files
            switch (Compilation.classifyFileExt(entry.basename)) {
                .unknown => continue,
                else => {},
            }
            try filenames.append(try ctx.arena.dupe(u8, entry.path));
        }

        // Sort filenames, so that incremental tests are contiguous and in-order
        sortTestFilenames(filenames.items);

        var test_it = TestIterator{ .filenames = filenames.items };
        while (test_it.next()) |maybe_batch| {
            const batch = maybe_batch orelse break;
            const strategy: TestStrategy = if (batch.len > 1) .incremental else .independent;
            var cases = std.ArrayList(usize).init(ctx.arena);

            for (batch) |filename| {
                current_file.* = filename;

                const max_file_size = 10 * 1024 * 1024;
                const src = try iterable_dir.dir.readFileAllocOptions(ctx.arena, filename, max_file_size, null, 1, 0);

                // Parse the manifest
                var manifest = try TestManifest.parse(ctx.arena, src);

                if (cases.items.len == 0) {
                    const backends = try manifest.getConfigForKeyAlloc(ctx.arena, "backend", Backend);
                    const targets = try manifest.getConfigForKeyAlloc(ctx.arena, "target", CrossTarget);
                    const is_test = try manifest.getConfigForKeyAssertSingle("is_test", bool);
                    const output_mode = try manifest.getConfigForKeyAssertSingle("output_mode", std.builtin.OutputMode);

                    const name_prefix = blk: {
                        const ext_index = std.mem.lastIndexOfScalar(u8, current_file.*, '.') orelse
                            return error.InvalidFilename;
                        const index = std.mem.lastIndexOfScalar(u8, current_file.*[0..ext_index], '.') orelse ext_index;
                        break :blk current_file.*[0..index];
                    };

                    // Cross-product to get all possible test combinations
                    for (backends) |backend| {
                        if (backend == .stage1 and skip_stage1) continue;

                        for (targets) |target| {
                            const name = try std.fmt.allocPrint(ctx.arena, "{s} ({s}, {s})", .{
                                name_prefix,
                                @tagName(backend),
                                try target.zigTriple(ctx.arena),
                            });
                            const next = ctx.cases.items.len;
                            try ctx.cases.append(.{
                                .name = name,
                                .target = target,
                                .backend = backend,
                                .updates = std.ArrayList(TestContext.Update).init(ctx.cases.allocator),
                                .is_test = is_test,
                                .output_mode = output_mode,
                                .link_libc = backend == .llvm,
                                .files = std.ArrayList(TestContext.File).init(ctx.cases.allocator),
                            });
                            try cases.append(next);
                        }
                    }
                }

                for (cases.items) |case_index| {
                    const case = &ctx.cases.items[case_index];
                    switch (manifest.@"type") {
                        .@"error" => {
                            const errors = try manifest.trailingAlloc(ctx.arena);
                            switch (strategy) {
                                .independent => {
                                    case.addError(src, errors);
                                },
                                .incremental => {
                                    case.addErrorNamed("update", src, errors);
                                },
                            }
                        },
                        .run => {
                            var output = std.ArrayList(u8).init(ctx.arena);
                            var trailing_it = manifest.trailing();
                            while (trailing_it.next()) |line| {
                                try output.appendSlice(line);
                                try output.append('\n');
                            }
                            if (output.items.len > 0) {
                                try output.resize(output.items.len - 1);
                            }
                            case.addCompareOutput(src, output.toOwnedSlice());
                        },
                        .cli => @panic("TODO cli tests"),
                    }
                }
            }
        } else |err| {
            // make sure the current file is set to the file that produced an error
            current_file.* = test_it.currentFilename();
            return err;
        }
    }

    fn init(gpa: Allocator, arena: Allocator) TestContext {
        return .{
            .gpa = gpa,
            .cases = std.ArrayList(Case).init(gpa),
            .arena = arena,
        };
    }

    fn deinit(self: *TestContext) void {
        for (self.cases.items) |case| {
            for (case.updates.items) |u| {
                if (u.case == .Error) {
                    case.updates.allocator.free(u.case.Error);
                }
            }
            case.updates.deinit();
        }
        self.cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        const host = try std.zig.system.NativeTargetInfo.detect(self.gpa, .{});

        var progress = std.Progress{};
        const root_node = progress.start("compiler", self.cases.items.len);
        defer root_node.end();

        var zig_lib_directory = try introspect.findZigLibDir(self.gpa);
        defer zig_lib_directory.handle.close();
        defer self.gpa.free(zig_lib_directory.path.?);

        var aux_thread_pool: ThreadPool = undefined;
        try aux_thread_pool.init(self.gpa);
        defer aux_thread_pool.deinit();

        var case_thread_pool: ThreadPool = undefined;
        try case_thread_pool.init(self.gpa);
        defer case_thread_pool.deinit();

        // Use the same global cache dir for all the tests, such that we for example don't have to
        // rebuild musl libc for every case (when LLVM backend is enabled).
        var global_tmp = std.testing.tmpDir(.{});
        defer global_tmp.cleanup();

        var cache_dir = try global_tmp.dir.makeOpenPath("zig-cache", .{});
        defer cache_dir.close();
        const tmp_dir_path = try std.fs.path.join(self.gpa, &[_][]const u8{ ".", "zig-cache", "tmp", &global_tmp.sub_path });
        defer self.gpa.free(tmp_dir_path);

        const global_cache_directory: Compilation.Directory = .{
            .handle = cache_dir,
            .path = try std.fs.path.join(self.gpa, &[_][]const u8{ tmp_dir_path, "zig-cache" }),
        };
        defer self.gpa.free(global_cache_directory.path.?);

        {
            var wait_group: WaitGroup = .{};
            defer wait_group.wait();

            for (self.cases.items) |*case| {
                if (build_options.skip_non_native) {
                    if (case.target.getCpuArch() != builtin.cpu.arch)
                        continue;
                    if (case.target.getObjectFormat() != builtin.object_format)
                        continue;
                }

                // Skip tests that require LLVM backend when it is not available
                if (!build_options.have_llvm and case.backend == .llvm)
                    continue;

                if (build_options.test_filter) |test_filter| {
                    if (std.mem.indexOf(u8, case.name, test_filter) == null) continue;
                }

                wait_group.start();
                try case_thread_pool.spawn(workerRunOneCase, .{
                    self.gpa,
                    root_node,
                    case,
                    zig_lib_directory,
                    &aux_thread_pool,
                    global_cache_directory,
                    host,
                    &wait_group,
                });
            }
        }

        var fail_count: usize = 0;
        for (self.cases.items) |*case| {
            case.result catch |err| {
                fail_count += 1;
                print("{s} failed: {s}\n", .{ case.name, @errorName(err) });
            };
        }

        if (fail_count != 0) {
            print("{d} tests failed\n", .{fail_count});
            return error.TestFailed;
        }
    }

    fn workerRunOneCase(
        gpa: Allocator,
        root_node: *std.Progress.Node,
        case: *Case,
        zig_lib_directory: Compilation.Directory,
        thread_pool: *ThreadPool,
        global_cache_directory: Compilation.Directory,
        host: std.zig.system.NativeTargetInfo,
        wait_group: *WaitGroup,
    ) void {
        defer wait_group.finish();

        var prg_node = root_node.start(case.name, case.updates.items.len);
        prg_node.activate();
        defer prg_node.end();

        case.result = runOneCase(
            gpa,
            &prg_node,
            case.*,
            zig_lib_directory,
            thread_pool,
            global_cache_directory,
            host,
        );
    }

    fn runOneCase(
        allocator: Allocator,
        root_node: *std.Progress.Node,
        case: Case,
        zig_lib_directory: Compilation.Directory,
        thread_pool: *ThreadPool,
        global_cache_directory: Compilation.Directory,
        host: std.zig.system.NativeTargetInfo,
    ) !void {
        const target_info = try std.zig.system.NativeTargetInfo.detect(allocator, case.target);
        const target = target_info.target;

        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        var cache_dir = try tmp.dir.makeOpenPath("zig-cache", .{});
        defer cache_dir.close();

        const tmp_dir_path = try std.fs.path.join(
            arena,
            &[_][]const u8{ ".", "zig-cache", "tmp", &tmp.sub_path },
        );
        const tmp_dir_path_plus_slash = try std.fmt.allocPrint(
            arena,
            "{s}" ++ std.fs.path.sep_str,
            .{tmp_dir_path},
        );
        const local_cache_path = try std.fs.path.join(
            arena,
            &[_][]const u8{ tmp_dir_path, "zig-cache" },
        );

        for (case.files.items) |file| {
            try tmp.dir.writeFile(file.path, file.src);
        }

        if (case.backend == .stage1) {
            // stage1 backend has limitations:
            // * leaks memory
            // * calls exit() when a compile error happens
            // * cannot handle updates
            // because of this we must spawn a child process rather than
            // using Compilation directly.

            if (!std.process.can_spawn) {
                print("Unable to spawn child processes on {s}, skipping test.\n", .{@tagName(builtin.os.tag)});
                return; // Pass test.
            }

            assert(case.updates.items.len == 1);
            const update = case.updates.items[0];
            try tmp.dir.writeFile(tmp_src_path, update.src);

            var zig_args = std.ArrayList([]const u8).init(arena);
            try zig_args.append(std.testing.zig_exe_path);

            if (case.is_test) {
                try zig_args.append("test");
            } else if (update.case == .Execution) {
                try zig_args.append("run");
            } else switch (case.output_mode) {
                .Obj => try zig_args.append("build-obj"),
                .Exe => try zig_args.append("build-exe"),
                .Lib => try zig_args.append("build-lib"),
            }

            try zig_args.append(try std.fs.path.join(arena, &.{ tmp_dir_path, tmp_src_path }));

            try zig_args.append("--name");
            try zig_args.append("test");

            try zig_args.append("--cache-dir");
            try zig_args.append(local_cache_path);

            try zig_args.append("--global-cache-dir");
            try zig_args.append(global_cache_directory.path orelse ".");

            if (!case.target.isNative()) {
                try zig_args.append("-target");
                try zig_args.append(try target.zigTriple(arena));
            }

            try zig_args.append("-O");
            try zig_args.append(@tagName(case.optimize_mode));

            // Prevent sub-process progress bar from interfering with the
            // one in this parent process.
            try zig_args.append("--color");
            try zig_args.append("off");

            const result = try std.ChildProcess.exec(.{
                .allocator = arena,
                .argv = zig_args.items,
            });
            switch (update.case) {
                .Error => |case_error_list| {
                    switch (result.term) {
                        .Exited => |code| {
                            if (code == 0) {
                                dumpArgs(zig_args.items);
                                return error.CompilationIncorrectlySucceeded;
                            }
                        },
                        else => {
                            std.debug.print("{s}", .{result.stderr});
                            dumpArgs(zig_args.items);
                            return error.CompilationCrashed;
                        },
                    }
                    var ok = true;
                    if (case.expect_exact) {
                        var err_iter = std.mem.split(u8, result.stderr, "\n");
                        var i: usize = 0;
                        ok = while (err_iter.next()) |line| : (i += 1) {
                            if (i >= case_error_list.len) break false;
                            const expected = try std.mem.replaceOwned(
                                u8,
                                arena,
                                try std.fmt.allocPrint(arena, "{s}", .{case_error_list[i]}),
                                "${DIR}",
                                tmp_dir_path_plus_slash,
                            );

                            if (std.mem.indexOf(u8, line, expected) == null) break false;
                            continue;
                        } else true;

                        ok = ok and i == case_error_list.len;

                        if (!ok) {
                            print("\n======== Expected these compile errors: ========\n", .{});
                            for (case_error_list) |msg| {
                                const expected = try std.fmt.allocPrint(arena, "{s}", .{msg});
                                print("{s}\n", .{expected});
                            }
                        }
                    } else {
                        for (case_error_list) |msg| {
                            const expected = try std.mem.replaceOwned(
                                u8,
                                arena,
                                try std.fmt.allocPrint(arena, "{s}", .{msg}),
                                "${DIR}",
                                tmp_dir_path_plus_slash,
                            );
                            if (std.mem.indexOf(u8, result.stderr, expected) == null) {
                                print(
                                    \\
                                    \\=========== Expected compile error: ============
                                    \\{s}
                                    \\
                                , .{expected});
                                ok = false;
                                break;
                            }
                        }
                    }

                    if (!ok) {
                        print(
                            \\================= Full output: =================
                            \\{s}
                            \\================================================
                            \\
                        , .{result.stderr});
                        return error.TestFailed;
                    }
                },
                .CompareObjectFile => @panic("TODO implement in the test harness"),
                .Execution => |expected_stdout| {
                    switch (result.term) {
                        .Exited => |code| {
                            if (code != 0) {
                                std.debug.print("{s}", .{result.stderr});
                                dumpArgs(zig_args.items);
                                return error.CompilationFailed;
                            }
                        },
                        else => {
                            std.debug.print("{s}", .{result.stderr});
                            dumpArgs(zig_args.items);
                            return error.CompilationCrashed;
                        },
                    }
                    try std.testing.expectEqualStrings("", result.stderr);
                    try std.testing.expectEqualStrings(expected_stdout, result.stdout);
                },
                .Header => @panic("TODO implement in the test harness"),
            }
            return;
        }

        const zig_cache_directory: Compilation.Directory = .{
            .handle = cache_dir,
            .path = local_cache_path,
        };

        var main_pkg: Package = .{
            .root_src_directory = .{ .path = tmp_dir_path, .handle = tmp.dir },
            .root_src_path = tmp_src_path,
        };
        defer main_pkg.table.deinit(allocator);

        const bin_name = try std.zig.binNameAlloc(arena, .{
            .root_name = "test_case",
            .target = target,
            .output_mode = case.output_mode,
            .object_format = case.object_format,
        });

        const emit_directory: Compilation.Directory = .{
            .path = tmp_dir_path,
            .handle = tmp.dir,
        };
        const emit_bin: Compilation.EmitLoc = .{
            .directory = emit_directory,
            .basename = bin_name,
        };
        const emit_h: ?Compilation.EmitLoc = if (case.emit_h) .{
            .directory = emit_directory,
            .basename = "test_case.h",
        } else null;
        const use_llvm: bool = switch (case.backend) {
            .llvm => true,
            else => false,
        };
        const comp = try Compilation.create(allocator, .{
            .local_cache_directory = zig_cache_directory,
            .global_cache_directory = global_cache_directory,
            .zig_lib_directory = zig_lib_directory,
            .thread_pool = thread_pool,
            .root_name = "test_case",
            .target = target,
            // TODO: support tests for object file building, and library builds
            // and linking. This will require a rework to support multi-file
            // tests.
            .output_mode = case.output_mode,
            .is_test = case.is_test,
            .optimize_mode = case.optimize_mode,
            .emit_bin = emit_bin,
            .emit_h = emit_h,
            .main_pkg = &main_pkg,
            .keep_source_files_loaded = true,
            .object_format = case.object_format,
            .is_native_os = case.target.isNativeOs(),
            .is_native_abi = case.target.isNativeAbi(),
            .dynamic_linker = target_info.dynamic_linker.get(),
            .link_libc = case.link_libc,
            .use_llvm = use_llvm,
            .use_stage1 = null, // We already handled stage1 tests
            .self_exe_path = std.testing.zig_exe_path,
            // TODO instead of turning off color, pass in a std.Progress.Node
            .color = .off,
        });
        defer comp.destroy();

        for (case.updates.items) |update, update_index| {
            var update_node = root_node.start(update.name, 3);
            update_node.activate();
            defer update_node.end();

            var sync_node = update_node.start("write", 0);
            sync_node.activate();
            try tmp.dir.writeFile(tmp_src_path, update.src);
            sync_node.end();

            var module_node = update_node.start("parse/analysis/codegen", 0);
            module_node.activate();
            try comp.makeBinFileWritable();
            try comp.update();
            module_node.end();

            if (update.case != .Error) {
                var all_errors = try comp.getAllErrorsAlloc();
                defer all_errors.deinit(allocator);
                if (all_errors.list.len != 0) {
                    print(
                        "\nCase '{s}': unexpected errors at update_index={d}:\n{s}\n",
                        .{ case.name, update_index, hr },
                    );
                    for (all_errors.list) |err_msg| {
                        switch (err_msg) {
                            .src => |src| {
                                print("{s}:{d}:{d}: error: {s}\n{s}\n", .{
                                    src.src_path, src.line + 1, src.column + 1, src.msg, hr,
                                });
                            },
                            .plain => |plain| {
                                print("error: {s}\n{s}\n", .{ plain.msg, hr });
                            },
                        }
                    }
                    // TODO print generated C code
                    return error.UnexpectedCompileErrors;
                }
            }

            switch (update.case) {
                .Header => |expected_output| {
                    var file = try tmp.dir.openFile("test_case.h", .{ .mode = .read_only });
                    defer file.close();
                    const out = try file.reader().readAllAlloc(arena, 5 * 1024 * 1024);

                    try std.testing.expectEqualStrings(expected_output, out);
                },
                .CompareObjectFile => |expected_output| {
                    var file = try tmp.dir.openFile(bin_name, .{ .mode = .read_only });
                    defer file.close();
                    const out = try file.reader().readAllAlloc(arena, 5 * 1024 * 1024);

                    try std.testing.expectEqualStrings(expected_output, out);
                },
                .Error => |case_error_list| {
                    var test_node = update_node.start("assert", 0);
                    test_node.activate();
                    defer test_node.end();

                    const handled_errors = try arena.alloc(bool, case_error_list.len);
                    std.mem.set(bool, handled_errors, false);

                    var actual_errors = try comp.getAllErrorsAlloc();
                    defer actual_errors.deinit(allocator);

                    var any_failed = false;
                    var notes_to_check = std.ArrayList(*const Compilation.AllErrors.Message).init(allocator);
                    defer notes_to_check.deinit();

                    for (actual_errors.list) |actual_error| {
                        for (case_error_list) |case_msg, i| {
                            if (handled_errors[i]) continue;

                            const ex_tag: std.meta.Tag(@TypeOf(case_msg)) = case_msg;
                            switch (actual_error) {
                                .src => |actual_msg| {
                                    for (actual_msg.notes) |*note| {
                                        try notes_to_check.append(note);
                                    }

                                    if (ex_tag != .src) continue;

                                    const src_path_ok = case_msg.src.src_path.len == 0 or
                                        std.mem.eql(u8, case_msg.src.src_path, actual_msg.src_path);

                                    const expected_msg = try std.mem.replaceOwned(
                                        u8,
                                        arena,
                                        case_msg.src.msg,
                                        "${DIR}",
                                        tmp_dir_path_plus_slash,
                                    );

                                    var buf: [1024]u8 = undefined;
                                    const rendered_msg = blk: {
                                        var msg: Compilation.AllErrors.Message = actual_error;
                                        msg.src.src_path = case_msg.src.src_path;
                                        msg.src.notes = &.{};
                                        var fib = std.io.fixedBufferStream(&buf);
                                        try msg.renderToWriter(.no_color, fib.writer(), "error", .Red, 0);
                                        var it = std.mem.split(u8, fib.getWritten(), "error: ");
                                        _ = it.next();
                                        const rendered = it.rest();
                                        break :blk rendered[0 .. rendered.len - 1]; // trim final newline
                                    };

                                    if (src_path_ok and
                                        (case_msg.src.line == std.math.maxInt(u32) or
                                        actual_msg.line == case_msg.src.line) and
                                        (case_msg.src.column == std.math.maxInt(u32) or
                                        actual_msg.column == case_msg.src.column) and
                                        std.mem.eql(u8, expected_msg, rendered_msg) and
                                        case_msg.src.kind == .@"error" and
                                        actual_msg.count == case_msg.src.count)
                                    {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                                .plain => |plain| {
                                    if (ex_tag != .plain) continue;

                                    if (std.mem.eql(u8, case_msg.plain.msg, plain.msg) and
                                        case_msg.plain.kind == .@"error" and
                                        case_msg.plain.count == plain.count)
                                    {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                            }
                        } else {
                            print(
                                "\nUnexpected error:\n{s}\n{}\n{s}",
                                .{ hr, ErrorMsg.init(actual_error, .@"error"), hr },
                            );
                            any_failed = true;
                        }
                    }
                    while (notes_to_check.popOrNull()) |note| {
                        for (case_error_list) |case_msg, i| {
                            const ex_tag: std.meta.Tag(@TypeOf(case_msg)) = case_msg;
                            switch (note.*) {
                                .src => |actual_msg| {
                                    for (actual_msg.notes) |*sub_note| {
                                        try notes_to_check.append(sub_note);
                                    }
                                    if (ex_tag != .src) continue;

                                    const expected_msg = try std.mem.replaceOwned(
                                        u8,
                                        arena,
                                        case_msg.src.msg,
                                        "${DIR}",
                                        tmp_dir_path_plus_slash,
                                    );

                                    if ((case_msg.src.line == std.math.maxInt(u32) or
                                        actual_msg.line == case_msg.src.line) and
                                        (case_msg.src.column == std.math.maxInt(u32) or
                                        actual_msg.column == case_msg.src.column) and
                                        std.mem.eql(u8, expected_msg, actual_msg.msg) and
                                        case_msg.src.kind == .note)
                                    {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                                .plain => |plain| {
                                    if (ex_tag != .plain) continue;

                                    if (std.mem.eql(u8, case_msg.plain.msg, plain.msg) and
                                        case_msg.plain.kind == .note)
                                    {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                            }
                        } else {
                            print(
                                "\nUnexpected note:\n{s}\n{}\n{s}",
                                .{ hr, ErrorMsg.init(note.*, .note), hr },
                            );
                            any_failed = true;
                        }
                    }

                    for (handled_errors) |handled, i| {
                        if (!handled) {
                            print(
                                "\nExpected error not found:\n{s}\n{}\n{s}",
                                .{ hr, case_error_list[i], hr },
                            );
                            any_failed = true;
                        }
                    }

                    if (any_failed) {
                        print("\nupdate_index={d}\n", .{update_index});
                        return error.WrongCompileErrors;
                    }
                },
                .Execution => |expected_stdout| {
                    if (!std.process.can_spawn) {
                        print("Unable to spawn child processes on {s}, skipping test.\n", .{@tagName(builtin.os.tag)});
                        return; // Pass test.
                    }

                    update_node.setEstimatedTotalItems(4);

                    var argv = std.ArrayList([]const u8).init(allocator);
                    defer argv.deinit();

                    var exec_result = x: {
                        var exec_node = update_node.start("execute", 0);
                        exec_node.activate();
                        defer exec_node.end();

                        // We go out of our way here to use the unique temporary directory name in
                        // the exe_path so that it makes its way into the cache hash, avoiding
                        // cache collisions from multiple threads doing `zig run` at the same time
                        // on the same test_case.c input filename.
                        const ss = std.fs.path.sep_str;
                        const exe_path = try std.fmt.allocPrint(
                            arena,
                            ".." ++ ss ++ "{s}" ++ ss ++ "{s}",
                            .{ &tmp.sub_path, bin_name },
                        );
                        if (case.object_format != null and case.object_format.? == .c) {
                            if (host.getExternalExecutor(target_info, .{ .link_libc = true }) != .native) {
                                // We wouldn't be able to run the compiled C code.
                                return; // Pass test.
                            }
                            try argv.appendSlice(&[_][]const u8{
                                std.testing.zig_exe_path,
                                "run",
                                "-cflags",
                                "-std=c99",
                                "-pedantic",
                                "-Werror",
                                "-Wno-incompatible-library-redeclaration", // https://github.com/ziglang/zig/issues/875
                                "--",
                                "-lc",
                                exe_path,
                            });
                        } else switch (host.getExternalExecutor(target_info, .{ .link_libc = case.link_libc })) {
                            .native => try argv.append(exe_path),
                            .bad_dl, .bad_os_or_cpu => return, // Pass test.

                            .rosetta => if (enable_rosetta) {
                                try argv.append(exe_path);
                            } else {
                                return; // Rosetta not available, pass test.
                            },

                            .qemu => |qemu_bin_name| if (enable_qemu) {
                                const need_cross_glibc = target.isGnuLibC() and case.link_libc;
                                const glibc_dir_arg = if (need_cross_glibc)
                                    glibc_runtimes_dir orelse return // glibc dir not available; pass test
                                else
                                    null;
                                try argv.append(qemu_bin_name);
                                if (glibc_dir_arg) |dir| {
                                    const linux_triple = try target.linuxTriple(arena);
                                    const full_dir = try std.fs.path.join(arena, &[_][]const u8{
                                        dir,
                                        linux_triple,
                                    });

                                    try argv.append("-L");
                                    try argv.append(full_dir);
                                }
                                try argv.append(exe_path);
                            } else {
                                return; // QEMU not available; pass test.
                            },

                            .wine => |wine_bin_name| if (enable_wine) {
                                try argv.append(wine_bin_name);
                                try argv.append(exe_path);
                            } else {
                                return; // Wine not available; pass test.
                            },

                            .wasmtime => |wasmtime_bin_name| if (enable_wasmtime) {
                                try argv.append(wasmtime_bin_name);
                                try argv.append("--dir=.");
                                try argv.append(exe_path);
                            } else {
                                return; // wasmtime not available; pass test.
                            },

                            .darling => |darling_bin_name| if (enable_darling) {
                                try argv.append(darling_bin_name);
                                // Since we use relative to cwd here, we invoke darling with
                                // "shell" subcommand.
                                try argv.append("shell");
                                try argv.append(exe_path);
                            } else {
                                return; // Darling not available; pass test.
                            },
                        }

                        try comp.makeBinFileExecutable();

                        while (true) {
                            break :x std.ChildProcess.exec(.{
                                .allocator = allocator,
                                .argv = argv.items,
                                .cwd_dir = tmp.dir,
                                .cwd = tmp_dir_path,
                            }) catch |err| switch (err) {
                                error.FileBusy => {
                                    // There is a fundamental design flaw in Unix systems with how
                                    // ETXTBSY interacts with fork+exec.
                                    // https://github.com/golang/go/issues/22315
                                    // https://bugs.openjdk.org/browse/JDK-8068370
                                    // Unfortunately, this could be a real error, but we can't
                                    // tell the difference here.
                                    continue;
                                },
                                else => {
                                    print("\n{s}.{d} The following command failed with {s}:\n", .{
                                        case.name, update_index, @errorName(err),
                                    });
                                    dumpArgs(argv.items);
                                    return error.ChildProcessExecution;
                                },
                            };
                        }
                    };
                    var test_node = update_node.start("test", 0);
                    test_node.activate();
                    defer test_node.end();
                    defer allocator.free(exec_result.stdout);
                    defer allocator.free(exec_result.stderr);
                    switch (exec_result.term) {
                        .Exited => |code| {
                            if (code != 0) {
                                print("\n{s}\n{s}: execution exited with code {d}:\n", .{
                                    exec_result.stderr, case.name, code,
                                });
                                dumpArgs(argv.items);
                                return error.ChildProcessExecution;
                            }
                        },
                        else => {
                            print("\n{s}\n{s}: execution crashed:\n", .{
                                exec_result.stderr, case.name,
                            });
                            dumpArgs(argv.items);
                            return error.ChildProcessExecution;
                        },
                    }
                    try std.testing.expectEqualStrings(expected_stdout, exec_result.stdout);
                    // We allow stderr to have garbage in it because wasmtime prints a
                    // warning about --invoke even though we don't pass it.
                    //std.testing.expectEqualStrings("", exec_result.stderr);
                },
            }
        }
    }
};

fn dumpArgs(argv: []const []const u8) void {
    for (argv) |arg| {
        print("{s} ", .{arg});
    }
    print("\n", .{});
}

const tmp_src_path = "tmp.zig";
