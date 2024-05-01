//! This API is non-allocating, non-fallible, and thread-safe.
//! The tradeoff is that users of this API must provide the storage
//! for each `Progress.Node`.
//!
//! Initialize the struct directly, overriding these fields as desired:
//! * `refresh_rate_ms`
//! * `initial_delay_ms`

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const testing = std.testing;
const assert = std.debug.assert;
const Progress = @This();

const output_buffer_rows = 20;
const output_buffer_cols = 200;

/// `null` if the current node (and its children) should
/// not print on update(), refreshes the `output_buffer` nonetheless
terminal: ?std.fs.File = undefined,

/// Is this a windows API terminal (note: this is not the same as being run on windows
/// because other terminals exist like MSYS/git-bash)
is_windows_terminal: bool = false,

/// Whether the terminal supports ANSI escape codes.
supports_ansi_escape_codes: bool = false,

/// If the terminal is "dumb", don't print output.
/// This can be useful if you don't want to print all
/// the stages of code generation if there are a lot.
/// You should not use it if the user should see output
/// for example showing the user what tests run.
dont_print_on_dumb: bool = false,

root: Node = undefined,

/// Keeps track of how much time has passed since the beginning.
/// Used to compare with `initial_delay_ms` and `refresh_rate_ms`.
timer: ?std.time.Timer = null,

/// When the previous refresh was written to the terminal.
/// Used to compare with `refresh_rate_ms`.
prev_refresh_timestamp: u64 = 0,

/// This buffer represents the maximum number of rows and columns
/// written to the terminal with each refresh.
output_buffer: [output_buffer_rows][output_buffer_cols]u8 = undefined,

/// This symbol will be used as a bullet in the tree listing.
bullet: u8 = '-',

/// How many nanoseconds between writing updates to the terminal.
refresh_rate_ns: u64 = 50 * std.time.ns_per_ms,

/// How many nanoseconds to keep the output hidden
initial_delay_ns: u64 = 500 * std.time.ns_per_ms,

done: bool = true,

/// Protects the `refresh` function, as well as `Node` attributes.
/// Without this, callsites would call `Node.end` and then free `Node` memory
/// while it was still being accessed by the `refresh` function.
update_mutex: std.Thread.Mutex = .{},

/// Keeps track of how many rows in the terminal have been output, so that
/// we can move the cursor back later.
rows_written: usize = 0,

/// Keeps track of how many cols in the terminal should be output for each row
columns_written: [output_buffer_rows]usize = [_]usize{0} ** output_buffer_rows,

/// Stores the current max width of the terminal.
/// If not available then 0.
max_columns: usize = 0,

/// Disable or enable truncating the buffer to the terminal width
respect_terminal_width: bool = true,

/// Replicate the old one-line style progress bar
emulate_one_line_bar: bool = false,

