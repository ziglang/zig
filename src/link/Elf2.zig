base: link.File,
options: link.File.OpenOptions,
mf: MappedFile,
ni: Node.Known,
nodes: std.MultiArrayList(Node),
shdrs: std.ArrayList(Section),
phdrs: std.ArrayList(MappedFile.Node.Index),
si: Symbol.Known,
symtab: std.ArrayList(Symbol),
shstrtab: StringTable,
strtab: StringTable,
dynsym: std.ArrayList(Symbol.Index),
dynstr: StringTable,
needed: std.AutoArrayHashMapUnmanaged(u32, void),
inputs: std.ArrayList(struct {
    path: std.Build.Cache.Path,
    member: ?[]const u8,
    si: Symbol.Index,
}),
input_sections: std.ArrayList(struct {
    ii: Node.InputIndex,
    file_location: MappedFile.Node.FileLocation,
    si: Symbol.Index,
}),
input_section_pending_index: u32,
globals: std.AutoArrayHashMapUnmanaged(u32, Symbol.Index),
navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, Symbol.Index),
uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
lazy: std.EnumArray(link.File.LazySymbol.Kind, struct {
    map: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
    pending_index: u32,
}),
pending_uavs: std.AutoArrayHashMapUnmanaged(Node.UavMapIndex, struct {
    alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
}),
relocs: std.ArrayList(Reloc),
/// This is hiding actual bugs with global symbols! Reconsider once they are implemented correctly.
entry_hack: Symbol.Index,
const_prog_node: std.Progress.Node,
synth_prog_node: std.Progress.Node,
input_prog_node: std.Progress.Node,

pub const Node = union(enum) {
    file,
    ehdr,
    shdr,
    segment: u32,
    section: Symbol.Index,
    input_section: InputSectionIndex,
    nav: NavMapIndex,
    uav: UavMapIndex,
    lazy_code: LazyMapRef.Index(.code),
    lazy_const_data: LazyMapRef.Index(.const_data),

    pub const InputIndex = enum(u32) {
        _,

        pub fn path(ii: InputIndex, elf: *const Elf) std.Build.Cache.Path {
            return elf.inputs.items[@intFromEnum(ii)].path;
        }

        pub fn member(ii: InputIndex, elf: *const Elf) ?[]const u8 {
            return elf.inputs.items[@intFromEnum(ii)].member;
        }

        pub fn symbol(ii: InputIndex, elf: *const Elf) Symbol.Index {
            return elf.inputs.items[@intFromEnum(ii)].si;
        }

        pub fn endSymbol(ii: InputIndex, elf: *const Elf) Symbol.Index {
            const next_ii = @intFromEnum(ii) + 1;
            return if (next_ii < elf.inputs.items.len)
                @as(InputIndex, @enumFromInt(next_ii)).symbol(elf)
            else
                @enumFromInt(elf.symtab.items.len);
        }
    };

    pub const InputSectionIndex = enum(u32) {
        _,

        pub fn input(isi: InputSectionIndex, elf: *const Elf) InputIndex {
            return elf.input_sections.items[@intFromEnum(isi)].ii;
        }

        pub fn fileLocation(isi: InputSectionIndex, elf: *const Elf) MappedFile.Node.FileLocation {
            return elf.input_sections.items[@intFromEnum(isi)].file_location;
        }

        pub fn symbol(isi: InputSectionIndex, elf: *const Elf) Symbol.Index {
            return elf.input_sections.items[@intFromEnum(isi)].si;
        }
    };

    pub const NavMapIndex = enum(u32) {
        _,

        pub fn navIndex(nmi: NavMapIndex, elf: *const Elf) InternPool.Nav.Index {
            return elf.navs.keys()[@intFromEnum(nmi)];
        }

        pub fn symbol(nmi: NavMapIndex, elf: *const Elf) Symbol.Index {
            return elf.navs.values()[@intFromEnum(nmi)];
        }
    };

    pub const UavMapIndex = enum(u32) {
        _,

        pub fn uavValue(umi: UavMapIndex, elf: *const Elf) InternPool.Index {
            return elf.uavs.keys()[@intFromEnum(umi)];
        }

        pub fn symbol(umi: UavMapIndex, elf: *const Elf) Symbol.Index {
            return elf.uavs.values()[@intFromEnum(umi)];
        }
    };

    pub const LazyMapRef = struct {
        kind: link.File.LazySymbol.Kind,
        index: u32,

        pub fn Index(comptime kind: link.File.LazySymbol.Kind) type {
            return enum(u32) {
                _,

                pub fn ref(lmi: @This()) LazyMapRef {
                    return .{ .kind = kind, .index = @intFromEnum(lmi) };
                }

                pub fn lazySymbol(lmi: @This(), elf: *const Elf) link.File.LazySymbol {
                    return lmi.ref().lazySymbol(elf);
                }

                pub fn symbol(lmi: @This(), elf: *const Elf) Symbol.Index {
                    return lmi.ref().symbol(elf);
                }
            };
        }

        pub fn lazySymbol(lmr: LazyMapRef, elf: *const Elf) link.File.LazySymbol {
            return .{ .kind = lmr.kind, .ty = elf.lazy.getPtrConst(lmr.kind).map.keys()[lmr.index] };
        }

        pub fn symbol(lmr: LazyMapRef, elf: *const Elf) Symbol.Index {
            return elf.lazy.getPtrConst(lmr.kind).map.values()[lmr.index];
        }
    };

    pub const Known = struct {
        comptime file: MappedFile.Node.Index = .root,
        comptime ehdr: MappedFile.Node.Index = @enumFromInt(1),
        comptime shdr: MappedFile.Node.Index = @enumFromInt(2),
        comptime rodata: MappedFile.Node.Index = @enumFromInt(3),
        comptime phdr: MappedFile.Node.Index = @enumFromInt(4),
        comptime text: MappedFile.Node.Index = @enumFromInt(5),
        comptime data: MappedFile.Node.Index = @enumFromInt(6),
        tls: MappedFile.Node.Index,
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Node) == 8);
    }
};

pub const Section = struct {
    si: Symbol.Index,
    rela_si: Symbol.Index,
    rela_free: RelIndex,

    pub const RelIndex = enum(u32) {
        none,
        _,

        pub fn wrap(i: ?u32) RelIndex {
            return @enumFromInt((i orelse return .none) + 1);
        }
        pub fn unwrap(ri: RelIndex) ?u32 {
            return switch (ri) {
                .none => null,
                else => @intFromEnum(ri) - 1,
            };
        }
    };
};

pub const StringTable = struct {
    map: std.HashMapUnmanaged(u32, void, StringTable.Context, std.hash_map.default_max_load_percentage),

    const Context = struct {
        slice: []const u8,

        pub fn eql(_: Context, lhs_key: u32, rhs_key: u32) bool {
            return lhs_key == rhs_key;
        }

        pub fn hash(ctx: Context, key: u32) u64 {
            return std.hash_map.hashString(std.mem.sliceTo(ctx.slice[key..], 0));
        }
    };

    const Adapter = struct {
        slice: []const u8,

        pub fn eql(adapter: Adapter, lhs_key: []const u8, rhs_key: u32) bool {
            return std.mem.startsWith(u8, adapter.slice[rhs_key..], lhs_key) and
                adapter.slice[rhs_key + lhs_key.len] == 0;
        }

        pub fn hash(_: Adapter, key: []const u8) u64 {
            assert(std.mem.indexOfScalar(u8, key, 0) == null);
            return std.hash_map.hashString(key);
        }
    };

    pub fn get(st: *StringTable, elf: *Elf, si: Symbol.Index, key: []const u8) !u32 {
        const gpa = elf.base.comp.gpa;
        const ni = si.node(elf);
        const slice_const = ni.sliceConst(&elf.mf);
        const gop = try st.map.getOrPutContextAdapted(
            gpa,
            key,
            StringTable.Adapter{ .slice = slice_const },
            .{ .slice = slice_const },
        );
        if (gop.found_existing) return gop.key_ptr.*;
        const old_size, const new_size = size: switch (elf.shdrPtr(si.shndx(elf))) {
            inline else => |shdr| {
                const old_size: u32 = @intCast(elf.targetLoad(&shdr.size));
                const new_size: u32 = @intCast(old_size + key.len + 1);
                elf.targetStore(&shdr.size, new_size);
                break :size .{ old_size, new_size };
            },
        };
        _, const node_size = ni.location(&elf.mf).resolve(&elf.mf);
        if (new_size > node_size)
            try ni.resize(&elf.mf, gpa, new_size +| new_size / MappedFile.growth_factor);
        const slice = ni.slice(&elf.mf)[old_size..];
        @memcpy(slice[0..key.len], key);
        slice[key.len] = 0;
        gop.key_ptr.* = old_size;
        return old_size;
    }
};

pub const Symbol = struct {
    ni: MappedFile.Node.Index,
    /// Relocations contained within this symbol
    loc_relocs: Reloc.Index,
    /// Relocations targeting this symbol
    target_relocs: Reloc.Index,
    unused: u32,

    pub const Index = enum(u32) {
        null,
        symtab,
        shstrtab,
        strtab,
        rodata,
        text,
        data,
        _,

        pub fn get(si: Symbol.Index, elf: *Elf) *Symbol {
            return &elf.symtab.items[@intFromEnum(si)];
        }

        pub fn node(si: Symbol.Index, elf: *Elf) MappedFile.Node.Index {
            const ni = si.get(elf).ni;
            assert(ni != .none);
            return ni;
        }

        pub fn next(si: Symbol.Index) Symbol.Index {
            return @enumFromInt(@intFromEnum(si) + 1);
        }

        pub const Shndx = enum(Tag) {
            UNDEF = std.elf.SHN_UNDEF,
            LIVEPATCH = reserve(std.elf.SHN_LIVEPATCH),
            ABS = reserve(std.elf.SHN_ABS),
            COMMON = reserve(std.elf.SHN_COMMON),
            _,

            pub const Tag = u32;

            pub const LORESERVE: Shndx = .fromSection(std.elf.SHN_LORESERVE);
            pub const HIRESERVE: Shndx = .fromSection(std.elf.SHN_HIRESERVE);
            comptime {
                assert(@intFromEnum(HIRESERVE) == std.math.maxInt(Tag));
            }

            fn reserve(sec: std.elf.Section) Tag {
                assert(sec >= std.elf.SHN_LORESERVE and sec <= std.elf.SHN_HIRESERVE);
                return @as(Tag, std.math.maxInt(Tag) - std.elf.SHN_HIRESERVE) + sec;
            }

            pub fn fromSection(sec: std.elf.Section) Shndx {
                return switch (sec) {
                    std.elf.SHN_UNDEF...std.elf.SHN_LORESERVE - 1 => @enumFromInt(sec),
                    std.elf.SHN_LORESERVE...std.elf.SHN_HIRESERVE => @enumFromInt(reserve(sec)),
                };
            }
            pub fn toSection(s: Shndx) ?std.elf.Section {
                return switch (@intFromEnum(s)) {
                    std.elf.SHN_UNDEF...std.elf.SHN_LORESERVE - 1 => |sec| @intCast(sec),
                    std.elf.SHN_LORESERVE...reserve(std.elf.SHN_LORESERVE) - 1 => null,
                    reserve(std.elf.SHN_LORESERVE)...reserve(std.elf.SHN_HIRESERVE) => |sec| @intCast(
                        sec - reserve(std.elf.SHN_LORESERVE) + std.elf.SHN_LORESERVE,
                    ),
                };
            }

            pub fn get(s: Shndx, elf: *Elf) *Section {
                return &elf.shdrs.items[@intFromEnum(s)];
            }
        };
        pub fn shndx(si: Symbol.Index, elf: *Elf) Shndx {
            return .fromSection(switch (elf.symPtr(si)) {
                inline else => |sym| elf.targetLoad(&sym.shndx),
            });
        }

        pub const InitOptions = struct {
            name: []const u8 = "",
            lib_name: ?[]const u8 = null,
            value: u64 = 0,
            size: u64 = 0,
            type: std.elf.STT,
            bind: std.elf.STB = .LOCAL,
            visibility: std.elf.STV = .DEFAULT,
            shndx: Shndx = .UNDEF,
        };
        pub fn init(si: Symbol.Index, elf: *Elf, opts: InitOptions) !void {
            const gpa = elf.base.comp.gpa;
            const target_endian = elf.targetEndian();
            const name_strtab_entry = try elf.string(.strtab, opts.name);
            switch (elf.shdrPtr(elf.si.symtab.shndx(elf))) {
                inline else => |shdr| {
                    const old_size = elf.targetLoad(&shdr.size);
                    const ent_size = elf.targetLoad(&shdr.entsize);
                    const new_size = ent_size * elf.symtab.items.len;
                    if (new_size > old_size) {
                        elf.targetStore(&shdr.size, @intCast(new_size));
                        const symtab_ni = elf.si.symtab.node(elf);
                        _, const node_size = symtab_ni.location(&elf.mf).resolve(&elf.mf);
                        if (new_size > node_size) try symtab_ni.resize(
                            &elf.mf,
                            gpa,
                            new_size +| new_size / MappedFile.growth_factor,
                        );
                    }
                },
            }
            switch (elf.symPtr(si)) {
                inline else => |sym, class| {
                    const Sym = class.ElfN().Sym;
                    sym.* = .{
                        .name = name_strtab_entry,
                        .value = @intCast(opts.value),
                        .size = @intCast(opts.size),
                        .info = .{ .type = opts.type, .bind = opts.bind },
                        .other = .{ .visibility = opts.visibility },
                        .shndx = opts.shndx.toSection().?,
                    };
                    if (target_endian != native_endian) std.mem.byteSwapAllFields(Sym, sym);
                },
            }
            switch (elf.shdrPtr(elf.si.symtab.shndx(elf))) {
                inline else => |shdr| elf.targetStore(&shdr.info, @max(
                    elf.targetLoad(&shdr.info),
                    @intFromEnum(si) + 1,
                )),
            }
            if (opts.bind == .LOCAL or elf.si.dynsym == .null) return;
            const dsi = elf.dynsym.items.len;
            try elf.dynsym.append(gpa, si);
            const name_dynstr_entry = try elf.string(.dynstr, opts.name);
            switch (elf.shdrPtr(elf.si.dynsym.shndx(elf))) {
                inline else => |shdr| {
                    const old_size = elf.targetLoad(&shdr.size);
                    const ent_size = elf.targetLoad(&shdr.entsize);
                    const new_size = ent_size * elf.dynsym.items.len;
                    if (new_size > old_size) {
                        elf.targetStore(&shdr.size, @intCast(new_size));
                        const dynsym_ni = elf.si.dynsym.node(elf);
                        _, const node_size = dynsym_ni.location(&elf.mf).resolve(&elf.mf);
                        if (new_size > node_size) try dynsym_ni.resize(
                            &elf.mf,
                            gpa,
                            new_size +| new_size / MappedFile.growth_factor,
                        );
                    }
                },
            }
            switch (elf.dynsymSlice()) {
                inline else => |dynsyms, class| {
                    const Sym = class.ElfN().Sym;
                    const dynsym = &dynsyms[dsi];
                    dynsym.* = .{
                        .name = name_dynstr_entry,
                        .value = @intCast(opts.value),
                        .size = @intCast(opts.size),
                        .info = .{ .type = opts.type, .bind = opts.bind },
                        .other = .{ .visibility = opts.visibility },
                        .shndx = opts.shndx.toSection().?,
                    };
                    if (target_endian != native_endian) std.mem.byteSwapAllFields(Sym, dynsym);
                },
            }
        }

        pub fn flushMoved(si: Symbol.Index, elf: *Elf, value: u64) void {
            switch (elf.symPtr(si)) {
                inline else => |sym, class| {
                    elf.targetStore(&sym.value, @intCast(value));
                    if (si == elf.entry_hack) {
                        @branchHint(.unlikely);
                        @field(elf.ehdrPtr(), @tagName(class)).entry = sym.value;
                    }
                },
            }
            si.applyLocationRelocs(elf);
            si.applyTargetRelocs(elf);
        }

        pub fn applyLocationRelocs(si: Symbol.Index, elf: *Elf) void {
            if (elf.ehdrField(.type) == .REL) return;
            switch (si.get(elf).loc_relocs) {
                .none => {},
                else => |loc_relocs| for (elf.relocs.items[@intFromEnum(loc_relocs)..]) |*reloc| {
                    if (reloc.loc != si) break;
                    reloc.apply(elf);
                },
            }
        }

        pub fn applyTargetRelocs(si: Symbol.Index, elf: *Elf) void {
            if (elf.ehdrField(.type) == .REL) return;
            var ri = si.get(elf).target_relocs;
            while (ri != .none) {
                const reloc = ri.get(elf);
                assert(reloc.target == si);
                reloc.apply(elf);
                ri = reloc.next;
            }
        }

        pub fn deleteLocationRelocs(si: Symbol.Index, elf: *Elf) void {
            const sym = si.get(elf);
            for (elf.relocs.items[@intFromEnum(sym.loc_relocs)..]) |*reloc| {
                if (reloc.loc != si) break;
                reloc.delete(elf);
            }
            sym.loc_relocs = .none;
        }
    };

    pub const Known = struct {
        comptime symtab: Symbol.Index = .symtab,
        comptime shstrtab: Symbol.Index = .shstrtab,
        comptime strtab: Symbol.Index = .strtab,
        comptime rodata: Symbol.Index = .rodata,
        comptime text: Symbol.Index = .text,
        comptime data: Symbol.Index = .data,
        dynsym: Symbol.Index,
        dynstr: Symbol.Index,
        dynamic: Symbol.Index,
        tdata: Symbol.Index,
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Symbol) == 16);
    }
};

