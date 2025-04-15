pub const Entry = struct {
    target: MachO.Ref,
    offset: u64,
    segment_id: u4,
    addend: i64,

    pub fn lessThan(ctx: *MachO, entry: Entry, other: Entry) bool {
        _ = ctx;
        if (entry.segment_id == other.segment_id) {
            if (entry.target.eql(other.target)) {
                return entry.offset < other.offset;
            }
            return entry.target.lessThan(other.target);
        }
        return entry.segment_id < other.segment_id;
    }
};

pub const Bind = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,

    pub fn deinit(bind: *Bind, gpa: Allocator) void {
        bind.entries.deinit(gpa);
        bind.buffer.deinit(gpa);
    }

    pub fn updateSize(bind: *Bind, macho_file: *MachO) !void {
        const tracy = trace(@src());
        defer tracy.end();

        const gpa = macho_file.base.comp.gpa;
        const cpu_arch = macho_file.getTarget().cpu.arch;

        var objects = try std.ArrayList(File.Index).initCapacity(gpa, macho_file.objects.items.len + 2);
        defer objects.deinit();
        objects.appendSliceAssumeCapacity(macho_file.objects.items);
        if (macho_file.getZigObject()) |obj| objects.appendAssumeCapacity(obj.index);
        if (macho_file.getInternalObject()) |obj| objects.appendAssumeCapacity(obj.index);

        for (objects.items) |index| {
            const file = macho_file.getFile(index).?;
            for (file.getAtoms()) |atom_index| {
                const atom = file.getAtom(atom_index) orelse continue;
                if (!atom.isAlive()) continue;
                if (atom.getInputSection(macho_file).isZerofill()) continue;
                const atom_addr = atom.getAddress(macho_file);
                const relocs = atom.getRelocs(macho_file);
                const seg_id = macho_file.sections.items(.segment_id)[atom.out_n_sect];
                const seg = macho_file.segments.items[seg_id];
                for (relocs) |rel| {
                    if (rel.type != .unsigned or rel.meta.length != 3 or rel.tag != .@"extern") continue;
                    const rel_offset = rel.offset - atom.off;
                    const addend = rel.addend + rel.getRelocAddend(cpu_arch);
                    const sym = rel.getTargetSymbol(atom.*, macho_file);
                    if (sym.isTlvInit(macho_file)) continue;
                    if (sym.flags.import or (!(sym.flags.@"export" and sym.flags.weak) and sym.flags.interposable)) (try bind.entries.addOne(gpa)).* = .{
                        .target = rel.getTargetSymbolRef(atom.*, macho_file),
                        .offset = atom_addr + rel_offset - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = addend,
                    };
                }
            }
        }

        if (macho_file.got_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.got.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.got.getAddress(@intCast(idx), macho_file);
                if (sym.flags.import or (sym.flags.@"export" and sym.flags.interposable and !sym.flags.weak)) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        if (macho_file.la_symbol_ptr_sect_index) |sid| {
            const sect = macho_file.sections.items(.header)[sid];
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = sect.addr + idx * @sizeOf(u64);
                if (sym.flags.import and sym.flags.weak) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        if (macho_file.tlv_ptr_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.tlv_ptr.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.tlv_ptr.getAddress(@intCast(idx), macho_file);
                if (sym.flags.import or (sym.flags.@"export" and sym.flags.interposable and !sym.flags.weak)) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        try bind.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.bind_size = mem.alignForward(u32, @intCast(bind.buffer.items.len), @alignOf(u64));
    }

    fn finalize(bind: *Bind, gpa: Allocator, ctx: *MachO) !void {
        if (bind.entries.items.len == 0) return;

        var aw: std.io.AllocatingWriter = undefined;
        const bw = aw.fromArrayList(gpa, &bind.buffer);
        defer bind.buffer = aw.toArrayList();

        log.debug("bind opcodes", .{});

        std.mem.sort(Entry, bind.entries.items, ctx, Entry.lessThan);

        var start: usize = 0;
        var seg_id: ?u8 = null;
        for (bind.entries.items, 0..) |entry, i| {
            if (seg_id != null and seg_id.? == entry.segment_id) continue;
            try finalizeSegment(bind.entries.items[start..i], ctx, bw);
            seg_id = entry.segment_id;
            start = i;
        }

        try finalizeSegment(bind.entries.items[start..], ctx, bw);
        try done(bw);
    }

    fn finalizeSegment(entries: []const Entry, ctx: *MachO, bw: *std.io.BufferedWriter) anyerror!void {
        if (entries.len == 0) return;

        const seg_id = entries[0].segment_id;
        try setSegmentOffset(seg_id, 0, bw);

        var offset: u64 = 0;
        var addend: i64 = 0;
        var count: usize = 0;
        var skip: u64 = 0;
        var target: ?MachO.Ref = null;

        var state: enum {
            start,
            bind_single,
            bind_times_skip,
        } = .start;

        var i: usize = 0;
        while (i < entries.len) : (i += 1) {
            const current = entries[i];
            if (target == null or !target.?.eql(current.target)) {
                switch (state) {
                    .start => {},
                    .bind_single => try doBind(bw),
                    .bind_times_skip => try doBindTimesSkip(count, skip, bw),
                }
                state = .start;
                target = current.target;

                const sym = current.target.getSymbol(ctx).?;
                const name = sym.getName(ctx);
                const flags: u4 = if (sym.weakRef(ctx)) macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT else 0;
                const ordinal: i16 = ord: {
                    if (sym.flags.interposable) break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                    if (sym.flags.import) {
                        // TODO: if (ctx.options.namespace == .flat) break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                        if (sym.getDylibOrdinal(ctx)) |ord| break :ord @bitCast(ord);
                    }
                    if (ctx.undefined_treatment == .dynamic_lookup)
                        break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                    break :ord macho.BIND_SPECIAL_DYLIB_SELF;
                };

                try setSymbol(name, flags, bw);
                try setTypePointer(bw);
                try setDylibOrdinal(ordinal, bw);

                if (current.addend != addend) {
                    addend = current.addend;
                    try setAddend(addend, bw);
                }
            }

            log.debug("{x}, {d}, {x}, {?x}, {s}", .{ offset, count, skip, addend, @tagName(state) });
            log.debug("  => {x}", .{current.offset});
            switch (state) {
                .start => {
                    if (current.offset < offset) {
                        try addAddr(@bitCast(@as(i64, @intCast(current.offset)) - @as(i64, @intCast(offset))), bw);
                        offset = offset - (offset - current.offset);
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        try addAddr(delta, bw);
                        offset += delta;
                    }
                    state = .bind_single;
                    offset += @sizeOf(u64);
                    count = 1;
                },
                .bind_single => {
                    if (current.offset == offset) {
                        try doBind(bw);
                        state = .start;
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        state = .bind_times_skip;
                        skip = @as(u64, @intCast(delta));
                        offset += skip;
                    } else unreachable;
                    i -= 1;
                },
                .bind_times_skip => {
                    if (current.offset < offset) {
                        count -= 1;
                        if (count == 1) {
                            try doBindAddAddr(skip, bw);
                        } else {
                            try doBindTimesSkip(count, skip, bw);
                        }
                        state = .start;
                        offset = offset - (@sizeOf(u64) + skip);
                        i -= 2;
                    } else if (current.offset == offset) {
                        count += 1;
                        offset += @sizeOf(u64) + skip;
                    } else {
                        try doBindTimesSkip(count, skip, bw);
                        state = .start;
                        i -= 1;
                    }
                },
            }
        }

        switch (state) {
            .start => unreachable,
            .bind_single => try doBind(bw),
            .bind_times_skip => try doBindTimesSkip(count, skip, bw),
        }
    }

    pub fn write(bind: Bind, bw: *std.io.BufferedWriter) anyerror!void {
        try bw.writeAll(bind.buffer.items);
    }
};

pub const WeakBind = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,

    pub fn deinit(bind: *WeakBind, gpa: Allocator) void {
        bind.entries.deinit(gpa);
        bind.buffer.deinit(gpa);
    }

    pub fn updateSize(bind: *WeakBind, macho_file: *MachO) !void {
        const tracy = trace(@src());
        defer tracy.end();

        const gpa = macho_file.base.comp.gpa;
        const cpu_arch = macho_file.getTarget().cpu.arch;

        var objects = try std.ArrayList(File.Index).initCapacity(gpa, macho_file.objects.items.len + 2);
        defer objects.deinit();
        objects.appendSliceAssumeCapacity(macho_file.objects.items);
        if (macho_file.getZigObject()) |obj| objects.appendAssumeCapacity(obj.index);
        if (macho_file.getInternalObject()) |obj| objects.appendAssumeCapacity(obj.index);

        for (objects.items) |index| {
            const file = macho_file.getFile(index).?;
            for (file.getAtoms()) |atom_index| {
                const atom = file.getAtom(atom_index) orelse continue;
                if (!atom.isAlive()) continue;
                if (atom.getInputSection(macho_file).isZerofill()) continue;
                const atom_addr = atom.getAddress(macho_file);
                const relocs = atom.getRelocs(macho_file);
                const seg_id = macho_file.sections.items(.segment_id)[atom.out_n_sect];
                const seg = macho_file.segments.items[seg_id];
                for (relocs) |rel| {
                    if (rel.type != .unsigned or rel.meta.length != 3 or rel.tag != .@"extern") continue;
                    const rel_offset = rel.offset - atom.off;
                    const addend = rel.addend + rel.getRelocAddend(cpu_arch);
                    const sym = rel.getTargetSymbol(atom.*, macho_file);
                    if (sym.isTlvInit(macho_file)) continue;
                    if (!sym.isLocal() and sym.flags.weak) (try bind.entries.addOne(gpa)).* = .{
                        .target = rel.getTargetSymbolRef(atom.*, macho_file),
                        .offset = atom_addr + rel_offset - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = addend,
                    };
                }
            }
        }

        if (macho_file.got_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.got.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.got.getAddress(@intCast(idx), macho_file);
                if (sym.flags.weak) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        if (macho_file.la_symbol_ptr_sect_index) |sid| {
            const sect = macho_file.sections.items(.header)[sid];
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = sect.addr + idx * @sizeOf(u64);
                if (sym.flags.weak) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        if (macho_file.tlv_ptr_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.tlv_ptr.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.tlv_ptr.getAddress(@intCast(idx), macho_file);
                if (sym.flags.weak) (try bind.entries.addOne(gpa)).* = .{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
            }
        }

        try bind.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.weak_bind_size = mem.alignForward(u32, @intCast(bind.buffer.items.len), @alignOf(u64));
    }

    fn finalize(bind: *WeakBind, gpa: Allocator, ctx: *MachO) !void {
        if (bind.entries.items.len == 0) return;

        var aw: std.io.AllocatingWriter = undefined;
        const bw = aw.fromArrayList(gpa, &bind.buffer);
        defer bind.buffer = aw.toArrayList();

        log.debug("weak bind opcodes", .{});

        std.mem.sort(Entry, bind.entries.items, ctx, Entry.lessThan);

        var start: usize = 0;
        var seg_id: ?u8 = null;
        for (bind.entries.items, 0..) |entry, i| {
            if (seg_id != null and seg_id.? == entry.segment_id) continue;
            try finalizeSegment(bind.entries.items[start..i], ctx, bw);
            seg_id = entry.segment_id;
            start = i;
        }

        try finalizeSegment(bind.entries.items[start..], ctx, bw);
        try done(bw);
    }

    fn finalizeSegment(entries: []const Entry, ctx: *MachO, bw: *std.io.BufferedWriter) anyerror!void {
        if (entries.len == 0) return;

        const seg_id = entries[0].segment_id;
        try setSegmentOffset(seg_id, 0, bw);

        var offset: u64 = 0;
        var addend: i64 = 0;
        var count: usize = 0;
        var skip: u64 = 0;
        var target: ?MachO.Ref = null;

        var state: enum {
            start,
            bind_single,
            bind_times_skip,
        } = .start;

        var i: usize = 0;
        while (i < entries.len) : (i += 1) {
            const current = entries[i];
            if (target == null or !target.?.eql(current.target)) {
                switch (state) {
                    .start => {},
                    .bind_single => try doBind(bw),
                    .bind_times_skip => try doBindTimesSkip(count, skip, bw),
                }
                state = .start;
                target = current.target;

                const sym = current.target.getSymbol(ctx).?;
                const name = sym.getName(ctx);
                const flags: u8 = 0; // TODO NON_WEAK_DEFINITION

                try setSymbol(name, flags, bw);
                try setTypePointer(bw);

                if (current.addend != addend) {
                    addend = current.addend;
                    try setAddend(addend, bw);
                }
            }

            log.debug("{x}, {d}, {x}, {?x}, {s}", .{ offset, count, skip, addend, @tagName(state) });
            log.debug("  => {x}", .{current.offset});
            switch (state) {
                .start => {
                    if (current.offset < offset) {
                        try addAddr(@as(u64, @bitCast(@as(i64, @intCast(current.offset)) - @as(i64, @intCast(offset)))), bw);
                        offset = offset - (offset - current.offset);
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        try addAddr(delta, bw);
                        offset += delta;
                    }
                    state = .bind_single;
                    offset += @sizeOf(u64);
                    count = 1;
                },
                .bind_single => {
                    if (current.offset == offset) {
                        try doBind(bw);
                        state = .start;
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        state = .bind_times_skip;
                        skip = @intCast(delta);
                        offset += skip;
                    } else unreachable;
                    i -= 1;
                },
                .bind_times_skip => {
                    if (current.offset < offset) {
                        count -= 1;
                        if (count == 1) {
                            try doBindAddAddr(skip, bw);
                        } else {
                            try doBindTimesSkip(count, skip, bw);
                        }
                        state = .start;
                        offset = offset - (@sizeOf(u64) + skip);
                        i -= 2;
                    } else if (current.offset == offset) {
                        count += 1;
                        offset += @sizeOf(u64) + skip;
                    } else {
                        try doBindTimesSkip(count, skip, bw);
                        state = .start;
                        i -= 1;
                    }
                },
            }
        }

        switch (state) {
            .start => unreachable,
            .bind_single => try doBind(bw),
            .bind_times_skip => try doBindTimesSkip(count, skip, bw),
        }
    }

    pub fn write(bind: WeakBind, bw: *std.io.BufferedWriter) anyerror!void {
        try bw.writeAll(bind.buffer.items);
    }
};

pub const LazyBind = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    offsets: std.ArrayListUnmanaged(u32) = .empty,

    pub fn deinit(bind: *LazyBind, gpa: Allocator) void {
        bind.entries.deinit(gpa);
        bind.buffer.deinit(gpa);
        bind.offsets.deinit(gpa);
    }

    pub fn updateSize(bind: *LazyBind, macho_file: *MachO) !void {
        const tracy = trace(@src());
        defer tracy.end();

        const gpa = macho_file.base.comp.gpa;

        const sid = macho_file.la_symbol_ptr_sect_index.?;
        const sect = macho_file.sections.items(.header)[sid];
        const seg_id = macho_file.sections.items(.segment_id)[sid];
        const seg = macho_file.segments.items[seg_id];

        for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const addr = sect.addr + idx * @sizeOf(u64);
            if ((sym.flags.import and !sym.flags.weak) or (sym.flags.interposable and !sym.flags.weak)) (try bind.entries.addOne(gpa)).* = .{
                .target = ref,
                .offset = addr - seg.vmaddr,
                .segment_id = seg_id,
                .addend = 0,
            };
        }

        try bind.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.lazy_bind_size = mem.alignForward(u32, @intCast(bind.buffer.items.len), @alignOf(u64));
    }

    fn finalize(bind: *LazyBind, gpa: Allocator, ctx: *MachO) !void {
        try bind.offsets.ensureTotalCapacityPrecise(gpa, bind.entries.items.len);

        var aw: std.io.AllocatingWriter = undefined;
        const bw = aw.fromArrayList(gpa, &bind.buffer);
        defer bind.buffer = aw.toArrayList();

        log.debug("lazy bind opcodes", .{});

        var addend: i64 = 0;

        for (bind.entries.items) |entry| {
            bind.offsets.appendAssumeCapacity(@intCast(bind.buffer.items.len));

            const sym = entry.target.getSymbol(ctx).?;
            const name = sym.getName(ctx);
            const flags: u4 = if (sym.weakRef(ctx)) macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT else 0;
            const ordinal: i16 = ord: {
                if (sym.flags.interposable) break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                if (sym.flags.import) {
                    // TODO: if (ctx.options.namespace == .flat) break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                    if (sym.getDylibOrdinal(ctx)) |ord| break :ord @bitCast(ord);
                }
                if (ctx.undefined_treatment == .dynamic_lookup)
                    break :ord macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP;
                break :ord macho.BIND_SPECIAL_DYLIB_SELF;
            };

            try setSegmentOffset(entry.segment_id, entry.offset, bw);
            try setSymbol(name, flags, bw);
            try setDylibOrdinal(ordinal, bw);

            if (entry.addend != addend) {
                try setAddend(entry.addend, bw);
                addend = entry.addend;
            }

            try doBind(bw);
            try done(bw);
        }
    }

    pub fn write(bind: LazyBind, bw: *std.io.BufferedWriter) anyerror!void {
        try bw.writeAll(bind.buffer.items);
    }
};

fn setSegmentOffset(segment_id: u4, offset: u64, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> set segment: {d} and offset: {x}", .{ segment_id, offset });
    try bw.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | segment_id);
    try bw.writeLeb128(offset);
}