/// Represents one unit of progress. Each node can have children nodes, or
/// one can use integers with `update`.
pub const Node = struct {
    context: *Progress,
    parent: ?*Node,
    name: []const u8,
    unit: []const u8 = "",
    /// Depth of the Node within the tree
    node_tree_depth: usize = undefined,
    /// Must be handled using `update_mutex.lock` to be thread-safe.
    children: [presentable_children]?*Node = [1]?*Node{null} ** presentable_children,
    /// Must be handled atomically to be thread-safe. 0 means null.
    unprotected_estimated_total_items: usize,
    /// Must be handled atomically to be thread-safe.
    unprotected_completed_items: usize,

    const presentable_children = 10;

    /// Push this `Node` to the `parent.children` stack of the provided `Node` (insert at first index). Thread-safe
    fn tryPushToParentStack(self: *Node, target_node: *Node) void {
        const parent = target_node.parent orelse return;
        if (self.context.emulate_one_line_bar) {
            if (parent.children[0] == self) return;
        } else {
            inline for (parent.children) |child| if (child == self) return;
        }
        self.context.update_mutex.lock(); // lock below existence check for slight performance reasons
        defer self.context.update_mutex.unlock(); // (downside: less precision, but not noticeable)
        if (!self.context.emulate_one_line_bar) std.mem.copyBackwards(?*Node, parent.children[1..], parent.children[0 .. parent.children.len - 1]);
        parent.children[0] = self;
    }

    /// Remove this `Node` from the `parent.children` stack of the provided `Node`. Thread-safe
    fn tryRemoveFromParentStack(self: *Node, target_node: *Node) void {
        const parent = target_node.parent orelse return;
        self.context.update_mutex.lock();
        defer self.context.update_mutex.unlock();
        if (self.context.emulate_one_line_bar) {
            parent.children[0] = null;
        } else {
            const index = std.mem.indexOfScalar(?*Node, parent.children[0..], self) orelse return;
            std.mem.copyBackwards(?*Node, parent.children[index..], parent.children[index + 1 ..]);
            parent.children[parent.children.len - 1] = null;
        }
    }

    /// Create a new child progress node. Thread-safe.
    /// Call `Node.end` when done.
    /// TODO solve https://github.com/ziglang/zig/issues/2765 and then change this
    /// API to set `self.children` with the return value.
    /// Until that is fixed you probably want to call `activate` on the return value.
    /// Passing 0 for `estimated_total_items` means unknown.
    pub fn start(self: *Node, name: []const u8, estimated_total_items: usize) Node {
        return Node{
            .context = self.context,
            .parent = self,
            .name = name,
            .node_tree_depth = self.node_tree_depth + 1,
            .unprotected_estimated_total_items = estimated_total_items,
            .unprotected_completed_items = 0,
        };
    }

    /// This is the same as calling `start` and then `end` on the returned `Node`. Thread-safe.
    pub fn completeOne(self: *Node) void {
        _ = @atomicRmw(usize, &self.unprotected_completed_items, .Add, 1, .monotonic);
        self.context.maybeRefresh();
    }

    /// Finish a started `Node`. Thread-safe.
    pub fn end(self: *Node) void {
        self.context.maybeRefresh();
        if (self.parent) |parent| {
            self.tryRemoveFromParentStack(self);
            parent.completeOne();
        } else {
            self.context.update_mutex.lock();
            defer self.context.update_mutex.unlock();
            self.context.done = true;
            self.context.refreshWithHeldLock();
        }
    }

    /// Tell the parent node that this node is actively being worked on. Thread-safe.
    pub fn activate(self: *Node) void {
        self.tryPushToParentStack(self);
        self.context.maybeRefresh();
    }

    /// Tell the parent node that this node is not being worked on anymore. Thread-safe.
    pub fn deactivate(self: *Node) void {
        self.tryRemoveFromParentStack(self);
        self.context.maybeRefresh();
    }

    /// Will also tell the parent node that this node is actively being worked on. Thread-safe.
    pub fn setName(self: *Node, name: []const u8) void {
        self.tryPushToParentStack(self);
        const progress = self.context;
        progress.update_mutex.lock();
        defer progress.update_mutex.unlock();
        self.name = name;
        if (progress.timer) |*timer| progress.maybeRefreshWithHeldLock(timer);
    }

    /// Will also tell the parent node that this node is actively being worked on. Thread-safe.
    pub fn setUnit(self: *Node, unit: []const u8) void {
        self.tryPushToParentStack(self);
        const progress = self.context;
        progress.update_mutex.lock();
        defer progress.update_mutex.unlock();
        self.unit = unit;
        if (progress.timer) |*timer| progress.maybeRefreshWithHeldLock(timer);
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

/// Create a new progress node.
/// Call `Node.end` when done.
/// TODO solve https://github.com/ziglang/zig/issues/2765 and then change this
/// API to return Progress rather than accept it as a parameter.
/// `estimated_total_items` value of 0 means unknown.
pub fn start(self: *Progress, name: []const u8, estimated_total_items: usize) *Node {
    const stderr = std.io.getStdErr();
    self.terminal = null;
    if (stderr.supportsAnsiEscapeCodes()) {
        self.terminal = stderr;
        self.supports_ansi_escape_codes = true;
    } else if (builtin.os.tag == .windows and stderr.isTty()) {
        self.is_windows_terminal = true;
        self.terminal = stderr;
    } else if (builtin.os.tag != .windows) {
        // we are in a "dumb" terminal like in acme or writing to a file
        self.terminal = stderr;
    }
    self.root = Node{
        .context = self,
        .parent = null,
        .name = name,
        .node_tree_depth = 0,
        .unprotected_estimated_total_items = estimated_total_items,
        .unprotected_completed_items = 0,
    };
    if (self.respect_terminal_width) self.max_columns = determineTerminalWidth(self) orelse 0;
    self.timer = std.time.Timer.start() catch null;
    self.done = false;
    return &self.root;
}

/// Updates the terminal if enough time has passed since last update. Thread-safe.
pub fn maybeRefresh(self: *Progress) void {
    if (self.timer) |*timer| {
        if (self.respect_terminal_width) self.max_columns = determineTerminalWidth(self) orelse 0;
        if (!self.update_mutex.tryLock()) return;
        defer self.update_mutex.unlock();
        maybeRefreshWithHeldLock(self, timer);
    }
}

fn maybeRefreshWithHeldLock(self: *Progress, timer: *std.time.Timer) void {
    const now = timer.read();
    if (now < self.initial_delay_ns) return;
    // TODO I have observed this to happen sometimes. I think we need to follow Rust's
    // lead and guarantee monotonically increasing times in the std lib itself.
    if (now < self.prev_refresh_timestamp) return;
    if (now - self.prev_refresh_timestamp < self.refresh_rate_ns) return;
    return self.refreshWithHeldLock();
}

/// Updates the terminal and resets `self.next_refresh_timestamp`. Thread-safe.
pub fn refresh(self: *Progress) void {
    if (!self.update_mutex.tryLock()) return;
    defer self.update_mutex.unlock();

    return self.refreshWithHeldLock();
}

/// Determine the terminal window width in columns
fn determineTerminalWidth(self: *Progress) ?usize {
    if (self.terminal == null) return null;
    switch (builtin.os.tag) {
        .linux => {
            var window_size: std.os.linux.winsize = undefined;
            const exit_code = std.os.linux.ioctl(self.terminal.?.handle, std.os.linux.T.IOCGWINSZ, @intFromPtr(&window_size));
            if (exit_code < 0) return null;
            return @intCast(window_size.ws_col);
        },
        .macos => {
            var window_size: std.c.winsize = undefined;
            const exit_code = std.c.ioctl(self.terminal.?.handle, std.c.T.IOCGWINSZ, @intFromPtr(&window_size));
            if (exit_code < 0) return null;
            return @intCast(window_size.ws_col);
        },
        .windows => {
            if (!self.is_windows_terminal) return null;
            var screen_buffer_info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            const exit_code = windows.kernel32.GetConsoleScreenBufferInfo(self.terminal.?.handle, &screen_buffer_info);
            if (exit_code != windows.TRUE) return null;
            return @intCast(screen_buffer_info.dwSize.X - 1);
        },
        else => return null,
    }
    return null;
}

/// Clear previously written data and empty the `output_buffer`
fn clearWithHeldLock(p: *Progress) void {
    const file = p.terminal orelse return;

    // restore the cursor position by moving the cursor
    // `rows_written` cells up, beginning of line,
    // then clear to the end of the screen
    if (p.supports_ansi_escape_codes) {
        var buffer: [20]u8 = undefined;
        var end: usize = 0;

        if (p.rows_written == 0) {
            end += (std.fmt.bufPrint(buffer[end..], "\x1b[0G", .{}) catch unreachable).len; // beginning of line
            end += (std.fmt.bufPrint(buffer[end..], "\x1b[0K", .{}) catch unreachable).len; // clear till end of line
        } else {
            end += (std.fmt.bufPrint(buffer[end..], "\x1b[{d}F", .{p.rows_written}) catch unreachable).len; // move up and to start
            end += (std.fmt.bufPrint(buffer[end..], "\x1b[0J", .{}) catch unreachable).len; // clear till end of screen
        }

        _ = file.write(buffer[0..end]) catch {
            // stop trying to write to this file
            p.terminal = null;
        };
    } else if (builtin.os.tag == .windows and p.is_windows_terminal) winapi: {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info) != windows.TRUE) {
            // stop trying to write to this file
            p.terminal = null;
            break :winapi;
        }
        const cursor_pos = windows.COORD{
            .X = 0,
            .Y = info.dwCursorPosition.Y - @as(windows.SHORT, @intCast(p.rows_written)),
        };

        const fill_chars = @as(windows.DWORD, @intCast(info.dwSize.Y - cursor_pos.Y));

        var written: windows.DWORD = undefined;
        if (windows.kernel32.FillConsoleOutputAttribute(
            file.handle,
            info.wAttributes,
            fill_chars,
            cursor_pos,
            &written,
        ) != windows.TRUE) {
            // stop trying to write to this file
            p.terminal = null;
            break :winapi;
        }
        if (windows.kernel32.FillConsoleOutputCharacterW(
            file.handle,
            ' ',
            fill_chars,
            cursor_pos,
            &written,
        ) != windows.TRUE) {
            // stop trying to write to this file
            p.terminal = null;
            break :winapi;
        }
        if (windows.kernel32.SetConsoleCursorPosition(file.handle, cursor_pos) != windows.TRUE) {
            // stop trying to write to this file
            p.terminal = null;
            break :winapi;
        }
    } else {
        // we are in a "dumb" terminal like in acme or writing to a file
        _ = file.write("\n") catch {
            p.terminal = null;
        };
    }
    p.rows_written = 0;
    p.columns_written[0] = 0;
}

