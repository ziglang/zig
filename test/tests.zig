const std = @import("std");
const debug = std.debug;
const build = std.build;
const os = std.os;
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;
const Buffer0 = std.cstr.Buffer0;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const List = std.list.List;

const compare_output = @import("compare_output.zig");
const build_examples = @import("build_examples.zig");
const compile_errors = @import("compile_errors.zig");
const assemble_and_link = @import("assemble_and_link.zig");
const debug_safety = @import("debug_safety.zig");
const parseh = @import("parseh.zig");

error TestFailed;

pub fn addCompareOutputTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(CompareOutputContext);
    *cases = CompareOutputContext {
        .b = b,
        .step = b.step("test-compare-output", "Run the compare output tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    compare_output.addCases(cases);

    return cases.step;
}

pub fn addDebugSafetyTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(CompareOutputContext);
    *cases = CompareOutputContext {
        .b = b,
        .step = b.step("test-debug-safety", "Run the debug safety tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    debug_safety.addCases(cases);

    return cases.step;
}

pub fn addCompileErrorTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(CompileErrorContext);
    *cases = CompileErrorContext {
        .b = b,
        .step = b.step("test-compile-errors", "Run the compile error tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    compile_errors.addCases(cases);

    return cases.step;
}

pub fn addBuildExampleTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(BuildExamplesContext);
    *cases = BuildExamplesContext {
        .b = b,
        .step = b.step("test-build-examples", "Build the examples"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    build_examples.addCases(cases);

    return cases.step;
}

pub fn addAssembleAndLinkTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(CompareOutputContext);
    *cases = CompareOutputContext {
        .b = b,
        .step = b.step("test-asm-link", "Run the assemble and link tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    assemble_and_link.addCases(cases);

    return cases.step;
}

pub fn addParseHTests(b: &build.Builder, test_filter: ?[]const u8) -> &build.Step {
    const cases = %%b.allocator.create(ParseHContext);
    *cases = ParseHContext {
        .b = b,
        .step = b.step("test-parseh", "Run the C header file parsing tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    parseh.addCases(cases);

    return cases.step;
}

pub fn addPkgTests(b: &build.Builder, test_filter: ?[]const u8, root_src: []const u8,
    name:[] const u8, desc: []const u8) -> &build.Step
{
    const step = b.step(b.fmt("test-{}", name), desc);
    for ([]bool{false, true}) |release| {
        for ([]bool{false, true}) |link_libc| {
            const these_tests = b.addTest(root_src);
            these_tests.setNamePrefix(b.fmt("{}-{}-{} ", name,
                if (release) "release" else "debug",
                if (link_libc) "c" else "bare"));
            these_tests.setFilter(test_filter);
            these_tests.setRelease(release);
            if (link_libc) {
                these_tests.linkLibrary("c");
            }
            step.dependOn(&these_tests.step);
        }
    }
    return step;
}

pub const CompareOutputContext = struct {
    b: &build.Builder,
    step: &build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const Special = enum {
        None,
        Asm,
        DebugSafety,
    };

    const TestCase = struct {
        name: []const u8,
        sources: List(SourceFile),
        expected_output: []const u8,
        link_libc: bool,
        special: Special,

        const SourceFile = struct {
            filename: []const u8,
            source: []const u8,
        };

        pub fn addSourceFile(self: &TestCase, filename: []const u8, source: []const u8) {
            %%self.sources.append(SourceFile {
                .filename = filename,
                .source = source,
            });
        }
    };

    const RunCompareOutputStep = struct {
        step: build.Step,
        context: &CompareOutputContext,
        exe_path: []const u8,
        name: []const u8,
        expected_output: []const u8,
        test_index: usize,

        pub fn create(context: &CompareOutputContext, exe_path: []const u8,
            name: []const u8, expected_output: []const u8) -> &RunCompareOutputStep
        {
            const allocator = context.b.allocator;
            const ptr = %%allocator.create(RunCompareOutputStep);
            *ptr = RunCompareOutputStep {
                .context = context,
                .exe_path = exe_path,
                .name = name,
                .expected_output = expected_output,
                .test_index = context.test_index,
                .step = build.Step.init("RunCompareOutput", allocator, make),
            };
            context.test_index += 1;
            return ptr;
        }

        fn make(step: &build.Step) -> %void {
            const self = @fieldParentPtr(RunCompareOutputStep, "step", step);
            const b = self.context.b;

            const full_exe_path = b.pathFromRoot(self.exe_path);

            %%io.stderr.printf("Test {}/{} {}...", self.test_index+1, self.context.test_index, self.name);

            var child = os.ChildProcess.spawn(full_exe_path, [][]u8{}, &b.env_map,
                StdIo.Ignore, StdIo.Pipe, StdIo.Pipe, b.allocator) %% |err|
            {
                debug.panic("Unable to spawn {}: {}\n", full_exe_path, @errorName(err));
            };

            const term = child.wait() %% |err| {
                debug.panic("Unable to spawn {}: {}\n", full_exe_path, @errorName(err));
            };
            switch (term) {
                Term.Clean => |code| {
                    if (code != 0) {
                        %%io.stderr.printf("Process {} exited with error code {}\n", full_exe_path, code);
                        return error.TestFailed;
                    }
                },
                else => {
                    %%io.stderr.printf("Process {} terminated unexpectedly\n", full_exe_path);
                    return error.TestFailed;
                },
            };

            var stdout = %%Buffer0.initEmpty(b.allocator);
            var stderr = %%Buffer0.initEmpty(b.allocator);

            %%(??child.stdout).readAll(&stdout);
            %%(??child.stderr).readAll(&stderr);

            if (!mem.eql(u8, self.expected_output, stdout.toSliceConst())) {
                %%io.stderr.printf(
                    \\
                    \\========= Expected this output: =========
                    \\{}
                    \\================================================
                    \\{}
                    \\
                , self.expected_output, stdout.toSliceConst());
                return error.TestFailed;
            }
            %%io.stderr.printf("OK\n");
        }
    };

    const DebugSafetyRunStep = struct {
        step: build.Step,
        context: &CompareOutputContext,
        exe_path: []const u8,
        name: []const u8,
        test_index: usize,

        pub fn create(context: &CompareOutputContext, exe_path: []const u8,
            name: []const u8) -> &DebugSafetyRunStep
        {
            const allocator = context.b.allocator;
            const ptr = %%allocator.create(DebugSafetyRunStep);
            *ptr = DebugSafetyRunStep {
                .context = context,
                .exe_path = exe_path,
                .name = name,
                .test_index = context.test_index,
                .step = build.Step.init("DebugSafetyRun", allocator, make),
            };
            context.test_index += 1;
            return ptr;
        }

        fn make(step: &build.Step) -> %void {
            const self = @fieldParentPtr(DebugSafetyRunStep, "step", step);
            const b = self.context.b;

            const full_exe_path = b.pathFromRoot(self.exe_path);

            %%io.stderr.printf("Test {}/{} {}...", self.test_index+1, self.context.test_index, self.name);

            var child = os.ChildProcess.spawn(full_exe_path, [][]u8{}, &b.env_map,
                StdIo.Ignore, StdIo.Pipe, StdIo.Pipe, b.allocator) %% |err|
            {
                debug.panic("Unable to spawn {}: {}\n", full_exe_path, @errorName(err));
            };

            const term = child.wait() %% |err| {
                debug.panic("Unable to spawn {}: {}\n", full_exe_path, @errorName(err));
            };

            const debug_trap_signal: i32 = 5;
            switch (term) {
                Term.Clean => |code| {
                    %%io.stderr.printf("\nProgram expected to hit debug trap (signal {}) " ++
                        "but exited with return code {}\n", debug_trap_signal, code);
                    return error.TestFailed;
                },
                Term.Signal => |sig| {
                    if (sig != debug_trap_signal) {
                        %%io.stderr.printf("\nProgram expected to hit debug trap (signal {}) " ++
                            "but instead signaled {}\n", debug_trap_signal, sig);
                        return error.TestFailed;
                    }
                },
                else => {
                    %%io.stderr.printf("\nProgram expected to hit debug trap (signal {}) " ++
                        " but exited in an unexpected way\n", debug_trap_signal);
                    return error.TestFailed;
                },
            }

            %%io.stderr.printf("OK\n");
        }
    };

    pub fn createExtra(self: &CompareOutputContext, name: []const u8, source: []const u8,
        expected_output: []const u8, special: Special) -> TestCase
    {
        var tc = TestCase {
            .name = name,
            .sources = List(TestCase.SourceFile).init(self.b.allocator),
            .expected_output = expected_output,
            .link_libc = false,
            .special = special,
        };
        const root_src_name = if (special == Special.Asm) "source.s" else "source.zig";
        tc.addSourceFile(root_src_name, source);
        return tc;
    }

    pub fn create(self: &CompareOutputContext, name: []const u8, source: []const u8,
        expected_output: []const u8) -> TestCase
    {
        return createExtra(self, name, source, expected_output, Special.None);
    }

    pub fn addC(self: &CompareOutputContext, name: []const u8, source: []const u8, expected_output: []const u8) {
        var tc = self.create(name, source, expected_output);
        tc.link_libc = true;
        self.addCase(tc);
    }

    pub fn add(self: &CompareOutputContext, name: []const u8, source: []const u8, expected_output: []const u8) {
        const tc = self.create(name, source, expected_output);
        self.addCase(tc);
    }

    pub fn addAsm(self: &CompareOutputContext, name: []const u8, source: []const u8, expected_output: []const u8) {
        const tc = self.createExtra(name, source, expected_output, Special.Asm);
        self.addCase(tc);
    }

    pub fn addDebugSafety(self: &CompareOutputContext, name: []const u8, source: []const u8) {
        const tc = self.createExtra(name, source, undefined, Special.DebugSafety);
        self.addCase(tc);
    }

    pub fn addCase(self: &CompareOutputContext, case: &const TestCase) {
        const b = self.b;

        const root_src = %%os.path.join(b.allocator, "test_artifacts", case.sources.items[0].filename);
        const exe_path = %%os.path.join(b.allocator, "test_artifacts", "test");

        switch (case.special) {
            Special.Asm => {
                const obj_path = %%os.path.join(b.allocator, "test_artifacts", "test.o");
                const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "assemble-and-link {}", case.name);
                if (const filter ?= self.test_filter) {
                    if (mem.indexOf(u8, annotated_case_name, filter) == null)
                        return;
                }

                const obj = b.addAssemble("test", root_src);
                obj.setOutputPath(obj_path);

                for (case.sources.toSliceConst()) |src_file| {
                    const expanded_src_path = %%os.path.join(b.allocator, "test_artifacts", src_file.filename);
                    const write_src = b.addWriteFile(expanded_src_path, src_file.source);
                    obj.step.dependOn(&write_src.step);
                }

                const exe = b.addLinkExecutable("test");
                exe.step.dependOn(&obj.step);
                exe.addObjectFile(obj_path);
                exe.setOutputPath(exe_path);

                const run_and_cmp_output = RunCompareOutputStep.create(self, exe_path, annotated_case_name,
                    case.expected_output);
                run_and_cmp_output.step.dependOn(&exe.step);

                self.step.dependOn(&run_and_cmp_output.step);
            },
            Special.None => {
                for ([]bool{false, true}) |release| {
                    const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "{} {} ({})",
                        "compare-output", case.name, if (release) "release" else "debug");
                    if (const filter ?= self.test_filter) {
                        if (mem.indexOf(u8, annotated_case_name, filter) == null)
                            continue;
                    }

                    const exe = b.addExecutable("test", root_src);
                    exe.setOutputPath(exe_path);
                    exe.setRelease(release);
                    if (case.link_libc) {
                        exe.linkLibrary("c");
                    }

                    for (case.sources.toSliceConst()) |src_file| {
                        const expanded_src_path = %%os.path.join(b.allocator, "test_artifacts", src_file.filename);
                        const write_src = b.addWriteFile(expanded_src_path, src_file.source);
                        exe.step.dependOn(&write_src.step);
                    }

                    const run_and_cmp_output = RunCompareOutputStep.create(self, exe_path, annotated_case_name,
                        case.expected_output);
                    run_and_cmp_output.step.dependOn(&exe.step);

                    self.step.dependOn(&run_and_cmp_output.step);
                }
            },
            Special.DebugSafety => {
                const obj_path = %%os.path.join(b.allocator, "test_artifacts", "test.o");
                const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "debug-safety {}", case.name);
                if (const filter ?= self.test_filter) {
                    if (mem.indexOf(u8, annotated_case_name, filter) == null)
                        return;
                }

                const exe = b.addExecutable("test", root_src);
                exe.setOutputPath(exe_path);
                if (case.link_libc) {
                    exe.linkLibrary("c");
                }

                for (case.sources.toSliceConst()) |src_file| {
                    const expanded_src_path = %%os.path.join(b.allocator, "test_artifacts", src_file.filename);
                    const write_src = b.addWriteFile(expanded_src_path, src_file.source);
                    exe.step.dependOn(&write_src.step);
                }

                const run_and_cmp_output = DebugSafetyRunStep.create(self, exe_path, annotated_case_name);
                run_and_cmp_output.step.dependOn(&exe.step);

                self.step.dependOn(&run_and_cmp_output.step);
            },
        }
    }
};

pub const CompileErrorContext = struct {
    b: &build.Builder,
    step: &build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const TestCase = struct {
        name: []const u8,
        sources: List(SourceFile),
        expected_errors: List([]const u8),
        link_libc: bool,
        is_exe: bool,

        const SourceFile = struct {
            filename: []const u8,
            source: []const u8,
        };

        pub fn addSourceFile(self: &TestCase, filename: []const u8, source: []const u8) {
            %%self.sources.append(SourceFile {
                .filename = filename,
                .source = source,
            });
        }

        pub fn addExpectedError(self: &TestCase, text: []const u8) {
            %%self.expected_errors.append(text);
        }
    };

    const CompileCmpOutputStep = struct {
        step: build.Step,
        context: &CompileErrorContext,
        name: []const u8,
        test_index: usize,
        case: &const TestCase,
        release: bool,

        pub fn create(context: &CompileErrorContext, name: []const u8,
            case: &const TestCase, release: bool) -> &CompileCmpOutputStep
        {
            const allocator = context.b.allocator;
            const ptr = %%allocator.create(CompileCmpOutputStep);
            *ptr = CompileCmpOutputStep {
                .step = build.Step.init("CompileCmpOutput", allocator, make),
                .context = context,
                .name = name,
                .test_index = context.test_index,
                .case = case,
                .release = release,
            };
            context.test_index += 1;
            return ptr;
        }

        fn make(step: &build.Step) -> %void {
            const self = @fieldParentPtr(CompileCmpOutputStep, "step", step);
            const b = self.context.b;

            const root_src = %%os.path.join(b.allocator, "test_artifacts", self.case.sources.items[0].filename);
            const obj_path = %%os.path.join(b.allocator, "test_artifacts", "test.o");

            var zig_args = List([]const u8).init(b.allocator);
            %%zig_args.append(if (self.case.is_exe) "build_exe" else "build_obj");
            %%zig_args.append(b.pathFromRoot(root_src));

            %%zig_args.append("--name");
            %%zig_args.append("test");

            %%zig_args.append("--output");
            %%zig_args.append(b.pathFromRoot(obj_path));

            if (self.release) {
                %%zig_args.append("--release");
            }

            %%io.stderr.printf("Test {}/{} {}...", self.test_index+1, self.context.test_index, self.name);

            if (b.verbose) {
                printInvocation(b.zig_exe, zig_args.toSliceConst());
            }

            var child = os.ChildProcess.spawn(b.zig_exe, zig_args.toSliceConst(), &b.env_map,
                StdIo.Ignore, StdIo.Pipe, StdIo.Pipe, b.allocator) %% |err|
            {
                debug.panic("Unable to spawn {}: {}\n", b.zig_exe, @errorName(err));
            };

            const term = child.wait() %% |err| {
                debug.panic("Unable to spawn {}: {}\n", b.zig_exe, @errorName(err));
            };
            switch (term) {
                Term.Clean => |code| {
                    if (code == 0) {
                        %%io.stderr.printf("Compilation incorrectly succeeded\n");
                        return error.TestFailed;
                    }
                },
                else => {
                    %%io.stderr.printf("Process {} terminated unexpectedly\n", b.zig_exe);
                    return error.TestFailed;
                },
            };

            var stdout_buf = %%Buffer0.initEmpty(b.allocator);
            var stderr_buf = %%Buffer0.initEmpty(b.allocator);

            %%(??child.stdout).readAll(&stdout_buf);
            %%(??child.stderr).readAll(&stderr_buf);

            const stdout = stdout_buf.toSliceConst();
            const stderr = stderr_buf.toSliceConst();

            if (stdout.len != 0) {
                %%io.stderr.printf(
                    \\
                    \\Expected empty stdout, instead found:
                    \\================================================
                    \\{}
                    \\================================================
                    \\
                , stdout);
                return error.TestFailed;
            }

            for (self.case.expected_errors.toSliceConst()) |expected_error| {
                if (mem.indexOf(u8, stderr, expected_error) == null) {
                    %%io.stderr.printf(
                        \\
                        \\========= Expected this compile error: =========
                        \\{}
                        \\================================================
                        \\{}
                        \\
                    , expected_error, stderr);
                    return error.TestFailed;
                }
            }
            %%io.stderr.printf("OK\n");
        }
    };

    fn printInvocation(exe_path: []const u8, args: []const []const u8) {
        %%io.stderr.printf("{}", exe_path);
        for (args) |arg| {
            %%io.stderr.printf(" {}", arg);
        }
        %%io.stderr.printf("\n");
    }

    pub fn create(self: &CompileErrorContext, name: []const u8, source: []const u8,
        expected_lines: ...) -> &TestCase
    {
        const tc = %%self.b.allocator.create(TestCase);
        *tc = TestCase {
            .name = name,
            .sources = List(TestCase.SourceFile).init(self.b.allocator),
            .expected_errors = List([]const u8).init(self.b.allocator),
            .link_libc = false,
            .is_exe = false,
        };
        tc.addSourceFile(".tmp_source.zig", source);
        comptime var arg_i = 0;
        inline while (arg_i < expected_lines.len; arg_i += 1) {
            // TODO mem.dupe is because of issue #336
            tc.addExpectedError(%%mem.dupe(self.b.allocator, u8, expected_lines[arg_i]));
        }
        return tc;
    }

    pub fn addC(self: &CompileErrorContext, name: []const u8, source: []const u8, expected_lines: ...) {
        var tc = self.create(name, source, expected_lines);
        tc.link_libc = true;
        self.addCase(tc);
    }

    pub fn addExe(self: &CompileErrorContext, name: []const u8, source: []const u8, expected_lines: ...) {
        var tc = self.create(name, source, expected_lines);
        tc.is_exe = true;
        self.addCase(tc);
    }

    pub fn add(self: &CompileErrorContext, name: []const u8, source: []const u8, expected_lines: ...) {
        const tc = self.create(name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addCase(self: &CompileErrorContext, case: &const TestCase) {
        const b = self.b;

        for ([]bool{false, true}) |release| {
            const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "compile-error {} ({})",
                case.name, if (release) "release" else "debug");
            if (const filter ?= self.test_filter) {
                if (mem.indexOf(u8, annotated_case_name, filter) == null)
                    continue;
            }

            const compile_and_cmp_errors = CompileCmpOutputStep.create(self, annotated_case_name, case, release);
            self.step.dependOn(&compile_and_cmp_errors.step);

            for (case.sources.toSliceConst()) |src_file| {
                const expanded_src_path = %%os.path.join(b.allocator, "test_artifacts", src_file.filename);
                const write_src = b.addWriteFile(expanded_src_path, src_file.source);
                compile_and_cmp_errors.step.dependOn(&write_src.step);
            }
        }
    }
};

pub const BuildExamplesContext = struct {
    b: &build.Builder,
    step: &build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    pub fn addC(self: &BuildExamplesContext, root_src: []const u8) {
        self.addAllArgs(root_src, true);
    }

    pub fn add(self: &BuildExamplesContext, root_src: []const u8) {
        self.addAllArgs(root_src, false);
    }

    pub fn addAllArgs(self: &BuildExamplesContext, root_src: []const u8, link_libc: bool) {
        const b = self.b;

        for ([]bool{false, true}) |release| {
            const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "build {} ({})",
                root_src, if (release) "release" else "debug");
            if (const filter ?= self.test_filter) {
                if (mem.indexOf(u8, annotated_case_name, filter) == null)
                    continue;
            }

            const exe = b.addExecutable("test", root_src);
            exe.setRelease(release);
            if (link_libc) {
                exe.linkLibrary("c");
            }

            const log_step = b.addLog("PASS {}\n", annotated_case_name);
            log_step.step.dependOn(&exe.step);

            self.step.dependOn(&log_step.step);
        }
    }
};

pub const ParseHContext = struct {
    b: &build.Builder,
    step: &build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const TestCase = struct {
        name: []const u8,
        sources: List(SourceFile),
        expected_lines: List([]const u8),
        allow_warnings: bool,

        const SourceFile = struct {
            filename: []const u8,
            source: []const u8,
        };

        pub fn addSourceFile(self: &TestCase, filename: []const u8, source: []const u8) {
            %%self.sources.append(SourceFile {
                .filename = filename,
                .source = source,
            });
        }

        pub fn addExpectedError(self: &TestCase, text: []const u8) {
            %%self.expected_lines.append(text);
        }
    };

    const ParseHCmpOutputStep = struct {
        step: build.Step,
        context: &ParseHContext,
        name: []const u8,
        test_index: usize,
        case: &const TestCase,

        pub fn create(context: &ParseHContext, name: []const u8, case: &const TestCase) -> &ParseHCmpOutputStep {
            const allocator = context.b.allocator;
            const ptr = %%allocator.create(ParseHCmpOutputStep);
            *ptr = ParseHCmpOutputStep {
                .step = build.Step.init("ParseHCmpOutput", allocator, make),
                .context = context,
                .name = name,
                .test_index = context.test_index,
                .case = case,
            };
            context.test_index += 1;
            return ptr;
        }

        fn make(step: &build.Step) -> %void {
            const self = @fieldParentPtr(ParseHCmpOutputStep, "step", step);
            const b = self.context.b;

            const root_src = %%os.path.join(b.allocator, "test_artifacts", self.case.sources.items[0].filename);

            var zig_args = List([]const u8).init(b.allocator);
            %%zig_args.append("parseh");
            %%zig_args.append(b.pathFromRoot(root_src));

            %%io.stderr.printf("Test {}/{} {}...", self.test_index+1, self.context.test_index, self.name);

            if (b.verbose) {
                printInvocation(b.zig_exe, zig_args.toSliceConst());
            }

            var child = os.ChildProcess.spawn(b.zig_exe, zig_args.toSliceConst(), &b.env_map,
                StdIo.Ignore, StdIo.Pipe, StdIo.Pipe, b.allocator) %% |err|
            {
                debug.panic("Unable to spawn {}: {}\n", b.zig_exe, @errorName(err));
            };

            const term = child.wait() %% |err| {
                debug.panic("Unable to spawn {}: {}\n", b.zig_exe, @errorName(err));
            };
            switch (term) {
                Term.Clean => |code| {
                    if (code != 0) {
                        %%io.stderr.printf("Compilation failed with exit code {}\n", code);
                        return error.TestFailed;
                    }
                },
                Term.Signal => |code| {
                    %%io.stderr.printf("Compilation failed with signal {}\n", code);
                    return error.TestFailed;
                },
                else => {
                    %%io.stderr.printf("Compilation terminated unexpectedly\n");
                    return error.TestFailed;
                },
            };

            var stdout_buf = %%Buffer0.initEmpty(b.allocator);
            var stderr_buf = %%Buffer0.initEmpty(b.allocator);

            %%(??child.stdout).readAll(&stdout_buf);
            %%(??child.stderr).readAll(&stderr_buf);

            const stdout = stdout_buf.toSliceConst();
            const stderr = stderr_buf.toSliceConst();

            if (stderr.len != 0 and !self.case.allow_warnings) {
                %%io.stderr.printf(
                    \\====== parseh emitted warnings: ============
                    \\{}
                    \\============================================
                    \\
                , stderr);
                return error.TestFailed;
            }

            for (self.case.expected_lines.toSliceConst()) |expected_line| {
                if (mem.indexOf(u8, stdout, expected_line) == null) {
                    %%io.stderr.printf(
                        \\
                        \\========= Expected this output: ================
                        \\{}
                        \\================================================
                        \\{}
                        \\
                    , expected_line, stdout);
                    return error.TestFailed;
                }
            }
            %%io.stderr.printf("OK\n");
        }
    };

    fn printInvocation(exe_path: []const u8, args: []const []const u8) {
        %%io.stderr.printf("{}", exe_path);
        for (args) |arg| {
            %%io.stderr.printf(" {}", arg);
        }
        %%io.stderr.printf("\n");
    }

    pub fn create(self: &ParseHContext, allow_warnings: bool, name: []const u8,
        source: []const u8, expected_lines: ...) -> &TestCase
    {
        const tc = %%self.b.allocator.create(TestCase);
        *tc = TestCase {
            .name = name,
            .sources = List(TestCase.SourceFile).init(self.b.allocator),
            .expected_lines = List([]const u8).init(self.b.allocator),
            .allow_warnings = allow_warnings,
        };
        tc.addSourceFile("source.h", source);
        comptime var arg_i = 0;
        inline while (arg_i < expected_lines.len; arg_i += 1) {
            // TODO mem.dupe is because of issue #336
            tc.addExpectedError(%%mem.dupe(self.b.allocator, u8, expected_lines[arg_i]));
        }
        return tc;
    }

    pub fn add(self: &ParseHContext, name: []const u8, source: []const u8, expected_lines: ...) {
        const tc = self.create(false, name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addAllowWarnings(self: &ParseHContext, name: []const u8, source: []const u8, expected_lines: ...) {
        const tc = self.create(true, name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addCase(self: &ParseHContext, case: &const TestCase) {
        const b = self.b;

        const annotated_case_name = %%fmt.allocPrint(self.b.allocator, "parseh {}", case.name);
        if (const filter ?= self.test_filter) {
            if (mem.indexOf(u8, annotated_case_name, filter) == null)
                return;
        }

        const parseh_and_cmp = ParseHCmpOutputStep.create(self, annotated_case_name, case);
        self.step.dependOn(&parseh_and_cmp.step);

        for (case.sources.toSliceConst()) |src_file| {
            const expanded_src_path = %%os.path.join(b.allocator, "test_artifacts", src_file.filename);
            const write_src = b.addWriteFile(expanded_src_path, src_file.source);
            parseh_and_cmp.step.dependOn(&write_src.step);
        }
    }
};
