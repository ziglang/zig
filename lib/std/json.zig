
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const maxInt = std.math.maxInt;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;

pub const WriteStream = @import("json/write_stream.zig").WriteStream;
pub const writeStream = @import("json/write_stream.zig").writeStream;

pub const JsonError = @import("json/scanner.zig").JsonError;
pub const jsonReader = @import("json/scanner.zig").jsonReader;
pub const default_buffer_size = @import("json/scanner.zig").default_buffer_size;
pub const Token = @import("json/scanner.zig").Token;
pub const JsonReader = @import("json/scanner.zig").JsonReader;
pub const JsonScanner = @import("json/scanner.zig").JsonScanner;

/// Validate a JSON string. This does not limit number precision so a decoder may not necessarily
/// be able to decode the string even if this returns true.
pub fn validate(allocator: Allocator, s: []const u8) bool {
    var scanner = JsonScanner.initCompleteInput(allocator, s);
    while (true) {
        const token = scanner.next() catch return false;
        if (token == .end_of_document) break;
    }
    return true;
}