pub const Reloc = extern struct {
    type: Reloc.Type,
    prev: Reloc.Index,
    next: Reloc.Index,
    loc: Symbol.Index,
    target: Symbol.Index,
    index: Section.RelIndex,
    offset: u64,
    addend: i64,

    pub const Type = extern union {
        X86_64: std.elf.R_X86_64,
        AARCH64: std.elf.R_AARCH64,
        RISCV: std.elf.R_RISCV,
        PPC64: std.elf.R_PPC64,

        pub fn none(elf: *Elf) Reloc.Type {
            return switch (elf.ehdrField(.machine)) {
                else => unreachable,
                .AARCH64 => .{ .AARCH64 = .NONE },
                .PPC64 => .{ .PPC64 = .NONE },
                .RISCV => .{ .RISCV = .NONE },
                .X86_64 => .{ .X86_64 = .NONE },
            };
        }

        pub fn absAddr(elf: *Elf) Reloc.Type {
            return switch (elf.ehdrField(.machine)) {
                else => unreachable,
                .AARCH64 => .{ .AARCH64 = .ABS64 },
                .PPC64 => .{ .PPC64 = .ADDR64 },
                .RISCV => .{ .RISCV = .@"64" },
                .X86_64 => .{ .X86_64 = .@"64" },
            };
        }

        pub fn sizeAddr(elf: *Elf) Reloc.Type {
            return switch (elf.ehdrField(.machine)) {
                else => unreachable,
                .X86_64 => .{ .X86_64 = .SIZE64 },
            };
        }

        pub fn wrap(int: u32, elf: *Elf) Reloc.Type {
            return switch (elf.ehdrField(.machine)) {
                else => unreachable,
                inline .AARCH64,
                .PPC64,
                .RISCV,
                .X86_64,
                => |machine| @unionInit(Reloc.Type, @tagName(machine), @enumFromInt(int)),
            };
        }

        pub fn unwrap(rt: Reloc.Type, elf: *Elf) u32 {
            return switch (elf.ehdrField(.machine)) {
                else => unreachable,
                inline .AARCH64,
                .PPC64,
                .RISCV,
                .X86_64,
                => |machine| @intFromEnum(@field(rt, @tagName(machine))),
            };
        }
    };

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn get(si: Reloc.Index, elf: *Elf) *Reloc {
            return &elf.relocs.items[@intFromEnum(si)];
        }
    };

    pub fn apply(reloc: *const Reloc, elf: *Elf) void {
        assert(elf.ehdrField(.type) != .REL);
        const loc_ni = reloc.loc.get(elf).ni;
        switch (loc_ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&elf.mf)) return,
        }
        switch (reloc.target.get(elf).ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&elf.mf)) return,
        }
        const loc_slice = loc_ni.slice(&elf.mf)[@intCast(reloc.offset)..];
        const target_endian = elf.targetEndian();
        switch (elf.symtabSlice()) {
            inline else => |symtab, class| {
                const loc_sym = &symtab[@intFromEnum(reloc.loc)];
                const loc_shndx = elf.targetLoad(&loc_sym.shndx);
                assert(loc_shndx != std.elf.SHN_UNDEF);
                const loc_value = elf.targetLoad(&loc_sym.value) + reloc.offset;
                const target_sym = &symtab[@intFromEnum(reloc.target)];
                const target_value =
                    elf.targetLoad(&target_sym.value) +% @as(u64, @bitCast(reloc.addend));
                switch (elf.ehdrField(.machine)) {
                    else => |machine| @panic(@tagName(machine)),
                    .X86_64 => switch (reloc.type.X86_64) {
                        else => |kind| @panic(@tagName(kind)),
                        .@"64" => std.mem.writeInt(
                            u64,
                            loc_slice[0..8],
                            target_value,
                            target_endian,
                        ),
                        .PC32, .PLT32 => std.mem.writeInt(
                            i32,
                            loc_slice[0..4],
                            @intCast(@as(i64, @bitCast(target_value -% loc_value))),
                            target_endian,
                        ),
                        .@"32" => std.mem.writeInt(
                            u32,
                            loc_slice[0..4],
                            @intCast(target_value),
                            target_endian,
                        ),
                        .@"32S" => std.mem.writeInt(
                            i32,
                            loc_slice[0..4],
                            @intCast(@as(i64, @bitCast(target_value))),
                            target_endian,
                        ),
                        .TPOFF32 => {
                            const phdr = @field(elf.phdrSlice(), @tagName(class));
                            const ph = &phdr[elf.getNode(elf.ni.tls).segment];
                            assert(elf.targetLoad(&ph.type) == .TLS);
                            std.mem.writeInt(
                                i32,
                                loc_slice[0..4],
                                @intCast(@as(i64, @bitCast(target_value -% elf.targetLoad(&ph.memsz)))),
                                target_endian,
                            );
                        },
                        .SIZE32 => std.mem.writeInt(
                            u32,
                            loc_slice[0..4],
                            @intCast(elf.targetLoad(&target_sym.size)),
                            target_endian,
                        ),
                        .SIZE64 => std.mem.writeInt(
                            u64,
                            loc_slice[0..8],
                            @intCast(elf.targetLoad(&target_sym.size)),
                            target_endian,
                        ),
                    },
                }
            },
        }
    }

    pub fn delete(reloc: *Reloc, elf: *Elf) void {
        switch (reloc.prev) {
            .none => {
                const target = reloc.target.get(elf);
                assert(target.target_relocs.get(elf) == reloc);
                target.target_relocs = reloc.next;
            },
            else => |prev| prev.get(elf).next = reloc.next,
        }
        switch (reloc.next) {
            .none => {},
            else => |next| next.get(elf).prev = reloc.prev,
        }
        switch (elf.ehdrField(.type)) {
            .NONE, .CORE, _ => unreachable,
            .REL => {
                const sh = reloc.loc.shndx(elf).get(elf);
                switch (elf.shdrPtr(sh.rela_si.shndx(elf))) {
                    inline else => |shdr, class| {
                        const Rela = class.ElfN().Rela;
                        const ent_size = elf.targetLoad(&shdr.entsize);
                        const start = ent_size * reloc.index.unwrap().?;
                        const rela_slice = sh.rela_si.node(elf).slice(&elf.mf);
                        const rela: *Rela = @ptrCast(@alignCast(
                            rela_slice[@intCast(start)..][0..@intCast(ent_size)],
                        ));
                        rela.* = .{
                            .offset = @intFromEnum(sh.rela_free),
                            .info = .{
                                .type = @intCast(Reloc.Type.none(elf).unwrap(elf)),
                                .sym = 0,
                            },
                            .addend = 0,
                        };
                    },
                }
                sh.rela_free = reloc.index;
            },
            .EXEC, .DYN => assert(reloc.index == .none),
        }
        reloc.* = undefined;
    }

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Reloc) == 40);
    }
};

pub fn open(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    return create(arena, comp, path, options);
}
pub fn createEmpty(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    return create(arena, comp, path, options);
}
fn create(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    const target = &comp.root_mod.resolved_target.result;
    assert(target.ofmt == .elf);
    const class: std.elf.CLASS = switch (target.ptrBitWidth()) {
        0...32 => .@"32",
        33...64 => .@"64",
        else => return error.UnsupportedELFArchitecture,
    };
    const data: std.elf.DATA = switch (target.cpu.arch.endian()) {
        .little => .@"2LSB",
        .big => .@"2MSB",
    };
    const osabi: std.elf.OSABI = switch (target.os.tag) {
        else => .NONE,
        .freestanding, .other => .STANDALONE,
        .netbsd => .NETBSD,
        .illumos => .SOLARIS,
        .freebsd, .ps4 => .FREEBSD,
        .openbsd => .OPENBSD,
        .cuda => .CUDA,
        .amdhsa => .AMDGPU_HSA,
        .amdpal => .AMDGPU_PAL,
        .mesa3d => .AMDGPU_MESA3D,
    };
    const @"type": std.elf.ET = switch (comp.config.output_mode) {
        .Exe => if (comp.config.pie or target.os.tag == .haiku) .DYN else .EXEC,
        .Lib => switch (comp.config.link_mode) {
            .static => .REL,
            .dynamic => .DYN,
        },
        .Obj => .REL,
    };
    const machine = target.toElfMachine();
    const maybe_interp = switch (comp.config.link_mode) {
        .static => null,
        .dynamic => switch (comp.config.output_mode) {
            .Exe => target.dynamic_linker.get(),
            .Lib => if (comp.root_mod.resolved_target.is_explicit_dynamic_linker)
                target.dynamic_linker.get()
            else
                null,
            .Obj => null,
        },
    };

    const elf = try arena.create(Elf);
    const file = try path.root_dir.handle.adaptToNewApi().createFile(comp.io, path.sub_path, .{
        .read = true,
        .mode = link.File.determineMode(comp.config.output_mode, comp.config.link_mode),
    });
    errdefer file.close(comp.io);
    elf.* = .{
        .base = .{
            .tag = .elf2,

            .comp = comp,
            .emit = path,

            .file = .adaptFromNewApi(file),
            .gc_sections = false,
            .print_gc_sections = false,
            .build_id = .none,
            .allow_shlib_undefined = false,
            .stack_size = 0,
        },
        .options = options,
        .mf = try .init(file, comp.gpa),
        .ni = .{
            .tls = .none,
        },
        .nodes = .empty,
        .shdrs = .empty,
        .phdrs = .empty,
        .si = .{
            .dynsym = .null,
            .dynstr = .null,
            .dynamic = .null,
            .tdata = .null,
        },
        .symtab = .empty,
        .shstrtab = .{
            .map = .empty,
        },
        .strtab = .{
            .map = .empty,
        },
        .dynsym = .empty,
        .dynstr = .{
            .map = .empty,
        },
        .needed = .empty,
        .inputs = .empty,
        .input_sections = .empty,
        .input_section_pending_index = 0,
        .globals = .empty,
        .navs = .empty,
        .uavs = .empty,
        .lazy = comptime .initFill(.{
            .map = .empty,
            .pending_index = 0,
        }),
        .pending_uavs = .empty,
        .relocs = .empty,
        .entry_hack = .null,
        .const_prog_node = .none,
        .synth_prog_node = .none,
        .input_prog_node = .none,
    };
    errdefer elf.deinit();

    try elf.initHeaders(class, data, osabi, @"type", machine, maybe_interp);
    return elf;
}

pub fn deinit(elf: *Elf) void {
    const gpa = elf.base.comp.gpa;
    elf.mf.deinit(gpa);
    elf.nodes.deinit(gpa);
    elf.shdrs.deinit(gpa);
    elf.phdrs.deinit(gpa);
    elf.symtab.deinit(gpa);
    elf.shstrtab.map.deinit(gpa);
    elf.strtab.map.deinit(gpa);
    elf.dynsym.deinit(gpa);
    elf.dynstr.map.deinit(gpa);
    elf.needed.deinit(gpa);
    for (elf.inputs.items) |input| if (input.member) |m| gpa.free(m);
    elf.inputs.deinit(gpa);
    elf.input_sections.deinit(gpa);
    elf.globals.deinit(gpa);
    elf.navs.deinit(gpa);
    elf.uavs.deinit(gpa);
    for (&elf.lazy.values) |*lazy| lazy.map.deinit(gpa);
    elf.pending_uavs.deinit(gpa);
    elf.relocs.deinit(gpa);
    elf.* = undefined;
}

