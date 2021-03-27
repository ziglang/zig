//! TODO: the name for this file is a bit misleading, this is actually for
//! *nix - darwin, but unix_other_than_darwin is too long.

const std = @import("std.zig");
const builtin = std.builtin;
const assert = std.debug.assert;
const SymbolInfo = std.debug.SymbolMap.SymbolInfo;
const debug_info = std.debug_info;
const BaseError = debug_info.BaseError;
const chopSlice = debug_info.chopSlice;
const mem = std.mem;
const DW = std.dwarf;
const elf = std.elf;
const os = std.os;
const math = std.math;
const fs = std.fs;
const File = fs.File;

const SymbolMapState = debug_info.SymbolMapStateFromModuleInfo(Module);
pub const init = SymbolMapState.init;

const Module = struct {
    const Self = @This();

    base_address: usize,
    dwarf: DW.DwarfInfo,
    mapped_memory: []const u8,

    pub fn lookup(allocator: *mem.Allocator, address_map: *SymbolMapState.AddressMap, address: usize) !*Self {
        var ctx: struct {
            // Input
            address: usize,
            // Output
            base_address: usize = undefined,
            name: []const u8 = undefined,
        } = .{ .address = address };
        const CtxTy = @TypeOf(ctx);

        if (os.dl_iterate_phdr(&ctx, anyerror, struct {
            fn callback(info: *os.dl_phdr_info, size: usize, context: *CtxTy) !void {
                // The base address is too high
                if (context.address < info.dlpi_addr)
                    return;

                const phdrs = info.dlpi_phdr[0..info.dlpi_phnum];
                for (phdrs) |*phdr| {
                    if (phdr.p_type != elf.PT_LOAD) continue;

                    const seg_start = info.dlpi_addr + phdr.p_vaddr;
                    const seg_end = seg_start + phdr.p_memsz;

                    if (context.address >= seg_start and context.address < seg_end) {
                        // Android libc uses NULL instead of an empty string to mark the
                        // main program
                        context.name = mem.spanZ(info.dlpi_name) orelse "";
                        context.base_address = info.dlpi_addr;
                        // Stop the iteration
                        return error.Found;
                    }
                }
            }
        }.callback)) {
            return BaseError.MissingDebugInfo;
        } else |err| switch (err) {
            error.Found => {},
            else => return BaseError.MissingDebugInfo,
        }

        if (address_map.get(ctx.base_address)) |obj_di| {
            return obj_di;
        }

        const obj_di = try allocator.create(Self);
        errdefer allocator.destroy(obj_di);

        // TODO https://github.com/ziglang/zig/issues/5525
        const copy = if (ctx.name.len > 0)
            fs.cwd().openFile(ctx.name, .{ .intended_io_mode = .blocking })
        else
            fs.openSelfExe(.{ .intended_io_mode = .blocking });

        const elf_file = copy catch |err| switch (err) {
            error.FileNotFound => return BaseError.MissingDebugInfo,
            else => return err,
        };

        obj_di.* = try readElfDebugInfo(allocator, elf_file);
        obj_di.base_address = ctx.base_address;

        try address_map.putNoClobber(ctx.base_address, obj_di);

        return obj_di;
    }

    /// This takes ownership of elf_file: users of this function should not close
    /// it themselves, even on error.
    /// TODO resources https://github.com/ziglang/zig/issues/4353
    /// TODO it's weird to take ownership even on error, rework this code.
    fn readElfDebugInfo(allocator: *mem.Allocator, elf_file: File) !Self {
        nosuspend {
            const mapped_mem = try debug_info.mapWholeFile(elf_file);
            const hdr = @ptrCast(*const elf.Ehdr, &mapped_mem[0]);
            if (!mem.eql(u8, hdr.e_ident[0..4], "\x7fELF")) return error.InvalidElfMagic;
            if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

            const endian: builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
                elf.ELFDATA2LSB => .Little,
                elf.ELFDATA2MSB => .Big,
                else => return error.InvalidElfEndian,
            };
            assert(endian == std.builtin.endian); // this is our own debug info

            const shoff = hdr.e_shoff;
            const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
            const str_shdr = @ptrCast(
                *const elf.Shdr,
                @alignCast(@alignOf(elf.Shdr), &mapped_mem[try math.cast(usize, str_section_off)]),
            );
            const header_strings = mapped_mem[str_shdr.sh_offset .. str_shdr.sh_offset + str_shdr.sh_size];
            const shdrs = @ptrCast(
                [*]const elf.Shdr,
                @alignCast(@alignOf(elf.Shdr), &mapped_mem[shoff]),
            )[0..hdr.e_shnum];

            var opt_debug_info: ?[]const u8 = null;
            var opt_debug_abbrev: ?[]const u8 = null;
            var opt_debug_str: ?[]const u8 = null;
            var opt_debug_line: ?[]const u8 = null;
            var opt_debug_ranges: ?[]const u8 = null;

            for (shdrs) |*shdr| {
                if (shdr.sh_type == elf.SHT_NULL) continue;

                const name = std.mem.span(std.meta.assumeSentinel(header_strings[shdr.sh_name..].ptr, 0));
                if (mem.eql(u8, name, ".debug_info")) {
                    opt_debug_info = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                } else if (mem.eql(u8, name, ".debug_abbrev")) {
                    opt_debug_abbrev = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                } else if (mem.eql(u8, name, ".debug_str")) {
                    opt_debug_str = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                } else if (mem.eql(u8, name, ".debug_line")) {
                    opt_debug_line = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                } else if (mem.eql(u8, name, ".debug_ranges")) {
                    opt_debug_ranges = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                }
            }

            var di = DW.DwarfInfo{
                .endian = endian,
                .debug_info = opt_debug_info orelse return BaseError.MissingDebugInfo,
                .debug_abbrev = opt_debug_abbrev orelse return BaseError.MissingDebugInfo,
                .debug_str = opt_debug_str orelse return BaseError.MissingDebugInfo,
                .debug_line = opt_debug_line orelse return BaseError.MissingDebugInfo,
                .debug_ranges = opt_debug_ranges,
            };

            try DW.openDwarfDebugInfo(&di, allocator);

            return Self{
                .base_address = undefined,
                .dwarf = di,
                .mapped_memory = mapped_mem,
            };
        }
    }

    pub fn addressToSymbol(self: *Self, address: usize) !SymbolInfo {
        // Translate the VA into an address into this object
        const relocated_address = address - self.base_address;

        return debug_info.dwarfAddressToSymbolInfo(&self.dwarf, relocated_address);
    }
};
