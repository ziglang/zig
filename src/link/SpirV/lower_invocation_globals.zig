const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.spirv_link);

const BinaryModule = @import("BinaryModule.zig");
const Section = @import("../../codegen/spirv/Section.zig");
const spec = @import("../../codegen/spirv/spec.zig");
const ResultId = spec.IdResult;
const Word = spec.Word;

/// This structure contains all the stuff that we need to parse from the module in
/// order to run this pass, as well as some functions to ease its use.
const ModuleInfo = struct {
    /// Information about a particular function.
    const Fn = struct {
        /// The index of the first callee in `callee_store`.
        first_callee: usize,
        /// The return type id of this function
        return_type: ResultId,
        /// The parameter types of this function
        param_types: []const ResultId,
        /// The set of (result-id's of) invocation globals that are accessed
        /// in this function, or after resolution, that are accessed in this
        /// function or any of it's callees.
        invocation_globals: std.AutoArrayHashMapUnmanaged(ResultId, void),
    };

    /// Information about a particular invocation global
    const InvocationGlobal = struct {
        /// The list of invocation globals that this invocation global
        /// depends on.
        dependencies: std.AutoArrayHashMapUnmanaged(ResultId, void),
        /// The invocation global's type
        ty: ResultId,
        /// Initializer function. May be `none`.
        /// Note that if the initializer is `none`, then `dependencies` is empty.
        initializer: ResultId,
    };

    /// Maps function result-id -> Fn information structure.
    functions: std.AutoArrayHashMapUnmanaged(ResultId, Fn),
    /// Set of OpFunction result-ids in this module.
    entry_points: std.AutoArrayHashMapUnmanaged(ResultId, void),
    /// For each function, a list of function result-ids that it calls.
    callee_store: []const ResultId,
    /// Maps each invocation global result-id to a type-id.
    invocation_globals: std.AutoArrayHashMapUnmanaged(ResultId, InvocationGlobal),

    /// Fetch the list of callees per function. Guaranteed to contain only unique IDs.
    fn callees(self: ModuleInfo, fn_id: ResultId) []const ResultId {
        const fn_index = self.functions.getIndex(fn_id).?;
        const values = self.functions.values();
        const first_callee = values[fn_index].first_callee;
        if (fn_index == values.len - 1) {
            return self.callee_store[first_callee..];
        } else {
            const next_first_callee = values[fn_index + 1].first_callee;
            return self.callee_store[first_callee..next_first_callee];
        }
    }

    /// Extract most of the required information from the binary. The remaining info is
    /// constructed by `resolve()`.
    fn parse(
        arena: Allocator,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
    ) BinaryModule.ParseError!ModuleInfo {
        var entry_points = std.AutoArrayHashMap(ResultId, void).init(arena);
        var functions = std.AutoArrayHashMap(ResultId, Fn).init(arena);
        var fn_types = std.AutoHashMap(ResultId, struct {
            return_type: ResultId,
            param_types: []const ResultId,
        }).init(arena);
        var calls = std.AutoArrayHashMap(ResultId, void).init(arena);
        var callee_store = std.ArrayList(ResultId).init(arena);
        var function_invocation_globals = std.AutoArrayHashMap(ResultId, void).init(arena);
        var result_id_offsets = std.ArrayList(u16).init(arena);
        var invocation_globals = std.AutoArrayHashMap(ResultId, InvocationGlobal).init(arena);

        var maybe_current_function: ?ResultId = null;
        var fn_ty_id: ResultId = undefined;

        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            result_id_offsets.items.len = 0;
            try parser.parseInstructionResultIds(binary, inst, &result_id_offsets);

            switch (inst.opcode) {
                .OpEntryPoint => {
                    const entry_point: ResultId = @enumFromInt(inst.operands[1]);
                    const entry = try entry_points.getOrPut(entry_point);
                    if (entry.found_existing) {
                        log.err("Entry point type {} has duplicate definition", .{entry_point});
                        return error.DuplicateId;
                    }
                },
                .OpTypeFunction => {
                    const fn_type: ResultId = @enumFromInt(inst.operands[0]);
                    const return_type: ResultId = @enumFromInt(inst.operands[1]);
                    const param_types: []const ResultId = @ptrCast(inst.operands[2..]);

                    const entry = try fn_types.getOrPut(fn_type);
                    if (entry.found_existing) {
                        log.err("Function type {} has duplicate definition", .{fn_type});
                        return error.DuplicateId;
                    }

                    entry.value_ptr.* = .{
                        .return_type = return_type,
                        .param_types = param_types,
                    };
                },
                .OpExtInst => {
                    // Note: format and set are already verified by parseInstructionResultIds().
                    const global_type: ResultId = @enumFromInt(inst.operands[0]);
                    const result_id: ResultId = @enumFromInt(inst.operands[1]);
                    const set_id: ResultId = @enumFromInt(inst.operands[2]);
                    const set_inst = inst.operands[3];

                    const set = binary.ext_inst_map.get(set_id).?;
                    if (set == .zig and set_inst == 0) {
                        const initializer: ResultId = if (inst.operands.len >= 5)
                            @enumFromInt(inst.operands[4])
                        else
                            .none;

                        try invocation_globals.put(result_id, .{
                            .dependencies = .{},
                            .ty = global_type,
                            .initializer = initializer,
                        });
                    }
                },
                .OpFunction => {
                    if (maybe_current_function) |current_function| {
                        log.err("OpFunction {} does not have an OpFunctionEnd", .{current_function});
                        return error.InvalidPhysicalFormat;
                    }

                    maybe_current_function = @enumFromInt(inst.operands[1]);
                    fn_ty_id = @enumFromInt(inst.operands[3]);
                    function_invocation_globals.clearRetainingCapacity();
                },
                .OpFunctionCall => {
                    const callee: ResultId = @enumFromInt(inst.operands[2]);
                    try calls.put(callee, {});
                },
                .OpFunctionEnd => {
                    const current_function = maybe_current_function orelse {
                        log.err("encountered OpFunctionEnd without corresponding OpFunction", .{});
                        return error.InvalidPhysicalFormat;
                    };
                    const entry = try functions.getOrPut(current_function);
                    if (entry.found_existing) {
                        log.err("Function {} has duplicate definition", .{current_function});
                        return error.DuplicateId;
                    }

                    const first_callee = callee_store.items.len;
                    try callee_store.appendSlice(calls.keys());

                    const fn_type = fn_types.get(fn_ty_id) orelse {
                        log.err("Function {} has invalid OpFunction type", .{current_function});
                        return error.InvalidId;
                    };

                    entry.value_ptr.* = .{
                        .first_callee = first_callee,
                        .return_type = fn_type.return_type,
                        .param_types = fn_type.param_types,
                        .invocation_globals = try function_invocation_globals.unmanaged.clone(arena),
                    };
                    maybe_current_function = null;
                    calls.clearRetainingCapacity();
                },
                else => {},
            }

            for (result_id_offsets.items) |off| {
                const result_id: ResultId = @enumFromInt(inst.operands[off]);
                if (invocation_globals.contains(result_id)) {
                    try function_invocation_globals.put(result_id, {});
                }
            }
        }

        if (maybe_current_function) |current_function| {
            log.err("OpFunction {} does not have an OpFunctionEnd", .{current_function});
            return error.InvalidPhysicalFormat;
        }

        return ModuleInfo{
            .functions = functions.unmanaged,
            .entry_points = entry_points.unmanaged,
            .callee_store = callee_store.items,
            .invocation_globals = invocation_globals.unmanaged,
        };
    }

    /// Derive the remaining info from the structures filled in by parsing.
    fn resolve(self: *ModuleInfo, arena: Allocator) !void {
        try self.resolveInvocationGlobalUsage(arena);
        try self.resolveInvocationGlobalDependencies(arena);
    }

    /// For each function, extend the list of `invocation_globals` with the
    /// invocation globals that ALL of its dependencies use.
    fn resolveInvocationGlobalUsage(self: *ModuleInfo, arena: Allocator) !void {
        var seen = try std.DynamicBitSetUnmanaged.initEmpty(arena, self.functions.count());

        for (self.functions.keys()) |id| {
            try self.resolveInvocationGlobalUsageStep(arena, id, &seen);
        }
    }

    fn resolveInvocationGlobalUsageStep(
        self: *ModuleInfo,
        arena: Allocator,
        id: ResultId,
        seen: *std.DynamicBitSetUnmanaged,
    ) !void {
        const index = self.functions.getIndex(id) orelse {
            log.err("function calls invalid function {}", .{id});
            return error.InvalidId;
        };

        if (seen.isSet(index)) {
            return;
        }
        seen.set(index);

        const info = &self.functions.values()[index];
        for (self.callees(id)) |callee| {
            try self.resolveInvocationGlobalUsageStep(arena, callee, seen);
            const callee_info = self.functions.get(callee).?;
            for (callee_info.invocation_globals.keys()) |global| {
                try info.invocation_globals.put(arena, global, {});
            }
        }
    }

    /// For each invocation global, populate and fully resolve the `dependencies` set.
    /// This requires `resolveInvocationGlobalUsage()` to be already done.
    fn resolveInvocationGlobalDependencies(
        self: *ModuleInfo,
        arena: Allocator,
    ) !void {
        var seen = try std.DynamicBitSetUnmanaged.initEmpty(arena, self.invocation_globals.count());

        for (self.invocation_globals.keys()) |id| {
            try self.resolveInvocationGlobalDependenciesStep(arena, id, &seen);
        }
    }

    fn resolveInvocationGlobalDependenciesStep(
        self: *ModuleInfo,
        arena: Allocator,
        id: ResultId,
        seen: *std.DynamicBitSetUnmanaged,
    ) !void {
        const index = self.invocation_globals.getIndex(id) orelse {
            log.err("invalid invocation global {}", .{id});
            return error.InvalidId;
        };

        if (seen.isSet(index)) {
            return;
        }
        seen.set(index);

        const info = &self.invocation_globals.values()[index];
        if (info.initializer == .none) {
            return;
        }

        const initializer = self.functions.get(info.initializer) orelse {
            log.err("invocation global {} has invalid initializer {}", .{ id, info.initializer });
            return error.InvalidId;
        };

        for (initializer.invocation_globals.keys()) |dependency| {
            if (dependency == id) {
                // The set of invocation global dependencies includes the dependency itself,
                // so we need to skip that case.
                continue;
            }

            try info.dependencies.put(arena, dependency, {});
            try self.resolveInvocationGlobalDependenciesStep(arena, dependency, seen);

            const dep_info = self.invocation_globals.getPtr(dependency).?;

            for (dep_info.dependencies.keys()) |global| {
                try info.dependencies.put(arena, global, {});
            }
        }
    }
};

