const std = @import("std");
const aarch64 = @import("../../codegen/aarch64.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.reloc);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const Allocator = mem.Allocator;

pub const Relocation = struct {
    @"type": Type,
    code: []u8,
    offset: u32,
    target: Target,

    pub fn cast(base: *Relocation, comptime T: type) ?*T {
        if (base.@"type" != T.base_type)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub const ResolveArgs = struct {
        source_addr: u64,
        target_addr: u64,
        subtractor: ?u64,
    };

    pub fn resolve(base: *Relocation, args: ResolveArgs) !void {
        log.debug("{s}", .{base.@"type"});
        log.debug("    | offset 0x{x}", .{base.offset});
        log.debug("    | source address 0x{x}", .{args.source_addr});
        log.debug("    | target address 0x{x}", .{args.target_addr});
        if (args.subtractor) |sub|
            log.debug("    | subtractor address 0x{x}", .{sub});

        return switch (base.@"type") {
            .branch => @fieldParentPtr(Branch, "base", base).resolve(args.source_addr, args.target_addr),
            .unsigned => @fieldParentPtr(Unsigned, "base", base).resolve(args.target_addr, args.subtractor),
            .page => @fieldParentPtr(Page, "base", base).resolve(args.source_addr, args.target_addr),
            .page_off => @fieldParentPtr(PageOff, "base", base).resolve(args.target_addr),
            .got_page => @fieldParentPtr(GotPage, "base", base).resolve(args.source_addr, args.target_addr),
            .got_page_off => @fieldParentPtr(GotPageOff, "base", base).resolve(args.target_addr),
            .tlvp_page => @fieldParentPtr(TlvpPage, "base", base).resolve(args.source_addr, args.target_addr),
            .tlvp_page_off => @fieldParentPtr(TlvpPageOff, "base", base).resolve(args.target_addr),
        };
    }

    pub const Type = enum {
        branch,
        unsigned,
        page,
        page_off,
        got_page,
        got_page_off,
        tlvp_page,
        tlvp_page_off,
    };

    pub const Target = union(enum) {
        symbol: u32,
        section: u16,

        pub fn from_reloc(reloc: macho.relocation_info) Target {
            return if (reloc.r_extern == 1) .{
                .symbol = reloc.r_symbolnum,
            } else .{
                .section = @intCast(u16, reloc.r_symbolnum - 1),
            };
        }
    };

    pub const Branch = struct {
        base: Relocation,
        /// Always .UnconditionalBranchImmediate
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .branch;

        pub fn resolve(branch: Branch, source_addr: u64, target_addr: u64) !void {
            const displacement = try math.cast(i28, @intCast(i64, target_addr) - @intCast(i64, source_addr));

            log.debug("    | displacement 0x{x}", .{displacement});

            var inst = branch.inst;
            inst.UnconditionalBranchImmediate.imm26 = @truncate(u26, @bitCast(u28, displacement) >> 2);
            mem.writeIntLittle(u32, branch.base.code[0..4], inst.toU32());
        }
    };

    pub const Unsigned = struct {
        base: Relocation,
        subtractor: ?Target = null,
        /// Addend embedded directly in the relocation slot
        addend: i64,
        /// Extracted from r_length:
        /// => 3 implies true
        /// => 2 implies false
        /// => * is unreachable
        is_64bit: bool,

        pub const base_type: Relocation.Type = .unsigned;

        pub fn resolve(unsigned: Unsigned, target_addr: u64, subtractor: ?u64) !void {
            const result = if (subtractor) |sub|
                @intCast(i64, target_addr) - @intCast(i64, sub) + unsigned.addend
            else
                @intCast(i64, target_addr) + unsigned.addend;

            log.debug("    | calculated addend 0x{x}", .{unsigned.addend});
            log.debug("    | calculated unsigned value 0x{x}", .{result});

            if (unsigned.is_64bit) {
                mem.writeIntLittle(
                    u64,
                    unsigned.base.code[0..8],
                    @bitCast(u64, result),
                );
            } else {
                mem.writeIntLittle(
                    u32,
                    unsigned.base.code[0..4],
                    @truncate(u32, @bitCast(u64, result)),
                );
            }
        }
    };

    pub const Page = struct {
        base: Relocation,
        addend: ?u32 = null,
        /// Always .PCRelativeAddress
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .page;

        pub fn resolve(page: Page, source_addr: u64, target_addr: u64) !void {
            const ta = if (page.addend) |a| target_addr + a else target_addr;
            const source_page = @intCast(i32, source_addr >> 12);
            const target_page = @intCast(i32, ta >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));

            log.debug("    | calculated addend 0x{x}", .{page.addend});
            log.debug("    | moving by {} pages", .{pages});

            var inst = page.inst;
            inst.PCRelativeAddress.immhi = @truncate(u19, pages >> 2);
            inst.PCRelativeAddress.immlo = @truncate(u2, pages);

            mem.writeIntLittle(u32, page.base.code[0..4], inst.toU32());
        }
    };

    pub const PageOff = struct {
        base: Relocation,
        addend: ?u32 = null,
        op_kind: OpKind,
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .page_off;

        pub const OpKind = enum {
            arithmetic,
            load_store,
        };

        pub fn resolve(page_off: PageOff, target_addr: u64) !void {
            const ta = if (page_off.addend) |a| target_addr + a else target_addr;
            const narrowed = @truncate(u12, ta);

            log.debug("    | narrowed address within the page 0x{x}", .{narrowed});
            log.debug("    | {s} opcode", .{page_off.op_kind});

            var inst = page_off.inst;
            if (page_off.op_kind == .arithmetic) {
                inst.AddSubtractImmediate.imm12 = narrowed;
            } else {
                const offset: u12 = blk: {
                    if (inst.LoadStoreRegister.size == 0) {
                        if (inst.LoadStoreRegister.v == 1) {
                            // 128-bit SIMD is scaled by 16.
                            break :blk try math.divExact(u12, narrowed, 16);
                        }
                        // Otherwise, 8-bit SIMD or ldrb.
                        break :blk narrowed;
                    } else {
                        const denom: u4 = try math.powi(u4, 2, inst.LoadStoreRegister.size);
                        break :blk try math.divExact(u12, narrowed, denom);
                    }
                };
                inst.LoadStoreRegister.offset = offset;
            }

            mem.writeIntLittle(u32, page_off.base.code[0..4], inst.toU32());
        }
    };

    pub const GotPage = struct {
        base: Relocation,
        /// Always .PCRelativeAddress
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .got_page;

        pub fn resolve(page: GotPage, source_addr: u64, target_addr: u64) !void {
            const source_page = @intCast(i32, source_addr >> 12);
            const target_page = @intCast(i32, target_addr >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));

            log.debug("    | moving by {} pages", .{pages});

            var inst = page.inst;
            inst.PCRelativeAddress.immhi = @truncate(u19, pages >> 2);
            inst.PCRelativeAddress.immlo = @truncate(u2, pages);

            mem.writeIntLittle(u32, page.base.code[0..4], inst.toU32());
        }
    };

    pub const GotPageOff = struct {
        base: Relocation,
        /// Always .LoadStoreRegister with size = 3 for GOT indirection
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .got_page_off;

        pub fn resolve(page_off: GotPageOff, target_addr: u64) !void {
            const narrowed = @truncate(u12, target_addr);

            log.debug("    | narrowed address within the page 0x{x}", .{narrowed});

            var inst = page_off.inst;
            const offset = try math.divExact(u12, narrowed, 8);
            inst.LoadStoreRegister.offset = offset;

            mem.writeIntLittle(u32, page_off.base.code[0..4], inst.toU32());
        }
    };

    pub const TlvpPage = struct {
        base: Relocation,
        /// Always .PCRelativeAddress
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .tlvp_page;

        pub fn resolve(page: TlvpPage, source_addr: u64, target_addr: u64) !void {
            const source_page = @intCast(i32, source_addr >> 12);
            const target_page = @intCast(i32, target_addr >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));

            log.debug("    | moving by {} pages", .{pages});

            var inst = page.inst;
            inst.PCRelativeAddress.immhi = @truncate(u19, pages >> 2);
            inst.PCRelativeAddress.immlo = @truncate(u2, pages);

            mem.writeIntLittle(u32, page.base.code[0..4], inst.toU32());
        }
    };

    pub const TlvpPageOff = struct {
        base: Relocation,
        /// Always .AddSubtractImmediate regardless of the source instruction.
        /// This means, we always rewrite the instruction to add even if the
        /// source instruction was an ldr.
        inst: aarch64.Instruction,

        pub const base_type: Relocation.Type = .tlvp_page_off;

        pub fn resolve(page_off: TlvpPageOff, target_addr: u64) !void {
            const narrowed = @truncate(u12, target_addr);

            log.debug("    | narrowed address within the page 0x{x}", .{narrowed});

            var inst = page_off.inst;
            inst.AddSubtractImmediate.imm12 = narrowed;

            mem.writeIntLittle(u32, page_off.base.code[0..4], inst.toU32());
        }
    };
};

