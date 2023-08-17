const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const fs = std.fs;
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const CheckObject = @This();

const Allocator = mem.Allocator;
const Step = std.Build.Step;

pub const base_id = .check_object;

step: Step,
source: std.Build.LazyPath,
max_bytes: usize = 20 * 1024 * 1024,
checks: std.ArrayList(Check),
obj_format: std.Target.ObjectFormat,

pub fn create(
    owner: *std.Build,
    source: std.Build.LazyPath,
    obj_format: std.Target.ObjectFormat,
) *CheckObject {
    const gpa = owner.allocator;
    const self = gpa.create(CheckObject) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = .check_file,
            .name = "CheckObject",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source.dupe(owner),
        .checks = std.ArrayList(Check).init(gpa),
        .obj_format = obj_format,
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

const SearchPhrase = struct {
    string: []const u8,
    file_source: ?std.Build.LazyPath = null,

    fn resolve(phrase: SearchPhrase, b: *std.Build, step: *Step) []const u8 {
        const file_source = phrase.file_source orelse return phrase.string;
        return b.fmt("{s} {s}", .{ phrase.string, file_source.getPath2(b, step) });
    }
};

/// There five types of actions currently supported:
/// .exact - will do an exact match against the haystack
/// .contains - will check for existence within the haystack
/// .not_present - will check for non-existence within the haystack
/// .extract - will do an exact match and extract into a variable enclosed within `{name}` braces
/// .compute_cmp - will perform an operation on the extracted global variables
/// using the MatchAction. It currently only supports an addition. The operation is required
/// to be specified in Reverse Polish Notation to ease in operator-precedence parsing (well,
/// to avoid any parsing really).
/// For example, if the two extracted values were saved as `vmaddr` and `entryoff` respectively
/// they could then be added with this simple program `vmaddr entryoff +`.
const Action = struct {
    tag: enum { exact, contains, not_present, extract, compute_cmp },
    phrase: SearchPhrase,
    expected: ?ComputeCompareExpected = null,

    /// Returns true if the `phrase` is an exact match with the haystack and variable was successfully extracted.
    fn extract(
        act: Action,
        b: *std.Build,
        step: *Step,
        haystack: []const u8,
        global_vars: anytype,
    ) !bool {
        assert(act.tag == .extract);
        const hay = mem.trim(u8, haystack, " ");
        const phrase = mem.trim(u8, act.phrase.resolve(b, step), " ");

        var candidate_vars = std.ArrayList(struct { name: []const u8, value: u64 }).init(b.allocator);
        var hay_it = mem.tokenizeScalar(u8, hay, ' ');
        var needle_it = mem.tokenizeScalar(u8, phrase, ' ');

        while (needle_it.next()) |needle_tok| {
            const hay_tok = hay_it.next() orelse break;
            if (mem.startsWith(u8, needle_tok, "{")) {
                const closing_brace = mem.indexOf(u8, needle_tok, "}") orelse return error.MissingClosingBrace;
                if (closing_brace != needle_tok.len - 1) return error.ClosingBraceNotLast;

                const name = needle_tok[1..closing_brace];
                if (name.len == 0) return error.MissingBraceValue;
                const value = std.fmt.parseInt(u64, hay_tok, 16) catch return false;
                try candidate_vars.append(.{
                    .name = name,
                    .value = value,
                });
            } else {
                if (!mem.eql(u8, hay_tok, needle_tok)) return false;
            }
        }

        if (candidate_vars.items.len == 0) return false;

        for (candidate_vars.items) |cv| try global_vars.putNoClobber(cv.name, cv.value);

        return true;
    }

    /// Returns true if the `phrase` is an exact match with the haystack.
    fn exact(
        act: Action,
        b: *std.Build,
        step: *Step,
        haystack: []const u8,
    ) bool {
        assert(act.tag == .exact);
        const hay = mem.trim(u8, haystack, " ");
        const phrase = mem.trim(u8, act.phrase.resolve(b, step), " ");
        return mem.eql(u8, hay, phrase);
    }

    /// Returns true if the `phrase` exists within the haystack.
    fn contains(
        act: Action,
        b: *std.Build,
        step: *Step,
        haystack: []const u8,
    ) bool {
        assert(act.tag == .contains);
        const hay = mem.trim(u8, haystack, " ");
        const phrase = mem.trim(u8, act.phrase.resolve(b, step), " ");
        return mem.indexOf(u8, hay, phrase) != null;
    }

    /// Returns true if the `phrase` does not exist within the haystack.
    fn notPresent(
        act: Action,
        b: *std.Build,
        step: *Step,
        haystack: []const u8,
    ) bool {
        assert(act.tag == .not_present);
        return !contains(.{
            .tag = .contains,
            .phrase = act.phrase,
            .expected = act.expected,
        }, b, step, haystack);
    }

    /// Will return true if the `phrase` is correctly parsed into an RPN program and
    /// its reduced, computed value compares using `op` with the expected value, either
    /// a literal or another extracted variable.
    fn computeCmp(act: Action, b: *std.Build, step: *Step, global_vars: anytype) !bool {
        const gpa = step.owner.allocator;
        const phrase = act.phrase.resolve(b, step);
        var op_stack = std.ArrayList(enum { add, sub, mod, mul }).init(gpa);
        var values = std.ArrayList(u64).init(gpa);

        var it = mem.tokenizeScalar(u8, phrase, ' ');
        while (it.next()) |next| {
            if (mem.eql(u8, next, "+")) {
                try op_stack.append(.add);
            } else if (mem.eql(u8, next, "-")) {
                try op_stack.append(.sub);
            } else if (mem.eql(u8, next, "%")) {
                try op_stack.append(.mod);
            } else if (mem.eql(u8, next, "*")) {
                try op_stack.append(.mul);
            } else {
                const val = std.fmt.parseInt(u64, next, 0) catch blk: {
                    break :blk global_vars.get(next) orelse {
                        try step.addError(
                            \\
                            \\========= variable was not extracted: ===========
                            \\{s}
                            \\=================================================
                        , .{next});
                        return error.UnknownVariable;
                    };
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
                .sub => {
                    reduced -= other;
                },
                .mod => {
                    reduced %= other;
                },
                .mul => {
                    reduced *= other;
                },
            }
            op_i += 1;
        }

        const exp_value = switch (act.expected.?.value) {
            .variable => |name| global_vars.get(name) orelse {
                try step.addError(
                    \\
                    \\========= variable was not extracted: ===========
                    \\{s}
                    \\=================================================
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
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, value);
        _ = options;
        try writer.print("{s} ", .{@tagName(value.op)});
        switch (value.value) {
            .variable => |name| try writer.writeAll(name),
            .literal => |x| try writer.print("{x}", .{x}),
        }
    }
};

const Check = struct {
    actions: std.ArrayList(Action),

    fn create(allocator: Allocator) Check {
        return .{
            .actions = std.ArrayList(Action).init(allocator),
        };
    }

    fn extract(self: *Check, phrase: SearchPhrase) void {
        self.actions.append(.{
            .tag = .extract,
            .phrase = phrase,
        }) catch @panic("OOM");
    }

    fn exact(self: *Check, phrase: SearchPhrase) void {
        self.actions.append(.{
            .tag = .exact,
            .phrase = phrase,
        }) catch @panic("OOM");
    }

    fn contains(self: *Check, phrase: SearchPhrase) void {
        self.actions.append(.{
            .tag = .contains,
            .phrase = phrase,
        }) catch @panic("OOM");
    }

    fn notPresent(self: *Check, phrase: SearchPhrase) void {
        self.actions.append(.{
            .tag = .not_present,
            .phrase = phrase,
        }) catch @panic("OOM");
    }

    fn computeCmp(self: *Check, phrase: SearchPhrase, expected: ComputeCompareExpected) void {
        self.actions.append(.{
            .tag = .compute_cmp,
            .phrase = phrase,
            .expected = expected,
        }) catch @panic("OOM");
    }
};

/// Creates a new empty sequence of actions.
pub fn checkStart(self: *CheckObject) void {
    var new_check = Check.create(self.step.owner.allocator);
    self.checks.append(new_check) catch @panic("OOM");
}

/// Adds an exact match phrase to the latest created Check with `CheckObject.checkStart()`.
pub fn checkExact(self: *CheckObject, phrase: []const u8) void {
    self.checkExactInner(phrase, null);
}

/// Like `checkExact()` but takes an additional argument `LazyPath` which will be
/// resolved to a full search query in `make()`.
pub fn checkExactPath(self: *CheckObject, phrase: []const u8, file_source: std.Build.LazyPath) void {
    self.checkExactInner(phrase, file_source);
}

fn checkExactInner(self: *CheckObject, phrase: []const u8, file_source: ?std.Build.LazyPath) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.exact(.{ .string = self.step.owner.dupe(phrase), .file_source = file_source });
}

/// Adds a fuzzy match phrase to the latest created Check with `CheckObject.checkStart()`.
pub fn checkContains(self: *CheckObject, phrase: []const u8) void {
    self.checkContainsInner(phrase, null);
}

/// Like `checkContains()` but takes an additional argument `FileSource` which will be
/// resolved to a full search query in `make()`.
pub fn checkContainsPath(self: *CheckObject, phrase: []const u8, file_source: std.Build.LazyPath) void {
    self.checkContainsInner(phrase, file_source);
}

fn checkContainsInner(self: *CheckObject, phrase: []const u8, file_source: ?std.Build.FileSource) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.contains(.{ .string = self.step.owner.dupe(phrase), .file_source = file_source });
}

/// Adds an exact match phrase with variable extractor to the latest created Check
/// with `CheckObject.checkStart()`.
pub fn checkExtract(self: *CheckObject, phrase: []const u8) void {
    self.checkExtractInner(phrase, null);
}

/// Like `checkExtract()` but takes an additional argument `FileSource` which will be
/// resolved to a full search query in `make()`.
pub fn checkExtractFileSource(self: *CheckObject, phrase: []const u8, file_source: std.Build.FileSource) void {
    self.checkExtractInner(phrase, file_source);
}

fn checkExtractInner(self: *CheckObject, phrase: []const u8, file_source: ?std.Build.FileSource) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.extract(.{ .string = self.step.owner.dupe(phrase), .file_source = file_source });
}

/// Adds another searched phrase to the latest created Check with `CheckObject.checkStart(...)`
/// however ensures there is no matching phrase in the output.
pub fn checkNotPresent(self: *CheckObject, phrase: []const u8) void {
    self.checkNotPresentInner(phrase, null);
}

/// Like `checkExtract()` but takes an additional argument `FileSource` which will be
/// resolved to a full search query in `make()`.
pub fn checkNotPresentFileSource(self: *CheckObject, phrase: []const u8, file_source: std.Build.FileSource) void {
    self.checkNotPresentInner(phrase, file_source);
}

fn checkNotPresentInner(self: *CheckObject, phrase: []const u8, file_source: ?std.Build.FileSource) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.notPresent(.{ .string = self.step.owner.dupe(phrase), .file_source = file_source });
}

