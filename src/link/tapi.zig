const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.tapi);

const Allocator = mem.Allocator;
const Yaml = @import("tapi/yaml.zig").Yaml;

pub const LibStub = struct {
    /// Underlying memory for stub's contents.
    yaml: Yaml,

    /// Typed contents of the tbd file.
    inner: []Tbd,

    const Tbd = struct {
        tbd_version: u3,
        targets: []const []const u8,
        uuids: []const struct {
            target: []const u8,
            value: []const u8,
        },
        install_name: []const u8,
        current_version: ?union(enum) {
            string: []const u8,
            float: f64,
            int: u64,
        },
        compatibility_version: ?union(enum) {
            string: []const u8,
            float: f64,
            int: u64,
        },
        reexported_libraries: ?[]const struct {
            targets: []const []const u8,
            libraries: []const []const u8,
        },
        parent_umbrella: ?[]const struct {
            targets: []const []const u8,
            umbrella: []const u8,
        },
        exports: ?[]const struct {
            targets: []const []const u8,
            symbols: ?[]const []const u8,
            objc_classes: ?[]const []const u8,
        },
        reexports: ?[]const struct {
            targets: []const []const u8,
            symbols: ?[]const []const u8,
            objc_classes: ?[]const []const u8,
        },
        allowable_clients: ?[]const struct {
            targets: []const []const u8,
            clients: []const []const u8,
        },
        objc_classes: ?[]const []const u8,
    };

    pub fn loadFromFile(allocator: *Allocator, file: fs.File) !LibStub {
        const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
        defer allocator.free(source);

        var lib_stub = LibStub{
            .yaml = try Yaml.load(allocator, source),
            .inner = undefined,
        };

        lib_stub.inner = lib_stub.yaml.parse([]Tbd) catch |err| blk: {
            switch (err) {
                error.TypeMismatch => {
                    // TODO clean this up.
                    var out = try lib_stub.yaml.arena.allocator.alloc(Tbd, 1);
                    out[0] = try lib_stub.yaml.parse(Tbd);
                    break :blk out;
                },
                else => |e| return e,
            }
        };

        return lib_stub;
    }

    pub fn deinit(self: *LibStub) void {
        self.yaml.deinit();
    }
};
