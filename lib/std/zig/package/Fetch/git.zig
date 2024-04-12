//! Git support for package fetching.
//!
//! This is not intended to support all features of Git: it is limited to the
//! basic functionality needed to clone a repository for the purpose of fetching
//! a package.

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;
const Sha1 = std.crypto.hash.Sha1;
const assert = std.debug.assert;

pub const oid_length = Sha1.digest_length;
pub const fmt_oid_length = 2 * oid_length;
/// The ID of a Git object (an SHA-1 hash).
pub const Oid = [oid_length]u8;

pub fn parseOid(s: []const u8) !Oid {
    if (s.len != fmt_oid_length) return error.InvalidOid;
    var oid: Oid = undefined;
    for (&oid, 0..) |*b, i| {
        b.* = std.fmt.parseUnsigned(u8, s[2 * i ..][0..2], 16) catch return error.InvalidOid;
    }
    return oid;
}

test parseOid {
    try testing.expectEqualSlices(
        u8,
        &.{ 0xCE, 0x91, 0x9C, 0xCF, 0x45, 0x95, 0x18, 0x56, 0xA7, 0x62, 0xFF, 0xDB, 0x8E, 0xF8, 0x50, 0x30, 0x1C, 0xD8, 0xC5, 0x88 },
        &try parseOid("ce919ccf45951856a762ffdb8ef850301cd8c588"),
    );
    try testing.expectError(error.InvalidOid, parseOid("ce919ccf"));
    try testing.expectError(error.InvalidOid, parseOid("master"));
    try testing.expectError(error.InvalidOid, parseOid("HEAD"));
}

pub const Diagnostics = struct {
    allocator: Allocator,
    errors: std.ArrayListUnmanaged(Error) = .{},

    pub const Error = union(enum) {
        unable_to_create_sym_link: struct {
            code: anyerror,
            file_name: []const u8,
            link_name: []const u8,
        },
        unable_to_create_file: struct {
            code: anyerror,
            file_name: []const u8,
        },
    };

    pub fn deinit(d: *Diagnostics) void {
        for (d.errors.items) |item| {
            switch (item) {
                .unable_to_create_sym_link => |info| {
                    d.allocator.free(info.file_name);
                    d.allocator.free(info.link_name);
                },
                .unable_to_create_file => |info| {
                    d.allocator.free(info.file_name);
                },
            }
        }
        d.errors.deinit(d.allocator);
        d.* = undefined;
    }
};

pub const Repository = struct {
    odb: Odb,

    pub fn init(allocator: Allocator, pack_file: std.fs.File, index_file: std.fs.File) !Repository {
        return .{ .odb = try Odb.init(allocator, pack_file, index_file) };
    }

    pub fn deinit(repository: *Repository) void {
        repository.odb.deinit();
        repository.* = undefined;
    }

    /// Checks out the repository at `commit_oid` to `worktree`.
    pub fn checkout(
        repository: *Repository,
        worktree: std.fs.Dir,
        commit_oid: Oid,
        diagnostics: *Diagnostics,
    ) !void {
        try repository.odb.seekOid(commit_oid);
        const tree_oid = tree_oid: {
            const commit_object = try repository.odb.readObject();
            if (commit_object.type != .commit) return error.NotACommit;
            break :tree_oid try getCommitTree(commit_object.data);
        };
        try repository.checkoutTree(worktree, tree_oid, "", diagnostics);
    }

    /// Checks out the tree at `tree_oid` to `worktree`.
    fn checkoutTree(
        repository: *Repository,
        dir: std.fs.Dir,
        tree_oid: Oid,
        current_path: []const u8,
        diagnostics: *Diagnostics,
    ) !void {
        try repository.odb.seekOid(tree_oid);
        const tree_object = try repository.odb.readObject();
        if (tree_object.type != .tree) return error.NotATree;
        // The tree object may be evicted from the object cache while we're
        // iterating over it, so we can make a defensive copy here to make sure
        // it remains valid until we're done with it
        const tree_data = try repository.odb.allocator.dupe(u8, tree_object.data);
        defer repository.odb.allocator.free(tree_data);

        var tree_iter: TreeIterator = .{ .data = tree_data };
        while (try tree_iter.next()) |entry| {
            switch (entry.type) {
                .directory => {
                    try dir.makeDir(entry.name);
                    var subdir = try dir.openDir(entry.name, .{});
                    defer subdir.close();
                    const sub_path = try std.fs.path.join(repository.odb.allocator, &.{ current_path, entry.name });
                    defer repository.odb.allocator.free(sub_path);
                    try repository.checkoutTree(subdir, entry.oid, sub_path, diagnostics);
                },
                .file => {
                    try repository.odb.seekOid(entry.oid);
                    const file_object = try repository.odb.readObject();
                    if (file_object.type != .blob) return error.InvalidFile;
                    var file = dir.createFile(entry.name, .{ .exclusive = true }) catch |e| {
                        const file_name = try std.fs.path.join(diagnostics.allocator, &.{ current_path, entry.name });
                        errdefer diagnostics.allocator.free(file_name);
                        try diagnostics.errors.append(diagnostics.allocator, .{ .unable_to_create_file = .{
                            .code = e,
                            .file_name = file_name,
                        } });
                        continue;
                    };
                    defer file.close();
                    try file.writeAll(file_object.data);
                    try file.sync();
                },
                .symlink => {
                    try repository.odb.seekOid(entry.oid);
                    const symlink_object = try repository.odb.readObject();
                    if (symlink_object.type != .blob) return error.InvalidFile;
                    const link_name = symlink_object.data;
                    dir.symLink(link_name, entry.name, .{}) catch |e| {
                        const file_name = try std.fs.path.join(diagnostics.allocator, &.{ current_path, entry.name });
                        errdefer diagnostics.allocator.free(file_name);
                        const link_name_dup = try diagnostics.allocator.dupe(u8, link_name);
                        errdefer diagnostics.allocator.free(link_name_dup);
                        try diagnostics.errors.append(diagnostics.allocator, .{ .unable_to_create_sym_link = .{
                            .code = e,
                            .file_name = file_name,
                            .link_name = link_name_dup,
                        } });
                    };
                },
                .gitlink => {
                    // Consistent with git archive behavior, create the directory but
                    // do nothing else
                    try dir.makeDir(entry.name);
                },
            }
        }
    }

    /// Returns the ID of the tree associated with the given commit (provided as
    /// raw object data).
    fn getCommitTree(commit_data: []const u8) !Oid {
        if (!mem.startsWith(u8, commit_data, "tree ") or
            commit_data.len < "tree ".len + fmt_oid_length + "\n".len or
            commit_data["tree ".len + fmt_oid_length] != '\n')
        {
            return error.InvalidCommit;
        }
        return try parseOid(commit_data["tree ".len..][0..fmt_oid_length]);
    }

    const TreeIterator = struct {
        data: []const u8,
        pos: usize = 0,

        const Entry = struct {
            type: Type,
            executable: bool,
            name: [:0]const u8,
            oid: Oid,

            const Type = enum(u4) {
                directory = 0o4,
                file = 0o10,
                symlink = 0o12,
                gitlink = 0o16,
            };
        };

        fn next(iterator: *TreeIterator) !?Entry {
            if (iterator.pos == iterator.data.len) return null;

            const mode_end = mem.indexOfScalarPos(u8, iterator.data, iterator.pos, ' ') orelse return error.InvalidTree;
            const mode: packed struct {
                permission: u9,
                unused: u3,
                type: u4,
            } = @bitCast(std.fmt.parseUnsigned(u16, iterator.data[iterator.pos..mode_end], 8) catch return error.InvalidTree);
            const @"type" = std.meta.intToEnum(Entry.Type, mode.type) catch return error.InvalidTree;
            const executable = switch (mode.permission) {
                0 => if (@"type" == .file) return error.InvalidTree else false,
                0o644 => if (@"type" != .file) return error.InvalidTree else false,
                0o755 => if (@"type" != .file) return error.InvalidTree else true,
                else => return error.InvalidTree,
            };
            iterator.pos = mode_end + 1;

            const name_end = mem.indexOfScalarPos(u8, iterator.data, iterator.pos, 0) orelse return error.InvalidTree;
            const name = iterator.data[iterator.pos..name_end :0];
            iterator.pos = name_end + 1;

            if (iterator.pos + oid_length > iterator.data.len) return error.InvalidTree;
            const oid = iterator.data[iterator.pos..][0..oid_length].*;
            iterator.pos += oid_length;

            return .{ .type = @"type", .executable = executable, .name = name, .oid = oid };
        }
    };
};

