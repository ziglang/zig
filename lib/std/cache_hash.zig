const Blake3 = @import("crypto.zig").Blake3;
const fs = @import("fs.zig");
const base64 = @import("base64.zig");
const ArrayList = @import("array_list.zig").ArrayList;
const debug = @import("debug.zig");
const testing = @import("testing.zig");
const mem = @import("mem.zig");
const fmt = @import("fmt.zig");
const Allocator = mem.Allocator;
const os = @import("os.zig");
const time = @import("time.zig");

const base64_encoder = fs.base64_encoder;
const base64_decoder = fs.base64_decoder;
const BIN_DIGEST_LEN = 48;
const BASE64_DIGEST_LEN = base64.Base64Encoder.calcSize(BIN_DIGEST_LEN);

pub const File = struct {
    path: ?[]const u8,
    stat: fs.File.Stat,
    bin_digest: [BIN_DIGEST_LEN]u8,

    pub fn deinit(self: *@This(), alloc: *Allocator) void {
        if (self.path) |owned_slice| {
            alloc.free(owned_slice);
            self.path = null;
        }
    }
};

pub const CacheHash = struct {
    alloc: *Allocator,
    blake3: Blake3,
    manifest_dir: fs.Dir,
    manifest_file: ?fs.File,
    manifest_dirty: bool,
    files: ArrayList(File),
    b64_digest: [BASE64_DIGEST_LEN]u8,

    pub fn init(alloc: *Allocator, manifest_dir_path: []const u8) !@This() {
        try fs.cwd().makePath(manifest_dir_path);
        const manifest_dir = try fs.cwd().openDir(manifest_dir_path, .{ .iterate = true });

        return CacheHash{
            .alloc = alloc,
            .blake3 = Blake3.init(),
            .manifest_dir = manifest_dir,
            .manifest_file = null,
            .manifest_dirty = false,
            .files = ArrayList(File).init(alloc),
            .b64_digest = undefined,
        };
    }

    /// Record a slice of bytes as an dependency of the process being cached
    pub fn addSlice(self: *@This(), val: []const u8) void {
        debug.assert(self.manifest_file == null);

        self.blake3.update(val);
        self.blake3.update(&[_]u8{0});
    }

    /// Convert the input value into bytes and record it as a dependency of the
    /// process being cached
    pub fn add(self: *@This(), val: var) void {
        debug.assert(self.manifest_file == null);

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
    pub fn addFile(self: *@This(), file_path: []const u8) !void {
        debug.assert(self.manifest_file == null);

        var cache_hash_file = try self.files.addOne();
        cache_hash_file.path = try fs.path.resolve(self.alloc, &[_][]const u8{file_path});

        self.addSlice(cache_hash_file.path.?);
    }

    /// Check the cache to see if the input exists in it. If it exists, a base64 encoding
    /// of it's hash will be returned; otherwise, null will be returned.
    ///
    /// This function will also acquire an exclusive lock to the manifest file. This means
    /// that a process holding a CacheHash will block any other process attempting to
    /// acquire the lock.
    ///
    /// The lock on the manifest file is released when `CacheHash.release` is called.
    pub fn hit(self: *@This()) !?[BASE64_DIGEST_LEN]u8 {
        debug.assert(self.manifest_file == null);

        var bin_digest: [BIN_DIGEST_LEN]u8 = undefined;
        self.blake3.final(&bin_digest);

        base64_encoder.encode(self.b64_digest[0..], &bin_digest);

        self.blake3 = Blake3.init();
        self.blake3.update(&bin_digest);

        const manifest_file_path = try fmt.allocPrint(self.alloc, "{}.txt", .{self.b64_digest});
        defer self.alloc.free(manifest_file_path);

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

        // TODO: Figure out a good max value?
        const file_contents = try self.manifest_file.?.inStream().readAllAlloc(self.alloc, 16 * 1024);
        defer self.alloc.free(file_contents);

        const input_file_count = self.files.items.len;
        var any_file_changed = false;
        var line_iter = mem.tokenize(file_contents, "\n");
        var idx: usize = 0;
        while (line_iter.next()) |line| {
            defer idx += 1;

            var cache_hash_file: *File = undefined;
            if (idx < input_file_count) {
                cache_hash_file = self.files.ptrAt(idx);
            } else {
                cache_hash_file = try self.files.addOne();
                cache_hash_file.path = null;
            }

            var iter = mem.tokenize(line, " ");
            const inode = iter.next() orelse return error.InvalidFormat;
            const mtime_nsec_str = iter.next() orelse return error.InvalidFormat;
            const digest_str = iter.next() orelse return error.InvalidFormat;
            const file_path = iter.rest();

            cache_hash_file.stat.inode = fmt.parseInt(os.ino_t, mtime_nsec_str, 10) catch return error.InvalidFormat;
            cache_hash_file.stat.mtime = fmt.parseInt(i64, mtime_nsec_str, 10) catch return error.InvalidFormat;
            base64_decoder.decode(&cache_hash_file.bin_digest, digest_str) catch return error.InvalidFormat;

            if (file_path.len == 0) {
                return error.InvalidFormat;
            }
            if (cache_hash_file.path != null and !mem.eql(u8, file_path, cache_hash_file.path.?)) {
                return error.InvalidFormat;
            }

            const this_file = fs.cwd().openFile(cache_hash_file.path.?, .{ .read = true }) catch {
                return error.CacheUnavailable;
            };
            defer this_file.close();

            const actual_stat = try this_file.stat();
            const mtime_match = actual_stat.mtime == cache_hash_file.stat.mtime;
            const inode_match = actual_stat.inode == cache_hash_file.stat.inode;

            if (!mtime_match or !inode_match) {
                self.manifest_dirty = true;

                cache_hash_file.stat = actual_stat;

                if (is_problematic_timestamp(cache_hash_file.stat.mtime)) {
                    cache_hash_file.stat.mtime = 0;
                    cache_hash_file.stat.inode = 0;
                }

                var actual_digest: [BIN_DIGEST_LEN]u8 = undefined;
                const contents = try hash_file(self.alloc, &actual_digest, &this_file);
                self.alloc.free(contents);

                if (!mem.eql(u8, &cache_hash_file.bin_digest, &actual_digest)) {
                    mem.copy(u8, &cache_hash_file.bin_digest, &actual_digest);
                    // keep going until we have the input file digests
                    any_file_changed = true;
                }
            }

            if (!any_file_changed) {
                self.blake3.update(&cache_hash_file.bin_digest);
            }
        }

        if (any_file_changed) {
            // cache miss
            // keep the manifest file open
            // reset the hash
            self.blake3 = Blake3.init();
            self.blake3.update(&bin_digest);
            try self.files.resize(input_file_count);
            for (self.files.toSlice()) |file| {
                self.blake3.update(&file.bin_digest);
            }
            return null;
        }

        if (idx < input_file_count) {
            self.manifest_dirty = true;
            while (idx < input_file_count) : (idx += 1) {
                var cache_hash_file = &self.files.items[idx];
                const contents = self.populate_file_hash(cache_hash_file) catch |err| {
                    return error.CacheUnavailable;
                };
            }
            return null;
        }

        return self.final();
    }

    fn populate_file_hash_fetch(self: *@This(), otherAlloc: *mem.Allocator, cache_hash_file: *File) ![]u8 {
        debug.assert(cache_hash_file.path != null);

        const this_file = try fs.cwd().openFile(cache_hash_file.path.?, .{});
        defer this_file.close();

        cache_hash_file.stat = try this_file.stat();

        if (is_problematic_timestamp(cache_hash_file.stat.mtime)) {
            cache_hash_file.stat.mtime = 0;
            cache_hash_file.stat.inode = 0;
        }

        const contents = try hash_file(otherAlloc, &cache_hash_file.bin_digest, &this_file);
        self.blake3.update(&cache_hash_file.bin_digest);

        return contents;
    }

    fn populate_file_hash(self: *@This(), cache_hash_file: *File) !void {
        const contents = try self.populate_file_hash_fetch(self.alloc, cache_hash_file);
        self.alloc.free(contents);
    }

    /// Add a file as a dependency of process being cached, after the initial hash has been
    /// calculated. Returns the contents of the file, allocated with the given allocator.
    pub fn addFilePostFetch(self: *@This(), otherAlloc: *mem.Allocator, file_path: []const u8) ![]u8 {
        debug.assert(self.manifest_file != null);

        var cache_hash_file = try self.files.addOne();
        cache_hash_file.path = try fs.path.resolve(self.alloc, &[_][]const u8{file_path});

        return try self.populate_file_hash_fetch(otherAlloc, cache_hash_file);
    }

    /// Add a file as a dependency of process being cached, after the initial hash has been
    /// calculated.
    pub fn addFilePost(self: *@This(), file_path: []const u8) !void {
        const contents = try self.addFilePostFetch(self.alloc, file_path);
        self.alloc.free(contents);
    }

    /// Returns a base64 encoded hash of the inputs.
    pub fn final(self: *@This()) [BASE64_DIGEST_LEN]u8 {
        debug.assert(self.manifest_file != null);

        // We don't close the manifest file yet, because we want to
        // keep it locked until the API user is done using it.
        // We also don't write out the manifest yet, because until
        // cache_release is called we still might be working on creating
        // the artifacts to cache.

        var bin_digest: [BIN_DIGEST_LEN]u8 = undefined;
        self.blake3.final(&bin_digest);

        var out_digest: [BASE64_DIGEST_LEN]u8 = undefined;
        base64_encoder.encode(&out_digest, &bin_digest);

        return out_digest;
    }

    pub fn write_manifest(self: *@This()) !void {
        debug.assert(self.manifest_file != null);

        var encoded_digest: [BASE64_DIGEST_LEN]u8 = undefined;
        var contents = ArrayList(u8).init(self.alloc);
        var outStream = contents.outStream();
        defer contents.deinit();

        for (self.files.toSlice()) |file| {
            base64_encoder.encode(encoded_digest[0..], &file.bin_digest);
            try outStream.print("{} {} {} {}\n", .{ file.stat.inode, file.stat.mtime, encoded_digest[0..], file.path });
        }

        try self.manifest_file.?.seekTo(0);
        try self.manifest_file.?.writeAll(contents.items);
    }

    pub fn release(self: *@This()) void {
        debug.assert(self.manifest_file != null);

        if (self.manifest_dirty) {
            self.write_manifest() catch |err| {
                debug.warn("Unable to write cache file '{}': {}\n", .{ self.b64_digest, err });
            };
        }

        self.manifest_file.?.close();

        for (self.files.toSlice()) |*file| {
            file.deinit(self.alloc);
        }
        self.files.deinit();
        self.manifest_dir.close();
    }
};

/// Hash the file, and return the contents as an array
fn hash_file(alloc: *Allocator, bin_digest: []u8, handle: *const fs.File) ![]u8 {
    var blake3 = Blake3.init();

    const contents = try handle.inStream().readAllAlloc(alloc, 64 * 1024);

    blake3.update(contents);

    blake3.final(bin_digest);

    return contents;
}

/// If the wall clock time, rounded to the same precision as the
/// mtime, is equal to the mtime, then we cannot rely on this mtime
/// yet. We will instead save an mtime value that indicates the hash
/// must be unconditionally computed.
fn is_problematic_timestamp(file_mtime_ns: i64) bool {
    const now_ms = time.milliTimestamp();
    const file_mtime_ms = @divFloor(file_mtime_ns, time.millisecond);
    return now_ms == file_mtime_ms;
}

test "cache file and then recall it" {
    const cwd = fs.cwd();

    const temp_file = "test.txt";
    const temp_manifest_dir = "temp_manifest_dir";

    try cwd.writeFile(temp_file, "Hello, world!\n");

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add(true);
        ch.add(@as(u16, 1234));
        ch.add("1234");
        try ch.addFile(temp_file);

        // There should be nothing in the cache
        testing.expectEqual(@as(?[64]u8, null), try ch.hit());

        digest1 = ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add(true);
        ch.add(@as(u16, 1234));
        ch.add("1234");
        try ch.addFile(temp_file);

        // Cache hit! We just "built" the same file
        digest2 = (try ch.hit()).?;
    }

    testing.expectEqual(digest1, digest2);

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteFile(temp_file);
}