fn setSymbol(name: []const u8, flags: u4, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> set symbol: {s} with flags: {x}", .{ name, flags });
    try bw.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM | flags);
    try bw.writeAll(name);
    try bw.writeByte(0);
}

fn setTypePointer(bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> set type: {d}", .{macho.BIND_TYPE_POINTER});
    try bw.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @as(u4, @intCast(macho.BIND_TYPE_POINTER)));
}

fn setDylibOrdinal(ordinal: i16, bw: *std.io.BufferedWriter) anyerror!void {
    switch (ordinal) {
        else => unreachable, // Invalid dylib special binding
        macho.BIND_SPECIAL_DYLIB_SELF,
        macho.BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE,
        macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP,
        => {
            log.debug(">>> set dylib special: {d}", .{ordinal});
            try bw.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @as(u4, @bitCast(@as(i4, @intCast(ordinal)))));
        },
        1...std.math.maxInt(i16) => {
            log.debug(">>> set dylib ordinal: {d}", .{ordinal});
            if (std.math.cast(u4, ordinal)) |imm| {
                try bw.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | imm);
            } else {
                try bw.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
                try bw.writeUleb128(ordinal);
            }
        },
    }
}

fn setAddend(addend: i64, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> set addend: {x}", .{addend});
    try bw.writeByte(macho.BIND_OPCODE_SET_ADDEND_SLEB);
    try bw.writeLeb128(addend);
}

