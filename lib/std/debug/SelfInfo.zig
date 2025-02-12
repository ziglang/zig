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
const pdb = std.pdb;
const assert = std.debug.assert;
const posix = std.posix;
const elf = std.elf;
const Dwarf = std.debug.Dwarf;
const Pdb = std.debug.Pdb;
const File = std.fs.File;
const math = std.math;
const testing = std.testing;
const StackIterator = std.debug.StackIterator;
const regBytes = Dwarf.abi.regBytes;
const regValueNative = Dwarf.abi.regValueNative;

const SelfInfo = @This();

const root = @import("root");

allocator: Allocator,
address_map: std.AutoHashMap(usize, *Module),
modules: if (native_os == .windows) std.ArrayListUnmanaged(WindowsModule) else void,

pub const OpenError = error{
    MissingDebugInfo,
    UnsupportedOperatingSystem,
} || @typeInfo(@typeInfo(@TypeOf(SelfInfo.init)).@"fn".return_type.?).error_union.error_set;

pub fn open(allocator: Allocator) OpenError!SelfInfo {
    nosuspend {
        if (builtin.strip_debug_info)
            return error.MissingDebugInfo;
        switch (native_os) {
            .linux,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .macos,
            .solaris,
            .illumos,
            .windows,
            => return try SelfInfo.init(allocator),
            else => return error.UnsupportedOperatingSystem,
        }
    }
}

pub fn init(allocator: Allocator) !SelfInfo {
    var debug_info: SelfInfo = .{
        .allocator = allocator,
        .address_map = std.AutoHashMap(usize, *Module).init(allocator),
        .modules = if (native_os == .windows) .{} else {},
    };

    if (native_os == .windows) {
        errdefer debug_info.modules.deinit(allocator);

        const handle = windows.kernel32.CreateToolhelp32Snapshot(windows.TH32CS_SNAPMODULE | windows.TH32CS_SNAPMODULE32, 0);
        if (handle == windows.INVALID_HANDLE_VALUE) {
            switch (windows.GetLastError()) {
                else => |err| return windows.unexpectedError(err),
            }
        }
        defer windows.CloseHandle(handle);

        var module_entry: windows.MODULEENTRY32 = undefined;
        module_entry.dwSize = @sizeOf(windows.MODULEENTRY32);
        if (windows.kernel32.Module32First(handle, &module_entry) == 0) {
            return error.MissingDebugInfo;
        }

        var module_valid = true;
        while (module_valid) {
            const module_info = try debug_info.modules.addOne(allocator);
            const name = allocator.dupe(u8, mem.sliceTo(&module_entry.szModule, 0)) catch &.{};
            errdefer allocator.free(name);

            module_info.* = .{
                .base_address = @intFromPtr(module_entry.modBaseAddr),
                .size = module_entry.modBaseSize,
                .name = name,
                .handle = module_entry.hModule,
            };

            module_valid = windows.kernel32.Module32Next(handle, &module_entry) == 1;
        }
    }

    return debug_info;
}

pub fn deinit(self: *SelfInfo) void {
    var it = self.address_map.iterator();
    while (it.next()) |entry| {
        const mdi = entry.value_ptr.*;
        mdi.deinit(self.allocator);
        self.allocator.destroy(mdi);
    }
    self.address_map.deinit();
    if (native_os == .windows) {
        for (self.modules.items) |module| {
            self.allocator.free(module.name);
            if (module.mapped_file) |mapped_file| mapped_file.deinit();
        }
        self.modules.deinit(self.allocator);
    }
}

pub fn getModuleForAddress(self: *SelfInfo, address: usize) !*Module {
    if (builtin.target.isDarwin()) {
        return self.lookupModuleDyld(address);
    } else if (native_os == .windows) {
        return self.lookupModuleWin32(address);
    } else if (native_os == .haiku) {
        return self.lookupModuleHaiku(address);
    } else if (builtin.target.isWasm()) {
        return self.lookupModuleWasm(address);
    } else {
        return self.lookupModuleDl(address);
    }
}

// Returns the module name for a given address.
// This can be called when getModuleForAddress fails, so implementations should provide
// a path that doesn't rely on any side-effects of a prior successful module lookup.
pub fn getModuleNameForAddress(self: *SelfInfo, address: usize) ?[]const u8 {
    if (builtin.target.isDarwin()) {
        return self.lookupModuleNameDyld(address);
    } else if (native_os == .windows) {
        return self.lookupModuleNameWin32(address);
    } else if (native_os == .haiku) {
        return null;
    } else if (builtin.target.isWasm()) {
        return null;
    } else {
        return self.lookupModuleNameDl(address);
    }
}

fn lookupModuleDyld(self: *SelfInfo, address: usize) !*Module {
    const image_count = std.c._dyld_image_count();

    var i: u32 = 0;
    while (i < image_count) : (i += 1) {
        const header = std.c._dyld_get_image_header(i) orelse continue;
        const base_address = @intFromPtr(header);
        if (address < base_address) continue;
        const vmaddr_slide = std.c._dyld_get_image_vmaddr_slide(i);

        var it = macho.LoadCommandIterator{
            .ncmds = header.ncmds,
            .buffer = @alignCast(@as(
                [*]u8,
                @ptrFromInt(@intFromPtr(header) + @sizeOf(macho.mach_header_64)),
            )[0..header.sizeofcmds]),
        };

        var unwind_info: ?[]const u8 = null;
        var eh_frame: ?[]const u8 = null;
        while (it.next()) |cmd| switch (cmd.cmd()) {
            .SEGMENT_64 => {
                const segment_cmd = cmd.cast(macho.segment_command_64).?;
                if (!mem.eql(u8, "__TEXT", segment_cmd.segName())) continue;

                const seg_start = segment_cmd.vmaddr + vmaddr_slide;
                const seg_end = seg_start + segment_cmd.vmsize;
                if (address >= seg_start and address < seg_end) {
                    if (self.address_map.get(base_address)) |obj_di| {
                        return obj_di;
                    }

                    for (cmd.getSections()) |sect| {
                        const sect_addr: usize = @intCast(sect.addr);
                        const sect_size: usize = @intCast(sect.size);
                        if (mem.eql(u8, "__unwind_info", sect.sectName())) {
                            unwind_info = @as([*]const u8, @ptrFromInt(sect_addr + vmaddr_slide))[0..sect_size];
                        } else if (mem.eql(u8, "__eh_frame", sect.sectName())) {
                            eh_frame = @as([*]const u8, @ptrFromInt(sect_addr + vmaddr_slide))[0..sect_size];
                        }
                    }

                    const obj_di = try self.allocator.create(Module);
                    errdefer self.allocator.destroy(obj_di);

                    const macho_path = mem.sliceTo(std.c._dyld_get_image_name(i), 0);
                    const macho_file = fs.cwd().openFile(macho_path, .{}) catch |err| switch (err) {
                        error.FileNotFound => return error.MissingDebugInfo,
                        else => return err,
                    };
                    obj_di.* = try readMachODebugInfo(self.allocator, macho_file);
                    obj_di.base_address = base_address;
                    obj_di.vmaddr_slide = vmaddr_slide;
                    obj_di.unwind_info = unwind_info;
                    obj_di.eh_frame = eh_frame;

                    try self.address_map.putNoClobber(base_address, obj_di);

                    return obj_di;
                }
            },
            else => {},
        };
    }

    return error.MissingDebugInfo;
}

fn lookupModuleNameDyld(self: *SelfInfo, address: usize) ?[]const u8 {
    _ = self;
    const image_count = std.c._dyld_image_count();

    var i: u32 = 0;
    while (i < image_count) : (i += 1) {
        const header = std.c._dyld_get_image_header(i) orelse continue;
        const base_address = @intFromPtr(header);
        if (address < base_address) continue;
        const vmaddr_slide = std.c._dyld_get_image_vmaddr_slide(i);

        var it = macho.LoadCommandIterator{
            .ncmds = header.ncmds,
            .buffer = @alignCast(@as(
                [*]u8,
                @ptrFromInt(@intFromPtr(header) + @sizeOf(macho.mach_header_64)),
            )[0..header.sizeofcmds]),
        };

        while (it.next()) |cmd| switch (cmd.cmd()) {
            .SEGMENT_64 => {
                const segment_cmd = cmd.cast(macho.segment_command_64).?;
                if (!mem.eql(u8, "__TEXT", segment_cmd.segName())) continue;

                const original_address = address - vmaddr_slide;
                const seg_start = segment_cmd.vmaddr;
                const seg_end = seg_start + segment_cmd.vmsize;
                if (original_address >= seg_start and original_address < seg_end) {
                    return fs.path.basename(mem.sliceTo(std.c._dyld_get_image_name(i), 0));
                }
            },
            else => {},
        };
    }

    return null;
}

