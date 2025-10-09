file: std.fs.File,
flags: packed struct {
    block_size: std.mem.Alignment,
    copy_file_range_unsupported: bool,
    fallocate_punch_hole_unsupported: bool,
    fallocate_insert_range_unsupported: bool,
},
section: if (is_windows) windows.HANDLE else void,
contents: []align(std.heap.page_size_min) u8,
nodes: std.ArrayList(Node),
free_ni: Node.Index,
large: std.ArrayList(u64),
updates: std.ArrayList(Node.Index),
update_prog_node: std.Progress.Node,
writers: std.SinglyLinkedList,

pub const Error = std.posix.MMapError ||
    std.posix.MRemapError ||
    std.fs.File.SetEndPosError ||
    std.fs.File.CopyRangeError ||
    error{NotFile};

pub fn init(file: std.fs.File, gpa: std.mem.Allocator) !MappedFile {
    var mf: MappedFile = .{
        .file = file,
        .flags = undefined,
        .section = if (is_windows) windows.INVALID_HANDLE_VALUE else {},
        .contents = &.{},
        .nodes = .empty,
        .free_ni = .none,
        .large = .empty,
        .updates = .empty,
        .update_prog_node = .none,
        .writers = .{},
    };
    errdefer mf.deinit(gpa);
    const size: u64, const block_size = stat: {
        if (is_windows) {
            var sbi: windows.SYSTEM_BASIC_INFORMATION = undefined;
            break :stat .{
                try windows.GetFileSizeEx(file.handle),
                switch (windows.ntdll.NtQuerySystemInformation(
                    .SystemBasicInformation,
                    &sbi,
                    @sizeOf(windows.SYSTEM_BASIC_INFORMATION),
                    null,
                )) {
                    .SUCCESS => @max(sbi.PageSize, sbi.AllocationGranularity),
                    else => std.heap.page_size_max,
                },
            };
        }
        const stat = try std.posix.fstat(mf.file.handle);
        if (!std.posix.S.ISREG(stat.mode)) return error.PathAlreadyExists;
        break :stat .{ @bitCast(stat.size), @max(std.heap.pageSize(), stat.blksize) };
    };
    mf.flags = .{
        .block_size = .fromByteUnits(std.math.ceilPowerOfTwoAssert(usize, block_size)),
        .copy_file_range_unsupported = false,
        .fallocate_insert_range_unsupported = false,
        .fallocate_punch_hole_unsupported = false,
    };
    try mf.nodes.ensureUnusedCapacity(gpa, 1);
    assert(try mf.addNode(gpa, .{
        .add_node = .{
            .size = size,
            .fixed = true,
        },
    }) == Node.Index.root);
    try mf.ensureTotalCapacity(@intCast(size));
    return mf;
}

pub fn deinit(mf: *MappedFile, gpa: std.mem.Allocator) void {
    mf.unmap();
    mf.nodes.deinit(gpa);
    mf.large.deinit(gpa);
    mf.updates.deinit(gpa);
    mf.update_prog_node.end();
    assert(mf.writers.first == null);
    mf.* = undefined;
}

