//! Temporary, dynamically allocated structures used only during flush.
//! Could be constructed fresh each time, or kept around between updates to reduce heap allocations.

const Flush = @This();
const Wasm = @import("../Wasm.zig");
const Object = @import("Object.zig");
const Zcu = @import("../../Zcu.zig");
const Alignment = Wasm.Alignment;
const String = Wasm.String;
const Relocation = Wasm.Relocation;
const InternPool = @import("../../InternPool.zig");

const build_options = @import("build_options");

const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const leb = std.leb;
const log = std.log.scoped(.link);
const assert = std.debug.assert;

/// Ordered list of data segments that will appear in the final binary.
/// When sorted, to-be-merged segments will be made adjacent.
/// Values are virtual address.
data_segments: std.AutoArrayHashMapUnmanaged(Wasm.DataSegmentId, u32) = .empty,
/// Each time a `data_segment` offset equals zero it indicates a new group, and
/// the next element in this array will contain the total merged segment size.
/// Value is the virtual memory address of the end of the segment.
data_segment_groups: std.ArrayListUnmanaged(DataSegmentGroup) = .empty,

binary_bytes: std.ArrayListUnmanaged(u8) = .empty,
missing_exports: std.AutoArrayHashMapUnmanaged(String, void) = .empty,
function_imports: std.AutoArrayHashMapUnmanaged(String, Wasm.FunctionImportId) = .empty,
global_imports: std.AutoArrayHashMapUnmanaged(String, Wasm.GlobalImportId) = .empty,
data_imports: std.AutoArrayHashMapUnmanaged(String, Wasm.DataImportId) = .empty,

indirect_function_table: std.AutoArrayHashMapUnmanaged(Wasm.OutputFunctionIndex, void) = .empty,

/// A subset of the full interned function type list created only during flush.
func_types: std.AutoArrayHashMapUnmanaged(Wasm.FunctionType.Index, void) = .empty,

/// For debug purposes only.
memory_layout_finished: bool = false,

/// Index into `func_types`.
pub const FuncTypeIndex = enum(u32) {
    _,

    pub fn fromTypeIndex(i: Wasm.FunctionType.Index, f: *const Flush) FuncTypeIndex {
        return @enumFromInt(f.func_types.getIndex(i).?);
    }
};

/// Index into `indirect_function_table`.
const IndirectFunctionTableIndex = enum(u32) {
    _,

    fn fromObjectFunctionHandlingWeak(wasm: *const Wasm, index: Wasm.ObjectFunctionIndex) IndirectFunctionTableIndex {
        return fromOutputFunctionIndex(&wasm.flush_buffer, .fromObjectFunctionHandlingWeak(wasm, index));
    }

    fn fromSymbolName(wasm: *const Wasm, name: String) IndirectFunctionTableIndex {
        return fromOutputFunctionIndex(&wasm.flush_buffer, .fromSymbolName(wasm, name));
    }

    fn fromOutputFunctionIndex(f: *const Flush, i: Wasm.OutputFunctionIndex) IndirectFunctionTableIndex {
        return @enumFromInt(f.indirect_function_table.getIndex(i).?);
    }

    fn fromZcuIndirectFunctionSetIndex(i: Wasm.ZcuIndirectFunctionSetIndex) IndirectFunctionTableIndex {
        // These are the same since those are added to the table first.
        return @enumFromInt(@intFromEnum(i));
    }

    fn toAbi(i: IndirectFunctionTableIndex) u32 {
        return @intFromEnum(i) + 1;
    }
};

const DataSegmentGroup = struct {
    first_segment: Wasm.DataSegmentId,
    end_addr: u32,
};

pub fn clear(f: *Flush) void {
    f.data_segments.clearRetainingCapacity();
    f.data_segment_groups.clearRetainingCapacity();
    f.binary_bytes.clearRetainingCapacity();
    f.indirect_function_table.clearRetainingCapacity();
    f.func_types.clearRetainingCapacity();
    f.memory_layout_finished = false;
}

pub fn deinit(f: *Flush, gpa: Allocator) void {
    f.data_segments.deinit(gpa);
    f.data_segment_groups.deinit(gpa);
    f.binary_bytes.deinit(gpa);
    f.missing_exports.deinit(gpa);
    f.function_imports.deinit(gpa);
    f.global_imports.deinit(gpa);
    f.data_imports.deinit(gpa);
    f.indirect_function_table.deinit(gpa);
    f.func_types.deinit(gpa);
    f.* = undefined;
}