fn lookupModuleWin32(self: *SelfInfo, address: usize) !*Module {
    for (self.modules.items) |*module| {
        if (address >= module.base_address and address < module.base_address + module.size) {
            if (self.address_map.get(module.base_address)) |obj_di| {
                return obj_di;
            }

            const obj_di = try self.allocator.create(Module);
            errdefer self.allocator.destroy(obj_di);

            const mapped_module = @as([*]const u8, @ptrFromInt(module.base_address))[0..module.size];
            var coff_obj = try coff.Coff.init(mapped_module, true);

            // The string table is not mapped into memory by the loader, so if a section name is in the
            // string table then we have to map the full image file from disk. This can happen when
            // a binary is produced with -gdwarf, since the section names are longer than 8 bytes.
            if (coff_obj.strtabRequired()) {
                var name_buffer: [windows.PATH_MAX_WIDE + 4:0]u16 = undefined;
                // openFileAbsoluteW requires the prefix to be present
                @memcpy(name_buffer[0..4], &[_]u16{ '\\', '?', '?', '\\' });

                const process_handle = windows.GetCurrentProcess();
                const len = windows.kernel32.GetModuleFileNameExW(
                    process_handle,
                    module.handle,
                    @ptrCast(&name_buffer[4]),
                    windows.PATH_MAX_WIDE,
                );

                if (len == 0) return error.MissingDebugInfo;
                const coff_file = fs.openFileAbsoluteW(name_buffer[0 .. len + 4 :0], .{}) catch |err| switch (err) {
                    error.FileNotFound => return error.MissingDebugInfo,
                    else => return err,
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
                var base_ptr: usize = 0;
                const map_section_rc = windows.ntdll.NtMapViewOfSection(
                    section_handle,
                    process_handle,
                    @ptrCast(&base_ptr),
                    null,
                    0,
                    null,
                    &coff_len,
                    .ViewUnmap,
                    0,
                    windows.PAGE_READONLY,
                );
                if (map_section_rc != .SUCCESS) return error.MissingDebugInfo;
                errdefer assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @ptrFromInt(base_ptr)) == .SUCCESS);

                const section_view = @as([*]const u8, @ptrFromInt(base_ptr))[0..coff_len];
                coff_obj = try coff.Coff.init(section_view, false);

                module.mapped_file = .{
                    .file = coff_file,
                    .section_handle = section_handle,
                    .section_view = section_view,
                };
            }
            errdefer if (module.mapped_file) |mapped_file| mapped_file.deinit();

            obj_di.* = try readCoffDebugInfo(self.allocator, &coff_obj);
            obj_di.base_address = module.base_address;

            try self.address_map.putNoClobber(module.base_address, obj_di);
            return obj_di;
        }
    }

    return error.MissingDebugInfo;
}

fn lookupModuleNameWin32(self: *SelfInfo, address: usize) ?[]const u8 {
    for (self.modules.items) |module| {
        if (address >= module.base_address and address < module.base_address + module.size) {
            return module.name;
        }
    }
    return null;
}

fn lookupModuleNameDl(self: *SelfInfo, address: usize) ?[]const u8 {
    _ = self;

    var ctx: struct {
        // Input
        address: usize,
        // Output
        name: []const u8 = "",
    } = .{ .address = address };
    const CtxTy = @TypeOf(ctx);

    if (posix.dl_iterate_phdr(&ctx, error{Found}, struct {
        fn callback(info: *posix.dl_phdr_info, size: usize, context: *CtxTy) !void {
            _ = size;
            if (context.address < info.addr) return;
            const phdrs = info.phdr[0..info.phnum];
            for (phdrs) |*phdr| {
                if (phdr.p_type != elf.PT_LOAD) continue;

                const seg_start = info.addr +% phdr.p_vaddr;
                const seg_end = seg_start + phdr.p_memsz;
                if (context.address >= seg_start and context.address < seg_end) {
                    context.name = mem.sliceTo(info.name, 0) orelse "";
                    break;
                }
            } else return;

            return error.Found;
        }
    }.callback)) {
        return null;
    } else |err| switch (err) {
        error.Found => return fs.path.basename(ctx.name),
    }

    return null;
}

fn lookupModuleDl(self: *SelfInfo, address: usize) !*Module {
    var ctx: struct {
        // Input
        address: usize,
        // Output
        base_address: usize = undefined,
        name: []const u8 = undefined,
        build_id: ?[]const u8 = null,
        gnu_eh_frame: ?[]const u8 = null,
    } = .{ .address = address };
    const CtxTy = @TypeOf(ctx);

    if (posix.dl_iterate_phdr(&ctx, error{Found}, struct {
        fn callback(info: *posix.dl_phdr_info, size: usize, context: *CtxTy) !void {
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
                    // Android libc uses NULL instead of an empty string to mark the
                    // main program
                    context.name = mem.sliceTo(info.name, 0) orelse "";
                    context.base_address = info.addr;
                    break;
                }
            } else return;

            for (info.phdr[0..info.phnum]) |phdr| {
                switch (phdr.p_type) {
                    elf.PT_NOTE => {
                        // Look for .note.gnu.build-id
                        const note_bytes = @as([*]const u8, @ptrFromInt(info.addr + phdr.p_vaddr))[0..phdr.p_memsz];
                        const name_size = mem.readInt(u32, note_bytes[0..4], native_endian);
                        if (name_size != 4) continue;
                        const desc_size = mem.readInt(u32, note_bytes[4..8], native_endian);
                        const note_type = mem.readInt(u32, note_bytes[8..12], native_endian);
                        if (note_type != elf.NT_GNU_BUILD_ID) continue;
                        if (!mem.eql(u8, "GNU\x00", note_bytes[12..16])) continue;
                        context.build_id = note_bytes[16..][0..desc_size];
                    },
                    elf.PT_GNU_EH_FRAME => {
                        context.gnu_eh_frame = @as([*]const u8, @ptrFromInt(info.addr + phdr.p_vaddr))[0..phdr.p_memsz];
                    },
                    else => {},
                }
            }

            // Stop the iteration
            return error.Found;
        }
    }.callback)) {
        return error.MissingDebugInfo;
    } else |err| switch (err) {
        error.Found => {},
    }

    if (self.address_map.get(ctx.base_address)) |obj_di| {
        return obj_di;
    }

    const obj_di = try self.allocator.create(Module);
    errdefer self.allocator.destroy(obj_di);

    var sections: Dwarf.SectionArray = Dwarf.null_section_array;
    if (ctx.gnu_eh_frame) |eh_frame_hdr| {
        // This is a special case - pointer offsets inside .eh_frame_hdr
        // are encoded relative to its base address, so we must use the
        // version that is already memory mapped, and not the one that
        // will be mapped separately from the ELF file.
        sections[@intFromEnum(Dwarf.Section.Id.eh_frame_hdr)] = .{
            .data = eh_frame_hdr,
            .owned = false,
        };
    }

    obj_di.* = try readElfDebugInfo(self.allocator, if (ctx.name.len > 0) ctx.name else null, ctx.build_id, null, &sections, null);
    obj_di.base_address = ctx.base_address;

    // Missing unwind info isn't treated as a failure, as the unwinder will fall back to FP-based unwinding
    obj_di.dwarf.scanAllUnwindInfo(self.allocator, ctx.base_address) catch {};

    try self.address_map.putNoClobber(ctx.base_address, obj_di);

    return obj_di;
}

fn lookupModuleHaiku(self: *SelfInfo, address: usize) !*Module {
    _ = self;
    _ = address;
    @panic("TODO implement lookup module for Haiku");
}

fn lookupModuleWasm(self: *SelfInfo, address: usize) !*Module {
    _ = self;
    _ = address;
    @panic("TODO implement lookup module for Wasm");
}

