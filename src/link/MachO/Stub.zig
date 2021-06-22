const Stub = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.stub);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Symbol = @import("Symbol.zig");
pub const LibStub = @import("../tapi.zig").LibStub;

allocator: *Allocator,
arch: ?std.Target.Cpu.Arch = null,
lib_stub: ?LibStub = null,
name: ?[]const u8 = null,

ordinal: ?u16 = null,

id: ?Id = null,

/// Parsed symbol table represented as hash map of symbols'
/// names. We can and should defer creating *Symbols until
/// a symbol is referenced by an object file.
symbols: std.StringArrayHashMapUnmanaged(void) = .{},

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn deinit(id: *Id, allocator: *Allocator) void {
        allocator.free(id.name);
    }
};

pub fn init(allocator: *Allocator) Stub {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Stub) void {
    for (self.symbols.keys()) |key| {
        self.allocator.free(key);
    }
    self.symbols.deinit(self.allocator);

    if (self.lib_stub) |*lib_stub| {
        lib_stub.deinit();
    }

    if (self.name) |name| {
        self.allocator.free(name);
    }

    if (self.id) |*id| {
        id.deinit(self.allocator);
    }
}

fn addObjCClassSymbols(self: *Stub, sym_name: []const u8) !void {
    const expanded = &[_][]const u8{
        try std.fmt.allocPrint(self.allocator, "_OBJC_CLASS_$_{s}", .{sym_name}),
        try std.fmt.allocPrint(self.allocator, "_OBJC_METACLASS_$_{s}", .{sym_name}),
    };

    for (expanded) |sym| {
        if (self.symbols.contains(sym)) continue;
        try self.symbols.putNoClobber(self.allocator, sym, .{});
    }
}

pub fn parse(self: *Stub) !void {
    const lib_stub = self.lib_stub orelse return error.EmptyStubFile;
    if (lib_stub.inner.len == 0) return error.EmptyStubFile;

    log.debug("parsing shared library from stub '{s}'", .{self.name.?});

    const umbrella_lib = lib_stub.inner[0];
    self.id = .{
        .name = try self.allocator.dupe(u8, umbrella_lib.install_name),
        // TODO parse from the stub
        .timestamp = 2,
        .current_version = 0,
        .compatibility_version = 0,
    };

    const target_string: []const u8 = switch (self.arch.?) {
        .aarch64 => "arm64-macos",
        .x86_64 => "x86_64-macos",
        else => unreachable,
    };

    for (lib_stub.inner) |stub| {
        if (!hasTarget(stub.targets, target_string)) continue;

        if (stub.exports) |exports| {
            for (exports) |exp| {
                if (!hasTarget(exp.targets, target_string)) continue;

                if (exp.symbols) |symbols| {
                    for (symbols) |sym_name| {
                        if (self.symbols.contains(sym_name)) continue;
                        try self.symbols.putNoClobber(self.allocator, try self.allocator.dupe(u8, sym_name), {});
                    }
                }

                if (exp.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbols(sym_name);
                    }
                }
            }
        }

        if (stub.reexports) |reexports| {
            for (reexports) |reexp| {
                if (!hasTarget(reexp.targets, target_string)) continue;

                for (reexp.symbols) |sym_name| {
                    if (self.symbols.contains(sym_name)) continue;
                    try self.symbols.putNoClobber(self.allocator, try self.allocator.dupe(u8, sym_name), {});
                }
            }
        }

        if (stub.objc_classes) |classes| {
            for (classes) |sym_name| {
                try self.addObjCClassSymbols(sym_name);
            }
        }
    }
}

fn hasTarget(targets: []const []const u8, target: []const u8) bool {
    for (targets) |t| {
        if (mem.eql(u8, t, target)) return true;
    }
    return false;
}

pub fn createProxy(self: *Stub, sym_name: []const u8) !?*Symbol {
    if (!self.symbols.contains(sym_name)) return null;

    const name = try self.allocator.dupe(u8, sym_name);
    const proxy = try self.allocator.create(Symbol.Proxy);
    errdefer self.allocator.destroy(proxy);

    proxy.* = .{
        .base = .{
            .@"type" = .proxy,
            .name = name,
        },
        .file = .{ .stub = self },
    };

    return &proxy.base;
}
