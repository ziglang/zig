// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const windows = std.os.windows;
const testing = std.testing;
const assert = std.debug.assert;

/// This API is non-allocating and non-fallible. The tradeoff is that users of
/// this API must provide the storage for each `Progress.Node`.
/// Initialize the struct directly, overriding these fields as desired:
/// * `refresh_rate_ms`
/// * `initial_delay_ms`
pub const Progress = struct {
    /// `null` if the current node (and its children) should
    /// not print on update()
    terminal: ?std.fs.File = undefined,

    /// Whether the terminal supports ANSI escape codes.
    supports_ansi_escape_codes: bool = false,

    root: Node = undefined,

    /// Keeps track of how much time has passed since the beginning.
    /// Used to compare with `initial_delay_ms` and `refresh_rate_ms`.
    timer: std.time.Timer = undefined,

    /// When the previous refresh was written to the terminal.
    /// Used to compare with `refresh_rate_ms`.
    prev_refresh_timestamp: u64 = undefined,

    /// This buffer represents the maximum number of bytes written to the terminal
    /// with each refresh.
    output_buffer: [100]u8 = undefined,

    /// How many nanoseconds between writing updates to the terminal.
    refresh_rate_ns: u64 = 50 * std.time.ns_per_ms,

    /// How many nanoseconds to keep the output hidden
    initial_delay_ns: u64 = 500 * std.time.ns_per_ms,

    done: bool = true,

    /// Keeps track of how many columns in the terminal have been output, so that
    /// we can move the cursor back later.
    columns_written: usize = undefined,

    /// Represents one unit of progress. Each node can have children nodes, or
    /// one can use integers with `update`.
    pub const Node = struct {
        context: *Progress,
        parent: ?*Node,
        completed_items: usize,
        name: []const u8,
        recently_updated_child: ?*Node = null,

        /// This field may be updated freely.
        estimated_total_items: ?usize,

        /// Create a new child progress node.
        /// Call `Node.end` when done.
        /// TODO solve https://github.com/ziglang/zig/issues/2765 and then change this
        /// API to set `self.parent.recently_updated_child` with the return value.
        /// Until that is fixed you probably want to call `activate` on the return value.
        pub fn start(self: *Node, name: []const u8, estimated_total_items: ?usize) Node {
            return Node{
                .context = self.context,
                .parent = self,
                .completed_items = 0,
                .name = name,
                .estimated_total_items = estimated_total_items,
            };
        }

        /// This is the same as calling `start` and then `end` on the returned `Node`.
        pub fn completeOne(self: *Node) void {
            if (self.parent) |parent| parent.recently_updated_child = self;
            self.completed_items += 1;
            self.context.maybeRefresh();
        }

        pub fn end(self: *Node) void {
            self.context.maybeRefresh();
            if (self.parent) |parent| {
                if (parent.recently_updated_child) |parent_child| {
                    if (parent_child == self) {
                        parent.recently_updated_child = null;
                    }
                }
                parent.completeOne();
            } else {
                self.context.done = true;
                self.context.refresh();
            }
        }

        /// Tell the parent node that this node is actively being worked on.
        pub fn activate(self: *Node) void {
            if (self.parent) |parent| parent.recently_updated_child = self;
        }
    };

    /// Create a new progress node.
    /// Call `Node.end` when done.
    /// TODO solve https://github.com/ziglang/zig/issues/2765 and then change this
    /// API to return Progress rather than accept it as a parameter.
    pub fn start(self: *Progress, name: []const u8, estimated_total_items: ?usize) !*Node {
        const stderr = std.io.getStdErr();
        self.terminal = null;
        if (stderr.supportsAnsiEscapeCodes()) {
            self.terminal = stderr;
            self.supports_ansi_escape_codes = true;
        } else if (std.builtin.os.tag == .windows and stderr.isTty()) {
            self.terminal = stderr;
        }
        self.root = Node{
            .context = self,
            .parent = null,
            .completed_items = 0,
            .name = name,
            .estimated_total_items = estimated_total_items,
        };
        self.columns_written = 0;
        self.prev_refresh_timestamp = 0;
        self.timer = try std.time.Timer.start();
        self.done = false;
        return &self.root;
    }

    /// Updates the terminal if enough time has passed since last update.
    pub fn maybeRefresh(self: *Progress) void {
        const now = self.timer.read();
        if (now < self.initial_delay_ns) return;
        if (now - self.prev_refresh_timestamp < self.refresh_rate_ns) return;
        self.refresh();
    }

    /// Updates the terminal and resets `self.next_refresh_timestamp`.
    pub fn refresh(self: *Progress) void {
        const file = self.terminal orelse return;

        const prev_columns_written = self.columns_written;
        var end: usize = 0;
        if (self.columns_written > 0) {
            // restore the cursor position by moving the cursor
            // `columns_written` cells to the left, then clear the rest of the
            // line
            if (self.supports_ansi_escape_codes) {
                end += (std.fmt.bufPrint(self.output_buffer[end..], "\x1b[{}D", .{self.columns_written}) catch unreachable).len;
                end += (std.fmt.bufPrint(self.output_buffer[end..], "\x1b[0K", .{}) catch unreachable).len;
            } else if (std.builtin.os.tag == .windows) winapi: {
                var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                if (windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info) != windows.TRUE)
                    unreachable;

                var cursor_pos = windows.COORD{
                    .X = info.dwCursorPosition.X - @intCast(windows.SHORT, self.columns_written),
                    .Y = info.dwCursorPosition.Y,
                };

                if (cursor_pos.X < 0)
                    cursor_pos.X = 0;

                const fill_chars = @intCast(windows.DWORD, info.dwSize.X - cursor_pos.X);

                var written: windows.DWORD = undefined;
                if (windows.kernel32.FillConsoleOutputAttribute(
                    file.handle,
                    info.wAttributes,
                    fill_chars,
                    cursor_pos,
                    &written,
                ) != windows.TRUE) {
                    // Stop trying to write to this file.
                    self.terminal = null;
                    break :winapi;
                }
                if (windows.kernel32.FillConsoleOutputCharacterA(
                    file.handle,
                    ' ',
                    fill_chars,
                    cursor_pos,
                    &written,
                ) != windows.TRUE) unreachable;

                if (windows.kernel32.SetConsoleCursorPosition(file.handle, cursor_pos) != windows.TRUE)
                    unreachable;
            } else unreachable;

            self.columns_written = 0;
        }

        if (!self.done) {
            var need_ellipse = false;
            var maybe_node: ?*Node = &self.root;
            while (maybe_node) |node| {
                if (need_ellipse) {
                    self.bufWrite(&end, "... ", .{});
                }
                need_ellipse = false;
                if (node.name.len != 0 or node.estimated_total_items != null) {
                    if (node.name.len != 0) {
                        self.bufWrite(&end, "{}", .{node.name});
                        need_ellipse = true;
                    }
                    if (node.estimated_total_items) |total| {
                        if (need_ellipse) self.bufWrite(&end, " ", .{});
                        self.bufWrite(&end, "[{}/{}] ", .{ node.completed_items + 1, total });
                        need_ellipse = false;
                    } else if (node.completed_items != 0) {
                        if (need_ellipse) self.bufWrite(&end, " ", .{});
                        self.bufWrite(&end, "[{}] ", .{node.completed_items + 1});
                        need_ellipse = false;
                    }
                }
                maybe_node = node.recently_updated_child;
            }
            if (need_ellipse) {
                self.bufWrite(&end, "... ", .{});
            }
        }

        _ = file.write(self.output_buffer[0..end]) catch |e| {
            // Stop trying to write to this file once it errors.
            self.terminal = null;
        };
        self.prev_refresh_timestamp = self.timer.read();
    }

    pub fn log(self: *Progress, comptime format: []const u8, args: anytype) void {
        const file = self.terminal orelse return;
        self.refresh();
        file.outStream().print(format, args) catch {
            self.terminal = null;
            return;
        };
        self.columns_written = 0;
    }

    fn bufWrite(self: *Progress, end: *usize, comptime format: []const u8, args: anytype) void {
        if (std.fmt.bufPrint(self.output_buffer[end.*..], format, args)) |written| {
            const amt = written.len;
            end.* += amt;
            self.columns_written += amt;
        } else |err| switch (err) {
            error.NoSpaceLeft => {
                self.columns_written += self.output_buffer.len - end.*;
                end.* = self.output_buffer.len;
            },
        }
        const bytes_needed_for_esc_codes_at_end = if (std.builtin.os.tag == .windows) 0 else 11;
        const max_end = self.output_buffer.len - bytes_needed_for_esc_codes_at_end;
        if (end.* > max_end) {
            const suffix = "... ";
            self.columns_written = self.columns_written - (end.* - max_end) + suffix.len;
            std.mem.copy(u8, self.output_buffer[max_end..], suffix);
            end.* = max_end + suffix.len;
        }
    }
};

test "basic functionality" {
    var disable = true;
    if (disable) {
        // This test is disabled because it uses time.sleep() and is therefore slow. It also
        // prints bogus progress data to stderr.
        return error.SkipZigTest;
    }
    var progress = Progress{};
    const root_node = try progress.start("", 100);
    defer root_node.end();

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
        std.time.sleep(5 * std.time.ns_per_ms);
        node.completeOne();
        node.completeOne();
        std.time.sleep(5 * std.time.ns_per_ms);
        node.completeOne();
        node.completeOne();
        std.time.sleep(5 * std.time.ns_per_ms);

        node.end();

        std.time.sleep(5 * std.time.ns_per_ms);
    }
    {
        var node = root_node.start("this is a really long name designed to activate the truncation code. let's find out if it works", null);
        node.activate();
        std.time.sleep(10 * std.time.ns_per_ms);
        progress.refresh();
        std.time.sleep(10 * std.time.ns_per_ms);
        node.end();
    }
}
