pub const GotSection = struct {
    symbols: std.ArrayListUnmanaged(MachO.Ref) = .empty,

    pub const Index = u32;

    pub fn deinit(got: *GotSection, allocator: Allocator) void {
        got.symbols.deinit(allocator);
    }

    pub fn addSymbol(got: *GotSection, ref: MachO.Ref, macho_file: *MachO) !void {
        const gpa = macho_file.base.comp.gpa;
        const index = @as(Index, @intCast(got.symbols.items.len));
        const entry = try got.symbols.addOne(gpa);
        entry.* = ref;
        const symbol = ref.getSymbol(macho_file).?;
        symbol.setSectionFlags(.{ .has_got = true });
        symbol.addExtra(.{ .got = index }, macho_file);
    }

    pub fn getAddress(got: GotSection, index: Index, macho_file: *MachO) u64 {
        assert(index < got.symbols.items.len);
        const header = macho_file.sections.items(.header)[macho_file.got_sect_index.?];
        return header.addr + index * @sizeOf(u64);
    }

    pub fn size(got: GotSection) usize {
        return got.symbols.items.len * @sizeOf(u64);
    }

    pub fn write(got: GotSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();
        for (got.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            const value = if (sym.flags.import) @as(u64, 0) else sym.getAddress(.{}, macho_file);
            try writer.writeInt(u64, value, .little);
        }
    }

    const FormatCtx = struct {
        got: GotSection,
        macho_file: *MachO,
    };

    pub fn fmt(got: GotSection, macho_file: *MachO) std.fmt.Formatter(format2) {
        return .{ .data = .{ .got = got, .macho_file = macho_file } };
    }

    pub fn format2(
        ctx: FormatCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        for (ctx.got.symbols.items, 0..) |ref, i| {
            const symbol = ref.getSymbol(ctx.macho_file).?;
            try writer.print("  {d}@0x{x} => {d}@0x{x} ({s})\n", .{
                i,
                symbol.getGotAddress(ctx.macho_file),
                ref,
                symbol.getAddress(.{}, ctx.macho_file),
                symbol.getName(ctx.macho_file),
            });
        }
    }
};

pub const StubsSection = struct {
    symbols: std.ArrayListUnmanaged(MachO.Ref) = .empty,

    pub const Index = u32;

    pub fn deinit(stubs: *StubsSection, allocator: Allocator) void {
        stubs.symbols.deinit(allocator);
    }

    pub fn addSymbol(stubs: *StubsSection, ref: MachO.Ref, macho_file: *MachO) !void {
        const gpa = macho_file.base.comp.gpa;
        const index = @as(Index, @intCast(stubs.symbols.items.len));
        const entry = try stubs.symbols.addOne(gpa);
        entry.* = ref;
        const symbol = ref.getSymbol(macho_file).?;
        symbol.addExtra(.{ .stubs = index }, macho_file);
    }

    pub fn getAddress(stubs: StubsSection, index: Index, macho_file: *MachO) u64 {
        assert(index < stubs.symbols.items.len);
        const header = macho_file.sections.items(.header)[macho_file.stubs_sect_index.?];
        return header.addr + index * header.reserved2;
    }

    pub fn size(stubs: StubsSection, macho_file: *MachO) usize {
        const header = macho_file.sections.items(.header)[macho_file.stubs_sect_index.?];
        return stubs.symbols.items.len * header.reserved2;
    }

    pub fn write(stubs: StubsSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();
        const cpu_arch = macho_file.getTarget().cpu.arch;
        const laptr_sect = macho_file.sections.items(.header)[macho_file.la_symbol_ptr_sect_index.?];

        for (stubs.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const source = sym.getAddress(.{ .stubs = true }, macho_file);
            const target = laptr_sect.addr + idx * @sizeOf(u64);
            switch (cpu_arch) {
                .x86_64 => {
                    try writer.writeAll(&.{ 0xff, 0x25 });
                    try writer.writeInt(i32, @intCast(target - source - 2 - 4), .little);
                },
                .aarch64 => {
                    // TODO relax if possible
                    const pages = try aarch64.calcNumberOfPages(@intCast(source), @intCast(target));
                    try writer.writeInt(u32, aarch64.Instruction.adrp(.x16, pages).toU32(), .little);
                    const off = try math.divExact(u12, @truncate(target), 8);
                    try writer.writeInt(
                        u32,
                        aarch64.Instruction.ldr(.x16, .x16, aarch64.Instruction.LoadStoreOffset.imm(off)).toU32(),
                        .little,
                    );
                    try writer.writeInt(u32, aarch64.Instruction.br(.x16).toU32(), .little);
                },
                else => unreachable,
            }
        }
    }

    const FormatCtx = struct {
        stubs: StubsSection,
        macho_file: *MachO,
    };

    pub fn fmt(stubs: StubsSection, macho_file: *MachO) std.fmt.Formatter(format2) {
        return .{ .data = .{ .stubs = stubs, .macho_file = macho_file } };
    }

    pub fn format2(
        ctx: FormatCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        for (ctx.stubs.symbols.items, 0..) |ref, i| {
            const symbol = ref.getSymbol(ctx.macho_file).?;
            try writer.print("  {d}@0x{x} => {d}@0x{x} ({s})\n", .{
                i,
                symbol.getStubsAddress(ctx.macho_file),
                ref,
                symbol.getAddress(.{}, ctx.macho_file),
                symbol.getName(ctx.macho_file),
            });
        }
    }
};