pub fn finish(f: *Flush, wasm: *Wasm) !void {
    const comp = wasm.base.comp;
    const shared_memory = comp.config.shared_memory;
    const diags = &comp.link_diags;
    const gpa = comp.gpa;
    const import_memory = comp.config.import_memory;
    const export_memory = comp.config.export_memory;
    const target = &comp.root_mod.resolved_target.result;
    const is64 = switch (target.cpu.arch) {
        .wasm32 => false,
        .wasm64 => true,
        else => unreachable,
    };
    const is_obj = comp.config.output_mode == .Obj;
    const allow_undefined = is_obj or wasm.import_symbols;

    const entry_name = if (wasm.entry_resolution.isNavOrUnresolved(wasm)) wasm.entry_name else .none;

    if (comp.zcu) |zcu| {
        const ip: *const InternPool = &zcu.intern_pool; // No mutations allowed!

        // Detect any intrinsics that were called; they need to have dependencies on the symbols marked.
        // Likewise detect `@tagName` calls so those functions can be included in the output and synthesized.
        for (wasm.mir_instructions.items(.tag), wasm.mir_instructions.items(.data)) |tag, *data| switch (tag) {
            .call_intrinsic => {
                const symbol_name = try wasm.internString(@tagName(data.intrinsic));
                const i: Wasm.FunctionImport.Index = @enumFromInt(wasm.object_function_imports.getIndex(symbol_name) orelse {
                    return diags.fail("missing compiler runtime intrinsic '{s}' (undefined linker symbol)", .{
                        @tagName(data.intrinsic),
                    });
                });
                try wasm.markFunctionImport(symbol_name, i.value(wasm), i);
            },
            .call_tag_name => {
                assert(ip.indexToKey(data.ip_index) == .enum_type);
                const gop = try wasm.zcu_funcs.getOrPut(gpa, data.ip_index);
                if (!gop.found_existing) {
                    wasm.tag_name_table_ref_count += 1;
                    const int_tag_ty = Zcu.Type.fromInterned(data.ip_index).intTagType(zcu);
                    gop.value_ptr.* = .{ .tag_name = .{
                        .symbol_name = try wasm.internStringFmt("__zig_tag_name_{d}", .{@intFromEnum(data.ip_index)}),
                        .type_index = try wasm.internFunctionType(.Unspecified, &.{int_tag_ty.ip_index}, .slice_const_u8_sentinel_0, target),
                        .table_index = @intCast(wasm.tag_name_offs.items.len),
                    } };
                    try wasm.functions.put(gpa, .fromZcuFunc(wasm, @enumFromInt(gop.index)), {});
                    const tag_names = ip.loadEnumType(data.ip_index).names;
                    for (tag_names.get(ip)) |tag_name| {
                        const slice = tag_name.toSlice(ip);
                        try wasm.tag_name_offs.append(gpa, @intCast(wasm.tag_name_bytes.items.len));
                        try wasm.tag_name_bytes.appendSlice(gpa, slice[0 .. slice.len + 1]);
                    }
                }
            },
            else => continue,
        };

        {
            var i = wasm.function_imports_len_prelink;
            while (i < f.function_imports.entries.len) {
                const symbol_name = f.function_imports.keys()[i];
                if (wasm.object_function_imports.getIndex(symbol_name)) |import_index_usize| {
                    const import_index: Wasm.FunctionImport.Index = @enumFromInt(import_index_usize);
                    try wasm.markFunctionImport(symbol_name, import_index.value(wasm), import_index);
                    f.function_imports.swapRemoveAt(i);
                    continue;
                }
                i += 1;
            }
        }

        {
            var i = wasm.data_imports_len_prelink;
            while (i < f.data_imports.entries.len) {
                const symbol_name = f.data_imports.keys()[i];
                if (wasm.object_data_imports.getIndex(symbol_name)) |import_index_usize| {
                    const import_index: Wasm.ObjectDataImport.Index = @enumFromInt(import_index_usize);
                    try wasm.markDataImport(symbol_name, import_index.value(wasm), import_index);
                    f.data_imports.swapRemoveAt(i);
                    continue;
                }
                i += 1;
            }
        }

        if (wasm.error_name_table_ref_count > 0) {
            // Ensure Zcu error name structures are populated.
            const full_error_names = ip.global_error_set.getNamesFromMainThread();
            try wasm.error_name_offs.ensureTotalCapacity(gpa, full_error_names.len + 1);
            if (wasm.error_name_offs.items.len == 0) {
                // Dummy entry at index 0 to avoid a sub instruction at `@errorName` sites.
                wasm.error_name_offs.appendAssumeCapacity(0);
            }
            const new_error_names = full_error_names[wasm.error_name_offs.items.len - 1 ..];
            for (new_error_names) |error_name| {
                wasm.error_name_offs.appendAssumeCapacity(@intCast(wasm.error_name_bytes.items.len));
                const s: [:0]const u8 = error_name.toSlice(ip);
                try wasm.error_name_bytes.appendSlice(gpa, s[0 .. s.len + 1]);
            }
        }

        for (wasm.nav_exports.keys(), wasm.nav_exports.values()) |*nav_export, export_index| {
            if (ip.isFunctionType(ip.getNav(nav_export.nav_index).typeOf(ip))) {
                log.debug("flush export '{s}' nav={d}", .{ nav_export.name.slice(wasm), nav_export.nav_index });
                const function_index = Wasm.FunctionIndex.fromIpNav(wasm, nav_export.nav_index).?;
                const explicit = f.missing_exports.swapRemove(nav_export.name);
                const is_hidden = !explicit and switch (export_index.ptr(zcu).opts.visibility) {
                    .hidden => true,
                    .default, .protected => false,
                };
                if (is_hidden) {
                    try wasm.hidden_function_exports.put(gpa, nav_export.name, function_index);
                } else {
                    try wasm.function_exports.put(gpa, nav_export.name, function_index);
                }
                _ = f.function_imports.swapRemove(nav_export.name);

                if (nav_export.name.toOptional() == entry_name)
                    wasm.entry_resolution = .fromIpNav(wasm, nav_export.nav_index);
            } else {
                // This is a data export because Zcu currently has no way to
                // export wasm globals.
                _ = f.missing_exports.swapRemove(nav_export.name);
                _ = f.data_imports.swapRemove(nav_export.name);
                if (!is_obj) {
                    diags.addError("unable to export data symbol '{s}'; not emitting a relocatable", .{
                        nav_export.name.slice(wasm),
                    });
                }
            }
        }

        for (f.missing_exports.keys()) |exp_name| {
            diags.addError("manually specified export name '{s}' undefined", .{exp_name.slice(wasm)});
        }
    }

    if (entry_name.unwrap()) |name| {
        if (wasm.entry_resolution == .unresolved) {
            var err = try diags.addErrorWithNotes(1);
            try err.addMsg("entry symbol '{s}' missing", .{name.slice(wasm)});
            err.addNote("'-fno-entry' suppresses this error", .{});
        }
    }

    if (!allow_undefined) {
        for (f.function_imports.keys(), f.function_imports.values()) |name, function_import_id| {
            if (function_import_id.undefinedAllowed(wasm)) continue;
            const src_loc = function_import_id.sourceLocation(wasm);
            src_loc.addError(wasm, "undefined function: {s}", .{name.slice(wasm)});
        }
        for (f.global_imports.keys(), f.global_imports.values()) |name, global_import_id| {
            const src_loc = global_import_id.sourceLocation(wasm);
            src_loc.addError(wasm, "undefined global: {s}", .{name.slice(wasm)});
        }
        for (wasm.table_imports.keys(), wasm.table_imports.values()) |name, table_import_id| {
            const src_loc = table_import_id.value(wasm).source_location;
            src_loc.addError(wasm, "undefined table: {s}", .{name.slice(wasm)});
        }
        for (f.data_imports.keys(), f.data_imports.values()) |name, data_import_id| {
            const src_loc = data_import_id.sourceLocation(wasm);
            src_loc.addError(wasm, "undefined data: {s}", .{name.slice(wasm)});
        }
    }

    if (diags.hasErrors()) return error.LinkFailure;

    // Merge indirect function tables.
    try f.indirect_function_table.ensureUnusedCapacity(gpa, wasm.zcu_indirect_function_set.entries.len +
        wasm.object_indirect_function_import_set.entries.len + wasm.object_indirect_function_set.entries.len);
    // This one goes first so the indexes can be stable for MIR lowering.
    for (wasm.zcu_indirect_function_set.keys()) |nav_index|
        f.indirect_function_table.putAssumeCapacity(.fromIpNav(wasm, nav_index), {});
    for (wasm.object_indirect_function_import_set.keys()) |symbol_name|
        f.indirect_function_table.putAssumeCapacity(.fromSymbolName(wasm, symbol_name), {});
    for (wasm.object_indirect_function_set.keys()) |object_function_index|
        f.indirect_function_table.putAssumeCapacity(.fromObjectFunction(wasm, object_function_index), {});

    if (wasm.object_init_funcs.items.len > 0) {
        // Zig has no constructors so these are only for object file inputs.
        mem.sortUnstable(Wasm.InitFunc, wasm.object_init_funcs.items, {}, Wasm.InitFunc.lessThan);
        try wasm.functions.put(gpa, .__wasm_call_ctors, {});
    }

    // Merge and order the data segments. Depends on garbage collection so that
    // unused segments can be omitted.
    try f.data_segments.ensureUnusedCapacity(gpa, wasm.data_segments.entries.len +
        wasm.uavs_obj.entries.len + wasm.navs_obj.entries.len +
        wasm.uavs_exe.entries.len + wasm.navs_exe.entries.len + 4);
    if (is_obj) assert(wasm.uavs_exe.entries.len == 0);
    if (is_obj) assert(wasm.navs_exe.entries.len == 0);
    if (!is_obj) assert(wasm.uavs_obj.entries.len == 0);
    if (!is_obj) assert(wasm.navs_obj.entries.len == 0);
    for (0..wasm.uavs_obj.entries.len) |uavs_index| f.data_segments.putAssumeCapacityNoClobber(.pack(wasm, .{
        .uav_obj = @enumFromInt(uavs_index),
    }), @as(u32, undefined));
    for (0..wasm.navs_obj.entries.len) |navs_index| f.data_segments.putAssumeCapacityNoClobber(.pack(wasm, .{
        .nav_obj = @enumFromInt(navs_index),
    }), @as(u32, undefined));
    for (0..wasm.uavs_exe.entries.len) |uavs_index| f.data_segments.putAssumeCapacityNoClobber(.pack(wasm, .{
        .uav_exe = @enumFromInt(uavs_index),
    }), @as(u32, undefined));
    for (0..wasm.navs_exe.entries.len) |navs_index| f.data_segments.putAssumeCapacityNoClobber(.pack(wasm, .{
        .nav_exe = @enumFromInt(navs_index),
    }), @as(u32, undefined));
    if (wasm.error_name_table_ref_count > 0) {
        f.data_segments.putAssumeCapacity(.__zig_error_names, @as(u32, undefined));
        f.data_segments.putAssumeCapacity(.__zig_error_name_table, @as(u32, undefined));
    }
    if (wasm.tag_name_table_ref_count > 0) {
        f.data_segments.putAssumeCapacity(.__zig_tag_names, @as(u32, undefined));
        f.data_segments.putAssumeCapacity(.__zig_tag_name_table, @as(u32, undefined));
    }
    for (wasm.data_segments.keys()) |data_id| f.data_segments.putAssumeCapacity(data_id, @as(u32, undefined));

    try wasm.functions.ensureUnusedCapacity(gpa, 3);

    // Passive segments are used to avoid memory being reinitialized on each
    // thread's instantiation. These passive segments are initialized and
    // dropped in __wasm_init_memory, which is registered as the start function
    // We also initialize bss segments (using memory.fill) as part of this
    // function.
    if (wasm.any_passive_inits) {
        try wasm.addFunction(.__wasm_init_memory, &.{}, &.{});
    }

    try wasm.tables.ensureUnusedCapacity(gpa, 1);

    if (f.indirect_function_table.entries.len > 0) {
        wasm.tables.putAssumeCapacity(.__indirect_function_table, {});
    }

    // Sort order:
    // 0. Segment category (tls, data, zero)
    // 1. Segment name prefix
    // 2. Segment alignment
    // 3. Reference count, descending (optimize for LEB encoding)
    // 4. Segment name suffix
    // 5. Segment ID interpreted as an integer (for determinism)
    //
    // TLS segments are intended to be merged with each other, and segments
    // with a common prefix name are intended to be merged with each other.
    // Sorting ensures the segments intended to be merged will be adjacent.
    //
    // Each Zcu Nav and Cau has an independent data segment ID in this logic.
    // For the purposes of sorting, they are implicitly all named ".data".
    const Sort = struct {
        wasm: *const Wasm,
        segments: []const Wasm.DataSegmentId,
        pub fn lessThan(ctx: @This(), lhs: usize, rhs: usize) bool {
            const lhs_segment = ctx.segments[lhs];
            const rhs_segment = ctx.segments[rhs];
            const lhs_category = @intFromEnum(lhs_segment.category(ctx.wasm));
            const rhs_category = @intFromEnum(rhs_segment.category(ctx.wasm));
            switch (std.math.order(lhs_category, rhs_category)) {
                .lt => return true,
                .gt => return false,
                .eq => {},
            }
            const lhs_segment_name = lhs_segment.name(ctx.wasm);
            const rhs_segment_name = rhs_segment.name(ctx.wasm);
            const lhs_prefix, const lhs_suffix = splitSegmentName(lhs_segment_name);
            const rhs_prefix, const rhs_suffix = splitSegmentName(rhs_segment_name);
            switch (mem.order(u8, lhs_prefix, rhs_prefix)) {
                .lt => return true,
                .gt => return false,
                .eq => {},
            }
            const lhs_alignment = lhs_segment.alignment(ctx.wasm);
            const rhs_alignment = rhs_segment.alignment(ctx.wasm);
            switch (lhs_alignment.order(rhs_alignment)) {
                .lt => return false,
                .gt => return true,
                .eq => {},
            }
            switch (std.math.order(lhs_segment.refCount(ctx.wasm), rhs_segment.refCount(ctx.wasm))) {
                .lt => return false,
                .gt => return true,
                .eq => {},
            }
            switch (mem.order(u8, lhs_suffix, rhs_suffix)) {
                .lt => return true,
                .gt => return false,
                .eq => {},
            }
            return @intFromEnum(lhs_segment) < @intFromEnum(rhs_segment);
        }
    };
    f.data_segments.sortUnstable(@as(Sort, .{
        .wasm = wasm,
        .segments = f.data_segments.keys(),
    }));

    const page_size = std.wasm.page_size; // 64kb
    const stack_alignment: Alignment = .@"16"; // wasm's stack alignment as specified by tool-convention
    const heap_alignment: Alignment = .@"16"; // wasm's heap alignment as specified by tool-convention
    const pointer_alignment: Alignment = .@"4";
    // Always place the stack at the start by default unless the user specified the global-base flag.
    const place_stack_first, var memory_ptr: u64 = if (wasm.global_base) |base| .{ false, base } else .{ true, 0 };

    var virtual_addrs: VirtualAddrs = .{
        .stack_pointer = undefined,
        .heap_base = undefined,
        .heap_end = undefined,
        .tls_base = null,
        .tls_align = .none,
        .tls_size = null,
        .init_memory_flag = null,
    };

    if (place_stack_first and !is_obj) {
        memory_ptr = stack_alignment.forward(memory_ptr);
        memory_ptr += wasm.base.stack_size;
        virtual_addrs.stack_pointer = @intCast(memory_ptr);
    }

    const segment_ids = f.data_segments.keys();
    const segment_vaddrs = f.data_segments.values();
    assert(f.data_segment_groups.items.len == 0);
    const data_vaddr: u32 = @intCast(memory_ptr);
    if (segment_ids.len > 0) {
        var seen_tls: enum { before, during, after } = .before;
        var category: Wasm.DataSegmentId.Category = undefined;
        var first_segment: Wasm.DataSegmentId = segment_ids[0];
        for (segment_ids, segment_vaddrs, 0..) |segment_id, *segment_vaddr, i| {
            const alignment = segment_id.alignment(wasm);
            category = segment_id.category(wasm);
            const start_addr = alignment.forward(memory_ptr);

            const want_new_segment = b: {
                if (is_obj) break :b false;
                switch (seen_tls) {
                    .before => switch (category) {
                        .tls => {
                            virtual_addrs.tls_base = if (shared_memory) 0 else @intCast(start_addr);
                            virtual_addrs.tls_align = alignment;
                            seen_tls = .during;
                            break :b f.data_segment_groups.items.len > 0;
                        },
                        else => {},
                    },
                    .during => switch (category) {
                        .tls => {
                            virtual_addrs.tls_align = virtual_addrs.tls_align.maxStrict(alignment);
                            virtual_addrs.tls_size = @intCast(memory_ptr - virtual_addrs.tls_base.?);
                            break :b false;
                        },
                        else => {
                            seen_tls = .after;
                            break :b true;
                        },
                    },
                    .after => {},
                }
                break :b i >= 1 and !wantSegmentMerge(wasm, segment_ids[i - 1], segment_id, category);
            };
            if (want_new_segment) {
                log.debug("new segment group at 0x{x} {} {s} {}", .{ start_addr, segment_id, segment_id.name(wasm), category });
                try f.data_segment_groups.append(gpa, .{
                    .end_addr = @intCast(memory_ptr),
                    .first_segment = first_segment,
                });
                first_segment = segment_id;
            }

            const size = segment_id.size(wasm);
            segment_vaddr.* = @intCast(start_addr);
            log.debug("0x{x} {d} {s}", .{ start_addr, @intFromEnum(segment_id), segment_id.name(wasm) });
            memory_ptr = start_addr + size;
        }
        if (category != .zero) try f.data_segment_groups.append(gpa, .{
            .first_segment = first_segment,
            .end_addr = @intCast(memory_ptr),
        });
        if (category == .tls and seen_tls == .during) {
            virtual_addrs.tls_size = @intCast(memory_ptr - virtual_addrs.tls_base.?);
        }
    }

    if (shared_memory and wasm.any_passive_inits) {
        memory_ptr = pointer_alignment.forward(memory_ptr);
        virtual_addrs.init_memory_flag = @intCast(memory_ptr);
        memory_ptr += 4;
    }

    if (!place_stack_first and !is_obj) {
        memory_ptr = stack_alignment.forward(memory_ptr);
        memory_ptr += wasm.base.stack_size;
        virtual_addrs.stack_pointer = @intCast(memory_ptr);
    }

    memory_ptr = heap_alignment.forward(memory_ptr);
    virtual_addrs.heap_base = @intCast(memory_ptr);

    if (wasm.initial_memory) |initial_memory| {
        if (!mem.isAlignedGeneric(u64, initial_memory, page_size)) {
            diags.addError("initial memory value {d} is not {d}-byte aligned", .{ initial_memory, page_size });
        }
        if (memory_ptr > initial_memory) {
            diags.addError("initial memory value {d} insufficient; minimum {d}", .{ initial_memory, memory_ptr });
        }
        if (initial_memory > std.math.maxInt(u32)) {
            diags.addError("initial memory value {d} exceeds 32-bit address space", .{initial_memory});
        }
        if (diags.hasErrors()) return error.LinkFailure;
        memory_ptr = initial_memory;
    } else {
        memory_ptr = mem.alignForward(u64, memory_ptr, std.wasm.page_size);
    }
    virtual_addrs.heap_end = @intCast(memory_ptr);

    // In case we do not import memory, but define it ourselves, set the
    // minimum amount of pages on the memory section.
    wasm.memories.limits.min = @intCast(memory_ptr / page_size);
    log.debug("total memory pages: {d}", .{wasm.memories.limits.min});

    if (wasm.max_memory) |max_memory| {
        if (!mem.isAlignedGeneric(u64, max_memory, page_size)) {
            diags.addError("maximum memory value {d} is not {d}-byte aligned", .{ max_memory, page_size });
        }
        if (memory_ptr > max_memory) {
            diags.addError("maximum memory value {d} insufficient; minimum {d}", .{ max_memory, memory_ptr });
        }
        if (max_memory > std.math.maxInt(u32)) {
            diags.addError("maximum memory value {d} exceeds 32-bit address space", .{max_memory});
        }
        if (diags.hasErrors()) return error.LinkFailure;
        wasm.memories.limits.max = @intCast(max_memory / page_size);
        wasm.memories.limits.flags.has_max = true;
        if (shared_memory) wasm.memories.limits.flags.is_shared = true;
        log.debug("maximum memory pages: {?d}", .{wasm.memories.limits.max});
    }
    f.memory_layout_finished = true;

    // When we have TLS GOT entries and shared memory is enabled, we must
    // perform runtime relocations or else we don't create the function.
    if (shared_memory and virtual_addrs.tls_base != null) {
        // This logic that checks `any_tls_relocs` is missing the part where it
        // also notices threadlocal globals from Zcu code.
        if (wasm.any_tls_relocs) try wasm.addFunction(.__wasm_apply_global_tls_relocs, &.{}, &.{});
        try wasm.addFunction(.__wasm_init_tls, &.{.i32}, &.{});
        try wasm.globals.ensureUnusedCapacity(gpa, 3);
        wasm.globals.putAssumeCapacity(.__tls_base, {});
        wasm.globals.putAssumeCapacity(.__tls_size, {});
        wasm.globals.putAssumeCapacity(.__tls_align, {});
    }

    var section_index: u32 = 0;
    // Index of the code section. Used to tell relocation table where the section lives.
    var code_section_index: ?u32 = null;
    // Index of the data section. Used to tell relocation table where the section lives.
    var data_section_index: ?u32 = null;

    const binary_bytes = &f.binary_bytes;
    assert(binary_bytes.items.len == 0);

    try binary_bytes.appendSlice(gpa, &std.wasm.magic ++ &std.wasm.version);
    assert(binary_bytes.items.len == 8);

    const binary_writer = binary_bytes.writer(gpa);

    // Type section.
    for (f.function_imports.values()) |id| {
        try f.func_types.put(gpa, id.functionType(wasm), {});
    }
    for (wasm.functions.keys()) |function| {
        try f.func_types.put(gpa, function.typeIndex(wasm), {});
    }
    if (f.func_types.entries.len != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        for (f.func_types.keys()) |func_type_index| {
            const func_type = func_type_index.ptr(wasm);
            try leb.writeUleb128(binary_writer, std.wasm.function_type);
            const params = func_type.params.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(params.len)));
            for (params) |param_ty| {
                try leb.writeUleb128(binary_writer, @intFromEnum(param_ty));
            }
            const returns = func_type.returns.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(returns.len)));
            for (returns) |ret_ty| {
                try leb.writeUleb128(binary_writer, @intFromEnum(ret_ty));
            }
        }
        replaceVecSectionHeader(binary_bytes, header_offset, .type, @intCast(f.func_types.entries.len));
        section_index += 1;
    }

    if (!is_obj) {
        // TODO: sort function_imports by ref count descending for optimal LEB encodings
        // TODO: sort   global_imports by ref count descending for optimal LEB encodings
        // TODO: sort output functions by ref count descending for optimal LEB encodings
    }

    // Import section
    {
        var total_imports: usize = 0;
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (f.function_imports.values()) |id| {
            const module_name = id.moduleName(wasm).slice(wasm).?;
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(module_name.len)));
            try binary_writer.writeAll(module_name);

            const name = id.importName(wasm).slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_writer.writeAll(name);

            try binary_writer.writeByte(@intFromEnum(std.wasm.ExternalKind.function));
            const type_index: FuncTypeIndex = .fromTypeIndex(id.functionType(wasm), f);
            try leb.writeUleb128(binary_writer, @intFromEnum(type_index));
        }
        total_imports += f.function_imports.entries.len;

        for (wasm.table_imports.values()) |id| {
            const table_import = id.value(wasm);
            const module_name = table_import.module_name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(module_name.len)));
            try binary_writer.writeAll(module_name);

            const name = table_import.name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_writer.writeAll(name);

            try binary_writer.writeByte(@intFromEnum(std.wasm.ExternalKind.table));
            try leb.writeUleb128(binary_writer, @intFromEnum(@as(std.wasm.RefType, table_import.flags.ref_type.to())));
            try emitLimits(gpa, binary_bytes, table_import.limits());
        }
        total_imports += wasm.table_imports.entries.len;

        if (import_memory) {
            const name = if (is_obj) wasm.preloaded_strings.__linear_memory else wasm.preloaded_strings.memory;
            try emitMemoryImport(wasm, binary_bytes, name, &.{
                // TODO the import_memory option needs to specify from which module
                .module_name = wasm.object_host_name.unwrap().?,
                .limits_min = wasm.memories.limits.min,
                .limits_max = wasm.memories.limits.max,
                .limits_has_max = wasm.memories.limits.flags.has_max,
                .limits_is_shared = wasm.memories.limits.flags.is_shared,
                .source_location = .none,
            });
            total_imports += 1;
        }

        for (f.global_imports.values()) |id| {
            const module_name = id.moduleName(wasm).slice(wasm).?;
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(module_name.len)));
            try binary_writer.writeAll(module_name);

            const name = id.importName(wasm).slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_writer.writeAll(name);

            try binary_writer.writeByte(@intFromEnum(std.wasm.ExternalKind.global));
            const global_type = id.globalType(wasm);
            try leb.writeUleb128(binary_writer, @intFromEnum(@as(std.wasm.Valtype, global_type.valtype)));
            try binary_writer.writeByte(@intFromBool(global_type.mutable));
        }
        total_imports += f.global_imports.entries.len;

        if (total_imports > 0) {
            replaceVecSectionHeader(binary_bytes, header_offset, .import, @intCast(total_imports));
            section_index += 1;
        } else {
            binary_bytes.shrinkRetainingCapacity(header_offset);
        }
    }

    // Function section
    if (wasm.functions.count() != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        for (wasm.functions.keys()) |function| {
            const index: FuncTypeIndex = .fromTypeIndex(function.typeIndex(wasm), f);
            try leb.writeUleb128(binary_writer, @intFromEnum(index));
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .function, @intCast(wasm.functions.count()));
        section_index += 1;
    }

    // Table section
    if (wasm.tables.entries.len > 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (wasm.tables.keys()) |table| {
            try leb.writeUleb128(binary_writer, @intFromEnum(@as(std.wasm.RefType, table.refType(wasm))));
            try emitLimits(gpa, binary_bytes, table.limits(wasm));
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .table, @intCast(wasm.tables.entries.len));
        section_index += 1;
    }

    // Memory section. wasm currently only supports 1 linear memory segment.
    if (!import_memory) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        try emitLimits(gpa, binary_bytes, wasm.memories.limits);
        replaceVecSectionHeader(binary_bytes, header_offset, .memory, 1);
        section_index += 1;
    }

    // Global section.
    const globals_len: u32 = @intCast(wasm.globals.entries.len);
    if (globals_len > 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (wasm.globals.keys()) |global_resolution| {
            switch (global_resolution.unpack(wasm)) {
                .unresolved => unreachable,
                .__heap_base => try appendGlobal(gpa, binary_bytes, 0, virtual_addrs.heap_base),
                .__heap_end => try appendGlobal(gpa, binary_bytes, 0, virtual_addrs.heap_end),
                .__stack_pointer => try appendGlobal(gpa, binary_bytes, 1, virtual_addrs.stack_pointer),
                .__tls_align => try appendGlobal(gpa, binary_bytes, 0, @intCast(virtual_addrs.tls_align.toByteUnits().?)),
                .__tls_base => try appendGlobal(gpa, binary_bytes, 1, virtual_addrs.tls_base.?),
                .__tls_size => try appendGlobal(gpa, binary_bytes, 0, virtual_addrs.tls_size.?),
                .object_global => |i| {
                    const global = i.ptr(wasm);
                    try binary_bytes.appendSlice(gpa, &.{
                        @intFromEnum(@as(std.wasm.Valtype, global.flags.global_type.valtype.to())),
                        @intFromBool(global.flags.global_type.mutable),
                    });
                    try emitExpr(wasm, binary_bytes, global.expr);
                },
                .nav_exe => unreachable, // Zig source code currently cannot represent this.
                .nav_obj => unreachable, // Zig source code currently cannot represent this.
            }
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .global, globals_len);
        section_index += 1;
    }

    // Export section
    {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        var exports_len: usize = 0;

        for (wasm.function_exports.keys(), wasm.function_exports.values()) |exp_name, function_index| {
            const name = exp_name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
            try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.function));
            const func_index = Wasm.OutputFunctionIndex.fromFunctionIndex(wasm, function_index);
            try leb.writeUleb128(binary_writer, @intFromEnum(func_index));
        }
        exports_len += wasm.function_exports.entries.len;

        if (wasm.export_table and f.indirect_function_table.entries.len > 0) {
            const name = "__indirect_function_table";
            const index: u32 = @intCast(wasm.tables.getIndex(.__indirect_function_table).?);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
            try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.table));
            try leb.writeUleb128(binary_writer, index);
            exports_len += 1;
        }

        if (export_memory) {
            const name = "memory";
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
            try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.memory));
            try leb.writeUleb128(binary_writer, @as(u32, 0));
            exports_len += 1;
        }

        for (wasm.global_exports.items) |exp| {
            const name = exp.name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
            try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.global));
            try leb.writeUleb128(binary_writer, @intFromEnum(exp.global_index));
        }
        exports_len += wasm.global_exports.items.len;

        if (exports_len > 0) {
            replaceVecSectionHeader(binary_bytes, header_offset, .@"export", @intCast(exports_len));
            section_index += 1;
        } else {
            binary_bytes.shrinkRetainingCapacity(header_offset);
        }
    }

    // start section
    if (wasm.functions.getIndex(.__wasm_init_memory)) |func_index| {
        try emitStartSection(gpa, binary_bytes, .fromFunctionIndex(wasm, @enumFromInt(func_index)));
    } else if (Wasm.OutputFunctionIndex.fromResolution(wasm, wasm.entry_resolution)) |func_index| {
        try emitStartSection(gpa, binary_bytes, func_index);
    }

    // element section
    if (f.indirect_function_table.entries.len > 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        // indirect function table elements
        const table_index: u32 = @intCast(wasm.tables.getIndex(.__indirect_function_table).?);
        // passive with implicit 0-index table or set table index manually
        const flags: u32 = if (table_index == 0) 0x0 else 0x02;
        try leb.writeUleb128(binary_writer, flags);
        if (flags == 0x02) {
            try leb.writeUleb128(binary_writer, table_index);
        }
        // We start at index 1, so unresolved function pointers are invalid
        try emitInit(binary_writer, .{ .i32_const = 1 });
        if (flags == 0x02) {
            try leb.writeUleb128(binary_writer, @as(u8, 0)); // represents funcref
        }
        try leb.writeUleb128(binary_writer, @as(u32, @intCast(f.indirect_function_table.entries.len)));
        for (f.indirect_function_table.keys()) |func_index| {
            try leb.writeUleb128(binary_writer, @intFromEnum(func_index));
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .element, 1);
        section_index += 1;
    }

    // When the shared-memory option is enabled, we *must* emit the 'data count' section.
    if (f.data_segment_groups.items.len > 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        replaceVecSectionHeader(binary_bytes, header_offset, .data_count, @intCast(f.data_segment_groups.items.len));
    }

    // Code section.
    if (wasm.functions.count() != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (wasm.functions.keys()) |resolution| switch (resolution.unpack(wasm)) {
            .unresolved => unreachable,
            .__wasm_apply_global_tls_relocs => @panic("TODO lower __wasm_apply_global_tls_relocs"),
            .__wasm_call_ctors => {
                const code_start = try reserveSize(gpa, binary_bytes);
                defer replaceSize(binary_bytes, code_start);
                try emitCallCtorsFunction(wasm, binary_bytes);
            },
            .__wasm_init_memory => {
                const code_start = try reserveSize(gpa, binary_bytes);
                defer replaceSize(binary_bytes, code_start);
                try emitInitMemoryFunction(wasm, binary_bytes, &virtual_addrs);
            },
            .__wasm_init_tls => {
                const code_start = try reserveSize(gpa, binary_bytes);
                defer replaceSize(binary_bytes, code_start);
                try emitInitTlsFunction(wasm, binary_bytes);
            },
            .object_function => |i| {
                const ptr = i.ptr(wasm);
                const code = ptr.code.slice(wasm);
                try leb.writeUleb128(binary_writer, code.len);
                const code_start = binary_bytes.items.len;
                try binary_bytes.appendSlice(gpa, code);
                if (!is_obj) applyRelocs(binary_bytes.items[code_start..], ptr.offset, ptr.relocations(wasm), wasm);
            },
            .zcu_func => |i| {
                const code_start = try reserveSize(gpa, binary_bytes);
                defer replaceSize(binary_bytes, code_start);

                log.debug("lowering function code for '{s}'", .{resolution.name(wasm).?});

                const zcu = comp.zcu.?;
                const ip = &zcu.intern_pool;
                const ip_index = i.key(wasm).*;
                switch (ip.indexToKey(ip_index)) {
                    .enum_type => {
                        try emitTagNameFunction(wasm, binary_bytes, f.data_segments.get(.__zig_tag_name_table).?, i.value(wasm).tag_name.table_index, ip_index);
                    },
                    else => try i.value(wasm).function.lower(wasm, binary_bytes),
                }
            },
        };

        replaceVecSectionHeader(binary_bytes, header_offset, .code, @intCast(wasm.functions.entries.len));
        code_section_index = section_index;
        section_index += 1;
    }

    if (!is_obj) {
        for (wasm.uav_fixups.items) |uav_fixup| {
            const ds_id: Wasm.DataSegmentId = .pack(wasm, .{ .uav_exe = uav_fixup.uavs_exe_index });
            const vaddr = f.data_segments.get(ds_id).? + uav_fixup.addend;
            if (!is64) {
                mem.writeInt(u32, wasm.string_bytes.items[uav_fixup.offset..][0..4], vaddr, .little);
            } else {
                mem.writeInt(u64, wasm.string_bytes.items[uav_fixup.offset..][0..8], vaddr, .little);
            }
        }
        for (wasm.nav_fixups.items) |nav_fixup| {
            const ds_id: Wasm.DataSegmentId = .pack(wasm, .{ .nav_exe = nav_fixup.navs_exe_index });
            const vaddr = f.data_segments.get(ds_id).? + nav_fixup.addend;
            if (!is64) {
                mem.writeInt(u32, wasm.string_bytes.items[nav_fixup.offset..][0..4], vaddr, .little);
            } else {
                mem.writeInt(u64, wasm.string_bytes.items[nav_fixup.offset..][0..8], vaddr, .little);
            }
        }
        for (wasm.func_table_fixups.items) |fixup| {
            const table_index: IndirectFunctionTableIndex = .fromZcuIndirectFunctionSetIndex(fixup.table_index);
            if (!is64) {
                mem.writeInt(u32, wasm.string_bytes.items[fixup.offset..][0..4], table_index.toAbi(), .little);
            } else {
                mem.writeInt(u64, wasm.string_bytes.items[fixup.offset..][0..8], table_index.toAbi(), .little);
            }
        }
    }

    // Data section.
    if (f.data_segment_groups.items.len != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        var group_index: u32 = 0;
        var segment_offset: u32 = 0;
        var group_start_addr: u32 = data_vaddr;
        var group_end_addr = f.data_segment_groups.items[group_index].end_addr;
        for (segment_ids, segment_vaddrs) |segment_id, segment_vaddr| {
            if (segment_vaddr >= group_end_addr) {
                try binary_bytes.appendNTimes(gpa, 0, group_end_addr - group_start_addr - segment_offset);
                group_index += 1;
                if (group_index >= f.data_segment_groups.items.len) {
                    // All remaining segments are zero.
                    break;
                }
                group_start_addr = group_end_addr;
                group_end_addr = f.data_segment_groups.items[group_index].end_addr;
                segment_offset = 0;
            }
            if (segment_offset == 0) {
                const group_size = group_end_addr - group_start_addr;
                log.debug("emit data section group, {d} bytes", .{group_size});
                const flags: Object.DataSegmentFlags = if (segment_id.isPassive(wasm)) .passive else .active;
                try leb.writeUleb128(binary_writer, @intFromEnum(flags));
                // Passive segments are initialized at runtime.
                if (flags != .passive) {
                    try emitInit(binary_writer, .{ .i32_const = @as(i32, @bitCast(group_start_addr)) });
                }
                try leb.writeUleb128(binary_writer, group_size);
            }
            if (segment_id.isEmpty(wasm)) {
                // It counted for virtual memory but it does not go into the binary.
                continue;
            }

            // Padding for alignment.
            const needed_offset = segment_vaddr - group_start_addr;
            try binary_bytes.appendNTimes(gpa, 0, needed_offset - segment_offset);
            segment_offset = needed_offset;

            const code_start = binary_bytes.items.len;
            append: {
                const code = switch (segment_id.unpack(wasm)) {
                    .__heap_base => {
                        mem.writeInt(u32, try binary_bytes.addManyAsArray(gpa, 4), virtual_addrs.heap_base, .little);
                        break :append;
                    },
                    .__heap_end => {
                        mem.writeInt(u32, try binary_bytes.addManyAsArray(gpa, 4), virtual_addrs.heap_end, .little);
                        break :append;
                    },
                    .__zig_error_names => {
                        try binary_bytes.appendSlice(gpa, wasm.error_name_bytes.items);
                        break :append;
                    },
                    .__zig_error_name_table => {
                        if (is_obj) @panic("TODO error name table reloc");
                        const base = f.data_segments.get(.__zig_error_names).?;
                        if (!is64) {
                            try emitTagNameTable(gpa, binary_bytes, wasm.error_name_offs.items, wasm.error_name_bytes.items, base, u32);
                        } else {
                            try emitTagNameTable(gpa, binary_bytes, wasm.error_name_offs.items, wasm.error_name_bytes.items, base, u64);
                        }
                        break :append;
                    },
                    .__zig_tag_names => {
                        try binary_bytes.appendSlice(gpa, wasm.tag_name_bytes.items);
                        break :append;
                    },
                    .__zig_tag_name_table => {
                        if (is_obj) @panic("TODO tag name table reloc");
                        const base = f.data_segments.get(.__zig_tag_names).?;
                        if (!is64) {
                            try emitTagNameTable(gpa, binary_bytes, wasm.tag_name_offs.items, wasm.tag_name_bytes.items, base, u32);
                        } else {
                            try emitTagNameTable(gpa, binary_bytes, wasm.tag_name_offs.items, wasm.tag_name_bytes.items, base, u64);
                        }
                        break :append;
                    },
                    .object => |i| {
                        const ptr = i.ptr(wasm);
                        try binary_bytes.appendSlice(gpa, ptr.payload.slice(wasm));
                        if (!is_obj) applyRelocs(binary_bytes.items[code_start..], ptr.offset, ptr.relocations(wasm), wasm);
                        break :append;
                    },
                    inline .uav_exe, .uav_obj, .nav_exe, .nav_obj => |i| i.value(wasm).code,
                };
                try binary_bytes.appendSlice(gpa, code.slice(wasm));
            }
            segment_offset += @intCast(binary_bytes.items.len - code_start);
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .data, @intCast(f.data_segment_groups.items.len));
        data_section_index = section_index;
        section_index += 1;
    }

    if (is_obj) {
        @panic("TODO emit link section for object file and emit modified relocations");
    } else if (comp.config.debug_format != .strip) {
        try emitNameSection(wasm, f.data_segment_groups.items, binary_bytes);
    }

    if (comp.config.debug_format != .strip) {
        // The build id must be computed on the main sections only,
        // so we have to do it now, before the debug sections.
        switch (wasm.base.build_id) {
            .none => {},
            .fast => {
                var id: [16]u8 = undefined;
                std.crypto.hash.sha3.TurboShake128(null).hash(binary_bytes.items, &id, .{});
                var uuid: [36]u8 = undefined;
                _ = try std.fmt.bufPrint(&uuid, "{x}-{x}-{x}-{x}-{x}", .{
                    id[0..4], id[4..6], id[6..8], id[8..10], id[10..],
                });
                try emitBuildIdSection(gpa, binary_bytes, &uuid);
            },
            .hexstring => |hs| {
                var buffer: [32 * 2]u8 = undefined;
                const str = std.fmt.bufPrint(&buffer, "{x}", .{hs.toSlice()}) catch unreachable;
                try emitBuildIdSection(gpa, binary_bytes, str);
            },
            else => |mode| {
                var err = try diags.addErrorWithNotes(0);
                try err.addMsg("build-id '{s}' is not supported for WebAssembly", .{@tagName(mode)});
            },
        }

        var debug_bytes = std.ArrayList(u8).init(gpa);
        defer debug_bytes.deinit();

        try emitProducerSection(gpa, binary_bytes);
        try emitFeaturesSection(gpa, binary_bytes, target);
    }

    // Finally, write the entire binary into the file.
    const file = wasm.base.file.?;
    try file.pwriteAll(binary_bytes.items, 0);
    try file.setEndPos(binary_bytes.items.len);
}

