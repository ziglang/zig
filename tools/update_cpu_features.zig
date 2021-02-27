const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const json = std.json;
const assert = std.debug.assert;

const FeatureOverride = struct {
    llvm_name: []const u8,
    omit: bool = false,
    zig_name: ?[]const u8 = null,
    desc: ?[]const u8 = null,
};

const ExtraCpu = struct {
    llvm_name: ?[]const u8,
    zig_name: []const u8,
    features: []const []const u8,
};

const LlvmTarget = struct {
    zig_name: []const u8,
    llvm_name: []const u8,
    td_name: []const u8,
    feature_overrides: []const FeatureOverride = &.{},
    extra_cpus: []const ExtraCpu = &.{},
    branch_quota: ?usize = null,
};

const llvm_targets = [_]LlvmTarget{
    .{
        .zig_name = "aarch64",
        .llvm_name = "AArch64",
        .td_name = "AArch64.td",
        .branch_quota = 2000,
        .feature_overrides = &.{
            .{
                .llvm_name = "CONTEXTIDREL2",
                .zig_name = "contextidr_el2",
                .desc = "Enable RW operand Context ID Register (EL2)",
            },
            .{
                .llvm_name = "neoversee1",
                .zig_name = "neoverse_e1",
            },
            .{
                .llvm_name = "neoversen1",
                .zig_name = "neoverse_n1",
            },
            .{
                .llvm_name = "neoversen2",
                .zig_name = "neoverse_n2",
            },
            .{
                .llvm_name = "neoversev1",
                .zig_name = "neoverse_v1",
            },
        },
    },
    .{
        .zig_name = "amdgpu",
        .llvm_name = "AMDGPU",
        .td_name = "AMDGPU.td",
        .feature_overrides = &.{
            .{
                .llvm_name = "DumpCode",
                .omit = true,
            },
            .{
                .llvm_name = "dumpcode",
                .omit = true,
            },
        },
    },
    .{
        .zig_name = "arc",
        .llvm_name = "ARC",
        .td_name = "ARC.td",
    },
    .{
        .zig_name = "arm",
        .llvm_name = "ARM",
        .td_name = "ARM.td",
        .branch_quota = 10000,
    },
    .{
        .zig_name = "avr",
        .llvm_name = "AVR",
        .td_name = "AVR.td",
    },
    .{
        .zig_name = "bpf",
        .llvm_name = "BPF",
        .td_name = "BPF.td",
    },
    .{
        .zig_name = "csky",
        .llvm_name = "CSKY",
        .td_name = "CSKY.td",
    },
    .{
        .zig_name = "hexagon",
        .llvm_name = "Hexagon",
        .td_name = "Hexagon.td",
    },
    .{
        .zig_name = "lanai",
        .llvm_name = "Lanai",
        .td_name = "Lanai.td",
    },
    .{
        .zig_name = "msp430",
        .llvm_name = "MSP430",
        .td_name = "MSP430.td",
    },
    .{
        .zig_name = "mips",
        .llvm_name = "Mips",
        .td_name = "Mips.td",
    },
    .{
        .zig_name = "nvptx",
        .llvm_name = "NVPTX",
        .td_name = "NVPTX.td",
    },
    .{
        .zig_name = "powerpc",
        .llvm_name = "PowerPC",
        .td_name = "PPC.td",
    },
    .{
        .zig_name = "riscv",
        .llvm_name = "RISCV",
        .td_name = "RISCV.td",
        .extra_cpus = &.{
            .{
                .llvm_name = null,
                .zig_name = "baseline_rv32",
                .features = &.{ "a", "c", "d", "f", "m" },
            },
            .{
                .llvm_name = null,
                .zig_name = "baseline_rv64",
                .features = &.{ "64bit", "a", "c", "d", "f", "m" },
            },
        },
    },
    .{
        .zig_name = "sparc",
        .llvm_name = "Sparc",
        .td_name = "Sparc.td",
    },
    .{
        .zig_name = "systemz",
        .llvm_name = "SystemZ",
        .td_name = "SystemZ.td",
    },
    .{
        .zig_name = "ve",
        .llvm_name = "VE",
        .td_name = "VE.td",
    },
    .{
        .zig_name = "wasm",
        .llvm_name = "WebAssembly",
        .td_name = "WebAssembly.td",
    },
    .{
        .zig_name = "x86",
        .llvm_name = "X86",
        .td_name = "X86.td",
        .feature_overrides = &.{
            .{
                .llvm_name = "64bit-mode",
                .omit = true,
            },
            .{
                .llvm_name = "i386",
                .zig_name = "_i386",
            },
            .{
                .llvm_name = "i486",
                .zig_name = "_i486",
            },
            .{
                .llvm_name = "i586",
                .zig_name = "_i586",
            },
            .{
                .llvm_name = "i686",
                .zig_name = "_i686",
            },
        },
    },
    .{
        .zig_name = "xcore",
        .llvm_name = "XCore",
        .td_name = "XCore.td",
    },
};

