pub fn isFatLibrary(file: std.fs.File) bool {
    const reader = file.reader();
    const hdr = reader.readStructEndian(macho.fat_header, .big) catch return false;
    defer file.seekTo(0) catch {};
    return hdr.magic == macho.FAT_MAGIC;
}

pub const Arch = struct {
    tag: std.Target.Cpu.Arch,
    offset: u64,
};

/// Caller owns the memory.
pub fn parseArchs(gpa: Allocator, file: std.fs.File) ![]const Arch {
    const reader = file.reader();
    const fat_header = try reader.readStructEndian(macho.fat_header, .big);
    assert(fat_header.magic == macho.FAT_MAGIC);

    var archs = try std.ArrayList(Arch).initCapacity(gpa, fat_header.nfat_arch);
    defer archs.deinit();

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

        archs.appendAssumeCapacity(.{ .tag = arch, .offset = fat_arch.offset });
    }

    return archs.toOwnedSlice();
}

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.archive);
const macho = std.macho;
const mem = std.mem;
const Allocator = mem.Allocator;
