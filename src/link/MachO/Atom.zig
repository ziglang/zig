/// Address allocated for this Atom.
value: u64 = 0,

/// Name of this Atom.
name: u32 = 0,

/// Index into linker's input file table.
file: File.Index = 0,

/// Size of this atom
size: u64 = 0,

/// Alignment of this atom as a power of two.
alignment: u32 = 0,

/// Index of the input section.
n_sect: u32 = 0,

/// Index of the output section.
out_n_sect: u8 = 0,

/// Offset within the parent section pointed to by n_sect.
/// off + size <= parent section size.
off: u64 = 0,

/// Relocations of this atom.
relocs: Loc = .{},

/// Index of this atom in the linker's atoms table.
atom_index: Index = 0,

/// Index of the thunk for this atom.
thunk_index: Thunk.Index = 0,

/// Unwind records associated with this atom.
unwind_records: Loc = .{},

flags: Flags = .{},

pub fn getName(self: Atom, macho_file: *MachO) [:0]const u8 {
    return macho_file.string_intern.getAssumeExists(self.name);
}

pub fn getFile(self: Atom, macho_file: *MachO) File {
    return macho_file.getFile(self.file).?;
}

pub fn getInputSection(self: Atom, macho_file: *MachO) macho.section_64 {
    return switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        inline else => |x| x.sections.items(.header)[self.n_sect],
    };
}

pub fn getInputAddress(self: Atom, macho_file: *MachO) u64 {
    return self.getInputSection(macho_file).addr + self.off;
}

pub fn getPriority(self: Atom, macho_file: *MachO) u64 {
    const file = self.getFile(macho_file);
    return (@as(u64, @intCast(file.getIndex())) << 32) | @as(u64, @intCast(self.n_sect));
}

pub fn getCode(self: Atom, macho_file: *MachO) []const u8 {
    const code = switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        inline else => |x| x.getSectionData(self.n_sect),
    };
    return code[self.off..][0..self.size];
}

pub fn getRelocs(self: Atom, macho_file: *MachO) []const Relocation {
    const relocs = switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        inline else => |x| x.sections.items(.relocs)[self.n_sect],
    };
    return relocs.items[self.relocs.pos..][0..self.relocs.len];
}

pub fn getUnwindRecords(self: Atom, macho_file: *MachO) []const UnwindInfo.Record.Index {
    return switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        .internal => &[0]UnwindInfo.Record.Index{},
        .object => |x| x.unwind_records.items[self.unwind_records.pos..][0..self.unwind_records.len],
    };
}

pub fn markUnwindRecordsDead(self: Atom, macho_file: *MachO) void {
    for (self.getUnwindRecords(macho_file)) |cu_index| {
        const cu = macho_file.getUnwindRecord(cu_index);
        cu.alive = false;

        if (cu.getFdePtr(macho_file)) |fde| {
            fde.alive = false;
        }
    }
}

pub fn getThunk(self: Atom, macho_file: *MachO) *Thunk {
    return macho_file.getThunk(self.thunk_index);
}

