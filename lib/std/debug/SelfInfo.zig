//! Cross-platform abstraction for this binary's own debug information, with a
//! goal of minimal code bloat and compilation speed penalty.

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const native_endian = native_arch.endian();
const native_arch = builtin.cpu.arch;

const std = @import("../std.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const windows = std.os.windows;
const macho = std.macho;
const fs = std.fs;
const coff = std.coff;
const assert = std.debug.assert;
const posix = std.posix;
const elf = std.elf;
const Dwarf = std.debug.Dwarf;
const Pdb = std.debug.Pdb;
const File = std.fs.File;
const math = std.math;
const testing = std.testing;
const regBytes = Dwarf.abi.regBytes;
const regValueNative = Dwarf.abi.regValueNative;

const SelfInfo = @This();

modules: std.AutoHashMapUnmanaged(usize, struct {
    di: Module.DebugInfo,
    // MLUGG TODO: okay actually these should definitely go on the impl so it can share state. e.g. loading unwind info might require lodaing debug info in some cases
    loaded_locations: bool,
    loaded_unwind: bool,
    const init: @This() = .{ .di = .init, .loaded_locations = false, .loaded_unwind = false };
}),
lookup_cache: Module.LookupCache,

pub const target_supported: bool = switch (native_os) {
    .linux,
    .freebsd,
    .netbsd,
    .dragonfly,
    .openbsd,
    .macos,
    .solaris,
    .illumos,
    .windows,
    => true,
    else => false,
};

pub const init: SelfInfo = .{
    .modules = .empty,
    .lookup_cache = if (Module.LookupCache != void) .init,
};

pub fn deinit(self: *SelfInfo) void {
    // MLUGG TODO: that's amusing, this function is straight-up unused. i... wonder if it even should be used anywhere? perhaps not... so perhaps it should not even exist...????
    var it = self.modules.iterator();
    while (it.next()) |entry| {
        const mdi = entry.value_ptr.*;
        mdi.deinit(self.allocator);
        self.allocator.destroy(mdi);
    }
    self.modules.deinit(self.allocator);
    if (native_os == .windows) {
        for (self.modules.items) |module| {
            self.allocator.free(module.name);
            if (module.mapped_file) |mapped_file| mapped_file.deinit();
        }
        self.modules.deinit(self.allocator);
    }
}

pub fn unwindFrame(self: *SelfInfo, gpa: Allocator, context: *UnwindContext) !usize {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, context.pc);
    const gop = try self.modules.getOrPut(gpa, module.load_offset);
    if (!gop.found_existing) gop.value_ptr.* = .init;
    if (!gop.value_ptr.loaded_unwind) {
        try module.loadUnwindInfo(gpa, &gop.value_ptr.di);
        gop.value_ptr.loaded_unwind = true;
    }
    return module.unwindFrame(gpa, &gop.value_ptr.di, context);
}

pub fn getSymbolAtAddress(self: *SelfInfo, gpa: Allocator, address: usize) !std.debug.Symbol {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    const gop = try self.modules.getOrPut(gpa, module.key());
    if (!gop.found_existing) gop.value_ptr.* = .init;
    if (!gop.value_ptr.loaded_locations) {
        try module.loadLocationInfo(gpa, &gop.value_ptr.di);
        gop.value_ptr.loaded_locations = true;
    }
    return module.getSymbolAtAddress(gpa, &gop.value_ptr.di, address);
}

/// Returns the module name for a given address.
/// This can be called when getModuleForAddress fails, so implementations should provide
/// a path that doesn't rely on any side-effects of a prior successful module lookup.
pub fn getModuleNameForAddress(self: *SelfInfo, gpa: Allocator, address: usize) error{ Unexpected, OutOfMemory, MissingDebugInfo }![]const u8 {
    comptime assert(target_supported);
    const module: Module = try .lookup(&self.lookup_cache, gpa, address);
    return module.name;
}