pub const Module = switch (native_os) {
    .macos, .ios, .watchos, .tvos, .visionos => struct {
        base_address: usize,
        vmaddr_slide: usize,
        mapped_memory: []align(std.heap.page_size_min) const u8,
        symbols: []const MachoSymbol,
        strings: [:0]const u8,
        ofiles: OFileTable,

        // Backed by the in-memory sections mapped by the loader
        unwind_info: ?[]const u8 = null,
        eh_frame: ?[]const u8 = null,

        const OFileTable = std.StringHashMap(OFileInfo);
        const OFileInfo = struct {
            di: Dwarf,
            addr_table: std.StringHashMap(u64),
        };

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            var it = self.ofiles.iterator();
            while (it.next()) |entry| {
                const ofile = entry.value_ptr;
                ofile.di.deinit(allocator);
                ofile.addr_table.deinit();
            }
            self.ofiles.deinit();
            allocator.free(self.symbols);
            posix.munmap(self.mapped_memory);
        }

        fn loadOFile(self: *@This(), allocator: Allocator, o_file_path: []const u8) !*OFileInfo {
            const o_file = try fs.cwd().openFile(o_file_path, .{});
            const mapped_mem = try mapWholeFile(o_file);

            const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
            if (hdr.magic != std.macho.MH_MAGIC_64)
                return error.InvalidDebugInfo;

            var segcmd: ?macho.LoadCommandIterator.LoadCommand = null;
            var symtabcmd: ?macho.symtab_command = null;
            var it = macho.LoadCommandIterator{
                .ncmds = hdr.ncmds,
                .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
            };
            while (it.next()) |cmd| switch (cmd.cmd()) {
                .SEGMENT_64 => segcmd = cmd,
                .SYMTAB => symtabcmd = cmd.cast(macho.symtab_command).?,
                else => {},
            };

            if (segcmd == null or symtabcmd == null) return error.MissingDebugInfo;

            // Parse symbols
            const strtab = @as(
                [*]const u8,
                @ptrCast(&mapped_mem[symtabcmd.?.stroff]),
            )[0 .. symtabcmd.?.strsize - 1 :0];
            const symtab = @as(
                [*]const macho.nlist_64,
                @ptrCast(@alignCast(&mapped_mem[symtabcmd.?.symoff])),
            )[0..symtabcmd.?.nsyms];

            // TODO handle tentative (common) symbols
            var addr_table = std.StringHashMap(u64).init(allocator);
            try addr_table.ensureTotalCapacity(@as(u32, @intCast(symtab.len)));
            for (symtab) |sym| {
                if (sym.n_strx == 0) continue;
                if (sym.undf() or sym.tentative() or sym.abs()) continue;
                const sym_name = mem.sliceTo(strtab[sym.n_strx..], 0);
                // TODO is it possible to have a symbol collision?
                addr_table.putAssumeCapacityNoClobber(sym_name, sym.n_value);
            }

            var sections: Dwarf.SectionArray = Dwarf.null_section_array;
            if (self.eh_frame) |eh_frame| sections[@intFromEnum(Dwarf.Section.Id.eh_frame)] = .{
                .data = eh_frame,
                .owned = false,
            };

            for (segcmd.?.getSections()) |sect| {
                if (!std.mem.eql(u8, "__DWARF", sect.segName())) continue;

                var section_index: ?usize = null;
                inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |section, i| {
                    if (mem.eql(u8, "__" ++ section.name, sect.sectName())) section_index = i;
                }
                if (section_index == null) continue;

                const section_bytes = try Dwarf.chopSlice(mapped_mem, sect.offset, sect.size);
                sections[section_index.?] = .{
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

            var di: Dwarf = .{
                .endian = .little,
                .sections = sections,
                .is_macho = true,
            };

            try Dwarf.open(&di, allocator);
            const info = OFileInfo{
                .di = di,
                .addr_table = addr_table,
            };

            // Add the debug info to the cache
            const result = try self.ofiles.getOrPut(o_file_path);
            assert(!result.found_existing);
            result.value_ptr.* = info;

            return result.value_ptr;
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !std.debug.Symbol {
            nosuspend {
                const result = try self.getOFileInfoForAddress(allocator, address);
                if (result.symbol == null) return .{};

                // Take the symbol name from the N_FUN STAB entry, we're going to
                // use it if we fail to find the DWARF infos
                const stab_symbol = mem.sliceTo(self.strings[result.symbol.?.strx..], 0);
                if (result.o_file_info == null) return .{ .name = stab_symbol };

                // Translate again the address, this time into an address inside the
                // .o file
                const relocated_address_o = result.o_file_info.?.addr_table.get(stab_symbol) orelse return .{
                    .name = "???",
                };

                const addr_off = result.relocated_address - result.symbol.?.addr;
                const o_file_di = &result.o_file_info.?.di;
                if (o_file_di.findCompileUnit(relocated_address_o)) |compile_unit| {
                    return .{
                        .name = o_file_di.getSymbolName(relocated_address_o) orelse "???",
                        .compile_unit_name = compile_unit.die.getAttrString(
                            o_file_di,
                            std.dwarf.AT.name,
                            o_file_di.section(.debug_str),
                            compile_unit.*,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                        },
                        .source_location = o_file_di.getLineNumberInfo(
                            allocator,
                            compile_unit,
                            relocated_address_o + addr_off,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => null,
                            else => return err,
                        },
                    };
                } else |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => {
                        return .{ .name = stab_symbol };
                    },
                    else => return err,
                }
            }
        }

        pub fn getOFileInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !struct {
            relocated_address: usize,
            symbol: ?*const MachoSymbol = null,
            o_file_info: ?*OFileInfo = null,
        } {
            nosuspend {
                // Translate the VA into an address into this object
                const relocated_address = address - self.vmaddr_slide;

                // Find the .o file where this symbol is defined
                const symbol = machoSearchSymbols(self.symbols, relocated_address) orelse return .{
                    .relocated_address = relocated_address,
                };

                // Check if its debug infos are already in the cache
                const o_file_path = mem.sliceTo(self.strings[symbol.ofile..], 0);
                const o_file_info = self.ofiles.getPtr(o_file_path) orelse
                    (self.loadOFile(allocator, o_file_path) catch |err| switch (err) {
                    error.FileNotFound,
                    error.MissingDebugInfo,
                    error.InvalidDebugInfo,
                    => return .{
                        .relocated_address = relocated_address,
                        .symbol = symbol,
                    },
                    else => return err,
                });

                return .{
                    .relocated_address = relocated_address,
                    .symbol = symbol,
                    .o_file_info = o_file_info,
                };
            }
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*Dwarf {
            return if ((try self.getOFileInfoForAddress(allocator, address)).o_file_info) |o_file_info| &o_file_info.di else null;
        }
    },
    .uefi, .windows => struct {
        base_address: usize,
        pdb: ?Pdb = null,
        dwarf: ?Dwarf = null,
        coff_image_base: u64,

        /// Only used if pdb is non-null
        coff_section_headers: []coff.SectionHeader,

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            if (self.dwarf) |*dwarf| {
                dwarf.deinit(allocator);
            }

            if (self.pdb) |*p| {
                p.deinit();
                allocator.free(self.coff_section_headers);
            }
        }

        fn getSymbolFromPdb(self: *@This(), relocated_address: usize) !?std.debug.Symbol {
            var coff_section: *align(1) const coff.SectionHeader = undefined;
            const mod_index = for (self.pdb.?.sect_contribs) |sect_contrib| {
                if (sect_contrib.section > self.coff_section_headers.len) continue;
                // Remember that SectionContribEntry.Section is 1-based.
                coff_section = &self.coff_section_headers[sect_contrib.section - 1];

                const vaddr_start = coff_section.virtual_address + sect_contrib.offset;
                const vaddr_end = vaddr_start + sect_contrib.size;
                if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                    break sect_contrib.module_index;
                }
            } else {
                // we have no information to add to the address
                return null;
            };

            const module = (try self.pdb.?.getModule(mod_index)) orelse
                return error.InvalidDebugInfo;
            const obj_basename = fs.path.basename(module.obj_file_name);

            const symbol_name = self.pdb.?.getSymbolName(
                module,
                relocated_address - coff_section.virtual_address,
            ) orelse "???";
            const opt_line_info = try self.pdb.?.getLineNumberInfo(
                module,
                relocated_address - coff_section.virtual_address,
            );

            return .{
                .name = symbol_name,
                .compile_unit_name = obj_basename,
                .source_location = opt_line_info,
            };
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !std.debug.Symbol {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;

            if (self.pdb != null) {
                if (try self.getSymbolFromPdb(relocated_address)) |symbol| return symbol;
            }

            if (self.dwarf) |*dwarf| {
                const dwarf_address = relocated_address + self.coff_image_base;
                return dwarf.getSymbol(allocator, dwarf_address);
            }

            return .{};
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*Dwarf {
            _ = allocator;
            _ = address;

            return switch (self.debug_data) {
                .dwarf => |*dwarf| dwarf,
                else => null,
            };
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris, .illumos => Dwarf.ElfModule,
    .wasi, .emscripten => struct {
        pub fn deinit(self: *@This(), allocator: Allocator) void {
            _ = self;
            _ = allocator;
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !std.debug.Symbol {
            _ = self;
            _ = allocator;
            _ = address;
            return .{};
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*Dwarf {
            _ = self;
            _ = allocator;
            _ = address;
            return null;
        }
    },
    else => Dwarf,
};

/// How is this different than `Module` when the host is Windows?
/// Why are both stored in the `SelfInfo` struct?
/// Boy, it sure would be nice if someone added documentation comments for this
/// struct explaining it.
pub const WindowsModule = struct {
    base_address: usize,
    size: u32,
    name: []const u8,
    handle: windows.HMODULE,

    // Set when the image file needed to be mapped from disk
    mapped_file: ?struct {
        file: File,
        section_handle: windows.HANDLE,
        section_view: []const u8,

        pub fn deinit(self: @This()) void {
            const process_handle = windows.GetCurrentProcess();
            assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @constCast(@ptrCast(self.section_view.ptr))) == .SUCCESS);
            windows.CloseHandle(self.section_handle);
            self.file.close();
        }
    } = null,
};

/// This takes ownership of macho_file: users of this function should not close
/// it themselves, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn readMachODebugInfo(allocator: Allocator, macho_file: File) !Module {
    const mapped_mem = try mapWholeFile(macho_file);

    const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
    if (hdr.magic != macho.MH_MAGIC_64)
        return error.InvalidDebugInfo;

    var it = macho.LoadCommandIterator{
        .ncmds = hdr.ncmds,
        .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
    };
    const symtab = while (it.next()) |cmd| switch (cmd.cmd()) {
        .SYMTAB => break cmd.cast(macho.symtab_command).?,
        else => {},
    } else return error.MissingDebugInfo;

    const syms = @as(
        [*]const macho.nlist_64,
        @ptrCast(@alignCast(&mapped_mem[symtab.symoff])),
    )[0..symtab.nsyms];
    const strings = mapped_mem[symtab.stroff..][0 .. symtab.strsize - 1 :0];

    const symbols_buf = try allocator.alloc(MachoSymbol, syms.len);

    var ofile: u32 = undefined;
    var last_sym: MachoSymbol = undefined;
    var symbol_index: usize = 0;
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
        if (!sym.stab()) continue;

        // TODO handle globals N_GSYM, and statics N_STSYM
        switch (sym.n_type) {
            macho.N_OSO => {
                switch (state) {
                    .init, .oso_close => {
                        state = .oso_open;
                        ofile = sym.n_strx;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_BNSYM => {
                switch (state) {
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
                }
            },
            macho.N_FUN => {
                switch (state) {
                    .bnsym => {
                        state = .fun_strx;
                        last_sym.strx = sym.n_strx;
                    },
                    .fun_strx => {
                        state = .fun_size;
                        last_sym.size = @as(u32, @intCast(sym.n_value));
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_ENSYM => {
                switch (state) {
                    .fun_size => {
                        state = .ensym;
                        symbols_buf[symbol_index] = last_sym;
                        symbol_index += 1;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_SO => {
                switch (state) {
                    .init, .oso_close => {},
                    .oso_open, .ensym => {
                        state = .oso_close;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            else => {},
        }
    }

    switch (state) {
        .init => return error.MissingDebugInfo,
        .oso_close => {},
        else => return error.InvalidDebugInfo,
    }

    const symbols = try allocator.realloc(symbols_buf, symbol_index);

    // Even though lld emits symbols in ascending order, this debug code
    // should work for programs linked in any valid way.
    // This sort is so that we can binary search later.
    mem.sort(MachoSymbol, symbols, {}, MachoSymbol.addressLessThan);

    return .{
        .base_address = undefined,
        .vmaddr_slide = undefined,
        .mapped_memory = mapped_mem,
        .ofiles = Module.OFileTable.init(allocator),
        .symbols = symbols,
        .strings = strings,
    };
}

fn readCoffDebugInfo(allocator: Allocator, coff_obj: *coff.Coff) !Module {
    nosuspend {
        var di: Module = .{
            .base_address = undefined,
            .coff_image_base = coff_obj.getImageBase(),
            .coff_section_headers = undefined,
        };

        if (coff_obj.getSectionByName(".debug_info")) |_| {
            // This coff file has embedded DWARF debug info
            var sections: Dwarf.SectionArray = Dwarf.null_section_array;
            errdefer for (sections) |section| if (section) |s| if (s.owned) allocator.free(s.data);

            inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |section, i| {
                sections[i] = if (coff_obj.getSectionByName("." ++ section.name)) |section_header| blk: {
                    break :blk .{
                        .data = try coff_obj.getSectionDataAlloc(section_header, allocator),
                        .virtual_address = section_header.virtual_address,
                        .owned = true,
                    };
                } else null;
            }

            var dwarf: Dwarf = .{
                .endian = native_endian,
                .sections = sections,
                .is_macho = false,
            };

            try Dwarf.open(&dwarf, allocator);
            di.dwarf = dwarf;
        }

        const raw_path = try coff_obj.getPdbPath() orelse return di;
        const path = blk: {
            if (fs.path.isAbsolute(raw_path)) {
                break :blk raw_path;
            } else {
                const self_dir = try fs.selfExeDirPathAlloc(allocator);
                defer allocator.free(self_dir);
                break :blk try fs.path.join(allocator, &.{ self_dir, raw_path });
            }
        };
        defer if (path.ptr != raw_path.ptr) allocator.free(path);

        di.pdb = Pdb.init(allocator, path) catch |err| switch (err) {
            error.FileNotFound, error.IsDir => {
                if (di.dwarf == null) return error.MissingDebugInfo;
                return di;
            },
            else => return err,
        };
        try di.pdb.?.parseInfoStream();
        try di.pdb.?.parseDbiStream();

        if (!mem.eql(u8, &coff_obj.guid, &di.pdb.?.guid) or coff_obj.age != di.pdb.?.age)
            return error.InvalidDebugInfo;

        // Only used by the pdb path
        di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(allocator);
        errdefer allocator.free(di.coff_section_headers);

        return di;
    }
}

/// Reads debug info from an ELF file, or the current binary if none in specified.
/// If the required sections aren't present but a reference to external debug info is,
/// then this this function will recurse to attempt to load the debug sections from
/// an external file.
pub fn readElfDebugInfo(
    allocator: Allocator,
    elf_filename: ?[]const u8,
    build_id: ?[]const u8,
    expected_crc: ?u32,
    parent_sections: *Dwarf.SectionArray,
    parent_mapped_mem: ?[]align(std.heap.page_size_min) const u8,
) !Dwarf.ElfModule {
    nosuspend {
        const elf_file = (if (elf_filename) |filename| blk: {
            break :blk fs.cwd().openFile(filename, .{});
        } else fs.openSelfExe(.{})) catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            else => return err,
        };

        const mapped_mem = try mapWholeFile(elf_file);
        return Dwarf.ElfModule.load(
            allocator,
            mapped_mem,
            build_id,
            expected_crc,
            parent_sections,
            parent_mapped_mem,
            elf_filename,
        );
    }
}

const MachoSymbol = struct {
    strx: u32,
    addr: u64,
    size: u32,
    ofile: u32,

    /// Returns the address from the macho file
    fn address(self: MachoSymbol) u64 {
        return self.addr;
    }

    fn addressLessThan(context: void, lhs: MachoSymbol, rhs: MachoSymbol) bool {
        _ = context;
        return lhs.addr < rhs.addr;
    }
};

/// Takes ownership of file, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn mapWholeFile(file: File) ![]align(std.heap.page_size_min) const u8 {
    nosuspend {
        defer file.close();

        const file_len = math.cast(usize, try file.getEndPos()) orelse math.maxInt(usize);
        const mapped_mem = try posix.mmap(
            null,
            file_len,
            posix.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        errdefer posix.munmap(mapped_mem);

        return mapped_mem;
    }
}

fn machoSearchSymbols(symbols: []const MachoSymbol, address: usize) ?*const MachoSymbol {
    var min: usize = 0;
    var max: usize = symbols.len - 1;
    while (min < max) {
        const mid = min + (max - min) / 2;
        const curr = &symbols[mid];
        const next = &symbols[mid + 1];
        if (address >= next.address()) {
            min = mid + 1;
        } else if (address < curr.address()) {
            max = mid;
        } else {
            return curr;
        }
    }

    const max_sym = &symbols[symbols.len - 1];
    if (address >= max_sym.address())
        return max_sym;

    return null;
}

test machoSearchSymbols {
    const symbols = [_]MachoSymbol{
        .{ .addr = 100, .strx = undefined, .size = undefined, .ofile = undefined },
        .{ .addr = 200, .strx = undefined, .size = undefined, .ofile = undefined },
        .{ .addr = 300, .strx = undefined, .size = undefined, .ofile = undefined },
    };

    try testing.expectEqual(null, machoSearchSymbols(&symbols, 0));
    try testing.expectEqual(null, machoSearchSymbols(&symbols, 99));
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 100).?);
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 150).?);
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 199).?);

    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 200).?);
    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 250).?);
    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 299).?);

    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 300).?);
    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 301).?);
    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 5000).?);
}