pub const Node = extern struct {
    parent: Node.Index,
    prev: Node.Index,
    next: Node.Index,
    first: Node.Index,
    last: Node.Index,
    flags: Flags,
    location_payload: Location.Payload,

    pub const Flags = packed struct(u32) {
        location_tag: Location.Tag,
        alignment: std.mem.Alignment,
        /// Whether this node can be moved.
        fixed: bool,
        /// Whether this node has been moved.
        moved: bool,
        /// Whether this node has been resized.
        resized: bool,
        /// Whether this node might contain non-zero bytes.
        has_content: bool,
        /// Whether a moved event on this node bubbles down to children.
        bubbles_moved: bool,
        unused: @Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = 32 - @bitSizeOf(std.mem.Alignment) - 6,
        } }) = 0,
    };

    pub const Location = union(enum(u1)) {
        small: extern struct {
            /// Relative to `parent`.
            offset: u32,
            size: u32,
        },
        large: extern struct {
            index: usize,
            unused: @Type(.{ .int = .{
                .signedness = .unsigned,
                .bits = 64 - @bitSizeOf(usize),
            } }) = 0,
        },

        pub const Tag = @typeInfo(Location).@"union".tag_type.?;
        pub const Payload = @Type(.{ .@"union" = .{
            .layout = .@"extern",
            .tag_type = null,
            .fields = @typeInfo(Location).@"union".fields,
            .decls = &.{},
        } });

        pub fn resolve(loc: Location, mf: *const MappedFile) [2]u64 {
            return switch (loc) {
                .small => |small| .{ small.offset, small.size },
                .large => |large| mf.large.items[large.index..][0..2].*,
            };
        }
    };

    pub const Index = enum(u32) {
        none,
        _,

        pub const root: Node.Index = .none;

        fn get(ni: Node.Index, mf: *const MappedFile) *Node {
            return &mf.nodes.items[@intFromEnum(ni)];
        }

        pub fn parent(ni: Node.Index, mf: *const MappedFile) Node.Index {
            return ni.get(mf).parent;
        }

        pub const ChildIterator = struct {
            mf: *const MappedFile,
            ni: Node.Index,

            pub fn next(it: *ChildIterator) ?Node.Index {
                const ni = it.ni;
                if (ni == .none) return null;
                it.ni = ni.get(it.mf).next;
                return ni;
            }
        };
        pub fn children(ni: Node.Index, mf: *const MappedFile) ChildIterator {
            return .{ .mf = mf, .ni = ni.get(mf).first };
        }

        pub fn childrenMoved(ni: Node.Index, gpa: std.mem.Allocator, mf: *MappedFile) !void {
            var child_ni = ni.get(mf).last;
            while (child_ni != .none) {
                try child_ni.moved(gpa, mf);
                child_ni = child_ni.get(mf).prev;
            }
        }

        pub fn hasMoved(ni: Node.Index, mf: *const MappedFile) bool {
            var parent_ni = ni;
            while (parent_ni != Node.Index.root) {
                const parent_node = parent_ni.get(mf);
                if (!parent_node.flags.bubbles_moved) break;
                if (parent_node.flags.moved) return true;
                parent_ni = parent_node.parent;
            }
            return false;
        }
        pub fn moved(ni: Node.Index, gpa: std.mem.Allocator, mf: *MappedFile) !void {
            try mf.updates.ensureUnusedCapacity(gpa, 1);
            ni.movedAssumeCapacity(mf);
        }
        pub fn cleanMoved(ni: Node.Index, mf: *const MappedFile) bool {
            const node_moved = &ni.get(mf).flags.moved;
            defer node_moved.* = false;
            return node_moved.*;
        }
        fn movedAssumeCapacity(ni: Node.Index, mf: *MappedFile) void {
            if (ni.hasMoved(mf)) return;
            const node = ni.get(mf);
            node.flags.moved = true;
            if (node.flags.resized) return;
            mf.updates.appendAssumeCapacity(ni);
            mf.update_prog_node.increaseEstimatedTotalItems(1);
        }

        pub fn hasResized(ni: Node.Index, mf: *const MappedFile) bool {
            return ni.get(mf).flags.resized;
        }
        pub fn resized(ni: Node.Index, gpa: std.mem.Allocator, mf: *MappedFile) !void {
            try mf.updates.ensureUnusedCapacity(gpa, 1);
            ni.resizedAssumeCapacity(mf);
        }
        pub fn cleanResized(ni: Node.Index, mf: *const MappedFile) bool {
            const node_resized = &ni.get(mf).flags.resized;
            defer node_resized.* = false;
            return node_resized.*;
        }
        fn resizedAssumeCapacity(ni: Node.Index, mf: *MappedFile) void {
            const node = ni.get(mf);
            if (node.flags.resized) return;
            node.flags.resized = true;
            if (node.flags.moved) return;
            mf.updates.appendAssumeCapacity(ni);
            mf.update_prog_node.increaseEstimatedTotalItems(1);
        }

        pub fn alignment(ni: Node.Index, mf: *const MappedFile) std.mem.Alignment {
            return ni.get(mf).flags.alignment;
        }

        fn setLocationAssumeCapacity(ni: Node.Index, mf: *MappedFile, offset: u64, size: u64) void {
            const node = ni.get(mf);
            if (size == 0) node.flags.has_content = false;
            switch (node.location()) {
                .small => |small| {
                    if (small.offset != offset) ni.movedAssumeCapacity(mf);
                    if (small.size != size) ni.resizedAssumeCapacity(mf);
                    if (std.math.cast(u32, offset)) |small_offset| {
                        if (std.math.cast(u32, size)) |small_size| {
                            node.location_payload.small = .{
                                .offset = small_offset,
                                .size = small_size,
                            };
                            return;
                        }
                    }
                    defer mf.large.appendSliceAssumeCapacity(&.{ offset, size });
                    node.flags.location_tag = .large;
                    node.location_payload = .{ .large = .{ .index = mf.large.items.len } };
                },
                .large => |large| {
                    const large_items = mf.large.items[large.index..][0..2];
                    if (large_items[0] != offset) ni.movedAssumeCapacity(mf);
                    if (large_items[1] != size) ni.resizedAssumeCapacity(mf);
                    large_items.* = .{ offset, size };
                },
            }
        }

        pub fn location(ni: Node.Index, mf: *const MappedFile) Location {
            return ni.get(mf).location();
        }

        pub fn fileLocation(
            ni: Node.Index,
            mf: *const MappedFile,
            set_has_content: bool,
        ) struct { offset: u64, size: u64 } {
            var offset, const size = ni.location(mf).resolve(mf);
            var parent_ni = ni;
            while (true) {
                const parent_node = parent_ni.get(mf);
                if (set_has_content) parent_node.flags.has_content = true;
                if (parent_ni == .none) break;
                parent_ni = parent_node.parent;
                offset += parent_ni.location(mf).resolve(mf)[0];
            }
            return .{ .offset = offset, .size = size };
        }

        pub fn slice(ni: Node.Index, mf: *const MappedFile) []u8 {
            const file_loc = ni.fileLocation(mf, true);
            return mf.contents[@intCast(file_loc.offset)..][0..@intCast(file_loc.size)];
        }

        pub fn sliceConst(ni: Node.Index, mf: *const MappedFile) []const u8 {
            const file_loc = ni.fileLocation(mf, false);
            return mf.contents[@intCast(file_loc.offset)..][0..@intCast(file_loc.size)];
        }

        pub fn resize(ni: Node.Index, mf: *MappedFile, gpa: std.mem.Allocator, size: u64) !void {
            try mf.resizeNode(gpa, ni, size);
            var writers_it = mf.writers.first;
            while (writers_it) |writer_node| : (writers_it = writer_node.next) {
                const w: *Node.Writer = @fieldParentPtr("writer_node", writer_node);
                w.interface.buffer = w.ni.slice(mf);
            }
        }

        pub fn writer(ni: Node.Index, mf: *MappedFile, gpa: std.mem.Allocator, w: *Writer) void {
            w.* = .{
                .gpa = gpa,
                .mf = mf,
                .writer_node = .{},
                .ni = ni,
                .interface = .{
                    .buffer = ni.slice(mf),
                    .vtable = &Writer.vtable,
                },
                .err = null,
            };
            mf.writers.prepend(&w.writer_node);
        }
    };

    pub fn location(node: *const Node) Location {
        return switch (node.flags.location_tag) {
            inline else => |tag| @unionInit(
                Location,
                @tagName(tag),
                @field(node.location_payload, @tagName(tag)),
            ),
        };
    }

    pub const Writer = struct {
        gpa: std.mem.Allocator,
        mf: *MappedFile,
        writer_node: std.SinglyLinkedList.Node,
        ni: Node.Index,
        interface: std.Io.Writer,
        err: ?Error,

        pub fn deinit(w: *Writer) void {
            assert(w.mf.writers.popFirst() == &w.writer_node);
            w.* = undefined;
        }

        const vtable: std.Io.Writer.VTable = .{
            .drain = drain,
            .sendFile = sendFile,
            .flush = std.Io.Writer.noopFlush,
            .rebase = growingRebase,
        };

        fn drain(
            interface: *std.Io.Writer,
            data: []const []const u8,
            splat: usize,
        ) std.Io.Writer.Error!usize {
            const pattern = data[data.len - 1];
            const splat_len = pattern.len * splat;
            const start_len = interface.end;
            assert(data.len != 0);
            for (data) |bytes| {
                try growingRebase(interface, interface.end, bytes.len + splat_len + 1);
                @memcpy(interface.buffer[interface.end..][0..bytes.len], bytes);
                interface.end += bytes.len;
            }
            if (splat == 0) {
                interface.end -= pattern.len;
            } else switch (pattern.len) {
                0 => {},
                1 => {
                    @memset(interface.buffer[interface.end..][0 .. splat - 1], pattern[0]);
                    interface.end += splat - 1;
                },
                else => for (0..splat - 1) |_| {
                    @memcpy(interface.buffer[interface.end..][0..pattern.len], pattern);
                    interface.end += pattern.len;
                },
            }
            return interface.end - start_len;
        }

        fn sendFile(
            interface: *std.Io.Writer,
            file_reader: *std.fs.File.Reader,
            limit: std.Io.Limit,
        ) std.Io.Writer.FileError!usize {
            if (limit == .nothing) return 0;
            const pos = file_reader.logicalPos();
            const additional = if (file_reader.getSize()) |size| size - pos else |_| std.atomic.cache_line;
            if (additional == 0) return error.EndOfStream;
            try growingRebase(interface, interface.end, limit.minInt64(additional));
            switch (file_reader.mode) {
                .positional => {
                    const fr_buf = file_reader.interface.buffered();
                    const buf_copy_size = interface.write(fr_buf) catch unreachable;
                    file_reader.interface.toss(buf_copy_size);
                    if (buf_copy_size < fr_buf.len) return buf_copy_size;
                    assert(file_reader.logicalPos() == file_reader.pos);

                    const w: *Writer = @fieldParentPtr("interface", interface);
                    const copy_size: usize = @intCast(w.mf.copyFileRange(
                        file_reader.file,
                        file_reader.pos,
                        w.ni.fileLocation(w.mf, true).offset + interface.end,
                        limit.minInt(interface.unusedCapacityLen()),
                    ) catch |err| {
                        w.err = err;
                        return error.WriteFailed;
                    });
                    interface.end += copy_size;
                    return copy_size;
                },
                .streaming,
                .streaming_reading,
                .positional_reading,
                .failure,
                => {
                    const dest = limit.slice(interface.unusedCapacitySlice());
                    const n = try file_reader.interface.readSliceShort(dest);
                    if (n == 0) return error.EndOfStream;
                    interface.end += n;
                    return n;
                },
            }
        }

        fn growingRebase(
            interface: *std.Io.Writer,
            preserve: usize,
            unused_capacity: usize,
        ) std.Io.Writer.Error!void {
            _ = preserve;
            const total_capacity = interface.end + unused_capacity;
            if (interface.buffer.len >= total_capacity) return;
            const w: *Writer = @fieldParentPtr("interface", interface);
            w.ni.resize(w.mf, w.gpa, total_capacity +| total_capacity / 2) catch |err| {
                w.err = err;
                return error.WriteFailed;
            };
        }
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Node) == 32);
    }
};