fn initHeaders(
    elf: *Elf,
    class: std.elf.CLASS,
    data: std.elf.DATA,
    osabi: std.elf.OSABI,
    @"type": std.elf.ET,
    machine: std.elf.EM,
    maybe_interp: ?[]const u8,
) !void {
    const comp = elf.base.comp;
    const gpa = comp.gpa;
    const have_dynamic_section = switch (@"type") {
        .NONE, .CORE, _ => unreachable,
        .REL => false,
        .EXEC => comp.config.link_mode == .dynamic,
        .DYN => true,
    };
    const addr_align: std.mem.Alignment = switch (class) {
        .NONE, _ => unreachable,
        .@"32" => .@"4",
        .@"64" => .@"8",
    };

    const shnum: u32 = 1;
    var phnum: u32 = 0;
    const phdr_phndx = phnum;
    phnum += 1;
    const interp_phndx = if (maybe_interp) |_| phndx: {
        defer phnum += 1;
        break :phndx phnum;
    } else undefined;
    const rodata_phndx = phnum;
    phnum += 1;
    const text_phndx = phnum;
    phnum += 1;
    const data_phndx = phnum;
    phnum += 1;
    const dynamic_phndx = if (have_dynamic_section) phndx: {
        defer phnum += 1;
        break :phndx phnum;
    } else undefined;
    const tls_phndx = if (comp.config.any_non_single_threaded) phndx: {
        defer phnum += 1;
        break :phndx phnum;
    } else undefined;

    const expected_nodes_len = expected_nodes_len: switch (@"type") {
        .NONE, .CORE, _ => unreachable,
        .REL => {
            defer phnum = 0;
            break :expected_nodes_len 5 + phnum;
        },
        .EXEC, .DYN => break :expected_nodes_len 5 + phnum * 2 +
            @as(usize, 2) * @intFromBool(have_dynamic_section),
    };
    try elf.nodes.ensureTotalCapacity(gpa, expected_nodes_len);
    try elf.shdrs.ensureTotalCapacity(gpa, shnum);
    try elf.phdrs.resize(gpa, phnum);
    elf.nodes.appendAssumeCapacity(.file);

    switch (class) {
        .NONE, _ => unreachable,
        inline else => |ct_class| {
            const ElfN = ct_class.ElfN();
            assert(elf.ni.ehdr == try elf.mf.addOnlyChildNode(gpa, elf.ni.file, .{
                .size = @sizeOf(ElfN.Ehdr),
                .alignment = addr_align,
                .fixed = true,
            }));
            elf.nodes.appendAssumeCapacity(.ehdr);

            const ehdr: *ElfN.Ehdr = @ptrCast(@alignCast(elf.ni.ehdr.slice(&elf.mf)));
            const EI = std.elf.EI;
            @memcpy(ehdr.ident[0..std.elf.MAGIC.len], std.elf.MAGIC);
            ehdr.ident[EI.CLASS] = @intFromEnum(class);
            ehdr.ident[EI.DATA] = @intFromEnum(data);
            ehdr.ident[EI.VERSION] = 1;
            ehdr.ident[EI.OSABI] = @intFromEnum(osabi);
            ehdr.ident[EI.ABIVERSION] = 0;
            @memset(ehdr.ident[EI.PAD..], 0);
            ehdr.type = @"type";
            ehdr.machine = machine;
            ehdr.version = 1;
            ehdr.entry = 0;
            ehdr.phoff = 0;
            ehdr.shoff = 0;
            ehdr.flags = 0;
            ehdr.ehsize = @sizeOf(ElfN.Ehdr);
            ehdr.phentsize = @sizeOf(ElfN.Phdr);
            ehdr.phnum = @min(phnum, std.elf.PN_XNUM);
            ehdr.shentsize = @sizeOf(ElfN.Shdr);
            ehdr.shnum = if (shnum < std.elf.SHN_LORESERVE) shnum else 0;
            ehdr.shstrndx = std.elf.SHN_UNDEF;
            if (elf.targetEndian() != native_endian) std.mem.byteSwapAllFields(ElfN.Ehdr, ehdr);
        },
    }

    assert(elf.ni.shdr == try elf.mf.addLastChildNode(gpa, elf.ni.file, .{
        .size = elf.ehdrField(.shentsize) * elf.ehdrField(.shnum),
        .alignment = elf.mf.flags.block_size,
        .moved = true,
        .resized = true,
    }));
    elf.nodes.appendAssumeCapacity(.shdr);

    var ph_vaddr: u32 = if (@"type" != .REL) ph_vaddr: {
        assert(elf.ni.rodata == try elf.mf.addLastChildNode(gpa, elf.ni.file, .{
            .alignment = elf.mf.flags.block_size,
            .moved = true,
            .bubbles_moved = false,
        }));
        elf.nodes.appendAssumeCapacity(.{ .segment = rodata_phndx });
        elf.phdrs.items[rodata_phndx] = elf.ni.rodata;

        assert(elf.ni.phdr == try elf.mf.addOnlyChildNode(gpa, elf.ni.rodata, .{
            .size = elf.ehdrField(.phentsize) * elf.ehdrField(.phnum),
            .alignment = addr_align,
            .moved = true,
            .resized = true,
            .bubbles_moved = false,
        }));
        elf.nodes.appendAssumeCapacity(.{ .segment = phdr_phndx });
        elf.phdrs.items[phdr_phndx] = elf.ni.phdr;

        assert(elf.ni.text == try elf.mf.addLastChildNode(gpa, elf.ni.file, .{
            .alignment = elf.mf.flags.block_size,
            .moved = true,
            .bubbles_moved = false,
        }));
        elf.nodes.appendAssumeCapacity(.{ .segment = text_phndx });
        elf.phdrs.items[text_phndx] = elf.ni.text;

        assert(elf.ni.data == try elf.mf.addLastChildNode(gpa, elf.ni.file, .{
            .alignment = elf.mf.flags.block_size,
            .moved = true,
            .bubbles_moved = false,
        }));
        elf.nodes.appendAssumeCapacity(.{ .segment = data_phndx });
        elf.phdrs.items[data_phndx] = elf.ni.data;

        break :ph_vaddr switch (elf.ehdrField(.type)) {
            .NONE, .CORE, _ => unreachable,
            .REL, .DYN => 0,
            .EXEC => switch (elf.ehdrField(.machine)) {
                .@"386" => 0x400000,
                .AARCH64, .X86_64 => 0x200000,
                .PPC, .PPC64 => 0x10000000,
                .S390, .S390_OLD => 0x1000000,
                .OLD_SPARCV9, .SPARCV9 => 0x100000,
                else => 0x10000,
            },
        };
    } else undefined;
    switch (class) {
        .NONE, _ => unreachable,
        inline else => |ct_class| {
            const ElfN = ct_class.ElfN();
            const target_endian = elf.targetEndian();

            if (@"type" != .REL) {
                const phdr: []ElfN.Phdr = @ptrCast(@alignCast(elf.ni.phdr.slice(&elf.mf)));
                const ph_phdr = &phdr[phdr_phndx];
                ph_phdr.* = .{
                    .type = .PHDR,
                    .offset = 0,
                    .vaddr = 0,
                    .paddr = 0,
                    .filesz = 0,
                    .memsz = 0,
                    .flags = .{ .R = true },
                    .@"align" = @intCast(elf.ni.phdr.alignment(&elf.mf).toByteUnits()),
                };
                if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_phdr);

                if (maybe_interp) |_| {
                    const ph_interp = &phdr[interp_phndx];
                    ph_interp.* = .{
                        .type = .INTERP,
                        .offset = 0,
                        .vaddr = 0,
                        .paddr = 0,
                        .filesz = 0,
                        .memsz = 0,
                        .flags = .{ .R = true },
                        .@"align" = 1,
                    };
                    if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_interp);
                }

                _, const rodata_size = elf.ni.rodata.location(&elf.mf).resolve(&elf.mf);
                const ph_rodata = &phdr[rodata_phndx];
                ph_rodata.* = .{
                    .type = if (rodata_size == 0) .NULL else .LOAD,
                    .offset = 0,
                    .vaddr = ph_vaddr,
                    .paddr = ph_vaddr,
                    .filesz = @intCast(rodata_size),
                    .memsz = @intCast(rodata_size),
                    .flags = .{ .R = true },
                    .@"align" = @intCast(elf.ni.rodata.alignment(&elf.mf).toByteUnits()),
                };
                if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_rodata);
                ph_vaddr += @intCast(rodata_size);

                _, const text_size = elf.ni.text.location(&elf.mf).resolve(&elf.mf);
                const ph_text = &phdr[text_phndx];
                ph_text.* = .{
                    .type = if (text_size == 0) .NULL else .LOAD,
                    .offset = 0,
                    .vaddr = ph_vaddr,
                    .paddr = ph_vaddr,
                    .filesz = @intCast(text_size),
                    .memsz = @intCast(text_size),
                    .flags = .{ .R = true, .X = true },
                    .@"align" = @intCast(elf.ni.text.alignment(&elf.mf).toByteUnits()),
                };
                if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_text);
                ph_vaddr += @intCast(text_size);

                _, const data_size = elf.ni.data.location(&elf.mf).resolve(&elf.mf);
                const ph_data = &phdr[data_phndx];
                ph_data.* = .{
                    .type = if (data_size == 0) .NULL else .LOAD,
                    .offset = 0,
                    .vaddr = ph_vaddr,
                    .paddr = ph_vaddr,
                    .filesz = @intCast(data_size),
                    .memsz = @intCast(data_size),
                    .flags = .{ .R = true, .W = true },
                    .@"align" = @intCast(elf.ni.data.alignment(&elf.mf).toByteUnits()),
                };
                if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_data);
                ph_vaddr += @intCast(data_size);

                if (have_dynamic_section) {
                    const ph_dynamic = &phdr[dynamic_phndx];
                    ph_dynamic.* = .{
                        .type = .DYNAMIC,
                        .offset = 0,
                        .vaddr = 0,
                        .paddr = 0,
                        .filesz = 0,
                        .memsz = 0,
                        .flags = .{ .R = true, .W = true },
                        .@"align" = @intCast(addr_align.toByteUnits()),
                    };
                    if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_dynamic);
                }

                if (comp.config.any_non_single_threaded) {
                    const ph_tls = &phdr[tls_phndx];
                    ph_tls.* = .{
                        .type = .TLS,
                        .offset = 0,
                        .vaddr = 0,
                        .paddr = 0,
                        .filesz = 0,
                        .memsz = 0,
                        .flags = .{ .R = true },
                        .@"align" = @intCast(elf.mf.flags.block_size.toByteUnits()),
                    };
                    if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_tls);
                }
            }

            const sh_undef: *ElfN.Shdr = @ptrCast(@alignCast(elf.ni.shdr.slice(&elf.mf)));
            sh_undef.* = .{
                .name = try elf.string(.shstrtab, ""),
                .type = .NULL,
                .flags = .{ .shf = .{} },
                .addr = 0,
                .offset = 0,
                .size = if (shnum < std.elf.SHN_LORESERVE) 0 else shnum,
                .link = 0,
                .info = if (phnum < std.elf.PN_XNUM) 0 else phnum,
                .addralign = 0,
                .entsize = 0,
            };
            if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Shdr, sh_undef);
            elf.shdrs.appendAssumeCapacity(.{ .si = .null, .rela_si = .null, .rela_free = .none });

            try elf.symtab.ensureTotalCapacity(gpa, 1);
            elf.symtab.addOneAssumeCapacity().* = .{
                .ni = .none,
                .loc_relocs = .none,
                .target_relocs = .none,
                .unused = 0,
            };
            assert(elf.si.symtab == try elf.addSection(elf.ni.file, .{
                .type = .SYMTAB,
                .size = @sizeOf(ElfN.Sym) * 1,
                .addralign = addr_align,
                .entsize = @sizeOf(ElfN.Sym),
                .node_align = elf.mf.flags.block_size,
            }));
            const symtab_null = @field(elf.symPtr(.null), @tagName(ct_class));
            symtab_null.* = .{
                .name = try elf.string(.strtab, ""),
                .value = 0,
                .size = 0,
                .info = .{ .type = .NOTYPE, .bind = .LOCAL },
                .other = .{ .visibility = .DEFAULT },
                .shndx = std.elf.SHN_UNDEF,
            };
            if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Sym, symtab_null);

            const ehdr = @field(elf.ehdrPtr(), @tagName(ct_class));
            elf.targetStore(&ehdr.shstrndx, ehdr.shnum);
        },
    }
    assert(elf.si.shstrtab == try elf.addSection(elf.ni.file, .{
        .type = .STRTAB,
        .size = 1,
        .entsize = 1,
        .node_align = elf.mf.flags.block_size,
    }));
    try elf.renameSection(.symtab, ".symtab");
    try elf.renameSection(.shstrtab, ".shstrtab");
    elf.si.shstrtab.node(elf).slice(&elf.mf)[0] = 0;

    assert(elf.si.strtab == try elf.addSection(elf.ni.file, .{
        .name = ".strtab",
        .type = .STRTAB,
        .size = 1,
        .entsize = 1,
        .node_align = elf.mf.flags.block_size,
    }));
    try elf.linkSections(.symtab, .strtab);
    elf.si.strtab.node(elf).slice(&elf.mf)[0] = 0;

    assert(elf.si.rodata == try elf.addSection(elf.ni.rodata, .{
        .name = ".rodata",
        .flags = .{ .ALLOC = true },
        .addralign = elf.mf.flags.block_size,
    }));
    assert(elf.si.text == try elf.addSection(elf.ni.text, .{
        .name = ".text",
        .flags = .{ .ALLOC = true, .EXECINSTR = true },
        .addralign = elf.mf.flags.block_size,
    }));
    assert(elf.si.data == try elf.addSection(elf.ni.data, .{
        .name = ".data",
        .flags = .{ .WRITE = true, .ALLOC = true },
        .addralign = elf.mf.flags.block_size,
    }));
    if (@"type" != .REL) {
        if (maybe_interp) |interp| {
            const interp_ni = try elf.mf.addLastChildNode(gpa, elf.ni.rodata, .{
                .size = interp.len + 1,
                .moved = true,
                .resized = true,
                .bubbles_moved = false,
            });
            elf.nodes.appendAssumeCapacity(.{ .segment = interp_phndx });
            elf.phdrs.items[interp_phndx] = interp_ni;

            const sec_interp_si = try elf.addSection(interp_ni, .{
                .type = .PROGBITS,
                .name = ".interp",
                .flags = .{ .ALLOC = true },
                .size = @intCast(interp.len + 1),
            });
            const sec_interp = sec_interp_si.node(elf).slice(&elf.mf);
            @memcpy(sec_interp[0..interp.len], interp);
            sec_interp[interp.len] = 0;
        }
        if (have_dynamic_section) {
            const dynamic_ni = try elf.mf.addLastChildNode(gpa, elf.ni.data, .{
                .moved = true,
                .bubbles_moved = false,
            });
            elf.nodes.appendAssumeCapacity(.{ .segment = dynamic_phndx });
            elf.phdrs.items[dynamic_phndx] = dynamic_ni;

            switch (class) {
                .NONE, _ => unreachable,
                inline else => |ct_class| {
                    const Sym = ct_class.ElfN().Sym;
                    elf.si.dynsym = try elf.addSection(elf.ni.rodata, .{
                        .name = ".dynsym",
                        .type = .DYNSYM,
                        .size = @sizeOf(Sym) * 1,
                        .addralign = addr_align,
                        .entsize = @sizeOf(Sym),
                        .node_align = elf.mf.flags.block_size,
                    });
                    const dynsym_null = &@field(elf.dynsymSlice(), @tagName(ct_class))[0];
                    dynsym_null.* = .{
                        .name = try elf.string(.dynstr, ""),
                        .value = 0,
                        .size = 0,
                        .info = .{ .type = .NOTYPE, .bind = .LOCAL },
                        .other = .{ .visibility = .DEFAULT },
                        .shndx = std.elf.SHN_UNDEF,
                    };
                    if (elf.targetEndian() != native_endian) std.mem.byteSwapAllFields(
                        Sym,
                        dynsym_null,
                    );
                },
            }
            elf.si.dynstr = try elf.addSection(elf.ni.rodata, .{
                .name = ".dynstr",
                .type = .STRTAB,
                .size = 1,
                .entsize = 1,
                .node_align = elf.mf.flags.block_size,
            });
            elf.si.dynamic = try elf.addSection(dynamic_ni, .{
                .name = ".dynamic",
                .type = .DYNAMIC,
                .flags = .{ .ALLOC = true, .WRITE = true },
                .node_align = addr_align,
            });
            try elf.linkSections(elf.si.dynamic, elf.si.dynstr);
            try elf.linkSections(elf.si.dynsym, elf.si.dynstr);
        }
        if (comp.config.any_non_single_threaded) {
            elf.ni.tls = try elf.mf.addLastChildNode(gpa, elf.ni.rodata, .{
                .alignment = elf.mf.flags.block_size,
                .moved = true,
                .bubbles_moved = false,
            });
            elf.nodes.appendAssumeCapacity(.{ .segment = tls_phndx });
            elf.phdrs.items[tls_phndx] = elf.ni.tls;
        }
    } else {
        assert(maybe_interp == null);
        assert(!have_dynamic_section);
    }
    if (comp.config.any_non_single_threaded) elf.si.tdata = try elf.addSection(elf.ni.tls, .{
        .name = ".tdata",
        .flags = .{ .WRITE = true, .ALLOC = true, .TLS = true },
        .addralign = elf.mf.flags.block_size,
    });
    assert(elf.nodes.len == expected_nodes_len);
}

