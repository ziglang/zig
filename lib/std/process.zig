const std = @import("std.zig");
const builtin = std.builtin;
const os = std.os;
const fs = std.fs;
const BufMap = std.BufMap;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;

pub const abort = os.abort;
pub const exit = os.exit;
pub const changeCurDir = os.chdir;
pub const changeCurDirC = os.chdirC;

/// The result is a slice of `out_buffer`, from index `0`.
pub fn getCwd(out_buffer: []u8) ![]u8 {
    return os.getcwd(out_buffer);
}

/// Caller must free the returned memory.
pub fn getCwdAlloc(allocator: *Allocator) ![]u8 {
    // The use of MAX_PATH_BYTES here is just a heuristic: most paths will fit
    // in stack_buf, avoiding an extra allocation in the common case.
    var stack_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    var heap_buf: ?[]u8 = null;
    defer if (heap_buf) |buf| allocator.free(buf);

    var current_buf: []u8 = &stack_buf;
    while (true) {
        if (os.getcwd(current_buf)) |slice| {
            return allocator.dupe(u8, slice);
        } else |err| switch (err) {
            error.NameTooLong => {
                // The path is too long to fit in stack_buf. Allocate geometrically
                // increasing buffers until we find one that works
                const new_capacity = current_buf.len * 2;
                if (heap_buf) |buf| allocator.free(buf);
                current_buf = try allocator.alloc(u8, new_capacity);
                heap_buf = current_buf;
            },
            else => |e| return e,
        }
    }
}

test "getCwdAlloc" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const cwd = try getCwdAlloc(testing.allocator);
    testing.allocator.free(cwd);
}

/// Caller owns resulting `BufMap`.
pub fn getEnvMap(allocator: *Allocator) !BufMap {
    var result = BufMap.init(allocator);
    errdefer result.deinit();

    if (builtin.os.tag == .windows) {
        const ptr = os.windows.peb().ProcessParameters.Environment;

        var i: usize = 0;
        while (ptr[i] != 0) {
            const key_start = i;

            while (ptr[i] != 0 and ptr[i] != '=') : (i += 1) {}
            const key_w = ptr[key_start..i];
            const key = try std.unicode.utf16leToUtf8Alloc(allocator, key_w);
            errdefer allocator.free(key);

            if (ptr[i] == '=') i += 1;

            const value_start = i;
            while (ptr[i] != 0) : (i += 1) {}
            const value_w = ptr[value_start..i];
            const value = try std.unicode.utf16leToUtf8Alloc(allocator, value_w);
            errdefer allocator.free(value);

            i += 1; // skip over null byte

            try result.setMove(key, value);
        }
        return result;
    } else if (builtin.os.tag == .wasi) {
        var environ_count: usize = undefined;
        var environ_buf_size: usize = undefined;

        const environ_sizes_get_ret = os.wasi.environ_sizes_get(&environ_count, &environ_buf_size);
        if (environ_sizes_get_ret != os.wasi.ESUCCESS) {
            return os.unexpectedErrno(environ_sizes_get_ret);
        }

        var environ = try allocator.alloc([*:0]u8, environ_count);
        defer allocator.free(environ);
        var environ_buf = try allocator.alloc(u8, environ_buf_size);
        defer allocator.free(environ_buf);

        const environ_get_ret = os.wasi.environ_get(environ.ptr, environ_buf.ptr);
        if (environ_get_ret != os.wasi.ESUCCESS) {
            return os.unexpectedErrno(environ_get_ret);
        }

        for (environ) |env| {
            const pair = mem.spanZ(env);
            var parts = mem.split(pair, "=");
            const key = parts.next().?;
            const value = parts.next().?;
            try result.set(key, value);
        }
        return result;
    } else if (builtin.link_libc) {
        var ptr = std.c.environ;
        while (ptr.*) |line| : (ptr += 1) {
            var line_i: usize = 0;
            while (line[line_i] != 0 and line[line_i] != '=') : (line_i += 1) {}
            const key = line[0..line_i];

            var end_i: usize = line_i;
            while (line[end_i] != 0) : (end_i += 1) {}
            const value = line[line_i + 1 .. end_i];

            try result.set(key, value);
        }
        return result;
    } else {
        for (os.environ) |line| {
            var line_i: usize = 0;
            while (line[line_i] != 0 and line[line_i] != '=') : (line_i += 1) {}
            const key = line[0..line_i];

            var end_i: usize = line_i;
            while (line[end_i] != 0) : (end_i += 1) {}
            const value = line[line_i + 1 .. end_i];

            try result.set(key, value);
        }
        return result;
    }
}

