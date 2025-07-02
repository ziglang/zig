pub const Entry = struct {
    target: MachO.Ref,
    offset: u64,
    segment_id: u8,
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

    const Self = @This();

    pub fn deinit(self: *Self, gpa: Allocator) void {
        self.entries.deinit(gpa);
        self.buffer.deinit(gpa);
    }

    pub fn updateSize(self: *Self, macho_file: *MachO) !void {
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
                    const entry = Entry{
                        .target = rel.getTargetSymbolRef(atom.*, macho_file),
                        .offset = atom_addr + rel_offset - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = addend,
                    };
                    if (sym.flags.import or (!(sym.flags.@"export" and sym.flags.weak) and sym.flags.interposable)) {
                        try self.entries.append(gpa, entry);
                    }
                }
            }
        }

        if (macho_file.got_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.got.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.got.getAddress(@intCast(idx), macho_file);
                const entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.import or (sym.flags.@"export" and sym.flags.interposable and !sym.flags.weak)) {
                    try self.entries.append(gpa, entry);
                }
            }
        }

        if (macho_file.la_symbol_ptr_sect_index) |sid| {
            const sect = macho_file.sections.items(.header)[sid];
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = sect.addr + idx * @sizeOf(u64);
                const bind_entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.import and sym.flags.weak) {
                    try self.entries.append(gpa, bind_entry);
                }
            }
        }

        if (macho_file.tlv_ptr_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.tlv_ptr.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.tlv_ptr.getAddress(@intCast(idx), macho_file);
                const entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.import or (sym.flags.@"export" and sym.flags.interposable and !sym.flags.weak)) {
                    try self.entries.append(gpa, entry);
                }
            }
        }

        try self.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.bind_size = mem.alignForward(u32, @intCast(self.buffer.items.len), @alignOf(u64));
    }

    fn finalize(self: *Self, gpa: Allocator, ctx: *MachO) !void {
        if (self.entries.items.len == 0) return;

        const writer = self.buffer.writer(gpa);

        log.debug("bind opcodes", .{});

        std.mem.sort(Entry, self.entries.items, ctx, Entry.lessThan);

        var start: usize = 0;
        var seg_id: ?u8 = null;
        for (self.entries.items, 0..) |entry, i| {
            if (seg_id != null and seg_id.? == entry.segment_id) continue;
            try finalizeSegment(self.entries.items[start..i], ctx, writer);
            seg_id = entry.segment_id;
            start = i;
        }

        try finalizeSegment(self.entries.items[start..], ctx, writer);
        try done(writer);
    }

    fn finalizeSegment(entries: []const Entry, ctx: *MachO, writer: anytype) !void {
        if (entries.len == 0) return;

        const seg_id = entries[0].segment_id;
        try setSegmentOffset(seg_id, 0, writer);

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
                    .bind_single => try doBind(writer),
                    .bind_times_skip => try doBindTimesSkip(count, skip, writer),
                }
                state = .start;
                target = current.target;

                const sym = current.target.getSymbol(ctx).?;
                const name = sym.getName(ctx);
                const flags: u8 = if (sym.weakRef(ctx)) macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT else 0;
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

                try setSymbol(name, flags, writer);
                try setTypePointer(writer);
                try setDylibOrdinal(ordinal, writer);

                if (current.addend != addend) {
                    addend = current.addend;
                    try setAddend(addend, writer);
                }
            }

            log.debug("{x}, {d}, {x}, {?x}, {s}", .{ offset, count, skip, addend, @tagName(state) });
            log.debug("  => {x}", .{current.offset});
            switch (state) {
                .start => {
                    if (current.offset < offset) {
                        try addAddr(@bitCast(@as(i64, @intCast(current.offset)) - @as(i64, @intCast(offset))), writer);
                        offset = offset - (offset - current.offset);
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        try addAddr(delta, writer);
                        offset += delta;
                    }
                    state = .bind_single;
                    offset += @sizeOf(u64);
                    count = 1;
                },
                .bind_single => {
                    if (current.offset == offset) {
                        try doBind(writer);
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
                            try doBindAddAddr(skip, writer);
                        } else {
                            try doBindTimesSkip(count, skip, writer);
                        }
                        state = .start;
                        offset = offset - (@sizeOf(u64) + skip);
                        i -= 2;
                    } else if (current.offset == offset) {
                        count += 1;
                        offset += @sizeOf(u64) + skip;
                    } else {
                        try doBindTimesSkip(count, skip, writer);
                        state = .start;
                        i -= 1;
                    }
                },
            }
        }

        switch (state) {
            .start => unreachable,
            .bind_single => try doBind(writer),
            .bind_times_skip => try doBindTimesSkip(count, skip, writer),
        }
    }

    pub fn write(self: Self, writer: anytype) !void {
        try writer.writeAll(self.buffer.items);
    }
};

