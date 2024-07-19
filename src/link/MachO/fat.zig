const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const log = std.log.scoped(.macho);
const macho = std.macho;
const mem = std.mem;
const native_endian = builtin.target.cpu.arch.endian();

const MachO = @import("../MachO.zig");

pub fn readFatHeader(file: std.fs.File) !macho.fat_header {
    return readFatHeaderGeneric(macho.fat_header, file, 0);
}

fn readFatHeaderGeneric(comptime Hdr: type, file: std.fs.File, offset: usize) !Hdr {
    var buffer: [@sizeOf(Hdr)]u8 = undefined;
    const nread = try file.preadAll(&buffer, offset);
    if (nread != buffer.len) return error.InputOutput;
    var hdr = @as(*align(1) const Hdr, @ptrCast(&buffer)).*;
    mem.byteSwapAllFields(Hdr, &hdr);
    return hdr;
}

pub const Arch = struct {
    tag: std.Target.Cpu.Arch,
    offset: u32,
    size: u32,
};

pub fn parseArchs(file: std.fs.File, fat_header: macho.fat_header, out: *[2]Arch) ![]const Arch {
    var count: usize = 0;
    var fat_arch_index: u32 = 0;
    while (fat_arch_index < fat_header.nfat_arch and count < out.len) : (fat_arch_index += 1) {
        const offset = @sizeOf(macho.fat_header) + @sizeOf(macho.fat_arch) * fat_arch_index;
        const fat_arch = try readFatHeaderGeneric(macho.fat_arch, file, offset);
        // If we come across an architecture that we do not know how to handle, that's
        // fine because we can keep looking for one that might match.
        const arch: std.Target.Cpu.Arch = switch (fat_arch.cputype) {
            macho.CPU_TYPE_ARM64 => if (fat_arch.cpusubtype == macho.CPU_SUBTYPE_ARM_ALL) .aarch64 else continue,
            macho.CPU_TYPE_X86_64 => if (fat_arch.cpusubtype == macho.CPU_SUBTYPE_X86_64_ALL) .x86_64 else continue,
            else => continue,
        };
        out[count] = .{ .tag = arch, .offset = fat_arch.offset, .size = fat_arch.size };
        count += 1;
    }

    return out[0..count];
}
