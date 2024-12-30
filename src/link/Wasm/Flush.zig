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
data_segments: std.AutoArrayHashMapUnmanaged(Wasm.DataId, u32) = .empty,
/// Each time a `data_segment` offset equals zero it indicates a new group, and
/// the next element in this array will contain the total merged segment size.
/// Value is the virtual memory address of the end of the segment.
data_segment_groups: std.ArrayListUnmanaged(u32) = .empty,

binary_bytes: std.ArrayListUnmanaged(u8) = .empty,
missing_exports: std.AutoArrayHashMapUnmanaged(String, void) = .empty,
function_imports: std.AutoArrayHashMapUnmanaged(String, Wasm.FunctionImportId) = .empty,
global_imports: std.AutoArrayHashMapUnmanaged(String, Wasm.GlobalImportId) = .empty,

/// For debug purposes only.
memory_layout_finished: bool = false,

pub fn clear(f: *Flush) void {
    f.data_segments.clearRetainingCapacity();
    f.data_segment_groups.clearRetainingCapacity();
    f.binary_bytes.clearRetainingCapacity();
    f.memory_layout_finished = false;
}

pub fn deinit(f: *Flush, gpa: Allocator) void {
    f.data_segments.deinit(gpa);
    f.data_segment_groups.deinit(gpa);
    f.binary_bytes.deinit(gpa);
    f.missing_exports.deinit(gpa);
    f.function_imports.deinit(gpa);
    f.global_imports.deinit(gpa);
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

        for (wasm.nav_exports.keys()) |*nav_export| {
            if (ip.isFunctionType(ip.getNav(nav_export.nav_index).typeOf(ip))) {
                log.debug("flush export '{s}' nav={d}", .{ nav_export.name.slice(wasm), nav_export.nav_index });
                try wasm.function_exports.append(gpa, .{
                    .name = nav_export.name,
                    .function_index = Wasm.FunctionIndex.fromIpNav(wasm, nav_export.nav_index).?,
                });
                _ = f.missing_exports.swapRemove(nav_export.name);
                _ = f.function_imports.swapRemove(nav_export.name);

                if (nav_export.name.toOptional() == entry_name)
                    wasm.entry_resolution = .fromIpNav(wasm, nav_export.nav_index);
            } else {
                try wasm.global_exports.append(gpa, .{
                    .name = nav_export.name,
                    .global_index = Wasm.GlobalIndex.fromIpNav(wasm, nav_export.nav_index).?,
                });
                _ = f.missing_exports.swapRemove(nav_export.name);
                _ = f.global_imports.swapRemove(nav_export.name);
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
    }

    if (diags.hasErrors()) return error.LinkFailure;

    // TODO only include init functions for objects with must_link=true or
    // which have any alive functions inside them.
    if (wasm.object_init_funcs.items.len > 0) {
        // Zig has no constructors so these are only for object file inputs.
        mem.sortUnstable(Wasm.InitFunc, wasm.object_init_funcs.items, {}, Wasm.InitFunc.lessThan);
        try wasm.functions.put(gpa, .__wasm_call_ctors, {});
    }

    var any_passive_inits = false;

    // Merge and order the data segments. Depends on garbage collection so that
    // unused segments can be omitted.
    try f.data_segments.ensureUnusedCapacity(gpa, wasm.object_data_segments.items.len +
        wasm.uavs_obj.entries.len + wasm.navs_obj.entries.len +
        wasm.uavs_exe.entries.len + wasm.navs_exe.entries.len + 2);
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
    for (wasm.object_data_segments.items, 0..) |*ds, i| {
        if (!ds.flags.alive) continue;
        const obj_seg_index: Wasm.ObjectDataSegment.Index = @enumFromInt(i);
        any_passive_inits = any_passive_inits or ds.flags.is_passive or (import_memory and !wasm.isBss(ds.name));
        _ = f.data_segments.putAssumeCapacityNoClobber(.pack(wasm, .{
            .object = obj_seg_index,
        }), @as(u32, undefined));
    }
    if (wasm.error_name_table_ref_count > 0) {
        f.data_segments.putAssumeCapacity(.__zig_error_names, @as(u32, undefined));
        f.data_segments.putAssumeCapacity(.__zig_error_name_table, @as(u32, undefined));
    }

    try wasm.functions.ensureUnusedCapacity(gpa, 3);

    // Passive segments are used to avoid memory being reinitialized on each
    // thread's instantiation. These passive segments are initialized and
    // dropped in __wasm_init_memory, which is registered as the start function
    // We also initialize bss segments (using memory.fill) as part of this
    // function.
    if (any_passive_inits) {
        wasm.functions.putAssumeCapacity(.__wasm_init_memory, {});
    }

    // When we have TLS GOT entries and shared memory is enabled,
    // we must perform runtime relocations or else we don't create the function.
    if (shared_memory) {
        // This logic that checks `any_tls_relocs` is missing the part where it
        // also notices threadlocal globals from Zcu code.
        if (wasm.any_tls_relocs) wasm.functions.putAssumeCapacity(.__wasm_apply_global_tls_relocs, {});
        wasm.functions.putAssumeCapacity(.__wasm_init_tls, {});
    }

    try wasm.tables.ensureUnusedCapacity(gpa, 1);

    if (wasm.indirect_function_table.entries.len > 0) {
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
        segments: []const Wasm.DataId,
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

    const VirtualAddrs = struct {
        stack_pointer: u32,
        heap_base: u32,
        heap_end: u32,
        tls_base: ?u32,
        tls_align: Alignment,
        tls_size: ?u32,
        init_memory_flag: ?u32,
    };
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
    {
        var seen_tls: enum { before, during, after } = .before;
        var category: Wasm.DataId.Category = undefined;
        for (segment_ids, segment_vaddrs, 0..) |segment_id, *segment_vaddr, i| {
            const alignment = segment_id.alignment(wasm);
            category = segment_id.category(wasm);
            const start_addr = alignment.forward(memory_ptr);

            const want_new_segment = b: {
                if (is_obj) break :b false;
                switch (seen_tls) {
                    .before => if (category == .tls) {
                        virtual_addrs.tls_base = if (shared_memory) 0 else @intCast(start_addr);
                        virtual_addrs.tls_align = alignment;
                        seen_tls = .during;
                        break :b f.data_segment_groups.items.len > 0;
                    },
                    .during => if (category != .tls) {
                        virtual_addrs.tls_size = @intCast(start_addr - virtual_addrs.tls_base.?);
                        virtual_addrs.tls_align = virtual_addrs.tls_align.maxStrict(alignment);
                        seen_tls = .after;
                        break :b true;
                    },
                    .after => {},
                }
                break :b i >= 1 and !wantSegmentMerge(wasm, segment_ids[i - 1], segment_id, category);
            };
            if (want_new_segment) {
                log.debug("new segment at 0x{x} {} {s} {}", .{ start_addr, segment_id, segment_id.name(wasm), category });
                try f.data_segment_groups.append(gpa, @intCast(memory_ptr));
            }

            const size = segment_id.size(wasm);
            segment_vaddr.* = @intCast(start_addr);
            memory_ptr = start_addr + size;
        }
        if (category != .zero) try f.data_segment_groups.append(gpa, @intCast(memory_ptr));
    }

    if (shared_memory and any_passive_inits) {
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

    // Type section
    if (wasm.func_types.entries.len != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        log.debug("Writing type section. Count: ({d})", .{wasm.func_types.entries.len});
        for (wasm.func_types.keys()) |func_type| {
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

        replaceVecSectionHeader(binary_bytes, header_offset, .type, @intCast(wasm.func_types.entries.len));
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

            const name = id.name(wasm).slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_writer.writeAll(name);

            try binary_writer.writeByte(@intFromEnum(std.wasm.ExternalKind.function));
            try leb.writeUleb128(binary_writer, @intFromEnum(id.functionType(wasm)));
        }
        total_imports += f.function_imports.entries.len;

        for (wasm.table_imports.values()) |id| {
            const table_import = id.value(wasm);
            const module_name = table_import.module_name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(module_name.len)));
            try binary_writer.writeAll(module_name);

            const name = id.key(wasm).slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_writer.writeAll(name);

            try binary_writer.writeByte(@intFromEnum(std.wasm.ExternalKind.table));
            try leb.writeUleb128(binary_writer, @intFromEnum(@as(std.wasm.RefType, table_import.flags.ref_type.to())));
            try emitLimits(gpa, binary_bytes, table_import.limits());
        }
        total_imports += wasm.table_imports.entries.len;

        for (wasm.object_memory_imports.items) |*memory_import| {
            try emitMemoryImport(wasm, binary_bytes, memory_import);
            total_imports += 1;
        } else if (import_memory) {
            try emitMemoryImport(wasm, binary_bytes, &.{
                // TODO the import_memory option needs to specify from which module
                .module_name = wasm.object_host_name.unwrap().?,
                .name = if (is_obj) wasm.preloaded_strings.__linear_memory else wasm.preloaded_strings.memory,
                .limits_min = wasm.memories.limits.min,
                .limits_max = wasm.memories.limits.max,
                .limits_has_max = wasm.memories.limits.flags.has_max,
                .limits_is_shared = wasm.memories.limits.flags.is_shared,
            });
            total_imports += 1;
        }

        for (f.global_imports.values()) |id| {
            const module_name = id.moduleName(wasm).slice(wasm).?;
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(module_name.len)));
            try binary_writer.writeAll(module_name);

            const name = id.name(wasm).slice(wasm);
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
            try leb.writeUleb128(binary_writer, @intFromEnum(function.typeIndex(wasm)));
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

    // Global section (used to emit stack pointer)
    const globals_len: u32 = @intCast(wasm.globals.entries.len);
    if (globals_len > 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (wasm.globals.keys()) |global_resolution| {
            switch (global_resolution.unpack(wasm)) {
                .unresolved => unreachable,
                .__heap_base => @panic("TODO"),
                .__heap_end => @panic("TODO"),
                .__stack_pointer => {
                    try binary_bytes.ensureUnusedCapacity(gpa, 9);
                    binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Valtype.i32));
                    binary_bytes.appendAssumeCapacity(1); // mutable
                    binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
                    leb.writeUleb128(binary_bytes.fixedWriter(), virtual_addrs.stack_pointer) catch unreachable;
                    binary_bytes.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.end));
                },
                .__tls_align => @panic("TODO"),
                .__tls_base => @panic("TODO"),
                .__tls_size => @panic("TODO"),
                .object_global => |i| {
                    const global = i.ptr(wasm);
                    try binary_bytes.appendSlice(gpa, &.{
                        @intFromEnum(@as(std.wasm.Valtype, global.flags.global_type.valtype.to())),
                        @intFromBool(global.flags.global_type.mutable),
                    });
                    try emitExpr(wasm, binary_bytes, global.expr);
                },
                .nav_exe => @panic("TODO"),
                .nav_obj => @panic("TODO"),
            }
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .global, globals_len);
        section_index += 1;
    }

    // Export section
    {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        var exports_len: usize = 0;

        for (wasm.function_exports.items) |exp| {
            const name = exp.name.slice(wasm);
            try leb.writeUleb128(binary_writer, @as(u32, @intCast(name.len)));
            try binary_bytes.appendSlice(gpa, name);
            try binary_bytes.append(gpa, @intFromEnum(std.wasm.ExternalKind.function));
            const func_index = Wasm.OutputFunctionIndex.fromFunctionIndex(wasm, exp.function_index);
            try leb.writeUleb128(binary_writer, @intFromEnum(func_index));
        }
        exports_len += wasm.function_exports.items.len;

        // No table exports.

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

    if (Wasm.OutputFunctionIndex.fromResolution(wasm, wasm.entry_resolution)) |func_index| {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        replaceVecSectionHeader(binary_bytes, header_offset, .start, @intFromEnum(func_index));
    }

    // element section
    if (wasm.indirect_function_table.entries.len > 0) {
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
        try leb.writeUleb128(binary_writer, @as(u32, @intCast(wasm.indirect_function_table.entries.len)));
        for (wasm.indirect_function_table.keys()) |ip_index| {
            const func_index: Wasm.OutputFunctionIndex = .fromIpIndex(wasm, ip_index);
            try leb.writeUleb128(binary_writer, @intFromEnum(func_index));
        }

        replaceVecSectionHeader(binary_bytes, header_offset, .element, 1);
        section_index += 1;
    }

    // When the shared-memory option is enabled, we *must* emit the 'data count' section.
    if (f.data_segment_groups.items.len > 0 and shared_memory) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);
        replaceVecSectionHeader(binary_bytes, header_offset, .data_count, @intCast(f.data_segment_groups.items.len));
    }

    // Code section.
    if (wasm.functions.count() != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        for (wasm.functions.keys()) |resolution| switch (resolution.unpack(wasm)) {
            .unresolved => unreachable,
            .__wasm_apply_global_tls_relocs => @panic("TODO lower __wasm_apply_global_tls_relocs"),
            .__wasm_call_ctors => @panic("TODO lower __wasm_call_ctors"),
            .__wasm_init_memory => @panic("TODO lower __wasm_init_memory "),
            .__wasm_init_tls => @panic("TODO lower __wasm_init_tls "),
            .object_function => |i| {
                _ = i;
                @panic("TODO lower object function code and apply relocations");
                //try leb.writeUleb128(binary_writer, atom.code.len);
                //try binary_bytes.appendSlice(gpa, atom.code.slice(wasm));
            },
            .zcu_func => |i| {
                const code_start = try reserveSize(gpa, binary_bytes);
                defer replaceSize(binary_bytes, code_start);

                log.debug("lowering function code for '{s}'", .{resolution.name(wasm).?});

                try i.value(wasm).function.lower(wasm, binary_bytes);
            },
        };

        replaceVecSectionHeader(binary_bytes, header_offset, .code, @intCast(wasm.functions.entries.len));
        if (is_obj) @panic("TODO apply offset to code relocs");
        code_section_index = section_index;
        section_index += 1;
    }

    if (!is_obj) {
        for (wasm.uav_fixups.items) |uav_fixup| {
            const ds_id: Wasm.DataId = .pack(wasm, .{ .uav_exe = uav_fixup.uavs_exe_index });
            const vaddr = f.data_segments.get(ds_id).?;
            if (!is64) {
                mem.writeInt(u32, wasm.string_bytes.items[uav_fixup.offset..][0..4], vaddr, .little);
            } else {
                mem.writeInt(u64, wasm.string_bytes.items[uav_fixup.offset..][0..8], vaddr, .little);
            }
        }
        for (wasm.nav_fixups.items) |nav_fixup| {
            const ds_id: Wasm.DataId = .pack(wasm, .{ .nav_exe = nav_fixup.navs_exe_index });
            const vaddr = f.data_segments.get(ds_id).?;
            if (!is64) {
                mem.writeInt(u32, wasm.string_bytes.items[nav_fixup.offset..][0..4], vaddr, .little);
            } else {
                mem.writeInt(u64, wasm.string_bytes.items[nav_fixup.offset..][0..8], vaddr, .little);
            }
        }
    }

    // Data section.
    if (f.data_segment_groups.items.len != 0) {
        const header_offset = try reserveVecSectionHeader(gpa, binary_bytes);

        var group_index: u32 = 0;
        var segment_offset: u32 = 0;
        var group_start_addr: u32 = data_vaddr;
        var group_end_addr = f.data_segment_groups.items[group_index];
        for (segment_ids, segment_vaddrs) |segment_id, segment_vaddr| {
            if (segment_vaddr >= group_end_addr) {
                try binary_bytes.appendNTimes(gpa, 0, group_end_addr - group_start_addr - segment_offset);
                group_index += 1;
                if (group_index >= f.data_segment_groups.items.len) {
                    // All remaining segments are zero.
                    break;
                }
                group_start_addr = group_end_addr;
                group_end_addr = f.data_segment_groups.items[group_index];
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
                    .__zig_error_names => {
                        try binary_bytes.appendSlice(gpa, wasm.error_name_bytes.items);
                        break :append;
                    },
                    .__zig_error_name_table => {
                        if (is_obj) @panic("TODO error name table reloc");
                        const base = f.data_segments.get(.__zig_error_names).?;
                        if (!is64) {
                            try emitErrorNameTable(gpa, binary_bytes, wasm.error_name_offs.items, wasm.error_name_bytes.items, base, u32);
                        } else {
                            try emitErrorNameTable(gpa, binary_bytes, wasm.error_name_offs.items, wasm.error_name_bytes.items, base, u64);
                        }
                        break :append;
                    },
                    .object => |i| c: {
                        if (true) @panic("TODO apply data segment relocations");
                        break :c i.ptr(wasm).payload;
                    },
                    inline .uav_exe, .uav_obj, .nav_exe, .nav_obj => |i| i.value(wasm).code,
                };
                try binary_bytes.appendSlice(gpa, code.slice(wasm));
            }
            segment_offset += @intCast(binary_bytes.items.len - code_start);
        }
        assert(group_index == f.data_segment_groups.items.len);

        replaceVecSectionHeader(binary_bytes, header_offset, .data, group_index);
        data_section_index = section_index;
        section_index += 1;
    }

    if (is_obj) {
        @panic("TODO emit link section for object file and apply relocations");
        //var symbol_table = std.AutoArrayHashMap(SymbolLoc, u32).init(arena);
        //try wasm.emitLinkSection(binary_bytes, &symbol_table);
        //if (code_section_index) |code_index| {
        //    try wasm.emitCodeRelocations(binary_bytes, code_index, symbol_table);
        //}
        //if (data_section_index) |data_index| {
        //    if (f.data_segments.count() > 0)
        //        try wasm.emitDataRelocations(binary_bytes, data_index, symbol_table);
        //}
    } else if (comp.config.debug_format != .strip) {
        try emitNameSection(wasm, &f.data_segments, binary_bytes);
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
                _ = try std.fmt.bufPrint(&uuid, "{s}-{s}-{s}-{s}-{s}", .{
                    std.fmt.fmtSliceHexLower(id[0..4]),
                    std.fmt.fmtSliceHexLower(id[4..6]),
                    std.fmt.fmtSliceHexLower(id[6..8]),
                    std.fmt.fmtSliceHexLower(id[8..10]),
                    std.fmt.fmtSliceHexLower(id[10..]),
                });
                try emitBuildIdSection(gpa, binary_bytes, &uuid);
            },
            .hexstring => |hs| {
                var buffer: [32 * 2]u8 = undefined;
                const str = std.fmt.bufPrint(&buffer, "{s}", .{
                    std.fmt.fmtSliceHexLower(hs.toSlice()),
                }) catch unreachable;
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

fn emitNameSection(
    wasm: *Wasm,
    data_segments: *const std.AutoArrayHashMapUnmanaged(Wasm.DataId, u32),
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

        const total_globals: u32 = @intCast(f.global_imports.entries.len + wasm.globals.entries.len);
        try leb.writeUleb128(binary_bytes.writer(gpa), total_globals);

        for (data_segments.keys(), 0..) |ds, i| {
            const name = ds.name(wasm);
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

///// For each relocatable section, emits a custom "relocation.<section_name>" section
//fn emitCodeRelocations(
//    wasm: *Wasm,
//    binary_bytes: *std.ArrayListUnmanaged(u8),
//    section_index: u32,
//    symbol_table: std.AutoArrayHashMapUnmanaged(SymbolLoc, u32),
//) !void {
//    const comp = wasm.base.comp;
//    const gpa = comp.gpa;
//    const code_index = wasm.code_section_index.unwrap() orelse return;
//    const writer = binary_bytes.writer(gpa);
//    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
//
//    // write custom section information
//    const name = "reloc.CODE";
//    try leb.writeUleb128(writer, @as(u32, @intCast(name.len)));
//    try writer.writeAll(name);
//    try leb.writeUleb128(writer, section_index);
//    const reloc_start = binary_bytes.items.len;
//
//    var count: u32 = 0;
//    var atom: *Atom = wasm.atoms.get(code_index).?.ptr(wasm);
//    // for each atom, we calculate the uleb size and append that
//    var size_offset: u32 = 5; // account for code section size leb128
//    while (true) {
//        size_offset += getUleb128Size(atom.code.len);
//        for (atom.relocSlice(wasm)) |relocation| {
//            count += 1;
//            const sym_loc: SymbolLoc = .{ .file = atom.file, .index = @enumFromInt(relocation.index) };
//            const symbol_index = symbol_table.get(sym_loc).?;
//            try leb.writeUleb128(writer, @intFromEnum(relocation.tag));
//            const offset = atom.offset + relocation.offset + size_offset;
//            try leb.writeUleb128(writer, offset);
//            try leb.writeUleb128(writer, symbol_index);
//            if (relocation.tag.addendIsPresent()) {
//                try leb.writeIleb128(writer, relocation.addend);
//            }
//            log.debug("Emit relocation: {}", .{relocation});
//        }
//        if (atom.prev == .none) break;
//        atom = atom.prev.ptr(wasm);
//    }
//    if (count == 0) return;
//    var buf: [5]u8 = undefined;
//    leb.writeUnsignedFixed(5, &buf, count);
//    try binary_bytes.insertSlice(reloc_start, &buf);
//    writeCustomSectionHeader(binary_bytes, header_offset);
//}

//fn emitDataRelocations(
//    wasm: *Wasm,
//    binary_bytes: *std.ArrayList(u8),
//    section_index: u32,
//    symbol_table: std.AutoArrayHashMap(SymbolLoc, u32),
//) !void {
//    const comp = wasm.base.comp;
//    const gpa = comp.gpa;
//    const writer = binary_bytes.writer(gpa);
//    const header_offset = try reserveCustomSectionHeader(gpa, binary_bytes);
//
//    // write custom section information
//    const name = "reloc.DATA";
//    try leb.writeUleb128(writer, @as(u32, @intCast(name.len)));
//    try writer.writeAll(name);
//    try leb.writeUleb128(writer, section_index);
//    const reloc_start = binary_bytes.items.len;
//
//    var count: u32 = 0;
//    // for each atom, we calculate the uleb size and append that
//    var size_offset: u32 = 5; // account for code section size leb128
//    for (f.data_segments.values()) |segment_index| {
//        var atom: *Atom = wasm.atoms.get(segment_index).?.ptr(wasm);
//        while (true) {
//            size_offset += getUleb128Size(atom.code.len);
//            for (atom.relocSlice(wasm)) |relocation| {
//                count += 1;
//                const sym_loc: SymbolLoc = .{ .file = atom.file, .index = @enumFromInt(relocation.index) };
//                const symbol_index = symbol_table.get(sym_loc).?;
//                try leb.writeUleb128(writer, @intFromEnum(relocation.tag));
//                const offset = atom.offset + relocation.offset + size_offset;
//                try leb.writeUleb128(writer, offset);
//                try leb.writeUleb128(writer, symbol_index);
//                if (relocation.tag.addendIsPresent()) {
//                    try leb.writeIleb128(writer, relocation.addend);
//                }
//                log.debug("Emit relocation: {}", .{relocation});
//            }
//            if (atom.prev == .none) break;
//            atom = atom.prev.ptr(wasm);
//        }
//    }
//    if (count == 0) return;
//
//    var buf: [5]u8 = undefined;
//    leb.writeUnsignedFixed(5, &buf, count);
//    try binary_bytes.insertSlice(reloc_start, &buf);
//    writeCustomSectionHeader(binary_bytes, header_offset);
//}

fn splitSegmentName(name: []const u8) struct { []const u8, []const u8 } {
    const start = @intFromBool(name.len >= 1 and name[0] == '.');
    const pivot = mem.indexOfScalarPos(u8, name, start, '.') orelse 0;
    return .{ name[0..pivot], name[pivot..] };
}

fn wantSegmentMerge(
    wasm: *const Wasm,
    a_id: Wasm.DataId,
    b_id: Wasm.DataId,
    b_category: Wasm.DataId.Category,
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
    memory_import: *const Wasm.MemoryImport,
) Allocator.Error!void {
    const gpa = wasm.base.comp.gpa;
    const module_name = memory_import.module_name.slice(wasm);
    try leb.writeUleb128(binary_bytes.writer(gpa), @as(u32, @intCast(module_name.len)));
    try binary_bytes.appendSlice(gpa, module_name);

    const name = memory_import.name.slice(wasm);
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

//fn emitLinkSection(
//    wasm: *Wasm,
//    binary_bytes: *std.ArrayListUnmanaged(u8),
//    symbol_table: *std.AutoArrayHashMapUnmanaged(SymbolLoc, u32),
//) !void {
//    const gpa = wasm.base.comp.gpa;
//    const offset = try reserveCustomSectionHeader(gpa, binary_bytes);
//    const writer = binary_bytes.writer(gpa);
//    // emit "linking" custom section name
//    const section_name = "linking";
//    try leb.writeUleb128(writer, section_name.len);
//    try writer.writeAll(section_name);
//
//    // meta data version, which is currently '2'
//    try leb.writeUleb128(writer, @as(u32, 2));
//
//    // For each subsection type (found in Subsection) we can emit a section.
//    // Currently, we only support emitting segment info and the symbol table.
//    try wasm.emitSymbolTable(binary_bytes, symbol_table);
//    try wasm.emitSegmentInfo(binary_bytes);
//
//    const size: u32 = @intCast(binary_bytes.items.len - offset - 6);
//    writeCustomSectionHeader(binary_bytes, offset, size);
//}

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

//fn emitSymbolTable(
//    wasm: *Wasm,
//    binary_bytes: *std.ArrayListUnmanaged(u8),
//    symbol_table: *std.AutoArrayHashMapUnmanaged(SymbolLoc, u32),
//) !void {
//    const gpa = wasm.base.comp.gpa;
//    const writer = binary_bytes.writer(gpa);
//
//    try leb.writeUleb128(writer, @intFromEnum(SubsectionType.symbol_table));
//    const table_offset = binary_bytes.items.len;
//
//    var symbol_count: u32 = 0;
//    for (wasm.resolved_symbols.keys()) |sym_loc| {
//        const symbol = wasm.finalSymbolByLoc(sym_loc).*;
//        if (symbol.tag == .dead) continue;
//        try symbol_table.putNoClobber(gpa, sym_loc, symbol_count);
//        symbol_count += 1;
//        log.debug("emit symbol: {}", .{symbol});
//        try leb.writeUleb128(writer, @intFromEnum(symbol.tag));
//        try leb.writeUleb128(writer, symbol.flags);
//
//        const sym_name = wasm.symbolLocName(sym_loc);
//        switch (symbol.tag) {
//            .data => {
//                try leb.writeUleb128(writer, @as(u32, @intCast(sym_name.len)));
//                try writer.writeAll(sym_name);
//
//                if (!symbol.flags.undefined) {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.data_out));
//                    const atom_index = wasm.symbol_atom.get(sym_loc).?;
//                    const atom = wasm.getAtom(atom_index);
//                    try leb.writeUleb128(writer, @as(u32, atom.offset));
//                    try leb.writeUleb128(writer, @as(u32, atom.code.len));
//                }
//            },
//            .section => {
//                try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.section));
//            },
//            .function => {
//                if (symbol.flags.undefined) {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.function_import));
//                } else {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.function));
//                    try leb.writeUleb128(writer, @as(u32, @intCast(sym_name.len)));
//                    try writer.writeAll(sym_name);
//                }
//            },
//            .global => {
//                if (symbol.flags.undefined) {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.global_import));
//                } else {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.global));
//                    try leb.writeUleb128(writer, @as(u32, @intCast(sym_name.len)));
//                    try writer.writeAll(sym_name);
//                }
//            },
//            .table => {
//                if (symbol.flags.undefined) {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.table_import));
//                } else {
//                    try leb.writeUleb128(writer, @intFromEnum(symbol.pointee.table));
//                    try leb.writeUleb128(writer, @as(u32, @intCast(sym_name.len)));
//                    try writer.writeAll(sym_name);
//                }
//            },
//            .event => unreachable,
//            .dead => unreachable,
//            .uninitialized => unreachable,
//        }
//    }
//
//    var buf: [10]u8 = undefined;
//    leb.writeUnsignedFixed(5, buf[0..5], @intCast(binary_bytes.items.len - table_offset + 5));
//    leb.writeUnsignedFixed(5, buf[5..], symbol_count);
//    try binary_bytes.insertSlice(table_offset, &buf);
//}

fn uleb128size(x: u32) u32 {
    var value = x;
    var size: u32 = 0;
    while (value != 0) : (size += 1) value >>= 7;
    return size;
}

fn emitErrorNameTable(
    gpa: Allocator,
    code: *std.ArrayListUnmanaged(u8),
    error_name_offs: []const u32,
    error_name_bytes: []const u8,
    base: u32,
    comptime Int: type,
) error{OutOfMemory}!void {
    const ptr_size_bytes = @divExact(@bitSizeOf(Int), 8);
    try code.ensureUnusedCapacity(gpa, ptr_size_bytes * 2 * error_name_offs.len);
    for (error_name_offs) |off| {
        const name_len: u32 = @intCast(mem.indexOfScalar(u8, error_name_bytes[off..], 0).?);
        mem.writeInt(Int, code.addManyAsArrayAssumeCapacity(ptr_size_bytes), base + off, .little);
        mem.writeInt(Int, code.addManyAsArrayAssumeCapacity(ptr_size_bytes), name_len, .little);
    }
}