const Module = switch (native_os) {
    else => {}, // Dwarf, // TODO MLUGG: it's this on master but that's definitely broken atm...
    .macos, .ios, .watchos, .tvos, .visionos => struct {
        /// The runtime address where __TEXT is loaded.
        text_base: usize,
        load_offset: usize,
        name: []const u8,
        unwind_info: ?[]const u8,
        eh_frame: ?[]const u8,
        fn key(m: *const Module) usize {
            return m.text_base;
        }
        fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) !Module {
            _ = cache;
            _ = gpa;
            const image_count = std.c._dyld_image_count();
            for (0..image_count) |image_idx| {
                const header = std.c._dyld_get_image_header(@intCast(image_idx)) orelse continue;
                const text_base = @intFromPtr(header);
                if (address < text_base) continue;
                const load_offset = std.c._dyld_get_image_vmaddr_slide(@intCast(image_idx));

                // Find the __TEXT segment
                var it: macho.LoadCommandIterator = .{
                    .ncmds = header.ncmds,
                    .buffer = @as([*]u8, @ptrCast(header))[@sizeOf(macho.mach_header_64)..][0..header.sizeofcmds],
                };
                const text_segment_cmd, const text_sections = while (it.next()) |load_cmd| {
                    if (load_cmd.cmd() != .SEGMENT_64) continue;
                    const segment_cmd = load_cmd.cast(macho.segment_command_64).?;
                    if (!mem.eql(u8, segment_cmd.segName(), "__TEXT")) continue;
                    break .{ segment_cmd, load_cmd.getSections() };
                } else continue;

                const seg_start = load_offset + text_segment_cmd.vmaddr;
                assert(seg_start == text_base);
                const seg_end = seg_start + text_segment_cmd.vmsize;
                if (address < seg_start or address >= seg_end) continue;

                // We've found the matching __TEXT segment. This is the image we need, but we must look
                // for unwind info in it before returning.

                var result: Module = .{
                    .text_base = text_base,
                    .load_offset = load_offset,
                    .name = mem.span(std.c._dyld_get_image_name(@intCast(image_idx))),
                    .unwind_info = null,
                    .eh_frame = null,
                };
                for (text_sections) |sect| {
                    if (mem.eql(u8, sect.sectName(), "__unwind_info")) {
                        const sect_ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(load_offset + sect.addr)));
                        result.unwind_info = sect_ptr[0..@intCast(sect.size)];
                    } else if (mem.eql(u8, sect.sectName(), "__eh_frame")) {
                        const sect_ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(load_offset + sect.addr)));
                        result.eh_frame = sect_ptr[0..@intCast(sect.size)];
                    }
                }
                return result;
            }
            return error.MissingDebugInfo;
        }
        fn loadLocationInfo(module: *const Module, gpa: Allocator, di: *Module.DebugInfo) !void {
            try loadMachODebugInfo(gpa, module, di); // MLUGG TODO inline
        }
        fn loadUnwindInfo(module: *const Module, gpa: Allocator, di: *Module.DebugInfo) !void {
            // MLUGG TODO HACKHACK
            try loadMachODebugInfo(gpa, module, di);
        }
        fn getSymbolAtAddress(module: *const Module, gpa: Allocator, di: *DebugInfo, address: usize) !std.debug.Symbol {
            const vaddr = address - module.load_offset;
            const symbol = MachoSymbol.find(di.symbols, vaddr) orelse return .{}; // MLUGG TODO null?

            // offset of `address` from start of `symbol`
            const address_symbol_offset = vaddr - symbol.addr;

            // Take the symbol name from the N_FUN STAB entry, we're going to
            // use it if we fail to find the DWARF infos
            const stab_symbol = mem.sliceTo(di.strings[symbol.strx..], 0);
            const o_file_path = mem.sliceTo(di.strings[symbol.ofile..], 0);

            const o_file: *DebugInfo.OFile = of: {
                const gop = try di.ofiles.getOrPut(gpa, o_file_path);
                if (!gop.found_existing) {
                    gop.value_ptr.* = DebugInfo.loadOFile(gpa, o_file_path) catch |err| {
                        defer _ = di.ofiles.pop().?;
                        switch (err) {
                            error.FileNotFound,
                            error.MissingDebugInfo,
                            error.InvalidDebugInfo,
                            => return .{ .name = stab_symbol },
                            else => |e| return e,
                        }
                    };
                }
                break :of gop.value_ptr;
            };

            const symbol_ofile_vaddr = o_file.addr_table.get(stab_symbol) orelse return .{ .name = stab_symbol };

            const compile_unit = o_file.dwarf.findCompileUnit(native_endian, symbol_ofile_vaddr) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => return .{ .name = stab_symbol },
                else => |e| return e,
            };

            return .{
                .name = o_file.dwarf.getSymbolName(symbol_ofile_vaddr) orelse stab_symbol,
                .compile_unit_name = compile_unit.die.getAttrString(
                    &o_file.dwarf,
                    native_endian,
                    std.dwarf.AT.name,
                    o_file.dwarf.section(.debug_str),
                    compile_unit,
                ) catch |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                },
                .source_location = o_file.dwarf.getLineNumberInfo(
                    gpa,
                    native_endian,
                    compile_unit,
                    symbol_ofile_vaddr + address_symbol_offset,
                ) catch |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => null,
                    else => return err,
                },
            };
        }
        fn unwindFrame(module: *const Module, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) !usize {
            _ = gpa;
            const unwind_info = di.unwind_info orelse return error.MissingUnwindInfo;
            // MLUGG TODO: inline
            return unwindFrameMachO(
                module.text_base,
                module.load_offset,
                context,
                unwind_info,
                di.eh_frame,
            );
        }
        const LookupCache = void;
        const DebugInfo = struct {
            mapped_memory: []align(std.heap.page_size_min) const u8,
            symbols: []const MachoSymbol,
            strings: [:0]const u8,
            // MLUGG TODO: this could use an adapter to just index straight into `strings`!
            ofiles: std.StringArrayHashMapUnmanaged(OFile),

            // Backed by the in-memory sections mapped by the loader
            // MLUGG TODO: these are duplicated state. i actually reckon they should be removed from Module, and loadMachODebugInfo should be the one discovering them!
            unwind_info: ?[]const u8,
            eh_frame: ?[]const u8,

            // MLUGG TODO HACKHACK: this is awful
            const init: DebugInfo = undefined;

            const OFile = struct {
                dwarf: Dwarf,
                // MLUGG TODO: this could use an adapter to just index straight into the strtab!
                addr_table: std.StringArrayHashMapUnmanaged(u64),
            };

            fn deinit(di: *DebugInfo, gpa: Allocator) void {
                for (di.ofiles.values()) |*ofile| {
                    ofile.dwarf.deinit(gpa);
                    ofile.addr_table.deinit(gpa);
                }
                di.ofiles.deinit();
                gpa.free(di.symbols);
                posix.munmap(di.mapped_memory);
            }

            fn loadOFile(gpa: Allocator, o_file_path: []const u8) !OFile {
                const mapped_mem = try mapFileOrSelfExe(o_file_path);
                errdefer posix.munmap(mapped_mem);

                if (mapped_mem.len < @sizeOf(macho.mach_header_64)) return error.InvalidDebugInfo;
                const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
                if (hdr.magic != std.macho.MH_MAGIC_64) return error.InvalidDebugInfo;

                const seg_cmd: macho.LoadCommandIterator.LoadCommand, const symtab_cmd: macho.symtab_command = cmds: {
                    var seg_cmd: ?macho.LoadCommandIterator.LoadCommand = null;
                    var symtab_cmd: ?macho.symtab_command = null;
                    var it: macho.LoadCommandIterator = .{
                        .ncmds = hdr.ncmds,
                        .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
                    };
                    while (it.next()) |cmd| switch (cmd.cmd()) {
                        .SEGMENT_64 => seg_cmd = cmd,
                        .SYMTAB => symtab_cmd = cmd.cast(macho.symtab_command) orelse return error.InvalidDebugInfo,
                        else => {},
                    };
                    break :cmds .{
                        seg_cmd orelse return error.MissingDebugInfo,
                        symtab_cmd orelse return error.MissingDebugInfo,
                    };
                };

                if (mapped_mem.len < symtab_cmd.stroff + symtab_cmd.strsize) return error.InvalidDebugInfo;
                if (mapped_mem[symtab_cmd.stroff + symtab_cmd.strsize - 1] != 0) return error.InvalidDebugInfo;
                const strtab = mapped_mem[symtab_cmd.stroff..][0 .. symtab_cmd.strsize - 1];

                const n_sym_bytes = symtab_cmd.nsyms * @sizeOf(macho.nlist_64);
                if (mapped_mem.len < symtab_cmd.symoff + n_sym_bytes) return error.InvalidDebugInfo;
                const symtab: []align(1) const macho.nlist_64 = @ptrCast(mapped_mem[symtab_cmd.symoff..][0..n_sym_bytes]);

                // TODO handle tentative (common) symbols
                // MLUGG TODO: does initCapacity actually make sense?
                var addr_table: std.StringArrayHashMapUnmanaged(u64) = .empty;
                defer addr_table.deinit(gpa);
                try addr_table.ensureUnusedCapacity(gpa, @intCast(symtab.len));
                for (symtab) |sym| {
                    if (sym.n_strx == 0) continue;
                    switch (sym.n_type.bits.type) {
                        .undf => continue, // includes tentative symbols
                        .abs => continue,
                        else => {},
                    }
                    const sym_name = mem.sliceTo(strtab[sym.n_strx..], 0);
                    const gop = addr_table.getOrPutAssumeCapacity(sym_name);
                    if (gop.found_existing) return error.InvalidDebugInfo;
                    gop.value_ptr.* = sym.n_value;
                }

                var sections: Dwarf.SectionArray = @splat(null);
                for (seg_cmd.getSections()) |sect| {
                    if (!std.mem.eql(u8, "__DWARF", sect.segName())) continue;

                    const section_index: usize = inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |section, i| {
                        if (mem.eql(u8, "__" ++ section.name, sect.sectName())) break i;
                    } else continue;

                    const section_bytes = try Dwarf.chopSlice(mapped_mem, sect.offset, sect.size);
                    sections[section_index] = .{
                        .data = section_bytes,
                        .virtual_address = @intCast(sect.addr),
                        .owned = false,
                    };
                }

                const missing_debug_info =
                    sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
                    sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
                    sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
                    sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;
                if (missing_debug_info) return error.MissingDebugInfo;

                var dwarf: Dwarf = .{ .sections = sections };
                errdefer dwarf.deinit(gpa);
                try dwarf.open(gpa, native_endian);

                return .{
                    .dwarf = dwarf,
                    .addr_table = addr_table.move(),
                };
            }
        };
    },
    .wasi, .emscripten => struct {
        const LookupCache = void;
        const DebugInfo = struct {
            const init: DebugInfo = .{};
        };
        fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) !Module {
            _ = cache;
            _ = gpa;
            _ = address;
            @panic("TODO implement lookup module for Wasm");
        }
        fn getSymbolAtAddress(module: *const Module, gpa: Allocator, di: *DebugInfo, address: usize) !std.debug.Symbol {
            _ = module;
            _ = gpa;
            _ = di;
            _ = address;
            unreachable;
        }
        fn loadLocationInfo(module: *const Module, gpa: Allocator, di: *DebugInfo) !void {
            _ = module;
            _ = gpa;
            _ = di;
            unreachable;
        }
        fn loadUnwindInfo(module: *const Module, gpa: Allocator, di: *DebugInfo) !void {
            _ = module;
            _ = gpa;
            _ = di;
            unreachable;
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris, .illumos => struct {
        load_offset: usize,
        name: []const u8,
        build_id: ?[]const u8,
        gnu_eh_frame: ?[]const u8,
        const LookupCache = void;
        const DebugInfo = struct {
            const init: DebugInfo = undefined; // MLUGG TODO: this makes me sad
            em: Dwarf.ElfModule, // MLUGG TODO: bad field name (and, frankly, type)
            unwind: Dwarf.Unwind,
        };
        fn key(m: Module) usize {
            return m.load_offset; // MLUGG TODO: is this technically valid? idk
        }
        fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) !Module {
            _ = cache;
            _ = gpa;
            if (native_os == .haiku) @panic("TODO implement lookup module for Haiku");
            const DlIterContext = struct {
                /// input
                address: usize,
                /// output
                module: Module,

                fn callback(info: *posix.dl_phdr_info, size: usize, context: *@This()) !void {
                    _ = size;
                    // The base address is too high
                    if (context.address < info.addr)
                        return;

                    const phdrs = info.phdr[0..info.phnum];
                    for (phdrs) |*phdr| {
                        if (phdr.p_type != elf.PT_LOAD) continue;

                        // Overflowing addition is used to handle the case of VSDOs having a p_vaddr = 0xffffffffff700000
                        const seg_start = info.addr +% phdr.p_vaddr;
                        const seg_end = seg_start + phdr.p_memsz;
                        if (context.address >= seg_start and context.address < seg_end) {
                            context.module = .{
                                .load_offset = info.addr,
                                // Android libc uses NULL instead of "" to mark the main program
                                .name = mem.sliceTo(info.name, 0) orelse "",
                                .build_id = null,
                                .gnu_eh_frame = null,
                            };
                            break;
                        }
                    } else return;

                    for (info.phdr[0..info.phnum]) |phdr| {
                        switch (phdr.p_type) {
                            elf.PT_NOTE => {
                                // Look for .note.gnu.build-id
                                const segment_ptr: [*]const u8 = @ptrFromInt(info.addr + phdr.p_vaddr);
                                var r: std.Io.Reader = .fixed(segment_ptr[0..phdr.p_memsz]);
                                const name_size = r.takeInt(u32, native_endian) catch continue;
                                const desc_size = r.takeInt(u32, native_endian) catch continue;
                                const note_type = r.takeInt(u32, native_endian) catch continue;
                                const name = r.take(name_size) catch continue;
                                if (note_type != elf.NT_GNU_BUILD_ID) continue;
                                if (!mem.eql(u8, name, "GNU\x00")) continue;
                                const desc = r.take(desc_size) catch continue;
                                context.module.build_id = desc;
                            },
                            elf.PT_GNU_EH_FRAME => {
                                const segment_ptr: [*]const u8 = @ptrFromInt(info.addr + phdr.p_vaddr);
                                context.module.gnu_eh_frame = segment_ptr[0..phdr.p_memsz];
                            },
                            else => {},
                        }
                    }

                    // Stop the iteration
                    return error.Found;
                }
            };
            var ctx: DlIterContext = .{
                .address = address,
                .module = undefined,
            };
            posix.dl_iterate_phdr(&ctx, error{Found}, DlIterContext.callback) catch |err| switch (err) {
                error.Found => return ctx.module,
            };
            return error.MissingDebugInfo;
        }
        fn loadLocationInfo(module: *const Module, gpa: Allocator, di: *Module.DebugInfo) !void {
            const filename: ?[]const u8 = if (module.name.len > 0) module.name else null;
            const mapped_mem = mapFileOrSelfExe(filename) catch |err| switch (err) {
                error.FileNotFound => return error.MissingDebugInfo,
                error.FileTooBig => return error.InvalidDebugInfo,
                else => |e| return e,
            };
            errdefer posix.munmap(mapped_mem);
            di.em = try .load(gpa, mapped_mem, module.build_id, null, null, null, filename);
        }
        fn loadUnwindInfo(module: *const Module, gpa: Allocator, di: *Module.DebugInfo) !void {
            const section_bytes = module.gnu_eh_frame orelse return error.MissingUnwindInfo; // MLUGG TODO: load from file
            const section_vaddr: u64 = @intFromPtr(section_bytes.ptr) - module.load_offset;
            const header: Dwarf.Unwind.EhFrameHeader = try .parse(section_vaddr, section_bytes, @sizeOf(usize), native_endian);
            di.unwind = .initEhFrameHdr(header, section_vaddr, @ptrFromInt(module.load_offset + header.eh_frame_vaddr));
            try di.unwind.prepareLookup(gpa, @sizeOf(usize), native_endian);
        }
        fn getSymbolAtAddress(module: *const Module, gpa: Allocator, di: *DebugInfo, address: usize) !std.debug.Symbol {
            return di.em.getSymbolAtAddress(gpa, native_endian, module.load_offset, address);
        }
        fn unwindFrame(module: *const Module, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) !usize {
            _ = gpa;
            return unwindFrameDwarf(&di.unwind, module.load_offset, context, null);
        }
    },
    .uefi, .windows => struct {
        base_address: usize,
        size: usize,
        name: []const u8,
        handle: windows.HMODULE,
        fn key(m: Module) usize {
            return m.base_address;
        }
        fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) !Module {
            if (lookupInCache(cache, address)) |m| return m;
            {
                // Check a new module hasn't been loaded
                cache.modules.clearRetainingCapacity();

                const handle = windows.kernel32.CreateToolhelp32Snapshot(windows.TH32CS_SNAPMODULE | windows.TH32CS_SNAPMODULE32, 0);
                if (handle == windows.INVALID_HANDLE_VALUE) {
                    return windows.unexpectedError(windows.GetLastError());
                }
                defer windows.CloseHandle(handle);

                var entry: windows.MODULEENTRY32 = undefined;
                entry.dwSize = @sizeOf(windows.MODULEENTRY32);
                if (windows.kernel32.Module32First(handle, &entry) != 0) {
                    try cache.modules.append(gpa, entry);
                    while (windows.kernel32.Module32Next(handle, &entry) != 0) {
                        try cache.modules.append(gpa, entry);
                    }
                }
            }
            if (lookupInCache(cache, address)) |m| return m;
            return error.MissingDebugInfo;
        }
        fn lookupInCache(cache: *const LookupCache, address: usize) ?Module {
            for (cache.modules.items) |*entry| {
                const base_address = @intFromPtr(entry.modBaseAddr);
                if (address >= base_address and address < base_address + entry.modBaseSize) {
                    return .{
                        .base_address = base_address,
                        .size = entry.modBaseSize,
                        .name = std.mem.sliceTo(&entry.szModule, 0),
                        .handle = entry.hModule,
                    };
                }
            }
            return null;
        }
        fn loadLocationInfo(module: *const Module, gpa: Allocator, di: *DebugInfo) !void {
            const mapped_ptr: [*]const u8 = @ptrFromInt(module.base_address);
            const mapped = mapped_ptr[0..module.size];
            var coff_obj = coff.Coff.init(mapped, true) catch return error.InvalidDebugInfo;
            // The string table is not mapped into memory by the loader, so if a section name is in the
            // string table then we have to map the full image file from disk. This can happen when
            // a binary is produced with -gdwarf, since the section names are longer than 8 bytes.
            if (coff_obj.strtabRequired()) {
                var name_buffer: [windows.PATH_MAX_WIDE + 4:0]u16 = undefined;
                name_buffer[0..4].* = .{ '\\', '?', '?', '\\' }; // openFileAbsoluteW requires the prefix to be present
                const process_handle = windows.GetCurrentProcess();
                const len = windows.kernel32.GetModuleFileNameExW(
                    process_handle,
                    module.handle,
                    name_buffer[4..],
                    windows.PATH_MAX_WIDE,
                );
                if (len == 0) return error.MissingDebugInfo;
                const coff_file = fs.openFileAbsoluteW(name_buffer[0 .. len + 4 :0], .{}) catch |err| switch (err) {
                    error.FileNotFound => return error.MissingDebugInfo,
                    else => |e| return e,
                };
                errdefer coff_file.close();
                var section_handle: windows.HANDLE = undefined;
                const create_section_rc = windows.ntdll.NtCreateSection(
                    &section_handle,
                    windows.STANDARD_RIGHTS_REQUIRED | windows.SECTION_QUERY | windows.SECTION_MAP_READ,
                    null,
                    null,
                    windows.PAGE_READONLY,
                    // The documentation states that if no AllocationAttribute is specified, then SEC_COMMIT is the default.
                    // In practice, this isn't the case and specifying 0 will result in INVALID_PARAMETER_6.
                    windows.SEC_COMMIT,
                    coff_file.handle,
                );
                if (create_section_rc != .SUCCESS) return error.MissingDebugInfo;
                errdefer windows.CloseHandle(section_handle);
                var coff_len: usize = 0;
                var section_view_ptr: [*]const u8 = undefined;
                const map_section_rc = windows.ntdll.NtMapViewOfSection(
                    section_handle,
                    process_handle,
                    @ptrCast(&section_view_ptr),
                    null,
                    0,
                    null,
                    &coff_len,
                    .ViewUnmap,
                    0,
                    windows.PAGE_READONLY,
                );
                if (map_section_rc != .SUCCESS) return error.MissingDebugInfo;
                errdefer assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @constCast(section_view_ptr)) == .SUCCESS);
                const section_view = section_view_ptr[0..coff_len];
                coff_obj = coff.Coff.init(section_view, false) catch return error.InvalidDebugInfo;
                di.mapped_file = .{
                    .file = coff_file,
                    .section_handle = section_handle,
                    .section_view = section_view,
                };
            }
            di.coff_image_base = coff_obj.getImageBase();

            if (coff_obj.getSectionByName(".debug_info")) |_| {
                di.dwarf = .{};

                inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |section, i| {
                    di.dwarf.?.sections[i] = if (coff_obj.getSectionByName("." ++ section.name)) |section_header| blk: {
                        break :blk .{
                            .data = try coff_obj.getSectionDataAlloc(section_header, gpa),
                            .virtual_address = section_header.virtual_address,
                            .owned = true,
                        };
                    } else null;
                }

                try di.dwarf.?.open(gpa, native_endian);
            }

            if (try coff_obj.getPdbPath()) |raw_path| pdb: {
                const path = blk: {
                    if (fs.path.isAbsolute(raw_path)) {
                        break :blk raw_path;
                    } else {
                        const self_dir = try fs.selfExeDirPathAlloc(gpa);
                        defer gpa.free(self_dir);
                        break :blk try fs.path.join(gpa, &.{ self_dir, raw_path });
                    }
                };
                defer if (path.ptr != raw_path.ptr) gpa.free(path);

                di.pdb = Pdb.init(gpa, path) catch |err| switch (err) {
                    error.FileNotFound, error.IsDir => break :pdb,
                    else => return err,
                };
                try di.pdb.?.parseInfoStream();
                try di.pdb.?.parseDbiStream();

                if (!mem.eql(u8, &coff_obj.guid, &di.pdb.?.guid) or coff_obj.age != di.pdb.?.age)
                    return error.InvalidDebugInfo;

                di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(gpa);
            }
        }
        const LookupCache = struct {
            modules: std.ArrayListUnmanaged(windows.MODULEENTRY32),
            const init: LookupCache = .{ .modules = .empty };
        };
        const DebugInfo = struct {
            coff_image_base: u64,
            mapped_file: ?struct {
                file: File,
                section_handle: windows.HANDLE,
                section_view: []const u8,
                fn deinit(mapped: @This()) void {
                    const process_handle = windows.GetCurrentProcess();
                    assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @constCast(mapped.section_view.ptr)) == .SUCCESS);
                    windows.CloseHandle(mapped.section_handle);
                    mapped.file.close();
                }
            },

            dwarf: ?Dwarf,

            pdb: ?Pdb,
            /// Populated iff `pdb != null`; otherwise `&.{}`.
            coff_section_headers: []coff.SectionHeader,

            const init: DebugInfo = .{
                .coff_image_base = undefined,
                .mapped_file = null,
                .dwarf = null,
                .pdb = null,
                .coff_section_headers = &.{},
            };

            fn deinit(di: *DebugInfo, gpa: Allocator) void {
                if (di.dwarf) |*dwarf| dwarf.deinit(gpa);
                if (di.pdb) |*pdb| pdb.deinit();
                gpa.free(di.coff_section_headers);
                if (di.mapped_file) |mapped| mapped.deinit();
            }

            fn getSymbolFromPdb(di: *DebugInfo, relocated_address: usize) !?std.debug.Symbol {
                var coff_section: *align(1) const coff.SectionHeader = undefined;
                const mod_index = for (di.pdb.?.sect_contribs) |sect_contrib| {
                    if (sect_contrib.section > di.coff_section_headers.len) continue;
                    // Remember that SectionContribEntry.Section is 1-based.
                    coff_section = &di.coff_section_headers[sect_contrib.section - 1];

                    const vaddr_start = coff_section.virtual_address + sect_contrib.offset;
                    const vaddr_end = vaddr_start + sect_contrib.size;
                    if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                        break sect_contrib.module_index;
                    }
                } else {
                    // we have no information to add to the address
                    return null;
                };

                const module = (try di.pdb.?.getModule(mod_index)) orelse
                    return error.InvalidDebugInfo;
                const obj_basename = fs.path.basename(module.obj_file_name);

                const symbol_name = di.pdb.?.getSymbolName(
                    module,
                    relocated_address - coff_section.virtual_address,
                ) orelse "???";
                const opt_line_info = try di.pdb.?.getLineNumberInfo(
                    module,
                    relocated_address - coff_section.virtual_address,
                );

                return .{
                    .name = symbol_name,
                    .compile_unit_name = obj_basename,
                    .source_location = opt_line_info,
                };
            }
        };

        fn getSymbolAtAddress(module: *const Module, gpa: Allocator, di: *DebugInfo, address: usize) !std.debug.Symbol {
            // Translate the runtime address into a virtual address into the module
            const vaddr = address - module.base_address;

            if (di.pdb != null) {
                if (try di.getSymbolFromPdb(vaddr)) |symbol| return symbol;
            }

            if (di.dwarf) |*dwarf| {
                const dwarf_address = vaddr + di.coff_image_base;
                return dwarf.getSymbol(gpa, native_endian, dwarf_address);
            }

            return error.MissingDebugInfo;
        }
    },
};

