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
        var section_view_ptr: ?[*]const u8 = null;
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
        errdefer assert(windows.ntdll.NtUnmapViewOfSection(process_handle, @constCast(section_view_ptr.?)) == .SUCCESS);
        const section_view = section_view_ptr.?[0..coff_len];
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

    if (coff_obj.getPdbPath() catch return error.InvalidDebugInfo) |raw_path| pdb: {
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

        const pdb_file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound, error.IsDir => break :pdb,
            else => |e| return e,
        };
        errdefer pdb_file.close();

        const pdb_reader = try gpa.create(std.fs.File.Reader);
        errdefer gpa.destroy(pdb_reader);

        pdb_reader.* = pdb_file.reader(try gpa.alloc(u8, 4096));
        errdefer gpa.free(pdb_reader.interface.buffer);

        var pdb: Pdb = try .init(gpa, pdb_reader);
        errdefer pdb.deinit();
        try pdb.parseInfoStream();
        try pdb.parseDbiStream();

        if (!mem.eql(u8, &coff_obj.guid, &pdb.guid) or coff_obj.age != pdb.age)
            return error.InvalidDebugInfo;

        di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(gpa);

        di.pdb = pdb;
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
        if (di.pdb) |*pdb| {
            pdb.file_reader.file.close();
            gpa.free(pdb.file_reader.interface.buffer);
            gpa.destroy(pdb.file_reader);
            pdb.deinit();
        }
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

pub const supports_unwinding: bool = switch (builtin.cpu.arch) {
    else => true,
    // On x86, `RtlVirtualUnwind` does not exist. We could in theory use `RtlCaptureStackBackTrace`
    // instead, but on x86, it turns out that function is just... doing FP unwinding with esp! It's
    // hard to find implementation details to confirm that, but the most authoritative source I have
    // is an entry in the LLVM mailing list from 2020/08/16 which contains this quote:
    //
    // > x86 doesn't have what most architectures would consider an "unwinder" in the sense of
    // > restoring registers; there is simply a linked list of frames that participate in SEH and
    // > that desire to be called for a dynamic unwind operation, so RtlCaptureStackBackTrace
    // > assumes that EBP-based frames are in use and walks an EBP-based frame chain on x86 - not
    // > all x86 code is written with EBP-based frames so while even though we generally build the
    // > OS that way, you might always run the risk of encountering external code that uses EBP as a
    // > general purpose register for which such an unwind attempt for a stack trace would fail.
    //
    // Regardless, it's easy to effectively confirm this hypothesis just by compiling some code with
    // `-fomit-frame-pointer -OReleaseFast` and observing that `RtlCaptureStackBackTrace` returns an
    // empty trace when it's called in such an application. Note that without `-OReleaseFast` or
    // similar, LLVM seems reluctant to ever clobber ebp, so you'll get a trace returned which just
    // contains all of the kernel32/ntdll frames but none of your own. Don't be deceived---this is
    // just coincidental!
    //
    // Anyway, the point is, the only stack walking primitive on x86-windows is FP unwinding. We
    // *could* ask Microsoft to do that for us with `RtlCaptureStackBackTrace`... but better to just
    // use our existing FP unwinder in `std.debug`!
    .x86 => false,
};
pub const UnwindContext = struct {
    pc: usize,
    cur: windows.CONTEXT,
    history_table: windows.UNWIND_HISTORY_TABLE,
    pub fn init(ctx: *const std.debug.cpu_context.Native) UnwindContext {
        return .{
            .pc = @returnAddress(),
            .cur = switch (builtin.cpu.arch) {
                .x86_64 => std.mem.zeroInit(windows.CONTEXT, .{
                    .Rax = ctx.gprs.get(.rax),
                    .Rcx = ctx.gprs.get(.rcx),
                    .Rdx = ctx.gprs.get(.rdx),
                    .Rbx = ctx.gprs.get(.rbx),
                    .Rsp = ctx.gprs.get(.rsp),
                    .Rbp = ctx.gprs.get(.rbp),
                    .Rsi = ctx.gprs.get(.rsi),
                    .Rdi = ctx.gprs.get(.rdi),
                    .R8 = ctx.gprs.get(.r8),
                    .R9 = ctx.gprs.get(.r9),
                    .R10 = ctx.gprs.get(.r10),
                    .R11 = ctx.gprs.get(.r11),
                    .R12 = ctx.gprs.get(.r12),
                    .R13 = ctx.gprs.get(.r13),
                    .R14 = ctx.gprs.get(.r14),
                    .R15 = ctx.gprs.get(.r15),
                    .Rip = ctx.gprs.get(.rip),
                }),
                .aarch64, .aarch64_be => .{
                    .ContextFlags = 0,
                    .Cpsr = 0,
                    .DUMMYUNIONNAME = .{ .X = ctx.x },
                    .Sp = ctx.sp,
                    .Pc = ctx.pc,
                    .V = @splat(.{ .B = @splat(0) }),
                    .Fpcr = 0,
                    .Fpsr = 0,
                    .Bcr = @splat(0),
                    .Bvr = @splat(0),
                    .Wcr = @splat(0),
                    .Wvr = @splat(0),
                },
                else => comptime unreachable,
            },
            .history_table = std.mem.zeroes(windows.UNWIND_HISTORY_TABLE),
        };
    }
    pub fn deinit(ctx: *UnwindContext, gpa: Allocator) void {
        _ = ctx;
        _ = gpa;
    }
    pub fn getFp(ctx: *UnwindContext) usize {
        return ctx.cur.getRegs().bp;
    }
};
pub fn unwindFrame(module: *const WindowsModule, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) !usize {
    _ = module;
    _ = gpa;
    _ = di;

    const current_regs = context.cur.getRegs();
    var image_base: windows.DWORD64 = undefined;
    if (windows.ntdll.RtlLookupFunctionEntry(current_regs.ip, &image_base, &context.history_table)) |runtime_function| {
        var handler_data: ?*anyopaque = null;
        var establisher_frame: u64 = undefined;
        _ = windows.ntdll.RtlVirtualUnwind(
            windows.UNW_FLAG_NHANDLER,
            image_base,
            current_regs.ip,
            runtime_function,
            &context.cur,
            &handler_data,
            &establisher_frame,
            null,
        );
    } else {
        // leaf function
        context.cur.setIp(@as(*const usize, @ptrFromInt(current_regs.sp)).*);
        context.cur.setSp(current_regs.sp + @sizeOf(usize));
    }

    const next_regs = context.cur.getRegs();
    const tib = &windows.teb().NtTib;
    if (next_regs.sp < @intFromPtr(tib.StackLimit) or next_regs.sp > @intFromPtr(tib.StackBase)) {
        return 0;
    }
    context.pc = next_regs.ip -| 1;
    return next_regs.ip;
}

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