pub const WeakBind = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,

    const Self = @This();

    pub fn deinit(self: *Self, gpa: Allocator) void {
        self.entries.deinit(gpa);
        self.buffer.deinit(gpa);
    }

    pub fn updateSize(self: *Self, macho_file: *MachO) !void {
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
                    const entry = Entry{
                        .target = rel.getTargetSymbolRef(atom.*, macho_file),
                        .offset = atom_addr + rel_offset - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = addend,
                    };
                    if (!sym.isLocal() and sym.flags.weak) {
                        try self.entries.append(gpa, entry);
                    }
                }
            }
        }

        if (macho_file.got_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];
            for (macho_file.got.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.got.getAddress(@intCast(idx), macho_file);
                const entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.weak) {
                    try self.entries.append(gpa, entry);
                }
            }
        }

        if (macho_file.la_symbol_ptr_sect_index) |sid| {
            const sect = macho_file.sections.items(.header)[sid];
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.stubs.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = sect.addr + idx * @sizeOf(u64);
                const bind_entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.weak) {
                    try self.entries.append(gpa, bind_entry);
                }
            }
        }

        if (macho_file.tlv_ptr_sect_index) |sid| {
            const seg_id = macho_file.sections.items(.segment_id)[sid];
            const seg = macho_file.segments.items[seg_id];

            for (macho_file.tlv_ptr.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(macho_file).?;
                const addr = macho_file.tlv_ptr.getAddress(@intCast(idx), macho_file);
                const entry = Entry{
                    .target = ref,
                    .offset = addr - seg.vmaddr,
                    .segment_id = seg_id,
                    .addend = 0,
                };
                if (sym.flags.weak) {
                    try self.entries.append(gpa, entry);
                }
            }
        }

        try self.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.weak_bind_size = mem.alignForward(u32, @intCast(self.buffer.items.len), @alignOf(u64));
    }

    fn finalize(self: *Self, gpa: Allocator, ctx: *MachO) !void {
        if (self.entries.items.len == 0) return;

        const writer = self.buffer.writer(gpa);

        log.debug("weak bind opcodes", .{});

        std.mem.sort(Entry, self.entries.items, ctx, Entry.lessThan);

        var start: usize = 0;
        var seg_id: ?u8 = null;
        for (self.entries.items, 0..) |entry, i| {
            if (seg_id != null and seg_id.? == entry.segment_id) continue;
            try finalizeSegment(self.entries.items[start..i], ctx, writer);
            seg_id = entry.segment_id;
            start = i;
        }

        try finalizeSegment(self.entries.items[start..], ctx, writer);
        try done(writer);
    }

    fn finalizeSegment(entries: []const Entry, ctx: *MachO, writer: anytype) !void {
        if (entries.len == 0) return;

        const seg_id = entries[0].segment_id;
        try setSegmentOffset(seg_id, 0, writer);

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
                    .bind_single => try doBind(writer),
                    .bind_times_skip => try doBindTimesSkip(count, skip, writer),
                }
                state = .start;
                target = current.target;

                const sym = current.target.getSymbol(ctx).?;
                const name = sym.getName(ctx);
                const flags: u8 = 0; // TODO NON_WEAK_DEFINITION

                try setSymbol(name, flags, writer);
                try setTypePointer(writer);

                if (current.addend != addend) {
                    addend = current.addend;
                    try setAddend(addend, writer);
                }
            }

            log.debug("{x}, {d}, {x}, {?x}, {s}", .{ offset, count, skip, addend, @tagName(state) });
            log.debug("  => {x}", .{current.offset});
            switch (state) {
                .start => {
                    if (current.offset < offset) {
                        try addAddr(@as(u64, @bitCast(@as(i64, @intCast(current.offset)) - @as(i64, @intCast(offset)))), writer);
                        offset = offset - (offset - current.offset);
                    } else if (current.offset > offset) {
                        const delta = current.offset - offset;
                        try addAddr(delta, writer);
                        offset += delta;
                    }
                    state = .bind_single;
                    offset += @sizeOf(u64);
                    count = 1;
                },
                .bind_single => {
                    if (current.offset == offset) {
                        try doBind(writer);
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
                            try doBindAddAddr(skip, writer);
                        } else {
                            try doBindTimesSkip(count, skip, writer);
                        }
                        state = .start;
                        offset = offset - (@sizeOf(u64) + skip);
                        i -= 2;
                    } else if (current.offset == offset) {
                        count += 1;
                        offset += @sizeOf(u64) + skip;
                    } else {
                        try doBindTimesSkip(count, skip, writer);
                        state = .start;
                        i -= 1;
                    }
                },
            }
        }

        switch (state) {
            .start => unreachable,
            .bind_single => try doBind(writer),
            .bind_times_skip => try doBindTimesSkip(count, skip, writer),
        }
    }

    pub fn write(self: Self, writer: anytype) !void {
        try writer.writeAll(self.buffer.items);
    }
};