pub fn initOutputSection(sect: macho.section_64, macho_file: *MachO) !u8 {
    const segname, const sectname, const flags = blk: {
        if (sect.isCode()) break :blk .{
            "__TEXT",
            "__text",
            macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        };

        switch (sect.type()) {
            macho.S_4BYTE_LITERALS,
            macho.S_8BYTE_LITERALS,
            macho.S_16BYTE_LITERALS,
            => break :blk .{ "__TEXT", "__const", macho.S_REGULAR },

            macho.S_CSTRING_LITERALS => {
                if (mem.startsWith(u8, sect.sectName(), "__objc")) break :blk .{
                    sect.segName(), sect.sectName(), macho.S_REGULAR,
                };
                break :blk .{ "__TEXT", "__cstring", macho.S_CSTRING_LITERALS };
            },

            macho.S_MOD_INIT_FUNC_POINTERS,
            macho.S_MOD_TERM_FUNC_POINTERS,
            => break :blk .{ "__DATA_CONST", sect.sectName(), sect.flags },

            macho.S_LITERAL_POINTERS,
            macho.S_ZEROFILL,
            macho.S_GB_ZEROFILL,
            macho.S_THREAD_LOCAL_VARIABLES,
            macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
            macho.S_THREAD_LOCAL_REGULAR,
            macho.S_THREAD_LOCAL_ZEROFILL,
            => break :blk .{ sect.segName(), sect.sectName(), sect.flags },

            macho.S_COALESCED => break :blk .{
                sect.segName(),
                sect.sectName(),
                macho.S_REGULAR,
            },

            macho.S_REGULAR => {
                const segname = sect.segName();
                const sectname = sect.sectName();
                if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__const") or
                        mem.eql(u8, sectname, "__cfstring") or
                        mem.eql(u8, sectname, "__objc_classlist") or
                        mem.eql(u8, sectname, "__objc_imageinfo")) break :blk .{
                        "__DATA_CONST",
                        sectname,
                        macho.S_REGULAR,
                    };
                }
                break :blk .{ segname, sectname, sect.flags };
            },

            else => break :blk .{ sect.segName(), sect.sectName(), sect.flags },
        }
    };
    const osec = macho_file.getSectionByName(segname, sectname) orelse try macho_file.addSection(
        segname,
        sectname,
        .{ .flags = flags },
    );
    if (mem.eql(u8, segname, "__DATA") and mem.eql(u8, sectname, "__data")) {
        macho_file.data_sect_index = osec;
    }
    return osec;
}

pub fn scanRelocs(self: Atom, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const object = self.getFile(macho_file).object;
    const relocs = self.getRelocs(macho_file);

    for (relocs) |rel| {
        if (try self.reportUndefSymbol(rel, macho_file)) continue;

        switch (rel.type) {
            .branch => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (symbol.flags.import or (symbol.flags.@"export" and (symbol.flags.weak or symbol.flags.interposable))) {
                    symbol.flags.stubs = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                } else if (mem.startsWith(u8, symbol.getName(macho_file), "_objc_msgSend$")) {
                    symbol.flags.objc_stubs = true;
                }
            },

            .got_load,
            .got_load_page,
            .got_load_pageoff,
            => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (symbol.flags.import or
                    (symbol.flags.@"export" and (symbol.flags.weak or symbol.flags.interposable)) or
                    macho_file.options.cpu_arch.? == .aarch64) // TODO relax on arm64
                {
                    symbol.flags.got = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                }
            },

            .got => {
                rel.getTargetSymbol(macho_file).flags.got = true;
            },

            .tlv,
            .tlvp_page,
            .tlvp_pageoff,
            => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (!symbol.flags.tlv) {
                    macho_file.base.fatal(
                        "{}: {s}: illegal thread-local variable reference to regular symbol {s}",
                        .{ object.fmtPath(), self.getName(macho_file), symbol.getName(macho_file) },
                    );
                }
                if (symbol.flags.import or (symbol.flags.@"export" and (symbol.flags.weak or symbol.flags.interposable))) {
                    symbol.flags.tlv_ptr = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                }
            },

            .unsigned => {
                if (rel.meta.length == 3) { // TODO this really should check if this is pointer width
                    if (rel.tag == .@"extern") {
                        const symbol = rel.getTargetSymbol(macho_file);
                        if (symbol.isTlvInit(macho_file)) {
                            macho_file.has_tlv = true;
                            continue;
                        }
                        if (symbol.flags.import) {
                            object.num_bind_relocs += 1;
                            if (symbol.flags.weak) {
                                object.num_weak_bind_relocs += 1;
                                macho_file.binds_to_weak = true;
                            }
                            continue;
                        }
                        if (symbol.flags.@"export") {
                            if (symbol.flags.weak) {
                                object.num_weak_bind_relocs += 1;
                                macho_file.binds_to_weak = true;
                            } else if (symbol.flags.interposable) {
                                object.num_bind_relocs += 1;
                            }
                        }
                    }
                    object.num_rebase_relocs += 1;
                }
            },

            else => {},
        }
    }
}