const ModuleBuilder = struct {
    const FunctionType = struct {
        return_type: ResultId,
        param_types: []const ResultId,

        const Context = struct {
            pub fn hash(_: @This(), ty: FunctionType) u32 {
                var hasher = std.hash.Wyhash.init(0);
                hasher.update(std.mem.asBytes(&ty.return_type));
                hasher.update(std.mem.sliceAsBytes(ty.param_types));
                return @truncate(hasher.final());
            }

            pub fn eql(_: @This(), a: FunctionType, b: FunctionType, _: usize) bool {
                if (a.return_type != b.return_type) return false;
                return std.mem.eql(ResultId, a.param_types, b.param_types);
            }
        };
    };

    const FunctionNewInfo = struct {
        /// This is here just so that we don't need to allocate the new
        /// param_types multiple times.
        new_function_type: ResultId,
        /// The first ID of the parameters for the invocation globals.
        /// Each global is allocate here according to the index in
        /// `ModuleInfo.Fn.invocation_globals`.
        global_id_base: u32,

        fn invocationGlobalId(self: FunctionNewInfo, index: usize) ResultId {
            return @enumFromInt(self.global_id_base + @as(u32, @intCast(index)));
        }
    };

    arena: Allocator,
    section: Section,
    /// The ID bound of the new module.
    id_bound: u32,
    /// The first ID of the new entry points. Entry points are allocated from
    /// here according to their index in `info.entry_points`.
    entry_point_new_id_base: u32,
    /// A set of all function types in the new program. SPIR-V mandates that these are unique,
    /// and until a general type deduplication pass is programmed, we just handle it here via this.
    function_types: std.ArrayHashMapUnmanaged(FunctionType, ResultId, FunctionType.Context, true) = .empty,
    /// Maps functions to new information required for creating the module
    function_new_info: std.AutoArrayHashMapUnmanaged(ResultId, FunctionNewInfo) = .empty,
    /// Offset of the functions section in the new binary.
    new_functions_section: ?usize,

    fn init(arena: Allocator, binary: BinaryModule, info: ModuleInfo) !ModuleBuilder {
        var self = ModuleBuilder{
            .arena = arena,
            .section = .{},
            .id_bound = binary.id_bound,
            .entry_point_new_id_base = undefined,
            .new_functions_section = null,
        };
        self.entry_point_new_id_base = @intFromEnum(self.allocIds(@intCast(info.entry_points.count())));
        return self;
    }

    fn allocId(self: *ModuleBuilder) ResultId {
        return self.allocIds(1);
    }

    fn allocIds(self: *ModuleBuilder, n: u32) ResultId {
        defer self.id_bound += n;
        return @enumFromInt(self.id_bound);
    }

    fn finalize(self: *ModuleBuilder, a: Allocator, binary: *BinaryModule) !void {
        binary.id_bound = self.id_bound;
        binary.instructions = try a.dupe(Word, self.section.instructions.items);
        // Nothing is removed in this pass so we don't need to change any of the maps,
        // just make sure the section is updated.
        binary.sections.functions = self.new_functions_section orelse binary.instructions.len;
    }

    /// Process everything from `binary` up to the first function and emit it into the builder.
    fn processPreamble(self: *ModuleBuilder, binary: BinaryModule, info: ModuleInfo) !void {
        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            switch (inst.opcode) {
                .OpExtInst => {
                    const set_id: ResultId = @enumFromInt(inst.operands[2]);
                    const set_inst = inst.operands[3];
                    const set = binary.ext_inst_map.get(set_id).?;
                    if (set == .zig and set_inst == 0) {
                        continue;
                    }
                },
                .OpEntryPoint => {
                    const original_id: ResultId = @enumFromInt(inst.operands[1]);
                    const new_id_index = info.entry_points.getIndex(original_id).?;
                    const new_id: ResultId = @enumFromInt(self.entry_point_new_id_base + new_id_index);
                    try self.section.emitRaw(self.arena, .OpEntryPoint, inst.operands.len);
                    self.section.writeWord(inst.operands[0]);
                    self.section.writeOperand(ResultId, new_id);
                    self.section.writeWords(inst.operands[2..]);
                    continue;
                },
                .OpTypeFunction => {
                    // Re-emitted in `emitFunctionTypes()`. We can do this because
                    // OpTypeFunction's may not currently be used anywhere that is not
                    // directly with an OpFunction. For now we ignore Intels function
                    // pointers extension, that is not a problem with a generalized
                    // pass anyway.
                    continue;
                },
                .OpFunction => break,
                else => {},
            }

            try self.section.emitRawInstruction(self.arena, inst.opcode, inst.operands);
        }
    }

    /// Derive new information required for further emitting this module,
    fn deriveNewFnInfo(self: *ModuleBuilder, info: ModuleInfo) !void {
        for (info.functions.keys(), info.functions.values()) |func, fn_info| {
            const invocation_global_count = fn_info.invocation_globals.count();
            const new_param_types = try self.arena.alloc(ResultId, fn_info.param_types.len + invocation_global_count);
            for (fn_info.invocation_globals.keys(), 0..) |global, i| {
                new_param_types[i] = info.invocation_globals.get(global).?.ty;
            }
            @memcpy(new_param_types[invocation_global_count..], fn_info.param_types);

            const new_type = try self.internFunctionType(fn_info.return_type, new_param_types);
            try self.function_new_info.put(self.arena, func, .{
                .new_function_type = new_type,
                .global_id_base = @intFromEnum(self.allocIds(@intCast(invocation_global_count))),
            });
        }
    }

    /// Emit the new function types, which include the parameters for the invocation globals.
    /// Currently, this function re-emits ALL function types to ensure that there are
    /// no duplicates in the final program.
    /// TODO: The above should be resolved by a generalized deduplication pass, and then
    /// we only need to emit the new function pointers type here.
    fn emitFunctionTypes(self: *ModuleBuilder, info: ModuleInfo) !void {
        // TODO: Handle decorators. Function types usually don't have those
        // though, but stuff like OpName could be a possibility.

        // Entry points retain their old function type, so make sure to emit
        // those in the `function_types` set.
        for (info.entry_points.keys()) |func| {
            const fn_info = info.functions.get(func).?;
            _ = try self.internFunctionType(fn_info.return_type, fn_info.param_types);
        }

        for (self.function_types.keys(), self.function_types.values()) |fn_type, result_id| {
            try self.section.emit(self.arena, .OpTypeFunction, .{
                .id_result = result_id,
                .return_type = fn_type.return_type,
                .id_ref_2 = fn_type.param_types,
            });
        }
    }

    fn internFunctionType(self: *ModuleBuilder, return_type: ResultId, param_types: []const ResultId) !ResultId {
        const entry = try self.function_types.getOrPut(self.arena, .{
            .return_type = return_type,
            .param_types = param_types,
        });

        if (!entry.found_existing) {
            const new_id = self.allocId();
            entry.value_ptr.* = new_id;
        }

        return entry.value_ptr.*;
    }

    /// Rewrite the modules' functions and emit them with the new parameter types.
    fn rewriteFunctions(
        self: *ModuleBuilder,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
        info: ModuleInfo,
    ) !void {
        var result_id_offsets = std.ArrayList(u16).init(self.arena);
        var operands = std.ArrayList(u32).init(self.arena);

        var maybe_current_function: ?ResultId = null;
        var it = binary.iterateInstructionsFrom(binary.sections.functions);
        self.new_functions_section = self.section.instructions.items.len;
        while (it.next()) |inst| {
            result_id_offsets.items.len = 0;
            try parser.parseInstructionResultIds(binary, inst, &result_id_offsets);

            operands.items.len = 0;
            try operands.appendSlice(inst.operands);

            // Replace the result-ids with the global's new result-id if required.
            for (result_id_offsets.items) |off| {
                const result_id: ResultId = @enumFromInt(operands.items[off]);
                if (info.invocation_globals.contains(result_id)) {
                    const func = maybe_current_function.?;
                    const new_info = self.function_new_info.get(func).?;
                    const fn_info = info.functions.get(func).?;
                    const index = fn_info.invocation_globals.getIndex(result_id).?;
                    operands.items[off] = @intFromEnum(new_info.invocationGlobalId(index));
                }
            }

            switch (inst.opcode) {
                .OpFunction => {
                    // Re-declare the function with the new parameters.
                    const func: ResultId = @enumFromInt(operands.items[1]);
                    const fn_info = info.functions.get(func).?;
                    const new_info = self.function_new_info.get(func).?;

                    try self.section.emitRaw(self.arena, .OpFunction, 4);
                    self.section.writeOperand(ResultId, fn_info.return_type);
                    self.section.writeOperand(ResultId, func);
                    self.section.writeWord(operands.items[2]);
                    self.section.writeOperand(ResultId, new_info.new_function_type);

                    // Emit the OpFunctionParameters for the invocation globals. The functions
                    // actual parameters are emitted unchanged from their original form, so
                    // we don't need to handle those here.

                    for (fn_info.invocation_globals.keys(), 0..) |global, index| {
                        const ty = info.invocation_globals.get(global).?.ty;
                        const id = new_info.invocationGlobalId(index);
                        try self.section.emit(self.arena, .OpFunctionParameter, .{
                            .id_result_type = ty,
                            .id_result = id,
                        });
                    }

                    maybe_current_function = func;
                },
                .OpFunctionCall => {
                    // Add the required invocation globals to the function's new parameter list.
                    const caller = maybe_current_function.?;
                    const callee: ResultId = @enumFromInt(operands.items[2]);
                    const caller_info = info.functions.get(caller).?;
                    const callee_info = info.functions.get(callee).?;
                    const caller_new_info = self.function_new_info.get(caller).?;
                    const total_params = callee_info.invocation_globals.count() + callee_info.param_types.len;

                    try self.section.emitRaw(self.arena, .OpFunctionCall, 3 + total_params);
                    self.section.writeWord(operands.items[0]); // Copy result type-id
                    self.section.writeWord(operands.items[1]); // Copy result-id
                    self.section.writeOperand(ResultId, callee);

                    // Add the new arguments
                    for (callee_info.invocation_globals.keys()) |global| {
                        const caller_global_index = caller_info.invocation_globals.getIndex(global).?;
                        const id = caller_new_info.invocationGlobalId(caller_global_index);
                        self.section.writeOperand(ResultId, id);
                    }

                    // Add the original arguments
                    self.section.writeWords(operands.items[3..]);
                },
                else => {
                    try self.section.emitRawInstruction(self.arena, inst.opcode, operands.items);
                },
            }
        }
    }

    fn emitNewEntryPoints(self: *ModuleBuilder, info: ModuleInfo) !void {
        var all_function_invocation_globals = std.AutoArrayHashMap(ResultId, void).init(self.arena);

        for (info.entry_points.keys(), 0..) |func, entry_point_index| {
            const fn_info = info.functions.get(func).?;
            const ep_id: ResultId = @enumFromInt(self.entry_point_new_id_base + @as(u32, @intCast(entry_point_index)));
            const fn_type = self.function_types.get(.{
                .return_type = fn_info.return_type,
                .param_types = fn_info.param_types,
            }).?;

            try self.section.emit(self.arena, .OpFunction, .{
                .id_result_type = fn_info.return_type,
                .id_result = ep_id,
                .function_control = .{}, // TODO: Copy the attributes from the original function maybe?
                .function_type = fn_type,
            });

            // Emit OpFunctionParameter instructions for the original kernel's parameters.
            const params_id_base: u32 = @intFromEnum(self.allocIds(@intCast(fn_info.param_types.len)));
            for (fn_info.param_types, 0..) |param_type, i| {
                const id: ResultId = @enumFromInt(params_id_base + @as(u32, @intCast(i)));
                try self.section.emit(self.arena, .OpFunctionParameter, .{
                    .id_result_type = param_type,
                    .id_result = id,
                });
            }

            try self.section.emit(self.arena, .OpLabel, .{
                .id_result = self.allocId(),
            });

            // Besides the IDs of the main kernel, we also need the
            // dependencies of the globals.
            // Just quickly construct that set here.
            all_function_invocation_globals.clearRetainingCapacity();
            for (fn_info.invocation_globals.keys()) |global| {
                try all_function_invocation_globals.put(global, {});
                const global_info = info.invocation_globals.get(global).?;
                for (global_info.dependencies.keys()) |dependency| {
                    try all_function_invocation_globals.put(dependency, {});
                }
            }

            // Declare the IDs of the invocation globals.
            const global_id_base: u32 = @intFromEnum(self.allocIds(@intCast(all_function_invocation_globals.count())));
            for (all_function_invocation_globals.keys(), 0..) |global, i| {
                const global_info = info.invocation_globals.get(global).?;

                const id: ResultId = @enumFromInt(global_id_base + @as(u32, @intCast(i)));
                try self.section.emit(self.arena, .OpVariable, .{
                    .id_result_type = global_info.ty,
                    .id_result = id,
                    .storage_class = .Function,
                    .initializer = null,
                });
            }

            // Call initializers for invocation globals that need it
            for (all_function_invocation_globals.keys()) |global| {
                const global_info = info.invocation_globals.get(global).?;
                if (global_info.initializer == .none) continue;

                const initializer_info = info.functions.get(global_info.initializer).?;
                assert(initializer_info.param_types.len == 0);

                try self.callWithGlobalsAndLinearParams(
                    all_function_invocation_globals,
                    global_info.initializer,
                    initializer_info,
                    global_id_base,
                    undefined,
                );
            }

            // Call the main kernel entry
            try self.callWithGlobalsAndLinearParams(
                all_function_invocation_globals,
                func,
                fn_info,
                global_id_base,
                params_id_base,
            );

            try self.section.emit(self.arena, .OpReturn, {});
            try self.section.emit(self.arena, .OpFunctionEnd, {});
        }
    }

    fn callWithGlobalsAndLinearParams(
        self: *ModuleBuilder,
        all_globals: std.AutoArrayHashMap(ResultId, void),
        func: ResultId,
        callee_info: ModuleInfo.Fn,
        global_id_base: u32,
        params_id_base: u32,
    ) !void {
        const total_arguments = callee_info.invocation_globals.count() + callee_info.param_types.len;
        try self.section.emitRaw(self.arena, .OpFunctionCall, 3 + total_arguments);
        self.section.writeOperand(ResultId, callee_info.return_type);
        self.section.writeOperand(ResultId, self.allocId());
        self.section.writeOperand(ResultId, func);

        // Add the invocation globals
        for (callee_info.invocation_globals.keys()) |global| {
            const index = all_globals.getIndex(global).?;
            const id: ResultId = @enumFromInt(global_id_base + @as(u32, @intCast(index)));
            self.section.writeOperand(ResultId, id);
        }

        // Add the arguments
        for (0..callee_info.param_types.len) |index| {
            const id: ResultId = @enumFromInt(params_id_base + @as(u32, @intCast(index)));
            self.section.writeOperand(ResultId, id);
        }
    }
};

pub fn run(parser: *BinaryModule.Parser, binary: *BinaryModule, progress: std.Progress.Node) !void {
    const sub_node = progress.start("Lower invocation globals", 6);
    defer sub_node.end();

    var arena = std.heap.ArenaAllocator.init(parser.a);
    defer arena.deinit();
    const a = arena.allocator();

    var info = try ModuleInfo.parse(a, parser, binary.*);
    try info.resolve(a);

    var builder = try ModuleBuilder.init(a, binary.*, info);
    sub_node.completeOne();
    try builder.deriveNewFnInfo(info);
    sub_node.completeOne();
    try builder.processPreamble(binary.*, info);
    sub_node.completeOne();
    try builder.emitFunctionTypes(info);
    sub_node.completeOne();
    try builder.rewriteFunctions(parser, binary.*, info);
    sub_node.completeOne();
    try builder.emitNewEntryPoints(info);
    sub_node.completeOne();
    try builder.finalize(parser.a, binary);
}
