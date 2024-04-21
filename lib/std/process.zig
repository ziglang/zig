const std = @import("std.zig");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;
const child_process = @import("child_process.zig");
const native_os = builtin.os.tag;
const posix = std.posix;
const windows = std.os.windows;

pub const Child = child_process.ChildProcess;
pub const abort = posix.abort;
pub const exit = posix.exit;
pub const changeCurDir = posix.chdir;
pub const changeCurDirC = posix.chdirC;

pub const GetCwdError = posix.GetCwdError;

/// The result is a slice of `out_buffer`, from index `0`.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
pub fn getCwd(out_buffer: []u8) ![]u8 {
    return posix.getcwd(out_buffer);
}

pub const GetCwdAllocError = Allocator.Error || posix.GetCwdError;

/// Caller must free the returned memory.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
pub fn getCwdAlloc(allocator: Allocator) ![]u8 {
    // The use of MAX_PATH_BYTES here is just a heuristic: most paths will fit
    // in stack_buf, avoiding an extra allocation in the common case.
    var stack_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    var heap_buf: ?[]u8 = null;
    defer if (heap_buf) |buf| allocator.free(buf);

    var current_buf: []u8 = &stack_buf;
    while (true) {
        if (posix.getcwd(current_buf)) |slice| {
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

test getCwdAlloc {
    if (native_os == .wasi) return error.SkipZigTest;

    const cwd = try getCwdAlloc(testing.allocator);
    testing.allocator.free(cwd);
}

pub const EnvMap = struct {
    hash_map: HashMap,

    const HashMap = std.HashMap(
        []const u8,
        []const u8,
        EnvNameHashContext,
        std.hash_map.default_max_load_percentage,
    );

    pub const Size = HashMap.Size;

    pub const EnvNameHashContext = struct {
        fn upcase(c: u21) u21 {
            if (c <= std.math.maxInt(u16))
                return windows.ntdll.RtlUpcaseUnicodeChar(@as(u16, @intCast(c)));
            return c;
        }

        pub fn hash(self: @This(), s: []const u8) u64 {
            _ = self;
            if (native_os == .windows) {
                var h = std.hash.Wyhash.init(0);
                var it = std.unicode.Wtf8View.initUnchecked(s).iterator();
                while (it.nextCodepoint()) |cp| {
                    const cp_upper = upcase(cp);
                    h.update(&[_]u8{
                        @as(u8, @intCast((cp_upper >> 16) & 0xff)),
                        @as(u8, @intCast((cp_upper >> 8) & 0xff)),
                        @as(u8, @intCast((cp_upper >> 0) & 0xff)),
                    });
                }
                return h.final();
            }
            return std.hash_map.hashString(s);
        }

        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            _ = self;
            if (native_os == .windows) {
                var it_a = std.unicode.Wtf8View.initUnchecked(a).iterator();
                var it_b = std.unicode.Wtf8View.initUnchecked(b).iterator();
                while (true) {
                    const c_a = it_a.nextCodepoint() orelse break;
                    const c_b = it_b.nextCodepoint() orelse return false;
                    if (upcase(c_a) != upcase(c_b))
                        return false;
                }
                return if (it_b.nextCodepoint()) |_| false else true;
            }
            return std.hash_map.eqlString(a, b);
        }
    };

    /// Create a EnvMap backed by a specific allocator.
    /// That allocator will be used for both backing allocations
    /// and string deduplication.
    pub fn init(allocator: Allocator) EnvMap {
        return EnvMap{ .hash_map = HashMap.init(allocator) };
    }

    /// Free the backing storage of the map, as well as all
    /// of the stored keys and values.
    pub fn deinit(self: *EnvMap) void {
        var it = self.hash_map.iterator();
        while (it.next()) |entry| {
            self.free(entry.key_ptr.*);
            self.free(entry.value_ptr.*);
        }

        self.hash_map.deinit();
    }

    /// Same as `put` but the key and value become owned by the EnvMap rather
    /// than being copied.
    /// If `putMove` fails, the ownership of key and value does not transfer.
    /// On Windows `key` must be a valid [WTF-8](https://simonsapin.github.io/wtf-8/) string.
    pub fn putMove(self: *EnvMap, key: []u8, value: []u8) !void {
        assert(std.unicode.wtf8ValidateSlice(key));
        const get_or_put = try self.hash_map.getOrPut(key);
        if (get_or_put.found_existing) {
            self.free(get_or_put.key_ptr.*);
            self.free(get_or_put.value_ptr.*);
            get_or_put.key_ptr.* = key;
        }
        get_or_put.value_ptr.* = value;
    }

    /// `key` and `value` are copied into the EnvMap.
    /// On Windows `key` must be a valid [WTF-8](https://simonsapin.github.io/wtf-8/) string.
    pub fn put(self: *EnvMap, key: []const u8, value: []const u8) !void {
        assert(std.unicode.wtf8ValidateSlice(key));
        const value_copy = try self.copy(value);
        errdefer self.free(value_copy);
        const get_or_put = try self.hash_map.getOrPut(key);
        if (get_or_put.found_existing) {
            self.free(get_or_put.value_ptr.*);
        } else {
            get_or_put.key_ptr.* = self.copy(key) catch |err| {
                _ = self.hash_map.remove(key);
                return err;
            };
        }
        get_or_put.value_ptr.* = value_copy;
    }

    /// Find the address of the value associated with a key.
    /// The returned pointer is invalidated if the map resizes.
    /// On Windows `key` must be a valid [WTF-8](https://simonsapin.github.io/wtf-8/) string.
    pub fn getPtr(self: EnvMap, key: []const u8) ?*[]const u8 {
        assert(std.unicode.wtf8ValidateSlice(key));
        return self.hash_map.getPtr(key);
    }

    /// Return the map's copy of the value associated with
    /// a key.  The returned string is invalidated if this
    /// key is removed from the map.
    /// On Windows `key` must be a valid [WTF-8](https://simonsapin.github.io/wtf-8/) string.
    pub fn get(self: EnvMap, key: []const u8) ?[]const u8 {
        assert(std.unicode.wtf8ValidateSlice(key));
        return self.hash_map.get(key);
    }

    /// Removes the item from the map and frees its value.
    /// This invalidates the value returned by get() for this key.
    /// On Windows `key` must be a valid [WTF-8](https://simonsapin.github.io/wtf-8/) string.
    pub fn remove(self: *EnvMap, key: []const u8) void {
        assert(std.unicode.wtf8ValidateSlice(key));
        const kv = self.hash_map.fetchRemove(key) orelse return;
        self.free(kv.key);
        self.free(kv.value);
    }

    /// Returns the number of KV pairs stored in the map.
    pub fn count(self: EnvMap) HashMap.Size {
        return self.hash_map.count();
    }

    /// Returns an iterator over entries in the map.
    pub fn iterator(self: *const EnvMap) HashMap.Iterator {
        return self.hash_map.iterator();
    }

    fn free(self: EnvMap, value: []const u8) void {
        self.hash_map.allocator.free(value);
    }

    fn copy(self: EnvMap, value: []const u8) ![]u8 {
        return self.hash_map.allocator.dupe(u8, value);
    }
};

test EnvMap {
    var env = EnvMap.init(testing.allocator);
    defer env.deinit();

    try env.put("SOMETHING_NEW", "hello");
    try testing.expectEqualStrings("hello", env.get("SOMETHING_NEW").?);
    try testing.expectEqual(@as(EnvMap.Size, 1), env.count());

    // overwrite
    try env.put("SOMETHING_NEW", "something");
    try testing.expectEqualStrings("something", env.get("SOMETHING_NEW").?);
    try testing.expectEqual(@as(EnvMap.Size, 1), env.count());

    // a new longer name to test the Windows-specific conversion buffer
    try env.put("SOMETHING_NEW_AND_LONGER", "1");
    try testing.expectEqualStrings("1", env.get("SOMETHING_NEW_AND_LONGER").?);
    try testing.expectEqual(@as(EnvMap.Size, 2), env.count());

    // case insensitivity on Windows only
    if (native_os == .windows) {
        try testing.expectEqualStrings("1", env.get("something_New_aNd_LONGER").?);
    } else {
        try testing.expect(null == env.get("something_New_aNd_LONGER"));
    }

    var it = env.iterator();
    var count: EnvMap.Size = 0;
    while (it.next()) |entry| {
        const is_an_expected_name = std.mem.eql(u8, "SOMETHING_NEW", entry.key_ptr.*) or std.mem.eql(u8, "SOMETHING_NEW_AND_LONGER", entry.key_ptr.*);
        try testing.expect(is_an_expected_name);
        count += 1;
    }
    try testing.expectEqual(@as(EnvMap.Size, 2), count);

    env.remove("SOMETHING_NEW");
    try testing.expect(env.get("SOMETHING_NEW") == null);

    try testing.expectEqual(@as(EnvMap.Size, 1), env.count());

    if (native_os == .windows) {
        // test Unicode case-insensitivity on Windows
        try env.put("КИРиллИЦА", "something else");
        try testing.expectEqualStrings("something else", env.get("кириллица").?);

        // and WTF-8 that's not valid UTF-8
        const wtf8_with_surrogate_pair = try std.unicode.wtf16LeToWtf8Alloc(testing.allocator, &[_]u16{
            std.mem.nativeToLittle(u16, 0xD83D), // unpaired high surrogate
        });
        defer testing.allocator.free(wtf8_with_surrogate_pair);

        try env.put(wtf8_with_surrogate_pair, wtf8_with_surrogate_pair);
        try testing.expectEqualSlices(u8, wtf8_with_surrogate_pair, env.get(wtf8_with_surrogate_pair).?);
    }
}

pub const GetEnvMapError = error{
    OutOfMemory,
    /// WASI-only. `environ_sizes_get` or `environ_get`
    /// failed for an unexpected reason.
    Unexpected,
};

/// Returns a snapshot of the environment variables of the current process.
/// Any modifications to the resulting EnvMap will not be reflected in the environment, and
/// likewise, any future modifications to the environment will not be reflected in the EnvMap.
/// Caller owns resulting `EnvMap` and should call its `deinit` fn when done.
pub fn getEnvMap(allocator: Allocator) GetEnvMapError!EnvMap {
    var result = EnvMap.init(allocator);
    errdefer result.deinit();

    if (native_os == .windows) {
        const ptr = windows.peb().ProcessParameters.Environment;

        var i: usize = 0;
        while (ptr[i] != 0) {
            const key_start = i;

            // There are some special environment variables that start with =,
            // so we need a special case to not treat = as a key/value separator
            // if it's the first character.
            // https://devblogs.microsoft.com/oldnewthing/20100506-00/?p=14133
            if (ptr[key_start] == '=') i += 1;

            while (ptr[i] != 0 and ptr[i] != '=') : (i += 1) {}
            const key_w = ptr[key_start..i];
            const key = try std.unicode.wtf16LeToWtf8Alloc(allocator, key_w);
            errdefer allocator.free(key);

            if (ptr[i] == '=') i += 1;

            const value_start = i;
            while (ptr[i] != 0) : (i += 1) {}
            const value_w = ptr[value_start..i];
            const value = try std.unicode.wtf16LeToWtf8Alloc(allocator, value_w);
            errdefer allocator.free(value);

            i += 1; // skip over null byte

            try result.putMove(key, value);
        }
        return result;
    } else if (native_os == .wasi and !builtin.link_libc) {
        var environ_count: usize = undefined;
        var environ_buf_size: usize = undefined;

        const environ_sizes_get_ret = std.os.wasi.environ_sizes_get(&environ_count, &environ_buf_size);
        if (environ_sizes_get_ret != .SUCCESS) {
            return posix.unexpectedErrno(environ_sizes_get_ret);
        }

        if (environ_count == 0) {
            return result;
        }

        const environ = try allocator.alloc([*:0]u8, environ_count);
        defer allocator.free(environ);
        const environ_buf = try allocator.alloc(u8, environ_buf_size);
        defer allocator.free(environ_buf);

        const environ_get_ret = std.os.wasi.environ_get(environ.ptr, environ_buf.ptr);
        if (environ_get_ret != .SUCCESS) {
            return posix.unexpectedErrno(environ_get_ret);
        }

        for (environ) |env| {
            const pair = mem.sliceTo(env, 0);
            var parts = mem.splitScalar(u8, pair, '=');
            const key = parts.first();
            const value = parts.rest();
            try result.put(key, value);
        }
        return result;
    } else if (builtin.link_libc) {
        var ptr = std.c.environ;
        while (ptr[0]) |line| : (ptr += 1) {
            var line_i: usize = 0;
            while (line[line_i] != 0 and line[line_i] != '=') : (line_i += 1) {}
            const key = line[0..line_i];

            var end_i: usize = line_i;
            while (line[end_i] != 0) : (end_i += 1) {}
            const value = line[line_i + 1 .. end_i];

            try result.put(key, value);
        }
        return result;
    } else {
        for (std.os.environ) |line| {
            var line_i: usize = 0;
            while (line[line_i] != 0 and line[line_i] != '=') : (line_i += 1) {}
            const key = line[0..line_i];

            var end_i: usize = line_i;
            while (line[end_i] != 0) : (end_i += 1) {}
            const value = line[line_i + 1 .. end_i];

            try result.put(key, value);
        }
        return result;
    }
}

test getEnvMap {
    var env = try getEnvMap(testing.allocator);
    defer env.deinit();
}

pub const GetEnvVarOwnedError = error{
    OutOfMemory,
    EnvironmentVariableNotFound,

    /// On Windows, environment variable keys provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
};

/// Caller must free returned memory.
/// On Windows, if `key` is not valid [WTF-8](https://simonsapin.github.io/wtf-8/),
/// then `error.InvalidWtf8` is returned.
/// On Windows, the value is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, the value is an opaque sequence of bytes with no particular encoding.
pub fn getEnvVarOwned(allocator: Allocator, key: []const u8) GetEnvVarOwnedError![]u8 {
    if (native_os == .windows) {
        const result_w = blk: {
            var stack_alloc = std.heap.stackFallback(256 * @sizeOf(u16), allocator);
            const stack_allocator = stack_alloc.get();
            const key_w = try std.unicode.wtf8ToWtf16LeAllocZ(stack_allocator, key);
            defer stack_allocator.free(key_w);

            break :blk getenvW(key_w) orelse return error.EnvironmentVariableNotFound;
        };
        // wtf16LeToWtf8Alloc can only fail with OutOfMemory
        return std.unicode.wtf16LeToWtf8Alloc(allocator, result_w);
    } else if (native_os == .wasi and !builtin.link_libc) {
        var envmap = getEnvMap(allocator) catch return error.OutOfMemory;
        defer envmap.deinit();
        const val = envmap.get(key) orelse return error.EnvironmentVariableNotFound;
        return allocator.dupe(u8, val);
    } else {
        const result = posix.getenv(key) orelse return error.EnvironmentVariableNotFound;
        return allocator.dupe(u8, result);
    }
}

/// On Windows, `key` must be valid UTF-8.
pub fn hasEnvVarConstant(comptime key: []const u8) bool {
    if (native_os == .windows) {
        const key_w = comptime std.unicode.utf8ToUtf16LeStringLiteral(key);
        return getenvW(key_w) != null;
    } else if (native_os == .wasi and !builtin.link_libc) {
        @compileError("hasEnvVarConstant is not supported for WASI without libc");
    } else {
        return posix.getenv(key) != null;
    }
}

pub const HasEnvVarError = error{
    OutOfMemory,

    /// On Windows, environment variable keys provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
};

/// On Windows, if `key` is not valid [WTF-8](https://simonsapin.github.io/wtf-8/),
/// then `error.InvalidWtf8` is returned.
pub fn hasEnvVar(allocator: Allocator, key: []const u8) HasEnvVarError!bool {
    if (native_os == .windows) {
        var stack_alloc = std.heap.stackFallback(256 * @sizeOf(u16), allocator);
        const stack_allocator = stack_alloc.get();
        const key_w = try std.unicode.wtf8ToWtf16LeAllocZ(stack_allocator, key);
        defer stack_allocator.free(key_w);
        return getenvW(key_w) != null;
    } else if (native_os == .wasi and !builtin.link_libc) {
        var envmap = getEnvMap(allocator) catch return error.OutOfMemory;
        defer envmap.deinit();
        return envmap.getPtr(key) != null;
    } else {
        return posix.getenv(key) != null;
    }
}

/// Windows-only. Get an environment variable with a null-terminated, WTF-16 encoded name.
///
/// This function performs a Unicode-aware case-insensitive lookup using RtlEqualUnicodeString.
///
/// See also:
/// * `std.posix.getenv`
/// * `getEnvMap`
/// * `getEnvVarOwned`
/// * `hasEnvVarConstant`
/// * `hasEnvVar`
pub fn getenvW(key: [*:0]const u16) ?[:0]const u16 {
    if (native_os != .windows) {
        @compileError("Windows-only");
    }
    const key_slice = mem.sliceTo(key, 0);
    const ptr = windows.peb().ProcessParameters.Environment;
    var i: usize = 0;
    while (ptr[i] != 0) {
        const key_start = i;

        // There are some special environment variables that start with =,
        // so we need a special case to not treat = as a key/value separator
        // if it's the first character.
        // https://devblogs.microsoft.com/oldnewthing/20100506-00/?p=14133
        if (ptr[key_start] == '=') i += 1;

        while (ptr[i] != 0 and ptr[i] != '=') : (i += 1) {}
        const this_key = ptr[key_start..i];

        if (ptr[i] == '=') i += 1;

        const value_start = i;
        while (ptr[i] != 0) : (i += 1) {}
        const this_value = ptr[value_start..i :0];

        if (windows.eqlIgnoreCaseWTF16(key_slice, this_key)) {
            return this_value;
        }

        i += 1; // skip over null byte
    }
    return null;
}

test getEnvVarOwned {
    try testing.expectError(
        error.EnvironmentVariableNotFound,
        getEnvVarOwned(std.testing.allocator, "BADENV"),
    );
}

test hasEnvVarConstant {
    if (native_os == .wasi and !builtin.link_libc) return error.SkipZigTest;

    try testing.expect(!hasEnvVarConstant("BADENV"));
}

test hasEnvVar {
    const has_env = try hasEnvVar(std.testing.allocator, "BADENV");
    try testing.expect(!has_env);
}

pub const ArgIteratorPosix = struct {
    index: usize,
    count: usize,

    pub const InitError = error{};

    pub fn init() ArgIteratorPosix {
        return ArgIteratorPosix{
            .index = 0,
            .count = std.os.argv.len,
        };
    }

    pub fn next(self: *ArgIteratorPosix) ?[:0]const u8 {
        if (self.index == self.count) return null;

        const s = std.os.argv[self.index];
        self.index += 1;
        return mem.sliceTo(s, 0);
    }

    pub fn skip(self: *ArgIteratorPosix) bool {
        if (self.index == self.count) return false;

        self.index += 1;
        return true;
    }
};

pub const ArgIteratorWasi = struct {
    allocator: Allocator,
    index: usize,
    args: [][:0]u8,

    pub const InitError = error{OutOfMemory} || posix.UnexpectedError;

    /// You must call deinit to free the internal buffer of the
    /// iterator after you are done.
    pub fn init(allocator: Allocator) InitError!ArgIteratorWasi {
        const fetched_args = try ArgIteratorWasi.internalInit(allocator);
        return ArgIteratorWasi{
            .allocator = allocator,
            .index = 0,
            .args = fetched_args,
        };
    }

    fn internalInit(allocator: Allocator) InitError![][:0]u8 {
        var count: usize = undefined;
        var buf_size: usize = undefined;

        switch (std.os.wasi.args_sizes_get(&count, &buf_size)) {
            .SUCCESS => {},
            else => |err| return posix.unexpectedErrno(err),
        }

        if (count == 0) {
            return &[_][:0]u8{};
        }

        const argv = try allocator.alloc([*:0]u8, count);
        defer allocator.free(argv);

        const argv_buf = try allocator.alloc(u8, buf_size);

        switch (std.os.wasi.args_get(argv.ptr, argv_buf.ptr)) {
            .SUCCESS => {},
            else => |err| return posix.unexpectedErrno(err),
        }

        var result_args = try allocator.alloc([:0]u8, count);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            result_args[i] = mem.sliceTo(argv[i], 0);
        }

        return result_args;
    }

    pub fn next(self: *ArgIteratorWasi) ?[:0]const u8 {
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
        const last_byte_addr = @intFromPtr(last_item.ptr) + last_item.len + 1; // null terminated
        const first_item_ptr = self.args[0].ptr;
        const len = last_byte_addr - @intFromPtr(first_item_ptr);
        self.allocator.free(first_item_ptr[0..len]);
        self.allocator.free(self.args);
    }
};

/// Iterator that implements the Windows command-line parsing algorithm.
/// The implementation is intended to be compatible with the post-2008 C runtime,
/// but is *not* intended to be compatible with `CommandLineToArgvW` since
/// `CommandLineToArgvW` uses the pre-2008 parsing rules.
///
/// This iterator faithfully implements the parsing behavior observed from the C runtime with
/// one exception: if the command-line string is empty, the iterator will immediately complete
/// without returning any arguments (whereas the C runtime will return a single argument
/// representing the name of the current executable).
///
/// The essential parts of the algorithm are described in Microsoft's documentation:
///
/// - https://learn.microsoft.com/en-us/cpp/cpp/main-function-command-line-args?view=msvc-170#parsing-c-command-line-arguments
///
/// David Deley explains some additional undocumented quirks in great detail:
///
/// - https://daviddeley.com/autohotkey/parameters/parameters.htm#WINCRULES
pub const ArgIteratorWindows = struct {
    allocator: Allocator,
    /// Owned by the iterator.
    /// Encoded as WTF-8.
    cmd_line: []const u8,
    index: usize = 0,
    /// Owned by the iterator. Long enough to hold the entire `cmd_line` plus a null terminator.
    buffer: []u8,
    start: usize = 0,
    end: usize = 0,

    pub const InitError = error{OutOfMemory};

    /// `cmd_line_w` *must* be a WTF16-LE-encoded string.
    ///
    /// The iterator makes a copy of `cmd_line_w` converted WTF-8 and keeps it; it does *not* take
    /// ownership of `cmd_line_w`.
    pub fn init(allocator: Allocator, cmd_line_w: [*:0]const u16) InitError!ArgIteratorWindows {
        const cmd_line = try std.unicode.wtf16LeToWtf8Alloc(allocator, mem.sliceTo(cmd_line_w, 0));
        errdefer allocator.free(cmd_line);

        const buffer = try allocator.alloc(u8, cmd_line.len + 1);
        errdefer allocator.free(buffer);

        return .{
            .allocator = allocator,
            .cmd_line = cmd_line,
            .buffer = buffer,
        };
    }

    /// Returns the next argument and advances the iterator. Returns `null` if at the end of the
    /// command-line string. The iterator owns the returned slice.
    /// The result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
    pub fn next(self: *ArgIteratorWindows) ?[:0]const u8 {
        return self.nextWithStrategy(next_strategy);
    }

    /// Skips the next argument and advances the iterator. Returns `true` if an argument was
    /// skipped, `false` if at the end of the command-line string.
    pub fn skip(self: *ArgIteratorWindows) bool {
        return self.nextWithStrategy(skip_strategy);
    }

    const next_strategy = struct {
        const T = ?[:0]const u8;

        const eof = null;

        fn emitBackslashes(self: *ArgIteratorWindows, count: usize) void {
            for (0..count) |_| emitCharacter(self, '\\');
        }

        fn emitCharacter(self: *ArgIteratorWindows, char: u8) void {
            self.buffer[self.end] = char;
            self.end += 1;

            // Because we are emitting WTF-8 byte-by-byte, we need to
            // check to see if we've emitted two consecutive surrogate
            // codepoints that form a valid surrogate pair in order
            // to ensure that we're always emitting well-formed WTF-8
            // (https://simonsapin.github.io/wtf-8/#concatenating).
            //
            // If we do have a valid surrogate pair, we need to emit
            // the UTF-8 sequence for the codepoint that they encode
            // instead of the WTF-8 encoding for the two surrogate pairs
            // separately.
            //
            // This is relevant when dealing with a WTF-16 encoded
            // command line like this:
            // "<0xD801>"<0xDC37>
            // which would get converted to WTF-8 in `cmd_line` as:
            // "<0xED><0xA0><0x81>"<0xED><0xB0><0xB7>
            // and then after parsing it'd naively get emitted as:
            // <0xED><0xA0><0x81><0xED><0xB0><0xB7>
            // but instead, we need to recognize the surrogate pair
            // and emit the codepoint it encodes, which in this
            // example is U+10437 (𐐷), which is encoded in UTF-8 as:
            // <0xF0><0x90><0x90><0xB7>
            concatSurrogatePair(self);
        }

        fn concatSurrogatePair(self: *ArgIteratorWindows) void {
            // Surrogate codepoints are always encoded as 3 bytes, so there
            // must be 6 bytes for a surrogate pair to exist.
            if (self.end - self.start >= 6) {
                const window = self.buffer[self.end - 6 .. self.end];
                const view = std.unicode.Wtf8View.init(window) catch return;
                var it = view.iterator();
                var pair: [2]u16 = undefined;
                pair[0] = std.mem.nativeToLittle(u16, std.math.cast(u16, it.nextCodepoint().?) orelse return);
                if (!std.unicode.utf16IsHighSurrogate(std.mem.littleToNative(u16, pair[0]))) return;
                pair[1] = std.mem.nativeToLittle(u16, std.math.cast(u16, it.nextCodepoint().?) orelse return);
                if (!std.unicode.utf16IsLowSurrogate(std.mem.littleToNative(u16, pair[1]))) return;
                // We know we have a valid surrogate pair, so convert
                // it to UTF-8, overwriting the surrogate pair's bytes
                // and then chop off the extra bytes.
                const len = std.unicode.utf16LeToUtf8(window, &pair) catch unreachable;
                const delta = 6 - len;
                self.end -= delta;
            }
        }

        fn yieldArg(self: *ArgIteratorWindows) [:0]const u8 {
            self.buffer[self.end] = 0;
            const arg = self.buffer[self.start..self.end :0];
            self.end += 1;
            self.start = self.end;
            return arg;
        }
    };

    const skip_strategy = struct {
        const T = bool;

        const eof = false;

        fn emitBackslashes(_: *ArgIteratorWindows, _: usize) void {}

        fn emitCharacter(_: *ArgIteratorWindows, _: u8) void {}

        fn yieldArg(_: *ArgIteratorWindows) bool {
            return true;
        }
    };

    fn nextWithStrategy(self: *ArgIteratorWindows, comptime strategy: type) strategy.T {
        // The first argument (the executable name) uses different parsing rules.
        if (self.index == 0) {
            if (self.cmd_line.len == 0 or self.cmd_line[0] == 0) {
                // Immediately complete the iterator.
                // The C runtime would return the name of the current executable here.
                return strategy.eof;
            }

            var inside_quotes = false;
            while (true) : (self.index += 1) {
                const char = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
                switch (char) {
                    0 => {
                        return strategy.yieldArg(self);
                    },
                    '"' => {
                        inside_quotes = !inside_quotes;
                    },
                    ' ', '\t' => {
                        if (inside_quotes)
                            strategy.emitCharacter(self, char)
                        else {
                            self.index += 1;
                            return strategy.yieldArg(self);
                        }
                    },
                    else => {
                        strategy.emitCharacter(self, char);
                    },
                }
            }
        }

        // Skip spaces and tabs. The iterator completes if we reach the end of the string here.
        while (true) : (self.index += 1) {
            const char = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
            switch (char) {
                0 => return strategy.eof,
                ' ', '\t' => continue,
                else => break,
            }
        }

        // Parsing rules for subsequent arguments:
        //
        // - The end of the string always terminates the current argument.
        // - When not in 'inside_quotes' mode, a space or tab terminates the current argument.
        // - 2n backslashes followed by a quote emit n backslashes (note: n can be zero).
        //   If in 'inside_quotes' and the quote is immediately followed by a second quote,
        //   one quote is emitted and the other is skipped, otherwise, the quote is skipped
        //   and 'inside_quotes' is toggled.
        // - 2n + 1 backslashes followed by a quote emit n backslashes followed by a quote.
        // - n backslashes not followed by a quote emit n backslashes.
        var backslash_count: usize = 0;
        var inside_quotes = false;
        while (true) : (self.index += 1) {
            const char = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
            switch (char) {
                0 => {
                    strategy.emitBackslashes(self, backslash_count);
                    return strategy.yieldArg(self);
                },
                ' ', '\t' => {
                    strategy.emitBackslashes(self, backslash_count);
                    backslash_count = 0;
                    if (inside_quotes)
                        strategy.emitCharacter(self, char)
                    else
                        return strategy.yieldArg(self);
                },
                '"' => {
                    const char_is_escaped_quote = backslash_count % 2 != 0;
                    strategy.emitBackslashes(self, backslash_count / 2);
                    backslash_count = 0;
                    if (char_is_escaped_quote) {
                        strategy.emitCharacter(self, '"');
                    } else {
                        if (inside_quotes and
                            self.index + 1 != self.cmd_line.len and
                            self.cmd_line[self.index + 1] == '"')
                        {
                            strategy.emitCharacter(self, '"');
                            self.index += 1;
                        } else {
                            inside_quotes = !inside_quotes;
                        }
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                else => {
                    strategy.emitBackslashes(self, backslash_count);
                    backslash_count = 0;
                    strategy.emitCharacter(self, char);
                },
            }
        }
    }

    /// Frees the iterator's copy of the command-line string and all previously returned
    /// argument slices.
    pub fn deinit(self: *ArgIteratorWindows) void {
        self.allocator.free(self.buffer);
        self.allocator.free(self.cmd_line);
    }
};

/// Optional parameters for `ArgIteratorGeneral`
pub const ArgIteratorGeneralOptions = struct {
    comments: bool = false,
    single_quotes: bool = false,
};

/// A general Iterator to parse a string into a set of arguments
pub fn ArgIteratorGeneral(comptime options: ArgIteratorGeneralOptions) type {
    return struct {
        allocator: Allocator,
        index: usize = 0,
        cmd_line: []const u8,

        /// Should the cmd_line field be free'd (using the allocator) on deinit()?
        free_cmd_line_on_deinit: bool,

        /// buffer MUST be long enough to hold the cmd_line plus a null terminator.
        /// buffer will we free'd (using the allocator) on deinit()
        buffer: []u8,
        start: usize = 0,
        end: usize = 0,

        pub const Self = @This();

        pub const InitError = error{OutOfMemory};

        /// cmd_line_utf8 MUST remain valid and constant while using this instance
        pub fn init(allocator: Allocator, cmd_line_utf8: []const u8) InitError!Self {
            const buffer = try allocator.alloc(u8, cmd_line_utf8.len + 1);
            errdefer allocator.free(buffer);

            return Self{
                .allocator = allocator,
                .cmd_line = cmd_line_utf8,
                .free_cmd_line_on_deinit = false,
                .buffer = buffer,
            };
        }

        /// cmd_line_utf8 will be free'd (with the allocator) on deinit()
        pub fn initTakeOwnership(allocator: Allocator, cmd_line_utf8: []const u8) InitError!Self {
            const buffer = try allocator.alloc(u8, cmd_line_utf8.len + 1);
            errdefer allocator.free(buffer);

            return Self{
                .allocator = allocator,
                .cmd_line = cmd_line_utf8,
                .free_cmd_line_on_deinit = true,
                .buffer = buffer,
            };
        }

        // Skips over whitespace in the cmd_line.
        // Returns false if the terminating sentinel is reached, true otherwise.
        // Also skips over comments (if supported).
        fn skipWhitespace(self: *Self) bool {
            while (true) : (self.index += 1) {
                const character = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
                switch (character) {
                    0 => return false,
                    ' ', '\t', '\r', '\n' => continue,
                    '#' => {
                        if (options.comments) {
                            while (true) : (self.index += 1) {
                                switch (self.cmd_line[self.index]) {
                                    '\n' => break,
                                    0 => return false,
                                    else => continue,
                                }
                            }
                            continue;
                        } else {
                            break;
                        }
                    },
                    else => break,
                }
            }
            return true;
        }

        pub fn skip(self: *Self) bool {
            if (!self.skipWhitespace()) {
                return false;
            }

            var backslash_count: usize = 0;
            var in_quote = false;
            while (true) : (self.index += 1) {
                const character = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
                switch (character) {
                    0 => return true,
                    '"', '\'' => {
                        if (!options.single_quotes and character == '\'') {
                            backslash_count = 0;
                            continue;
                        }
                        const quote_is_real = backslash_count % 2 == 0;
                        if (quote_is_real) {
                            in_quote = !in_quote;
                        }
                    },
                    '\\' => {
                        backslash_count += 1;
                    },
                    ' ', '\t', '\r', '\n' => {
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

        /// Returns a slice of the internal buffer that contains the next argument.
        /// Returns null when it reaches the end.
        pub fn next(self: *Self) ?[:0]const u8 {
            if (!self.skipWhitespace()) {
                return null;
            }

            var backslash_count: usize = 0;
            var in_quote = false;
            while (true) : (self.index += 1) {
                const character = if (self.index != self.cmd_line.len) self.cmd_line[self.index] else 0;
                switch (character) {
                    0 => {
                        self.emitBackslashes(backslash_count);
                        self.buffer[self.end] = 0;
                        const token = self.buffer[self.start..self.end :0];
                        self.end += 1;
                        self.start = self.end;
                        return token;
                    },
                    '"', '\'' => {
                        if (!options.single_quotes and character == '\'') {
                            self.emitBackslashes(backslash_count);
                            backslash_count = 0;
                            self.emitCharacter(character);
                            continue;
                        }
                        const quote_is_real = backslash_count % 2 == 0;
                        self.emitBackslashes(backslash_count / 2);
                        backslash_count = 0;

                        if (quote_is_real) {
                            in_quote = !in_quote;
                        } else {
                            self.emitCharacter('"');
                        }
                    },
                    '\\' => {
                        backslash_count += 1;
                    },
                    ' ', '\t', '\r', '\n' => {
                        self.emitBackslashes(backslash_count);
                        backslash_count = 0;
                        if (in_quote) {
                            self.emitCharacter(character);
                        } else {
                            self.buffer[self.end] = 0;
                            const token = self.buffer[self.start..self.end :0];
                            self.end += 1;
                            self.start = self.end;
                            return token;
                        }
                    },
                    else => {
                        self.emitBackslashes(backslash_count);
                        backslash_count = 0;
                        self.emitCharacter(character);
                    },
                }
            }
        }

        fn emitBackslashes(self: *Self, emit_count: usize) void {
            var i: usize = 0;
            while (i < emit_count) : (i += 1) {
                self.emitCharacter('\\');
            }
        }

        fn emitCharacter(self: *Self, char: u8) void {
            self.buffer[self.end] = char;
            self.end += 1;
        }

        /// Call to free the internal buffer of the iterator.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buffer);

            if (self.free_cmd_line_on_deinit) {
                self.allocator.free(self.cmd_line);
            }
        }
    };
}

/// Cross-platform command line argument iterator.
pub const ArgIterator = struct {
    const InnerType = switch (native_os) {
        .windows => ArgIteratorWindows,
        .wasi => if (builtin.link_libc) ArgIteratorPosix else ArgIteratorWasi,
        else => ArgIteratorPosix,
    };

    inner: InnerType,

    /// Initialize the args iterator. Consider using initWithAllocator() instead
    /// for cross-platform compatibility.
    pub fn init() ArgIterator {
        if (native_os == .wasi) {
            @compileError("In WASI, use initWithAllocator instead.");
        }
        if (native_os == .windows) {
            @compileError("In Windows, use initWithAllocator instead.");
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    pub const InitError = InnerType.InitError;

    /// You must deinitialize iterator's internal buffers by calling `deinit` when done.
    pub fn initWithAllocator(allocator: Allocator) InitError!ArgIterator {
        if (native_os == .wasi and !builtin.link_libc) {
            return ArgIterator{ .inner = try InnerType.init(allocator) };
        }
        if (native_os == .windows) {
            const cmd_line_w = windows.kernel32.GetCommandLineW();
            return ArgIterator{ .inner = try InnerType.init(allocator, cmd_line_w) };
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    /// Get the next argument. Returns 'null' if we are at the end.
    /// Returned slice is pointing to the iterator's internal buffer.
    /// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
    /// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
    pub fn next(self: *ArgIterator) ?([:0]const u8) {
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
        // Unless we're targeting WASI or Windows, this is a no-op.
        if (native_os == .wasi and !builtin.link_libc) {
            self.inner.deinit();
        }

        if (native_os == .windows) {
            self.inner.deinit();
        }
    }
};

/// Holds the command-line arguments, with the program name as the first entry.
/// Use argsWithAllocator() for cross-platform code.
pub fn args() ArgIterator {
    return ArgIterator.init();
}

/// You must deinitialize iterator's internal buffers by calling `deinit` when done.
pub fn argsWithAllocator(allocator: Allocator) ArgIterator.InitError!ArgIterator {
    return ArgIterator.initWithAllocator(allocator);
}

/// Caller must call argsFree on result.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
pub fn argsAlloc(allocator: Allocator) ![][:0]u8 {
    // TODO refactor to only make 1 allocation.
    var it = try argsWithAllocator(allocator);
    defer it.deinit();

    var contents = std.ArrayList(u8).init(allocator);
    defer contents.deinit();

    var slice_list = std.ArrayList(usize).init(allocator);
    defer slice_list.deinit();

    while (it.next()) |arg| {
        try contents.appendSlice(arg[0 .. arg.len + 1]);
        try slice_list.append(arg.len);
    }

    const contents_slice = contents.items;
    const slice_sizes = slice_list.items;
    const slice_list_bytes = try math.mul(usize, @sizeOf([]u8), slice_sizes.len);
    const total_bytes = try math.add(usize, slice_list_bytes, contents_slice.len);
    const buf = try allocator.alignedAlloc(u8, @alignOf([]u8), total_bytes);
    errdefer allocator.free(buf);

    const result_slice_list = mem.bytesAsSlice([:0]u8, buf[0..slice_list_bytes]);
    const result_contents = buf[slice_list_bytes..];
    @memcpy(result_contents[0..contents_slice.len], contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes, 0..) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index :0];
        contents_index = new_index + 1;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: Allocator, args_alloc: []const [:0]u8) void {
    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len + 1;
    }
    const unaligned_allocated_buf = @as([*]const u8, @ptrCast(args_alloc.ptr))[0..total_bytes];
    const aligned_allocated_buf: []align(@alignOf([]u8)) const u8 = @alignCast(unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
}

test ArgIteratorWindows {
    const t = testArgIteratorWindows;

    try t(
        \\"C:\Program Files\zig\zig.exe" run .\src\main.zig -target x86_64-windows-gnu -O ReleaseSafe -- --emoji=🗿 --eval="new Regex(\"Dwayne \\\"The Rock\\\" Johnson\")"
    , &.{
        \\C:\Program Files\zig\zig.exe
        ,
        \\run
        ,
        \\.\src\main.zig
        ,
        \\-target
        ,
        \\x86_64-windows-gnu
        ,
        \\-O
        ,
        \\ReleaseSafe
        ,
        \\--
        ,
        \\--emoji=🗿
        ,
        \\--eval=new Regex("Dwayne \"The Rock\" Johnson")
        ,
    });

    // Empty
    try t("", &.{});

    // Separators
    try t("aa bb cc", &.{ "aa", "bb", "cc" });
    try t("aa\tbb\tcc", &.{ "aa", "bb", "cc" });
    try t("aa\nbb\ncc", &.{"aa\nbb\ncc"});
    try t("aa\r\nbb\r\ncc", &.{"aa\r\nbb\r\ncc"});
    try t("aa\rbb\rcc", &.{"aa\rbb\rcc"});
    try t("aa\x07bb\x07cc", &.{"aa\x07bb\x07cc"});
    try t("aa\x7Fbb\x7Fcc", &.{"aa\x7Fbb\x7Fcc"});
    try t("aa🦎bb🦎cc", &.{"aa🦎bb🦎cc"});

    // Leading/trailing whitespace
    try t("  ", &.{""});
    try t("  aa  bb  ", &.{ "", "aa", "bb" });
    try t("\t\t", &.{""});
    try t("\t\taa\t\tbb\t\t", &.{ "", "aa", "bb" });
    try t("\n\n", &.{"\n\n"});
    try t("\n\naa\n\nbb\n\n", &.{"\n\naa\n\nbb\n\n"});

    // Executable name with quotes/backslashes
    try t("\"aa bb\tcc\ndd\"", &.{"aa bb\tcc\ndd"});
    try t("\"", &.{""});
    try t("\"\"", &.{""});
    try t("\"\"\"", &.{""});
    try t("\"\"\"\"", &.{""});
    try t("\"\"\"\"\"", &.{""});
    try t("aa\"bb\"cc\"dd", &.{"aabbccdd"});
    try t("aa\"bb cc\"dd", &.{"aabb ccdd"});
    try t("\"aa\\\"bb\"", &.{"aa\\bb"});
    try t("\"aa\\\\\"", &.{"aa\\\\"});
    try t("aa\\\"bb", &.{"aa\\bb"});
    try t("aa\\\\\"bb", &.{"aa\\\\bb"});

    // Arguments with quotes/backslashes
    try t(". \"aa bb\tcc\ndd\"", &.{ ".", "aa bb\tcc\ndd" });
    try t(". aa\" \"bb\"\t\"cc\"\n\"dd\"", &.{ ".", "aa bb\tcc\ndd" });
    try t(". ", &.{"."});
    try t(". \"", &.{ ".", "" });
    try t(". \"\"", &.{ ".", "" });
    try t(". \"\"\"", &.{ ".", "\"" });
    try t(". \"\"\"\"", &.{ ".", "\"" });
    try t(". \"\"\"\"\"", &.{ ".", "\"\"" });
    try t(". \"\"\"\"\"\"", &.{ ".", "\"\"" });
    try t(". \" \"", &.{ ".", " " });
    try t(". \" \"\"", &.{ ".", " \"" });
    try t(". \" \"\"\"", &.{ ".", " \"" });
    try t(". \" \"\"\"\"", &.{ ".", " \"\"" });
    try t(". \" \"\"\"\"\"", &.{ ".", " \"\"" });
    try t(". \" \"\"\"\"\"\"", &.{ ".", " \"\"\"" });
    try t(". \\\"", &.{ ".", "\"" });
    try t(". \\\"\"", &.{ ".", "\"" });
    try t(". \\\"\"\"", &.{ ".", "\"" });
    try t(". \\\"\"\"\"", &.{ ".", "\"\"" });
    try t(". \\\"\"\"\"\"", &.{ ".", "\"\"" });
    try t(". \\\"\"\"\"\"\"", &.{ ".", "\"\"\"" });
    try t(". \" \\\"", &.{ ".", " \"" });
    try t(". \" \\\"\"", &.{ ".", " \"" });
    try t(". \" \\\"\"\"", &.{ ".", " \"\"" });
    try t(". \" \\\"\"\"\"", &.{ ".", " \"\"" });
    try t(". \" \\\"\"\"\"\"", &.{ ".", " \"\"\"" });
    try t(". \" \\\"\"\"\"\"\"", &.{ ".", " \"\"\"" });
    try t(". aa\\bb\\\\cc\\\\\\dd", &.{ ".", "aa\\bb\\\\cc\\\\\\dd" });
    try t(". \\\\\\\"aa bb\"", &.{ ".", "\\\"aa", "bb" });
    try t(". \\\\\\\\\"aa bb\"", &.{ ".", "\\\\aa bb" });

    // From https://learn.microsoft.com/en-us/cpp/cpp/main-function-command-line-args#results-of-parsing-command-lines
    try t(
        \\foo.exe "abc" d e
    , &.{ "foo.exe", "abc", "d", "e" });
    try t(
        \\foo.exe a\\b d"e f"g h
    , &.{ "foo.exe", "a\\\\b", "de fg", "h" });
    try t(
        \\foo.exe a\\\"b c d
    , &.{ "foo.exe", "a\\\"b", "c", "d" });
    try t(
        \\foo.exe a\\\\"b c" d e
    , &.{ "foo.exe", "a\\\\b c", "d", "e" });
    try t(
        \\foo.exe a"b"" c d
    , &.{ "foo.exe", "ab\" c d" });

    // From https://daviddeley.com/autohotkey/parameters/parameters.htm#WINCRULESEX
    try t("foo.exe CallMeIshmael", &.{ "foo.exe", "CallMeIshmael" });
    try t("foo.exe \"Call Me Ishmael\"", &.{ "foo.exe", "Call Me Ishmael" });
    try t("foo.exe Cal\"l Me I\"shmael", &.{ "foo.exe", "Call Me Ishmael" });
    try t("foo.exe CallMe\\\"Ishmael", &.{ "foo.exe", "CallMe\"Ishmael" });
    try t("foo.exe \"CallMe\\\"Ishmael\"", &.{ "foo.exe", "CallMe\"Ishmael" });
    try t("foo.exe \"Call Me Ishmael\\\\\"", &.{ "foo.exe", "Call Me Ishmael\\" });
    try t("foo.exe \"CallMe\\\\\\\"Ishmael\"", &.{ "foo.exe", "CallMe\\\"Ishmael" });
    try t("foo.exe a\\\\\\b", &.{ "foo.exe", "a\\\\\\b" });
    try t("foo.exe \"a\\\\\\b\"", &.{ "foo.exe", "a\\\\\\b" });

    // Surrogate pair encoding of 𐐷 separated by quotes.
    // Encoded as WTF-16:
    // "<0xD801>"<0xDC37>
    // Encoded as WTF-8:
    // "<0xED><0xA0><0x81>"<0xED><0xB0><0xB7>
    // During parsing, the quotes drop out and the surrogate pair
    // should end up encoded as its normal UTF-8 representation.
    try t("foo.exe \"\xed\xa0\x81\"\xed\xb0\xb7", &.{ "foo.exe", "𐐷" });
}

fn testArgIteratorWindows(cmd_line: []const u8, expected_args: []const []const u8) !void {
    const cmd_line_w = try std.unicode.wtf8ToWtf16LeAllocZ(testing.allocator, cmd_line);
    defer testing.allocator.free(cmd_line_w);

    // next
    {
        var it = try ArgIteratorWindows.init(testing.allocator, cmd_line_w);
        defer it.deinit();

        for (expected_args) |expected| {
            if (it.next()) |actual| {
                try testing.expectEqualStrings(expected, actual);
            } else {
                return error.TestUnexpectedResult;
            }
        }
        try testing.expect(it.next() == null);
    }

    // skip
    {
        var it = try ArgIteratorWindows.init(testing.allocator, cmd_line_w);
        defer it.deinit();

        for (0..expected_args.len) |_| {
            try testing.expect(it.skip());
        }
        try testing.expect(!it.skip());
    }
}

test "general arg parsing" {
    try testGeneralCmdLine("a   b\tc d", &.{ "a", "b", "c", "d" });
    try testGeneralCmdLine("\"abc\" d e", &.{ "abc", "d", "e" });
    try testGeneralCmdLine("a\\\\\\b d\"e f\"g h", &.{ "a\\\\\\b", "de fg", "h" });
    try testGeneralCmdLine("a\\\\\\\"b c d", &.{ "a\\\"b", "c", "d" });
    try testGeneralCmdLine("a\\\\\\\\\"b c\" d e", &.{ "a\\\\b c", "d", "e" });
    try testGeneralCmdLine("a   b\tc \"d f", &.{ "a", "b", "c", "d f" });
    try testGeneralCmdLine("j k l\\", &.{ "j", "k", "l\\" });
    try testGeneralCmdLine("\"\" x y z\\\\", &.{ "", "x", "y", "z\\\\" });

    try testGeneralCmdLine("\".\\..\\zig-cache\\build\" \"bin\\zig.exe\" \".\\..\" \".\\..\\zig-cache\" \"--help\"", &.{
        ".\\..\\zig-cache\\build",
        "bin\\zig.exe",
        ".\\..",
        ".\\..\\zig-cache",
        "--help",
    });

    try testGeneralCmdLine(
        \\ 'foo' "bar"
    , &.{ "'foo'", "bar" });
}

fn testGeneralCmdLine(input_cmd_line: []const u8, expected_args: []const []const u8) !void {
    var it = try ArgIteratorGeneral(.{}).init(std.testing.allocator, input_cmd_line);
    defer it.deinit();
    for (expected_args) |expected_arg| {
        const arg = it.next().?;
        try testing.expectEqualStrings(expected_arg, arg);
    }
    try testing.expect(it.next() == null);
}

test "response file arg parsing" {
    try testResponseFileCmdLine(
        \\a b
        \\c d\
    , &.{ "a", "b", "c", "d\\" });
    try testResponseFileCmdLine("a b c d\\", &.{ "a", "b", "c", "d\\" });

    try testResponseFileCmdLine(
        \\j
        \\ k l # this is a comment \\ \\\ \\\\ "none" "\\" "\\\"
        \\ "m" #another comment
        \\
    , &.{ "j", "k", "l", "m" });

    try testResponseFileCmdLine(
        \\ "" q ""
        \\ "r s # t" "u\" v" #another comment
        \\
    , &.{ "", "q", "", "r s # t", "u\" v" });

    try testResponseFileCmdLine(
        \\ -l"advapi32" a# b#c d#
        \\e\\\
    , &.{ "-ladvapi32", "a#", "b#c", "d#", "e\\\\\\" });

    try testResponseFileCmdLine(
        \\ 'foo' "bar"
    , &.{ "foo", "bar" });
}

fn testResponseFileCmdLine(input_cmd_line: []const u8, expected_args: []const []const u8) !void {
    var it = try ArgIteratorGeneral(.{ .comments = true, .single_quotes = true })
        .init(std.testing.allocator, input_cmd_line);
    defer it.deinit();
    for (expected_args) |expected_arg| {
        const arg = it.next().?;
        try testing.expectEqualStrings(expected_arg, arg);
    }
    try testing.expect(it.next() == null);
}

pub const UserInfo = struct {
    uid: posix.uid_t,
    gid: posix.gid_t,
};

/// POSIX function which gets a uid from username.
pub fn getUserInfo(name: []const u8) !UserInfo {
    return switch (native_os) {
        .linux,
        .macos,
        .watchos,
        .tvos,
        .ios,
        .freebsd,
        .netbsd,
        .openbsd,
        .haiku,
        .solaris,
        .illumos,
        => posixGetUserInfo(name),
        else => @compileError("Unsupported OS"),
    };
}

/// TODO this reads /etc/passwd. But sometimes the user/id mapping is in something else
/// like NIS, AD, etc. See `man nss` or look at an strace for `id myuser`.
pub fn posixGetUserInfo(name: []const u8) !UserInfo {
    const file = try std.fs.openFileAbsolute("/etc/passwd", .{});
    defer file.close();

    const reader = file.reader();

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
    var uid: posix.uid_t = 0;
    var gid: posix.gid_t = 0;

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
                        {
                            const ov = @mulWithOverflow(uid, 10);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            uid = ov[0];
                        }
                        {
                            const ov = @addWithOverflow(uid, digit);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            uid = ov[0];
                        }
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
                        {
                            const ov = @mulWithOverflow(gid, 10);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            gid = ov[0];
                        }
                        {
                            const ov = @addWithOverflow(gid, digit);
                            if (ov[1] != 0) return error.CorruptPasswordFile;
                            gid = ov[0];
                        }
                    },
                },
            }
        }
        if (amt_read < buf.len) return error.UserNotFound;
    }
}

pub fn getBaseAddress() usize {
    switch (native_os) {
        .linux => {
            const base = std.os.linux.getauxval(std.elf.AT_BASE);
            if (base != 0) {
                return base;
            }
            const phdr = std.os.linux.getauxval(std.elf.AT_PHDR);
            return phdr - @sizeOf(std.elf.Ehdr);
        },
        .macos, .freebsd, .netbsd => {
            return @intFromPtr(&std.c._mh_execute_header);
        },
        .windows => return @intFromPtr(windows.kernel32.GetModuleHandleW(null)),
        else => @compileError("Unsupported OS"),
    }
}

/// Tells whether calling the `execv` or `execve` functions will be a compile error.
pub const can_execv = switch (native_os) {
    .windows, .haiku, .wasi => false,
    else => true,
};

/// Tells whether spawning child processes is supported (e.g. via ChildProcess)
pub const can_spawn = switch (native_os) {
    .wasi, .watchos, .tvos => false,
    else => true,
};

pub const ExecvError = std.posix.ExecveError || error{OutOfMemory};

/// Replaces the current process image with the executed process.
/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// Due to the heap-allocation, it is illegal to call this function in a fork() child.
/// For that use case, use the `std.posix` functions directly.
pub fn execv(allocator: Allocator, argv: []const []const u8) ExecvError {
    return execve(allocator, argv, null);
}

/// Replaces the current process image with the executed process.
/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// Due to the heap-allocation, it is illegal to call this function in a fork() child.
/// For that use case, use the `std.posix` functions directly.
pub fn execve(
    allocator: Allocator,
    argv: []const []const u8,
    env_map: ?*const EnvMap,
) ExecvError {
    if (!can_execv) @compileError("The target OS does not support execv");

    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const argv_buf = try arena.allocSentinel(?[*:0]const u8, argv.len, null);
    for (argv, 0..) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

    const envp = m: {
        if (env_map) |m| {
            const envp_buf = try child_process.createNullDelimitedEnvMap(arena, m);
            break :m envp_buf.ptr;
        } else if (builtin.link_libc) {
            break :m std.c.environ;
        } else if (builtin.output_mode == .Exe) {
            // Then we have Zig start code and this works.
            // TODO type-safety for null-termination of `os.environ`.
            break :m @as([*:null]const ?[*:0]const u8, @ptrCast(std.os.environ.ptr));
        } else {
            // TODO come up with a solution for this.
            @compileError("missing std lib enhancement: std.process.execv implementation has no way to collect the environment variables to forward to the child process");
        }
    };

    return posix.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp);
}

pub const TotalSystemMemoryError = error{
    UnknownTotalSystemMemory,
};

/// Returns the total system memory, in bytes as a u64.
/// We return a u64 instead of usize due to PAE on ARM
/// and Linux's /proc/meminfo reporting more memory when
/// using QEMU user mode emulation.
pub fn totalSystemMemory() TotalSystemMemoryError!u64 {
    switch (native_os) {
        .linux => {
            return totalSystemMemoryLinux() catch return error.UnknownTotalSystemMemory;
        },
        .freebsd => {
            var physmem: c_ulong = undefined;
            var len: usize = @sizeOf(c_ulong);
            posix.sysctlbynameZ("hw.physmem", &physmem, &len, null, 0) catch |err| switch (err) {
                error.NameTooLong, error.UnknownName => unreachable,
                else => return error.UnknownTotalSystemMemory,
            };
            return @as(usize, @intCast(physmem));
        },
        .openbsd => {
            const mib: [2]c_int = [_]c_int{
                posix.CTL.HW,
                posix.HW.PHYSMEM64,
            };
            var physmem: i64 = undefined;
            var len: usize = @sizeOf(@TypeOf(physmem));
            posix.sysctl(&mib, &physmem, &len, null, 0) catch |err| switch (err) {
                error.NameTooLong => unreachable, // constant, known good value
                error.PermissionDenied => unreachable, // only when setting values,
                error.SystemResources => unreachable, // memory already on the stack
                error.UnknownName => unreachable, // constant, known good value
                else => return error.UnknownTotalSystemMemory,
            };
            assert(physmem >= 0);
            return @as(u64, @bitCast(physmem));
        },
        .windows => {
            var sbi: windows.SYSTEM_BASIC_INFORMATION = undefined;
            const rc = windows.ntdll.NtQuerySystemInformation(
                .SystemBasicInformation,
                &sbi,
                @sizeOf(windows.SYSTEM_BASIC_INFORMATION),
                null,
            );
            if (rc != .SUCCESS) {
                return error.UnknownTotalSystemMemory;
            }
            return @as(u64, sbi.NumberOfPhysicalPages) * sbi.PageSize;
        },
        else => return error.UnknownTotalSystemMemory,
    }
}

fn totalSystemMemoryLinux() !u64 {
    var file = try std.fs.openFileAbsoluteZ("/proc/meminfo", .{});
    defer file.close();
    var buf: [50]u8 = undefined;
    const amt = try file.read(&buf);
    if (amt != 50) return error.Unexpected;
    var it = std.mem.tokenizeAny(u8, buf[0..amt], " \n");
    const label = it.next().?;
    if (!std.mem.eql(u8, label, "MemTotal:")) return error.Unexpected;
    const int_text = it.next() orelse return error.Unexpected;
    const units = it.next() orelse return error.Unexpected;
    if (!std.mem.eql(u8, units, "kB")) return error.Unexpected;
    const kilobytes = try std.fmt.parseInt(u64, int_text, 10);
    return kilobytes * 1024;
}

/// Indicate that we are now terminating with a successful exit code.
/// In debug builds, this is a no-op, so that the calling code's
/// cleanup mechanisms are tested and so that external tools that
/// check for resource leaks can be accurate. In release builds, this
/// calls exit(0), and does not return.
pub fn cleanExit() void {
    if (builtin.mode == .Debug) {
        return;
    } else {
        exit(0);
    }
}
