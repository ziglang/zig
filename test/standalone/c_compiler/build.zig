const std = @import("std");
const ArrayList = std.ArrayList;
const Builder = std.build.Builder;
const ChildProcess = std.ChildProcess;
const CrossTarget = std.zig.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const Str = []const u8;

const ExecutorRunStep = struct {
    const Self = @This();

    pub const base_id = .custom;

    step: Step,
    builder: *Builder,
    artifact: *LibExeObjStep,
    executor: Str,

    pub fn init(b: *Builder, artifact: *LibExeObjStep, executor: Str) Self {
        var step = Step.init(
            .custom,
            b.fmt("{s} {s}", .{ @typeName(Self), artifact.name }),
            b.allocator,
            make,
        );
        step.dependOn(&artifact.step);
        return Self{
            .builder = b,
            .step = step,
            .artifact = artifact,
            .executor = b.dupe(executor),
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        const exe = self.artifact.installed_path orelse
            self.artifact.getOutputSource().getPath(self.builder);
        var cmd = [_]Str{ self.executor, exe };
        const index: usize = if (self.executor.len == 0) 1 else 0;

        const result = try ChildProcess.exec(
            .{ .allocator = self.builder.allocator, .argv = cmd[index..] },
        );
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    std.debug.warn(
                        "\"{s} {s}\" exited with error code {}\n",
                        .{ self.executor, exe, code },
                    );
                    std.debug.warn("{s}\n", .{result.stderr});
                    return error.CommandFailed;
                }
            },
            else => {
                std.debug.warn(
                    "\"{s} {s}\" terminated unexpectedly\n",
                    .{ self.executor, exe },
                );
                std.debug.warn("{s}\n", .{result.stderr});
                return error.CommandFailed;
            },
        }
        std.debug.warn("{s}\n", .{result.stdout});
    }
};

fn executorRun(b: *Builder, artifact: *LibExeObjStep) ?*ExecutorRunStep {
    const opt_executor = switch (artifact.target.getExternalExecutor()) {
        .native, .unavailable => "",
        .qemu => |bin_name| bin_name,
        .wasmtime => |bin_name| bin_name,
        else => null,
    };
    if (opt_executor) |executor| {
        const opt_step = b.allocator.create(ExecutorRunStep) catch null;
        if (opt_step) |executorRunStep| {
            executorRunStep.* = ExecutorRunStep.init(b, artifact, executor);
            return executorRunStep;
        }
    }
    return null;
}

fn isSingleThreadedTarget(t: CrossTarget) bool {
    // WASM target will be detected automatically as single threaded

    // C++ lib doesn't work on ARM on multi-threaded mode yet:
    // https://reviews.llvm.org/D75183 (abandoned, used as a ref)
    return t.getCpuArch() == .arm;
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Test the program");

    const exe_c = b.addExecutable("test_c", null);
    b.default_step.dependOn(&exe_c.step);
    exe_c.addCSourceFile("test.c", &[0][]const u8{});
    exe_c.setBuildMode(mode);
    exe_c.setTarget(target);
    exe_c.linkLibC();

    const exe_cpp = b.addExecutable("test_cpp", null);
    b.default_step.dependOn(&exe_cpp.step);
    exe_cpp.addCSourceFile("test.cpp", &[0][]const u8{});
    exe_cpp.setBuildMode(mode);
    exe_cpp.setTarget(target);
    exe_cpp.linkLibCpp();
    exe_cpp.single_threaded = isSingleThreadedTarget(target);
    if (target.getCpuArch().isWasm()) {
        exe_cpp.defineCMacro("_LIBCPP_NO_EXCEPTIONS", null);
    }

    // disable broken LTO links:
    switch (target.getOsTag()) {
        .windows => {
            exe_cpp.want_lto = false;
        },
        .macos => {
            exe_cpp.want_lto = false;
            exe_c.want_lto = false;
        },
        else => {},
    }

    if (executorRun(b, exe_c)) |run_c_cmd| {
        test_step.dependOn(&run_c_cmd.step);
    } else {
        test_step.dependOn(&exe_c.step);
    }

    if (executorRun(b, exe_cpp)) |run_cpp_cmd| {
        test_step.dependOn(&run_cpp_cmd.step);
    } else {
        test_step.dependOn(&exe_cpp.step);
    }
}