fn reportUndefSymbol(self: Atom, rel: Relocation, macho_file: *MachO) !bool {
    if (rel.tag == .local) return false;

    const sym = rel.getTargetSymbol(macho_file);
    if (sym.getFile(macho_file) == null) {
        const gpa = macho_file.base.allocator;
        const gop = try macho_file.undefs.getOrPut(gpa, rel.target);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(gpa, self.atom_index);
        return true;
    }

    return false;
}

pub fn resolveRelocs(self: Atom, macho_file: *MachO, buffer: []u8) !void {
    const tracy = trace(@src());
    defer tracy.end();

    assert(!self.getInputSection(macho_file).isZerofill());
    const relocs = self.getRelocs(macho_file);
    const file = self.getFile(macho_file);
    const name = self.getName(macho_file);
    @memcpy(buffer, self.getCode(macho_file));

    relocs_log.debug("{x}: {s}", .{ self.value, name });

    var stream = std.io.fixedBufferStream(buffer);

    var i: usize = 0;
    while (i < relocs.len) : (i += 1) {
        const rel = relocs[i];
        const rel_offset = rel.offset - self.off;
        const subtractor = if (rel.meta.has_subtractor) relocs[i - 1] else null;

        if (rel.tag == .@"extern") {
            if (rel.getTargetSymbol(macho_file).getFile(macho_file) == null) continue;
        }

        try stream.seekTo(rel_offset);
        self.resolveRelocInner(rel, subtractor, buffer, macho_file, stream.writer()) catch |err| {
            switch (err) {
                error.RelaxFail => macho_file.base.fatal(
                    "{}: {s}: 0x{x}: failed to relax relocation: in {s}",
                    .{ file.fmtPath(), name, rel.offset, @tagName(rel.type) },
                ),
                else => |e| return e,
            }
            return error.ResolveFailed;
        };
    }
}

const ResolveError = error{
    RelaxFail,
    NoSpaceLeft,
    DivisionByZero,
    UnexpectedRemainder,
    Overflow,
};