const VirtualAddrs = struct {
    stack_pointer: u32,
    heap_base: u32,
    heap_end: u32,
    tls_base: ?u32,
    tls_align: Alignment,
    tls_size: ?u32,
    init_memory_flag: ?u32,
};

fn emitNameSection(
    wasm: *Wasm,
    data_segment_groups: []const DataSegmentGroup,
    binary_bytes: *std.ArrayListUnmanaged(u8),
) !void {
    const f = &wasm.flush_buffer;
    const comp = wasm.base.comp;
    const gpa = comp.gpa;

    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
    defer writeCustomSectionHeader(binary_bytes, header_offset);

    const name_name = "name";
    try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, name_name.len));
    try binary_bytes.appendSlice(gpa, name_name);

    {
        const sub_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
        defer replaceHeader(binary_bytes, sub_offset, @intFromEnum(std.wasm.NameSubsection.function));

        const total_functions: u32 = @intCast(f.function_imports.entries.len + wasm.functions.entries.len);
        try leb.writeUleb128(binary_bytes.writer(gpa), total_functions);

        for (f.function_imports.keys(), 0..) |name_index, function_index| {
            const name = name_index.slice(wasm);
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(function_index)));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
        }
        for (wasm.functions.keys(), f.function_imports.entries.len..) |resolution, function_index| {
            const name = resolution.name(wasm).?;
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(function_index)));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
        }
    }

    {
        const sub_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
        defer replaceHeader(binary_bytes, sub_offset, @intFromEnum(std.wasm.NameSubsection.global));

        const total_globals: u32 = @intCast(f.global_imports.entries.len + wasm.globals.entries.len);
        try leb.writeUleb128(binary_bytes.writer(gpa), total_globals);

        for (f.global_imports.keys(), 0..) |name_index, global_index| {
            const name = name_index.slice(wasm);
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(global_index)));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
        }
        for (wasm.globals.keys(), f.global_imports.entries.len..) |resolution, global_index| {
            const name = resolution.name(wasm).?;
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(global_index)));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
        }
    }

    {
        const sub_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
        defer replaceHeader(binary_bytes, sub_offset, @intFromEnum(std.wasm.NameSubsection.data_segment));

        const total_data_segments: u32 = @intCast(data_segment_groups.len);
        try leb.writeUleb128(binary_bytes.writer(gpa), total_data_segments);

        for (data_segment_groups, 0..) |group, i| {
            const name, _ = splitSegmentName(group.first_segment.name(wasm));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(i)));
            try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
        }
    }
}

