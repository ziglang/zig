//! Here we test our MachO linker for correctness and functionality.
//! TODO migrate standalone tests from test/link/macho/* to here.

pub fn testAll(b: *std.Build) *Step {
    const macho_step = b.step("test-macho", "Run MachO tests");

    macho_step.dependOn(testSectionBoundarySymbols(b, .{
        .target = b.resolveTargetQuery(.{ .os_tag = .macos }),
    }));

    return macho_step;
}

fn testSectionBoundarySymbols(b: *std.Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-section-boundary-symbols", opts);

    const obj1 = addObject(b, opts, .{
        .name = "obj1",
        .cpp_source_bytes =
        \\constexpr const char* MESSAGE __attribute__((used, section("__DATA_CONST,__message_ptr"))) = "codebase";
        ,
    });

    const main_o = addObject(b, opts, .{
        .name = "main",
        .zig_source_bytes =
        \\const std = @import("std");
        \\extern fn interop() ?[*:0]const u8;
        \\pub fn main() !void {
        \\    std.debug.print("All your {s} are belong to us.\n", .{
        \\        if (interop()) |ptr| std.mem.span(ptr) else "(null)",
        \\    });
        \\}
        ,
    });

    {
        const obj2 = addObject(b, opts, .{
            .name = "obj2",
            .cpp_source_bytes =
            \\extern const char* message_pointer __asm("section$start$__DATA_CONST$__message_ptr");
            \\extern "C" const char* interop() {
            \\  return message_pointer;
            \\}
            ,
        });

        const exe = addExecutable(b, opts, .{ .name = "test" });
        exe.addObject(obj1);
        exe.addObject(obj2);
        exe.addObject(main_o);

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdErrEqual("All your codebase are belong to us.\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("external section$start$__DATA_CONST$__message_ptr");
        test_step.dependOn(&check.step);
    }

    {
        const obj3 = addObject(b, opts, .{
            .name = "obj3",
            .cpp_source_bytes =
            \\extern const char* message_pointer __asm("section$start$__DATA_CONST$__not_present");
            \\extern "C" const char* interop() {
            \\  return message_pointer;
            \\}
            ,
        });

        const exe = addExecutable(b, opts, .{ .name = "test" });
        exe.addObject(obj1);
        exe.addObject(obj3);
        exe.addObject(main_o);

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdErrEqual("All your (null) are belong to us.\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("external section$start$__DATA_CONST$__not_present");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn addTestStep(b: *std.Build, comptime prefix: []const u8, opts: Options) *Step {
    return link.addTestStep(b, "macho-" ++ prefix, opts);
}

const addObject = link.addObject;
const addExecutable = link.addExecutable;
const expectLinkErrors = link.expectLinkErrors;
const link = @import("link.zig");
const std = @import("std");
const Options = link.Options;
const Step = std.Build.Step;
