//! This API is non-allocating, non-fallible, and thread-safe.
//!
//! The tradeoff is that users of this API must provide the storage
//! for each `Progress.Node`.

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const testing = std.testing;
const assert = std.debug.assert;
const Progress = @This();
const posix = std.posix;

/// `null` if the current node (and its children) should
/// not print on update()
terminal: ?std.fs.File,

/// Is this a windows API terminal (note: this is not the same as being run on windows
/// because other terminals exist like MSYS/git-bash)
is_windows_terminal: bool,

/// Whether the terminal supports ANSI escape codes.
supports_ansi_escape_codes: bool,

update_thread: ?std.Thread,

/// Atomically set by SIGWINCH as well as the root done() function.
redraw_event: std.Thread.ResetEvent,
/// Indicates a request to shut down and reset global state.
/// Accessed atomically.
done: bool,

refresh_rate_ns: u64,
initial_delay_ns: u64,

rows: u16,
cols: u16,
/// Needed because terminal escape codes require one to take scrolling into
/// account.
newline_count: u16,

/// Accessed only by the update thread.
draw_buffer: []u8,

/// This is in a separate array from `node_storage` but with the same length so
/// that it can be iterated over efficiently without trashing too much of the
/// CPU cache.
node_parents: []Node.Parent,
node_storage: []Node.Storage,
node_freelist: []Node.OptionalIndex,
node_freelist_first: Node.OptionalIndex,
node_end_index: u32,

pub const Options = struct {
    /// User-provided buffer with static lifetime.
    ///
    /// Used to store the entire write buffer sent to the terminal. Progress output will be truncated if it
    /// cannot fit into this buffer which will look bad but not cause any malfunctions.
    ///
    /// Must be at least 200 bytes.
    draw_buffer: []u8,
    /// How many nanoseconds between writing updates to the terminal.
    refresh_rate_ns: u64 = 60 * std.time.ns_per_ms,
    /// How many nanoseconds to keep the output hidden
    initial_delay_ns: u64 = 500 * std.time.ns_per_ms,
    /// If provided, causes the progress item to have a denominator.
    /// 0 means unknown.
    estimated_total_items: usize = 0,
    root_name: []const u8 = "",
};

