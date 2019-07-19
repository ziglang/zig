const std = @import("std.zig");
const testing = std.testing;

pub const Config = struct {
    milliseconds_until_print: usize = 200,
    suppress_output: bool = false,
};

pub var config = Config{};

pub const ProgressNode = struct {
    completed_items: usize = 0,
    total_items: usize,

    /// The node's starting timestamp.
    timestamp: u64,

    /// If we should print the current node to stderr.
    print_flag: bool,

    prefix: []const u8,

    /// Create a new progress node.
    pub fn start(
        parent_opt: ?ProgressNode,
        item_count_opt: ?usize,
    ) !ProgressNode {
        var print_flag = false;

        // if the parent reached its 200ms, then we should
        // also print ourselves.
        if (parent_opt) |parent| {
            print_flag = parent.print_flag;
        }

        var item_count: usize = 0;
        if (item_count_opt) |estimated_count| {
            item_count = estimated_count;
        }

        // TODO should we do this at comptime so we remove the possibility
        // of errors on start()?
        var stderr = try std.io.getStdErr();
        const is_term = std.os.isatty(stderr.handle);

        // if we're in a terminal, use vt100 escape codes
        // for the progress.
        var prefix: []const u8 = undefined;
        if (is_term) {
            prefix = "\x21[2K\r";
        } else {
            prefix = "\n";
        }

        std.debug.warn("\n");

        return ProgressNode{
            .timestamp = std.time.milliTimestamp(),
            .total_items = item_count,
            .print_flag = print_flag,
            .prefix = prefix,
        };
    }

    /// Signal an update on the progress node.
    /// This may or may not print to stderr based on how many milliseconds
    /// passed since the progress node's creation.
    pub fn update(
        self: *ProgressNode,
        current_action: ?[]const u8,
        items_done_opt: ?usize,
    ) void {
        const cur_time = std.time.milliTimestamp();
        const delta = cur_time - self.timestamp;

        if (delta >= config.milliseconds_until_print) {
            self.print_flag = true;
        }

        if (items_done_opt) |items_done| {
            self.completed_items = items_done;

            if (items_done > self.total_items) {
                self.total_items = items_done;
            }
        }

        if (self.print_flag and !config.suppress_output and current_action != null) {
            std.debug.warn(
                "{}[{}/{}] {}",
                self.prefix,
                self.completed_items,
                self.total_items,
                current_action,
            );
        }
    }

    pub fn end(self: *ProgressNode) void {
        if (!self.print_flag) return;

        // TODO emoji?
        std.debug.warn("\n[V] done!");
    }
};

test "basic functionality" {
    var node = try ProgressNode.start(null, 100);
    std.time.sleep(200 * std.time.millisecond);

    var buf: [100]u8 = undefined;

    var i: usize = 0;
    while (i < 100) : (i += 6) {
        const msg = try std.fmt.bufPrint(buf[0..], "action at i={}", i);
        node.update(msg, i);
        std.time.sleep(10 * std.time.millisecond);
    }

    node.end();
}