fn emitFeaturesSection(
    gpa: Allocator,
    binary_bytes: *std.ArrayListUnmanaged(u8),
    target: *const std.Target,
) Allocator.Error!void {
    const feature_count = target.cpu.features.count();
    if (feature_count == 0) return;

    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
    defer writeCustomSectionHeader(binary_bytes, header_offset);

    const writer = binary_bytes.writer(gpa);
    const target_features = "target_features";
    try leb.writeUleb128(writer, @as(u32, @intCast(target_features.len)));
    try writer.writeAll(target_features);

    try leb.writeUleb128(writer, @as(u32, @intCast(feature_count)));

    var safety_count = feature_count;
    for (target.cpu.arch.allFeaturesList(), 0..) |*feature, i| {
        if (!std.Target.wasm.featureSetHas(target.cpu.features, @enumFromInt(i))) continue;
        safety_count -= 1;

        try leb.writeUleb128(writer, @as(u32, '+'));
        // Depends on llvm_name for the hyphenated version that matches wasm tooling conventions.
        const name = feature.llvm_name.?;
        try leb.writeUleb128(writer, @as(u32, @intCast(name.len)));
        try writer.writeAll(name);
    }
    assert(safety_count == 0);
}

fn emitBuildIdSection(gpa: Allocator, binary_bytes: *std.ArrayListUnmanaged(u8), build_id: []const u8) !void {
    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
    defer writeCustomSectionHeader(binary_bytes, header_offset);

    const writer = binary_bytes.writer(gpa);
    const hdr_build_id = "build_id";
    try leb.writeUleb128(writer, @as(u32, @intCast(hdr_build_id.len)));
    try writer.writeAll(hdr_build_id);

    try leb.writeUleb128(writer, @as(u32, 1));
    try leb.writeUleb128(writer, @as(u32, @intCast(build_id.len)));
    try writer.writeAll(build_id);
}