/// A Git object database backed by a packfile. A packfile index is also used
/// for efficient access to objects in the packfile.
///
/// The format of the packfile and its associated index are documented in
/// [pack-format](https://git-scm.com/docs/pack-format).
const Odb = struct {
    pack_file: std.fs.File,
    index_header: IndexHeader,
    index_file: std.fs.File,
    cache: ObjectCache = .{},
    allocator: Allocator,

    /// Initializes the database from open pack and index files.
    fn init(allocator: Allocator, pack_file: std.fs.File, index_file: std.fs.File) !Odb {
        try pack_file.seekTo(0);
        try index_file.seekTo(0);
        const index_header = try IndexHeader.read(index_file.reader());
        return .{
            .pack_file = pack_file,
            .index_header = index_header,
            .index_file = index_file,
            .allocator = allocator,
        };
    }

    fn deinit(odb: *Odb) void {
        odb.cache.deinit(odb.allocator);
        odb.* = undefined;
    }

    /// Reads the object at the current position in the database.
    fn readObject(odb: *Odb) !Object {
        var base_offset = try odb.pack_file.getPos();
        var base_header: EntryHeader = undefined;
        var delta_offsets = std.ArrayListUnmanaged(u64){};
        defer delta_offsets.deinit(odb.allocator);
        const base_object = while (true) {
            if (odb.cache.get(base_offset)) |base_object| break base_object;

            base_header = try EntryHeader.read(odb.pack_file.reader());
            switch (base_header) {
                .ofs_delta => |ofs_delta| {
                    try delta_offsets.append(odb.allocator, base_offset);
                    base_offset = std.math.sub(u64, base_offset, ofs_delta.offset) catch return error.InvalidFormat;
                    try odb.pack_file.seekTo(base_offset);
                },
                .ref_delta => |ref_delta| {
                    try delta_offsets.append(odb.allocator, base_offset);
                    try odb.seekOid(ref_delta.base_object);
                    base_offset = try odb.pack_file.getPos();
                },
                else => {
                    const base_data = try readObjectRaw(odb.allocator, odb.pack_file.reader(), base_header.uncompressedLength());
                    errdefer odb.allocator.free(base_data);
                    const base_object: Object = .{ .type = base_header.objectType(), .data = base_data };
                    try odb.cache.put(odb.allocator, base_offset, base_object);
                    break base_object;
                },
            }
        };

        const base_data = try resolveDeltaChain(
            odb.allocator,
            odb.pack_file,
            base_object,
            delta_offsets.items,
            &odb.cache,
        );

        return .{ .type = base_object.type, .data = base_data };
    }

    /// Seeks to the beginning of the object with the given ID.
    fn seekOid(odb: *Odb, oid: Oid) !void {
        const key = oid[0];
        var start_index = if (key > 0) odb.index_header.fan_out_table[key - 1] else 0;
        var end_index = odb.index_header.fan_out_table[key];
        const found_index = while (start_index < end_index) {
            const mid_index = start_index + (end_index - start_index) / 2;
            try odb.index_file.seekTo(IndexHeader.size + mid_index * oid_length);
            const mid_oid = try odb.index_file.reader().readBytesNoEof(oid_length);
            switch (mem.order(u8, &mid_oid, &oid)) {
                .lt => start_index = mid_index + 1,
                .gt => end_index = mid_index,
                .eq => break mid_index,
            }
        } else return error.ObjectNotFound;

        const n_objects = odb.index_header.fan_out_table[255];
        const offset_values_start = IndexHeader.size + n_objects * (oid_length + 4);
        try odb.index_file.seekTo(offset_values_start + found_index * 4);
        const l1_offset: packed struct { value: u31, big: bool } = @bitCast(try odb.index_file.reader().readInt(u32, .big));
        const pack_offset = pack_offset: {
            if (l1_offset.big) {
                const l2_offset_values_start = offset_values_start + n_objects * 4;
                try odb.index_file.seekTo(l2_offset_values_start + l1_offset.value * 4);
                break :pack_offset try odb.index_file.reader().readInt(u64, .big);
            } else {
                break :pack_offset l1_offset.value;
            }
        };

        try odb.pack_file.seekTo(pack_offset);
    }
};

const Object = struct {
    type: Type,
    data: []const u8,

    const Type = enum {
        commit,
        tree,
        blob,
        tag,
    };
};

