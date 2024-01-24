const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const log = std.log.scoped(.macho);
const macho = std.macho;
const mem = std.mem;
const native_endian = builtin.target.cpu.arch.endian();

const MachO = @import("../MachO.zig");

pub fn isFatLibrary(path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const hdr = file.reader().readStructEndian(macho.fat_header, .big) catch return false;
    return hdr.magic == macho.FAT_MAGIC;
}

pub const Arch = struct {
    tag: std.Target.Cpu.Arch,
    offset: u32,
    size: u32,
};

pub fn parseArchs(path: []const u8, buffer: *[2]Arch) ![]const Arch {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.reader();
    const fat_header = try reader.readStructEndian(macho.fat_header, .big);
    assert(fat_header.magic == macho.FAT_MAGIC);

    var count: usize = 0;
    var fat_arch_index: u32 = 0;
    while (fat_arch_index < fat_header.nfat_arch) : (fat_arch_index += 1) {
        const fat_arch = try reader.readStructEndian(macho.fat_arch, .big);
        // If we come across an architecture that we do not know how to handle, that's
        // fine because we can keep looking for one that might match.
        const arch: std.Target.Cpu.Arch = switch (fat_arch.cputype) {
            macho.CPU_TYPE_ARM64 => if (fat_arch.cpusubtype == macho.CPU_SUBTYPE_ARM_ALL) .aarch64 else continue,
            macho.CPU_TYPE_X86_64 => if (fat_arch.cpusubtype == macho.CPU_SUBTYPE_X86_64_ALL) .x86_64 else continue,
            else => continue,
        };
        buffer[count] = .{ .tag = arch, .offset = fat_arch.offset, .size = fat_arch.size };
        count += 1;
    }

    return buffer[0..count];
}
