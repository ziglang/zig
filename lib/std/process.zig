const std = @import("std.zig");
const builtin = @import("builtin");
const os = std.os;
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;
const child_process = @import("child_process.zig");

pub const abort = os.abort;
pub const exit = os.exit;
pub const changeCurDir = os.chdir;
pub const changeCurDirC = os.chdirC;

/// The result is a slice of `out_buffer`, from index `0`.
pub fn getCwd(out_buffer: []u8) ![]u8 {
    return os.getcwd(out_buffer);
}

/// Caller must free the returned memory.
pub fn getCwdAlloc(allocator: Allocator) ![]u8 {
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

/// EnvMap for Windows that handles Unicode-aware case insensitivity for lookups, while also
/// providing the canonical environment variable names when iterating.
///
/// Allows for zero-allocation lookups (even though it needs to do UTF-8 -> UTF-16 -> uppercase
/// conversions) by allocating a buffer large enough to fit the largest environment variable
/// name, and using that when doing lookups (i.e. anything that overflows the buffer can be treated
/// as the environment variable not being found).
pub const EnvMapWindows = struct {
    allocator: Allocator,
    /// Keys are UTF-16le stored as []const u8
    uppercased_map: std.StringHashMapUnmanaged(EnvValue),
    /// Buffer for converting to uppercased UTF-16 on key lookups
    /// Must call `reallocUppercaseBuf` before doing any lookups after a `put` call.
    uppercase_buf_utf16: []u16 = &[_]u16{},
    max_name_utf16_length: usize = 0,

    pub const EnvValue = struct {
        value: []const u8,
        canonical_name: []const u8,
    };

    const Self = @This();

    /// Deinitialize with `deinit`.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .uppercased_map = std.StringHashMapUnmanaged(EnvValue){},
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.uppercased_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
            self.allocator.free(entry.value_ptr.canonical_name);
        }
        self.uppercased_map.deinit(self.allocator);
        self.allocator.free(self.uppercase_buf_utf16);
    }

    /// Increases the size of the uppercase buffer if the maximum name size has increased.
    /// Must be called before any `get` calls after any number of `put` calls.
    pub fn reallocUppercaseBuf(self: *Self) !void {
        if (self.max_name_utf16_length > self.uppercase_buf_utf16.len) {
            self.uppercase_buf_utf16 = try self.allocator.realloc(self.uppercase_buf_utf16, self.max_name_utf16_length);
        }
    }

    /// Converts `src` to uppercase using `RtlUpcaseUnicodeString` and puts the result in `dest`.
    /// Returns the length of the converted UTF-16 string. `dest.len` must be >= `src.len`.
    ///
    /// Note: As of now, RtlUpcaseUnicodeString does not seem to handle codepoints above 0x10000
    /// (i.e. those that require a surrogate pair), so this function will always return a length
    /// equal to `src.len`. However, if RtlUpcaseUnicodeString is updated to handle codepoints above
    /// 0x10000, this property would still hold unless there are lowercase <-> uppercase conversions
    /// that cross over the boundary between codepoints >= 0x10000 and < 0x10000.
    /// TODO: Is it feasible that Unicode lowercase <-> uppercase conversions could cross that boundary?
    fn uppercaseName(dest: []u16, src: []const u16) u16 {
        assert(dest.len >= src.len);

        const dest_bytes = @intCast(u16, dest.len * 2);
        var dest_string = os.windows.UNICODE_STRING{
            .Length = dest_bytes,
            .MaximumLength = dest_bytes,
            .Buffer = @intToPtr([*]u16, @ptrToInt(dest.ptr)),
        };
        const src_bytes = @intCast(u16, src.len * 2);
        const src_string = os.windows.UNICODE_STRING{
            .Length = src_bytes,
            .MaximumLength = src_bytes,
            .Buffer = @intToPtr([*]u16, @ptrToInt(src.ptr)),
        };
        const rc = os.windows.ntdll.RtlUpcaseUnicodeString(&dest_string, &src_string, os.windows.FALSE);
        switch (rc) {
            .SUCCESS => return dest_string.Length / 2,
            else => unreachable, // we are not allocating, so no errors should be possible
        }
    }

    /// Note: Does not realloc the uppercase buf to allow for calling put for many variables and
    /// only allocating the uppercase buf afterwards.
    pub fn putUtf8(self: *Self, name: []const u8, value: []const u8) !void {
        const uppercased_len = len: {
            const name_uppercased_utf16 = uppercased: {
                var name_utf16_buf = try std.ArrayListAligned(u8, @alignOf(u16)).initCapacity(self.allocator, name.len);
                errdefer name_utf16_buf.deinit();

                var uppercased_len = try std.unicode.utf8ToUtf16LeWriter(name_utf16_buf.writer(), name);
                assert(uppercased_len == name_utf16_buf.items.len);

                break :uppercased name_utf16_buf.toOwnedSlice();
            };
            errdefer self.allocator.free(name_uppercased_utf16);

            const name_canonical = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(name_canonical);

            const value_dupe = try self.allocator.dupe(u8, value);
            errdefer self.allocator.free(value_dupe);

            const get_or_put = try self.uppercased_map.getOrPut(self.allocator, name_uppercased_utf16);
            if (get_or_put.found_existing) {
                // note: this is only safe from UAF because the errdefer that frees this value above
                // no longer has a possibility of being triggered after this point
                self.allocator.free(name_uppercased_utf16);
                self.allocator.free(get_or_put.value_ptr.value);
                self.allocator.free(get_or_put.value_ptr.canonical_name);
            } else {
                get_or_put.key_ptr.* = name_uppercased_utf16;
            }
            get_or_put.value_ptr.value = value_dupe;
            get_or_put.value_ptr.canonical_name = name_canonical;

            break :len name_uppercased_utf16.len;
        };

        // The buffer for case conversion for key lookups will need to be as big as the largest
        // key stored in the hash map.
        self.max_name_utf16_length = @maximum(self.max_name_utf16_length, uppercased_len);
    }

    /// Asserts that the name does not already exist in the map.
    /// Note: Does not realloc the uppercase buf to allow for calling put for many variables and
    /// only allocating the uppercase buf afterwards.
    pub fn putUtf16NoClobber(self: *Self, name_utf16: []const u16, value_utf16: []const u16) !void {
        const uppercased_len = len: {
            const name_canonical = try std.unicode.utf16leToUtf8Alloc(self.allocator, name_utf16);
            errdefer self.allocator.free(name_canonical);

            const value = try std.unicode.utf16leToUtf8Alloc(self.allocator, value_utf16);
            errdefer self.allocator.free(value);

            const name_uppercased_utf16 = try self.allocator.alloc(u16, name_utf16.len);
            errdefer self.allocator.free(name_uppercased_utf16);

            const uppercased_len = uppercaseName(name_uppercased_utf16, name_utf16);
            assert(uppercased_len == name_uppercased_utf16.len);

            try self.uppercased_map.putNoClobber(self.allocator, std.mem.sliceAsBytes(name_uppercased_utf16), EnvValue{
                .value = value,
                .canonical_name = name_canonical,
            });
            break :len name_uppercased_utf16.len;
        };

        // The buffer for case conversion for key lookups will need to be as big as the largest
        // key stored in the hash map.
        self.max_name_utf16_length = @maximum(self.max_name_utf16_length, uppercased_len);
    }

    /// Attempts to convert a UTF-8 name into a uppercased UTF-16le name for a lookup. If the
    /// name cannot be converted, this function will return `null`.
    fn utf8ToUppercasedUtf16(self: Self, name: []const u8) ?[]u16 {
        const name_utf16: []u16 = to_utf16: {
            var utf16_buf_stream = std.io.fixedBufferStream(std.mem.sliceAsBytes(self.uppercase_buf_utf16));
            _ = std.unicode.utf8ToUtf16LeWriter(utf16_buf_stream.writer(), name) catch |err| switch (err) {
                // If the buffer isn't large enough, we can treat that as 'env var not found', as we
                // know anything too large for the buffer can't be found in the map.
                error.NoSpaceLeft => return null,
                // Anything with invalid UTF-8 will also not be found in the map, so treat that as
                // 'env var not found' too
                error.InvalidUtf8 => return null,
            };
            break :to_utf16 std.mem.bytesAsSlice(u16, utf16_buf_stream.getWritten());
        };

        // uppercase in place
        const uppercased_len = uppercaseName(name_utf16, name_utf16);
        assert(uppercased_len == name_utf16.len);

        return name_utf16;
    }

    /// Returns true if an entry was found and deleted, false otherwise.
    pub fn remove(self: *Self, name: []const u8) bool {
        const name_utf16 = self.utf8ToUppercasedUtf16(name) orelse return false;
        const kv = self.uppercased_map.fetchRemove(std.mem.sliceAsBytes(name_utf16)) orelse return false;
        self.allocator.free(kv.key);
        self.allocator.free(kv.value.value);
        self.allocator.free(kv.value.canonical_name);
        return true;
    }

    pub fn get(self: Self, name: []const u8) ?EnvValue {
        const name_utf16 = self.utf8ToUppercasedUtf16(name) orelse return null;
        return self.uppercased_map.get(std.mem.sliceAsBytes(name_utf16));
    }

    pub fn count(self: Self) EnvMap.Size {
        return self.uppercased_map.count();
    }

    pub fn iterator(self: *const Self) Iterator {
        return .{
            .env_map = self,
            .uppercased_map_iterator = self.uppercased_map.iterator(),
        };
    }

    pub const Iterator = struct {
        env_map: *const Self,
        uppercased_map_iterator: std.StringHashMapUnmanaged(EnvValue).Iterator,

        pub fn next(it: *Iterator) ?EnvMap.Entry {
            if (it.uppercased_map_iterator.next()) |uppercased_entry| {
                return EnvMap.Entry{
                    .name = uppercased_entry.value_ptr.canonical_name,
                    .value = uppercased_entry.value_ptr.value,
                };
            } else {
                return null;
            }
        }
    };
};