fn emitProducerSection(gpa: Allocator, binary_bytes: *std.ArrayListUnmanaged(u8)) !void {
    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
    defer writeCustomSectionHeader(binary_bytes, header_offset);

    const writer = binary_bytes.writer(gpa);
    const producers = "producers";
    try leb.writeUleb128(writer, @as(u32, @intCast(producers.len)));
    try writer.writeAll(producers);

    try leb.writeUleb128(writer, @as(u32, 2)); // 2 fields: Language + processed-by

    // language field
    {
        const language = "language";
        try leb.writeUleb128(writer, @as(u32, @intCast(language.len)));
        try writer.writeAll(language);

        // field_value_count (TODO: Parse object files for producer sections to detect their language)
        try leb.writeUleb128(writer, @as(u32, 1));

        // versioned name
        {
            try leb.writeUleb128(writer, @as(u32, 3)); // len of "Zig"
            try writer.writeAll("Zig");

            try leb.writeUleb128(writer, @as(u32, @intCast(build_options.version.len)));
            try writer.writeAll(build_options.version);
        }
    }

    // processed-by field
    {
        const processed_by = "processed-by";
        try leb.writeUleb128(writer, @as(u32, @intCast(processed_by.len)));
        try writer.writeAll(processed_by);

        // field_value_count (TODO: Parse object files for producer sections to detect other used tools)
        try leb.writeUleb128(writer, @as(u32, 1));

        // versioned name
        {
            try leb.writeUleb128(writer, @as(u32, 3)); // len of "Zig"
            try writer.writeAll("Zig");

            try leb.writeUleb128(writer, @as(u32, @intCast(build_options.version.len)));
            try writer.writeAll(build_options.version);
        }
    }
}

fn splitSegmentName(name: []const u8) struct { []const u8, []const u8 } {
    const start = @intFromBool(name.len >= 1 and name[0] == '.');
    const pivot = mem.indexOfScalarPos(u8, name, start, '.') orelse name.len;
    return .{ name[0..pivot], name[pivot..] };
}

