const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    if (@import("builtin").os.tag == .windows) {
        // TODO: Fix open handle in wasm-linker refraining rename from working on Windows.
        return;
    }

    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .optimize = .ReleaseSafe, // to make the output deterministic in address positions
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
    });
    lib.entry = .disabled;
    lib.use_lld = false;
    lib.root_module.export_symbol_names = &.{ "foo", "bar" };
    lib.global_base = 0; // put data section at address 0 to make data symbols easier to parse

    const check_lib = lib.checkObject();

    check_lib.checkInHeaders();
    check_lib.checkExact("Section global");
    check_lib.checkExact("entries 3");
    check_lib.checkExact("type i32"); // stack pointer so skip other fields
    check_lib.checkExact("type i32");
    check_lib.checkExact("mutable false");
    check_lib.checkExtract("i32.const {foo_address}");
    check_lib.checkExact("type i32");
    check_lib.checkExact("mutable false");
    check_lib.checkExtract("i32.const {bar_address}");
    check_lib.checkComputeCompare("foo_address", .{ .op = .eq, .value = .{ .literal = 4 } });
    check_lib.checkComputeCompare("bar_address", .{ .op = .eq, .value = .{ .literal = 0 } });

    check_lib.checkInHeaders();
    check_lib.checkExact("Section export");
    check_lib.checkExact("entries 3");
    check_lib.checkExact("name foo");
    check_lib.checkExact("kind global");
    check_lib.checkExact("index 1");
    check_lib.checkExact("name bar");
    check_lib.checkExact("kind global");
    check_lib.checkExact("index 2");

    test_step.dependOn(&check_lib.step);
}
