// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const crypto = std.crypto;
const Hasher = crypto.auth.siphash.SipHash128(1, 3); // provides enough collision resistance for the CacheHash use cases, while being one of our fastest options right now
const fs = std.fs;
const base64 = std.base64;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const base64_encoder = fs.base64_encoder;
const base64_decoder = fs.base64_decoder;
/// This is 128 bits - Even with 2^54 cache entries, the probably of a collision would be under 10^-6
const BIN_DIGEST_LEN = 16;
const BASE64_DIGEST_LEN = base64.Base64Encoder.calcSize(BIN_DIGEST_LEN);

const MANIFEST_FILE_SIZE_MAX = 50 * 1024 * 1024;

pub const File = struct {
    path: ?[]const u8,
    max_file_size: ?usize,
    stat: fs.File.Stat,
    bin_digest: [BIN_DIGEST_LEN]u8,
    contents: ?[]const u8,

    pub fn deinit(self: *File, allocator: *Allocator) void {
        if (self.path) |owned_slice| {
            allocator.free(owned_slice);
            self.path = null;
        }
        if (self.contents) |contents| {
            allocator.free(contents);
            self.contents = null;
        }
        self.* = undefined;
    }
};

/// CacheHash manages project-local `zig-cache` directories.
/// This is not a general-purpose cache.
/// It was designed to be fast and simple, not to withstand attacks using specially-crafted input.
pub const CacheHash = struct {
    allocator: *Allocator,
    hasher_init: Hasher, // initial state, that can be copied
    hasher: Hasher, // current state for incremental hashing
    manifest_dir: fs.Dir,
    manifest_file: ?fs.File,
    manifest_dirty: bool,
    files: ArrayList(File),
    b64_digest: [BASE64_DIGEST_LEN]u8,

    /// Be sure to call release after successful initialization.
    pub fn init(allocator: *Allocator, dir: fs.Dir, manifest_dir_path: []const u8) !CacheHash {
        const hasher_init = Hasher.init(&[_]u8{0} ** Hasher.minimum_key_length);
        return CacheHash{
            .allocator = allocator,
            .hasher_init = hasher_init,
            .hasher = hasher_init,
            .manifest_dir = try dir.makeOpenPath(manifest_dir_path, .{}),
            .manifest_file = null,
            .manifest_dirty = false,
            .files = ArrayList(File).init(allocator),
            .b64_digest = undefined,
        };
    }

    /// Record a slice of bytes as an dependency of the process being cached
    pub fn addSlice(self: *CacheHash, val: []const u8) void {
        assert(self.manifest_file == null);

        self.hasher.update(val);
        self.hasher.update(&[_]u8{0});
    }

    /// Convert the input value into bytes and record it as a dependency of the
    /// process being cached
    pub fn add(self: *CacheHash, val: anytype) void {
        assert(self.manifest_file == null);

        const valPtr = switch (@typeInfo(@TypeOf(val))) {
            .Int => &val,
            .Pointer => val,
            else => &val,
        };

        self.addSlice(mem.asBytes(valPtr));
    }

    /// Add a file as a dependency of process being cached. When `CacheHash.hit` is
    /// called, the file's contents will be checked to ensure that it matches
    /// the contents from previous times.
    ///
    /// Max file size will be used to determine the amount of space to the file contents
    /// are allowed to take up in memory. If max_file_size is null, then the contents
    /// will not be loaded into memory.
    ///
    /// Returns the index of the entry in the `CacheHash.files` ArrayList. You can use it
    /// to access the contents of the file after calling `CacheHash.hit()` like so:
    ///
    /// ```
    /// var file_contents = cache_hash.files.items[file_index].contents.?;
    /// ```
    pub fn addFile(self: *CacheHash, file_path: []const u8, max_file_size: ?usize) !usize {
        assert(self.manifest_file == null);

        try self.files.ensureCapacity(self.files.items.len + 1);
        const resolved_path = try fs.path.resolve(self.allocator, &[_][]const u8{file_path});

        const idx = self.files.items.len;
        self.files.addOneAssumeCapacity().* = .{
            .path = resolved_path,
            .contents = null,
            .max_file_size = max_file_size,
            .stat = undefined,
            .bin_digest = undefined,
        };

        self.addSlice(resolved_path);

        return idx;
    }

    /// Check the cache to see if the input exists in it. If it exists, a base64 encoding
    /// of it's hash will be returned; otherwise, null will be returned.
    ///
    /// This function will also acquire an exclusive lock to the manifest file. This means
    /// that a process holding a CacheHash will block any other process attempting to
    /// acquire the lock.
    ///
    /// The lock on the manifest file is released when `CacheHash.release` is called.
    pub fn hit(self: *CacheHash) !?[BASE64_DIGEST_LEN]u8 {
        assert(self.manifest_file == null);

        var bin_digest: [BIN_DIGEST_LEN]u8 = undefined;
        self.hasher.final(&bin_digest);

        base64_encoder.encode(self.b64_digest[0..], &bin_digest);

        self.hasher = self.hasher_init;
        self.hasher.update(&bin_digest);

        const manifest_file_path = try fmt.allocPrint(self.allocator, "{}.txt", .{self.b64_digest});
        defer self.allocator.free(manifest_file_path);

        if (self.files.items.len != 0) {
            self.manifest_file = try self.manifest_dir.createFile(manifest_file_path, .{
                .read = true,
                .truncate = false,
                .lock = .Exclusive,
            });
        } else {
            // If there are no file inputs, we check if the manifest file exists instead of
            // comparing the hashes on the files used for the cached item
            self.manifest_file = self.manifest_dir.openFile(manifest_file_path, .{
                .read = true,
                .write = true,
                .lock = .Exclusive,
            }) catch |err| switch (err) {
                error.FileNotFound => {
                    self.manifest_dirty = true;
                    self.manifest_file = try self.manifest_dir.createFile(manifest_file_path, .{
                        .read = true,
                        .truncate = false,
                        .lock = .Exclusive,
                    });
                    return null;
                },
                else => |e| return e,
            };
        }

        const file_contents = try self.manifest_file.?.inStream().readAllAlloc(self.allocator, MANIFEST_FILE_SIZE_MAX);
        defer self.allocator.free(file_contents);

        const input_file_count = self.files.items.len;
        var any_file_changed = false;
        var line_iter = mem.tokenize(file_contents, "\n");
        var idx: usize = 0;
        while (line_iter.next()) |line| {
            defer idx += 1;

            const cache_hash_file = if (idx < input_file_count) &self.files.items[idx] else blk: {
                const new = try self.files.addOne();
                new.* = .{
                    .path = null,
                    .contents = null,
                    .max_file_size = null,
                    .stat = undefined,
                    .bin_digest = undefined,
                };
                break :blk new;
            };

            var iter = mem.tokenize(line, " ");
            const size = iter.next() orelse return error.InvalidFormat;
            const inode = iter.next() orelse return error.InvalidFormat;
            const mtime_nsec_str = iter.next() orelse return error.InvalidFormat;
            const digest_str = iter.next() orelse return error.InvalidFormat;
            const file_path = iter.rest();

            cache_hash_file.stat.size = fmt.parseInt(u64, size, 10) catch return error.InvalidFormat;
            cache_hash_file.stat.inode = fmt.parseInt(fs.File.INode, inode, 10) catch return error.InvalidFormat;
            cache_hash_file.stat.mtime = fmt.parseInt(i64, mtime_nsec_str, 10) catch return error.InvalidFormat;
            base64_decoder.decode(&cache_hash_file.bin_digest, digest_str) catch return error.InvalidFormat;

            if (file_path.len == 0) {
                return error.InvalidFormat;
            }
            if (cache_hash_file.path) |p| {
                if (!mem.eql(u8, file_path, p)) {
                    return error.InvalidFormat;
                }
            }

            if (cache_hash_file.path == null) {
                cache_hash_file.path = try self.allocator.dupe(u8, file_path);
            }

            const this_file = fs.cwd().openFile(cache_hash_file.path.?, .{ .read = true }) catch {
                return error.CacheUnavailable;
            };
            defer this_file.close();

            const actual_stat = try this_file.stat();
            const size_match = actual_stat.size == cache_hash_file.stat.size;
            const mtime_match = actual_stat.mtime == cache_hash_file.stat.mtime;
            const inode_match = actual_stat.inode == cache_hash_file.stat.inode;

            if (!size_match or !mtime_match or !inode_match) {
                self.manifest_dirty = true;

                cache_hash_file.stat = actual_stat;

                if (isProblematicTimestamp(cache_hash_file.stat.mtime)) {
                    cache_hash_file.stat.mtime = 0;
                    cache_hash_file.stat.inode = 0;
                }

                var actual_digest: [BIN_DIGEST_LEN]u8 = undefined;
                try hashFile(this_file, &actual_digest, self.hasher_init);

                if (!mem.eql(u8, &cache_hash_file.bin_digest, &actual_digest)) {
                    cache_hash_file.bin_digest = actual_digest;
                    // keep going until we have the input file digests
                    any_file_changed = true;
                }
            }

            if (!any_file_changed) {
                self.hasher.update(&cache_hash_file.bin_digest);
            }
        }

        if (any_file_changed) {
            // cache miss
            // keep the manifest file open
            // reset the hash
            self.hasher = self.hasher_init;
            self.hasher.update(&bin_digest);

            // Remove files not in the initial hash
            for (self.files.items[input_file_count..]) |*file| {
                file.deinit(self.allocator);
            }
            self.files.shrink(input_file_count);

            for (self.files.items) |file| {
                self.hasher.update(&file.bin_digest);
            }
            return null;
        }

        if (idx < input_file_count) {
            self.manifest_dirty = true;
            while (idx < input_file_count) : (idx += 1) {
                const ch_file = &self.files.items[idx];
                try self.populateFileHash(ch_file);
            }
            return null;
        }

        return self.final();
    }

    fn populateFileHash(self: *CacheHash, ch_file: *File) !void {
        const file = try fs.cwd().openFile(ch_file.path.?, .{});
        defer file.close();

        ch_file.stat = try file.stat();

        if (isProblematicTimestamp(ch_file.stat.mtime)) {
            ch_file.stat.mtime = 0;
            ch_file.stat.inode = 0;
        }

        if (ch_file.max_file_size) |max_file_size| {
            if (ch_file.stat.size > max_file_size) {
                return error.FileTooBig;
            }

            const contents = try self.allocator.alloc(u8, @intCast(usize, ch_file.stat.size));
            errdefer self.allocator.free(contents);

            // Hash while reading from disk, to keep the contents in the cpu cache while
            // doing hashing.
            var hasher = self.hasher_init;
            var off: usize = 0;
            while (true) {
                // give me everything you've got, captain
                const bytes_read = try file.read(contents[off..]);
                if (bytes_read == 0) break;
                hasher.update(contents[off..][0..bytes_read]);
                off += bytes_read;
            }
            hasher.final(&ch_file.bin_digest);

            ch_file.contents = contents;
        } else {
            try hashFile(file, &ch_file.bin_digest, self.hasher_init);
        }

        self.hasher.update(&ch_file.bin_digest);
    }

    /// Add a file as a dependency of process being cached, after the initial hash has been
    /// calculated. This is useful for processes that don't know the all the files that
    /// are depended on ahead of time. For example, a source file that can import other files
    /// will need to be recompiled if the imported file is changed.
    pub fn addFilePostFetch(self: *CacheHash, file_path: []const u8, max_file_size: usize) ![]u8 {
        assert(self.manifest_file != null);

        const resolved_path = try fs.path.resolve(self.allocator, &[_][]const u8{file_path});
        errdefer self.allocator.free(resolved_path);

        const new_ch_file = try self.files.addOne();
        new_ch_file.* = .{
            .path = resolved_path,
            .max_file_size = max_file_size,
            .stat = undefined,
            .bin_digest = undefined,
            .contents = null,
        };
        errdefer self.files.shrink(self.files.items.len - 1);

        try self.populateFileHash(new_ch_file);

        return new_ch_file.contents.?;
    }

    /// Add a file as a dependency of process being cached, after the initial hash has been
    /// calculated. This is useful for processes that don't know the all the files that
    /// are depended on ahead of time. For example, a source file that can import other files
    /// will need to be recompiled if the imported file is changed.
    pub fn addFilePost(self: *CacheHash, file_path: []const u8) !void {
        assert(self.manifest_file != null);

        const resolved_path = try fs.path.resolve(self.allocator, &[_][]const u8{file_path});
        errdefer self.allocator.free(resolved_path);

        const new_ch_file = try self.files.addOne();
        new_ch_file.* = .{
            .path = resolved_path,
            .max_file_size = null,
            .stat = undefined,
            .bin_digest = undefined,
            .contents = null,
        };
        errdefer self.files.shrink(self.files.items.len - 1);

        try self.populateFileHash(new_ch_file);
    }

    /// Returns a base64 encoded hash of the inputs.
    pub fn final(self: *CacheHash) [BASE64_DIGEST_LEN]u8 {
        assert(self.manifest_file != null);

        // We don't close the manifest file yet, because we want to
        // keep it locked until the API user is done using it.
        // We also don't write out the manifest yet, because until
        // cache_release is called we still might be working on creating
        // the artifacts to cache.

        var bin_digest: [BIN_DIGEST_LEN]u8 = undefined;
        self.hasher.final(&bin_digest);

        var out_digest: [BASE64_DIGEST_LEN]u8 = undefined;
        base64_encoder.encode(&out_digest, &bin_digest);

        return out_digest;
    }

    pub fn writeManifest(self: *CacheHash) !void {
        assert(self.manifest_file != null);

        var encoded_digest: [BASE64_DIGEST_LEN]u8 = undefined;
        var contents = ArrayList(u8).init(self.allocator);
        var outStream = contents.outStream();
        defer contents.deinit();

        for (self.files.items) |file| {
            base64_encoder.encode(encoded_digest[0..], &file.bin_digest);
            try outStream.print("{} {} {} {} {}\n", .{ file.stat.size, file.stat.inode, file.stat.mtime, encoded_digest[0..], file.path });
        }

        try self.manifest_file.?.pwriteAll(contents.items, 0);
        self.manifest_dirty = false;
    }

    /// Releases the manifest file and frees any memory the CacheHash was using.
    /// `CacheHash.hit` must be called first.
    ///
    /// Will also attempt to write to the manifest file if the manifest is dirty.
    /// Writing to the manifest file can fail, but this function ignores those errors.
    /// To detect failures from writing the manifest, one may explicitly call
    /// `writeManifest` before `release`.
    pub fn release(self: *CacheHash) void {
        if (self.manifest_file) |file| {
            if (self.manifest_dirty) {
                // To handle these errors, API users should call
                // writeManifest before release().
                self.writeManifest() catch {};
            }

            file.close();
        }

        for (self.files.items) |*file| {
            file.deinit(self.allocator);
        }
        self.files.deinit();
        self.manifest_dir.close();
    }
};