test splitSegmentName {
    {
        const a, const b = splitSegmentName(".data");
        try std.testing.expectEqualStrings(".data", a);
        try std.testing.expectEqualStrings("", b);
    }
}

fn wantSegmentMerge(
    wasm: *const Wasm,
    a_id: Wasm.DataSegmentId,
    b_id: Wasm.DataSegmentId,
    b_category: Wasm.DataSegmentId.Category,
) bool {
    const a_category = a_id.category(wasm);
    if (a_category != b_category) return false;
    if (a_category == .tls or b_category == .tls) return false;
    if (a_id.isPassive(wasm) != b_id.isPassive(wasm)) return false;
    if (b_category == .zero) return true;
    const a_name = a_id.name(wasm);
    const b_name = b_id.name(wasm);
    const a_prefix, _ = splitSegmentName(a_name);
    const b_prefix, _ = splitSegmentName(b_name);
    return mem.eql(u8, a_prefix, b_prefix);
}

/// section id + fixed leb contents size + fixed leb vector length
const section_header_reserve_size = 1 + 5 + 5;
const section_header_size = 5 + 1;

fn reserveVecSectionHeader(gpa: Allocator, bytes: *std.ArrayListUnmanaged(u8)) Allocator.Error!u32 {
    try bytes.appendNTimes(gpa, 0, section_header_reserve_size);
    return @intCast(bytes.items.len - section_header_reserve_size);
}

fn replaceVecSectionHeader(
    bytes: *std.ArrayListUnmanaged(u8),
    offset: u32,
    section: std.wasm.Section,
    n_items: u32,
) void {
    const size: u32 = @intCast(bytes.items.len - offset - section_header_reserve_size + uleb128size(n_items));
    var buf: [section_header_reserve_size]u8 = undefined;
    var fbw = std.io.fixedBufferStream(&buf);
    const w = fbw.writer();
    w.writeByte(@intFromEnum(section)) catch unreachable;
    leb.writeUleb128(w, size) catch unreachable;
    leb.writeUleb128(w, n_items) catch unreachable;
    bytes.replaceRangeAssumeCapacity(offset, section_header_reserve_size, fbw.getWritten());
}

fn reserveCustomSectionHeader(gpa: Allocator, bytes: *std.ArrayListUnmanaged(u8)) Allocator.Error!u32 {
    try bytes.appendNTimes(gpa, 0, section_header_size);
    return @intCast(bytes.items.len - section_header_size);
}

fn writeCustomSectionHeader(bytes: *std.ArrayListUnmanaged(u8), offset: u32) void {
    return replaceHeader(bytes, offset, 0); // 0 = 'custom' section
}

fn replaceHeader(bytes: *std.ArrayListUnmanaged(u8), offset: u32, tag: u8) void {
    const size: u32 = @intCast(bytes.items.len - offset - section_header_size);
    var buf: [section_header_size]u8 = undefined;
    var fbw = std.io.fixedBufferStream(&buf);
    const w = fbw.writer();
    w.writeByte(tag) catch unreachable;
    leb.writeUleb128(w, size) catch unreachable;
    bytes.replaceRangeAssumeCapacity(offset, section_header_size, fbw.getWritten());
}

const max_size_encoding = 5;

fn reserveSize(gpa: Allocator, bytes: *std.ArrayListUnmanaged(u8)) Allocator.Error!u32 {
    try bytes.appendNTimes(gpa, 0, max_size_encoding);
    return @intCast(bytes.items.len - max_size_encoding);
}

fn replaceSize(bytes: *std.ArrayListUnmanaged(u8), offset: u32) void {
    const size: u32 = @intCast(bytes.items.len - offset - max_size_encoding);
    var buf: [max_size_encoding]u8 = undefined;
    var fbw = std.io.fixedBufferStream(&buf);
    leb.writeUleb128(fbw.writer(), size) catch unreachable;
    bytes.replaceRangeAssumeCapacity(offset, max_size_encoding, fbw.getWritten());
}

fn emitLimits(
    gpa: Allocator,
    binary_bytes: *std.ArrayListUnmanaged(u8),
    limits: std.wasm.Limits,
) Allocator.Error!void {
    try binary_bytes.append(gpa, @bitCast(limits.flags));
    try leb.writeUleb128(binary_bytes.writer(gpa), limits.min);
    if (limits.flags.has_max) try leb.writeUleb128(binary_bytes.writer(gpa), limits.max);
}

fn emitMemoryImport(
    wasm: *Wasm,
    binary_bytes: *std.ArrayListUnmanaged(u8),
    name_index: String,
    memory_import: *const Wasm.MemoryImport,
) Allocator.Error!void {
    const gpa = wasm.base.comp.gpa;
    const module_name = memory_import.module_name.slice(wasm);
    try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(module_name.len)));
    try binary_bytes.appendSlice(gpa, module_name);

    const name = name_index.slice(wasm);
    try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(name.len)));
    try binary_bytes.appendSlice(gpa, name);

    try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.memory));
    try emitLimits(gpa, binary_bytes, memory_import.limits());
}

pub fn emitInit(writer: anytype, init_expr: std.wasm.InitExpression) !void {
    switch (init_expr) {
        .i32_const => |val| {
            try writer.writeByte(@intFromEnum(std.wasm.Opcode.i32_const));
            try leb.writeIleb128(writer, val);
        },
        .i64_const => |val| {
            try writer.writeByte(@intFromEnum(std.wasm.Opcode.i64_const));
            try leb.writeIleb128(writer, val);
        },
        .f32_const => |val| {
            try writer.writeByte(@intFromEnum(std.wasm.Opcode.f32_const));
            try writer.writeInt(u32, @bitCast(val), .little);
        },
        .f64_const => |val| {
            try writer.writeByte(@intFromEnum(std.wasm.Opcode.f64_const));
            try writer.writeInt(u64, @bitCast(val), .little);
        },
        .global_get => |val| {
            try writer.writeByte(@intFromEnum(std.wasm.Opcode.global_get));
            try leb.writeUleb128(writer, val);
        },
    }
    try writer.writeByte(@intFromEnum(std.wasm.Opcode.end));
}

pub fn emitExpr(wasm: *const Wasm, binary_bytes: *std.ArrayListUnmanaged(u8), expr: Wasm.Expr) Allocator.Error!void {
    const gpa = wasm.base.comp.gpa;
    const slice = expr.slice(wasm);
    try binary_bytes.appendSlice(gpa, slice[0 .. slice.len + 1]); // +1 to include end opcode
}

fn emitSegmentInfo(wasm: *Wasm, binary_bytes: *std.ArrayList(u8)) !void {
    const gpa = wasm.base.comp.gpa;
    const writer = binary_bytes.writer(gpa);
    try leb.writeUleb128(writer, @intFromEnum(Wasm.SubsectionType.segment_info));
    const segment_offset = binary_bytes.items.len;

    try leb.writeUleb128(writer, @as(u32, @intCast(wasm.segment_info.count())));
    for (wasm.segment_info.values()) |segment_info| {
        log.debug("Emit segment: {s} align({d}) flags({b})", .{
            segment_info.name,
            segment_info.alignment,
            segment_info.flags,
        });
        try leb.writeUleb128(writer, @as(u32, @intCast(segment_info.name.len)));
        try writer.writeAll(segment_info.name);
        try leb.writeUleb128(writer, segment_info.alignment.toLog2Units());
        try leb.writeUleb128(writer, segment_info.flags);
    }

    var buf: [5]u8 = undefined;
    leb.writeUnsignedFixed(5, &buf, @as(u32, @intCast(binary_bytes.items.len - segment_offset)));
    try binary_bytes.insertSlice(segment_offset, &buf);
}

fn uleb128size(x: u32) u32 {
    var value = x;
    var size: u32 = 0;
    while (value != 0) : (size += 1) value >>= 7;
    return size;
}

fn emitTagNameTable(
    gpa: Allocator,
    code: *std.ArrayListUnmanaged(u8),
    tag_name_offs: []const u32,
    tag_name_bytes: []const u8,
    base: u32,
    comptime Int: type,
) error{OutOfMemory}!void {
    const ptr_size_bytes = @divExact(@bitSizeOf(Int), 8);
    try code.ensureUnusedCapacity(gpa, ptr_size_bytes * 2 * tag_name_offs.len);
    for (tag_name_offs) |off| {
        const name_len: u32 = @intCast(mem.indexOfScalar(u8, tag_name_bytes[off..], 0).?);
        mem.writeInt(Int, code.addManyAsArrayAssumeCapacity(ptr_size_bytes), base + off, .little);
        mem.writeInt(Int, code.addManyAsArrayAssumeCapacity(ptr_size_bytes), name_len, .little);
    }
}

