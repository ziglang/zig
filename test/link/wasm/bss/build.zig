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
        const lib = b.addSharedLibrary(.{
            .name = "lib",
            .root_source_file = .{ .path = "lib.zig" },
            .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
            .optimize = optimize_mode,
        });
        lib.use_llvm = false;
        lib.use_lld = false;
        lib.strip = false;
        // to make sure the bss segment is emitted, we must import memory
        lib.import_memory = true;

        const check_lib = lib.checkObject();

        // since we import memory, make sure it exists with the correct naming
        check_lib.checkStart("Section import");
        check_lib.checkNext("entries 1");
        check_lib.checkNext("module env"); // default module name is "env"
        check_lib.checkNext("name memory"); // as per linker specification

        // since we are importing memory, ensure it's not exported
        check_lib.checkNotPresent("Section export");

        // validate the name of the stack pointer
        check_lib.checkStart("Section custom");
        check_lib.checkNext("type data_segment");
        check_lib.checkNext("names 2");
        check_lib.checkNext("index 0");
        check_lib.checkNext("name .rodata");
        // for safe optimization modes `undefined` is stored in data instead of bss.
        if (is_safe) {
            check_lib.checkNext("index 1");
            check_lib.checkNext("name .data");
            check_lib.checkNotPresent("name .bss");
        } else {
            check_lib.checkNext("index 1"); // bss section always last
            check_lib.checkNext("name .bss");
        }
        test_step.dependOn(&check_lib.step);
    }

    // verify zero'd declaration is stored in bss for all optimization modes.
    {
        const lib = b.addSharedLibrary(.{
            .name = "lib",
            .root_source_file = .{ .path = "lib2.zig" },
            .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
            .optimize = optimize_mode,
        });
        lib.use_llvm = false;
        lib.use_lld = false;
        lib.strip = false;
        // to make sure the bss segment is emitted, we must import memory
        lib.import_memory = true;

        const check_lib = lib.checkObject();
        check_lib.checkStart("Section custom");
        check_lib.checkNext("type data_segment");
        check_lib.checkNext("names 2");
        check_lib.checkNext("index 0");
        check_lib.checkNext("name .rodata");
        check_lib.checkNext("index 1");
        check_lib.checkNext("name .bss");

        test_step.dependOn(&check_lib.step);
    }
}