fn hashFile(file: fs.File, bin_digest: []u8, hasher_init: anytype) !void {
    var buf: [1024]u8 = undefined;

    var hasher = hasher_init;
    while (true) {
        const bytes_read = try file.read(&buf);
        if (bytes_read == 0) break;
        hasher.update(buf[0..bytes_read]);
    }

    hasher.final(bin_digest);
}

/// If the wall clock time, rounded to the same precision as the
/// mtime, is equal to the mtime, then we cannot rely on this mtime
/// yet. We will instead save an mtime value that indicates the hash
/// must be unconditionally computed.
/// This function recognizes the precision of mtime by looking at trailing
/// zero bits of the seconds and nanoseconds.
fn isProblematicTimestamp(fs_clock: i128) bool {
    const wall_clock = std.time.nanoTimestamp();

    // We have to break the nanoseconds into seconds and remainder nanoseconds
    // to detect precision of seconds, because looking at the zero bits in base
    // 2 would not detect precision of the seconds value.
    const fs_sec = @intCast(i64, @divFloor(fs_clock, std.time.ns_per_s));
    const fs_nsec = @intCast(i64, @mod(fs_clock, std.time.ns_per_s));
    var wall_sec = @intCast(i64, @divFloor(wall_clock, std.time.ns_per_s));
    var wall_nsec = @intCast(i64, @mod(wall_clock, std.time.ns_per_s));

    // First make all the least significant zero bits in the fs_clock, also zero bits in the wall clock.
    if (fs_nsec == 0) {
        wall_nsec = 0;
        if (fs_sec == 0) {
            wall_sec = 0;
        } else {
            wall_sec &= @as(i64, -1) << @intCast(u6, @ctz(i64, fs_sec));
        }
    } else {
        wall_nsec &= @as(i64, -1) << @intCast(u6, @ctz(i64, fs_nsec));
    }
    return wall_nsec == fs_nsec and wall_sec == fs_sec;
}

