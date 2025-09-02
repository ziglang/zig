load_offset: usize,
name: []const u8,
build_id: ?[]const u8,
gnu_eh_frame: ?[]const u8,

/// No cache needed, because `dl_iterate_phdr` is already fast.
pub const LookupCache = void;

pub const DebugInfo = struct {
    loaded_elf: ?Dwarf.ElfModule,
    unwind: ?Dwarf.Unwind,
    pub const init: DebugInfo = .{
        .loaded_elf = null,
        .unwind = null,
    };
    pub fn deinit(di: *DebugInfo, gpa: Allocator) void {
        if (di.loaded_elf) |*loaded_elf| loaded_elf.deinit(gpa);
    }
};

pub fn key(m: ElfModule) usize {
    return m.load_offset;
}
pub fn lookup(cache: *LookupCache, gpa: Allocator, address: usize) !ElfModule {
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
fn loadDwarf(module: *const ElfModule, gpa: Allocator, di: *DebugInfo) !void {
    if (module.name.len > 0) {
        di.loaded_elf = Dwarf.ElfModule.load(gpa, .{
            .root_dir = .cwd(),
            .sub_path = module.name,
        }, module.build_id, null, null, null) catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            error.Overflow => return error.InvalidDebugInfo,
            else => |e| return e,
        };
    } else {
        const path = try std.fs.selfExePathAlloc(gpa);
        defer gpa.free(path);
        di.loaded_elf = Dwarf.ElfModule.load(gpa, .{
            .root_dir = .cwd(),
            .sub_path = path,
        }, module.build_id, null, null, null) catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            error.Overflow => return error.InvalidDebugInfo,
            else => |e| return e,
        };
    }
}
pub fn getSymbolAtAddress(module: *const ElfModule, gpa: Allocator, di: *DebugInfo, address: usize) !std.debug.Symbol {
    if (di.loaded_elf == null) try module.loadDwarf(gpa, di);
    const vaddr = address - module.load_offset;
    return di.loaded_elf.?.dwarf.getSymbol(gpa, native_endian, vaddr);
}
fn loadUnwindInfo(module: *const ElfModule, gpa: Allocator, di: *DebugInfo) !void {
    const section_bytes = module.gnu_eh_frame orelse return error.MissingUnwindInfo; // MLUGG TODO: load from file
    const section_vaddr: u64 = @intFromPtr(section_bytes.ptr) - module.load_offset;
    const header: Dwarf.Unwind.EhFrameHeader = try .parse(section_vaddr, section_bytes, @sizeOf(usize), native_endian);
    di.unwind = .initEhFrameHdr(header, section_vaddr, @ptrFromInt(module.load_offset + header.eh_frame_vaddr));
    try di.unwind.?.prepareLookup(gpa, @sizeOf(usize), native_endian);
}
pub fn unwindFrame(module: *const ElfModule, gpa: Allocator, di: *DebugInfo, context: *UnwindContext) !usize {
    if (di.unwind == null) try module.loadUnwindInfo(gpa, di);
    return context.unwindFrameDwarf(&di.unwind.?, module.load_offset, null);
}

const ElfModule = @This();

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;
const elf = std.elf;
const mem = std.mem;
const UnwindContext = std.debug.SelfInfo.UnwindContext;

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
