const std = @import("std");
const Allocator = std.mem.Allocator;

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

test {
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/write_stream.zig");
    _ = @import("json/dynamic.zig");
    _ = @import("json/static.zig");
    _ = @import("json/stringify.zig");
}
