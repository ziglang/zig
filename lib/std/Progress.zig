//! This API is non-allocating, non-fallible, thread-safe, and lock-free.

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const testing = std.testing;
const assert = std.debug.assert;
const Progress = @This();
const posix = std.posix;
const is_big_endian = builtin.cpu.arch.endian() == .big;
const is_windows = builtin.os.tag == .windows;

/// `null` if the current node (and its children) should
/// not print on update()
terminal: std.fs.File,

terminal_mode: TerminalMode,

update_thread: ?std.Thread,

/// Atomically set by SIGWINCH as well as the root done() function.
redraw_event: std.Thread.ResetEvent,
/// Indicates a request to shut down and reset global state.
/// Accessed atomically.
done: bool,
need_clear: bool,

refresh_rate_ns: u64,
initial_delay_ns: u64,

rows: u16,
cols: u16,

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

pub const TerminalMode = union(enum) {
    off,
    ansi_escape_codes,
    /// This is not the same as being run on windows because other terminals
    /// exist like MSYS/git-bash.
    windows_api: if (is_windows) WindowsApi else void,

    pub const WindowsApi = struct {
        /// The output code page of the console.
        code_page: windows.UINT,
    };
};

pub const Options = struct {
    /// User-provided buffer with static lifetime.
    ///
    /// Used to store the entire write buffer sent to the terminal. Progress output will be truncated if it
    /// cannot fit into this buffer which will look bad but not cause any malfunctions.
    ///
    /// Must be at least 200 bytes.
    draw_buffer: []u8 = &default_draw_buffer,
    /// How many nanoseconds between writing updates to the terminal.
    refresh_rate_ns: u64 = 80 * std.time.ns_per_ms,
    /// How many nanoseconds to keep the output hidden
    initial_delay_ns: u64 = 200 * std.time.ns_per_ms,
    /// If provided, causes the progress item to have a denominator.
    /// 0 means unknown.
    estimated_total_items: usize = 0,
    root_name: []const u8 = "",
    disable_printing: bool = false,
};