pub const StubsHelperSection = struct {
    pub inline fn preambleSize(cpu_arch: std.Target.Cpu.Arch) usize {
        return switch (cpu_arch) {
            .x86_64 => 16,
            .aarch64 => 6 * @sizeOf(u32),
            else => 0,
        };
    }

    pub inline fn entrySize(cpu_arch: std.Target.Cpu.Arch) usize {
        return switch (cpu_arch) {
            .x86_64 => 10,
            .aarch64 => 3 * @sizeOf(u32),
            else => 0,
        };
    }

    pub fn size(stubs_helper: StubsHelperSection, macho_file: *MachO) usize {
        const tracy = trace(@src());
        defer tracy.end();
        _ = stubs_helper;
        const cpu_arch = macho_file.getTarget().cpu.arch;
        var s: usize = preambleSize(cpu_arch);
        for (macho_file.stubs.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            if (sym.flags.weak) continue;
            s += entrySize(cpu_arch);
        }
        return s;
    }

    pub fn write(stubs_helper: StubsHelperSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();

        try stubs_helper.writePreamble(macho_file, writer);

        const cpu_arch = macho_file.getTarget().cpu.arch;
        const sect = macho_file.sections.items(.header)[macho_file.stubs_helper_sect_index.?];
        const preamble_size = preambleSize(cpu_arch);
        const entry_size = entrySize(cpu_arch);

        var idx: usize = 0;
        for (macho_file.stubs.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            if (sym.flags.weak) continue;
            const offset = macho_file.lazy_bind_section.offsets.items[idx];
            const source: i64 = @intCast(sect.addr + preamble_size + entry_size * idx);
            const target: i64 = @intCast(sect.addr);
            switch (cpu_arch) {
                .x86_64 => {
                    try writer.writeByte(0x68);
                    try writer.writeInt(u32, offset, .little);
                    try writer.writeByte(0xe9);
                    try writer.writeInt(i32, @intCast(target - source - 6 - 4), .little);
                },
                .aarch64 => {
                    const literal = blk: {
                        const div_res = try std.math.divExact(u64, entry_size - @sizeOf(u32), 4);
                        break :blk std.math.cast(u18, div_res) orelse return error.Overflow;
                    };
                    try writer.writeInt(u32, aarch64.Instruction.ldrLiteral(
                        .w16,
                        literal,
                    ).toU32(), .little);
                    const disp = math.cast(i28, @as(i64, @intCast(target)) - @as(i64, @intCast(source + 4))) orelse
                        return error.Overflow;
                    try writer.writeInt(u32, aarch64.Instruction.b(disp).toU32(), .little);
                    try writer.writeAll(&.{ 0x0, 0x0, 0x0, 0x0 });
                },
                else => unreachable,
            }
            idx += 1;
        }
    }

    fn writePreamble(stubs_helper: StubsHelperSection, macho_file: *MachO, writer: anytype) !void {
        _ = stubs_helper;
        const obj = macho_file.getInternalObject().?;
        const cpu_arch = macho_file.getTarget().cpu.arch;
        const sect = macho_file.sections.items(.header)[macho_file.stubs_helper_sect_index.?];
        const dyld_private_addr = target: {
            const sym = obj.getDyldPrivateRef(macho_file).?.getSymbol(macho_file).?;
            break :target sym.getAddress(.{}, macho_file);
        };
        const dyld_stub_binder_addr = target: {
            const sym = obj.getDyldStubBinderRef(macho_file).?.getSymbol(macho_file).?;
            break :target sym.getGotAddress(macho_file);
        };
        switch (cpu_arch) {
            .x86_64 => {
                try writer.writeAll(&.{ 0x4c, 0x8d, 0x1d });
                try writer.writeInt(i32, @intCast(dyld_private_addr - sect.addr - 3 - 4), .little);
                try writer.writeAll(&.{ 0x41, 0x53, 0xff, 0x25 });
                try writer.writeInt(i32, @intCast(dyld_stub_binder_addr - sect.addr - 11 - 4), .little);
                try writer.writeByte(0x90);
            },
            .aarch64 => {
                {
                    // TODO relax if possible
                    const pages = try aarch64.calcNumberOfPages(@intCast(sect.addr), @intCast(dyld_private_addr));
                    try writer.writeInt(u32, aarch64.Instruction.adrp(.x17, pages).toU32(), .little);
                    const off: u12 = @truncate(dyld_private_addr);
                    try writer.writeInt(u32, aarch64.Instruction.add(.x17, .x17, off, false).toU32(), .little);
                }
                try writer.writeInt(u32, aarch64.Instruction.stp(
                    .x16,
                    .x17,
                    aarch64.Register.sp,
                    aarch64.Instruction.LoadStorePairOffset.pre_index(-16),
                ).toU32(), .little);
                {
                    // TODO relax if possible
                    const pages = try aarch64.calcNumberOfPages(@intCast(sect.addr + 12), @intCast(dyld_stub_binder_addr));
                    try writer.writeInt(u32, aarch64.Instruction.adrp(.x16, pages).toU32(), .little);
                    const off = try math.divExact(u12, @truncate(dyld_stub_binder_addr), 8);
                    try writer.writeInt(u32, aarch64.Instruction.ldr(
                        .x16,
                        .x16,
                        aarch64.Instruction.LoadStoreOffset.imm(off),
                    ).toU32(), .little);
                }
                try writer.writeInt(u32, aarch64.Instruction.br(.x16).toU32(), .little);
            },
            else => unreachable,
        }
    }
};