fn addNode(mf: *MappedFile, gpa: std.mem.Allocator, opts: struct {
    parent: Node.Index = .none,
    prev: Node.Index = .none,
    next: Node.Index = .none,
    offset: u64 = 0,
    add_node: AddNodeOptions,
}) !Node.Index {
    if (opts.add_node.moved or opts.add_node.resized) try mf.updates.ensureUnusedCapacity(gpa, 1);
    const offset = opts.add_node.alignment.forward(@intCast(opts.offset));
    const location_tag: Node.Location.Tag, const location_payload: Node.Location.Payload = location: {
        if (std.math.cast(u32, offset)) |small_offset| break :location .{ .small, .{
            .small = .{ .offset = small_offset, .size = 0 },
        } };
        try mf.large.ensureUnusedCapacity(gpa, 2);
        defer mf.large.appendSliceAssumeCapacity(&.{ offset, 0 });
        break :location .{ .large, .{ .large = .{ .index = mf.large.items.len } } };
    };
    const free_ni: Node.Index, const free_node = free: switch (mf.free_ni) {
        .none => .{ @enumFromInt(mf.nodes.items.len), mf.nodes.addOneAssumeCapacity() },
        else => |free_ni| {
            const free_node = free_ni.get(mf);
            mf.free_ni = free_node.next;
            break :free .{ free_ni, free_node };
        },
    };
    free_node.* = .{
        .parent = opts.parent,
        .prev = opts.prev,
        .next = opts.next,
        .first = .none,
        .last = .none,
        .flags = .{
            .location_tag = location_tag,
            .alignment = opts.add_node.alignment,
            .fixed = opts.add_node.fixed,
            .moved = true,
            .resized = true,
            .has_content = false,
            .bubbles_moved = opts.add_node.bubbles_moved,
        },
        .location_payload = location_payload,
    };
    {
        defer {
            free_node.flags.moved = false;
            free_node.flags.resized = false;
        }
        if (offset > opts.parent.location(mf).resolve(mf)[1]) try opts.parent.resize(mf, gpa, offset);
        try free_ni.resize(mf, gpa, opts.add_node.size);
    }
    if (opts.add_node.moved) free_ni.movedAssumeCapacity(mf);
    if (opts.add_node.resized) free_ni.resizedAssumeCapacity(mf);
    return free_ni;
}