pub fn startProgress(elf: *Elf, prog_node: std.Progress.Node) void {
    prog_node.increaseEstimatedTotalItems(4);
    elf.const_prog_node = prog_node.start("Constants", elf.pending_uavs.count());
    elf.synth_prog_node = prog_node.start("Synthetics", count: {
        var count: usize = 0;
        for (&elf.lazy.values) |*lazy| count += lazy.map.count() - lazy.pending_index;
        break :count count;
    });
    elf.mf.update_prog_node = prog_node.start("Relocations", elf.mf.updates.items.len);
    elf.input_prog_node = prog_node.start(
        "Inputs",
        elf.input_sections.items.len - elf.input_section_pending_index,
    );
}

pub fn endProgress(elf: *Elf) void {
    elf.input_prog_node.end();
    elf.input_prog_node = .none;
    elf.mf.update_prog_node.end();
    elf.mf.update_prog_node = .none;
    elf.synth_prog_node.end();
    elf.synth_prog_node = .none;
    elf.const_prog_node.end();
    elf.const_prog_node = .none;
}

fn getNode(elf: *const Elf, ni: MappedFile.Node.Index) Node {
    return elf.nodes.get(@intFromEnum(ni));
}
fn computeNodeVAddr(elf: *Elf, ni: MappedFile.Node.Index) u64 {
    const parent_vaddr = parent_vaddr: {
        const parent_si = switch (elf.getNode(ni.parent(&elf.mf))) {
            .file => return 0,
            .ehdr, .shdr => unreachable,
            .segment => |phndx| break :parent_vaddr switch (elf.phdrSlice()) {
                inline else => |phdr| elf.targetLoad(&phdr[phndx].vaddr),
            },
            .section => |si| si,
            .input_section => unreachable,
            inline .nav, .uav, .lazy_code, .lazy_const_data => |mi| mi.symbol(elf),
        };
        break :parent_vaddr if (parent_si == elf.si.tdata) 0 else switch (elf.symPtr(parent_si)) {
            inline else => |sym| elf.targetLoad(&sym.value),
        };
    };
    const offset, _ = ni.location(&elf.mf).resolve(&elf.mf);
    return parent_vaddr + offset;
}

pub fn identClass(elf: *const Elf) std.elf.CLASS {
    return @enumFromInt(elf.mf.contents[std.elf.EI.CLASS]);
}
pub fn identData(elf: *const Elf) std.elf.DATA {
    return @enumFromInt(elf.mf.contents[std.elf.EI.DATA]);
}

pub fn targetEndian(elf: *const Elf) std.builtin.Endian {
    return switch (elf.identData()) {
        .NONE, _ => unreachable,
        .@"2LSB" => .little,
        .@"2MSB" => .big,
    };
}
fn targetLoad(elf: *const Elf, ptr: anytype) @typeInfo(@TypeOf(ptr)).pointer.child {
    const Child = @typeInfo(@TypeOf(ptr)).pointer.child;
    return switch (@typeInfo(Child)) {
        else => @compileError(@typeName(Child)),
        .int => std.mem.toNative(Child, ptr.*, elf.targetEndian()),
        .@"enum" => |@"enum"| @enumFromInt(elf.targetLoad(@as(*@"enum".tag_type, @ptrCast(ptr)))),
        .@"struct" => |@"struct"| @bitCast(
            elf.targetLoad(@as(*@"struct".backing_integer.?, @ptrCast(ptr))),
        ),
    };
}
fn targetStore(elf: *const Elf, ptr: anytype, val: @typeInfo(@TypeOf(ptr)).pointer.child) void {
    const Child = @typeInfo(@TypeOf(ptr)).pointer.child;
    return switch (@typeInfo(Child)) {
        else => @compileError(@typeName(Child)),
        .int => ptr.* = std.mem.nativeTo(Child, val, elf.targetEndian()),
        .@"enum" => |@"enum"| elf.targetStore(
            @as(*@"enum".tag_type, @ptrCast(ptr)),
            @intFromEnum(val),
        ),
        .@"struct" => |@"struct"| elf.targetStore(
            @as(*@"struct".backing_integer.?, @ptrCast(ptr)),
            @bitCast(val),
        ),
    };
}

pub const EhdrPtr = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": *std.elf.Elf32.Ehdr,
    @"64": *std.elf.Elf64.Ehdr,
};
pub fn ehdrPtr(elf: *Elf) EhdrPtr {
    const slice = elf.ni.ehdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| @unionInit(
            EhdrPtr,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}
pub fn ehdrField(
    elf: *Elf,
    comptime field: std.meta.FieldEnum(std.elf.Elf64.Ehdr),
) @FieldType(std.elf.Elf64.Ehdr, @tagName(field)) {
    return switch (elf.ehdrPtr()) {
        inline else => |ehdr| elf.targetLoad(&@field(ehdr, @tagName(field))),
    };
}

pub const PhdrSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Phdr,
    @"64": []std.elf.Elf64.Phdr,
};
pub fn phdrSlice(elf: *Elf) PhdrSlice {
    assert(elf.ehdrField(.type) != .REL);
    const slice = elf.ni.phdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| @unionInit(
            PhdrSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

pub const ShdrSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Shdr,
    @"64": []std.elf.Elf64.Shdr,
};
pub fn shdrSlice(elf: *Elf) ShdrSlice {
    const slice = elf.ni.shdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| @unionInit(
            ShdrSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

pub const ShdrPtr = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": *std.elf.Elf32.Shdr,
    @"64": *std.elf.Elf64.Shdr,
};
pub fn shdrPtr(elf: *Elf, shndx: Symbol.Index.Shndx) ShdrPtr {
    return switch (elf.shdrSlice()) {
        inline else => |shdrs, class| @unionInit(ShdrPtr, @tagName(class), &shdrs[@intFromEnum(shndx)]),
    };
}

pub const SymtabSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Sym,
    @"64": []std.elf.Elf64.Sym,
};
pub fn symtabSlice(elf: *Elf) SymtabSlice {
    const slice = elf.si.symtab.node(elf).slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| @unionInit(
            SymtabSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice[0..std.mem.alignBackwardAnyAlign(
                usize,
                slice.len,
                @sizeOf(class.ElfN().Sym),
            )])),
        ),
    };
}

pub const SymPtr = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": *std.elf.Elf32.Sym,
    @"64": *std.elf.Elf64.Sym,
};
pub fn symPtr(elf: *Elf, si: Symbol.Index) SymPtr {
    return switch (elf.symtabSlice()) {
        inline else => |syms, class| @unionInit(SymPtr, @tagName(class), &syms[@intFromEnum(si)]),
    };
}

pub fn dynsymSlice(elf: *Elf) SymtabSlice {
    const slice = elf.si.dynsym.node(elf).slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| @unionInit(
            SymtabSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

fn addSymbolAssumeCapacity(elf: *Elf) Symbol.Index {
    defer elf.symtab.addOneAssumeCapacity().* = .{
        .ni = .none,
        .loc_relocs = .none,
        .target_relocs = .none,
        .unused = 0,
    };
    return @enumFromInt(elf.symtab.items.len);
}

fn initSymbolAssumeCapacity(elf: *Elf, opts: Symbol.Index.InitOptions) !Symbol.Index {
    const si = elf.addSymbolAssumeCapacity();
    try si.init(elf, opts);
    return si;
}

pub fn globalSymbol(elf: *Elf, opts: struct {
    name: []const u8,
    lib_name: ?[]const u8 = null,
    type: std.elf.STT,
    bind: std.elf.STB = .GLOBAL,
    visibility: std.elf.STV = .DEFAULT,
}) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const global_gop = try elf.globals.getOrPut(gpa, try elf.string(.strtab, opts.name));
    if (!global_gop.found_existing) global_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
        .name = opts.name,
        .lib_name = opts.lib_name,
        .type = opts.type,
        .bind = opts.bind,
        .visibility = opts.visibility,
    });
    return global_gop.value_ptr.*;
}

fn navType(
    ip: *const InternPool,
    nav_status: @FieldType(InternPool.Nav, "status"),
    any_non_single_threaded: bool,
) std.elf.STT {
    return switch (nav_status) {
        .unresolved => unreachable,
        .type_resolved => |tr| if (any_non_single_threaded and tr.is_threadlocal)
            .TLS
        else if (ip.isFunctionType(tr.type))
            .FUNC
        else
            .OBJECT,
        .fully_resolved => |fr| switch (ip.indexToKey(fr.val)) {
            else => .OBJECT,
            .variable => |variable| if (any_non_single_threaded and variable.is_threadlocal)
                .TLS
            else
                .OBJECT,
            .@"extern" => |@"extern"| if (any_non_single_threaded and @"extern".is_threadlocal)
                .TLS
            else if (ip.isFunctionType(@"extern".ty))
                .FUNC
            else
                .OBJECT,
            .func => .FUNC,
        },
    };
}
fn namedSection(elf: *const Elf, name: []const u8) ?Symbol.Index {
    if (std.mem.eql(u8, name, ".rodata") or
        std.mem.startsWith(u8, name, ".rodata.")) return elf.si.rodata;
    if (std.mem.eql(u8, name, ".text") or
        std.mem.startsWith(u8, name, ".text.")) return elf.si.text;
    if (std.mem.eql(u8, name, ".data") or
        std.mem.startsWith(u8, name, ".data.")) return elf.si.data;
    if (std.mem.eql(u8, name, ".tdata") or
        std.mem.startsWith(u8, name, ".tdata.")) return elf.si.tdata;
    return null;
}
fn navSection(
    elf: *Elf,
    ip: *const InternPool,
    nav_fr: @FieldType(@FieldType(InternPool.Nav, "status"), "fully_resolved"),
) Symbol.Index {
    if (nav_fr.@"linksection".toSlice(ip)) |@"linksection"|
        if (elf.namedSection(@"linksection")) |si| return si;
    return switch (navType(
        ip,
        .{ .fully_resolved = nav_fr },
        elf.base.comp.config.any_non_single_threaded,
    )) {
        else => unreachable,
        .FUNC => elf.si.text,
        .OBJECT => elf.si.data,
        .TLS => elf.si.tdata,
    };
}
fn navMapIndex(elf: *Elf, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Node.NavMapIndex {
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const nav_gop = try elf.navs.getOrPut(gpa, nav_index);
    if (!nav_gop.found_existing) nav_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
        .name = nav.fqn.toSlice(ip),
        .type = navType(ip, nav.status, elf.base.comp.config.any_non_single_threaded),
    });
    return @enumFromInt(nav_gop.index);
}
pub fn navSymbol(elf: *Elf, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Symbol.Index {
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    if (nav.getExtern(ip)) |@"extern"| return elf.globalSymbol(.{
        .name = @"extern".name.toSlice(ip),
        .lib_name = @"extern".lib_name.toSlice(ip),
        .type = navType(ip, nav.status, elf.base.comp.config.any_non_single_threaded),
        .bind = switch (@"extern".linkage) {
            .internal => .LOCAL,
            .strong => .GLOBAL,
            .weak => .WEAK,
            .link_once => return error.LinkOnceUnsupported,
        },
        .visibility = switch (@"extern".visibility) {
            .default => .DEFAULT,
            .hidden => .HIDDEN,
            .protected => .PROTECTED,
        },
    });
    const nmi = try elf.navMapIndex(zcu, nav_index);
    return nmi.symbol(elf);
}

fn uavMapIndex(elf: *Elf, uav_val: InternPool.Index) !Node.UavMapIndex {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const uav_gop = try elf.uavs.getOrPut(gpa, uav_val);
    if (!uav_gop.found_existing)
        uav_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{ .type = .OBJECT });
    return @enumFromInt(uav_gop.index);
}
pub fn uavSymbol(elf: *Elf, uav_val: InternPool.Index) !Symbol.Index {
    const umi = try elf.uavMapIndex(uav_val);
    return umi.symbol(elf);
}

pub fn lazySymbol(elf: *Elf, lazy: link.File.LazySymbol) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const lazy_gop = try elf.lazy.getPtr(lazy.kind).map.getOrPut(gpa, lazy.ty);
    if (!lazy_gop.found_existing) {
        lazy_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
            .type = switch (lazy.kind) {
                .code => .FUNC,
                .const_data => .OBJECT,
            },
        });
        elf.synth_prog_node.increaseEstimatedTotalItems(1);
    }
    return lazy_gop.value_ptr.*;
}

