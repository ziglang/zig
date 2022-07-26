const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("zip.h");
});

const Error = error{
    FailedToWriteEntry,
    FileNotFound,
    FailedToCreateEntry,
    Overflow,
    OutOfMemory,
    InvalidCmdLine,
};

test {
    const allocator = std.heap.c_allocator;

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 4) {
        return;
    }

    const zip_file = args[1];
    const src_file_name = args[2];
    const dst_file_name = args[3];

    errdefer |e| switch (@as(Error, e)) {
        error.FailedToWriteEntry => std.log.err("could not find {s}", .{src_file_name}),
        error.FileNotFound => std.log.err("could not open {s}", .{zip_file}),
        error.FailedToCreateEntry => std.log.err("could not create {s}", .{dst_file_name}),
        else => {},
    };

    const zip = c.zip_open(zip_file, c.ZIP_DEFAULT_COMPRESSION_LEVEL, 'a') orelse return error.FileNotFound;
    defer c.zip_close(zip);

    if (c.zip_entry_open(zip, dst_file_name) < 0)
        return error.FailedToCreateEntry;
    defer _ = c.zip_entry_close(zip);

    if (c.zip_entry_fwrite(zip, src_file_name) < 0)
        return error.FailedToWriteEntry;
}
