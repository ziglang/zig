const std = @import("std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const testing = std.testing;
const elf = std.elf;
const windows = std.os.windows;
const native_os = builtin.os.tag;
const posix = std.posix;

/// Cross-platform dynamic library loading and symbol lookup.
/// Platform-specific functionality is available through the `inner` field.
pub const DynLib = struct {
    const InnerType = switch (native_os) {
        .linux => if (!builtin.link_libc or builtin.abi == .musl and builtin.link_mode == .static)
            ElfDynLib
        else
            DlDynLib,
        .windows => WindowsDynLib,
        .macos, .tvos, .watchos, .ios, .visionos, .freebsd, .netbsd, .openbsd, .dragonfly, .solaris, .illumos => DlDynLib,
        else => @compileError("unsupported platform"),
    };

    inner: InnerType,

    pub const Error = ElfDynLib.Error || DlDynLib.Error || WindowsDynLib.Error;

    /// Trusts the file. Malicious file will be able to execute arbitrary code.
    pub fn open(path: []const u8) Error!DynLib {
        return .{ .inner = try InnerType.open(path) };
    }

    /// Trusts the file. Malicious file will be able to execute arbitrary code.
    pub fn openZ(path_c: [*:0]const u8) Error!DynLib {
        return .{ .inner = try InnerType.open(path_c) };
    }

    /// Trusts the file.
    pub fn close(self: *DynLib) void {
        return self.inner.close();
    }

    pub fn lookup(self: *DynLib, comptime T: type, name: [:0]const u8) ?T {
        return self.inner.lookup(T, name);
    }
};

// The link_map structure is not completely specified beside the fields
// reported below, any libc is free to store additional data in the remaining
// space.
// An iterator is provided in order to traverse the linked list in a idiomatic
// fashion.
const LinkMap = extern struct {
    l_addr: usize,
    l_name: [*:0]const u8,
    l_ld: ?*elf.Dyn,
    l_next: ?*LinkMap,
    l_prev: ?*LinkMap,

    pub const Iterator = struct {
        current: ?*LinkMap,

        pub fn end(self: *Iterator) bool {
            return self.current == null;
        }

        pub fn next(self: *Iterator) ?*LinkMap {
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

/// TODO make it possible to reference this same external symbol 2x so we don't need this
/// helper function.
pub fn get_DYNAMIC() ?[*]elf.Dyn {
    return @extern([*]elf.Dyn, .{ .name = "_DYNAMIC", .linkage = .weak });
}

pub fn linkmap_iterator(phdrs: []elf.Phdr) error{InvalidExe}!LinkMap.Iterator {
    _ = phdrs;
    const _DYNAMIC = get_DYNAMIC() orelse {
        // No PT_DYNAMIC means this is either a statically-linked program or a
        // badly corrupted dynamically-linked one.
        return .{ .current = null };
    };

    const link_map_ptr = init: {
        var i: usize = 0;
        while (_DYNAMIC[i].d_tag != elf.DT_NULL) : (i += 1) {
            switch (_DYNAMIC[i].d_tag) {
                elf.DT_DEBUG => {
                    const ptr = @as(?*RDebug, @ptrFromInt(_DYNAMIC[i].d_val));
                    if (ptr) |r_debug| {
                        if (r_debug.r_version != 1) return error.InvalidExe;
                        break :init r_debug.r_map;
                    }
                },
                elf.DT_PLTGOT => {
                    const ptr = @as(?[*]usize, @ptrFromInt(_DYNAMIC[i].d_val));
                    if (ptr) |got_table| {
                        // The address to the link_map structure is stored in
                        // the second slot
                        break :init @as(?*LinkMap, @ptrFromInt(got_table[1]));
                    }
                },
                else => {},
            }
        }
        return .{ .current = null };
    };

    return .{ .current = link_map_ptr };
}

pub const ElfDynLib = struct {
    strings: [*:0]u8,
    syms: [*]elf.Sym,
    hashtab: [*]posix.Elf_Symndx,
    versym: ?[*]u16,
    verdef: ?*elf.Verdef,
    memory: []align(mem.page_size) u8,

    pub const Error = error{
        FileTooBig,
        NotElfFile,
        NotDynamicLibrary,
        MissingDynamicLinkingInformation,
        ElfStringSectionNotFound,
        ElfSymSectionNotFound,
        ElfHashTableNotFound,
    } || posix.OpenError || posix.MMapError;

    /// Trusts the file. Malicious file will be able to execute arbitrary code.
    pub fn open(path: []const u8) Error!ElfDynLib {
        const fd = try posix.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
        defer posix.close(fd);

        const stat = try posix.fstat(fd);
        const size = std.math.cast(usize, stat.size) orelse return error.FileTooBig;

        // This one is to read the ELF info. We do more mmapping later
        // corresponding to the actual LOAD sections.
        const file_bytes = try posix.mmap(
            null,
            mem.alignForward(usize, size, mem.page_size),
            posix.PROT.READ,
            .{ .TYPE = .PRIVATE },
            fd,
            0,
        );
        defer posix.munmap(file_bytes);

        const eh = @as(*elf.Ehdr, @ptrCast(file_bytes.ptr));
        if (!mem.eql(u8, eh.e_ident[0..4], elf.MAGIC)) return error.NotElfFile;
        if (eh.e_type != elf.ET.DYN) return error.NotDynamicLibrary;

        const elf_addr = @intFromPtr(file_bytes.ptr);

        // Iterate over the program header entries to find out the
        // dynamic vector as well as the total size of the virtual memory.
        var maybe_dynv: ?[*]usize = null;
        var virt_addr_end: usize = 0;
        {
            var i: usize = 0;
            var ph_addr: usize = elf_addr + eh.e_phoff;
            while (i < eh.e_phnum) : ({
                i += 1;
                ph_addr += eh.e_phentsize;
            }) {
                const ph = @as(*elf.Phdr, @ptrFromInt(ph_addr));
                switch (ph.p_type) {
                    elf.PT_LOAD => virt_addr_end = @max(virt_addr_end, ph.p_vaddr + ph.p_memsz),
                    elf.PT_DYNAMIC => maybe_dynv = @as([*]usize, @ptrFromInt(elf_addr + ph.p_offset)),
                    else => {},
                }
            }
        }
        const dynv = maybe_dynv orelse return error.MissingDynamicLinkingInformation;

        // Reserve the entire range (with no permissions) so that we can do MAP.FIXED below.
        const all_loaded_mem = try posix.mmap(
            null,
            virt_addr_end,
            posix.PROT.NONE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );
        errdefer posix.munmap(all_loaded_mem);

        const base = @intFromPtr(all_loaded_mem.ptr);

        // Now iterate again and actually load all the program sections.
        {
            var i: usize = 0;
            var ph_addr: usize = elf_addr + eh.e_phoff;
            while (i < eh.e_phnum) : ({
                i += 1;
                ph_addr += eh.e_phentsize;
            }) {
                const ph = @as(*elf.Phdr, @ptrFromInt(ph_addr));
                switch (ph.p_type) {
                    elf.PT_LOAD => {
                        // The VirtAddr may not be page-aligned; in such case there will be
                        // extra nonsense mapped before/after the VirtAddr,MemSiz
                        const aligned_addr = (base + ph.p_vaddr) & ~(@as(usize, mem.page_size) - 1);
                        const extra_bytes = (base + ph.p_vaddr) - aligned_addr;
                        const extended_memsz = mem.alignForward(usize, ph.p_memsz + extra_bytes, mem.page_size);
                        const ptr = @as([*]align(mem.page_size) u8, @ptrFromInt(aligned_addr));
                        const prot = elfToMmapProt(ph.p_flags);
                        if ((ph.p_flags & elf.PF_W) == 0) {
                            // If it does not need write access, it can be mapped from the fd.
                            _ = try posix.mmap(
                                ptr,
                                extended_memsz,
                                prot,
                                .{ .TYPE = .PRIVATE, .FIXED = true },
                                fd,
                                ph.p_offset - extra_bytes,
                            );
                        } else {
                            const sect_mem = try posix.mmap(
                                ptr,
                                extended_memsz,
                                prot,
                                .{ .TYPE = .PRIVATE, .FIXED = true, .ANONYMOUS = true },
                                -1,
                                0,
                            );
                            @memcpy(sect_mem[0..ph.p_filesz], file_bytes[0..ph.p_filesz]);
                        }
                    },
                    else => {},
                }
            }
        }

        var maybe_strings: ?[*:0]u8 = null;
        var maybe_syms: ?[*]elf.Sym = null;
        var maybe_hashtab: ?[*]posix.Elf_Symndx = null;
        var maybe_versym: ?[*]u16 = null;
        var maybe_verdef: ?*elf.Verdef = null;

        {
            var i: usize = 0;
            while (dynv[i] != 0) : (i += 2) {
                const p = base + dynv[i + 1];
                switch (dynv[i]) {
                    elf.DT_STRTAB => maybe_strings = @as([*:0]u8, @ptrFromInt(p)),
                    elf.DT_SYMTAB => maybe_syms = @as([*]elf.Sym, @ptrFromInt(p)),
                    elf.DT_HASH => maybe_hashtab = @as([*]posix.Elf_Symndx, @ptrFromInt(p)),
                    elf.DT_VERSYM => maybe_versym = @as([*]u16, @ptrFromInt(p)),
                    elf.DT_VERDEF => maybe_verdef = @as(*elf.Verdef, @ptrFromInt(p)),
                    else => {},
                }
            }
        }

        return .{
            .memory = all_loaded_mem,
            .strings = maybe_strings orelse return error.ElfStringSectionNotFound,
            .syms = maybe_syms orelse return error.ElfSymSectionNotFound,
            .hashtab = maybe_hashtab orelse return error.ElfHashTableNotFound,
            .versym = maybe_versym,
            .verdef = maybe_verdef,
        };
    }

    /// Trusts the file. Malicious file will be able to execute arbitrary code.
    pub fn openZ(path_c: [*:0]const u8) Error!ElfDynLib {
        return open(mem.sliceTo(path_c, 0));
    }

    /// Trusts the file
    pub fn close(self: *ElfDynLib) void {
        posix.munmap(self.memory);
        self.* = undefined;
    }

    pub fn lookup(self: *const ElfDynLib, comptime T: type, name: [:0]const u8) ?T {
        if (self.lookupAddress("", name)) |symbol| {
            return @as(T, @ptrFromInt(symbol));
        } else {
            return null;
        }
    }

    /// ElfDynLib specific
    /// Returns the address of the symbol
    pub fn lookupAddress(self: *const ElfDynLib, vername: []const u8, name: []const u8) ?usize {
        const maybe_versym = if (self.verdef == null) null else self.versym;

        const OK_TYPES = (1 << elf.STT_NOTYPE | 1 << elf.STT_OBJECT | 1 << elf.STT_FUNC | 1 << elf.STT_COMMON);
        const OK_BINDS = (1 << elf.STB_GLOBAL | 1 << elf.STB_WEAK | 1 << elf.STB_GNU_UNIQUE);

        var i: usize = 0;
        while (i < self.hashtab[1]) : (i += 1) {
            if (0 == (@as(u32, 1) << @as(u5, @intCast(self.syms[i].st_info & 0xf)) & OK_TYPES)) continue;
            if (0 == (@as(u32, 1) << @as(u5, @intCast(self.syms[i].st_info >> 4)) & OK_BINDS)) continue;
            if (0 == self.syms[i].st_shndx) continue;
            if (!mem.eql(u8, name, mem.sliceTo(self.strings + self.syms[i].st_name, 0))) continue;
            if (maybe_versym) |versym| {
                if (!checkver(self.verdef.?, versym[i], vername, self.strings))
                    continue;
            }
            return @intFromPtr(self.memory.ptr) + self.syms[i].st_value;
        }

        return null;
    }

    fn elfToMmapProt(elf_prot: u64) u32 {
        var result: u32 = posix.PROT.NONE;
        if ((elf_prot & elf.PF_R) != 0) result |= posix.PROT.READ;
        if ((elf_prot & elf.PF_W) != 0) result |= posix.PROT.WRITE;
        if ((elf_prot & elf.PF_X) != 0) result |= posix.PROT.EXEC;
        return result;
    }
};

fn checkver(def_arg: *elf.Verdef, vsym_arg: i32, vername: []const u8, strings: [*:0]u8) bool {
    var def = def_arg;
    const vsym = @as(u32, @bitCast(vsym_arg)) & 0x7fff;
    while (true) {
        if (0 == (def.vd_flags & elf.VER_FLG_BASE) and (def.vd_ndx & 0x7fff) == vsym)
            break;
        if (def.vd_next == 0)
            return false;
        def = @as(*elf.Verdef, @ptrFromInt(@intFromPtr(def) + def.vd_next));
    }
    const aux = @as(*elf.Verdaux, @ptrFromInt(@intFromPtr(def) + def.vd_aux));
    return mem.eql(u8, vername, mem.sliceTo(strings + aux.vda_name, 0));
}

test "ElfDynLib" {
    if (native_os != .linux) {
        return error.SkipZigTest;
    }

    try testing.expectError(error.FileNotFound, ElfDynLib.open("invalid_so.so"));
}

pub const WindowsDynLib = struct {
    pub const Error = error{
        FileNotFound,
        InvalidPath,
    } || windows.LoadLibraryError;

    dll: windows.HMODULE,

    pub fn open(path: []const u8) Error!WindowsDynLib {
        return openEx(path, .none);
    }

    /// WindowsDynLib specific
    /// Opens dynamic library with specified library loading flags.
    pub fn openEx(path: []const u8, flags: windows.LoadLibraryFlags) Error!WindowsDynLib {
        const path_w = windows.sliceToPrefixedFileW(null, path) catch return error.InvalidPath;
        return openExW(path_w.span().ptr, flags);
    }

    pub fn openZ(path_c: [*:0]const u8) Error!WindowsDynLib {
        return openExZ(path_c, .none);
    }

    /// WindowsDynLib specific
    /// Opens dynamic library with specified library loading flags.
    pub fn openExZ(path_c: [*:0]const u8, flags: windows.LoadLibraryFlags) Error!WindowsDynLib {
        const path_w = try windows.cStrToPrefixedFileW(null, path_c);
        return openExW(path_w.span().ptr, flags);
    }

    /// WindowsDynLib specific
    pub fn openW(path_w: [*:0]const u16) Error!WindowsDynLib {
        return openExW(path_w, .none);
    }

    /// WindowsDynLib specific
    /// Opens dynamic library with specified library loading flags.
    pub fn openExW(path_w: [*:0]const u16, flags: windows.LoadLibraryFlags) Error!WindowsDynLib {
        var offset: usize = 0;
        if (path_w[0] == '\\' and path_w[1] == '?' and path_w[2] == '?' and path_w[3] == '\\') {
            // + 4 to skip over the \??\
            offset = 4;
        }

        return .{
            .dll = try windows.LoadLibraryExW(path_w + offset, flags),
        };
    }

    pub fn close(self: *WindowsDynLib) void {
        windows.FreeLibrary(self.dll);
        self.* = undefined;
    }

    pub fn lookup(self: *WindowsDynLib, comptime T: type, name: [:0]const u8) ?T {
        if (windows.kernel32.GetProcAddress(self.dll, name.ptr)) |addr| {
            return @as(T, @ptrCast(@alignCast(addr)));
        } else {
            return null;
        }
    }
};

pub const DlDynLib = struct {
    pub const Error = error{ FileNotFound, NameTooLong };

    handle: *anyopaque,

    pub fn open(path: []const u8) Error!DlDynLib {
        const path_c = try posix.toPosixPath(path);
        return openZ(&path_c);
    }

    pub fn openZ(path_c: [*:0]const u8) Error!DlDynLib {
        return .{
            .handle = std.c.dlopen(path_c, std.c.RTLD.LAZY) orelse {
                return error.FileNotFound;
            },
        };
    }

    pub fn close(self: *DlDynLib) void {
        switch (posix.errno(std.c.dlclose(self.handle))) {
            .SUCCESS => return,
            else => unreachable,
        }
        self.* = undefined;
    }

    pub fn lookup(self: *DlDynLib, comptime T: type, name: [:0]const u8) ?T {
        // dlsym (and other dl-functions) secretly take shadow parameter - return address on stack
        // https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66826
        if (@call(.never_tail, std.c.dlsym, .{ self.handle, name.ptr })) |symbol| {
            return @as(T, @ptrCast(@alignCast(symbol)));
        } else {
            return null;
        }
    }

    /// DlDynLib specific
    /// Returns human readable string describing most recent error than occurred from `lookup`
    /// or `null` if no error has occurred since initialization or when `getError` was last called.
    pub fn getError() ?[:0]const u8 {
        return mem.span(std.c.dlerror());
    }
};

test "dynamic_library" {
    const libname = switch (native_os) {
        .linux, .freebsd, .openbsd, .solaris, .illumos => "invalid_so.so",
        .windows => "invalid_dll.dll",
        .macos, .tvos, .watchos, .ios, .visionos => "invalid_dylib.dylib",
        else => return error.SkipZigTest,
    };

    try testing.expectError(error.FileNotFound, DynLib.open(libname));
}