pub fn loadInput(elf: *Elf, input: link.Input) (std.fs.File.Reader.SizeError ||
    std.Io.File.Reader.Error || MappedFile.Error || error{ EndOfStream, LinkFailure })!void {
    const io = elf.base.comp.io;
    var buf: [4096]u8 = undefined;
    switch (input) {
        .object => |object| {
            var fr = object.file.reader(io, &buf);
            elf.loadObject(object.path, null, &fr, .{
                .offset = fr.logicalPos(),
                .size = try fr.getSize(),
            }) catch |err| switch (err) {
                error.ReadFailed => return fr.err.?,
                else => |e| return e,
            };
        },
        .archive => |archive| {
            var fr = archive.file.reader(io, &buf);
            elf.loadArchive(archive.path, &fr) catch |err| switch (err) {
                error.ReadFailed => return fr.err.?,
                else => |e| return e,
            };
        },
        .res => unreachable,
        .dso => |dso| {
            try elf.needed.ensureUnusedCapacity(elf.base.comp.gpa, 1);
            var fr = dso.file.reader(io, &buf);
            elf.loadDso(dso.path, &fr) catch |err| switch (err) {
                error.ReadFailed => return fr.err.?,
                else => |e| return e,
            };
        },
        .dso_exact => |dso_exact| try elf.loadDsoExact(dso_exact.name),
    }
}
fn loadArchive(elf: *Elf, path: std.Build.Cache.Path, fr: *std.Io.File.Reader) !void {
    const comp = elf.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const r = &fr.interface;

    log.debug("loadArchive({f})", .{path.fmtEscapeString()});
    if (!std.mem.eql(u8, try r.take(std.elf.ARMAG.len), std.elf.ARMAG))
        return diags.failParse(path, "bad magic", .{});
    var strtab: std.Io.Writer.Allocating = .init(gpa);
    defer strtab.deinit();
    while (r.takeStruct(std.elf.ar_hdr, native_endian)) |header| {
        if (!std.mem.eql(u8, &header.ar_fmag, std.elf.ARFMAG))
            return diags.failParse(path, "bad file magic", .{});
        const offset = fr.logicalPos();
        const size = header.size() catch
            return diags.failParse(path, "bad member size", .{});
        if (std.mem.eql(u8, &header.ar_name, std.elf.STRNAME)) {
            strtab.clearRetainingCapacity();
            try strtab.ensureTotalCapacityPrecise(size);
            r.streamExact(&strtab.writer, size) catch |err| switch (err) {
                error.WriteFailed => return error.OutOfMemory,
                else => |e| return e,
            };
            continue;
        }
        load_object: {
            const member = header.name() orelse member: {
                const strtab_offset = header.nameOffset() catch |err| switch (err) {
                    error.Overflow => break :member error.Overflow,
                    error.InvalidCharacter => break :load_object,
                } orelse break :load_object;
                const strtab_written = strtab.written();
                if (strtab_offset > strtab_written.len) break :member error.Overflow;
                const member = std.mem.sliceTo(strtab_written[strtab_offset..], '\n');
                break :member if (std.mem.endsWith(u8, member, "/"))
                    member[0 .. member.len - "/".len]
                else
                    member;
            } catch |err| switch (err) {
                error.Overflow => return diags.failParse(path, "bad member name offset", .{}),
            };
            if (!std.mem.endsWith(u8, member, ".o")) break :load_object;
            try elf.loadObject(path, member, fr, .{ .offset = offset, .size = size });
        }
        try fr.seekTo(std.mem.alignForward(u64, offset + size, 2));
    } else |err| switch (err) {
        error.EndOfStream => if (!fr.atEnd()) return error.EndOfStream,
        else => |e| return e,
    }
}
fn fmtMemberString(member: ?[]const u8) std.fmt.Alt(?[]const u8, memberStringEscape) {
    return .{ .data = member };
}
fn memberStringEscape(member: ?[]const u8, w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.print("({f})", .{std.zig.fmtString(member orelse return)});
}
fn loadObject(
    elf: *Elf,
    path: std.Build.Cache.Path,
    member: ?[]const u8,
    fr: *std.Io.File.Reader,
    fl: MappedFile.Node.FileLocation,
) !void {
    const comp = elf.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const r = &fr.interface;

    const ii: Node.InputIndex = @enumFromInt(elf.inputs.items.len);
    log.debug("loadObject({f}{f})", .{ path.fmtEscapeString(), fmtMemberString(member) });
    const ident = try r.peek(std.elf.EI.NIDENT);
    if (!std.mem.eql(u8, ident, elf.mf.contents[0..std.elf.EI.NIDENT]))
        return diags.failParse(path, "bad ident", .{});
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    try elf.inputs.ensureUnusedCapacity(gpa, 1);
    elf.inputs.addOneAssumeCapacity().* = .{
        .path = path,
        .member = if (member) |m| try gpa.dupe(u8, m) else null,
        .si = try elf.initSymbolAssumeCapacity(.{
            .name = std.fs.path.stem(member orelse path.sub_path),
            .type = .FILE,
            .shndx = .ABS,
        }),
    };
    const target_endian = elf.targetEndian();
    switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| {
            const ElfN = class.ElfN();
            const ehdr = try r.peekStruct(ElfN.Ehdr, target_endian);
            if (ehdr.type != .REL) return diags.failParse(path, "unsupported object type", .{});
            if (ehdr.machine != elf.ehdrField(.machine))
                return diags.failParse(path, "bad machine", .{});
            if (ehdr.shoff == 0 or ehdr.shnum <= 1) return;
            if (ehdr.shoff + ehdr.shentsize * ehdr.shnum > fl.size)
                return diags.failParse(path, "bad section header location", .{});
            if (ehdr.shentsize < @sizeOf(ElfN.Shdr))
                return diags.failParse(path, "unsupported shentsize", .{});
            const sections = try gpa.alloc(struct { shdr: ElfN.Shdr, si: Symbol.Index }, ehdr.shnum);
            defer gpa.free(sections);
            try fr.seekTo(fl.offset + ehdr.shoff);
            for (sections) |*section| {
                section.* = .{
                    .shdr = try r.peekStruct(ElfN.Shdr, target_endian),
                    .si = .null,
                };
                try r.discardAll(ehdr.shentsize);
                switch (section.shdr.type) {
                    .NULL, .NOBITS => {},
                    else => if (section.shdr.offset + section.shdr.size > fl.size)
                        return diags.failParse(path, "bad section location", .{}),
                }
            }
            const shstrtab = shstrtab: {
                if (ehdr.shstrndx == std.elf.SHN_UNDEF or ehdr.shstrndx >= ehdr.shnum)
                    return diags.failParse(path, "missing section names", .{});
                const shdr = &sections[ehdr.shstrndx].shdr;
                if (shdr.type != .STRTAB) return diags.failParse(path, "invalid shstrtab type", .{});
                const shstrtab = try gpa.alloc(u8, @intCast(shdr.size));
                errdefer gpa.free(shstrtab);
                try fr.seekTo(fl.offset + shdr.offset);
                try r.readSliceAll(shstrtab);
                break :shstrtab shstrtab;
            };
            defer gpa.free(shstrtab);
            try elf.nodes.ensureUnusedCapacity(gpa, ehdr.shnum - 1);
            try elf.symtab.ensureUnusedCapacity(gpa, ehdr.shnum - 1);
            try elf.input_sections.ensureUnusedCapacity(gpa, ehdr.shnum - 1);
            for (sections[1..]) |*section| switch (section.shdr.type) {
                else => {},
                .PROGBITS, .NOBITS => {
                    if (section.shdr.name >= shstrtab.len) continue;
                    const name = std.mem.sliceTo(shstrtab[section.shdr.name..], 0);
                    const parent_si = elf.namedSection(name) orelse continue;
                    const ni = try elf.mf.addLastChildNode(gpa, parent_si.node(elf), .{
                        .size = section.shdr.size,
                        .alignment = .fromByteUnits(std.math.ceilPowerOfTwoAssert(
                            usize,
                            @intCast(@max(section.shdr.addralign, 1)),
                        )),
                        .moved = true,
                    });
                    elf.nodes.appendAssumeCapacity(.{
                        .input_section = @enumFromInt(elf.input_sections.items.len),
                    });
                    section.si = try elf.initSymbolAssumeCapacity(.{
                        .type = .SECTION,
                        .shndx = parent_si.shndx(elf),
                    });
                    section.si.get(elf).ni = ni;
                    elf.input_sections.addOneAssumeCapacity().* = .{
                        .ii = ii,
                        .si = section.si,
                        .file_location = .{
                            .offset = fl.offset + section.shdr.offset,
                            .size = section.shdr.size,
                        },
                    };
                    elf.synth_prog_node.increaseEstimatedTotalItems(1);
                },
            };
            var symmap: std.ArrayList(Symbol.Index) = .empty;
            defer symmap.deinit(gpa);
            for (sections[1..], 1..) |*symtab, symtab_shndx| switch (symtab.shdr.type) {
                else => {},
                .SYMTAB => {
                    if (symtab.shdr.entsize < @sizeOf(ElfN.Sym))
                        return diags.failParse(path, "unsupported symtab entsize", .{});
                    const strtab = strtab: {
                        if (symtab.shdr.link == std.elf.SHN_UNDEF or symtab.shdr.link >= ehdr.shnum)
                            return diags.failParse(path, "missing symbol names", .{});
                        const shdr = &sections[symtab.shdr.link].shdr;
                        if (shdr.type != .STRTAB)
                            return diags.failParse(path, "invalid strtab type", .{});
                        const strtab = try gpa.alloc(u8, @intCast(shdr.size));
                        errdefer gpa.free(strtab);
                        try fr.seekTo(fl.offset + shdr.offset);
                        try r.readSliceAll(strtab);
                        break :strtab strtab;
                    };
                    defer gpa.free(strtab);
                    const symnum = std.math.divExact(
                        u32,
                        @intCast(symtab.shdr.size),
                        @intCast(symtab.shdr.entsize),
                    ) catch return diags.failParse(
                        path,
                        "symtab section size (0x{x}) is not a multiple of entsize (0x{x})",
                        .{ symtab.shdr.size, symtab.shdr.entsize },
                    );
                    symmap.clearRetainingCapacity();
                    try symmap.resize(gpa, std.math.sub(u32, symnum, 1) catch continue);
                    try elf.symtab.ensureUnusedCapacity(gpa, symnum);
                    try elf.globals.ensureUnusedCapacity(gpa, symnum);
                    try fr.seekTo(fl.offset + symtab.shdr.offset + symtab.shdr.entsize);
                    for (symmap.items) |*si| {
                        si.* = .null;
                        const input_sym = try r.peekStruct(ElfN.Sym, target_endian);
                        try r.discardAll64(symtab.shdr.entsize);
                        if (input_sym.name >= strtab.len or input_sym.shndx == std.elf.SHN_UNDEF or
                            input_sym.shndx >= ehdr.shnum) continue;
                        switch (input_sym.info.type) {
                            else => continue,
                            .SECTION => {
                                const section = &sections[input_sym.shndx];
                                if (input_sym.value == section.shdr.addr) si.* = section.si;
                                continue;
                            },
                            .OBJECT, .FUNC => {},
                        }
                        const name = std.mem.sliceTo(strtab[input_sym.name..], 0);
                        const parent_si = sections[input_sym.shndx].si;
                        si.* = try elf.initSymbolAssumeCapacity(.{
                            .name = name,
                            .value = input_sym.value,
                            .size = input_sym.size,
                            .type = input_sym.info.type,
                            .bind = input_sym.info.bind,
                            .visibility = input_sym.other.visibility,
                            .shndx = parent_si.shndx(elf),
                        });
                        si.get(elf).ni = parent_si.get(elf).ni;
                        switch (input_sym.info.bind) {
                            else => {},
                            .GLOBAL => {
                                const gop = elf.globals.getOrPutAssumeCapacity(elf.targetLoad(
                                    &@field(elf.symPtr(si.*), @tagName(class)).name,
                                ));
                                if (gop.found_existing) switch (elf.targetLoad(
                                    switch (elf.symPtr(gop.value_ptr.*)) {
                                        inline else => |sym| &sym.info,
                                    },
                                ).bind) {
                                    else => unreachable,
                                    .GLOBAL => return diags.failParse(
                                        path,
                                        "multiple definitions of '{s}'",
                                        .{name},
                                    ),
                                    .WEAK => {},
                                };
                                gop.value_ptr.* = si.*;
                            },
                            .WEAK => {
                                const gop = elf.globals.getOrPutAssumeCapacity(elf.targetLoad(
                                    &@field(elf.symPtr(si.*), @tagName(class)).name,
                                ));
                                if (!gop.found_existing) gop.value_ptr.* = si.*;
                            },
                        }
                    }
                    for (sections[1..]) |*rels| switch (rels.shdr.type) {
                        else => {},
                        inline .REL, .RELA => |sht| {
                            if (rels.shdr.link != symtab_shndx or rels.shdr.info == std.elf.SHN_UNDEF or
                                rels.shdr.info >= ehdr.shnum) continue;
                            const Rel = switch (sht) {
                                else => comptime unreachable,
                                .REL => ElfN.Rel,
                                .RELA => ElfN.Rela,
                            };
                            if (rels.shdr.entsize < @sizeOf(Rel))
                                return diags.failParse(path, "unsupported rel entsize", .{});
                            const loc_sec = &sections[rels.shdr.info];
                            if (loc_sec.si == .null) continue;
                            const relnum = std.math.divExact(
                                u32,
                                @intCast(rels.shdr.size),
                                @intCast(rels.shdr.entsize),
                            ) catch return diags.failParse(
                                path,
                                "relocation section size (0x{x}) is not a multiple of entsize (0x{x})",
                                .{ rels.shdr.size, rels.shdr.entsize },
                            );
                            try elf.ensureUnusedRelocCapacity(loc_sec.si, relnum);
                            try fr.seekTo(fl.offset + rels.shdr.offset);
                            for (0..relnum) |_| {
                                const rel = try r.peekStruct(Rel, target_endian);
                                try r.discardAll64(rels.shdr.entsize);
                                if (rel.info.sym >= symnum) continue;
                                const target_si = symmap.items[rel.info.sym - 1];
                                if (target_si == .null) continue;
                                elf.addRelocAssumeCapacity(
                                    loc_sec.si,
                                    rel.offset - loc_sec.shdr.addr,
                                    target_si,
                                    rel.addend,
                                    .wrap(rel.info.type, elf),
                                );
                            }
                        },
                    };
                },
            };
        },
    }
}
fn loadDso(elf: *Elf, path: std.Build.Cache.Path, fr: *std.Io.File.Reader) !void {
    const comp = elf.base.comp;
    const diags = &comp.link_diags;
    const r = &fr.interface;

    log.debug("loadDso({f})", .{path.fmtEscapeString()});
    const ident = try r.peek(std.elf.EI.NIDENT);
    if (!std.mem.eql(u8, ident, elf.mf.contents[0..std.elf.EI.NIDENT]))
        return diags.failParse(path, "bad ident", .{});
    const target_endian = elf.targetEndian();
    switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |class| {
            const ElfN = class.ElfN();
            const ehdr = try r.peekStruct(ElfN.Ehdr, target_endian);
            if (ehdr.type != .DYN) return diags.failParse(path, "unsupported dso type", .{});
            if (ehdr.machine != elf.ehdrField(.machine))
                return diags.failParse(path, "bad machine", .{});
            if (ehdr.phoff == 0 or ehdr.phnum <= 1)
                return diags.failParse(path, "no program headers", .{});
            try fr.seekTo(ehdr.phoff);
            const dynamic_ph = for (0..ehdr.phnum) |_| {
                const ph = try r.peekStruct(ElfN.Phdr, target_endian);
                try r.discardAll(ehdr.phentsize);
                switch (ph.type) {
                    else => {},
                    .DYNAMIC => break ph,
                }
            } else return diags.failParse(path, "no dynamic segment", .{});
            const dynnum = std.math.divExact(
                u32,
                @intCast(dynamic_ph.filesz),
                @sizeOf(ElfN.Addr) * 2,
            ) catch return diags.failParse(
                path,
                "dynamic segment filesz (0x{x}) is not a multiple of entsize (0x{x})",
                .{ dynamic_ph.filesz, @sizeOf(ElfN.Addr) * 2 },
            );
            var strtab: ?ElfN.Addr = null;
            var strsz: ?ElfN.Addr = null;
            var soname: ?ElfN.Addr = null;
            try fr.seekTo(dynamic_ph.offset);
            for (0..dynnum) |_| {
                const tag = try r.takeInt(ElfN.Addr, target_endian);
                const val = try r.takeInt(ElfN.Addr, target_endian);
                switch (tag) {
                    else => {},
                    std.elf.DT_STRTAB => strtab = val,
                    std.elf.DT_STRSZ => strsz = val,
                    std.elf.DT_SONAME => soname = val,
                }
            }
            if (strtab == null or soname == null)
                return elf.loadDsoExact(std.fs.path.basename(path.sub_path));
            if (strsz) |size| if (soname.? >= size)
                return diags.failParse(path, "bad soname string", .{});
            try fr.seekTo(ehdr.phoff);
            const ph = for (0..ehdr.phnum) |_| {
                const ph = try r.peekStruct(ElfN.Phdr, target_endian);
                try r.discardAll(ehdr.phentsize);
                switch (ph.type) {
                    else => {},
                    .LOAD => if (strtab.? >= ph.vaddr and
                        strtab.? + (strsz orelse 0) <= ph.vaddr + ph.filesz) break ph,
                }
            } else return diags.failParse(path, "strtab not part of a loaded segment", .{});
            try fr.seekTo(strtab.? + soname.? - ph.vaddr + ph.offset);
            return elf.loadDsoExact(r.peekSentinel(0) catch |err| switch (err) {
                error.StreamTooLong => return diags.failParse(path, "soname too lang", .{}),
                else => |e| return e,
            });
        },
    }
}
fn loadDsoExact(elf: *Elf, name: []const u8) !void {
    log.debug("loadDsoExact({f})", .{std.zig.fmtString(name)});
    try elf.needed.put(elf.base.comp.gpa, try elf.string(.dynstr, name), {});
}