fn resolveRelocInner(
    self: Atom,
    rel: Relocation,
    subtractor: ?Relocation,
    code: []u8,
    macho_file: *MachO,
    writer: anytype,
) ResolveError!void {
    const cpu_arch = macho_file.options.cpu_arch.?;
    const rel_offset = rel.offset - self.off;
    const seg_id = macho_file.sections.items(.segment_id)[self.out_n_sect];
    const seg = macho_file.segments.items[seg_id];
    const P = @as(i64, @intCast(self.value)) + @as(i64, @intCast(rel_offset));
    const A = rel.addend + rel.getRelocAddend(cpu_arch);
    const S: i64 = @intCast(rel.getTargetAddress(macho_file));
    const G: i64 = @intCast(rel.getGotTargetAddress(macho_file));
    const TLS = @as(i64, @intCast(macho_file.getTlsAddress()));
    const SUB = if (subtractor) |sub| @as(i64, @intCast(sub.getTargetAddress(macho_file))) else 0;

    switch (rel.tag) {
        .local => relocs_log.debug("  {x}<+{d}>: {s}: [=> {x}] atom({d})", .{
            P,
            rel_offset,
            @tagName(rel.type),
            S + A - SUB,
            rel.getTargetAtom(macho_file).atom_index,
        }),
        .@"extern" => relocs_log.debug("  {x}<+{d}>: {s}: [=> {x}] G({x}) ({s})", .{
            P,
            rel_offset,
            @tagName(rel.type),
            S + A - SUB,
            G + A,
            rel.getTargetSymbol(macho_file).getName(macho_file),
        }),
    }

    switch (rel.type) {
        .subtractor => {},

        .unsigned => {
            assert(!rel.meta.pcrel);
            if (rel.meta.length == 3) {
                if (rel.tag == .@"extern") {
                    const sym = rel.getTargetSymbol(macho_file);
                    if (sym.isTlvInit(macho_file)) {
                        try writer.writeInt(u64, @intCast(S - TLS), .little);
                        return;
                    }
                    const entry = bind.Entry{
                        .target = rel.target,
                        .offset = @as(u64, @intCast(P)) - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = A,
                    };
                    if (sym.flags.import) {
                        macho_file.bind.entries.appendAssumeCapacity(entry);
                        if (sym.flags.weak) {
                            macho_file.weak_bind.entries.appendAssumeCapacity(entry);
                        }
                        return;
                    }
                    if (sym.flags.@"export") {
                        if (sym.flags.weak) {
                            macho_file.weak_bind.entries.appendAssumeCapacity(entry);
                        } else if (sym.flags.interposable) {
                            macho_file.bind.entries.appendAssumeCapacity(entry);
                        }
                    }
                }
                macho_file.rebase.entries.appendAssumeCapacity(.{
                    .offset = @as(u64, @intCast(P)) - seg.vmaddr,
                    .segment_id = seg_id,
                });
                try writer.writeInt(u64, @bitCast(S + A - SUB), .little);
            } else if (rel.meta.length == 2) {
                try writer.writeInt(u32, @bitCast(@as(i32, @truncate(S + A - SUB))), .little);
            } else unreachable;
        },

        .got => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            try writer.writeInt(i32, @intCast(G + A - P), .little);
        },

        .branch => {
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            assert(rel.tag == .@"extern");

            switch (cpu_arch) {
                .x86_64 => try writer.writeInt(i32, @intCast(S + A - P), .little),
                .aarch64 => {
                    const disp: i28 = math.cast(i28, S + A - P) orelse blk: {
                        const thunk = self.getThunk(macho_file);
                        const S_: i64 = @intCast(thunk.getAddress(rel.target));
                        break :blk math.cast(i28, S_ + A - P) orelse return error.Overflow;
                    };
                    var inst = aarch64.Instruction{
                        .unconditional_branch_immediate = mem.bytesToValue(std.meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.unconditional_branch_immediate,
                        ), code[rel_offset..][0..4]),
                    };
                    inst.unconditional_branch_immediate.imm26 = @as(u26, @truncate(@as(u28, @bitCast(disp >> 2))));
                    try writer.writeInt(u32, inst.toU32(), .little);
                },
                else => unreachable,
            }
        },

        .got_load => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            if (rel.getTargetSymbol(macho_file).flags.got) {
                try writer.writeInt(i32, @intCast(G + A - P), .little);
            } else {
                try relaxGotLoad(code[rel_offset - 3 ..]);
                try writer.writeInt(i32, @intCast(S + A - P), .little);
            }
        },

        .tlv => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            const sym = rel.getTargetSymbol(macho_file);
            if (sym.flags.tlv_ptr) {
                const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                try writer.writeInt(i32, @intCast(S_ + A - P), .little);
            } else {
                try relaxTlv(code[rel_offset - 3 ..]);
                try writer.writeInt(i32, @intCast(S + A - P), .little);
            }
        },

        .signed, .signed1, .signed2, .signed4 => {
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            try writer.writeInt(i32, @intCast(S + A - P), .little);
        },

        .page,
        .got_load_page,
        .tlvp_page,
        => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            const sym = rel.getTargetSymbol(macho_file);
            const source = math.cast(u64, P) orelse return error.Overflow;
            const target = target: {
                const target = switch (rel.type) {
                    .page => S + A,
                    .got_load_page => G + A,
                    .tlvp_page => if (sym.flags.tlv_ptr) blk: {
                        const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                        break :blk S_ + A;
                    } else S + A,
                    else => unreachable,
                };
                break :target math.cast(u64, target) orelse return error.Overflow;
            };
            const pages = @as(u21, @bitCast(try Relocation.calcNumberOfPages(source, target)));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(std.meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), code[rel_offset..][0..4]),
            };
            inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
            inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
            try writer.writeInt(u32, inst.toU32(), .little);
        },

        .pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);
            const target = math.cast(u64, S + A) orelse return error.Overflow;
            const inst_code = code[rel_offset..][0..4];
            if (Relocation.isArithmeticOp(inst_code)) {
                const off = try Relocation.calcPageOffset(target, .arithmetic);
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), inst_code),
                };
                inst.add_subtract_immediate.imm12 = off;
                try writer.writeInt(u32, inst.toU32(), .little);
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), inst_code),
                };
                const off = try Relocation.calcPageOffset(target, switch (inst.load_store_register.size) {
                    0 => if (inst.load_store_register.v == 1)
                        Relocation.PageOffsetInstKind.load_store_128
                    else
                        Relocation.PageOffsetInstKind.load_store_8,
                    1 => .load_store_16,
                    2 => .load_store_32,
                    3 => .load_store_64,
                });
                inst.load_store_register.offset = off;
                try writer.writeInt(u32, inst.toU32(), .little);
            }
        },

        .got_load_pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);
            const target = math.cast(u64, G + A) orelse return error.Overflow;
            const off = try Relocation.calcPageOffset(target, .load_store_64);
            var inst: aarch64.Instruction = .{
                .load_store_register = mem.bytesToValue(std.meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.load_store_register,
                ), code[rel_offset..][0..4]),
            };
            inst.load_store_register.offset = off;
            try writer.writeInt(u32, inst.toU32(), .little);
        },

        .tlvp_pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);

            const sym = rel.getTargetSymbol(macho_file);
            const target = target: {
                const target = if (sym.flags.tlv_ptr) blk: {
                    const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                    break :blk S_ + A;
                } else S + A;
                break :target math.cast(u64, target) orelse return error.Overflow;
            };

            const RegInfo = struct {
                rd: u5,
                rn: u5,
                size: u2,
            };

            const inst_code = code[rel_offset..][0..4];
            const reg_info: RegInfo = blk: {
                if (Relocation.isArithmeticOp(inst_code)) {
                    const inst = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), inst_code);
                    break :blk .{
                        .rd = inst.rd,
                        .rn = inst.rn,
                        .size = inst.sf,
                    };
                } else {
                    const inst = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), inst_code);
                    break :blk .{
                        .rd = inst.rt,
                        .rn = inst.rn,
                        .size = inst.size,
                    };
                }
            };

            var inst = if (sym.flags.tlv_ptr) aarch64.Instruction{
                .load_store_register = .{
                    .rt = reg_info.rd,
                    .rn = reg_info.rn,
                    .offset = try Relocation.calcPageOffset(target, .load_store_64),
                    .opc = 0b01,
                    .op1 = 0b01,
                    .v = 0,
                    .size = reg_info.size,
                },
            } else aarch64.Instruction{
                .add_subtract_immediate = .{
                    .rd = reg_info.rd,
                    .rn = reg_info.rn,
                    .imm12 = try Relocation.calcPageOffset(target, .arithmetic),
                    .sh = 0,
                    .s = 0,
                    .op = 0,
                    .sf = @as(u1, @truncate(reg_info.size)),
                },
            };
            try writer.writeInt(u32, inst.toU32(), .little);
        },
    }
}