pub const AddNodeOptions = struct {
    size: u64 = 0,
    alignment: std.mem.Alignment = .@"1",
    fixed: bool = false,
    moved: bool = false,
    resized: bool = false,
    bubbles_moved: bool = true,
};

pub fn addOnlyChildNode(
    mf: *MappedFile,
    gpa: std.mem.Allocator,
    parent_ni: Node.Index,
    opts: AddNodeOptions,
) !Node.Index {
    try mf.nodes.ensureUnusedCapacity(gpa, 1);
    const parent = parent_ni.get(mf);
    assert(parent.first == .none and parent.last == .none);
    const ni = try mf.addNode(gpa, .{
        .parent = parent_ni,
        .add_node = opts,
    });
    parent.first = ni;
    parent.last = ni;
    return ni;
}

pub fn addLastChildNode(
    mf: *MappedFile,
    gpa: std.mem.Allocator,
    parent_ni: Node.Index,
    opts: AddNodeOptions,
) !Node.Index {
    try mf.nodes.ensureUnusedCapacity(gpa, 1);
    const parent = parent_ni.get(mf);
    const ni = try mf.addNode(gpa, .{
        .parent = parent_ni,
        .prev = parent.last,
        .offset = offset: switch (parent.last) {
            .none => 0,
            else => |last_ni| {
                const last_offset, const last_size = last_ni.location(mf).resolve(mf);
                break :offset last_offset + last_size;
            },
        },
        .add_node = opts,
    });
    switch (parent.last) {
        .none => parent.first = ni,
        else => |last_ni| last_ni.get(mf).next = ni,
    }
    parent.last = ni;
    return ni;
}