test "EnvMapWindows" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var env_map = EnvMapWindows.init(testing.allocator);
    defer env_map.deinit();

    // both put methods
    try env_map.putUtf16NoClobber(std.unicode.utf8ToUtf16LeStringLiteral("Path"), std.unicode.utf8ToUtf16LeStringLiteral("something"));
    try env_map.putUtf8("КИРИЛЛИЦА", "something else");
    try env_map.reallocUppercaseBuf();

    try testing.expectEqual(@as(EnvMap.Size, 2), env_map.count());

    // unicode-aware case-insensitive lookups
    try testing.expectEqualStrings("something", env_map.get("PATH").?.value);
    try testing.expectEqualStrings("something else", env_map.get("кириллица").?.value);
    try testing.expect(env_map.get("missing") == null);

    // canonical names when iterating
    var it = env_map.iterator();
    var count: EnvMap.Size = 0;
    while (it.next()) |entry| {
        const is_an_expected_name = std.mem.eql(u8, "Path", entry.name) or std.mem.eql(u8, "КИРИЛЛИЦА", entry.name);
        try testing.expect(is_an_expected_name);
        count += 1;
    }
    try testing.expectEqual(@as(EnvMap.Size, 2), count);
}

pub const EnvMap = struct {
    storage: StorageType,

    pub const StorageType = switch (builtin.os.tag) {
        .windows => EnvMapWindows,
        else => std.BufMap,
    };

    /// Matches what BufMap uses for its internal HashMap Size
    pub const Size = u32;

    const Self = @This();

    /// Deinitialize with `deinit`.
    pub fn init(allocator: Allocator) Self {
        return Self{ .storage = StorageType.init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.storage.deinit();
    }

    pub fn get(self: Self, name: []const u8) ?[]const u8 {
        switch (builtin.os.tag) {
            .windows => {
                if (self.storage.get(name)) |entry| {
                    return entry.value;
                } else {
                    return null;
                }
            },
            else => return self.storage.get(name),
        }
    }

    pub fn count(self: Self) Size {
        return self.storage.count();
    }

    pub fn iterator(self: *const Self) Iterator {
        return .{ .storage_iterator = self.storage.iterator() };
    }

    pub fn put(self: *Self, name: []const u8, value: []const u8) !void {
        switch (builtin.os.tag) {
            .windows => {
                try self.storage.putUtf8(name, value);
                try self.storage.reallocUppercaseBuf();
            },
            else => return self.storage.put(name, value),
        }
    }

    pub fn remove(self: *Self, name: []const u8) void {
        _ = self.storage.remove(name);
    }

    pub const Entry = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const Iterator = struct {
        storage_iterator: switch (builtin.os.tag) {
            .windows => EnvMapWindows.Iterator,
            else => std.BufMap.BufMapHashMap.Iterator,
        },

        pub fn next(it: *Iterator) ?Entry {
            switch (builtin.os.tag) {
                .windows => return it.storage_iterator.next(),
                else => {
                    if (it.storage_iterator.next()) |entry| {
                        return Entry{
                            .name = entry.key_ptr.*,
                            .value = entry.value_ptr.*,
                        };
                    } else {
                        return null;
                    }
                },
            }
        }
    };
};

test "EnvMap" {
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
    if (builtin.os.tag == .windows) {
        try testing.expectEqualStrings("1", env.get("something_New_aNd_LONGER").?);
    } else {
        try testing.expect(null == env.get("something_New_aNd_LONGER"));
    }

    var it = env.iterator();
    var count: EnvMap.Size = 0;
    while (it.next()) |entry| {
        const is_an_expected_name = std.mem.eql(u8, "SOMETHING_NEW", entry.name) or std.mem.eql(u8, "SOMETHING_NEW_AND_LONGER", entry.name);
        try testing.expect(is_an_expected_name);
        count += 1;
    }
    try testing.expectEqual(@as(EnvMap.Size, 2), count);

    env.remove("SOMETHING_NEW");
    try testing.expect(env.get("SOMETHING_NEW") == null);

    try testing.expectEqual(@as(EnvMap.Size, 1), env.count());
}

/// Returns a snapshot of the environment variables of the current process.
/// Any modifications to the resulting EnvMap will not be not reflected in the environment, and
/// likewise, any future modifications to the environment will not be reflected in the EnvMap.
/// Caller owns resulting `EnvMap` and should call its `deinit` fn when done.
pub fn getEnvMap(allocator: Allocator) !EnvMap {
    var result = EnvMap.init(allocator);
    errdefer result.deinit();

    if (builtin.os.tag == .windows) {
        const ptr = os.windows.peb().ProcessParameters.Environment;

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

            if (ptr[i] == '=') i += 1;

            const value_start = i;
            while (ptr[i] != 0) : (i += 1) {}
            const value_w = ptr[value_start..i];

            try result.storage.putUtf16NoClobber(key_w, value_w);

            i += 1; // skip over null byte
        }

        try result.storage.reallocUppercaseBuf();
        return result;
    } else if (builtin.os.tag == .wasi and !builtin.link_libc) {
        var environ_count: usize = undefined;
        var environ_buf_size: usize = undefined;

        const environ_sizes_get_ret = os.wasi.environ_sizes_get(&environ_count, &environ_buf_size);
        if (environ_sizes_get_ret != .SUCCESS) {
            return os.unexpectedErrno(environ_sizes_get_ret);
        }

        var environ = try allocator.alloc([*:0]u8, environ_count);
        defer allocator.free(environ);
        var environ_buf = try allocator.alloc(u8, environ_buf_size);
        defer allocator.free(environ_buf);

        const environ_get_ret = os.wasi.environ_get(environ.ptr, environ_buf.ptr);
        if (environ_get_ret != .SUCCESS) {
            return os.unexpectedErrno(environ_get_ret);
        }

        for (environ) |env| {
            const pair = mem.sliceTo(env, 0);
            var parts = mem.split(u8, pair, "=");
            const key = parts.next().?;
            const value = parts.next().?;
            try result.put(key, value);
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

            try result.put(key, value);
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

            try result.put(key, value);
        }
        return result;
    }
}