fn relaxGotLoad(code: []u8) error{RelaxFail}!void {
    const old_inst = disassemble(code) orelse return error.RelaxFail;
    switch (old_inst.encoding.mnemonic) {
        .mov => {
            const inst = Instruction.new(old_inst.prefix, .lea, &old_inst.ops) catch return error.RelaxFail;
            relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
            encode(&.{inst}, code) catch return error.RelaxFail;
        },
        else => return error.RelaxFail,
    }
}

fn relaxTlv(code: []u8) error{RelaxFail}!void {
    const old_inst = disassemble(code) orelse return error.RelaxFail;
    switch (old_inst.encoding.mnemonic) {
        .mov => {
            const inst = Instruction.new(old_inst.prefix, .lea, &old_inst.ops) catch return error.RelaxFail;
            relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
            encode(&.{inst}, code) catch return error.RelaxFail;
        },
        else => return error.RelaxFail,
    }
}

fn disassemble(code: []const u8) ?Instruction {
    var disas = Disassembler.init(code);
    const inst = disas.next() catch return null;
    return inst;
}

fn encode(insts: []const Instruction, code: []u8) !void {
    var stream = std.io.fixedBufferStream(code);
    const writer = stream.writer();
    for (insts) |inst| {
        try inst.encode(writer, .{});
    }
}

