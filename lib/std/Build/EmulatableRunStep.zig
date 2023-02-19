//! Unlike `RunStep` this step will provide emulation, when enabled, to run foreign binaries.
//! When a binary is foreign, but emulation for the target is disabled, the specified binary
//! will not be run and therefore also not validated against its output.
//! This step can be useful when wishing to run a built binary on multiple platforms,
//! without having to verify if it's possible to be ran against.

const std = @import("../std.zig");
const Step = std.Build.Step;
const CompileStep = std.Build.CompileStep;
const RunStep = std.Build.RunStep;

const fs = std.fs;
const process = std.process;
const EnvMap = process.EnvMap;

const EmulatableRunStep = @This();

pub const base_id = .emulatable_run;

const max_stdout_size = 1 * 1024 * 1024; // 1 MiB

step: Step,
builder: *std.Build,

/// The artifact (executable) to be run by this step
exe: *CompileStep,

/// Set this to `null` to ignore the exit code for the purpose of determining a successful execution
expected_term: ?std.ChildProcess.Term = .{ .Exited = 0 },

/// Override this field to modify the environment
env_map: ?*EnvMap,

/// Set this to modify the current working directory
cwd: ?[]const u8,

stdout_action: RunStep.StdIoAction = .inherit,
stderr_action: RunStep.StdIoAction = .inherit,

/// When set to true, hides the warning of skipping a foreign binary which cannot be run on the host
/// or through emulation.
hide_foreign_binaries_warning: bool,

/// Creates a step that will execute the given artifact. This step will allow running the
/// binary through emulation when any of the emulation options such as `enable_rosetta` are set to true.
/// When set to false, and the binary is foreign, running the executable is skipped.
/// Asserts given artifact is an executable.
pub fn create(builder: *std.Build, name: []const u8, artifact: *CompileStep) *EmulatableRunStep {
    std.debug.assert(artifact.kind == .exe or artifact.kind == .test_exe);
    const self = builder.allocator.create(EmulatableRunStep) catch @panic("OOM");

    const option_name = "hide-foreign-warnings";
    const hide_warnings = if (builder.available_options_map.get(option_name) == null) warn: {
        break :warn builder.option(bool, option_name, "Hide the warning when a foreign binary which is incompatible is skipped") orelse false;
    } else false;

    self.* = .{
        .builder = builder,
        .step = Step.init(.emulatable_run, name, builder.allocator, make),
        .exe = artifact,
        .env_map = null,
        .cwd = null,
        .hide_foreign_binaries_warning = hide_warnings,
    };
    self.step.dependOn(&artifact.step);

    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(EmulatableRunStep, "step", step);
    const host_info = self.builder.host;

    var argv_list = std.ArrayList([]const u8).init(self.builder.allocator);
    defer argv_list.deinit();

    const need_cross_glibc = self.exe.target.isGnuLibC() and self.exe.is_linking_libc;
    switch (host_info.getExternalExecutor(self.exe.target_info, .{
        .qemu_fixes_dl = need_cross_glibc and self.builder.glibc_runtimes_dir != null,
        .link_libc = self.exe.is_linking_libc,
    })) {
        .native => {},
        .rosetta => if (!self.builder.enable_rosetta) return warnAboutForeignBinaries(self),
        .wine => |bin_name| if (self.builder.enable_wine) {
            try argv_list.append(bin_name);
        } else return,
        .qemu => |bin_name| if (self.builder.enable_qemu) {
            const glibc_dir_arg = if (need_cross_glibc)
                self.builder.glibc_runtimes_dir orelse return
            else
                null;
            try argv_list.append(bin_name);
            if (glibc_dir_arg) |dir| {
                // TODO look into making this a call to `linuxTriple`. This
                // needs the directory to be called "i686" rather than
                // "x86" which is why we do it manually here.
                const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                const cpu_arch = self.exe.target.getCpuArch();
                const os_tag = self.exe.target.getOsTag();
                const abi = self.exe.target.getAbi();
                const cpu_arch_name: []const u8 = if (cpu_arch == .x86)
                    "i686"
                else
                    @tagName(cpu_arch);
                const full_dir = try std.fmt.allocPrint(self.builder.allocator, fmt_str, .{
                    dir, cpu_arch_name, @tagName(os_tag), @tagName(abi),
                });

                try argv_list.append("-L");
                try argv_list.append(full_dir);
            }
        } else return warnAboutForeignBinaries(self),
        .darling => |bin_name| if (self.builder.enable_darling) {
            try argv_list.append(bin_name);
        } else return warnAboutForeignBinaries(self),
        .wasmtime => |bin_name| if (self.builder.enable_wasmtime) {
            try argv_list.append(bin_name);
            try argv_list.append("--dir=.");
        } else return warnAboutForeignBinaries(self),
        else => return warnAboutForeignBinaries(self),
    }

    if (self.exe.target.isWindows()) {
        // On Windows we don't have rpaths so we have to add .dll search paths to PATH
        RunStep.addPathForDynLibsInternal(&self.step, self.builder, self.exe);
    }

    const executable_path = self.exe.installed_path orelse self.exe.getOutputSource().getPath(self.builder);
    try argv_list.append(executable_path);

    try RunStep.runCommand(
        argv_list.items,
        self.builder,
        self.expected_term,
        self.stdout_action,
        self.stderr_action,
        .Inherit,
        self.env_map,
        self.cwd,
        false,
    );
}

