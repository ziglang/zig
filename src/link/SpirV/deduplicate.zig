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
        .OpName, .OpMemberName => true, // Debug decoration-style instructions
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
    };

    /// Maps result-id to Entity's
    entities: std.AutoArrayHashMapUnmanaged(ResultId, Entity),
    /// A bit set that keeps track of which operands are result-ids.
    /// Note: This also includes any result-id!
    /// Because we need these values when recoding the module anyway,
    /// it contains the status of ALL operands in the module.
    operand_is_id: std.DynamicBitSetUnmanaged,

    pub fn parse(
        arena: Allocator,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
    ) !ModuleInfo {
        var entities = std.AutoArrayHashMap(ResultId, Entity).init(arena);
        var id_offsets = std.ArrayList(u16).init(arena);
        var operand_is_id = try std.DynamicBitSetUnmanaged.initEmpty(arena, binary.instructions.len);

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

            switch (inst.opcode.class()) {
                .Annotation, .Debug => {
                    // TODO
                },
                .TypeDeclaration, .ConstantCreation => {
                    const entry = try entities.getOrPut(result_id);
                    if (entry.found_existing) {
                        log.err("type or constant {} has duplicate definition", .{result_id});
                        return error.DuplicateId;
                    }
                    entry.value_ptr.* = .{
                        .kind = inst.opcode,
                        .first_operand = first_operand_offset,
                        .num_operands = @intCast(inst.operands.len),
                        .result_id_index = result_id_index,
                    };
                },
                else => unreachable,
            }
        }

        return ModuleInfo{
            .entities = entities.unmanaged,
            .operand_is_id = operand_is_id,
        };
    }
};

const EntityContext = struct {
    a: Allocator,
    ptr_map_a: std.AutoArrayHashMapUnmanaged(ResultId, void) = .{},
    ptr_map_b: std.AutoArrayHashMapUnmanaged(ResultId, void) = .{},
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

    fn hashInner(self: *EntityContext, hasher: *std.hash.Wyhash, id: ResultId) !void {
        const index = self.info.entities.getIndex(id).?;
        const entity = self.info.entities.values()[index];

        std.hash.autoHash(hasher, entity.kind);
        if (entity.kind == .OpTypePointer) {
            // This may be either a pointer that is forward-referenced in the future,
            // or a forward reference to a pointer.
            const entry = try self.ptr_map_a.getOrPut(self.a, id);
            if (entry.found_existing) {
                // Pointer already seen. Hash the index instead of recursing into its children.
                // TODO: Discriminate this path somehow?
                std.hash.autoHash(hasher, entry.index);
                return;
            }
        }

        // Process operands
        const operands = self.binary.instructions[entity.first_operand..][0..entity.num_operands];
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

    fn eqlInner(self: *EntityContext, id_a: ResultId, id_b: ResultId) !bool {
        const index_a = self.info.entities.getIndex(id_a).?;
        const index_b = self.info.entities.getIndex(id_b).?;

        const entity_a = self.info.entities.values()[index_a];
        const entity_b = self.info.entities.values()[index_b];

        if (entity_a.kind != entity_b.kind) {
            return false;
        } else if (entity_a.result_id_index != entity_a.result_id_index) {
            return false;
        }

        if (entity_a.kind == .OpTypePointer) {
            // May be a forward reference, or should be saved as a potential
            // forward reference in the future. Whatever the case, it should
            // be the same for both a and b.
            const entry_a = try self.ptr_map_a.getOrPut(self.a, id_a);
            const entry_b = try self.ptr_map_b.getOrPut(self.a, id_b);

            if (entry_a.found_existing != entry_b.found_existing) return false;
            if (entry_a.index != entry_b.index) return false;

            if (entry_a.found_existing) {
                // No need to recurse.
                return true;
            }
        }

        const operands_a = self.binary.instructions[entity_a.first_operand..][0..entity_a.num_operands];
        const operands_b = self.binary.instructions[entity_b.first_operand..][0..entity_b.num_operands];

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

pub fn run(parser: *BinaryModule.Parser, binary: *BinaryModule) !void {
    var arena = std.heap.ArenaAllocator.init(parser.a);
    defer arena.deinit();
    const a = arena.allocator();

    const info = try ModuleInfo.parse(a, parser, binary.*);
    log.info("added {} entities", .{info.entities.count()});

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
    for (info.entities.keys(), info.entities.values()) |id, entity| {
        const entry = try map.getOrPut(id);
        if (entry.found_existing) {
            log.info("deduplicating {} - {s} (prior definition: {})", .{ id, @tagName(entity.kind), entry.key_ptr.* });
            try replace.putNoClobber(id, entry.key_ptr.*);
        }
    }

    // Now process the module, and replace instructions where needed.
    var section = Section{};
    var it = binary.iterateInstructions();
    var new_functions_section: ?usize = null;
    var new_operands = std.ArrayList(u32).init(a);
    var emitted_ptrs = std.AutoHashMap(ResultId, void).init(a);
    while (it.next()) |inst| {
        // Result-id can only be the first or second operand
        const inst_spec = parser.getInstSpec(inst.opcode).?;
        const maybe_result_id: ?ResultId = for (0..2) |i| {
            if (inst_spec.operands.len > i and inst_spec.operands[i].kind == .IdResult) {
                break @enumFromInt(inst.operands[i]);
            }
        } else null;

        if (maybe_result_id) |result_id| {
            if (replace.contains(result_id)) continue;
        }

        switch (inst.opcode) {
            .OpFunction => if (new_functions_section == null) {
                new_functions_section = section.instructions.items.len;
            },
            .OpTypeForwardPointer => continue, // We re-emit these where needed
            // TODO: These aren't supported yet, strip them out for testing purposes.
            .OpName, .OpMemberName => continue,
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

            const id: ResultId = @enumFromInt(operand.*);
            // TODO: This test is a little janky. Check the offset instead?
            if (maybe_result_id == null or maybe_result_id.? != id) {
                const index = info.entities.getIndex(id) orelse continue;
                const entity = info.entities.values()[index];
                if (entity.kind == .OpTypePointer and !emitted_ptrs.contains(id)) {
                    // Grab the pointer's storage class from its operands in the original
                    // module.
                    const storage_class: spec.StorageClass = @enumFromInt(binary.instructions[entity.first_operand + 1]);
                    try section.emit(a, .OpTypeForwardPointer, .{
                        .pointer_type = id,
                        .storage_class = storage_class,
                    });
                    try emitted_ptrs.put(id, {});
                }
            }
        }

        if (inst.opcode == .OpTypePointer) {
            try emitted_ptrs.put(maybe_result_id.?, {});
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
