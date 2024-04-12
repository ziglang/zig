const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    add(b, test_step, .Debug, true);
    add(b, test_step, .ReleaseFast, false);
    add(b, test_step, .ReleaseSmall, false);
    add(b, test_step, .ReleaseSafe, true);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize_mode: std.builtin.OptimizeMode, is_safe: bool) void {
    {
        const lib = b.addExecutable(.{
            .name = "lib",
            .root_source_file = b.path("lib.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize_mode,
            .strip = false,
        });
        lib.entry = .disabled;
        lib.use_llvm = false;
        lib.use_lld = false;
        // to make sure the bss segment is emitted, we must import memory
        lib.import_memory = true;
        lib.link_gc_sections = false;

        const check_lib = lib.checkObject();

        // since we import memory, make sure it exists with the correct naming
        check_lib.checkInHeaders();
        check_lib.checkExact("Section import");
        check_lib.checkExact("entries 1");
        check_lib.checkExact("module env"); // default module name is "env"
        check_lib.checkExact("name memory"); // as per linker specification

        // since we are importing memory, ensure it's not exported
        check_lib.checkInHeaders();
        check_lib.checkNotPresent("Section export");

        // validate the name of the stack pointer
        check_lib.checkInHeaders();
        check_lib.checkExact("Section custom");
        check_lib.checkExact("type data_segment");
        check_lib.checkExact("names 2");
        check_lib.checkExact("index 0");
        check_lib.checkExact("name .rodata");
        // for safe optimization modes `undefined` is stored in data instead of bss.
        if (is_safe) {
            check_lib.checkExact("index 1");
            check_lib.checkExact("name .data");
            check_lib.checkNotPresent("name .bss");
        } else {
            check_lib.checkExact("index 1"); // bss section always last
            check_lib.checkExact("name .bss");
        }
        test_step.dependOn(&check_lib.step);
    }

    // verify zero'd declaration is stored in bss for all optimization modes.
    {
        const lib = b.addExecutable(.{
            .name = "lib",
            .root_source_file = b.path("lib2.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize_mode,
            .strip = false,
        });
        lib.entry = .disabled;
        lib.use_llvm = false;
        lib.use_lld = false;
        // to make sure the bss segment is emitted, we must import memory
        lib.import_memory = true;
        lib.link_gc_sections = false;

        const check_lib = lib.checkObject();
        check_lib.checkInHeaders();
        check_lib.checkExact("Section custom");
        check_lib.checkExact("type data_segment");
        check_lib.checkExact("names 2");
        check_lib.checkExact("index 0");
        check_lib.checkExact("name .rodata");
        check_lib.checkExact("index 1");
        check_lib.checkExact("name .bss");

        test_step.dependOn(&check_lib.step);
    }
}