/// A cache for object data.
///
/// The purpose of this cache is to speed up resolution of deltas by caching the
/// results of resolving delta objects, while maintaining a maximum cache size
/// to avoid excessive memory usage. If the total size of the objects in the
/// cache exceeds the maximum, the cache will begin evicting the least recently
/// used objects: when resolving delta chains, the most recently used objects
/// will likely be more helpful as they will be further along in the chain
/// (skipping earlier reconstruction steps).
///
/// Object data stored in the cache is managed by the cache. It should not be
/// freed by the caller at any point after inserting it into the cache. Any
/// objects remaining in the cache will be freed when the cache itself is freed.
const ObjectCache = struct {
    objects: std.AutoHashMapUnmanaged(u64, CacheEntry) = .{},
    lru_nodes: LruList = .{},
    byte_size: usize = 0,

    const max_byte_size = 128 * 1024 * 1024; // 128MiB
    /// A list of offsets stored in the cache, with the most recently used
    /// entries at the end.
    const LruList = std.DoublyLinkedList(u64);
    const CacheEntry = struct { object: Object, lru_node: *LruList.Node };

    fn deinit(cache: *ObjectCache, allocator: Allocator) void {
        var object_iterator = cache.objects.iterator();
        while (object_iterator.next()) |object| {
            allocator.free(object.value_ptr.object.data);
            allocator.destroy(object.value_ptr.lru_node);
        }
        cache.objects.deinit(allocator);
        cache.* = undefined;
    }

    /// Gets an object from the cache, moving it to the most recently used
    /// position if it is present.
    fn get(cache: *ObjectCache, offset: u64) ?Object {
        if (cache.objects.get(offset)) |entry| {
            cache.lru_nodes.remove(entry.lru_node);
            cache.lru_nodes.append(entry.lru_node);
            return entry.object;
        } else {
            return null;
        }
    }

    /// Puts an object in the cache, possibly evicting older entries if the
    /// cache exceeds its maximum size. Note that, although old objects may
    /// be evicted, the object just added to the cache with this function
    /// will not be evicted before the next call to `put` or `deinit` even if
    /// it exceeds the maximum cache size.
    fn put(cache: *ObjectCache, allocator: Allocator, offset: u64, object: Object) !void {
        const lru_node = try allocator.create(LruList.Node);
        errdefer allocator.destroy(lru_node);
        lru_node.data = offset;

        const gop = try cache.objects.getOrPut(allocator, offset);
        if (gop.found_existing) {
            cache.byte_size -= gop.value_ptr.object.data.len;
            cache.lru_nodes.remove(gop.value_ptr.lru_node);
            allocator.destroy(gop.value_ptr.lru_node);
            allocator.free(gop.value_ptr.object.data);
        }
        gop.value_ptr.* = .{ .object = object, .lru_node = lru_node };
        cache.byte_size += object.data.len;
        cache.lru_nodes.append(lru_node);

        while (cache.byte_size > max_byte_size and cache.lru_nodes.len > 1) {
            // The > 1 check is to make sure that we don't evict the most
            // recently added node, even if it by itself happens to exceed the
            // maximum size of the cache.
            const evict_node = cache.lru_nodes.popFirst().?;
            const evict_offset = evict_node.data;
            allocator.destroy(evict_node);
            const evict_object = cache.objects.get(evict_offset).?.object;
            cache.byte_size -= evict_object.data.len;
            allocator.free(evict_object.data);
            _ = cache.objects.remove(evict_offset);
        }
    }
};

/// A single pkt-line in the Git protocol.
///
/// The format of a pkt-line is documented in
/// [protocol-common](https://git-scm.com/docs/protocol-common). The special
/// meanings of the delimiter and response-end packets are documented in
/// [protocol-v2](https://git-scm.com/docs/protocol-v2).
const Packet = union(enum) {
    flush,
    delimiter,
    response_end,
    data: []const u8,

    const max_data_length = 65516;

    /// Reads a packet in pkt-line format.
    fn read(reader: anytype, buf: *[max_data_length]u8) !Packet {
        const length = std.fmt.parseUnsigned(u16, &try reader.readBytesNoEof(4), 16) catch return error.InvalidPacket;
        switch (length) {
            0 => return .flush,
            1 => return .delimiter,
            2 => return .response_end,
            3 => return error.InvalidPacket,
            else => if (length - 4 > max_data_length) return error.InvalidPacket,
        }
        const data = buf[0 .. length - 4];
        try reader.readNoEof(data);
        return .{ .data = data };
    }

    /// Writes a packet in pkt-line format.
    fn write(packet: Packet, writer: anytype) !void {
        switch (packet) {
            .flush => try writer.writeAll("0000"),
            .delimiter => try writer.writeAll("0001"),
            .response_end => try writer.writeAll("0002"),
            .data => |data| {
                assert(data.len <= max_data_length);
                try writer.print("{x:0>4}", .{data.len + 4});
                try writer.writeAll(data);
            },
        }
    }

    /// Returns the normalized form of textual packet data, stripping any
    /// trailing '\n'.
    ///
    /// As documented in
    /// [protocol-common](https://git-scm.com/docs/protocol-common#_pkt_line_format),
    /// non-binary (textual) pkt-line data should contain a trailing '\n', but
    /// is not required to do so (implementations must support both forms).
    fn normalizeText(data: []const u8) []const u8 {
        return if (mem.endsWith(u8, data, "\n"))
            data[0 .. data.len - 1]
        else
            data;
    }
};