pub fn expectStdErrEqual(self: *EmulatableRunStep, bytes: []const u8) void {
    self.stderr_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

pub fn expectStdOutEqual(self: *EmulatableRunStep, bytes: []const u8) void {
    self.stdout_action = .{ .expect_exact = self.builder.dupe(bytes) };
}

fn warnAboutForeignBinaries(step: *EmulatableRunStep) void {
    if (step.hide_foreign_binaries_warning) return;
    const builder = step.builder;
    const artifact = step.exe;

    const host_name = builder.host.target.zigTriple(builder.allocator) catch @panic("unhandled error");
    const foreign_name = artifact.target.zigTriple(builder.allocator) catch @panic("unhandled error");
    const target_info = std.zig.system.NativeTargetInfo.detect(artifact.target) catch @panic("unhandled error");
    const need_cross_glibc = artifact.target.isGnuLibC() and artifact.is_linking_libc;
    switch (builder.host.getExternalExecutor(target_info, .{
        .qemu_fixes_dl = need_cross_glibc and builder.glibc_runtimes_dir != null,
        .link_libc = artifact.is_linking_libc,
    })) {
        .native => unreachable,
        .bad_dl => |foreign_dl| {
            const host_dl = builder.host.dynamic_linker.get() orelse "(none)";
            std.debug.print("the host system does not appear to be capable of executing binaries from the target because the host dynamic linker is '{s}', while the target dynamic linker is '{s}'. Consider setting the dynamic linker as '{s}'.\n", .{
                host_dl, foreign_dl, host_dl,
            });
        },
        .bad_os_or_cpu => {
            std.debug.print("the host system ({s}) does not appear to be capable of executing binaries from the target ({s}).\n", .{
                host_name, foreign_name,
            });
        },
        .darling => if (!builder.enable_darling) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling darling.\n",
                .{ host_name, foreign_name },
            );
        },
        .rosetta => if (!builder.enable_rosetta) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling rosetta.\n",
                .{ host_name, foreign_name },
            );
        },
        .wine => if (!builder.enable_wine) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling wine.\n",
                .{ host_name, foreign_name },
            );
        },
        .qemu => if (!builder.enable_qemu) {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling qemu.\n",
                .{ host_name, foreign_name },
            );
        },
        .wasmtime => {
            std.debug.print(
                "the host system ({s}) does not appear to be capable of executing binaries " ++
                    "from the target ({s}). Consider enabling wasmtime.\n",
                .{ host_name, foreign_name },
            );
        },
    }
}