/// Creates a new check checking specifically symbol table parsed and dumped from the object
/// file.
pub fn checkInSymtab(self: *CheckObject) void {
    const label = switch (self.obj_format) {
        .macho => MachODumper.symtab_label,
        .elf => ElfDumper.symtab_label,
        .wasm => WasmDumper.symtab_label,
        .coff => @panic("TODO symtab for coff"),
        else => @panic("TODO other file formats"),
    };
    self.checkStart();
    self.checkExact(label);
}

/// Creates a new check checking specifically dynamic symbol table parsed and dumped from the object
/// file.
/// This check is target-dependent and applicable to ELF only.
pub fn checkInDynamicSymtab(self: *CheckObject) void {
    const label = switch (self.obj_format) {
        .elf => ElfDumper.dynamic_symtab_label,
        else => @panic("Unsupported target platform"),
    };
    self.checkStart();
    self.checkExact(label);
}

/// Creates a new check checking specifically dynamic section parsed and dumped from the object
/// file.
/// This check is target-dependent and applicable to ELF only.
pub fn checkInDynamicSection(self: *CheckObject) void {
    const label = switch (self.obj_format) {
        .elf => ElfDumper.dynamic_section_label,
        else => @panic("Unsupported target platform"),
    };
    self.checkStart();
    self.checkExact(label);
}