/// A client session for the Git protocol, currently limited to an HTTP(S)
/// transport. Only protocol version 2 is supported, as documented in
/// [protocol-v2](https://git-scm.com/docs/protocol-v2).
pub const Session = struct {
    transport: *std.http.Client,
    uri: std.Uri,
    supports_agent: bool = false,
    supports_shallow: bool = false,

    const agent = "zig/" ++ @import("builtin").zig_version_string;
    const agent_capability = std.fmt.comptimePrint("agent={s}\n", .{agent});

    /// Discovers server capabilities. This should be called before using any
    /// other client functionality, or the client will be forced to default to
    /// the bare minimum server requirements, which may be considerably less
    /// efficient (e.g. no shallow fetches).
    ///
    /// See the note on `getCapabilities` regarding `redirect_uri`.
    pub fn discoverCapabilities(
        session: *Session,
        allocator: Allocator,
        redirect_uri: *[]u8,
        http_headers_buffer: []u8,
    ) !void {
        var capability_iterator = try session.getCapabilities(allocator, redirect_uri, http_headers_buffer);
        defer capability_iterator.deinit();
        while (try capability_iterator.next()) |capability| {
            if (mem.eql(u8, capability.key, "agent")) {
                session.supports_agent = true;
            } else if (mem.eql(u8, capability.key, "fetch")) {
                var feature_iterator = mem.splitScalar(u8, capability.value orelse continue, ' ');
                while (feature_iterator.next()) |feature| {
                    if (mem.eql(u8, feature, "shallow")) {
                        session.supports_shallow = true;
                    }
                }
            }
        }
    }

    /// Returns an iterator over capabilities supported by the server.
    ///
    /// If the server redirects the request, `error.Redirected` is returned and
    /// `redirect_uri` is populated with the URI resulting from the redirects.
    /// When this occurs, the value of `redirect_uri` must be freed with
    /// `allocator` when the caller is done with it.
    fn getCapabilities(
        session: Session,
        allocator: Allocator,
        redirect_uri: *[]u8,
        http_headers_buffer: []u8,
    ) !CapabilityIterator {
        var info_refs_uri = session.uri;
        {
            const session_uri_path = try std.fmt.allocPrint(allocator, "{path}", .{session.uri.path});
            defer allocator.free(session_uri_path);
            info_refs_uri.path = .{ .percent_encoded = try std.fs.path.resolvePosix(allocator, &.{ "/", session_uri_path, "info/refs" }) };
        }
        defer allocator.free(info_refs_uri.path.percent_encoded);
        info_refs_uri.query = .{ .percent_encoded = "service=git-upload-pack" };
        info_refs_uri.fragment = null;

        const max_redirects = 3;
        var request = try session.transport.open(.GET, info_refs_uri, .{
            .redirect_behavior = @enumFromInt(max_redirects),
            .server_header_buffer = http_headers_buffer,
            .extra_headers = &.{
                .{ .name = "Git-Protocol", .value = "version=2" },
            },
        });
        errdefer request.deinit();
        try request.send();
        try request.finish();

        try request.wait();
        if (request.response.status != .ok) return error.ProtocolError;
        const any_redirects_occurred = request.redirect_behavior.remaining() < max_redirects;
        if (any_redirects_occurred) {
            const request_uri_path = try std.fmt.allocPrint(allocator, "{path}", .{request.uri.path});
            defer allocator.free(request_uri_path);
            if (!mem.endsWith(u8, request_uri_path, "/info/refs")) return error.UnparseableRedirect;
            var new_uri = request.uri;
            new_uri.path = .{ .percent_encoded = request_uri_path[0 .. request_uri_path.len - "/info/refs".len] };
            new_uri.query = null;
            redirect_uri.* = try std.fmt.allocPrint(allocator, "{+/}", .{new_uri});
            return error.Redirected;
        }

        const reader = request.reader();
        var buf: [Packet.max_data_length]u8 = undefined;
        var state: enum { response_start, response_content } = .response_start;
        while (true) {
            // Some Git servers (at least GitHub) include an additional
            // '# service=git-upload-pack' informative response before sending
            // the expected 'version 2' packet and capability information.
            // This is not universal: SourceHut, for example, does not do this.
            // Thus, we need to skip any such useless additional responses
            // before we get the one we're actually looking for. The responses
            // will be delimited by flush packets.
            const packet = Packet.read(reader, &buf) catch |e| switch (e) {
                error.EndOfStream => return error.UnsupportedProtocol, // 'version 2' packet not found
                else => |other| return other,
            };
            switch (packet) {
                .flush => state = .response_start,
                .data => |data| switch (state) {
                    .response_start => if (mem.eql(u8, Packet.normalizeText(data), "version 2")) {
                        return .{ .request = request };
                    } else {
                        state = .response_content;
                    },
                    else => {},
                },
                else => return error.UnexpectedPacket,
            }
        }
    }

    const CapabilityIterator = struct {
        request: std.http.Client.Request,
        buf: [Packet.max_data_length]u8 = undefined,

        const Capability = struct {
            key: []const u8,
            value: ?[]const u8 = null,

            fn parse(data: []const u8) Capability {
                return if (mem.indexOfScalar(u8, data, '=')) |separator_pos|
                    .{ .key = data[0..separator_pos], .value = data[separator_pos + 1 ..] }
                else
                    .{ .key = data };
            }
        };

        fn deinit(iterator: *CapabilityIterator) void {
            iterator.request.deinit();
            iterator.* = undefined;
        }

        fn next(iterator: *CapabilityIterator) !?Capability {
            switch (try Packet.read(iterator.request.reader(), &iterator.buf)) {
                .flush => return null,
                .data => |data| return Capability.parse(Packet.normalizeText(data)),
                else => return error.UnexpectedPacket,
            }
        }
    };

    const ListRefsOptions = struct {
        /// The ref prefixes (if any) to use to filter the refs available on the
        /// server. Note that the client must still check the returned refs
        /// against its desired filters itself: the server is not required to
        /// respect these prefix filters and may return other refs as well.
        ref_prefixes: []const []const u8 = &.{},
        /// Whether to include symref targets for returned symbolic refs.
        include_symrefs: bool = false,
        /// Whether to include the peeled object ID for returned tag refs.
        include_peeled: bool = false,
        server_header_buffer: []u8,
    };

    /// Returns an iterator over refs known to the server.
    pub fn listRefs(session: Session, allocator: Allocator, options: ListRefsOptions) !RefIterator {
        var upload_pack_uri = session.uri;
        {
            const session_uri_path = try std.fmt.allocPrint(allocator, "{path}", .{session.uri.path});
            defer allocator.free(session_uri_path);
            upload_pack_uri.path = .{ .percent_encoded = try std.fs.path.resolvePosix(allocator, &.{ "/", session_uri_path, "git-upload-pack" }) };
        }
        defer allocator.free(upload_pack_uri.path.percent_encoded);
        upload_pack_uri.query = null;
        upload_pack_uri.fragment = null;

        var body = std.ArrayListUnmanaged(u8){};
        defer body.deinit(allocator);
        const body_writer = body.writer(allocator);
        try Packet.write(.{ .data = "command=ls-refs\n" }, body_writer);
        if (session.supports_agent) {
            try Packet.write(.{ .data = agent_capability }, body_writer);
        }
        try Packet.write(.delimiter, body_writer);
        for (options.ref_prefixes) |ref_prefix| {
            const ref_prefix_packet = try std.fmt.allocPrint(allocator, "ref-prefix {s}\n", .{ref_prefix});
            defer allocator.free(ref_prefix_packet);
            try Packet.write(.{ .data = ref_prefix_packet }, body_writer);
        }
        if (options.include_symrefs) {
            try Packet.write(.{ .data = "symrefs\n" }, body_writer);
        }
        if (options.include_peeled) {
            try Packet.write(.{ .data = "peel\n" }, body_writer);
        }
        try Packet.write(.flush, body_writer);

        var request = try session.transport.open(.POST, upload_pack_uri, .{
            .redirect_behavior = .unhandled,
            .server_header_buffer = options.server_header_buffer,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/x-git-upload-pack-request" },
                .{ .name = "Git-Protocol", .value = "version=2" },
            },
        });
        errdefer request.deinit();
        request.transfer_encoding = .{ .content_length = body.items.len };
        try request.send();
        try request.writeAll(body.items);
        try request.finish();

        try request.wait();
        if (request.response.status != .ok) return error.ProtocolError;

        return .{ .request = request };
    }

    pub const RefIterator = struct {
        request: std.http.Client.Request,
        buf: [Packet.max_data_length]u8 = undefined,

        pub const Ref = struct {
            oid: Oid,
            name: []const u8,
            symref_target: ?[]const u8,
            peeled: ?Oid,
        };

        pub fn deinit(iterator: *RefIterator) void {
            iterator.request.deinit();
            iterator.* = undefined;
        }

        pub fn next(iterator: *RefIterator) !?Ref {
            switch (try Packet.read(iterator.request.reader(), &iterator.buf)) {
                .flush => return null,
                .data => |data| {
                    const ref_data = Packet.normalizeText(data);
                    const oid_sep_pos = mem.indexOfScalar(u8, ref_data, ' ') orelse return error.InvalidRefPacket;
                    const oid = parseOid(data[0..oid_sep_pos]) catch return error.InvalidRefPacket;

                    const name_sep_pos = mem.indexOfScalarPos(u8, ref_data, oid_sep_pos + 1, ' ') orelse ref_data.len;
                    const name = ref_data[oid_sep_pos + 1 .. name_sep_pos];

                    var symref_target: ?[]const u8 = null;
                    var peeled: ?Oid = null;
                    var last_sep_pos = name_sep_pos;
                    while (last_sep_pos < ref_data.len) {
                        const next_sep_pos = mem.indexOfScalarPos(u8, ref_data, last_sep_pos + 1, ' ') orelse ref_data.len;
                        const attribute = ref_data[last_sep_pos + 1 .. next_sep_pos];
                        if (mem.startsWith(u8, attribute, "symref-target:")) {
                            symref_target = attribute["symref-target:".len..];
                        } else if (mem.startsWith(u8, attribute, "peeled:")) {
                            peeled = parseOid(attribute["peeled:".len..]) catch return error.InvalidRefPacket;
                        }
                        last_sep_pos = next_sep_pos;
                    }

                    return .{ .oid = oid, .name = name, .symref_target = symref_target, .peeled = peeled };
                },
                else => return error.UnexpectedPacket,
            }
        }
    };

    /// Fetches the given refs from the server. A shallow fetch (depth 1) is
    /// performed if the server supports it.
    pub fn fetch(
        session: Session,
        allocator: Allocator,
        wants: []const []const u8,
        http_headers_buffer: []u8,
    ) !FetchStream {
        var upload_pack_uri = session.uri;
        {
            const session_uri_path = try std.fmt.allocPrint(allocator, "{path}", .{session.uri.path});
            defer allocator.free(session_uri_path);
            upload_pack_uri.path = .{ .percent_encoded = try std.fs.path.resolvePosix(allocator, &.{ "/", session_uri_path, "git-upload-pack" }) };
        }
        defer allocator.free(upload_pack_uri.path.percent_encoded);
        upload_pack_uri.query = null;
        upload_pack_uri.fragment = null;

        var body = std.ArrayListUnmanaged(u8){};
        defer body.deinit(allocator);
        const body_writer = body.writer(allocator);
        try Packet.write(.{ .data = "command=fetch\n" }, body_writer);
        if (session.supports_agent) {
            try Packet.write(.{ .data = agent_capability }, body_writer);
        }
        try Packet.write(.delimiter, body_writer);
        // Our packfile parser supports the OFS_DELTA object type
        try Packet.write(.{ .data = "ofs-delta\n" }, body_writer);
        // We do not currently convey server progress information to the user
        try Packet.write(.{ .data = "no-progress\n" }, body_writer);
        if (session.supports_shallow) {
            try Packet.write(.{ .data = "deepen 1\n" }, body_writer);
        }
        for (wants) |want| {
            var buf: [Packet.max_data_length]u8 = undefined;
            const arg = std.fmt.bufPrint(&buf, "want {s}\n", .{want}) catch unreachable;
            try Packet.write(.{ .data = arg }, body_writer);
        }
        try Packet.write(.{ .data = "done\n" }, body_writer);
        try Packet.write(.flush, body_writer);

        var request = try session.transport.open(.POST, upload_pack_uri, .{
            .redirect_behavior = .not_allowed,
            .server_header_buffer = http_headers_buffer,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/x-git-upload-pack-request" },
                .{ .name = "Git-Protocol", .value = "version=2" },
            },
        });
        errdefer request.deinit();
        request.transfer_encoding = .{ .content_length = body.items.len };
        try request.send();
        try request.writeAll(body.items);
        try request.finish();

        try request.wait();
        if (request.response.status != .ok) return error.ProtocolError;

        const reader = request.reader();
        // We are not interested in any of the sections of the returned fetch
        // data other than the packfile section, since we aren't doing anything
        // complex like ref negotiation (this is a fresh clone).
        var state: enum { section_start, section_content } = .section_start;
        while (true) {
            var buf: [Packet.max_data_length]u8 = undefined;
            const packet = try Packet.read(reader, &buf);
            switch (state) {
                .section_start => switch (packet) {
                    .data => |data| if (mem.eql(u8, Packet.normalizeText(data), "packfile")) {
                        return .{ .request = request };
                    } else {
                        state = .section_content;
                    },
                    else => return error.UnexpectedPacket,
                },
                .section_content => switch (packet) {
                    .delimiter => state = .section_start,
                    .data => {},
                    else => return error.UnexpectedPacket,
                },
            }
        }
    }

    pub const FetchStream = struct {
        request: std.http.Client.Request,
        buf: [Packet.max_data_length]u8 = undefined,
        pos: usize = 0,
        len: usize = 0,

        pub fn deinit(stream: *FetchStream) void {
            stream.request.deinit();
        }

        pub const ReadError = std.http.Client.Request.ReadError || error{
            InvalidPacket,
            ProtocolError,
            UnexpectedPacket,
        };
        pub const Reader = std.io.Reader(*FetchStream, ReadError, read);

        const StreamCode = enum(u8) {
            pack_data = 1,
            progress = 2,
            fatal_error = 3,
            _,
        };

        pub fn reader(stream: *FetchStream) Reader {
            return .{ .context = stream };
        }

        pub fn read(stream: *FetchStream, buf: []u8) !usize {
            if (stream.pos == stream.len) {
                while (true) {
                    switch (try Packet.read(stream.request.reader(), &stream.buf)) {
                        .flush => return 0,
                        .data => |data| if (data.len > 1) switch (@as(StreamCode, @enumFromInt(data[0]))) {
                            .pack_data => {
                                stream.pos = 1;
                                stream.len = data.len;
                                break;
                            },
                            .fatal_error => return error.ProtocolError,
                            else => {},
                        },
                        else => return error.UnexpectedPacket,
                    }
                }
            }

            const size = @min(buf.len, stream.len - stream.pos);
            @memcpy(buf[0..size], stream.buf[stream.pos .. stream.pos + size]);
            stream.pos += size;
            return size;
        }
    };
};