pub fn main() anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = &arena_state.allocator;

    const args = try std.process.argsAlloc(arena);
    if (args.len <= 1) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }
    if (std.mem.eql(u8, args[1], "--help")) {
        usageAndExit(std.io.getStdOut(), args[0], 0);
    }
    if (args.len < 4) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const llvm_tblgen_exe = args[1];
    if (std.mem.startsWith(u8, llvm_tblgen_exe, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const llvm_src_root = args[2];
    if (std.mem.startsWith(u8, llvm_src_root, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    const zig_src_root = args[3];
    if (std.mem.startsWith(u8, zig_src_root, "-")) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    var zig_src_dir = try fs.cwd().openDir(zig_src_root, .{});
    defer zig_src_dir.close();

    var progress = std.Progress{};
    const root_progress = try progress.start("", llvm_targets.len);
    defer root_progress.end();

    if (std.builtin.single_threaded) {
        for (llvm_targets) |llvm_target| {
            try processOneTarget(Job{
                .llvm_tblgen_exe = llvm_tblgen_exe,
                .llvm_src_root = llvm_src_root,
                .zig_src_dir = zig_src_dir,
                .root_progress = root_progress,
                .llvm_target = llvm_target,
            });
        }
    } else {
        var threads = try arena.alloc(*std.Thread, llvm_targets.len);
        for (llvm_targets) |llvm_target, i| {
            threads[i] = try std.Thread.spawn(Job{
                .llvm_tblgen_exe = llvm_tblgen_exe,
                .llvm_src_root = llvm_src_root,
                .zig_src_dir = zig_src_dir,
                .root_progress = root_progress,
                .llvm_target = llvm_target,
            }, processOneTarget);
        }
        for (threads) |thread| {
            thread.wait();
        }
    }
}

const Job = struct {
    llvm_tblgen_exe: []const u8,
    llvm_src_root: []const u8,
    zig_src_dir: std.fs.Dir,
    root_progress: *std.Progress.Node,
    llvm_target: LlvmTarget,
};

fn processOneTarget(job: Job) anyerror!void {
    const llvm_target = job.llvm_target;

    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = &arena_state.allocator;

    var progress_node = job.root_progress.start(llvm_target.zig_name, 3);
    progress_node.activate();
    defer progress_node.end();

    var tblgen_progress = progress_node.start("invoke llvm-tblgen", 0);
    tblgen_progress.activate();

    const child_args = [_][]const u8{
        job.llvm_tblgen_exe,
        "--dump-json",
        try std.fmt.allocPrint(arena, "{s}/llvm/lib/Target/{s}/{s}", .{
            job.llvm_src_root,
            llvm_target.llvm_name,
            llvm_target.td_name,
        }),
        try std.fmt.allocPrint(arena, "-I={s}/llvm/include", .{job.llvm_src_root}),
        try std.fmt.allocPrint(arena, "-I={s}/llvm/lib/Target/{s}", .{
            job.llvm_src_root, llvm_target.llvm_name,
        }),
    };

    const child_result = try std.ChildProcess.exec(.{
        .allocator = arena,
        .argv = &child_args,
        .max_output_bytes = 200 * 1024 * 1024,
    });
    tblgen_progress.end();
    if (child_result.stderr.len != 0) {
        std.debug.warn("{s}\n", .{child_result.stderr});
    }

    const json_text = switch (child_result.term) {
        .Exited => |code| if (code == 0) child_result.stdout else {
            std.debug.warn("llvm-tblgen exited with code {d}\n", .{code});
            std.process.exit(1);
        },
        else => {
            std.debug.warn("llvm-tblgen crashed\n", .{});
            std.process.exit(1);
        },
    };

    var json_parse_progress = progress_node.start("parse JSON", 0);
    json_parse_progress.activate();

    var parser = json.Parser.init(arena, false);
    const tree = try parser.parse(json_text);
    json_parse_progress.end();

    var render_progress = progress_node.start("render zig code", 0);
    render_progress.activate();

    const root_map = &tree.root.Object;
    var all_features = std.ArrayList(*json.ObjectMap).init(arena);
    var all_cpus = std.ArrayList(*json.ObjectMap).init(arena);
    {
        var it = root_map.iterator();
        root_it: while (it.next()) |kv| {
            if (kv.key.len == 0) continue;
            if (kv.key[0] == '!') continue;
            if (kv.value != .Object) continue;
            if (hasSuperclass(&kv.value.Object, "SubtargetFeature")) {
                const llvm_name = kv.value.Object.get("Name").?.String;
                if (llvm_name.len == 0) continue;
                for (llvm_target.feature_overrides) |feature_override| {
                    if (mem.eql(u8, llvm_name, feature_override.llvm_name)) {
                        if (feature_override.omit) {
                            continue :root_it;
                        }
                    }
                }

                try all_features.append(&kv.value.Object);
            }
            if (hasSuperclass(&kv.value.Object, "Processor")) {
                try all_cpus.append(&kv.value.Object);
            }
        }
    }
    std.sort.sort(*json.ObjectMap, all_features.items, {}, objectLessThan);
    std.sort.sort(*json.ObjectMap, all_cpus.items, {}, objectLessThan);

    const target_sub_path = try fs.path.join(arena, &.{ "lib", "std", "target" });
    var target_dir = try job.zig_src_dir.makeOpenPath(target_sub_path, .{});
    defer target_dir.close();

    const zig_code_basename = try std.fmt.allocPrint(arena, "{s}.zig", .{llvm_target.zig_name});

    if (all_features.items.len == 0) {
        // We represent this with an empty file.
        try target_dir.deleteTree(zig_code_basename);
        return;
    }

    var zig_code_file = try target_dir.createFile(zig_code_basename, .{});
    defer zig_code_file.close();

    var bw = std.io.bufferedWriter(zig_code_file.writer());
    const w = bw.writer();

    try w.writeAll(
        \\//! This file is auto-generated by tools/update_cpu_features.zig.
        \\
        \\const std = @import("../std.zig");
        \\const CpuFeature = std.Target.Cpu.Feature;
        \\const CpuModel = std.Target.Cpu.Model;
        \\
        \\pub const Feature = enum {
        \\
    );

    for (all_features.items) |obj| {
        const llvm_name = obj.get("Name").?.String;
        const zig_name = try llvmNameToZigName(arena, llvm_target, llvm_name);
        try w.print("    {},\n", .{std.zig.fmtId(zig_name)});
    }

    try w.writeAll(
        \\};
        \\
        \\pub usingnamespace CpuFeature.feature_set_fns(Feature);
        \\
        \\pub const all_features = blk: {
        \\
    );
    if (llvm_target.branch_quota) |branch_quota| {
        try w.print("    @setEvalBranchQuota({d});\n", .{branch_quota});
    }
    try w.writeAll(
        \\    const len = @typeInfo(Feature).Enum.fields.len;
        \\    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
        \\    var result: [len]CpuFeature = undefined;
        \\
    );

    for (all_features.items) |obj| {
        const llvm_name = obj.get("Name").?.String;
        const llvm_description = obj.get("Desc").?.String;
        const description = for (llvm_target.feature_overrides) |feature_override| {
            if (mem.eql(u8, llvm_name, feature_override.llvm_name)) {
                if (feature_override.desc) |desc| {
                    break desc;
                }
            }
        } else llvm_description;
        const zig_name = try llvmNameToZigName(arena, llvm_target, llvm_name);
        try w.print(
            \\    result[@enumToInt(Feature.{})] = .{{
            \\        .llvm_name = "{}",
            \\        .description = "{}",
            \\        .dependencies = featureSet(&[_]Feature{{
        ,
            .{
                std.zig.fmtId(zig_name),
                std.zig.fmtEscapes(llvm_name),
                std.zig.fmtEscapes(description),
            },
        );
        const implies = obj.get("Implies").?.Array;
        var deps_set = std.StringHashMap(void).init(arena);
        for (implies.items) |imply| {
            const other_key = imply.Object.get("def").?.String;
            try deps_set.put(other_key, {});
        }
        try pruneFeatures(arena, root_map, &deps_set);
        var dependencies = std.ArrayList(*json.ObjectMap).init(arena);
        {
            var it = deps_set.iterator();
            while (it.next()) |entry| {
                const other_obj = &root_map.getEntry(entry.key).?.value.Object;
                try dependencies.append(other_obj);
            }
        }
        std.sort.sort(*json.ObjectMap, dependencies.items, {}, objectLessThan);

        if (dependencies.items.len == 0) {
            try w.writeAll(
                \\}),
                \\    };
                \\
            );
        } else {
            try w.writeAll("\n");
            for (dependencies.items) |dep| {
                const other_llvm_name = dep.get("Name").?.String;
                const other_zig_name = try llvmNameToZigName(arena, llvm_target, other_llvm_name);
                try w.print("            .{},\n", .{std.zig.fmtId(other_zig_name)});
            }
            try w.writeAll(
                \\        }),
                \\    };
                \\
            );
        }
    }
    try w.writeAll(
        \\    const ti = @typeInfo(Feature);
        \\    for (result) |*elem, i| {
        \\        elem.index = i;
        \\        elem.name = ti.Enum.fields[i].name;
        \\    }
        \\    break :blk result;
        \\};
        \\
        \\pub const cpu = struct {
        \\
    );
    for (llvm_target.extra_cpus) |extra_cpu| {
        try w.print(
            \\    pub const {} = CpuModel{{
            \\        .name = "{}",
            \\
        , .{
            std.zig.fmtId(extra_cpu.zig_name),
            std.zig.fmtEscapes(extra_cpu.zig_name),
        });
        if (extra_cpu.llvm_name) |llvm_name| {
            try w.print(
                \\        .llvm_name = "{}",
                \\        .features = featureSet(&[_]Feature{{
            , .{std.zig.fmtEscapes(llvm_name)});
        } else {
            try w.writeAll(
                \\        .llvm_name = null,
                \\        .features = featureSet(&[_]Feature{
            );
        }
        if (extra_cpu.features.len == 0) {
            try w.writeAll(
                \\}),
                \\    };
                \\
            );
        } else {
            try w.writeAll("\n");
            for (extra_cpu.features) |feature_zig_name| {
                try w.print("            .{},\n", .{std.zig.fmtId(feature_zig_name)});
            }
            try w.writeAll(
                \\        }),
                \\    };
                \\
            );
        }
    }
    for (all_cpus.items) |obj| {
        const llvm_name = obj.get("Name").?.String;
        var deps_set = std.StringHashMap(void).init(arena);

        const features = obj.get("Features").?.Array;
        for (features.items) |feature| {
            const feature_key = feature.Object.get("def").?.String;
            try deps_set.put(feature_key, {});
        }
        const tune_features = obj.get("TuneFeatures").?.Array;
        for (tune_features.items) |feature| {
            const feature_key = feature.Object.get("def").?.String;
            try deps_set.put(feature_key, {});
        }
        try pruneFeatures(arena, root_map, &deps_set);
        var cpu_features = std.ArrayList(*json.ObjectMap).init(arena);
        {
            var it = deps_set.iterator();
            while (it.next()) |entry| {
                const feature_obj = &root_map.getEntry(entry.key).?.value.Object;
                const feature_llvm_name = feature_obj.get("Name").?.String;
                if (feature_llvm_name.len == 0) continue;
                try cpu_features.append(feature_obj);
            }
        }
        std.sort.sort(*json.ObjectMap, cpu_features.items, {}, objectLessThan);
        const zig_cpu_name = try llvmNameToZigName(arena, llvm_target, llvm_name);
        try w.print(
            \\    pub const {} = CpuModel{{
            \\        .name = "{}",
            \\        .llvm_name = "{}",
            \\        .features = featureSet(&[_]Feature{{
        , .{
            std.zig.fmtId(zig_cpu_name),
            std.zig.fmtEscapes(zig_cpu_name),
            std.zig.fmtEscapes(llvm_name),
        });
        if (cpu_features.items.len == 0) {
            try w.writeAll(
                \\}),
                \\    };
                \\
            );
        } else {
            try w.writeAll("\n");
            for (cpu_features.items) |feature_obj| {
                const feature_llvm_name = feature_obj.get("Name").?.String;
                const feature_zig_name = try llvmNameToZigName(arena, llvm_target, feature_llvm_name);
                try w.print("            .{},\n", .{std.zig.fmtId(feature_zig_name)});
            }
            try w.writeAll(
                \\        }),
                \\    };
                \\
            );
        }
    }

    try w.writeAll(
        \\};
        \\
    );
    try bw.flush();

    render_progress.end();
}

fn usageAndExit(file: fs.File, arg0: []const u8, code: u8) noreturn {
    file.writer().print(
        \\Usage: {s} /path/to/llvm-tblgen /path/git/llvm-project /path/git/zig
        \\
        \\Prints to stdout Zig code which you can use to replace the file src/clang_options_data.zig.
        \\
        \\On a less beefy system, or when debugging, compile with --single-threaded.
        \\
    , .{arg0}) catch std.process.exit(1);
    std.process.exit(code);
}

fn objectLessThan(context: void, a: *json.ObjectMap, b: *json.ObjectMap) bool {
    const a_key = a.get("Name").?.String;
    const b_key = b.get("Name").?.String;
    return std.ascii.lessThanIgnoreCase(a_key, b_key);
}

fn llvmNameToZigName(
    arena: *mem.Allocator,
    llvm_target: LlvmTarget,
    llvm_name: []const u8,
) ![]const u8 {
    for (llvm_target.feature_overrides) |feature_override| {
        if (mem.eql(u8, feature_override.llvm_name, llvm_name)) {
            assert(!feature_override.omit);
            return feature_override.zig_name orelse break;
        }
    }
    const duped = try arena.dupe(u8, llvm_name);
    for (duped) |*byte| switch (byte.*) {
        '-', '.' => byte.* = '_',
        else => continue,
    };
    return duped;
}

fn hasSuperclass(obj: *json.ObjectMap, class_name: []const u8) bool {
    const superclasses_json = obj.get("!superclasses") orelse return false;
    for (superclasses_json.Array.items) |superclass_json| {
        const superclass = superclass_json.String;
        if (std.mem.eql(u8, superclass, class_name)) {
            return true;
        }
    }
    return false;
}

fn pruneFeatures(
    arena: *mem.Allocator,
    root_map: *const json.ObjectMap,
    deps_set: *std.StringHashMap(void),
) !void {
    // For each element, recursively iterate over the dependencies and add
    // everything we find to a "deletion set".
    // Then, iterate over the deletion set and delete all that stuff from `deps_set`.
    var deletion_set = std.StringHashMap(void).init(arena);
    {
        var it = deps_set.iterator();
        while (it.next()) |entry| {
            const other_obj = &root_map.getEntry(entry.key).?.value.Object;
            try walkFeatures(root_map, &deletion_set, other_obj);
        }
    }
    {
        var it = deletion_set.iterator();
        while (it.next()) |entry| {
            _ = deps_set.remove(entry.key);
        }
    }
}

fn walkFeatures(
    root_map: *const json.ObjectMap,
    deletion_set: *std.StringHashMap(void),
    feature: *json.ObjectMap,
) error{OutOfMemory}!void {
    const implies = feature.get("Implies").?.Array;
    for (implies.items) |imply| {
        const other_key = imply.Object.get("def").?.String;
        try deletion_set.put(other_key, {});
        const other_obj = &root_map.getEntry(other_key).?.value.Object;
        try walkFeatures(root_map, deletion_set, other_obj);
    }
}