/// Represents one unit of progress. Each node can have children nodes, or
/// one can use integers with `update`.
pub const Node = struct {
    index: OptionalIndex,

    pub const max_name_len = 40;

    const Storage = extern struct {
        /// Little endian.
        completed_count: u32,
        /// 0 means unknown.
        /// Little endian.
        estimated_total_count: u32,
        name: [max_name_len]u8,

        fn getIpcFd(s: Storage) ?posix.fd_t {
            if (s.estimated_total_count != std.math.maxInt(u32))
                return null;

            const low: u16 = @truncate(s.completed_count);
            return low;
        }

        fn getMainStorageIndex(s: Storage) Node.Index {
            assert(s.estimated_total_count == std.math.maxInt(u32));
            const i: u16 = @truncate(s.completed_count >> 16);
            return @enumFromInt(i);
        }

        fn setIpcFd(s: *Storage, fd: posix.fd_t) void {
            s.estimated_total_count = std.math.maxInt(u32);
            s.completed_count = @bitCast(fd);
        }

        comptime {
            assert((@sizeOf(Storage) % 4) == 0);
        }
    };

    const Parent = enum(u16) {
        /// Unallocated storage.
        unused = std.math.maxInt(u16) - 1,
        /// Indicates root node.
        none = std.math.maxInt(u16),
        /// Index into `node_storage`.
        _,

        fn unwrap(i: @This()) ?Index {
            return switch (i) {
                .unused, .none => return null,
                else => @enumFromInt(@intFromEnum(i)),
            };
        }
    };

    const OptionalIndex = enum(u16) {
        none = std.math.maxInt(u16),
        /// Index into `node_storage`.
        _,

        fn unwrap(i: @This()) ?Index {
            if (i == .none) return null;
            return @enumFromInt(@intFromEnum(i));
        }

        fn toParent(i: @This()) Parent {
            assert(@intFromEnum(i) != @intFromEnum(Parent.unused));
            return @enumFromInt(@intFromEnum(i));
        }
    };

    /// Index into `node_storage`.
    const Index = enum(u16) {
        _,

        fn toParent(i: @This()) Parent {
            assert(@intFromEnum(i) != @intFromEnum(Parent.unused));
            assert(@intFromEnum(i) != @intFromEnum(Parent.none));
            return @enumFromInt(@intFromEnum(i));
        }

        fn toOptional(i: @This()) OptionalIndex {
            return @enumFromInt(@intFromEnum(i));
        }
    };

    /// Create a new child progress node. Thread-safe.
    ///
    /// Passing 0 for `estimated_total_items` means unknown.
    pub fn start(node: Node, name: []const u8, estimated_total_items: usize) Node {
        const node_index = node.index.unwrap() orelse return .{ .index = .none };
        const parent = node_index.toParent();

        const freelist_head = &global_progress.node_freelist_first;
        var opt_free_index = @atomicLoad(Node.OptionalIndex, freelist_head, .seq_cst);
        while (opt_free_index.unwrap()) |free_index| {
            const freelist_ptr = freelistByIndex(free_index);
            opt_free_index = @cmpxchgWeak(Node.OptionalIndex, freelist_head, opt_free_index, freelist_ptr.*, .seq_cst, .seq_cst) orelse {
                // We won the allocation race.
                return init(free_index, parent, name, estimated_total_items);
            };
        }

        const free_index = @atomicRmw(u32, &global_progress.node_end_index, .Add, 1, .monotonic);
        if (free_index >= global_progress.node_storage.len) {
            // Ran out of node storage memory. Progress for this node will not be tracked.
            _ = @atomicRmw(u32, &global_progress.node_end_index, .Sub, 1, .monotonic);
            return .{ .index = .none };
        }

        return init(@enumFromInt(free_index), parent, name, estimated_total_items);
    }

    /// This is the same as calling `start` and then `end` on the returned `Node`. Thread-safe.
    pub fn completeOne(n: Node) void {
        const index = n.index.unwrap() orelse return;
        const storage = storageByIndex(index);
        _ = @atomicRmw(u32, &storage.completed_count, .Add, 1, .monotonic);
    }

    /// Thread-safe.
    pub fn setCompletedItems(n: Node, completed_items: usize) void {
        const index = n.index.unwrap() orelse return;
        const storage = storageByIndex(index);
        @atomicStore(u32, &storage.completed_count, std.math.lossyCast(u32, completed_items), .monotonic);
    }

    /// Thread-safe. 0 means unknown.
    pub fn setEstimatedTotalItems(n: Node, count: usize) void {
        const index = n.index.unwrap() orelse return;
        const storage = storageByIndex(index);
        @atomicStore(u32, &storage.estimated_total_count, std.math.lossyCast(u32, count), .monotonic);
    }

    /// Finish a started `Node`. Thread-safe.
    pub fn end(n: Node) void {
        const index = n.index.unwrap() orelse return;
        const parent_ptr = parentByIndex(index);
        if (parent_ptr.unwrap()) |parent_index| {
            _ = @atomicRmw(u32, &storageByIndex(parent_index).completed_count, .Add, 1, .monotonic);
            @atomicStore(Node.Parent, parent_ptr, .unused, .seq_cst);

            const freelist_head = &global_progress.node_freelist_first;
            var first = @atomicLoad(Node.OptionalIndex, freelist_head, .seq_cst);
            while (true) {
                freelistByIndex(index).* = first;
                first = @cmpxchgWeak(Node.OptionalIndex, freelist_head, first, index.toOptional(), .seq_cst, .seq_cst) orelse break;
            }
        } else {
            @atomicStore(bool, &global_progress.done, true, .seq_cst);
            global_progress.redraw_event.set();
            if (global_progress.update_thread) |thread| thread.join();
        }
    }

    /// Posix-only. Used by `std.process.Child`.
    pub fn setIpcFd(node: Node, fd: posix.fd_t) void {
        const index = node.index.unwrap() orelse return;
        assert(fd != -1);
        storageByIndex(index).setIpcFd(fd);
    }

    fn storageByIndex(index: Node.Index) *Node.Storage {
        return &global_progress.node_storage[@intFromEnum(index)];
    }

    fn parentByIndex(index: Node.Index) *Node.Parent {
        return &global_progress.node_parents[@intFromEnum(index)];
    }

    fn freelistByIndex(index: Node.Index) *Node.OptionalIndex {
        return &global_progress.node_freelist[@intFromEnum(index)];
    }

    fn init(free_index: Index, parent: Parent, name: []const u8, estimated_total_items: usize) Node {
        assert(parent != .unused);

        const storage = storageByIndex(free_index);
        storage.* = .{
            .completed_count = 0,
            .estimated_total_count = std.math.lossyCast(u32, estimated_total_items),
            .name = [1]u8{0} ** max_name_len,
        };
        const name_len = @min(max_name_len, name.len);
        @memcpy(storage.name[0..name_len], name[0..name_len]);

        const parent_ptr = parentByIndex(free_index);
        assert(parent_ptr.* == .unused);
        @atomicStore(Node.Parent, parent_ptr, parent, .release);

        return .{ .index = free_index.toOptional() };
    }
};