fn loadMachODebugInfo(gpa: Allocator, module: *const Module, di: *Module.DebugInfo) !void {
    const mapped_mem = mapFileOrSelfExe(module.name) catch |err| switch (err) {
        error.FileNotFound => return error.MissingDebugInfo,
        error.FileTooBig => return error.InvalidDebugInfo,
        else => |e| return e,
    };
    errdefer posix.munmap(mapped_mem);

    const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
    if (hdr.magic != macho.MH_MAGIC_64)
        return error.InvalidDebugInfo;

    const symtab: macho.symtab_command = symtab: {
        var it: macho.LoadCommandIterator = .{
            .ncmds = hdr.ncmds,
            .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
        };
        while (it.next()) |cmd| switch (cmd.cmd()) {
            .SYMTAB => break :symtab cmd.cast(macho.symtab_command) orelse return error.InvalidDebugInfo,
            else => {},
        };
        return error.MissingDebugInfo;
    };

    const syms_ptr: [*]align(1) const macho.nlist_64 = @ptrCast(mapped_mem[symtab.symoff..]);
    const syms = syms_ptr[0..symtab.nsyms];
    const strings = mapped_mem[symtab.stroff..][0 .. symtab.strsize - 1 :0];

    // MLUGG TODO: does it really make sense to initCapacity here? how many of syms are omitted?
    var symbols: std.ArrayList(MachoSymbol) = try .initCapacity(gpa, syms.len);
    defer symbols.deinit(gpa);

    var ofile: u32 = undefined;
    var last_sym: MachoSymbol = undefined;
    var state: enum {
        init,
        oso_open,
        oso_close,
        bnsym,
        fun_strx,
        fun_size,
        ensym,
    } = .init;

    for (syms) |*sym| {
        if (sym.n_type.bits.is_stab == 0) continue;

        // TODO handle globals N_GSYM, and statics N_STSYM
        switch (sym.n_type.stab) {
            .oso => switch (state) {
                .init, .oso_close => {
                    state = .oso_open;
                    ofile = sym.n_strx;
                },
                else => return error.InvalidDebugInfo,
            },
            .bnsym => switch (state) {
                .oso_open, .ensym => {
                    state = .bnsym;
                    last_sym = .{
                        .strx = 0,
                        .addr = sym.n_value,
                        .size = 0,
                        .ofile = ofile,
                    };
                },
                else => return error.InvalidDebugInfo,
            },
            .fun => switch (state) {
                .bnsym => {
                    state = .fun_strx;
                    last_sym.strx = sym.n_strx;
                },
                .fun_strx => {
                    state = .fun_size;
                    last_sym.size = @intCast(sym.n_value);
                },
                else => return error.InvalidDebugInfo,
            },
            .ensym => switch (state) {
                .fun_size => {
                    state = .ensym;
                    symbols.appendAssumeCapacity(last_sym);
                },
                else => return error.InvalidDebugInfo,
            },
            .so => switch (state) {
                .init, .oso_close => {},
                .oso_open, .ensym => {
                    state = .oso_close;
                },
                else => return error.InvalidDebugInfo,
            },
            else => {},
        }
    }

    switch (state) {
        .init => return error.MissingDebugInfo,
        .oso_close => {},
        else => return error.InvalidDebugInfo,
    }

    const symbols_slice = try symbols.toOwnedSlice(gpa);
    errdefer gpa.free(symbols_slice);

    // Even though lld emits symbols in ascending order, this debug code
    // should work for programs linked in any valid way.
    // This sort is so that we can binary search later.
    mem.sort(MachoSymbol, symbols_slice, {}, MachoSymbol.addressLessThan);

    di.* = .{
        .unwind_info = module.unwind_info,
        .eh_frame = module.eh_frame,
        .mapped_memory = mapped_mem,
        .symbols = symbols_slice,
        .strings = strings,
        .ofiles = .empty,
    };
}