pub fn addNodeAfter(
    mf: *MappedFile,
    gpa: std.mem.Allocator,
    prev_ni: Node.Index,
    opts: AddNodeOptions,
) !Node.Index {
    assert(prev_ni != .none);
    try mf.nodes.ensureUnusedCapacity(gpa, 1);
    const prev = prev_ni.get(mf);
    const prev_offset, const prev_size = prev.location().resolve(mf);
    const ni = try mf.addNode(gpa, .{
        .parent = prev.parent,
        .prev = prev_ni,
        .next = prev.next,
        .offset = prev_offset + prev_size,
        .add_node = opts,
    });
    switch (prev.next) {
        .none => prev.parent.get(mf).last = ni,
        else => |next_ni| next_ni.get(mf).prev = ni,
    }
    prev.next = ni;
    return ni;
}

fn resizeNode(mf: *MappedFile, gpa: std.mem.Allocator, ni: Node.Index, requested_size: u64) !void {
    const node = ni.get(mf);
    var old_offset, const old_size = node.location().resolve(mf);
    const new_size = node.flags.alignment.forward(@intCast(requested_size));
    // Resize the entire file
    if (ni == Node.Index.root) {
        try mf.ensureCapacityForSetLocation(gpa);
        try mf.file.setEndPos(new_size);
        try mf.ensureTotalCapacity(@intCast(new_size));
        ni.setLocationAssumeCapacity(mf, old_offset, new_size);
        return;
    }
    while (true) {
        const parent = node.parent.get(mf);
        _, const old_parent_size = parent.location().resolve(mf);
        const trailing_end = switch (node.next) {
            .none => parent.location().resolve(mf)[1],
            else => |next_ni| next_ni.location(mf).resolve(mf)[0],
        };
        assert(old_offset + old_size <= trailing_end);
        // Expand the node into available trailing free space
        if (old_offset + new_size <= trailing_end) {
            try mf.ensureCapacityForSetLocation(gpa);
            ni.setLocationAssumeCapacity(mf, old_offset, new_size);
            return;
        }
        // Ask the filesystem driver to insert an extent into the file without copying any data
        if (is_linux and !mf.flags.fallocate_insert_range_unsupported and
            node.flags.alignment.order(mf.flags.block_size).compare(.gte))
        insert_range: {
            const last_offset, const last_size = parent.last.location(mf).resolve(mf);
            const last_end = last_offset + last_size;
            assert(last_end <= old_parent_size);
            const range_size =
                node.flags.alignment.forward(@intCast(requested_size +| requested_size / 2)) - old_size;
            const new_parent_size = last_end + range_size;
            if (new_parent_size > old_parent_size) {
                try mf.resizeNode(gpa, node.parent, new_parent_size +| new_parent_size / 2);
                continue;
            }
            const range_file_offset = ni.fileLocation(mf, false).offset + old_size;
            while (true) switch (linux.E.init(linux.fallocate(
                mf.file.handle,
                linux.FALLOC.FL_INSERT_RANGE,
                @intCast(range_file_offset),
                @intCast(range_size),
            ))) {
                .SUCCESS => {
                    var enclosing_ni = ni;
                    while (true) {
                        try mf.ensureCapacityForSetLocation(gpa);
                        const enclosing = enclosing_ni.get(mf);
                        const enclosing_offset, const old_enclosing_size =
                            enclosing.location().resolve(mf);
                        const new_enclosing_size = old_enclosing_size + range_size;
                        enclosing_ni.setLocationAssumeCapacity(mf, enclosing_offset, new_enclosing_size);
                        if (enclosing_ni == Node.Index.root) {
                            assert(enclosing_offset == 0);
                            try mf.ensureTotalCapacity(@intCast(new_enclosing_size));
                            break;
                        }
                        var after_ni = enclosing.next;
                        while (after_ni != .none) {
                            try mf.ensureCapacityForSetLocation(gpa);
                            const after = after_ni.get(mf);
                            const after_offset, const after_size = after.location().resolve(mf);
                            after_ni.setLocationAssumeCapacity(
                                mf,
                                range_size + after_offset,
                                after_size,
                            );
                            after_ni = after.next;
                        }
                        enclosing_ni = enclosing.parent;
                    }
                    return;
                },
                .INTR => continue,
                .BADF, .FBIG, .INVAL => unreachable,
                .IO => return error.InputOutput,
                .NODEV => return error.NotFile,
                .NOSPC => return error.NoSpaceLeft,
                .NOSYS, .OPNOTSUPP => {
                    mf.flags.fallocate_insert_range_unsupported = true;
                    break :insert_range;
                },
                .PERM => return error.PermissionDenied,
                .SPIPE => return error.Unseekable,
                .TXTBSY => return error.FileBusy,
                else => |e| return std.posix.unexpectedErrno(e),
            };
        }
        switch (node.next) {
            .none => {
                // As this is the last node, we simply need more space in the parent
                const new_parent_size = old_offset + new_size;
                try mf.resizeNode(gpa, node.parent, new_parent_size +| new_parent_size / 2);
            },
            else => |*next_ni_ptr| switch (node.flags.fixed) {
                false => {
                    // Make space at the end of the parent for this floating node
                    const last = parent.last.get(mf);
                    const last_offset, const last_size = last.location().resolve(mf);
                    const new_offset = node.flags.alignment.forward(@intCast(last_offset + last_size));
                    const new_parent_size = new_offset + new_size;
                    if (new_parent_size > old_parent_size) {
                        try mf.resizeNode(
                            gpa,
                            node.parent,
                            new_parent_size +| new_parent_size / 2,
                        );
                        continue;
                    }
                    const next_ni = next_ni_ptr.*;
                    next_ni.get(mf).prev = node.prev;
                    switch (node.prev) {
                        .none => parent.first = next_ni,
                        else => |prev_ni| prev_ni.get(mf).next = next_ni,
                    }
                    last.next = ni;
                    node.prev = parent.last;
                    next_ni_ptr.* = .none;
                    parent.last = ni;
                    if (node.flags.has_content) {
                        const parent_file_offset = node.parent.fileLocation(mf, false).offset;
                        try mf.moveRange(
                            parent_file_offset + old_offset,
                            parent_file_offset + new_offset,
                            old_size,
                        );
                    }
                    old_offset = new_offset;
                },
                true => {
                    // Move the next floating node to make space for this fixed node
                    const next_ni = next_ni_ptr.*;
                    const next = next_ni.get(mf);
                    assert(!next.flags.fixed);
                    const next_offset, const next_size = next.location().resolve(mf);
                    const last = parent.last.get(mf);
                    const last_offset, const last_size = last.location().resolve(mf);
                    const new_offset = next.flags.alignment.forward(@intCast(
                        @max(old_offset + new_size, last_offset + last_size),
                    ));
                    const new_parent_size = new_offset + next_size;
                    if (new_parent_size > old_parent_size) {
                        try mf.resizeNode(
                            gpa,
                            node.parent,
                            new_parent_size +| new_parent_size / 2,
                        );
                        continue;
                    }
                    try mf.ensureCapacityForSetLocation(gpa);
                    next.prev = parent.last;
                    parent.last = next_ni;
                    last.next = next_ni;
                    next_ni_ptr.* = next.next;
                    switch (next.next) {
                        .none => {},
                        else => |next_next_ni| next_next_ni.get(mf).prev = ni,
                    }
                    next.next = .none;
                    if (node.flags.has_content) {
                        const parent_file_offset = node.parent.fileLocation(mf, false).offset;
                        try mf.moveRange(
                            parent_file_offset + next_offset,
                            parent_file_offset + new_offset,
                            next_size,
                        );
                    }
                    next_ni.setLocationAssumeCapacity(mf, new_offset, next_size);
                },
            },
        }
    }
}