var global_progress: Progress = .{
    .terminal = null,
    .is_windows_terminal = false,
    .supports_ansi_escape_codes = false,
    .update_thread = null,
    .redraw_event = .{},
    .refresh_rate_ns = undefined,
    .initial_delay_ns = undefined,
    .rows = 0,
    .cols = 0,
    .newline_count = 0,
    .draw_buffer = undefined,
    .done = false,

    // TODO: make these configurable and avoid including the globals in .data if unused
    .node_parents = &node_parents_buffer,
    .node_storage = &node_storage_buffer,
    .node_freelist = &node_freelist_buffer,
    .node_freelist_first = .none,
    .node_end_index = 0,
};

const default_node_storage_buffer_len = 100;
var node_parents_buffer: [default_node_storage_buffer_len]Node.Parent = undefined;
var node_storage_buffer: [default_node_storage_buffer_len]Node.Storage = undefined;
var node_freelist_buffer: [default_node_storage_buffer_len]Node.OptionalIndex = undefined;

/// Initializes a global Progress instance.
///
/// Asserts there is only one global Progress instance.
///
/// Call `Node.end` when done.
pub fn start(options: Options) Node {
    // Ensure there is only 1 global Progress object.
    assert(global_progress.node_end_index == 0);

    @memset(global_progress.node_parents, .unused);
    const root_node = Node.init(@enumFromInt(0), .none, options.root_name, options.estimated_total_items);
    global_progress.done = false;
    global_progress.node_end_index = 1;

    assert(options.draw_buffer.len >= 200);
    global_progress.draw_buffer = options.draw_buffer;
    global_progress.refresh_rate_ns = options.refresh_rate_ns;
    global_progress.initial_delay_ns = options.initial_delay_ns;

    if (std.process.parseEnvVarInt("ZIG_PROGRESS", u31, 10)) |ipc_fd| {
        if (std.Thread.spawn(.{}, ipcThreadRun, .{ipc_fd})) |thread| {
            global_progress.update_thread = thread;
        } else |err| {
            std.log.warn("failed to spawn IPC thread for communicating progress to parent: {s}", .{@errorName(err)});
            return .{ .index = .none };
        }
    } else |env_err| switch (env_err) {
        error.EnvironmentVariableNotFound => {
            const stderr = std.io.getStdErr();
            if (stderr.supportsAnsiEscapeCodes()) {
                global_progress.terminal = stderr;
                global_progress.supports_ansi_escape_codes = true;
            } else if (builtin.os.tag == .windows and stderr.isTty()) {
                global_progress.is_windows_terminal = true;
                global_progress.terminal = stderr;
            } else if (builtin.os.tag != .windows) {
                // we are in a "dumb" terminal like in acme or writing to a file
                global_progress.terminal = stderr;
            }

            if (global_progress.terminal == null) {
                return .{ .index = .none };
            }

            var act: posix.Sigaction = .{
                .handler = .{ .sigaction = handleSigWinch },
                .mask = posix.empty_sigset,
                .flags = (posix.SA.SIGINFO | posix.SA.RESTART),
            };
            posix.sigaction(posix.SIG.WINCH, &act, null) catch |err| {
                std.log.warn("failed to install SIGWINCH signal handler for noticing terminal resizes: {s}", .{@errorName(err)});
            };

            if (std.Thread.spawn(.{}, updateThreadRun, .{})) |thread| {
                global_progress.update_thread = thread;
            } else |err| {
                std.log.warn("unable to spawn thread for printing progress to terminal: {s}", .{@errorName(err)});
                return .{ .index = .none };
            }
        },
        else => |e| {
            std.log.warn("invalid ZIG_PROGRESS file descriptor integer: {s}", .{@errorName(e)});
            return .{ .index = .none };
        },
    }

    return root_node;
}

