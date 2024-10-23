const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.spirv_link);
const assert = std.debug.assert;

const BinaryModule = @import("BinaryModule.zig");
const Section = @import("../../codegen/spirv/Section.zig");
const spec = @import("../../codegen/spirv/spec.zig");
const Opcode = spec.Opcode;
const ResultId = spec.IdResult;
const Word = spec.Word;

fn canDeduplicate(opcode: Opcode) bool {
    return switch (opcode) {
        .OpTypeForwardPointer => false, // Don't need to handle these
        .OpGroupDecorate, .OpGroupMemberDecorate => {
            // These are deprecated, so don't bother supporting them for now.
            return false;
        },
        // Debug decoration-style instructions
        .OpName, .OpMemberName => true,
        else => switch (opcode.class()) {
            .TypeDeclaration,
            .ConstantCreation,
            .Annotation,
            => true,
            else => false,
        },
    };
}

const ModuleInfo = struct {
    /// This models a type, decoration or constant instruction
    /// and its dependencies.
    const Entity = struct {
        /// The type that this entity represents. This is just
        /// the instruction opcode.
        kind: Opcode,
        /// The offset of this entity's operands, in
        /// `binary.instructions`.
        first_operand: u32,
        /// The number of operands in this entity
        num_operands: u16,
        /// The (first_operand-relative) offset of the result-id,
        /// or the entity that is affected by this entity if this entity
        /// is a decoration.
        result_id_index: u16,
        /// The first decoration in `self.decorations`.
        first_decoration: u32,

        fn operands(self: Entity, binary: *const BinaryModule) []const Word {
            return binary.instructions[self.first_operand..][0..self.num_operands];
        }
    };

    /// Maps result-id to Entity's
    entities: std.AutoArrayHashMapUnmanaged(ResultId, Entity),
    /// A bit set that keeps track of which operands are result-ids.
    /// Note: This also includes any result-id!
    /// Because we need these values when recoding the module anyway,
    /// it contains the status of ALL operands in the module.
    operand_is_id: std.DynamicBitSetUnmanaged,
    /// Store of decorations for each entity.
    decorations: []const Entity,

    pub fn parse(
        arena: Allocator,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
    ) !ModuleInfo {
        var entities = std.AutoArrayHashMap(ResultId, Entity).init(arena);
        var id_offsets = std.ArrayList(u16).init(arena);
        var operand_is_id = try std.DynamicBitSetUnmanaged.initEmpty(arena, binary.instructions.len);
        var decorations = std.MultiArrayList(struct { target_id: ResultId, entity: Entity }){};

        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            id_offsets.items.len = 0;
            try parser.parseInstructionResultIds(binary, inst, &id_offsets);

            const first_operand_offset: u32 = @intCast(inst.offset + 1);
            for (id_offsets.items) |offset| {
                operand_is_id.set(first_operand_offset + offset);
            }

            if (!canDeduplicate(inst.opcode)) continue;

            const result_id_index: u16 = switch (inst.opcode.class()) {
                .TypeDeclaration, .Annotation, .Debug => 0,
                .ConstantCreation => 1,
                else => unreachable,
            };

            const result_id: ResultId = @enumFromInt(inst.operands[id_offsets.items[result_id_index]]);
            const entity = Entity{
                .kind = inst.opcode,
                .first_operand = first_operand_offset,
                .num_operands = @intCast(inst.operands.len),
                .result_id_index = result_id_index,
                .first_decoration = undefined, // Filled in later
            };

            switch (inst.opcode.class()) {
                .Annotation, .Debug => {
                    try decorations.append(arena, .{
                        .target_id = result_id,
                        .entity = entity,
                    });
                },
                .TypeDeclaration, .ConstantCreation => {
                    const entry = try entities.getOrPut(result_id);
                    if (entry.found_existing) {
                        log.err("type or constant {} has duplicate definition", .{result_id});
                        return error.DuplicateId;
                    }
                    entry.value_ptr.* = entity;
                },
                else => unreachable,
            }
        }

        // Sort decorations by the index of the result-id in `entities.
        // This ensures not only that the decorations of a particular reuslt-id
        // are continuous, but the subsequences also appear in the same order as in `entities`.

        const SortContext = struct {
            entities: std.AutoArrayHashMapUnmanaged(ResultId, Entity),
            ids: []const ResultId,

            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                // If any index is not in the entities set, its because its not a
                // deduplicatable result-id. Those should be considered largest and
                // float to the end.
                const entity_index_a = ctx.entities.getIndex(ctx.ids[a_index]) orelse return false;
                const entity_index_b = ctx.entities.getIndex(ctx.ids[b_index]) orelse return true;

                return entity_index_a < entity_index_b;
            }
        };

        decorations.sort(SortContext{
            .entities = entities.unmanaged,
            .ids = decorations.items(.target_id),
        });

        // Now go through the decorations and add the offsets to the entities list.
        var decoration_i: u32 = 0;
        const target_ids = decorations.items(.target_id);
        for (entities.keys(), entities.values()) |id, *entity| {
            entity.first_decoration = decoration_i;

            // Scan ahead to the next decoration
            while (decoration_i < target_ids.len and target_ids[decoration_i] == id) {
                decoration_i += 1;
            }
        }

        return ModuleInfo{
            .entities = entities.unmanaged,
            .operand_is_id = operand_is_id,
            // There may be unrelated decorations at the end, so make sure to
            // slice those off.
            .decorations = decorations.items(.entity)[0..decoration_i],
        };
    }

    fn entityDecorationsByIndex(self: ModuleInfo, index: usize) []const Entity {
        const values = self.entities.values();
        const first_decoration = values[index].first_decoration;
        if (index == values.len - 1) {
            return self.decorations[first_decoration..];
        } else {
            const next_first_decoration = values[index + 1].first_decoration;
            return self.decorations[first_decoration..next_first_decoration];
        }
    }
};

