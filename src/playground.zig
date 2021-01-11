const std = @import("std");

const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const Package = @import("Package.zig");
const Type = @import("type.zig").Type;
const ThreadPool = @import("ThreadPool.zig");
const link = @import("link.zig");

extern fn wasmEval(code_ptr: [*]const u8, code_len: usize) f64;
extern fn stderr(msg_ptr: [*]const u8, msg_len: usize) void;

pub const os = struct {
    pub const system = struct {
        pub fn exit(status: u8) noreturn {
            std.os.abort();
        }

        pub fn abort() noreturn {
            // TODO trap instruction
            while (true) {
                @breakpoint();
            }
        }
    };
};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // We only recognize 4 log levels in this application.
    const level_txt = switch (level) {
        .emerg, .alert, .crit, .err => "error",
        .warn => "warning",
        .notice, .info => "info",
        .debug => "debug",
    };
    const arena = &arena_allocator.allocator;
    const msg = std.fmt.allocPrint(arena, level_txt ++ ": " ++ format, args) catch
        "log: out of memory";
    stderr(msg.ptr, msg.len);
}

// TODO recover from panic by having the js re-instantiate the wasm
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    const arena = &arena_allocator.allocator;
    const full_msg = std.fmt.allocPrint(arena, "panic: {s}", .{msg}) catch
        "panic: out of memory";
    stderr(full_msg.ptr, full_msg.len);
    std.os.abort();
}

var arena_allocator: std.heap.ArenaAllocator = undefined;

export fn zigEval(code_ptr: [*]const u8, code_len: usize) f64 {
    arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    if (eval(arena, code_ptr[0..code_len])) |result| {
        return result;
    } else |err| {
        const msg = @errorName(err);
        stderr(msg.ptr, msg.len);
        return 1.0;
    }
}

fn eval(arena: *std.mem.Allocator, code: []const u8) !f64 {
    const gpa = arena;
    const comp = try arena.create(Compilation);
    const root_pkg = try Package.create(arena, null, "main.zig");
    const root_scope = try arena.create(Module.Scope.File);
    const struct_ty = try Type.Tag.empty_struct.create(arena, &root_scope.root_container);
    root_scope.* = .{
        .sub_file_path = root_pkg.root_src_path,
        .source = .{ .unloaded = {} },
        .contents = .{ .not_available = {} },
        .status = .never_loaded,
        .pkg = root_pkg,
        .root_container = .{
            .file_scope = root_scope,
            .decls = .{},
            .ty = struct_ty,
        },
    };

    const module = try arena.create(Module);
    module.* = .{
        .gpa = gpa,
        .comp = comp,
        .root_pkg = root_pkg,
        .root_scope = &root_scope.base,
        .zig_cache_artifact_directory = .{
            .path = null,
            .handle = .{},
        },
        .emit_h = null,
    };

    const emit_directory: Compilation.Directory = .{
        .path = null,
        .handle = .{},
    };

    const emit_bin: link.Emit = .{
        .directory = emit_directory,
        .sub_path = "main.wasm",
    };

    const bin_file = try link.File.openPath(arena, .{
        .emit = emit_bin,
        .root_name = "main",
        .module = module,
        .target = std.Target.current,
        .dynamic_linker = null,
        .output_mode = .Lib,
        .link_mode = .Static,
        .object_format = .wasm,
        .optimize_mode = .Debug,
        .use_lld = false,
        .use_llvm = false,
        .system_linker_hack = false,
        .link_libc = false,
        .link_libcpp = false,
        .objects = &[0][]const u8{},
        .frameworks = &[0][]const u8{},
        .framework_dirs = &[0][]const u8{},
        .system_libs = std.StringArrayHashMapUnmanaged(void){},
        .syslibroot = null,
        .lib_dirs = &[0][]const u8{},
        .rpath_list = &[0][]const u8{},
        .strip = false,
        .is_native_os = false,
        .is_native_abi = false,
        .function_sections = false,
        .allow_shlib_undefined = false,
        .bind_global_refs_locally = false,
        .z_nodelete = false,
        .z_defs = false,
        .stack_size_override = null,
        .image_base_override = null,
        .include_compiler_rt = false,
        .linker_script = null,
        .version_script = null,
        .gc_sections = false,
        .eh_frame_hdr = false,
        .emit_relocs = false,
        .rdynamic = false,
        .extra_lld_args = &[0][]const u8{},
        .soname = null,
        .version = null,
        .libc_installation = null,
        .pic = false,
        .pie = false,
        .valgrind = false,
        .tsan = false,
        .stack_check = false,
        .single_threaded = true,
        .verbose_link = false,
        .machine_code_model = .default,
        .dll_export_fns = false,
        .error_return_tracing = false,
        .llvm_cpu_features = null,
        .skip_linker_dependencies = false,
        .parent_compilation_link_libc = false,
        .each_lib_rpath = false,
        .disable_lld_caching = true,
        .subsystem = null,
        .is_test = false,
    });

    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(gpa);
    defer thread_pool.deinit();

    comp.* = .{
        .gpa = gpa,
        .bin_file = bin_file,
        .work_queue = std.fifo.LinearFifo(Compilation.Job, .Dynamic).init(gpa),
        .keep_source_files_loaded = true,
        .use_clang = false,
        .sanitize_c = false,
        .c_source_files = &[0]Compilation.CSourceFile{},
        .thread_pool = &thread_pool,
        .verbose_cc = false,
        .verbose_tokenize = false,
        .verbose_ast = false,
        .verbose_ir = false,
        .verbose_llvm_ir = false,
        .verbose_cimport = false,
        .verbose_llvm_cpu_features = false,
        .disable_c_depfile = true,
        .time_report = false,
        .stack_report = false,
        .test_evented_io = false,
        .work_queue_wait_group = undefined,
        .color = .off,
    };

    try comp.update();

    var errors = try comp.getAllErrorsAlloc();
    if (errors.list.len != 0) {
        // TODO report compile errors
        //for (errors.list) |full_err_msg| {
        //    full_err_msg.renderToStdErr();
        //}
        return error.SemanticAnalyzeFail;
    }

    const wasm_binary = try emit_directory.handle.readFileAllocOptions(
        arena,
        emit_bin.sub_path,
        std.math.maxInt(u32),
        null,
        1,
        0,
    );

    return wasmEval(wasm_binary.ptr, wasm_binary.len);
}