const MachoSymbol = struct {
    strx: u32,
    addr: u64,
    size: u32,
    ofile: u32,
    fn addressLessThan(context: void, lhs: MachoSymbol, rhs: MachoSymbol) bool {
        _ = context;
        return lhs.addr < rhs.addr;
    }
    /// Assumes that `symbols` is sorted in order of ascending `addr`.
    fn find(symbols: []const MachoSymbol, address: usize) ?*const MachoSymbol {
        if (symbols.len == 0) return null; // no potential match
        if (address < symbols[0].addr) return null; // address is before the lowest-address symbol
        var left: usize = 0;
        var len: usize = symbols.len;
        while (len > 1) {
            const mid = left + len / 2;
            if (address < symbols[mid].addr) {
                len /= 2;
            } else {
                left = mid;
                len -= len / 2;
            }
        }
        return &symbols[left];
    }

    test find {
        const symbols: []const MachoSymbol = &.{
            .{ .addr = 100, .strx = undefined, .size = undefined, .ofile = undefined },
            .{ .addr = 200, .strx = undefined, .size = undefined, .ofile = undefined },
            .{ .addr = 300, .strx = undefined, .size = undefined, .ofile = undefined },
        };

        try testing.expectEqual(null, find(symbols, 0));
        try testing.expectEqual(null, find(symbols, 99));
        try testing.expectEqual(&symbols[0], find(symbols, 100).?);
        try testing.expectEqual(&symbols[0], find(symbols, 150).?);
        try testing.expectEqual(&symbols[0], find(symbols, 199).?);

        try testing.expectEqual(&symbols[1], find(symbols, 200).?);
        try testing.expectEqual(&symbols[1], find(symbols, 250).?);
        try testing.expectEqual(&symbols[1], find(symbols, 299).?);

        try testing.expectEqual(&symbols[2], find(symbols, 300).?);
        try testing.expectEqual(&symbols[2], find(symbols, 301).?);
        try testing.expectEqual(&symbols[2], find(symbols, 5000).?);
    }
};
test {
    _ = MachoSymbol;
}