pub fn parse(allocator: *Allocator, code: []u8, relocs: []const macho.relocation_info) ![]*Relocation {
    var it = RelocIterator{
        .buffer = relocs,
    };

    var parser = Parser{
        .allocator = allocator,
        .it = &it,
        .code = code,
        .parsed = std.ArrayList(*Relocation).init(allocator),
    };
    defer parser.deinit();
    try parser.parse();

    return parser.parsed.toOwnedSlice();
}

const RelocIterator = struct {
    buffer: []const macho.relocation_info,
    index: i64 = -1,

    pub fn next(self: *RelocIterator) ?macho.relocation_info {
        self.index += 1;
        if (self.index < self.buffer.len) {
            const reloc = self.buffer[@intCast(u64, self.index)];
            log.debug("{s}", .{@intToEnum(macho.reloc_type_arm64, reloc.r_type)});
            log.debug("    | offset = {}", .{reloc.r_address});
            log.debug("    | PC = {}", .{reloc.r_pcrel == 1});
            log.debug("    | length = {}", .{reloc.r_length});
            log.debug("    | symbolnum = {}", .{reloc.r_symbolnum});
            log.debug("    | extern = {}", .{reloc.r_extern == 1});
            return reloc;
        }
        return null;
    }

    pub fn peek(self: *RelocIterator) ?macho.reloc_type_arm64 {
        if (self.index + 1 < self.buffer.len) {
            const reloc = self.buffer[@intCast(u64, self.index + 1)];
            const tt = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
            return tt;
        }
        return null;
    }
};

