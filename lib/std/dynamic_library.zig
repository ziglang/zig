const builtin = @import("builtin");

const std = @import("std.zig");
const mem = std.mem;
const os = std.os;
const assert = std.debug.assert;
const testing = std.testing;
const elf = std.elf;
const windows = std.os.windows;
const system = std.os.system;
const maxInt = std.math.maxInt;

pub const DynLib = switch (builtin.os) {
    .linux => if (builtin.link_libc) DlDynlib else LinuxDynLib,
    .windows => WindowsDynLib,
    .macosx, .tvos, .watchos, .ios, .freebsd => DlDynlib,
    else => void,
};

// The link_map structure is not completely specified beside the fields
// reported below, any libc is free to store additional data in the remaining
// space.
// An iterator is provided in order to traverse the linked list in a idiomatic
// fashion.
const LinkMap = extern struct {
    l_addr: usize,
    l_name: [*]const u8,
    l_ld: ?*elf.Dyn,
    l_next: ?*LinkMap,
    l_prev: ?*LinkMap,

    pub const Iterator = struct {
        current: ?*LinkMap,

        fn end(self: *Iterator) bool {
            return self.current == null;
        }

        fn next(self: *Iterator) ?*LinkMap {
            if (self.current) |it| {
                self.current = it.l_next;
                return it;
            }
            return null;
        }
    };
};

const RDebug = extern struct {
    r_version: i32,
    r_map: ?*LinkMap,
    r_brk: usize,
    r_ldbase: usize,
};

fn elf_get_va_offset(phdrs: []elf.Phdr) !usize {
    for (phdrs) |*phdr| {
        if (phdr.p_type == elf.PT_LOAD) {
            return @ptrToInt(phdr) - phdr.p_vaddr;
        }
    }
    return error.InvalidExe;
}

pub fn linkmap_iterator(phdrs: []elf.Phdr) !LinkMap.Iterator {
    const va_offset = try elf_get_va_offset(phdrs);

    const dyn_table = init: {
        for (phdrs) |*phdr| {
            if (phdr.p_type == elf.PT_DYNAMIC) {
                const ptr = @intToPtr([*]elf.Dyn, va_offset + phdr.p_vaddr);
                break :init ptr[0 .. phdr.p_memsz / @sizeOf(elf.Dyn)];
            }
        }
        // No PT_DYNAMIC means this is either a statically-linked program or a
        // badly corrupted one
        return LinkMap.Iterator{ .current = null };
    };

    const link_map_ptr = init: {
        for (dyn_table) |*dyn| {
            switch (dyn.d_tag) {
                elf.DT_DEBUG => {
                    const r_debug = @intToPtr(*RDebug, dyn.d_un.d_ptr);
                    if (r_debug.r_version != 1) return error.InvalidExe;
                    break :init r_debug.r_map;
                },
                elf.DT_PLTGOT => {
                    const got_table = @intToPtr([*]usize, dyn.d_un.d_ptr);
                    // The address to the link_map structure is stored in the
                    // second slot
                    break :init @intToPtr(?*LinkMap, got_table[1]);
                },
                else => {},
            }
        }
        return error.InvalidExe;
    };

    return LinkMap.Iterator{ .current = link_map_ptr };
}

pub const LinuxDynLib = struct {
    pub const Error = ElfLib.Error;

    elf_lib: ElfLib,
    fd: i32,
    memory: []align(mem.page_size) u8,

    /// Trusts the file
    pub fn open(path: []const u8) !LinuxDynLib {
        const fd = try os.open(path, 0, os.O_RDONLY | os.O_CLOEXEC);
        errdefer os.close(fd);

        // TODO remove this @intCast
        const size = @intCast(usize, (try os.fstat(fd)).size);

        const bytes = try os.mmap(
            null,
            mem.alignForward(size, mem.page_size),
            os.PROT_READ | os.PROT_EXEC,
            os.MAP_PRIVATE,
            fd,
            0,
        );
        errdefer os.munmap(bytes);

        return LinuxDynLib{
            .elf_lib = try ElfLib.init(bytes),
            .fd = fd,
            .memory = bytes,
        };
    }

    pub fn openC(path_c: [*:0]const u8) !LinuxDynLib {
        return open(mem.toSlice(u8, path_c));
    }

    pub fn close(self: *LinuxDynLib) void {
        os.munmap(self.memory);
        os.close(self.fd);
        self.* = undefined;
    }

    pub fn lookup(self: *LinuxDynLib, comptime T: type, name: [:0]const u8) ?T {
        if (self.elf_lib.lookup("", name)) |symbol| {
            return @intToPtr(T, symbol);
        } else {
            return null;
        }
    }
};