fn moveRange(mf: *MappedFile, old_file_offset: u64, new_file_offset: u64, size: u64) !void {
    // make a copy of this node at the new location
    try mf.copyRange(old_file_offset, new_file_offset, size);
    // delete the copy of this node at the old location
    if (is_linux and !mf.flags.fallocate_punch_hole_unsupported and
        size >= mf.flags.block_size.toByteUnits() * 2 - 1) while (true)
        switch (linux.E.init(linux.fallocate(
            mf.file.handle,
            linux.FALLOC.FL_PUNCH_HOLE | linux.FALLOC.FL_KEEP_SIZE,
            @intCast(old_file_offset),
            @intCast(size),
        ))) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF, .FBIG, .INVAL => unreachable,
            .IO => return error.InputOutput,
            .NODEV => return error.NotFile,
            .NOSPC => return error.NoSpaceLeft,
            .NOSYS, .OPNOTSUPP => {
                mf.flags.fallocate_punch_hole_unsupported = true;
                break;
            },
            .PERM => return error.PermissionDenied,
            .SPIPE => return error.Unseekable,
            .TXTBSY => return error.FileBusy,
            else => |e| return std.posix.unexpectedErrno(e),
        };
    @memset(mf.contents[@intCast(old_file_offset)..][0..@intCast(size)], 0);
}

