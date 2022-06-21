const std = @import("../std.zig");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;
const fs = std.fs;
const macho = std.macho;
const mem = std.mem;

const CheckMachOStep = @This();

pub const base_id = .check_macho;

step: Step,
builder: *Builder,
source: build.FileSource,
max_bytes: usize = 20 * 1024 * 1024,
lc_checks: std.ArrayList(LCCheck),

const LCCheck = struct {
    // common to most LCs
    cmd: macho.LC,
    name: ?[]const u8 = null,
    // LC.SEGMENT_64 specific
    index: ?usize = null,
    vaddr: ?u64 = null,
    memsz: ?u64 = null,
    offset: ?u64 = null,
    filesz: ?u64 = null,
    // LC.LOAD_DYLIB specific
    timestamp: ?u64 = null,
    current_version: ?u32 = null,
    compat_version: ?u32 = null,
};

pub fn create(builder: *Builder, source: build.FileSource) *CheckMachOStep {
    const gpa = builder.allocator;
    const self = gpa.create(CheckMachOStep) catch unreachable;
    self.* = CheckMachOStep{
        .builder = builder,
        .step = Step.init(.check_file, "CheckMachO", gpa, make),
        .source = source.dupe(builder),
        .lc_checks = std.ArrayList(LCCheck).init(gpa),
    };
    self.source.addStepDependencies(&self.step);
    return self;
}

pub fn checkLoadCommand(self: *CheckMachOStep, check: LCCheck) void {
    self.lc_checks.append(.{
        .cmd = check.cmd,
        .index = check.index,
        .name = if (check.name) |name| self.builder.dupe(name) else null,
        .vaddr = check.vaddr,
        .memsz = check.memsz,
        .offset = check.offset,
        .filesz = check.filesz,
        .timestamp = check.timestamp,
        .current_version = check.current_version,
        .compat_version = check.compat_version,
    }) catch unreachable;
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

    var load_commands = std.ArrayList(macho.LoadCommand).init(gpa);
    try load_commands.ensureTotalCapacity(hdr.ncmds);

    var i: u16 = 0;
    while (i < hdr.ncmds) : (i += 1) {
        var cmd = try macho.LoadCommand.read(gpa, reader);
        load_commands.appendAssumeCapacity(cmd);
    }

    outer: for (self.lc_checks.items) |ch| {
        if (ch.index) |index| {
            const lc = load_commands.items[index];
            try cmpLoadCommand(ch, lc);
        } else {
            for (load_commands.items) |lc| {
                if (lc.cmd() == ch.cmd) {
                    try cmpLoadCommand(ch, lc);
                    continue :outer;
                }
            } else {
                return err("LC not found", ch.cmd, "");
            }
        }
    }
}

fn cmpLoadCommand(exp: LCCheck, given: macho.LoadCommand) error{TestFailed}!void {
    if (exp.cmd != given.cmd()) {
        return err("LC mismatch", exp.cmd, given.cmd());
    }
    switch (exp.cmd) {
        .SEGMENT_64 => {
            const lc = given.segment.inner;
            if (exp.name) |name| {
                if (!mem.eql(u8, name, lc.segName())) {
                    return err("segment name mismatch", name, lc.segName());
                }
            }
            if (exp.vaddr) |vaddr| {
                if (vaddr != lc.vmaddr) {
                    return err("segment VM address mismatch", vaddr, lc.vmaddr);
                }
            }
            if (exp.memsz) |memsz| {
                if (memsz != lc.vmsize) {
                    return err("segment VM size mismatch", memsz, lc.vmsize);
                }
            }
            if (exp.offset) |offset| {
                if (offset != lc.fileoff) {
                    return err("segment file offset mismatch", offset, lc.fileoff);
                }
            }
            if (exp.filesz) |filesz| {
                if (filesz != lc.filesize) {
                    return err("segment file size mismatch", filesz, lc.filesize);
                }
            }
        },
        .ID_DYLIB, .LOAD_DYLIB => {
            const lc = given.dylib;
            if (exp.name) |name| {
                if (!mem.eql(u8, name, mem.sliceTo(lc.data, 0))) {
                    return err("dylib path mismatch", name, mem.sliceTo(lc.data, 0));
                }
            }
            if (exp.timestamp) |ts| {
                if (ts != lc.inner.dylib.timestamp) {
                    return err("timestamp mismatch", ts, lc.inner.dylib.timestamp);
                }
            }
            if (exp.current_version) |cv| {
                if (cv != lc.inner.dylib.current_version) {
                    return err("current version mismatch", cv, lc.inner.dylib.current_version);
                }
            }
            if (exp.compat_version) |cv| {
                if (cv != lc.inner.dylib.compatibility_version) {
                    return err("compatibility version mismatch", cv, lc.inner.dylib.compatibility_version);
                }
            }
        },
        .RPATH => {
            const lc = given.rpath;
            if (exp.name) |name| {
                if (!mem.eql(u8, name, mem.sliceTo(lc.data, 0))) {
                    return err("rpath path mismatch", name, mem.sliceTo(lc.data, 0));
                }
            }
        },
        else => @panic("TODO compare more load commands"),
    }
}

fn err(msg: []const u8, exp: anytype, giv: anytype) error{TestFailed} {
    const fmt_specifier = if (comptime isString(@TypeOf(exp))) "{s}" else switch (@typeInfo(@TypeOf(exp))) {
        .Int => "{x}",
        .Float => "{d}",
        else => "{any}",
    };
    std.debug.print(
        \\=====================================
        \\{s}
        \\
        \\======== Expected to find: ==========
        \\
    ++ fmt_specifier ++
        \\
        \\======== But instead found: =========
        \\
    ++ fmt_specifier ++
        \\
        \\
    , .{ msg, exp, giv });
    return error.TestFailed;
}

fn isString(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Array => return std.meta.Elem(T) == u8,
        .Pointer => |pinfo| {
            switch (pinfo.size) {
                .Slice, .Many => return std.meta.Elem(T) == u8,
                else => switch (@typeInfo(pinfo.child)) {
                    .Array => return isString(pinfo.child),
                    else => return false,
                },
            }
        },
        else => return false,
    }
}
