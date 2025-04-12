gpa: Allocator,
arena: Allocator,
cases: std.ArrayList(Case),
translate: std.ArrayList(Translate),

pub const IncrementalCase = struct {
    base_path: []const u8,
};

pub const File = struct {
    src: [:0]const u8,
    path: []const u8,
};

pub const DepModule = struct {
    name: []const u8,
    path: []const u8,
};

pub const Backend = enum {
    stage1,
    stage2,
    llvm,
};

pub const CFrontend = enum {
    clang,
    aro,
};

pub const Case = struct {
    /// The name of the test case. This is shown if a test fails, and
    /// otherwise ignored.
    name: []const u8,
    /// The platform the test targets. For non-native platforms, an emulator
    /// such as QEMU is required for tests to complete.
    target: std.Build.ResolvedTarget,
    /// In order to be able to run e.g. Execution updates, this must be set
    /// to Executable.
    output_mode: std.builtin.OutputMode,
    optimize_mode: std.builtin.OptimizeMode = .Debug,

    files: std.ArrayList(File),
    case: ?union(enum) {
        /// Check that it compiles with no errors.
        Compile: void,
        /// Check the main binary output file against an expected set of bytes.
        /// This is most useful with, for example, `-ofmt=c`.
        CompareObjectFile: []const u8,
        /// An error update attempts to compile bad code, and ensures that it
        /// fails to compile, and for the expected reasons.
        /// A slice containing the expected stderr template, which
        /// gets some values substituted.
        Error: []const []const u8,
        /// An execution update compiles and runs the input, testing the
        /// stdout against the expected results
        /// This is a slice containing the expected message.
        Execution: []const u8,
        /// A header update compiles the input with the equivalent of
        /// `-femit-h` and tests the produced header against the
        /// expected result.
        Header: []const u8,
    },

    emit_bin: bool = true,
    emit_h: bool = false,
    is_test: bool = false,
    expect_exact: bool = false,
    backend: Backend = .stage2,
    link_libc: bool = false,
    pic: ?bool = null,
    pie: ?bool = null,
    /// A list of imports to cache alongside the source file.
    imports: []const []const u8 = &.{},
    /// Where to look for imports relative to the `cases_dir_path` given to
    /// `lower_to_build_steps`. If null, file imports will assert.
    import_path: ?[]const u8 = null,

    deps: std.ArrayList(DepModule),

    pub fn addSourceFile(case: *Case, name: []const u8, src: [:0]const u8) void {
        case.files.append(.{ .path = name, .src = src }) catch @panic("OOM");
    }

    pub fn addDepModule(case: *Case, name: []const u8, path: []const u8) void {
        case.deps.append(.{
            .name = name,
            .path = path,
        }) catch @panic("out of memory");
    }

    /// Adds a subcase in which the module is updated with `src`, compiled,
    /// run, and the output is tested against `result`.
    pub fn addCompareOutput(self: *Case, src: [:0]const u8, result: []const u8) void {
        assert(self.case == null);
        self.case = .{ .Execution = result };
        self.addSourceFile("tmp.zig", src);
    }

    /// Adds a subcase in which the module is updated with `src`, which
    /// should contain invalid input, and ensures that compilation fails
    /// for the expected reasons, given in sequential order in `errors` in
    /// the form `:line:column: error: message`.
    pub fn addError(self: *Case, src: [:0]const u8, errors: []const []const u8) void {
        assert(errors.len != 0);
        assert(self.case == null);
        self.case = .{ .Error = errors };
        self.addSourceFile("tmp.zig", src);
    }

    /// Adds a subcase in which the module is updated with `src`, and
    /// asserts that it compiles without issue
    pub fn addCompile(self: *Case, src: [:0]const u8) void {
        assert(self.case == null);
        self.case = .Compile;
        self.addSourceFile("tmp.zig", src);
    }
};

pub const Translate = struct {
    /// The name of the test case. This is shown if a test fails, and
    /// otherwise ignored.
    name: []const u8,

    input: [:0]const u8,
    target: std.Build.ResolvedTarget,
    link_libc: bool,
    c_frontend: CFrontend,
    kind: union(enum) {
        /// Translate the input, run it and check that it
        /// outputs the expected text.
        run: []const u8,
        /// Translate the input and check that it contains
        /// the expected lines of code.
        translate: []const []const u8,
    },
};