test "os.getEnvMap" {
    var env = try getEnvMap(std.testing.allocator);
    defer env.deinit();
}

pub const GetEnvVarOwnedError = error{
    OutOfMemory,
    EnvironmentVariableNotFound,

    /// See https://github.com/ziglang/zig/issues/1774
    InvalidUtf8,
};

/// Caller must free returned memory.
pub fn getEnvVarOwned(allocator: *mem.Allocator, key: []const u8) GetEnvVarOwnedError![]u8 {
    if (builtin.os.tag == .windows) {
        const result_w = blk: {
            const key_w = try std.unicode.utf8ToUtf16LeWithNull(allocator, key);
            defer allocator.free(key_w);

            break :blk std.os.getenvW(key_w) orelse return error.EnvironmentVariableNotFound;
        };
        return std.unicode.utf16leToUtf8Alloc(allocator, result_w) catch |err| switch (err) {
            error.DanglingSurrogateHalf => return error.InvalidUtf8,
            error.ExpectedSecondSurrogateHalf => return error.InvalidUtf8,
            error.UnexpectedSecondSurrogateHalf => return error.InvalidUtf8,
            else => |e| return e,
        };
    } else {
        const result = os.getenv(key) orelse return error.EnvironmentVariableNotFound;
        return allocator.dupe(u8, result);
    }
}

test "os.getEnvVarOwned" {
    var ga = std.testing.allocator;
    testing.expectError(error.EnvironmentVariableNotFound, getEnvVarOwned(ga, "BADENV"));
}

pub const ArgIteratorPosix = struct {
    index: usize,
    count: usize,

    pub fn init() ArgIteratorPosix {
        return ArgIteratorPosix{
            .index = 0,
            .count = os.argv.len,
        };
    }

    pub fn next(self: *ArgIteratorPosix) ?[]const u8 {
        if (self.index == self.count) return null;

        const s = os.argv[self.index];
        self.index += 1;
        return mem.spanZ(s);
    }

    pub fn skip(self: *ArgIteratorPosix) bool {
        if (self.index == self.count) return false;

        self.index += 1;
        return true;
    }
};

pub const ArgIteratorWasi = struct {
    allocator: *mem.Allocator,
    index: usize,
    args: [][]u8,

    pub const InitError = error{OutOfMemory} || os.UnexpectedError;

    /// You must call deinit to free the internal buffer of the
    /// iterator after you are done.
    pub fn init(allocator: *mem.Allocator) InitError!ArgIteratorWasi {
        const fetched_args = try ArgIteratorWasi.internalInit(allocator);
        return ArgIteratorWasi{
            .allocator = allocator,
            .index = 0,
            .args = fetched_args,
        };
    }

    fn internalInit(allocator: *mem.Allocator) InitError![][]u8 {
        const w = os.wasi;
        var count: usize = undefined;
        var buf_size: usize = undefined;

        switch (w.args_sizes_get(&count, &buf_size)) {
            w.ESUCCESS => {},
            else => |err| return os.unexpectedErrno(err),
        }

        var argv = try allocator.alloc([*:0]u8, count);
        defer allocator.free(argv);

        var argv_buf = try allocator.alloc(u8, buf_size);

        switch (w.args_get(argv.ptr, argv_buf.ptr)) {
            w.ESUCCESS => {},
            else => |err| return os.unexpectedErrno(err),
        }

        var result_args = try allocator.alloc([]u8, count);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            result_args[i] = mem.spanZ(argv[i]);
        }

        return result_args;
    }

    pub fn next(self: *ArgIteratorWasi) ?[]const u8 {
        if (self.index == self.args.len) return null;

        const arg = self.args[self.index];
        self.index += 1;
        return arg;
    }

    pub fn skip(self: *ArgIteratorWasi) bool {
        if (self.index == self.args.len) return false;

        self.index += 1;
        return true;
    }

    /// Call to free the internal buffer of the iterator.
    pub fn deinit(self: *ArgIteratorWasi) void {
        const last_item = self.args[self.args.len - 1];
        const last_byte_addr = @ptrToInt(last_item.ptr) + last_item.len + 1; // null terminated
        const first_item_ptr = self.args[0].ptr;
        const len = last_byte_addr - @ptrToInt(first_item_ptr);
        self.allocator.free(first_item_ptr[0..len]);
        self.allocator.free(self.args);
    }
};