test "cache file and then recall it" {
    if (std.Target.current.os.tag == .wasi) {
        // https://github.com/ziglang/zig/issues/5437
        return error.SkipZigTest;
    }
    const cwd = fs.cwd();

    const temp_file = "test.txt";
    const temp_manifest_dir = "temp_manifest_dir";

    const ts = std.time.nanoTimestamp();
    try cwd.writeFile(temp_file, "Hello, world!\n");

    while (isProblematicTimestamp(ts)) {
        std.time.sleep(1);
    }

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add(true);
        ch.add(@as(u16, 1234));
        ch.add("1234");
        _ = try ch.addFile(temp_file, null);

        // There should be nothing in the cache
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        digest1 = ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add(true);
        ch.add(@as(u16, 1234));
        ch.add("1234");
        _ = try ch.addFile(temp_file, null);

        // Cache hit! We just "built" the same file
        digest2 = (try ch.hit()).?;
    }

    testing.expectEqual(digest1, digest2);

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteFile(temp_file);
}

test "give problematic timestamp" {
    var fs_clock = std.time.nanoTimestamp();
    // to make it problematic, we make it only accurate to the second
    fs_clock = @divTrunc(fs_clock, std.time.ns_per_s);
    fs_clock *= std.time.ns_per_s;
    testing.expect(isProblematicTimestamp(fs_clock));
}

