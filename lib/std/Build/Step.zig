id: Id,
name: []const u8,
makeFn: *const fn (self: *Step) anyerror!void,
dependencies: std.ArrayList(*Step),
/// This field is empty during execution of the user's build script, and
/// then populated during dependency loop checking in the build runner.
dependants: std.ArrayListUnmanaged(*Step),
state: State,
/// The return addresss associated with creation of this step that can be useful
/// to print along with debugging messages.
debug_stack_trace: [n_debug_stack_frames]usize,

result_error_msgs: std.ArrayListUnmanaged([]const u8),
result_error_bundle: std.zig.ErrorBundle,

const n_debug_stack_frames = 4;

pub const State = enum {
    precheck_unstarted,
    precheck_started,
    precheck_done,
    running,
    dependency_failure,
    success,
    failure,
};

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

pub const Options = struct {
    id: Id,
    name: []const u8,
    makeFn: *const fn (self: *Step) anyerror!void = makeNoOp,
    first_ret_addr: ?usize = null,
};

pub fn init(allocator: Allocator, options: Options) Step {
    var addresses = [1]usize{0} ** n_debug_stack_frames;
    const first_ret_addr = options.first_ret_addr orelse @returnAddress();
    var stack_trace = std.builtin.StackTrace{
        .instruction_addresses = &addresses,
        .index = 0,
    };
    std.debug.captureStackTrace(first_ret_addr, &stack_trace);

    return .{
        .id = options.id,
        .name = allocator.dupe(u8, options.name) catch @panic("OOM"),
        .makeFn = options.makeFn,
        .dependencies = std.ArrayList(*Step).init(allocator),
        .dependants = .{},
        .state = .precheck_unstarted,
        .debug_stack_trace = addresses,
        .result_error_msgs = .{},
        .result_error_bundle = std.zig.ErrorBundle.empty,
    };
}

/// If the Step's `make` function reports `error.MakeFailed`, it indicates they
/// have already reported the error. Otherwise, we add a simple error report
/// here.
pub fn make(s: *Step) error{MakeFailed}!void {
    return s.makeFn(s) catch |err| {
        if (err != error.MakeFailed) {
            const gpa = s.dependencies.allocator;
            s.result_error_msgs.append(gpa, std.fmt.allocPrint(gpa, "{s} failed: {s}", .{
                s.name, @errorName(err),
            }) catch @panic("OOM")) catch @panic("OOM");
        }
        return error.MakeFailed;
    };
}

pub fn dependOn(self: *Step, other: *Step) void {
    self.dependencies.append(other) catch @panic("OOM");
}

pub fn getStackTrace(s: *Step) std.builtin.StackTrace {
    const stack_addresses = &s.debug_stack_trace;
    var len: usize = 0;
    while (len < n_debug_stack_frames and stack_addresses[len] != 0) {
        len += 1;
    }
    return .{
        .instruction_addresses = stack_addresses,
        .index = len,
    };
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

/// For debugging purposes, prints identifying information about this Step.
pub fn dump(step: *Step) void {
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();

    const stderr = std.io.getStdErr();
    const w = stderr.writer();
    const tty_config = std.debug.detectTTYConfig(stderr);
    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        w.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{
            @errorName(err),
        }) catch {};
        return;
    };
    const ally = debug_info.allocator;
    w.print("name: '{s}'. creation stack trace:\n", .{step.name}) catch {};
    std.debug.writeStackTrace(step.getStackTrace(), w, ally, debug_info, tty_config) catch |err| {
        stderr.writer().print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch {};
        return;
    };
}

const Step = @This();
const std = @import("../std.zig");
const Build = std.Build;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