const PackHeader = struct {
    total_objects: u32,

    const signature = "PACK";
    const supported_version = 2;

    fn read(reader: anytype) !PackHeader {
        const actual_signature = reader.readBytesNoEof(4) catch |e| switch (e) {
            error.EndOfStream => return error.InvalidHeader,
            else => |other| return other,
        };
        if (!mem.eql(u8, &actual_signature, signature)) return error.InvalidHeader;
        const version = reader.readInt(u32, .big) catch |e| switch (e) {
            error.EndOfStream => return error.InvalidHeader,
            else => |other| return other,
        };
        if (version != supported_version) return error.UnsupportedVersion;
        const total_objects = reader.readInt(u32, .big) catch |e| switch (e) {
            error.EndOfStream => return error.InvalidHeader,
            else => |other| return other,
        };
        return .{ .total_objects = total_objects };
    }
};

const EntryHeader = union(Type) {
    commit: Undeltified,
    tree: Undeltified,
    blob: Undeltified,
    tag: Undeltified,
    ofs_delta: OfsDelta,
    ref_delta: RefDelta,

    const Type = enum(u3) {
        commit = 1,
        tree = 2,
        blob = 3,
        tag = 4,
        ofs_delta = 6,
        ref_delta = 7,
    };

    const Undeltified = struct {
        uncompressed_length: u64,
    };

    const OfsDelta = struct {
        offset: u64,
        uncompressed_length: u64,
    };

    const RefDelta = struct {
        base_object: Oid,
        uncompressed_length: u64,
    };

    fn objectType(header: EntryHeader) Object.Type {
        return switch (header) {
            inline .commit, .tree, .blob, .tag => |_, tag| @field(Object.Type, @tagName(tag)),
            else => unreachable,
        };
    }

    fn uncompressedLength(header: EntryHeader) u64 {
        return switch (header) {
            inline else => |entry| entry.uncompressed_length,
        };
    }

    fn read(reader: anytype) !EntryHeader {
        const InitialByte = packed struct { len: u4, type: u3, has_next: bool };
        const initial: InitialByte = @bitCast(reader.readByte() catch |e| switch (e) {
            error.EndOfStream => return error.InvalidFormat,
            else => |other| return other,
        });
        const rest_len = if (initial.has_next) try readSizeVarInt(reader) else 0;
        var uncompressed_length: u64 = initial.len;
        uncompressed_length |= std.math.shlExact(u64, rest_len, 4) catch return error.InvalidFormat;
        const @"type" = std.meta.intToEnum(EntryHeader.Type, initial.type) catch return error.InvalidFormat;
        return switch (@"type") {
            inline .commit, .tree, .blob, .tag => |tag| @unionInit(EntryHeader, @tagName(tag), .{
                .uncompressed_length = uncompressed_length,
            }),
            .ofs_delta => .{ .ofs_delta = .{
                .offset = try readOffsetVarInt(reader),
                .uncompressed_length = uncompressed_length,
            } },
            .ref_delta => .{ .ref_delta = .{
                .base_object = reader.readBytesNoEof(oid_length) catch |e| switch (e) {
                    error.EndOfStream => return error.InvalidFormat,
                    else => |other| return other,
                },
                .uncompressed_length = uncompressed_length,
            } },
        };
    }
};