/// Write the `output_buffer` to the terminal
/// Together with `clearWithHeldLock` this method flushes the buffer
fn writeOutputBufferToFile(p: *Progress) void {
    const file = p.terminal orelse return;

    for (p.output_buffer[0 .. p.rows_written + 1], 0..) |output_row, row_index| {
        // Join the rows with LFs without requiring a large buffer
        if (row_index != 0) {
            _ = file.write("\n") catch {
                p.terminal = null;
                break;
            };
        }
        _ = file.write(output_row[0..p.columns_written[row_index]]) catch {
            // stop trying to write to this file
            p.terminal = null;
            break;
        };
    }
}

fn refreshWithHeldLock(self: *Progress) void {
    const is_dumb = !self.supports_ansi_escape_codes and !self.is_windows_terminal;
    if (is_dumb and self.dont_print_on_dumb) return;

    clearWithHeldLock(self);

    if (!self.done) {
        var need_newline = false;
        refreshOutputBufWithHeldLock(self, &self.root, &need_newline);
    }

    writeOutputBufferToFile(self);
    if (self.timer) |*timer| {
        self.prev_refresh_timestamp = timer.read();
    }
}

fn refreshOutputBufWithHeldLock(self: *Progress, node: *Node, need_newline: *bool) void {
    var need_ellipse = false;

    const eti = @atomicLoad(usize, &node.unprotected_estimated_total_items, .monotonic);
    const completed_items = @atomicLoad(usize, &node.unprotected_completed_items, .monotonic);
    const current_item = completed_items + 1;

    if (node.name.len != 0 or eti > 0) {
        if (need_newline.*) {
            if (self.emulate_one_line_bar) {
                self.bufWrite(" ", .{});
            } else {
                self.bufWriteLineFeed();
            }
            need_newline.* = false;
        }
        if (node.node_tree_depth > 0 and !self.emulate_one_line_bar) {
            const depth: usize = @min(10, node.node_tree_depth);
            const whitespace_length: usize = if (depth > 1) (depth - 1) * 2 else 0;
            self.bufWrite("{s: <[3]}{s}{c} ", .{
                "",
                if (node.node_tree_depth > 10) "_ " else "",
                self.bullet,
                whitespace_length,
            });
        }
        if (node.name.len != 0) {
            self.bufWrite("{s} ", .{node.name});
            need_ellipse = true;
        }
        if (eti > 0) {
            self.bufWrite("[{d}/{d}{s}]", .{ current_item, eti, node.unit });
            need_ellipse = false;
        } else if (completed_items != 0) {
            self.bufWrite("[{d}{s}]", .{ current_item, node.unit });
            need_ellipse = false;
        }
        if (need_ellipse) {
            self.bufWrite("...", .{});
        }

        need_newline.* = true;
    }

    for (node.children[0..if (self.emulate_one_line_bar) 1 else node.children.len]) |maybe_child| {
        if (maybe_child) |child| refreshOutputBufWithHeldLock(self, child, need_newline) else break;
    }
}

