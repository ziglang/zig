base_address: usize,
size: usize,
name: []const u8,
handle: windows.HMODULE,
pub fn key(m: WindowsModule) usize {
    return m.base_address;
}
pub fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) std.debug.SelfInfo.Error!WindowsModule {
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
pub fn getSymbolAtAddress(module: *const WindowsModule, gpa: Allocator, di: *DebugInfo, address: usize) std.debug.SelfInfo.Error!std.debug.Symbol {
    if (!di.loaded) module.loadDebugInfo(gpa, di) catch |err| switch (err) {
        error.OutOfMemory, error.InvalidDebugInfo, error.MissingDebugInfo, error.Unexpected => |e| return e,
        error.FileNotFound => return error.MissingDebugInfo,
        error.UnknownPDBVersion => return error.UnsupportedDebugInfo,
        else => return error.ReadFailed,
    };
    // Translate the runtime address into a virtual address into the module
    const vaddr = address - module.base_address;

    if (di.pdb != null) {
        if (di.getSymbolFromPdb(vaddr) catch return error.InvalidDebugInfo) |symbol| return symbol;
    }

    if (di.dwarf) |*dwarf| {
        const dwarf_address = vaddr + di.coff_image_base;
        return dwarf.getSymbol(gpa, native_endian, dwarf_address) catch return error.InvalidDebugInfo;
    }

    return error.MissingDebugInfo;
}
fn lookupInCache(cache: *const LookupCache, address: usize) ?WindowsModule {
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
fn loadDebugInfo(module: *const WindowsModule, gpa: Allocator, di: *DebugInfo) !void {
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
            else => |e| return e,
        };
        try di.pdb.?.parseInfoStream();
        try di.pdb.?.parseDbiStream();

        if (!mem.eql(u8, &coff_obj.guid, &di.pdb.?.guid) or coff_obj.age != di.pdb.?.age)
            return error.InvalidDebugInfo;

        di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(gpa);
    }

    di.loaded = true;
}
pub const LookupCache = struct {
    modules: std.ArrayListUnmanaged(windows.MODULEENTRY32),
    pub const init: LookupCache = .{ .modules = .empty };
    pub fn deinit(lc: *LookupCache, gpa: Allocator) void {
        lc.modules.deinit(gpa);
    }
};
pub const DebugInfo = struct {
    loaded: bool,

    coff_image_base: u64,
    mapped_file: ?struct {
        file: fs.File,
        section_handle: windows.HANDLE,
        section_view: []const u8,
    },

    dwarf: ?Dwarf,

    pdb: ?Pdb,
    /// Populated iff `pdb != null`; otherwise `&.{}`.
    coff_section_headers: []coff.SectionHeader,

    pub const init: DebugInfo = .{
        .loaded = false,
        .coff_image_base = undefined,
        .mapped_file = null,
        .dwarf = null,
        .pdb = null,
        .coff_section_headers = &.{},
    };

    pub fn deinit(di: *DebugInfo, gpa: Allocator) void {
        if (!di.loaded) return;
        if (di.dwarf) |*dwarf| dwarf.deinit(gpa);
        if (di.pdb) |*pdb| pdb.deinit();
        gpa.free(di.coff_section_headers);
        if (di.mapped_file) |mapped| {
            const process_handle = windows.GetCurrentProcess();
            assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @constCast(mapped.section_view.ptr)) == .SUCCESS);
            windows.CloseHandle(mapped.section_handle);
            mapped.file.close();
        }
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

        const module = try di.pdb.?.getModule(mod_index) orelse return error.InvalidDebugInfo;

        return .{
            .name = di.pdb.?.getSymbolName(
                module,
                relocated_address - coff_section.virtual_address,
            ),
            .compile_unit_name = fs.path.basename(module.obj_file_name),
            .source_location = try di.pdb.?.getLineNumberInfo(
                module,
                relocated_address - coff_section.virtual_address,
            ),
        };
    }
};
pub const supports_unwinding: bool = false;

const WindowsModule = @This();

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;
const Pdb = std.debug.Pdb;
const assert = std.debug.assert;
const coff = std.coff;
const fs = std.fs;
const mem = std.mem;
const windows = std.os.windows;

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