pub const UnwindContext = struct {
    gpa: Allocator,
    cfa: ?usize,
    pc: usize,
    thread_context: *std.debug.ThreadContext,
    reg_context: Dwarf.abi.RegisterContext,
    vm: Dwarf.Unwind.VirtualMachine,
    stack_machine: Dwarf.expression.StackMachine(.{ .call_frame_context = true }),

    pub fn init(gpa: Allocator, thread_context: *std.debug.ThreadContext) !UnwindContext {
        comptime assert(supports_unwinding);

        const pc = stripInstructionPtrAuthCode(
            (try regValueNative(thread_context, ip_reg_num, null)).*,
        );

        const context_copy = try gpa.create(std.debug.ThreadContext);
        std.debug.copyContext(thread_context, context_copy);

        return .{
            .gpa = gpa,
            .cfa = null,
            .pc = pc,
            .thread_context = context_copy,
            .reg_context = undefined,
            .vm = .{},
            .stack_machine = .{},
        };
    }

    pub fn deinit(self: *UnwindContext) void {
        self.vm.deinit(self.gpa);
        self.stack_machine.deinit(self.gpa);
        self.gpa.destroy(self.thread_context);
        self.* = undefined;
    }

    pub fn getFp(self: *const UnwindContext) !usize {
        return (try regValueNative(self.thread_context, fpRegNum(self.reg_context), self.reg_context)).*;
    }

    /// Resolves the register rule and places the result into `out` (see regBytes)
    pub fn resolveRegisterRule(
        context: *UnwindContext,
        col: Dwarf.Unwind.VirtualMachine.Column,
        expression_context: std.debug.Dwarf.expression.Context,
        out: []u8,
    ) !void {
        switch (col.rule) {
            .default => {
                const register = col.register orelse return error.InvalidRegister;
                // The default type is usually undefined, but can be overriden by ABI authors.
                // See the doc comment on `Dwarf.Unwind.VirtualMachine.RegisterRule.default`.
                if (builtin.cpu.arch.isAARCH64() and register >= 19 and register <= 18) {
                    // Callee-saved registers are initialized as if they had the .same_value rule
                    const src = try regBytes(context.thread_context, register, context.reg_context);
                    if (src.len != out.len) return error.RegisterSizeMismatch;
                    @memcpy(out, src);
                    return;
                }
                @memset(out, undefined);
            },
            .undefined => {
                @memset(out, undefined);
            },
            .same_value => {
                // TODO: This copy could be eliminated if callers always copy the state then call this function to update it
                const register = col.register orelse return error.InvalidRegister;
                const src = try regBytes(context.thread_context, register, context.reg_context);
                if (src.len != out.len) return error.RegisterSizeMismatch;
                @memcpy(out, src);
            },
            .offset => |offset| {
                if (context.cfa) |cfa| {
                    const addr = try applyOffset(cfa, offset);
                    const ptr: *const usize = @ptrFromInt(addr);
                    mem.writeInt(usize, out[0..@sizeOf(usize)], ptr.*, native_endian);
                } else return error.InvalidCFA;
            },
            .val_offset => |offset| {
                if (context.cfa) |cfa| {
                    mem.writeInt(usize, out[0..@sizeOf(usize)], try applyOffset(cfa, offset), native_endian);
                } else return error.InvalidCFA;
            },
            .register => |register| {
                const src = try regBytes(context.thread_context, register, context.reg_context);
                if (src.len != out.len) return error.RegisterSizeMismatch;
                @memcpy(out, try regBytes(context.thread_context, register, context.reg_context));
            },
            .expression => |expression| {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(expression, context.gpa, expression_context, context.cfa.?);
                const addr = if (value) |v| blk: {
                    if (v != .generic) return error.InvalidExpressionValue;
                    break :blk v.generic;
                } else return error.NoExpressionValue;

                const ptr: *usize = @ptrFromInt(addr);
                mem.writeInt(usize, out[0..@sizeOf(usize)], ptr.*, native_endian);
            },
            .val_expression => |expression| {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(expression, context.gpa, expression_context, context.cfa.?);
                if (value) |v| {
                    if (v != .generic) return error.InvalidExpressionValue;
                    mem.writeInt(usize, out[0..@sizeOf(usize)], v.generic, native_endian);
                } else return error.NoExpressionValue;
            },
            .architectural => return error.UnimplementedRegisterRule,
        }
    }
};