pub const ElfLib = struct {
    pub const Error = error{
        NotElfFile,
        NotDynamicLibrary,
        MissingDynamicLinkingInformation,
        BaseNotFound,
        ElfStringSectionNotFound,
        ElfSymSectionNotFound,
        ElfHashTableNotFound,
    };

    strings: [*:0]u8,
    syms: [*]elf.Sym,
    hashtab: [*]os.Elf_Symndx,
    versym: ?[*]u16,
    verdef: ?*elf.Verdef,
    base: usize,

    // Trusts the memory
    pub fn init(bytes: []align(@alignOf(elf.Ehdr)) u8) !ElfLib {
        const eh = @ptrCast(*elf.Ehdr, bytes.ptr);
        if (!mem.eql(u8, eh.e_ident[0..4], "\x7fELF")) return error.NotElfFile;
        if (eh.e_type != elf.ET.DYN) return error.NotDynamicLibrary;

        const elf_addr = @ptrToInt(bytes.ptr);
        var ph_addr: usize = elf_addr + eh.e_phoff;

        var base: usize = maxInt(usize);
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
        if (base == maxInt(usize)) return error.BaseNotFound;

        var maybe_strings: ?[*:0]u8 = null;
        var maybe_syms: ?[*]elf.Sym = null;
        var maybe_hashtab: ?[*]os.Elf_Symndx = null;
        var maybe_versym: ?[*]u16 = null;
        var maybe_verdef: ?*elf.Verdef = null;

        {
            var i: usize = 0;
            while (dynv[i] != 0) : (i += 2) {
                const p = base + dynv[i + 1];
                switch (dynv[i]) {
                    elf.DT_STRTAB => maybe_strings = @intToPtr([*:0]u8, p),
                    elf.DT_SYMTAB => maybe_syms = @intToPtr([*]elf.Sym, p),
                    elf.DT_HASH => maybe_hashtab = @intToPtr([*]os.Elf_Symndx, p),
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
            if (0 == (@as(u32, 1) << @intCast(u5, self.syms[i].st_info & 0xf) & OK_TYPES)) continue;
            if (0 == (@as(u32, 1) << @intCast(u5, self.syms[i].st_info >> 4) & OK_BINDS)) continue;
            if (0 == self.syms[i].st_shndx) continue;
            if (!mem.eql(u8, name, mem.toSliceConst(u8, self.strings + self.syms[i].st_name))) continue;
            if (maybe_versym) |versym| {
                if (!checkver(self.verdef.?, versym[i], vername, self.strings))
                    continue;
            }
            return self.base + self.syms[i].st_value;
        }

        return null;
    }
};

fn checkver(def_arg: *elf.Verdef, vsym_arg: i32, vername: []const u8, strings: [*:0]u8) bool {
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
    return mem.eql(u8, vername, mem.toSliceConst(u8, strings + aux.vda_name));
}

pub const WindowsDynLib = struct {
    pub const Error = error{FileNotFound};

    dll: windows.HMODULE,

    pub fn open(path: []const u8) !WindowsDynLib {
        const path_w = try windows.sliceToPrefixedFileW(path);
        return openW(&path_w);
    }

    pub fn openC(path_c: [*:0]const u8) !WindowsDynLib {
        const path_w = try windows.cStrToPrefixedFileW(path);
        return openW(&path_w);
    }

    pub fn openW(path_w: [*:0]const u16) !WindowsDynLib {
        return WindowsDynLib{
            // + 4 to skip over the \??\
            .dll = try windows.LoadLibraryW(path_w + 4),
        };
    }

    pub fn close(self: *WindowsDynLib) void {
        windows.FreeLibrary(self.dll);
        self.* = undefined;
    }

    pub fn lookup(self: *WindowsDynLib, comptime T: type, name: [:0]const u8) ?T {
        if (windows.kernel32.GetProcAddress(self.dll, name.ptr)) |addr| {
            return @ptrCast(T, addr);
        } else {
            return null;
        }
    }
};

pub const DlDynlib = struct {
    pub const Error = error{FileNotFound};

    handle: *c_void,

    pub fn open(path: []const u8) !DlDynlib {
        const path_c = try os.toPosixPath(path);
        return openC(&path_c);
    }

    pub fn openC(path_c: [*:0]const u8) !DlDynlib {
        return DlDynlib{
            .handle = system.dlopen(path_c, system.RTLD_LAZY) orelse {
                return error.FileNotFound;
            },
        };
    }

    pub fn close(self: *DlDynlib) void {
        _ = system.dlclose(self.handle);
        self.* = undefined;
    }

    pub fn lookup(self: *DlDynlib, comptime T: type, name: [:0]const u8) ?T {
        // dlsym (and other dl-functions) secretly take shadow parameter - return address on stack
        // https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66826
        if (@call(.{ .modifier = .never_tail }, system.dlsym, .{ self.handle, name.ptr })) |symbol| {
            return @ptrCast(T, symbol);
        } else {
            return null;
        }
    }
};

test "dynamic_library" {
    const libname = switch (builtin.os) {
        .linux, .freebsd => "invalid_so.so",
        .windows => "invalid_dll.dll",
        .macosx, .tvos, .watchos, .ios => "invalid_dylib.dylib",
        else => return error.SkipZigTest,
    };

    const dynlib = DynLib.open(libname) catch |err| {
        testing.expect(err == error.FileNotFound);
        return;
    };
}