test "give nonproblematic timestamp" {
    testing.expect(!isProblematicTimestamp(std.time.nanoTimestamp() - std.time.ns_per_s));
}

test "check that changing a file makes cache fail" {
    if (std.Target.current.os.tag == .wasi) {
        // https://github.com/ziglang/zig/issues/5437
        return error.SkipZigTest;
    }
    const cwd = fs.cwd();

    const temp_file = "cache_hash_change_file_test.txt";
    const temp_manifest_dir = "cache_hash_change_file_manifest_dir";
    const original_temp_file_contents = "Hello, world!\n";
    const updated_temp_file_contents = "Hello, world; but updated!\n";

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteTree(temp_file);

    const ts = std.time.nanoTimestamp();
    try cwd.writeFile(temp_file, original_temp_file_contents);

    while (isProblematicTimestamp(ts)) {
        std.time.sleep(1);
    }

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        const temp_file_idx = try ch.addFile(temp_file, 100);

        // There should be nothing in the cache
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        testing.expect(mem.eql(u8, original_temp_file_contents, ch.files.items[temp_file_idx].contents.?));

        digest1 = ch.final();
    }

    try cwd.writeFile(temp_file, updated_temp_file_contents);

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        const temp_file_idx = try ch.addFile(temp_file, 100);

        // A file that we depend on has been updated, so the cache should not contain an entry for it
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        // The cache system does not keep the contents of re-hashed input files.
        testing.expect(ch.files.items[temp_file_idx].contents == null);

        digest2 = ch.final();
    }

    testing.expect(!mem.eql(u8, digest1[0..], digest2[0..]));

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteTree(temp_file);
}