/// Some platforms use pointer authentication - the upper bits of instruction pointers contain a signature.
/// This function clears these signature bits to make the pointer usable.
pub inline fn stripInstructionPtrAuthCode(ptr: usize) usize {
    if (native_arch.isAARCH64()) {
        // `hint 0x07` maps to `xpaclri` (or `nop` if the hardware doesn't support it)
        // The save / restore is because `xpaclri` operates on x30 (LR)
        return asm (
            \\mov x16, x30
            \\mov x30, x15
            \\hint 0x07
            \\mov x15, x30
            \\mov x30, x16
            : [ret] "={x15}" (-> usize),
            : [ptr] "{x15}" (ptr),
            : .{ .x16 = true });
    }

    return ptr;
}

/// Unwind a stack frame using DWARF unwinding info, updating the register context.
///
/// If `.eh_frame_hdr` is available and complete, it will be used to binary search for the FDE.
/// Otherwise, a linear scan of `.eh_frame` and `.debug_frame` is done to find the FDE. The latter
/// may require lazily loading the data in those sections.
///
/// `explicit_fde_offset` is for cases where the FDE offset is known, such as when __unwind_info
/// defers unwinding to DWARF. This is an offset into the `.eh_frame` section.
fn unwindFrameDwarf(
    unwind: *const Dwarf.Unwind,
    load_offset: usize,
    context: *UnwindContext,
    explicit_fde_offset: ?usize,
) !usize {
    if (!supports_unwinding) return error.UnsupportedCpuArchitecture;
    if (context.pc == 0) return 0;

    const pc_vaddr = context.pc - load_offset;

    const fde_offset = explicit_fde_offset orelse try unwind.lookupPc(
        pc_vaddr,
        @sizeOf(usize),
        native_endian,
    ) orelse return error.MissingDebugInfo;
    const format, const cie, const fde = try unwind.getFde(fde_offset, @sizeOf(usize), native_endian);

    // Check if this FDE *actually* includes the address.
    if (pc_vaddr < fde.pc_begin or pc_vaddr >= fde.pc_begin + fde.pc_range) return error.MissingDebugInfo;

    // Do not set `compile_unit` because the spec states that CFIs
    // may not reference other debug sections anyway.
    var expression_context: Dwarf.expression.Context = .{
        .format = format,
        .thread_context = context.thread_context,
        .reg_context = context.reg_context,
        .cfa = context.cfa,
    };

    context.vm.reset();
    context.reg_context.eh_frame = cie.version != 4;
    context.reg_context.is_macho = native_os.isDarwin();

    const row = try context.vm.runTo(context.gpa, context.pc - load_offset, cie, fde, @sizeOf(usize), native_endian);
    context.cfa = switch (row.cfa.rule) {
        .val_offset => |offset| blk: {
            const register = row.cfa.register orelse return error.InvalidCFARule;
            const value = mem.readInt(usize, (try regBytes(context.thread_context, register, context.reg_context))[0..@sizeOf(usize)], native_endian);
            break :blk try applyOffset(value, offset);
        },
        .expression => |expr| blk: {
            context.stack_machine.reset();
            const value = try context.stack_machine.run(
                expr,
                context.gpa,
                expression_context,
                context.cfa,
            );

            if (value) |v| {
                if (v != .generic) return error.InvalidExpressionValue;
                break :blk v.generic;
            } else return error.NoExpressionValue;
        },
        else => return error.InvalidCFARule,
    };

    expression_context.cfa = context.cfa;

    // Buffering the modifications is done because copying the thread context is not portable,
    // some implementations (ie. darwin) use internal pointers to the mcontext.
    var arena: std.heap.ArenaAllocator = .init(context.gpa);
    defer arena.deinit();
    const update_arena = arena.allocator();

    const RegisterUpdate = struct {
        // Backed by thread_context
        dest: []u8,
        // Backed by arena
        src: []const u8,
        prev: ?*@This(),
    };

    var update_tail: ?*RegisterUpdate = null;
    var has_return_address = true;
    for (context.vm.rowColumns(row)) |column| {
        if (column.register) |register| {
            if (register == cie.return_address_register) {
                has_return_address = column.rule != .undefined;
            }

            const dest = try regBytes(context.thread_context, register, context.reg_context);
            const src = try update_arena.alloc(u8, dest.len);
            try context.resolveRegisterRule(column, expression_context, src);

            const new_update = try update_arena.create(RegisterUpdate);
            new_update.* = .{
                .dest = dest,
                .src = src,
                .prev = update_tail,
            };
            update_tail = new_update;
        }
    }

    // On all implemented architectures, the CFA is defined as being the previous frame's SP
    (try regValueNative(context.thread_context, spRegNum(context.reg_context), context.reg_context)).* = context.cfa.?;

    while (update_tail) |tail| {
        @memcpy(tail.dest, tail.src);
        update_tail = tail.prev;
    }

    if (has_return_address) {
        context.pc = stripInstructionPtrAuthCode(mem.readInt(usize, (try regBytes(
            context.thread_context,
            cie.return_address_register,
            context.reg_context,
        ))[0..@sizeOf(usize)], native_endian));
    } else {
        context.pc = 0;
    }

    (try regValueNative(context.thread_context, ip_reg_num, context.reg_context)).* = context.pc;

    // The call instruction will have pushed the address of the instruction that follows the call as the return address.
    // This next instruction may be past the end of the function if the caller was `noreturn` (ie. the last instruction in
    // the function was the call). If we were to look up an FDE entry using the return address directly, it could end up
    // either not finding an FDE at all, or using the next FDE in the program, producing incorrect results. To prevent this,
    // we subtract one so that the next lookup is guaranteed to land inside the
    //
    // The exception to this rule is signal frames, where we return execution would be returned to the instruction
    // that triggered the handler.
    const return_address = context.pc;
    if (context.pc > 0 and !cie.is_signal_frame) context.pc -= 1;

    return return_address;
}