fn readSizeVarInt(r: anytype) !u64 {
    const Byte = packed struct { value: u7, has_next: bool };
    var b: Byte = @bitCast(try r.readByte());
    var value: u64 = b.value;
    var shift: u6 = 0;
    while (b.has_next) {
        b = @bitCast(try r.readByte());
        shift = std.math.add(u6, shift, 7) catch return error.InvalidFormat;
        value |= @as(u64, b.value) << shift;
    }
    return value;
}

fn readOffsetVarInt(r: anytype) !u64 {
    const Byte = packed struct { value: u7, has_next: bool };
    var b: Byte = @bitCast(try r.readByte());
    var value: u64 = b.value;
    while (b.has_next) {
        b = @bitCast(try r.readByte());
        value = std.math.shlExact(u64, value + 1, 7) catch return error.InvalidFormat;
        value |= b.value;
    }
    return value;
}

const IndexHeader = struct {
    fan_out_table: [256]u32,

    const signature = "\xFFtOc";
    const supported_version = 2;
    const size = 4 + 4 + @sizeOf([256]u32);

    fn read(reader: anytype) !IndexHeader {
        var header_bytes = try reader.readBytesNoEof(size);
        if (!mem.eql(u8, header_bytes[0..4], signature)) return error.InvalidHeader;
        const version = mem.readInt(u32, header_bytes[4..8], .big);
        if (version != supported_version) return error.UnsupportedVersion;

        var fan_out_table: [256]u32 = undefined;
        var fan_out_table_stream = std.io.fixedBufferStream(header_bytes[8..]);
        const fan_out_table_reader = fan_out_table_stream.reader();
        for (&fan_out_table) |*entry| {
            entry.* = fan_out_table_reader.readInt(u32, .big) catch unreachable;
        }
        return .{ .fan_out_table = fan_out_table };
    }
};

const IndexEntry = struct {
    offset: u64,
    crc32: u32,
};

/// Writes out a version 2 index for the given packfile, as documented in
/// [pack-format](https://git-scm.com/docs/pack-format).
pub fn indexPack(allocator: Allocator, pack: std.fs.File, index_writer: anytype) !void {
    try pack.seekTo(0);

    var index_entries = std.AutoHashMapUnmanaged(Oid, IndexEntry){};
    defer index_entries.deinit(allocator);
    var pending_deltas = std.ArrayListUnmanaged(IndexEntry){};
    defer pending_deltas.deinit(allocator);

    const pack_checksum = try indexPackFirstPass(allocator, pack, &index_entries, &pending_deltas);

    var cache: ObjectCache = .{};
    defer cache.deinit(allocator);
    var remaining_deltas = pending_deltas.items.len;
    while (remaining_deltas > 0) {
        var i: usize = remaining_deltas;
        while (i > 0) {
            i -= 1;
            const delta = pending_deltas.items[i];
            if (try indexPackHashDelta(allocator, pack, delta, index_entries, &cache)) |oid| {
                try index_entries.put(allocator, oid, delta);
                _ = pending_deltas.swapRemove(i);
            }
        }
        if (pending_deltas.items.len == remaining_deltas) return error.IncompletePack;
        remaining_deltas = pending_deltas.items.len;
    }

    var oids = std.ArrayListUnmanaged(Oid){};
    defer oids.deinit(allocator);
    try oids.ensureTotalCapacityPrecise(allocator, index_entries.count());
    var index_entries_iter = index_entries.iterator();
    while (index_entries_iter.next()) |entry| {
        oids.appendAssumeCapacity(entry.key_ptr.*);
    }
    mem.sortUnstable(Oid, oids.items, {}, struct {
        fn lessThan(_: void, o1: Oid, o2: Oid) bool {
            return mem.lessThan(u8, &o1, &o2);
        }
    }.lessThan);

    var fan_out_table: [256]u32 = undefined;
    var count: u32 = 0;
    var fan_out_index: u8 = 0;
    for (oids.items) |oid| {
        if (oid[0] > fan_out_index) {
            @memset(fan_out_table[fan_out_index..oid[0]], count);
            fan_out_index = oid[0];
        }
        count += 1;
    }
    @memset(fan_out_table[fan_out_index..], count);

    var index_hashed_writer = hashedWriter(index_writer, Sha1.init(.{}));
    const writer = index_hashed_writer.writer();
    try writer.writeAll(IndexHeader.signature);
    try writer.writeInt(u32, IndexHeader.supported_version, .big);
    for (fan_out_table) |fan_out_entry| {
        try writer.writeInt(u32, fan_out_entry, .big);
    }

    for (oids.items) |oid| {
        try writer.writeAll(&oid);
    }

    for (oids.items) |oid| {
        try writer.writeInt(u32, index_entries.get(oid).?.crc32, .big);
    }

    var big_offsets = std.ArrayListUnmanaged(u64){};
    defer big_offsets.deinit(allocator);
    for (oids.items) |oid| {
        const offset = index_entries.get(oid).?.offset;
        if (offset <= std.math.maxInt(u31)) {
            try writer.writeInt(u32, @intCast(offset), .big);
        } else {
            const index = big_offsets.items.len;
            try big_offsets.append(allocator, offset);
            try writer.writeInt(u32, @as(u32, @intCast(index)) | (1 << 31), .big);
        }
    }
    for (big_offsets.items) |offset| {
        try writer.writeInt(u64, offset, .big);
    }

    try writer.writeAll(&pack_checksum);
    const index_checksum = index_hashed_writer.hasher.finalResult();
    try index_writer.writeAll(&index_checksum);
}