fn doBind(bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> bind", .{});
    try bw.writeByte(macho.BIND_OPCODE_DO_BIND);
}

fn doBindAddAddr(addr: u64, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> bind with add: {x}", .{addr});
    if (std.math.divExact(u64, addr, @sizeOf(u64))) |scaled| {
        if (std.math.cast(u4, scaled)) |imm_scaled| return bw.writeByte(
            macho.BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED | imm_scaled,
        );
    } else |_| {}
    try bw.writeByte(macho.BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB);
    try bw.writeLeb128(addr);
}

fn doBindTimesSkip(count: usize, skip: u64, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> bind with count: {d} and skip: {x}", .{ count, skip });
    try bw.writeByte(macho.BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB);
    try bw.writeLeb128(count);
    try bw.writeLeb128(skip);
}

fn addAddr(addr: u64, bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> add: {x}", .{addr});
    try bw.writeByte(macho.BIND_OPCODE_ADD_ADDR_ULEB);
    try bw.writeLeb128(addr);
}

fn done(bw: *std.io.BufferedWriter) anyerror!void {
    log.debug(">>> done", .{});
    try bw.writeByte(macho.BIND_OPCODE_DONE);
}

const assert = std.debug.assert;
const leb = std.leb;
const log = std.log.scoped(.link_dyld_info);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const trace = @import("../../../tracy.zig").trace;
const std = @import("std");

const Allocator = mem.Allocator;
const File = @import("../file.zig").File;
const MachO = @import("../../MachO.zig");
const Symbol = @import("../Symbol.zig");
