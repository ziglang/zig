const Allocator = @import("mem.zig").Allocator;
const io = @import("io.zig");
const os = @import("os.zig");
const elf = @import("elf.zig");
const DW = @import("dwarf.zig");

pub error MissingDebugInfo;
pub error InvalidDebugInfo;
pub error UnsupportedDebugInfo;

pub fn assert(b: bool) {
    if (!b) unreachable{}
}

pub fn printStackTrace() -> %void {
    %return writeStackTrace(&io.stderr);
    %return io.stderr.flush();
}

pub fn writeStackTrace(out_stream: &io.OutStream) -> %void {
    switch (@compileVar("object_format")) {
        elf => {
            var st: ElfStackTrace = undefined;
            %return io.openSelfExe(&st.self_exe_stream);
            defer %return st.self_exe_stream.close();

            %return st.elf.openStream(&global_allocator, &st.self_exe_stream);
            defer %return st.elf.close();

            st.aranges = %return st.elf.findSection(".debug_aranges");
            st.debug_info = (%return st.elf.findSection(".debug_info")) ?? return error.MissingDebugInfo;

            var maybe_fp: ?&const u8 = @frameAddress();
            while (true) {
                const fp = maybe_fp ?? break;
                const return_address = *(&const usize)(usize(fp) + @sizeOf(usize));

                // read .debug_aranges to find out which compile unit the address is in
                const compile_unit_offset = %return findCompileUnitOffset(&st, return_address);

                %return out_stream.printInt(usize, return_address);
                %return out_stream.printf("  -> ");
                %return out_stream.printInt(u64, debug_info_offset);
                %return out_stream.printf("\n");
                maybe_fp = *(&const ?&const u8)(fp);
            }
        },
        coff => {
            out_stream.write("(stack trace unavailable for COFF object format)\n");
        },
        macho => {
            out_stream.write("(stack trace unavailable for Mach-O object format)\n");
        },
        unknown => {
            out_stream.write("(stack trace unavailable for unknown object format)\n");
        },
    }
}

struct ElfStackTrace {
    self_exe_stream: io.InStream,
    elf: elf.Elf,
    aranges: ?&elf.SectionHeader,
    debug_info: &elf.SectionHeader,
}

fn findCompileUnitOffset(st: &ElfStackTrace, target_address: usize) -> %u64 {
    if (const result ?= %return arangesOffset(st, target_address))
        return result;

    // iterate over compile units looking for a match with the low pc and high pc
    %return st.elf.seekToSection(st.debug_info);

    while (true) {
        const tag_id = %return st.self_exe_stream.readByte();
        if (tag_id == DW.TAG_compile_unit) {

        } else {
            
        }
    }
}

fn arangesOffset(st: &ElfStackTrace, target_address: usize) -> %?u64 {
    const aranges = ?return st.aranges;

    %return st.elf.seekToSection(aranges);

    const first_32_bits = %return st.self_exe_stream.readIntLe(u32);
    const is_64 = (first_32_bits == 0xffffffff);
    const unit_length = if (is_64) {
        %return st.self_exe_stream.readIntLe(u64)
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        first_32_bits
    };
    var unit_index: u64 = 0;

    while (unit_index < unit_length) {
        const version = %return st.self_exe_stream.readIntLe(u16);
        if (version != 2) return error.InvalidDebugInfo;
        unit_index += 2;

        const debug_info_offset = if (is_64) {
            unit_index += 4;
            %return st.self_exe_stream.readIntLe(u64)
        } else {
            unit_index += 2;
            %return st.self_exe_stream.readIntLe(u32)
        };

        const address_size = %return st.self_exe_stream.readByte();
        if (address_size > 8) return error.UnsupportedDebugInfo;
        unit_index += 1;

        const segment_size = %return st.self_exe_stream.readByte();
        if (segment_size > 0) return error.UnsupportedDebugInfo;
        unit_index += 1;

        const align = segment_size + 2 * address_size;
        const padding = st.self_exe_stream.offset % align;
        %return st.self_exe_stream.seekForward(padding);
        unit_index += padding;

        while (true) {
            const address = %return st.self_exe_stream.readVarInt(false, u64, address_size);
            const length = %return st.self_exe_stream.readVarInt(false, u64, address_size);
            unit_index += align;
            if (address == 0 && length == 0) break;

            if (target_address >= address && target_address < address + length) {
                return debug_info_offset;
            }
        }
    }

    return error.MissingDebugInfo;
}

pub var global_allocator = Allocator {
    .allocFn = globalAlloc,
    .reallocFn = globalRealloc,
    .freeFn = globalFree,
    .context = null,
};

var some_mem: [10 * 1024]u8 = undefined;
var some_mem_index: usize = 0;

fn globalAlloc(self: &Allocator, n: usize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn globalRealloc(self: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8 {
    const result = %return globalAlloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn globalFree(self: &Allocator, old_mem: []u8) { }
