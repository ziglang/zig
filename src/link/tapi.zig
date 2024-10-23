const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.tapi);
const yaml = @import("tapi/yaml.zig");

const Allocator = mem.Allocator;
const Yaml = yaml.Yaml;

const VersionField = union(enum) {
    string: []const u8,
    float: f64,
    int: u64,
};

pub const TbdV3 = struct {
    archs: []const []const u8,
    uuids: []const []const u8,
    platform: []const u8,
    install_name: []const u8,
    current_version: ?VersionField,
    compatibility_version: ?VersionField,
    objc_constraint: ?[]const u8,
    parent_umbrella: ?[]const u8,
    exports: ?[]const struct {
        archs: []const []const u8,
        allowable_clients: ?[]const []const u8,
        re_exports: ?[]const []const u8,
        symbols: ?[]const []const u8,
        weak_symbols: ?[]const []const u8,
        objc_classes: ?[]const []const u8,
        objc_ivars: ?[]const []const u8,
        objc_eh_types: ?[]const []const u8,
    },
};

pub const TbdV4 = struct {
    tbd_version: u3,
    targets: []const []const u8,
    uuids: ?[]const struct {
        target: []const u8,
        value: []const u8,
    },
    install_name: []const u8,
    current_version: ?VersionField,
    compatibility_version: ?VersionField,
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
        weak_symbols: ?[]const []const u8,
        objc_classes: ?[]const []const u8,
        objc_ivars: ?[]const []const u8,
        objc_eh_types: ?[]const []const u8,
    },
    reexports: ?[]const struct {
        targets: []const []const u8,
        symbols: ?[]const []const u8,
        weak_symbols: ?[]const []const u8,
        objc_classes: ?[]const []const u8,
        objc_ivars: ?[]const []const u8,
        objc_eh_types: ?[]const []const u8,
    },
    allowable_clients: ?[]const struct {
        targets: []const []const u8,
        clients: []const []const u8,
    },
    objc_classes: ?[]const []const u8,
    objc_ivars: ?[]const []const u8,
    objc_eh_types: ?[]const []const u8,
};

pub const Tbd = union(enum) {
    v3: TbdV3,
    v4: TbdV4,

    /// Caller owns memory.
    pub fn targets(self: Tbd, gpa: Allocator) error{OutOfMemory}![]const []const u8 {
        var out = std.ArrayList([]const u8).init(gpa);
        defer out.deinit();

        switch (self) {
            .v3 => |v3| {
                try out.ensureTotalCapacityPrecise(v3.archs.len);
                for (v3.archs) |arch| {
                    const target = try std.fmt.allocPrint(gpa, "{s}-{s}", .{ arch, v3.platform });
                    out.appendAssumeCapacity(target);
                }
            },
            .v4 => |v4| {
                try out.ensureTotalCapacityPrecise(v4.targets.len);
                for (v4.targets) |t| {
                    out.appendAssumeCapacity(try gpa.dupe(u8, t));
                }
            },
        }

        return out.toOwnedSlice();
    }

    pub fn currentVersion(self: Tbd) ?VersionField {
        return switch (self) {
            .v3 => |v3| v3.current_version,
            .v4 => |v4| v4.current_version,
        };
    }

    pub fn compatibilityVersion(self: Tbd) ?VersionField {
        return switch (self) {
            .v3 => |v3| v3.compatibility_version,
            .v4 => |v4| v4.compatibility_version,
        };
    }

    pub fn installName(self: Tbd) []const u8 {
        return switch (self) {
            .v3 => |v3| v3.install_name,
            .v4 => |v4| v4.install_name,
        };
    }
};

pub const TapiError = error{
    NotLibStub,
    InputOutput,
} || yaml.YamlError || std.fs.File.PReadError;

pub const LibStub = struct {
    /// Underlying memory for stub's contents.
    yaml: Yaml,

    /// Typed contents of the tbd file.
    inner: []Tbd,

    pub fn loadFromFile(allocator: Allocator, file: fs.File) TapiError!LibStub {
        const filesize = blk: {
            const stat = file.stat() catch break :blk std.math.maxInt(u32);
            break :blk @min(stat.size, std.math.maxInt(u32));
        };
        const source = try allocator.alloc(u8, filesize);
        defer allocator.free(source);
        const amt = try file.preadAll(source, 0);
        if (amt != filesize) return error.InputOutput;

        var lib_stub = LibStub{
            .yaml = try Yaml.load(allocator, source),
            .inner = undefined,
        };

        // TODO revisit this logic in the hope of simplifying it.
        lib_stub.inner = blk: {
            err: {
                log.debug("trying to parse as []TbdV4", .{});
                const inner = lib_stub.yaml.parse([]TbdV4) catch break :err;
                var out = try lib_stub.yaml.arena.allocator().alloc(Tbd, inner.len);
                for (inner, 0..) |doc, i| {
                    out[i] = .{ .v4 = doc };
                }
                break :blk out;
            }

            err: {
                log.debug("trying to parse as TbdV4", .{});
                const inner = lib_stub.yaml.parse(TbdV4) catch break :err;
                var out = try lib_stub.yaml.arena.allocator().alloc(Tbd, 1);
                out[0] = .{ .v4 = inner };
                break :blk out;
            }

            err: {
                log.debug("trying to parse as []TbdV3", .{});
                const inner = lib_stub.yaml.parse([]TbdV3) catch break :err;
                var out = try lib_stub.yaml.arena.allocator().alloc(Tbd, inner.len);
                for (inner, 0..) |doc, i| {
                    out[i] = .{ .v3 = doc };
                }
                break :blk out;
            }

            err: {
                log.debug("trying to parse as TbdV3", .{});
                const inner = lib_stub.yaml.parse(TbdV3) catch break :err;
                var out = try lib_stub.yaml.arena.allocator().alloc(Tbd, 1);
                out[0] = .{ .v3 = inner };
                break :blk out;
            }

            return error.NotLibStub;
        };

        return lib_stub;
    }

    pub fn deinit(self: *LibStub) void {
        self.yaml.deinit();
    }
};