pub const ArgIteratorWindows = struct {
    index: usize,
    cmd_line: [*]const u8,

    pub const NextError = error{OutOfMemory};

    pub fn init() ArgIteratorWindows {
        return initWithCmdLine(os.windows.kernel32.GetCommandLineA());
    }

    pub fn initWithCmdLine(cmd_line: [*]const u8) ArgIteratorWindows {
        return ArgIteratorWindows{
            .index = 0,
            .cmd_line = cmd_line,
        };
    }

    /// You must free the returned memory when done.
    pub fn next(self: *ArgIteratorWindows, allocator: *Allocator) ?(NextError![]u8) {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return null,
                ' ', '\t' => continue,
                else => break,
            }
        }

        return self.internalNext(allocator);
    }

    pub fn skip(self: *ArgIteratorWindows) bool {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return false,
                ' ', '\t' => continue,
                else => break,
            }
        }

        var backslash_count: usize = 0;
        var in_quote = false;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return true,
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    if (quote_is_real) {
                        in_quote = !in_quote;
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    if (!in_quote) {
                        return true;
                    }
                    backslash_count = 0;
                },
                else => {
                    backslash_count = 0;
                    continue;
                },
            }
        }
    }

    fn internalNext(self: *ArgIteratorWindows, allocator: *Allocator) NextError![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        var backslash_count: usize = 0;
        var in_quote = false;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return buf.toOwnedSlice(),
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    try self.emitBackslashes(&buf, backslash_count / 2);
                    backslash_count = 0;

                    if (quote_is_real) {
                        in_quote = !in_quote;
                    } else {
                        try buf.append('"');
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    try self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    if (in_quote) {
                        try buf.append(byte);
                    } else {
                        return buf.toOwnedSlice();
                    }
                },
                else => {
                    try self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    try buf.append(byte);
                },
            }
        }
    }

    fn emitBackslashes(self: *ArgIteratorWindows, buf: *std.ArrayList(u8), emit_count: usize) !void {
        var i: usize = 0;
        while (i < emit_count) : (i += 1) {
            try buf.append('\\');
        }
    }
};

