const std = @import("std");
const testing = std.testing;

pub const PrintConfig = struct {
    /// If the current node (and its children) should
    /// print to stderr on update()
    flag: bool = false,

    /// If all output should be suppressed instead
    /// serves the same practical purpose as `flag` but supposed to be used
    /// by separate parts of the user program.
    suppress: bool = false,
};

pub const ProgressNode = struct {
    completed_items: usize = 0,
    total_items: usize,

    print_config: PrintConfig,

    // TODO maybe instead of keeping a prefix field, we could
    // select the proper prefix at the time of update(), and if we're not
    // in a terminal, we use warn("/r{}", lots_of_whitespace).
    prefix: []const u8,

    /// Create a new progress node.
    pub fn start(
        parent_opt: ?ProgressNode,
        total_items_opt: ?usize,
    ) !ProgressNode {

        // inherit the last set print "configuration" from the parent node
        var print_config = PrintConfig{};
        if (parent_opt) |parent| {
            print_config = parent.print_config;
        }

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

        return ProgressNode{
            .total_items = total_items_opt orelse 0,
            .print_config = print_config,
            .prefix = prefix,
        };
    }

    /// Signal an update on the progress node.
    /// The user of this function is supposed to modify
    /// ProgressNode.PrintConfig.flag when update() is supposed to print.
    pub fn update(
        self: *ProgressNode,
        current_action: ?[]const u8,
        items_done_opt: ?usize,
    ) void {
        if (items_done_opt) |items_done| {
            self.completed_items = items_done;

            if (items_done > self.total_items) {
                self.total_items = items_done;
            }
        }

        var cfg = self.print_config;
        if (cfg.flag and !cfg.suppress and current_action != null) {
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
        if (!self.print_config.flag) return;

        // TODO emoji?
        std.debug.warn("\n[V] done!");
    }
};

test "basic functionality" {
    var node = try ProgressNode.start(null, 100);

    var buf: [100]u8 = undefined;

    var i: usize = 0;
    while (i < 100) : (i += 6) {
        if (i > 50) node.print_config.flag = true;
        const msg = try std.fmt.bufPrint(buf[0..], "action at i={}", i);
        node.update(msg, i);
        std.time.sleep(10 * std.time.millisecond);
    }

    node.end();
}
