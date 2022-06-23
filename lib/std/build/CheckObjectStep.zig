const std = @import("../std.zig");
const assert = std.debug.assert;
const build = std.build;
const fs = std.fs;
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;

const CheckObjectStep = @This();

const Allocator = mem.Allocator;
const Builder = build.Builder;
const Step = build.Step;

pub const base_id = .check_obj;

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

const Action = union(enum) {
    match: MatchAction,
    compute_eq: ComputeEqAction,
};

/// MatchAction is the main building block of standard matchers with optional eat-all token `{*}`
/// and extractors by name such as `{n_value}`. Please note this action is very simplistic in nature
/// i.e., it won't really handle edge cases/nontrivial examples. But given that we do want to use
/// it mainly to test the output of our object format parser-dumpers when testing the linkers, etc.
/// it should be plenty useful in its current form.
const MatchAction = struct {
    needle: []const u8,

    /// Will return true if the `needle` was found in the `haystack`.
    /// Some examples include:
    ///
    /// LC 0                     => will match in its entirety
    /// vmaddr {vmaddr}          => will match `vmaddr` and then extract the following value as u64
    ///                             and save under `vmaddr` global name (see `global_vars` param)
    /// name {*}libobjc{*}.dylib => will match `name` followed by a token which contains `libobjc` and `.dylib`
    ///                             in that order with other letters in between
    fn match(act: MatchAction, haystack: []const u8, global_vars: anytype) !bool {
        var hay_it = mem.tokenize(u8, mem.trim(u8, haystack, " "), " ");
        var needle_it = mem.tokenize(u8, mem.trim(u8, act.needle, " "), " ");

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
                const value = try std.fmt.parseInt(u64, hay_tok, 16);
                try global_vars.putNoClobber(name, value);
            } else {
                if (!mem.eql(u8, hay_tok, needle_tok)) return false;
            }
        }

        return true;
    }
};

/// ComputeEqAction can be used to perform an operation on the extracted global variables
/// using the MatchAction. It currently only supports an addition. The operation is required
/// to be specified in Reverse Polish Notation to ease in operator-precedence parsing (well,
/// to avoid any parsing really).
/// For example, if the two extracted values were saved as `vmaddr` and `entryoff` respectively
/// they could then be added with this simple program `vmaddr entryoff +`.
const ComputeEqAction = struct {
    expected: []const u8,
    var_stack: std.ArrayList([]const u8),
    op_stack: std.ArrayList(Op),

    const Op = enum {
        add,
    };
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

    fn match(self: *Check, needle: []const u8) void {
        self.actions.append(.{
            .match = .{ .needle = self.builder.dupe(needle) },
        }) catch unreachable;
    }

    fn computeEq(self: *Check, act: ComputeEqAction) void {
        self.actions.append(.{
            .compute_eq = act,
        }) catch unreachable;
    }
};

/// Creates a new sequence of actions with `phrase` as the first anchor searched phrase.
pub fn check(self: *CheckObjectStep, phrase: []const u8) void {
    var new_check = Check.create(self.builder);
    new_check.match(phrase);
    self.checks.append(new_check) catch unreachable;
}

/// Adds another searched phrase to the latest created Check with `CheckObjectStep.check(...)`.
/// Asserts at least one check already exists.
pub fn checkNext(self: *CheckObjectStep, phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.match(phrase);
}

/// Creates a new check checking specifically symbol table parsed and dumped from the object
/// file.
/// Issuing this check will force parsing and dumping of the symbol table.
pub fn checkInSymtab(self: *CheckObjectStep) void {
    self.dump_symtab = true;
    self.check("symtab");
}

