//! Extract the "de facto" Zig Grammar from the parser in lib/std/zig/parse.zig.
//!
//! The generated file must be edited by hand, in order to remove normal doc-comments.

const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const process = std.process;
const zig = std.zig;

const Buffer = struct {
    const buf_size = 4096;

    buf: [buf_size]u8 = undefined,
    pos: usize = 0,

    pub fn append(self: *Buffer, src: []const u8) !void {
        if (self.pos + src.len > buf_size) {
            return error.BufferOverflow;
        }

        mem.copy(u8, self.buf[self.pos..buf_size], src);
        self.pos += src.len;
    }

    pub fn reset(self: *Buffer) void {
        self.pos = 0;
    }

    pub fn slice(self: *Buffer) []const u8 {
        return self.buf[0..self.pos];
    }
};

/// There are many assumptions in the entire codebase that Zig source files can
/// be byte-indexed with a u32 integer.
const max_src_size = std.math.maxInt(u32);

pub fn main() !void {
    const stdout_wr = io.getStdOut().writer();
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit(); // NOTE(mperillo): Can be removed.
    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    _ = args_it.skip(); // it is safe to ignore

    const path = args_it.next() orelse return error.SourceFileRequired;
    const src = try read(path, allocator);

    var tokenizer = zig.Tokenizer.init(src);
    var buf: Buffer = Buffer{};
    while (true) {
        const token = tokenizer.next();
        switch (token.tag) {
            .eof => break,
            .doc_comment => {
                const line = blk: {
                    // Strip leading whitespace.
                    const len = token.loc.end - token.loc.start;
                    break :blk if (len == 3) src[token.loc.start + 3 .. token.loc.end] else src[token.loc.start + 4 .. token.loc.end];
                };

                try buf.append(line);
                try buf.append("\n");
            },
            .keyword_fn => {
                const doc = buf.slice();
                buf.reset();

                // Check if doc contains a PEG grammar block, so that normal
                // doc-comments are ignored.
                if (mem.indexOf(u8, doc, "<-") != null) {
                    // Separate each doc with an empty line.  This in turn will
                    // ensure that rules are separate by an empty line.
                    try stdout_wr.print("{s}\n", .{doc});
                }
            },
            else => {},
        }
    }
}

fn read(path: []const u8, allocator: mem.Allocator) ![:0]const u8 {
    var f = try fs.cwd().openFile(path, .{ .mode = .read_only });
    defer f.close();

    const st = try f.stat();
    if (st.size > max_src_size) return error.FileTooBig;

    const src = try allocator.allocSentinel(u8, @as(usize, @intCast(st.size)), 0);
    const n = try f.readAll(src);
    if (n != st.size) return error.UnexpectedEndOfFile;

    return src;
}