/// Print to the terminal, temporarily stopping the progress bar from flushing the buffer
pub fn log(self: *Progress, comptime format: []const u8, args: anytype) void {
    self.lock_stderr();
    defer self.unlock_stderr();
    const file = self.terminal orelse {
        std.debug.print(format, args);
        return;
    };
    file.writer().print(format, args) catch {
        self.terminal = null;
        return;
    };
}

/// Allows the caller to freely write to stderr until unlock_stderr() is called.
/// During the lock, the progress information is cleared from the terminal.
pub fn lock_stderr(p: *Progress) void {
    p.update_mutex.lock();
    clearWithHeldLock(p);
    writeOutputBufferToFile(p);
    std.debug.getStderrMutex().lock();
}

pub fn unlock_stderr(p: *Progress) void {
    std.debug.getStderrMutex().unlock();
    p.update_mutex.unlock();
}

/// Move to the next row in the buffer and reset the cursor position to 0
/// Ignores request if buffer is full
fn bufWriteLineFeed(self: *Progress) void {
    if (self.rows_written + 1 >= self.columns_written.len) return;
    self.rows_written += 1;
    self.columns_written[self.rows_written] = 0;
}

/// Append to the current row stored in the buffer
fn bufWrite(self: *Progress, comptime format: []const u8, args: anytype) void {
    comptime std.debug.assert(std.mem.count(u8, format, "\n") == 0);
    const output_row = &self.output_buffer[self.rows_written];
    const columns_written = &self.columns_written[self.rows_written];

    if (std.fmt.bufPrint(output_row[columns_written.*..], format, args)) |written| {
        columns_written.* += written.len;
    } else |err| switch (err) {
        error.NoSpaceLeft => {
            columns_written.* = output_row.len;
            const suffix = "...";
            @memcpy(output_row.*[output_row.*.len - suffix.len ..], suffix);
        },
    }

    if (self.max_columns != 0 and columns_written.* > self.max_columns) {
        const ellipse = "...";
        columns_written.* = self.max_columns;
        if (columns_written.* >= ellipse.len) @memcpy(output_row.*[columns_written.* - ellipse.len .. columns_written.*], ellipse);
    }
}

