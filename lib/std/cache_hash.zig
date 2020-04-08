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

const base64_encoder = fs.base64_encoder;
const base64_decoder = fs.base64_decoder;
const BIN_DIGEST_LEN = 48;
const BASE64_DIGEST_LEN = base64.Base64Encoder.calcSize(BIN_DIGEST_LEN);

pub const File = struct {
    path: ?[]const u8,
    stat: fs.File.Stat,
    bin_digest: [BIN_DIGEST_LEN]u8,
    contents: ?[]const u8,

    pub fn deinit(self: *@This(), alloc: *Allocator) void {
        if (self.path) |owned_slice| {
            alloc.free(owned_slice);
            self.path = null;
        }
        if (self.contents) |owned_slice| {
            alloc.free(owned_slice);
            self.contents = null;
        }
    }
};

pub const CacheHash = struct {
    alloc: *Allocator,
    blake3: Blake3,
    manifest_dir: fs.Dir,
    manifest_file: ?fs.File,
    manifest_dirty: bool,
    force_check_manifest: bool,
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
            .force_check_manifest = false,
            .files = ArrayList(File).init(alloc),
            .b64_digest = undefined,
        };
    }

    pub fn addSlice(self: *@This(), val: []const u8) void {
        debug.assert(self.manifest_file == null);

        self.blake3.update(val);
        self.blake3.update(&[_]u8{0});
    }

    pub fn addBool(self: *@This(), val: bool) void {
        debug.assert(self.manifest_file == null);
        self.blake3.update(&[_]u8{@boolToInt(val)});
    }

    pub fn addInt(self: *@This(), val: var) void {
        debug.assert(self.manifest_file == null);

        switch (@typeInfo(@TypeOf(val))) {
            .Int => |int_info| {
                if (int_info.bits == 0 or int_info.bits % 8 != 0) {
                    @compileError("Unsupported integer size. Please use a multiple of 8, manually convert to a u8 slice.");
                }

                const buf_len = @divExact(int_info.bits, 8);
                var buf: [buf_len]u8 = undefined;
                mem.writeIntNative(@TypeOf(val), &buf, val);
                self.addSlice(&buf);

                self.blake3.update(&[_]u8{0});
            },
            else => @compileError("Type must be an integer."),
        }
    }

    pub fn add(self: *@This(), val: var) void {
        debug.assert(self.manifest_file == null);

        const val_type = @TypeOf(val);
        switch (@typeInfo(val_type)) {
            .Int => self.addInt(val),
            .Bool => self.addBool(val),
            .Array => |array_info| if (array_info.child == u8) {
                self.addSlice(val[0..]);
            } else {
                @compileError("Unsupported array type");
            },
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Slice => if (ptr_info.child == u8) {
                    self.addSlice(val);
                },
                .One => self.add(val.*),
                else => {
                    @compileLog("Pointer type: ", ptr_info.size, ptr_info.child);
                    @compileError("Unsupported pointer type");
                },
            },
            else => @compileError("Unsupported type"),
        }
    }

    pub fn addFile(self: *@This(), file_path: []const u8) !void {
        debug.assert(self.manifest_file == null);

        var cache_hash_file = try self.files.addOne();
        cache_hash_file.path = try fs.path.resolve(self.alloc, &[_][]const u8{file_path});

        self.addSlice(cache_hash_file.path.?);
    }

    pub fn hit(self: *@This()) !?[BASE64_DIGEST_LEN]u8 {
        debug.assert(self.manifest_file == null);

        var bin_digest: [BIN_DIGEST_LEN]u8 = undefined;
        self.blake3.final(&bin_digest);

        base64_encoder.encode(self.b64_digest[0..], &bin_digest);

        if (self.files.toSlice().len == 0 and !self.force_check_manifest) {
            return self.b64_digest;
        }

        self.blake3 = Blake3.init();
        self.blake3.update(&bin_digest);

        {
            const manifest_file_path = try fmt.allocPrint(self.alloc, "{}.txt", .{self.b64_digest});
            defer self.alloc.free(manifest_file_path);

            self.manifest_file = try self.manifest_dir.createFile(manifest_file_path, .{ .read = true, .truncate = false });
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
            const mtime_nsec_str = iter.next() orelse return error.InvalidFormat;
            const digest_str = iter.next() orelse return error.InvalidFormat;
            const file_path = iter.rest();

            cache_hash_file.stat.mtime = fmt.parseInt(i64, mtime_nsec_str, 10) catch return error.InvalidFormat;
            base64_decoder.decode(&cache_hash_file.bin_digest, digest_str) catch return error.InvalidFormat;

            if (file_path.len == 0) {
                return error.InvalidFormat;
            }
            if (cache_hash_file.path != null and !mem.eql(u8, file_path, cache_hash_file.path.?)) {
                return error.InvalidFormat;
            }

            const this_file = fs.cwd().openFile(cache_hash_file.path.?, .{ .read = true }) catch {
                self.manifest_file.?.close();
                self.manifest_file = null;
                return error.CacheUnavailable;
            };
            defer this_file.close();

            const actual_stat = try this_file.stat();
            const mtime_matches = actual_stat.mtime == cache_hash_file.stat.mtime;

            // TODO: check inode
            if (!mtime_matches) {
                self.manifest_dirty = true;

                cache_hash_file.stat = actual_stat;

                // TODO: check for problematic timestamp

                var actual_digest: [BIN_DIGEST_LEN]u8 = undefined;
                try hash_file(self.alloc, &actual_digest, &this_file);

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
            // keep the manifest file open (TODO: with rw lock)
            // reset the hash
            self.blake3 = Blake3.init();
            self.blake3.update(&bin_digest);
            try self.files.resize(input_file_count);
            for (self.files.toSlice()) |file| {
                self.blake3.update(&file.bin_digest);
            }
            return null;
        }

        if (idx < input_file_count or idx == 0) {
            self.manifest_dirty = true;
            while (idx < input_file_count) : (idx += 1) {
                var cache_hash_file = self.files.ptrAt(idx);
                self.populate_file_hash(cache_hash_file) catch |err| {
                    self.manifest_file.?.close();
                    self.manifest_file = null;
                    return error.CacheUnavailable;
                };
            }
            return null;
        }

        return try self.final();
    }

    pub fn populate_file_hash(self: *@This(), cache_hash_file: *File) !void {
        debug.assert(cache_hash_file.path != null);

        const this_file = try fs.cwd().openFile(cache_hash_file.path.?, .{});
        defer this_file.close();

        cache_hash_file.stat = try this_file.stat();

        // TODO: check for problematic timestamp

        try hash_file(self.alloc, &cache_hash_file.bin_digest, &this_file);
        self.blake3.update(&cache_hash_file.bin_digest);
    }

    pub fn final(self: *@This()) ![BASE64_DIGEST_LEN]u8 {
        debug.assert(self.manifest_file != null);

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
            try outStream.print("{} {} {}\n", .{ file.stat.mtime, encoded_digest[0..], file.path });
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

fn hash_file(alloc: *Allocator, bin_digest: []u8, handle: *const fs.File) !void {
    var blake3 = Blake3.init();

    const contents = try handle.inStream().readAllAlloc(alloc, 64 * 1024);
    defer alloc.free(contents);

    blake3.update(contents);

    blake3.final(bin_digest);
}

test "cache file and the recall it" {
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
        try ch.addFile("test.txt");

        // There should be nothing in the cache
        debug.assert((try ch.hit()) == null);

        digest1 = try ch.final();
    }
    {
        var ch = try CacheHash.init(testing.allocator, temp_manifest_dir);
        defer ch.release();

        ch.add(true);
        ch.add(@as(u16, 1234));
        ch.add("1234");
        try ch.addFile("test.txt");

        // Cache hit! We just "built" the same file
        digest2 = (try ch.hit()).?;
    }

    debug.assert(mem.eql(u8, digest1[0..], digest2[0..]));

    try cwd.deleteTree(temp_manifest_dir);
    try cwd.deleteFile(temp_file);
}