/// Performs the first pass over the packfile data for index construction.
/// This will index all non-delta objects, queue delta objects for further
/// processing, and return the pack checksum (which is part of the index
/// format).
fn indexPackFirstPass(
    allocator: Allocator,
    pack: std.fs.File,
    index_entries: *std.AutoHashMapUnmanaged(Oid, IndexEntry),
    pending_deltas: *std.ArrayListUnmanaged(IndexEntry),
) ![Sha1.digest_length]u8 {
    var pack_buffered_reader = std.io.bufferedReader(pack.reader());
    var pack_counting_reader = std.io.countingReader(pack_buffered_reader.reader());
    var pack_hashed_reader = std.compress.hashedReader(pack_counting_reader.reader(), Sha1.init(.{}));
    const pack_reader = pack_hashed_reader.reader();

    const pack_header = try PackHeader.read(pack_reader);

    var current_entry: u32 = 0;
    while (current_entry < pack_header.total_objects) : (current_entry += 1) {
        const entry_offset = pack_counting_reader.bytes_read;
        var entry_crc32_reader = std.compress.hashedReader(pack_reader, std.hash.Crc32.init());
        const entry_header = try EntryHeader.read(entry_crc32_reader.reader());
        switch (entry_header) {
            .commit, .tree, .blob, .tag => |object| {
                var entry_decompress_stream = std.compress.zlib.decompressor(entry_crc32_reader.reader());
                var entry_counting_reader = std.io.countingReader(entry_decompress_stream.reader());
                var entry_hashed_writer = hashedWriter(std.io.null_writer, Sha1.init(.{}));
                const entry_writer = entry_hashed_writer.writer();
                // The object header is not included in the pack data but is
                // part of the object's ID
                try entry_writer.print("{s} {}\x00", .{ @tagName(entry_header), object.uncompressed_length });
                var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
                try fifo.pump(entry_counting_reader.reader(), entry_writer);
                if (entry_counting_reader.bytes_read != object.uncompressed_length) {
                    return error.InvalidObject;
                }
                const oid = entry_hashed_writer.hasher.finalResult();
                try index_entries.put(allocator, oid, .{
                    .offset = entry_offset,
                    .crc32 = entry_crc32_reader.hasher.final(),
                });
            },
            inline .ofs_delta, .ref_delta => |delta| {
                var entry_decompress_stream = std.compress.zlib.decompressor(entry_crc32_reader.reader());
                var entry_counting_reader = std.io.countingReader(entry_decompress_stream.reader());
                var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
                try fifo.pump(entry_counting_reader.reader(), std.io.null_writer);
                if (entry_counting_reader.bytes_read != delta.uncompressed_length) {
                    return error.InvalidObject;
                }
                try pending_deltas.append(allocator, .{
                    .offset = entry_offset,
                    .crc32 = entry_crc32_reader.hasher.final(),
                });
            },
        }
    }

    const pack_checksum = pack_hashed_reader.hasher.finalResult();
    const recorded_checksum = try pack_buffered_reader.reader().readBytesNoEof(Sha1.digest_length);
    if (!mem.eql(u8, &pack_checksum, &recorded_checksum)) {
        return error.CorruptedPack;
    }
    _ = pack_reader.readByte() catch |e| switch (e) {
        error.EndOfStream => return pack_checksum,
        else => |other| return other,
    };
    return error.InvalidFormat;
}

/// Attempts to determine the final object ID of the given deltified object.
/// May return null if this is not yet possible (if the delta is a ref-based
/// delta and we do not yet know the offset of the base object).
fn indexPackHashDelta(
    allocator: Allocator,
    pack: std.fs.File,
    delta: IndexEntry,
    index_entries: std.AutoHashMapUnmanaged(Oid, IndexEntry),
    cache: *ObjectCache,
) !?Oid {
    // Figure out the chain of deltas to resolve
    var base_offset = delta.offset;
    var base_header: EntryHeader = undefined;
    var delta_offsets = std.ArrayListUnmanaged(u64){};
    defer delta_offsets.deinit(allocator);
    const base_object = while (true) {
        if (cache.get(base_offset)) |base_object| break base_object;

        try pack.seekTo(base_offset);
        base_header = try EntryHeader.read(pack.reader());
        switch (base_header) {
            .ofs_delta => |ofs_delta| {
                try delta_offsets.append(allocator, base_offset);
                base_offset = std.math.sub(u64, base_offset, ofs_delta.offset) catch return error.InvalidObject;
            },
            .ref_delta => |ref_delta| {
                try delta_offsets.append(allocator, base_offset);
                base_offset = (index_entries.get(ref_delta.base_object) orelse return null).offset;
            },
            else => {
                const base_data = try readObjectRaw(allocator, pack.reader(), base_header.uncompressedLength());
                errdefer allocator.free(base_data);
                const base_object: Object = .{ .type = base_header.objectType(), .data = base_data };
                try cache.put(allocator, base_offset, base_object);
                break base_object;
            },
        }
    };

    const base_data = try resolveDeltaChain(allocator, pack, base_object, delta_offsets.items, cache);

    var entry_hasher = Sha1.init(.{});
    var entry_hashed_writer = hashedWriter(std.io.null_writer, &entry_hasher);
    try entry_hashed_writer.writer().print("{s} {}\x00", .{ @tagName(base_object.type), base_data.len });
    entry_hasher.update(base_data);
    return entry_hasher.finalResult();
}

/// Resolves a chain of deltas, returning the final base object data. `pack` is
/// assumed to be looking at the start of the object data for the base object of
/// the chain, and will then apply the deltas in `delta_offsets` in reverse order
/// to obtain the final object.
fn resolveDeltaChain(
    allocator: Allocator,
    pack: std.fs.File,
    base_object: Object,
    delta_offsets: []const u64,
    cache: *ObjectCache,
) ![]const u8 {
    var base_data = base_object.data;
    var i: usize = delta_offsets.len;
    while (i > 0) {
        i -= 1;

        const delta_offset = delta_offsets[i];
        try pack.seekTo(delta_offset);
        const delta_header = try EntryHeader.read(pack.reader());
        const delta_data = try readObjectRaw(allocator, pack.reader(), delta_header.uncompressedLength());
        defer allocator.free(delta_data);
        var delta_stream = std.io.fixedBufferStream(delta_data);
        const delta_reader = delta_stream.reader();
        _ = try readSizeVarInt(delta_reader); // base object size
        const expanded_size = try readSizeVarInt(delta_reader);

        const expanded_alloc_size = std.math.cast(usize, expanded_size) orelse return error.ObjectTooLarge;
        const expanded_data = try allocator.alloc(u8, expanded_alloc_size);
        errdefer allocator.free(expanded_data);
        var expanded_delta_stream = std.io.fixedBufferStream(expanded_data);
        var base_stream = std.io.fixedBufferStream(base_data);
        try expandDelta(&base_stream, delta_reader, expanded_delta_stream.writer());
        if (expanded_delta_stream.pos != expanded_size) return error.InvalidObject;

        try cache.put(allocator, delta_offset, .{ .type = base_object.type, .data = expanded_data });
        base_data = expanded_data;
    }
    return base_data;
}

/// Reads the complete contents of an object from `reader`. This function may
/// read more bytes than required from `reader`, so the reader position after
/// returning is not reliable.
fn readObjectRaw(allocator: Allocator, reader: anytype, size: u64) ![]u8 {
    const alloc_size = std.math.cast(usize, size) orelse return error.ObjectTooLarge;
    var buffered_reader = std.io.bufferedReader(reader);
    var decompress_stream = std.compress.zlib.decompressor(buffered_reader.reader());
    const data = try allocator.alloc(u8, alloc_size);
    errdefer allocator.free(data);
    try decompress_stream.reader().readNoEof(data);
    _ = decompress_stream.reader().readByte() catch |e| switch (e) {
        error.EndOfStream => return data,
        else => |other| return other,
    };
    return error.InvalidFormat;
}