/// Unwind a frame using MachO compact unwind info (from __unwind_info).
/// If the compact encoding can't encode a way to unwind a frame, it will
/// defer unwinding to DWARF, in which case `.eh_frame` will be used if available.
pub fn unwindFrameMachO(
    allocator: Allocator,
    base_address: usize,
    context: *UnwindContext,
    ma: *std.debug.MemoryAccessor,
    unwind_info: []const u8,
    eh_frame: ?[]const u8,
) !usize {
    const header = std.mem.bytesAsValue(
        macho.unwind_info_section_header,
        unwind_info[0..@sizeOf(macho.unwind_info_section_header)],
    );
    const indices = std.mem.bytesAsSlice(
        macho.unwind_info_section_header_index_entry,
        unwind_info[header.indexSectionOffset..][0 .. header.indexCount * @sizeOf(macho.unwind_info_section_header_index_entry)],
    );
    if (indices.len == 0) return error.MissingUnwindInfo;

    const mapped_pc = context.pc - base_address;
    const second_level_index = blk: {
        var left: usize = 0;
        var len: usize = indices.len;

        while (len > 1) {
            const mid = left + len / 2;
            const offset = indices[mid].functionOffset;
            if (mapped_pc < offset) {
                len /= 2;
            } else {
                left = mid;
                if (mapped_pc == offset) break;
                len -= len / 2;
            }
        }

        // Last index is a sentinel containing the highest address as its functionOffset
        if (indices[left].secondLevelPagesSectionOffset == 0) return error.MissingUnwindInfo;
        break :blk &indices[left];
    };

    const common_encodings = std.mem.bytesAsSlice(
        macho.compact_unwind_encoding_t,
        unwind_info[header.commonEncodingsArraySectionOffset..][0 .. header.commonEncodingsArrayCount * @sizeOf(macho.compact_unwind_encoding_t)],
    );

    const start_offset = second_level_index.secondLevelPagesSectionOffset;
    const kind = std.mem.bytesAsValue(
        macho.UNWIND_SECOND_LEVEL,
        unwind_info[start_offset..][0..@sizeOf(macho.UNWIND_SECOND_LEVEL)],
    );

    const entry: struct {
        function_offset: usize,
        raw_encoding: u32,
    } = switch (kind.*) {
        .REGULAR => blk: {
            const page_header = std.mem.bytesAsValue(
                macho.unwind_info_regular_second_level_page_header,
                unwind_info[start_offset..][0..@sizeOf(macho.unwind_info_regular_second_level_page_header)],
            );

            const entries = std.mem.bytesAsSlice(
                macho.unwind_info_regular_second_level_entry,
                unwind_info[start_offset + page_header.entryPageOffset ..][0 .. page_header.entryCount * @sizeOf(macho.unwind_info_regular_second_level_entry)],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                const offset = entries[mid].functionOffset;
                if (mapped_pc < offset) {
                    len /= 2;
                } else {
                    left = mid;
                    if (mapped_pc == offset) break;
                    len -= len / 2;
                }
            }

            break :blk .{
                .function_offset = entries[left].functionOffset,
                .raw_encoding = entries[left].encoding,
            };
        },
        .COMPRESSED => blk: {
            const page_header = std.mem.bytesAsValue(
                macho.unwind_info_compressed_second_level_page_header,
                unwind_info[start_offset..][0..@sizeOf(macho.unwind_info_compressed_second_level_page_header)],
            );

            const entries = std.mem.bytesAsSlice(
                macho.UnwindInfoCompressedEntry,
                unwind_info[start_offset + page_header.entryPageOffset ..][0 .. page_header.entryCount * @sizeOf(macho.UnwindInfoCompressedEntry)],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                const offset = second_level_index.functionOffset + entries[mid].funcOffset;
                if (mapped_pc < offset) {
                    len /= 2;
                } else {
                    left = mid;
                    if (mapped_pc == offset) break;
                    len -= len / 2;
                }
            }

            const entry = entries[left];
            const function_offset = second_level_index.functionOffset + entry.funcOffset;
            if (entry.encodingIndex < header.commonEncodingsArrayCount) {
                if (entry.encodingIndex >= common_encodings.len) return error.InvalidUnwindInfo;
                break :blk .{
                    .function_offset = function_offset,
                    .raw_encoding = common_encodings[entry.encodingIndex],
                };
            } else {
                const local_index = try math.sub(
                    u8,
                    entry.encodingIndex,
                    math.cast(u8, header.commonEncodingsArrayCount) orelse return error.InvalidUnwindInfo,
                );
                const local_encodings = std.mem.bytesAsSlice(
                    macho.compact_unwind_encoding_t,
                    unwind_info[start_offset + page_header.encodingsPageOffset ..][0 .. page_header.encodingsCount * @sizeOf(macho.compact_unwind_encoding_t)],
                );
                if (local_index >= local_encodings.len) return error.InvalidUnwindInfo;
                break :blk .{
                    .function_offset = function_offset,
                    .raw_encoding = local_encodings[local_index],
                };
            }
        },
        else => return error.InvalidUnwindInfo,
    };

    if (entry.raw_encoding == 0) return error.NoUnwindInfo;
    const reg_context = Dwarf.abi.RegisterContext{
        .eh_frame = false,
        .is_macho = true,
    };

    const encoding: macho.CompactUnwindEncoding = @bitCast(entry.raw_encoding);
    const new_ip = switch (builtin.cpu.arch) {
        .x86_64 => switch (encoding.mode.x86_64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .RBP_FRAME => blk: {
                const regs: [5]u3 = .{
                    encoding.value.x86_64.frame.reg0,
                    encoding.value.x86_64.frame.reg1,
                    encoding.value.x86_64.frame.reg2,
                    encoding.value.x86_64.frame.reg3,
                    encoding.value.x86_64.frame.reg4,
                };

                const frame_offset = encoding.value.x86_64.frame.frame_offset * @sizeOf(usize);
                var max_reg: usize = 0;
                inline for (regs, 0..) |reg, i| {
                    if (reg > 0) max_reg = i;
                }

                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 2 * @sizeOf(usize);

                // Verify the stack range we're about to read register values from
                if (ma.load(usize, new_sp) == null or ma.load(usize, fp - frame_offset + max_reg * @sizeOf(usize)) == null) return error.InvalidUnwindInfo;

                const ip_ptr = fp + @sizeOf(usize);
                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                for (regs, 0..) |reg, i| {
                    if (reg == 0) continue;
                    const addr = fp - frame_offset + i * @sizeOf(usize);
                    const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(reg);
                    (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(addr)).*;
                }

                break :blk new_ip;
            },
            .STACK_IMMD,
            .STACK_IND,
            => blk: {
                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const stack_size = if (encoding.mode.x86_64 == .STACK_IMMD)
                    @as(usize, encoding.value.x86_64.frameless.stack.direct.stack_size) * @sizeOf(usize)
                else stack_size: {
                    // In .STACK_IND, the stack size is inferred from the subq instruction at the beginning of the function.
                    const sub_offset_addr =
                        base_address +
                        entry.function_offset +
                        encoding.value.x86_64.frameless.stack.indirect.sub_offset;
                    if (ma.load(usize, sub_offset_addr) == null) return error.InvalidUnwindInfo;

                    // `sub_offset_addr` points to the offset of the literal within the instruction
                    const sub_operand = @as(*align(1) const u32, @ptrFromInt(sub_offset_addr)).*;
                    break :stack_size sub_operand + @sizeOf(usize) * @as(usize, encoding.value.x86_64.frameless.stack.indirect.stack_adjust);
                };

                // Decode the Lehmer-coded sequence of registers.
                // For a description of the encoding see lib/libc/include/any-macos.13-any/mach-o/compact_unwind_encoding.h

                // Decode the variable-based permutation number into its digits. Each digit represents
                // an index into the list of register numbers that weren't yet used in the sequence at
                // the time the digit was added.
                const reg_count = encoding.value.x86_64.frameless.stack_reg_count;
                const ip_ptr = if (reg_count > 0) reg_blk: {
                    var digits: [6]u3 = undefined;
                    var accumulator: usize = encoding.value.x86_64.frameless.stack_reg_permutation;
                    var base: usize = 2;
                    for (0..reg_count) |i| {
                        const div = accumulator / base;
                        digits[digits.len - 1 - i] = @intCast(accumulator - base * div);
                        accumulator = div;
                        base += 1;
                    }

                    const reg_numbers = [_]u3{ 1, 2, 3, 4, 5, 6 };
                    var registers: [reg_numbers.len]u3 = undefined;
                    var used_indices = [_]bool{false} ** reg_numbers.len;
                    for (digits[digits.len - reg_count ..], 0..) |target_unused_index, i| {
                        var unused_count: u8 = 0;
                        const unused_index = for (used_indices, 0..) |used, index| {
                            if (!used) {
                                if (target_unused_index == unused_count) break index;
                                unused_count += 1;
                            }
                        } else unreachable;

                        registers[i] = reg_numbers[unused_index];
                        used_indices[unused_index] = true;
                    }

                    var reg_addr = sp + stack_size - @sizeOf(usize) * @as(usize, reg_count + 1);
                    if (ma.load(usize, reg_addr) == null) return error.InvalidUnwindInfo;
                    for (0..reg_count) |i| {
                        const reg_number = try Dwarf.compactUnwindToDwarfRegNumber(registers[i]);
                        (try regValueNative(context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }

                    break :reg_blk reg_addr;
                } else sp + stack_size - @sizeOf(usize);

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_sp = ip_ptr + @sizeOf(usize);
                if (ma.load(usize, new_sp) == null) return error.InvalidUnwindInfo;

                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :blk new_ip;
            },
            .DWARF => {
                return unwindFrameMachODwarf(allocator, base_address, context, ma, eh_frame orelse return error.MissingEhFrame, @intCast(encoding.value.x86_64.dwarf));
            },
        },
        .aarch64, .aarch64_be => switch (encoding.mode.arm64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .FRAMELESS => blk: {
                const sp = (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).*;
                const new_sp = sp + encoding.value.arm64.frameless.stack_size * 16;
                const new_ip = (try regValueNative(context.thread_context, 30, reg_context)).*;
                if (ma.load(usize, new_sp) == null) return error.InvalidUnwindInfo;
                (try regValueNative(context.thread_context, spRegNum(reg_context), reg_context)).* = new_sp;
                break :blk new_ip;
            },
            .DWARF => {
                return unwindFrameMachODwarf(allocator, base_address, context, ma, eh_frame orelse return error.MissingEhFrame, @intCast(encoding.value.arm64.dwarf));
            },
            .FRAME => blk: {
                const fp = (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 16;
                const ip_ptr = fp + @sizeOf(usize);

                const num_restored_pairs: usize =
                    @popCount(@as(u5, @bitCast(encoding.value.arm64.frame.x_reg_pairs))) +
                    @popCount(@as(u4, @bitCast(encoding.value.arm64.frame.d_reg_pairs)));
                const min_reg_addr = fp - num_restored_pairs * 2 * @sizeOf(usize);

                if (ma.load(usize, new_sp) == null or ma.load(usize, min_reg_addr) == null) return error.InvalidUnwindInfo;

                var reg_addr = fp - @sizeOf(usize);
                inline for (@typeInfo(@TypeOf(encoding.value.arm64.frame.x_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(encoding.value.arm64.frame.x_reg_pairs, field.name) != 0) {
                        (try regValueNative(context.thread_context, 19 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                        (try regValueNative(context.thread_context, 20 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }
                }

                inline for (@typeInfo(@TypeOf(encoding.value.arm64.frame.d_reg_pairs)).@"struct".fields, 0..) |field, i| {
                    if (@field(encoding.value.arm64.frame.d_reg_pairs, field.name) != 0) {
                        // Only the lower half of the 128-bit V registers are restored during unwinding
                        @memcpy(
                            try regBytes(context.thread_context, 64 + 8 + i, context.reg_context),
                            std.mem.asBytes(@as(*const usize, @ptrFromInt(reg_addr))),
                        );
                        reg_addr += @sizeOf(usize);
                        @memcpy(
                            try regBytes(context.thread_context, 64 + 9 + i, context.reg_context),
                            std.mem.asBytes(@as(*const usize, @ptrFromInt(reg_addr))),
                        );
                        reg_addr += @sizeOf(usize);
                    }
                }

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try regValueNative(context.thread_context, fpRegNum(reg_context), reg_context)).* = new_fp;
                (try regValueNative(context.thread_context, ip_reg_num, reg_context)).* = new_ip;

                break :blk new_ip;
            },
        },
        else => return error.UnimplementedArch,
    };

    context.pc = stripInstructionPtrAuthCode(new_ip);
    if (context.pc > 0) context.pc -= 1;
    return new_ip;
}

pub const UnwindContext = struct {
    allocator: Allocator,
    cfa: ?usize,
    pc: usize,
    thread_context: *std.debug.ThreadContext,
    reg_context: Dwarf.abi.RegisterContext,
    vm: VirtualMachine,
    stack_machine: Dwarf.expression.StackMachine(.{ .call_frame_context = true }),

    pub fn init(
        allocator: Allocator,
        thread_context: *std.debug.ThreadContext,
    ) !UnwindContext {
        comptime assert(supports_unwinding);

        const pc = stripInstructionPtrAuthCode(
            (try regValueNative(thread_context, ip_reg_num, null)).*,
        );

        const context_copy = try allocator.create(std.debug.ThreadContext);
        std.debug.copyContext(thread_context, context_copy);

        return .{
            .allocator = allocator,
            .cfa = null,
            .pc = pc,
            .thread_context = context_copy,
            .reg_context = undefined,
            .vm = .{},
            .stack_machine = .{},
        };
    }

    pub fn deinit(self: *UnwindContext) void {
        self.vm.deinit(self.allocator);
        self.stack_machine.deinit(self.allocator);
        self.allocator.destroy(self.thread_context);
        self.* = undefined;
    }

    pub fn getFp(self: *const UnwindContext) !usize {
        return (try regValueNative(self.thread_context, fpRegNum(self.reg_context), self.reg_context)).*;
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
            : "x16"
        );
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
pub fn unwindFrameDwarf(
    allocator: Allocator,
    di: *Dwarf,
    base_address: usize,
    context: *UnwindContext,
    ma: *std.debug.MemoryAccessor,
    explicit_fde_offset: ?usize,
) !usize {
    if (!supports_unwinding) return error.UnsupportedCpuArchitecture;
    if (context.pc == 0) return 0;

    // Find the FDE and CIE
    const cie, const fde = if (explicit_fde_offset) |fde_offset| blk: {
        const dwarf_section: Dwarf.Section.Id = .eh_frame;
        const frame_section = di.section(dwarf_section) orelse return error.MissingFDE;
        if (fde_offset >= frame_section.len) return error.MissingFDE;

        var fbr: std.debug.FixedBufferReader = .{
            .buf = frame_section,
            .pos = fde_offset,
            .endian = di.endian,
        };

        const fde_entry_header = try Dwarf.EntryHeader.read(&fbr, null, dwarf_section);
        if (fde_entry_header.type != .fde) return error.MissingFDE;

        const cie_offset = fde_entry_header.type.fde;
        try fbr.seekTo(cie_offset);

        fbr.endian = native_endian;
        const cie_entry_header = try Dwarf.EntryHeader.read(&fbr, null, dwarf_section);
        if (cie_entry_header.type != .cie) return Dwarf.bad();

        const cie = try Dwarf.CommonInformationEntry.parse(
            cie_entry_header.entry_bytes,
            0,
            true,
            cie_entry_header.format,
            dwarf_section,
            cie_entry_header.length_offset,
            @sizeOf(usize),
            native_endian,
        );
        const fde = try Dwarf.FrameDescriptionEntry.parse(
            fde_entry_header.entry_bytes,
            0,
            true,
            cie,
            @sizeOf(usize),
            native_endian,
        );

        break :blk .{ cie, fde };
    } else blk: {
        // `.eh_frame_hdr` may be incomplete. We'll try it first, but if the lookup fails, we fall
        // back to loading `.eh_frame`/`.debug_frame` and using those from that point on.

        if (di.eh_frame_hdr) |header| hdr: {
            const eh_frame_len = if (di.section(.eh_frame)) |eh_frame| eh_frame.len else null;

            var cie: Dwarf.CommonInformationEntry = undefined;
            var fde: Dwarf.FrameDescriptionEntry = undefined;

            header.findEntry(
                ma,
                eh_frame_len,
                @intFromPtr(di.section(.eh_frame_hdr).?.ptr),
                context.pc,
                &cie,
                &fde,
            ) catch |err| switch (err) {
                error.InvalidDebugInfo => {
                    // `.eh_frame_hdr` appears to be incomplete, so go ahead and populate `cie_map`
                    // and `fde_list`, and fall back to the binary search logic below.
                    try di.scanCieFdeInfo(allocator, base_address);

                    // Since `.eh_frame_hdr` is incomplete, we're very likely to get more lookup
                    // failures using it, and we've just built a complete, sorted list of FDEs
                    // anyway, so just stop using `.eh_frame_hdr` altogether.
                    di.eh_frame_hdr = null;

                    break :hdr;
                },
                else => return err,
            };

            break :blk .{ cie, fde };
        }

        const index = std.sort.binarySearch(Dwarf.FrameDescriptionEntry, di.fde_list.items, context.pc, struct {
            pub fn compareFn(pc: usize, item: Dwarf.FrameDescriptionEntry) std.math.Order {
                if (pc < item.pc_begin) return .lt;

                const range_end = item.pc_begin + item.pc_range;
                if (pc < range_end) return .eq;

                return .gt;
            }
        }.compareFn);

        const fde = if (index) |i| di.fde_list.items[i] else return error.MissingFDE;
        const cie = di.cie_map.get(fde.cie_length_offset) orelse return error.MissingCIE;

        break :blk .{ cie, fde };
    };

    var expression_context: Dwarf.expression.Context = .{
        .format = cie.format,
        .memory_accessor = ma,
        .compile_unit = di.findCompileUnit(fde.pc_begin) catch null,
        .thread_context = context.thread_context,
        .reg_context = context.reg_context,
        .cfa = context.cfa,
    };

    context.vm.reset();
    context.reg_context.eh_frame = cie.version != 4;
    context.reg_context.is_macho = di.is_macho;

    const row = try context.vm.runToNative(context.allocator, context.pc, cie, fde);
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
                context.allocator,
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

    if (ma.load(usize, context.cfa.?) == null) return error.InvalidCFA;
    expression_context.cfa = context.cfa;

    // Buffering the modifications is done because copying the thread context is not portable,
    // some implementations (ie. darwin) use internal pointers to the mcontext.
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const update_allocator = arena.allocator();

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
            const src = try update_allocator.alloc(u8, dest.len);

            const prev = update_tail;
            update_tail = try update_allocator.create(RegisterUpdate);
            update_tail.?.* = .{
                .dest = dest,
                .src = src,
                .prev = prev,
            };

            try column.resolveValue(
                context,
                expression_context,
                ma,
                src,
            );
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
    if (context.pc > 0 and !cie.isSignalFrame()) context.pc -= 1;

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
pub const supports_unwinding = supportsUnwinding(builtin.target);

comptime {
    if (supports_unwinding) assert(Dwarf.abi.supportsUnwinding(builtin.target));
}

/// Tells whether unwinding for this target is *implemented* here in the Zig
/// standard library.
///
/// See also `Dwarf.abi.supportsUnwinding` which tells whether Dwarf supports
/// unwinding on that target *in theory*.
pub fn supportsUnwinding(target: std.Target) bool {
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

fn unwindFrameMachODwarf(
    allocator: Allocator,
    base_address: usize,
    context: *UnwindContext,
    ma: *std.debug.MemoryAccessor,
    eh_frame: []const u8,
    fde_offset: usize,
) !usize {
    var di: Dwarf = .{
        .endian = native_endian,
        .is_macho = true,
    };
    defer di.deinit(context.allocator);

    di.sections[@intFromEnum(Dwarf.Section.Id.eh_frame)] = .{
        .data = eh_frame,
        .owned = false,
    };

    return unwindFrameDwarf(allocator, &di, base_address, context, ma, fde_offset);
}

/// This is a virtual machine that runs DWARF call frame instructions.
pub const VirtualMachine = struct {
    /// See section 6.4.1 of the DWARF5 specification for details on each
    const RegisterRule = union(enum) {
        // The spec says that the default rule for each column is the undefined rule.
        // However, it also allows ABI / compiler authors to specify alternate defaults, so
        // there is a distinction made here.
        default: void,
        undefined: void,
        same_value: void,
        // offset(N)
        offset: i64,
        // val_offset(N)
        val_offset: i64,
        // register(R)
        register: u8,
        // expression(E)
        expression: []const u8,
        // val_expression(E)
        val_expression: []const u8,
        // Augmenter-defined rule
        architectural: void,
    };

    /// Each row contains unwinding rules for a set of registers.
    pub const Row = struct {
        /// Offset from `FrameDescriptionEntry.pc_begin`
        offset: u64 = 0,
        /// Special-case column that defines the CFA (Canonical Frame Address) rule.
        /// The register field of this column defines the register that CFA is derived from.
        cfa: Column = .{},
        /// The register fields in these columns define the register the rule applies to.
        columns: ColumnRange = .{},
        /// Indicates that the next write to any column in this row needs to copy
        /// the backing column storage first, as it may be referenced by previous rows.
        copy_on_write: bool = false,
    };

    pub const Column = struct {
        register: ?u8 = null,
        rule: RegisterRule = .{ .default = {} },

        /// Resolves the register rule and places the result into `out` (see regBytes)
        pub fn resolveValue(
            self: Column,
            context: *SelfInfo.UnwindContext,
            expression_context: std.debug.Dwarf.expression.Context,
            ma: *std.debug.MemoryAccessor,
            out: []u8,
        ) !void {
            switch (self.rule) {
                .default => {
                    const register = self.register orelse return error.InvalidRegister;
                    try getRegDefaultValue(register, context, out);
                },
                .undefined => {
                    @memset(out, undefined);
                },
                .same_value => {
                    // TODO: This copy could be eliminated if callers always copy the state then call this function to update it
                    const register = self.register orelse return error.InvalidRegister;
                    const src = try regBytes(context.thread_context, register, context.reg_context);
                    if (src.len != out.len) return error.RegisterSizeMismatch;
                    @memcpy(out, src);
                },
                .offset => |offset| {
                    if (context.cfa) |cfa| {
                        const addr = try applyOffset(cfa, offset);
                        if (ma.load(usize, addr) == null) return error.InvalidAddress;
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
                    const value = try context.stack_machine.run(expression, context.allocator, expression_context, context.cfa.?);
                    const addr = if (value) |v| blk: {
                        if (v != .generic) return error.InvalidExpressionValue;
                        break :blk v.generic;
                    } else return error.NoExpressionValue;

                    if (ma.load(usize, addr) == null) return error.InvalidExpressionAddress;
                    const ptr: *usize = @ptrFromInt(addr);
                    mem.writeInt(usize, out[0..@sizeOf(usize)], ptr.*, native_endian);
                },
                .val_expression => |expression| {
                    context.stack_machine.reset();
                    const value = try context.stack_machine.run(expression, context.allocator, expression_context, context.cfa.?);
                    if (value) |v| {
                        if (v != .generic) return error.InvalidExpressionValue;
                        mem.writeInt(usize, out[0..@sizeOf(usize)], v.generic, native_endian);
                    } else return error.NoExpressionValue;
                },
                .architectural => return error.UnimplementedRegisterRule,
            }
        }
    };

    const ColumnRange = struct {
        /// Index into `columns` of the first column in this row.
        start: usize = undefined,
        len: u8 = 0,
    };

    columns: std.ArrayListUnmanaged(Column) = .empty,
    stack: std.ArrayListUnmanaged(ColumnRange) = .empty,
    current_row: Row = .{},

    /// The result of executing the CIE's initial_instructions
    cie_row: ?Row = null,

    pub fn deinit(self: *VirtualMachine, allocator: std.mem.Allocator) void {
        self.stack.deinit(allocator);
        self.columns.deinit(allocator);
        self.* = undefined;
    }

    pub fn reset(self: *VirtualMachine) void {
        self.stack.clearRetainingCapacity();
        self.columns.clearRetainingCapacity();
        self.current_row = .{};
        self.cie_row = null;
    }

    /// Return a slice backed by the row's non-CFA columns
    pub fn rowColumns(self: VirtualMachine, row: Row) []Column {
        if (row.columns.len == 0) return &.{};
        return self.columns.items[row.columns.start..][0..row.columns.len];
    }

    /// Either retrieves or adds a column for `register` (non-CFA) in the current row.
    fn getOrAddColumn(self: *VirtualMachine, allocator: std.mem.Allocator, register: u8) !*Column {
        for (self.rowColumns(self.current_row)) |*c| {
            if (c.register == register) return c;
        }

        if (self.current_row.columns.len == 0) {
            self.current_row.columns.start = self.columns.items.len;
        }
        self.current_row.columns.len += 1;

        const column = try self.columns.addOne(allocator);
        column.* = .{
            .register = register,
        };

        return column;
    }

    /// Runs the CIE instructions, then the FDE instructions. Execution halts
    /// once the row that corresponds to `pc` is known, and the row is returned.
    pub fn runTo(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        pc: u64,
        cie: std.debug.Dwarf.CommonInformationEntry,
        fde: std.debug.Dwarf.FrameDescriptionEntry,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Row {
        assert(self.cie_row == null);
        if (pc < fde.pc_begin or pc >= fde.pc_begin + fde.pc_range) return error.AddressOutOfRange;

        var prev_row: Row = self.current_row;

        var cie_stream = std.io.fixedBufferStream(cie.initial_instructions);
        var fde_stream = std.io.fixedBufferStream(fde.instructions);
        var streams = [_]*std.io.FixedBufferStream([]const u8){
            &cie_stream,
            &fde_stream,
        };

        for (&streams, 0..) |stream, i| {
            while (stream.pos < stream.buffer.len) {
                const instruction = try std.debug.Dwarf.call_frame.Instruction.read(stream, addr_size_bytes, endian);
                prev_row = try self.step(allocator, cie, i == 0, instruction);
                if (pc < fde.pc_begin + self.current_row.offset) return prev_row;
            }
        }

        return self.current_row;
    }

    pub fn runToNative(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        pc: u64,
        cie: std.debug.Dwarf.CommonInformationEntry,
        fde: std.debug.Dwarf.FrameDescriptionEntry,
    ) !Row {
        return self.runTo(allocator, pc, cie, fde, @sizeOf(usize), native_endian);
    }

    fn resolveCopyOnWrite(self: *VirtualMachine, allocator: std.mem.Allocator) !void {
        if (!self.current_row.copy_on_write) return;

        const new_start = self.columns.items.len;
        if (self.current_row.columns.len > 0) {
            try self.columns.ensureUnusedCapacity(allocator, self.current_row.columns.len);
            self.columns.appendSliceAssumeCapacity(self.rowColumns(self.current_row));
            self.current_row.columns.start = new_start;
        }
    }

    /// Executes a single instruction.
    /// If this instruction is from the CIE, `is_initial` should be set.
    /// Returns the value of `current_row` before executing this instruction.
    pub fn step(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        cie: std.debug.Dwarf.CommonInformationEntry,
        is_initial: bool,
        instruction: Dwarf.call_frame.Instruction,
    ) !Row {
        // CIE instructions must be run before FDE instructions
        assert(!is_initial or self.cie_row == null);
        if (!is_initial and self.cie_row == null) {
            self.cie_row = self.current_row;
            self.current_row.copy_on_write = true;
        }

        const prev_row = self.current_row;
        switch (instruction) {
            .set_loc => |i| {
                if (i.address <= self.current_row.offset) return error.InvalidOperation;
                // TODO: Check cie.segment_selector_size != 0 for DWARFV4
                self.current_row.offset = i.address;
            },
            inline .advance_loc,
            .advance_loc1,
            .advance_loc2,
            .advance_loc4,
            => |i| {
                self.current_row.offset += i.delta * cie.code_alignment_factor;
                self.current_row.copy_on_write = true;
            },
            inline .offset,
            .offset_extended,
            .offset_extended_sf,
            => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor };
            },
            inline .restore,
            .restore_extended,
            => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.cie_row) |cie_row| {
                    const column = try self.getOrAddColumn(allocator, i.register);
                    column.rule = for (self.rowColumns(cie_row)) |cie_column| {
                        if (cie_column.register == i.register) break cie_column.rule;
                    } else .{ .default = {} };
                } else return error.InvalidOperation;
            },
            .nop => {},
            .undefined => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .undefined = {} };
            },
            .same_value => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .same_value = {} };
            },
            .register => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .register = i.target_register };
            },
            .remember_state => {
                try self.stack.append(allocator, self.current_row.columns);
                self.current_row.copy_on_write = true;
            },
            .restore_state => {
                const restored_columns = self.stack.pop() orelse return error.InvalidOperation;
                self.columns.shrinkRetainingCapacity(self.columns.items.len - self.current_row.columns.len);
                try self.columns.ensureUnusedCapacity(allocator, restored_columns.len);

                self.current_row.columns.start = self.columns.items.len;
                self.current_row.columns.len = restored_columns.len;
                self.columns.appendSliceAssumeCapacity(self.columns.items[restored_columns.start..][0..restored_columns.len]);
            },
            .def_cfa => |i| {
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa = .{
                    .register = i.register,
                    .rule = .{ .val_offset = @intCast(i.offset) },
                };
            },
            .def_cfa_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa = .{
                    .register = i.register,
                    .rule = .{ .val_offset = i.offset * cie.data_alignment_factor },
                };
            },
            .def_cfa_register => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.register = i.register;
            },
            .def_cfa_offset => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.rule = .{
                    .val_offset = @intCast(i.offset),
                };
            },
            .def_cfa_offset_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.rule = .{
                    .val_offset = i.offset * cie.data_alignment_factor,
                };
            },
            .def_cfa_expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa.register = undefined;
                self.current_row.cfa.rule = .{
                    .expression = i.block,
                };
            },
            .expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .expression = i.block,
                };
            },
            .val_offset => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor,
                };
            },
            .val_offset_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_offset = i.offset * cie.data_alignment_factor,
                };
            },
            .val_expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_expression = i.block,
                };
            },
        }

        return prev_row;
    }
};

/// Returns the ABI-defined default value this register has in the unwinding table
/// before running any of the CIE instructions. The DWARF spec defines these as having
/// the .undefined rule by default, but allows ABI authors to override that.
fn getRegDefaultValue(reg_number: u8, context: *UnwindContext, out: []u8) !void {
    switch (builtin.cpu.arch) {
        .aarch64, .aarch64_be => {
            // Callee-saved registers are initialized as if they had the .same_value rule
            if (reg_number >= 19 and reg_number <= 28) {
                const src = try regBytes(context.thread_context, reg_number, context.reg_context);
                if (src.len != out.len) return error.RegisterSizeMismatch;
                @memcpy(out, src);
                return;
            }
        },
        else => {},
    }

    @memset(out, undefined);
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
