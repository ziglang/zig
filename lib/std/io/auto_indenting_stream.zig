const std = @import("../std.zig");
const io = std.io;
const mem = std.mem;
const assert = std.debug.assert;

/// Automatically inserts indentation of written data by keeping
/// track of the current indentation level
pub fn AutoIndentingStream(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        writer_pointer: *WriterType,

        indent_stack: usize = 0,
        indent_delta: usize,
        current_line_empty: bool = true,
        indent_one_shot_count: usize = 0, // automatically popped when applied
        applied_indent: usize = 0, // the most recently applied indent
        indent_next_line: usize = 0, // not used until the next line

        pub fn init(indent_delta: usize, writer_pointer: *WriterType) Self {
            return Self{ .writer_pointer = writer_pointer, .indent_delta = indent_delta };
        }

        /// Release all allocated memory.
        pub fn deinit(self: Self) void {}

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len == 0)
                return @as(usize, 0);

            try self.applyIndent();
            return self.writeNoIndent(bytes);
        }

        fn writeNoIndent(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len == 0)
                return @as(usize, 0);

            try self.writer_pointer.writer().writeAll(bytes);
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
            // Doesn't actually write any indentation.
            // Just primes the stream to be able to write the correct indentation if it needs to.
            self.indent_stack += 1;
        }

        /// Push an indent that is automatically popped after being applied
        pub fn pushIndentOneShot(self: *Self) void {
            self.indent_one_shot_count += 1;
            self.pushIndent();
        }

        /// Turns all one-shot indents into regular indents
        /// Returns number of indents that must now be manually popped
        pub fn lockOneShotIndent(self: *Self) usize {
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
            assert(self.indent_stack != 0);
            self.indent_stack -= 1;
            self.indent_next_line = std.math.min(self.indent_stack, self.indent_next_line); // Tentative indent may have been popped before there was a newline
        }

        /// Writes ' ' bytes if the current line is empty
        fn applyIndent(self: *Self) Error!void {
            const current_indent = self.currentIndent();
            if (self.current_line_empty and current_indent > 0) {
                try self.writer_pointer.writer().writeByteNTimes(' ', current_indent);
                self.applied_indent = current_indent;
            }

            self.indent_stack -= self.indent_one_shot_count;
            self.indent_one_shot_count = 0;
            self.current_line_empty = false;
        }

        /// Checks to see if the most recent indentation exceeds the currently pushed indents
        pub fn isLineOverIndented(self: *Self) bool {
            if (self.current_line_empty) return false;
            return self.applied_indent > self.currentIndent();
        }

        fn currentIndent(self: *Self) usize {
            var indent_current: usize = 0;
            if (self.indent_stack > 0) {
                const stack_top = self.indent_stack - self.indent_next_line;
                indent_current = stack_top * self.indent_delta;
            }
            return indent_current;
        }
    };
}

pub fn autoIndentingStream(
    indent_delta: usize,
    underlying_stream: anytype,
) AutoIndentingStream(@TypeOf(underlying_stream).Child) {
    comptime assert(@typeInfo(@TypeOf(underlying_stream)) == .Pointer);
    return AutoIndentingStream(@TypeOf(underlying_stream).Child).init(indent_delta, underlying_stream);
}
