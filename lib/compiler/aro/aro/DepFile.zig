const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Format = enum { make, nmake };

const DepFile = @This();

target: []const u8,
deps: std.StringArrayHashMapUnmanaged(void) = .empty,
format: Format,

pub fn deinit(d: *DepFile, gpa: Allocator) void {
    d.deps.deinit(gpa);
    d.* = undefined;
}

pub fn addDependency(d: *DepFile, gpa: Allocator, path: []const u8) !void {
    try d.deps.put(gpa, path, {});
}

pub fn addDependencyDupe(d: *DepFile, gpa: Allocator, arena: Allocator, path: []const u8) !void {
    const gop = try d.deps.getOrPut(gpa, path);
    if (gop.found_existing) return;
    gop.key_ptr.* = try arena.dupe(u8, path);
}

pub fn write(d: *const DepFile, w: *std.Io.Writer) std.Io.Writer.Error!void {
    const max_columns = 75;
    var columns: usize = 0;

    try writeTarget(d.target, w);
    columns += d.target.len;
    try w.writeByte(':');
    columns += 1;

    for (d.deps.keys()) |path| {
        if (std.mem.eql(u8, path, "<stdin>")) continue;

        if (columns + path.len + " \\\n".len > max_columns) {
            try w.writeAll(" \\\n ");
            columns = 1;
        }
        try w.writeByte(' ');
        try d.writePath(path, w);
        columns += path.len + 1;
    }
    try w.writeByte('\n');
    try w.flush();
}

fn writeTarget(path: []const u8, w: *std.Io.Writer) !void {
    for (path, 0..) |c, i| {
        switch (c) {
            ' ', '\t' => {
                try w.writeByte('\\');
                var j = i;
                while (j != 0) {
                    j -= 1;
                    if (path[j] != '\\') break;
                    try w.writeByte('\\');
                }
            },
            '$' => try w.writeByte('$'),
            '#' => try w.writeByte('\\'),
            else => {},
        }
        try w.writeByte(c);
    }
}

fn writePath(d: *const DepFile, path: []const u8, w: *std.Io.Writer) !void {
    switch (d.format) {
        .nmake => {
            if (std.mem.indexOfAny(u8, path, " #${}^!")) |_|
                try w.print("\"{s}\"", .{path})
            else
                try w.writeAll(path);
        },
        .make => {
            for (path, 0..) |c, i| {
                switch (c) {
                    ' ' => {
                        try w.writeByte('\\');
                        var j = i;
                        while (j != 0) {
                            j -= 1;
                            if (path[j] != '\\') break;
                            try w.writeByte('\\');
                        }
                    },
                    '$' => try w.writeByte('$'),
                    '#' => try w.writeByte('\\'),
                    else => {},
                }
                try w.writeByte(c);
            }
        },
    }
}
