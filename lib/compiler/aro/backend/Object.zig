const std = @import("std");
const Allocator = std.mem.Allocator;
const Elf = @import("Object/Elf.zig");

const Object = @This();

format: std.Target.ObjectFormat,
target: std.Target,

pub fn create(gpa: Allocator, target: std.Target) !*Object {
    switch (target.ofmt) {
        .elf => return Elf.create(gpa, target),
        else => unreachable,
    }
}

pub fn deinit(obj: *Object) void {
    switch (obj.format) {
        .elf => @as(*Elf, @fieldParentPtr("obj", obj)).deinit(),
        else => unreachable,
    }
}

pub const Section = union(enum) {
    undefined,
    data,
    read_only_data,
    func,
    strings,
    custom: []const u8,
};

pub fn getSection(obj: *Object, section: Section) !*std.ArrayList(u8) {
    switch (obj.format) {
        .elf => return @as(*Elf, @fieldParentPtr("obj", obj)).getSection(section),
        else => unreachable,
    }
}

pub const SymbolType = enum {
    func,
    variable,
    external,
};

pub fn declareSymbol(
    obj: *Object,
    section: Section,
    name: ?[]const u8,
    linkage: std.builtin.GlobalLinkage,
    @"type": SymbolType,
    offset: u64,
    size: u64,
) ![]const u8 {
    switch (obj.format) {
        .elf => return @as(*Elf, @fieldParentPtr("obj", obj)).declareSymbol(section, name, linkage, @"type", offset, size),
        else => unreachable,
    }
}

pub fn addRelocation(obj: *Object, name: []const u8, section: Section, address: u64, addend: i64) !void {
    switch (obj.format) {
        .elf => return @as(*Elf, @fieldParentPtr("obj", obj)).addRelocation(name, section, address, addend),
        else => unreachable,
    }
}

pub fn finish(obj: *Object, file: std.fs.File) !void {
    switch (obj.format) {
        .elf => return @as(*Elf, @fieldParentPtr("obj", obj)).finish(file),
        else => unreachable,
    }
}
