const std = @import("std");
pub fn build(b: *std.Build) void {
    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &[0][]const u8{};

    const compiler_rt_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "compiler_rt",
        .use_llvm = false,
        .use_lld = false,
        .root_module = b.createModule(.{
            .root_source_file = b.addWriteFiles().add("compiler_rt.zig", ""),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64 }),
        }),
    });
    compiler_rt_lib.bundle_compiler_rt = true;

    for ([_]std.Target.Query{
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.bsf_bsr_0_clobbers_result}),
            //.cpu_features_sub = std.Target.x86.featureSet(&.{.sse}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.bsf_bsr_0_clobbers_result}),
            .cpu_features_sub = std.Target.x86.featureSet(&.{
                .cmov,
                //.sse,
            }),
        },
        //.{
        //    .cpu_arch = .x86_64,
        //    .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
        //    .cpu_features_sub = std.Target.x86.featureSet(&.{.sse}),
        //},
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_sub = std.Target.x86.featureSet(&.{.sse2}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.sse3}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.ssse3}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.sse4_1}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.sse4_2}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 },
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 },
            .cpu_features_add = std.Target.x86.featureSet(&.{.avx}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
            .cpu_features_sub = std.Target.x86.featureSet(&.{.avx2}),
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
        },
        .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v4 },
        },
    }) |query| {
        const target = b.resolveTargetQuery(query);
        const cpu = query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
        for ([_][]const u8{
            "math.zig",
            "mem.zig",
        }) |path| {
            const test_mod = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
            });
            const test_exe = b.addTest(.{
                .name = std.fs.path.stem(path),
                .filters = test_filters,
                .use_llvm = false,
                .use_lld = false,
                .root_module = test_mod,
            });
            if (!std.Target.x86.featureSetHas(target.result.cpu.features, .sse2)) {
                test_exe.bundle_compiler_rt = false;
                test_mod.linkLibrary(compiler_rt_lib);
            }
            const test_run = b.addRunArtifact(test_exe);
            b.default_step.dependOn(&test_run.step);
            for ([_]*std.Build.Step{
                &test_exe.step,
                &test_run.step,
            }) |step| step.name = b.fmt("{s} {s}", .{ step.name, cpu });
        }
    }
}