pub const LaSymbolPtrSection = struct {
    pub fn size(laptr: LaSymbolPtrSection, macho_file: *MachO) usize {
        _ = laptr;
        return macho_file.stubs.symbols.items.len * @sizeOf(u64);
    }

    pub fn write(laptr: LaSymbolPtrSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();
        _ = laptr;
        const cpu_arch = macho_file.getTarget().cpu.arch;
        const sect = macho_file.sections.items(.header)[macho_file.stubs_helper_sect_index.?];
        var stub_helper_idx: u32 = 0;
        for (macho_file.stubs.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            if (sym.flags.weak) {
                const value = sym.getAddress(.{ .stubs = false }, macho_file);
                try writer.writeInt(u64, @intCast(value), .little);
            } else {
                const value = sect.addr + StubsHelperSection.preambleSize(cpu_arch) +
                    StubsHelperSection.entrySize(cpu_arch) * stub_helper_idx;
                stub_helper_idx += 1;
                try writer.writeInt(u64, @intCast(value), .little);
            }
        }
    }
};

pub const TlvPtrSection = struct {
    symbols: std.ArrayListUnmanaged(MachO.Ref) = .empty,

    pub const Index = u32;

    pub fn deinit(tlv: *TlvPtrSection, allocator: Allocator) void {
        tlv.symbols.deinit(allocator);
    }

    pub fn addSymbol(tlv: *TlvPtrSection, ref: MachO.Ref, macho_file: *MachO) !void {
        const gpa = macho_file.base.comp.gpa;
        const index = @as(Index, @intCast(tlv.symbols.items.len));
        const entry = try tlv.symbols.addOne(gpa);
        entry.* = ref;
        const symbol = ref.getSymbol(macho_file).?;
        symbol.addExtra(.{ .tlv_ptr = index }, macho_file);
    }

    pub fn getAddress(tlv: TlvPtrSection, index: Index, macho_file: *MachO) u64 {
        assert(index < tlv.symbols.items.len);
        const header = macho_file.sections.items(.header)[macho_file.tlv_ptr_sect_index.?];
        return header.addr + index * @sizeOf(u64);
    }

    pub fn size(tlv: TlvPtrSection) usize {
        return tlv.symbols.items.len * @sizeOf(u64);
    }

    pub fn write(tlv: TlvPtrSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();

        for (tlv.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            if (sym.flags.import) {
                try writer.writeInt(u64, 0, .little);
            } else {
                try writer.writeInt(u64, sym.getAddress(.{}, macho_file), .little);
            }
        }
    }

    const FormatCtx = struct {
        tlv: TlvPtrSection,
        macho_file: *MachO,
    };

    pub fn fmt(tlv: TlvPtrSection, macho_file: *MachO) std.fmt.Formatter(format2) {
        return .{ .data = .{ .tlv = tlv, .macho_file = macho_file } };
    }

    pub fn format2(
        ctx: FormatCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        for (ctx.tlv.symbols.items, 0..) |ref, i| {
            const symbol = ref.getSymbol(ctx.macho_file).?;
            try writer.print("  {d}@0x{x} => {d}@0x{x} ({s})\n", .{
                i,
                symbol.getTlvPtrAddress(ctx.macho_file),
                ref,
                symbol.getAddress(.{}, ctx.macho_file),
                symbol.getName(ctx.macho_file),
            });
        }
    }
};