fn copyRange(mf: *MappedFile, old_file_offset: u64, new_file_offset: u64, size: u64) !void {
    const copy_size = try mf.copyFileRange(mf.file, old_file_offset, new_file_offset, size);
    if (copy_size < size) @memcpy(
        mf.contents[@intCast(new_file_offset + copy_size)..][0..@intCast(size - copy_size)],
        mf.contents[@intCast(old_file_offset + copy_size)..][0..@intCast(size - copy_size)],
    );
}

fn copyFileRange(
    mf: *MappedFile,
    old_file: std.fs.File,
    old_file_offset: u64,
    new_file_offset: u64,
    size: u64,
) !u64 {
    var remaining_size = size;
    if (is_linux and !mf.flags.copy_file_range_unsupported) {
        var old_file_offset_mut: i64 = @intCast(old_file_offset);
        var new_file_offset_mut: i64 = @intCast(new_file_offset);
        while (remaining_size >= mf.flags.block_size.toByteUnits() * 2 - 1) {
            const copy_len = linux.copy_file_range(
                old_file.handle,
                &old_file_offset_mut,
                mf.file.handle,
                &new_file_offset_mut,
                @intCast(remaining_size),
                0,
            );
            switch (linux.E.init(copy_len)) {
                .SUCCESS => {
                    if (copy_len == 0) break;
                    remaining_size -= copy_len;
                    if (remaining_size == 0) break;
                },
                .INTR => continue,
                .BADF, .FBIG, .INVAL, .OVERFLOW => unreachable,
                .IO => return error.InputOutput,
                .ISDIR => return error.IsDir,
                .NOMEM => return error.SystemResources,
                .NOSPC => return error.NoSpaceLeft,
                .NOSYS, .OPNOTSUPP, .XDEV => {
                    mf.flags.copy_file_range_unsupported = true;
                    break;
                },
                .PERM => return error.PermissionDenied,
                .TXTBSY => return error.FileBusy,
                else => |e| return std.posix.unexpectedErrno(e),
            }
        }
    }
    return size - remaining_size;
}

