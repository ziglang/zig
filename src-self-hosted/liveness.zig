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
    try analyzeWithTable(arena, &table, body);
}

fn analyzeWithTable(arena: *std.mem.Allocator, table: *std.AutoHashMap(*ir.Inst, void), body: ir.Body) error{OutOfMemory}!void {
    var i: usize = body.instructions.len;

    while (i != 0) {
        i -= 1;
        const base = body.instructions[i];
        try analyzeInst(arena, table, base);
    }
}

fn analyzeInst(arena: *std.mem.Allocator, table: *std.AutoHashMap(*ir.Inst, void), base: *ir.Inst) error{OutOfMemory}!void {
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
            try analyzeWithTable(arena, table, inst.body);
            // We let this continue so that it can possibly mark the block as
            // unreferenced below.
        },
        .condbr => {
            const inst = base.castTag(.condbr).?;
            var true_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer true_table.deinit();
            try true_table.ensureCapacity(inst.then_body.instructions.len);
            try analyzeWithTable(arena, &true_table, inst.then_body);

            var false_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer false_table.deinit();
            try false_table.ensureCapacity(inst.else_body.instructions.len);
            try analyzeWithTable(arena, &false_table, inst.else_body);

            // Each death that occurs inside one branch, but not the other, needs
            // to be added as a death immediately upon entering the other branch.
            // During the iteration of the table, we additionally propagate the
            // deaths to the parent table.
            var true_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer true_entry_deaths.deinit();
            var false_entry_deaths = std.ArrayList(*ir.Inst).init(table.allocator);
            defer false_entry_deaths.deinit();
            {
                var it = false_table.iterator();
                while (it.next()) |entry| {
                    const false_death = entry.key;
                    if (!true_table.contains(false_death)) {
                        try true_entry_deaths.append(false_death);
                        // Here we are only adding to the parent table if the following iteration
                        // would miss it.
                        try table.putNoClobber(false_death, {});
                    }
                }
            }
            {
                var it = true_table.iterator();
                while (it.next()) |entry| {
                    const true_death = entry.key;
                    try table.putNoClobber(true_death, {});
                    if (!false_table.contains(true_death)) {
                        try false_entry_deaths.append(true_death);
                    }
                }
            }
            inst.true_death_count = std.math.cast(@TypeOf(inst.true_death_count), true_entry_deaths.items.len) catch return error.OutOfMemory;
            inst.false_death_count = std.math.cast(@TypeOf(inst.false_death_count), false_entry_deaths.items.len) catch return error.OutOfMemory;
            const allocated_slice = try arena.alloc(*ir.Inst, true_entry_deaths.items.len + false_entry_deaths.items.len);
            inst.deaths = allocated_slice.ptr;

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
            }
        }
    } else {
        @panic("Handle liveness analysis for instructions with many parameters");
    }

    std.log.debug(.liveness, "analyze {}: 0b{b}\n", .{ base.tag, base.deaths });
}
