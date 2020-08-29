const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const assert = std.debug.assert;

pub fn AutoIndentingStream(comptime indent_delta: u8, comptime OutStreamType: type) type {
    return struct {
        const Self = @This();
        pub const Error = OutStreamType.Error;
        pub const OutStream = io.Writer(*Self, Error, write);

        out_stream: *OutStreamType,
        current_line_empty: bool = true,
        indent_stack: [255]u8 = undefined,
        indent_stack_top: u8 = 0,
        indent_one_shot_count: u8 = 0, // automatically popped when applied
        applied_indent: u8 = 0, // the most recently applied indent
        indent_next_line: u8 = 0, // not used until the next line

        pub fn init(out_stream: *OutStreamType) Self {
            return Self{ .out_stream = out_stream };
        }

        pub fn writer(self: *Self) OutStream {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len == 0)
                return @as(usize, 0);

            try self.applyIndent();
            return self.writeNoIndent(bytes);
        }

        fn writeNoIndent(self: *Self, bytes: []const u8) Error!usize {
            try self.out_stream.outStream().writeAll(bytes);
            if (bytes[bytes.len - 1] == '\n')
                self.resetLine();
            return bytes.len;
        }

        pub fn insertNewline(self: *Self) Error!void {
            _ = try self.writeNoIndent("\n");
        }

        fn resetLine(self: *Self) void {
            self.current_line_empty = true;
            self.indent_next_line = 0;
        }

        /// Insert a newline unless the current line is blank
        pub fn maybeInsertNewline(self: *Self) Error!void {
            if (!self.current_line_empty)
                try self.insertNewline();
        }

        /// Push default indentation
        pub fn pushIndent(self: *Self) void {
            // Doesn't actually write any indentation. Just primes the stream to be able to write the correct indentation if it needs to.
            self.pushIndentN(indent_delta);
        }

        /// Push an indent of arbitrary width
        pub fn pushIndentN(self: *Self, n: u8) void {
            assert(self.indent_stack_top < std.math.maxInt(u8));
            self.indent_stack[self.indent_stack_top] = n;
            self.indent_stack_top += 1;
        }

        /// Push an indent that is automatically popped after being applied
        pub fn pushIndentOneShot(self: *Self) void {
            self.indent_one_shot_count += 1;
            self.pushIndent();
        }

        /// Turns all one-shot indents into regular indents
        /// Returns number of indents that must now be manually popped
        pub fn lockOneShotIndent(self: *Self) u8 {
            var locked_count = self.indent_one_shot_count;
            self.indent_one_shot_count = 0;
            return locked_count;
        }

        /// Push an indent that should not take effect until the next line
        pub fn pushIndentNextLine(self: *Self) void {
            self.indent_next_line += 1;
            self.pushIndent();
        }

        pub fn popIndent(self: *Self) void {
            assert(self.indent_stack_top != 0);
            self.indent_stack_top -= 1;
            self.indent_next_line = std.math.min(self.indent_stack_top, self.indent_next_line); // Tentative indent may have been popped before there was a newline
        }

        /// Writes ' ' bytes if the current line is empty
        fn applyIndent(self: *Self) Error!void {
            const current_indent = self.currentIndent();
            if (self.current_line_empty and current_indent > 0) {
                try self.out_stream.outStream().writeByteNTimes(' ', current_indent);
                self.applied_indent = current_indent;
            }

            self.indent_stack_top -= self.indent_one_shot_count;
            self.indent_one_shot_count = 0;
            self.current_line_empty = false;
        }

        /// Checks to see if the most recent indentation exceeds the currently pushed indents
        pub fn isLineOverIndented(self: *Self) bool {
            if (self.current_line_empty) return false;
            return self.applied_indent > self.currentIndent();
        }

        fn currentIndent(self: *Self) u8 {
            var indent_current: u8 = 0;
            if (self.indent_stack_top > 0) {
                const stack_top = self.indent_stack_top - self.indent_next_line;
                for (self.indent_stack[0..stack_top]) |indent| {
                    indent_current += indent;
                }
            }
            return indent_current;
        }
    };
}

pub fn autoIndentingStream(
    comptime indent_delta: u8,
    underlying_stream: anytype,
) AutoIndentingStream(indent_delta, @TypeOf(underlying_stream).Child) {
    comptime assert(@typeInfo(@TypeOf(underlying_stream)) == .Pointer);
    return AutoIndentingStream(indent_delta, @TypeOf(underlying_stream).Child).init(underlying_stream);
}