fn applyRelocs(code: []u8, code_offset: u32, relocs: Wasm.ObjectRelocation.IterableSlice, wasm: *const Wasm) void {
    for (
        relocs.slice.tags(wasm),
        relocs.slice.pointees(wasm),
        relocs.slice.offsets(wasm),
        relocs.slice.addends(wasm),
    ) |tag, pointee, offset, *addend| {
        if (offset >= relocs.end) break;
        const sliced_code = code[offset - code_offset ..];
        switch (tag) {
            .function_index_i32 => reloc_u32_function(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),
            .function_index_leb => reloc_leb_function(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),
            .function_offset_i32 => @panic("TODO this value is not known yet"),
            .function_offset_i64 => @panic("TODO this value is not known yet"),
            .table_index_i32 => reloc_u32_table_index(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),
            .table_index_i64 => reloc_u64_table_index(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),
            .table_index_rel_sleb => @panic("TODO what does this reloc tag mean?"),
            .table_index_rel_sleb64 => @panic("TODO what does this reloc tag mean?"),
            .table_index_sleb => reloc_sleb_table_index(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),
            .table_index_sleb64 => reloc_sleb64_table_index(sliced_code, .fromObjectFunctionHandlingWeak(wasm, pointee.function)),

            .function_import_index_i32 => reloc_u32_function(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .function_import_index_leb => reloc_leb_function(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .function_import_offset_i32 => @panic("TODO this value is not known yet"),
            .function_import_offset_i64 => @panic("TODO this value is not known yet"),
            .table_import_index_i32 => reloc_u32_table_index(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .table_import_index_i64 => reloc_u64_table_index(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .table_import_index_rel_sleb => @panic("TODO what does this reloc tag mean?"),
            .table_import_index_rel_sleb64 => @panic("TODO what does this reloc tag mean?"),
            .table_import_index_sleb => reloc_sleb_table_index(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .table_import_index_sleb64 => reloc_sleb64_table_index(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),

            .global_index_i32 => reloc_u32_global(sliced_code, .fromObjectGlobalHandlingWeak(wasm, pointee.global)),
            .global_index_leb => reloc_leb_global(sliced_code, .fromObjectGlobalHandlingWeak(wasm, pointee.global)),

            .global_import_index_i32 => reloc_u32_global(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),
            .global_import_index_leb => reloc_leb_global(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),

            .memory_addr_i32 => reloc_u32_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_i64 => reloc_u64_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_leb => reloc_leb_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_leb64 => reloc_leb64_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_locrel_i32 => @panic("TODO implement relocation memory_addr_locrel_i32"),
            .memory_addr_rel_sleb => @panic("TODO implement relocation memory_addr_rel_sleb"),
            .memory_addr_rel_sleb64 => @panic("TODO implement relocation memory_addr_rel_sleb64"),
            .memory_addr_sleb => reloc_sleb_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_sleb64 => reloc_sleb64_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_tls_sleb => reloc_sleb_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),
            .memory_addr_tls_sleb64 => reloc_sleb64_addr(sliced_code, .fromObjectData(wasm, pointee.data, addend.*)),

            .memory_addr_import_i32 => reloc_u32_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_i64 => reloc_u64_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_leb => reloc_leb_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_leb64 => reloc_leb64_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_locrel_i32 => @panic("TODO implement relocation memory_addr_import_locrel_i32"),
            .memory_addr_import_rel_sleb => @panic("TODO implement relocation memory_addr_import_rel_sleb"),
            .memory_addr_import_rel_sleb64 => @panic("TODO implement memory_addr_import_rel_sleb64"),
            .memory_addr_import_sleb => reloc_sleb_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_sleb64 => reloc_sleb64_addr(sliced_code, .fromSymbolName(wasm, pointee.symbol_name, addend.*)),
            .memory_addr_import_tls_sleb => @panic("TODO"),
            .memory_addr_import_tls_sleb64 => @panic("TODO"),

            .section_offset_i32 => @panic("TODO this value is not known yet"),

            .table_number_leb => reloc_leb_table(sliced_code, .fromObjectTable(wasm, pointee.table)),
            .table_import_number_leb => reloc_leb_table(sliced_code, .fromSymbolName(wasm, pointee.symbol_name)),

            .type_index_leb => reloc_leb_type(sliced_code, .fromTypeIndex(pointee.type_index, &wasm.flush_buffer)),
        }
    }
}

fn reloc_u32_table_index(code: []u8, i: IndirectFunctionTableIndex) void {
    mem.writeInt(u32, code[0..4], i.toAbi(), .little);
}

fn reloc_u64_table_index(code: []u8, i: IndirectFunctionTableIndex) void {
    mem.writeInt(u64, code[0..8], i.toAbi(), .little);
}

fn reloc_sleb_table_index(code: []u8, i: IndirectFunctionTableIndex) void {
    leb.writeSignedFixed(5, code[0..5], i.toAbi());
}

fn reloc_sleb64_table_index(code: []u8, i: IndirectFunctionTableIndex) void {
    leb.writeSignedFixed(11, code[0..11], i.toAbi());
}

fn reloc_u32_function(code: []u8, function: Wasm.OutputFunctionIndex) void {
    mem.writeInt(u32, code[0..4], @intFromEnum(function), .little);
}

fn reloc_leb_function(code: []u8, function: Wasm.OutputFunctionIndex) void {
    leb.writeUnsignedFixed(5, code[0..5], @intFromEnum(function));
}

fn reloc_u32_global(code: []u8, global: Wasm.GlobalIndex) void {
    mem.writeInt(u32, code[0..4], @intFromEnum(global), .little);
}

fn reloc_leb_global(code: []u8, global: Wasm.GlobalIndex) void {
    leb.writeUnsignedFixed(5, code[0..5], @intFromEnum(global));
}

const RelocAddr = struct {
    addr: u32,

    fn fromObjectData(wasm: *const Wasm, i: Wasm.ObjectData.Index, addend: i32) RelocAddr {
        return fromDataLoc(&wasm.flush_buffer, .fromObjectDataIndex(wasm, i), addend);
    }

    fn fromSymbolName(wasm: *const Wasm, name: String, addend: i32) RelocAddr {
        const flush = &wasm.flush_buffer;
        if (wasm.object_data_imports.getPtr(name)) |import| {
            return fromDataLoc(flush, import.resolution.dataLoc(wasm), addend);
        } else if (wasm.data_imports.get(name)) |id| {
            return fromDataLoc(flush, .fromDataImportId(wasm, id), addend);
        } else {
            unreachable;
        }
    }

    fn fromDataLoc(flush: *const Flush, data_loc: Wasm.DataLoc, addend: i32) RelocAddr {
        const base_addr: i64 = flush.data_segments.get(data_loc.segment).?;
        return .{ .addr = @intCast(base_addr + data_loc.offset + addend) };
    }
};

fn reloc_u32_addr(code: []u8, ra: RelocAddr) void {
    mem.writeInt(u32, code[0..4], ra.addr, .little);
}

fn reloc_u64_addr(code: []u8, ra: RelocAddr) void {
    mem.writeInt(u64, code[0..8], ra.addr, .little);
}

fn reloc_leb_addr(code: []u8, ra: RelocAddr) void {
    leb.writeUnsignedFixed(5, code[0..5], ra.addr);
}

fn reloc_leb64_addr(code: []u8, ra: RelocAddr) void {
    leb.writeUnsignedFixed(11, code[0..11], ra.addr);
}

fn reloc_sleb_addr(code: []u8, ra: RelocAddr) void {
    leb.writeSignedFixed(5, code[0..5], ra.addr);
}

fn reloc_sleb64_addr(code: []u8, ra: RelocAddr) void {
    leb.writeSignedFixed(11, code[0..11], ra.addr);
}

fn reloc_leb_table(code: []u8, table: Wasm.TableIndex) void {
    leb.writeUnsignedFixed(5, code[0..5], @intFromEnum(table));
}

fn reloc_leb_type(code: []u8, index: FuncTypeIndex) void {
    leb.writeUnsignedFixed(5, code[0..5], @intFromEnum(index));
}

fn emitCallCtorsFunction(wasm: *const Wasm, binary_bytes: *std.ArrayListUnmanaged(u8)) Allocator.Error!void {
    const gpa = wasm.base.comp.gpa;

    try binary_bytes.ensureUnusedCapacity(gpa, 5 + 1);
    appendReservedUleb32(binary_bytes, 0); // no locals

    for (wasm.object_init_funcs.items) |init_func| {
        const func = init_func.function_index.ptr(wasm);
        if (!func.object_index.ptr(wasm).is_included) continue;
        const ty = func.type_index.ptr(wasm);
        const n_returns = ty.returns.slice(wasm).len;

        // Call function by its function index
        try binary_bytes.ensureUnusedCapacity(gpa, 1 + 5 + n_returns + 1);
        const call_index: Wasm.OutputFunctionIndex = .fromObjectFunction(wasm, init_func.function_index);
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call));
        appendReservedUleb32(binary_bytes, @intFromEnum(call_index));

        // drop all returned values from the stack as __wasm_call_ctors has no return value
        binary_bytes.appendNTimesAssumeCapacity(@intFromEnum(std.wasm.Opcode.drop), n_returns);
    }

    binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end)); // end function body
}