fn ensureCapacityForSetLocation(mf: *MappedFile, gpa: std.mem.Allocator) !void {
    try mf.large.ensureUnusedCapacity(gpa, 2);
    try mf.updates.ensureUnusedCapacity(gpa, 1);
}

pub fn ensureTotalCapacity(mf: *MappedFile, new_capacity: usize) !void {
    if (mf.contents.len >= new_capacity) return;
    try mf.ensureTotalCapacityPrecise(new_capacity +| new_capacity / 2);
}

pub fn ensureTotalCapacityPrecise(mf: *MappedFile, new_capacity: usize) !void {
    if (mf.contents.len >= new_capacity) return;
    const aligned_capacity = mf.flags.block_size.forward(new_capacity);
    if (!is_linux) mf.unmap() else if (mf.contents.len > 0) {
        mf.contents = try std.posix.mremap(
            mf.contents.ptr,
            mf.contents.len,
            aligned_capacity,
            .{ .MAYMOVE = true },
            null,
        );
        return;
    }
    if (is_windows) {
        if (mf.section == windows.INVALID_HANDLE_VALUE) switch (windows.ntdll.NtCreateSection(
            &mf.section,
            windows.STANDARD_RIGHTS_REQUIRED | windows.SECTION_QUERY |
                windows.SECTION_MAP_WRITE | windows.SECTION_MAP_READ | windows.SECTION_EXTEND_SIZE,
            null,
            @constCast(&@as(i64, @intCast(aligned_capacity))),
            windows.PAGE_READWRITE,
            windows.SEC_COMMIT,
            mf.file.handle,
        )) {
            .SUCCESS => {},
            else => return error.MemoryMappingNotSupported,
        };
        var contents_ptr: ?[*]align(std.heap.page_size_min) u8 = null;
        var contents_len = aligned_capacity;
        switch (windows.ntdll.NtMapViewOfSection(
            mf.section,
            windows.GetCurrentProcess(),
            @ptrCast(&contents_ptr),
            null,
            0,
            null,
            &contents_len,
            .ViewUnmap,
            0,
            windows.PAGE_READWRITE,
        )) {
            .SUCCESS => mf.contents = contents_ptr.?[0..contents_len],
            else => return error.MemoryMappingNotSupported,
        }
    } else mf.contents = try std.posix.mmap(
        null,
        aligned_capacity,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = if (is_linux) .SHARED_VALIDATE else .SHARED },
        mf.file.handle,
        0,
    );
}

pub fn unmap(mf: *MappedFile) void {
    if (mf.contents.len == 0) return;
    if (is_windows)
        _ = windows.ntdll.NtUnmapViewOfSection(windows.GetCurrentProcess(), mf.contents.ptr)
    else
        std.posix.munmap(mf.contents);
    mf.contents = &.{};
    if (is_windows and mf.section != windows.INVALID_HANDLE_VALUE) {
        windows.CloseHandle(mf.section);
        mf.section = windows.INVALID_HANDLE_VALUE;
    }
}

fn verify(mf: *MappedFile) void {
    const root = Node.Index.root.get(mf);
    assert(root.parent == .none);
    assert(root.prev == .none);
    assert(root.next == .none);
    mf.verifyNode(Node.Index.root);
}

fn verifyNode(mf: *MappedFile, parent_ni: Node.Index) void {
    const parent = parent_ni.get(mf);
    const parent_offset, const parent_size = parent.location().resolve(mf);
    var prev_ni: Node.Index = .none;
    var prev_end: u64 = 0;
    var ni = parent.first;
    while (true) {
        if (ni == .none) {
            assert(parent.last == prev_ni);
            return;
        }
        const node = ni.get(mf);
        assert(node.parent == parent_ni);
        const offset, const size = node.location().resolve(mf);
        assert(node.flags.alignment.check(@intCast(offset)));
        assert(node.flags.alignment.check(@intCast(size)));
        const end = offset + size;
        assert(end <= parent_offset + parent_size);
        assert(offset >= prev_end);
        assert(node.prev == prev_ni);
        mf.verifyNode(ni);
        prev_ni = ni;
        prev_end = end;
        ni = node.next;
    }
}

const assert = std.debug.assert;
const builtin = @import("builtin");
const is_linux = builtin.os.tag == .linux;
const is_windows = builtin.os.tag == .windows;
const linux = std.os.linux;
const MappedFile = @This();
const std = @import("std");
const windows = std.os.windows;