pub fn calcNumRelocs(self: Atom, macho_file: *MachO) u32 {
    switch (macho_file.options.cpu_arch.?) {
        .aarch64 => {
            var nreloc: u32 = 0;
            for (self.getRelocs(macho_file)) |rel| {
                nreloc += 1;
                switch (rel.type) {
                    .page, .pageoff => if (rel.addend > 0) {
                        nreloc += 1;
                    },
                    else => {},
                }
            }
            return nreloc;
        },
        .x86_64 => return @intCast(self.getRelocs(macho_file).len),
        else => unreachable,
    }
}

pub fn writeRelocs(self: Atom, macho_file: *MachO, code: []u8, buffer: *std.ArrayList(macho.relocation_info)) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const cpu_arch = macho_file.options.cpu_arch.?;
    const relocs = self.getRelocs(macho_file);
    const sect = macho_file.sections.items(.header)[self.out_n_sect];
    var stream = std.io.fixedBufferStream(code);

    for (relocs) |rel| {
        const rel_offset = rel.offset - self.off;
        const r_address: i32 = math.cast(i32, self.value + rel_offset - sect.addr) orelse return error.Overflow;
        const r_symbolnum = r_symbolnum: {
            const r_symbolnum: u32 = switch (rel.tag) {
                .local => rel.getTargetAtom(macho_file).out_n_sect + 1,
                .@"extern" => rel.getTargetSymbol(macho_file).getOutputSymtabIndex(macho_file).?,
            };
            break :r_symbolnum math.cast(u24, r_symbolnum) orelse return error.Overflow;
        };
        const r_extern = rel.tag == .@"extern";
        var addend = rel.addend + rel.getRelocAddend(cpu_arch);
        if (rel.tag == .local) {
            const target: i64 = @intCast(rel.getTargetAddress(macho_file));
            addend += target;
        }

        try stream.seekTo(rel_offset);

        switch (cpu_arch) {
            .aarch64 => {
                if (rel.type == .unsigned) switch (rel.meta.length) {
                    0, 1 => unreachable,
                    2 => try stream.writer().writeInt(i32, @truncate(addend), .little),
                    3 => try stream.writer().writeInt(i64, addend, .little),
                } else if (addend > 0) {
                    buffer.appendAssumeCapacity(.{
                        .r_address = r_address,
                        .r_symbolnum = @bitCast(math.cast(i24, addend) orelse return error.Overflow),
                        .r_pcrel = 0,
                        .r_length = 2,
                        .r_extern = 0,
                        .r_type = @intFromEnum(macho.reloc_type_arm64.ARM64_RELOC_ADDEND),
                    });
                }

                const r_type: macho.reloc_type_arm64 = switch (rel.type) {
                    .page => .ARM64_RELOC_PAGE21,
                    .pageoff => .ARM64_RELOC_PAGEOFF12,
                    .got_load_page => .ARM64_RELOC_GOT_LOAD_PAGE21,
                    .got_load_pageoff => .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                    .tlvp_page => .ARM64_RELOC_TLVP_LOAD_PAGE21,
                    .tlvp_pageoff => .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
                    .branch => .ARM64_RELOC_BRANCH26,
                    .got => .ARM64_RELOC_POINTER_TO_GOT,
                    .subtractor => .ARM64_RELOC_SUBTRACTOR,
                    .unsigned => .ARM64_RELOC_UNSIGNED,

                    .signed,
                    .signed1,
                    .signed2,
                    .signed4,
                    .got_load,
                    .tlv,
                    => unreachable,
                };
                buffer.appendAssumeCapacity(.{
                    .r_address = r_address,
                    .r_symbolnum = r_symbolnum,
                    .r_pcrel = @intFromBool(rel.meta.pcrel),
                    .r_extern = @intFromBool(r_extern),
                    .r_length = rel.meta.length,
                    .r_type = @intFromEnum(r_type),
                });
            },
            .x86_64 => {
                if (rel.meta.pcrel) {
                    if (rel.tag == .local) {
                        addend -= @as(i64, @intCast(self.value + rel_offset));
                    } else {
                        addend += 4;
                    }
                }
                switch (rel.meta.length) {
                    0, 1 => unreachable,
                    2 => try stream.writer().writeInt(i32, @truncate(addend), .little),
                    3 => try stream.writer().writeInt(i64, addend, .little),
                }

                const r_type: macho.reloc_type_x86_64 = switch (rel.type) {
                    .signed => .X86_64_RELOC_SIGNED,
                    .signed1 => .X86_64_RELOC_SIGNED_1,
                    .signed2 => .X86_64_RELOC_SIGNED_2,
                    .signed4 => .X86_64_RELOC_SIGNED_4,
                    .got_load => .X86_64_RELOC_GOT_LOAD,
                    .tlv => .X86_64_RELOC_TLV,
                    .branch => .X86_64_RELOC_BRANCH,
                    .got => .X86_64_RELOC_GOT,
                    .subtractor => .X86_64_RELOC_SUBTRACTOR,
                    .unsigned => .X86_64_RELOC_UNSIGNED,

                    .page,
                    .pageoff,
                    .got_load_page,
                    .got_load_pageoff,
                    .tlvp_page,
                    .tlvp_pageoff,
                    => unreachable,
                };
                buffer.appendAssumeCapacity(.{
                    .r_address = r_address,
                    .r_symbolnum = r_symbolnum,
                    .r_pcrel = @intFromBool(rel.meta.pcrel),
                    .r_extern = @intFromBool(r_extern),
                    .r_length = rel.meta.length,
                    .r_type = @intFromEnum(r_type),
                });
            },
            else => unreachable,
        }
    }
}

