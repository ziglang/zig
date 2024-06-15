const builtin = @import("builtin");
const std = @import("std");
const fatal = std.zig.fatal;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = std.mem.Allocator;
const testing = std.testing;
const getExternalExecutor = std.zig.system.getExternalExecutor;

const max_doc_file_size = 10 * 1024 * 1024;

const usage =
    \\Usage: doctest [options] -i input -o output
    \\
    \\   Compiles and possibly runs a code example, capturing output and rendering
    \\   it to HTML documentation.
    \\
    \\Options:
    \\   -h, --help             Print this help and exit
    \\   -i input               Source code file path
    \\   -o output              Where to write output HTML docs to
    \\   --zig zig              Path to the zig compiler
    \\   --zig-lib-dir dir      Override the zig compiler library path
    \\   --cache-root dir       Path to local .zig-cache/
    \\
;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();

    const arena = arena_instance.allocator();

    var args_it = try process.argsWithAllocator(arena);
    if (!args_it.skip()) fatal("missing argv[0]", .{});

    var opt_input: ?[]const u8 = null;
    var opt_output: ?[]const u8 = null;
    var opt_zig: ?[]const u8 = null;
    var opt_zig_lib_dir: ?[]const u8 = null;
    var opt_cache_root: ?[]const u8 = null;

    while (args_it.next()) |arg| {
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                try std.io.getStdOut().writeAll(usage);
                process.exit(0);
            } else if (mem.eql(u8, arg, "-i")) {
                opt_input = args_it.next() orelse fatal("expected parameter after -i", .{});
            } else if (mem.eql(u8, arg, "-o")) {
                opt_output = args_it.next() orelse fatal("expected parameter after -o", .{});
            } else if (mem.eql(u8, arg, "--zig")) {
                opt_zig = args_it.next() orelse fatal("expected parameter after --zig", .{});
            } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                opt_zig_lib_dir = args_it.next() orelse fatal("expected parameter after --zig-lib-dir", .{});
            } else if (mem.eql(u8, arg, "--cache-root")) {
                opt_cache_root = args_it.next() orelse fatal("expected parameter after --cache-root", .{});
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else {
            fatal("unexpected positional argument: '{s}'", .{arg});
        }
    }

    const input_path = opt_input orelse fatal("missing input file (-i)", .{});
    const output_path = opt_output orelse fatal("missing output file (-o)", .{});
    const zig_path = opt_zig orelse fatal("missing zig compiler path (--zig)", .{});
    const cache_root = opt_cache_root orelse fatal("missing cache root path (--cache-root)", .{});

    const source_bytes = try fs.cwd().readFileAlloc(arena, input_path, std.math.maxInt(u32));
    const code = try parseManifest(arena, source_bytes);
    const source = stripManifest(source_bytes);

    const tmp_dir_path = try std.fmt.allocPrint(arena, "{s}/tmp/{x}", .{
        cache_root, std.crypto.random.int(u64),
    });
    fs.cwd().makePath(tmp_dir_path) catch |err|
        fatal("unable to create tmp dir '{s}': {s}", .{ tmp_dir_path, @errorName(err) });
    defer fs.cwd().deleteTree(tmp_dir_path) catch |err| std.log.err("unable to delete '{s}': {s}", .{
        tmp_dir_path, @errorName(err),
    });

    var out_file = try fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    var bw = std.io.bufferedWriter(out_file.writer());
    const out = bw.writer();

    try printSourceBlock(arena, out, source, fs.path.basename(input_path));
    try printOutput(arena, out, code, input_path, zig_path, opt_zig_lib_dir, tmp_dir_path);

    try bw.flush();
}