fn fpRegNum(reg_context: Dwarf.abi.RegisterContext) u8 {
    return Dwarf.abi.fpRegNum(native_arch, reg_context);
}

fn spRegNum(reg_context: Dwarf.abi.RegisterContext) u8 {
    return Dwarf.abi.spRegNum(native_arch, reg_context);
}

const ip_reg_num = Dwarf.abi.ipRegNum(native_arch).?;

/// Tells whether unwinding for the host is implemented.
pub const supports_unwinding = supportsUnwinding(&builtin.target);

comptime {
    if (supports_unwinding) assert(Dwarf.abi.supportsUnwinding(&builtin.target));
}

/// Tells whether unwinding for this target is *implemented* here in the Zig
/// standard library.
///
/// See also `Dwarf.abi.supportsUnwinding` which tells whether Dwarf supports
/// unwinding on that target *in theory*.
pub fn supportsUnwinding(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        .x86 => switch (target.os.tag) {
            .linux, .netbsd, .solaris, .illumos => true,
            else => false,
        },
        .x86_64 => switch (target.os.tag) {
            .linux, .netbsd, .freebsd, .openbsd, .macos, .ios, .solaris, .illumos => true,
            else => false,
        },
        .arm, .armeb, .thumb, .thumbeb => switch (target.os.tag) {
            .linux => true,
            else => false,
        },
        .aarch64, .aarch64_be => switch (target.os.tag) {
            .linux, .netbsd, .freebsd, .macos, .ios => true,
            else => false,
        },
        // Unwinding is possible on other targets but this implementation does
        // not support them...yet!
        else => false,
    };
}

/// Since register rules are applied (usually) during a panic,
/// checked addition / subtraction is used so that we can return
/// an error and fall back to FP-based unwinding.
fn applyOffset(base: usize, offset: i64) !usize {
    return if (offset >= 0)
        try std.math.add(usize, base, @as(usize, @intCast(offset)))
    else
        try std.math.sub(usize, base, @as(usize, @intCast(-offset)));
}

/// Uses `mmap` to map the file at `opt_path` (or, if `null`, the self executable image) into memory.
fn mapFileOrSelfExe(opt_path: ?[]const u8) ![]align(std.heap.page_size_min) const u8 {
    const file = if (opt_path) |path|
        try fs.cwd().openFile(path, .{})
    else
        try fs.openSelfExe(.{});
    defer file.close();

    const file_len = math.cast(usize, try file.getEndPos()) orelse return error.FileTooBig;

    return posix.mmap(
        null,
        file_len,
        posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );
}