pub const ObjcStubsSection = struct {
    symbols: std.ArrayListUnmanaged(MachO.Ref) = .empty,

    pub fn deinit(objc: *ObjcStubsSection, allocator: Allocator) void {
        objc.symbols.deinit(allocator);
    }

    pub fn entrySize(cpu_arch: std.Target.Cpu.Arch) u8 {
        return switch (cpu_arch) {
            .x86_64 => 13,
            .aarch64 => 8 * @sizeOf(u32),
            else => unreachable,
        };
    }

    pub fn addSymbol(objc: *ObjcStubsSection, ref: MachO.Ref, macho_file: *MachO) !void {
        const gpa = macho_file.base.comp.gpa;
        const index = @as(Index, @intCast(objc.symbols.items.len));
        const entry = try objc.symbols.addOne(gpa);
        entry.* = ref;
        const symbol = ref.getSymbol(macho_file).?;
        symbol.addExtra(.{ .objc_stubs = index }, macho_file);
    }

    pub fn getAddress(objc: ObjcStubsSection, index: Index, macho_file: *MachO) u64 {
        assert(index < objc.symbols.items.len);
        const header = macho_file.sections.items(.header)[macho_file.objc_stubs_sect_index.?];
        return header.addr + index * entrySize(macho_file.getTarget().cpu.arch);
    }

    pub fn size(objc: ObjcStubsSection, macho_file: *MachO) usize {
        return objc.symbols.items.len * entrySize(macho_file.getTarget().cpu.arch);
    }

    pub fn write(objc: ObjcStubsSection, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();

        const obj = macho_file.getInternalObject().?;

        for (objc.symbols.items, 0..) |ref, idx| {
            const sym = ref.getSymbol(macho_file).?;
            const addr = objc.getAddress(@intCast(idx), macho_file);
            switch (macho_file.getTarget().cpu.arch) {
                .x86_64 => {
                    try writer.writeAll(&.{ 0x48, 0x8b, 0x35 });
                    {
                        const target = sym.getObjcSelrefsAddress(macho_file);
                        const source = addr;
                        try writer.writeInt(i32, @intCast(target - source - 3 - 4), .little);
                    }
                    try writer.writeAll(&.{ 0xff, 0x25 });
                    {
                        const target_sym = obj.getObjcMsgSendRef(macho_file).?.getSymbol(macho_file).?;
                        const target = target_sym.getGotAddress(macho_file);
                        const source = addr + 7;
                        try writer.writeInt(i32, @intCast(target - source - 2 - 4), .little);
                    }
                },
                .aarch64 => {
                    {
                        const target = sym.getObjcSelrefsAddress(macho_file);
                        const source = addr;
                        const pages = try aarch64.calcNumberOfPages(@intCast(source), @intCast(target));
                        try writer.writeInt(u32, aarch64.Instruction.adrp(.x1, pages).toU32(), .little);
                        const off = try math.divExact(u12, @truncate(target), 8);
                        try writer.writeInt(
                            u32,
                            aarch64.Instruction.ldr(.x1, .x1, aarch64.Instruction.LoadStoreOffset.imm(off)).toU32(),
                            .little,
                        );
                    }
                    {
                        const target_sym = obj.getObjcMsgSendRef(macho_file).?.getSymbol(macho_file).?;
                        const target = target_sym.getGotAddress(macho_file);
                        const source = addr + 2 * @sizeOf(u32);
                        const pages = try aarch64.calcNumberOfPages(@intCast(source), @intCast(target));
                        try writer.writeInt(u32, aarch64.Instruction.adrp(.x16, pages).toU32(), .little);
                        const off = try math.divExact(u12, @truncate(target), 8);
                        try writer.writeInt(
                            u32,
                            aarch64.Instruction.ldr(.x16, .x16, aarch64.Instruction.LoadStoreOffset.imm(off)).toU32(),
                            .little,
                        );
                    }
                    try writer.writeInt(u32, aarch64.Instruction.br(.x16).toU32(), .little);
                    try writer.writeInt(u32, aarch64.Instruction.brk(1).toU32(), .little);
                    try writer.writeInt(u32, aarch64.Instruction.brk(1).toU32(), .little);
                    try writer.writeInt(u32, aarch64.Instruction.brk(1).toU32(), .little);
                },
                else => unreachable,
            }
        }
    }

    const FormatCtx = struct {
        objc: ObjcStubsSection,
        macho_file: *MachO,
    };

    pub fn fmt(objc: ObjcStubsSection, macho_file: *MachO) std.fmt.Formatter(format2) {
        return .{ .data = .{ .objc = objc, .macho_file = macho_file } };
    }

    pub fn format2(
        ctx: FormatCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        for (ctx.objc.symbols.items, 0..) |ref, i| {
            const symbol = ref.getSymbol(ctx.macho_file).?;
            try writer.print("  {d}@0x{x} => {d}@0x{x} ({s})\n", .{
                i,
                symbol.getObjcStubsAddress(ctx.macho_file),
                ref,
                symbol.getAddress(.{}, ctx.macho_file),
                symbol.getName(ctx.macho_file),
            });
        }
    }

    pub const Index = u32;
};

