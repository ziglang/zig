load_offset: usize,
name: []const u8,
build_id: ?[]const u8,
gnu_eh_frame: ?[]const u8,

/// No cache needed, because `dl_iterate_phdr` is already fast.
pub const LookupCache = void;

pub const DebugInfo = struct {
    /// Held while checking and/or populating `loaded_elf`/`scanned_dwarf`/`unwind`.
    /// Once data is populated and a pointer to the field has been gotten, the lock
    /// is released; i.e. it is not held while *using* the loaded debug info.
    mutex: std.Thread.Mutex,

    loaded_elf: ?ElfFile,
    scanned_dwarf: bool,
    unwind: [2]?Dwarf.Unwind,
    pub const init: DebugInfo = .{
        .mutex = .{},
        .loaded_elf = null,
        .scanned_dwarf = false,
        .unwind = @splat(null),
    };
    pub fn deinit(di: *DebugInfo, gpa: Allocator) void {
        if (di.loaded_elf) |*loaded_elf| loaded_elf.deinit(gpa);
        for (di.unwind) |*opt_unwind| {
            const unwind = &(opt_unwind orelse continue);
            unwind.deinit(gpa);
        }
    }
};

pub fn key(m: ElfModule) usize {
    return m.load_offset;
}
pub fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) Error!ElfModule {
    _ = cache;
    _ = gpa;
    const DlIterContext = struct {
        /// input
        address: usize,
        /// output
        module: ElfModule,

        fn callback(info: *std.posix.dl_phdr_info, size: usize, context: *@This()) !void {
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
    std.posix.dl_iterate_phdr(&ctx, error{Found}, DlIterContext.callback) catch |err| switch (err) {
        error.Found => return ctx.module,
    };
    return error.MissingDebugInfo;
}
fn loadElf(module: *const ElfModule, gpa: Allocator, di: *DebugInfo) Error!void {
    std.debug.assert(di.loaded_elf == null);
    std.debug.assert(!di.scanned_dwarf);

    const load_result = if (module.name.len > 0) res: {
        var file = std.fs.cwd().openFile(module.name, .{}) catch return error.MissingDebugInfo;
        defer file.close();
        break :res ElfFile.load(gpa, file, module.build_id, &.native(module.name));
    } else res: {
        const path = std.fs.selfExePathAlloc(gpa) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => return error.ReadFailed,
        };
        defer gpa.free(path);
        var file = std.fs.cwd().openFile(path, .{}) catch return error.MissingDebugInfo;
        defer file.close();
        break :res ElfFile.load(gpa, file, module.build_id, &.native(path));
    };
    di.loaded_elf = load_result catch |err| switch (err) {
        error.OutOfMemory,
        error.Unexpected,
        => |e| return e,

        error.Overflow,
        error.TruncatedElfFile,
        error.InvalidCompressedSection,
        error.InvalidElfMagic,
        error.InvalidElfVersion,
        error.InvalidElfClass,
        error.InvalidElfEndian,
        => return error.InvalidDebugInfo,

        error.SystemResources,
        error.MemoryMappingNotSupported,
        error.AccessDenied,
        error.LockedMemoryLimitExceeded,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        => return error.ReadFailed,
    };

    const matches_native =
        di.loaded_elf.?.endian == native_endian and
        di.loaded_elf.?.is_64 == (@sizeOf(usize) == 8);

    if (!matches_native) {
        di.loaded_elf.?.deinit(gpa);
        di.loaded_elf = null;
        return error.InvalidDebugInfo;
    }
}
pub fn getSymbolAtAddress(module: *const ElfModule, gpa: Allocator, di: *DebugInfo, address: usize) Error!std.debug.Symbol {
    const vaddr = address - module.load_offset;
    {
        di.mutex.lock();
        defer di.mutex.unlock();
        if (di.loaded_elf == null) try module.loadElf(gpa, di);
        const loaded_elf = &di.loaded_elf.?;
        // We need the lock if using DWARF, as we might scan the DWARF or build a line number table.
        if (loaded_elf.dwarf) |*dwarf| {
            if (!di.scanned_dwarf) {
                dwarf.open(gpa, native_endian) catch |err| switch (err) {
                    error.InvalidDebugInfo,
                    error.MissingDebugInfo,
                    error.OutOfMemory,
                    => |e| return e,
                    error.EndOfStream,
                    error.Overflow,
                    error.ReadFailed,
                    error.StreamTooLong,
                    => return error.InvalidDebugInfo,
                };
                di.scanned_dwarf = true;
            }
            return dwarf.getSymbol(gpa, native_endian, vaddr) catch |err| switch (err) {
                error.InvalidDebugInfo,
                error.MissingDebugInfo,
                error.OutOfMemory,
                => |e| return e,
                error.ReadFailed,
                error.EndOfStream,
                error.Overflow,
                error.StreamTooLong,
                => return error.InvalidDebugInfo,
            };
        }
        // Otherwise, we're just going to scan the symtab, which we don't need the lock for; fall out of this block.
    }
    // When there's no DWARF available, fall back to searching the symtab.
    return di.loaded_elf.?.searchSymtab(gpa, vaddr) catch |err| switch (err) {
        error.NoSymtab, error.NoStrtab => return error.MissingDebugInfo,
        error.BadSymtab => return error.InvalidDebugInfo,
        error.OutOfMemory => |e| return e,
    };
}
fn prepareUnwindLookup(unwind: *Dwarf.Unwind, gpa: Allocator) Error!void {
    unwind.prepareLookup(gpa, @sizeOf(usize), native_endian) catch |err| switch (err) {
        error.ReadFailed => unreachable, // it's all fixed buffers
        error.InvalidDebugInfo, error.MissingDebugInfo, error.OutOfMemory => |e| return e,
        error.EndOfStream, error.Overflow, error.StreamTooLong => return error.InvalidDebugInfo,
        error.UnsupportedAddrSize, error.UnsupportedDwarfVersion => return error.UnsupportedDebugInfo,
    };
}
fn loadUnwindInfo(module: *const ElfModule, gpa: Allocator, di: *DebugInfo) Error!void {
    var buf: [2]Dwarf.Unwind = undefined;
    const unwinds: []Dwarf.Unwind = if (module.gnu_eh_frame) |section_bytes| unwinds: {
        const section_vaddr: u64 = @intFromPtr(section_bytes.ptr) - module.load_offset;
        const header = Dwarf.Unwind.EhFrameHeader.parse(section_vaddr, section_bytes, @sizeOf(usize), native_endian) catch |err| switch (err) {
            error.ReadFailed => unreachable, // it's all fixed buffers
            error.InvalidDebugInfo => |e| return e,
            error.EndOfStream, error.Overflow => return error.InvalidDebugInfo,
            error.UnsupportedAddrSize => return error.UnsupportedDebugInfo,
        };
        buf[0] = .initEhFrameHdr(header, section_vaddr, @ptrFromInt(@as(usize, @intCast(module.load_offset + header.eh_frame_vaddr))));
        break :unwinds buf[0..1];
    } else unwinds: {
        // There is no `.eh_frame_hdr` section. There may still be an `.eh_frame` or `.debug_frame`
        // section, but we'll have to load the binary to get at it.
        if (di.loaded_elf == null) try module.loadElf(gpa, di);
        const opt_debug_frame = &di.loaded_elf.?.debug_frame;
        const opt_eh_frame = &di.loaded_elf.?.eh_frame;
        var i: usize = 0;
        // If both are present, we can't just pick one -- the info could be split between them.
        // `.debug_frame` is likely to be the more complete section, so we'll prioritize that one.
        if (opt_debug_frame.*) |*debug_frame| {
            buf[i] = .initSection(.debug_frame, debug_frame.vaddr, debug_frame.bytes);
            i += 1;
        }
        if (opt_eh_frame.*) |*eh_frame| {
            buf[i] = .initSection(.eh_frame, eh_frame.vaddr, eh_frame.bytes);
            i += 1;
        }
        if (i == 0) return error.MissingDebugInfo;
        break :unwinds buf[0..i];
    };
    errdefer for (unwinds) |*u| u.deinit(gpa);
    for (unwinds) |*u| try prepareUnwindLookup(u, gpa);
    switch (unwinds.len) {
        0 => unreachable,
        1 => di.unwind = .{ unwinds[0], null },
        2 => di.unwind = .{ unwinds[0], unwinds[1] },
        else => unreachable,
    }
}
pub fn unwindFrame(module: *const ElfModule, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) Error!usize {
    const unwinds: *const [2]?Dwarf.Unwind = u: {
        di.mutex.lock();
        defer di.mutex.unlock();
        if (di.unwind[0] == null) try module.loadUnwindInfo(gpa, di);
        std.debug.assert(di.unwind[0] != null);
        break :u &di.unwind;
    };
    for (unwinds) |*opt_unwind| {
        const unwind = &(opt_unwind.* orelse break);
        return context.unwindFrame(gpa, unwind, module.load_offset, null) catch |err| switch (err) {
            error.MissingDebugInfo => continue, // try the next one
            else => |e| return e,
        };
    }
    return error.MissingDebugInfo;
}
pub const UnwindContext = std.debug.SelfInfo.DwarfUnwindContext;
pub const supports_unwinding: bool = s: {
    const archs: []const std.Target.Cpu.Arch = switch (builtin.target.os.tag) {
        .linux => &.{ .x86, .x86_64, .arm, .armeb, .thumb, .thumbeb, .aarch64, .aarch64_be },
        .netbsd => &.{ .x86, .x86_64, .aarch64, .aarch64_be },
        .freebsd => &.{ .x86_64, .aarch64, .aarch64_be },
        .openbsd => &.{.x86_64},
        .solaris => &.{ .x86, .x86_64 },
        .illumos => &.{ .x86, .x86_64 },
        else => unreachable,
    };
    for (archs) |a| {
        if (builtin.target.cpu.arch == a) break :s true;
    }
    break :s false;
};
comptime {
    if (supports_unwinding) {
        std.debug.assert(Dwarf.supportsUnwinding(&builtin.target));
    }
}

const ElfModule = @This();

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;
const ElfFile = std.debug.ElfFile;
const elf = std.elf;
const mem = std.mem;
const Error = std.debug.SelfInfo.Error;

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
