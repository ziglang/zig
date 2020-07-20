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
        try analyzeInstGeneric(arena, table, base);
    }
}

fn analyzeInstGeneric(arena: *std.mem.Allocator, table: *std.AutoHashMap(*ir.Inst, void), base: *ir.Inst) error{OutOfMemory}!void {
    // Obtain the corresponding instruction type based on the tag type.
    inline for (std.meta.declarations(ir.Inst)) |decl| {
        switch (decl.data) {
            .Type => |T| {
                if (@typeInfo(T) == .Struct and @hasDecl(T, "base_tag")) {
                    if (T.base_tag == base.tag) {
                        return analyzeInst(arena, table, T, @fieldParentPtr(T, "base", base));
                    }
                }
            },
            else => {},
        }
    }
    unreachable;
}

fn analyzeInst(arena: *std.mem.Allocator, table: *std.AutoHashMap(*ir.Inst, void), comptime T: type, inst: *T) error{OutOfMemory}!void {
    if (table.contains(&inst.base)) {
        inst.base.deaths = 0;
    } else {
        // No tombstone for this instruction means it is never referenced,
        // and its birth marks its own death. Very metal 🤘
        inst.base.deaths = 1 << ir.Inst.unreferenced_bit_index;
    }

    switch (T) {
        ir.Inst.Constant => return,
        ir.Inst.Block => {
            try analyzeWithTable(arena, table, inst.args.body);
            // We let this continue so that it can possibly mark the block as
            // unreferenced below.
        },
        ir.Inst.CondBr => {
            var true_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer true_table.deinit();
            try true_table.ensureCapacity(inst.args.true_body.instructions.len);
            try analyzeWithTable(arena, &true_table, inst.args.true_body);

            var false_table = std.AutoHashMap(*ir.Inst, void).init(table.allocator);
            defer false_table.deinit();
            try false_table.ensureCapacity(inst.args.false_body.instructions.len);
            try analyzeWithTable(arena, &false_table, inst.args.false_body);

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
        ir.Inst.Call => {
            // Call instructions have a runtime-known number of operands so we have to handle them ourselves here.
            const needed_bits = 1 + inst.args.args.len;
            if (needed_bits <= ir.Inst.deaths_bits) {
                var bit_i: ir.Inst.DeathsBitIndex = 0;
                {
                    const prev = try table.fetchPut(inst.args.func, {});
                    if (prev == null) inst.base.deaths |= @as(ir.Inst.DeathsInt, 1) << bit_i;
                    bit_i += 1;
                }
                for (inst.args.args) |arg| {
                    const prev = try table.fetchPut(arg, {});
                    if (prev == null) inst.base.deaths |= @as(ir.Inst.DeathsInt, 1) << bit_i;
                    bit_i += 1;
                }
            } else {
                @panic("Handle liveness analysis for function calls with many parameters");
            }
        },
        else => {},
    }

    const Args = ir.Inst.Args(T);
    if (Args == void) {
        return;
    }

    comptime var arg_index: usize = 0;
    inline for (std.meta.fields(Args)) |field| {
        if (field.field_type == *ir.Inst) {
            if (arg_index >= 6) {
                @compileError("out of bits to mark deaths of operands");
            }
            const prev = try table.fetchPut(@field(inst.args, field.name), {});
            if (prev == null) {
                // Death.
                inst.base.deaths |= 1 << arg_index;
            }
            arg_index += 1;
        }
    }

    std.log.debug(.liveness, "analyze {}: 0b{b}\n", .{ inst.base.tag, inst.base.deaths });
}