/// Unwind a frame using MachO compact unwind info (from __unwind_info).
/// If the compact encoding can't encode a way to unwind a frame, it will
/// defer unwinding to DWARF, in which case `.eh_frame` will be used if available.
fn unwindFrameMachO(
    text_base: usize,
    load_offset: usize,
    context: *UnwindContext,
    unwind_info: []const u8,
    opt_eh_frame: ?[]const u8,
) !usize {
    if (unwind_info.len < @sizeOf(macho.unwind_info_section_header)) return error.InvalidUnwindInfo;
    const header: *align(1) const macho.unwind_info_section_header = @ptrCast(unwind_info);

    const index_byte_count = header.indexCount * @sizeOf(macho.unwind_info_section_header_index_entry);
    if (unwind_info.len < header.indexSectionOffset + index_byte_count) return error.InvalidUnwindInfo;
    const indices: []align(1) const macho.unwind_info_section_header_index_entry = @ptrCast(unwind_info[header.indexSectionOffset..][0..index_byte_count]);
    if (indices.len == 0) return error.MissingUnwindInfo;

    // offset of the PC into the `__TEXT` segment
    const pc_text_offset = context.pc - text_base;

    const start_offset: u32, const first_level_offset: u32 = index: {
        var left: usize = 0;
        var len: usize = indices.len;
        while (len > 1) {
            const mid = left + len / 2;
            if (pc_text_offset < indices[mid].functionOffset) {
                len /= 2;
            } else {
                left = mid;
                len -= len / 2;
            }
        }
        break :index .{ indices[left].secondLevelPagesSectionOffset, indices[left].functionOffset };
    };
    // An offset of 0 is a sentinel indicating a range does not have unwind info.
    if (start_offset == 0) return error.MissingUnwindInfo;

    const common_encodings_byte_count = header.commonEncodingsArrayCount * @sizeOf(macho.compact_unwind_encoding_t);
    if (unwind_info.len < header.commonEncodingsArraySectionOffset + common_encodings_byte_count) return error.InvalidUnwindInfo;
    const common_encodings: []align(1) const macho.compact_unwind_encoding_t = @ptrCast(
        unwind_info[header.commonEncodingsArraySectionOffset..][0..common_encodings_byte_count],
    );

    if (unwind_info.len < start_offset + @sizeOf(macho.UNWIND_SECOND_LEVEL)) return error.InvalidUnwindInfo;
    const kind: *align(1) const macho.UNWIND_SECOND_LEVEL = @ptrCast(unwind_info[start_offset..]);

    const entry: struct {
        function_offset: usize,
        raw_encoding: u32,
    } = switch (kind.*) {
        .REGULAR => entry: {
            if (unwind_info.len < start_offset + @sizeOf(macho.unwind_info_regular_second_level_page_header)) return error.InvalidUnwindInfo;
            const page_header: *align(1) const macho.unwind_info_regular_second_level_page_header = @ptrCast(unwind_info[start_offset..]);

            const entries_byte_count = page_header.entryCount * @sizeOf(macho.unwind_info_regular_second_level_entry);
            if (unwind_info.len < start_offset + entries_byte_count) return error.InvalidUnwindInfo;
            const entries: []align(1) const macho.unwind_info_regular_second_level_entry = @ptrCast(
                unwind_info[start_offset + page_header.entryPageOffset ..][0..entries_byte_count],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                if (pc_text_offset < entries[mid].functionOffset) {
                    len /= 2;
                } else {
                    left = mid;
                    len -= len / 2;
                }
            }
            break :entry .{
                .function_offset = entries[left].functionOffset,
                .raw_encoding = entries[left].encoding,
            };
        },
        .COMPRESSED => entry: {
            if (unwind_info.len < start_offset + @sizeOf(macho.unwind_info_compressed_second_level_page_header)) return error.InvalidUnwindInfo;
            const page_header: *align(1) const macho.unwind_info_compressed_second_level_page_header = @ptrCast(unwind_info[start_offset..]);

            const entries_byte_count = page_header.entryCount * @sizeOf(macho.UnwindInfoCompressedEntry);
            if (unwind_info.len < start_offset + entries_byte_count) return error.InvalidUnwindInfo;
            const entries: []align(1) const macho.UnwindInfoCompressedEntry = @ptrCast(
                unwind_info[start_offset + page_header.entryPageOffset ..][0..entries_byte_count],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                if (pc_text_offset < first_level_offset + entries[mid].funcOffset) {
                    len /= 2;
                } else {
                    left = mid;
                    len -= len / 2;
                }
            }
            const entry = entries[left];

            const function_offset = first_level_offset + entry.funcOffset;
            if (entry.encodingIndex < common_encodings.len) {
                break :entry .{
                    .function_offset = function_offset,
                    .raw_encoding = common_encodings[entry.encodingIndex],
                };
            }

            const local_index = entry.encodingIndex - common_encodings.len;
            const local_encodings_byte_count = page_header.encodingsCount * @sizeOf(macho.compact_unwind_encoding_t);
            if (unwind_info.len < start_offset + page_header.encodingsPageOffset + local_encodings_byte_count) return error.InvalidUnwindInfo;
            const local_encodings: []align(1) const macho.compact_unwind_encoding_t = @ptrCast(
                unwind_info[start_offset + page_header.encodingsPageOffset ..][0..local_encodings_byte_count],
            );
            if (local_index >= local_encodings.len) return error.InvalidUnwindInfo;
            break :entry .{
                .function_offset = function_offset,
                .raw_encoding = local_encodings[local_index],
            };
        },
        else => return error.InvalidUnwindInfo,
    };

    if (entry.raw_encoding == 0) return error.NoUnwindInfo;
    const reg_context: Dwarf.abi.RegisterContext = .{ .eh_frame = false, .is_macho = true };

    const encoding: macho.CompactUnwindEncoding = @bitCast(entry.raw_encoding);
    const new_ip = switch (builtin.cpu.arch) {
        .x86_64 => switch (encoding.mode.x86_64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .RBP_FRAME => ip: {
                const frame = encoding.value.x86_64.frame;

                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 2 * @sizeOf(usize);

                const ip_ptr = fp + @sizeOf(usize);
                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                const regs: [5]u3 = .{
                    frame.reg0,
                    frame.reg1,
                    frame.reg2,
                    frame.reg3,
                    frame.reg4,
                };
                for (regs, 0..) |reg, i| {
                    if (reg == 0) continue;
                    const addr = fp - frame.frame_offset * @sizeOf(usize) + i * @sizeOf(usize);
                    const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(reg);
                    (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(addr)).*;
                }

                break :ip new_ip;
            },
            .STACK_IMMD,
            .STACK_IND,
            => ip: {
                const frameless = encoding.value.x86_64.frameless;

                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const stack_size: usize = stack_size: {
                    if (encoding.mode.x86_64 == .STACK_IMMD) {
                        break :stack_size @as(usize, frameless.stack.direct.stack_size) * @sizeOf(usize);
                    }
                    // In .STACK_IND, the stack size is inferred from the subq instruction at the beginning of the function.
                    const sub_offset_addr =
                        text_base +
                        entry.function_offset +
                        frameless.stack.indirect.sub_offset;
                    // `sub_offset_addr` points to the offset of the literal within the instruction
                    const sub_operand = @as(*align(1) const u32, @ptrFromInt(sub_offset_addr)).*;
                    break :stack_size sub_operand + @sizeOf(usize) * @as(usize, frameless.stack.indirect.stack_adjust);
                };

                // Decode the Lehmer-coded sequence of registers.
                // For a description of the encoding see lib/libc/include/any-macos.13-any/mach-o/compact_unwind_encoding.h

                // Decode the variable-based permutation number into its digits. Each digit represents
                // an index into the list of register numbers that weren't yet used in the sequence at
                // the time the digit was added.
                const reg_count = frameless.stack_reg_count;
                const ip_ptr = ip_ptr: {
                    var digits: [6]u3 = undefined;
                    var accumulator: usize = frameless.stack_reg_permutation;
                    var base: usize = 2;
                    for (0..reg_count) |i| {
                        const div = accumulator / base;
                        digits[digits.len - 1 - i] = @intCast(accumulator - base * div);
                        accumulator = div;
                        base += 1;
                    }

                    var registers: [6]u3 = undefined;
                    var used_indices: [6]bool = @splat(false);
                    for (digits[digits.len - reg_count ..], 0..) |target_unused_index, i| {
                        var unused_count: u8 = 0;
                        const unused_index = for (used_indices, 0..) |used, index| {
                            if (!used) {
                                if (target_unused_index == unused_count) break index;
                                unused_count += 1;
                            }
                        } else unreachable;
                        registers[i] = @intCast(unused_index + 1);
                        used_indices[unused_index] = true;
                    }

                    var reg_addr = sp + stack_size - @sizeOf(usize) * @as(usize, reg_count + 1);
                    for (0..reg_count) |i| {
                        const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(registers[i]);
                        (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }

                    break :ip_ptr reg_addr;
                };

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_sp = ip_ptr + @sizeOf(usize);

                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :ip new_ip;
            },
            .DWARF => {
                const eh_frame = opt_eh_frame orelse return error.MissingEhFrame;
                const eh_frame_vaddr = @intFromPtr(eh_frame.ptr) - load_offset;
                return unwindFrameDwarf(
                    &.initSection(.eh_frame, eh_frame_vaddr, eh_frame),
                    load_offset,
                    context,
                    @intCast(encoding.value.x86_64.dwarf),
                );
            },
        },
        .aarch64, .aarch64_be => switch (encoding.mode.arm64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .FRAMELESS => ip: {
                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const new_sp = sp + encoding.value.arm64.frameless.stack_size * 16;
                const new_ip = (try regValueNative(context.thread_context, 30, reg_context)).*;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                break :ip new_ip;
            },
            .DWARF => {
                const eh_frame = opt_eh_frame orelse return error.MissingEhFrame;
                const eh_frame_vaddr = @intFromPtr(eh_frame.ptr) - load_offset;
                return unwindFrameDwarf(
                    &.initSection(.eh_frame, eh_frame_vaddr, eh_frame),
                    load_offset,
                    context,
                    @intCast(encoding.value.x86_64.dwarf),
                );
            },
            .FRAME => ip: {
                const frame = encoding.value.arm64.frame;

                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const ip_ptr = fp + @sizeOf(usize);

                var reg_addr = fp - @sizeOf(usize);
                inline for (@typeInfo(@TypeOf(frame.x_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(frame.x_reg_pairs, field.name) != 0) {
                        (try regValueNative(context.thread_context, 19 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                        (try regValueNative(context.thread_context, 20 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }
                }

                inline for (@typeInfo(@TypeOf(frame.d_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(frame.d_reg_pairs, field.name) != 0) {
                        // Only the lower half of the 128-bit V registers are restored during unwinding
                        {
                            const dest: *align(1) usize = @ptrCast(try regBytes(context.thread_context, 64 + 8 + i, context.reg_context));
                            dest.* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        }
                        reg_addr += @sizeOf(usize);
                        {
                            const dest: *align(1) usize = @ptrCast(try regBytes(context.thread_context, 64 + 9 + i, context.reg_context));
                            dest.* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        }
                        reg_addr += @sizeOf(usize);
                    }
                }

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :ip new_ip;
            },
        },
        else => comptime unreachable, // unimplemented
    };

    context.pc = stripInstructionPtrAuthCode(new_ip);
    if (context.pc > 0) context.pc -= 1;
    return new_ip;
}
