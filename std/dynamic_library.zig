const std = @import("index.zig");
const mem = std.mem;
const elf = std.elf;
const cstr = std.cstr;
const linux = std.os.linux;

pub const DynLib = struct {
    allocator: *mem.Allocator,
    elf_lib: ElfLib,
    fd: i32,
    map_addr: usize,
    map_size: usize,

    /// Trusts the file
    pub fn open(allocator: *mem.Allocator, path: []const u8) !DynLib {
        const fd = try std.os.posixOpen(allocator, path, 0, linux.O_RDONLY | linux.O_CLOEXEC);
        errdefer std.os.close(fd);

        const size = @intCast(usize, (try std.os.posixFStat(fd)).size);

        const addr = linux.mmap(
            null,
            size,
            linux.PROT_READ | linux.PROT_EXEC,
            linux.MAP_PRIVATE | linux.MAP_LOCKED,
            fd,
            0,
        );
        errdefer _ = linux.munmap(addr, size);

        const bytes = @intToPtr([*]align(std.os.page_size) u8, addr)[0..size];

        return DynLib{
            .allocator = allocator,
            .elf_lib = try ElfLib.init(bytes),
            .fd = fd,
            .map_addr = addr,
            .map_size = size,
        };
    }

    pub fn close(self: *DynLib) void {
        _ = linux.munmap(self.map_addr, self.map_size);
        std.os.close(self.fd);
        self.* = undefined;
    }

    pub fn lookup(self: *DynLib, name: []const u8) ?usize {
        return self.elf_lib.lookup("", name);
    }
};

pub const ElfLib = struct {
    strings: [*]u8,
    syms: [*]elf.Sym,
    hashtab: [*]linux.Elf_Symndx,
    versym: ?[*]u16,
    verdef: ?*elf.Verdef,
    base: usize,

    // Trusts the memory
    pub fn init(bytes: []align(@alignOf(elf.Ehdr)) u8) !ElfLib {
        const eh = @ptrCast(*elf.Ehdr, bytes.ptr);
        if (!mem.eql(u8, eh.e_ident[0..4], "\x7fELF")) return error.NotElfFile;
        if (eh.e_type != elf.ET_DYN) return error.NotDynamicLibrary;

        const elf_addr = @ptrToInt(bytes.ptr);
        var ph_addr: usize = elf_addr + eh.e_phoff;

        var base: usize = @maxValue(usize);
        var maybe_dynv: ?[*]usize = null;
        {
            var i: usize = 0;
            while (i < eh.e_phnum) : ({
                i += 1;
                ph_addr += eh.e_phentsize;
            }) {
                const ph = @intToPtr(*elf.Phdr, ph_addr);
                switch (ph.p_type) {
                    elf.PT_LOAD => base = elf_addr + ph.p_offset - ph.p_vaddr,
                    elf.PT_DYNAMIC => maybe_dynv = @intToPtr([*]usize, elf_addr + ph.p_offset),
                    else => {},
                }
            }
        }
        const dynv = maybe_dynv orelse return error.MissingDynamicLinkingInformation;
        if (base == @maxValue(usize)) return error.BaseNotFound;

        var maybe_strings: ?[*]u8 = null;
        var maybe_syms: ?[*]elf.Sym = null;
        var maybe_hashtab: ?[*]linux.Elf_Symndx = null;
        var maybe_versym: ?[*]u16 = null;
        var maybe_verdef: ?*elf.Verdef = null;

        {
            var i: usize = 0;
            while (dynv[i] != 0) : (i += 2) {
                const p = base + dynv[i + 1];
                switch (dynv[i]) {
                    elf.DT_STRTAB => maybe_strings = @intToPtr([*]u8, p),
                    elf.DT_SYMTAB => maybe_syms = @intToPtr([*]elf.Sym, p),
                    elf.DT_HASH => maybe_hashtab = @intToPtr([*]linux.Elf_Symndx, p),
                    elf.DT_VERSYM => maybe_versym = @intToPtr([*]u16, p),
                    elf.DT_VERDEF => maybe_verdef = @intToPtr(*elf.Verdef, p),
                    else => {},
                }
            }
        }

        return ElfLib{
            .base = base,
            .strings = maybe_strings orelse return error.ElfStringSectionNotFound,
            .syms = maybe_syms orelse return error.ElfSymSectionNotFound,
            .hashtab = maybe_hashtab orelse return error.ElfHashTableNotFound,
            .versym = maybe_versym,
            .verdef = maybe_verdef,
        };
    }

    /// Returns the address of the symbol
    pub fn lookup(self: *const ElfLib, vername: []const u8, name: []const u8) ?usize {
        const maybe_versym = if (self.verdef == null) null else self.versym;

        const OK_TYPES = (1 << elf.STT_NOTYPE | 1 << elf.STT_OBJECT | 1 << elf.STT_FUNC | 1 << elf.STT_COMMON);
        const OK_BINDS = (1 << elf.STB_GLOBAL | 1 << elf.STB_WEAK | 1 << elf.STB_GNU_UNIQUE);

        var i: usize = 0;
        while (i < self.hashtab[1]) : (i += 1) {
            if (0 == (u32(1) << @intCast(u5, self.syms[i].st_info & 0xf) & OK_TYPES)) continue;
            if (0 == (u32(1) << @intCast(u5, self.syms[i].st_info >> 4) & OK_BINDS)) continue;
            if (0 == self.syms[i].st_shndx) continue;
            if (!mem.eql(u8, name, cstr.toSliceConst(self.strings + self.syms[i].st_name))) continue;
            if (maybe_versym) |versym| {
                if (!checkver(self.verdef.?, versym[i], vername, self.strings))
                    continue;
            }
            return self.base + self.syms[i].st_value;
        }

        return null;
    }
};

fn checkver(def_arg: *elf.Verdef, vsym_arg: i32, vername: []const u8, strings: [*]u8) bool {
    var def = def_arg;
    const vsym = @bitCast(u32, vsym_arg) & 0x7fff;
    while (true) {
        if (0 == (def.vd_flags & elf.VER_FLG_BASE) and (def.vd_ndx & 0x7fff) == vsym)
            break;
        if (def.vd_next == 0)
            return false;
        def = @intToPtr(*elf.Verdef, @ptrToInt(def) + def.vd_next);
    }
    const aux = @intToPtr(*elf.Verdaux, @ptrToInt(def) + def.vd_aux);
    return mem.eql(u8, vername, cstr.toSliceConst(strings + aux.vda_name));
}
