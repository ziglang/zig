//! Unlike `RunStep` this step will provide emulation, when enabled, to run foreign binaries.
//! When a binary is foreign, but emulation for the target is disabled, the specified binary
//! will not be run and therefore also not validated against its output.
//! This step can be useful when wishing to run a built binary on multiple platforms,
//! without having to verify if it's possible to be ran against.

const std = @import("../std.zig");
const build = std.build;
const Step = std.build.Step;
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

const fs = std.fs;
const process = std.process;
const EnvMap = process.EnvMap;

const RunCompareStep = @This();

pub const step_id = .run_and_compare;

step: Step,
builder: *Builder,

/// The artifact (executable) to be run by this step
exe: *LibExeObjStep,

/// Set this to `null` to ignore the exit code for the purpose of determining a successful execution
expected_exit_code: ?u8 = 0,

/// Override this field to modify the environment
env_map: ?*EnvMap,

pub fn create(builder: *Builder, name: []const u8, artifact: *LibExeObjStep) *RunCompareStep {
    std.debug.assert(artifact.kind == .exe or artifact.kind == .test_exe);
    const self = builder.allocator.create(RunCompareStep) catch unreachable;
    self.* = .{
        .builder = builder,
        .step = Step.init(.run_and_compare, name, builder.allocator, make),
        .exe = artifact,
        .env_map = null,
    };
    self.step.dependOn(&artifact.step);

    return self;
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(RunCompareStep, "step", step);
    const host_info = self.builder.host;
    const cwd = self.builder.build_root;
    _ = cwd;
    std.debug.print("Make called!\n", .{});

    var argv_list = std.ArrayList([]const u8).init(self.builder.allocator);
    _ = argv_list;

    const need_cross_glibc = self.exe.target.isGnuLibC() and self.exe.is_linking_libc;
    switch (host_info.getExternalExecutor(self.exe.target_info, .{
        .qemu_fixes_dl = need_cross_glibc and self.builder.glibc_runtimes_dir != null,
        .link_libc = self.exe.is_linking_libc,
    })) {
        .native => {},
        .rosetta => if (!self.builder.enable_rosetta) return,
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
                // "i386" which is why we do it manually here.
                const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                const cpu_arch = self.exe.target.getCpuArch();
                const os_tag = self.exe.target.getOsTag();
                const abi = self.exe.target.getAbi();
                const cpu_arch_name: []const u8 = if (cpu_arch == .i386)
                    "i686"
                else
                    @tagName(cpu_arch);
                const full_dir = try std.fmt.allocPrint(self.builder.allocator, fmt_str, .{
                    dir, cpu_arch_name, @tagName(os_tag), @tagName(abi),
                });

                try argv_list.append("-L");
                try argv_list.append(full_dir);
            }
        } else return,
        .darling => |bin_name| if (self.builder.enable_darling) {
            try argv_list.append(bin_name);
        } else return,
        .wasmtime => |bin_name| if (self.builder.enable_wasmtime) {
            try argv_list.append(bin_name);
            try argv_list.append("--dir=.");
        } else return,
        else => return, // on any failures we skip
    }

    if (self.exe.target.isWindows()) {
        // On Windows we don't have rpaths so we have to add .dll search paths to PATH
        self.addPathForDynLibs(self.exe);
    }

    const executable_path = self.exe.installed_path orelse self.exe.getOutputSource().getPath(self.builder);
    try argv_list.append(executable_path);
}

fn addPathForDynLibs(self: *RunCompareStep, artifact: *LibExeObjStep) void {
    for (artifact.link_objects.items) |link_object| {
        switch (link_object) {
            .other_step => |other| {
                if (other.target.isWindows() and other.isDynamicLibrary()) {
                    self.addPathDir(fs.path.dirname(other.getOutputSource().getPath(self.builder)).?);
                    self.addPathForDynLibs(other);
                }
            },
            else => {},
        }
    }
}

pub fn addPathDir(self: *RunCompareStep, search_path: []const u8) void {
    const env_map = self.getEnvMap();

    const key = "PATH";
    var prev_path = env_map.get(key);

    if (prev_path) |pp| {
        const new_path = self.builder.fmt("{s}" ++ [1]u8{fs.path.delimiter} ++ "{s}", .{ pp, search_path });
        env_map.put(key, new_path) catch unreachable;
    } else {
        env_map.put(key, self.builder.dupePath(search_path)) catch unreachable;
    }
}

pub fn getEnvMap(self: *RunCompareStep) *EnvMap {
    return self.env_map orelse {
        const env_map = self.builder.allocator.create(EnvMap) catch unreachable;
        env_map.* = process.getEnvMap(self.builder.allocator) catch unreachable;
        self.env_map = env_map;
        return env_map;
    };
}