/// Creates a new standalone, singular check which allows running simple binary operations
/// on the extracted variables. It will then compare the reduced program with the value of
/// the expected variable.
pub fn checkComputeCompare(
    self: *CheckObject,
    program: []const u8,
    expected: ComputeCompareExpected,
) void {
    var new_check = Check.create(self.step.owner.allocator);
    new_check.computeCmp(.{ .string = self.step.owner.dupe(program) }, expected);
    self.checks.append(new_check) catch @panic("OOM");
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const gpa = b.allocator;
    const self = @fieldParentPtr(CheckObject, "step", step);

    const src_path = self.source.getPath(b);
    const contents = fs.cwd().readFileAllocOptions(
        gpa,
        src_path,
        self.max_bytes,
        null,
        @alignOf(u64),
        null,
    ) catch |err| return step.fail("unable to read '{s}': {s}", .{ src_path, @errorName(err) });

    const output = switch (self.obj_format) {
        .macho => try MachODumper.parseAndDump(step, contents),
        .elf => try ElfDumper.parseAndDump(step, contents),
        .coff => @panic("TODO coff parser"),
        .wasm => try WasmDumper.parseAndDump(step, contents),
        else => unreachable,
    };

    var vars = std.StringHashMap(u64).init(gpa);

    for (self.checks.items) |chk| {
        var it = mem.tokenizeAny(u8, output, "\r\n");
        for (chk.actions.items) |act| {
            switch (act.tag) {
                .exact => {
                    while (it.next()) |line| {
                        if (act.exact(b, step, line)) break;
                    } else {
                        return step.fail(
                            \\
                            \\========= expected to find: ==========================
                            \\{s}
                            \\========= but parsed file does not contain it: =======
                            \\{s}
                            \\======================================================
                        , .{ act.phrase.resolve(b, step), output });
                    }
                },
                .contains => {
                    while (it.next()) |line| {
                        if (act.contains(b, step, line)) break;
                    } else {
                        return step.fail(
                            \\
                            \\========= expected to find: ==========================
                            \\*{s}*
                            \\========= but parsed file does not contain it: =======
                            \\{s}
                            \\======================================================
                        , .{ act.phrase.resolve(b, step), output });
                    }
                },
                .not_present => {
                    while (it.next()) |line| {
                        if (act.notPresent(b, step, line)) continue;
                        return step.fail(
                            \\
                            \\========= expected not to find: ===================
                            \\{s}
                            \\========= but parsed file does contain it: ========
                            \\{s}
                            \\===================================================
                        , .{ act.phrase.resolve(b, step), output });
                    }
                },
                .extract => {
                    while (it.next()) |line| {
                        if (try act.extract(b, step, line, &vars)) break;
                    } else {
                        return step.fail(
                            \\
                            \\========= expected to find and extract: ==============
                            \\{s}
                            \\========= but parsed file does not contain it: =======
                            \\{s}
                            \\======================================================
                        , .{ act.phrase.resolve(b, step), output });
                    }
                },
                .compute_cmp => {
                    const res = act.computeCmp(b, step, vars) catch |err| switch (err) {
                        error.UnknownVariable => {
                            return step.fail(
                                \\========= from parsed file: =====================
                                \\{s}
                                \\=================================================
                            , .{output});
                        },
                        else => |e| return e,
                    };
                    if (!res) {
                        return step.fail(
                            \\
                            \\========= comparison failed for action: ===========
                            \\{s} {}
                            \\========= from parsed file: =======================
                            \\{s}
                            \\===================================================
                        , .{ act.phrase.resolve(b, step), act.expected.?, output });
                    }
                },
            }
        }
    }
}

