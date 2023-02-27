id: Id,
name: []const u8,
makeFn: *const fn (self: *Step) anyerror!void,
dependencies: std.ArrayList(*Step),
loop_flag: bool,
done_flag: bool,

pub const Id = enum {
    top_level,
    compile,
    install_artifact,
    install_file,
    install_dir,
    log,
    remove_dir,
    fmt,
    translate_c,
    write_file,
    run,
    emulatable_run,
    check_file,
    check_object,
    config_header,
    objcopy,
    options,
    custom,

    pub fn Type(comptime id: Id) type {
        return switch (id) {
            .top_level => Build.TopLevelStep,
            .compile => Build.CompileStep,
            .install_artifact => Build.InstallArtifactStep,
            .install_file => Build.InstallFileStep,
            .install_dir => Build.InstallDirStep,
            .log => Build.LogStep,
            .remove_dir => Build.RemoveDirStep,
            .fmt => Build.FmtStep,
            .translate_c => Build.TranslateCStep,
            .write_file => Build.WriteFileStep,
            .run => Build.RunStep,
            .emulatable_run => Build.EmulatableRunStep,
            .check_file => Build.CheckFileStep,
            .check_object => Build.CheckObjectStep,
            .config_header => Build.ConfigHeaderStep,
            .objcopy => Build.ObjCopyStep,
            .options => Build.OptionsStep,
            .custom => @compileError("no type available for custom step"),
        };
    }
};

pub fn init(
    id: Id,
    name: []const u8,
    allocator: Allocator,
    makeFn: *const fn (self: *Step) anyerror!void,
) Step {
    return Step{
        .id = id,
        .name = allocator.dupe(u8, name) catch @panic("OOM"),
        .makeFn = makeFn,
        .dependencies = std.ArrayList(*Step).init(allocator),
        .loop_flag = false,
        .done_flag = false,
    };
}

pub fn initNoOp(id: Id, name: []const u8, allocator: Allocator) Step {
    return init(id, name, allocator, makeNoOp);
}

pub fn make(self: *Step) !void {
    if (self.done_flag) return;

    try self.makeFn(self);
    self.done_flag = true;
}

pub fn dependOn(self: *Step, other: *Step) void {
    self.dependencies.append(other) catch @panic("OOM");
}

fn makeNoOp(self: *Step) anyerror!void {
    _ = self;
}

pub fn cast(step: *Step, comptime T: type) ?*T {
    if (step.id == T.base_id) {
        return @fieldParentPtr(T, "step", step);
    }
    return null;
}

const Step = @This();
const std = @import("../std.zig");
const Build = std.Build;
const Allocator = std.mem.Allocator;
