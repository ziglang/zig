const std = @import("../std.zig");
const assert = std.debug.assert;
const build = std.build;
const fs = std.fs;
const macho = std.macho;
const mem = std.mem;

const CheckMachOStep = @This();

const Allocator = mem.Allocator;
const Builder = build.Builder;
const Step = build.Step;

pub const base_id = .check_macho;

step: Step,
builder: *Builder,
source: build.FileSource,
max_bytes: usize = 20 * 1024 * 1024,
checks: std.ArrayList(Check),

pub fn create(builder: *Builder, source: build.FileSource) *CheckMachOStep {
    const gpa = builder.allocator;
    const self = gpa.create(CheckMachOStep) catch unreachable;
    self.* = CheckMachOStep{
        .builder = builder,
        .step = Step.init(.check_file, "CheckMachO", gpa, make),
        .source = source.dupe(builder),
        .checks = std.ArrayList(Check).init(gpa),
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

const Check = struct {
    builder: *Builder,
    phrases: std.ArrayList([]const u8),

    fn create(b: *Builder) Check {
        return .{
            .builder = b,
            .phrases = std.ArrayList([]const u8).init(b.allocator),
        };
    }

    fn addPhrase(self: *Check, phrase: []const u8) void {
        self.phrases.append(self.builder.dupe(phrase)) catch unreachable;
    }
};

pub fn check(self: *CheckMachOStep, phrase: []const u8) void {
    var new_check = Check.create(self.builder);
    new_check.addPhrase(phrase);
    self.checks.append(new_check) catch unreachable;
}

pub fn checkNext(self: *CheckMachOStep, phrase: []const u8) void {
    assert(self.checks.items.len > 0);
    const last = &self.checks.items[self.checks.items.len - 1];
    last.addPhrase(phrase);
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(CheckMachOStep, "step", step);

    const gpa = self.builder.allocator;
    const src_path = self.source.getPath(self.builder);
    const contents = try fs.cwd().readFileAlloc(gpa, src_path, self.max_bytes);

    // Parse the object file's header
    var stream = std.io.fixedBufferStream(contents);
    const reader = stream.reader();

    const hdr = try reader.readStruct(macho.mach_header_64);
    if (hdr.magic != macho.MH_MAGIC_64) {
        return error.InvalidMagicNumber;
    }

    var metadata = std.ArrayList(u8).init(gpa);
    const writer = metadata.writer();

    var i: u16 = 0;
    while (i < hdr.ncmds) : (i += 1) {
        var cmd = try macho.LoadCommand.read(gpa, reader);
        try dumpLoadCommand(cmd, i, writer);
        try writer.writeByte('\n');
    }

    for (self.checks.items) |chk| {
        const first_phrase = chk.phrases.items[0];

        if (mem.indexOf(u8, metadata.items, first_phrase)) |index| {
            // TODO backtrack to track current scope
            var it = std.mem.tokenize(u8, metadata.items[index..], "\r\n");

            outer: for (chk.phrases.items[1..]) |next_phrase| {
                while (it.next()) |line| {
                    if (mem.eql(u8, line, next_phrase)) {
                        std.debug.print("{s} == {s}\n", .{ line, next_phrase });
                        continue :outer;
                    }
                    std.debug.print("{s} != {s}\n", .{ line, next_phrase });
                } else {
                    return error.TestFailed;
                }
            }
        } else {
            return error.TestFailed;
        }
    }
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
                \\path {s}
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
