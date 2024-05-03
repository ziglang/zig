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

root: Node,

/// Protects all the state shared between the update thread and the public API calls.
mutex: std.Thread.Mutex,
update_thread: ?std.Thread,

/// Atomically set by SIGWINCH as well as the root done() function.
redraw_event: std.Thread.ResetEvent,
/// Ensure there is only 1 global Progress object.
initialized: bool,
/// Indicates a request to shut down and reset global state.
done: bool,

refresh_rate_ns: u64,
initial_delay_ns: u64,

rows: u16,
cols: u16,

/// Accessed only by the update thread.
draw_buffer: []u8,

pub const Options = struct {
    /// User-provided buffer with static lifetime.
    ///
    /// Used to store the entire write buffer sent to the terminal. Progress output will be truncated if it
    /// cannot fit into this buffer which will look bad but not cause any malfunctions.
    ///
    /// Must be at least 100 bytes.
    draw_buffer: []u8,
    /// How many nanoseconds between writing updates to the terminal.
    refresh_rate_ns: u64 = 50 * std.time.ns_per_ms,
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
    parent: ?*Node,
    name: []const u8,
    /// Must be handled atomically to be thread-safe.
    recently_updated_child: ?*Node = null,
    /// Must be handled atomically to be thread-safe. 0 means null.
    unprotected_estimated_total_items: usize,
    /// Must be handled atomically to be thread-safe.
    unprotected_completed_items: usize,

    pub const ListNode = std.DoublyLinkedList(void);

    /// Create a new child progress node. Thread-safe.
    ///
    /// Call `Node.end` when done.
    ///
    /// Passing 0 for `estimated_total_items` means unknown.
    pub fn start(self: *Node, name: []const u8, estimated_total_items: usize) Node {
        return .{
            .parent = self,
            .name = name,
            .unprotected_estimated_total_items = estimated_total_items,
            .unprotected_completed_items = 0,
        };
    }

    /// This is the same as calling `start` and then `end` on the returned `Node`. Thread-safe.
    pub fn completeOne(self: *Node) void {
        _ = @atomicRmw(usize, &self.unprotected_completed_items, .Add, 1, .monotonic);
        self.activate();
    }

    /// Finish a started `Node`. Thread-safe.
    pub fn end(self: *Node) void {
        if (self.parent) |parent| {
            parent.completeOne();
        } else {
            {
                global_progress.mutex.lock();
                defer global_progress.mutex.unlock();
                global_progress.done = true;
            }
            global_progress.redraw_event.set();
            if (global_progress.update_thread) |thread| thread.join();
        }
    }

    /// Tell the parent node that this node is actively being worked on. Thread-safe.
    pub fn activate(self: *Node) void {
        var parent = self.parent;
        var child = self;
        while (parent) |p| {
            @atomicStore(?*Node, &p.recently_updated_child, child, .release);
            child = p;
            parent = p.parent;
        }
    }

    /// Thread-safe. 0 means unknown.
    pub fn setEstimatedTotalItems(self: *Node, count: usize) void {
        @atomicStore(usize, &self.unprotected_estimated_total_items, count, .monotonic);
    }

    /// Thread-safe.
    pub fn setCompletedItems(self: *Node, completed_items: usize) void {
        @atomicStore(usize, &self.unprotected_completed_items, completed_items, .monotonic);
    }
};

var global_progress: Progress = .{
    .terminal = null,
    .is_windows_terminal = false,
    .supports_ansi_escape_codes = false,
    .root = undefined,
    .mutex = .{},
    .update_thread = null,
    .redraw_event = .{},
    .initialized = false,
    .refresh_rate_ns = undefined,
    .initial_delay_ns = undefined,
    .rows = 0,
    .cols = 0,
    .draw_buffer = undefined,
    .done = false,
};

/// Initializes a global Progress instance.
///
/// Asserts there is only one global Progress instance.
///
/// Call `Node.end` when done.
pub fn start(options: Options) *Node {
    assert(!global_progress.initialized);
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
    global_progress.root = .{
        .parent = null,
        .name = options.root_name,
        .unprotected_estimated_total_items = options.estimated_total_items,
        .unprotected_completed_items = 0,
    };
    global_progress.done = false;
    global_progress.initialized = true;

    assert(options.draw_buffer.len >= 100);
    global_progress.draw_buffer = options.draw_buffer;
    global_progress.refresh_rate_ns = options.refresh_rate_ns;
    global_progress.initial_delay_ns = options.initial_delay_ns;

    var act: posix.Sigaction = .{
        .handler = .{ .sigaction = handleSigWinch },
        .mask = posix.empty_sigset,
        .flags = (posix.SA.SIGINFO | posix.SA.RESTART),
    };
    posix.sigaction(posix.SIG.WINCH, &act, null) catch {
        global_progress.terminal = null;
        return &global_progress.root;
    };

    if (global_progress.terminal != null) {
        if (std.Thread.spawn(.{}, updateThreadRun, .{})) |thread| {
            global_progress.update_thread = thread;
        } else |_| {
            global_progress.terminal = null;
        }
    }

    return &global_progress.root;
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

        const buffer = b: {
            global_progress.mutex.lock();
            defer global_progress.mutex.unlock();

            if (global_progress.done) return clearTerminal();

            break :b computeRedraw();
        };
        write(buffer);
    }

    while (true) {
        const resize_flag = wait(global_progress.refresh_rate_ns);
        maybeUpdateSize(resize_flag);

        const buffer = b: {
            global_progress.mutex.lock();
            defer global_progress.mutex.unlock();

            if (global_progress.done) return clearTerminal();

            break :b computeRedraw();
        };
        write(buffer);
    }
}

const start_sync = "\x1b[?2026h";
const clear = "\x1b[J";
const save = "\x1b7";
const restore = "\x1b8";
const finish_sync = "\x1b[?2026l";

fn clearTerminal() void {
    write(clear);
}

fn computeRedraw() []u8 {
    // The strategy is: keep the cursor at the beginning, and then with every redraw:
    // erase, save, write, restore

    var i: usize = 0;
    const buf = global_progress.draw_buffer;

    const prefix = start_sync ++ clear ++ save;
    const suffix = restore ++ finish_sync;

    buf[0..prefix.len].* = prefix.*;
    i = prefix.len;

    // Walk the tree and write the progress output to the buffer.

    var node: *Node = &global_progress.root;
    while (true) {
        const eti = @atomicLoad(usize, &node.unprotected_estimated_total_items, .monotonic);
        const completed_items = @atomicLoad(usize, &node.unprotected_completed_items, .monotonic);

        if (node.name.len != 0 or eti > 0) {
            if (node.name.len != 0) {
                i += (std.fmt.bufPrint(buf[i..], "{s}", .{node.name}) catch @panic("TODO")).len;
            }
            if (eti > 0) {
                i += (std.fmt.bufPrint(buf[i..], "[{d}/{d}] ", .{ completed_items, eti }) catch @panic("TODO")).len;
            } else if (completed_items != 0) {
                i += (std.fmt.bufPrint(buf[i..], "[{d}] ", .{completed_items}) catch @panic("TODO")).len;
            }
        }

        node = @atomicLoad(?*Node, &node.recently_updated_child, .acquire) orelse break;
    }

    i = @min(global_progress.cols + prefix.len, i);

    buf[i..][0..suffix.len].* = suffix.*;
    i += suffix.len;

    return buf[0..i];
}

fn write(buf: []const u8) void {
    const tty = global_progress.terminal orelse return;
    tty.writeAll(buf) catch {
        global_progress.terminal = null;
    };
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