const EntityContext = struct {
    a: Allocator,
    ptr_map_a: std.AutoArrayHashMapUnmanaged(ResultId, void) = .empty,
    ptr_map_b: std.AutoArrayHashMapUnmanaged(ResultId, void) = .empty,
    info: *const ModuleInfo,
    binary: *const BinaryModule,

    fn deinit(self: *EntityContext) void {
        self.ptr_map_a.deinit(self.a);
        self.ptr_map_b.deinit(self.a);

        self.* = undefined;
    }

    fn equalizeMapCapacity(self: *EntityContext) !void {
        const cap = @max(self.ptr_map_a.capacity(), self.ptr_map_b.capacity());
        try self.ptr_map_a.ensureTotalCapacity(self.a, cap);
        try self.ptr_map_b.ensureTotalCapacity(self.a, cap);
    }

    fn hash(self: *EntityContext, id: ResultId) !u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.ptr_map_a.clearRetainingCapacity();
        try self.hashInner(&hasher, id);
        return hasher.final();
    }

    fn hashInner(self: *EntityContext, hasher: *std.hash.Wyhash, id: ResultId) error{OutOfMemory}!void {
        const index = self.info.entities.getIndex(id) orelse {
            // Index unknown, the type or constant may depend on another result-id
            // that couldn't be deduplicated and so it wasn't added to info.entities.
            // In this case, just has the ID itself.
            std.hash.autoHash(hasher, id);
            return;
        };

        const entity = self.info.entities.values()[index];

        // If the current pointer is recursive, don't immediately add it to the map. This is to ensure that
        // if the current pointer is already recursive, it gets the same hash a pointer that points to the
        // same child but has a different result-id.
        if (entity.kind == .OpTypePointer) {
            // This may be either a pointer that is forward-referenced in the future,
            // or a forward reference to a pointer.
            // Note: We use the **struct** here instead of the pointer itself, to avoid an edge case like this:
            //
            // A - C*'
            //        \
            //         C - C*'
            //        /
            // B - C*"
            //
            // In this case, hashing A goes like
            //   A -> C*' -> C -> C*' recursion
            // And hashing B goes like
            //   B -> C*" -> C -> C*' -> C -> C*' recursion
            // The are several calls to ptrType in codegen that may C*' and C*" to be generated as separate
            // types. This is not a problem for C itself though - this can only be generated through resolveType()
            // and so ensures equality by Zig's type system. Technically the above problem is still present, but it
            // would only be present in a structure such as
            //
            // A - C*' - C'
            //             \
            //              C*" - C - C*
            //             /
            //            B
            //
            // where there is a duplicate definition of struct C. Resolving this requires a much more time consuming
            // algorithm though, and because we don't expect any correctness issues with it, we leave that for now.

            // TODO: Do we need to mind the storage class here? Its going to be recursive regardless, right?
            const struct_id: ResultId = @enumFromInt(entity.operands(self.binary)[2]);
            const entry = try self.ptr_map_a.getOrPut(self.a, struct_id);
            if (entry.found_existing) {
                // Pointer already seen. Hash the index instead of recursing into its children.
                std.hash.autoHash(hasher, entry.index);
                return;
            }
        }

        try self.hashEntity(hasher, entity);

        // Process decorations.
        const decorations = self.info.entityDecorationsByIndex(index);
        for (decorations) |decoration| {
            try self.hashEntity(hasher, decoration);
        }

        if (entity.kind == .OpTypePointer) {
            const struct_id: ResultId = @enumFromInt(entity.operands(self.binary)[2]);
            assert(self.ptr_map_a.swapRemove(struct_id));
        }
    }

    fn hashEntity(self: *EntityContext, hasher: *std.hash.Wyhash, entity: ModuleInfo.Entity) !void {
        std.hash.autoHash(hasher, entity.kind);
        // Process operands
        const operands = entity.operands(self.binary);
        for (operands, 0..) |operand, i| {
            if (i == entity.result_id_index) {
                // Not relevant, skip...
                continue;
            } else if (self.info.operand_is_id.isSet(entity.first_operand + i)) {
                // Operand is ID
                try self.hashInner(hasher, @enumFromInt(operand));
            } else {
                // Operand is merely data
                std.hash.autoHash(hasher, operand);
            }
        }
    }

    fn eql(self: *EntityContext, a: ResultId, b: ResultId) !bool {
        self.ptr_map_a.clearRetainingCapacity();
        self.ptr_map_b.clearRetainingCapacity();

        return try self.eqlInner(a, b);
    }

    fn eqlInner(self: *EntityContext, id_a: ResultId, id_b: ResultId) error{OutOfMemory}!bool {
        const maybe_index_a = self.info.entities.getIndex(id_a);
        const maybe_index_b = self.info.entities.getIndex(id_b);

        if (maybe_index_a == null and maybe_index_b == null) {
            // Both indices unknown. In this case the type or constant
            // may depend on another result-id that couldn't be deduplicated
            // (so it wasn't added to info.entities). In this case, that particular
            // result-id should be the same one.
            return id_a == id_b;
        }

        const index_a = maybe_index_a orelse return false;
        const index_b = maybe_index_b orelse return false;

        const entity_a = self.info.entities.values()[index_a];
        const entity_b = self.info.entities.values()[index_b];

        if (entity_a.kind != entity_b.kind) {
            return false;
        }

        if (entity_a.kind == .OpTypePointer) {
            // May be a forward reference, or should be saved as a potential
            // forward reference in the future. Whatever the case, it should
            // be the same for both a and b.
            const struct_id_a: ResultId = @enumFromInt(entity_a.operands(self.binary)[2]);
            const struct_id_b: ResultId = @enumFromInt(entity_b.operands(self.binary)[2]);

            const entry_a = try self.ptr_map_a.getOrPut(self.a, struct_id_a);
            const entry_b = try self.ptr_map_b.getOrPut(self.a, struct_id_b);

            if (entry_a.found_existing != entry_b.found_existing) return false;
            if (entry_a.index != entry_b.index) return false;

            if (entry_a.found_existing) {
                // No need to recurse.
                return true;
            }
        }

        if (!try self.eqlEntities(entity_a, entity_b)) {
            return false;
        }

        // Compare decorations.
        const decorations_a = self.info.entityDecorationsByIndex(index_a);
        const decorations_b = self.info.entityDecorationsByIndex(index_b);
        if (decorations_a.len != decorations_b.len) {
            return false;
        }

        for (decorations_a, decorations_b) |decoration_a, decoration_b| {
            if (!try self.eqlEntities(decoration_a, decoration_b)) {
                return false;
            }
        }

        if (entity_a.kind == .OpTypePointer) {
            const struct_id_a: ResultId = @enumFromInt(entity_a.operands(self.binary)[2]);
            const struct_id_b: ResultId = @enumFromInt(entity_b.operands(self.binary)[2]);

            assert(self.ptr_map_a.swapRemove(struct_id_a));
            assert(self.ptr_map_b.swapRemove(struct_id_b));
        }

        return true;
    }

    fn eqlEntities(self: *EntityContext, entity_a: ModuleInfo.Entity, entity_b: ModuleInfo.Entity) !bool {
        if (entity_a.kind != entity_b.kind) {
            return false;
        } else if (entity_a.result_id_index != entity_a.result_id_index) {
            return false;
        }

        const operands_a = entity_a.operands(self.binary);
        const operands_b = entity_b.operands(self.binary);

        // Note: returns false for operands that have explicit defaults in optional operands... oh well
        if (operands_a.len != operands_b.len) {
            return false;
        }

        for (operands_a, operands_b, 0..) |operand_a, operand_b, i| {
            const a_is_id = self.info.operand_is_id.isSet(entity_a.first_operand + i);
            const b_is_id = self.info.operand_is_id.isSet(entity_b.first_operand + i);
            if (a_is_id != b_is_id) {
                return false;
            } else if (i == entity_a.result_id_index) {
                // result-id for both...
                continue;
            } else if (a_is_id) {
                // Both are IDs, so recurse.
                if (!try self.eqlInner(@enumFromInt(operand_a), @enumFromInt(operand_b))) {
                    return false;
                }
            } else if (operand_a != operand_b) {
                return false;
            }
        }

        return true;
    }
};