fn printOutput(
    arena: Allocator,
    out: anytype,
    code: Code,
    input_path: []const u8,
    zig_exe: []const u8,
    opt_zig_lib_dir: ?[]const u8,
    tmp_dir_path: []const u8,
) !void {
    var env_map = try process.getEnvMap(arena);
    try env_map.put("CLICOLOR_FORCE", "1");

    const host = try std.zig.system.resolveTargetQuery(.{});
    const obj_ext = builtin.object_format.fileExt(builtin.cpu.arch);
    const print = std.debug.print;

    var shell_buffer = std.ArrayList(u8).init(arena);
    defer shell_buffer.deinit();
    var shell_out = shell_buffer.writer();

    const code_name = std.fs.path.stem(input_path);

    switch (code.id) {
        .exe => |expected_outcome| code_block: {
            var build_args = std.ArrayList([]const u8).init(arena);
            defer build_args.deinit();
            try build_args.appendSlice(&[_][]const u8{
                zig_exe,    "build-exe",
                "--name",   code_name,
                "--color",  "on",
                input_path,
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try build_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }

            try shell_out.print("$ zig build-exe {s}.zig ", .{code_name});

            switch (code.mode) {
                .Debug => {},
                else => {
                    try build_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                    try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                },
            }
            for (code.link_objects) |link_object| {
                const name_with_ext = try std.fmt.allocPrint(arena, "{s}{s}", .{ link_object, obj_ext });
                try build_args.append(name_with_ext);
                try shell_out.print("{s} ", .{name_with_ext});
            }
            if (code.link_libc) {
                try build_args.append("-lc");
                try shell_out.print("-lc ", .{});
            }

            if (code.target_str) |triple| {
                try build_args.appendSlice(&[_][]const u8{ "-target", triple });
                try shell_out.print("-target {s} ", .{triple});
            }
            if (code.verbose_cimport) {
                try build_args.append("--verbose-cimport");
                try shell_out.print("--verbose-cimport ", .{});
            }
            for (code.additional_options) |option| {
                try build_args.append(option);
                try shell_out.print("{s} ", .{option});
            }

            try shell_out.print("\n", .{});

            if (expected_outcome == .build_fail) {
                const result = try process.Child.run(.{
                    .allocator = arena,
                    .argv = build_args.items,
                    .cwd = tmp_dir_path,
                    .env_map = &env_map,
                    .max_output_bytes = max_doc_file_size,
                });
                switch (result.term) {
                    .Exited => |exit_code| {
                        if (exit_code == 0) {
                            print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                            dumpArgs(build_args.items);
                            fatal("example incorrectly compiled", .{});
                        }
                    },
                    else => {
                        print("{s}\nThe following command crashed:\n", .{result.stderr});
                        dumpArgs(build_args.items);
                        fatal("example compile crashed", .{});
                    },
                }
                const escaped_stderr = try escapeHtml(arena, result.stderr);
                const colored_stderr = try termColor(arena, escaped_stderr);
                try shell_out.writeAll(colored_stderr);
                break :code_block;
            }
            const exec_result = run(arena, &env_map, tmp_dir_path, build_args.items) catch
                fatal("example failed to compile", .{});

            if (code.verbose_cimport) {
                const escaped_build_stderr = try escapeHtml(arena, exec_result.stderr);
                try shell_out.writeAll(escaped_build_stderr);
            }

            if (code.target_str) |triple| {
                if (mem.startsWith(u8, triple, "wasm32") or
                    mem.startsWith(u8, triple, "riscv64-linux") or
                    (mem.startsWith(u8, triple, "x86_64-linux") and
                    builtin.os.tag != .linux or builtin.cpu.arch != .x86_64))
                {
                    // skip execution
                    break :code_block;
                }
            }

            const target_query = try std.Target.Query.parse(.{
                .arch_os_abi = code.target_str orelse "native",
            });
            const target = try std.zig.system.resolveTargetQuery(target_query);

            const path_to_exe = try std.fmt.allocPrint(arena, "./{s}{s}", .{
                code_name, target.exeFileExt(),
            });
            const run_args = &[_][]const u8{path_to_exe};

            var exited_with_signal = false;

            const result = if (expected_outcome == .fail) blk: {
                const result = try process.Child.run(.{
                    .allocator = arena,
                    .argv = run_args,
                    .env_map = &env_map,
                    .cwd = tmp_dir_path,
                    .max_output_bytes = max_doc_file_size,
                });
                switch (result.term) {
                    .Exited => |exit_code| {
                        if (exit_code == 0) {
                            print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                            dumpArgs(run_args);
                            fatal("example incorrectly compiled", .{});
                        }
                    },
                    .Signal => exited_with_signal = true,
                    else => {},
                }
                break :blk result;
            } else blk: {
                break :blk run(arena, &env_map, tmp_dir_path, run_args) catch
                    fatal("example crashed", .{});
            };

            const escaped_stderr = try escapeHtml(arena, result.stderr);
            const escaped_stdout = try escapeHtml(arena, result.stdout);

            const colored_stderr = try termColor(arena, escaped_stderr);
            const colored_stdout = try termColor(arena, escaped_stdout);

            try shell_out.print("$ ./{s}\n{s}{s}", .{ code_name, colored_stdout, colored_stderr });
            if (exited_with_signal) {
                try shell_out.print("(process terminated by signal)", .{});
            }
            try shell_out.writeAll("\n");
        },
        .@"test" => {
            var test_args = std.ArrayList([]const u8).init(arena);
            defer test_args.deinit();

            try test_args.appendSlice(&[_][]const u8{
                zig_exe, "test", input_path,
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }
            try shell_out.print("$ zig test {s}.zig ", .{code_name});

            switch (code.mode) {
                .Debug => {},
                else => {
                    try test_args.appendSlice(&[_][]const u8{
                        "-O", @tagName(code.mode),
                    });
                    try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                },
            }
            if (code.link_libc) {
                try test_args.append("-lc");
                try shell_out.print("-lc ", .{});
            }
            if (code.target_str) |triple| {
                try test_args.appendSlice(&[_][]const u8{ "-target", triple });
                try shell_out.print("-target {s} ", .{triple});

                const target_query = try std.Target.Query.parse(.{
                    .arch_os_abi = triple,
                });
                const target = try std.zig.system.resolveTargetQuery(
                    target_query,
                );
                switch (getExternalExecutor(host, &target, .{
                    .link_libc = code.link_libc,
                })) {
                    .native => {},
                    else => {
                        try test_args.appendSlice(&[_][]const u8{"--test-no-exec"});
                        try shell_out.writeAll("--test-no-exec");
                    },
                }
            }
            const result = run(arena, &env_map, null, test_args.items) catch
                fatal("test failed", .{});
            const escaped_stderr = try escapeHtml(arena, result.stderr);
            const escaped_stdout = try escapeHtml(arena, result.stdout);
            try shell_out.print("\n{s}{s}\n", .{ escaped_stderr, escaped_stdout });
        },
        .test_error => |error_match| {
            var test_args = std.ArrayList([]const u8).init(arena);
            defer test_args.deinit();

            try test_args.appendSlice(&[_][]const u8{
                zig_exe,    "test",
                "--color",  "on",
                input_path,
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }
            try shell_out.print("$ zig test {s}.zig ", .{code_name});

            switch (code.mode) {
                .Debug => {},
                else => {
                    try test_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                    try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                },
            }
            if (code.link_libc) {
                try test_args.append("-lc");
                try shell_out.print("-lc ", .{});
            }
            const result = try process.Child.run(.{
                .allocator = arena,
                .argv = test_args.items,
                .env_map = &env_map,
                .max_output_bytes = max_doc_file_size,
            });
            switch (result.term) {
                .Exited => |exit_code| {
                    if (exit_code == 0) {
                        print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                        dumpArgs(test_args.items);
                        fatal("example incorrectly compiled", .{});
                    }
                },
                else => {
                    print("{s}\nThe following command crashed:\n", .{result.stderr});
                    dumpArgs(test_args.items);
                    fatal("example compile crashed", .{});
                },
            }
            if (mem.indexOf(u8, result.stderr, error_match) == null) {
                print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                fatal("example did not have expected compile error", .{});
            }
            const escaped_stderr = try escapeHtml(arena, result.stderr);
            const colored_stderr = try termColor(arena, escaped_stderr);
            try shell_out.print("\n{s}\n", .{colored_stderr});
        },
        .test_safety => |error_match| {
            var test_args = std.ArrayList([]const u8).init(arena);
            defer test_args.deinit();

            try test_args.appendSlice(&[_][]const u8{
                zig_exe,    "test",
                input_path,
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }
            var mode_arg: []const u8 = "";
            switch (code.mode) {
                .Debug => {},
                .ReleaseSafe => {
                    try test_args.append("-OReleaseSafe");
                    mode_arg = "-OReleaseSafe";
                },
                .ReleaseFast => {
                    try test_args.append("-OReleaseFast");
                    mode_arg = "-OReleaseFast";
                },
                .ReleaseSmall => {
                    try test_args.append("-OReleaseSmall");
                    mode_arg = "-OReleaseSmall";
                },
            }

            const result = try process.Child.run(.{
                .allocator = arena,
                .argv = test_args.items,
                .env_map = &env_map,
                .max_output_bytes = max_doc_file_size,
            });
            switch (result.term) {
                .Exited => |exit_code| {
                    if (exit_code == 0) {
                        print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                        dumpArgs(test_args.items);
                        fatal("example test incorrectly succeeded", .{});
                    }
                },
                else => {
                    print("{s}\nThe following command crashed:\n", .{result.stderr});
                    dumpArgs(test_args.items);
                    fatal("example compile crashed", .{});
                },
            }
            if (mem.indexOf(u8, result.stderr, error_match) == null) {
                print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                fatal("example did not have expected runtime safety error message", .{});
            }
            const escaped_stderr = try escapeHtml(arena, result.stderr);
            const colored_stderr = try termColor(arena, escaped_stderr);
            try shell_out.print("$ zig test {s}.zig {s}\n{s}\n", .{
                code_name,
                mode_arg,
                colored_stderr,
            });
        },
        .obj => |maybe_error_match| {
            const name_plus_obj_ext = try std.fmt.allocPrint(arena, "{s}{s}", .{ code_name, obj_ext });
            var build_args = std.ArrayList([]const u8).init(arena);
            defer build_args.deinit();

            try build_args.appendSlice(&[_][]const u8{
                zig_exe,    "build-obj",
                "--color",  "on",
                "--name",   code_name,
                input_path,
                try std.fmt.allocPrint(arena, "-femit-bin={s}{c}{s}", .{
                    tmp_dir_path, fs.path.sep, name_plus_obj_ext,
                }),
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try build_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }

            try shell_out.print("$ zig build-obj {s}.zig ", .{code_name});

            switch (code.mode) {
                .Debug => {},
                else => {
                    try build_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                    try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                },
            }

            if (code.target_str) |triple| {
                try build_args.appendSlice(&[_][]const u8{ "-target", triple });
                try shell_out.print("-target {s} ", .{triple});
            }
            for (code.additional_options) |option| {
                try build_args.append(option);
                try shell_out.print("{s} ", .{option});
            }

            if (maybe_error_match) |error_match| {
                const result = try process.Child.run(.{
                    .allocator = arena,
                    .argv = build_args.items,
                    .env_map = &env_map,
                    .max_output_bytes = max_doc_file_size,
                });
                switch (result.term) {
                    .Exited => |exit_code| {
                        if (exit_code == 0) {
                            print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                            dumpArgs(build_args.items);
                            fatal("example build incorrectly succeeded", .{});
                        }
                    },
                    else => {
                        print("{s}\nThe following command crashed:\n", .{result.stderr});
                        dumpArgs(build_args.items);
                        fatal("example compile crashed", .{});
                    },
                }
                if (mem.indexOf(u8, result.stderr, error_match) == null) {
                    print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                    fatal("example did not have expected compile error message", .{});
                }
                const escaped_stderr = try escapeHtml(arena, result.stderr);
                const colored_stderr = try termColor(arena, escaped_stderr);
                try shell_out.print("\n{s} ", .{colored_stderr});
            } else {
                _ = run(arena, &env_map, null, build_args.items) catch fatal("example failed to compile", .{});
            }
            try shell_out.writeAll("\n");
        },
        .lib => {
            const bin_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = code_name,
                .target = builtin.target,
                .output_mode = .Lib,
            });

            var test_args = std.ArrayList([]const u8).init(arena);
            defer test_args.deinit();

            try test_args.appendSlice(&[_][]const u8{
                zig_exe,    "build-lib",
                input_path,
                try std.fmt.allocPrint(arena, "-femit-bin={s}{s}{s}", .{
                    tmp_dir_path, fs.path.sep_str, bin_basename,
                }),
            });
            if (opt_zig_lib_dir) |zig_lib_dir| {
                try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
            }
            try shell_out.print("$ zig build-lib {s}.zig ", .{code_name});

            switch (code.mode) {
                .Debug => {},
                else => {
                    try test_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                    try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                },
            }
            if (code.target_str) |triple| {
                try test_args.appendSlice(&[_][]const u8{ "-target", triple });
                try shell_out.print("-target {s} ", .{triple});
            }
            if (code.link_mode) |link_mode| {
                switch (link_mode) {
                    .static => {
                        try test_args.append("-static");
                        try shell_out.print("-static ", .{});
                    },
                    .dynamic => {
                        try test_args.append("-dynamic");
                        try shell_out.print("-dynamic ", .{});
                    },
                }
            }
            for (code.additional_options) |option| {
                try test_args.append(option);
                try shell_out.print("{s} ", .{option});
            }
            const result = run(arena, &env_map, null, test_args.items) catch fatal("test failed", .{});
            const escaped_stderr = try escapeHtml(arena, result.stderr);
            const escaped_stdout = try escapeHtml(arena, result.stdout);
            try shell_out.print("\n{s}{s}\n", .{ escaped_stderr, escaped_stdout });
        },
    }

    if (!code.just_check_syntax) {
        try printShell(out, shell_buffer.items, false);
    }
}

fn dumpArgs(args: []const []const u8) void {
    for (args) |arg|
        std.debug.print("{s} ", .{arg})
    else
        std.debug.print("\n", .{});
}

fn printSourceBlock(arena: Allocator, out: anytype, source_bytes: []const u8, name: []const u8) !void {
    try out.print("<figure><figcaption class=\"{s}-cap\"><cite class=\"file\">{s}</cite></figcaption><pre>", .{
        "zig", name,
    });
    try tokenizeAndPrint(arena, out, source_bytes);
    try out.writeAll("</pre></figure>");
}

fn tokenizeAndPrint(arena: Allocator, out: anytype, raw_src: []const u8) !void {
    const src_non_terminated = mem.trim(u8, raw_src, " \r\n");
    const src = try arena.dupeZ(u8, src_non_terminated);

    try out.writeAll("<code>");
    var tokenizer = std.zig.Tokenizer.init(src);
    var index: usize = 0;
    var next_tok_is_fn = false;
    while (true) {
        const prev_tok_was_fn = next_tok_is_fn;
        next_tok_is_fn = false;

        const token = tokenizer.next();
        if (mem.indexOf(u8, src[index..token.loc.start], "//")) |comment_start_off| {
            // render one comment
            const comment_start = index + comment_start_off;
            const comment_end_off = mem.indexOf(u8, src[comment_start..token.loc.start], "\n");
            const comment_end = if (comment_end_off) |o| comment_start + o else token.loc.start;

            try writeEscapedLines(out, src[index..comment_start]);
            try out.writeAll("<span class=\"tok-comment\">");
            try writeEscaped(out, src[comment_start..comment_end]);
            try out.writeAll("</span>");
            index = comment_end;
            tokenizer.index = index;
            continue;
        }

        try writeEscapedLines(out, src[index..token.loc.start]);
        switch (token.tag) {
            .eof => break,

            .keyword_addrspace,
            .keyword_align,
            .keyword_and,
            .keyword_asm,
            .keyword_async,
            .keyword_await,
            .keyword_break,
            .keyword_catch,
            .keyword_comptime,
            .keyword_const,
            .keyword_continue,
            .keyword_defer,
            .keyword_else,
            .keyword_enum,
            .keyword_errdefer,
            .keyword_error,
            .keyword_export,
            .keyword_extern,
            .keyword_for,
            .keyword_if,
            .keyword_inline,
            .keyword_noalias,
            .keyword_noinline,
            .keyword_nosuspend,
            .keyword_opaque,
            .keyword_or,
            .keyword_orelse,
            .keyword_packed,
            .keyword_anyframe,
            .keyword_pub,
            .keyword_resume,
            .keyword_return,
            .keyword_linksection,
            .keyword_callconv,
            .keyword_struct,
            .keyword_suspend,
            .keyword_switch,
            .keyword_test,
            .keyword_threadlocal,
            .keyword_try,
            .keyword_union,
            .keyword_unreachable,
            .keyword_usingnamespace,
            .keyword_var,
            .keyword_volatile,
            .keyword_allowzero,
            .keyword_while,
            .keyword_anytype,
            => {
                try out.writeAll("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .keyword_fn => {
                try out.writeAll("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
                next_tok_is_fn = true;
            },

            .string_literal,
            .multiline_string_literal_line,
            .char_literal,
            => {
                try out.writeAll("<span class=\"tok-str\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .builtin => {
                try out.writeAll("<span class=\"tok-builtin\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .doc_comment,
            .container_doc_comment,
            => {
                try out.writeAll("<span class=\"tok-comment\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .identifier => {
                const tok_bytes = src[token.loc.start..token.loc.end];
                if (mem.eql(u8, tok_bytes, "undefined") or
                    mem.eql(u8, tok_bytes, "null") or
                    mem.eql(u8, tok_bytes, "true") or
                    mem.eql(u8, tok_bytes, "false"))
                {
                    try out.writeAll("<span class=\"tok-null\">");
                    try writeEscaped(out, tok_bytes);
                    try out.writeAll("</span>");
                } else if (prev_tok_was_fn) {
                    try out.writeAll("<span class=\"tok-fn\">");
                    try writeEscaped(out, tok_bytes);
                    try out.writeAll("</span>");
                } else {
                    const is_int = blk: {
                        if (src[token.loc.start] != 'i' and src[token.loc.start] != 'u')
                            break :blk false;
                        var i = token.loc.start + 1;
                        if (i == token.loc.end)
                            break :blk false;
                        while (i != token.loc.end) : (i += 1) {
                            if (src[i] < '0' or src[i] > '9')
                                break :blk false;
                        }
                        break :blk true;
                    };
                    const isType = std.zig.isPrimitive;
                    if (is_int or isType(tok_bytes)) {
                        try out.writeAll("<span class=\"tok-type\">");
                        try writeEscaped(out, tok_bytes);
                        try out.writeAll("</span>");
                    } else {
                        try writeEscaped(out, tok_bytes);
                    }
                }
            },

            .number_literal => {
                try out.writeAll("<span class=\"tok-number\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .bang,
            .pipe,
            .pipe_pipe,
            .pipe_equal,
            .equal,
            .equal_equal,
            .equal_angle_bracket_right,
            .bang_equal,
            .l_paren,
            .r_paren,
            .semicolon,
            .percent,
            .percent_equal,
            .l_brace,
            .r_brace,
            .l_bracket,
            .r_bracket,
            .period,
            .period_asterisk,
            .ellipsis2,
            .ellipsis3,
            .caret,
            .caret_equal,
            .plus,
            .plus_plus,
            .plus_equal,
            .plus_percent,
            .plus_percent_equal,
            .plus_pipe,
            .plus_pipe_equal,
            .minus,
            .minus_equal,
            .minus_percent,
            .minus_percent_equal,
            .minus_pipe,
            .minus_pipe_equal,
            .asterisk,
            .asterisk_equal,
            .asterisk_asterisk,
            .asterisk_percent,
            .asterisk_percent_equal,
            .asterisk_pipe,
            .asterisk_pipe_equal,
            .arrow,
            .colon,
            .slash,
            .slash_equal,
            .comma,
            .ampersand,
            .ampersand_equal,
            .question_mark,
            .angle_bracket_left,
            .angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left,
            .angle_bracket_angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left_pipe,
            .angle_bracket_angle_bracket_left_pipe_equal,
            .angle_bracket_right,
            .angle_bracket_right_equal,
            .angle_bracket_angle_bracket_right,
            .angle_bracket_angle_bracket_right_equal,
            .tilde,
            => try writeEscaped(out, src[token.loc.start..token.loc.end]),

            .invalid, .invalid_periodasterisks => fatal("syntax error", .{}),
        }
        index = token.loc.end;
    }
    try out.writeAll("</code>");
}

fn writeEscapedLines(out: anytype, text: []const u8) !void {
    return writeEscaped(out, text);
}

const Code = struct {
    id: Id,
    mode: std.builtin.OptimizeMode,
    link_objects: []const []const u8,
    target_str: ?[]const u8,
    link_libc: bool,
    link_mode: ?std.builtin.LinkMode,
    disable_cache: bool,
    verbose_cimport: bool,
    just_check_syntax: bool,
    additional_options: []const []const u8,

    const Id = union(enum) {
        @"test",
        test_error: []const u8,
        test_safety: []const u8,
        exe: ExpectedOutcome,
        obj: ?[]const u8,
        lib,
    };

    const ExpectedOutcome = enum {
        succeed,
        fail,
        build_fail,
    };
};

fn stripManifest(source_bytes: []const u8) []const u8 {
    const manifest_start = mem.lastIndexOf(u8, source_bytes, "\n\n// ") orelse
        fatal("missing manifest comment", .{});
    return source_bytes[0 .. manifest_start + 1];
}

fn parseManifest(arena: Allocator, source_bytes: []const u8) !Code {
    const manifest_start = mem.lastIndexOf(u8, source_bytes, "\n\n// ") orelse
        fatal("missing manifest comment", .{});
    var it = mem.tokenizeScalar(u8, source_bytes[manifest_start..], '\n');
    const first_line = skipPrefix(it.next().?);

    var just_check_syntax = false;
    const id: Code.Id = if (mem.eql(u8, first_line, "syntax")) blk: {
        just_check_syntax = true;
        break :blk .{ .obj = null };
    } else if (mem.eql(u8, first_line, "test"))
        .@"test"
    else if (mem.eql(u8, first_line, "lib"))
        .lib
    else if (mem.eql(u8, first_line, "obj"))
        .{ .obj = null }
    else if (mem.startsWith(u8, first_line, "test_error="))
        .{ .test_error = first_line["test_error=".len..] }
    else if (mem.startsWith(u8, first_line, "test_safety="))
        .{ .test_safety = first_line["test_safety=".len..] }
    else if (mem.startsWith(u8, first_line, "exe="))
        .{ .exe = std.meta.stringToEnum(Code.ExpectedOutcome, first_line["exe=".len..]) orelse
            fatal("bad exe expected outcome in line '{s}'", .{first_line}) }
    else if (mem.startsWith(u8, first_line, "obj="))
        .{ .obj = first_line["obj=".len..] }
    else
        fatal("unrecognized manifest id: '{s}'", .{first_line});

    var mode: std.builtin.OptimizeMode = .Debug;
    var link_mode: ?std.builtin.LinkMode = null;
    var link_objects: std.ArrayListUnmanaged([]const u8) = .{};
    var additional_options: std.ArrayListUnmanaged([]const u8) = .{};
    var target_str: ?[]const u8 = null;
    var link_libc = false;
    var disable_cache = false;
    var verbose_cimport = false;

    while (it.next()) |prefixed_line| {
        const line = skipPrefix(prefixed_line);
        if (mem.startsWith(u8, line, "optimize=")) {
            mode = std.meta.stringToEnum(std.builtin.OptimizeMode, line["optimize=".len..]) orelse
                fatal("bad optimization mode line: '{s}'", .{line});
        } else if (mem.startsWith(u8, line, "link_mode=")) {
            link_mode = std.meta.stringToEnum(std.builtin.LinkMode, line["link_mode=".len..]) orelse
                fatal("bad link mode line: '{s}'", .{line});
        } else if (mem.startsWith(u8, line, "link_object=")) {
            try link_objects.append(arena, line["link_object=".len..]);
        } else if (mem.startsWith(u8, line, "additional_option=")) {
            try additional_options.append(arena, line["additional_option=".len..]);
        } else if (mem.startsWith(u8, line, "target=")) {
            target_str = line["target=".len..];
        } else if (mem.eql(u8, line, "link_libc")) {
            link_libc = true;
        } else if (mem.eql(u8, line, "disable_cache")) {
            disable_cache = true;
        } else if (mem.eql(u8, line, "verbose_cimport")) {
            verbose_cimport = true;
        } else {
            fatal("unrecognized manifest line: {s}", .{line});
        }
    }

    return .{
        .id = id,
        .mode = mode,
        .additional_options = try additional_options.toOwnedSlice(arena),
        .link_objects = try link_objects.toOwnedSlice(arena),
        .target_str = target_str,
        .link_libc = link_libc,
        .link_mode = link_mode,
        .disable_cache = disable_cache,
        .verbose_cimport = verbose_cimport,
        .just_check_syntax = just_check_syntax,
    };
}

fn skipPrefix(line: []const u8) []const u8 {
    if (!mem.startsWith(u8, line, "// ")) {
        fatal("line does not start with '// ': '{s}", .{line});
    }
    return line[3..];
}

fn escapeHtml(allocator: Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    const out = buf.writer();
    try writeEscaped(out, input);
    return try buf.toOwnedSlice();
}

fn writeEscaped(out: anytype, input: []const u8) !void {
    for (input) |c| {
        try switch (c) {
            '&' => out.writeAll("&amp;"),
            '<' => out.writeAll("&lt;"),
            '>' => out.writeAll("&gt;"),
            '"' => out.writeAll("&quot;"),
            else => out.writeByte(c),
        };
    }
}

fn termColor(allocator: Allocator, input: []const u8) ![]u8 {
    // The SRG sequences generates by the Zig compiler are in the format:
    //   ESC [ <foreground-color> ; <n> m
    // or
    //   ESC [ <n> m
    //
    // where
    //   foreground-color is 31 (red), 32 (green), 36 (cyan)
    //   n is 0 (reset), 1 (bold), 2 (dim)
    //
    //   Note that 37 (white) is currently not used by the compiler.
    //
    // See std.debug.TTY.Color.
    const supported_sgr_colors = [_]u8{ 31, 32, 36 };
    const supported_sgr_numbers = [_]u8{ 0, 1, 2 };

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var out = buf.writer();
    var sgr_param_start_index: usize = undefined;
    var sgr_num: u8 = undefined;
    var sgr_color: u8 = undefined;
    var i: usize = 0;
    var state: enum {
        start,
        escape,
        lbracket,
        number,
        after_number,
        arg,
        arg_number,
        expect_end,
    } = .start;
    var last_new_line: usize = 0;
    var open_span_count: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (state) {
            .start => switch (c) {
                '\x1b' => state = .escape,
                '\n' => {
                    try out.writeByte(c);
                    last_new_line = buf.items.len;
                },
                else => try out.writeByte(c),
            },
            .escape => switch (c) {
                '[' => state = .lbracket,
                else => return error.UnsupportedEscape,
            },
            .lbracket => switch (c) {
                '0'...'9' => {
                    sgr_param_start_index = i;
                    state = .number;
                },
                else => return error.UnsupportedEscape,
            },
            .number => switch (c) {
                '0'...'9' => {},
                else => {
                    sgr_num = try std.fmt.parseInt(u8, input[sgr_param_start_index..i], 10);
                    sgr_color = 0;
                    state = .after_number;
                    i -= 1;
                },
            },
            .after_number => switch (c) {
                ';' => state = .arg,
                'D' => state = .start,
                'K' => {
                    buf.items.len = last_new_line;
                    state = .start;
                },
                else => {
                    state = .expect_end;
                    i -= 1;
                },
            },
            .arg => switch (c) {
                '0'...'9' => {
                    sgr_param_start_index = i;
                    state = .arg_number;
                },
                else => return error.UnsupportedEscape,
            },
            .arg_number => switch (c) {
                '0'...'9' => {},
                else => {
                    // Keep the sequence consistent, foreground color first.
                    // 32;1m is equivalent to 1;32m, but the latter will
                    // generate an incorrect HTML class without notice.
                    sgr_color = sgr_num;
                    if (!in(&supported_sgr_colors, sgr_color)) return error.UnsupportedForegroundColor;

                    sgr_num = try std.fmt.parseInt(u8, input[sgr_param_start_index..i], 10);
                    if (!in(&supported_sgr_numbers, sgr_num)) return error.UnsupportedNumber;

                    state = .expect_end;
                    i -= 1;
                },
            },
            .expect_end => switch (c) {
                'm' => {
                    state = .start;
                    while (open_span_count != 0) : (open_span_count -= 1) {
                        try out.writeAll("</span>");
                    }
                    if (sgr_num == 0) {
                        if (sgr_color != 0) return error.UnsupportedColor;
                        continue;
                    }
                    if (sgr_color != 0) {
                        try out.print("<span class=\"sgr-{d}_{d}m\">", .{ sgr_color, sgr_num });
                    } else {
                        try out.print("<span class=\"sgr-{d}m\">", .{sgr_num});
                    }
                    open_span_count += 1;
                },
                else => return error.UnsupportedEscape,
            },
        }
    }
    return try buf.toOwnedSlice();
}

// Returns true if number is in slice.
fn in(slice: []const u8, number: u8) bool {
    return mem.indexOfScalar(u8, slice, number) != null;
}

fn run(
    allocator: Allocator,
    env_map: *process.EnvMap,
    cwd: ?[]const u8,
    args: []const []const u8,
) !process.Child.RunResult {
    const result = try process.Child.run(.{
        .allocator = allocator,
        .argv = args,
        .env_map = env_map,
        .cwd = cwd,
        .max_output_bytes = max_doc_file_size,
    });
    switch (result.term) {
        .Exited => |exit_code| {
            if (exit_code != 0) {
                std.debug.print("{s}\nThe following command exited with code {}:\n", .{ result.stderr, exit_code });
                dumpArgs(args);
                return error.ChildExitError;
            }
        },
        else => {
            std.debug.print("{s}\nThe following command crashed:\n", .{result.stderr});
            dumpArgs(args);
            return error.ChildCrashed;
        },
    }
    return result;
}

fn printShell(out: anytype, shell_content: []const u8, escape: bool) !void {
    const trimmed_shell_content = mem.trim(u8, shell_content, " \r\n");
    try out.writeAll("<figure><figcaption class=\"shell-cap\">Shell</figcaption><pre><samp>");
    var cmd_cont: bool = false;
    var iter = std.mem.splitScalar(u8, trimmed_shell_content, '\n');
    while (iter.next()) |orig_line| {
        const line = mem.trimRight(u8, orig_line, " \r");
        if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] != '\\') {
            try out.writeAll("$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll("</kbd>" ++ "\n");
        } else if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] == '\\') {
            try out.writeAll("$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll("\n");
            cmd_cont = true;
        } else if (line.len > 0 and line[line.len - 1] != '\\' and cmd_cont) {
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll("</kbd>" ++ "\n");
            cmd_cont = false;
        } else {
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll("\n");
        }
    }

    try out.writeAll("</samp></pre></figure>");
}

test "term supported colors" {
    const test_allocator = testing.allocator;

    {
        const input = "A\x1b[31;1mred\x1b[0mB";
        const expect = "A<span class=\"sgr-31_1m\">red</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[32;1mgreen\x1b[0mB";
        const expect = "A<span class=\"sgr-32_1m\">green</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[36;1mcyan\x1b[0mB";
        const expect = "A<span class=\"sgr-36_1m\">cyan</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[1mbold\x1b[0mB";
        const expect = "A<span class=\"sgr-1m\">bold</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[2mdim\x1b[0mB";
        const expect = "A<span class=\"sgr-2m\">dim</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }
}

test "term output from zig" {
    // Use data generated by https://github.com/perillo/zig-tty-test-data,
    // with zig version 0.11.0-dev.1898+36d47dd19.
    const test_allocator = testing.allocator;

    {
        // 1.1-with-build-progress.out
        const input = "Semantic Analysis [1324] \x1b[25D\x1b[0KLLVM Emit Object... \x1b[20D\x1b[0KLLVM Emit Object... \x1b[20D\x1b[0KLLD Link... \x1b[12D\x1b[0K";
        const expect = "";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.1-with-reference-traces.out
        const input = "\x1b[1msrc/2.1-with-reference-traces.zig:3:7: \x1b[31;1merror: \x1b[0m\x1b[1mcannot assign to constant\n\x1b[0m    x += 1;\n    \x1b[32;1m~~^~~~\n\x1b[0m\x1b[0m\x1b[2mreferenced by:\n    main: src/2.1-with-reference-traces.zig:7:5\n    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17\n    remaining reference traces hidden; use '-freference-trace' to see all reference traces\n\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">src/2.1-with-reference-traces.zig:3:7: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">cannot assign to constant
            \\</span>    x += 1;
            \\    <span class="sgr-32_1m">~~^~~~
            \\</span><span class="sgr-2m">referenced by:
            \\    main: src/2.1-with-reference-traces.zig:7:5
            \\    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17
            \\    remaining reference traces hidden; use '-freference-trace' to see all reference traces
            \\
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.2-without-reference-traces.out
        const input = "\x1b[1m/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:128:29: \x1b[31;1merror: \x1b[0m\x1b[1minvalid type given to fixedBufferStream\n\x1b[0m                    else => @compileError(\"invalid type given to fixedBufferStream\"),\n                            \x1b[32;1m^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\x1b[0m\x1b[1m/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:116:66: \x1b[36;1mnote: \x1b[0m\x1b[1mcalled from here\n\x1b[0mpub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {\n;                                                            \x1b[32;1m~~~~~^~~~~~~~~~~~~~~~~\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:128:29: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">invalid type given to fixedBufferStream
            \\</span>                    else => @compileError("invalid type given to fixedBufferStream"),
            \\                            <span class="sgr-32_1m">^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            \\</span><span class="sgr-1m">/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:116:66: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">called from here
            \\</span>pub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {
            \\;                                                            <span class="sgr-32_1m">~~~~~^~~~~~~~~~~~~~~~~
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.3-with-notes.out
        const input = "\x1b[1msrc/2.3-with-notes.zig:6:9: \x1b[31;1merror: \x1b[0m\x1b[1mexpected type '*2.3-with-notes.Derp', found '*2.3-with-notes.Wat'\n\x1b[0m    bar(w);\n        \x1b[32;1m^\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:6:9: \x1b[36;1mnote: \x1b[0m\x1b[1mpointer type child '2.3-with-notes.Wat' cannot cast into pointer type child '2.3-with-notes.Derp'\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:2:13: \x1b[36;1mnote: \x1b[0m\x1b[1mopaque declared here\n\x1b[0mconst Wat = opaque {};\n            \x1b[32;1m^~~~~~~~~\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:1:14: \x1b[36;1mnote: \x1b[0m\x1b[1mopaque declared here\n\x1b[0mconst Derp = opaque {};\n             \x1b[32;1m^~~~~~~~~\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:4:18: \x1b[36;1mnote: \x1b[0m\x1b[1mparameter type declared here\n\x1b[0mextern fn bar(d: *Derp) void;\n                 \x1b[32;1m^~~~~\n\x1b[0m\x1b[0m\x1b[2mreferenced by:\n    main: src/2.3-with-notes.zig:10:5\n    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17\n    remaining reference traces hidden; use '-freference-trace' to see all reference traces\n\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">src/2.3-with-notes.zig:6:9: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">expected type '*2.3-with-notes.Derp', found '*2.3-with-notes.Wat'
            \\</span>    bar(w);
            \\        <span class="sgr-32_1m">^
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:6:9: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">pointer type child '2.3-with-notes.Wat' cannot cast into pointer type child '2.3-with-notes.Derp'
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:2:13: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">opaque declared here
            \\</span>const Wat = opaque {};
            \\            <span class="sgr-32_1m">^~~~~~~~~
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:1:14: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">opaque declared here
            \\</span>const Derp = opaque {};
            \\             <span class="sgr-32_1m">^~~~~~~~~
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:4:18: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">parameter type declared here
            \\</span>extern fn bar(d: *Derp) void;
            \\                 <span class="sgr-32_1m">^~~~~
            \\</span><span class="sgr-2m">referenced by:
            \\    main: src/2.3-with-notes.zig:10:5
            \\    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17
            \\    remaining reference traces hidden; use '-freference-trace' to see all reference traces
            \\
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 3.1-with-error-return-traces.out

        const input = "error: Error\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:5:5\x1b[0m: \x1b[2m0x20b008 in callee (3.1-with-error-return-traces)\x1b[0m\n    return error.Error;\n    \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:9:5\x1b[0m: \x1b[2m0x20b113 in caller (3.1-with-error-return-traces)\x1b[0m\n    try callee();\n    \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:13:5\x1b[0m: \x1b[2m0x20b153 in main (3.1-with-error-return-traces)\x1b[0m\n    try caller();\n    \x1b[32;1m^\x1b[0m\n";
        const expect =
            \\error: Error
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:5:5</span>: <span class="sgr-2m">0x20b008 in callee (3.1-with-error-return-traces)</span>
            \\    return error.Error;
            \\    <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:9:5</span>: <span class="sgr-2m">0x20b113 in caller (3.1-with-error-return-traces)</span>
            \\    try callee();
            \\    <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:13:5</span>: <span class="sgr-2m">0x20b153 in main (3.1-with-error-return-traces)</span>
            \\    try caller();
            \\    <span class="sgr-32_1m">^</span>
            \\
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 3.2-with-stack-trace.out
        const input = "\x1b[1m/usr/local/lib/zig/lib/std/debug.zig:561:19\x1b[0m: \x1b[2m0x22a107 in writeCurrentStackTrace__anon_5898 (3.2-with-stack-trace)\x1b[0m\n    while (it.next()) |return_address| {\n                  \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/debug.zig:157:80\x1b[0m: \x1b[2m0x20bb23 in dumpCurrentStackTrace (3.2-with-stack-trace)\x1b[0m\n        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(io.getStdErr()), start_addr) catch |err| {\n                                                                               \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.2-with-stack-trace.zig:5:36\x1b[0m: \x1b[2m0x20d3b2 in foo (3.2-with-stack-trace)\x1b[0m\n    std.debug.dumpCurrentStackTrace(null);\n                                   \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.2-with-stack-trace.zig:9:8\x1b[0m: \x1b[2m0x20b458 in main (3.2-with-stack-trace)\x1b[0m\n    foo();\n       \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/start.zig:607:22\x1b[0m: \x1b[2m0x20a965 in posixCallMainAndExit (3.2-with-stack-trace)\x1b[0m\n            root.main();\n                     \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/start.zig:376:5\x1b[0m: \x1b[2m0x20a411 in _start (3.2-with-stack-trace)\x1b[0m\n    @call(.never_inline, posixCallMainAndExit, .{});\n    \x1b[32;1m^\x1b[0m\n";
        const expect =
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/debug.zig:561:19</span>: <span class="sgr-2m">0x22a107 in writeCurrentStackTrace__anon_5898 (3.2-with-stack-trace)</span>
            \\    while (it.next()) |return_address| {
            \\                  <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/debug.zig:157:80</span>: <span class="sgr-2m">0x20bb23 in dumpCurrentStackTrace (3.2-with-stack-trace)</span>
            \\        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(io.getStdErr()), start_addr) catch |err| {
            \\                                                                               <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.2-with-stack-trace.zig:5:36</span>: <span class="sgr-2m">0x20d3b2 in foo (3.2-with-stack-trace)</span>
            \\    std.debug.dumpCurrentStackTrace(null);
            \\                                   <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.2-with-stack-trace.zig:9:8</span>: <span class="sgr-2m">0x20b458 in main (3.2-with-stack-trace)</span>
            \\    foo();
            \\       <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/start.zig:607:22</span>: <span class="sgr-2m">0x20a965 in posixCallMainAndExit (3.2-with-stack-trace)</span>
            \\            root.main();
            \\                     <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/start.zig:376:5</span>: <span class="sgr-2m">0x20a411 in _start (3.2-with-stack-trace)</span>
            \\    @call(.never_inline, posixCallMainAndExit, .{});
            \\    <span class="sgr-32_1m">^</span>
            \\
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }
}

test "printShell" {
    const test_allocator = std.testing.allocator;

    {
        const shell_out =
            \\$ zig build test.zig
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\build output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out = "$ zig build test.zig\r\nbuild output\r\n";
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\build output
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
            \\$ <kbd>./test</kbd>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\
            \\$ <kbd>./test</kbd>
            \\output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\$ <kbd>./test</kbd>
            \\output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig \
            \\ --build-option
            \\build output
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\ --build-option</kbd>
            \\build output
            \\$ <kbd>./test</kbd>
            \\output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        // intentional space after "--build-option1 \"
        const shell_out =
            \\$ zig build test.zig \
            \\ --build-option1 \ 
            \\ --build-option2
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\ --build-option1 \
            \\ --build-option2</kbd>
            \\$ <kbd>./test</kbd>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig \
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\$ ./test</kbd>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\$ ./test
            \\$1
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\$ <kbd>./test</kbd>
            \\$1
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$zig build test.zig
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$zig build test.zig
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
}