pub fn addExe(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
) *Case {
    ctx.cases.append(.{
        .name = name,
        .target = target,
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Exe,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

/// Adds a test case for Zig input, producing an executable
pub fn exe(ctx: *Cases, name: []const u8, target: std.Build.ResolvedTarget) *Case {
    return ctx.addExe(name, target);
}

pub fn exeFromCompiledC(ctx: *Cases, name: []const u8, target_query: std.Target.Query, b: *std.Build) *Case {
    var adjusted_query = target_query;
    adjusted_query.ofmt = .c;
    ctx.cases.append(.{
        .name = name,
        .target = b.resolveTargetQuery(adjusted_query),
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Exe,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
        .link_libc = true,
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

pub fn addObjLlvm(ctx: *Cases, name: []const u8, target: std.Build.ResolvedTarget) *Case {
    ctx.cases.append(.{
        .name = name,
        .target = target,
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Obj,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
        .backend = .llvm,
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

pub fn addObj(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
) *Case {
    ctx.cases.append(.{
        .name = name,
        .target = target,
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Obj,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

pub fn addTest(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
) *Case {
    ctx.cases.append(.{
        .name = name,
        .target = target,
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Exe,
        .is_test = true,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

/// Adds a test case for Zig input, producing an object file.
pub fn obj(ctx: *Cases, name: []const u8, target: std.Build.ResolvedTarget) *Case {
    return ctx.addObj(name, target);
}

/// Adds a test case for ZIR input, producing an object file.
pub fn objZIR(ctx: *Cases, name: []const u8, target: std.Build.ResolvedTarget) *Case {
    return ctx.addObj(name, target, .ZIR);
}

/// Adds a test case for Zig or ZIR input, producing C code.
pub fn addC(ctx: *Cases, name: []const u8, target: std.Build.ResolvedTarget) *Case {
    var target_adjusted = target;
    target_adjusted.ofmt = std.Target.ObjectFormat.c;
    ctx.cases.append(.{
        .name = name,
        .target = target_adjusted,
        .files = .init(ctx.arena),
        .case = null,
        .output_mode = .Obj,
        .deps = std.ArrayList(DepModule).init(ctx.arena),
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}

pub fn addCompareOutput(
    ctx: *Cases,
    name: []const u8,
    src: [:0]const u8,
    expected_stdout: []const u8,
) void {
    ctx.addExe(name, .{}).addCompareOutput(src, expected_stdout);
}

/// Adds a test case that compiles the Zig source given in `src`, executes
/// it, runs it, and tests the output against `expected_stdout`
pub fn compareOutput(
    ctx: *Cases,
    name: []const u8,
    src: [:0]const u8,
    expected_stdout: []const u8,
) void {
    return ctx.addCompareOutput(name, src, expected_stdout);
}

pub fn addTransform(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    src: [:0]const u8,
    result: [:0]const u8,
) void {
    ctx.addObj(name, target).addTransform(src, result);
}

/// Adds a test case that compiles the Zig given in `src` to ZIR and tests
/// the ZIR against `result`
pub fn transform(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    src: [:0]const u8,
    result: [:0]const u8,
) void {
    ctx.addTransform(name, target, src, result);
}

pub fn addError(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    src: [:0]const u8,
    expected_errors: []const []const u8,
) void {
    ctx.addObj(name, target).addError(src, expected_errors);
}

/// Adds a test case that ensures that the Zig given in `src` fails to
/// compile for the expected reasons, given in sequential order in
/// `expected_errors` in the form `:line:column: error: message`.
pub fn compileError(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    src: [:0]const u8,
    expected_errors: []const []const u8,
) void {
    ctx.addError(name, target, src, expected_errors);
}

/// Adds a test case that asserts that the Zig given in `src` compiles
/// without any errors.
pub fn addCompile(
    ctx: *Cases,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    src: [:0]const u8,
) void {
    ctx.addObj(name, target).addCompile(src);
}

/// Adds a test for each file in the provided directory. Recurses nested directories.
///
/// Each file should include a test manifest as a contiguous block of comments at
/// the end of the file. The first line should be the test type, followed by a set of
/// key-value config values, followed by a blank line, then the expected output.
pub fn addFromDir(ctx: *Cases, dir: std.fs.Dir, b: *std.Build) void {
    var current_file: []const u8 = "none";
    ctx.addFromDirInner(dir, &current_file, b) catch |err| {
        std.debug.panicExtra(
            @returnAddress(),
            "test harness failed to process file '{s}': {s}\n",
            .{ current_file, @errorName(err) },
        );
    };
}

fn addFromDirInner(
    ctx: *Cases,
    iterable_dir: std.fs.Dir,
    /// This is kept up to date with the currently being processed file so
    /// that if any errors occur the caller knows it happened during this file.
    current_file: *[]const u8,
    b: *std.Build,
) !void {
    var it = try iterable_dir.walk(ctx.arena);
    var filenames: std.ArrayListUnmanaged([]const u8) = .empty;

    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        // Ignore stuff such as .swp files
        if (!knownFileExtension(entry.basename)) continue;
        try filenames.append(ctx.arena, try ctx.arena.dupe(u8, entry.path));
    }

    for (filenames.items) |filename| {
        current_file.* = filename;

        const max_file_size = 10 * 1024 * 1024;
        const src = try iterable_dir.readFileAllocOptions(ctx.arena, filename, max_file_size, null, .@"1", 0);

        // Parse the manifest
        var manifest = try TestManifest.parse(ctx.arena, src);

        const backends = try manifest.getConfigForKeyAlloc(ctx.arena, "backend", Backend);
        const targets = try manifest.getConfigForKeyAlloc(ctx.arena, "target", std.Target.Query);
        const c_frontends = try manifest.getConfigForKeyAlloc(ctx.arena, "c_frontend", CFrontend);
        const is_test = try manifest.getConfigForKeyAssertSingle("is_test", bool);
        const link_libc = try manifest.getConfigForKeyAssertSingle("link_libc", bool);
        const output_mode = try manifest.getConfigForKeyAssertSingle("output_mode", std.builtin.OutputMode);
        const pic = try manifest.getConfigForKeyAssertSingle("pic", ?bool);
        const pie = try manifest.getConfigForKeyAssertSingle("pie", ?bool);
        const emit_bin = try manifest.getConfigForKeyAssertSingle("emit_bin", bool);
        const imports = try manifest.getConfigForKeyAlloc(ctx.arena, "imports", []const u8);

        if (manifest.type == .translate_c) {
            for (c_frontends) |c_frontend| {
                for (targets) |target_query| {
                    const output = try manifest.trailingLinesSplit(ctx.arena);
                    try ctx.translate.append(.{
                        .name = std.fs.path.stem(filename),
                        .c_frontend = c_frontend,
                        .target = b.resolveTargetQuery(target_query),
                        .link_libc = link_libc,
                        .input = src,
                        .kind = .{ .translate = output },
                    });
                }
            }
            continue;
        }
        if (manifest.type == .run_translated_c) {
            for (c_frontends) |c_frontend| {
                for (targets) |target_query| {
                    const output = try manifest.trailingSplit(ctx.arena);
                    try ctx.translate.append(.{
                        .name = std.fs.path.stem(filename),
                        .c_frontend = c_frontend,
                        .target = b.resolveTargetQuery(target_query),
                        .link_libc = link_libc,
                        .input = src,
                        .kind = .{ .run = output },
                    });
                }
            }
            continue;
        }

        var cases = std.ArrayList(usize).init(ctx.arena);

        // Cross-product to get all possible test combinations
        for (targets) |target_query| {
            const resolved_target = b.resolveTargetQuery(target_query);
            const target = resolved_target.result;
            for (backends) |backend| {
                if (backend == .stage2 and
                    target.cpu.arch != .wasm32 and target.cpu.arch != .x86_64 and target.cpu.arch != .spirv64)
                {
                    // Other backends don't support new liveness format
                    continue;
                }
                if (backend == .stage2 and target.os.tag == .macos and
                    target.cpu.arch == .x86_64 and builtin.cpu.arch == .aarch64)
                {
                    // Rosetta has issues with ZLD
                    continue;
                }
                if (backend == .stage2 and target.ofmt == .coff) {
                    // COFF linker has bitrotted
                    continue;
                }

                const next = ctx.cases.items.len;
                try ctx.cases.append(.{
                    .name = std.fs.path.stem(filename),
                    .import_path = std.fs.path.dirname(filename),
                    .backend = backend,
                    .files = .init(ctx.arena),
                    .case = null,
                    .emit_bin = emit_bin,
                    .is_test = is_test,
                    .output_mode = output_mode,
                    .link_libc = link_libc,
                    .pic = pic,
                    .pie = pie,
                    .deps = std.ArrayList(DepModule).init(ctx.cases.allocator),
                    .imports = imports,
                    .target = resolved_target,
                });
                try cases.append(next);
            }
        }

        for (cases.items) |case_index| {
            const case = &ctx.cases.items[case_index];
            switch (manifest.type) {
                .compile => {
                    case.addCompile(src);
                },
                .@"error" => {
                    const errors = try manifest.trailingLines(ctx.arena);
                    case.addError(src, errors);
                },
                .run => {
                    const output = try manifest.trailingSplit(ctx.arena);
                    case.addCompareOutput(src, output);
                },
                .translate_c => @panic("c_frontend specified for compile case"),
                .run_translated_c => @panic("c_frontend specified for compile case"),
                .cli => @panic("TODO cli tests"),
            }
        }
    }
}

pub fn init(gpa: Allocator, arena: Allocator) Cases {
    return .{
        .gpa = gpa,
        .cases = std.ArrayList(Case).init(gpa),
        .translate = std.ArrayList(Translate).init(gpa),
        .arena = arena,
    };
}

pub const TranslateCOptions = struct {
    skip_translate_c: bool = false,
    skip_run_translated_c: bool = false,
};
pub fn lowerToTranslateCSteps(
    self: *Cases,
    b: *std.Build,
    parent_step: *std.Build.Step,
    test_filters: []const []const u8,
    test_target_filters: []const []const u8,
    target: std.Build.ResolvedTarget,
    translate_c_options: TranslateCOptions,
) void {
    const tests = @import("../tests.zig");
    const test_translate_c_step = b.step("test-translate-c", "Run the C translation tests");
    if (!translate_c_options.skip_translate_c) {
        tests.addTranslateCTests(b, test_translate_c_step, test_filters, test_target_filters);
        parent_step.dependOn(test_translate_c_step);
    }

    const test_run_translated_c_step = b.step("test-run-translated-c", "Run the Run-Translated-C tests");
    if (!translate_c_options.skip_run_translated_c) {
        tests.addRunTranslatedCTests(b, test_run_translated_c_step, test_filters, target);
        parent_step.dependOn(test_run_translated_c_step);
    }

    for (self.translate.items) |case| switch (case.kind) {
        .run => |output| {
            if (translate_c_options.skip_run_translated_c) continue;
            const annotated_case_name = b.fmt("run-translated-c {s}", .{case.name});
            for (test_filters) |test_filter| {
                if (std.mem.indexOf(u8, annotated_case_name, test_filter)) |_| break;
            } else if (test_filters.len > 0) continue;
            if (!std.process.can_spawn) {
                std.debug.print("Unable to spawn child processes on {s}, skipping test.\n", .{@tagName(builtin.os.tag)});
                continue; // Pass test.
            }

            const write_src = b.addWriteFiles();
            const file_source = write_src.add("tmp.c", case.input);

            const translate_c = b.addTranslateC(.{
                .root_source_file = file_source,
                .optimize = .Debug,
                .target = case.target,
                .link_libc = case.link_libc,
                .use_clang = case.c_frontend == .clang,
            });
            translate_c.step.name = b.fmt("{s} translate-c", .{annotated_case_name});

            const run_exe = b.addExecutable(.{
                .name = "translated_c",
                .root_module = translate_c.createModule(),
            });
            run_exe.step.name = b.fmt("{s} build-exe", .{annotated_case_name});
            run_exe.linkLibC();
            const run = b.addRunArtifact(run_exe);
            run.step.name = b.fmt("{s} run", .{annotated_case_name});
            run.expectStdOutEqual(output);
            run.skip_foreign_checks = true;

            test_run_translated_c_step.dependOn(&run.step);
        },
        .translate => |output| {
            if (translate_c_options.skip_translate_c) continue;
            const annotated_case_name = b.fmt("zig translate-c {s}", .{case.name});
            for (test_filters) |test_filter| {
                if (std.mem.indexOf(u8, annotated_case_name, test_filter)) |_| break;
            } else if (test_filters.len > 0) continue;

            const write_src = b.addWriteFiles();
            const file_source = write_src.add("tmp.c", case.input);

            const translate_c = b.addTranslateC(.{
                .root_source_file = file_source,
                .optimize = .Debug,
                .target = case.target,
                .link_libc = case.link_libc,
                .use_clang = case.c_frontend == .clang,
            });
            translate_c.step.name = b.fmt("{s} translate-c", .{annotated_case_name});

            const check_file = translate_c.addCheckFile(output);
            check_file.step.name = b.fmt("{s} CheckFile", .{annotated_case_name});
            test_translate_c_step.dependOn(&check_file.step);
        },
    };
}

pub fn lowerToBuildSteps(
    self: *Cases,
    b: *std.Build,
    parent_step: *std.Build.Step,
    test_filters: []const []const u8,
    test_target_filters: []const []const u8,
) void {
    const host = std.zig.system.resolveTargetQuery(.{}) catch |err|
        std.debug.panic("unable to detect native host: {s}\n", .{@errorName(err)});
    const cases_dir_path = b.build_root.join(b.allocator, &.{ "test", "cases" }) catch @panic("OOM");

    for (self.cases.items) |case| {
        for (test_filters) |test_filter| {
            if (std.mem.indexOf(u8, case.name, test_filter)) |_| break;
        } else if (test_filters.len > 0) continue;

        const triple_txt = case.target.result.zigTriple(b.allocator) catch @panic("OOM");

        if (test_target_filters.len > 0) {
            for (test_target_filters) |filter| {
                if (std.mem.indexOf(u8, triple_txt, filter) != null) break;
            } else continue;
        }

        const writefiles = b.addWriteFiles();
        var file_sources = std.StringHashMap(std.Build.LazyPath).init(b.allocator);
        defer file_sources.deinit();
        const first_file = case.files.items[0];
        const root_source_file = writefiles.add(first_file.path, first_file.src);
        file_sources.put(first_file.path, root_source_file) catch @panic("OOM");
        for (case.files.items[1..]) |file| {
            file_sources.put(file.path, writefiles.add(file.path, file.src)) catch @panic("OOM");
        }

        for (case.imports) |import_rel| {
            const import_abs = std.fs.path.join(b.allocator, &.{
                cases_dir_path,
                case.import_path orelse @panic("import_path not set"),
                import_rel,
            }) catch @panic("OOM");
            _ = writefiles.addCopyFile(.{ .cwd_relative = import_abs }, import_rel);
        }

        const mod = b.createModule(.{
            .root_source_file = root_source_file,
            .target = case.target,
            .optimize = case.optimize_mode,
        });

        if (case.link_libc) mod.link_libc = true;
        if (case.pic) |pic| mod.pic = pic;
        for (case.deps.items) |dep| {
            mod.addAnonymousImport(dep.name, .{
                .root_source_file = file_sources.get(dep.path).?,
            });
        }

        const artifact = if (case.is_test) b.addTest(.{
            .name = case.name,
            .root_module = mod,
        }) else switch (case.output_mode) {
            .Obj => b.addObject(.{
                .name = case.name,
                .root_module = mod,
            }),
            .Lib => b.addLibrary(.{
                .linkage = .static,
                .name = case.name,
                .root_module = mod,
            }),
            .Exe => b.addExecutable(.{
                .name = case.name,
                .root_module = mod,
            }),
        };

        if (case.pie) |pie| artifact.pie = pie;

        switch (case.backend) {
            .stage1 => continue,
            .stage2 => {
                artifact.use_llvm = false;
                artifact.use_lld = false;
            },
            .llvm => {
                artifact.use_llvm = true;
            },
        }

        switch (case.case.?) {
            .Compile => {
                // Force the binary to be emitted if requested.
                if (case.emit_bin) {
                    _ = artifact.getEmittedBin();
                }
                parent_step.dependOn(&artifact.step);
            },
            .CompareObjectFile => |expected_output| {
                const check = b.addCheckFile(artifact.getEmittedBin(), .{
                    .expected_exact = expected_output,
                });

                parent_step.dependOn(&check.step);
            },
            .Error => |expected_msgs| {
                assert(expected_msgs.len != 0);
                artifact.expect_errors = .{ .exact = expected_msgs };
                parent_step.dependOn(&artifact.step);
            },
            .Execution => |expected_stdout| no_exec: {
                const run = if (case.target.result.ofmt == .c) run_step: {
                    if (getExternalExecutor(host, &case.target.result, .{ .link_libc = true }) != .native) {
                        // We wouldn't be able to run the compiled C code.
                        break :no_exec;
                    }
                    const run_c = b.addSystemCommand(&.{
                        b.graph.zig_exe,
                        "run",
                        "-cflags",
                        "-Ilib",
                        "-std=c99",
                        "-pedantic",
                        "-Werror",
                        "-Wno-dollar-in-identifier-extension",
                        "-Wno-incompatible-library-redeclaration", // https://github.com/ziglang/zig/issues/875
                        "-Wno-incompatible-pointer-types",
                        "-Wno-overlength-strings",
                        "--",
                        "-lc",
                        "-target",
                        triple_txt,
                    });
                    run_c.addArtifactArg(artifact);
                    break :run_step run_c;
                } else b.addRunArtifact(artifact);
                run.skip_foreign_checks = true;
                if (!case.is_test) {
                    run.expectStdOutEqual(expected_stdout);
                }
                parent_step.dependOn(&run.step);
            },
            .Header => @panic("TODO"),
        }
    }
}

/// Default config values for known test manifest key-value pairings.
/// Currently handled defaults are:
/// * backend
/// * target
/// * output_mode
/// * is_test
const TestManifestConfigDefaults = struct {
    /// Asserts if the key doesn't exist - yep, it's an oversight alright.
    fn get(@"type": TestManifest.Type, key: []const u8) []const u8 {
        if (std.mem.eql(u8, key, "backend")) {
            return "stage2";
        } else if (std.mem.eql(u8, key, "target")) {
            if (@"type" == .@"error" or @"type" == .translate_c or @"type" == .run_translated_c) {
                return "native";
            }
            return comptime blk: {
                var defaults: []const u8 = "";
                // TODO should we only return "mainstream" targets by default here?
                // TODO we should also specify ABIs explicitly as the backends are
                // getting more and more complete
                // Linux
                for (&[_][]const u8{ "x86_64", "arm", "aarch64" }) |arch| {
                    defaults = defaults ++ arch ++ "-linux" ++ ",";
                }
                // macOS
                for (&[_][]const u8{ "x86_64", "aarch64" }) |arch| {
                    defaults = defaults ++ arch ++ "-macos" ++ ",";
                }
                // Windows
                defaults = defaults ++ "x86_64-windows" ++ ",";
                // Wasm
                defaults = defaults ++ "wasm32-wasi";
                break :blk defaults;
            };
        } else if (std.mem.eql(u8, key, "output_mode")) {
            return switch (@"type") {
                .@"error" => "Obj",
                .run => "Exe",
                .compile => "Obj",
                .translate_c => "Obj",
                .run_translated_c => "Obj",
                .cli => @panic("TODO test harness for CLI tests"),
            };
        } else if (std.mem.eql(u8, key, "emit_bin")) {
            return "true";
        } else if (std.mem.eql(u8, key, "is_test")) {
            return "false";
        } else if (std.mem.eql(u8, key, "link_libc")) {
            return "false";
        } else if (std.mem.eql(u8, key, "c_frontend")) {
            return "clang";
        } else if (std.mem.eql(u8, key, "pic")) {
            return "null";
        } else if (std.mem.eql(u8, key, "pie")) {
            return "null";
        } else if (std.mem.eql(u8, key, "imports")) {
            return "";
        } else unreachable;
    }
};

/// Manifest syntax example:
/// (see https://github.com/ziglang/zig/issues/11288)
///
/// error
/// backend=stage1,stage2
/// output_mode=exe
///
/// :3:19: error: foo
///
/// run
/// target=x86_64-linux,aarch64-macos
///
/// I am expected stdout! Hello!
///
/// cli
///
/// build test
const TestManifest = struct {
    type: Type,
    config_map: std.StringHashMap([]const u8),
    trailing_bytes: []const u8 = "",

    const valid_keys = std.StaticStringMap(void).initComptime(.{
        .{ "emit_bin", {} },
        .{ "is_test", {} },
        .{ "output_mode", {} },
        .{ "target", {} },
        .{ "c_frontend", {} },
        .{ "link_libc", {} },
        .{ "backend", {} },
        .{ "pic", {} },
        .{ "pie", {} },
        .{ "imports", {} },
    });

    const Type = enum {
        @"error",
        run,
        cli,
        compile,
        translate_c,
        run_translated_c,
    };

    const TrailingIterator = struct {
        inner: std.mem.TokenIterator(u8, .any),

        fn next(self: *TrailingIterator) ?[]const u8 {
            const next_inner = self.inner.next() orelse return null;
            return if (next_inner.len == 2) "" else std.mem.trimRight(u8, next_inner[3..], " \t");
        }
    };

    fn ConfigValueIterator(comptime T: type) type {
        return struct {
            inner: std.mem.TokenIterator(u8, .scalar),

            fn next(self: *@This()) !?T {
                const next_raw = self.inner.next() orelse return null;
                const parseFn = getDefaultParser(T);
                return try parseFn(next_raw);
            }
        };
    }

    fn parse(arena: Allocator, bytes: []const u8) !TestManifest {
        // The manifest is the last contiguous block of comments in the file
        // We scan for the beginning by searching backward for the first non-empty line that does not start with "//"
        var start: ?usize = null;
        var end: usize = bytes.len;
        if (bytes.len > 0) {
            var cursor: usize = bytes.len - 1;
            while (true) {
                // Move to beginning of line
                while (cursor > 0 and bytes[cursor - 1] != '\n') cursor -= 1;

                if (std.mem.startsWith(u8, bytes[cursor..], "//")) {
                    start = cursor; // Contiguous comment line, include in manifest
                } else {
                    if (start != null) break; // Encountered non-comment line, end of manifest

                    // We ignore all-whitespace lines following the comment block, but anything else
                    // means that there is no manifest present.
                    if (std.mem.trim(u8, bytes[cursor..end], " \r\n\t").len == 0) {
                        end = cursor;
                    } else break; // If it's not whitespace, there is no manifest
                }

                // Move to previous line
                if (cursor != 0) cursor -= 1 else break;
            }
        }

        const actual_start = start orelse return error.MissingTestManifest;
        const manifest_bytes = bytes[actual_start..end];

        var it = std.mem.tokenizeAny(u8, manifest_bytes, "\r\n");

        // First line is the test type
        const tt: Type = blk: {
            const line = it.next() orelse return error.MissingTestCaseType;
            const raw = std.mem.trim(u8, line[2..], " \t");
            if (std.mem.eql(u8, raw, "error")) {
                break :blk .@"error";
            } else if (std.mem.eql(u8, raw, "run")) {
                break :blk .run;
            } else if (std.mem.eql(u8, raw, "cli")) {
                break :blk .cli;
            } else if (std.mem.eql(u8, raw, "compile")) {
                break :blk .compile;
            } else if (std.mem.eql(u8, raw, "translate-c")) {
                break :blk .translate_c;
            } else if (std.mem.eql(u8, raw, "run-translated-c")) {
                break :blk .run_translated_c;
            } else {
                std.log.warn("unknown test case type requested: {s}", .{raw});
                return error.UnknownTestCaseType;
            }
        };

        var manifest: TestManifest = .{
            .type = tt,
            .config_map = std.StringHashMap([]const u8).init(arena),
        };

        // Any subsequent line until a blank comment line is key=value(s) pair
        while (it.next()) |line| {
            const trimmed = std.mem.trim(u8, line[2..], " \t");
            if (trimmed.len == 0) break;

            // Parse key=value(s)
            var kv_it = std.mem.splitScalar(u8, trimmed, '=');
            const key = kv_it.first();
            if (!valid_keys.has(key)) {
                return error.InvalidKey;
            }
            try manifest.config_map.putNoClobber(key, kv_it.next() orelse return error.MissingValuesForConfig);
        }

        // Finally, trailing is expected output
        manifest.trailing_bytes = manifest_bytes[it.index..];

        return manifest;
    }

    fn getConfigForKey(
        self: TestManifest,
        key: []const u8,
        comptime T: type,
    ) ConfigValueIterator(T) {
        const bytes = self.config_map.get(key) orelse TestManifestConfigDefaults.get(self.type, key);
        return ConfigValueIterator(T){
            .inner = std.mem.tokenizeScalar(u8, bytes, ','),
        };
    }

    fn getConfigForKeyAlloc(
        self: TestManifest,
        allocator: Allocator,
        key: []const u8,
        comptime T: type,
    ) ![]const T {
        var out = std.ArrayList(T).init(allocator);
        defer out.deinit();
        var it = self.getConfigForKey(key, T);
        while (try it.next()) |item| {
            try out.append(item);
        }
        return try out.toOwnedSlice();
    }

    fn getConfigForKeyAssertSingle(self: TestManifest, key: []const u8, comptime T: type) !T {
        var it = self.getConfigForKey(key, T);
        const res = (try it.next()) orelse unreachable;
        assert((try it.next()) == null);
        return res;
    }

    fn trailing(self: TestManifest) TrailingIterator {
        return .{
            .inner = std.mem.tokenizeAny(u8, self.trailing_bytes, "\r\n"),
        };
    }

    fn trailingSplit(self: TestManifest, allocator: Allocator) error{OutOfMemory}![]const u8 {
        var out = std.ArrayList(u8).init(allocator);
        defer out.deinit();
        var trailing_it = self.trailing();
        while (trailing_it.next()) |line| {
            try out.appendSlice(line);
            try out.append('\n');
        }
        if (out.items.len > 0) {
            try out.resize(out.items.len - 1);
        }
        return try out.toOwnedSlice();
    }

    fn trailingLines(self: TestManifest, allocator: Allocator) error{OutOfMemory}![]const []const u8 {
        var out = std.ArrayList([]const u8).init(allocator);
        defer out.deinit();
        var it = self.trailing();
        while (it.next()) |line| {
            try out.append(line);
        }
        return try out.toOwnedSlice();
    }

    fn trailingLinesSplit(self: TestManifest, allocator: Allocator) error{OutOfMemory}![]const []const u8 {
        // Collect output lines split by empty lines
        var out = std.ArrayList([]const u8).init(allocator);
        defer out.deinit();
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        var it = self.trailing();
        while (it.next()) |line| {
            if (line.len == 0) {
                if (buf.items.len != 0) {
                    try out.append(try buf.toOwnedSlice());
                    buf.items.len = 0;
                }
                continue;
            }
            try buf.appendSlice(line);
            try buf.append('\n');
        }
        try out.append(try buf.toOwnedSlice());
        return try out.toOwnedSlice();
    }

    fn ParseFn(comptime T: type) type {
        return fn ([]const u8) anyerror!T;
    }

    fn getDefaultParser(comptime T: type) ParseFn(T) {
        if (T == std.Target.Query) return struct {
            fn parse(str: []const u8) anyerror!T {
                return std.Target.Query.parse(.{ .arch_os_abi = str });
            }
        }.parse;

        switch (@typeInfo(T)) {
            .int => return struct {
                fn parse(str: []const u8) anyerror!T {
                    return try std.fmt.parseInt(T, str, 0);
                }
            }.parse,
            .bool => return struct {
                fn parse(str: []const u8) anyerror!T {
                    if (std.mem.eql(u8, str, "true")) return true;
                    if (std.mem.eql(u8, str, "false")) return false;
                    std.debug.print("{s}\n", .{str});
                    return error.InvalidBool;
                }
            }.parse,
            .@"enum" => return struct {
                fn parse(str: []const u8) anyerror!T {
                    return std.meta.stringToEnum(T, str) orelse {
                        std.log.err("unknown enum variant for {s}: {s}", .{ @typeName(T), str });
                        return error.UnknownEnumVariant;
                    };
                }
            }.parse,
            .optional => |o| return struct {
                fn parse(str: []const u8) anyerror!T {
                    if (std.mem.eql(u8, str, "null")) return null;
                    return try getDefaultParser(o.child)(str);
                }
            }.parse,
            .@"struct" => @compileError("no default parser for " ++ @typeName(T)),
            .pointer => {
                if (T == []const u8) {
                    return struct {
                        fn parse(str: []const u8) anyerror!T {
                            return str;
                        }
                    }.parse;
                } else {
                    @compileError("no default parser for " ++ @typeName(T));
                }
            },
            else => @compileError("no default parser for " ++ @typeName(T)),
        }
    }
};

const Cases = @This();
const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const getExternalExecutor = std.zig.system.getExternalExecutor;

fn resolveTargetQuery(query: std.Target.Query) std.Build.ResolvedTarget {
    return .{
        .query = query,
        .target = std.zig.system.resolveTargetQuery(query) catch
            @panic("unable to resolve target query"),
    };
}

fn knownFileExtension(filename: []const u8) bool {
    // List taken from `Compilation.classifyFileExt` in the compiler.
    for ([_][]const u8{
        ".c",     ".C",    ".cc",       ".cpp",
        ".cxx",   ".stub", ".m",        ".mm",
        ".ll",    ".bc",   ".s",        ".S",
        ".h",     ".zig",  ".so",       ".dll",
        ".dylib", ".tbd",  ".a",        ".lib",
        ".o",     ".obj",  ".cu",       ".def",
        ".rc",    ".res",  ".manifest",
    }) |ext| {
        if (std.mem.endsWith(u8, filename, ext)) return true;
    }
    // Final check for .so.X, .so.X.Y, .so.X.Y.Z.
    // From `Compilation.hasSharedLibraryExt`.
    var it = std.mem.splitScalar(u8, filename, '.');
    _ = it.first();
    var so_txt = it.next() orelse return false;
    while (!std.mem.eql(u8, so_txt, "so")) {
        so_txt = it.next() orelse return false;
    }
    const n1 = it.next() orelse return false;
    const n2 = it.next();
    const n3 = it.next();
    _ = std.fmt.parseInt(u32, n1, 10) catch return false;
    if (n2) |x| _ = std.fmt.parseInt(u32, x, 10) catch return false;
    if (n3) |x| _ = std.fmt.parseInt(u32, x, 10) catch return false;
    if (it.next() != null) return false;
    return false;
}