/// Creates a new standalone, singular check which allows running simple binary operations
/// on the extracted variables. It will then compare the reduced program with the value of
/// the expected variable.
pub fn checkComputeEq(self: *CheckObjectStep, program: []const u8, expected: []const u8) void {
    const gpa = self.builder.allocator;
    var ca = ComputeEqAction{
        .expected = expected,
        .var_stack = std.ArrayList([]const u8).init(gpa),
        .op_stack = std.ArrayList(ComputeEqAction.Op).init(gpa),
    };

    var it = mem.tokenize(u8, program, " ");
    while (it.next()) |next| {
        if (mem.eql(u8, next, "+")) {
            ca.op_stack.append(.add) catch unreachable;
        } else {
            ca.var_stack.append(self.builder.dupe(next)) catch unreachable;
        }
    }

    var new_check = Check.create(self.builder);
    new_check.computeEq(ca);
    self.checks.append(new_check) catch unreachable;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(CheckObjectStep, "step", step);

    const gpa = self.builder.allocator;
    const src_path = self.source.getPath(self.builder);
    const contents = try fs.cwd().readFileAlloc(gpa, src_path, self.max_bytes);

    const output = switch (self.obj_format) {
        .macho => try MachODumper.parseAndDump(contents, .{
            .gpa = gpa,
            .dump_symtab = self.dump_symtab,
        }),
        .elf => @panic("TODO elf parser"),
        .coff => @panic("TODO coff parser"),
        .wasm => @panic("TODO wasm parser"),
        else => unreachable,
    };

    var vars = std.StringHashMap(u64).init(gpa);

    for (self.checks.items) |chk| {
        var it = mem.tokenize(u8, output, "\r\n");
        for (chk.actions.items) |act| {
            switch (act) {
                .match => |match_act| {
                    while (it.next()) |line| {
                        if (try match_act.match(line, &vars)) break;
                    } else {
                        std.debug.print(
                            \\
                            \\========= Expected to find: ==========================
                            \\{s}
                            \\========= But parsed file does not contain it: =======
                            \\{s}
                            \\
                        , .{ match_act.needle, output });
                        return error.TestFailed;
                    }
                },
                .compute_eq => |c_eq| {
                    var values = std.ArrayList(u64).init(gpa);
                    try values.ensureTotalCapacity(c_eq.var_stack.items.len);
                    for (c_eq.var_stack.items) |vv| {
                        const val = vars.get(vv) orelse {
                            std.debug.print(
                                \\
                                \\========= Variable was not extracted: ===========
                                \\{s}
                                \\========= From parsed file: =====================
                                \\{s}
                                \\
                            , .{ vv, output });
                            return error.TestFailed;
                        };
                        values.appendAssumeCapacity(val);
                    }

                    var op_i: usize = 1;
                    var reduced: u64 = values.items[0];
                    for (c_eq.op_stack.items) |op| {
                        const other = values.items[op_i];
                        switch (op) {
                            .add => {
                                reduced += other;
                            },
                        }
                    }

                    const expected = vars.get(c_eq.expected) orelse {
                        std.debug.print(
                            \\
                            \\========= Variable was not extracted: ===========
                            \\{s}
                            \\========= From parsed file: =====================
                            \\{s}
                            \\
                        , .{ c_eq.expected, output });
                        return error.TestFailed;
                    };
                    try testing.expectEqual(reduced, expected);
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
    fn parseAndDump(bytes: []const u8, opts: Opts) ![]const u8 {
        const gpa = opts.gpa orelse unreachable; // MachO dumper requires an allocator
        var stream = std.io.fixedBufferStream(bytes);
        const reader = stream.reader();

        const hdr = try reader.readStruct(macho.mach_header_64);
        if (hdr.magic != macho.MH_MAGIC_64) {
            return error.InvalidMagicNumber;
        }

        var output = std.ArrayList(u8).init(gpa);
        const writer = output.writer();

        var symtab_cmd: ?macho.symtab_command = null;
        var i: u16 = 0;
        while (i < hdr.ncmds) : (i += 1) {
            var cmd = try macho.LoadCommand.read(gpa, reader);

            if (opts.dump_symtab and cmd.cmd() == .SYMTAB) {
                symtab_cmd = cmd.symtab;
            }

            try dumpLoadCommand(cmd, i, writer);
            try writer.writeByte('\n');
        }

        if (symtab_cmd) |cmd| {
            try writer.writeAll("symtab\n");
            const strtab = bytes[cmd.stroff..][0..cmd.strsize];
            const raw_symtab = bytes[cmd.symoff..][0 .. cmd.nsyms * @sizeOf(macho.nlist_64)];
            const symtab = mem.bytesAsSlice(macho.nlist_64, raw_symtab);

            for (symtab) |sym| {
                if (sym.stab()) continue;
                const sym_name = mem.sliceTo(@ptrCast([*:0]const u8, strtab.ptr + sym.n_strx), 0);
                try writer.print("{s} {x}\n", .{ sym_name, sym.n_value });
            }
        }

        return output.toOwnedSlice();
    }

    fn dumpLoadCommand(lc: macho.LoadCommand, index: u16, writer: anytype) !void {
        // print header first
        try writer.print(
            \\LC {d}
            \\cmd {s}
            \\cmdsize {d}
        , .{ index, @tagName(lc.cmd()), lc.cmdsize() });

        switch (lc.cmd()) {
            .SEGMENT_64 => {
                // TODO dump section headers
                const seg = lc.segment.inner;
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
            },

            .ID_DYLIB,
            .LOAD_DYLIB,
            => {
                const dylib = lc.dylib.inner.dylib;
                try writer.writeByte('\n');
                try writer.print(
                    \\name {s}
                    \\timestamp {d}
                    \\current version {x}
                    \\compatibility version {x}
                , .{
                    mem.sliceTo(lc.dylib.data, 0),
                    dylib.timestamp,
                    dylib.current_version,
                    dylib.compatibility_version,
                });
            },

            .MAIN => {
                try writer.writeByte('\n');
                try writer.print(
                    \\entryoff {x}
                    \\stacksize {x}
                , .{ lc.main.entryoff, lc.main.stacksize });
            },

            .RPATH => {
                try writer.writeByte('\n');
                try writer.print(
                    \\path {s}
                , .{
                    mem.sliceTo(lc.rpath.data, 0),
                });
            },

            else => {},
        }
    }
};