test "give problematic timestamp" {
    const now_ns = @intCast(i64, time.milliTimestamp() * time.millisecond);
    testing.expect(is_problematic_timestamp(now_ns));
}

test "give nonproblematic timestamp" {
    const now_ns = @intCast(i64, time.milliTimestamp() * time.millisecond) - 1000;
    testing.expect(!is_problematic_timestamp(now_ns));
}

test "check that changing a file makes cache fail" {
    const cwd = fs.cwd();

    const temp_file = "cache_hash_change_file_test.txt";
    const temp_manifest_dir = "cache_hash_change_file_manifest_dir";

    try cwd.writeFile(temp_file, "Hello, world!\n");

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        try ch.addFile(temp_file);

        // There should be nothing in the cache
        testing.expectEqual(@as(?[64]u8, null), try ch.hit());

        digest1 = ch.final();
    }

    try cwd.writeFile(temp_file, "Hello, world; but updated!\n");

    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");
        try ch.addFile(temp_file);

        // A file that we depend on has been updated, so the cache should not contain an entry for it
        testing.expectEqual(@as(?[64]u8, null), try ch.hit());

        digest2 = ch.final();
    }

    testing.expect(!mem.eql(u8, digest1[0..], digest2[0..]));

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteFile(temp_file);
}

test "no file inputs" {
    const cwd = fs.cwd();
    const temp_manifest_dir = "no_file_inputs_manifest_dir";
    defer cwd.deleteTree(temp_manifest_dir) catch unreachable;

    var digest1: [BASE64_DIGEST_LEN]u8 = undefined;
    var digest2: [BASE64_DIGEST_LEN]u8 = undefined;

    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");

        // There should be nothing in the cache
        testing.expectEqual(@as(?[64]u8, null), try ch.hit());

        digest1 = ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add("1234");

        digest2 = (try ch.hit()).?;
    }

    testing.expectEqual(digest1, digest2);
}