test "no file inputs" {
    if (std.Target.current.os.tag == .wasi) {
        // https://github.com/ziglang/zig/issues/5437
        return error.SkipZigTest;
    }
    const cwd = fs.cwd();
    const temp_manifest_dir = "no_file_inputs_manifest_dir";
    defer cwd.deleteTree(temp_manifest_dir) catch unreachable;

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");

        // There should be nothing in the cache
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        digest1 = ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");

        digest2 = (try ch.hit()).?;
    }

    testing.expectEqual(digest1, digest2);
}

test "CacheHashes with files added after initial hash work" {
    if (std.Target.current.os.tag == .wasi) {
        // https://github.com/ziglang/zig/issues/5437
        return error.SkipZigTest;
    }
    const cwd = fs.cwd();

    const temp_file1 = "cache_hash_post_file_test1.txt";
    const temp_file2 = "cache_hash_post_file_test2.txt";
    const temp_manifest_dir = "cache_hash_post_file_manifest_dir";

    const ts1 = std.time.nanoTimestamp();
    try cwd.writeFile(temp_file1, "Hello, world!\n");
    try cwd.writeFile(temp_file2, "Hello world the second!\n");

    while (isProblematicTimestamp(ts1)) {
        std.time.sleep(1);
    }

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest3: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        _ = try ch.addFile(temp_file1, null);

        // There should be nothing in the cache
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        _ = try ch.addFilePost(temp_file2);

        digest1 = ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        _ = try ch.addFile(temp_file1, null);

        digest2 = (try ch.hit()).?;
    }
    testing.expect(mem.eql(u8, &digest1, &digest2));

    // Modify the file added after initial hash
    const ts2 = std.time.nanoTimestamp();
    try cwd.writeFile(temp_file2, "Hello world the second, updated\n");

    while (isProblematicTimestamp(ts2)) {
        std.time.sleep(1);
    }

    {
        var ch = try CacheHash.init(testing.allocator, cwd, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        _ = try ch.addFile(temp_file1, null);

        // A file that we depend on has been updated, so the cache should not contain an entry for it
        testing.expectEqual(@as(?[BASE64_DIGEST_LEN]u8, null), try ch.hit());

        _ = try ch.addFilePost(temp_file2);

        digest3 = ch.final();
    }

    testing.expect(!mem.eql(u8, &digest1, &digest3));

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteFile(temp_file1);
    try cwd.deleteFile(temp_file2);
}
