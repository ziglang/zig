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
pub const validate = @import("json/scanner.zig").validate;

test {
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/write_stream.zig");
    _ = @import("json/dynamic.zig");
    _ = @import("json/static.zig");
    _ = @import("json/stringify.zig");
}