const MachODumper = struct {
    const LoadCommandIterator = macho.LoadCommandIterator;
    const symtab_label = "symbol table";

    const Symtab = struct {
        symbols: []align(1) const macho.nlist_64,
        strings: []const u8,
    };

    fn parseAndDump(step: *Step, bytes: []align(@alignOf(u64)) const u8) ![]const u8 {
        const gpa = step.owner.allocator;
        var stream = std.io.fixedBufferStream(bytes);
        const reader = stream.reader();

        const hdr = try reader.readStruct(macho.mach_header_64);
        if (hdr.magic != macho.MH_MAGIC_64) {
            return error.InvalidMagicNumber;
        }

        var output = std.ArrayList(u8).init(gpa);
        const writer = output.writer();

        var symtab: ?Symtab = null;
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
                .SYMTAB => {
                    const lc = cmd.cast(macho.symtab_command).?;
                    const symbols = @as([*]align(1) const macho.nlist_64, @ptrCast(bytes.ptr + lc.symoff))[0..lc.nsyms];
                    const strings = bytes[lc.stroff..][0..lc.strsize];
                    symtab = .{ .symbols = symbols, .strings = strings };
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

        if (symtab) |stab| {
            try dumpSymtab(sections.items, imports.items, stab, writer);
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

            .UUID => {
                const uuid = lc.cast(macho.uuid_command).?;
                try writer.writeByte('\n');
                try writer.print("uuid {x}", .{std.fmt.fmtSliceHexLower(&uuid.uuid)});
            },

            .DATA_IN_CODE,
            .FUNCTION_STARTS,
            .CODE_SIGNATURE,
            => {
                const llc = lc.cast(macho.linkedit_data_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\dataoff {x}
                    \\datasize {x}
                , .{ llc.dataoff, llc.datasize });
            },

            .DYLD_INFO_ONLY => {
                const dlc = lc.cast(macho.dyld_info_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\rebaseoff {x}
                    \\rebasesize {x}
                    \\bindoff {x}
                    \\bindsize {x}
                    \\weakbindoff {x}
                    \\weakbindsize {x}
                    \\lazybindoff {x}
                    \\lazybindsize {x}
                    \\exportoff {x}
                    \\exportsize {x}
                , .{
                    dlc.rebase_off,
                    dlc.rebase_size,
                    dlc.bind_off,
                    dlc.bind_size,
                    dlc.weak_bind_off,
                    dlc.weak_bind_size,
                    dlc.lazy_bind_off,
                    dlc.lazy_bind_size,
                    dlc.export_off,
                    dlc.export_size,
                });
            },

            .SYMTAB => {
                const slc = lc.cast(macho.symtab_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\symoff {x}
                    \\nsyms {x}
                    \\stroff {x}
                    \\strsize {x}
                , .{
                    slc.symoff,
                    slc.nsyms,
                    slc.stroff,
                    slc.strsize,
                });
            },

            .DYSYMTAB => {
                const dlc = lc.cast(macho.dysymtab_command).?;
                try writer.writeByte('\n');
                try writer.print(
                    \\ilocalsym {x}
                    \\nlocalsym {x}
                    \\iextdefsym {x}
                    \\nextdefsym {x}
                    \\iundefsym {x}
                    \\nundefsym {x}
                    \\indirectsymoff {x}
                    \\nindirectsyms {x}
                , .{
                    dlc.ilocalsym,
                    dlc.nlocalsym,
                    dlc.iextdefsym,
                    dlc.nextdefsym,
                    dlc.iundefsym,
                    dlc.nundefsym,
                    dlc.indirectsymoff,
                    dlc.nindirectsyms,
                });
            },

            else => {},
        }
    }

    fn dumpSymtab(
        sections: []const macho.section_64,
        imports: []const []const u8,
        symtab: Symtab,
        writer: anytype,
    ) !void {
        try writer.writeAll(symtab_label ++ "\n");

        for (symtab.symbols) |sym| {
            if (sym.stab()) continue;
            const sym_name = mem.sliceTo(@as([*:0]const u8, @ptrCast(symtab.strings.ptr + sym.n_strx)), 0);
            if (sym.sect()) {
                const sect = sections[sym.n_sect - 1];
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
                const ordinal = @divTrunc(@as(i16, @bitCast(sym.n_desc)), macho.N_SYMBOL_RESOLVER);
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
                    const full_path = imports[@as(u16, @bitCast(ordinal)) - 1];
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
};

const ElfDumper = struct {
    const symtab_label = "symbol table";
    const dynamic_symtab_label = "dynamic symbol table";
    const dynamic_section_label = "dynamic section";

    const Symtab = struct {
        symbols: []align(1) const elf.Elf64_Sym,
        strings: []const u8,

        fn get(st: Symtab, index: usize) ?elf.Elf64_Sym {
            if (index >= st.symbols.len) return null;
            return st.symbols[index];
        }

        fn getName(st: Symtab, index: usize) ?[]const u8 {
            const sym = st.get(index) orelse return null;
            return getString(st.strings, sym.st_name);
        }
    };

    const Context = struct {
        gpa: Allocator,
        data: []const u8,
        hdr: elf.Elf64_Ehdr,
        shdrs: []align(1) const elf.Elf64_Shdr,
        phdrs: []align(1) const elf.Elf64_Phdr,
        shstrtab: []const u8,
        symtab: ?Symtab = null,
        dysymtab: ?Symtab = null,
    };

    fn parseAndDump(step: *Step, bytes: []const u8) ![]const u8 {
        const gpa = step.owner.allocator;
        var stream = std.io.fixedBufferStream(bytes);
        const reader = stream.reader();

        const hdr = try reader.readStruct(elf.Elf64_Ehdr);
        if (!mem.eql(u8, hdr.e_ident[0..4], "\x7fELF")) {
            return error.InvalidMagicNumber;
        }

        const shdrs = @as([*]align(1) const elf.Elf64_Shdr, @ptrCast(bytes.ptr + hdr.e_shoff))[0..hdr.e_shnum];
        const phdrs = @as([*]align(1) const elf.Elf64_Phdr, @ptrCast(bytes.ptr + hdr.e_phoff))[0..hdr.e_phnum];

        var ctx = Context{
            .gpa = gpa,
            .data = bytes,
            .hdr = hdr,
            .shdrs = shdrs,
            .phdrs = phdrs,
            .shstrtab = undefined,
        };
        ctx.shstrtab = getSectionContents(ctx, ctx.hdr.e_shstrndx);

        for (ctx.shdrs, 0..) |shdr, i| switch (shdr.sh_type) {
            elf.SHT_SYMTAB, elf.SHT_DYNSYM => {
                const raw = getSectionContents(ctx, i);
                const nsyms = @divExact(raw.len, @sizeOf(elf.Elf64_Sym));
                const symbols = @as([*]align(1) const elf.Elf64_Sym, @ptrCast(raw.ptr))[0..nsyms];
                const strings = getSectionContents(ctx, shdr.sh_link);

                switch (shdr.sh_type) {
                    elf.SHT_SYMTAB => {
                        ctx.symtab = .{
                            .symbols = symbols,
                            .strings = strings,
                        };
                    },
                    elf.SHT_DYNSYM => {
                        ctx.dysymtab = .{
                            .symbols = symbols,
                            .strings = strings,
                        };
                    },
                    else => unreachable,
                }
            },

            else => {},
        };

        var output = std.ArrayList(u8).init(gpa);
        const writer = output.writer();

        try dumpHeader(ctx, writer);
        try dumpShdrs(ctx, writer);
        try dumpPhdrs(ctx, writer);
        try dumpDynamicSection(ctx, writer);
        try dumpSymtab(ctx, .symtab, writer);
        try dumpSymtab(ctx, .dysymtab, writer);

        return output.toOwnedSlice();
    }

    inline fn getSectionName(ctx: Context, shndx: usize) []const u8 {
        const shdr = ctx.shdrs[shndx];
        return getString(ctx.shstrtab, shdr.sh_name);
    }

    fn getSectionContents(ctx: Context, shndx: usize) []const u8 {
        const shdr = ctx.shdrs[shndx];
        assert(shdr.sh_offset < ctx.data.len);
        assert(shdr.sh_offset + shdr.sh_size <= ctx.data.len);
        return ctx.data[shdr.sh_offset..][0..shdr.sh_size];
    }

    fn getSectionByName(ctx: Context, name: []const u8) ?usize {
        for (0..ctx.shdrs.len) |shndx| {
            if (mem.eql(u8, getSectionName(ctx, shndx), name)) return shndx;
        } else return null;
    }

    fn getString(strtab: []const u8, off: u32) []const u8 {
        assert(off < strtab.len);
        return mem.sliceTo(@as([*:0]const u8, @ptrCast(strtab.ptr + off)), 0);
    }

    fn dumpHeader(ctx: Context, writer: anytype) !void {
        try writer.writeAll("header\n");
        try writer.print("type {s}\n", .{@tagName(ctx.hdr.e_type)});
        try writer.print("entry {x}\n", .{ctx.hdr.e_entry});
    }

    fn dumpShdrs(ctx: Context, writer: anytype) !void {
        if (ctx.shdrs.len == 0) return;

        try writer.writeAll("section headers\n");

        for (ctx.shdrs, 0..) |shdr, shndx| {
            try writer.print("shdr {d}\n", .{shndx});
            try writer.print("name {s}\n", .{getSectionName(ctx, shndx)});
            try writer.print("type {s}\n", .{fmtShType(shdr.sh_type)});
            try writer.print("addr {x}\n", .{shdr.sh_addr});
            try writer.print("offset {x}\n", .{shdr.sh_offset});
            try writer.print("size {x}\n", .{shdr.sh_size});
            try writer.print("addralign {x}\n", .{shdr.sh_addralign});
            // TODO dump formatted sh_flags
        }
    }

    fn dumpDynamicSection(ctx: Context, writer: anytype) !void {
        const shndx = getSectionByName(ctx, ".dynamic") orelse return;
        const shdr = ctx.shdrs[shndx];
        const strtab = getSectionContents(ctx, shdr.sh_link);
        const data = getSectionContents(ctx, shndx);
        const nentries = @divExact(data.len, @sizeOf(elf.Elf64_Dyn));
        const entries = @as([*]align(1) const elf.Elf64_Dyn, @ptrCast(data.ptr))[0..nentries];

        try writer.writeAll(ElfDumper.dynamic_section_label ++ "\n");

        for (entries) |entry| {
            const key = @as(u64, @bitCast(entry.d_tag));
            const value = entry.d_val;

            const key_str = switch (key) {
                elf.DT_NEEDED => "NEEDED",
                elf.DT_SONAME => "SONAME",
                elf.DT_INIT_ARRAY => "INIT_ARRAY",
                elf.DT_INIT_ARRAYSZ => "INIT_ARRAYSZ",
                elf.DT_FINI_ARRAY => "FINI_ARRAY",
                elf.DT_FINI_ARRAYSZ => "FINI_ARRAYSZ",
                elf.DT_HASH => "HASH",
                elf.DT_GNU_HASH => "GNU_HASH",
                elf.DT_STRTAB => "STRTAB",
                elf.DT_SYMTAB => "SYMTAB",
                elf.DT_STRSZ => "STRSZ",
                elf.DT_SYMENT => "SYMENT",
                elf.DT_PLTGOT => "PLTGOT",
                elf.DT_PLTRELSZ => "PLTRELSZ",
                elf.DT_PLTREL => "PLTREL",
                elf.DT_JMPREL => "JMPREL",
                elf.DT_RELA => "RELA",
                elf.DT_RELASZ => "RELASZ",
                elf.DT_RELAENT => "RELAENT",
                elf.DT_VERDEF => "VERDEF",
                elf.DT_VERDEFNUM => "VERDEFNUM",
                elf.DT_FLAGS => "FLAGS",
                elf.DT_FLAGS_1 => "FLAGS_1",
                elf.DT_VERNEED => "VERNEED",
                elf.DT_VERNEEDNUM => "VERNEEDNUM",
                elf.DT_VERSYM => "VERSYM",
                elf.DT_RELACOUNT => "RELACOUNT",
                elf.DT_RPATH => "RPATH",
                elf.DT_RUNPATH => "RUNPATH",
                elf.DT_INIT => "INIT",
                elf.DT_FINI => "FINI",
                elf.DT_NULL => "NULL",
                else => "UNKNOWN",
            };
            try writer.print("{s}", .{key_str});

            switch (key) {
                elf.DT_NEEDED,
                elf.DT_SONAME,
                elf.DT_RPATH,
                elf.DT_RUNPATH,
                => {
                    const name = getString(strtab, @intCast(value));
                    try writer.print(" {s}", .{name});
                },

                elf.DT_INIT_ARRAY,
                elf.DT_FINI_ARRAY,
                elf.DT_HASH,
                elf.DT_GNU_HASH,
                elf.DT_STRTAB,
                elf.DT_SYMTAB,
                elf.DT_PLTGOT,
                elf.DT_JMPREL,
                elf.DT_RELA,
                elf.DT_VERDEF,
                elf.DT_VERNEED,
                elf.DT_VERSYM,
                elf.DT_INIT,
                elf.DT_FINI,
                elf.DT_NULL,
                => try writer.print(" {x}", .{value}),

                elf.DT_INIT_ARRAYSZ,
                elf.DT_FINI_ARRAYSZ,
                elf.DT_STRSZ,
                elf.DT_SYMENT,
                elf.DT_PLTRELSZ,
                elf.DT_RELASZ,
                elf.DT_RELAENT,
                elf.DT_RELACOUNT,
                => try writer.print(" {d}", .{value}),

                elf.DT_PLTREL => try writer.writeAll(switch (value) {
                    elf.DT_REL => " REL",
                    elf.DT_RELA => " RELA",
                    else => " UNKNOWN",
                }),

                elf.DT_FLAGS => if (value > 0) {
                    if (value & elf.DF_ORIGIN != 0) try writer.writeAll(" ORIGIN");
                    if (value & elf.DF_SYMBOLIC != 0) try writer.writeAll(" SYMBOLIC");
                    if (value & elf.DF_TEXTREL != 0) try writer.writeAll(" TEXTREL");
                    if (value & elf.DF_BIND_NOW != 0) try writer.writeAll(" BIND_NOW");
                    if (value & elf.DF_STATIC_TLS != 0) try writer.writeAll(" STATIC_TLS");
                },

                elf.DT_FLAGS_1 => if (value > 0) {
                    if (value & elf.DF_1_NOW != 0) try writer.writeAll(" NOW");
                    if (value & elf.DF_1_GLOBAL != 0) try writer.writeAll(" GLOBAL");
                    if (value & elf.DF_1_GROUP != 0) try writer.writeAll(" GROUP");
                    if (value & elf.DF_1_NODELETE != 0) try writer.writeAll(" NODELETE");
                    if (value & elf.DF_1_LOADFLTR != 0) try writer.writeAll(" LOADFLTR");
                    if (value & elf.DF_1_INITFIRST != 0) try writer.writeAll(" INITFIRST");
                    if (value & elf.DF_1_NOOPEN != 0) try writer.writeAll(" NOOPEN");
                    if (value & elf.DF_1_ORIGIN != 0) try writer.writeAll(" ORIGIN");
                    if (value & elf.DF_1_DIRECT != 0) try writer.writeAll(" DIRECT");
                    if (value & elf.DF_1_TRANS != 0) try writer.writeAll(" TRANS");
                    if (value & elf.DF_1_INTERPOSE != 0) try writer.writeAll(" INTERPOSE");
                    if (value & elf.DF_1_NODEFLIB != 0) try writer.writeAll(" NODEFLIB");
                    if (value & elf.DF_1_NODUMP != 0) try writer.writeAll(" NODUMP");
                    if (value & elf.DF_1_CONFALT != 0) try writer.writeAll(" CONFALT");
                    if (value & elf.DF_1_ENDFILTEE != 0) try writer.writeAll(" ENDFILTEE");
                    if (value & elf.DF_1_DISPRELDNE != 0) try writer.writeAll(" DISPRELDNE");
                    if (value & elf.DF_1_DISPRELPND != 0) try writer.writeAll(" DISPRELPND");
                    if (value & elf.DF_1_NODIRECT != 0) try writer.writeAll(" NODIRECT");
                    if (value & elf.DF_1_IGNMULDEF != 0) try writer.writeAll(" IGNMULDEF");
                    if (value & elf.DF_1_NOKSYMS != 0) try writer.writeAll(" NOKSYMS");
                    if (value & elf.DF_1_NOHDR != 0) try writer.writeAll(" NOHDR");
                    if (value & elf.DF_1_EDITED != 0) try writer.writeAll(" EDITED");
                    if (value & elf.DF_1_NORELOC != 0) try writer.writeAll(" NORELOC");
                    if (value & elf.DF_1_SYMINTPOSE != 0) try writer.writeAll(" SYMINTPOSE");
                    if (value & elf.DF_1_GLOBAUDIT != 0) try writer.writeAll(" GLOBAUDIT");
                    if (value & elf.DF_1_SINGLETON != 0) try writer.writeAll(" SINGLETON");
                    if (value & elf.DF_1_STUB != 0) try writer.writeAll(" STUB");
                    if (value & elf.DF_1_PIE != 0) try writer.writeAll(" PIE");
                },

                else => try writer.print(" {x}", .{value}),
            }
            try writer.writeByte('\n');
        }
    }

    fn fmtShType(sh_type: u32) std.fmt.Formatter(formatShType) {
        return .{ .data = sh_type };
    }

    fn formatShType(
        sh_type: u32,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const name = switch (sh_type) {
            elf.SHT_NULL => "NULL",
            elf.SHT_PROGBITS => "PROGBITS",
            elf.SHT_SYMTAB => "SYMTAB",
            elf.SHT_STRTAB => "STRTAB",
            elf.SHT_RELA => "RELA",
            elf.SHT_HASH => "HASH",
            elf.SHT_DYNAMIC => "DYNAMIC",
            elf.SHT_NOTE => "NOTE",
            elf.SHT_NOBITS => "NOBITS",
            elf.SHT_REL => "REL",
            elf.SHT_SHLIB => "SHLIB",
            elf.SHT_DYNSYM => "DYNSYM",
            elf.SHT_INIT_ARRAY => "INIT_ARRAY",
            elf.SHT_FINI_ARRAY => "FINI_ARRAY",
            elf.SHT_PREINIT_ARRAY => "PREINIT_ARRAY",
            elf.SHT_GROUP => "GROUP",
            elf.SHT_SYMTAB_SHNDX => "SYMTAB_SHNDX",
            elf.SHT_X86_64_UNWIND => "X86_64_UNWIND",
            elf.SHT_LLVM_ADDRSIG => "LLVM_ADDRSIG",
            elf.SHT_GNU_HASH => "GNU_HASH",
            elf.SHT_GNU_VERDEF => "VERDEF",
            elf.SHT_GNU_VERNEED => "VERNEED",
            elf.SHT_GNU_VERSYM => "VERSYM",
            else => if (elf.SHT_LOOS <= sh_type and sh_type < elf.SHT_HIOS) {
                return try writer.print("LOOS+0x{x}", .{sh_type - elf.SHT_LOOS});
            } else if (elf.SHT_LOPROC <= sh_type and sh_type < elf.SHT_HIPROC) {
                return try writer.print("LOPROC+0x{x}", .{sh_type - elf.SHT_LOPROC});
            } else if (elf.SHT_LOUSER <= sh_type and sh_type < elf.SHT_HIUSER) {
                return try writer.print("LOUSER+0x{x}", .{sh_type - elf.SHT_LOUSER});
            } else "UNKNOWN",
        };
        try writer.writeAll(name);
    }

    fn dumpPhdrs(ctx: Context, writer: anytype) !void {
        if (ctx.phdrs.len == 0) return;

        try writer.writeAll("program headers\n");

        for (ctx.phdrs, 0..) |phdr, phndx| {
            try writer.print("phdr {d}\n", .{phndx});
            try writer.print("type {s}\n", .{fmtPhType(phdr.p_type)});
            try writer.print("vaddr {x}\n", .{phdr.p_vaddr});
            try writer.print("paddr {x}\n", .{phdr.p_paddr});
            try writer.print("offset {x}\n", .{phdr.p_offset});
            try writer.print("memsz {x}\n", .{phdr.p_memsz});
            try writer.print("filesz {x}\n", .{phdr.p_filesz});
            try writer.print("align {x}\n", .{phdr.p_align});

            {
                const flags = phdr.p_flags;
                try writer.writeAll("flags");
                if (flags > 0) try writer.writeByte(' ');
                if (flags & elf.PF_R != 0) {
                    try writer.writeByte('R');
                }
                if (flags & elf.PF_W != 0) {
                    try writer.writeByte('W');
                }
                if (flags & elf.PF_X != 0) {
                    try writer.writeByte('E');
                }
                if (flags & elf.PF_MASKOS != 0) {
                    try writer.writeAll("OS");
                }
                if (flags & elf.PF_MASKPROC != 0) {
                    try writer.writeAll("PROC");
                }
                try writer.writeByte('\n');
            }
        }
    }

    fn fmtPhType(ph_type: u32) std.fmt.Formatter(formatPhType) {
        return .{ .data = ph_type };
    }

    fn formatPhType(
        ph_type: u32,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const p_type = switch (ph_type) {
            elf.PT_NULL => "NULL",
            elf.PT_LOAD => "LOAD",
            elf.PT_DYNAMIC => "DYNAMIC",
            elf.PT_INTERP => "INTERP",
            elf.PT_NOTE => "NOTE",
            elf.PT_SHLIB => "SHLIB",
            elf.PT_PHDR => "PHDR",
            elf.PT_TLS => "TLS",
            elf.PT_NUM => "NUM",
            elf.PT_GNU_EH_FRAME => "GNU_EH_FRAME",
            elf.PT_GNU_STACK => "GNU_STACK",
            elf.PT_GNU_RELRO => "GNU_RELRO",
            else => if (elf.PT_LOOS <= ph_type and ph_type < elf.PT_HIOS) {
                return try writer.print("LOOS+0x{x}", .{ph_type - elf.PT_LOOS});
            } else if (elf.PT_LOPROC <= ph_type and ph_type < elf.PT_HIPROC) {
                return try writer.print("LOPROC+0x{x}", .{ph_type - elf.PT_LOPROC});
            } else "UNKNOWN",
        };
        try writer.writeAll(p_type);
    }

    fn dumpSymtab(ctx: Context, comptime @"type": enum { symtab, dysymtab }, writer: anytype) !void {
        const symtab = switch (@"type") {
            .symtab => ctx.symtab,
            .dysymtab => ctx.dysymtab,
        } orelse return;

        try writer.writeAll(switch (@"type") {
            .symtab => symtab_label,
            .dysymtab => dynamic_symtab_label,
        } ++ "\n");

        for (symtab.symbols, 0..) |sym, index| {
            try writer.print("{x} {x}", .{ sym.st_value, sym.st_size });

            {
                if (elf.SHN_LORESERVE <= sym.st_shndx and sym.st_shndx < elf.SHN_HIRESERVE) {
                    if (elf.SHN_LOPROC <= sym.st_shndx and sym.st_shndx < elf.SHN_HIPROC) {
                        try writer.print(" LO+{d}", .{sym.st_shndx - elf.SHN_LOPROC});
                    } else {
                        const sym_ndx = &switch (sym.st_shndx) {
                            elf.SHN_ABS => "ABS",
                            elf.SHN_COMMON => "COM",
                            elf.SHN_LIVEPATCH => "LIV",
                            else => "UNK",
                        };
                        try writer.print(" {s}", .{sym_ndx});
                    }
                } else if (sym.st_shndx == elf.SHN_UNDEF) {
                    try writer.writeAll(" UND");
                } else {
                    try writer.print(" {x}", .{sym.st_shndx});
                }
            }

            blk: {
                const tt = sym.st_type();
                const sym_type = switch (tt) {
                    elf.STT_NOTYPE => "NOTYPE",
                    elf.STT_OBJECT => "OBJECT",
                    elf.STT_FUNC => "FUNC",
                    elf.STT_SECTION => "SECTION",
                    elf.STT_FILE => "FILE",
                    elf.STT_COMMON => "COMMON",
                    elf.STT_TLS => "TLS",
                    elf.STT_NUM => "NUM",
                    elf.STT_GNU_IFUNC => "IFUNC",
                    else => if (elf.STT_LOPROC <= tt and tt < elf.STT_HIPROC) {
                        break :blk try writer.print(" LOPROC+{d}", .{tt - elf.STT_LOPROC});
                    } else if (elf.STT_LOOS <= tt and tt < elf.STT_HIOS) {
                        break :blk try writer.print(" LOOS+{d}", .{tt - elf.STT_LOOS});
                    } else "UNK",
                };
                try writer.print(" {s}", .{sym_type});
            }

            blk: {
                const bind = sym.st_bind();
                const sym_bind = switch (bind) {
                    elf.STB_LOCAL => "LOCAL",
                    elf.STB_GLOBAL => "GLOBAL",
                    elf.STB_WEAK => "WEAK",
                    elf.STB_NUM => "NUM",
                    else => if (elf.STB_LOPROC <= bind and bind < elf.STB_HIPROC) {
                        break :blk try writer.print(" LOPROC+{d}", .{bind - elf.STB_LOPROC});
                    } else if (elf.STB_LOOS <= bind and bind < elf.STB_HIOS) {
                        break :blk try writer.print(" LOOS+{d}", .{bind - elf.STB_LOOS});
                    } else "UNKNOWN",
                };
                try writer.print(" {s}", .{sym_bind});
            }

            const sym_vis = @as(elf.STV, @enumFromInt(sym.st_other));
            try writer.print(" {s}", .{@tagName(sym_vis)});

            const sym_name = switch (sym.st_type()) {
                elf.STT_SECTION => getSectionName(ctx, sym.st_shndx),
                else => symtab.getName(index).?,
            };
            try writer.print(" {s}\n", .{sym_name});
        }
    }
};

const WasmDumper = struct {
    const symtab_label = "symbols";

    fn parseAndDump(step: *Step, bytes: []const u8) ![]const u8 {
        const gpa = step.owner.allocator;
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
            const section = std.meta.intToEnum(std.wasm.Section, current_byte) catch {
                return step.fail("Found invalid section id '{d}'", .{current_byte});
            };

            const section_length = try std.leb.readULEB128(u32, reader);
            try parseAndDumpSection(step, section, bytes[fbs.pos..][0..section_length], writer);
            fbs.pos += section_length;
        } else |_| {} // reached end of stream

        return output.toOwnedSlice();
    }

    fn parseAndDumpSection(
        step: *Step,
        section: std.wasm.Section,
        data: []const u8,
        writer: anytype,
    ) !void {
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
                try dumpSection(step, section, data[fbs.pos..], entries, writer);
            },
            .custom => {
                const name_length = try std.leb.readULEB128(u32, reader);
                const name = data[fbs.pos..][0..name_length];
                fbs.pos += name_length;
                try writer.print("\nname {s}\n", .{name});

                if (mem.eql(u8, name, "name")) {
                    try parseDumpNames(step, reader, writer, data);
                } else if (mem.eql(u8, name, "producers")) {
                    try parseDumpProducers(reader, writer, data);
                } else if (mem.eql(u8, name, "target_features")) {
                    try parseDumpFeatures(reader, writer, data);
                }
                // TODO: Implement parsing and dumping other custom sections (such as relocations)
            },
            .start => {
                const start = try std.leb.readULEB128(u32, reader);
                try writer.print("\nstart {d}\n", .{start});
            },
            .data_count => {
                const count = try std.leb.readULEB128(u32, reader);
                try writer.print("\ncount {d}\n", .{count});
            },
            else => {}, // skip unknown sections
        }
    }

    fn dumpSection(step: *Step, section: std.wasm.Section, data: []const u8, entries: u32, writer: anytype) !void {
        var fbs = std.io.fixedBufferStream(data);
        const reader = fbs.reader();

        switch (section) {
            .type => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const func_type = try reader.readByte();
                    if (func_type != std.wasm.function_type) {
                        return step.fail("expected function type, found byte '{d}'", .{func_type});
                    }
                    const params = try std.leb.readULEB128(u32, reader);
                    try writer.print("params {d}\n", .{params});
                    var index: u32 = 0;
                    while (index < params) : (index += 1) {
                        try parseDumpType(step, std.wasm.Valtype, reader, writer);
                    } else index = 0;
                    const returns = try std.leb.readULEB128(u32, reader);
                    try writer.print("returns {d}\n", .{returns});
                    while (index < returns) : (index += 1) {
                        try parseDumpType(step, std.wasm.Valtype, reader, writer);
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

                    const kind = std.meta.intToEnum(std.wasm.ExternalKind, try reader.readByte()) catch {
                        return step.fail("invalid import kind", .{});
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
                            try parseDumpType(step, std.wasm.Valtype, reader, writer);
                            try writer.print("mutable {}\n", .{0x01 == try std.leb.readULEB128(u32, reader)});
                        },
                        .table => {
                            try parseDumpType(step, std.wasm.RefType, reader, writer);
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
                    try parseDumpType(step, std.wasm.RefType, reader, writer);
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
                    try parseDumpType(step, std.wasm.Valtype, reader, writer);
                    try writer.print("mutable {}\n", .{0x01 == try std.leb.readULEB128(u1, reader)});
                    try parseDumpInit(step, reader, writer);
                }
            },
            .@"export" => {
                var i: u32 = 0;
                while (i < entries) : (i += 1) {
                    const name_len = try std.leb.readULEB128(u32, reader);
                    const name = data[fbs.pos..][0..name_len];
                    fbs.pos += name_len;
                    const kind_byte = try std.leb.readULEB128(u8, reader);
                    const kind = std.meta.intToEnum(std.wasm.ExternalKind, kind_byte) catch {
                        return step.fail("invalid export kind value '{d}'", .{kind_byte});
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
                    try parseDumpInit(step, reader, writer);

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
                    const flags = try std.leb.readULEB128(u32, reader);
                    const index = if (flags & 0x02 != 0)
                        try std.leb.readULEB128(u32, reader)
                    else
                        0;
                    try writer.print("memory index 0x{x}\n", .{index});
                    if (flags == 0) {
                        try parseDumpInit(step, reader, writer);
                    }

                    const size = try std.leb.readULEB128(u32, reader);
                    try writer.print("size {d}\n", .{size});
                    try reader.skipBytes(size, .{}); // we do not care about the content of the segments
                }
            },
            else => unreachable,
        }
    }

    fn parseDumpType(step: *Step, comptime WasmType: type, reader: anytype, writer: anytype) !void {
        const type_byte = try reader.readByte();
        const valtype = std.meta.intToEnum(WasmType, type_byte) catch {
            return step.fail("Invalid wasm type value '{d}'", .{type_byte});
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

    fn parseDumpInit(step: *Step, reader: anytype, writer: anytype) !void {
        const byte = try reader.readByte();
        const opcode = std.meta.intToEnum(std.wasm.Opcode, byte) catch {
            return step.fail("invalid wasm opcode '{d}'", .{byte});
        };
        switch (opcode) {
            .i32_const => try writer.print("i32.const {x}\n", .{try std.leb.readILEB128(i32, reader)}),
            .i64_const => try writer.print("i64.const {x}\n", .{try std.leb.readILEB128(i64, reader)}),
            .f32_const => try writer.print("f32.const {x}\n", .{@as(f32, @bitCast(try reader.readIntLittle(u32)))}),
            .f64_const => try writer.print("f64.const {x}\n", .{@as(f64, @bitCast(try reader.readIntLittle(u64)))}),
            .global_get => try writer.print("global.get {x}\n", .{try std.leb.readULEB128(u32, reader)}),
            else => unreachable,
        }
        const end_opcode = try std.leb.readULEB128(u8, reader);
        if (end_opcode != std.wasm.opcode(.end)) {
            return step.fail("expected 'end' opcode in init expression", .{});
        }
    }

    fn parseDumpNames(step: *Step, reader: anytype, writer: anytype, data: []const u8) !void {
        while (reader.context.pos < data.len) {
            try parseDumpType(step, std.wasm.NameSubsection, reader, writer);
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

    fn parseDumpFeatures(reader: anytype, writer: anytype, data: []const u8) !void {
        const feature_count = try std.leb.readULEB128(u32, reader);
        try writer.print("features {d}\n", .{feature_count});

        var index: u32 = 0;
        while (index < feature_count) : (index += 1) {
            const prefix_byte = try std.leb.readULEB128(u8, reader);
            const name_length = try std.leb.readULEB128(u32, reader);
            const feature_name = data[reader.context.pos..][0..name_length];
            reader.context.pos += name_length;

            try writer.print("{c} {s}\n", .{ prefix_byte, feature_name });
        }
    }
};
