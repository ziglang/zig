load_offset: usize,
name: []const u8,
build_id: ?[]const u8,
gnu_eh_frame: ?[]const u8,

/// No cache needed, because `dl_iterate_phdr` is already fast.
pub const LookupCache = void;

pub const DebugInfo = struct {
    loaded_elf: ?Dwarf.ElfModule,
    unwind: [2]?Dwarf.Unwind,
    pub const init: DebugInfo = .{
        .loaded_elf = null,
        .unwind = @splat(null),
    };
    pub fn deinit(di: *DebugInfo, gpa: Allocator) void {
        if (di.loaded_elf) |*loaded_elf| loaded_elf.deinit(gpa);
    }
};

pub fn key(m: ElfModule) usize {
    return m.load_offset;
}
pub fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) Error!ElfModule {
    _ = cache;
    _ = gpa;
    if (builtin.target.os.tag == .haiku) @panic("TODO implement lookup module for Haiku");
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
fn loadDwarf(module: *const ElfModule, gpa: Allocator, di: *DebugInfo) Error!void {
    const load_result = if (module.name.len > 0) res: {
        break :res Dwarf.ElfModule.load(gpa, .{
            .root_dir = .cwd(),
            .sub_path = module.name,
        }, module.build_id, null, null, null);
    } else res: {
        const path = std.fs.selfExePathAlloc(gpa) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => return error.ReadFailed,
        };
        defer gpa.free(path);
        break :res Dwarf.ElfModule.load(gpa, .{
            .root_dir = .cwd(),
            .sub_path = path,
        }, module.build_id, null, null, null);
    };
    di.loaded_elf = load_result catch |err| switch (err) {
        error.FileNotFound => return error.MissingDebugInfo,

        error.OutOfMemory,
        error.InvalidDebugInfo,
        error.MissingDebugInfo,
        error.Unexpected,
        => |e| return e,

        error.InvalidElfEndian,
        error.InvalidElfMagic,
        error.InvalidElfVersion,
        error.InvalidUtf8,
        error.InvalidWtf8,
        error.EndOfStream,
        error.Overflow,
        error.UnimplementedDwarfForeignEndian, // this should be impossible as we're looking at the debug info for this process
        => return error.InvalidDebugInfo,

        else => return error.ReadFailed,
    };
}
pub fn getSymbolAtAddress(module: *const ElfModule, gpa: Allocator, di: *DebugInfo, address: usize) Error!std.debug.Symbol {
    if (di.loaded_elf == null) try module.loadDwarf(gpa, di);
    const vaddr = address - module.load_offset;
    return di.loaded_elf.?.dwarf.getSymbol(gpa, native_endian, vaddr) catch |err| switch (err) {
        error.InvalidDebugInfo, error.MissingDebugInfo, error.OutOfMemory => |e| return e,
        error.ReadFailed,
        error.EndOfStream,
        error.Overflow,
        error.StreamTooLong,
        => return error.InvalidDebugInfo,
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
        buf[0] = .initEhFrameHdr(header, section_vaddr, @ptrFromInt(module.load_offset + header.eh_frame_vaddr));
        break :unwinds buf[0..1];
    } else unwinds: {
        // There is no `.eh_frame_hdr` section. There may still be an `.eh_frame` or `.debug_frame`
        // section, but we'll have to load the binary to get at it.
        try module.loadDwarf(gpa, di);
        const opt_debug_frame = &di.loaded_elf.?.debug_frame;
        const opt_eh_frame = &di.loaded_elf.?.eh_frame;
        // If both are present, we can't just pick one -- the info could be split between them.
        // `.debug_frame` is likely to be the more complete section, so we'll prioritize that one.
        if (opt_debug_frame.*) |*debug_frame| {
            buf[0] = .initSection(.debug_frame, debug_frame.vaddr, debug_frame.bytes);
            if (opt_eh_frame.*) |*eh_frame| {
                buf[1] = .initSection(.eh_frame, eh_frame.vaddr, eh_frame.bytes);
                break :unwinds buf[0..2];
            }
            break :unwinds buf[0..1];
        } else if (opt_eh_frame.*) |*eh_frame| {
            buf[0] = .initSection(.eh_frame, eh_frame.vaddr, eh_frame.bytes);
            break :unwinds buf[0..1];
        }
        return error.MissingDebugInfo;
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
    if (di.unwind[0] == null) try module.loadUnwindInfo(gpa, di);
    std.debug.assert(di.unwind[0] != null);
    for (&di.unwind) |*opt_unwind| {
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
        std.debug.assert(Dwarf.abi.supportsUnwinding(&builtin.target));
    }
}

const ElfModule = @This();

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;
const elf = std.elf;
const mem = std.mem;
const Error = std.debug.SelfInfo.Error;

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
