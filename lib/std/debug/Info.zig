//! Cross-platform abstraction for debug information.

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
const File = std.fs.File;
const math = std.math;
const testing = std.testing;

const Info = @This();

const root = @import("root");

allocator: Allocator,
address_map: std.AutoHashMap(usize, *ModuleDebugInfo),
modules: if (native_os == .windows) std.ArrayListUnmanaged(WindowsModuleInfo) else void,

pub const OpenSelfError = error{
    MissingDebugInfo,
    UnsupportedOperatingSystem,
} || @typeInfo(@typeInfo(@TypeOf(Info.init)).Fn.return_type.?).ErrorUnion.error_set;

pub fn openSelf(allocator: Allocator) OpenSelfError!Info {
    nosuspend {
        if (builtin.strip_debug_info)
            return error.MissingDebugInfo;
        if (@hasDecl(root, "os") and @hasDecl(root.os, "debug") and @hasDecl(root.os.debug, "openSelfDebugInfo")) {
            return root.os.debug.openSelfDebugInfo(allocator);
        }
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
            => return try Info.init(allocator),
            else => return error.UnsupportedOperatingSystem,
        }
    }
}

pub fn init(allocator: Allocator) !Info {
    var debug_info = Info{
        .allocator = allocator,
        .address_map = std.AutoHashMap(usize, *ModuleDebugInfo).init(allocator),
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

pub fn deinit(self: *Info) void {
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

pub fn getModuleForAddress(self: *Info, address: usize) !*ModuleDebugInfo {
    if (comptime builtin.target.isDarwin()) {
        return self.lookupModuleDyld(address);
    } else if (native_os == .windows) {
        return self.lookupModuleWin32(address);
    } else if (native_os == .haiku) {
        return self.lookupModuleHaiku(address);
    } else if (comptime builtin.target.isWasm()) {
        return self.lookupModuleWasm(address);
    } else {
        return self.lookupModuleDl(address);
    }
}

// Returns the module name for a given address.
// This can be called when getModuleForAddress fails, so implementations should provide
// a path that doesn't rely on any side-effects of a prior successful module lookup.
pub fn getModuleNameForAddress(self: *Info, address: usize) ?[]const u8 {
    if (comptime builtin.target.isDarwin()) {
        return self.lookupModuleNameDyld(address);
    } else if (native_os == .windows) {
        return self.lookupModuleNameWin32(address);
    } else if (native_os == .haiku) {
        return null;
    } else if (comptime builtin.target.isWasm()) {
        return null;
    } else {
        return self.lookupModuleNameDl(address);
    }
}

fn lookupModuleDyld(self: *Info, address: usize) !*ModuleDebugInfo {
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
                        if (mem.eql(u8, "__unwind_info", sect.sectName())) {
                            unwind_info = @as([*]const u8, @ptrFromInt(sect.addr + vmaddr_slide))[0..sect.size];
                        } else if (mem.eql(u8, "__eh_frame", sect.sectName())) {
                            eh_frame = @as([*]const u8, @ptrFromInt(sect.addr + vmaddr_slide))[0..sect.size];
                        }
                    }

                    const obj_di = try self.allocator.create(ModuleDebugInfo);
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

fn lookupModuleNameDyld(self: *Info, address: usize) ?[]const u8 {
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

fn lookupModuleWin32(self: *Info, address: usize) !*ModuleDebugInfo {
    for (self.modules.items) |*module| {
        if (address >= module.base_address and address < module.base_address + module.size) {
            if (self.address_map.get(module.base_address)) |obj_di| {
                return obj_di;
            }

            const obj_di = try self.allocator.create(ModuleDebugInfo);
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

fn lookupModuleNameWin32(self: *Info, address: usize) ?[]const u8 {
    for (self.modules.items) |module| {
        if (address >= module.base_address and address < module.base_address + module.size) {
            return module.name;
        }
    }
    return null;
}

fn lookupModuleNameDl(self: *Info, address: usize) ?[]const u8 {
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

fn lookupModuleDl(self: *Info, address: usize) !*ModuleDebugInfo {
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

    const obj_di = try self.allocator.create(ModuleDebugInfo);
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

fn lookupModuleHaiku(self: *Info, address: usize) !*ModuleDebugInfo {
    _ = self;
    _ = address;
    @panic("TODO implement lookup module for Haiku");
}

fn lookupModuleWasm(self: *Info, address: usize) !*ModuleDebugInfo {
    _ = self;
    _ = address;
    @panic("TODO implement lookup module for Wasm");
}

pub const ModuleDebugInfo = switch (native_os) {
    .macos, .ios, .watchos, .tvos, .visionos => struct {
        base_address: usize,
        vmaddr_slide: usize,
        mapped_memory: []align(mem.page_size) const u8,
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
                inline for (@typeInfo(Dwarf.Section.Id).Enum.fields, 0..) |section, i| {
                    if (mem.eql(u8, "__" ++ section.name, sect.sectName())) section_index = i;
                }
                if (section_index == null) continue;

                const section_bytes = try chopSlice(mapped_mem, sect.offset, sect.size);
                sections[section_index.?] = .{
                    .data = section_bytes,
                    .virtual_address = sect.addr,
                    .owned = false,
                };
            }

            const missing_debug_info =
                sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
                sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
                sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
                sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;
            if (missing_debug_info) return error.MissingDebugInfo;

            var di = Dwarf{
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

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !SymbolInfo {
            nosuspend {
                const result = try self.getOFileInfoForAddress(allocator, address);
                if (result.symbol == null) return .{};

                // Take the symbol name from the N_FUN STAB entry, we're going to
                // use it if we fail to find the DWARF infos
                const stab_symbol = mem.sliceTo(self.strings[result.symbol.?.strx..], 0);
                if (result.o_file_info == null) return .{ .symbol_name = stab_symbol };

                // Translate again the address, this time into an address inside the
                // .o file
                const relocated_address_o = result.o_file_info.?.addr_table.get(stab_symbol) orelse return .{
                    .symbol_name = "???",
                };

                const addr_off = result.relocated_address - result.symbol.?.addr;
                const o_file_di = &result.o_file_info.?.di;
                if (o_file_di.findCompileUnit(relocated_address_o)) |compile_unit| {
                    return SymbolInfo{
                        .symbol_name = o_file_di.getSymbolName(relocated_address_o) orelse "???",
                        .compile_unit_name = compile_unit.die.getAttrString(
                            o_file_di,
                            std.dwarf.AT.name,
                            o_file_di.section(.debug_str),
                            compile_unit.*,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                        },
                        .line_info = o_file_di.getLineNumberInfo(
                            allocator,
                            compile_unit.*,
                            relocated_address_o + addr_off,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => null,
                            else => return err,
                        },
                    };
                } else |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => {
                        return SymbolInfo{ .symbol_name = stab_symbol };
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

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*const Dwarf {
            return if ((try self.getOFileInfoForAddress(allocator, address)).o_file_info) |o_file_info| &o_file_info.di else null;
        }
    },
    .uefi, .windows => struct {
        base_address: usize,
        pdb: ?pdb.Pdb = null,
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

        fn getSymbolFromPdb(self: *@This(), relocated_address: usize) !?SymbolInfo {
            var coff_section: *align(1) const coff.SectionHeader = undefined;
            const mod_index = for (self.pdb.?.sect_contribs) |sect_contrib| {
                if (sect_contrib.Section > self.coff_section_headers.len) continue;
                // Remember that SectionContribEntry.Section is 1-based.
                coff_section = &self.coff_section_headers[sect_contrib.Section - 1];

                const vaddr_start = coff_section.virtual_address + sect_contrib.Offset;
                const vaddr_end = vaddr_start + sect_contrib.Size;
                if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                    break sect_contrib.ModuleIndex;
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

            return SymbolInfo{
                .symbol_name = symbol_name,
                .compile_unit_name = obj_basename,
                .line_info = opt_line_info,
            };
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;

            if (self.pdb != null) {
                if (try self.getSymbolFromPdb(relocated_address)) |symbol| return symbol;
            }

            if (self.dwarf) |*dwarf| {
                const dwarf_address = relocated_address + self.coff_image_base;
                return getSymbolFromDwarf(allocator, dwarf_address, dwarf);
            }

            return SymbolInfo{};
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*const Dwarf {
            _ = allocator;
            _ = address;

            return switch (self.debug_data) {
                .dwarf => |*dwarf| dwarf,
                else => null,
            };
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris, .illumos => struct {
        base_address: usize,
        dwarf: Dwarf,
        mapped_memory: []align(mem.page_size) const u8,
        external_mapped_memory: ?[]align(mem.page_size) const u8,

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.dwarf.deinit(allocator);
            posix.munmap(self.mapped_memory);
            if (self.external_mapped_memory) |m| posix.munmap(m);
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;
            return getSymbolFromDwarf(allocator, relocated_address, &self.dwarf);
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*const Dwarf {
            _ = allocator;
            _ = address;
            return &self.dwarf;
        }
    },
    .wasi, .emscripten => struct {
        pub fn deinit(self: *@This(), allocator: Allocator) void {
            _ = self;
            _ = allocator;
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !SymbolInfo {
            _ = self;
            _ = allocator;
            _ = address;
            return SymbolInfo{};
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*const Dwarf {
            _ = self;
            _ = allocator;
            _ = address;
            return null;
        }
    },
    else => Dwarf,
};

pub const WindowsModuleInfo = struct {
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
fn readMachODebugInfo(allocator: Allocator, macho_file: File) !ModuleDebugInfo {
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

    return ModuleDebugInfo{
        .base_address = undefined,
        .vmaddr_slide = undefined,
        .mapped_memory = mapped_mem,
        .ofiles = ModuleDebugInfo.OFileTable.init(allocator),
        .symbols = symbols,
        .strings = strings,
    };
}

fn readCoffDebugInfo(allocator: Allocator, coff_obj: *coff.Coff) !ModuleDebugInfo {
    nosuspend {
        var di = ModuleDebugInfo{
            .base_address = undefined,
            .coff_image_base = coff_obj.getImageBase(),
            .coff_section_headers = undefined,
        };

        if (coff_obj.getSectionByName(".debug_info")) |_| {
            // This coff file has embedded DWARF debug info
            var sections: Dwarf.SectionArray = Dwarf.null_section_array;
            errdefer for (sections) |section| if (section) |s| if (s.owned) allocator.free(s.data);

            inline for (@typeInfo(Dwarf.Section.Id).Enum.fields, 0..) |section, i| {
                sections[i] = if (coff_obj.getSectionByName("." ++ section.name)) |section_header| blk: {
                    break :blk .{
                        .data = try coff_obj.getSectionDataAlloc(section_header, allocator),
                        .virtual_address = section_header.virtual_address,
                        .owned = true,
                    };
                } else null;
            }

            var dwarf = Dwarf{
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

        di.pdb = pdb.Pdb.init(allocator, path) catch |err| switch (err) {
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
    parent_mapped_mem: ?[]align(mem.page_size) const u8,
) !ModuleDebugInfo {
    nosuspend {
        const elf_file = (if (elf_filename) |filename| blk: {
            break :blk fs.cwd().openFile(filename, .{});
        } else fs.openSelfExe(.{})) catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            else => return err,
        };

        const mapped_mem = try mapWholeFile(elf_file);
        if (expected_crc) |crc| if (crc != std.hash.crc.Crc32.hash(mapped_mem)) return error.InvalidDebugInfo;

        const hdr: *const elf.Ehdr = @ptrCast(&mapped_mem[0]);
        if (!mem.eql(u8, hdr.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
        if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

        const endian: std.builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
            elf.ELFDATA2LSB => .little,
            elf.ELFDATA2MSB => .big,
            else => return error.InvalidElfEndian,
        };
        assert(endian == native_endian); // this is our own debug info

        const shoff = hdr.e_shoff;
        const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
        const str_shdr: *const elf.Shdr = @ptrCast(@alignCast(&mapped_mem[math.cast(usize, str_section_off) orelse return error.Overflow]));
        const header_strings = mapped_mem[str_shdr.sh_offset..][0..str_shdr.sh_size];
        const shdrs = @as(
            [*]const elf.Shdr,
            @ptrCast(@alignCast(&mapped_mem[shoff])),
        )[0..hdr.e_shnum];

        var sections: Dwarf.SectionArray = Dwarf.null_section_array;

        // Combine section list. This takes ownership over any owned sections from the parent scope.
        for (parent_sections, &sections) |*parent, *section| {
            if (parent.*) |*p| {
                section.* = p.*;
                p.owned = false;
            }
        }
        errdefer for (sections) |section| if (section) |s| if (s.owned) allocator.free(s.data);

        var separate_debug_filename: ?[]const u8 = null;
        var separate_debug_crc: ?u32 = null;

        for (shdrs) |*shdr| {
            if (shdr.sh_type == elf.SHT_NULL or shdr.sh_type == elf.SHT_NOBITS) continue;
            const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);

            if (mem.eql(u8, name, ".gnu_debuglink")) {
                const gnu_debuglink = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                const debug_filename = mem.sliceTo(@as([*:0]const u8, @ptrCast(gnu_debuglink.ptr)), 0);
                const crc_offset = mem.alignForward(usize, @intFromPtr(&debug_filename[debug_filename.len]) + 1, 4) - @intFromPtr(gnu_debuglink.ptr);
                const crc_bytes = gnu_debuglink[crc_offset..][0..4];
                separate_debug_crc = mem.readInt(u32, crc_bytes, native_endian);
                separate_debug_filename = debug_filename;
                continue;
            }

            var section_index: ?usize = null;
            inline for (@typeInfo(Dwarf.Section.Id).Enum.fields, 0..) |section, i| {
                if (mem.eql(u8, "." ++ section.name, name)) section_index = i;
            }
            if (section_index == null) continue;
            if (sections[section_index.?] != null) continue;

            const section_bytes = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            sections[section_index.?] = if ((shdr.sh_flags & elf.SHF_COMPRESSED) > 0) blk: {
                var section_stream = std.io.fixedBufferStream(section_bytes);
                var section_reader = section_stream.reader();
                const chdr = section_reader.readStruct(elf.Chdr) catch continue;
                if (chdr.ch_type != .ZLIB) continue;

                var zlib_stream = std.compress.zlib.decompressor(section_stream.reader());

                const decompressed_section = try allocator.alloc(u8, chdr.ch_size);
                errdefer allocator.free(decompressed_section);

                const read = zlib_stream.reader().readAll(decompressed_section) catch continue;
                assert(read == decompressed_section.len);

                break :blk .{
                    .data = decompressed_section,
                    .virtual_address = shdr.sh_addr,
                    .owned = true,
                };
            } else .{
                .data = section_bytes,
                .virtual_address = shdr.sh_addr,
                .owned = false,
            };
        }

        const missing_debug_info =
            sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;

        // Attempt to load debug info from an external file
        // See: https://sourceware.org/gdb/onlinedocs/gdb/Separate-Debug-Files.html
        if (missing_debug_info) {

            // Only allow one level of debug info nesting
            if (parent_mapped_mem) |_| {
                return error.MissingDebugInfo;
            }

            const global_debug_directories = [_][]const u8{
                "/usr/lib/debug",
            };

            // <global debug directory>/.build-id/<2-character id prefix>/<id remainder>.debug
            if (build_id) |id| blk: {
                if (id.len < 3) break :blk;

                // Either md5 (16 bytes) or sha1 (20 bytes) are used here in practice
                const extension = ".debug";
                var id_prefix_buf: [2]u8 = undefined;
                var filename_buf: [38 + extension.len]u8 = undefined;

                _ = std.fmt.bufPrint(&id_prefix_buf, "{s}", .{std.fmt.fmtSliceHexLower(id[0..1])}) catch unreachable;
                const filename = std.fmt.bufPrint(
                    &filename_buf,
                    "{s}" ++ extension,
                    .{std.fmt.fmtSliceHexLower(id[1..])},
                ) catch break :blk;

                for (global_debug_directories) |global_directory| {
                    const path = try fs.path.join(allocator, &.{ global_directory, ".build-id", &id_prefix_buf, filename });
                    defer allocator.free(path);

                    return readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem) catch continue;
                }
            }

            // use the path from .gnu_debuglink, in the same search order as gdb
            if (separate_debug_filename) |separate_filename| blk: {
                if (elf_filename != null and mem.eql(u8, elf_filename.?, separate_filename)) return error.MissingDebugInfo;

                // <cwd>/<gnu_debuglink>
                if (readElfDebugInfo(allocator, separate_filename, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}

                // <cwd>/.debug/<gnu_debuglink>
                {
                    const path = try fs.path.join(allocator, &.{ ".debug", separate_filename });
                    defer allocator.free(path);

                    if (readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }

                var cwd_buf: [fs.max_path_bytes]u8 = undefined;
                const cwd_path = posix.realpath(".", &cwd_buf) catch break :blk;

                // <global debug directory>/<absolute folder of current binary>/<gnu_debuglink>
                for (global_debug_directories) |global_directory| {
                    const path = try fs.path.join(allocator, &.{ global_directory, cwd_path, separate_filename });
                    defer allocator.free(path);
                    if (readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }
            }

            return error.MissingDebugInfo;
        }

        var di = Dwarf{
            .endian = endian,
            .sections = sections,
            .is_macho = false,
        };

        try Dwarf.open(&di, allocator);

        return ModuleDebugInfo{
            .base_address = undefined,
            .dwarf = di,
            .mapped_memory = parent_mapped_mem orelse mapped_mem,
            .external_mapped_memory = if (parent_mapped_mem != null) mapped_mem else null,
        };
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
fn mapWholeFile(file: File) ![]align(mem.page_size) const u8 {
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

fn chopSlice(ptr: []const u8, offset: u64, size: u64) error{Overflow}![]const u8 {
    const start = math.cast(usize, offset) orelse return error.Overflow;
    const end = start + (math.cast(usize, size) orelse return error.Overflow);
    return ptr[start..end];
}

pub const SymbolInfo = struct {
    symbol_name: []const u8 = "???",
    compile_unit_name: []const u8 = "???",
    line_info: ?SourceLocation = null,

    pub fn deinit(self: SymbolInfo, allocator: Allocator) void {
        if (self.line_info) |li| {
            li.deinit(allocator);
        }
    }
};

pub const SourceLocation = struct {
    line: u64,
    column: u64,
    file_name: []const u8,

    pub fn deinit(self: SourceLocation, allocator: Allocator) void {
        allocator.free(self.file_name);
    }
};

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

fn getSymbolFromDwarf(allocator: Allocator, address: u64, di: *Dwarf) !SymbolInfo {
    if (nosuspend di.findCompileUnit(address)) |compile_unit| {
        return SymbolInfo{
            .symbol_name = nosuspend di.getSymbolName(address) orelse "???",
            .compile_unit_name = compile_unit.die.getAttrString(di, std.dwarf.AT.name, di.section(.debug_str), compile_unit.*) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => "???",
            },
            .line_info = nosuspend di.getLineNumberInfo(allocator, compile_unit.*, address) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => null,
                else => return err,
            },
        };
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            return SymbolInfo{};
        },
        else => return err,
    }
}
