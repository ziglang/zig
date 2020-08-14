const std = @import("std");
const ir = @import("ir.zig");
const trace = @import("tracy.zig").trace;

/// Perform Liveness Analysis over the `Body`. Each `Inst` will have its `deaths` field populated.
pub fn analyze(
    /// Used for temporary storage during the analysis.
    gpa: *std.mem.Allocator,
    /// Used to tack on extra allocations in the same lifetime as the existing instructions.
    arena: *std.mem.Allocator,
    body: ir.Body,
) error{OutOfMemory}!void {
    const tracy = trace(@src());
    defer tracy.end();

    var table = std.AutoHashMap(*ir.Inst, void).init(gpa);
    defer table.deinit();
    try table.ensureCapacity(body.instructions.len);
    try analyzeWithTable(arena, &table, null, body);
}

fn analyzeWithTable(
    arena: *std.mem.Allocator,
    table: *std.AutoHashMap(*ir.Inst, void),
    new_set: ?*std.AutoHashMap(*ir.Inst, void),
    body: ir.Body,
) error{OutOfMemory}!void {
    var i: usize = body.instructions.len;

    if (new_set) |ns| {
        // We are only interested in doing this for instructions which are born
        // before a conditional branch, so after obtaining the new set for
        // each branch we prune the instructions which were born within.
        while (i != 0) {
            i -= 1;
            const base = body.instructions[i];
            _ = ns.remove(base);
            try analyzeInst(arena, table, new_set, base);
        }
    } else {
        while (i != 0) {
            i -= 1;
            const base = body.instructions[i];
            try analyzeInst(arena, table, new_set, base);
        }
    }
}

fn analyzeInst(
    arena: *std.mem.Allocator,
    table: *std.AutoHashMap(*ir.Inst, void),
    new_set: ?*std.AutoHashMap(*ir.Inst, void),
    base: *ir.Inst,
) error{OutOfMemory}!void {
    if (table.contains(base)) {
        base.deaths = 0;
    } else {
        // No tombstone for this instruction means it is never referenced,
        // and its birth marks its own death. Very metal 🤘
        base.deaths = 1 << ir.Inst.unreferenced_bit_index;
    }

    switch (base.tag) {
        .constant => return,
        .block => {
            const inst = base.castTag(.block).?;
            try analyzeWithTable(arena, table, new_set, inst.body);
            // We let this continue so that it can possibly mark the block as
            // unreferenced below.
        },
        .loop => {
            const inst = base.castTag(.loop).?;
            try analyzeWithTable(arena, table, new_set, inst.body);
            return; // Loop has no operands and it is always unreferenced.
        },
        .condbr => {
            const inst = base.castTag(.condbr).?;

            // Each death that occurs inside one branch, but not the other, needs
            // to be added as a death immediately upon entering the other branch.

            var then_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer then_table.deinit();
            try analyzeWithTable(arena, table, &then_table, inst.then_body);

            // Reset the table back to its state from before the branch.
            for (then_table.items()) |entry| {
                table.removeAssertDiscard(entry.key);
            }

            var else_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer else_table.deinit();
            try analyzeWithTable(arena, table, &else_table, inst.else_body);

            var then_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer then_entry_deaths.deinit();
            var else_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer else_entry_deaths.deinit();

            for (else_table.items()) |entry| {
                const else_death = entry.key;
                if (!then_table.contains(else_death)) {
                    try then_entry_deaths.append(else_death);
                }
            }
            // This loop is the same, except it's for the then branch, and it additionally
            // has to put its items back into the table to undo the reset.
            for (then_table.items()) |entry| {
                const then_death = entry.key;
                if (!else_table.contains(then_death)) {
                    try else_entry_deaths.append(then_death);
                }
                _ = try table.put(then_death, {});
            }
            // Now we have to correctly populate new_set.
            if (new_set) |ns| {
                try ns.ensureCapacity(ns.items().len + then_table.items().len + else_table.items().len);
                for (then_table.items()) |entry| {
                    _ = ns.putAssumeCapacity(entry.key, {});
                }
                for (else_table.items()) |entry| {
                    _ = ns.putAssumeCapacity(entry.key, {});
                }
            }
            inst.then_death_count = std.math.cast(@TypeOf(inst.then_death_count), then_entry_deaths.items.len) catch return error.OutOfMemory;
            inst.else_death_count = std.math.cast(@TypeOf(inst.else_death_count), else_entry_deaths.items.len) catch return error.OutOfMemory;
            const allocated_slice = try arena.alloc(*ir.Inst, then_entry_deaths.items.len + else_entry_deaths.items.len);
            inst.deaths = allocated_slice.ptr;
            std.mem.copy(*ir.Inst, inst.thenDeaths(), then_entry_deaths.items);
            std.mem.copy(*ir.Inst, inst.elseDeaths(), else_entry_deaths.items);

            // Continue on with the instruction analysis. The following code will find the condition
            // instruction, and the deaths flag for the CondBr instruction will indicate whether the
            // condition's lifetime ends immediately before entering any branch.
        },
        else => {},
    }

    const needed_bits = base.operandCount();
    if (needed_bits <= ir.Inst.deaths_bits) {
        var bit_i: ir.Inst.DeathsBitIndex = 0;
        while (base.getOperand(bit_i)) |operand| : (bit_i += 1) {
            const prev = try table.fetchPut(operand, {});
            if (prev == null) {
                // Death.
                base.deaths |= @as(ir.Inst.DeathsInt, 1) << bit_i;
                if (new_set) |ns| try ns.putNoClobber(operand, {});
            }
        }
    } else {
        @panic("Handle liveness analysis for instructions with many parameters");
    }

    std.log.debug(.liveness, "analyze {}: 0b{b}\n", .{ base.tag, base.deaths });
}