test "basic functionality" {
    var disable = true;
    _ = &disable;
    if (disable) {
        // This test is disabled because it uses time.sleep() and is therefore slow. It also
        // prints bogus progress data to stderr.
        return error.SkipZigTest;
    }
    var progress = Progress{};
    const root_node = progress.start("", 100);
    defer root_node.end();

    const speed_factor = std.time.ns_per_ms;

    const sub_task_names = [_][]const u8{
        "reticulating splines",
        "adjusting shoes",
        "climbing towers",
        "pouring juice",
    };
    var next_sub_task: usize = 0;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var node = root_node.start(sub_task_names[next_sub_task], 5);
        node.activate();
        next_sub_task = (next_sub_task + 1) % sub_task_names.len;

        node.completeOne();
        std.time.sleep(5 * speed_factor);
        node.completeOne();
        node.completeOne();
        std.time.sleep(5 * speed_factor);
        node.completeOne();
        node.completeOne();
        std.time.sleep(5 * speed_factor);

        node.end();

        std.time.sleep(5 * speed_factor);
    }
    {
        var node = root_node.start("this is a really long name designed to activate the truncation code. let's find out if it works", 0);
        node.activate();
        std.time.sleep(10 * speed_factor);
        progress.refresh();
        std.time.sleep(10 * speed_factor);
        node.end();
    }
}