/// This struct is a wrapper around EntityContext that adapts it for
/// use in a hash map. Because EntityContext allocates, it cannot be
/// used. This wrapper simply assumes that the maps have been allocated
/// the max amount of memory they are going to use.
/// This is done by pre-hashing all keys.
const EntityHashContext = struct {
    entity_context: *EntityContext,

    pub fn hash(self: EntityHashContext, key: ResultId) u64 {
        return self.entity_context.hash(key) catch unreachable;
    }

    pub fn eql(self: EntityHashContext, a: ResultId, b: ResultId) bool {
        return self.entity_context.eql(a, b) catch unreachable;
    }
};

pub fn run(parser: *BinaryModule.Parser, binary: *BinaryModule, progress: std.Progress.Node) !void {
    const sub_node = progress.start("deduplicate", 0);
    defer sub_node.end();

    var arena = std.heap.ArenaAllocator.init(parser.a);
    defer arena.deinit();
    const a = arena.allocator();

    const info = try ModuleInfo.parse(a, parser, binary.*);

    // Hash all keys once so that the maps can be allocated the right size.
    var ctx = EntityContext{
        .a = a,
        .info = &info,
        .binary = binary,
    };

    for (info.entities.keys()) |id| {
        _ = try ctx.hash(id);
    }

    // hash only uses ptr_map_a, so allocate ptr_map_b too
    try ctx.equalizeMapCapacity();

    // Figure out which entities can be deduplicated.
    var map = std.HashMap(ResultId, void, EntityHashContext, 80).initContext(a, .{
        .entity_context = &ctx,
    });
    var replace = std.AutoArrayHashMap(ResultId, ResultId).init(a);
    for (info.entities.keys()) |id| {
        const entry = try map.getOrPut(id);
        if (entry.found_existing) {
            try replace.putNoClobber(id, entry.key_ptr.*);
        }
    }

    sub_node.setEstimatedTotalItems(binary.instructions.len);

    // Now process the module, and replace instructions where needed.
    var section = Section{};
    var it = binary.iterateInstructions();
    var new_functions_section: ?usize = null;
    var new_operands = std.ArrayList(u32).init(a);
    var emitted_ptrs = std.AutoHashMap(ResultId, void).init(a);
    while (it.next()) |inst| {
        defer sub_node.setCompletedItems(inst.offset);

        // Result-id can only be the first or second operand
        const inst_spec = parser.getInstSpec(inst.opcode).?;

        const maybe_result_id_offset: ?u16 = for (0..2) |i| {
            if (inst_spec.operands.len > i and inst_spec.operands[i].kind == .IdResult) {
                break @intCast(i);
            }
        } else null;

        if (maybe_result_id_offset) |offset| {
            const result_id: ResultId = @enumFromInt(inst.operands[offset]);
            if (replace.contains(result_id)) continue;
        }

        switch (inst.opcode) {
            .OpFunction => if (new_functions_section == null) {
                new_functions_section = section.instructions.items.len;
            },
            .OpTypeForwardPointer => continue, // We re-emit these where needed
            else => {},
        }

        switch (inst.opcode.class()) {
            .Annotation, .Debug => {
                // For decoration-style instructions, only emit them
                // if the target is not removed.
                const target: ResultId = @enumFromInt(inst.operands[0]);
                if (replace.contains(target)) continue;
            },
            else => {},
        }

        // Re-emit the instruction, but replace all the IDs.

        new_operands.items.len = 0;
        try new_operands.appendSlice(inst.operands);

        for (new_operands.items, 0..) |*operand, i| {
            const is_id = info.operand_is_id.isSet(inst.offset + 1 + i);
            if (!is_id) continue;

            if (replace.get(@enumFromInt(operand.*))) |new_id| {
                operand.* = @intFromEnum(new_id);
            }

            if (maybe_result_id_offset == null or maybe_result_id_offset.? != i) {
                const id: ResultId = @enumFromInt(operand.*);
                const index = info.entities.getIndex(id) orelse continue;
                const entity = info.entities.values()[index];
                if (entity.kind == .OpTypePointer and !emitted_ptrs.contains(id)) {
                    // Grab the pointer's storage class from its operands in the original
                    // module.
                    const storage_class: spec.StorageClass = @enumFromInt(entity.operands(binary)[1]);
                    try section.emit(a, .OpTypeForwardPointer, .{
                        .pointer_type = id,
                        .storage_class = storage_class,
                    });
                    try emitted_ptrs.put(id, {});
                }
            }
        }

        if (inst.opcode == .OpTypePointer) {
            const result_id: ResultId = @enumFromInt(new_operands.items[maybe_result_id_offset.?]);
            try emitted_ptrs.put(result_id, {});
        }

        try section.emitRawInstruction(a, inst.opcode, new_operands.items);
    }

    for (replace.keys()) |key| {
        _ = binary.ext_inst_map.remove(key);
        _ = binary.arith_type_width.remove(key);
    }

    binary.instructions = try parser.a.dupe(Word, section.toWords());
    binary.sections.functions = new_functions_section orelse binary.instructions.len;
}