pub fn prelink(elf: *Elf, prog_node: std.Progress.Node) !void {
    _ = prog_node;
    elf.prelinkInner() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return elf.base.comp.link_diags.fail("prelink failed: {t}", .{e}),
    };
}
fn prelinkInner(elf: *Elf) !void {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    try elf.inputs.ensureUnusedCapacity(gpa, 1);
    const zcu_name = try std.fmt.allocPrint(gpa, "{s}_zcu", .{
        std.fs.path.stem(elf.base.emit.sub_path),
    });
    defer gpa.free(zcu_name);
    const si = try elf.initSymbolAssumeCapacity(.{ .name = zcu_name, .type = .FILE, .shndx = .ABS });
    elf.inputs.addOneAssumeCapacity().* = .{
        .path = elf.base.emit,
        .member = null,
        .si = si,
    };

    if (elf.si.dynamic != .null) switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline else => |ct_class| {
            const ElfN = ct_class.ElfN();
            const needed_len = elf.needed.count();
            const dynamic_len = needed_len + @intFromBool(elf.options.soname != null) + 5;
            const dynamic_size: u32 = @intCast(@sizeOf(ElfN.Addr) * 2 * dynamic_len);
            const dynamic_ni = elf.si.dynamic.node(elf);
            try dynamic_ni.resize(&elf.mf, gpa, dynamic_size);
            const sec_dynamic = dynamic_ni.slice(&elf.mf);
            const dynamic_entries: [][2]ElfN.Addr = @ptrCast(@alignCast(sec_dynamic));
            var dynamic_index: usize = 0;
            for (
                dynamic_entries[dynamic_index..][0..needed_len],
                elf.needed.keys(),
            ) |*dynamic_entry, needed| dynamic_entry.* = .{ std.elf.DT_NEEDED, needed };
            dynamic_index += needed_len;
            if (elf.options.soname) |soname| {
                dynamic_entries[dynamic_index] = .{ std.elf.DT_SONAME, try elf.string(.dynstr, soname) };
                dynamic_index += 1;
            }
            dynamic_entries[dynamic_index..][0..5].* = .{
                .{ std.elf.DT_SYMTAB, 0 },
                .{ std.elf.DT_SYMENT, @sizeOf(ElfN.Sym) },
                .{ std.elf.DT_STRTAB, 0 },
                .{ std.elf.DT_STRSZ, 0 },
                .{ std.elf.DT_NULL, 0 },
            };
            dynamic_index += 5;
            assert(dynamic_index == dynamic_len);
            if (elf.targetEndian() != native_endian) for (dynamic_entries) |*dynamic_entry|
                std.mem.byteSwapAllFields(@TypeOf(dynamic_entry.*), dynamic_entry);

            const dynamic_sym = elf.si.dynamic.get(elf);
            assert(dynamic_sym.loc_relocs == .none);
            dynamic_sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
            try elf.addReloc(
                elf.si.dynamic,
                @sizeOf(ElfN.Addr) * (2 * (dynamic_len - 5) + 1),
                elf.si.dynsym,
                0,
                .absAddr(elf),
            );
            try elf.addReloc(
                elf.si.dynamic,
                @sizeOf(ElfN.Addr) * (2 * (dynamic_len - 3) + 1),
                elf.si.dynstr,
                0,
                .absAddr(elf),
            );
            try elf.addReloc(
                elf.si.dynamic,
                @sizeOf(ElfN.Addr) * (2 * (dynamic_len - 2) + 1),
                elf.si.dynstr,
                0,
                .sizeAddr(elf),
            );
        },
    };
}

pub fn getNavVAddr(
    elf: *Elf,
    pt: Zcu.PerThread,
    nav: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return elf.getVAddr(reloc_info, try elf.navSymbol(pt.zcu, nav));
}

pub fn getUavVAddr(
    elf: *Elf,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return elf.getVAddr(reloc_info, try elf.uavSymbol(uav));
}

pub fn getVAddr(elf: *Elf, reloc_info: link.File.RelocInfo, target_si: Symbol.Index) !u64 {
    try elf.addReloc(
        @enumFromInt(reloc_info.parent.atom_index),
        reloc_info.offset,
        target_si,
        reloc_info.addend,
        .absAddr(elf),
    );
    return switch (elf.symPtr(target_si)) {
        inline else => |sym| elf.targetLoad(&sym.value),
    };
}

fn addSection(elf: *Elf, segment_ni: MappedFile.Node.Index, opts: struct {
    name: []const u8 = "",
    type: std.elf.SHT = .NULL,
    flags: std.elf.SHF = .{},
    size: std.elf.Xword = 0,
    link: std.elf.Word = 0,
    info: std.elf.Word = 0,
    addralign: std.mem.Alignment = .@"1",
    entsize: std.elf.Word = 0,
    node_align: std.mem.Alignment = .@"1",
}) !Symbol.Index {
    switch (opts.type) {
        .NULL => assert(opts.size == 0),
        .PROGBITS => assert(opts.size > 0),
        else => {},
    }
    const gpa = elf.base.comp.gpa;
    try elf.nodes.ensureUnusedCapacity(gpa, 1);
    try elf.shdrs.ensureUnusedCapacity(gpa, 1);
    try elf.symtab.ensureUnusedCapacity(gpa, 1);

    const shstrtab_entry = try elf.string(.shstrtab, opts.name);
    const shndx: Symbol.Index.Shndx, const new_shdr_size = shndx: switch (elf.ehdrPtr()) {
        inline else => |ehdr, class| {
            const shndx, const shnum = alloc_shndx: switch (elf.targetLoad(&ehdr.shnum)) {
                1...std.elf.SHN_LORESERVE - 2 => |shndx| {
                    const shnum = shndx + 1;
                    elf.targetStore(&ehdr.shnum, shnum);
                    break :alloc_shndx .{ shndx, shnum };
                },
                std.elf.SHN_LORESERVE - 1 => |shndx| {
                    const shnum = shndx + 1;
                    elf.targetStore(&ehdr.shnum, 0);
                    elf.targetStore(&@field(elf.shdrPtr(.UNDEF), @tagName(class)).size, shnum);
                    break :alloc_shndx .{ shndx, shnum };
                },
                std.elf.SHN_LORESERVE...std.elf.SHN_HIRESERVE => unreachable,
                0 => {
                    const shnum_ptr = &@field(elf.shdrPtr(.UNDEF), @tagName(class)).size;
                    const shndx: u32 = @intCast(elf.targetLoad(shnum_ptr));
                    const shnum = shndx + 1;
                    elf.targetStore(shnum_ptr, shnum);
                    break :alloc_shndx .{ shndx, shnum };
                },
            };
            assert(shndx < @intFromEnum(Symbol.Index.Shndx.LORESERVE));
            break :shndx .{ @enumFromInt(shndx), elf.targetLoad(&ehdr.shentsize) * shnum };
        },
    };
    _, const shdr_node_size = elf.ni.shdr.location(&elf.mf).resolve(&elf.mf);
    if (new_shdr_size > shdr_node_size)
        try elf.ni.shdr.resize(&elf.mf, gpa, new_shdr_size +| new_shdr_size / MappedFile.growth_factor);
    const ni = try elf.mf.addLastChildNode(gpa, switch (elf.ehdrField(.type)) {
        .NONE, .CORE, _ => unreachable,
        .REL => elf.ni.file,
        .EXEC, .DYN => segment_ni,
    }, .{
        .alignment = opts.addralign.max(opts.node_align),
        .size = opts.size,
        .resized = opts.size > 0,
    });
    const si = elf.addSymbolAssumeCapacity();
    elf.nodes.appendAssumeCapacity(.{ .section = si });
    elf.shdrs.appendAssumeCapacity(.{ .si = si, .rela_si = .null, .rela_free = .none });
    si.get(elf).ni = ni;
    const addr = elf.computeNodeVAddr(ni);
    const offset = ni.fileLocation(&elf.mf, false).offset;
    try si.init(elf, .{ .value = addr, .type = .SECTION, .shndx = shndx });
    switch (elf.shdrPtr(shndx)) {
        inline else => |shdr, class| {
            shdr.* = .{
                .name = shstrtab_entry,
                .type = opts.type,
                .flags = .{ .shf = opts.flags },
                .addr = @intCast(addr),
                .offset = @intCast(offset),
                .size = @intCast(opts.size),
                .link = opts.link,
                .info = opts.info,
                .addralign = @intCast(opts.addralign.toByteUnits()),
                .entsize = opts.entsize,
            };
            if (elf.targetEndian() != native_endian) std.mem.byteSwapAllFields(class.ElfN().Shdr, shdr);
        },
    }
    return si;
}

fn renameSection(elf: *Elf, si: Symbol.Index, name: []const u8) !void {
    const shstrtab_entry = try elf.string(.shstrtab, name);
    switch (elf.shdrPtr(si.shndx(elf))) {
        inline else => |shdr| elf.targetStore(&shdr.name, shstrtab_entry),
    }
}

fn linkSections(elf: *Elf, si: Symbol.Index, link_si: Symbol.Index) !void {
    switch (elf.shdrPtr(si.shndx(elf))) {
        inline else => |shdr| elf.targetStore(&shdr.link, @intFromEnum(link_si.shndx(elf))),
    }
}

fn sectionName(elf: *Elf, si: Symbol.Index) [:0]const u8 {
    const name = elf.si.shstrtab.node(elf).slice(&elf.mf)[switch (elf.shdrPtr(si.shndx(elf))) {
        inline else => |shdr| elf.targetLoad(&shdr.name),
    }..];
    return name[0..std.mem.indexOfScalar(u8, name, 0).? :0];
}

fn string(elf: *Elf, comptime section: enum { shstrtab, strtab, dynstr }, key: []const u8) !u32 {
    if (key.len == 0) return 0;
    return @field(elf, @tagName(section)).get(elf, @field(elf.si, @tagName(section)), key);
}

pub fn addReloc(
    elf: *Elf,
    loc_si: Symbol.Index,
    offset: u64,
    target_si: Symbol.Index,
    addend: i64,
    @"type": Reloc.Type,
) !void {
    try elf.ensureUnusedRelocCapacity(loc_si, 1);
    elf.addRelocAssumeCapacity(loc_si, offset, target_si, addend, @"type");
}
pub fn ensureUnusedRelocCapacity(elf: *Elf, loc_si: Symbol.Index, len: usize) !void {
    if (len == 0) return;
    const gpa = elf.base.comp.gpa;

    try elf.relocs.ensureUnusedCapacity(gpa, len);
    if (elf.ehdrField(.type) != .REL) return;

    const shndx = loc_si.shndx(elf);
    const sh = shndx.get(elf);
    if (sh.rela_si == .null) {
        var stack = std.heap.stackFallback(32, gpa);
        const allocator = stack.get();

        const rela_name = try std.fmt.allocPrint(allocator, ".rela{s}", .{elf.sectionName(sh.si)});
        defer allocator.free(rela_name);

        const class = elf.identClass();
        sh.rela_si = try elf.addSection(.none, .{
            .name = rela_name,
            .type = .RELA,
            .link = @intFromEnum(elf.si.symtab.shndx(elf)),
            .info = @intFromEnum(shndx),
            .addralign = switch (class) {
                .NONE, _ => unreachable,
                .@"32" => .@"4",
                .@"64" => .@"8",
            },
            .entsize = switch (class) {
                .NONE, _ => unreachable,
                inline else => |ct_class| @sizeOf(ct_class.ElfN().Rela),
            },
            .node_align = elf.mf.flags.block_size,
        });
    }
    const rela_ni = sh.rela_si.node(elf);
    _, const rela_node_size = rela_ni.location(&elf.mf).resolve(&elf.mf);
    const rela_size = switch (elf.shdrPtr(sh.rela_si.shndx(elf))) {
        inline else => |shdr| elf.targetLoad(&shdr.size) + elf.targetLoad(&shdr.entsize) * len,
    };
    if (rela_size > rela_node_size)
        try rela_ni.resize(&elf.mf, gpa, rela_size +| rela_size / MappedFile.growth_factor);
}
pub fn addRelocAssumeCapacity(
    elf: *Elf,
    loc_si: Symbol.Index,
    offset: u64,
    target_si: Symbol.Index,
    addend: i64,
    @"type": Reloc.Type,
) void {
    const target = target_si.get(elf);
    const ri: Reloc.Index = @enumFromInt(elf.relocs.items.len);
    elf.relocs.addOneAssumeCapacity().* = .{
        .type = @"type",
        .prev = .none,
        .next = target.target_relocs,
        .loc = loc_si,
        .target = target_si,
        .index = index: switch (elf.ehdrField(.type)) {
            .NONE, .CORE, _ => unreachable,
            .REL => {
                const sh = loc_si.shndx(elf).get(elf);
                switch (elf.shdrPtr(sh.rela_si.shndx(elf))) {
                    inline else => |shdr, class| {
                        const Rela = class.ElfN().Rela;
                        const ent_size = elf.targetLoad(&shdr.entsize);
                        const rela_slice = sh.rela_si.node(elf).slice(&elf.mf);
                        const index: u32 = if (sh.rela_free.unwrap()) |index| alloc_index: {
                            const rela: *Rela = @ptrCast(@alignCast(
                                rela_slice[@intCast(ent_size * index)..][0..@intCast(ent_size)],
                            ));
                            sh.rela_free = @enumFromInt(rela.offset);
                            break :alloc_index index;
                        } else alloc_index: {
                            const old_size = elf.targetLoad(&shdr.size);
                            const new_size = old_size + ent_size;
                            elf.targetStore(&shdr.size, @intCast(new_size));
                            break :alloc_index @intCast(@divExact(old_size, ent_size));
                        };
                        const rela: *Rela = @ptrCast(@alignCast(
                            rela_slice[@intCast(ent_size * index)..][0..@intCast(ent_size)],
                        ));
                        rela.* = .{
                            .offset = @intCast(offset),
                            .info = .{
                                .type = @intCast(@"type".unwrap(elf)),
                                .sym = @intCast(@intFromEnum(target_si)),
                            },
                            .addend = @intCast(addend),
                        };
                        if (elf.targetEndian() != native_endian) std.mem.byteSwapAllFields(Rela, rela);
                        break :index .wrap(index);
                    },
                }
            },
            .EXEC, .DYN => .none,
        },
        .offset = offset,
        .addend = addend,
    };
    switch (target.target_relocs) {
        .none => {},
        else => |target_ri| target_ri.get(elf).prev = ri,
    }
    target.target_relocs = ri;
}