pub const LazyBind = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    offsets: std.ArrayListUnmanaged(u32) = .empty,

    const Self = @This();

    pub fn deinit(self: *Self, gpa: Allocator) void {
        self.entries.deinit(gpa);
        self.buffer.deinit(gpa);
        self.offsets.deinit(gpa);
    }

    pub fn updateSize(self: *Self, macho_file: *MachO) !void {
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
            const bind_entry = Entry{
                .target = ref,
                .offset = addr - seg.vmaddr,
                .segment_id = seg_id,
                .addend = 0,
            };
            if ((sym.flags.import and !sym.flags.weak) or (sym.flags.interposable and !sym.flags.weak)) {
                try self.entries.append(gpa, bind_entry);
            }
        }

        try self.finalize(gpa, macho_file);
        macho_file.dyld_info_cmd.lazy_bind_size = mem.alignForward(u32, @intCast(self.buffer.items.len), @alignOf(u64));
    }

    fn finalize(self: *Self, gpa: Allocator, ctx: *MachO) !void {
        try self.offsets.ensureTotalCapacityPrecise(gpa, self.entries.items.len);

        const writer = self.buffer.writer(gpa);

        log.debug("lazy bind opcodes", .{});

        var addend: i64 = 0;

        for (self.entries.items) |entry| {
            self.offsets.appendAssumeCapacity(@intCast(self.buffer.items.len));

            const sym = entry.target.getSymbol(ctx).?;
            const name = sym.getName(ctx);
            const flags: u8 = if (sym.weakRef(ctx)) macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT else 0;
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

            try setSegmentOffset(entry.segment_id, entry.offset, writer);
            try setSymbol(name, flags, writer);
            try setDylibOrdinal(ordinal, writer);

            if (entry.addend != addend) {
                try setAddend(entry.addend, writer);
                addend = entry.addend;
            }

            try doBind(writer);
            try done(writer);
        }
    }

    pub fn write(self: Self, writer: anytype) !void {
        try writer.writeAll(self.buffer.items);
    }
};

fn setSegmentOffset(segment_id: u8, offset: u64, writer: anytype) !void {
    log.debug(">>> set segment: {d} and offset: {x}", .{ segment_id, offset });
    try writer.writeByte(macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | @as(u4, @truncate(segment_id)));
    try std.leb.writeUleb128(writer, offset);
}

fn setSymbol(name: []const u8, flags: u8, writer: anytype) !void {
    log.debug(">>> set symbol: {s} with flags: {x}", .{ name, flags });
    try writer.writeByte(macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM | @as(u4, @truncate(flags)));
    try writer.writeAll(name);
    try writer.writeByte(0);
}

fn setTypePointer(writer: anytype) !void {
    log.debug(">>> set type: {d}", .{macho.BIND_TYPE_POINTER});
    try writer.writeByte(macho.BIND_OPCODE_SET_TYPE_IMM | @as(u4, @truncate(macho.BIND_TYPE_POINTER)));
}

fn setDylibOrdinal(ordinal: i16, writer: anytype) !void {
    if (ordinal <= 0) {
        switch (ordinal) {
            macho.BIND_SPECIAL_DYLIB_SELF,
            macho.BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE,
            macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP,
            => {},
            else => unreachable, // Invalid dylib special binding
        }
        log.debug(">>> set dylib special: {d}", .{ordinal});
        const cast = @as(u16, @bitCast(ordinal));
        try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM | @as(u4, @truncate(cast)));
    } else {
        const cast = @as(u16, @bitCast(ordinal));
        log.debug(">>> set dylib ordinal: {d}", .{ordinal});
        if (cast <= 0xf) {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | @as(u4, @truncate(cast)));
        } else {
            try writer.writeByte(macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB);
            try std.leb.writeUleb128(writer, cast);
        }
    }
}

fn setAddend(addend: i64, writer: anytype) !void {
    log.debug(">>> set addend: {x}", .{addend});
    try writer.writeByte(macho.BIND_OPCODE_SET_ADDEND_SLEB);
    try std.leb.writeIleb128(writer, addend);
}

fn doBind(writer: anytype) !void {
    log.debug(">>> bind", .{});
    try writer.writeByte(macho.BIND_OPCODE_DO_BIND);
}

fn doBindAddAddr(addr: u64, writer: anytype) !void {
    log.debug(">>> bind with add: {x}", .{addr});
    if (std.mem.isAlignedGeneric(u64, addr, @sizeOf(u64))) {
        const imm = @divExact(addr, @sizeOf(u64));
        if (imm <= 0xf) {
            try writer.writeByte(
                macho.BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED | @as(u4, @truncate(imm)),
            );
            return;
        }
    }
    try writer.writeByte(macho.BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB);
    try std.leb.writeUleb128(writer, addr);
}

fn doBindTimesSkip(count: usize, skip: u64, writer: anytype) !void {
    log.debug(">>> bind with count: {d} and skip: {x}", .{ count, skip });
    try writer.writeByte(macho.BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB);
    try std.leb.writeUleb128(writer, count);
    try std.leb.writeUleb128(writer, skip);
}

fn addAddr(addr: u64, writer: anytype) !void {
    log.debug(">>> add: {x}", .{addr});
    try writer.writeByte(macho.BIND_OPCODE_ADD_ADDR_ULEB);
    try std.leb.writeUleb128(writer, addr);
}

fn done(writer: anytype) !void {
    log.debug(">>> done", .{});
    try writer.writeByte(macho.BIND_OPCODE_DONE);
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
