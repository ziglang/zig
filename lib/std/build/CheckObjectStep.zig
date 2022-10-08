const std = @import("../std.zig");
const assert = std.debug.assert;
const build = std.build;
const fs = std.fs;
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const CheckObjectStep = @This();

const Allocator = mem.Allocator;
const Builder = build.Builder;
const Step = build.Step;
const EmulatableRunStep = build.EmulatableRunStep;

pub const base_id = .check_object;

step: Step,
builder: *Builder,
source: build.FileSource,
max_bytes: usize = 20 * 1024 * 1024,
checks: std.ArrayList(Check),
dump_symtab: bool = false,
obj_format: std.Target.ObjectFormat,

pub fn create(builder: *Builder, source: build.FileSource, obj_format: std.Target.ObjectFormat) *CheckObjectStep {
    const gpa = builder.allocator;
    const self = gpa.create(CheckObjectStep) catch unreachable;
    self.* = .{
        .builder = builder,
        .step = Step.init(.check_file, "CheckObject", gpa, make),
        .source = source.dupe(builder),
        .checks = std.ArrayList(Check).init(gpa),
        .obj_format = obj_format,
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

/// Runs and (optionally) compares the output of a binary.
/// Asserts `self` was generated from an executable step.
pub fn runAndCompare(self: *CheckObjectStep) *EmulatableRunStep {
    const dependencies_len = self.step.dependencies.items.len;
    assert(dependencies_len > 0);
    const exe_step = self.step.dependencies.items[dependencies_len - 1];
    const exe = exe_step.cast(std.build.LibExeObjStep).?;
    return EmulatableRunStep.create(self.builder, "EmulatableRun", exe);
}

/// There two types of actions currently suported:
/// * `.match` - is the main building block of standard matchers with optional eat-all token `{*}`
/// and extractors by name such as `{n_value}`. Please note this action is very simplistic in nature
/// i.e., it won't really handle edge cases/nontrivial examples. But given that we do want to use
/// it mainly to test the output of our object format parser-dumpers when testing the linkers, etc.
/// it should be plenty useful in its current form.
/// * `.compute_cmp` - can be used to perform an operation on the extracted global variables
/// using the MatchAction. It currently only supports an addition. The operation is required
/// to be specified in Reverse Polish Notation to ease in operator-precedence parsing (well,
/// to avoid any parsing really).
/// For example, if the two extracted values were saved as `vmaddr` and `entryoff` respectively
/// they could then be added with this simple program `vmaddr entryoff +`.
const Action = struct {
    tag: enum { match, not_present, compute_cmp },
    phrase: []const u8,
    expected: ?ComputeCompareExpected = null,

    /// Will return true if the `phrase` was found in the `haystack`.
    /// Some examples include:
    ///
    /// LC 0                     => will match in its entirety
    /// vmaddr {vmaddr}          => will match `vmaddr` and then extract the following value as u64
    ///                             and save under `vmaddr` global name (see `global_vars` param)
    /// name {*}libobjc{*}.dylib => will match `name` followed by a token which contains `libobjc` and `.dylib`
    ///                             in that order with other letters in between
    fn match(act: Action, haystack: []const u8, global_vars: anytype) !bool {
        assert(act.tag == .match or act.tag == .not_present);

        var candidate_var: ?struct { name: []const u8, value: u64 } = null;
        var hay_it = mem.tokenize(u8, mem.trim(u8, haystack, " "), " ");
        var needle_it = mem.tokenize(u8, mem.trim(u8, act.phrase, " "), " ");

        while (needle_it.next()) |needle_tok| {
            const hay_tok = hay_it.next() orelse return false;

            if (mem.indexOf(u8, needle_tok, "{*}")) |index| {
                // We have fuzzy matchers within the search pattern, so we match substrings.
                var start = index;
                var n_tok = needle_tok;
                var h_tok = hay_tok;
                while (true) {
                    n_tok = n_tok[start + 3 ..];
                    const inner = if (mem.indexOf(u8, n_tok, "{*}")) |sub_end|
                        n_tok[0..sub_end]
                    else
                        n_tok;
                    if (mem.indexOf(u8, h_tok, inner) == null) return false;
                    start = mem.indexOf(u8, n_tok, "{*}") orelse break;
                }
            } else if (mem.startsWith(u8, needle_tok, "{")) {
                const closing_brace = mem.indexOf(u8, needle_tok, "}") orelse return error.MissingClosingBrace;
                if (closing_brace != needle_tok.len - 1) return error.ClosingBraceNotLast;

                const name = needle_tok[1..closing_brace];
                if (name.len == 0) return error.MissingBraceValue;
                const value = try std.fmt.parseInt(u64, hay_tok, 16);
                candidate_var = .{
                    .name = name,
                    .value = value,
                };
            } else {
                if (!mem.eql(u8, hay_tok, needle_tok)) return false;
            }
        }

        if (candidate_var) |v| {
            try global_vars.putNoClobber(v.name, v.value);
        }

        return true;
    }

    /// Will return true if the `phrase` is correctly parsed into an RPN program and
    /// its reduced, computed value compares using `op` with the expected value, either
    /// a literal or another extracted variable.
    fn computeCmp(act: Action, gpa: Allocator, global_vars: anytype) !bool {
        var op_stack = std.ArrayList(enum { add }).init(gpa);
        var values = std.ArrayList(u64).init(gpa);

        var it = mem.tokenize(u8, act.phrase, " ");
        while (it.next()) |next| {
            if (mem.eql(u8, next, "+")) {
                try op_stack.append(.add);
            } else {
                const val = global_vars.get(next) orelse {
                    std.debug.print(
                        \\
                        \\========= Variable was not extracted: ===========
                        \\{s}
                        \\
                    , .{next});
                    return error.UnknownVariable;
                };
                try values.append(val);
            }
        }

        var op_i: usize = 1;
        var reduced: u64 = values.items[0];
        for (op_stack.items) |op| {
            const other = values.items[op_i];
            switch (op) {
                .add => {
                    reduced += other;
                },
            }
        }

        const exp_value = switch (act.expected.?.value) {
            .variable => |name| global_vars.get(name) orelse {
                std.debug.print(
                    \\
                    \\========= Variable was not extracted: ===========
                    \\{s}
                    \\
                , .{name});
                return error.UnknownVariable;
            },
            .literal => |x| x,
        };
        return math.compare(reduced, act.expected.?.op, exp_value);
    }
};

const ComputeCompareExpected = struct {
    op: math.CompareOperator,
    value: union(enum) {
        variable: []const u8,
        literal: u64,
    },

    pub fn format(
        value: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} ", .{@tagName(value.op)});
        switch (value.value) {
            .variable => |name| try writer.writeAll(name),
            .literal => |x| try writer.print("{x}", .{x}),
        }
    }
};

const Check = struct {
    builder: *Builder,
    actions: std.ArrayList(Action),

    fn create(b: *Builder) Check {
        return .{
            .builder = b,
            .actions = std.ArrayList(Action).init(b.allocator),
        };
    }

    fn match(self: *Check, phrase: []const u8) void {
        self.actions.append(.{
            .tag = .match,
            .phrase = self.builder.dupe(phrase),
        }) catch unreachable;
    }

    fn notPresent(self: *Check, phrase: []const u8) void {
        self.actions.append(.{
            .tag = .not_present,
            .phrase = self.builder.dupe(phrase),
        }) catch unreachable;
    }

    fn computeCmp(self: *Check, phrase: []const u8, expected: ComputeCompareExpected) void {
        self.actions.append(.{
            .tag = .compute_cmp,
            .phrase = self.builder.dupe(phrase),
            .expected = expected,
        }) catch unreachable;
    }
};

/// Creates a new sequence of actions with `phrase` as the first anchor searched phrase.
pub fn checkStart(self: *CheckObjectStep, phrase: []const u8) void {
    var new_check = Check.create(self.builder);
    new_check.match(phrase);
    self.checks.append(new_check) catch unreachable;
}

/// Adds another searched phrase to the latest created Check with `CheckObjectStep.checkStart(...)`.
/// Asserts at least one check already exists.
pub fn checkNext(self: *CheckObjectStep, phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.match(phrase);
}

/// Adds another searched phrase to the latest created Check with `CheckObjectStep.checkStart(...)`
/// however ensures there is no matching phrase in the output.
/// Asserts at least one check already exists.
pub fn checkNotPresent(self: *CheckObjectStep, phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.notPresent(phrase);
}

/// Creates a new check checking specifically symbol table parsed and dumped from the object
/// file.
/// Issuing this check will force parsing and dumping of the symbol table.
pub fn checkInSymtab(self: *CheckObjectStep) void {
    self.dump_symtab = true;
    const symtab_label = switch (self.obj_format) {
        .macho => MachODumper.symtab_label,
        else => @panic("TODO other parsers"),
    };
    self.checkStart(symtab_label);
}

/// Creates a new standalone, singular check which allows running simple binary operations
/// on the extracted variables. It will then compare the reduced program with the value of
/// the expected variable.
pub fn checkComputeCompare(
    self: *CheckObjectStep,
    program: []const u8,
    expected: ComputeCompareExpected,
) void {
    var new_check = Check.create(self.builder);
    new_check.computeCmp(program, expected);
    self.checks.append(new_check) catch unreachable;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(CheckObjectStep, "step", step);

    const gpa = self.builder.allocator;
    const src_path = self.source.getPath(self.builder);
    const contents = try fs.cwd().readFileAllocOptions(
        gpa,
        src_path,
        self.max_bytes,
        null,
        @alignOf(u64),
        null,
    );

    const output = switch (self.obj_format) {
        .macho => try MachODumper.parseAndDump(contents, .{
            .gpa = gpa,
            .dump_symtab = self.dump_symtab,
        }),
        .elf => @panic("TODO elf parser"),
        .coff => @panic("TODO coff parser"),
        .wasm => try WasmDumper.parseAndDump(contents, .{
            .gpa = gpa,
            .dump_symtab = self.dump_symtab,
        }),
        else => unreachable,
    };

    var vars = std.StringHashMap(u64).init(gpa);

    for (self.checks.items) |chk| {
        var it = mem.tokenize(u8, output, "\r\n");
        for (chk.actions.items) |act| {
            switch (act.tag) {
                .match => {
                    while (it.next()) |line| {
                        if (try act.match(line, &vars)) break;
                    } else {
                        std.debug.print(
                            \\
                            \\========= Expected to find: ==========================
                            \\{s}
                            \\========= But parsed file does not contain it: =======
                            \\{s}
                            \\
                        , .{ act.phrase, output });
                        return error.TestFailed;
                    }
                },
                .not_present => {
                    while (it.next()) |line| {
                        if (try act.match(line, &vars)) {
                            std.debug.print(
                                \\
                                \\========= Expected not to find: ===================
                                \\{s}
                                \\========= But parsed file does contain it: ========
                                \\{s}
                                \\
                            , .{ act.phrase, output });
                            return error.TestFailed;
                        }
                    }
                },
                .compute_cmp => {
                    const res = act.computeCmp(gpa, vars) catch |err| switch (err) {
                        error.UnknownVariable => {
                            std.debug.print(
                                \\========= From parsed file: =====================
                                \\{s}
                                \\
                            , .{output});
                            return error.TestFailed;
                        },
                        else => |e| return e,
                    };
                    if (!res) {
                        std.debug.print(
                            \\
                            \\========= Comparison failed for action: ===========
                            \\{s} {s}
                            \\========= From parsed file: =======================
                            \\{s}
                            \\
                        , .{ act.phrase, act.expected.?, output });
                        return error.TestFailed;
                    }
                },
            }
        }
    }
}

const Opts = struct {
    gpa: ?Allocator = null,
    dump_symtab: bool = false,
};

const MachODumper = struct {
    const LoadCommandIterator = macho.LoadCommandIterator;
    const symtab_label = "symtab";

    fn parseAndDump(bytes: []align(@alignOf(u64)) const u8, opts: Opts) ![]const u8 {
        const gpa = opts.gpa orelse unreachable; // MachO dumper requires an allocator
        var stream = std.io.fixedBufferStream(bytes);
        const reader = stream.reader();

        const hdr = try reader.readStruct(macho.mach_header_64);
        if (hdr.magic != macho.MH_MAGIC_64) {
            return error.InvalidMagicNumber;
        }

        var output = std.ArrayList(u8).init(gpa);
        const writer = output.writer();

        var symtab: []const macho.nlist_64 = undefined;
        var strtab: []const u8 = undefined;
        var sections = std.ArrayList(macho.section_64).init(gpa);
        var imports = std.ArrayList([]const u8).init(gpa);

        var it = LoadCommandIterator{
            .ncmds = hdr.ncmds,
            .buffer = bytes[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
        };
        var i: usize = 0;
        while (it.next()) |cmd| {
            switch (cmd.cmd()) {
                .SEGMENT_64 => {
                    const seg = cmd.cast(macho.segment_command_64).?;
                    try sections.ensureUnusedCapacity(seg.nsects);
                    for (cmd.getSections()) |sect| {
                        sections.appendAssumeCapacity(sect);
                    }
                },
                .SYMTAB => if (opts.dump_symtab) {
                    const lc = cmd.cast(macho.symtab_command).?;
                    symtab = @ptrCast(
                        [*]const macho.nlist_64,
                        @alignCast(@alignOf(macho.nlist_64), &bytes[lc.symoff]),
                    )[0..lc.nsyms];
                    strtab = bytes[lc.stroff..][0..lc.strsize];
                },
                .LOAD_DYLIB,
                .LOAD_WEAK_DYLIB,
                .REEXPORT_DYLIB,
                => {
                    try imports.append(cmd.getDylibPathName());
                },
                else => {},
            }

            try dumpLoadCommand(cmd, i, writer);
            try writer.writeByte('\n');

            i += 1;
        }

        if (opts.dump_symtab) {
            for (symtab) |sym| {
                if (sym.stab()) continue;
                const sym_name = mem.sliceTo(@ptrCast([*:0]const u8, strtab.ptr + sym.n_strx), 0);
                if (sym.sect()) {
                    const sect = sections.items[sym.n_sect - 1];
                    try writer.print("{x} ({s},{s})", .{
                        sym.n_value,
                        sect.segName(),
                        sect.sectName(),
                    });
                    if (sym.ext()) {
                        try writer.writeAll(" external");
                    }
                    try writer.print(" {s}\n", .{sym_name});
                } else if (sym.undf()) {
                    const ordinal = @divTrunc(@bitCast(i16, sym.n_desc), macho.N_SYMBOL_RESOLVER);
                    const import_name = blk: {
                        if (ordinal <= 0) {
                            if (ordinal == macho.BIND_SPECIAL_DYLIB_SELF)
                                break :blk "self import";
                            if (ordinal == macho.BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE)
                                break :blk "main executable";
                            if (ordinal == macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP)
                                break :blk "flat lookup";
                            unreachable;
                        }
                        const full_path = imports.items[@bitCast(u16, ordinal) - 1];
                        const basename = fs.path.basename(full_path);
                        assert(basename.len > 0);
                        const ext = mem.lastIndexOfScalar(u8, basename, '.') orelse basename.len;
                        break :blk basename[0..ext];
                    };
                    try writer.writeAll("(undefined)");
                    if (sym.weakRef()) {
                        try writer.writeAll(" weak");
                    }
                    if (sym.ext()) {
                        try writer.writeAll(" external");
                    }
                    try writer.print(" {s} (from {s})\n", .{
                        sym_name,
                        import_name,
                    });
                } else unreachable;
            }
        }

        return output.toOwnedSlice();
    }

    fn dumpLoadCommand(lc: macho.LoadCommandIterator.LoadCommand, index: usize, writer: anytype) !void {
        // print header first
        try writer.print(
            \\LC {d}
            \\cmd {s}
            \\cmdsize {d}
        , .{ index, @tagName(lc.cmd()), lc.cmdsize() });

        switch (lc.cmd()) {
            .SEGMENT_64 => {
                const seg = lc.cast(macho.segment_command_64).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\segname {s}
                    \\vmaddr {x}
                    \\vmsize {x}
                    \\fileoff {x}
                    \\filesz {x}
                , .{
                    seg.segName(),
                    seg.vmaddr,
                    seg.vmsize,
                    seg.fileoff,
                    seg.filesize,
                });

                for (lc.getSections()) |sect| {
                    try writer.writeByte('\n');
                    try writer.print(
                        \\sectname {s}
                        \\addr {x}
                        \\size {x}
                        \\offset {x}
                        \\align {x}
                    , .{
                        sect.sectName(),
                        sect.addr,
                        sect.size,
                        sect.offset,
                        sect.@"align",
                    });
                }
            },

            .ID_DYLIB,
            .LOAD_DYLIB,
            .LOAD_WEAK_DYLIB,
            .REEXPORT_DYLIB,
            => {
                const dylib = lc.cast(macho.dylib_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\name {s}
                    \\timestamp {d}
                    \\current version {x}
                    \\compatibility version {x}
                , .{
                    lc.getDylibPathName(),
                    dylib.dylib.timestamp,
                    dylib.dylib.current_version,
                    dylib.dylib.compatibility_version,
                });
            },

            .MAIN => {
                const main = lc.cast(macho.entry_point_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\entryoff {x}
                    \\stacksize {x}
                , .{ main.entryoff, main.stacksize });
            },

            .RPATH => {
                try writer.writeByte('\n');
                try writer.print(
                    \\path {s}
                , .{
                    lc.getRpathPathName(),
                });
            },

            else => {},
        }
    }
};

const WasmDumper = struct {
    const symtab_label = "symbols";

    fn parseAndDump(bytes: []const u8, opts: Opts) ![]const u8 {
        const gpa = opts.gpa orelse unreachable; // Wasm dumper requires an allocator
        if (opts.dump_symtab) {
            @panic("TODO: Implement symbol table parsing and dumping");
        }

        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();

        const buf = try reader.readBytesNoEof(8);
        if (!mem.eql(u8, buf[0..4], &std.wasm.magic)) {
            return error.InvalidMagicByte;
        }
        if (!mem.eql(u8, buf[4..], &std.wasm.version)) {
            return error.UnsupportedWasmVersion;
        }

        var output = std.ArrayList(u8).init(gpa);
        errdefer output.deinit();
        const writer = output.writer();

        while (reader.readByte()) |current_byte| {
            const section = std.meta.intToEnum(std.wasm.Section, current_byte) catch |err| {
                std.debug.print("Found invalid section id '{d}'\n", .{current_byte});
                return err;
            };

            const section_length = try std.leb.readULEB128(u32, reader);
            try parseAndDumpSection(section, bytes[fbs.pos..][0..section_length], writer);
            fbs.pos += section_length;
        } else |_| {} // reached end of stream

        return output.toOwnedSlice();
    }

    fn parseAndDumpSection(section: std.wasm.Section, data: []const u8, writer: anytype) !void {
        var fbs = std.io.fixedBufferStream(data);
        const reader = fbs.reader();

        try writer.print(
            \\Section {s}
            \\size {d}
        , .{ @tagName(section), data.len });

        switch (section) {
            .type,
            .import,
            .function,
            .table,
            .memory,
            .global,
            .@"export",
            .element,
            .code,
            .data,
            => {
                const entries = try std.leb.readULEB128(u32, reader);
                try writer.print("\nentries {d}\n", .{entries});
                try dumpSection(section, data[fbs.pos..], entries, writer);
            },
            .custom => {
                const name_length = try std.leb.readULEB128(u32, reader);
                const name = data[fbs.pos..][0..name_length];
                fbs.pos += name_length;
                try writer.print("\nname {s}\n", .{name});

                if (mem.eql(u8, name, "name")) {
                    try parseDumpNames(reader, writer, data);
                } else if (mem.eql(u8, name, "producers")) {
                    try parseDumpProducers(reader, writer, data);
                }
                // TODO: Implement parsing and dumping other custom sections (such as relocations)
            },
            .start => {
                const start = try std.leb.readULEB128(u32, reader);
                try writer.print("\nstart {d}\n", .{start});
            },
            else => {}, // skip unknown sections
        }
    }

    fn dumpSection(section: std.wasm.Section, data: []const u8, entries: u32, writer: anytype) !void {
        var fbs = std.io.fixedBufferStream(data);
        const reader = fbs.reader();

        switch (section) {
            .type => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const func_type = try reader.readByte();
                    if (func_type != std.wasm.function_type) {
                        std.debug.print("Expected function type, found byte '{d}'\n", .{func_type});
                        return error.UnexpectedByte;
                    }
                    const params = try std.leb.readULEB128(u32, reader);
                    try writer.print("params {d}\n", .{params});
                    var index: u32 = 0;
                    while (index < params) : (index += 1) {
                        try parseDumpType(std.wasm.Valtype, reader, writer);
                    } else index = 0;
                    const returns = try std.leb.readULEB128(u32, reader);
                    try writer.print("returns {d}\n", .{returns});
                    while (index < returns) : (index += 1) {
                        try parseDumpType(std.wasm.Valtype, reader, writer);
                    }
                }
            },
            .import => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const module_name_len = try std.leb.readULEB128(u32, reader);
                    const module_name = data[fbs.pos..][0..module_name_len];
                    fbs.pos += module_name_len;
                    const name_len = try std.leb.readULEB128(u32, reader);
                    const name = data[fbs.pos..][0..name_len];
                    fbs.pos += name_len;

                    const kind = std.meta.intToEnum(std.wasm.ExternalKind, try reader.readByte()) catch |err| {
                        std.debug.print("Invalid import kind\n", .{});
                        return err;
                    };

                    try writer.print(
                        \\module {s}
                        \\name {s}
                        \\kind {s}
                    , .{ module_name, name, @tagName(kind) });
                    try writer.writeByte('\n');
                    switch (kind) {
                        .function => {
                            try writer.print("index {d}\n", .{try std.leb.readULEB128(u32, reader)});
                        },
                        .memory => {
                            try parseDumpLimits(reader, writer);
                        },
                        .global => {
                            try parseDumpType(std.wasm.Valtype, reader, writer);
                            try writer.print("mutable {}\n", .{0x01 == try std.leb.readULEB128(u32, reader)});
                        },
                        .table => {
                            try parseDumpType(std.wasm.RefType, reader, writer);
                            try parseDumpLimits(reader, writer);
                        },
                    }
                }
            },
            .function => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    try writer.print("index {d}\n", .{try std.leb.readULEB128(u32, reader)});
                }
            },
            .table => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    try parseDumpType(std.wasm.RefType, reader, writer);
                    try parseDumpLimits(reader, writer);
                }
            },
            .memory => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    try parseDumpLimits(reader, writer);
                }
            },
            .global => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    try parseDumpType(std.wasm.Valtype, reader, writer);
                    try writer.print("mutable {}\n", .{0x01 == try std.leb.readULEB128(u1, reader)});
                    try parseDumpInit(reader, writer);
                }
            },
            .@"export" => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const name_len = try std.leb.readULEB128(u32, reader);
                    const name = data[fbs.pos..][0..name_len];
                    fbs.pos += name_len;
                    const kind_byte = try std.leb.readULEB128(u8, reader);
                    const kind = std.meta.intToEnum(std.wasm.ExternalKind, kind_byte) catch |err| {
                        std.debug.print("invalid export kind value '{d}'\n", .{kind_byte});
                        return err;
                    };
                    const index = try std.leb.readULEB128(u32, reader);
                    try writer.print(
                        \\name {s}
                        \\kind {s}
                        \\index {d}
                    , .{ name, @tagName(kind), index });
                    try writer.writeByte('\n');
                }
            },
            .element => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    try writer.print("table index {d}\n", .{try std.leb.readULEB128(u32, reader)});
                    try parseDumpInit(reader, writer);

                    const function_indexes = try std.leb.readULEB128(u32, reader);
                    var function_index: u32 = 0;
                    try writer.print("indexes {d}\n", .{function_indexes});
                    while (function_index < function_indexes) : (function_index += 1) {
                        try writer.print("index {d}\n", .{try std.leb.readULEB128(u32, reader)});
                    }
                }
            },
            .code => {}, // code section is considered opaque to linker
            .data => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const index = try std.leb.readULEB128(u32, reader);
                    try writer.print("memory index 0x{x}\n", .{index});
                    try parseDumpInit(reader, writer);
                    const size = try std.leb.readULEB128(u32, reader);
                    try writer.print("size {d}\n", .{size});
                    try reader.skipBytes(size, .{}); // we do not care about the content of the segments
                }
            },
            else => unreachable,
        }
    }

    fn parseDumpType(comptime WasmType: type, reader: anytype, writer: anytype) !void {
        const type_byte = try reader.readByte();
        const valtype = std.meta.intToEnum(WasmType, type_byte) catch |err| {
            std.debug.print("Invalid wasm type value '{d}'\n", .{type_byte});
            return err;
        };
        try writer.print("type {s}\n", .{@tagName(valtype)});
    }

    fn parseDumpLimits(reader: anytype, writer: anytype) !void {
        const flags = try std.leb.readULEB128(u8, reader);
        const min = try std.leb.readULEB128(u32, reader);

        try writer.print("min {x}\n", .{min});
        if (flags != 0) {
            try writer.print("max {x}\n", .{try std.leb.readULEB128(u32, reader)});
        }
    }

    fn parseDumpInit(reader: anytype, writer: anytype) !void {
        const byte = try std.leb.readULEB128(u8, reader);
        const opcode = std.meta.intToEnum(std.wasm.Opcode, byte) catch |err| {
            std.debug.print("invalid wasm opcode '{d}'\n", .{byte});
            return err;
        };
        switch (opcode) {
            .i32_const => try writer.print("i32.const {x}\n", .{try std.leb.readILEB128(i32, reader)}),
            .i64_const => try writer.print("i64.const {x}\n", .{try std.leb.readILEB128(i64, reader)}),
            .f32_const => try writer.print("f32.const {x}\n", .{@bitCast(f32, try reader.readIntLittle(u32))}),
            .f64_const => try writer.print("f64.const {x}\n", .{@bitCast(f64, try reader.readIntLittle(u64))}),
            .global_get => try writer.print("global.get {x}\n", .{try std.leb.readULEB128(u32, reader)}),
            else => unreachable,
        }
        const end_opcode = try std.leb.readULEB128(u8, reader);
        if (end_opcode != std.wasm.opcode(.end)) {
            std.debug.print("expected 'end' opcode in init expression\n", .{});
            return error.MissingEndOpcode;
        }
    }

    fn parseDumpNames(reader: anytype, writer: anytype, data: []const u8) !void {
        while (reader.context.pos < data.len) {
            try parseDumpType(std.wasm.NameSubsection, reader, writer);
            const size = try std.leb.readULEB128(u32, reader);
            const entries = try std.leb.readULEB128(u32, reader);
            try writer.print(
                \\size {d}
                \\names {d}
            , .{ size, entries });
            try writer.writeByte('\n');
            var i: u32 = 0;
            while (i < entries) : (i += 1) {
                const index = try std.leb.readULEB128(u32, reader);
                const name_len = try std.leb.readULEB128(u32, reader);
                const pos = reader.context.pos;
                const name = data[pos..][0..name_len];
                reader.context.pos += name_len;

                try writer.print(
                    \\index {d}
                    \\name {s}
                , .{ index, name });
                try writer.writeByte('\n');
            }
        }
    }

    fn parseDumpProducers(reader: anytype, writer: anytype, data: []const u8) !void {
        const field_count = try std.leb.readULEB128(u32, reader);
        try writer.print("fields {d}\n", .{field_count});
        var current_field: u32 = 0;
        while (current_field < field_count) : (current_field += 1) {
            const field_name_length = try std.leb.readULEB128(u32, reader);
            const field_name = data[reader.context.pos..][0..field_name_length];
            reader.context.pos += field_name_length;

            const value_count = try std.leb.readULEB128(u32, reader);
            try writer.print(
                \\field_name {s}
                \\values {d}
            , .{ field_name, value_count });
            try writer.writeByte('\n');
            var current_value: u32 = 0;
            while (current_value < value_count) : (current_value += 1) {
                const value_length = try std.leb.readULEB128(u32, reader);
                const value = data[reader.context.pos..][0..value_length];
                reader.context.pos += value_length;

                const version_length = try std.leb.readULEB128(u32, reader);
                const version = data[reader.context.pos..][0..version_length];
                reader.context.pos += version_length;

                try writer.print(
                    \\value_name {s}
                    \\version {s}
                , .{ value, version });
                try writer.writeByte('\n');
            }
        }
    }
};