/// Expands delta data from `delta_reader` to `writer`. `base_object` must
/// support `reader` and `seekTo` (such as a `std.io.FixedBufferStream`).
///
/// The format of the delta data is documented in
/// [pack-format](https://git-scm.com/docs/pack-format).
fn expandDelta(base_object: anytype, delta_reader: anytype, writer: anytype) !void {
    while (true) {
        const inst: packed struct { value: u7, copy: bool } = @bitCast(delta_reader.readByte() catch |e| switch (e) {
            error.EndOfStream => return,
            else => |other| return other,
        });
        if (inst.copy) {
            const available: packed struct {
                offset1: bool,
                offset2: bool,
                offset3: bool,
                offset4: bool,
                size1: bool,
                size2: bool,
                size3: bool,
            } = @bitCast(inst.value);
            const offset_parts: packed struct { offset1: u8, offset2: u8, offset3: u8, offset4: u8 } = .{
                .offset1 = if (available.offset1) try delta_reader.readByte() else 0,
                .offset2 = if (available.offset2) try delta_reader.readByte() else 0,
                .offset3 = if (available.offset3) try delta_reader.readByte() else 0,
                .offset4 = if (available.offset4) try delta_reader.readByte() else 0,
            };
            const offset: u32 = @bitCast(offset_parts);
            const size_parts: packed struct { size1: u8, size2: u8, size3: u8 } = .{
                .size1 = if (available.size1) try delta_reader.readByte() else 0,
                .size2 = if (available.size2) try delta_reader.readByte() else 0,
                .size3 = if (available.size3) try delta_reader.readByte() else 0,
            };
            var size: u24 = @bitCast(size_parts);
            if (size == 0) size = 0x10000;
            try base_object.seekTo(offset);
            var copy_reader = std.io.limitedReader(base_object.reader(), size);
            var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
            try fifo.pump(copy_reader.reader(), writer);
        } else if (inst.value != 0) {
            var data_reader = std.io.limitedReader(delta_reader, inst.value);
            var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
            try fifo.pump(data_reader.reader(), writer);
        } else {
            return error.InvalidDeltaInstruction;
        }
    }
}

fn HashedWriter(
    comptime WriterType: anytype,
    comptime HasherType: anytype,
) type {
    return struct {
        child_writer: WriterType,
        hasher: HasherType,

        const Error = WriterType.Error;
        const Writer = std.io.Writer(*@This(), Error, write);

        fn write(hashed_writer: *@This(), buf: []const u8) Error!usize {
            const amt = try hashed_writer.child_writer.write(buf);
            hashed_writer.hasher.update(buf);
            return amt;
        }

        fn writer(hashed_writer: *@This()) Writer {
            return .{ .context = hashed_writer };
        }
    };
}

fn hashedWriter(
    writer: anytype,
    hasher: anytype,
) HashedWriter(@TypeOf(writer), @TypeOf(hasher)) {
    return .{ .child_writer = writer, .hasher = hasher };
}

test "packfile indexing and checkout" {
    // To verify the contents of this packfile without using the code in this
    // file:
    //
    // 1. Create a new empty Git repository (`git init`)
    // 2. `git unpack-objects <path/to/testdata.pack`
    // 3. `git fsck` -> note the "dangling commit" ID (which matches the commit
    //    checked out below)
    // 4. `git checkout dd582c0720819ab7130b103635bd7271b9fd4feb`
    const testrepo_pack = @embedFile("git/testdata/testrepo.pack");

    var git_dir = testing.tmpDir(.{});
    defer git_dir.cleanup();
    var pack_file = try git_dir.dir.createFile("testrepo.pack", .{ .read = true });
    defer pack_file.close();
    try pack_file.writeAll(testrepo_pack);

    var index_file = try git_dir.dir.createFile("testrepo.idx", .{ .read = true });
    defer index_file.close();
    try indexPack(testing.allocator, pack_file, index_file.writer());

    // Arbitrary size limit on files read while checking the repository contents
    // (all files in the test repo are known to be much smaller than this)
    const max_file_size = 4096;

    const index_file_data = try git_dir.dir.readFileAlloc(testing.allocator, "testrepo.idx", max_file_size);
    defer testing.allocator.free(index_file_data);
    // testrepo.idx is generated by Git. The index created by this file should
    // match it exactly. Running `git verify-pack -v testrepo.pack` can verify
    // this.
    const testrepo_idx = @embedFile("git/testdata/testrepo.idx");
    try testing.expectEqualSlices(u8, testrepo_idx, index_file_data);

    var repository = try Repository.init(testing.allocator, pack_file, index_file);
    defer repository.deinit();

    var worktree = testing.tmpDir(.{ .iterate = true });
    defer worktree.cleanup();

    const commit_id = try parseOid("dd582c0720819ab7130b103635bd7271b9fd4feb");

    var diagnostics: Diagnostics = .{ .allocator = testing.allocator };
    defer diagnostics.deinit();
    try repository.checkout(worktree.dir, commit_id, &diagnostics);
    try testing.expect(diagnostics.errors.items.len == 0);

    const expected_files: []const []const u8 = &.{
        "dir/file",
        "dir/subdir/file",
        "dir/subdir/file2",
        "dir2/file",
        "dir3/file",
        "dir3/file2",
        "file",
        "file2",
        "file3",
        "file4",
        "file5",
        "file6",
        "file7",
        "file8",
        "file9",
    };
    var actual_files: std.ArrayListUnmanaged([]u8) = .{};
    defer actual_files.deinit(testing.allocator);
    defer for (actual_files.items) |file| testing.allocator.free(file);
    var walker = try worktree.dir.walk(testing.allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        const path = try testing.allocator.dupe(u8, entry.path);
        errdefer testing.allocator.free(path);
        mem.replaceScalar(u8, path, std.fs.path.sep, '/');
        try actual_files.append(testing.allocator, path);
    }
    mem.sortUnstable([]u8, actual_files.items, {}, struct {
        fn lessThan(_: void, a: []u8, b: []u8) bool {
            return mem.lessThan(u8, a, b);
        }
    }.lessThan);
    try testing.expectEqualDeep(expected_files, actual_files.items);

    const expected_file_contents =
        \\revision 1
        \\revision 2
        \\revision 4
        \\revision 5
        \\revision 7
        \\revision 8
        \\revision 9
        \\revision 10
        \\revision 12
        \\revision 13
        \\revision 14
        \\revision 18
        \\revision 19
        \\
    ;
    const actual_file_contents = try worktree.dir.readFileAlloc(testing.allocator, "file", max_file_size);
    defer testing.allocator.free(actual_file_contents);
    try testing.expectEqualStrings(expected_file_contents, actual_file_contents);
}

/// Checks out a commit of a packfile. Intended for experimenting with and
/// benchmarking possible optimizations to the indexing and checkout behavior.
pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 4) {
        return error.InvalidArguments; // Arguments: packfile commit worktree
    }

    var pack_file = try std.fs.cwd().openFile(args[1], .{});
    defer pack_file.close();
    const commit = try parseOid(args[2]);
    var worktree = try std.fs.cwd().makeOpenPath(args[3], .{});
    defer worktree.close();

    var git_dir = try worktree.makeOpenPath(".git", .{});
    defer git_dir.close();

    std.debug.print("Starting index...\n", .{});
    var index_file = try git_dir.createFile("idx", .{ .read = true });
    defer index_file.close();
    var index_buffered_writer = std.io.bufferedWriter(index_file.writer());
    try indexPack(allocator, pack_file, index_buffered_writer.writer());
    try index_buffered_writer.flush();
    try index_file.sync();

    std.debug.print("Starting checkout...\n", .{});
    var repository = try Repository.init(allocator, pack_file, index_file);
    defer repository.deinit();
    var diagnostics: Diagnostics = .{ .allocator = allocator };
    defer diagnostics.deinit();
    try repository.checkout(worktree, commit, &diagnostics);

    for (diagnostics.errors.items) |err| {
        std.debug.print("Diagnostic: {}\n", .{err});
    }
}