pub const ArgIterator = struct {
    const InnerType = switch (builtin.os.tag) {
        .windows => ArgIteratorWindows,
        .wasi => ArgIteratorWasi,
        else => ArgIteratorPosix,
    };

    inner: InnerType,

    /// Initialize the args iterator.
    pub fn init() ArgIterator {
        if (builtin.os.tag == .wasi) {
            @compileError("In WASI, use initWithAllocator instead.");
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    pub const InitError = ArgIteratorWasi.InitError;

    /// You must deinitialize iterator's internal buffers by calling `deinit` when done.
    pub fn initWithAllocator(allocator: *mem.Allocator) InitError!ArgIterator {
        if (builtin.os.tag == .wasi) {
            return ArgIterator{ .inner = try InnerType.init(allocator) };
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    pub const NextError = ArgIteratorWindows.NextError;

    /// You must free the returned memory when done.
    pub fn next(self: *ArgIterator, allocator: *Allocator) ?(NextError![]u8) {
        if (builtin.os.tag == .windows) {
            return self.inner.next(allocator);
        } else {
            return allocator.dupe(u8, self.inner.next() orelse return null);
        }
    }

    /// If you only are targeting posix you can call this and not need an allocator.
    pub fn nextPosix(self: *ArgIterator) ?[]const u8 {
        return self.inner.next();
    }

    /// If you only are targeting WASI, you can call this and not need an allocator.
    pub fn nextWasi(self: *ArgIterator) ?[]const u8 {
        return self.inner.next();
    }

    /// Parse past 1 argument without capturing it.
    /// Returns `true` if skipped an arg, `false` if we are at the end.
    pub fn skip(self: *ArgIterator) bool {
        return self.inner.skip();
    }

    /// Call this to free the iterator's internal buffer if the iterator
    /// was created with `initWithAllocator` function.
    pub fn deinit(self: *ArgIterator) void {
        // Unless we're targeting WASI, this is a no-op.
        if (builtin.os.tag == .wasi) {
            self.inner.deinit();
        }
    }
};

pub fn args() ArgIterator {
    return ArgIterator.init();
}

/// You must deinitialize iterator's internal buffers by calling `deinit` when done.
pub fn argsWithAllocator(allocator: *mem.Allocator) ArgIterator.InitError!ArgIterator {
    return ArgIterator.initWithAllocator(allocator);
}

test "args iterator" {
    var ga = std.testing.allocator;
    var it = if (builtin.os.tag == .wasi) try argsWithAllocator(ga) else args();
    defer it.deinit(); // no-op unless WASI

    const prog_name = try it.next(ga) orelse unreachable;
    defer ga.free(prog_name);

    const expected_suffix = switch (builtin.os.tag) {
        .wasi => "test.wasm",
        .windows => "test.exe",
        else => "test",
    };
    const given_suffix = std.fs.path.basename(prog_name);

    testing.expect(mem.eql(u8, expected_suffix, given_suffix));
    testing.expectEqual(it.next(ga), null);
    testing.expect(!it.skip());
}

/// Caller must call argsFree on result.
pub fn argsAlloc(allocator: *mem.Allocator) ![][]u8 {
    // TODO refactor to only make 1 allocation.
    var it = if (builtin.os.tag == .wasi) try argsWithAllocator(allocator) else args();
    defer it.deinit();

    var contents = std.ArrayList(u8).init(allocator);
    defer contents.deinit();

    var slice_list = std.ArrayList(usize).init(allocator);
    defer slice_list.deinit();

    while (it.next(allocator)) |arg_or_err| {
        const arg = try arg_or_err;
        defer allocator.free(arg);
        try contents.appendSlice(arg);
        try slice_list.append(arg.len);
    }

    const contents_slice = contents.span();
    const slice_sizes = slice_list.span();
    const slice_list_bytes = try math.mul(usize, @sizeOf([]u8), slice_sizes.len);
    const total_bytes = try math.add(usize, slice_list_bytes, contents_slice.len);
    const buf = try allocator.alignedAlloc(u8, @alignOf([]u8), total_bytes);
    errdefer allocator.free(buf);

    const result_slice_list = mem.bytesAsSlice([]u8, buf[0..slice_list_bytes]);
    const result_contents = buf[slice_list_bytes..];
    mem.copy(u8, result_contents, contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index];
        contents_index = new_index;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: *mem.Allocator, args_alloc: []const []u8) void {
    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len;
    }
    const unaligned_allocated_buf = @ptrCast([*]const u8, args_alloc.ptr)[0..total_bytes];
    const aligned_allocated_buf = @alignCast(@alignOf([]u8), unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
}

test "windows arg parsing" {
    testWindowsCmdLine("a   b\tc d", &[_][]const u8{ "a", "b", "c", "d" });
    testWindowsCmdLine("\"abc\" d e", &[_][]const u8{ "abc", "d", "e" });
    testWindowsCmdLine("a\\\\\\b d\"e f\"g h", &[_][]const u8{ "a\\\\\\b", "de fg", "h" });
    testWindowsCmdLine("a\\\\\\\"b c d", &[_][]const u8{ "a\\\"b", "c", "d" });
    testWindowsCmdLine("a\\\\\\\\\"b c\" d e", &[_][]const u8{ "a\\\\b c", "d", "e" });
    testWindowsCmdLine("a   b\tc \"d f", &[_][]const u8{ "a", "b", "c", "d f" });

    testWindowsCmdLine("\".\\..\\zig-cache\\build\" \"bin\\zig.exe\" \".\\..\" \".\\..\\zig-cache\" \"--help\"", &[_][]const u8{
        ".\\..\\zig-cache\\build",
        "bin\\zig.exe",
        ".\\..",
        ".\\..\\zig-cache",
        "--help",
    });
}

fn testWindowsCmdLine(input_cmd_line: [*]const u8, expected_args: []const []const u8) void {
    var it = ArgIteratorWindows.initWithCmdLine(input_cmd_line);
    for (expected_args) |expected_arg| {
        const arg = it.next(std.testing.allocator).? catch unreachable;
        defer std.testing.allocator.free(arg);
        testing.expectEqualSlices(u8, expected_arg, arg);
    }
    testing.expect(it.next(std.testing.allocator) == null);
}

pub const UserInfo = struct {
    uid: u32,
    gid: u32,
};

/// POSIX function which gets a uid from username.
pub fn getUserInfo(name: []const u8) !UserInfo {
    return switch (builtin.os.tag) {
        .linux, .macosx, .watchos, .tvos, .ios, .freebsd, .netbsd => posixGetUserInfo(name),
        else => @compileError("Unsupported OS"),
    };
}

/// TODO this reads /etc/passwd. But sometimes the user/id mapping is in something else
/// like NIS, AD, etc. See `man nss` or look at an strace for `id myuser`.
pub fn posixGetUserInfo(name: []const u8) !UserInfo {
    var reader = try io.Reader.open("/etc/passwd", null);
    defer reader.close();

    const State = enum {
        Start,
        WaitForNextLine,
        SkipPassword,
        ReadUserId,
        ReadGroupId,
    };

    var buf: [std.mem.page_size]u8 = undefined;
    var name_index: usize = 0;
    var state = State.Start;
    var uid: u32 = 0;
    var gid: u32 = 0;

    while (true) {
        const amt_read = try reader.read(buf[0..]);
        for (buf[0..amt_read]) |byte| {
            switch (state) {
                .Start => switch (byte) {
                    ':' => {
                        state = if (name_index == name.len) State.SkipPassword else State.WaitForNextLine;
                    },
                    '\n' => return error.CorruptPasswordFile,
                    else => {
                        if (name_index == name.len or name[name_index] != byte) {
                            state = .WaitForNextLine;
                        }
                        name_index += 1;
                    },
                },
                .WaitForNextLine => switch (byte) {
                    '\n' => {
                        name_index = 0;
                        state = .Start;
                    },
                    else => continue,
                },
                .SkipPassword => switch (byte) {
                    '\n' => return error.CorruptPasswordFile,
                    ':' => {
                        state = .ReadUserId;
                    },
                    else => continue,
                },
                .ReadUserId => switch (byte) {
                    ':' => {
                        state = .ReadGroupId;
                    },
                    '\n' => return error.CorruptPasswordFile,
                    else => {
                        const digit = switch (byte) {
                            '0'...'9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        if (@mulWithOverflow(u32, uid, 10, *uid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, uid, digit, *uid)) return error.CorruptPasswordFile;
                    },
                },
                .ReadGroupId => switch (byte) {
                    '\n', ':' => {
                        return UserInfo{
                            .uid = uid,
                            .gid = gid,
                        };
                    },
                    else => {
                        const digit = switch (byte) {
                            '0'...'9' => byte - '0',
                            else => return error.CorruptPasswordFile,
                        };
                        if (@mulWithOverflow(u32, gid, 10, *gid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, gid, digit, *gid)) return error.CorruptPasswordFile;
                    },
                },
            }
        }
        if (amt_read < buf.len) return error.UserNotFound;
    }
}

pub fn getBaseAddress() usize {
    switch (builtin.os.tag) {
        .linux => {
            const base = os.system.getauxval(std.elf.AT_BASE);
            if (base != 0) {
                return base;
            }
            const phdr = os.system.getauxval(std.elf.AT_PHDR);
            return phdr - @sizeOf(std.elf.Ehdr);
        },
        .macosx, .freebsd, .netbsd => {
            return @ptrToInt(&std.c._mh_execute_header);
        },
        .windows => return @ptrToInt(os.windows.kernel32.GetModuleHandleW(null)),
        else => @compileError("Unsupported OS"),
    }
}

/// Caller owns the result value and each inner slice.
/// TODO Remove the `Allocator` requirement from this API, which will remove the `Allocator`
/// requirement from `std.zig.system.NativeTargetInfo.detect`. Most likely this will require
/// introducing a new, lower-level function which takes a callback function, and then this
/// function which takes an allocator can exist on top of it.
pub fn getSelfExeSharedLibPaths(allocator: *Allocator) error{OutOfMemory}![][:0]u8 {
    switch (builtin.link_mode) {
        .Static => return &[_][:0]u8{},
        .Dynamic => {},
    }
    const List = std.ArrayList([:0]u8);
    switch (builtin.os.tag) {
        .linux,
        .freebsd,
        .netbsd,
        .dragonfly,
        => {
            var paths = List.init(allocator);
            errdefer {
                const slice = paths.toOwnedSlice();
                for (slice) |item| {
                    allocator.free(item);
                }
                allocator.free(slice);
            }
            try os.dl_iterate_phdr(&paths, error{OutOfMemory}, struct {
                fn callback(info: *os.dl_phdr_info, size: usize, list: *List) !void {
                    const name = info.dlpi_name orelse return;
                    if (name[0] == '/') {
                        const item = try list.allocator.dupeZ(u8, mem.spanZ(name));
                        errdefer list.allocator.free(item);
                        try list.append(item);
                    }
                }
            }.callback);
            return paths.toOwnedSlice();
        },
        .macosx, .ios, .watchos, .tvos => {
            var paths = List.init(allocator);
            errdefer {
                const slice = paths.toOwnedSlice();
                for (slice) |item| {
                    allocator.free(item);
                }
                allocator.free(slice);
            }
            const img_count = std.c._dyld_image_count();
            var i: u32 = 0;
            while (i < img_count) : (i += 1) {
                const name = std.c._dyld_get_image_name(i);
                const item = try allocator.dupeZ(u8, mem.spanZ(name));
                errdefer allocator.free(item);
                try paths.append(item);
            }
            return paths.toOwnedSlice();
        },
        else => @compileError("getSelfExeSharedLibPaths unimplemented for this target"),
    }
}
