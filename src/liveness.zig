const std = @import("std");
const ir = @import("air.zig");
const trace = @import("tracy.zig").trace;
const log = std.log.scoped(.liveness);
const assert = std.debug.assert;

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
    try table.ensureCapacity(@intCast(u32, body.instructions.len));
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
            {
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }

            var else_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer else_table.deinit();
            try analyzeWithTable(arena, table, &else_table, inst.else_body);

            var then_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer then_entry_deaths.deinit();
            var else_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer else_entry_deaths.deinit();

            {
                var it = else_table.keyIterator();
                while (it.next()) |key| {
                    const else_death = key.*;
                    if (!then_table.contains(else_death)) {
                        try then_entry_deaths.append(else_death);
                    }
                }
            }
            // This loop is the same, except it's for the then branch, and it additionally
            // has to put its items back into the table to undo the reset.
            {
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    const then_death = key.*;
                    if (!else_table.contains(then_death)) {
                        try else_entry_deaths.append(then_death);
                    }
                    try table.put(then_death, {});
                }
            }
            // Now we have to correctly populate new_set.
            if (new_set) |ns| {
                try ns.ensureCapacity(@intCast(u32, ns.count() + then_table.count() + else_table.count()));
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    _ = ns.putAssumeCapacity(key.*, {});
                }
                it = else_table.keyIterator();
                while (it.next()) |key| {
                    _ = ns.putAssumeCapacity(key.*, {});
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
        .switchbr => {
            const inst = base.castTag(.switchbr).?;

            const Table = std.AutoHashMap(*ir.Inst, void);
            const case_tables = try table.allocator.alloc(Table, inst.cases.len + 1); // +1 for else
            defer table.allocator.free(case_tables);

            std.mem.set(Table, case_tables, Table.init(table.allocator));
            defer for (case_tables) |*ct| ct.deinit();

            for (inst.cases) |case, i| {
                try analyzeWithTable(arena, table, &case_tables[i], case.body);

                // Reset the table back to its state from before the case.
                var it = case_tables[i].keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }
            { // else
                try analyzeWithTable(arena, table, &case_tables[case_tables.len - 1], inst.else_body);

                // Reset the table back to its state from before the case.
                var it = case_tables[case_tables.len - 1].keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }

            const List = std.ArrayList(*ir.Inst);
            const case_deaths = try table.allocator.alloc(List, case_tables.len); // +1 for else
            defer table.allocator.free(case_deaths);

            std.mem.set(List, case_deaths, List.init(table.allocator));
            defer for (case_deaths) |*cd| cd.deinit();

            var total_deaths: u32 = 0;
            for (case_tables) |*ct, i| {
                total_deaths += ct.count();
                var it = ct.keyIterator();
                while (it.next()) |key| {
                    const case_death = key.*;
                    for (case_tables) |*ct_inner, j| {
                        if (i == j) continue;
                        if (!ct_inner.contains(case_death)) {
                            // instruction is not referenced in this case
                            try case_deaths[j].append(case_death);
                        }
                    }
                    // undo resetting the table
                    try table.put(case_death, {});
                }
            }

            // Now we have to correctly populate new_set.
            if (new_set) |ns| {
                try ns.ensureCapacity(@intCast(u32, ns.count() + total_deaths));
                for (case_tables) |*ct| {
                    var it = ct.keyIterator();
                    while (it.next()) |key| {
                        _ = ns.putAssumeCapacity(key.*, {});
                    }
                }
            }

            total_deaths = 0;
            for (case_deaths[0 .. case_deaths.len - 1]) |*ct, i| {
                inst.cases[i].index = total_deaths;
                const len = std.math.cast(@TypeOf(inst.else_deaths), ct.items.len) catch return error.OutOfMemory;
                inst.cases[i].deaths = len;
                total_deaths += len;
            }
            { // else
                const else_deaths = std.math.cast(@TypeOf(inst.else_deaths), case_deaths[case_deaths.len - 1].items.len) catch return error.OutOfMemory;
                inst.else_index = total_deaths;
                inst.else_deaths = else_deaths;
                total_deaths += else_deaths;
            }

            const allocated_slice = try arena.alloc(*ir.Inst, total_deaths);
            inst.deaths = allocated_slice.ptr;
            for (case_deaths[0 .. case_deaths.len - 1]) |*cd, i| {
                std.mem.copy(*ir.Inst, inst.caseDeaths(i), cd.items);
            }
            std.mem.copy(*ir.Inst, inst.elseDeaths(), case_deaths[case_deaths.len - 1].items);
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

    log.debug("analyze {}: 0b{b}\n", .{ base.tag, base.deaths });
}
