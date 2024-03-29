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
        /// Offset of first child result-id, stored in entity_children.
        /// These are the shallow entities appearing directly in the
        /// type's instruction.
        first_child: u32,
        /// Offset to the first word of extra-data: Data in the instruction
        /// that must be considered for uniqueness, but doesn't include
        /// any IDs.
        first_extra_data: u32,
    };

    /// Maps result-id to Entity's
    entities: std.AutoArrayHashMapUnmanaged(ResultId, Entity),
    /// The list of children per instruction.
    entity_children: []const ResultId,
    /// The list of extra data per instruction.
    /// TODO: This is a bit awkward, maybe we need to store it some
    /// other way?
    extra_data: []const u32,

    pub fn parse(
        arena: Allocator,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
    ) !ModuleInfo {
        var entities = std.AutoArrayHashMap(ResultId, Entity).init(arena);
        var entity_children = std.ArrayList(ResultId).init(arena);
        var extra_data = std.ArrayList(u32).init(arena);
        var id_offsets = std.ArrayList(u16).init(arena);

        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            if (inst.opcode == .OpFunction) break; // No more declarations are possible
            if (!canDeduplicate(inst.opcode)) continue;

            id_offsets.items.len = 0;
            try parser.parseInstructionResultIds(binary, inst, &id_offsets);

            const result_id_index: u32 = switch (inst.opcode.class()) {
                .TypeDeclaration, .Annotation, .Debug => 0,
                .ConstantCreation => 1,
                else => unreachable,
            };

            const result_id: ResultId = @enumFromInt(inst.operands[id_offsets.items[result_id_index]]);

            const first_child: u32 = @intCast(entity_children.items.len);
            const first_extra_data: u32 = @intCast(extra_data.items.len);

            try entity_children.ensureUnusedCapacity(id_offsets.items.len - 1);
            try extra_data.ensureUnusedCapacity(inst.operands.len - id_offsets.items.len);

            var id_i: usize = 0;
            for (inst.operands, 0..) |operand, i| {
                assert(id_i == id_offsets.items.len or id_offsets.items[id_i] >= i);
                if (id_i != id_offsets.items.len and id_offsets.items[id_i] == i) {
                    // Skip .IdResult / .IdResultType.
                    if (id_i != result_id_index) {
                        entity_children.appendAssumeCapacity(@enumFromInt(operand));
                    }
                    id_i += 1;
                } else {
                    // Non-id operand, add it to extra data.
                    extra_data.appendAssumeCapacity(operand);
                }
            }

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
                        .first_child = first_child,
                        .first_extra_data = first_extra_data,
                    };
                },
                else => unreachable,
            }
        }

        return ModuleInfo{
            .entities = entities.unmanaged,
            .entity_children = entity_children.items,
            .extra_data = extra_data.items,
        };
    }

    /// Fetch a slice of children for the index corresponding to an entity.
    fn childrenByIndex(self: ModuleInfo, index: usize) []const ResultId {
        const values = self.entities.values();
        const first_child = values[index].first_child;
        if (index == values.len - 1) {
            return self.entity_children[first_child..];
        } else {
            const next_first_child = values[index + 1].first_child;
            return self.entity_children[first_child..next_first_child];
        }
    }

    /// Fetch the slice of extra-data for the index corresponding to an entity.
    fn extraDataByIndex(self: ModuleInfo, index: usize) []const u32 {
        const values = self.entities.values();
        const first_extra_data = values[index].first_extra_data;
        if (index == values.len - 1) {
            return self.extra_data[first_extra_data..];
        } else {
            const next_extra_data = values[index + 1].first_extra_data;
            return self.extra_data[first_extra_data..next_extra_data];
        }
    }
};

const EntityContext = struct {
    a: Allocator,
    ptr_map_a: std.AutoArrayHashMapUnmanaged(ResultId, void) = .{},
    ptr_map_b: std.AutoArrayHashMapUnmanaged(ResultId, void) = .{},
    info: *const ModuleInfo,

    fn init(a: Allocator, info: *const ModuleInfo) EntityContext {
        return .{
            .a = a,
            .info = info,
        };
    }

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

        // Hash extra data
        for (self.info.extraDataByIndex(index)) |data| {
            std.hash.autoHash(hasher, data);
        }

        // Hash children
        for (self.info.childrenByIndex(index)) |child| {
            try self.hashInner(hasher, child);
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

        if (entity_a.kind != entity_b.kind) return false;

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

        // Check if extra data is the same.
        if (!std.mem.eql(u32, self.info.extraDataByIndex(index_a), self.info.extraDataByIndex(index_b))) {
            return false;
        }

        // Recursively check if children are the same
        const children_a = self.info.childrenByIndex(index_a);
        const children_b = self.info.childrenByIndex(index_b);
        if (children_a.len != children_b.len) return false;

        for (children_a, children_b) |child_a, child_b| {
            if (!try self.eqlInner(child_a, child_b)) {
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
    log.info("children size: {}", .{info.entity_children.len});
    log.info("extra data size: {}", .{info.extra_data.len});

    // Hash all keys once so that the maps can be allocated the right size.
    var ctx = EntityContext.init(a, &info);
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
    var id_offsets = std.ArrayList(u16).init(a);
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

        id_offsets.items.len = 0;
        try parser.parseInstructionResultIds(binary.*, inst, &id_offsets);

        new_operands.items.len = 0;
        try new_operands.appendSlice(inst.operands);
        for (id_offsets.items) |offset| {
            {
                const id: ResultId = @enumFromInt(inst.operands[offset]);
                if (replace.get(id)) |new_id| {
                    new_operands.items[offset] = @intFromEnum(new_id);
                }
            }

            // TODO: Does this logic work? Maybe it will emit an OpTypeForwardPointer to
            // something thats not a struct...
            // It seems to work correctly on behavior.zig at least
            const id: ResultId = @enumFromInt(new_operands.items[offset]);
            if (maybe_result_id == null or maybe_result_id.? != id) {
                const index = info.entities.getIndex(id) orelse continue;
                const entity = info.entities.values()[index];
                if (entity.kind == .OpTypePointer) {
                    if (!emitted_ptrs.contains(id)) {
                        // The storage class is in the extra data
                        // TODO: This is kind of hacky...
                        const extra_data = info.extraDataByIndex(index);
                        const storage_class: spec.StorageClass = @enumFromInt(extra_data[0]);
                        try section.emit(a, .OpTypeForwardPointer, .{
                            .pointer_type = id,
                            .storage_class = storage_class,
                        });
                        try emitted_ptrs.put(id, {});
                    }
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
