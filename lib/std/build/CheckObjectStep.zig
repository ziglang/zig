const std = @import("../std.zig");
const assert = std.debug.assert;
const build = std.build;
const fs = std.fs;
const macho = std.macho;
const mem = std.mem;

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
    exact_match: []const u8,
    extract_var: struct {
        fuzzy_match: []const u8,
        var_name: []const u8,
        var_value: u64,
    },
    compare: CompareAction,
};

const CompareAction = struct {
    expected: union(enum) {
        literal: u64,
        varr: []const u8,
    },
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

    fn exactMatch(self: *Check, phrase: []const u8) void {
        self.actions.append(.{
            .exact_match = self.builder.dupe(phrase),
        }) catch unreachable;
    }

    fn extractVar(self: *Check, phrase: []const u8, var_name: []const u8) void {
        self.actions.append(.{
            .extract_var = .{
                .fuzzy_match = self.builder.dupe(phrase),
                .var_name = self.builder.dupe(var_name),
                .var_value = undefined,
            },
        }) catch unreachable;
    }
};

pub fn check(self: *CheckObjectStep, phrase: []const u8) void {
    var new_check = Check.create(self.builder);
    new_check.exactMatch(phrase);
    self.checks.append(new_check) catch unreachable;
}

pub fn checkNext(self: *CheckObjectStep, phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.exactMatch(phrase);
}

pub fn checkNextExtract(self: *CheckObjectStep, comptime phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const matcher_start = comptime mem.indexOf(u8, phrase, "{") orelse
        @compileError("missing {  } matcher");
    const matcher_end = comptime mem.indexOf(u8, phrase, "}") orelse
        @compileError("missing {  } matcher");
    const last = &self.checks.items[self.checks.items.len - 1];
    last.extractVar(phrase[0..matcher_start], phrase[matcher_start + 1 .. matcher_end]);
}

pub fn checkInSymtab(self: *CheckObjectStep) void {
    self.dump_symtab = true;
    self.check("symtab");
}

pub fn checkCompare(self: *CheckObjectStep, comptime phrase: []const u8, expected: anytype) void {
    comptime assert(phrase[0] == '{');
    comptime assert(phrase[phrase.len - 1] == '}');

    const gpa = self.builder.allocator;
    var ca = CompareAction{
        .expected = expected,
        .var_stack = std.ArrayList([]const u8).init(gpa),
        .op_stack = std.ArrayList(CompareAction.Op).init(gpa),
    };

    var it = mem.tokenize(u8, phrase[1 .. phrase.len - 1], " ");
    while (it.next()) |next| {
        if (mem.eql(u8, next, "+")) {
            ca.op_stack.append(.add) catch unreachable;
        } else {
            ca.var_stack.append(self.builder.dupe(next)) catch unreachable;
        }
    }

    var new_check = Check.create(self.builder);
    new_check.actions.append(.{ .compare = ca }) catch unreachable;
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
        const first_action = chk.actions.items[0];

        switch (first_action) {
            .exact_match => |first| {
                if (mem.indexOf(u8, output, first)) |index| {
                    // TODO backtrack to track current scope
                    var it = std.mem.tokenize(u8, output[index..], "\r\n");

                    outer: for (chk.actions.items[1..]) |next_action| {
                        switch (next_action) {
                            .exact_match => |exact| {
                                while (it.next()) |line| {
                                    if (mem.eql(u8, line, exact)) {
                                        std.debug.print("{s} == {s}\n", .{ line, exact });
                                        continue :outer;
                                    }
                                    std.debug.print("{s} != {s}\n", .{ line, exact });
                                } else {
                                    return error.TestFailed;
                                }
                            },
                            .extract_var => |extract| {
                                const phrase = extract.fuzzy_match;
                                while (it.next()) |line| {
                                    if (mem.indexOf(u8, line, phrase)) |found| {
                                        std.debug.print("{s} in {s}\n", .{ phrase, line });
                                        // Extract variable and save back in the action.
                                        const trimmed = mem.trim(u8, line[found + phrase.len ..], " ");
                                        const parsed = try std.fmt.parseInt(u64, trimmed, 16);
                                        try vars.putNoClobber(extract.var_name, parsed);
                                        continue :outer;
                                    }
                                    std.debug.print("{s} not in {s}\n", .{ extract.fuzzy_match, line });
                                }
                            },
                            .compare => unreachable,
                        }
                    }
                } else {
                    return error.TestFailed;
                }
            },
            .compare => |act| {
                var values = std.ArrayList(u64).init(gpa);
                try values.ensureTotalCapacity(act.var_stack.items.len);
                for (act.var_stack.items) |vv| {
                    const val = vars.get(vv) orelse return error.TestFailed;
                    values.appendAssumeCapacity(val);
                }

                var op_i: usize = 1;
                var reduced: u64 = values.items[0];
                for (act.op_stack.items) |op| {
                    const other = values.items[op_i];
                    switch (op) {
                        .add => {
                            reduced += other;
                        },
                    }
                }

                const expected = switch (act.expected) {
                    .literal => |exp| exp,
                    .varr => |vv| vars.get(vv) orelse return error.TestFailed,
                };
                if (reduced != expected) return error.TestFailed;
            },
            .extract_var => unreachable,
        }
    }

    var it = vars.iterator();
    while (it.next()) |entry| {
        std.debug.print("  {s} => {x}", .{ entry.key_ptr.*, entry.value_ptr.* });
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
            const symtab = @ptrCast(
                [*]const macho.nlist_64,
                @alignCast(@alignOf(macho.nlist_64), bytes.ptr + cmd.symoff),
            )[0..cmd.nsyms];

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