/// Represents one unit of progress. Each node can have children nodes, or
/// one can use integers with `update`.
pub const Node = struct {
    index: OptionalIndex,

    pub const none: Node = .{ .index = .none };

    pub const max_name_len = 40;

    const Storage = extern struct {
        /// Little endian.
        completed_count: u32,
        /// 0 means unknown.
        /// Little endian.
        estimated_total_count: u32,
        name: [max_name_len]u8 align(@alignOf(usize)),

        /// Not thread-safe.
        fn getIpcFd(s: Storage) ?posix.fd_t {
            return if (s.estimated_total_count == std.math.maxInt(u32)) switch (@typeInfo(posix.fd_t)) {
                .int => @bitCast(s.completed_count),
                .pointer => @ptrFromInt(s.completed_count),
                else => @compileError("unsupported fd_t of " ++ @typeName(posix.fd_t)),
            } else null;
        }

        /// Thread-safe.
        fn setIpcFd(s: *Storage, fd: posix.fd_t) void {
            const integer: u32 = switch (@typeInfo(posix.fd_t)) {
                .int => @bitCast(fd),
                .pointer => @intFromPtr(fd),
                else => @compileError("unsupported fd_t of " ++ @typeName(posix.fd_t)),
            };
            // `estimated_total_count` max int indicates the special state that
            // causes `completed_count` to be treated as a file descriptor, so
            // the order here matters.
            @atomicStore(u32, &s.completed_count, integer, .monotonic);
            @atomicStore(u32, &s.estimated_total_count, std.math.maxInt(u32), .release);
        }

        /// Not thread-safe.
        fn byteSwap(s: *Storage) void {
            s.completed_count = @byteSwap(s.completed_count);
            s.estimated_total_count = @byteSwap(s.estimated_total_count);
        }

        comptime {
            assert((@sizeOf(Storage) % 4) == 0);
        }
    };

    const Parent = enum(u8) {
        /// Unallocated storage.
        unused = std.math.maxInt(u8) - 1,
        /// Indicates root node.
        none = std.math.maxInt(u8),
        /// Index into `node_storage`.
        _,

        fn unwrap(i: @This()) ?Index {
            return switch (i) {
                .unused, .none => return null,
                else => @enumFromInt(@intFromEnum(i)),
            };
        }
    };

    pub const OptionalIndex = enum(u8) {
        none = std.math.maxInt(u8),
        /// Index into `node_storage`.
        _,

        pub fn unwrap(i: @This()) ?Index {
            if (i == .none) return null;
            return @enumFromInt(@intFromEnum(i));
        }

        fn toParent(i: @This()) Parent {
            assert(@intFromEnum(i) != @intFromEnum(Parent.unused));
            return @enumFromInt(@intFromEnum(i));
        }
    };

    /// Index into `node_storage`.
    pub const Index = enum(u8) {
        _,

        fn toParent(i: @This()) Parent {
            assert(@intFromEnum(i) != @intFromEnum(Parent.unused));
            assert(@intFromEnum(i) != @intFromEnum(Parent.none));
            return @enumFromInt(@intFromEnum(i));
        }

        pub fn toOptional(i: @This()) OptionalIndex {
            return @enumFromInt(@intFromEnum(i));
        }
    };

    /// Create a new child progress node. Thread-safe.
    ///
    /// Passing 0 for `estimated_total_items` means unknown.
    pub fn start(node: Node, name: []const u8, estimated_total_items: usize) Node {
        if (noop_impl) {
            assert(node.index == .none);
            return Node.none;
        }
        const node_index = node.index.unwrap() orelse return Node.none;
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
            return Node.none;
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
        // Avoid u32 max int which is used to indicate a special state.
        const saturated = @min(std.math.maxInt(u32) - 1, count);
        @atomicStore(u32, &storage.estimated_total_count, saturated, .monotonic);
    }

    /// Thread-safe.
    pub fn increaseEstimatedTotalItems(n: Node, count: usize) void {
        const index = n.index.unwrap() orelse return;
        const storage = storageByIndex(index);
        _ = @atomicRmw(u32, &storage.estimated_total_count, .Add, std.math.lossyCast(u32, count), .monotonic);
    }

    /// Finish a started `Node`. Thread-safe.
    pub fn end(n: Node) void {
        if (noop_impl) {
            assert(n.index == .none);
            return;
        }
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

    /// Posix-only. Used by `std.process.Child`. Thread-safe.
    pub fn setIpcFd(node: Node, fd: posix.fd_t) void {
        const index = node.index.unwrap() orelse return;
        assert(fd >= 0);
        assert(fd != posix.STDOUT_FILENO);
        assert(fd != posix.STDIN_FILENO);
        assert(fd != posix.STDERR_FILENO);
        storageByIndex(index).setIpcFd(fd);
    }

    /// Posix-only. Thread-safe. Assumes the node is storing an IPC file
    /// descriptor.
    pub fn getIpcFd(node: Node) ?posix.fd_t {
        const index = node.index.unwrap() orelse return null;
        const storage = storageByIndex(index);
        const int = @atomicLoad(u32, &storage.completed_count, .monotonic);
        return switch (@typeInfo(posix.fd_t)) {
            .int => @bitCast(int),
            .pointer => @ptrFromInt(int),
            else => @compileError("unsupported fd_t of " ++ @typeName(posix.fd_t)),
        };
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
        assert(parent == .none or @intFromEnum(parent) < node_storage_buffer_len);

        const storage = storageByIndex(free_index);
        @atomicStore(u32, &storage.completed_count, 0, .monotonic);
        @atomicStore(u32, &storage.estimated_total_count, std.math.lossyCast(u32, estimated_total_items), .monotonic);
        const name_len = @min(max_name_len, name.len);
        copyAtomicStore(storage.name[0..name_len], name[0..name_len]);
        if (name_len < storage.name.len)
            @atomicStore(u8, &storage.name[name_len], 0, .monotonic);

        const parent_ptr = parentByIndex(free_index);
        assert(parent_ptr.* == .unused);
        @atomicStore(Node.Parent, parent_ptr, parent, .release);

        return .{ .index = free_index.toOptional() };
    }
};

var global_progress: Progress = .{
    .terminal = undefined,
    .terminal_mode = .off,
    .update_thread = null,
    .redraw_event = .{},
    .refresh_rate_ns = undefined,
    .initial_delay_ns = undefined,
    .rows = 0,
    .cols = 0,
    .draw_buffer = undefined,
    .done = false,
    .need_clear = false,

    .node_parents = &node_parents_buffer,
    .node_storage = &node_storage_buffer,
    .node_freelist = &node_freelist_buffer,
    .node_freelist_first = .none,
    .node_end_index = 0,
};

const node_storage_buffer_len = 83;
var node_parents_buffer: [node_storage_buffer_len]Node.Parent = undefined;
var node_storage_buffer: [node_storage_buffer_len]Node.Storage = undefined;
var node_freelist_buffer: [node_storage_buffer_len]Node.OptionalIndex = undefined;

var default_draw_buffer: [4096]u8 = undefined;

var debug_start_trace = std.debug.Trace.init;

pub const have_ipc = switch (builtin.os.tag) {
    .wasi, .freestanding, .windows => false,
    else => true,
};

const noop_impl = builtin.single_threaded or switch (builtin.os.tag) {
    .wasi, .freestanding => true,
    else => false,
};

/// Initializes a global Progress instance.
///
/// Asserts there is only one global Progress instance.
///
/// Call `Node.end` when done.
pub fn start(options: Options) Node {
    // Ensure there is only 1 global Progress object.
    if (global_progress.node_end_index != 0) {
        debug_start_trace.dump();
        unreachable;
    }
    debug_start_trace.add("first initialized here");

    @memset(global_progress.node_parents, .unused);
    const root_node = Node.init(@enumFromInt(0), .none, options.root_name, options.estimated_total_items);
    global_progress.done = false;
    global_progress.node_end_index = 1;

    assert(options.draw_buffer.len >= 200);
    global_progress.draw_buffer = options.draw_buffer;
    global_progress.refresh_rate_ns = options.refresh_rate_ns;
    global_progress.initial_delay_ns = options.initial_delay_ns;

    if (noop_impl)
        return Node.none;

    if (std.process.parseEnvVarInt("ZIG_PROGRESS", u31, 10)) |ipc_fd| {
        global_progress.update_thread = std.Thread.spawn(.{}, ipcThreadRun, .{
            @as(posix.fd_t, switch (@typeInfo(posix.fd_t)) {
                .int => ipc_fd,
                .pointer => @ptrFromInt(ipc_fd),
                else => @compileError("unsupported fd_t of " ++ @typeName(posix.fd_t)),
            }),
        }) catch |err| {
            std.log.warn("failed to spawn IPC thread for communicating progress to parent: {s}", .{@errorName(err)});
            return Node.none;
        };
    } else |env_err| switch (env_err) {
        error.EnvironmentVariableNotFound => {
            if (options.disable_printing) {
                return Node.none;
            }
            const stderr = std.io.getStdErr();
            global_progress.terminal = stderr;
            if (stderr.getOrEnableAnsiEscapeSupport()) {
                global_progress.terminal_mode = .ansi_escape_codes;
            } else if (is_windows and stderr.isTty()) {
                global_progress.terminal_mode = TerminalMode{ .windows_api = .{
                    .code_page = windows.kernel32.GetConsoleOutputCP(),
                } };
            }

            if (global_progress.terminal_mode == .off) {
                return Node.none;
            }

            if (have_sigwinch) {
                var act: posix.Sigaction = .{
                    .handler = .{ .sigaction = handleSigWinch },
                    .mask = posix.empty_sigset,
                    .flags = (posix.SA.SIGINFO | posix.SA.RESTART),
                };
                posix.sigaction(posix.SIG.WINCH, &act, null);
            }

            if (switch (global_progress.terminal_mode) {
                .off => unreachable, // handled a few lines above
                .ansi_escape_codes => std.Thread.spawn(.{}, updateThreadRun, .{}),
                .windows_api => if (is_windows) std.Thread.spawn(.{}, windowsApiUpdateThreadRun, .{}) else unreachable,
            }) |thread| {
                global_progress.update_thread = thread;
            } else |err| {
                std.log.warn("unable to spawn thread for printing progress to terminal: {s}", .{@errorName(err)});
                return Node.none;
            }
        },
        else => |e| {
            std.log.warn("invalid ZIG_PROGRESS file descriptor integer: {s}", .{@errorName(e)});
            return Node.none;
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
    // Store this data in the thread so that it does not need to be part of the
    // linker data of the main executable.
    var serialized_buffer: Serialized.Buffer = undefined;

    {
        const resize_flag = wait(global_progress.initial_delay_ns);
        if (@atomicLoad(bool, &global_progress.done, .seq_cst)) return;
        maybeUpdateSize(resize_flag);

        const buffer, _ = computeRedraw(&serialized_buffer);
        if (stderr_mutex.tryLock()) {
            defer stderr_mutex.unlock();
            write(buffer) catch return;
            global_progress.need_clear = true;
        }
    }

    while (true) {
        const resize_flag = wait(global_progress.refresh_rate_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst)) {
            stderr_mutex.lock();
            defer stderr_mutex.unlock();
            return clearWrittenWithEscapeCodes() catch {};
        }

        maybeUpdateSize(resize_flag);

        const buffer, _ = computeRedraw(&serialized_buffer);
        if (stderr_mutex.tryLock()) {
            defer stderr_mutex.unlock();
            write(buffer) catch return;
            global_progress.need_clear = true;
        }
    }
}

fn windowsApiWriteMarker() void {
    // Write the marker that we will use to find the beginning of the progress when clearing.
    // Note: This doesn't have to use WriteConsoleW, but doing so avoids dealing with the code page.
    var num_chars_written: windows.DWORD = undefined;
    const handle = global_progress.terminal.handle;
    _ = windows.kernel32.WriteConsoleW(handle, &[_]u16{windows_api_start_marker}, 1, &num_chars_written, null);
}

fn windowsApiUpdateThreadRun() void {
    var serialized_buffer: Serialized.Buffer = undefined;

    {
        const resize_flag = wait(global_progress.initial_delay_ns);
        if (@atomicLoad(bool, &global_progress.done, .seq_cst)) return;
        maybeUpdateSize(resize_flag);

        const buffer, const nl_n = computeRedraw(&serialized_buffer);
        if (stderr_mutex.tryLock()) {
            defer stderr_mutex.unlock();
            windowsApiWriteMarker();
            write(buffer) catch return;
            global_progress.need_clear = true;
            windowsApiMoveToMarker(nl_n) catch return;
        }
    }

    while (true) {
        const resize_flag = wait(global_progress.refresh_rate_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst)) {
            stderr_mutex.lock();
            defer stderr_mutex.unlock();
            return clearWrittenWindowsApi() catch {};
        }

        maybeUpdateSize(resize_flag);

        const buffer, const nl_n = computeRedraw(&serialized_buffer);
        if (stderr_mutex.tryLock()) {
            defer stderr_mutex.unlock();
            clearWrittenWindowsApi() catch return;
            windowsApiWriteMarker();
            write(buffer) catch return;
            global_progress.need_clear = true;
            windowsApiMoveToMarker(nl_n) catch return;
        }
    }
}

/// Allows the caller to freely write to stderr until `unlockStdErr` is called.
///
/// During the lock, any `std.Progress` information is cleared from the terminal.
///
/// The lock is recursive; the same thread may hold the lock multiple times.
pub fn lockStdErr() void {
    stderr_mutex.lock();
    clearWrittenWithEscapeCodes() catch {};
}

pub fn unlockStdErr() void {
    stderr_mutex.unlock();
}

fn ipcThreadRun(fd: posix.fd_t) anyerror!void {
    // Store this data in the thread so that it does not need to be part of the
    // linker data of the main executable.
    var serialized_buffer: Serialized.Buffer = undefined;

    {
        _ = wait(global_progress.initial_delay_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return;

        const serialized = serialize(&serialized_buffer);
        writeIpc(fd, serialized) catch |err| switch (err) {
            error.BrokenPipe => return,
        };
    }

    while (true) {
        _ = wait(global_progress.refresh_rate_ns);

        if (@atomicLoad(bool, &global_progress.done, .seq_cst))
            return;

        const serialized = serialize(&serialized_buffer);
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

const TreeSymbol = enum {
    /// ├─
    tee,
    /// │
    line,
    /// └─
    langle,

    const Encoding = enum {
        ansi_escapes,
        code_page_437,
        utf8,
        ascii,
    };

    /// The escape sequence representation as a string literal
    fn escapeSeq(symbol: TreeSymbol) *const [9:0]u8 {
        return switch (symbol) {
            .tee => "\x1B\x28\x30\x74\x71\x1B\x28\x42 ",
            .line => "\x1B\x28\x30\x78\x1B\x28\x42  ",
            .langle => "\x1B\x28\x30\x6d\x71\x1B\x28\x42 ",
        };
    }

    fn bytes(symbol: TreeSymbol, encoding: Encoding) []const u8 {
        return switch (encoding) {
            .ansi_escapes => escapeSeq(symbol),
            .code_page_437 => switch (symbol) {
                .tee => "\xC3\xC4 ",
                .line => "\xB3  ",
                .langle => "\xC0\xC4 ",
            },
            .utf8 => switch (symbol) {
                .tee => "├─ ",
                .line => "│  ",
                .langle => "└─ ",
            },
            .ascii => switch (symbol) {
                .tee => "|- ",
                .line => "|  ",
                .langle => "+- ",
            },
        };
    }

    fn maxByteLen(symbol: TreeSymbol) usize {
        var max: usize = 0;
        inline for (@typeInfo(Encoding).@"enum".fields) |field| {
            const len = symbol.bytes(@field(Encoding, field.name)).len;
            max = @max(max, len);
        }
        return max;
    }
};

fn appendTreeSymbol(symbol: TreeSymbol, buf: []u8, start_i: usize) usize {
    switch (global_progress.terminal_mode) {
        .off => unreachable,
        .ansi_escape_codes => {
            const bytes = symbol.escapeSeq();
            buf[start_i..][0..bytes.len].* = bytes.*;
            return start_i + bytes.len;
        },
        .windows_api => |windows_api| {
            const bytes = if (!is_windows) unreachable else switch (windows_api.code_page) {
                // Code page 437 is the default code page and contains the box drawing symbols
                437 => symbol.bytes(.code_page_437),
                // UTF-8
                65001 => symbol.bytes(.utf8),
                // Fall back to ASCII approximation
                else => symbol.bytes(.ascii),
            };
            @memcpy(buf[start_i..][0..bytes.len], bytes);
            return start_i + bytes.len;
        },
    }
}

fn clearWrittenWithEscapeCodes() anyerror!void {
    if (!global_progress.need_clear) return;

    global_progress.need_clear = false;
    try write(clear);
}

/// U+25BA or ►
const windows_api_start_marker = 0x25BA;

fn clearWrittenWindowsApi() error{Unexpected}!void {
    // This uses a 'marker' strategy. The idea is:
    // - Always write a marker (in this case U+25BA or ►) at the beginning of the progress
    // - Get the current cursor position (at the end of the progress)
    // - Subtract the number of lines written to get the expected start of the progress
    // - Check to see if the first character at the start of the progress is the marker
    // - If it's not the marker, keep checking the line before until we find it
    // - Clear the screen from that position down, and set the cursor position to the start
    //
    // This strategy works even if there is line wrapping, and can handle the window
    // being resized/scrolled arbitrarily.
    //
    // Notes:
    // - Ideally, the marker would be a zero-width character, but the Windows console
    //   doesn't seem to support rendering zero-width characters (they show up as a space)
    // - This same marker idea could technically be done with an attribute instead
    //   (https://learn.microsoft.com/en-us/windows/console/console-screen-buffers#character-attributes)
    //   but it must be a valid attribute and it actually needs to apply to the first
    //   character in order to be readable via ReadConsoleOutputAttribute. It doesn't seem
    //   like any of the available attributes are invisible/benign.
    if (!global_progress.need_clear) return;
    const handle = global_progress.terminal.handle;
    const screen_area = @as(windows.DWORD, global_progress.cols) * global_progress.rows;

    var console_info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (windows.kernel32.GetConsoleScreenBufferInfo(handle, &console_info) == 0) {
        return error.Unexpected;
    }
    var num_chars_written: windows.DWORD = undefined;
    if (windows.kernel32.FillConsoleOutputCharacterW(handle, ' ', screen_area, console_info.dwCursorPosition, &num_chars_written) == 0) {
        return error.Unexpected;
    }
}

fn windowsApiMoveToMarker(nl_n: usize) error{Unexpected}!void {
    const handle = global_progress.terminal.handle;
    var console_info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (windows.kernel32.GetConsoleScreenBufferInfo(handle, &console_info) == 0) {
        return error.Unexpected;
    }
    const cursor_pos = console_info.dwCursorPosition;
    const expected_y = cursor_pos.Y - @as(i16, @intCast(nl_n));
    var start_pos: windows.COORD = .{ .X = 0, .Y = expected_y };
    while (start_pos.Y >= 0) {
        var wchar: [1]u16 = undefined;
        var num_console_chars_read: windows.DWORD = undefined;
        if (windows.kernel32.ReadConsoleOutputCharacterW(handle, &wchar, wchar.len, start_pos, &num_console_chars_read) == 0) {
            return error.Unexpected;
        }

        if (wchar[0] == windows_api_start_marker) break;
        start_pos.Y -= 1;
    } else {
        // If we couldn't find the marker, then just assume that no lines wrapped
        start_pos = .{ .X = 0, .Y = expected_y };
    }
    if (windows.kernel32.SetConsoleCursorPosition(handle, start_pos) == 0) {
        return error.Unexpected;
    }
}

const Children = struct {
    child: Node.OptionalIndex,
    sibling: Node.OptionalIndex,
};

const Serialized = struct {
    parents: []Node.Parent,
    storage: []Node.Storage,

    const Buffer = struct {
        parents: [node_storage_buffer_len]Node.Parent,
        storage: [node_storage_buffer_len]Node.Storage,
        map: [node_storage_buffer_len]Node.OptionalIndex,

        parents_copy: [node_storage_buffer_len]Node.Parent,
        storage_copy: [node_storage_buffer_len]Node.Storage,
        ipc_metadata_fds_copy: [node_storage_buffer_len]Fd,
        ipc_metadata_copy: [node_storage_buffer_len]SavedMetadata,

        ipc_metadata_fds: [node_storage_buffer_len]Fd,
        ipc_metadata: [node_storage_buffer_len]SavedMetadata,
    };
};

fn serialize(serialized_buffer: *Serialized.Buffer) Serialized {
    var serialized_len: usize = 0;
    var any_ipc = false;

    // Iterate all of the nodes and construct a serializable copy of the state that can be examined
    // without atomics.
    const end_index = @atomicLoad(u32, &global_progress.node_end_index, .monotonic);
    for (
        global_progress.node_parents[0..end_index],
        global_progress.node_storage[0..end_index],
        serialized_buffer.map[0..end_index],
    ) |*parent_ptr, *storage_ptr, *map| {
        var begin_parent = @atomicLoad(Node.Parent, parent_ptr, .acquire);
        while (begin_parent != .unused) {
            const dest_storage = &serialized_buffer.storage[serialized_len];
            copyAtomicLoad(&dest_storage.name, &storage_ptr.name);
            dest_storage.estimated_total_count = @atomicLoad(u32, &storage_ptr.estimated_total_count, .acquire);
            dest_storage.completed_count = @atomicLoad(u32, &storage_ptr.completed_count, .monotonic);
            const end_parent = @atomicLoad(Node.Parent, parent_ptr, .acquire);
            if (begin_parent == end_parent) {
                any_ipc = any_ipc or (dest_storage.getIpcFd() != null);
                serialized_buffer.parents[serialized_len] = begin_parent;
                map.* = @enumFromInt(serialized_len);
                serialized_len += 1;
                break;
            }

            begin_parent = end_parent;
        } else {
            // A node may be freed during the execution of this loop, causing
            // there to be a parent reference to a nonexistent node. Without
            // this assignment, this would lead to the map entry containing
            // stale data. By assigning none, the child node with the bad
            // parent pointer will be harmlessly omitted from the tree.
            map.* = .none;
        }
    }

    // Remap parents to point inside serialized arrays.
    for (serialized_buffer.parents[0..serialized_len]) |*parent| {
        parent.* = switch (parent.*) {
            .unused => unreachable,
            .none => .none,
            _ => |p| serialized_buffer.map[@intFromEnum(p)].toParent(),
        };
    }

    // Find nodes which correspond to child processes.
    if (any_ipc)
        serialized_len = serializeIpc(serialized_len, serialized_buffer);

    return .{
        .parents = serialized_buffer.parents[0..serialized_len],
        .storage = serialized_buffer.storage[0..serialized_len],
    };
}

const SavedMetadata = struct {
    remaining_read_trash_bytes: u16,
    main_index: u8,
    start_index: u8,
    nodes_len: u8,
};

const Fd = enum(i32) {
    _,

    fn init(fd: posix.fd_t) Fd {
        return @enumFromInt(if (is_windows) @as(isize, @bitCast(@intFromPtr(fd))) else fd);
    }

    fn get(fd: Fd) posix.fd_t {
        return if (is_windows)
            @ptrFromInt(@as(usize, @bitCast(@as(isize, @intFromEnum(fd)))))
        else
            @intFromEnum(fd);
    }
};

var ipc_metadata_len: u8 = 0;

fn serializeIpc(start_serialized_len: usize, serialized_buffer: *Serialized.Buffer) usize {
    const ipc_metadata_fds_copy = &serialized_buffer.ipc_metadata_fds_copy;
    const ipc_metadata_copy = &serialized_buffer.ipc_metadata_copy;
    const ipc_metadata_fds = &serialized_buffer.ipc_metadata_fds;
    const ipc_metadata = &serialized_buffer.ipc_metadata;

    var serialized_len = start_serialized_len;
    var pipe_buf: [2 * 4096]u8 = undefined;

    const old_ipc_metadata_fds = ipc_metadata_fds_copy[0..ipc_metadata_len];
    const old_ipc_metadata = ipc_metadata_copy[0..ipc_metadata_len];
    ipc_metadata_len = 0;

    main_loop: for (
        serialized_buffer.parents[0..serialized_len],
        serialized_buffer.storage[0..serialized_len],
        0..,
    ) |main_parent, *main_storage, main_index| {
        if (main_parent == .unused) continue;
        const fd = main_storage.getIpcFd() orelse continue;
        const opt_saved_metadata = findOld(fd, old_ipc_metadata_fds, old_ipc_metadata);
        var bytes_read: usize = 0;
        while (true) {
            const n = posix.read(fd, pipe_buf[bytes_read..]) catch |err| switch (err) {
                error.WouldBlock => break,
                else => |e| {
                    std.log.debug("failed to read child progress data: {s}", .{@errorName(e)});
                    main_storage.completed_count = 0;
                    main_storage.estimated_total_count = 0;
                    continue :main_loop;
                },
            };
            if (n == 0) break;
            if (opt_saved_metadata) |m| {
                if (m.remaining_read_trash_bytes > 0) {
                    assert(bytes_read == 0);
                    if (m.remaining_read_trash_bytes >= n) {
                        m.remaining_read_trash_bytes = @intCast(m.remaining_read_trash_bytes - n);
                        continue;
                    }
                    const src = pipe_buf[m.remaining_read_trash_bytes..n];
                    std.mem.copyForwards(u8, &pipe_buf, src);
                    m.remaining_read_trash_bytes = 0;
                    bytes_read = src.len;
                    continue;
                }
            }
            bytes_read += n;
        }
        // Ignore all but the last message on the pipe.
        var input: []u8 = pipe_buf[0..bytes_read];
        if (input.len == 0) {
            serialized_len = useSavedIpcData(serialized_len, serialized_buffer, main_storage, main_index, opt_saved_metadata, 0, fd);
            continue;
        }

        const storage, const parents = while (true) {
            const subtree_len: usize = input[0];
            const expected_bytes = 1 + subtree_len * (@sizeOf(Node.Storage) + @sizeOf(Node.Parent));
            if (input.len < expected_bytes) {
                // Ignore short reads. We'll handle the next full message when it comes instead.
                const remaining_read_trash_bytes: u16 = @intCast(expected_bytes - input.len);
                serialized_len = useSavedIpcData(serialized_len, serialized_buffer, main_storage, main_index, opt_saved_metadata, remaining_read_trash_bytes, fd);
                continue :main_loop;
            }
            if (input.len > expected_bytes) {
                input = input[expected_bytes..];
                continue;
            }
            const storage_bytes = input[1..][0 .. subtree_len * @sizeOf(Node.Storage)];
            const parents_bytes = input[1 + storage_bytes.len ..][0 .. subtree_len * @sizeOf(Node.Parent)];
            break .{
                std.mem.bytesAsSlice(Node.Storage, storage_bytes),
                std.mem.bytesAsSlice(Node.Parent, parents_bytes),
            };
        };

        const nodes_len: u8 = @intCast(@min(parents.len - 1, serialized_buffer.storage.len - serialized_len));

        // Remember in case the pipe is empty on next update.
        ipc_metadata_fds[ipc_metadata_len] = Fd.init(fd);
        ipc_metadata[ipc_metadata_len] = .{
            .remaining_read_trash_bytes = 0,
            .start_index = @intCast(serialized_len),
            .nodes_len = nodes_len,
            .main_index = @intCast(main_index),
        };
        ipc_metadata_len += 1;

        // Mount the root here.
        copyRoot(main_storage, &storage[0]);
        if (is_big_endian) main_storage.byteSwap();

        // Copy the rest of the tree to the end.
        const storage_dest = serialized_buffer.storage[serialized_len..][0..nodes_len];
        @memcpy(storage_dest, storage[1..][0..nodes_len]);

        // Always little-endian over the pipe.
        if (is_big_endian) for (storage_dest) |*s| s.byteSwap();

        // Patch up parent pointers taking into account how the subtree is mounted.
        for (serialized_buffer.parents[serialized_len..][0..nodes_len], parents[1..][0..nodes_len]) |*dest, p| {
            dest.* = switch (p) {
                // Fix bad data so the rest of the code does not see `unused`.
                .none, .unused => .none,
                // Root node is being mounted here.
                @as(Node.Parent, @enumFromInt(0)) => @enumFromInt(main_index),
                // Other nodes mounted at the end.
                // Don't trust child data; if the data is outside the expected range, ignore the data.
                // This also handles the case when data was truncated.
                _ => |off| if (@intFromEnum(off) > nodes_len)
                    .none
                else
                    @enumFromInt(serialized_len + @intFromEnum(off) - 1),
            };
        }

        serialized_len += nodes_len;
    }

    // Save a copy in case any pipes are empty on the next update.
    @memcpy(serialized_buffer.parents_copy[0..serialized_len], serialized_buffer.parents[0..serialized_len]);
    @memcpy(serialized_buffer.storage_copy[0..serialized_len], serialized_buffer.storage[0..serialized_len]);
    @memcpy(ipc_metadata_fds_copy[0..ipc_metadata_len], ipc_metadata_fds[0..ipc_metadata_len]);
    @memcpy(ipc_metadata_copy[0..ipc_metadata_len], ipc_metadata[0..ipc_metadata_len]);

    return serialized_len;
}

fn copyRoot(dest: *Node.Storage, src: *align(1) Node.Storage) void {
    dest.* = .{
        .completed_count = src.completed_count,
        .estimated_total_count = src.estimated_total_count,
        .name = if (src.name[0] == 0) dest.name else src.name,
    };
}

fn findOld(
    ipc_fd: posix.fd_t,
    old_metadata_fds: []Fd,
    old_metadata: []SavedMetadata,
) ?*SavedMetadata {
    for (old_metadata_fds, old_metadata) |fd, *m| {
        if (fd.get() == ipc_fd)
            return m;
    }
    return null;
}

fn useSavedIpcData(
    start_serialized_len: usize,
    serialized_buffer: *Serialized.Buffer,
    main_storage: *Node.Storage,
    main_index: usize,
    opt_saved_metadata: ?*SavedMetadata,
    remaining_read_trash_bytes: u16,
    fd: posix.fd_t,
) usize {
    const parents_copy = &serialized_buffer.parents_copy;
    const storage_copy = &serialized_buffer.storage_copy;
    const ipc_metadata_fds = &serialized_buffer.ipc_metadata_fds;
    const ipc_metadata = &serialized_buffer.ipc_metadata;

    const saved_metadata = opt_saved_metadata orelse {
        main_storage.completed_count = 0;
        main_storage.estimated_total_count = 0;
        if (remaining_read_trash_bytes > 0) {
            ipc_metadata_fds[ipc_metadata_len] = Fd.init(fd);
            ipc_metadata[ipc_metadata_len] = .{
                .remaining_read_trash_bytes = remaining_read_trash_bytes,
                .start_index = @intCast(start_serialized_len),
                .nodes_len = 0,
                .main_index = @intCast(main_index),
            };
            ipc_metadata_len += 1;
        }
        return start_serialized_len;
    };

    const start_index = saved_metadata.start_index;
    const nodes_len = @min(saved_metadata.nodes_len, serialized_buffer.storage.len - start_serialized_len);
    const old_main_index = saved_metadata.main_index;

    ipc_metadata_fds[ipc_metadata_len] = Fd.init(fd);
    ipc_metadata[ipc_metadata_len] = .{
        .remaining_read_trash_bytes = remaining_read_trash_bytes,
        .start_index = @intCast(start_serialized_len),
        .nodes_len = nodes_len,
        .main_index = @intCast(main_index),
    };
    ipc_metadata_len += 1;

    const parents = parents_copy[start_index..][0..nodes_len];
    const storage = storage_copy[start_index..][0..nodes_len];

    copyRoot(main_storage, &storage_copy[old_main_index]);

    @memcpy(serialized_buffer.storage[start_serialized_len..][0..storage.len], storage);

    for (serialized_buffer.parents[start_serialized_len..][0..parents.len], parents) |*dest, p| {
        dest.* = switch (p) {
            .none, .unused => .none,
            _ => |prev| d: {
                if (@intFromEnum(prev) == old_main_index) {
                    break :d @enumFromInt(main_index);
                } else if (@intFromEnum(prev) > nodes_len) {
                    break :d .none;
                } else {
                    break :d @enumFromInt(@intFromEnum(prev) - start_index + start_serialized_len);
                }
            },
        };
    }

    return start_serialized_len + storage.len;
}

fn computeRedraw(serialized_buffer: *Serialized.Buffer) struct { []u8, usize } {
    const serialized = serialize(serialized_buffer);

    // Now we can analyze our copy of the graph without atomics, reconstructing
    // children lists which do not exist in the canonical data. These are
    // needed for tree traversal below.

    var children_buffer: [node_storage_buffer_len]Children = undefined;
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

    // The strategy is, with every redraw:
    // erase to end of screen, write, move cursor to beginning of line, move cursor up N lines
    // This keeps the cursor at the beginning so that unlocked stderr writes
    // don't get eaten by the clear.

    var i: usize = 0;
    const buf = global_progress.draw_buffer;

    if (global_progress.terminal_mode == .ansi_escape_codes) {
        buf[i..][0..start_sync.len].* = start_sync.*;
        i += start_sync.len;
    }

    switch (global_progress.terminal_mode) {
        .off => unreachable,
        .ansi_escape_codes => {
            buf[i..][0..clear.len].* = clear.*;
            i += clear.len;
        },
        .windows_api => if (!is_windows) unreachable,
    }

    const root_node_index: Node.Index = @enumFromInt(0);
    i, const nl_n = computeNode(buf, i, 0, serialized, children, root_node_index);

    if (global_progress.terminal_mode == .ansi_escape_codes) {
        if (nl_n > 0) {
            buf[i] = '\r';
            i += 1;
            for (0..nl_n) |_| {
                buf[i..][0..up_one_line.len].* = up_one_line.*;
                i += up_one_line.len;
            }
        }

        buf[i..][0..finish_sync.len].* = finish_sync.*;
        i += finish_sync.len;
    }

    return .{ buf[0..i], nl_n };
}

fn computePrefix(
    buf: []u8,
    start_i: usize,
    nl_n: usize,
    serialized: Serialized,
    children: []const Children,
    node_index: Node.Index,
) usize {
    var i = start_i;
    const parent_index = serialized.parents[@intFromEnum(node_index)].unwrap() orelse return i;
    if (serialized.parents[@intFromEnum(parent_index)] == .none) return i;
    if (@intFromEnum(serialized.parents[@intFromEnum(parent_index)]) == 0 and
        serialized.storage[0].name[0] == 0)
    {
        return i;
    }
    i = computePrefix(buf, i, nl_n, serialized, children, parent_index);
    if (children[@intFromEnum(parent_index)].sibling == .none) {
        const prefix = "   ";
        const upper_bound_len = prefix.len + lineUpperBoundLen(nl_n);
        if (i + upper_bound_len > buf.len) return buf.len;
        buf[i..][0..prefix.len].* = prefix.*;
        i += prefix.len;
    } else {
        const upper_bound_len = TreeSymbol.line.maxByteLen() + lineUpperBoundLen(nl_n);
        if (i + upper_bound_len > buf.len) return buf.len;
        i = appendTreeSymbol(.line, buf, i);
    }
    return i;
}

fn lineUpperBoundLen(nl_n: usize) usize {
    // \r\n on Windows, \n otherwise.
    const nl_len = if (is_windows) 2 else 1;
    return @max(TreeSymbol.tee.maxByteLen(), TreeSymbol.langle.maxByteLen()) +
        "[4294967296/4294967296] ".len + Node.max_name_len + nl_len +
        (1 + (nl_n + 1) * up_one_line.len) +
        finish_sync.len;
}

fn computeNode(
    buf: []u8,
    start_i: usize,
    start_nl_n: usize,
    serialized: Serialized,
    children: []const Children,
    node_index: Node.Index,
) struct { usize, usize } {
    var i = start_i;
    var nl_n = start_nl_n;

    i = computePrefix(buf, i, nl_n, serialized, children, node_index);

    if (i + lineUpperBoundLen(nl_n) > buf.len)
        return .{ start_i, start_nl_n };

    const storage = &serialized.storage[@intFromEnum(node_index)];
    const estimated_total = storage.estimated_total_count;
    const completed_items = storage.completed_count;
    const name = if (std.mem.indexOfScalar(u8, &storage.name, 0)) |end| storage.name[0..end] else &storage.name;
    const parent = serialized.parents[@intFromEnum(node_index)];

    if (parent != .none) p: {
        if (@intFromEnum(parent) == 0 and serialized.storage[0].name[0] == 0) {
            break :p;
        }
        if (children[@intFromEnum(node_index)].sibling == .none) {
            i = appendTreeSymbol(.langle, buf, i);
        } else {
            i = appendTreeSymbol(.tee, buf, i);
        }
    }

    const is_empty_root = @intFromEnum(node_index) == 0 and serialized.storage[0].name[0] == 0;
    if (!is_empty_root) {
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
        if (is_windows) {
            // \r\n on Windows is necessary for the old console with the
            // ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN
            // console modes set to behave properly.
            buf[i] = '\r';
            i += 1;
        }
        buf[i] = '\n';
        i += 1;
        nl_n += 1;
    }

    if (global_progress.withinRowLimit(nl_n)) {
        if (children[@intFromEnum(node_index)].child.unwrap()) |child| {
            i, nl_n = computeNode(buf, i, nl_n, serialized, children, child);
        }
    }

    if (global_progress.withinRowLimit(nl_n)) {
        if (children[@intFromEnum(node_index)].sibling.unwrap()) |sibling| {
            i, nl_n = computeNode(buf, i, nl_n, serialized, children, sibling);
        }
    }

    return .{ i, nl_n };
}

fn withinRowLimit(p: *Progress, nl_n: usize) bool {
    // The +2 here is so that the PS1 is not scrolled off the top of the terminal.
    // one because we keep the cursor on the next line
    // one more to account for the PS1
    return nl_n + 2 < p.rows;
}

fn write(buf: []const u8) anyerror!void {
    try global_progress.terminal.writeAll(buf);
}

var remaining_write_trash_bytes: usize = 0;

fn writeIpc(fd: posix.fd_t, serialized: Serialized) error{BrokenPipe}!void {
    // Byteswap if necessary to ensure little endian over the pipe. This is
    // needed because the parent or child process might be running in qemu.
    if (is_big_endian) for (serialized.storage) |*s| s.byteSwap();

    assert(serialized.parents.len == serialized.storage.len);
    const serialized_len: u8 = @intCast(serialized.parents.len);
    const header = std.mem.asBytes(&serialized_len);
    const storage = std.mem.sliceAsBytes(serialized.storage);
    const parents = std.mem.sliceAsBytes(serialized.parents);

    var vecs: [3]posix.iovec_const = .{
        .{ .base = header.ptr, .len = header.len },
        .{ .base = storage.ptr, .len = storage.len },
        .{ .base = parents.ptr, .len = parents.len },
    };

    // Ensures the packet can fit in the pipe buffer.
    const upper_bound_msg_len = 1 + node_storage_buffer_len * @sizeOf(Node.Storage) +
        node_storage_buffer_len * @sizeOf(Node.OptionalIndex);
    comptime assert(upper_bound_msg_len <= 4096);

    while (remaining_write_trash_bytes > 0) {
        // We do this in a separate write call to give a better chance for the
        // writev below to be in a single packet.
        const n = @min(parents.len, remaining_write_trash_bytes);
        if (posix.write(fd, parents[0..n])) |written| {
            remaining_write_trash_bytes -= written;
            continue;
        } else |err| switch (err) {
            error.WouldBlock => return,
            error.BrokenPipe => return error.BrokenPipe,
            else => |e| {
                std.log.debug("failed to send progress to parent process: {s}", .{@errorName(e)});
                return error.BrokenPipe;
            },
        }
    }

    // If this write would block we do not want to keep trying, but we need to
    // know if a partial message was written.
    if (writevNonblock(fd, &vecs)) |written| {
        const total = header.len + storage.len + parents.len;
        if (written < total) {
            remaining_write_trash_bytes = total - written;
        }
    } else |err| switch (err) {
        error.WouldBlock => {},
        error.BrokenPipe => return error.BrokenPipe,
        else => |e| {
            std.log.debug("failed to send progress to parent process: {s}", .{@errorName(e)});
            return error.BrokenPipe;
        },
    }
}

fn writevNonblock(fd: posix.fd_t, iov: []posix.iovec_const) posix.WriteError!usize {
    var iov_index: usize = 0;
    var written: usize = 0;
    var total_written: usize = 0;
    while (true) {
        while (if (iov_index < iov.len)
            written >= iov[iov_index].len
        else
            return total_written) : (iov_index += 1) written -= iov[iov_index].len;
        iov[iov_index].base += written;
        iov[iov_index].len -= written;
        written = try posix.writev(fd, iov[iov_index..]);
        if (written == 0) return total_written;
        total_written += written;
    }
}

fn maybeUpdateSize(resize_flag: bool) void {
    if (!resize_flag) return;

    const fd = global_progress.terminal.handle;

    if (is_windows) {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;

        if (windows.kernel32.GetConsoleScreenBufferInfo(fd, &info) != windows.FALSE) {
            // In the old Windows console, dwSize.Y is the line count of the
            // entire scrollback buffer, so we use this instead so that we
            // always get the size of the screen.
            const screen_height = info.srWindow.Bottom - info.srWindow.Top;
            global_progress.rows = @intCast(screen_height);
            global_progress.cols = @intCast(info.dwSize.X);
        } else {
            std.log.debug("failed to determine terminal size; using conservative guess 80x25", .{});
            global_progress.rows = 25;
            global_progress.cols = 80;
        }
    } else {
        var winsize: posix.winsize = .{
            .row = 0,
            .col = 0,
            .xpixel = 0,
            .ypixel = 0,
        };

        const err = posix.system.ioctl(fd, posix.T.IOCGWINSZ, @intFromPtr(&winsize));
        if (posix.errno(err) == .SUCCESS) {
            global_progress.rows = winsize.row;
            global_progress.cols = winsize.col;
        } else {
            std.log.debug("failed to determine terminal size; using conservative guess 80x25", .{});
            global_progress.rows = 25;
            global_progress.cols = 80;
        }
    }
}

fn handleSigWinch(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
    _ = info;
    _ = ctx_ptr;
    assert(sig == posix.SIG.WINCH);
    global_progress.redraw_event.set();
}

const have_sigwinch = switch (builtin.os.tag) {
    .linux,
    .plan9,
    .solaris,
    .netbsd,
    .openbsd,
    .haiku,
    .macos,
    .ios,
    .watchos,
    .tvos,
    .visionos,
    .dragonfly,
    .freebsd,
    => true,

    else => false,
};

/// The primary motivation for recursive mutex here is so that a panic while
/// stderr mutex is held still dumps the stack trace and other debug
/// information.
var stderr_mutex = std.Thread.Mutex.Recursive.init;

fn copyAtomicStore(dest: []align(@alignOf(usize)) u8, src: []const u8) void {
    assert(dest.len == src.len);
    const chunked_len = dest.len / @sizeOf(usize);
    const dest_chunked: []usize = @as([*]usize, @ptrCast(dest))[0..chunked_len];
    const src_chunked: []align(1) const usize = @as([*]align(1) const usize, @ptrCast(src))[0..chunked_len];
    for (dest_chunked, src_chunked) |*d, s| {
        @atomicStore(usize, d, s, .monotonic);
    }
    const remainder_start = chunked_len * @sizeOf(usize);
    for (dest[remainder_start..], src[remainder_start..]) |*d, s| {
        @atomicStore(u8, d, s, .monotonic);
    }
}

fn copyAtomicLoad(
    dest: *align(@alignOf(usize)) [Node.max_name_len]u8,
    src: *align(@alignOf(usize)) const [Node.max_name_len]u8,
) void {
    const chunked_len = @divExact(dest.len, @sizeOf(usize));
    const dest_chunked: *[chunked_len]usize = @ptrCast(dest);
    const src_chunked: *const [chunked_len]usize = @ptrCast(src);
    for (dest_chunked, src_chunked) |*d, *s| {
        d.* = @atomicLoad(usize, s, .monotonic);
    }
}