test "getEnvMap" {
    var env = try getEnvMap(testing.allocator);
    defer env.deinit();
}

pub const GetEnvVarOwnedError = error{
    OutOfMemory,
    EnvironmentVariableNotFound,

    /// See https://github.com/ziglang/zig/issues/1774
    InvalidUtf8,
};

/// Caller must free returned memory.
pub fn getEnvVarOwned(allocator: mem.Allocator, key: []const u8) GetEnvVarOwnedError![]u8 {
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

pub fn hasEnvVarConstant(comptime key: []const u8) bool {
    if (builtin.os.tag == .windows) {
        const key_w = comptime std.unicode.utf8ToUtf16LeStringLiteral(key);
        return std.os.getenvW(key_w) != null;
    } else {
        return os.getenv(key) != null;
    }
}

pub fn hasEnvVar(allocator: Allocator, key: []const u8) error{OutOfMemory}!bool {
    if (builtin.os.tag == .windows) {
        var stack_alloc = std.heap.stackFallback(256 * @sizeOf(u16), allocator);
        const key_w = try std.unicode.utf8ToUtf16LeWithNull(stack_alloc.get(), key);
        defer stack_alloc.allocator.free(key_w);
        return std.os.getenvW(key_w) != null;
    } else {
        return os.getenv(key) != null;
    }
}

test "os.getEnvVarOwned" {
    var ga = std.testing.allocator;
    try testing.expectError(error.EnvironmentVariableNotFound, getEnvVarOwned(ga, "BADENV"));
}

pub const ArgIteratorPosix = struct {
    index: usize,
    count: usize,

    pub const InitError = error{};

    pub fn init() ArgIteratorPosix {
        return ArgIteratorPosix{
            .index = 0,
            .count = os.argv.len,
        };
    }

    pub fn next(self: *ArgIteratorPosix) ?[:0]const u8 {
        if (self.index == self.count) return null;

        const s = os.argv[self.index];
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
    allocator: mem.Allocator,
    index: usize,
    args: [][:0]u8,

    pub const InitError = error{OutOfMemory} || os.UnexpectedError;

    /// You must call deinit to free the internal buffer of the
    /// iterator after you are done.
    pub fn init(allocator: mem.Allocator) InitError!ArgIteratorWasi {
        const fetched_args = try ArgIteratorWasi.internalInit(allocator);
        return ArgIteratorWasi{
            .allocator = allocator,
            .index = 0,
            .args = fetched_args,
        };
    }

    fn internalInit(allocator: mem.Allocator) InitError![][:0]u8 {
        const w = os.wasi;
        var count: usize = undefined;
        var buf_size: usize = undefined;

        switch (w.args_sizes_get(&count, &buf_size)) {
            .SUCCESS => {},
            else => |err| return os.unexpectedErrno(err),
        }

        var argv = try allocator.alloc([*:0]u8, count);
        defer allocator.free(argv);

        var argv_buf = try allocator.alloc(u8, buf_size);

        switch (w.args_get(argv.ptr, argv_buf.ptr)) {
            .SUCCESS => {},
            else => |err| return os.unexpectedErrno(err),
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
        const last_byte_addr = @ptrToInt(last_item.ptr) + last_item.len + 1; // null terminated
        const first_item_ptr = self.args[0].ptr;
        const len = last_byte_addr - @ptrToInt(first_item_ptr);
        self.allocator.free(first_item_ptr[0..len]);
        self.allocator.free(self.args);
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
        pub const InitUtf16leError = error{ OutOfMemory, InvalidCmdLine };

        /// cmd_line_utf8 MUST remain valid and constant while using this instance
        pub fn init(allocator: Allocator, cmd_line_utf8: []const u8) InitError!Self {
            var buffer = try allocator.alloc(u8, cmd_line_utf8.len + 1);
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
            var buffer = try allocator.alloc(u8, cmd_line_utf8.len + 1);
            errdefer allocator.free(buffer);

            return Self{
                .allocator = allocator,
                .cmd_line = cmd_line_utf8,
                .free_cmd_line_on_deinit = true,
                .buffer = buffer,
            };
        }

        /// cmd_line_utf16le MUST be encoded UTF16-LE, and is converted to UTF-8 in an internal buffer
        pub fn initUtf16le(allocator: Allocator, cmd_line_utf16le: [*:0]const u16) InitUtf16leError!Self {
            var utf16le_slice = mem.sliceTo(cmd_line_utf16le, 0);
            var cmd_line = std.unicode.utf16leToUtf8Alloc(allocator, utf16le_slice) catch |err| switch (err) {
                error.ExpectedSecondSurrogateHalf,
                error.DanglingSurrogateHalf,
                error.UnexpectedSecondSurrogateHalf,
                => return error.InvalidCmdLine,

                error.OutOfMemory => return error.OutOfMemory,
            };
            errdefer allocator.free(cmd_line);

            var buffer = try allocator.alloc(u8, cmd_line.len + 1);
            errdefer allocator.free(buffer);

            return Self{
                .allocator = allocator,
                .cmd_line = cmd_line,
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
                        var token = self.buffer[self.start..self.end :0];
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
                            var token = self.buffer[self.start..self.end :0];
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
    const InnerType = switch (builtin.os.tag) {
        .windows => ArgIteratorGeneral(.{}),
        .wasi => if (builtin.link_libc) ArgIteratorPosix else ArgIteratorWasi,
        else => ArgIteratorPosix,
    };

    inner: InnerType,

    /// Initialize the args iterator. Consider using initWithAllocator() instead
    /// for cross-platform compatibility.
    pub fn init() ArgIterator {
        if (builtin.os.tag == .wasi) {
            @compileError("In WASI, use initWithAllocator instead.");
        }
        if (builtin.os.tag == .windows) {
            @compileError("In Windows, use initWithAllocator instead.");
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    pub const InitError = switch (builtin.os.tag) {
        .windows => InnerType.InitUtf16leError,
        else => InnerType.InitError,
    };

    /// You must deinitialize iterator's internal buffers by calling `deinit` when done.
    pub fn initWithAllocator(allocator: mem.Allocator) InitError!ArgIterator {
        if (builtin.os.tag == .wasi and !builtin.link_libc) {
            return ArgIterator{ .inner = try InnerType.init(allocator) };
        }
        if (builtin.os.tag == .windows) {
            const cmd_line_w = os.windows.kernel32.GetCommandLineW();
            return ArgIterator{ .inner = try InnerType.initUtf16le(allocator, cmd_line_w) };
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    /// Get the next argument. Returns 'null' if we are at the end.
    /// Returned slice is pointing to the iterator's internal buffer.
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
        if (builtin.os.tag == .wasi and !builtin.link_libc) {
            self.inner.deinit();
        }

        if (builtin.os.tag == .windows) {
            self.inner.deinit();
        }
    }
};

/// Use argsWithAllocator() for cross-platform code
pub fn args() ArgIterator {
    return ArgIterator.init();
}

/// You must deinitialize iterator's internal buffers by calling `deinit` when done.
pub fn argsWithAllocator(allocator: mem.Allocator) ArgIterator.InitError!ArgIterator {
    return ArgIterator.initWithAllocator(allocator);
}

test "args iterator" {
    var ga = std.testing.allocator;
    var it = try argsWithAllocator(ga);
    defer it.deinit(); // no-op unless WASI or Windows

    const prog_name = it.next() orelse unreachable;
    const expected_suffix = switch (builtin.os.tag) {
        .wasi => "test.wasm",
        .windows => "test.exe",
        else => "test",
    };
    const given_suffix = std.fs.path.basename(prog_name);

    try testing.expect(mem.eql(u8, expected_suffix, given_suffix));
    try testing.expect(it.skip()); // Skip over zig_exe_path, passed to the test runner
    try testing.expect(it.next() == null);
    try testing.expect(!it.skip());
}

/// Caller must call argsFree on result.
pub fn argsAlloc(allocator: mem.Allocator) ![][:0]u8 {
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
    mem.copy(u8, result_contents, contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index :0];
        contents_index = new_index + 1;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: mem.Allocator, args_alloc: []const [:0]u8) void {
    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len + 1;
    }
    const unaligned_allocated_buf = @ptrCast([*]const u8, args_alloc.ptr)[0..total_bytes];
    const aligned_allocated_buf = @alignCast(@alignOf([]u8), unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
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
    uid: os.uid_t,
    gid: os.gid_t,
};

/// POSIX function which gets a uid from username.
pub fn getUserInfo(name: []const u8) !UserInfo {
    return switch (builtin.os.tag) {
        .linux, .macos, .watchos, .tvos, .ios, .freebsd, .netbsd, .openbsd, .haiku, .solaris => posixGetUserInfo(name),
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
    var uid: os.uid_t = 0;
    var gid: os.gid_t = 0;

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
                        if (@mulWithOverflow(u32, uid, 10, &uid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, uid, digit, &uid)) return error.CorruptPasswordFile;
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
                        if (@mulWithOverflow(u32, gid, 10, &gid)) return error.CorruptPasswordFile;
                        if (@addWithOverflow(u32, gid, digit, &gid)) return error.CorruptPasswordFile;
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
        .macos, .freebsd, .netbsd => {
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
pub fn getSelfExeSharedLibPaths(allocator: Allocator) error{OutOfMemory}![][:0]u8 {
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
        .openbsd,
        .solaris,
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
                    _ = size;
                    const name = info.dlpi_name orelse return;
                    if (name[0] == '/') {
                        const item = try list.allocator.dupeZ(u8, mem.sliceTo(name, 0));
                        errdefer list.allocator.free(item);
                        try list.append(item);
                    }
                }
            }.callback);
            return paths.toOwnedSlice();
        },
        .macos, .ios, .watchos, .tvos => {
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
                const item = try allocator.dupeZ(u8, mem.sliceTo(name, 0));
                errdefer allocator.free(item);
                try paths.append(item);
            }
            return paths.toOwnedSlice();
        },
        // revisit if Haiku implements dl_iterat_phdr (https://dev.haiku-os.org/ticket/15743)
        .haiku => {
            var paths = List.init(allocator);
            errdefer {
                const slice = paths.toOwnedSlice();
                for (slice) |item| {
                    allocator.free(item);
                }
                allocator.free(slice);
            }

            var b = "/boot/system/runtime_loader";
            const item = try allocator.dupeZ(u8, mem.sliceTo(b, 0));
            errdefer allocator.free(item);
            try paths.append(item);

            return paths.toOwnedSlice();
        },
        else => @compileError("getSelfExeSharedLibPaths unimplemented for this target"),
    }
}

/// Tells whether calling the `execv` or `execve` functions will be a compile error.
pub const can_execv = switch (builtin.os.tag) {
    .windows, .haiku, .wasi => false,
    else => true,
};

/// Tells whether spawning child processes is supported (e.g. via ChildProcess)
pub const can_spawn = switch (builtin.os.tag) {
    .wasi => false,
    else => true,
};

pub const ExecvError = std.os.ExecveError || error{OutOfMemory};

/// Replaces the current process image with the executed process.
/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// Due to the heap-allocation, it is illegal to call this function in a fork() child.
/// For that use case, use the `std.os` functions directly.
pub fn execv(allocator: mem.Allocator, argv: []const []const u8) ExecvError {
    return execve(allocator, argv, null);
}

/// Replaces the current process image with the executed process.
/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// Due to the heap-allocation, it is illegal to call this function in a fork() child.
/// For that use case, use the `std.os` functions directly.
pub fn execve(
    allocator: mem.Allocator,
    argv: []const []const u8,
    env_map: ?*const std.BufMap,
) ExecvError {
    if (!can_execv) @compileError("The target OS does not support execv");

    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const argv_buf = try arena.allocSentinel(?[*:0]u8, argv.len, null);
    for (argv) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

    const envp = m: {
        if (env_map) |m| {
            const envp_buf = try child_process.createNullDelimitedEnvMap(arena, m);
            break :m envp_buf.ptr;
        } else if (builtin.link_libc) {
            break :m std.c.environ;
        } else if (builtin.output_mode == .Exe) {
            // Then we have Zig start code and this works.
            // TODO type-safety for null-termination of `os.environ`.
            break :m @ptrCast([*:null]?[*:0]u8, os.environ.ptr);
        } else {
            // TODO come up with a solution for this.
            @compileError("missing std lib enhancement: std.process.execv implementation has no way to collect the environment variables to forward to the child process");
        }
    };

    return os.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp);
}