const Parser = struct {
    allocator: *Allocator,
    it: *RelocIterator,
    code: []u8,
    parsed: std.ArrayList(*Relocation),
    addend: ?u32 = null,
    subtractor: ?Relocation.Target = null,

    fn deinit(parser: *Parser) void {
        parser.parsed.deinit();
    }

    fn parse(parser: *Parser) !void {
        while (parser.it.next()) |reloc| {
            switch (@intToEnum(macho.reloc_type_arm64, reloc.r_type)) {
                .ARM64_RELOC_BRANCH26 => {
                    try parser.parseBranch(reloc);
                },
                .ARM64_RELOC_SUBTRACTOR => {
                    try parser.parseSubtractor(reloc);
                },
                .ARM64_RELOC_UNSIGNED => {
                    try parser.parseUnsigned(reloc);
                },
                .ARM64_RELOC_ADDEND => {
                    try parser.parseAddend(reloc);
                },
                .ARM64_RELOC_PAGE21,
                .ARM64_RELOC_GOT_LOAD_PAGE21,
                .ARM64_RELOC_TLVP_LOAD_PAGE21,
                => {
                    try parser.parsePage(reloc);
                },
                .ARM64_RELOC_PAGEOFF12 => {
                    try parser.parsePageOff(reloc);
                },
                .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => {
                    try parser.parseGotLoadPageOff(reloc);
                },
                .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
                    try parser.parseTlvpLoadPageOff(reloc);
                },
                .ARM64_RELOC_POINTER_TO_GOT => {
                    return error.ToDoRelocPointerToGot;
                },
            }
        }
    }

    fn parseAddend(parser: *Parser, reloc: macho.relocation_info) !void {
        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_ADDEND);
        assert(reloc.r_pcrel == 0);
        assert(reloc.r_extern == 0);
        assert(parser.addend == null);

        parser.addend = reloc.r_symbolnum;

        // Verify ADDEND is followed by a load.
        if (parser.it.peek()) |tt| {
            switch (tt) {
                .ARM64_RELOC_PAGE21, .ARM64_RELOC_PAGEOFF12 => {},
                else => |other| {
                    log.err("unexpected relocation type: expected PAGE21 or PAGEOFF12, found {s}", .{other});
                    return error.UnexpectedRelocationType;
                },
            }
        } else {
            log.err("unexpected end of stream", .{});
            return error.UnexpectedEndOfStream;
        }
    }

    fn parseBranch(parser: *Parser, reloc: macho.relocation_info) !void {
        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_BRANCH26);
        assert(reloc.r_pcrel == 1);
        assert(reloc.r_length == 2);

        const offset = @intCast(u32, reloc.r_address);
        const inst = parser.code[offset..][0..4];
        const parsed_inst = aarch64.Instruction{ .UnconditionalBranchImmediate = mem.bytesToValue(
            meta.TagPayload(
                aarch64.Instruction,
                aarch64.Instruction.UnconditionalBranchImmediate,
            ),
            inst,
        ) };

        var branch = try parser.allocator.create(Relocation.Branch);
        errdefer parser.allocator.destroy(branch);

        const target = Relocation.Target.from_reloc(reloc);

        branch.* = .{
            .base = .{
                .@"type" = .branch,
                .code = inst,
                .offset = @intCast(u32, reloc.r_address),
                .target = target,
            },
            .inst = parsed_inst,
        };

        log.debug("    | emitting {}", .{branch});
        try parser.parsed.append(&branch.base);
    }

    fn parsePage(parser: *Parser, reloc: macho.relocation_info) !void {
        assert(reloc.r_pcrel == 1);
        assert(reloc.r_length == 2);

        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        const target = Relocation.Target.from_reloc(reloc);

        const offset = @intCast(u32, reloc.r_address);
        const inst = parser.code[offset..][0..4];
        const parsed_inst = aarch64.Instruction{ .PCRelativeAddress = mem.bytesToValue(meta.TagPayload(
            aarch64.Instruction,
            aarch64.Instruction.PCRelativeAddress,
        ), inst) };

        const ptr: *Relocation = ptr: {
            switch (reloc_type) {
                .ARM64_RELOC_PAGE21 => {
                    defer {
                        // Reset parser's addend state
                        parser.addend = null;
                    }
                    var page = try parser.allocator.create(Relocation.Page);
                    errdefer parser.allocator.destroy(page);

                    page.* = .{
                        .base = .{
                            .@"type" = .page,
                            .code = inst,
                            .offset = offset,
                            .target = target,
                        },
                        .addend = parser.addend,
                        .inst = parsed_inst,
                    };

                    log.debug("    | emitting {}", .{page});

                    break :ptr &page.base;
                },
                .ARM64_RELOC_GOT_LOAD_PAGE21 => {
                    var page = try parser.allocator.create(Relocation.GotPage);
                    errdefer parser.allocator.destroy(page);

                    page.* = .{
                        .base = .{
                            .@"type" = .got_page,
                            .code = inst,
                            .offset = offset,
                            .target = target,
                        },
                        .inst = parsed_inst,
                    };

                    log.debug("    | emitting {}", .{page});

                    break :ptr &page.base;
                },
                .ARM64_RELOC_TLVP_LOAD_PAGE21 => {
                    var page = try parser.allocator.create(Relocation.TlvpPage);
                    errdefer parser.allocator.destroy(page);

                    page.* = .{
                        .base = .{
                            .@"type" = .tlvp_page,
                            .code = inst,
                            .offset = offset,
                            .target = target,
                        },
                        .inst = parsed_inst,
                    };

                    log.debug("    | emitting {}", .{page});

                    break :ptr &page.base;
                },
                else => unreachable,
            }
        };

        try parser.parsed.append(ptr);
    }

    fn parsePageOff(parser: *Parser, reloc: macho.relocation_info) !void {
        defer {
            // Reset parser's addend state
            parser.addend = null;
        }

        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_PAGEOFF12);
        assert(reloc.r_pcrel == 0);
        assert(reloc.r_length == 2);

        const offset = @intCast(u32, reloc.r_address);
        const inst = parser.code[offset..][0..4];

        var op_kind: Relocation.PageOff.OpKind = undefined;
        var parsed_inst: aarch64.Instruction = undefined;
        if (isArithmeticOp(inst)) {
            op_kind = .arithmetic;
            parsed_inst = .{ .AddSubtractImmediate = mem.bytesToValue(meta.TagPayload(
                aarch64.Instruction,
                aarch64.Instruction.AddSubtractImmediate,
            ), inst) };
        } else {
            op_kind = .load_store;
            parsed_inst = .{ .LoadStoreRegister = mem.bytesToValue(meta.TagPayload(
                aarch64.Instruction,
                aarch64.Instruction.LoadStoreRegister,
            ), inst) };
        }
        const target = Relocation.Target.from_reloc(reloc);

        var page_off = try parser.allocator.create(Relocation.PageOff);
        errdefer parser.allocator.destroy(page_off);

        page_off.* = .{
            .base = .{
                .@"type" = .page_off,
                .code = inst,
                .offset = offset,
                .target = target,
            },
            .op_kind = op_kind,
            .inst = parsed_inst,
            .addend = parser.addend,
        };

        log.debug("    | emitting {}", .{page_off});
        try parser.parsed.append(&page_off.base);
    }

    fn parseGotLoadPageOff(parser: *Parser, reloc: macho.relocation_info) !void {
        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_GOT_LOAD_PAGEOFF12);
        assert(reloc.r_pcrel == 0);
        assert(reloc.r_length == 2);

        const offset = @intCast(u32, reloc.r_address);
        const inst = parser.code[offset..][0..4];
        assert(!isArithmeticOp(inst));

        const parsed_inst = mem.bytesToValue(meta.TagPayload(
            aarch64.Instruction,
            aarch64.Instruction.LoadStoreRegister,
        ), inst);
        assert(parsed_inst.size == 3);

        const target = Relocation.Target.from_reloc(reloc);

        var page_off = try parser.allocator.create(Relocation.GotPageOff);
        errdefer parser.allocator.destroy(page_off);

        page_off.* = .{
            .base = .{
                .@"type" = .got_page_off,
                .code = inst,
                .offset = offset,
                .target = target,
            },
            .inst = .{
                .LoadStoreRegister = parsed_inst,
            },
        };

        log.debug("    | emitting {}", .{page_off});
        try parser.parsed.append(&page_off.base);
    }

    fn parseTlvpLoadPageOff(parser: *Parser, reloc: macho.relocation_info) !void {
        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_TLVP_LOAD_PAGEOFF12);
        assert(reloc.r_pcrel == 0);
        assert(reloc.r_length == 2);

        const RegInfo = struct {
            rd: u5,
            rn: u5,
            size: u1,
        };

        const offset = @intCast(u32, reloc.r_address);
        const inst = parser.code[offset..][0..4];
        const parsed: RegInfo = parsed: {
            if (isArithmeticOp(inst)) {
                const parsed_inst = mem.bytesAsValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.AddSubtractImmediate,
                ), inst);
                break :parsed .{
                    .rd = parsed_inst.rd,
                    .rn = parsed_inst.rn,
                    .size = parsed_inst.sf,
                };
            } else {
                const parsed_inst = mem.bytesAsValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.LoadStoreRegister,
                ), inst);
                break :parsed .{
                    .rd = parsed_inst.rt,
                    .rn = parsed_inst.rn,
                    .size = @truncate(u1, parsed_inst.size),
                };
            }
        };

        const target = Relocation.Target.from_reloc(reloc);

        var page_off = try parser.allocator.create(Relocation.TlvpPageOff);
        errdefer parser.allocator.destroy(page_off);

        page_off.* = .{
            .base = .{
                .@"type" = .tlvp_page_off,
                .code = inst,
                .offset = @intCast(u32, reloc.r_address),
                .target = target,
            },
            .inst = .{
                .AddSubtractImmediate = .{
                    .rd = parsed.rd,
                    .rn = parsed.rn,
                    .imm12 = 0, // This will be filled when target addresses are known.
                    .sh = 0,
                    .s = 0,
                    .op = 0,
                    .sf = parsed.size,
                },
            },
        };

        log.debug("    | emitting {}", .{page_off});
        try parser.parsed.append(&page_off.base);
    }

    fn parseSubtractor(parser: *Parser, reloc: macho.relocation_info) !void {
        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_SUBTRACTOR);
        assert(reloc.r_pcrel == 0);
        assert(parser.subtractor == null);

        parser.subtractor = Relocation.Target.from_reloc(reloc);

        // Verify SUBTRACTOR is followed by UNSIGNED.
        if (parser.it.peek()) |tt| {
            if (tt != .ARM64_RELOC_UNSIGNED) {
                log.err("unexpected relocation type: expected UNSIGNED, found {s}", .{tt});
                return error.UnexpectedRelocationType;
            }
        } else {
            log.err("unexpected end of stream", .{});
            return error.UnexpectedEndOfStream;
        }
    }

    fn parseUnsigned(parser: *Parser, reloc: macho.relocation_info) !void {
        defer {
            // Reset parser's subtractor state
            parser.subtractor = null;
        }

        const reloc_type = @intToEnum(macho.reloc_type_arm64, reloc.r_type);
        assert(reloc_type == .ARM64_RELOC_UNSIGNED);
        assert(reloc.r_pcrel == 0);

        var unsigned = try parser.allocator.create(Relocation.Unsigned);
        errdefer parser.allocator.destroy(unsigned);

        const target = Relocation.Target.from_reloc(reloc);
        const is_64bit: bool = switch (reloc.r_length) {
            3 => true,
            2 => false,
            else => unreachable,
        };
        const offset = @intCast(u32, reloc.r_address);
        const addend: i64 = if (is_64bit)
            mem.readIntLittle(i64, parser.code[offset..][0..8])
        else
            mem.readIntLittle(i32, parser.code[offset..][0..4]);

        unsigned.* = .{
            .base = .{
                .@"type" = .unsigned,
                .code = if (is_64bit) parser.code[offset..][0..8] else parser.code[offset..][0..4],
                .offset = offset,
                .target = target,
            },
            .subtractor = parser.subtractor,
            .is_64bit = is_64bit,
            .addend = addend,
        };

        log.debug("    | emitting {}", .{unsigned});
        try parser.parsed.append(&unsigned.base);
    }
};

fn isArithmeticOp(inst: *const [4]u8) callconv(.Inline) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}