pub fn format(
    atom: Atom,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = atom;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format Atom directly");
}

pub fn fmt(atom: Atom, macho_file: *MachO) std.fmt.Formatter(format2) {
    return .{ .data = .{
        .atom = atom,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    atom: Atom,
    macho_file: *MachO,
};

fn format2(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const atom = ctx.atom;
    const macho_file = ctx.macho_file;
    try writer.print("atom({d}) : {s} : @{x} : sect({d}) : align({x}) : size({x}) : thunk({d})", .{
        atom.atom_index,  atom.getName(macho_file), atom.value,
        atom.out_n_sect,  atom.alignment,           atom.size,
        atom.thunk_index,
    });
    if (!atom.flags.alive) try writer.writeAll(" : [*]");
    if (atom.unwind_records.len > 0) {
        try writer.writeAll(" : unwind{ ");
        for (atom.getUnwindRecords(macho_file), atom.unwind_records.pos..) |index, i| {
            const rec = macho_file.getUnwindRecord(index);
            try writer.print("{d}", .{index});
            if (!rec.alive) try writer.writeAll("([*])");
            if (i < atom.unwind_records.pos + atom.unwind_records.len - 1) try writer.writeAll(", ");
        }
        try writer.writeAll(" }");
    }
}

pub const Index = u32;

pub const Flags = packed struct {
    /// Specifies whether this atom is alive or has been garbage collected.
    alive: bool = true,

    /// Specifies if the atom has been visited during garbage collection.
    visited: bool = false,
};

pub const Loc = struct {
    pos: usize = 0,
    len: usize = 0,
};

const aarch64 = @import("../aarch64.zig");
const assert = std.debug.assert;
const bind = @import("dyld_info/bind.zig");
const dis_x86_64 = @import("dis_x86_64");
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const log = std.log.scoped(.link);
const relocs_log = std.log.scoped(.relocs);
const std = @import("std");
const trace = @import("../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @This();
const Disassembler = dis_x86_64.Disassembler;
const File = @import("file.zig").File;
const Instruction = dis_x86_64.Instruction;
const Immediate = dis_x86_64.Immediate;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const Thunk = @import("thunks.zig").Thunk;
const UnwindInfo = @import("UnwindInfo.zig");