pub const Indsymtab = struct {
    pub inline fn nsyms(ind: Indsymtab, macho_file: *MachO) u32 {
        _ = ind;
        return @intCast(macho_file.stubs.symbols.items.len * 2 + macho_file.got.symbols.items.len);
    }

    pub fn updateSize(ind: *Indsymtab, macho_file: *MachO) !void {
        macho_file.dysymtab_cmd.nindirectsyms = ind.nsyms(macho_file);
    }

    pub fn write(ind: Indsymtab, macho_file: *MachO, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();

        _ = ind;

        for (macho_file.stubs.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            try writer.writeInt(u32, sym.getOutputSymtabIndex(macho_file).?, .little);
        }

        for (macho_file.got.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            try writer.writeInt(u32, sym.getOutputSymtabIndex(macho_file).?, .little);
        }

        for (macho_file.stubs.symbols.items) |ref| {
            const sym = ref.getSymbol(macho_file).?;
            try writer.writeInt(u32, sym.getOutputSymtabIndex(macho_file).?, .little);
        }
    }
};

pub const DataInCode = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    pub fn deinit(dice: *DataInCode, allocator: Allocator) void {
        dice.entries.deinit(allocator);
    }

    pub fn size(dice: DataInCode) usize {
        return dice.entries.items.len * @sizeOf(macho.data_in_code_entry);
    }

    pub fn updateSize(dice: *DataInCode, macho_file: *MachO) !void {
        const gpa = macho_file.base.comp.gpa;

        for (macho_file.objects.items) |index| {
            const object = macho_file.getFile(index).?.object;
            const dices = object.getDataInCode();

            try dice.entries.ensureUnusedCapacity(gpa, dices.len);

            var next_dice: usize = 0;
            for (object.getAtoms()) |atom_index| {
                if (next_dice >= dices.len) break;
                const atom = object.getAtom(atom_index) orelse continue;
                const start_off = atom.getInputAddress(macho_file);
                const end_off = start_off + atom.size;
                const start_dice = next_dice;

                if (end_off < dices[next_dice].offset) continue;

                while (next_dice < dices.len and
                    dices[next_dice].offset < end_off) : (next_dice += 1)
                {}

                if (atom.isAlive()) for (dices[start_dice..next_dice]) |d| {
                    dice.entries.appendAssumeCapacity(.{
                        .atom_ref = .{ .index = atom_index, .file = index },
                        .offset = @intCast(d.offset - start_off),
                        .length = d.length,
                        .kind = d.kind,
                    });
                };
            }
        }

        macho_file.data_in_code_cmd.datasize = math.cast(u32, dice.size()) orelse return error.Overflow;
    }

    pub fn write(dice: DataInCode, macho_file: *MachO, writer: anytype) !void {
        const base_address = if (!macho_file.base.isRelocatable())
            macho_file.getTextSegment().vmaddr
        else
            0;
        for (dice.entries.items) |entry| {
            const atom_address = entry.atom_ref.getAtom(macho_file).?.getAddress(macho_file);
            const offset = atom_address + entry.offset - base_address;
            try writer.writeStruct(macho.data_in_code_entry{
                .offset = @intCast(offset),
                .length = entry.length,
                .kind = entry.kind,
            });
        }
    }

    const Entry = struct {
        atom_ref: MachO.Ref,
        offset: u32,
        length: u16,
        kind: u16,
    };
};

const aarch64 = @import("../aarch64.zig");
const assert = std.debug.assert;
const macho = std.macho;
const math = std.math;
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = std.mem.Allocator;
const MachO = @import("../MachO.zig");
const Symbol = @import("Symbol.zig");