/// Returns whether a resize is needed to learn the terminal size.
fn wait(timeout_ns: u64) bool {
    const resize_flag = if (global_progress.redraw_event.timedWait(timeout_ns)) |_|
        true
    else |err| switch (err) {
        error.Timeout => false,
    };
    global_progress.redraw_event.reset();
    return resize_flag or (global_progress.cols == 0);
}

fn updateThreadRun() void {
    {
        const resize_flag = wait(global_progress.initial_delay_ns);
        maybeUpdateSize(resize_flag);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return clearTerminal();

        const buffer = computeRedraw();
        write(buffer);
    }

    while (true) {
        const resize_flag = wait(global_progress.refresh_rate_ns);
        maybeUpdateSize(resize_flag);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return clearTerminal();

        const buffer = computeRedraw();
        write(buffer);
    }
}

fn ipcThreadRun(fd: posix.fd_t) anyerror!void {
    {
        _ = wait(global_progress.initial_delay_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return;

        const serialized = serialize();
        writeIpc(fd, serialized) catch |err| switch (err) {
            error.BrokenPipe => return,
        };
    }

    while (true) {
        _ = wait(global_progress.refresh_rate_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return clearTerminal();

        const serialized = serialize();
        writeIpc(fd, serialized) catch |err| switch (err) {
            error.BrokenPipe => return,
        };
    }
}

const start_sync = "\x1b[?2026h";
const up_one_line = "\x1bM";
const clear = "\x1b[J";
const save = "\x1b7";
const restore = "\x1b8";
const finish_sync = "\x1b[?2026l";

const tree_tee = "\x1B\x28\x30\x74\x71\x1B\x28\x42 "; // ├─
const tree_line = "\x1B\x28\x30\x78\x1B\x28\x42  "; // │
const tree_langle = "\x1B\x28\x30\x6d\x71\x1B\x28\x42 "; // └─

fn clearTerminal() void {
    var i: usize = 0;
    const buf = global_progress.draw_buffer;

    buf[i..][0..start_sync.len].* = start_sync.*;
    i += start_sync.len;

    i = computeClear(buf, i);

    buf[i..][0..finish_sync.len].* = finish_sync.*;
    i += finish_sync.len;

    write(buf[0..i]);
}

fn computeClear(buf: []u8, start_i: usize) usize {
    var i = start_i;

    const prev_nl_n = global_progress.newline_count;
    if (prev_nl_n > 0) {
        global_progress.newline_count = 0;
        buf[i] = '\r';
        i += 1;
        for (1..prev_nl_n) |_| {
            buf[i..][0..up_one_line.len].* = up_one_line.*;
            i += up_one_line.len;
        }
    }

    buf[i..][0..clear.len].* = clear.*;
    i += clear.len;

    return i;
}

const Children = struct {
    child: Node.OptionalIndex,
    sibling: Node.OptionalIndex,
};

// TODO make this configurable
var serialized_node_parents_buffer: [default_node_storage_buffer_len]Node.Parent = undefined;
var serialized_node_storage_buffer: [default_node_storage_buffer_len]Node.Storage = undefined;
var serialized_node_map_buffer: [default_node_storage_buffer_len]Node.Index = undefined;

const Serialized = struct {
    parents: []Node.Parent,
    storage: []Node.Storage,
};

fn serialize() Serialized {
    var serialized_len: usize = 0;
    var any_ipc = false;

    // Iterate all of the nodes and construct a serializable copy of the state that can be examined
    // without atomics.
    const end_index = @atomicLoad(u32, &global_progress.node_end_index, .monotonic);
    const node_parents = global_progress.node_parents[0..end_index];
    const node_storage = global_progress.node_storage[0..end_index];
    for (node_parents, node_storage, 0..) |*parent_ptr, *storage_ptr, i| {
        var begin_parent = @atomicLoad(Node.Parent, parent_ptr, .seq_cst);
        while (begin_parent != .unused) {
            const dest_storage = &serialized_node_storage_buffer[serialized_len];
            @memcpy(&dest_storage.name, &storage_ptr.name);
            dest_storage.completed_count = @atomicLoad(u32, &storage_ptr.completed_count, .monotonic);
            dest_storage.estimated_total_count = @atomicLoad(u32, &storage_ptr.estimated_total_count, .monotonic);

            if (dest_storage.getIpcFd() != null) {
                any_ipc = true;
                dest_storage.completed_count |= @as(u32, @intCast(i)) << 16;
            }

            const end_parent = @atomicLoad(Node.Parent, parent_ptr, .seq_cst);
            if (begin_parent == end_parent) {
                serialized_node_parents_buffer[serialized_len] = begin_parent;
                serialized_node_map_buffer[i] = @enumFromInt(serialized_len);
                serialized_len += 1;
                break;
            }

            begin_parent = end_parent;
        }
    }

    // Remap parents to point inside serialized arrays.
    for (serialized_node_parents_buffer[0..serialized_len]) |*parent| {
        parent.* = switch (parent.*) {
            .unused => unreachable,
            .none => .none,
            _ => |p| serialized_node_map_buffer[@intFromEnum(p)].toParent(),
        };
    }

    // Find nodes which correspond to child processes.
    if (any_ipc)
        serialized_len = serializeIpc(serialized_len);

    return .{
        .parents = serialized_node_parents_buffer[0..serialized_len],
        .storage = serialized_node_storage_buffer[0..serialized_len],
    };
}

var parents_copy: [default_node_storage_buffer_len]Node.Parent = undefined;
var storage_copy: [default_node_storage_buffer_len]Node.Storage = undefined;

const SavedMetadata = extern struct {
    start_index: u16,
    nodes_len: u16,
    main_index: u16,
    flags: Flags,

    const Flags = enum(u16) {
        saved = std.math.maxInt(u16),
        _,
    };
};

fn serializeIpc(start_serialized_len: usize) usize {
    var serialized_len = start_serialized_len;
    var pipe_buf: [4096]u8 align(4) = undefined;

    main_loop: for (
        serialized_node_parents_buffer[0..serialized_len],
        serialized_node_storage_buffer[0..serialized_len],
        0..,
    ) |main_parent, *main_storage, main_index| {
        if (main_parent == .unused) continue;
        const fd = main_storage.getIpcFd() orelse continue;
        var bytes_read: usize = 0;
        while (true) {
            bytes_read += posix.read(fd, pipe_buf[bytes_read..]) catch |err| switch (err) {
                error.WouldBlock => break,
                else => |e| {
                    std.log.warn("failed to read child progress data: {s}", .{@errorName(e)});
                    main_storage.completed_count = 0;
                    main_storage.estimated_total_count = 0;
                    continue :main_loop;
                },
            };
        }
        // Ignore all but the last message on the pipe.
        var input: []align(2) u8 = pipe_buf[0..bytes_read];
        if (input.len == 0) {
            serialized_len = useSavedIpcData(serialized_len, main_storage, main_index);
            continue;
        }

        const storage, const parents = while (true) {
            if (input.len < 4) {
                std.log.warn("short read: {d} out of 4 header bytes", .{input.len});
                // TODO keep track of the short read to trash odd bytes with the next read
                serialized_len = useSavedIpcData(serialized_len, main_storage, main_index);
                continue :main_loop;
            }
            const subtree_len = std.mem.readInt(u32, input[0..4], .little);
            const expected_bytes = 4 + subtree_len * (@sizeOf(Node.Storage) + @sizeOf(Node.Parent));
            if (input.len < expected_bytes) {
                std.log.warn("short read: {d} out of {d} ({d} nodes)", .{ input.len, expected_bytes, subtree_len });
                // TODO keep track of the short read to trash odd bytes with the next read
                serialized_len = useSavedIpcData(serialized_len, main_storage, main_index);
                continue :main_loop;
            }
            if (input.len > expected_bytes) {
                input = @alignCast(input[expected_bytes..]);
                continue;
            }
            const storage_bytes = input[4..][0 .. subtree_len * @sizeOf(Node.Storage)];
            const parents_bytes = input[4 + storage_bytes.len ..][0 .. subtree_len * @sizeOf(Node.Parent)];
            break .{
                std.mem.bytesAsSlice(Node.Storage, storage_bytes),
                std.mem.bytesAsSlice(Node.Parent, parents_bytes),
            };
        };

        // Remember in case the pipe is empty on next update.
        const real_storage: *Node.Storage = Node.storageByIndex(main_storage.getMainStorageIndex());
        @as(*SavedMetadata, @ptrCast(&real_storage.name)).* = .{
            .start_index = @intCast(serialized_len),
            .nodes_len = @intCast(parents.len),
            .main_index = @intCast(main_index),
            .flags = .saved,
        };

        // Mount the root here.
        main_storage.* = storage[0];

        // Copy the rest of the tree to the end.
        @memcpy(serialized_node_storage_buffer[serialized_len..][0 .. storage.len - 1], storage[1..]);

        // Patch up parent pointers taking into account how the subtree is mounted.
        serialized_node_parents_buffer[serialized_len] = .none;

        for (serialized_node_parents_buffer[serialized_len..][0 .. parents.len - 1], parents[1..]) |*dest, p| {
            dest.* = switch (p) {
                // Fix bad data so the rest of the code does not see `unused`.
                .none, .unused => .none,
                // Root node is being mounted here.
                @as(Node.Parent, @enumFromInt(0)) => @enumFromInt(main_index),
                // Other nodes mounted at the end.
                // TODO check for bad data pointing outside the expected range
                _ => |off| @enumFromInt(serialized_len + @intFromEnum(off) - 1),
            };
        }

        serialized_len += storage.len - 1;
    }

    // Save a copy in case any pipes are empty on the next update.
    @memcpy(parents_copy[0..serialized_len], serialized_node_parents_buffer[0..serialized_len]);
    @memcpy(storage_copy[0..serialized_len], serialized_node_storage_buffer[0..serialized_len]);

    return serialized_len;
}

fn useSavedIpcData(start_serialized_len: usize, main_storage: *Node.Storage, main_index: usize) usize {
    const saved_metadata: *SavedMetadata = @ptrCast(&main_storage.name);
    if (saved_metadata.flags != .saved) {
        main_storage.completed_count = 0;
        main_storage.estimated_total_count = 0;
        return start_serialized_len;
    }

    const start_index = saved_metadata.start_index;
    const nodes_len = saved_metadata.nodes_len;
    const old_main_index = saved_metadata.main_index;

    const real_storage: *Node.Storage = Node.storageByIndex(main_storage.getMainStorageIndex());
    @as(*SavedMetadata, @ptrCast(&real_storage.name)).* = .{
        .start_index = @intCast(start_serialized_len),
        .nodes_len = nodes_len,
        .main_index = @intCast(main_index),
        .flags = .saved,
    };

    const parents = parents_copy[start_index..][0 .. nodes_len - 1];
    const storage = storage_copy[start_index..][0 .. nodes_len - 1];

    main_storage.* = storage_copy[old_main_index];

    @memcpy(serialized_node_storage_buffer[start_serialized_len..][0..storage.len], storage);

    for (serialized_node_parents_buffer[start_serialized_len..][0..parents.len], parents) |*dest, p| {
        dest.* = switch (p) {
            .none, .unused => .none,
            _ => |prev| @enumFromInt(if (@intFromEnum(prev) == old_main_index)
                main_index
            else
                @intFromEnum(prev) - start_index + start_serialized_len),
        };
    }

    return start_serialized_len + storage.len;
}

fn computeRedraw() []u8 {
    const serialized = serialize();

    // Now we can analyze our copy of the graph without atomics, reconstructing
    // children lists which do not exist in the canonical data. These are
    // needed for tree traversal below.

    var children_buffer: [default_node_storage_buffer_len]Children = undefined;
    const children = children_buffer[0..serialized.parents.len];

    @memset(children, .{ .child = .none, .sibling = .none });

    for (serialized.parents, 0..) |parent, child_index_usize| {
        const child_index: Node.Index = @enumFromInt(child_index_usize);
        assert(parent != .unused);
        const parent_index = parent.unwrap() orelse continue;
        const children_node = &children[@intFromEnum(parent_index)];
        if (children_node.child.unwrap()) |existing_child_index| {
            const existing_child = &children[@intFromEnum(existing_child_index)];
            children[@intFromEnum(child_index)].sibling = existing_child.sibling;
            existing_child.sibling = child_index.toOptional();
        } else {
            children_node.child = child_index.toOptional();
        }
    }

    // The strategy is: keep the cursor at the end, and then with every redraw:
    // move cursor to beginning of line, move cursor up N lines, erase to end of screen, write

    var i: usize = 0;
    const buf = global_progress.draw_buffer;

    buf[i..][0..start_sync.len].* = start_sync.*;
    i += start_sync.len;

    i = computeClear(buf, i);

    const root_node_index: Node.Index = @enumFromInt(0);
    i = computeNode(buf, i, serialized, children, root_node_index);

    // Truncate trailing newline.
    if (buf[i - 1] == '\n') i -= 1;

    buf[i..][0..finish_sync.len].* = finish_sync.*;
    i += finish_sync.len;

    return buf[0..i];
}

fn computePrefix(
    buf: []u8,
    start_i: usize,
    serialized: Serialized,
    children: []const Children,
    node_index: Node.Index,
) usize {
    var i = start_i;
    const parent_index = serialized.parents[@intFromEnum(node_index)].unwrap() orelse return i;
    if (serialized.parents[@intFromEnum(parent_index)] == .none) return i;
    i = computePrefix(buf, i, serialized, children, parent_index);
    if (children[@intFromEnum(parent_index)].sibling == .none) {
        buf[i..][0..3].* = "   ".*;
        i += 3;
    } else {
        buf[i..][0..tree_line.len].* = tree_line.*;
        i += tree_line.len;
    }
    return i;
}

fn computeNode(
    buf: []u8,
    start_i: usize,
    serialized: Serialized,
    children: []const Children,
    node_index: Node.Index,
) usize {
    var i = start_i;
    i = computePrefix(buf, i, serialized, children, node_index);

    const storage = &serialized.storage[@intFromEnum(node_index)];
    const estimated_total = storage.estimated_total_count;
    const completed_items = storage.completed_count;
    const name = if (std.mem.indexOfScalar(u8, &storage.name, 0)) |end| storage.name[0..end] else &storage.name;
    const parent = serialized.parents[@intFromEnum(node_index)];

    if (parent != .none) {
        if (children[@intFromEnum(node_index)].sibling == .none) {
            buf[i..][0..tree_langle.len].* = tree_langle.*;
            i += tree_langle.len;
        } else {
            buf[i..][0..tree_tee.len].* = tree_tee.*;
            i += tree_tee.len;
        }
    }

    if (name.len != 0 or estimated_total > 0) {
        if (estimated_total > 0) {
            i += (std.fmt.bufPrint(buf[i..], "[{d}/{d}] ", .{ completed_items, estimated_total }) catch &.{}).len;
        } else if (completed_items != 0) {
            i += (std.fmt.bufPrint(buf[i..], "[{d}] ", .{completed_items}) catch &.{}).len;
        }
        if (name.len != 0) {
            i += (std.fmt.bufPrint(buf[i..], "{s}", .{name}) catch &.{}).len;
        }
    }

    i = @min(global_progress.cols + start_i, i);
    buf[i] = '\n';
    i += 1;
    global_progress.newline_count += 1;

    if (children[@intFromEnum(node_index)].child.unwrap()) |child| {
        i = computeNode(buf, i, serialized, children, child);
    }

    if (children[@intFromEnum(node_index)].sibling.unwrap()) |sibling| {
        i = computeNode(buf, i, serialized, children, sibling);
    }

    return i;
}

fn write(buf: []const u8) void {
    const tty = global_progress.terminal orelse return;
    tty.writeAll(buf) catch {
        global_progress.terminal = null;
    };
}

fn writeIpc(fd: posix.fd_t, serialized: Serialized) error{BrokenPipe}!void {
    assert(serialized.parents.len == serialized.storage.len);
    const serialized_len: u32 = @intCast(serialized.parents.len);
    const header = std.mem.asBytes(&serialized_len);
    const storage = std.mem.sliceAsBytes(serialized.storage);
    const parents = std.mem.sliceAsBytes(serialized.parents);

    var vecs: [3]std.posix.iovec_const = .{
        .{ .base = header.ptr, .len = header.len },
        .{ .base = storage.ptr, .len = storage.len },
        .{ .base = parents.ptr, .len = parents.len },
    };

    // TODO: if big endian, byteswap
    // this is needed because the parent or child process might be running in qemu

    // If this write would block we do not want to keep trying, but we need to
    // know if a partial message was written.
    if (posix.writev(fd, &vecs)) |written| {
        const total = header.len + storage.len + parents.len;
        if (written < total) {
            std.log.warn("short write: {d} out of {d}", .{ written, total });
        }
    } else |err| switch (err) {
        error.WouldBlock => {},
        error.BrokenPipe => return error.BrokenPipe,
        else => |e| {
            std.log.warn("failed to send progress to parent process: {s}", .{@errorName(e)});
            return error.BrokenPipe;
        },
    }
}

fn maybeUpdateSize(resize_flag: bool) void {
    if (!resize_flag) return;

    var winsize: posix.winsize = .{
        .ws_row = 0,
        .ws_col = 0,
        .ws_xpixel = 0,
        .ws_ypixel = 0,
    };

    const fd = (global_progress.terminal orelse return).handle;

    const err = posix.system.ioctl(fd, posix.T.IOCGWINSZ, @intFromPtr(&winsize));
    if (posix.errno(err) == .SUCCESS) {
        global_progress.rows = winsize.ws_row;
        global_progress.cols = winsize.ws_col;
    } else {
        @panic("TODO: handle this failure");
    }
}

fn handleSigWinch(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
    _ = info;
    _ = ctx_ptr;
    assert(sig == posix.SIG.WINCH);
    global_progress.redraw_event.set();
}