pub fn updateNav(elf: *Elf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    elf.updateNavInner(pt, nav_index) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        => |e| return e,
        else => |e| return elf.base.cgFail(nav_index, "linker failed to update variable: {t}", .{e}),
    };
}
fn updateNavInner(elf: *Elf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const nav = ip.getNav(nav_index);
    const nav_val = nav.status.fully_resolved.val;
    const nav_init = switch (ip.indexToKey(nav_val)) {
        else => nav_val,
        .variable => |variable| variable.init,
        .@"extern", .func => .none,
    };
    if (nav_init == .none or !Type.fromInterned(ip.typeOf(nav_init)).hasRuntimeBits(zcu)) return;

    const nmi = try elf.navMapIndex(zcu, nav_index);
    const si = nmi.symbol(elf);
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si = elf.navSection(ip, nav.status.fully_resolved);
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{
                    .alignment = pt.navAlignment(nav_index).toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .nav = nmi });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&elf.mf, gpa, &nw);
    defer nw.deinit();
    codegen.generateSymbol(
        &elf.base,
        pt,
        zcu.navSrcLoc(nav_index),
        .fromInterned(nav_init),
        &nw.interface,
        .{ .atom_index = @intFromEnum(si) },
    ) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |e| return e,
    };
    switch (elf.symPtr(si)) {
        inline else => |sym| elf.targetStore(&sym.size, @intCast(nw.interface.end)),
    }
    si.applyLocationRelocs(elf);
}

pub fn lowerUav(
    elf: *Elf,
    pt: Zcu.PerThread,
    uav_val: InternPool.Index,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.SymbolResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    try elf.pending_uavs.ensureUnusedCapacity(gpa, 1);
    const umi = elf.uavMapIndex(uav_val) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Zcu.ErrorMsg.create(
            gpa,
            src_loc,
            "linker failed to update constant: {s}",
            .{@errorName(e)},
        ) },
    };
    const si = umi.symbol(elf);
    if (switch (si.get(elf).ni) {
        .none => true,
        else => |ni| uav_align.toStdMem().order(ni.alignment(&elf.mf)).compare(.gt),
    }) {
        const gop = elf.pending_uavs.getOrPutAssumeCapacity(umi);
        if (gop.found_existing) {
            gop.value_ptr.alignment = gop.value_ptr.alignment.max(uav_align);
        } else {
            gop.value_ptr.* = .{
                .alignment = uav_align,
                .src_loc = src_loc,
            };
            elf.const_prog_node.increaseEstimatedTotalItems(1);
        }
    }
    return .{ .sym_index = @intFromEnum(si) };
}

pub fn updateFunc(
    elf: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    elf.updateFuncInner(pt, func_index, mir) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        error.CodegenFail,
        => |e| return e,
        else => |e| return elf.base.cgFail(
            pt.zcu.funcInfo(func_index).owner_nav,
            "linker failed to update function: {s}",
            .{@errorName(e)},
        ),
    };
}
fn updateFuncInner(
    elf: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const nav = ip.getNav(func.owner_nav);

    const nmi = try elf.navMapIndex(zcu, func.owner_nav);
    const si = nmi.symbol(elf);
    log.debug("updateFunc({f}) = {d}", .{ nav.fqn.fmt(ip), si });
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si = elf.navSection(ip, nav.status.fully_resolved);
                const mod = zcu.navFileScope(func.owner_nav).mod.?;
                const target = &mod.resolved_target.result;
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{
                    .alignment = switch (nav.status.fully_resolved.alignment) {
                        .none => switch (mod.optimize_mode) {
                            .Debug,
                            .ReleaseSafe,
                            .ReleaseFast,
                            => target_util.defaultFunctionAlignment(target),
                            .ReleaseSmall => target_util.minFunctionAlignment(target),
                        },
                        else => |a| a.maxStrict(target_util.minFunctionAlignment(target)),
                    }.toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .nav = nmi });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&elf.mf, gpa, &nw);
    defer nw.deinit();
    codegen.emitFunction(
        &elf.base,
        pt,
        zcu.navSrcLoc(func.owner_nav),
        func_index,
        @intFromEnum(si),
        mir,
        &nw.interface,
        .none,
    ) catch |err| switch (err) {
        error.WriteFailed => return nw.err.?,
        else => |e| return e,
    };
    switch (elf.symPtr(si)) {
        inline else => |sym| elf.targetStore(&sym.size, @intCast(nw.interface.end)),
    }
    si.applyLocationRelocs(elf);
}

pub fn updateErrorData(elf: *Elf, pt: Zcu.PerThread) !void {
    elf.flushLazy(pt, .{
        .kind = .const_data,
        .index = @intCast(elf.lazy.getPtr(.const_data).map.getIndex(.anyerror_type) orelse return),
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.CodegenFail => return error.LinkFailure,
        else => |e| return elf.base.comp.link_diags.fail("updateErrorData failed: {t}", .{e}),
    };
}

pub fn flush(
    elf: *Elf,
    arena: std.mem.Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) !void {
    _ = arena;
    _ = prog_node;
    while (try elf.idle(tid)) {}
}

pub fn idle(elf: *Elf, tid: Zcu.PerThread.Id) !bool {
    const comp = elf.base.comp;
    task: {
        while (elf.pending_uavs.pop()) |pending_uav| {
            const sub_prog_node = elf.idleProgNode(tid, elf.const_prog_node, .{ .uav = pending_uav.key });
            defer sub_prog_node.end();
            elf.flushUav(
                .{ .zcu = comp.zcu.?, .tid = tid },
                pending_uav.key,
                pending_uav.value.alignment,
                pending_uav.value.src_loc,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return comp.link_diags.fail(
                    "linker failed to lower constant: {t}",
                    .{e},
                ),
            };
            break :task;
        }
        var lazy_it = elf.lazy.iterator();
        while (lazy_it.next()) |lazy| if (lazy.value.pending_index < lazy.value.map.count()) {
            const pt: Zcu.PerThread = .{ .zcu = comp.zcu.?, .tid = tid };
            const lmr: Node.LazyMapRef = .{ .kind = lazy.key, .index = lazy.value.pending_index };
            lazy.value.pending_index += 1;
            const kind = switch (lmr.kind) {
                .code => "code",
                .const_data => "data",
            };
            var name: [std.Progress.Node.max_name_len]u8 = undefined;
            const sub_prog_node = elf.synth_prog_node.start(
                std.fmt.bufPrint(&name, "lazy {s} for {f}", .{
                    kind,
                    Type.fromInterned(lmr.lazySymbol(elf).ty).fmt(pt),
                }) catch &name,
                0,
            );
            defer sub_prog_node.end();
            elf.flushLazy(pt, lmr) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return comp.link_diags.fail(
                    "linker failed to lower lazy {s}: {t}",
                    .{ kind, e },
                ),
            };
            break :task;
        };
        if (elf.input_section_pending_index < elf.input_sections.items.len) {
            const isi: Node.InputSectionIndex = @enumFromInt(elf.input_section_pending_index);
            elf.input_section_pending_index += 1;
            const sub_prog_node = elf.idleProgNode(tid, elf.input_prog_node, elf.getNode(isi.symbol(elf).node(elf)));
            defer sub_prog_node.end();
            elf.flushInputSection(isi) catch |err| switch (err) {
                else => |e| {
                    const ii = isi.input(elf);
                    return comp.link_diags.fail(
                        "linker failed to read input section '{s}' from \"{f}{f}\": {t}",
                        .{
                            elf.sectionName(
                                elf.getNode(isi.symbol(elf).node(elf).parent(&elf.mf)).section,
                            ),
                            ii.path(elf).fmtEscapeString(),
                            fmtMemberString(ii.member(elf)),
                            e,
                        },
                    );
                },
            };
            break :task;
        }
        while (elf.mf.updates.pop()) |ni| {
            const clean_moved = ni.cleanMoved(&elf.mf);
            const clean_resized = ni.cleanResized(&elf.mf);
            if (clean_moved or clean_resized) {
                const sub_prog_node = elf.idleProgNode(tid, elf.mf.update_prog_node, elf.getNode(ni));
                defer sub_prog_node.end();
                if (clean_moved) try elf.flushMoved(ni);
                if (clean_resized) try elf.flushResized(ni);
                break :task;
            } else elf.mf.update_prog_node.completeOne();
        }
    }
    if (elf.pending_uavs.count() > 0) return true;
    for (&elf.lazy.values) |lazy| if (lazy.map.count() > lazy.pending_index) return true;
    if (elf.input_sections.items.len > elf.input_section_pending_index) return true;
    if (elf.mf.updates.items.len > 0) return true;
    return false;
}

fn idleProgNode(
    elf: *Elf,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
    node: Node,
) std.Progress.Node {
    var name: [std.Progress.Node.max_name_len]u8 = undefined;
    return prog_node.start(name: switch (node) {
        else => |tag| @tagName(tag),
        .section => |si| elf.sectionName(si),
        .input_section => |isi| {
            const ii = isi.input(elf);
            break :name std.fmt.bufPrint(&name, "{f}{f} {s}", .{
                ii.path(elf).fmtEscapeString(),
                fmtMemberString(ii.member(elf)),
                elf.sectionName(elf.getNode(isi.symbol(elf).node(elf).parent(&elf.mf)).section),
            }) catch &name;
        },
        .nav => |nmi| {
            const ip = &elf.base.comp.zcu.?.intern_pool;
            break :name ip.getNav(nmi.navIndex(elf)).fqn.toSlice(ip);
        },
        .uav => |umi| std.fmt.bufPrint(&name, "{f}", .{
            Value.fromInterned(umi.uavValue(elf)).fmtValue(.{ .zcu = elf.base.comp.zcu.?, .tid = tid }),
        }) catch &name,
    }, 0);
}

fn flushUav(
    elf: *Elf,
    pt: Zcu.PerThread,
    umi: Node.UavMapIndex,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const uav_val = umi.uavValue(elf);
    const si = umi.symbol(elf);
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si = elf.si.data;
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{
                    .alignment = uav_align.toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .uav = umi });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => {
                if (sym.ni.alignment(&elf.mf).order(uav_align.toStdMem()).compare(.gte)) return;
                si.deleteLocationRelocs(elf);
            },
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&elf.mf, gpa, &nw);
    defer nw.deinit();
    codegen.generateSymbol(
        &elf.base,
        pt,
        src_loc,
        .fromInterned(uav_val),
        &nw.interface,
        .{ .atom_index = @intFromEnum(si) },
    ) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |e| return e,
    };
    switch (elf.symPtr(si)) {
        inline else => |sym| elf.targetStore(&sym.size, @intCast(nw.interface.end)),
    }
    si.applyLocationRelocs(elf);
}

fn flushLazy(elf: *Elf, pt: Zcu.PerThread, lmr: Node.LazyMapRef) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const lazy = lmr.lazySymbol(elf);
    const si = lmr.symbol(elf);
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si: Symbol.Index = switch (lazy.kind) {
                    .code => .text,
                    .const_data => .rodata,
                };
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{ .moved = true });
                elf.nodes.appendAssumeCapacity(switch (lazy.kind) {
                    .code => .{ .lazy_code = @enumFromInt(lmr.index) },
                    .const_data => .{ .lazy_const_data = @enumFromInt(lmr.index) },
                });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    var required_alignment: InternPool.Alignment = .none;
    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&elf.mf, gpa, &nw);
    defer nw.deinit();
    try codegen.generateLazySymbol(
        &elf.base,
        pt,
        Type.fromInterned(lazy.ty).srcLocOrNull(pt.zcu) orelse .unneeded,
        lazy,
        &required_alignment,
        &nw.interface,
        .none,
        .{ .atom_index = @intFromEnum(si) },
    );
    switch (elf.symPtr(si)) {
        inline else => |sym| elf.targetStore(&sym.size, @intCast(nw.interface.end)),
    }
    si.applyLocationRelocs(elf);
}

fn flushInputSection(elf: *Elf, isi: Node.InputSectionIndex) !void {
    const file_loc = isi.fileLocation(elf);
    if (file_loc.size == 0) return;
    const comp = elf.base.comp;
    const gpa = comp.gpa;
    const ii = isi.input(elf);
    const path = ii.path(elf);
    const file = try path.root_dir.handle.adaptToNewApi().openFile(comp.io, path.sub_path, .{});
    defer file.close(comp.io);
    var fr = file.reader(comp.io, &.{});
    try fr.seekTo(file_loc.offset);
    var nw: MappedFile.Node.Writer = undefined;
    isi.symbol(elf).node(elf).writer(&elf.mf, gpa, &nw);
    defer nw.deinit();
    if (try nw.interface.sendFileAll(&fr, .limited(@intCast(file_loc.size))) != file_loc.size)
        return error.EndOfStream;
}