fn emitInitMemoryFunction(
    wasm: *const Wasm,
    binary_bytes: *std.ArrayListUnmanaged(u8),
    virtual_addrs: *const VirtualAddrs,
) Allocator.Error!void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const shared_memory = comp.config.shared_memory;

    // Passive segments are used to avoid memory being reinitialized on each
    // thread's instantiation. These passive segments are initialized and
    // dropped in __wasm_init_memory, which is registered as the start function
    // We also initialize bss segments (using memory.fill) as part of this
    // function.
    assert(wasm.any_passive_inits);

    try binary_bytes.ensureUnusedCapacity(gpa, 5 + 1);
    appendReservedUleb32(binary_bytes, 0); // no locals

    if (virtual_addrs.init_memory_flag) |flag_address| {
        assert(shared_memory);
        try binary_bytes.ensureUnusedCapacity(gpa, 2 * 3 + 6 * 3 + 1 + 6 * 3 + 1 + 5 * 4 + 1 + 1);
        // destination blocks
        // based on values we jump to corresponding label
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.block)); // $drop
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.BlockType.empty));

        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.block)); // $wait
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.BlockType.empty));

        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.block)); // $init
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.BlockType.empty));

        // atomically check
        appendReservedI32Const(binary_bytes, flag_address);
        appendReservedI32Const(binary_bytes, 0);
        appendReservedI32Const(binary_bytes, 1);
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.atomics_prefix));
        appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.AtomicsOpcode.i32_atomic_rmw_cmpxchg));
        appendReservedUleb32(binary_bytes, 2); // alignment
        appendReservedUleb32(binary_bytes, 0); // offset

        // based on the value from the atomic check, jump to the label.
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.br_table));
        appendReservedUleb32(binary_bytes, 2); // length of the table (we have 3 blocks but because of the mandatory default the length is 2).
        appendReservedUleb32(binary_bytes, 0); // $init
        appendReservedUleb32(binary_bytes, 1); // $wait
        appendReservedUleb32(binary_bytes, 2); // $drop
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
    }

    const segment_groups = wasm.flush_buffer.data_segment_groups.items;
    var prev_end: u32 = 0;
    for (segment_groups, 0..) |group, segment_index| {
        defer prev_end = group.end_addr;
        const segment = group.first_segment;
        if (!segment.isPassive(wasm)) continue;

        const start_addr: u32 = @intCast(segment.alignment(wasm).forward(prev_end));
        const segment_size: u32 = group.end_addr - start_addr;

        try binary_bytes.ensureUnusedCapacity(gpa, 6 + 6 + 1 + 5 + 6 + 6 + 1 + 6 * 2 + 1 + 1);

        // For passive BSS segments we can simply issue a memory.fill(0). For
        // non-BSS segments we do a memory.init. Both instructions take as
        // their first argument the destination address.
        appendReservedI32Const(binary_bytes, start_addr);

        if (shared_memory and segment.isTls(wasm)) {
            // When we initialize the TLS segment we also set the `__tls_base`
            // global.  This allows the runtime to use this static copy of the
            // TLS data for the first/main thread.
            appendReservedI32Const(binary_bytes, start_addr);
            binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.global_set));
            appendReservedUleb32(binary_bytes, virtual_addrs.tls_base.?);
        }

        appendReservedI32Const(binary_bytes, 0);
        appendReservedI32Const(binary_bytes, segment_size);
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.misc_prefix));
        if (segment.isBss(wasm)) {
            // fill bss segment with zeroes
            appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.MiscOpcode.memory_fill));
        } else {
            // initialize the segment
            appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.MiscOpcode.memory_init));
            appendReservedUleb32(binary_bytes, @intCast(segment_index));
        }
        binary_bytes.appendAssumeCapacity(0); // memory index immediate
    }

    if (virtual_addrs.init_memory_flag) |flag_address| {
        assert(shared_memory);
        try binary_bytes.ensureUnusedCapacity(gpa, 6 + 6 + 1 + 3 * 5 + 6 + 1 + 5 + 1 + 3 * 5 + 1 + 1 + 5 + 1 + 6 * 2 + 1 + 5 + 1 + 3 * 5 + 1 + 1 + 1);
        // we set the init memory flag to value '2'
        appendReservedI32Const(binary_bytes, flag_address);
        appendReservedI32Const(binary_bytes, 2);
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.atomics_prefix));
        appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.AtomicsOpcode.i32_atomic_store));
        appendReservedUleb32(binary_bytes, @as(u32, 2)); // alignment
        appendReservedUleb32(binary_bytes, @as(u32, 0)); // offset

        // notify any waiters for segment initialization completion
        appendReservedI32Const(binary_bytes, flag_address);
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
        leb.writeIleb128(binary_bytes.fixedWriter(), @as(i32, -1)) catch unreachable; // number of waiters
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.atomics_prefix));
        appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.AtomicsOpcode.memory_atomic_notify));
        appendReservedUleb32(binary_bytes, @as(u32, 2)); // alignment
        appendReservedUleb32(binary_bytes, @as(u32, 0)); // offset
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.drop));

        // branch and drop segments
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.br));
        appendReservedUleb32(binary_bytes, @as(u32, 1));

        // wait for thread to initialize memory segments
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end)); // end $wait
        appendReservedI32Const(binary_bytes, flag_address);
        appendReservedI32Const(binary_bytes, 1); // expected flag value
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_const));
        leb.writeIleb128(binary_bytes.fixedWriter(), @as(i64, -1)) catch unreachable; // timeout
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.atomics_prefix));
        appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.AtomicsOpcode.memory_atomic_wait32));
        appendReservedUleb32(binary_bytes, @as(u32, 2)); // alignment
        appendReservedUleb32(binary_bytes, @as(u32, 0)); // offset
        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.drop));

        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end)); // end $drop
    }

    for (segment_groups, 0..) |group, segment_index| {
        const segment = group.first_segment;
        if (!segment.isPassive(wasm)) continue;
        if (segment.isBss(wasm)) continue;
        // The TLS region should not be dropped since its is needed
        // during the initialization of each thread (__wasm_init_tls).
        if (shared_memory and segment.isTls(wasm)) continue;

        try binary_bytes.ensureUnusedCapacity(gpa, 1 + 5 + 5 + 1);

        binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.misc_prefix));
        appendReservedUleb32(binary_bytes, @intFromEnum(std.wasm.MiscOpcode.data_drop));
        appendReservedUleb32(binary_bytes, @intCast(segment_index));
    }

    // End of the function body
    binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
}

fn emitInitTlsFunction(wasm: *const Wasm, bytes: *std.ArrayListUnmanaged(u8)) Allocator.Error!void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;

    assert(comp.config.shared_memory);

    try bytes.ensureUnusedCapacity(gpa, 5 * 10 + 8);

    appendReservedUleb32(bytes, 0); // no locals

    // If there's a TLS segment, initialize it during runtime using the bulk-memory feature
    // TLS segment is always the first one due to how we sort the data segments.
    const data_segments = wasm.flush_buffer.data_segments.keys();
    if (data_segments.len > 0 and data_segments[0].isTls(wasm)) {
        const start_addr = wasm.flush_buffer.data_segments.values()[0];
        const end_addr = wasm.flush_buffer.data_segment_groups.items[0].end_addr;
        const group_size = end_addr - start_addr;
        const data_segment_index = 0;

        const param_local: u32 = 0;

        bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
        appendReservedUleb32(bytes, param_local);

        const tls_base_global_index: Wasm.GlobalIndex = @enumFromInt(wasm.globals.getIndex(.__tls_base).?);
        bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.global_set));
        appendReservedUleb32(bytes, @intFromEnum(tls_base_global_index));

        // load stack values for the bulk-memory operation
        {
            bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
            appendReservedUleb32(bytes, param_local);

            bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
            appendReservedUleb32(bytes, 0); //segment offset

            bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
            appendReservedUleb32(bytes, group_size); //segment offset
        }

        // perform the bulk-memory operation to initialize the data segment
        bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.misc_prefix));
        appendReservedUleb32(bytes, @intFromEnum(std.wasm.MiscOpcode.memory_init));
        // segment immediate
        appendReservedUleb32(bytes, data_segment_index);
        // memory index immediate (always 0)
        appendReservedUleb32(bytes, 0);
    }

    // If we have to perform any TLS relocations, call the corresponding function
    // which performs all runtime TLS relocations. This is a synthetic function,
    // generated by the linker.
    if (wasm.functions.getIndex(.__wasm_apply_global_tls_relocs)) |function_index| {
        const output_function_index: Wasm.OutputFunctionIndex = .fromFunctionIndex(wasm, @enumFromInt(function_index));
        bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call));
        appendReservedUleb32(bytes, @intFromEnum(output_function_index));
    }

    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
}

fn emitStartSection(gpa: Allocator, bytes: *std.ArrayListUnmanaged(u8), i: Wasm.OutputFunctionIndex) !void {
    const header_offset = try reserveVecSectionHeader(gpa, bytes);
    replaceVecSectionHeader(bytes, header_offset, .start, @intFromEnum(i));
}

fn emitTagNameFunction(
    wasm: *Wasm,
    code: *std.ArrayListUnmanaged(u8),
    table_base_addr: u32,
    table_index: u32,
    enum_type_ip: InternPool.Index,
) !void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const zcu = comp.zcu.?;
    const ip = &zcu.intern_pool;
    const enum_type = ip.loadEnumType(enum_type_ip);
    const tag_values = enum_type.values.get(ip);

    try code.ensureUnusedCapacity(gpa, 7 * 5 + 6 + 1 * 6);
    appendReservedUleb32(code, 0); // no locals

    const slice_abi_size = 8;
    const encoded_alignment = @ctz(@as(u32, 4));
    if (tag_values.len == 0) {
        // Then it's auto-numbered and therefore a direct table lookup.
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
        appendReservedUleb32(code, 0);

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
        appendReservedUleb32(code, 1);

        appendReservedI32Const(code, slice_abi_size);
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_mul));

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_load));
        appendReservedUleb32(code, encoded_alignment);
        appendReservedUleb32(code, table_base_addr + table_index * 8);

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_store));
        appendReservedUleb32(code, encoded_alignment);
        appendReservedUleb32(code, 0);
    } else {
        const int_info = Zcu.Type.intInfo(.fromInterned(enum_type.tag_ty), zcu);
        const outer_block_type: std.wasm.BlockType = switch (int_info.bits) {
            0...32 => .i32,
            33...64 => .i64,
            else => return diags.fail("wasm linker does not yet implement @tagName for sparse enums with more than 64 bit integer tag types", .{}),
        };

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
        appendReservedUleb32(code, 0);

        // Outer block that computes table offset.
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.block));
        code.appendAssumeCapacity(@intFromEnum(outer_block_type));

        for (tag_values, 0..) |tag_value, tag_index| {
            // block for this if case
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.block));
            code.appendAssumeCapacity(@intFromEnum(std.wasm.BlockType.empty));

            // Tag value whose name should be returned.
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.local_get));
            appendReservedUleb32(code, 1);

            const val: Zcu.Value = .fromInterned(tag_value);
            switch (outer_block_type) {
                .i32 => {
                    const x: u32 = switch (int_info.signedness) {
                        .signed => @bitCast(@as(i32, @intCast(val.toSignedInt(zcu)))),
                        .unsigned => @intCast(val.toUnsignedInt(zcu)),
                    };
                    appendReservedI32Const(code, x);
                    code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_ne));
                },
                .i64 => {
                    const x: u64 = switch (int_info.signedness) {
                        .signed => @bitCast(val.toSignedInt(zcu)),
                        .unsigned => val.toUnsignedInt(zcu),
                    };
                    appendReservedI64Const(code, x);
                    code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_ne));
                },
                else => unreachable,
            }

            // if they're not equal, break out of current branch
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.br_if));
            appendReservedUleb32(code, 0);

            // Put the table offset of the result on the stack.
            appendReservedI32Const(code, @intCast(tag_index * slice_abi_size));

            // break outside blocks
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.br));
            appendReservedUleb32(code, 1);

            // end the block for this case
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
        }
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.@"unreachable"));
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_load));
        appendReservedUleb32(code, encoded_alignment);
        appendReservedUleb32(code, table_base_addr + table_index * 8);

        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_store));
        appendReservedUleb32(code, encoded_alignment);
        appendReservedUleb32(code, 0);
    }

    // End of the function body
    code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
}

/// Writes an unsigned 32-bit integer as a LEB128-encoded 'i32.const' value.
fn appendReservedI32Const(bytes: *std.ArrayListUnmanaged(u8), val: u32) void {
    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
    leb.writeIleb128(bytes.fixedWriter(), @as(i32, @bitCast(val))) catch unreachable;
}

/// Writes an unsigned 64-bit integer as a LEB128-encoded 'i64.const' value.
fn appendReservedI64Const(bytes: *std.ArrayListUnmanaged(u8), val: u64) void {
    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_const));
    leb.writeIleb128(bytes.fixedWriter(), @as(i64, @bitCast(val))) catch unreachable;
}

fn appendReservedUleb32(bytes: *std.ArrayListUnmanaged(u8), val: u32) void {
    leb.writeUleb128(bytes.fixedWriter(), val) catch unreachable;
}

fn appendGlobal(gpa: Allocator, bytes: *std.ArrayListUnmanaged(u8), mutable: u8, val: u32) Allocator.Error!void {
    try bytes.ensureUnusedCapacity(gpa, 9);
    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Valtype.i32));
    bytes.appendAssumeCapacity(mutable);
    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
    appendReservedUleb32(bytes, val);
    bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
}