fn flushFileOffset(elf: *Elf, ni: MappedFile.Node.Index) !void {
    switch (elf.getNode(ni)) {
        else => unreachable,
        .ehdr => assert(ni.fileLocation(&elf.mf, false).offset == 0),
        .shdr => switch (elf.ehdrPtr()) {
            inline else => |ehdr| elf.targetStore(
                &ehdr.shoff,
                @intCast(ni.fileLocation(&elf.mf, false).offset),
            ),
        },
        .segment => |phndx| {
            switch (elf.phdrSlice()) {
                inline else => |phdr| elf.targetStore(
                    &phdr[phndx].offset,
                    @intCast(ni.fileLocation(&elf.mf, false).offset),
                ),
            }
            var child_it = ni.children(&elf.mf);
            while (child_it.next()) |child_ni| try elf.flushFileOffset(child_ni);
        },
        .section => |si| switch (elf.shdrPtr(si.shndx(elf))) {
            inline else => |shdr| elf.targetStore(&shdr.offset, @intCast(
                ni.fileLocation(&elf.mf, false).offset,
            )),
        },
    }
}

fn flushMoved(elf: *Elf, ni: MappedFile.Node.Index) !void {
    switch (elf.getNode(ni)) {
        .file => unreachable,
        .ehdr, .shdr => try elf.flushFileOffset(ni),
        .segment => |phndx| {
            try elf.flushFileOffset(ni);
            switch (elf.phdrSlice()) {
                inline else => |phdr, class| {
                    const ph = &phdr[phndx];
                    switch (elf.targetLoad(&ph.type)) {
                        else => unreachable,
                        .NULL, .LOAD => return,
                        .DYNAMIC, .INTERP => {},
                        .PHDR => @field(elf.ehdrPtr(), @tagName(class)).phoff = ph.offset,
                        .TLS => {},
                    }
                    elf.targetStore(&ph.vaddr, @intCast(elf.computeNodeVAddr(ni)));
                    ph.paddr = ph.vaddr;
                },
            }
        },
        .section => |si| {
            try elf.flushFileOffset(ni);
            const addr = elf.computeNodeVAddr(ni);
            switch (elf.shdrPtr(si.shndx(elf))) {
                inline else => |shdr, class| {
                    const flags = elf.targetLoad(&shdr.flags).shf;
                    if (flags.ALLOC) {
                        elf.targetStore(&shdr.addr, @intCast(addr));
                        @field(elf.symPtr(si), @tagName(class)).value = shdr.addr;
                    }
                },
            }
            si.flushMoved(elf, addr);
        },
        .input_section => |isi| {
            const old_addr = switch (elf.symPtr(isi.symbol(elf))) {
                inline else => |sym| elf.targetLoad(&sym.value),
            };
            const new_addr = elf.computeNodeVAddr(ni);
            const ii = isi.input(elf);
            var si = ii.symbol(elf);
            const end_si = ii.endSymbol(elf);
            while (cond: {
                si = si.next();
                break :cond si != end_si;
            }) {
                if (si.get(elf).ni != ni) continue;
                si.flushMoved(elf, switch (elf.symPtr(si)) {
                    inline else => |sym| elf.targetLoad(&sym.value),
                } - old_addr + new_addr);
            }
        },
        inline .nav, .uav, .lazy_code, .lazy_const_data => |mi| mi.symbol(elf).flushMoved(
            elf,
            elf.computeNodeVAddr(ni),
        ),
    }
    try ni.childrenMoved(elf.base.comp.gpa, &elf.mf);
}

fn flushResized(elf: *Elf, ni: MappedFile.Node.Index) !void {
    _, const size = ni.location(&elf.mf).resolve(&elf.mf);
    switch (elf.getNode(ni)) {
        .file => {},
        .ehdr => unreachable,
        .shdr => {},
        .segment => |phndx| switch (elf.phdrSlice()) {
            inline else => |phdr| {
                assert(elf.phdrs.items[phndx] == ni);
                const ph = &phdr[phndx];
                elf.targetStore(&ph.filesz, @intCast(size));
                if (size > elf.targetLoad(&ph.memsz)) {
                    const memsz = ni.alignment(&elf.mf).forward(@intCast(size * 4));
                    elf.targetStore(&ph.memsz, @intCast(memsz));
                    switch (elf.targetLoad(&ph.type)) {
                        else => unreachable,
                        .NULL => if (size > 0) elf.targetStore(&ph.type, .LOAD),
                        .LOAD => if (size == 0) elf.targetStore(&ph.type, .NULL),
                        .DYNAMIC, .INTERP, .PHDR => return,
                        .TLS => return ni.childrenMoved(elf.base.comp.gpa, &elf.mf),
                    }
                    var vaddr = elf.targetLoad(&ph.vaddr);
                    var new_phndx = phndx;
                    for (phdr[phndx + 1 ..], phndx + 1..) |*next_ph, next_phndx| {
                        switch (elf.targetLoad(&next_ph.type)) {
                            else => unreachable,
                            .NULL, .LOAD => {},
                            .DYNAMIC, .INTERP, .PHDR, .TLS => break,
                        }
                        const next_vaddr = elf.targetLoad(&next_ph.vaddr);
                        if (vaddr + memsz <= next_vaddr) break;
                        vaddr = next_vaddr + elf.targetLoad(&next_ph.memsz);
                        std.mem.swap(@TypeOf(ph.*), &phdr[new_phndx], next_ph);
                        const next_ni = elf.phdrs.items[next_phndx];
                        elf.phdrs.items[new_phndx] = next_ni;
                        elf.nodes.items(.data)[@intFromEnum(next_ni)] = .{ .segment = new_phndx };
                        new_phndx = @intCast(next_phndx);
                    }
                    if (new_phndx != phndx) {
                        const new_ph = &phdr[new_phndx];
                        elf.targetStore(&new_ph.vaddr, vaddr);
                        new_ph.paddr = new_ph.vaddr;
                        elf.phdrs.items[new_phndx] = ni;
                        elf.nodes.items(.data)[@intFromEnum(ni)] = .{ .segment = new_phndx };
                        try ni.childrenMoved(elf.base.comp.gpa, &elf.mf);
                    }
                }
            },
        },
        .section => |si| switch (elf.shdrPtr(si.shndx(elf))) {
            inline else => |shdr| {
                switch (elf.targetLoad(&shdr.type)) {
                    else => unreachable,
                    .NULL => if (size > 0) elf.targetStore(&shdr.type, .PROGBITS),
                    .PROGBITS => if (size == 0) elf.targetStore(&shdr.type, .NULL),
                    .SYMTAB, .STRTAB, .RELA, .DYNAMIC, .REL, .DYNSYM => return,
                }
                elf.targetStore(&shdr.size, @intCast(size));
            },
        },
        .input_section => {},
        .nav, .uav, .lazy_code, .lazy_const_data => {},
    }
}

pub fn updateExports(
    elf: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    return elf.updateExportsInner(pt, exported, export_indices) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.LinkFailure => error.AnalysisFail,
        else => |e| switch (elf.base.comp.link_diags.fail(
            "linker failed to update exports: {t}",
            .{e},
        )) {
            error.LinkFailure => return error.AnalysisFail,
        },
    };
}
fn updateExportsInner(
    elf: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    switch (exported) {
        .nav => |nav| log.debug("updateExports({f})", .{ip.getNav(nav).fqn.fmt(ip)}),
        .uav => |uav| log.debug("updateExports(@as({f}, {f}))", .{
            Type.fromInterned(ip.typeOf(uav)).fmt(pt),
            Value.fromInterned(uav).fmtValue(pt),
        }),
    }
    try elf.symtab.ensureUnusedCapacity(gpa, export_indices.len);
    const exported_si: Symbol.Index, const @"type": std.elf.STT = switch (exported) {
        .nav => |nav| .{
            try elf.navSymbol(zcu, nav),
            navType(ip, ip.getNav(nav).status, elf.base.comp.config.any_non_single_threaded),
        },
        .uav => |uav| .{ @enumFromInt(switch (try elf.lowerUav(
            pt,
            uav,
            Type.fromInterned(ip.typeOf(uav)).abiAlignment(zcu),
            export_indices[0].ptr(zcu).src,
        )) {
            .sym_index => |si| si,
            .fail => |em| {
                defer em.destroy(gpa);
                return elf.base.comp.link_diags.fail("{s}", .{em.msg});
            },
        }), .OBJECT },
    };
    while (try elf.idle(pt.tid)) {}
    const exported_ni = exported_si.node(elf);
    const value, const size, const shndx = switch (elf.symPtr(exported_si)) {
        inline else => |exported_sym| .{ exported_sym.value, exported_sym.size, exported_sym.shndx },
    };
    for (export_indices) |export_index| {
        const @"export" = export_index.ptr(zcu);
        const name = @"export".opts.name.toSlice(ip);
        const export_si = try elf.globalSymbol(.{
            .name = name,
            .type = @"type",
            .bind = switch (@"export".opts.linkage) {
                .internal => .LOCAL,
                .strong => .GLOBAL,
                .weak => .WEAK,
                .link_once => return error.LinkOnceUnsupported,
            },
            .visibility = switch (@"export".opts.visibility) {
                .default => .DEFAULT,
                .hidden => .HIDDEN,
                .protected => .PROTECTED,
            },
        });
        export_si.get(elf).ni = exported_ni;
        switch (elf.symPtr(export_si)) {
            inline else => |export_sym| {
                export_sym.value = @intCast(value);
                export_sym.size = @intCast(size);
                export_sym.shndx = shndx;
            },
        }
        export_si.applyTargetRelocs(elf);
        if (std.mem.eql(u8, name, "_start")) {
            elf.entry_hack = exported_si;
            switch (elf.ehdrPtr()) {
                inline else => |ehdr| ehdr.entry = @intCast(value),
            }
        }
    }
}

pub fn deleteExport(elf: *Elf, exported: Zcu.Exported, name: InternPool.NullTerminatedString) void {
    _ = elf;
    _ = exported;
    _ = name;
}

pub fn dump(elf: *Elf, tid: Zcu.PerThread.Id) void {
    const w, _ = std.debug.lockStderrWriter(&.{});
    defer std.debug.unlockStderrWriter();
    elf.printNode(tid, w, .root, 0) catch {};
}

pub fn printNode(
    elf: *Elf,
    tid: Zcu.PerThread.Id,
    w: *std.Io.Writer,
    ni: MappedFile.Node.Index,
    indent: usize,
) !void {
    const node = elf.getNode(ni);
    try w.splatByteAll(' ', indent);
    try w.writeAll(@tagName(node));
    switch (node) {
        else => {},
        .segment => |phndx| switch (elf.phdrSlice()) {
            inline else => |phdr| {
                const ph = &phdr[phndx];
                try w.writeByte('(');
                const pt = elf.targetLoad(&ph.type);
                if (std.enums.tagName(std.elf.PT, pt)) |pt_name|
                    try w.writeAll(pt_name)
                else inline for (@typeInfo(std.elf.PT).@"enum".decls) |decl| {
                    const decl_val = @field(std.elf.PT, decl.name);
                    if (@TypeOf(decl_val) != std.elf.PT) continue;
                    if (pt == @field(std.elf.PT, decl.name)) break try w.writeAll(decl.name);
                } else try w.print("0x{x}", .{pt});
                try w.writeAll(", ");
                const pf = elf.targetLoad(&ph.flags);
                if (pf.R) try w.writeByte('R');
                if (pf.W) try w.writeByte('W');
                if (pf.X) try w.writeByte('X');
                try w.writeByte(')');
            },
        },
        .section => |si| try w.print("({s})", .{elf.sectionName(si)}),
        .input_section => |isi| {
            const ii = isi.input(elf);
            try w.print("({f}{f}, {s})", .{
                ii.path(elf).fmtEscapeString(),
                fmtMemberString(ii.member(elf)),
                elf.sectionName(elf.getNode(isi.symbol(elf).node(elf).parent(&elf.mf)).section),
            });
        },
        .nav => |nmi| {
            const zcu = elf.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            const nav = ip.getNav(nmi.navIndex(elf));
            try w.print("({f}, {f})", .{
                Type.fromInterned(nav.typeOf(ip)).fmt(.{ .zcu = zcu, .tid = tid }),
                nav.fqn.fmt(ip),
            });
        },
        .uav => |umi| {
            const zcu = elf.base.comp.zcu.?;
            const val: Value = .fromInterned(umi.uavValue(elf));
            try w.print("({f}, {f})", .{
                val.typeOf(zcu).fmt(.{ .zcu = zcu, .tid = tid }),
                val.fmtValue(.{ .zcu = zcu, .tid = tid }),
            });
        },
        inline .lazy_code, .lazy_const_data => |lmi| try w.print("({f})", .{
            Type.fromInterned(lmi.lazySymbol(elf).ty).fmt(.{
                .zcu = elf.base.comp.zcu.?,
                .tid = tid,
            }),
        }),
    }
    {
        const mf_node = &elf.mf.nodes.items[@intFromEnum(ni)];
        const off, const size = mf_node.location().resolve(&elf.mf);
        try w.print(" index={d} offset=0x{x} size=0x{x} align=0x{x}{s}{s}{s}{s}\n", .{
            @intFromEnum(ni),
            off,
            size,
            mf_node.flags.alignment.toByteUnits(),
            if (mf_node.flags.fixed) " fixed" else "",
            if (mf_node.flags.moved) " moved" else "",
            if (mf_node.flags.resized) " resized" else "",
            if (mf_node.flags.has_content) " has_content" else "",
        });
    }
    var leaf = true;
    var child_it = ni.children(&elf.mf);
    while (child_it.next()) |child_ni| {
        leaf = false;
        try elf.printNode(tid, w, child_ni, indent + 1);
    }
    if (!leaf) return;
    const file_loc = ni.fileLocation(&elf.mf, false);
    var address = file_loc.offset;
    if (file_loc.size == 0) {
        try w.splatByteAll(' ', indent + 1);
        try w.print("{x:0>8}\n", .{address});
        return;
    }
    const line_len = 0x10;
    var line_it = std.mem.window(
        u8,
        elf.mf.contents[@intCast(file_loc.offset)..][0..@intCast(file_loc.size)],
        line_len,
        line_len,
    );
    while (line_it.next()) |line_bytes| : (address += line_len) {
        try w.splatByteAll(' ', indent + 1);
        try w.print("{x:0>8}  ", .{address});
        for (line_bytes) |byte| try w.print("{x:0>2} ", .{byte});
        try w.splatByteAll(' ', 3 * (line_len - line_bytes.len) + 1);
        for (line_bytes) |byte| try w.writeByte(if (std.ascii.isPrint(byte)) byte else '.');
        try w.writeByte('\n');
    }
}

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../codegen.zig");
const Compilation = @import("../Compilation.zig");
const Elf = @This();
const InternPool = @import("../InternPool.zig");
const link = @import("../link.zig");
const log = std.log.scoped(.link);
const MappedFile = @import("MappedFile.zig");
const native_endian = builtin.cpu.arch.endian();
const std = @import("std");
const target_util = @import("../target.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
