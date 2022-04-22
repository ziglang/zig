const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);
const math = std.math;
const native_endian = builtin.cpu.arch.endian();
const DW = std.dwarf;

const llvm = @import("llvm/bindings.zig");
const link = @import("../link.zig");
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const Module = @import("../Module.zig");
const Package = @import("../Package.zig");
const TypedValue = @import("../TypedValue.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const target_util = @import("../target.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const LazySrcLoc = Module.LazySrcLoc;
const CType = @import("../type.zig").CType;
const x86_64_abi = @import("../arch/x86_64/abi.zig");

const Error = error{ OutOfMemory, CodegenFail };

pub fn targetTriple(allocator: Allocator, target: std.Target) ![:0]u8 {
    const llvm_arch = switch (target.cpu.arch) {
        .arm => "arm",
        .armeb => "armeb",
        .aarch64 => "aarch64",
        .aarch64_be => "aarch64_be",
        .aarch64_32 => "aarch64_32",
        .arc => "arc",
        .avr => "avr",
        .bpfel => "bpfel",
        .bpfeb => "bpfeb",
        .csky => "csky",
        .hexagon => "hexagon",
        .m68k => "m68k",
        .mips => "mips",
        .mipsel => "mipsel",
        .mips64 => "mips64",
        .mips64el => "mips64el",
        .msp430 => "msp430",
        .powerpc => "powerpc",
        .powerpcle => "powerpcle",
        .powerpc64 => "powerpc64",
        .powerpc64le => "powerpc64le",
        .r600 => "r600",
        .amdgcn => "amdgcn",
        .riscv32 => "riscv32",
        .riscv64 => "riscv64",
        .sparc => "sparc",
        .sparcv9 => "sparcv9",
        .sparcel => "sparcel",
        .s390x => "s390x",
        .tce => "tce",
        .tcele => "tcele",
        .thumb => "thumb",
        .thumbeb => "thumbeb",
        .i386 => "i386",
        .x86_64 => "x86_64",
        .xcore => "xcore",
        .nvptx => "nvptx",
        .nvptx64 => "nvptx64",
        .le32 => "le32",
        .le64 => "le64",
        .amdil => "amdil",
        .amdil64 => "amdil64",
        .hsail => "hsail",
        .hsail64 => "hsail64",
        .spir => "spir",
        .spir64 => "spir64",
        .kalimba => "kalimba",
        .shave => "shave",
        .lanai => "lanai",
        .wasm32 => "wasm32",
        .wasm64 => "wasm64",
        .renderscript32 => "renderscript32",
        .renderscript64 => "renderscript64",
        .ve => "ve",
        .spu_2 => return error.@"LLVM backend does not support SPU Mark II",
        .spirv32 => return error.@"LLVM backend does not support SPIR-V",
        .spirv64 => return error.@"LLVM backend does not support SPIR-V",
    };

    const llvm_os = switch (target.os.tag) {
        .freestanding => "unknown",
        .ananas => "ananas",
        .cloudabi => "cloudabi",
        .dragonfly => "dragonfly",
        .freebsd => "freebsd",
        .fuchsia => "fuchsia",
        .ios => "ios",
        .kfreebsd => "kfreebsd",
        .linux => "linux",
        .lv2 => "lv2",
        .macos => "macosx",
        .netbsd => "netbsd",
        .openbsd => "openbsd",
        .solaris => "solaris",
        .windows => "windows",
        .zos => "zos",
        .haiku => "haiku",
        .minix => "minix",
        .rtems => "rtems",
        .nacl => "nacl",
        .aix => "aix",
        .cuda => "cuda",
        .nvcl => "nvcl",
        .amdhsa => "amdhsa",
        .ps4 => "ps4",
        .elfiamcu => "elfiamcu",
        .tvos => "tvos",
        .watchos => "watchos",
        .mesa3d => "mesa3d",
        .contiki => "contiki",
        .amdpal => "amdpal",
        .hermit => "hermit",
        .hurd => "hurd",
        .wasi => "wasi",
        .emscripten => "emscripten",
        .uefi => "windows",

        .opencl,
        .glsl450,
        .vulkan,
        .plan9,
        .other,
        => "unknown",
    };

    const llvm_abi = switch (target.abi) {
        .none => "unknown",
        .gnu => "gnu",
        .gnuabin32 => "gnuabin32",
        .gnuabi64 => "gnuabi64",
        .gnueabi => "gnueabi",
        .gnueabihf => "gnueabihf",
        .gnux32 => "gnux32",
        .gnuilp32 => "gnuilp32",
        .code16 => "code16",
        .eabi => "eabi",
        .eabihf => "eabihf",
        .android => "android",
        .musl => "musl",
        .musleabi => "musleabi",
        .musleabihf => "musleabihf",
        .muslx32 => "muslx32",
        .msvc => "msvc",
        .itanium => "itanium",
        .cygnus => "cygnus",
        .coreclr => "coreclr",
        .simulator => "simulator",
        .macabi => "macabi",
    };

    return std.fmt.allocPrintZ(allocator, "{s}-unknown-{s}-{s}", .{ llvm_arch, llvm_os, llvm_abi });
}

pub const Object = struct {
    gpa: Allocator,
    module: *Module,
    llvm_module: *const llvm.Module,
    di_builder: ?*llvm.DIBuilder,
    /// One of these mappings:
    /// - *Module.File => *DIFile
    /// - *Module.Decl (Fn) => *DISubprogram
    /// - *Module.Decl (Non-Fn) => *DIGlobalVariable
    di_map: std.AutoHashMapUnmanaged(*const anyopaque, *llvm.DINode),
    di_compile_unit: ?*llvm.DICompileUnit,
    context: *const llvm.Context,
    target_machine: *const llvm.TargetMachine,
    target_data: *const llvm.TargetData,
    target: std.Target,
    /// Ideally we would use `llvm_module.getNamedFunction` to go from *Decl to LLVM function,
    /// but that has some downsides:
    /// * we have to compute the fully qualified name every time we want to do the lookup
    /// * for externally linked functions, the name is not fully qualified, but when
    ///   a Decl goes from exported to not exported and vice-versa, we would use the wrong
    ///   version of the name and incorrectly get function not found in the llvm module.
    /// * it works for functions not all globals.
    /// Therefore, this table keeps track of the mapping.
    decl_map: std.AutoHashMapUnmanaged(Module.Decl.Index, *const llvm.Value),
    /// Maps Zig types to LLVM types. The table memory itself is backed by the GPA of
    /// the compiler, but the Type/Value memory here is backed by `type_map_arena`.
    /// TODO we need to remove entries from this map in response to incremental compilation
    /// but I think the frontend won't tell us about types that get deleted because
    /// hasRuntimeBits() is false for types.
    type_map: TypeMap,
    /// The backing memory for `type_map`. Periodically garbage collected after flush().
    /// The code for doing the periodical GC is not yet implemented.
    type_map_arena: std.heap.ArenaAllocator,
    di_type_map: DITypeMap,
    /// The LLVM global table which holds the names corresponding to Zig errors.
    /// Note that the values are not added until flushModule, when all errors in
    /// the compilation are known.
    error_name_table: ?*const llvm.Value,

    pub const TypeMap = std.HashMapUnmanaged(
        Type,
        *const llvm.Type,
        Type.HashContext64,
        std.hash_map.default_max_load_percentage,
    );

    /// This is an ArrayHashMap as opposed to a HashMap because in `flushModule` we
    /// want to iterate over it while adding entries to it.
    pub const DITypeMap = std.ArrayHashMapUnmanaged(
        Type,
        AnnotatedDITypePtr,
        Type.HashContext32,
        true,
    );

    pub fn create(gpa: Allocator, options: link.Options) !*Object {
        const obj = try gpa.create(Object);
        errdefer gpa.destroy(obj);
        obj.* = try Object.init(gpa, options);
        return obj;
    }

    pub fn init(gpa: Allocator, options: link.Options) !Object {
        const context = llvm.Context.create();
        errdefer context.dispose();

        initializeLLVMTarget(options.target.cpu.arch);

        const llvm_module = llvm.Module.createWithName(options.root_name.ptr, context);
        errdefer llvm_module.dispose();

        const llvm_target_triple = try targetTriple(gpa, options.target);
        defer gpa.free(llvm_target_triple);

        var error_message: [*:0]const u8 = undefined;
        var target: *const llvm.Target = undefined;
        if (llvm.Target.getFromTriple(llvm_target_triple.ptr, &target, &error_message).toBool()) {
            defer llvm.disposeMessage(error_message);

            log.err("LLVM failed to parse '{s}': {s}", .{ llvm_target_triple, error_message });
            return error.InvalidLlvmTriple;
        }

        llvm_module.setTarget(llvm_target_triple.ptr);
        var opt_di_builder: ?*llvm.DIBuilder = null;
        errdefer if (opt_di_builder) |di_builder| di_builder.dispose();

        var di_compile_unit: ?*llvm.DICompileUnit = null;

        if (!options.strip) {
            switch (options.object_format) {
                .coff => llvm_module.addModuleCodeViewFlag(),
                else => llvm_module.addModuleDebugInfoFlag(),
            }
            const di_builder = llvm_module.createDIBuilder(true);
            opt_di_builder = di_builder;

            // Don't use the version string here; LLVM misparses it when it
            // includes the git revision.
            const producer = try std.fmt.allocPrintZ(gpa, "zig {d}.{d}.{d}", .{
                build_options.semver.major,
                build_options.semver.minor,
                build_options.semver.patch,
            });
            defer gpa.free(producer);

            // For macOS stack traces, we want to avoid having to parse the compilation unit debug
            // info. As long as each debug info file has a path independent of the compilation unit
            // directory (DW_AT_comp_dir), then we never have to look at the compilation unit debug
            // info. If we provide an absolute path to LLVM here for the compilation unit debug
            // info, LLVM will emit DWARF info that depends on DW_AT_comp_dir. To avoid this, we
            // pass "." for the compilation unit directory. This forces each debug file to have a
            // directory rather than be relative to DW_AT_comp_dir. According to DWARF 5, debug
            // files will no longer reference DW_AT_comp_dir, for the purpose of being able to
            // support the common practice of stripping all but the line number sections from an
            // executable.
            const compile_unit_dir = d: {
                if (options.target.isDarwin()) break :d ".";
                const mod = options.module orelse break :d ".";
                break :d mod.root_pkg.root_src_directory.path orelse ".";
            };
            const compile_unit_dir_z = try gpa.dupeZ(u8, compile_unit_dir);
            defer gpa.free(compile_unit_dir_z);

            di_compile_unit = di_builder.createCompileUnit(
                DW.LANG.C99,
                di_builder.createFile(options.root_name, compile_unit_dir_z),
                producer,
                options.optimize_mode != .Debug,
                "", // flags
                0, // runtime version
                "", // split name
                0, // dwo id
                true, // emit debug info
            );
        }

        const opt_level: llvm.CodeGenOptLevel = if (options.optimize_mode == .Debug)
            .None
        else
            .Aggressive;

        const reloc_mode: llvm.RelocMode = if (options.pic)
            .PIC
        else if (options.link_mode == .Dynamic)
            llvm.RelocMode.DynamicNoPIC
        else
            .Static;

        const code_model: llvm.CodeModel = switch (options.machine_code_model) {
            .default => .Default,
            .tiny => .Tiny,
            .small => .Small,
            .kernel => .Kernel,
            .medium => .Medium,
            .large => .Large,
        };

        // TODO handle float ABI better- it should depend on the ABI portion of std.Target
        const float_abi: llvm.ABIType = .Default;

        const target_machine = llvm.TargetMachine.create(
            target,
            llvm_target_triple.ptr,
            if (options.target.cpu.model.llvm_name) |s| s.ptr else null,
            options.llvm_cpu_features,
            opt_level,
            reloc_mode,
            code_model,
            options.function_sections,
            float_abi,
            if (target_util.llvmMachineAbi(options.target)) |s| s.ptr else null,
        );
        errdefer target_machine.dispose();

        const target_data = target_machine.createTargetDataLayout();
        errdefer target_data.dispose();

        llvm_module.setModuleDataLayout(target_data);

        return Object{
            .gpa = gpa,
            .module = options.module.?,
            .llvm_module = llvm_module,
            .di_map = .{},
            .di_builder = opt_di_builder,
            .di_compile_unit = di_compile_unit,
            .context = context,
            .target_machine = target_machine,
            .target_data = target_data,
            .target = options.target,
            .decl_map = .{},
            .type_map = .{},
            .type_map_arena = std.heap.ArenaAllocator.init(gpa),
            .di_type_map = .{},
            .error_name_table = null,
        };
    }

    pub fn deinit(self: *Object, gpa: Allocator) void {
        if (self.di_builder) |dib| {
            dib.dispose();
            self.di_map.deinit(gpa);
            self.di_type_map.deinit(gpa);
        }
        self.target_data.dispose();
        self.target_machine.dispose();
        self.llvm_module.dispose();
        self.context.dispose();
        self.decl_map.deinit(gpa);
        self.type_map.deinit(gpa);
        self.type_map_arena.deinit();
        self.* = undefined;
    }

    pub fn destroy(self: *Object, gpa: Allocator) void {
        self.deinit(gpa);
        gpa.destroy(self);
    }

    fn locPath(
        arena: Allocator,
        opt_loc: ?Compilation.EmitLoc,
        cache_directory: Compilation.Directory,
    ) !?[*:0]u8 {
        const loc = opt_loc orelse return null;
        const directory = loc.directory orelse cache_directory;
        const slice = try directory.joinZ(arena, &[_][]const u8{loc.basename});
        return slice.ptr;
    }

    fn genErrorNameTable(self: *Object, comp: *Compilation) !void {
        // If self.error_name_table is null, there was no instruction that actually referenced the error table.
        const error_name_table_ptr_global = self.error_name_table orelse return;

        const mod = comp.bin_file.options.module.?;
        const target = mod.getTarget();

        const llvm_ptr_ty = self.context.intType(8).pointerType(0); // TODO: Address space
        const llvm_usize_ty = self.context.intType(target.cpu.arch.ptrBitWidth());
        const type_fields = [_]*const llvm.Type{
            llvm_ptr_ty,
            llvm_usize_ty,
        };
        const llvm_slice_ty = self.context.structType(&type_fields, type_fields.len, .False);
        const slice_ty = Type.initTag(.const_slice_u8_sentinel_0);
        const slice_alignment = slice_ty.abiAlignment(target);

        const error_name_list = mod.error_name_list.items;
        const llvm_errors = try comp.gpa.alloc(*const llvm.Value, error_name_list.len);
        defer comp.gpa.free(llvm_errors);

        llvm_errors[0] = llvm_slice_ty.getUndef();
        for (llvm_errors[1..]) |*llvm_error, i| {
            const name = error_name_list[1..][i];
            const str_init = self.context.constString(name.ptr, @intCast(c_uint, name.len), .False);
            const str_global = self.llvm_module.addGlobal(str_init.typeOf(), "");
            str_global.setInitializer(str_init);
            str_global.setLinkage(.Private);
            str_global.setGlobalConstant(.True);
            str_global.setUnnamedAddr(.True);
            str_global.setAlignment(1);

            const slice_fields = [_]*const llvm.Value{
                str_global.constBitCast(llvm_ptr_ty),
                llvm_usize_ty.constInt(name.len, .False),
            };
            llvm_error.* = llvm_slice_ty.constNamedStruct(&slice_fields, slice_fields.len);
        }

        const error_name_table_init = llvm_slice_ty.constArray(llvm_errors.ptr, @intCast(c_uint, error_name_list.len));

        const error_name_table_global = self.llvm_module.addGlobal(error_name_table_init.typeOf(), "");
        error_name_table_global.setInitializer(error_name_table_init);
        error_name_table_global.setLinkage(.Private);
        error_name_table_global.setGlobalConstant(.True);
        error_name_table_global.setUnnamedAddr(.True);
        error_name_table_global.setAlignment(slice_alignment); // TODO: Dont hardcode

        const error_name_table_ptr = error_name_table_global.constBitCast(llvm_slice_ty.pointerType(0)); // TODO: Address space
        error_name_table_ptr_global.setInitializer(error_name_table_ptr);
    }

    fn genCmpLtErrorsLenFunction(object: *Object, comp: *Compilation) !void {
        // If there is no such function in the module, it means the source code does not need it.
        const llvm_fn = object.llvm_module.getNamedFunction(lt_errors_fn_name) orelse return;
        const mod = comp.bin_file.options.module.?;
        const errors_len = mod.global_error_set.count();

        // Delete previous implementation. We replace it with every flush() because the
        // total number of errors may have changed.
        while (llvm_fn.getFirstBasicBlock()) |bb| {
            bb.deleteBasicBlock();
        }

        const builder = object.context.createBuilder();

        const entry_block = object.context.appendBasicBlock(llvm_fn, "Entry");
        builder.positionBuilderAtEnd(entry_block);
        builder.clearCurrentDebugLocation();

        // Example source of the following LLVM IR:
        // fn __zig_lt_errors_len(index: u16) bool {
        //     return index < total_errors_len;
        // }

        const lhs = llvm_fn.getParam(0);
        const rhs = lhs.typeOf().constInt(errors_len, .False);
        const is_lt = builder.buildICmp(.ULT, lhs, rhs, "");
        _ = builder.buildRet(is_lt);
    }

    pub fn flushModule(self: *Object, comp: *Compilation, prog_node: *std.Progress.Node) !void {
        var sub_prog_node = prog_node.start("LLVM Emit Object", 0);
        sub_prog_node.activate();
        sub_prog_node.context.refresh();
        defer sub_prog_node.end();

        try self.genErrorNameTable(comp);
        try self.genCmpLtErrorsLenFunction(comp);

        if (self.di_builder) |dib| {
            // When lowering debug info for pointers, we emitted the element types as
            // forward decls. Now we must go flesh those out.
            // Here we iterate over a hash map while modifying it but it is OK because
            // we never add or remove entries during this loop.
            var i: usize = 0;
            while (i < self.di_type_map.count()) : (i += 1) {
                const value_ptr = &self.di_type_map.values()[i];
                const annotated = value_ptr.*;
                if (!annotated.isFwdOnly()) continue;
                const entry: Object.DITypeMap.Entry = .{
                    .key_ptr = &self.di_type_map.keys()[i],
                    .value_ptr = value_ptr,
                };
                _ = try self.lowerDebugTypeImpl(entry, .full, annotated.toDIType());
            }

            dib.finalize();
        }

        if (comp.verbose_llvm_ir) {
            self.llvm_module.dump();
        }

        if (std.debug.runtime_safety) {
            var error_message: [*:0]const u8 = undefined;
            // verifyModule always allocs the error_message even if there is no error
            defer llvm.disposeMessage(error_message);

            if (self.llvm_module.verify(.ReturnStatus, &error_message).toBool()) {
                std.debug.print("\n{s}\n", .{error_message});
                @panic("LLVM module verification failed");
            }
        }

        var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const mod = comp.bin_file.options.module.?;
        const cache_dir = mod.zig_cache_artifact_directory;

        var emit_bin_path: ?[*:0]const u8 = if (comp.bin_file.options.emit) |emit|
            try emit.basenamePath(arena, try arena.dupeZ(u8, comp.bin_file.intermediary_basename.?))
        else
            null;

        const emit_asm_path = try locPath(arena, comp.emit_asm, cache_dir);
        const emit_llvm_ir_path = try locPath(arena, comp.emit_llvm_ir, cache_dir);
        const emit_llvm_bc_path = try locPath(arena, comp.emit_llvm_bc, cache_dir);

        const emit_asm_msg = emit_asm_path orelse "(none)";
        const emit_bin_msg = emit_bin_path orelse "(none)";
        const emit_llvm_ir_msg = emit_llvm_ir_path orelse "(none)";
        const emit_llvm_bc_msg = emit_llvm_bc_path orelse "(none)";
        log.debug("emit LLVM object asm={s} bin={s} ir={s} bc={s}", .{
            emit_asm_msg, emit_bin_msg, emit_llvm_ir_msg, emit_llvm_bc_msg,
        });

        var error_message: [*:0]const u8 = undefined;
        if (self.target_machine.emitToFile(
            self.llvm_module,
            &error_message,
            comp.bin_file.options.optimize_mode == .Debug,
            comp.bin_file.options.optimize_mode == .ReleaseSmall,
            comp.time_report,
            comp.bin_file.options.tsan,
            comp.bin_file.options.lto,
            emit_asm_path,
            emit_bin_path,
            emit_llvm_ir_path,
            emit_llvm_bc_path,
        )) {
            defer llvm.disposeMessage(error_message);

            log.err("LLVM failed to emit asm={s} bin={s} ir={s} bc={s}: {s}", .{
                emit_asm_msg,  emit_bin_msg, emit_llvm_ir_msg, emit_llvm_bc_msg,
                error_message,
            });
            return error.FailedToEmit;
        }
    }

    pub fn updateFunc(
        o: *Object,
        module: *Module,
        func: *Module.Fn,
        air: Air,
        liveness: Liveness,
    ) !void {
        const decl_index = func.owner_decl;
        const decl = module.declPtr(decl_index);

        var dg: DeclGen = .{
            .context = o.context,
            .object = o,
            .module = module,
            .decl_index = decl_index,
            .decl = decl,
            .err_msg = null,
            .gpa = module.gpa,
        };

        const llvm_func = try dg.resolveLlvmFunction(decl_index);

        if (module.align_stack_fns.get(func)) |align_info| {
            dg.addFnAttrInt(llvm_func, "alignstack", align_info.alignment);
            dg.addFnAttr(llvm_func, "noinline");
        } else {
            DeclGen.removeFnAttr(llvm_func, "alignstack");
            if (!func.is_noinline) DeclGen.removeFnAttr(llvm_func, "noinline");
        }

        if (func.is_cold) {
            dg.addFnAttr(llvm_func, "cold");
        } else {
            DeclGen.removeFnAttr(llvm_func, "cold");
        }

        // Remove all the basic blocks of a function in order to start over, generating
        // LLVM IR from an empty function body.
        while (llvm_func.getFirstBasicBlock()) |bb| {
            bb.deleteBasicBlock();
        }

        const builder = dg.context.createBuilder();

        const entry_block = dg.context.appendBasicBlock(llvm_func, "Entry");
        builder.positionBuilderAtEnd(entry_block);

        // This gets the LLVM values from the function and stores them in `dg.args`.
        const fn_info = decl.ty.fnInfo();
        const target = dg.module.getTarget();
        const sret = firstParamSRet(fn_info, target);
        const ret_ptr = if (sret) llvm_func.getParam(0) else null;
        const gpa = dg.gpa;

        var args = std.ArrayList(*const llvm.Value).init(gpa);
        defer args.deinit();

        const param_offset: c_uint = @boolToInt(ret_ptr != null);
        for (fn_info.param_types) |param_ty| {
            if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;

            const llvm_arg_i = @intCast(c_uint, args.items.len) + param_offset;
            try args.append(llvm_func.getParam(llvm_arg_i));
        }

        var di_file: ?*llvm.DIFile = null;
        var di_scope: ?*llvm.DIScope = null;

        if (dg.object.di_builder) |dib| {
            di_file = try dg.object.getDIFile(gpa, decl.src_namespace.file_scope);

            const line_number = decl.src_line + 1;
            const is_internal_linkage = decl.val.tag() != .extern_fn and
                !dg.module.decl_exports.contains(decl_index);
            const noret_bit: c_uint = if (fn_info.return_type.isNoReturn())
                llvm.DIFlags.NoReturn
            else
                0;
            const subprogram = dib.createFunction(
                di_file.?.toScope(),
                decl.name,
                llvm_func.getValueName(),
                di_file.?,
                line_number,
                try o.lowerDebugType(decl.ty, .full),
                is_internal_linkage,
                true, // is definition
                line_number + func.lbrace_line, // scope line
                llvm.DIFlags.StaticMember | noret_bit,
                dg.module.comp.bin_file.options.optimize_mode != .Debug,
                null, // decl_subprogram
            );
            try dg.object.di_map.put(gpa, decl, subprogram.toNode());

            llvm_func.fnSetSubprogram(subprogram);

            const lexical_block = dib.createLexicalBlock(subprogram.toScope(), di_file.?, line_number, 1);
            di_scope = lexical_block.toScope();
        }

        var fg: FuncGen = .{
            .gpa = gpa,
            .air = air,
            .liveness = liveness,
            .context = dg.context,
            .dg = &dg,
            .builder = builder,
            .ret_ptr = ret_ptr,
            .args = args.items,
            .arg_index = 0,
            .func_inst_table = .{},
            .llvm_func = llvm_func,
            .blocks = .{},
            .single_threaded = module.comp.bin_file.options.single_threaded,
            .di_scope = di_scope,
            .di_file = di_file,
            .base_line = dg.decl.src_line,
            .prev_dbg_line = 0,
            .prev_dbg_column = 0,
        };
        defer fg.deinit();

        fg.genBody(air.getMainBody()) catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl_index, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };

        const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
        try o.updateDeclExports(module, decl_index, decl_exports);
    }

    pub fn updateDecl(self: *Object, module: *Module, decl_index: Module.Decl.Index) !void {
        const decl = module.declPtr(decl_index);
        var dg: DeclGen = .{
            .context = self.context,
            .object = self,
            .module = module,
            .decl = decl,
            .decl_index = decl_index,
            .err_msg = null,
            .gpa = module.gpa,
        };
        dg.genDecl() catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl_index, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };
        const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
        try self.updateDeclExports(module, decl_index, decl_exports);
    }

    pub fn updateDeclExports(
        self: *Object,
        module: *Module,
        decl_index: Module.Decl.Index,
        exports: []const *Module.Export,
    ) !void {
        // If the module does not already have the function, we ignore this function call
        // because we call `updateDeclExports` at the end of `updateFunc` and `updateDecl`.
        const llvm_global = self.decl_map.get(decl_index) orelse return;
        const decl = module.declPtr(decl_index);
        if (decl.isExtern()) {
            llvm_global.setValueName(decl.name);
            llvm_global.setUnnamedAddr(.False);
            llvm_global.setLinkage(.External);
            if (self.di_map.get(decl)) |di_node| {
                if (try decl.isFunction()) {
                    const di_func = @ptrCast(*llvm.DISubprogram, di_node);
                    const linkage_name = llvm.MDString.get(self.context, decl.name, std.mem.len(decl.name));
                    di_func.replaceLinkageName(linkage_name);
                } else {
                    const di_global = @ptrCast(*llvm.DIGlobalVariable, di_node);
                    const linkage_name = llvm.MDString.get(self.context, decl.name, std.mem.len(decl.name));
                    di_global.replaceLinkageName(linkage_name);
                }
            }
            if (decl.val.castTag(.variable)) |variable| {
                if (variable.data.is_threadlocal) {
                    llvm_global.setThreadLocalMode(.GeneralDynamicTLSModel);
                } else {
                    llvm_global.setThreadLocalMode(.NotThreadLocal);
                }
                if (variable.data.is_weak_linkage) {
                    llvm_global.setLinkage(.ExternalWeak);
                }
            }
        } else if (exports.len != 0) {
            const exp_name = exports[0].options.name;
            llvm_global.setValueName2(exp_name.ptr, exp_name.len);
            llvm_global.setUnnamedAddr(.False);
            if (self.di_map.get(decl)) |di_node| {
                if (try decl.isFunction()) {
                    const di_func = @ptrCast(*llvm.DISubprogram, di_node);
                    const linkage_name = llvm.MDString.get(self.context, exp_name.ptr, exp_name.len);
                    di_func.replaceLinkageName(linkage_name);
                } else {
                    const di_global = @ptrCast(*llvm.DIGlobalVariable, di_node);
                    const linkage_name = llvm.MDString.get(self.context, exp_name.ptr, exp_name.len);
                    di_global.replaceLinkageName(linkage_name);
                }
            }
            switch (exports[0].options.linkage) {
                .Internal => unreachable,
                .Strong => llvm_global.setLinkage(.External),
                .Weak => llvm_global.setLinkage(.WeakODR),
                .LinkOnce => llvm_global.setLinkage(.LinkOnceODR),
            }
            if (decl.val.castTag(.variable)) |variable| {
                if (variable.data.is_threadlocal) {
                    llvm_global.setThreadLocalMode(.GeneralDynamicTLSModel);
                }
            }
            // If a Decl is exported more than one time (which is rare),
            // we add aliases for all but the first export.
            // TODO LLVM C API does not support deleting aliases. We need to
            // patch it to support this or figure out how to wrap the C++ API ourselves.
            // Until then we iterate over existing aliases and make them point
            // to the correct decl, or otherwise add a new alias. Old aliases are leaked.
            for (exports[1..]) |exp| {
                const exp_name_z = try module.gpa.dupeZ(u8, exp.options.name);
                defer module.gpa.free(exp_name_z);

                if (self.llvm_module.getNamedGlobalAlias(exp_name_z.ptr, exp_name_z.len)) |alias| {
                    alias.setAliasee(llvm_global);
                } else {
                    _ = self.llvm_module.addAlias(
                        llvm_global.typeOf(),
                        llvm_global,
                        exp_name_z,
                    );
                }
            }
        } else {
            const fqn = try decl.getFullyQualifiedName(module);
            defer module.gpa.free(fqn);
            llvm_global.setValueName2(fqn.ptr, fqn.len);
            llvm_global.setLinkage(.Internal);
            llvm_global.setUnnamedAddr(.True);
            if (decl.val.castTag(.variable)) |variable| {
                const single_threaded = module.comp.bin_file.options.single_threaded;
                if (variable.data.is_threadlocal and !single_threaded) {
                    llvm_global.setThreadLocalMode(.GeneralDynamicTLSModel);
                } else {
                    llvm_global.setThreadLocalMode(.NotThreadLocal);
                }
            }
        }
    }

    pub fn freeDecl(self: *Object, decl_index: Module.Decl.Index) void {
        const llvm_value = self.decl_map.get(decl_index) orelse return;
        llvm_value.deleteGlobal();
    }

    fn getDIFile(o: *Object, gpa: Allocator, file: *const Module.File) !*llvm.DIFile {
        const gop = try o.di_map.getOrPut(gpa, file);
        errdefer assert(o.di_map.remove(file));
        if (gop.found_existing) {
            return @ptrCast(*llvm.DIFile, gop.value_ptr.*);
        }
        const dir_path = file.pkg.root_src_directory.path orelse ".";
        const sub_file_path_z = try gpa.dupeZ(u8, file.sub_file_path);
        defer gpa.free(sub_file_path_z);
        const dir_path_z = try gpa.dupeZ(u8, dir_path);
        defer gpa.free(dir_path_z);
        const di_file = o.di_builder.?.createFile(sub_file_path_z, dir_path_z);
        gop.value_ptr.* = di_file.toNode();
        return di_file;
    }

    const DebugResolveStatus = enum { fwd, full };

    /// In the implementation of this function, it is required to store a forward decl
    /// into `gop` before making any recursive calls (even directly).
    fn lowerDebugType(
        o: *Object,
        ty: Type,
        resolve: DebugResolveStatus,
    ) Allocator.Error!*llvm.DIType {
        const gpa = o.gpa;
        // Be careful not to reference this `gop` variable after any recursive calls
        // to `lowerDebugType`.
        const gop = try o.di_type_map.getOrPutContext(gpa, ty, .{ .mod = o.module });
        if (gop.found_existing) {
            const annotated = gop.value_ptr.*;
            const di_type = annotated.toDIType();
            if (!annotated.isFwdOnly() or resolve == .fwd) {
                return di_type;
            }
            const entry: Object.DITypeMap.Entry = .{
                .key_ptr = gop.key_ptr,
                .value_ptr = gop.value_ptr,
            };
            return o.lowerDebugTypeImpl(entry, resolve, di_type);
        }
        errdefer assert(o.di_type_map.orderedRemoveContext(ty, .{ .mod = o.module }));
        // The Type memory is ephemeral; since we want to store a longer-lived
        // reference, we need to copy it here.
        gop.key_ptr.* = try ty.copy(o.type_map_arena.allocator());
        const entry: Object.DITypeMap.Entry = .{
            .key_ptr = gop.key_ptr,
            .value_ptr = gop.value_ptr,
        };
        return o.lowerDebugTypeImpl(entry, resolve, null);
    }

    /// This is a helper function used by `lowerDebugType`.
    fn lowerDebugTypeImpl(
        o: *Object,
        gop: Object.DITypeMap.Entry,
        resolve: DebugResolveStatus,
        opt_fwd_decl: ?*llvm.DIType,
    ) Allocator.Error!*llvm.DIType {
        const ty = gop.key_ptr.*;
        const gpa = o.gpa;
        const target = o.target;
        const dib = o.di_builder.?;
        switch (ty.zigTypeTag()) {
            .Void, .NoReturn => {
                const di_type = dib.createBasicType("void", 0, DW.ATE.signed);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Int => {
                const info = ty.intInfo(target);
                assert(info.bits != 0);
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                const dwarf_encoding: c_uint = switch (info.signedness) {
                    .signed => DW.ATE.signed,
                    .unsigned => DW.ATE.unsigned,
                };
                const di_type = dib.createBasicType(name, info.bits, dwarf_encoding);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Enum => {
                const owner_decl_index = ty.getOwnerDecl();
                const owner_decl = o.module.declPtr(owner_decl_index);

                if (!ty.hasRuntimeBitsIgnoreComptime()) {
                    const enum_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(enum_di_ty), .{ .mod = o.module });
                    return enum_di_ty;
                }

                const field_names = ty.enumFields().keys();

                const enumerators = try gpa.alloc(*llvm.DIEnumerator, field_names.len);
                defer gpa.free(enumerators);

                var buf_field_index: Value.Payload.U32 = .{
                    .base = .{ .tag = .enum_field_index },
                    .data = undefined,
                };
                const field_index_val = Value.initPayload(&buf_field_index.base);

                for (field_names) |field_name, i| {
                    const field_name_z = try gpa.dupeZ(u8, field_name);
                    defer gpa.free(field_name_z);

                    buf_field_index.data = @intCast(u32, i);
                    var buf_u64: Value.Payload.U64 = undefined;
                    const field_int_val = field_index_val.enumToInt(ty, &buf_u64);
                    // See https://github.com/ziglang/zig/issues/645
                    const field_int = field_int_val.toSignedInt();
                    enumerators[i] = dib.createEnumerator(field_name_z, field_int);
                }

                const di_file = try o.getDIFile(gpa, owner_decl.src_namespace.file_scope);
                const di_scope = try o.namespaceToDebugScope(owner_decl.src_namespace);

                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                var buffer: Type.Payload.Bits = undefined;
                const int_ty = ty.intTagType(&buffer);

                const enum_di_ty = dib.createEnumerationType(
                    di_scope,
                    name,
                    di_file,
                    owner_decl.src_node + 1,
                    ty.abiSize(target) * 8,
                    ty.abiAlignment(target) * 8,
                    enumerators.ptr,
                    @intCast(c_int, enumerators.len),
                    try o.lowerDebugType(int_ty, .full),
                    "",
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(enum_di_ty), .{ .mod = o.module });
                return enum_di_ty;
            },
            .Float => {
                const bits = ty.floatBits(target);
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                const di_type = dib.createBasicType(name, bits, DW.ATE.float);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Bool => {
                const di_type = dib.createBasicType("bool", 1, DW.ATE.boolean);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_type);
                return di_type;
            },
            .Pointer => {
                // Normalize everything that the debug info does not represent.
                const ptr_info = ty.ptrInfo().data;

                if (ptr_info.sentinel != null or
                    ptr_info.@"addrspace" != .generic or
                    ptr_info.bit_offset != 0 or
                    ptr_info.host_size != 0 or
                    ptr_info.@"allowzero" or
                    !ptr_info.mutable or
                    ptr_info.@"volatile" or
                    ptr_info.size == .Many or ptr_info.size == .C or
                    !ptr_info.pointee_type.hasRuntimeBitsIgnoreComptime())
                {
                    var payload: Type.Payload.Pointer = .{
                        .data = .{
                            .pointee_type = ptr_info.pointee_type,
                            .sentinel = null,
                            .@"align" = ptr_info.@"align",
                            .@"addrspace" = .generic,
                            .bit_offset = 0,
                            .host_size = 0,
                            .@"allowzero" = false,
                            .mutable = true,
                            .@"volatile" = false,
                            .size = switch (ptr_info.size) {
                                .Many, .C, .One => .One,
                                .Slice => .Slice,
                            },
                        },
                    };
                    if (!ptr_info.pointee_type.hasRuntimeBitsIgnoreComptime()) {
                        payload.data.pointee_type = Type.anyopaque;
                    }
                    const bland_ptr_ty = Type.initPayload(&payload.base);
                    const ptr_di_ty = try o.lowerDebugType(bland_ptr_ty, resolve);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.init(ptr_di_ty, resolve), .{ .mod = o.module });
                    return ptr_di_ty;
                }

                if (ty.isSlice()) {
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&buf);
                    const len_ty = Type.usize;

                    const name = try ty.nameAlloc(gpa, o.module);
                    defer gpa.free(name);
                    const di_file: ?*llvm.DIFile = null;
                    const line = 0;
                    const compile_unit_scope = o.di_compile_unit.?.toScope();

                    const fwd_decl = opt_fwd_decl orelse blk: {
                        const fwd_decl = dib.createReplaceableCompositeType(
                            DW.TAG.structure_type,
                            name.ptr,
                            compile_unit_scope,
                            di_file,
                            line,
                        );
                        gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                        if (resolve == .fwd) return fwd_decl;
                        break :blk fwd_decl;
                    };

                    const ptr_size = ptr_ty.abiSize(target);
                    const ptr_align = ptr_ty.abiAlignment(target);
                    const len_size = len_ty.abiSize(target);
                    const len_align = len_ty.abiAlignment(target);

                    var offset: u64 = 0;
                    offset += ptr_size;
                    offset = std.mem.alignForwardGeneric(u64, offset, len_align);
                    const len_offset = offset;

                    const fields: [2]*llvm.DIType = .{
                        dib.createMemberType(
                            fwd_decl.toScope(),
                            "ptr",
                            di_file,
                            line,
                            ptr_size * 8, // size in bits
                            ptr_align * 8, // align in bits
                            0, // offset in bits
                            0, // flags
                            try o.lowerDebugType(ptr_ty, .full),
                        ),
                        dib.createMemberType(
                            fwd_decl.toScope(),
                            "len",
                            di_file,
                            line,
                            len_size * 8, // size in bits
                            len_align * 8, // align in bits
                            len_offset * 8, // offset in bits
                            0, // flags
                            try o.lowerDebugType(len_ty, .full),
                        ),
                    };

                    const full_di_ty = dib.createStructType(
                        compile_unit_scope,
                        name.ptr,
                        di_file,
                        line,
                        ty.abiSize(target) * 8, // size in bits
                        ty.abiAlignment(target) * 8, // align in bits
                        0, // flags
                        null, // derived from
                        &fields,
                        fields.len,
                        0, // run time lang
                        null, // vtable holder
                        "", // unique id
                    );
                    dib.replaceTemporary(fwd_decl, full_di_ty);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                    return full_di_ty;
                }

                const elem_di_ty = try o.lowerDebugType(ptr_info.pointee_type, .fwd);
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                const ptr_di_ty = dib.createPointerType(
                    elem_di_ty,
                    target.cpu.arch.ptrBitWidth(),
                    ty.ptrAlignment(target) * 8,
                    name,
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(ptr_di_ty), .{ .mod = o.module });
                return ptr_di_ty;
            },
            .Opaque => {
                if (ty.tag() == .anyopaque) {
                    const di_ty = dib.createBasicType("anyopaque", 0, DW.ATE.signed);
                    gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                    return di_ty;
                }
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                const owner_decl_index = ty.getOwnerDecl();
                const owner_decl = o.module.declPtr(owner_decl_index);
                const opaque_di_ty = dib.createForwardDeclType(
                    DW.TAG.structure_type,
                    name,
                    try o.namespaceToDebugScope(owner_decl.src_namespace),
                    try o.getDIFile(gpa, owner_decl.src_namespace.file_scope),
                    owner_decl.src_node + 1,
                );
                // The recursive call to `lowerDebugType` va `namespaceToDebugScope`
                // means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(opaque_di_ty), .{ .mod = o.module });
                return opaque_di_ty;
            },
            .Array => {
                const array_di_ty = dib.createArrayType(
                    ty.abiSize(target) * 8,
                    ty.abiAlignment(target) * 8,
                    try o.lowerDebugType(ty.childType(), .full),
                    @intCast(c_int, ty.arrayLen()),
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(array_di_ty), .{ .mod = o.module });
                return array_di_ty;
            },
            .Vector => {
                const vector_di_ty = dib.createVectorType(
                    ty.abiSize(target) * 8,
                    ty.abiAlignment(target) * 8,
                    try o.lowerDebugType(ty.childType(), .full),
                    ty.vectorLen(),
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(vector_di_ty), .{ .mod = o.module });
                return vector_di_ty;
            },
            .Optional => {
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                var buf: Type.Payload.ElemType = undefined;
                const child_ty = ty.optionalChild(&buf);
                if (!child_ty.hasRuntimeBitsIgnoreComptime()) {
                    const di_ty = dib.createBasicType(name, 1, DW.ATE.boolean);
                    gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                    return di_ty;
                }
                if (ty.isPtrLikeOptional()) {
                    const ptr_di_ty = try o.lowerDebugType(child_ty, resolve);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(ptr_di_ty), .{ .mod = o.module });
                    return ptr_di_ty;
                }

                const di_file: ?*llvm.DIFile = null;
                const line = 0;
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        di_file,
                        line,
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                const non_null_ty = Type.bool;
                const payload_size = child_ty.abiSize(target);
                const payload_align = child_ty.abiAlignment(target);
                const non_null_size = non_null_ty.abiSize(target);
                const non_null_align = non_null_ty.abiAlignment(target);

                var offset: u64 = 0;
                offset += payload_size;
                offset = std.mem.alignForwardGeneric(u64, offset, non_null_align);
                const non_null_offset = offset;

                const fields: [2]*llvm.DIType = .{
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "data",
                        di_file,
                        line,
                        payload_size * 8, // size in bits
                        payload_align * 8, // align in bits
                        0, // offset in bits
                        0, // flags
                        try o.lowerDebugType(child_ty, .full),
                    ),
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "some",
                        di_file,
                        line,
                        non_null_size * 8, // size in bits
                        non_null_align * 8, // align in bits
                        non_null_offset * 8, // offset in bits
                        0, // flags
                        try o.lowerDebugType(non_null_ty, .full),
                    ),
                };

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    di_file,
                    line,
                    ty.abiSize(target) * 8, // size in bits
                    ty.abiAlignment(target) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &fields,
                    fields.len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                return full_di_ty;
            },
            .ErrorUnion => {
                const err_set_ty = ty.errorUnionSet();
                const payload_ty = ty.errorUnionPayload();
                if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                    const err_set_di_ty = try o.lowerDebugType(err_set_ty, .full);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(err_set_di_ty), .{ .mod = o.module });
                    return err_set_di_ty;
                }
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);
                const di_file: ?*llvm.DIFile = null;
                const line = 0;
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        di_file,
                        line,
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                const err_set_size = err_set_ty.abiSize(target);
                const err_set_align = err_set_ty.abiAlignment(target);
                const payload_size = payload_ty.abiSize(target);
                const payload_align = payload_ty.abiAlignment(target);

                var offset: u64 = 0;
                offset += err_set_size;
                offset = std.mem.alignForwardGeneric(u64, offset, payload_align);
                const payload_offset = offset;

                var len: u8 = 2;
                var fields: [3]*llvm.DIType = .{
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "tag",
                        di_file,
                        line,
                        err_set_size * 8, // size in bits
                        err_set_align * 8, // align in bits
                        0, // offset in bits
                        0, // flags
                        try o.lowerDebugType(err_set_ty, .full),
                    ),
                    dib.createMemberType(
                        fwd_decl.toScope(),
                        "value",
                        di_file,
                        line,
                        payload_size * 8, // size in bits
                        payload_align * 8, // align in bits
                        payload_offset * 8, // offset in bits
                        0, // flags
                        try o.lowerDebugType(payload_ty, .full),
                    ),
                    undefined,
                };

                const error_size = Type.anyerror.abiSize(target);
                if (payload_align > error_size) {
                    fields[2] = fields[1];
                    const pad_len = @intCast(u32, payload_align - error_size);
                    fields[1] = dib.createArrayType(
                        pad_len * 8,
                        8,
                        try o.lowerDebugType(Type.u8, .full),
                        @intCast(c_int, pad_len),
                    );
                    len += 1;
                }

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    di_file,
                    line,
                    ty.abiSize(target) * 8, // size in bits
                    ty.abiAlignment(target) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &fields,
                    len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                return full_di_ty;
            },
            .ErrorSet => {
                // TODO make this a proper enum with all the error codes in it.
                // will need to consider how to take incremental compilation into account.
                const di_ty = dib.createBasicType("anyerror", 16, DW.ATE.unsigned);
                gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                return di_ty;
            },
            .Struct => {
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);

                if (ty.castTag(.@"struct")) |payload| {
                    const struct_obj = payload.data;
                    if (struct_obj.layout == .Packed) {
                        var buf: Type.Payload.Bits = undefined;
                        const info = struct_obj.packedIntegerType(target, &buf).intInfo(target);
                        const dwarf_encoding: c_uint = switch (info.signedness) {
                            .signed => DW.ATE.signed,
                            .unsigned => DW.ATE.unsigned,
                        };
                        const di_ty = dib.createBasicType(name, info.bits, dwarf_encoding);
                        gop.value_ptr.* = AnnotatedDITypePtr.initFull(di_ty);
                        return di_ty;
                    }
                }

                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        compile_unit_scope,
                        null, // file
                        0, // line
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                if (ty.isTupleOrAnonStruct()) {
                    const tuple = ty.tupleFields();

                    var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                    defer di_fields.deinit(gpa);

                    try di_fields.ensureUnusedCapacity(gpa, tuple.types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;

                    for (tuple.types) |field_ty, i| {
                        const field_val = tuple.values[i];
                        if (field_val.tag() != .unreachable_value) continue;

                        const field_size = field_ty.abiSize(target);
                        const field_align = field_ty.abiAlignment(target);
                        const field_offset = std.mem.alignForwardGeneric(u64, offset, field_align);
                        offset = field_offset + field_size;

                        const field_name = if (ty.castTag(.anon_struct)) |payload|
                            try gpa.dupeZ(u8, payload.data.names[i])
                        else
                            try std.fmt.allocPrintZ(gpa, "{d}", .{i});
                        defer gpa.free(field_name);

                        try di_fields.append(gpa, dib.createMemberType(
                            fwd_decl.toScope(),
                            field_name,
                            null, // file
                            0, // line
                            field_size * 8, // size in bits
                            field_align * 8, // align in bits
                            field_offset * 8, // offset in bits
                            0, // flags
                            try o.lowerDebugType(field_ty, .full),
                        ));
                    }

                    const full_di_ty = dib.createStructType(
                        compile_unit_scope,
                        name.ptr,
                        null, // file
                        0, // line
                        ty.abiSize(target) * 8, // size in bits
                        ty.abiAlignment(target) * 8, // align in bits
                        0, // flags
                        null, // derived from
                        di_fields.items.ptr,
                        @intCast(c_int, di_fields.items.len),
                        0, // run time lang
                        null, // vtable holder
                        "", // unique id
                    );
                    dib.replaceTemporary(fwd_decl, full_di_ty);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                    return full_di_ty;
                }

                if (ty.castTag(.@"struct")) |payload| {
                    const struct_obj = payload.data;
                    if (!struct_obj.haveFieldTypes()) {
                        // This can happen if a struct type makes it all the way to
                        // flush() without ever being instantiated or referenced (even
                        // via pointer). The only reason we are hearing about it now is
                        // that it is being used as a namespace to put other debug types
                        // into. Therefore we can satisfy this by making an empty namespace,
                        // rather than changing the frontend to unnecessarily resolve the
                        // struct field types.
                        const owner_decl_index = ty.getOwnerDecl();
                        const struct_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                        dib.replaceTemporary(fwd_decl, struct_di_ty);
                        // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                        // means we can't use `gop` anymore.
                        try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(struct_di_ty), .{ .mod = o.module });
                        return struct_di_ty;
                    }
                }

                if (!ty.hasRuntimeBitsIgnoreComptime()) {
                    const owner_decl_index = ty.getOwnerDecl();
                    const struct_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    dib.replaceTemporary(fwd_decl, struct_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(struct_di_ty), .{ .mod = o.module });
                    return struct_di_ty;
                }

                const fields = ty.structFields();

                var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                defer di_fields.deinit(gpa);

                try di_fields.ensureUnusedCapacity(gpa, fields.count());

                comptime assert(struct_layout_version == 2);
                var offset: u64 = 0;

                for (fields.values()) |field, i| {
                    if (field.is_comptime or !field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                    const field_size = field.ty.abiSize(target);
                    const field_align = field.normalAlignment(target);
                    const field_offset = std.mem.alignForwardGeneric(u64, offset, field_align);
                    offset = field_offset + field_size;

                    const field_name = try gpa.dupeZ(u8, fields.keys()[i]);
                    defer gpa.free(field_name);

                    try di_fields.append(gpa, dib.createMemberType(
                        fwd_decl.toScope(),
                        field_name,
                        null, // file
                        0, // line
                        field_size * 8, // size in bits
                        field_align * 8, // align in bits
                        field_offset * 8, // offset in bits
                        0, // flags
                        try o.lowerDebugType(field.ty, .full),
                    ));
                }

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    null, // file
                    0, // line
                    ty.abiSize(target) * 8, // size in bits
                    ty.abiAlignment(target) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    di_fields.items.ptr,
                    @intCast(c_int, di_fields.items.len),
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                return full_di_ty;
            },
            .Union => {
                const compile_unit_scope = o.di_compile_unit.?.toScope();
                const owner_decl_index = ty.getOwnerDecl();

                const name = try ty.nameAlloc(gpa, o.module);
                defer gpa.free(name);

                const fwd_decl = opt_fwd_decl orelse blk: {
                    const fwd_decl = dib.createReplaceableCompositeType(
                        DW.TAG.structure_type,
                        name.ptr,
                        o.di_compile_unit.?.toScope(),
                        null, // file
                        0, // line
                    );
                    gop.value_ptr.* = AnnotatedDITypePtr.initFwd(fwd_decl);
                    if (resolve == .fwd) return fwd_decl;
                    break :blk fwd_decl;
                };

                if (!ty.hasRuntimeBitsIgnoreComptime()) {
                    const union_di_ty = try o.makeEmptyNamespaceDIType(owner_decl_index);
                    dib.replaceTemporary(fwd_decl, union_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(union_di_ty), .{ .mod = o.module });
                    return union_di_ty;
                }

                const layout = ty.unionGetLayout(target);
                const union_obj = ty.cast(Type.Payload.Union).?.data;

                if (layout.payload_size == 0) {
                    const tag_di_ty = try o.lowerDebugType(union_obj.tag_ty, .full);
                    const di_fields = [_]*llvm.DIType{tag_di_ty};
                    const full_di_ty = dib.createStructType(
                        compile_unit_scope,
                        name.ptr,
                        null, // file
                        0, // line
                        ty.abiSize(target) * 8, // size in bits
                        ty.abiAlignment(target) * 8, // align in bits
                        0, // flags
                        null, // derived from
                        &di_fields,
                        di_fields.len,
                        0, // run time lang
                        null, // vtable holder
                        "", // unique id
                    );
                    dib.replaceTemporary(fwd_decl, full_di_ty);
                    // The recursive call to `lowerDebugType` via `makeEmptyNamespaceDIType`
                    // means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                    return full_di_ty;
                }

                var di_fields: std.ArrayListUnmanaged(*llvm.DIType) = .{};
                defer di_fields.deinit(gpa);

                try di_fields.ensureUnusedCapacity(gpa, union_obj.fields.count());

                var it = union_obj.fields.iterator();
                while (it.next()) |kv| {
                    const field_name = kv.key_ptr.*;
                    const field = kv.value_ptr.*;

                    if (!field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                    const field_size = field.ty.abiSize(target);
                    const field_align = field.normalAlignment(target);

                    const field_name_copy = try gpa.dupeZ(u8, field_name);
                    defer gpa.free(field_name_copy);

                    di_fields.appendAssumeCapacity(dib.createMemberType(
                        fwd_decl.toScope(),
                        field_name_copy,
                        null, // file
                        0, // line
                        field_size * 8, // size in bits
                        field_align * 8, // align in bits
                        0, // offset in bits
                        0, // flags
                        try o.lowerDebugType(field.ty, .full),
                    ));
                }

                const union_name = if (layout.tag_size == 0) "AnonUnion" else name.ptr;

                const union_di_ty = dib.createUnionType(
                    compile_unit_scope,
                    union_name,
                    null, // file
                    0, // line
                    ty.abiSize(target) * 8, // size in bits
                    ty.abiAlignment(target) * 8, // align in bits
                    0, // flags
                    di_fields.items.ptr,
                    @intCast(c_int, di_fields.items.len),
                    0, // run time lang
                    "", // unique id
                );

                if (layout.tag_size == 0) {
                    dib.replaceTemporary(fwd_decl, union_di_ty);
                    // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                    try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(union_di_ty), .{ .mod = o.module });
                    return union_di_ty;
                }

                var tag_offset: u64 = undefined;
                var payload_offset: u64 = undefined;
                if (layout.tag_align >= layout.payload_align) {
                    tag_offset = 0;
                    payload_offset = std.mem.alignForwardGeneric(u64, layout.tag_size, layout.payload_align);
                } else {
                    payload_offset = 0;
                    tag_offset = std.mem.alignForwardGeneric(u64, layout.payload_size, layout.tag_align);
                }

                const tag_di = dib.createMemberType(
                    fwd_decl.toScope(),
                    "tag",
                    null, // file
                    0, // line
                    layout.tag_size * 8,
                    layout.tag_align * 8, // align in bits
                    tag_offset * 8, // offset in bits
                    0, // flags
                    try o.lowerDebugType(union_obj.tag_ty, .full),
                );

                const payload_di = dib.createMemberType(
                    fwd_decl.toScope(),
                    "payload",
                    null, // file
                    0, // line
                    layout.payload_size * 8, // size in bits
                    layout.payload_align * 8, // align in bits
                    payload_offset * 8, // offset in bits
                    0, // flags
                    union_di_ty,
                );

                const full_di_fields: [2]*llvm.DIType =
                    if (layout.tag_align >= layout.payload_align)
                .{ tag_di, payload_di } else .{ payload_di, tag_di };

                const full_di_ty = dib.createStructType(
                    compile_unit_scope,
                    name.ptr,
                    null, // file
                    0, // line
                    ty.abiSize(target) * 8, // size in bits
                    ty.abiAlignment(target) * 8, // align in bits
                    0, // flags
                    null, // derived from
                    &full_di_fields,
                    full_di_fields.len,
                    0, // run time lang
                    null, // vtable holder
                    "", // unique id
                );
                dib.replaceTemporary(fwd_decl, full_di_ty);
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(full_di_ty), .{ .mod = o.module });
                return full_di_ty;
            },
            .Fn => {
                const fn_info = ty.fnInfo();

                var param_di_types = std.ArrayList(*llvm.DIType).init(gpa);
                defer param_di_types.deinit();

                // Return type goes first.
                if (fn_info.return_type.hasRuntimeBitsIgnoreComptime()) {
                    const sret = firstParamSRet(fn_info, target);
                    const di_ret_ty = if (sret) Type.void else fn_info.return_type;
                    try param_di_types.append(try o.lowerDebugType(di_ret_ty, .full));

                    if (sret) {
                        var ptr_ty_payload: Type.Payload.ElemType = .{
                            .base = .{ .tag = .single_mut_pointer },
                            .data = fn_info.return_type,
                        };
                        const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
                        try param_di_types.append(try o.lowerDebugType(ptr_ty, .full));
                    }
                } else {
                    try param_di_types.append(try o.lowerDebugType(Type.void, .full));
                }

                for (fn_info.param_types) |param_ty| {
                    if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;

                    if (isByRef(param_ty)) {
                        var ptr_ty_payload: Type.Payload.ElemType = .{
                            .base = .{ .tag = .single_mut_pointer },
                            .data = param_ty,
                        };
                        const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
                        try param_di_types.append(try o.lowerDebugType(ptr_ty, .full));
                    } else {
                        try param_di_types.append(try o.lowerDebugType(param_ty, .full));
                    }
                }

                const fn_di_ty = dib.createSubroutineType(
                    param_di_types.items.ptr,
                    @intCast(c_int, param_di_types.items.len),
                    0,
                );
                // The recursive call to `lowerDebugType` means we can't use `gop` anymore.
                try o.di_type_map.putContext(gpa, ty, AnnotatedDITypePtr.initFull(fn_di_ty), .{ .mod = o.module });
                return fn_di_ty;
            },
            .ComptimeInt => unreachable,
            .ComptimeFloat => unreachable,
            .Type => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .EnumLiteral => unreachable,

            .BoundFn => @panic("TODO remove BoundFn from the language"),

            .Frame => @panic("TODO implement lowerDebugType for Frame types"),
            .AnyFrame => @panic("TODO implement lowerDebugType for AnyFrame types"),
        }
    }

    fn namespaceToDebugScope(o: *Object, namespace: *const Module.Namespace) !*llvm.DIScope {
        if (namespace.parent == null) {
            const di_file = try o.getDIFile(o.gpa, namespace.file_scope);
            return di_file.toScope();
        }
        const di_type = try o.lowerDebugType(namespace.ty, .fwd);
        return di_type.toScope();
    }

    /// This is to be used instead of void for debug info types, to avoid tripping
    /// Assertion `!isa<DIType>(Scope) && "shouldn't make a namespace scope for a type"'
    /// when targeting CodeView (Windows).
    fn makeEmptyNamespaceDIType(o: *Object, decl_index: Module.Decl.Index) !*llvm.DIType {
        const decl = o.module.declPtr(decl_index);
        const fields: [0]*llvm.DIType = .{};
        return o.di_builder.?.createStructType(
            try o.namespaceToDebugScope(decl.src_namespace),
            decl.name, // TODO use fully qualified name
            try o.getDIFile(o.gpa, decl.src_namespace.file_scope),
            decl.src_line + 1,
            0, // size in bits
            0, // align in bits
            0, // flags
            null, // derived from
            undefined, // TODO should be able to pass &fields,
            fields.len,
            0, // run time lang
            null, // vtable holder
            "", // unique id
        );
    }
};

pub const DeclGen = struct {
    context: *const llvm.Context,
    object: *Object,
    module: *Module,
    decl: *Module.Decl,
    decl_index: Module.Decl.Index,
    gpa: Allocator,
    err_msg: ?*Module.ErrorMsg,

    fn todo(self: *DeclGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        assert(self.err_msg == null);
        const src_loc = @as(LazySrcLoc, .{ .node_offset = 0 }).toSrcLoc(self.decl);
        self.err_msg = try Module.ErrorMsg.create(self.gpa, src_loc, "TODO (LLVM): " ++ format, args);
        return error.CodegenFail;
    }

    fn llvmModule(self: *DeclGen) *const llvm.Module {
        return self.object.llvm_module;
    }

    fn genDecl(dg: *DeclGen) !void {
        const decl = dg.decl;
        const decl_index = dg.decl_index;
        assert(decl.has_tv);

        log.debug("gen: {s} type: {}, value: {}", .{
            decl.name, decl.ty.fmtDebug(), decl.val.fmtDebug(),
        });

        if (decl.val.castTag(.function)) |func_payload| {
            _ = func_payload;
            @panic("TODO llvm backend genDecl function pointer");
        } else if (decl.val.castTag(.extern_fn)) |extern_fn| {
            _ = try dg.resolveLlvmFunction(extern_fn.data.owner_decl);
        } else {
            const target = dg.module.getTarget();
            var global = try dg.resolveGlobalDecl(decl_index);
            global.setAlignment(decl.getAlignment(target));
            assert(decl.has_tv);
            const init_val = if (decl.val.castTag(.variable)) |payload| init_val: {
                const variable = payload.data;
                break :init_val variable.init;
            } else init_val: {
                global.setGlobalConstant(.True);
                break :init_val decl.val;
            };
            if (init_val.tag() != .unreachable_value) {
                const llvm_init = try dg.genTypedValue(.{ .ty = decl.ty, .val = init_val });
                if (global.globalGetValueType() == llvm_init.typeOf()) {
                    global.setInitializer(llvm_init);
                } else {
                    // LLVM does not allow us to change the type of globals. So we must
                    // create a new global with the correct type, copy all its attributes,
                    // and then update all references to point to the new global,
                    // delete the original, and rename the new one to the old one's name.
                    // This is necessary because LLVM does not support const bitcasting
                    // a struct with padding bytes, which is needed to lower a const union value
                    // to LLVM, when a field other than the most-aligned is active. Instead,
                    // we must lower to an unnamed struct, and pointer cast at usage sites
                    // of the global. Such an unnamed struct is the cause of the global type
                    // mismatch, because we don't have the LLVM type until the *value* is created,
                    // whereas the global needs to be created based on the type alone, because
                    // lowering the value may reference the global as a pointer.
                    const new_global = dg.object.llvm_module.addGlobalInAddressSpace(
                        llvm_init.typeOf(),
                        "",
                        dg.llvmAddressSpace(decl.@"addrspace"),
                    );
                    new_global.setLinkage(global.getLinkage());
                    new_global.setUnnamedAddr(global.getUnnamedAddress());
                    new_global.setAlignment(global.getAlignment());
                    new_global.setInitializer(llvm_init);
                    // replaceAllUsesWith requires the type to be unchanged. So we bitcast
                    // the new global to the old type and use that as the thing to replace
                    // old uses.
                    const new_global_ptr = new_global.constBitCast(global.typeOf());
                    global.replaceAllUsesWith(new_global_ptr);
                    dg.object.decl_map.putAssumeCapacity(decl_index, new_global);
                    new_global.takeName(global);
                    global.deleteGlobal();
                    global = new_global;
                }
            }

            if (dg.object.di_builder) |dib| {
                const di_file = try dg.object.getDIFile(dg.gpa, decl.src_namespace.file_scope);

                const line_number = decl.src_line + 1;
                const is_internal_linkage = !dg.module.decl_exports.contains(decl_index);
                const di_global = dib.createGlobalVariable(
                    di_file.toScope(),
                    decl.name,
                    global.getValueName(),
                    di_file,
                    line_number,
                    try dg.object.lowerDebugType(decl.ty, .full),
                    is_internal_linkage,
                );

                try dg.object.di_map.put(dg.gpa, dg.decl, di_global.toNode());
            }
        }
    }

    /// If the llvm function does not exist, create it.
    /// Note that this can be called before the function's semantic analysis has
    /// completed, so if any attributes rely on that, they must be done in updateFunc, not here.
    fn resolveLlvmFunction(dg: *DeclGen, decl_index: Module.Decl.Index) !*const llvm.Value {
        const decl = dg.module.declPtr(decl_index);
        const zig_fn_type = decl.ty;
        const gop = try dg.object.decl_map.getOrPut(dg.gpa, decl_index);
        if (gop.found_existing) return gop.value_ptr.*;

        assert(decl.has_tv);
        const fn_info = zig_fn_type.fnInfo();
        const target = dg.module.getTarget();
        const sret = firstParamSRet(fn_info, target);

        const fn_type = try dg.llvmType(zig_fn_type);

        const fqn = try decl.getFullyQualifiedName(dg.module);
        defer dg.gpa.free(fqn);

        const llvm_addrspace = dg.llvmAddressSpace(decl.@"addrspace");
        const llvm_fn = dg.llvmModule().addFunctionInAddressSpace(fqn, fn_type, llvm_addrspace);
        gop.value_ptr.* = llvm_fn;

        const is_extern = decl.isExtern();
        if (!is_extern) {
            llvm_fn.setLinkage(.Internal);
            llvm_fn.setUnnamedAddr(.True);
        } else if (dg.module.getTarget().isWasm()) {
            dg.addFnAttrString(llvm_fn, "wasm-import-name", std.mem.sliceTo(decl.name, 0));
            if (decl.getExternFn().?.lib_name) |lib_name| {
                const module_name = std.mem.sliceTo(lib_name, 0);
                if (!std.mem.eql(u8, module_name, "c")) {
                    dg.addFnAttrString(llvm_fn, "wasm-import-module", module_name);
                }
            }
        }

        if (sret) {
            dg.addArgAttr(llvm_fn, 0, "nonnull"); // Sret pointers must not be address 0
            dg.addArgAttr(llvm_fn, 0, "noalias");

            const raw_llvm_ret_ty = try dg.llvmType(fn_info.return_type);
            llvm_fn.addSretAttr(0, raw_llvm_ret_ty);
        }

        // Set parameter attributes.
        var llvm_param_i: c_uint = @boolToInt(sret);
        for (fn_info.param_types) |param_ty| {
            if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;

            if (isByRef(param_ty)) {
                dg.addArgAttr(llvm_fn, llvm_param_i, "nonnull");
                // TODO readonly, noalias, align
            }
            llvm_param_i += 1;
        }

        // TODO: more attributes. see codegen.cpp `make_fn_llvm_value`.
        if (fn_info.cc == .Naked) {
            dg.addFnAttr(llvm_fn, "naked");
        } else {
            llvm_fn.setFunctionCallConv(toLlvmCallConv(fn_info.cc, target));
        }

        if (fn_info.alignment != 0) {
            llvm_fn.setAlignment(fn_info.alignment);
        }

        // Function attributes that are independent of analysis results of the function body.
        dg.addCommonFnAttributes(llvm_fn);

        if (fn_info.return_type.isNoReturn()) {
            dg.addFnAttr(llvm_fn, "noreturn");
        }

        return llvm_fn;
    }

    fn addCommonFnAttributes(dg: *DeclGen, llvm_fn: *const llvm.Value) void {
        if (!dg.module.comp.bin_file.options.red_zone) {
            dg.addFnAttr(llvm_fn, "noredzone");
        }
        if (dg.module.comp.bin_file.options.omit_frame_pointer) {
            dg.addFnAttrString(llvm_fn, "frame-pointer", "none");
        } else {
            dg.addFnAttrString(llvm_fn, "frame-pointer", "all");
        }
        dg.addFnAttr(llvm_fn, "nounwind");
        if (dg.module.comp.unwind_tables) {
            dg.addFnAttr(llvm_fn, "uwtable");
        }
        if (dg.module.comp.bin_file.options.skip_linker_dependencies) {
            // The intent here is for compiler-rt and libc functions to not generate
            // infinite recursion. For example, if we are compiling the memcpy function,
            // and llvm detects that the body is equivalent to memcpy, it may replace the
            // body of memcpy with a call to memcpy, which would then cause a stack
            // overflow instead of performing memcpy.
            dg.addFnAttr(llvm_fn, "nobuiltin");
        }
        if (dg.module.comp.bin_file.options.optimize_mode == .ReleaseSmall) {
            dg.addFnAttr(llvm_fn, "minsize");
            dg.addFnAttr(llvm_fn, "optsize");
        }
        if (dg.module.comp.bin_file.options.tsan) {
            dg.addFnAttr(llvm_fn, "sanitize_thread");
        }
        // TODO add target-cpu and target-features fn attributes
    }

    fn resolveGlobalDecl(dg: *DeclGen, decl_index: Module.Decl.Index) Error!*const llvm.Value {
        const gop = try dg.object.decl_map.getOrPut(dg.gpa, decl_index);
        if (gop.found_existing) return gop.value_ptr.*;
        errdefer assert(dg.object.decl_map.remove(decl_index));

        const decl = dg.module.declPtr(decl_index);
        const fqn = try decl.getFullyQualifiedName(dg.module);
        defer dg.gpa.free(fqn);

        const llvm_type = try dg.llvmType(decl.ty);
        const llvm_addrspace = dg.llvmAddressSpace(decl.@"addrspace");
        const llvm_global = dg.object.llvm_module.addGlobalInAddressSpace(llvm_type, fqn, llvm_addrspace);
        gop.value_ptr.* = llvm_global;

        // This is needed for declarations created by `@extern`.
        if (decl.isExtern()) {
            llvm_global.setValueName(decl.name);
            llvm_global.setUnnamedAddr(.False);
            llvm_global.setLinkage(.External);
            if (decl.val.castTag(.variable)) |variable| {
                const single_threaded = dg.module.comp.bin_file.options.single_threaded;
                if (variable.data.is_threadlocal and !single_threaded) {
                    llvm_global.setThreadLocalMode(.GeneralDynamicTLSModel);
                } else {
                    llvm_global.setThreadLocalMode(.NotThreadLocal);
                }
                if (variable.data.is_weak_linkage) llvm_global.setLinkage(.ExternalWeak);
            }
        } else {
            llvm_global.setLinkage(.Internal);
            llvm_global.setUnnamedAddr(.True);
        }

        return llvm_global;
    }

    fn llvmAddressSpace(self: DeclGen, address_space: std.builtin.AddressSpace) c_uint {
        const target = self.module.getTarget();
        return switch (target.cpu.arch) {
            .i386, .x86_64 => switch (address_space) {
                .generic => llvm.address_space.default,
                .gs => llvm.address_space.x86.gs,
                .fs => llvm.address_space.x86.fs,
                .ss => llvm.address_space.x86.ss,
                else => unreachable,
            },
            .nvptx, .nvptx64 => switch (address_space) {
                .generic => llvm.address_space.default,
                .global => llvm.address_space.nvptx.global,
                .constant => llvm.address_space.nvptx.constant,
                .param => llvm.address_space.nvptx.param,
                .shared => llvm.address_space.nvptx.shared,
                .local => llvm.address_space.nvptx.local,
                else => unreachable,
            },
            else => switch (address_space) {
                .generic => llvm.address_space.default,
                else => unreachable,
            },
        };
    }

    fn isUnnamedType(dg: *DeclGen, ty: Type, val: *const llvm.Value) bool {
        // Once `llvmType` succeeds, successive calls to it with the same Zig type
        // are guaranteed to succeed. So if a call to `llvmType` fails here it means
        // it is the first time lowering the type, which means the value can't possible
        // have that type.
        const llvm_ty = dg.llvmType(ty) catch return true;
        return val.typeOf() != llvm_ty;
    }

    fn llvmType(dg: *DeclGen, t: Type) Allocator.Error!*const llvm.Type {
        const gpa = dg.gpa;
        const target = dg.module.getTarget();
        switch (t.zigTypeTag()) {
            .Void, .NoReturn => return dg.context.voidType(),
            .Int => {
                const info = t.intInfo(target);
                assert(info.bits != 0);
                return dg.context.intType(info.bits);
            },
            .Enum => {
                var buffer: Type.Payload.Bits = undefined;
                const int_ty = t.intTagType(&buffer);
                const bit_count = int_ty.intInfo(target).bits;
                assert(bit_count != 0);
                return dg.context.intType(bit_count);
            },
            .Float => switch (t.floatBits(target)) {
                16 => return dg.context.halfType(),
                32 => return dg.context.floatType(),
                64 => return dg.context.doubleType(),
                80 => return if (backendSupportsF80(target)) dg.context.x86FP80Type() else dg.context.intType(80),
                128 => return dg.context.fp128Type(),
                else => unreachable,
            },
            .Bool => return dg.context.intType(1),
            .Pointer => {
                if (t.isSlice()) {
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_type = t.slicePtrFieldType(&buf);

                    const fields: [2]*const llvm.Type = .{
                        try dg.llvmType(ptr_type),
                        try dg.llvmType(Type.usize),
                    };
                    return dg.context.structType(&fields, fields.len, .False);
                }
                const ptr_info = t.ptrInfo().data;
                const llvm_addrspace = dg.llvmAddressSpace(ptr_info.@"addrspace");
                if (ptr_info.host_size != 0) {
                    return dg.context.intType(ptr_info.host_size * 8).pointerType(llvm_addrspace);
                }
                const elem_ty = ptr_info.pointee_type;
                const lower_elem_ty = switch (elem_ty.zigTypeTag()) {
                    .Opaque, .Fn => true,
                    .Array => elem_ty.childType().hasRuntimeBitsIgnoreComptime(),
                    else => elem_ty.hasRuntimeBitsIgnoreComptime(),
                };
                const llvm_elem_ty = if (lower_elem_ty)
                    try dg.llvmType(elem_ty)
                else
                    dg.context.intType(8);
                return llvm_elem_ty.pointerType(llvm_addrspace);
            },
            .Opaque => switch (t.tag()) {
                .@"opaque" => {
                    const gop = try dg.object.type_map.getOrPutContext(gpa, t, .{ .mod = dg.module });
                    if (gop.found_existing) return gop.value_ptr.*;

                    // The Type memory is ephemeral; since we want to store a longer-lived
                    // reference, we need to copy it here.
                    gop.key_ptr.* = try t.copy(dg.object.type_map_arena.allocator());

                    const opaque_obj = t.castTag(.@"opaque").?.data;
                    const name = try opaque_obj.getFullyQualifiedName(dg.module);
                    defer gpa.free(name);

                    const llvm_struct_ty = dg.context.structCreateNamed(name);
                    gop.value_ptr.* = llvm_struct_ty; // must be done before any recursive calls
                    return llvm_struct_ty;
                },
                .anyopaque => return dg.context.intType(8),
                else => unreachable,
            },
            .Array => {
                const elem_ty = t.childType();
                assert(elem_ty.onePossibleValue() == null);
                const elem_llvm_ty = try dg.llvmType(elem_ty);
                const total_len = t.arrayLen() + @boolToInt(t.sentinel() != null);
                return elem_llvm_ty.arrayType(@intCast(c_uint, total_len));
            },
            .Vector => {
                const elem_type = try dg.llvmType(t.childType());
                return elem_type.vectorType(t.vectorLen());
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const child_ty = t.optionalChild(&buf);
                if (!child_ty.hasRuntimeBitsIgnoreComptime()) {
                    return dg.context.intType(1);
                }
                const payload_llvm_ty = try dg.llvmType(child_ty);
                if (t.isPtrLikeOptional()) {
                    return payload_llvm_ty;
                }

                const fields: [2]*const llvm.Type = .{
                    payload_llvm_ty, dg.context.intType(1),
                };
                return dg.context.structType(&fields, fields.len, .False);
            },
            .ErrorUnion => {
                const error_type = t.errorUnionSet();
                const payload_type = t.errorUnionPayload();
                const llvm_error_type = try dg.llvmType(error_type);
                if (!payload_type.hasRuntimeBitsIgnoreComptime()) {
                    return llvm_error_type;
                }
                const llvm_payload_type = try dg.llvmType(payload_type);

                const payload_align = payload_type.abiAlignment(target);
                const error_size = error_type.abiSize(target);
                if (payload_align > error_size) {
                    const pad_type = dg.context.intType(8).arrayType(@intCast(u32, payload_align - error_size));
                    const fields: [3]*const llvm.Type = .{ llvm_error_type, pad_type, llvm_payload_type };
                    return dg.context.structType(&fields, fields.len, .False);
                } else {
                    const fields: [2]*const llvm.Type = .{ llvm_error_type, llvm_payload_type };
                    return dg.context.structType(&fields, fields.len, .False);
                }
            },
            .ErrorSet => {
                return dg.context.intType(16);
            },
            .Struct => {
                const gop = try dg.object.type_map.getOrPutContext(gpa, t, .{ .mod = dg.module });
                if (gop.found_existing) return gop.value_ptr.*;

                // The Type memory is ephemeral; since we want to store a longer-lived
                // reference, we need to copy it here.
                gop.key_ptr.* = try t.copy(dg.object.type_map_arena.allocator());

                if (t.isTupleOrAnonStruct()) {
                    const tuple = t.tupleFields();
                    const llvm_struct_ty = dg.context.structCreateNamed("");
                    gop.value_ptr.* = llvm_struct_ty; // must be done before any recursive calls

                    var llvm_field_types: std.ArrayListUnmanaged(*const llvm.Type) = .{};
                    defer llvm_field_types.deinit(gpa);

                    try llvm_field_types.ensureUnusedCapacity(gpa, tuple.types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: u32 = 0;

                    for (tuple.types) |field_ty, i| {
                        const field_val = tuple.values[i];
                        if (field_val.tag() != .unreachable_value) continue;

                        const field_align = field_ty.abiAlignment(target);
                        big_align = @maximum(big_align, field_align);
                        const prev_offset = offset;
                        offset = std.mem.alignForwardGeneric(u64, offset, field_align);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                            try llvm_field_types.append(gpa, llvm_array_ty);
                        }
                        const field_llvm_ty = try dg.llvmType(field_ty);
                        try llvm_field_types.append(gpa, field_llvm_ty);

                        offset += field_ty.abiSize(target);
                    }
                    {
                        const prev_offset = offset;
                        offset = std.mem.alignForwardGeneric(u64, offset, big_align);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                            try llvm_field_types.append(gpa, llvm_array_ty);
                        }
                    }

                    llvm_struct_ty.structSetBody(
                        llvm_field_types.items.ptr,
                        @intCast(c_uint, llvm_field_types.items.len),
                        .False,
                    );

                    return llvm_struct_ty;
                }

                const struct_obj = t.castTag(.@"struct").?.data;

                if (struct_obj.layout == .Packed) {
                    var buf: Type.Payload.Bits = undefined;
                    const int_ty = struct_obj.packedIntegerType(target, &buf);
                    const int_llvm_ty = try dg.llvmType(int_ty);
                    gop.value_ptr.* = int_llvm_ty;
                    return int_llvm_ty;
                }

                const name = try struct_obj.getFullyQualifiedName(dg.module);
                defer gpa.free(name);

                const llvm_struct_ty = dg.context.structCreateNamed(name);
                gop.value_ptr.* = llvm_struct_ty; // must be done before any recursive calls

                assert(struct_obj.haveFieldTypes());

                var llvm_field_types: std.ArrayListUnmanaged(*const llvm.Type) = .{};
                defer llvm_field_types.deinit(gpa);

                try llvm_field_types.ensureUnusedCapacity(gpa, struct_obj.fields.count());

                comptime assert(struct_layout_version == 2);
                var offset: u64 = 0;
                var big_align: u32 = 0;

                for (struct_obj.fields.values()) |field| {
                    if (field.is_comptime or !field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                    const field_align = field.normalAlignment(target);
                    big_align = @maximum(big_align, field_align);
                    const prev_offset = offset;
                    offset = std.mem.alignForwardGeneric(u64, offset, field_align);

                    const padding_len = offset - prev_offset;
                    if (padding_len > 0) {
                        const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                        try llvm_field_types.append(gpa, llvm_array_ty);
                    }
                    const field_llvm_ty = try dg.llvmType(field.ty);
                    try llvm_field_types.append(gpa, field_llvm_ty);

                    offset += field.ty.abiSize(target);
                }
                {
                    const prev_offset = offset;
                    offset = std.mem.alignForwardGeneric(u64, offset, big_align);
                    const padding_len = offset - prev_offset;
                    if (padding_len > 0) {
                        const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                        try llvm_field_types.append(gpa, llvm_array_ty);
                    }
                }

                llvm_struct_ty.structSetBody(
                    llvm_field_types.items.ptr,
                    @intCast(c_uint, llvm_field_types.items.len),
                    .False,
                );

                return llvm_struct_ty;
            },
            .Union => {
                const gop = try dg.object.type_map.getOrPutContext(gpa, t, .{ .mod = dg.module });
                if (gop.found_existing) return gop.value_ptr.*;

                // The Type memory is ephemeral; since we want to store a longer-lived
                // reference, we need to copy it here.
                gop.key_ptr.* = try t.copy(dg.object.type_map_arena.allocator());

                const layout = t.unionGetLayout(target);
                const union_obj = t.cast(Type.Payload.Union).?.data;

                if (layout.payload_size == 0) {
                    const enum_tag_llvm_ty = try dg.llvmType(union_obj.tag_ty);
                    gop.value_ptr.* = enum_tag_llvm_ty;
                    return enum_tag_llvm_ty;
                }

                const name = try union_obj.getFullyQualifiedName(dg.module);
                defer gpa.free(name);

                const llvm_union_ty = dg.context.structCreateNamed(name);
                gop.value_ptr.* = llvm_union_ty; // must be done before any recursive calls

                const aligned_field = union_obj.fields.values()[layout.most_aligned_field];
                const llvm_aligned_field_ty = try dg.llvmType(aligned_field.ty);

                const llvm_payload_ty = t: {
                    if (layout.most_aligned_field_size == layout.payload_size) {
                        break :t llvm_aligned_field_ty;
                    }
                    const padding_len = @intCast(c_uint, layout.payload_size - layout.most_aligned_field_size);
                    const fields: [2]*const llvm.Type = .{
                        llvm_aligned_field_ty,
                        dg.context.intType(8).arrayType(padding_len),
                    };
                    break :t dg.context.structType(&fields, fields.len, .True);
                };

                if (layout.tag_size == 0) {
                    var llvm_fields: [1]*const llvm.Type = .{llvm_payload_ty};
                    llvm_union_ty.structSetBody(&llvm_fields, llvm_fields.len, .False);
                    return llvm_union_ty;
                }
                const enum_tag_llvm_ty = try dg.llvmType(union_obj.tag_ty);

                // Put the tag before or after the payload depending on which one's
                // alignment is greater.
                var llvm_fields: [3]*const llvm.Type = undefined;
                var llvm_fields_len: c_uint = 2;

                if (layout.tag_align >= layout.payload_align) {
                    llvm_fields = .{ enum_tag_llvm_ty, llvm_payload_ty, undefined };
                } else {
                    llvm_fields = .{ llvm_payload_ty, enum_tag_llvm_ty, undefined };
                }

                // Insert padding to make the LLVM struct ABI size match the Zig union ABI size.
                if (layout.padding != 0) {
                    llvm_fields[2] = dg.context.intType(8).arrayType(layout.padding);
                    llvm_fields_len = 3;
                }

                llvm_union_ty.structSetBody(&llvm_fields, llvm_fields_len, .False);
                return llvm_union_ty;
            },
            .Fn => {
                const fn_info = t.fnInfo();
                const llvm_ret_ty = try lowerFnRetTy(dg, fn_info);

                var llvm_params = std.ArrayList(*const llvm.Type).init(dg.gpa);
                defer llvm_params.deinit();

                if (firstParamSRet(fn_info, target)) {
                    const llvm_sret_ty = try dg.llvmType(fn_info.return_type);
                    try llvm_params.append(llvm_sret_ty.pointerType(0));
                }

                for (fn_info.param_types) |param_ty| {
                    if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;

                    try llvm_params.append(try lowerFnParamTy(dg, fn_info.cc, param_ty));
                }

                return llvm.functionType(
                    llvm_ret_ty,
                    llvm_params.items.ptr,
                    @intCast(c_uint, llvm_params.items.len),
                    llvm.Bool.fromBool(fn_info.is_var_args),
                );
            },
            .ComptimeInt => unreachable,
            .ComptimeFloat => unreachable,
            .Type => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .EnumLiteral => unreachable,

            .BoundFn => @panic("TODO remove BoundFn from the language"),

            .Frame => @panic("TODO implement llvmType for Frame types"),
            .AnyFrame => @panic("TODO implement llvmType for AnyFrame types"),
        }
    }

    fn genTypedValue(dg: *DeclGen, tv: TypedValue) Error!*const llvm.Value {
        if (tv.val.isUndef()) {
            const llvm_type = try dg.llvmType(tv.ty);
            return llvm_type.getUndef();
        }
        const target = dg.module.getTarget();

        switch (tv.ty.zigTypeTag()) {
            .Bool => {
                const llvm_type = try dg.llvmType(tv.ty);
                return if (tv.val.toBool()) llvm_type.constAllOnes() else llvm_type.constNull();
            },
            // TODO this duplicates code with Pointer but they should share the handling
            // of the tv.val.tag() and then Int should do extra constPtrToInt on top
            .Int => switch (tv.val.tag()) {
                .decl_ref_mut => return lowerDeclRefValue(dg, tv, tv.val.castTag(.decl_ref_mut).?.data.decl_index),
                .decl_ref => return lowerDeclRefValue(dg, tv, tv.val.castTag(.decl_ref).?.data),
                else => {
                    var bigint_space: Value.BigIntSpace = undefined;
                    const bigint = tv.val.toBigInt(&bigint_space, target);
                    const int_info = tv.ty.intInfo(target);
                    assert(int_info.bits != 0);
                    const llvm_type = dg.context.intType(int_info.bits);

                    const unsigned_val = v: {
                        if (bigint.limbs.len == 1) {
                            break :v llvm_type.constInt(bigint.limbs[0], .False);
                        }
                        if (@sizeOf(usize) == @sizeOf(u64)) {
                            break :v llvm_type.constIntOfArbitraryPrecision(
                                @intCast(c_uint, bigint.limbs.len),
                                bigint.limbs.ptr,
                            );
                        }
                        @panic("TODO implement bigint to llvm int for 32-bit compiler builds");
                    };
                    if (!bigint.positive) {
                        return llvm.constNeg(unsigned_val);
                    }
                    return unsigned_val;
                },
            },
            .Enum => {
                var int_buffer: Value.Payload.U64 = undefined;
                const int_val = tv.enumToInt(&int_buffer);

                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = int_val.toBigInt(&bigint_space, target);

                const int_info = tv.ty.intInfo(target);
                const llvm_type = dg.context.intType(int_info.bits);

                const unsigned_val = v: {
                    if (bigint.limbs.len == 1) {
                        break :v llvm_type.constInt(bigint.limbs[0], .False);
                    }
                    if (@sizeOf(usize) == @sizeOf(u64)) {
                        break :v llvm_type.constIntOfArbitraryPrecision(
                            @intCast(c_uint, bigint.limbs.len),
                            bigint.limbs.ptr,
                        );
                    }
                    @panic("TODO implement bigint to llvm int for 32-bit compiler builds");
                };
                if (!bigint.positive) {
                    return llvm.constNeg(unsigned_val);
                }
                return unsigned_val;
            },
            .Float => {
                const llvm_ty = try dg.llvmType(tv.ty);
                switch (tv.ty.floatBits(target)) {
                    16, 32, 64 => return llvm_ty.constReal(tv.val.toFloat(f64)),
                    80 => {
                        const float = tv.val.toFloat(f80);
                        const repr = std.math.break_f80(float);
                        const llvm_i80 = dg.context.intType(80);
                        var x = llvm_i80.constInt(repr.exp, .False);
                        x = x.constShl(llvm_i80.constInt(64, .False));
                        x = x.constOr(llvm_i80.constInt(repr.fraction, .False));
                        if (backendSupportsF80(target)) {
                            return x.constBitCast(llvm_ty);
                        } else {
                            return x;
                        }
                    },
                    128 => {
                        var buf: [2]u64 = @bitCast([2]u64, tv.val.toFloat(f128));
                        // LLVM seems to require that the lower half of the f128 be placed first
                        // in the buffer.
                        if (native_endian == .Big) {
                            std.mem.swap(u64, &buf[0], &buf[1]);
                        }
                        const int = dg.context.intType(128).constIntOfArbitraryPrecision(buf.len, &buf);
                        return int.constBitCast(llvm_ty);
                    },
                    else => unreachable,
                }
            },
            .Pointer => switch (tv.val.tag()) {
                .decl_ref_mut => return lowerDeclRefValue(dg, tv, tv.val.castTag(.decl_ref_mut).?.data.decl_index),
                .decl_ref => return lowerDeclRefValue(dg, tv, tv.val.castTag(.decl_ref).?.data),
                .variable => {
                    const decl_index = tv.val.castTag(.variable).?.data.owner_decl;
                    const decl = dg.module.declPtr(decl_index);
                    dg.module.markDeclAlive(decl);
                    const val = try dg.resolveGlobalDecl(decl_index);
                    const llvm_var_type = try dg.llvmType(tv.ty);
                    const llvm_addrspace = dg.llvmAddressSpace(decl.@"addrspace");
                    const llvm_type = llvm_var_type.pointerType(llvm_addrspace);
                    return val.constBitCast(llvm_type);
                },
                .slice => {
                    const slice = tv.val.castTag(.slice).?.data;
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const fields: [2]*const llvm.Value = .{
                        try dg.genTypedValue(.{
                            .ty = tv.ty.slicePtrFieldType(&buf),
                            .val = slice.ptr,
                        }),
                        try dg.genTypedValue(.{
                            .ty = Type.usize,
                            .val = slice.len,
                        }),
                    };
                    return dg.context.constStruct(&fields, fields.len, .False);
                },
                .int_u64, .one, .int_big_positive => {
                    const llvm_usize = try dg.llvmType(Type.usize);
                    const llvm_int = llvm_usize.constInt(tv.val.toUnsignedInt(target), .False);
                    return llvm_int.constIntToPtr(try dg.llvmType(tv.ty));
                },
                .field_ptr, .opt_payload_ptr, .eu_payload_ptr, .elem_ptr => {
                    return dg.lowerParentPtr(tv.val, tv.ty.childType());
                },
                .null_value, .zero => {
                    const llvm_type = try dg.llvmType(tv.ty);
                    return llvm_type.constNull();
                },
                else => |tag| return dg.todo("implement const of pointer type '{}' ({})", .{
                    tv.ty.fmtDebug(), tag,
                }),
            },
            .Array => switch (tv.val.tag()) {
                .bytes => {
                    const bytes = tv.val.castTag(.bytes).?.data;
                    return dg.context.constString(
                        bytes.ptr,
                        @intCast(c_uint, tv.ty.arrayLenIncludingSentinel()),
                        .True, // don't null terminate. bytes has the sentinel, if any.
                    );
                },
                .aggregate => {
                    const elem_vals = tv.val.castTag(.aggregate).?.data;
                    const elem_ty = tv.ty.elemType();
                    const gpa = dg.gpa;
                    const len = @intCast(usize, tv.ty.arrayLenIncludingSentinel());
                    const llvm_elems = try gpa.alloc(*const llvm.Value, len);
                    defer gpa.free(llvm_elems);
                    var need_unnamed = false;
                    for (elem_vals[0..len]) |elem_val, i| {
                        llvm_elems[i] = try dg.genTypedValue(.{ .ty = elem_ty, .val = elem_val });
                        need_unnamed = need_unnamed or dg.isUnnamedType(elem_ty, llvm_elems[i]);
                    }
                    if (need_unnamed) {
                        return dg.context.constStruct(
                            llvm_elems.ptr,
                            @intCast(c_uint, llvm_elems.len),
                            .True,
                        );
                    } else {
                        const llvm_elem_ty = try dg.llvmType(elem_ty);
                        return llvm_elem_ty.constArray(
                            llvm_elems.ptr,
                            @intCast(c_uint, llvm_elems.len),
                        );
                    }
                },
                .repeated => {
                    const val = tv.val.castTag(.repeated).?.data;
                    const elem_ty = tv.ty.elemType();
                    const sentinel = tv.ty.sentinel();
                    const len = @intCast(usize, tv.ty.arrayLen());
                    const len_including_sent = len + @boolToInt(sentinel != null);
                    const gpa = dg.gpa;
                    const llvm_elems = try gpa.alloc(*const llvm.Value, len_including_sent);
                    defer gpa.free(llvm_elems);

                    var need_unnamed = false;
                    if (len != 0) {
                        for (llvm_elems[0..len]) |*elem| {
                            elem.* = try dg.genTypedValue(.{ .ty = elem_ty, .val = val });
                        }
                        need_unnamed = need_unnamed or dg.isUnnamedType(elem_ty, llvm_elems[0]);
                    }

                    if (sentinel) |sent| {
                        llvm_elems[len] = try dg.genTypedValue(.{ .ty = elem_ty, .val = sent });
                        need_unnamed = need_unnamed or dg.isUnnamedType(elem_ty, llvm_elems[len]);
                    }

                    if (need_unnamed) {
                        return dg.context.constStruct(
                            llvm_elems.ptr,
                            @intCast(c_uint, llvm_elems.len),
                            .True,
                        );
                    } else {
                        const llvm_elem_ty = try dg.llvmType(elem_ty);
                        return llvm_elem_ty.constArray(
                            llvm_elems.ptr,
                            @intCast(c_uint, llvm_elems.len),
                        );
                    }
                },
                .empty_array_sentinel => {
                    const elem_ty = tv.ty.elemType();
                    const sent_val = tv.ty.sentinel().?;
                    const sentinel = try dg.genTypedValue(.{ .ty = elem_ty, .val = sent_val });
                    const llvm_elems: [1]*const llvm.Value = .{sentinel};
                    const need_unnamed = dg.isUnnamedType(elem_ty, llvm_elems[0]);
                    if (need_unnamed) {
                        return dg.context.constStruct(&llvm_elems, llvm_elems.len, .True);
                    } else {
                        const llvm_elem_ty = try dg.llvmType(elem_ty);
                        return llvm_elem_ty.constArray(&llvm_elems, llvm_elems.len);
                    }
                },
                else => unreachable,
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const payload_ty = tv.ty.optionalChild(&buf);
                const llvm_i1 = dg.context.intType(1);
                const is_pl = !tv.val.isNull();
                const non_null_bit = if (is_pl) llvm_i1.constAllOnes() else llvm_i1.constNull();
                if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                    return non_null_bit;
                }
                if (tv.ty.isPtrLikeOptional()) {
                    if (tv.val.castTag(.opt_payload)) |payload| {
                        return dg.genTypedValue(.{ .ty = payload_ty, .val = payload.data });
                    } else if (is_pl) {
                        return dg.genTypedValue(.{ .ty = payload_ty, .val = tv.val });
                    } else {
                        const llvm_ty = try dg.llvmType(tv.ty);
                        return llvm_ty.constNull();
                    }
                }
                assert(payload_ty.zigTypeTag() != .Fn);
                const fields: [2]*const llvm.Value = .{
                    try dg.genTypedValue(.{
                        .ty = payload_ty,
                        .val = if (tv.val.castTag(.opt_payload)) |pl| pl.data else Value.initTag(.undef),
                    }),
                    non_null_bit,
                };
                return dg.context.constStruct(&fields, fields.len, .False);
            },
            .Fn => {
                const fn_decl_index = switch (tv.val.tag()) {
                    .extern_fn => tv.val.castTag(.extern_fn).?.data.owner_decl,
                    .function => tv.val.castTag(.function).?.data.owner_decl,
                    else => unreachable,
                };
                const fn_decl = dg.module.declPtr(fn_decl_index);
                dg.module.markDeclAlive(fn_decl);
                return dg.resolveLlvmFunction(fn_decl_index);
            },
            .ErrorSet => {
                const llvm_ty = try dg.llvmType(tv.ty);
                switch (tv.val.tag()) {
                    .@"error" => {
                        const err_name = tv.val.castTag(.@"error").?.data.name;
                        const kv = try dg.module.getErrorValue(err_name);
                        return llvm_ty.constInt(kv.value, .False);
                    },
                    else => {
                        // In this case we are rendering an error union which has a 0 bits payload.
                        return llvm_ty.constNull();
                    },
                }
            },
            .ErrorUnion => {
                const error_type = tv.ty.errorUnionSet();
                const payload_type = tv.ty.errorUnionPayload();
                const is_pl = tv.val.errorUnionIsPayload();

                if (!payload_type.hasRuntimeBitsIgnoreComptime()) {
                    // We use the error type directly as the type.
                    const err_val = if (!is_pl) tv.val else Value.initTag(.zero);
                    return dg.genTypedValue(.{ .ty = error_type, .val = err_val });
                }
                var len: u8 = 2;
                var fields: [3]*const llvm.Value = .{
                    try dg.genTypedValue(.{
                        .ty = error_type,
                        .val = if (is_pl) Value.initTag(.zero) else tv.val,
                    }),
                    try dg.genTypedValue(.{
                        .ty = payload_type,
                        .val = if (tv.val.castTag(.eu_payload)) |pl| pl.data else Value.initTag(.undef),
                    }),
                    undefined,
                };

                const payload_align = payload_type.abiAlignment(target);
                const error_size = error_type.abiSize(target);
                if (payload_align > error_size) {
                    fields[2] = fields[1];
                    const pad_type = dg.context.intType(8).arrayType(@intCast(u32, payload_align - error_size));
                    fields[1] = pad_type.getUndef();
                    len += 1;
                }
                return dg.context.constStruct(&fields, len, .False);
            },
            .Struct => {
                const llvm_struct_ty = try dg.llvmType(tv.ty);
                const field_vals = tv.val.castTag(.aggregate).?.data;
                const gpa = dg.gpa;

                if (tv.ty.isTupleOrAnonStruct()) {
                    const tuple = tv.ty.tupleFields();
                    var llvm_fields: std.ArrayListUnmanaged(*const llvm.Value) = .{};
                    defer llvm_fields.deinit(gpa);

                    try llvm_fields.ensureUnusedCapacity(gpa, tuple.types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: u32 = 0;
                    var need_unnamed = false;

                    for (tuple.types) |field_ty, i| {
                        if (tuple.values[i].tag() != .unreachable_value) continue;
                        if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                        const field_align = field_ty.abiAlignment(target);
                        big_align = @maximum(big_align, field_align);
                        const prev_offset = offset;
                        offset = std.mem.alignForwardGeneric(u64, offset, field_align);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                            // TODO make this and all other padding elsewhere in debug
                            // builds be 0xaa not undef.
                            llvm_fields.appendAssumeCapacity(llvm_array_ty.getUndef());
                        }

                        const field_llvm_val = try dg.genTypedValue(.{
                            .ty = field_ty,
                            .val = field_vals[i],
                        });

                        need_unnamed = need_unnamed or dg.isUnnamedType(field_ty, field_llvm_val);

                        llvm_fields.appendAssumeCapacity(field_llvm_val);

                        offset += field_ty.abiSize(target);
                    }
                    {
                        const prev_offset = offset;
                        offset = std.mem.alignForwardGeneric(u64, offset, big_align);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                            llvm_fields.appendAssumeCapacity(llvm_array_ty.getUndef());
                        }
                    }

                    if (need_unnamed) {
                        return dg.context.constStruct(
                            llvm_fields.items.ptr,
                            @intCast(c_uint, llvm_fields.items.len),
                            .False,
                        );
                    } else {
                        return llvm_struct_ty.constNamedStruct(
                            llvm_fields.items.ptr,
                            @intCast(c_uint, llvm_fields.items.len),
                        );
                    }
                }

                const struct_obj = tv.ty.castTag(.@"struct").?.data;

                if (struct_obj.layout == .Packed) {
                    const big_bits = struct_obj.packedIntegerBits(target);
                    const int_llvm_ty = dg.context.intType(big_bits);
                    const fields = struct_obj.fields.values();
                    comptime assert(Type.packed_struct_layout_version == 2);
                    var running_int: *const llvm.Value = int_llvm_ty.constNull();
                    var running_bits: u16 = 0;
                    for (field_vals) |field_val, i| {
                        const field = fields[i];
                        if (!field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                        const non_int_val = try dg.genTypedValue(.{
                            .ty = field.ty,
                            .val = field_val,
                        });
                        const ty_bit_size = @intCast(u16, field.ty.bitSize(target));
                        const small_int_ty = dg.context.intType(ty_bit_size);
                        const small_int_val = non_int_val.constBitCast(small_int_ty);
                        const shift_rhs = int_llvm_ty.constInt(running_bits, .False);
                        // If the field is as large as the entire packed struct, this
                        // zext would go from, e.g. i16 to i16. This is legal with
                        // constZExtOrBitCast but not legal with constZExt.
                        const extended_int_val = small_int_val.constZExtOrBitCast(int_llvm_ty);
                        const shifted = extended_int_val.constShl(shift_rhs);
                        running_int = running_int.constOr(shifted);
                        running_bits += ty_bit_size;
                    }
                    return running_int;
                }

                const llvm_field_count = llvm_struct_ty.countStructElementTypes();
                var llvm_fields = try std.ArrayListUnmanaged(*const llvm.Value).initCapacity(gpa, llvm_field_count);
                defer llvm_fields.deinit(gpa);

                comptime assert(struct_layout_version == 2);
                var offset: u64 = 0;
                var big_align: u32 = 0;
                var need_unnamed = false;

                for (struct_obj.fields.values()) |field, i| {
                    if (field.is_comptime or !field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                    const field_align = field.normalAlignment(target);
                    big_align = @maximum(big_align, field_align);
                    const prev_offset = offset;
                    offset = std.mem.alignForwardGeneric(u64, offset, field_align);

                    const padding_len = offset - prev_offset;
                    if (padding_len > 0) {
                        const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                        // TODO make this and all other padding elsewhere in debug
                        // builds be 0xaa not undef.
                        llvm_fields.appendAssumeCapacity(llvm_array_ty.getUndef());
                    }

                    const field_llvm_val = try dg.genTypedValue(.{
                        .ty = field.ty,
                        .val = field_vals[i],
                    });

                    need_unnamed = need_unnamed or dg.isUnnamedType(field.ty, field_llvm_val);

                    llvm_fields.appendAssumeCapacity(field_llvm_val);

                    offset += field.ty.abiSize(target);
                }
                {
                    const prev_offset = offset;
                    offset = std.mem.alignForwardGeneric(u64, offset, big_align);
                    const padding_len = offset - prev_offset;
                    if (padding_len > 0) {
                        const llvm_array_ty = dg.context.intType(8).arrayType(@intCast(c_uint, padding_len));
                        llvm_fields.appendAssumeCapacity(llvm_array_ty.getUndef());
                    }
                }

                if (need_unnamed) {
                    return dg.context.constStruct(
                        llvm_fields.items.ptr,
                        @intCast(c_uint, llvm_fields.items.len),
                        .False,
                    );
                } else {
                    return llvm_struct_ty.constNamedStruct(
                        llvm_fields.items.ptr,
                        @intCast(c_uint, llvm_fields.items.len),
                    );
                }
            },
            .Union => {
                const llvm_union_ty = try dg.llvmType(tv.ty);
                const tag_and_val = tv.val.castTag(.@"union").?.data;

                const layout = tv.ty.unionGetLayout(target);

                if (layout.payload_size == 0) {
                    return genTypedValue(dg, .{
                        .ty = tv.ty.unionTagType().?,
                        .val = tag_and_val.tag,
                    });
                }
                const union_obj = tv.ty.cast(Type.Payload.Union).?.data;
                const field_index = union_obj.tag_ty.enumTagFieldIndex(tag_and_val.tag, dg.module).?;
                assert(union_obj.haveFieldTypes());
                const field_ty = union_obj.fields.values()[field_index].ty;
                const payload = p: {
                    if (!field_ty.hasRuntimeBitsIgnoreComptime()) {
                        const padding_len = @intCast(c_uint, layout.payload_size);
                        break :p dg.context.intType(8).arrayType(padding_len).getUndef();
                    }
                    const field = try genTypedValue(dg, .{ .ty = field_ty, .val = tag_and_val.val });
                    const field_size = field_ty.abiSize(target);
                    if (field_size == layout.payload_size) {
                        break :p field;
                    }
                    const padding_len = @intCast(c_uint, layout.payload_size - field_size);
                    const fields: [2]*const llvm.Value = .{
                        field, dg.context.intType(8).arrayType(padding_len).getUndef(),
                    };
                    break :p dg.context.constStruct(&fields, fields.len, .True);
                };

                // In this case we must make an unnamed struct because LLVM does
                // not support bitcasting our payload struct to the true union payload type.
                // Instead we use an unnamed struct and every reference to the global
                // must pointer cast to the expected type before accessing the union.
                const need_unnamed = layout.most_aligned_field != field_index;

                if (layout.tag_size == 0) {
                    const fields: [1]*const llvm.Value = .{payload};
                    if (need_unnamed) {
                        return dg.context.constStruct(&fields, fields.len, .False);
                    } else {
                        return llvm_union_ty.constNamedStruct(&fields, fields.len);
                    }
                }
                const llvm_tag_value = try genTypedValue(dg, .{
                    .ty = tv.ty.unionTagType().?,
                    .val = tag_and_val.tag,
                });
                var fields: [3]*const llvm.Value = undefined;
                var fields_len: c_uint = 2;
                if (layout.tag_align >= layout.payload_align) {
                    fields = .{ llvm_tag_value, payload, undefined };
                } else {
                    fields = .{ payload, llvm_tag_value, undefined };
                }
                if (layout.padding != 0) {
                    fields[2] = dg.context.intType(8).arrayType(layout.padding).getUndef();
                    fields_len = 3;
                }
                if (need_unnamed) {
                    return dg.context.constStruct(&fields, fields_len, .False);
                } else {
                    return llvm_union_ty.constNamedStruct(&fields, fields_len);
                }
            },
            .Vector => switch (tv.val.tag()) {
                .bytes => {
                    // Note, sentinel is not stored even if the type has a sentinel.
                    const bytes = tv.val.castTag(.bytes).?.data;
                    const vector_len = @intCast(usize, tv.ty.arrayLen());
                    assert(vector_len == bytes.len or vector_len + 1 == bytes.len);

                    const elem_ty = tv.ty.elemType();
                    const llvm_elems = try dg.gpa.alloc(*const llvm.Value, vector_len);
                    defer dg.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem, i| {
                        var byte_payload: Value.Payload.U64 = .{
                            .base = .{ .tag = .int_u64 },
                            .data = bytes[i],
                        };

                        elem.* = try dg.genTypedValue(.{
                            .ty = elem_ty,
                            .val = Value.initPayload(&byte_payload.base),
                        });
                    }
                    return llvm.constVector(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                .aggregate => {
                    // Note, sentinel is not stored even if the type has a sentinel.
                    // The value includes the sentinel in those cases.
                    const elem_vals = tv.val.castTag(.aggregate).?.data;
                    const vector_len = @intCast(usize, tv.ty.arrayLen());
                    assert(vector_len == elem_vals.len or vector_len + 1 == elem_vals.len);
                    const elem_ty = tv.ty.elemType();
                    const llvm_elems = try dg.gpa.alloc(*const llvm.Value, vector_len);
                    defer dg.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem, i| {
                        elem.* = try dg.genTypedValue(.{ .ty = elem_ty, .val = elem_vals[i] });
                    }
                    return llvm.constVector(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                .repeated => {
                    // Note, sentinel is not stored even if the type has a sentinel.
                    const val = tv.val.castTag(.repeated).?.data;
                    const elem_ty = tv.ty.elemType();
                    const len = @intCast(usize, tv.ty.arrayLen());
                    const llvm_elems = try dg.gpa.alloc(*const llvm.Value, len);
                    defer dg.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem| {
                        elem.* = try dg.genTypedValue(.{ .ty = elem_ty, .val = val });
                    }
                    return llvm.constVector(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                else => unreachable,
            },

            .ComptimeInt => unreachable,
            .ComptimeFloat => unreachable,
            .Type => unreachable,
            .EnumLiteral => unreachable,
            .Void => unreachable,
            .NoReturn => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .BoundFn => unreachable,
            .Opaque => unreachable,

            .Frame,
            .AnyFrame,
            => return dg.todo("implement const of type '{}'", .{tv.ty.fmtDebug()}),
        }
    }

    const ParentPtr = struct {
        ty: Type,
        llvm_ptr: *const llvm.Value,
    };

    fn lowerParentPtrDecl(
        dg: *DeclGen,
        ptr_val: Value,
        decl_index: Module.Decl.Index,
        ptr_child_ty: Type,
    ) Error!*const llvm.Value {
        const decl = dg.module.declPtr(decl_index);
        dg.module.markDeclAlive(decl);
        var ptr_ty_payload: Type.Payload.ElemType = .{
            .base = .{ .tag = .single_mut_pointer },
            .data = decl.ty,
        };
        const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
        const llvm_ptr = try dg.lowerDeclRefValue(.{ .ty = ptr_ty, .val = ptr_val }, decl_index);

        if (ptr_child_ty.eql(decl.ty, dg.module)) {
            return llvm_ptr;
        } else {
            return llvm_ptr.constBitCast((try dg.llvmType(ptr_child_ty)).pointerType(0));
        }
    }

    fn lowerParentPtr(dg: *DeclGen, ptr_val: Value, ptr_child_ty: Type) Error!*const llvm.Value {
        const target = dg.module.getTarget();
        var bitcast_needed: bool = undefined;
        const llvm_ptr = switch (ptr_val.tag()) {
            .decl_ref_mut => {
                const decl = ptr_val.castTag(.decl_ref_mut).?.data.decl_index;
                return dg.lowerParentPtrDecl(ptr_val, decl, ptr_child_ty);
            },
            .decl_ref => {
                const decl = ptr_val.castTag(.decl_ref).?.data;
                return dg.lowerParentPtrDecl(ptr_val, decl, ptr_child_ty);
            },
            .variable => {
                const decl = ptr_val.castTag(.variable).?.data.owner_decl;
                return dg.lowerParentPtrDecl(ptr_val, decl, ptr_child_ty);
            },
            .int_i64 => {
                const int = ptr_val.castTag(.int_i64).?.data;
                const llvm_usize = try dg.llvmType(Type.usize);
                const llvm_int = llvm_usize.constInt(@bitCast(u64, int), .False);
                return llvm_int.constIntToPtr((try dg.llvmType(ptr_child_ty)).pointerType(0));
            },
            .int_u64 => {
                const int = ptr_val.castTag(.int_u64).?.data;
                const llvm_usize = try dg.llvmType(Type.usize);
                const llvm_int = llvm_usize.constInt(int, .False);
                return llvm_int.constIntToPtr((try dg.llvmType(ptr_child_ty)).pointerType(0));
            },
            .field_ptr => blk: {
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;
                const parent_llvm_ptr = try dg.lowerParentPtr(field_ptr.container_ptr, field_ptr.container_ty);
                const parent_ty = field_ptr.container_ty;

                const field_index = @intCast(u32, field_ptr.field_index);
                const llvm_u32 = dg.context.intType(32);
                switch (parent_ty.zigTypeTag()) {
                    .Union => {
                        bitcast_needed = true;

                        const layout = parent_ty.unionGetLayout(target);
                        if (layout.payload_size == 0) {
                            // In this case a pointer to the union and a pointer to any
                            // (void) payload is the same.
                            break :blk parent_llvm_ptr;
                        }
                        const llvm_pl_index = if (layout.tag_size == 0)
                            0
                        else
                            @boolToInt(layout.tag_align >= layout.payload_align);
                        const indices: [2]*const llvm.Value = .{
                            llvm_u32.constInt(0, .False),
                            llvm_u32.constInt(llvm_pl_index, .False),
                        };
                        break :blk parent_llvm_ptr.constInBoundsGEP(&indices, indices.len);
                    },
                    .Struct => {
                        const field_ty = parent_ty.structFieldType(field_index);
                        bitcast_needed = !field_ty.eql(ptr_child_ty, dg.module);

                        var ty_buf: Type.Payload.Pointer = undefined;
                        const llvm_field_index = llvmFieldIndex(parent_ty, field_index, target, &ty_buf).?;
                        const indices: [2]*const llvm.Value = .{
                            llvm_u32.constInt(0, .False),
                            llvm_u32.constInt(llvm_field_index, .False),
                        };
                        break :blk parent_llvm_ptr.constInBoundsGEP(&indices, indices.len);
                    },
                    else => unreachable,
                }
            },
            .elem_ptr => blk: {
                const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
                const parent_llvm_ptr = try dg.lowerParentPtr(elem_ptr.array_ptr, elem_ptr.elem_ty);
                bitcast_needed = !elem_ptr.elem_ty.eql(ptr_child_ty, dg.module);

                const llvm_usize = try dg.llvmType(Type.usize);
                const indices: [1]*const llvm.Value = .{
                    llvm_usize.constInt(elem_ptr.index, .False),
                };
                break :blk parent_llvm_ptr.constInBoundsGEP(&indices, indices.len);
            },
            .opt_payload_ptr => blk: {
                const opt_payload_ptr = ptr_val.castTag(.opt_payload_ptr).?.data;
                const parent_llvm_ptr = try dg.lowerParentPtr(opt_payload_ptr.container_ptr, opt_payload_ptr.container_ty);
                var buf: Type.Payload.ElemType = undefined;

                const payload_ty = opt_payload_ptr.container_ty.optionalChild(&buf);
                bitcast_needed = !payload_ty.eql(ptr_child_ty, dg.module);

                if (!payload_ty.hasRuntimeBitsIgnoreComptime() or payload_ty.isPtrLikeOptional()) {
                    // In this case, we represent pointer to optional the same as pointer
                    // to the payload.
                    break :blk parent_llvm_ptr;
                }

                const llvm_u32 = dg.context.intType(32);
                const indices: [2]*const llvm.Value = .{
                    llvm_u32.constInt(0, .False),
                    llvm_u32.constInt(0, .False),
                };
                break :blk parent_llvm_ptr.constInBoundsGEP(&indices, indices.len);
            },
            .eu_payload_ptr => blk: {
                const eu_payload_ptr = ptr_val.castTag(.eu_payload_ptr).?.data;
                const parent_llvm_ptr = try dg.lowerParentPtr(eu_payload_ptr.container_ptr, eu_payload_ptr.container_ty);

                const payload_ty = eu_payload_ptr.container_ty.errorUnionPayload();
                bitcast_needed = !payload_ty.eql(ptr_child_ty, dg.module);

                if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                    // In this case, we represent pointer to error union the same as pointer
                    // to the payload.
                    break :blk parent_llvm_ptr;
                }

                const payload_offset: u8 = if (payload_ty.abiAlignment(target) > Type.anyerror.abiSize(target)) 2 else 1;
                const llvm_u32 = dg.context.intType(32);
                const indices: [2]*const llvm.Value = .{
                    llvm_u32.constInt(0, .False),
                    llvm_u32.constInt(payload_offset, .False),
                };
                break :blk parent_llvm_ptr.constInBoundsGEP(&indices, indices.len);
            },
            else => unreachable,
        };
        if (bitcast_needed) {
            return llvm_ptr.constBitCast((try dg.llvmType(ptr_child_ty)).pointerType(0));
        } else {
            return llvm_ptr;
        }
    }

    fn lowerDeclRefValue(
        self: *DeclGen,
        tv: TypedValue,
        decl_index: Module.Decl.Index,
    ) Error!*const llvm.Value {
        if (tv.ty.isSlice()) {
            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            const ptr_ty = tv.ty.slicePtrFieldType(&buf);
            var slice_len: Value.Payload.U64 = .{
                .base = .{ .tag = .int_u64 },
                .data = tv.val.sliceLen(self.module),
            };
            const fields: [2]*const llvm.Value = .{
                try self.genTypedValue(.{
                    .ty = ptr_ty,
                    .val = tv.val,
                }),
                try self.genTypedValue(.{
                    .ty = Type.usize,
                    .val = Value.initPayload(&slice_len.base),
                }),
            };
            return self.context.constStruct(&fields, fields.len, .False);
        }

        // In the case of something like:
        // fn foo() void {}
        // const bar = foo;
        // ... &bar;
        // `bar` is just an alias and we actually want to lower a reference to `foo`.
        const decl = self.module.declPtr(decl_index);
        if (decl.val.castTag(.function)) |func| {
            if (func.data.owner_decl != decl_index) {
                return self.lowerDeclRefValue(tv, func.data.owner_decl);
            }
        }

        const is_fn_body = decl.ty.zigTypeTag() == .Fn;
        if (!is_fn_body and !decl.ty.hasRuntimeBitsIgnoreComptime()) {
            return self.lowerPtrToVoid(tv.ty);
        }

        self.module.markDeclAlive(decl);

        const llvm_val = if (is_fn_body)
            try self.resolveLlvmFunction(decl_index)
        else
            try self.resolveGlobalDecl(decl_index);

        const llvm_type = try self.llvmType(tv.ty);
        if (tv.ty.zigTypeTag() == .Int) {
            return llvm_val.constPtrToInt(llvm_type);
        } else {
            return llvm_val.constBitCast(llvm_type);
        }
    }

    fn lowerPtrToVoid(dg: *DeclGen, ptr_ty: Type) !*const llvm.Value {
        const alignment = ptr_ty.ptrInfo().data.@"align";
        // Even though we are pointing at something which has zero bits (e.g. `void`),
        // Pointers are defined to have bits. So we must return something here.
        // The value cannot be undefined, because we use the `nonnull` annotation
        // for non-optional pointers. We also need to respect the alignment, even though
        // the address will never be dereferenced.
        const llvm_usize = try dg.llvmType(Type.usize);
        const llvm_ptr_ty = try dg.llvmType(ptr_ty);
        if (alignment != 0) {
            return llvm_usize.constInt(alignment, .False).constIntToPtr(llvm_ptr_ty);
        }
        // Note that these 0xaa values are appropriate even in release-optimized builds
        // because we need a well-defined value that is not null, and LLVM does not
        // have an "undef_but_not_null" attribute. As an example, if this `alloc` AIR
        // instruction is followed by a `wrap_optional`, it will return this value
        // verbatim, and the result should test as non-null.
        const target = dg.module.getTarget();
        const int = switch (target.cpu.arch.ptrBitWidth()) {
            32 => llvm_usize.constInt(0xaaaaaaaa, .False),
            64 => llvm_usize.constInt(0xaaaaaaaa_aaaaaaaa, .False),
            else => unreachable,
        };
        return int.constIntToPtr(llvm_ptr_ty);
    }

    fn addAttr(dg: DeclGen, val: *const llvm.Value, index: llvm.AttributeIndex, name: []const u8) void {
        return dg.addAttrInt(val, index, name, 0);
    }

    fn addArgAttr(dg: DeclGen, fn_val: *const llvm.Value, param_index: u32, attr_name: []const u8) void {
        return dg.addAttr(fn_val, param_index + 1, attr_name);
    }

    fn removeAttr(val: *const llvm.Value, index: llvm.AttributeIndex, name: []const u8) void {
        const kind_id = llvm.getEnumAttributeKindForName(name.ptr, name.len);
        assert(kind_id != 0);
        val.removeEnumAttributeAtIndex(index, kind_id);
    }

    fn addAttrInt(
        dg: DeclGen,
        val: *const llvm.Value,
        index: llvm.AttributeIndex,
        name: []const u8,
        int: u64,
    ) void {
        const kind_id = llvm.getEnumAttributeKindForName(name.ptr, name.len);
        assert(kind_id != 0);
        const llvm_attr = dg.context.createEnumAttribute(kind_id, int);
        val.addAttributeAtIndex(index, llvm_attr);
    }

    fn addAttrString(
        dg: *DeclGen,
        val: *const llvm.Value,
        index: llvm.AttributeIndex,
        name: []const u8,
        value: []const u8,
    ) void {
        const llvm_attr = dg.context.createStringAttribute(
            name.ptr,
            @intCast(c_uint, name.len),
            value.ptr,
            @intCast(c_uint, value.len),
        );
        val.addAttributeAtIndex(index, llvm_attr);
    }

    fn addFnAttr(dg: DeclGen, val: *const llvm.Value, name: []const u8) void {
        dg.addAttr(val, std.math.maxInt(llvm.AttributeIndex), name);
    }

    fn addFnAttrString(dg: *DeclGen, val: *const llvm.Value, name: []const u8, value: []const u8) void {
        dg.addAttrString(val, std.math.maxInt(llvm.AttributeIndex), name, value);
    }

    fn removeFnAttr(fn_val: *const llvm.Value, name: []const u8) void {
        removeAttr(fn_val, std.math.maxInt(llvm.AttributeIndex), name);
    }

    fn addFnAttrInt(dg: DeclGen, fn_val: *const llvm.Value, name: []const u8, int: u64) void {
        return dg.addAttrInt(fn_val, std.math.maxInt(llvm.AttributeIndex), name, int);
    }

    /// If the operand type of an atomic operation is not byte sized we need to
    /// widen it before using it and then truncate the result.
    /// RMW exchange of floating-point values is bitcasted to same-sized integer
    /// types to work around a LLVM deficiency when targeting ARM/AArch64.
    fn getAtomicAbiType(dg: *DeclGen, ty: Type, is_rmw_xchg: bool) ?*const llvm.Type {
        const target = dg.module.getTarget();
        var buffer: Type.Payload.Bits = undefined;
        const int_ty = switch (ty.zigTypeTag()) {
            .Int => ty,
            .Enum => ty.intTagType(&buffer),
            .Float => {
                if (!is_rmw_xchg) return null;
                return dg.context.intType(@intCast(c_uint, ty.abiSize(target) * 8));
            },
            .Bool => return dg.context.intType(8),
            else => return null,
        };
        const bit_count = int_ty.intInfo(target).bits;
        if (!std.math.isPowerOfTwo(bit_count) or (bit_count % 8) != 0) {
            return dg.context.intType(@intCast(c_uint, int_ty.abiSize(target) * 8));
        } else {
            return null;
        }
    }
};

pub const FuncGen = struct {
    gpa: Allocator,
    dg: *DeclGen,
    air: Air,
    liveness: Liveness,
    context: *const llvm.Context,
    builder: *const llvm.Builder,
    di_scope: ?*llvm.DIScope,
    di_file: ?*llvm.DIFile,
    base_line: u32,
    prev_dbg_line: c_uint,
    prev_dbg_column: c_uint,

    /// Stack of locations where a call was inlined.
    dbg_inlined: std.ArrayListUnmanaged(DbgState) = .{},

    /// Stack of `DILexicalBlock`s. dbg_block instructions cannot happend accross
    /// dbg_inline instructions so no special handling there is required.
    dbg_block_stack: std.ArrayListUnmanaged(*llvm.DIScope) = .{},

    /// This stores the LLVM values used in a function, such that they can be referred to
    /// in other instructions. This table is cleared before every function is generated.
    func_inst_table: std.AutoHashMapUnmanaged(Air.Inst.Ref, *const llvm.Value),

    /// If the return type is sret, this is the result pointer. Otherwise null.
    /// Note that this can disagree with isByRef for the return type in the case
    /// of C ABI functions.
    ret_ptr: ?*const llvm.Value,
    /// These fields are used to refer to the LLVM value of the function parameters
    /// in an Arg instruction.
    /// This list may be shorter than the list according to the zig type system;
    /// it omits 0-bit types. If the function uses sret as the first parameter,
    /// this slice does not include it.
    args: []const *const llvm.Value,
    arg_index: c_uint,

    llvm_func: *const llvm.Value,

    /// This data structure is used to implement breaking to blocks.
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
        parent_bb: *const llvm.BasicBlock,
        break_bbs: *BreakBasicBlocks,
        break_vals: *BreakValues,
    }),

    single_threaded: bool,

    const DbgState = struct { loc: *llvm.DILocation, scope: *llvm.DIScope, base_line: u32 };
    const BreakBasicBlocks = std.ArrayListUnmanaged(*const llvm.BasicBlock);
    const BreakValues = std.ArrayListUnmanaged(*const llvm.Value);

    fn deinit(self: *FuncGen) void {
        self.builder.dispose();
        self.dbg_inlined.deinit(self.gpa);
        self.dbg_block_stack.deinit(self.gpa);
        self.func_inst_table.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
    }

    fn todo(self: *FuncGen, comptime format: []const u8, args: anytype) Error {
        @setCold(true);
        return self.dg.todo(format, args);
    }

    fn llvmModule(self: *FuncGen) *const llvm.Module {
        return self.dg.object.llvm_module;
    }

    fn resolveInst(self: *FuncGen, inst: Air.Inst.Ref) !*const llvm.Value {
        const gop = try self.func_inst_table.getOrPut(self.dg.gpa, inst);
        if (gop.found_existing) return gop.value_ptr.*;

        const val = self.air.value(inst).?;
        const ty = self.air.typeOf(inst);
        const llvm_val = try self.dg.genTypedValue(.{ .ty = ty, .val = val });
        if (!isByRef(ty)) {
            gop.value_ptr.* = llvm_val;
            return llvm_val;
        }

        // We have an LLVM value but we need to create a global constant and
        // set the value as its initializer, and then return a pointer to the global.
        const target = self.dg.module.getTarget();
        const global = self.dg.object.llvm_module.addGlobal(llvm_val.typeOf(), "");
        global.setInitializer(llvm_val);
        global.setLinkage(.Private);
        global.setGlobalConstant(.True);
        global.setUnnamedAddr(.True);
        global.setAlignment(ty.abiAlignment(target));
        // Because of LLVM limitations for lowering certain types such as unions,
        // the type of global constants might not match the type it is supposed to
        // be, and so we must bitcast the pointer at the usage sites.
        const wanted_llvm_ty = try self.dg.llvmType(ty);
        const wanted_llvm_ptr_ty = wanted_llvm_ty.pointerType(0);
        const casted_ptr = global.constBitCast(wanted_llvm_ptr_ty);
        gop.value_ptr.* = casted_ptr;
        return casted_ptr;
    }

    fn genBody(self: *FuncGen, body: []const Air.Inst.Index) Error!void {
        const air_tags = self.air.instructions.items(.tag);
        for (body) |inst| {
            const opt_value: ?*const llvm.Value = switch (air_tags[inst]) {
                // zig fmt: off
                .add       => try self.airAdd(inst),
                .addwrap   => try self.airAddWrap(inst),
                .add_sat   => try self.airAddSat(inst),
                .sub       => try self.airSub(inst),
                .subwrap   => try self.airSubWrap(inst),
                .sub_sat   => try self.airSubSat(inst),
                .mul       => try self.airMul(inst),
                .mulwrap   => try self.airMulWrap(inst),
                .mul_sat   => try self.airMulSat(inst),
                .div_float => try self.airDivFloat(inst),
                .div_trunc => try self.airDivTrunc(inst),
                .div_floor => try self.airDivFloor(inst),
                .div_exact => try self.airDivExact(inst),
                .rem       => try self.airRem(inst),
                .mod       => try self.airMod(inst),
                .ptr_add   => try self.airPtrAdd(inst),
                .ptr_sub   => try self.airPtrSub(inst),
                .shl       => try self.airShl(inst),
                .shl_sat   => try self.airShlSat(inst),
                .shl_exact => try self.airShlExact(inst),
                .min       => try self.airMin(inst),
                .max       => try self.airMax(inst),
                .slice     => try self.airSlice(inst),
                .mul_add   => try self.airMulAdd(inst),

                .add_with_overflow => try self.airOverflow(inst, "llvm.sadd.with.overflow", "llvm.uadd.with.overflow"),
                .sub_with_overflow => try self.airOverflow(inst, "llvm.ssub.with.overflow", "llvm.usub.with.overflow"),
                .mul_with_overflow => try self.airOverflow(inst, "llvm.smul.with.overflow", "llvm.umul.with.overflow"),
                .shl_with_overflow => try self.airShlWithOverflow(inst),

                .bit_and, .bool_and => try self.airAnd(inst),
                .bit_or, .bool_or   => try self.airOr(inst),
                .xor                => try self.airXor(inst),
                .shr                => try self.airShr(inst, false),
                .shr_exact          => try self.airShr(inst, true),

                .sqrt         => try self.airUnaryOp(inst, "sqrt"),
                .sin          => try self.airUnaryOp(inst, "sin"),
                .cos          => try self.airUnaryOp(inst, "cos"),
                .exp          => try self.airUnaryOp(inst, "exp"),
                .exp2         => try self.airUnaryOp(inst, "exp2"),
                .log          => try self.airUnaryOp(inst, "log"),
                .log2         => try self.airUnaryOp(inst, "log2"),
                .log10        => try self.airUnaryOp(inst, "log10"),
                .fabs         => try self.airUnaryOp(inst, "fabs"),
                .floor        => try self.airUnaryOp(inst, "floor"),
                .ceil         => try self.airUnaryOp(inst, "ceil"),
                .round        => try self.airUnaryOp(inst, "round"),
                .trunc_float  => try self.airUnaryOp(inst, "trunc"),

                .cmp_eq  => try self.airCmp(inst, .eq),
                .cmp_gt  => try self.airCmp(inst, .gt),
                .cmp_gte => try self.airCmp(inst, .gte),
                .cmp_lt  => try self.airCmp(inst, .lt),
                .cmp_lte => try self.airCmp(inst, .lte),
                .cmp_neq => try self.airCmp(inst, .neq),

                .cmp_vector => try self.airCmpVector(inst),
                .cmp_lt_errors_len => try self.airCmpLtErrorsLen(inst),

                .is_non_null     => try self.airIsNonNull(inst, false, false, .NE),
                .is_non_null_ptr => try self.airIsNonNull(inst, true , false, .NE),
                .is_null         => try self.airIsNonNull(inst, false, true , .EQ),
                .is_null_ptr     => try self.airIsNonNull(inst, true , true , .EQ),

                .is_non_err      => try self.airIsErr(inst, .EQ, false),
                .is_non_err_ptr  => try self.airIsErr(inst, .EQ, true),
                .is_err          => try self.airIsErr(inst, .NE, false),
                .is_err_ptr      => try self.airIsErr(inst, .NE, true),

                .alloc          => try self.airAlloc(inst),
                .ret_ptr        => try self.airRetPtr(inst),
                .arg            => try self.airArg(inst),
                .bitcast        => try self.airBitCast(inst),
                .bool_to_int    => try self.airBoolToInt(inst),
                .block          => try self.airBlock(inst),
                .br             => try self.airBr(inst),
                .switch_br      => try self.airSwitchBr(inst),
                .breakpoint     => try self.airBreakpoint(inst),
                .ret_addr       => try self.airRetAddr(inst),
                .frame_addr     => try self.airFrameAddress(inst),
                .cond_br        => try self.airCondBr(inst),
                .intcast        => try self.airIntCast(inst),
                .trunc          => try self.airTrunc(inst),
                .fptrunc        => try self.airFptrunc(inst),
                .fpext          => try self.airFpext(inst),
                .ptrtoint       => try self.airPtrToInt(inst),
                .load           => try self.airLoad(inst),
                .loop           => try self.airLoop(inst),
                .not            => try self.airNot(inst),
                .ret            => try self.airRet(inst),
                .ret_load       => try self.airRetLoad(inst),
                .store          => try self.airStore(inst),
                .assembly       => try self.airAssembly(inst),
                .slice_ptr      => try self.airSliceField(inst, 0),
                .slice_len      => try self.airSliceField(inst, 1),

                .call              => try self.airCall(inst, .Auto),
                .call_always_tail  => try self.airCall(inst, .AlwaysTail),
                .call_never_tail   => try self.airCall(inst, .NeverTail),
                .call_never_inline => try self.airCall(inst, .NeverInline),

                .ptr_slice_ptr_ptr => try self.airPtrSliceFieldPtr(inst, 0),
                .ptr_slice_len_ptr => try self.airPtrSliceFieldPtr(inst, 1),

                .array_to_slice => try self.airArrayToSlice(inst),
                .float_to_int   => try self.airFloatToInt(inst),
                .int_to_float   => try self.airIntToFloat(inst),
                .cmpxchg_weak   => try self.airCmpxchg(inst, true),
                .cmpxchg_strong => try self.airCmpxchg(inst, false),
                .fence          => try self.airFence(inst),
                .atomic_rmw     => try self.airAtomicRmw(inst),
                .atomic_load    => try self.airAtomicLoad(inst),
                .memset         => try self.airMemset(inst),
                .memcpy         => try self.airMemcpy(inst),
                .set_union_tag  => try self.airSetUnionTag(inst),
                .get_union_tag  => try self.airGetUnionTag(inst),
                .clz            => try self.airClzCtz(inst, "llvm.ctlz"),
                .ctz            => try self.airClzCtz(inst, "llvm.cttz"),
                .popcount       => try self.airBitOp(inst, "llvm.ctpop"),
                .byte_swap      => try self.airByteSwap(inst, "llvm.bswap"),
                .bit_reverse    => try self.airBitOp(inst, "llvm.bitreverse"),
                .tag_name       => try self.airTagName(inst),
                .error_name     => try self.airErrorName(inst),
                .splat          => try self.airSplat(inst),
                .select         => try self.airSelect(inst),
                .shuffle        => try self.airShuffle(inst),
                .reduce         => try self.airReduce(inst),
                .aggregate_init => try self.airAggregateInit(inst),
                .union_init     => try self.airUnionInit(inst),
                .prefetch       => try self.airPrefetch(inst),

                .atomic_store_unordered => try self.airAtomicStore(inst, .Unordered),
                .atomic_store_monotonic => try self.airAtomicStore(inst, .Monotonic),
                .atomic_store_release   => try self.airAtomicStore(inst, .Release),
                .atomic_store_seq_cst   => try self.airAtomicStore(inst, .SequentiallyConsistent),

                .struct_field_ptr => try self.airStructFieldPtr(inst),
                .struct_field_val => try self.airStructFieldVal(inst),

                .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
                .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
                .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
                .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

                .field_parent_ptr => try self.airFieldParentPtr(inst),

                .array_elem_val     => try self.airArrayElemVal(inst),
                .slice_elem_val     => try self.airSliceElemVal(inst),
                .slice_elem_ptr     => try self.airSliceElemPtr(inst),
                .ptr_elem_val       => try self.airPtrElemVal(inst),
                .ptr_elem_ptr       => try self.airPtrElemPtr(inst),

                .optional_payload         => try self.airOptionalPayload(inst),
                .optional_payload_ptr     => try self.airOptionalPayloadPtr(inst),
                .optional_payload_ptr_set => try self.airOptionalPayloadPtrSet(inst),

                .unwrap_errunion_payload     => try self.airErrUnionPayload(inst, false),
                .unwrap_errunion_payload_ptr => try self.airErrUnionPayload(inst, true),
                .unwrap_errunion_err         => try self.airErrUnionErr(inst, false),
                .unwrap_errunion_err_ptr     => try self.airErrUnionErr(inst, true),
                .errunion_payload_ptr_set    => try self.airErrUnionPayloadPtrSet(inst),

                .wrap_optional         => try self.airWrapOptional(inst),
                .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
                .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

                .wasm_memory_size => try self.airWasmMemorySize(inst),
                .wasm_memory_grow => try self.airWasmMemoryGrow(inst),

                .constant => unreachable,
                .const_ty => unreachable,
                .unreach  => self.airUnreach(inst),
                .dbg_stmt => self.airDbgStmt(inst),
                .dbg_inline_begin => try self.airDbgInlineBegin(inst),
                .dbg_inline_end => try self.airDbgInlineEnd(inst),
                .dbg_block_begin => try self.airDbgBlockBegin(),
                .dbg_block_end => try self.airDbgBlockEnd(),
                .dbg_var_ptr => try self.airDbgVarPtr(inst),
                .dbg_var_val => try self.airDbgVarVal(inst),
                // zig fmt: on
            };
            if (opt_value) |val| {
                const ref = Air.indexToRef(inst);
                try self.func_inst_table.putNoClobber(self.gpa, ref, val);
            }
        }
    }

    fn airCall(self: *FuncGen, inst: Air.Inst.Index, attr: llvm.CallAttr) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);
        const callee_ty = self.air.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag()) {
            .Fn => callee_ty,
            .Pointer => callee_ty.childType(),
            else => unreachable,
        };
        const fn_info = zig_fn_ty.fnInfo();
        const return_type = fn_info.return_type;
        const llvm_fn = try self.resolveInst(pl_op.operand);
        const target = self.dg.module.getTarget();
        const sret = firstParamSRet(fn_info, target);

        var llvm_args = std.ArrayList(*const llvm.Value).init(self.gpa);
        defer llvm_args.deinit();

        const ret_ptr = if (!sret) null else blk: {
            const llvm_ret_ty = try self.dg.llvmType(return_type);
            const ret_ptr = self.buildAlloca(llvm_ret_ty);
            ret_ptr.setAlignment(return_type.abiAlignment(target));
            try llvm_args.append(ret_ptr);
            break :blk ret_ptr;
        };

        for (args) |arg| {
            const param_ty = self.air.typeOf(arg);
            if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;

            const llvm_arg = try self.resolveInst(arg);
            const abi_llvm_ty = try lowerFnParamTy(self.dg, fn_info.cc, param_ty);
            const param_llvm_ty = llvm_arg.typeOf();
            if (abi_llvm_ty == param_llvm_ty) {
                try llvm_args.append(llvm_arg);
                continue;
            }

            // In this case the function param type is honoring the calling convention
            // by having a different LLVM type than the usual one. We solve this here
            // at the callsite by bitcasting a pointer to our canonical type, then
            // loading it if necessary.
            const alignment = param_ty.abiAlignment(target);
            const ptr_abi_ty = abi_llvm_ty.pointerType(0);

            const casted_ptr = if (isByRef(param_ty))
                self.builder.buildBitCast(llvm_arg, ptr_abi_ty, "")
            else p: {
                const arg_ptr = self.buildAlloca(param_llvm_ty);
                arg_ptr.setAlignment(alignment);
                const store_inst = self.builder.buildStore(llvm_arg, arg_ptr);
                store_inst.setAlignment(alignment);
                break :p self.builder.buildBitCast(arg_ptr, ptr_abi_ty, "");
            };

            const load_inst = self.builder.buildLoad(casted_ptr, "");
            load_inst.setAlignment(alignment);
            try llvm_args.append(load_inst);
        }

        const call = self.builder.buildCall(
            llvm_fn,
            llvm_args.items.ptr,
            @intCast(c_uint, llvm_args.items.len),
            toLlvmCallConv(fn_info.cc, target),
            attr,
            "",
        );

        if (return_type.isNoReturn()) {
            _ = self.builder.buildUnreachable();
            return null;
        }

        if (self.liveness.isUnused(inst) or !return_type.hasRuntimeBitsIgnoreComptime()) {
            return null;
        }

        const llvm_ret_ty = try self.dg.llvmType(return_type);

        if (ret_ptr) |rp| {
            call.setCallSret(llvm_ret_ty);
            if (isByRef(return_type)) {
                return rp;
            } else {
                // our by-ref status disagrees with sret so we must load.
                const loaded = self.builder.buildLoad(rp, "");
                loaded.setAlignment(return_type.abiAlignment(target));
                return loaded;
            }
        }

        const abi_ret_ty = try lowerFnRetTy(self.dg, fn_info);

        if (abi_ret_ty != llvm_ret_ty) {
            // In this case the function return type is honoring the calling convention by having
            // a different LLVM type than the usual one. We solve this here at the callsite
            // by bitcasting a pointer to our canonical type, then loading it if necessary.
            const rp = self.buildAlloca(llvm_ret_ty);
            const alignment = return_type.abiAlignment(target);
            rp.setAlignment(alignment);
            const ptr_abi_ty = abi_ret_ty.pointerType(0);
            const casted_ptr = self.builder.buildBitCast(rp, ptr_abi_ty, "");
            const store_inst = self.builder.buildStore(call, casted_ptr);
            store_inst.setAlignment(alignment);
            if (isByRef(return_type)) {
                return rp;
            } else {
                const load_inst = self.builder.buildLoad(rp, "");
                load_inst.setAlignment(alignment);
                return load_inst;
            }
        }

        if (isByRef(return_type)) {
            // our by-ref status disagrees with sret so we must allocate, store,
            // and return the allocation pointer.
            const rp = self.buildAlloca(llvm_ret_ty);
            const alignment = return_type.abiAlignment(target);
            rp.setAlignment(alignment);
            const store_inst = self.builder.buildStore(call, rp);
            store_inst.setAlignment(alignment);
            return rp;
        } else {
            return call;
        }
    }

    fn airRet(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ret_ty = self.air.typeOf(un_op);
        if (self.ret_ptr) |ret_ptr| {
            const operand = try self.resolveInst(un_op);
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = ret_ty,
            };
            const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            self.store(ret_ptr, ptr_ty, operand, .NotAtomic);
            _ = self.builder.buildRetVoid();
            return null;
        }
        if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
            _ = self.builder.buildRetVoid();
            return null;
        }
        const fn_info = self.dg.decl.ty.fnInfo();
        const abi_ret_ty = try lowerFnRetTy(self.dg, fn_info);
        const operand = try self.resolveInst(un_op);
        const llvm_ret_ty = operand.typeOf();
        if (abi_ret_ty == llvm_ret_ty) {
            _ = self.builder.buildRet(operand);
            return null;
        }

        const target = self.dg.module.getTarget();
        const alignment = ret_ty.abiAlignment(target);
        const ptr_abi_ty = abi_ret_ty.pointerType(0);
        const rp = self.buildAlloca(llvm_ret_ty);
        rp.setAlignment(alignment);
        const store_inst = self.builder.buildStore(operand, rp);
        store_inst.setAlignment(alignment);
        const casted_ptr = self.builder.buildBitCast(rp, ptr_abi_ty, "");
        const load_inst = self.builder.buildLoad(casted_ptr, "");
        load_inst.setAlignment(alignment);
        _ = self.builder.buildRet(load_inst);
        return null;
    }

    fn airRetLoad(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ptr_ty = self.air.typeOf(un_op);
        const ret_ty = ptr_ty.childType();
        if (!ret_ty.hasRuntimeBitsIgnoreComptime() or self.ret_ptr != null) {
            _ = self.builder.buildRetVoid();
            return null;
        }
        const ptr = try self.resolveInst(un_op);
        const target = self.dg.module.getTarget();
        const fn_info = self.dg.decl.ty.fnInfo();
        const abi_ret_ty = try lowerFnRetTy(self.dg, fn_info);
        const llvm_ret_ty = try self.dg.llvmType(ret_ty);
        const casted_ptr = if (abi_ret_ty == llvm_ret_ty) ptr else p: {
            const ptr_abi_ty = abi_ret_ty.pointerType(0);
            break :p self.builder.buildBitCast(ptr, ptr_abi_ty, "");
        };
        const loaded = self.builder.buildLoad(casted_ptr, "");
        loaded.setAlignment(ret_ty.abiAlignment(target));
        _ = self.builder.buildRet(loaded);
        return null;
    }

    fn airCmp(self: *FuncGen, inst: Air.Inst.Index, op: math.CompareOperator) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const operand_ty = self.air.typeOf(bin_op.lhs);

        return self.cmp(lhs, rhs, operand_ty, op);
    }

    fn airCmpVector(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const vec_ty = self.air.typeOf(extra.lhs);
        const cmp_op = extra.compareOperator();

        return self.cmp(lhs, rhs, vec_ty, cmp_op);
    }

    fn airCmpLtErrorsLen(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const llvm_fn = try self.getCmpLtErrorsLenFunction();
        const args: [1]*const llvm.Value = .{operand};
        return self.builder.buildCall(llvm_fn, &args, args.len, .Fast, .Auto, "");
    }

    fn cmp(
        self: *FuncGen,
        lhs: *const llvm.Value,
        rhs: *const llvm.Value,
        operand_ty: Type,
        op: math.CompareOperator,
    ) *const llvm.Value {
        var int_buffer: Type.Payload.Bits = undefined;
        var opt_buffer: Type.Payload.ElemType = undefined;

        const scalar_ty = operand_ty.scalarType();
        const int_ty = switch (scalar_ty.zigTypeTag()) {
            .Enum => scalar_ty.intTagType(&int_buffer),
            .Int, .Bool, .Pointer, .ErrorSet => scalar_ty,
            .Optional => blk: {
                const payload_ty = operand_ty.optionalChild(&opt_buffer);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime() or operand_ty.isPtrLikeOptional()) {
                    break :blk operand_ty;
                }
                // We need to emit instructions to check for equality/inequality
                // of optionals that are not pointers.
                const is_by_ref = isByRef(operand_ty);
                const lhs_non_null = self.optIsNonNull(lhs, is_by_ref);
                const rhs_non_null = self.optIsNonNull(rhs, is_by_ref);
                const llvm_i2 = self.context.intType(2);
                const lhs_non_null_i2 = self.builder.buildZExt(lhs_non_null, llvm_i2, "");
                const rhs_non_null_i2 = self.builder.buildZExt(rhs_non_null, llvm_i2, "");
                const lhs_shifted = self.builder.buildShl(lhs_non_null_i2, llvm_i2.constInt(1, .False), "");
                const lhs_rhs_ored = self.builder.buildOr(lhs_shifted, rhs_non_null_i2, "");
                const both_null_block = self.context.appendBasicBlock(self.llvm_func, "BothNull");
                const mixed_block = self.context.appendBasicBlock(self.llvm_func, "Mixed");
                const both_pl_block = self.context.appendBasicBlock(self.llvm_func, "BothNonNull");
                const end_block = self.context.appendBasicBlock(self.llvm_func, "End");
                const llvm_switch = self.builder.buildSwitch(lhs_rhs_ored, mixed_block, 2);
                const llvm_i2_00 = llvm_i2.constInt(0b00, .False);
                const llvm_i2_11 = llvm_i2.constInt(0b11, .False);
                llvm_switch.addCase(llvm_i2_00, both_null_block);
                llvm_switch.addCase(llvm_i2_11, both_pl_block);

                self.builder.positionBuilderAtEnd(both_null_block);
                _ = self.builder.buildBr(end_block);

                self.builder.positionBuilderAtEnd(mixed_block);
                _ = self.builder.buildBr(end_block);

                self.builder.positionBuilderAtEnd(both_pl_block);
                const lhs_payload = self.optPayloadHandle(lhs, is_by_ref);
                const rhs_payload = self.optPayloadHandle(rhs, is_by_ref);
                const payload_cmp = self.cmp(lhs_payload, rhs_payload, payload_ty, op);
                _ = self.builder.buildBr(end_block);
                const both_pl_block_end = self.builder.getInsertBlock();

                self.builder.positionBuilderAtEnd(end_block);
                const incoming_blocks: [3]*const llvm.BasicBlock = .{
                    both_null_block,
                    mixed_block,
                    both_pl_block_end,
                };
                const llvm_i1 = self.context.intType(1);
                const llvm_i1_0 = llvm_i1.constInt(0, .False);
                const llvm_i1_1 = llvm_i1.constInt(1, .False);
                const incoming_values: [3]*const llvm.Value = .{
                    switch (op) {
                        .eq => llvm_i1_1,
                        .neq => llvm_i1_0,
                        else => unreachable,
                    },
                    switch (op) {
                        .eq => llvm_i1_0,
                        .neq => llvm_i1_1,
                        else => unreachable,
                    },
                    payload_cmp,
                };

                const phi_node = self.builder.buildPhi(llvm_i1, "");
                comptime assert(incoming_values.len == incoming_blocks.len);
                phi_node.addIncoming(
                    &incoming_values,
                    &incoming_blocks,
                    incoming_values.len,
                );
                return phi_node;
            },
            .Float => {
                const operation: llvm.RealPredicate = switch (op) {
                    .eq => .OEQ,
                    .neq => .UNE,
                    .lt => .OLT,
                    .lte => .OLE,
                    .gt => .OGT,
                    .gte => .OGE,
                };
                return self.builder.buildFCmp(operation, lhs, rhs, "");
            },
            else => unreachable,
        };
        const is_signed = int_ty.isSignedInt();
        const operation: llvm.IntPredicate = switch (op) {
            .eq => .EQ,
            .neq => .NE,
            .lt => if (is_signed) llvm.IntPredicate.SLT else .ULT,
            .lte => if (is_signed) llvm.IntPredicate.SLE else .ULE,
            .gt => if (is_signed) llvm.IntPredicate.SGT else .UGT,
            .gte => if (is_signed) llvm.IntPredicate.SGE else .UGE,
        };
        return self.builder.buildICmp(operation, lhs, rhs, "");
    }

    fn airBlock(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];
        const inst_ty = self.air.typeOfIndex(inst);
        const parent_bb = self.context.createBasicBlock("Block");

        if (inst_ty.isNoReturn()) {
            try self.genBody(body);
            return null;
        }

        var break_bbs: BreakBasicBlocks = .{};
        defer break_bbs.deinit(self.gpa);

        var break_vals: BreakValues = .{};
        defer break_vals.deinit(self.gpa);

        try self.blocks.putNoClobber(self.gpa, inst, .{
            .parent_bb = parent_bb,
            .break_bbs = &break_bbs,
            .break_vals = &break_vals,
        });
        defer assert(self.blocks.remove(inst));

        try self.genBody(body);

        self.llvm_func.appendExistingBasicBlock(parent_bb);
        self.builder.positionBuilderAtEnd(parent_bb);

        // If the block does not return a value, we dont have to create a phi node.
        const is_body = inst_ty.zigTypeTag() == .Fn;
        if (!is_body and !inst_ty.hasRuntimeBitsIgnoreComptime()) return null;

        const raw_llvm_ty = try self.dg.llvmType(inst_ty);

        const llvm_ty = ty: {
            // If the zig tag type is a function, this represents an actual function body; not
            // a pointer to it. LLVM IR allows the call instruction to use function bodies instead
            // of function pointers, however the phi makes it a runtime value and therefore
            // the LLVM type has to be wrapped in a pointer.
            if (is_body or isByRef(inst_ty)) {
                break :ty raw_llvm_ty.pointerType(0);
            }
            break :ty raw_llvm_ty;
        };

        const phi_node = self.builder.buildPhi(llvm_ty, "");
        phi_node.addIncoming(
            break_vals.items.ptr,
            break_bbs.items.ptr,
            @intCast(c_uint, break_vals.items.len),
        );
        return phi_node;
    }

    fn airBr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const branch = self.air.instructions.items(.data)[inst].br;
        const block = self.blocks.get(branch.block_inst).?;

        // If the break doesn't break a value, then we don't have to add
        // the values to the lists.
        const operand_ty = self.air.typeOf(branch.operand);
        if (operand_ty.hasRuntimeBitsIgnoreComptime() or operand_ty.zigTypeTag() == .Fn) {
            const val = try self.resolveInst(branch.operand);

            // For the phi node, we need the basic blocks and the values of the
            // break instructions.
            try block.break_bbs.append(self.gpa, self.builder.getInsertBlock());
            try block.break_vals.append(self.gpa, val);
        }
        _ = self.builder.buildBr(block.parent_bb);
        return null;
    }

    fn airCondBr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond = try self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
        const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];

        const then_block = self.context.appendBasicBlock(self.llvm_func, "Then");
        const else_block = self.context.appendBasicBlock(self.llvm_func, "Else");
        _ = self.builder.buildCondBr(cond, then_block, else_block);

        self.builder.positionBuilderAtEnd(then_block);
        try self.genBody(then_body);

        self.builder.positionBuilderAtEnd(else_block);
        try self.genBody(else_body);

        // No need to reset the insert cursor since this instruction is noreturn.
        return null;
    }

    fn airSwitchBr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const cond = try self.resolveInst(pl_op.operand);
        const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
        const else_block = self.context.appendBasicBlock(self.llvm_func, "Else");
        const target = self.dg.module.getTarget();
        const llvm_usize = self.context.intType(target.cpu.arch.ptrBitWidth());
        const cond_int = if (cond.typeOf().getTypeKind() == .Pointer)
            self.builder.buildPtrToInt(cond, llvm_usize, "")
        else
            cond;
        const llvm_switch = self.builder.buildSwitch(cond_int, else_block, switch_br.data.cases_len);

        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;

        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
            const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + case.data.items_len + case_body.len;

            const case_block = self.context.appendBasicBlock(self.llvm_func, "Case");

            for (items) |item| {
                const llvm_item = try self.resolveInst(item);
                const llvm_int_item = if (llvm_item.typeOf().getTypeKind() == .Pointer)
                    llvm_item.constPtrToInt(llvm_usize)
                else
                    llvm_item;
                llvm_switch.addCase(llvm_int_item, case_block);
            }

            self.builder.positionBuilderAtEnd(case_block);
            try self.genBody(case_body);
        }

        self.builder.positionBuilderAtEnd(else_block);
        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];
        if (else_body.len != 0) {
            try self.genBody(else_body);
        } else {
            _ = self.builder.buildUnreachable();
        }

        // No need to reset the insert cursor since this instruction is noreturn.
        return null;
    }

    fn airLoop(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[loop.end..][0..loop.data.body_len];
        const loop_block = self.context.appendBasicBlock(self.llvm_func, "Loop");
        _ = self.builder.buildBr(loop_block);

        self.builder.positionBuilderAtEnd(loop_block);
        try self.genBody(body);

        // TODO instead of this logic, change AIR to have the property that
        // every block is guaranteed to end with a noreturn instruction.
        // Then we can simply rely on the fact that a repeat or break instruction
        // would have been emitted already. Also the main loop in genBody can
        // be while(true) instead of for(body), which will eliminate 1 branch on
        // a hot path.
        if (body.len == 0 or !self.air.typeOfIndex(body[body.len - 1]).isNoReturn()) {
            _ = self.builder.buildBr(loop_block);
        }
        return null;
    }

    fn airArrayToSlice(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        const array_ty = operand_ty.childType();
        const llvm_usize = try self.dg.llvmType(Type.usize);
        const len = llvm_usize.constInt(array_ty.arrayLen(), .False);
        const slice_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
        if (!array_ty.hasRuntimeBitsIgnoreComptime()) {
            return self.builder.buildInsertValue(slice_llvm_ty.getUndef(), len, 1, "");
        }
        const operand = try self.resolveInst(ty_op.operand);
        const indices: [2]*const llvm.Value = .{
            llvm_usize.constNull(), llvm_usize.constNull(),
        };
        const ptr = self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
        const partial = self.builder.buildInsertValue(slice_llvm_ty.getUndef(), ptr, 0, "");
        return self.builder.buildInsertValue(partial, len, 1, "");
    }

    fn airIntToFloat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand_scalar_ty = operand_ty.scalarType();
        const dest_ty = self.air.typeOfIndex(inst);
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);

        if (operand_scalar_ty.isSignedInt()) {
            return self.builder.buildSIToFP(operand, dest_llvm_ty, "");
        } else {
            return self.builder.buildUIToFP(operand, dest_llvm_ty, "");
        }
    }

    fn airFloatToInt(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const dest_ty = self.air.typeOfIndex(inst);
        const dest_scalar_ty = dest_ty.scalarType();
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);

        // TODO set fast math flag

        if (dest_scalar_ty.isSignedInt()) {
            return self.builder.buildFPToSI(operand, dest_llvm_ty, "");
        } else {
            return self.builder.buildFPToUI(operand, dest_llvm_ty, "");
        }
    }

    fn airSliceField(self: *FuncGen, inst: Air.Inst.Index, index: c_uint) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        return self.builder.buildExtractValue(operand, index, "");
    }

    fn airPtrSliceFieldPtr(self: *FuncGen, inst: Air.Inst.Index, index: c_uint) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const slice_ptr = try self.resolveInst(ty_op.operand);

        return self.builder.buildStructGEP(slice_ptr, index, "");
    }

    fn airSliceElemVal(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const slice_ty = self.air.typeOf(bin_op.lhs);
        if (!slice_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        const ptr = self.sliceElemPtr(slice, index);
        return self.load(ptr, slice_ty);
    }

    fn airSliceElemPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        return self.sliceElemPtr(slice, index);
    }

    fn airArrayElemVal(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const array_ty = self.air.typeOf(bin_op.lhs);
        const array_llvm_val = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        if (isByRef(array_ty)) {
            const indices: [2]*const llvm.Value = .{ self.context.intType(32).constNull(), rhs };
            const elem_ptr = self.builder.buildInBoundsGEP(array_llvm_val, &indices, indices.len, "");
            const elem_ty = array_ty.childType();
            if (isByRef(elem_ty)) {
                return elem_ptr;
            } else {
                return self.builder.buildLoad(elem_ptr, "");
            }
        }

        // This branch can be reached for vectors, which are always by-value.
        return self.builder.buildExtractElement(array_llvm_val, rhs, "");
    }

    fn airPtrElemVal(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        if (!ptr_ty.isVolatilePtr() and self.liveness.isUnused(inst)) return null;

        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const ptr = if (ptr_ty.isSinglePointer()) ptr: {
            // If this is a single-item pointer to an array, we need another index in the GEP.
            const indices: [2]*const llvm.Value = .{ self.context.intType(32).constNull(), rhs };
            break :ptr self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        } else ptr: {
            const indices: [1]*const llvm.Value = .{rhs};
            break :ptr self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        };
        return self.load(ptr, ptr_ty);
    }

    fn airPtrElemPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType();
        if (!elem_ty.hasRuntimeBitsIgnoreComptime()) return self.dg.lowerPtrToVoid(ptr_ty);

        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        if (ptr_ty.isSinglePointer()) {
            // If this is a single-item pointer to an array, we need another index in the GEP.
            const indices: [2]*const llvm.Value = .{ self.context.intType(32).constNull(), rhs };
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        } else {
            const indices: [1]*const llvm.Value = .{rhs};
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        }
    }

    fn airStructFieldPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ptr = try self.resolveInst(struct_field.struct_operand);
        const struct_ptr_ty = self.air.typeOf(struct_field.struct_operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, struct_field.field_index);
    }

    fn airStructFieldPtrIndex(
        self: *FuncGen,
        inst: Air.Inst.Index,
        field_index: u32,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const struct_ptr = try self.resolveInst(ty_op.operand);
        const struct_ptr_ty = self.air.typeOf(ty_op.operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, field_index);
    }

    fn airStructFieldVal(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ty = self.air.typeOf(struct_field.struct_operand);
        const struct_llvm_val = try self.resolveInst(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = struct_ty.structFieldType(field_index);
        if (!field_ty.hasRuntimeBitsIgnoreComptime()) {
            return null;
        }
        const target = self.dg.module.getTarget();

        if (!isByRef(struct_ty)) {
            assert(!isByRef(field_ty));
            switch (struct_ty.zigTypeTag()) {
                .Struct => switch (struct_ty.containerLayout()) {
                    .Packed => {
                        const struct_obj = struct_ty.castTag(.@"struct").?.data;
                        const bit_offset = struct_obj.packedFieldBitOffset(target, field_index);
                        const containing_int = struct_llvm_val;
                        const shift_amt = containing_int.typeOf().constInt(bit_offset, .False);
                        const shifted_value = self.builder.buildLShr(containing_int, shift_amt, "");
                        const elem_llvm_ty = try self.dg.llvmType(field_ty);
                        if (field_ty.zigTypeTag() == .Float) {
                            const elem_bits = @intCast(c_uint, field_ty.bitSize(target));
                            const same_size_int = self.context.intType(elem_bits);
                            const truncated_int = self.builder.buildTrunc(shifted_value, same_size_int, "");
                            return self.builder.buildBitCast(truncated_int, elem_llvm_ty, "");
                        }
                        return self.builder.buildTrunc(shifted_value, elem_llvm_ty, "");
                    },
                    else => {
                        var ptr_ty_buf: Type.Payload.Pointer = undefined;
                        const llvm_field_index = llvmFieldIndex(struct_ty, field_index, target, &ptr_ty_buf).?;
                        return self.builder.buildExtractValue(struct_llvm_val, llvm_field_index, "");
                    },
                },
                .Union => {
                    return self.todo("airStructFieldVal byval union", .{});
                },
                else => unreachable,
            }
        }

        switch (struct_ty.zigTypeTag()) {
            .Struct => {
                assert(struct_ty.containerLayout() != .Packed);
                var ptr_ty_buf: Type.Payload.Pointer = undefined;
                const llvm_field_index = llvmFieldIndex(struct_ty, field_index, target, &ptr_ty_buf).?;
                const field_ptr = self.builder.buildStructGEP(struct_llvm_val, llvm_field_index, "");
                const field_ptr_ty = Type.initPayload(&ptr_ty_buf.base);
                return self.load(field_ptr, field_ptr_ty);
            },
            .Union => {
                const llvm_field_ty = try self.dg.llvmType(field_ty);
                const layout = struct_ty.unionGetLayout(target);
                const payload_index = @boolToInt(layout.tag_align >= layout.payload_align);
                const union_field_ptr = self.builder.buildStructGEP(struct_llvm_val, payload_index, "");
                const field_ptr = self.builder.buildBitCast(union_field_ptr, llvm_field_ty.pointerType(0), "");
                if (isByRef(field_ty)) {
                    return field_ptr;
                } else {
                    return self.builder.buildLoad(field_ptr, "");
                }
            },
            else => unreachable,
        }
    }

    fn airFieldParentPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        const field_ptr = try self.resolveInst(extra.field_ptr);

        const target = self.dg.module.getTarget();
        const struct_ty = self.air.getRefType(ty_pl.ty).childType();
        const field_offset = struct_ty.structFieldOffset(extra.field_index, target);

        const res_ty = try self.dg.llvmType(self.air.getRefType(ty_pl.ty));
        if (field_offset == 0) {
            return self.builder.buildBitCast(field_ptr, res_ty, "");
        }
        const llvm_usize_ty = self.context.intType(target.cpu.arch.ptrBitWidth());

        const field_ptr_int = self.builder.buildPtrToInt(field_ptr, llvm_usize_ty, "");
        const base_ptr_int = self.builder.buildNUWSub(field_ptr_int, llvm_usize_ty.constInt(field_offset, .False), "");
        return self.builder.buildIntToPtr(base_ptr_int, res_ty, "");
    }

    fn airNot(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);

        return self.builder.buildNot(operand, "");
    }

    fn airUnreach(self: *FuncGen, inst: Air.Inst.Index) ?*const llvm.Value {
        _ = inst;
        _ = self.builder.buildUnreachable();
        return null;
    }

    fn airDbgStmt(self: *FuncGen, inst: Air.Inst.Index) ?*const llvm.Value {
        const di_scope = self.di_scope orelse return null;
        const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
        self.prev_dbg_line = @intCast(c_uint, self.base_line + dbg_stmt.line + 1);
        self.prev_dbg_column = @intCast(c_uint, dbg_stmt.column + 1);
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        self.builder.setCurrentDebugLocation(self.prev_dbg_line, self.prev_dbg_column, di_scope, inlined_at);
        return null;
    }

    fn airDbgInlineBegin(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const dib = self.dg.object.di_builder orelse return null;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;

        const func = self.air.values[ty_pl.payload].castTag(.function).?.data;
        const decl_index = func.owner_decl;
        const decl = self.dg.module.declPtr(decl_index);
        const di_file = try self.dg.object.getDIFile(self.gpa, decl.src_namespace.file_scope);
        self.di_file = di_file;
        const line_number = decl.src_line + 1;
        const cur_debug_location = self.builder.getCurrentDebugLocation2();

        try self.dbg_inlined.append(self.gpa, .{
            .loc = @ptrCast(*llvm.DILocation, cur_debug_location),
            .scope = self.di_scope.?,
            .base_line = self.base_line,
        });

        const fqn = try decl.getFullyQualifiedName(self.dg.module);
        defer self.gpa.free(fqn);

        const is_internal_linkage = !self.dg.module.decl_exports.contains(decl_index);
        const subprogram = dib.createFunction(
            di_file.toScope(),
            decl.name,
            fqn,
            di_file,
            line_number,
            try self.dg.object.lowerDebugType(Type.initTag(.fn_void_no_args), .full),
            is_internal_linkage,
            true, // is definition
            line_number + func.lbrace_line, // scope line
            llvm.DIFlags.StaticMember,
            self.dg.module.comp.bin_file.options.optimize_mode != .Debug,
            null, // decl_subprogram
        );

        const lexical_block = dib.createLexicalBlock(subprogram.toScope(), di_file, line_number, 1);
        self.di_scope = lexical_block.toScope();
        self.base_line = decl.src_line;
        return null;
    }

    fn airDbgInlineEnd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.dg.object.di_builder == null) return null;
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;

        const func = self.air.values[ty_pl.payload].castTag(.function).?.data;
        const mod = self.dg.module;
        const decl = mod.declPtr(func.owner_decl);
        const di_file = try self.dg.object.getDIFile(self.gpa, decl.src_namespace.file_scope);
        self.di_file = di_file;
        const old = self.dbg_inlined.pop();
        self.di_scope = old.scope;
        self.base_line = old.base_line;
        return null;
    }

    fn airDbgBlockBegin(self: *FuncGen) !?*const llvm.Value {
        const dib = self.dg.object.di_builder orelse return null;
        const old_scope = self.di_scope.?;
        try self.dbg_block_stack.append(self.gpa, old_scope);
        const lexical_block = dib.createLexicalBlock(old_scope, self.di_file.?, self.prev_dbg_line, self.prev_dbg_column);
        self.di_scope = lexical_block.toScope();
        return null;
    }

    fn airDbgBlockEnd(self: *FuncGen) !?*const llvm.Value {
        if (self.dg.object.di_builder == null) return null;
        self.di_scope = self.dbg_block_stack.pop();
        return null;
    }

    fn airDbgVarPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const dib = self.dg.object.di_builder orelse return null;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);
        const ptr_ty = self.air.typeOf(pl_op.operand);

        const di_local_var = dib.createAutoVariable(
            self.di_scope.?,
            name.ptr,
            self.di_file.?,
            self.prev_dbg_line,
            try self.dg.object.lowerDebugType(ptr_ty.childType(), .full),
            true, // always preserve
            0, // flags
        );
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        const debug_loc = llvm.getDebugLoc(self.prev_dbg_line, self.prev_dbg_column, self.di_scope.?, inlined_at);
        const insert_block = self.builder.getInsertBlock();
        _ = dib.insertDeclareAtEnd(operand, di_local_var, debug_loc, insert_block);
        return null;
    }

    fn airDbgVarVal(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const dib = self.dg.object.di_builder orelse return null;
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const operand_ty = self.air.typeOf(pl_op.operand);
        const name = self.air.nullTerminatedString(pl_op.payload);

        const di_local_var = dib.createAutoVariable(
            self.di_scope.?,
            name.ptr,
            self.di_file.?,
            self.prev_dbg_line,
            try self.dg.object.lowerDebugType(operand_ty, .full),
            true, // always preserve
            0, // flags
        );
        const inlined_at = if (self.dbg_inlined.items.len > 0)
            self.dbg_inlined.items[self.dbg_inlined.items.len - 1].loc
        else
            null;
        const debug_loc = llvm.getDebugLoc(self.prev_dbg_line, self.prev_dbg_column, self.di_scope.?, inlined_at);
        const insert_block = self.builder.getInsertBlock();
        if (isByRef(operand_ty)) {
            _ = dib.insertDeclareAtEnd(operand, di_local_var, debug_loc, insert_block);
        } else {
            _ = dib.insertDbgValueIntrinsicAtEnd(operand, di_local_var, debug_loc, insert_block);
        }
        return null;
    }

    fn airAssembly(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        // Eventually, the Zig compiler needs to be reworked to have inline assembly go
        // through the same parsing code regardless of backend, and have LLVM-flavored
        // inline assembly be *output* from that assembler.
        // We don't have such an assembler implemented yet though. For now, this
        // implementation feeds the inline assembly code directly to LLVM, same
        // as stage1.

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);
        const is_volatile = @truncate(u1, extra.data.flags >> 31) != 0;
        const clobbers_len = @truncate(u31, extra.data.flags);
        var extra_i: usize = extra.end;

        if (!is_volatile and self.liveness.isUnused(inst)) return null;

        const outputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.outputs_len]);
        extra_i += outputs.len;
        const inputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.inputs_len]);
        extra_i += inputs.len;

        if (outputs.len > 1) {
            return self.todo("implement llvm codegen for asm with more than 1 output", .{});
        }

        var llvm_constraints: std.ArrayListUnmanaged(u8) = .{};
        defer llvm_constraints.deinit(self.gpa);

        var arena_allocator = std.heap.ArenaAllocator.init(self.gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const llvm_params_len = inputs.len;
        const llvm_param_types = try arena.alloc(*const llvm.Type, llvm_params_len);
        const llvm_param_values = try arena.alloc(*const llvm.Value, llvm_params_len);
        var llvm_param_i: usize = 0;
        var total_i: usize = 0;

        for (outputs) |output| {
            if (output != .none) {
                return self.todo("implement inline asm with non-returned output", .{});
            }
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += constraint.len / 4 + 1;

            try llvm_constraints.ensureUnusedCapacity(self.gpa, constraint.len + 1);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendAssumeCapacity('=');
            llvm_constraints.appendSliceAssumeCapacity(constraint[1..]);

            total_i += 1;
        }

        const input_start_extra_i = extra_i;
        for (inputs) |input| {
            const input_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(input_bytes, 0);
            const input_name = std.mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + input_name.len + 1) / 4 + 1;

            const arg_llvm_value = try self.resolveInst(input);

            llvm_param_values[llvm_param_i] = arg_llvm_value;
            llvm_param_types[llvm_param_i] = arg_llvm_value.typeOf();

            try llvm_constraints.ensureUnusedCapacity(self.gpa, constraint.len + 1);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendSliceAssumeCapacity(constraint);

            llvm_param_i += 1;
            total_i += 1;
        }

        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;

                try llvm_constraints.ensureUnusedCapacity(self.gpa, clobber.len + 4);
                if (total_i != 0) {
                    llvm_constraints.appendAssumeCapacity(',');
                }
                llvm_constraints.appendSliceAssumeCapacity("~{");
                llvm_constraints.appendSliceAssumeCapacity(clobber);
                llvm_constraints.appendSliceAssumeCapacity("}");

                total_i += 1;
            }
        }
        const asm_source = std.mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];

        // hackety hacks until stage2 has proper inline asm in the frontend.
        var rendered_template = std.ArrayList(u8).init(self.gpa);
        defer rendered_template.deinit();

        const State = enum { start, percent, input };

        var state: State = .start;

        var name_start: usize = undefined;
        for (asm_source) |byte, i| {
            switch (state) {
                .start => switch (byte) {
                    '%' => state = .percent,
                    '$' => try rendered_template.appendSlice("$$"),
                    else => try rendered_template.append(byte),
                },
                .percent => switch (byte) {
                    '%' => {
                        try rendered_template.append('%');
                        state = .start;
                    },
                    '[' => {
                        try rendered_template.append('$');
                        name_start = i + 1;
                        state = .input;
                    },
                    else => {
                        try rendered_template.append('%');
                        try rendered_template.append(byte);
                        state = .start;
                    },
                },
                .input => switch (byte) {
                    ']' => {
                        const name = asm_source[name_start..i];
                        state = .start;

                        extra_i = input_start_extra_i;
                        for (inputs) |_, input_i| {
                            const input_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
                            const constraint = std.mem.sliceTo(input_bytes, 0);
                            const input_name = std.mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
                            extra_i += (constraint.len + input_name.len + 1) / 4 + 1;

                            if (std.mem.eql(u8, name, input_name)) {
                                try rendered_template.writer().print("{d}", .{input_i});
                                break;
                            }
                        } else {
                            return self.todo("TODO validate asm in Sema", .{});
                        }
                    },
                    else => {},
                },
            }
        }

        const ret_ty = self.air.typeOfIndex(inst);
        const ret_llvm_ty = try self.dg.llvmType(ret_ty);
        const llvm_fn_ty = llvm.functionType(
            ret_llvm_ty,
            llvm_param_types.ptr,
            @intCast(c_uint, llvm_param_types.len),
            .False,
        );
        const asm_fn = llvm.getInlineAsm(
            llvm_fn_ty,
            rendered_template.items.ptr,
            rendered_template.items.len,
            llvm_constraints.items.ptr,
            llvm_constraints.items.len,
            llvm.Bool.fromBool(is_volatile),
            .False,
            .ATT,
            .False,
        );
        return self.builder.buildCall(
            asm_fn,
            llvm_param_values.ptr,
            @intCast(c_uint, llvm_param_values.len),
            .C,
            .Auto,
            "",
        );
    }

    fn airIsNonNull(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
        invert: bool,
        pred: llvm.IntPredicate,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.air.typeOf(un_op);
        const optional_ty = if (operand_is_ptr) operand_ty.childType() else operand_ty;
        if (optional_ty.isPtrLikeOptional()) {
            const optional_llvm_ty = try self.dg.llvmType(optional_ty);
            const loaded = if (operand_is_ptr) self.builder.buildLoad(operand, "") else operand;
            return self.builder.buildICmp(pred, loaded, optional_llvm_ty.constNull(), "");
        }

        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            const loaded = if (operand_is_ptr) self.builder.buildLoad(operand, "") else operand;
            if (invert) {
                return self.builder.buildNot(loaded, "");
            } else {
                return loaded;
            }
        }

        const is_by_ref = operand_is_ptr or isByRef(optional_ty);
        const non_null_bit = self.optIsNonNull(operand, is_by_ref);
        if (invert) {
            return self.builder.buildNot(non_null_bit, "");
        } else {
            return non_null_bit;
        }
    }

    fn airIsErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        op: llvm.IntPredicate,
        operand_is_ptr: bool,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const err_union_ty = self.air.typeOf(un_op);
        const payload_ty = err_union_ty.errorUnionPayload();
        const err_set_ty = try self.dg.llvmType(Type.initTag(.anyerror));
        const zero = err_set_ty.constNull();

        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            const loaded = if (operand_is_ptr) self.builder.buildLoad(operand, "") else operand;
            return self.builder.buildICmp(op, loaded, zero, "");
        }

        if (operand_is_ptr or isByRef(err_union_ty)) {
            const err_field_ptr = self.builder.buildStructGEP(operand, 0, "");
            const loaded = self.builder.buildLoad(err_field_ptr, "");
            return self.builder.buildICmp(op, loaded, zero, "");
        }

        const loaded = self.builder.buildExtractValue(operand, 0, "");
        return self.builder.buildICmp(op, loaded, zero, "");
    }

    fn airOptionalPayloadPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.air.typeOf(ty_op.operand).childType();
        const result_ty = self.air.getRefType(ty_op.ty);
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            // We have a pointer to a zero-bit value and we need to return
            // a pointer to a zero-bit value.

            // TODO once we update to LLVM 14 this bitcast won't be necessary.
            const res_ptr_ty = try self.dg.llvmType(result_ty);
            return self.builder.buildBitCast(operand, res_ptr_ty, "");
        }
        if (optional_ty.isPtrLikeOptional()) {
            // The payload and the optional are the same value.
            return operand;
        }
        const index_type = self.context.intType(32);
        const indices: [2]*const llvm.Value = .{
            index_type.constNull(), // dereference the pointer
            index_type.constNull(), // first field is the payload
        };
        return self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
    }

    fn airOptionalPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.air.typeOf(ty_op.operand).childType();
        const result_ty = self.air.getRefType(ty_op.ty);
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        const non_null_bit = self.context.intType(1).constAllOnes();
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            // We have a pointer to a i1. We need to set it to 1 and then return the same pointer.
            _ = self.builder.buildStore(non_null_bit, operand);

            // TODO once we update to LLVM 14 this bitcast won't be necessary.
            const res_ptr_ty = try self.dg.llvmType(result_ty);
            return self.builder.buildBitCast(operand, res_ptr_ty, "");
        }
        if (optional_ty.isPtrLikeOptional()) {
            // The payload and the optional are the same value.
            // Setting to non-null will be done when the payload is set.
            return operand;
        }
        const index_type = self.context.intType(32);
        {
            // First set the non-null bit.
            const indices: [2]*const llvm.Value = .{
                index_type.constNull(), // dereference the pointer
                index_type.constInt(1, .False), // second field is the payload
            };
            const non_null_ptr = self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
            _ = self.builder.buildStore(non_null_bit, non_null_ptr);
        }
        // Then return the payload pointer (only if it's used).
        if (self.liveness.isUnused(inst))
            return null;
        const indices: [2]*const llvm.Value = .{
            index_type.constNull(), // dereference the pointer
            index_type.constNull(), // first field is the payload
        };
        return self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
    }

    fn airOptionalPayload(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.air.typeOf(ty_op.operand);
        const payload_ty = self.air.typeOfIndex(inst);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) return null;

        if (optional_ty.isPtrLikeOptional()) {
            // Payload value is the same as the optional value.
            return operand;
        }

        return self.optPayloadHandle(operand, isByRef(payload_ty));
    }

    fn airErrUnionPayload(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const result_ty = self.air.getRefType(ty_op.ty);
        const payload_ty = if (operand_is_ptr) result_ty.childType() else result_ty;

        const target = self.dg.module.getTarget();
        const offset: u8 = if (payload_ty.abiAlignment(target) > Type.anyerror.abiSize(target)) 2 else 1;

        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            if (!operand_is_ptr) return null;

            // TODO once we update to LLVM 14 this bitcast won't be necessary.
            const res_ptr_ty = try self.dg.llvmType(result_ty);
            return self.builder.buildBitCast(operand, res_ptr_ty, "");
        }
        if (operand_is_ptr or isByRef(payload_ty)) {
            return self.builder.buildStructGEP(operand, offset, "");
        }
        return self.builder.buildExtractValue(operand, offset, "");
    }

    fn airErrUnionErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const err_set_ty = if (operand_is_ptr) operand_ty.childType() else operand_ty;

        const payload_ty = err_set_ty.errorUnionPayload();
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            if (!operand_is_ptr) return operand;
            return self.builder.buildLoad(operand, "");
        }

        if (operand_is_ptr or isByRef(err_set_ty)) {
            const err_field_ptr = self.builder.buildStructGEP(operand, 0, "");
            return self.builder.buildLoad(err_field_ptr, "");
        }

        return self.builder.buildExtractValue(operand, 0, "");
    }

    fn airErrUnionPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const error_set_ty = self.air.typeOf(ty_op.operand).childType();

        const error_ty = error_set_ty.errorUnionSet();
        const payload_ty = error_set_ty.errorUnionPayload();
        const non_error_val = try self.dg.genTypedValue(.{ .ty = error_ty, .val = Value.zero });
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            // We have a pointer to a i1. We need to set it to 1 and then return the same pointer.
            _ = self.builder.buildStore(non_error_val, operand);
            return operand;
        }
        const index_type = self.context.intType(32);
        {
            // First set the non-error value.
            const indices: [2]*const llvm.Value = .{
                index_type.constNull(), // dereference the pointer
                index_type.constNull(), // first field is the payload
            };
            const non_null_ptr = self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
            _ = self.builder.buildStore(non_error_val, non_null_ptr);
        }
        // Then return the payload pointer (only if it is used).
        if (self.liveness.isUnused(inst))
            return null;

        const target = self.dg.module.getTarget();
        const payload_offset: u8 = if (payload_ty.abiAlignment(target) > Type.anyerror.abiSize(target)) 2 else 1;
        const indices: [2]*const llvm.Value = .{
            index_type.constNull(), // dereference the pointer
            index_type.constInt(payload_offset, .False), // second field is the payload
        };
        return self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
    }

    fn airWrapOptional(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const payload_ty = self.air.typeOf(ty_op.operand);
        const non_null_bit = self.context.intType(1).constAllOnes();
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) return non_null_bit;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.air.typeOfIndex(inst);
        if (optional_ty.isPtrLikeOptional()) return operand;
        const llvm_optional_ty = try self.dg.llvmType(optional_ty);
        if (isByRef(optional_ty)) {
            const optional_ptr = self.buildAlloca(llvm_optional_ty);
            const payload_ptr = self.builder.buildStructGEP(optional_ptr, 0, "");
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = payload_ty,
            };
            const payload_ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            self.store(payload_ptr, payload_ptr_ty, operand, .NotAtomic);
            const non_null_ptr = self.builder.buildStructGEP(optional_ptr, 1, "");
            _ = self.builder.buildStore(non_null_bit, non_null_ptr);
            return optional_ptr;
        }
        const partial = self.builder.buildInsertValue(llvm_optional_ty.getUndef(), operand, 0, "");
        return self.builder.buildInsertValue(partial, non_null_bit, 1, "");
    }

    fn airWrapErrUnionPayload(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const payload_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            return operand;
        }
        const inst_ty = self.air.typeOfIndex(inst);
        const ok_err_code = self.context.intType(16).constNull();
        const err_un_llvm_ty = try self.dg.llvmType(inst_ty);

        const target = self.dg.module.getTarget();
        const payload_offset: u8 = if (payload_ty.abiAlignment(target) > Type.anyerror.abiSize(target)) 2 else 1;
        if (isByRef(inst_ty)) {
            const result_ptr = self.buildAlloca(err_un_llvm_ty);
            const err_ptr = self.builder.buildStructGEP(result_ptr, 0, "");
            _ = self.builder.buildStore(ok_err_code, err_ptr);
            const payload_ptr = self.builder.buildStructGEP(result_ptr, payload_offset, "");
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = payload_ty,
            };
            const payload_ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            self.store(payload_ptr, payload_ptr_ty, operand, .NotAtomic);
            return result_ptr;
        }

        const partial = self.builder.buildInsertValue(err_un_llvm_ty.getUndef(), ok_err_code, 0, "");
        return self.builder.buildInsertValue(partial, operand, payload_offset, "");
    }

    fn airWrapErrUnionErr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const err_un_ty = self.air.typeOfIndex(inst);
        const payload_ty = err_un_ty.errorUnionPayload();
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            return operand;
        }
        const err_un_llvm_ty = try self.dg.llvmType(err_un_ty);

        const target = self.dg.module.getTarget();
        const payload_offset: u8 = if (payload_ty.abiAlignment(target) > Type.anyerror.abiSize(target)) 2 else 1;
        if (isByRef(err_un_ty)) {
            const result_ptr = self.buildAlloca(err_un_llvm_ty);
            const err_ptr = self.builder.buildStructGEP(result_ptr, 0, "");
            _ = self.builder.buildStore(operand, err_ptr);
            const payload_ptr = self.builder.buildStructGEP(result_ptr, payload_offset, "");
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = payload_ty,
            };
            const payload_ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            // TODO store undef to payload_ptr
            _ = payload_ptr;
            _ = payload_ptr_ty;
            return result_ptr;
        }

        const partial = self.builder.buildInsertValue(err_un_llvm_ty.getUndef(), operand, 0, "");
        // TODO set payload bytes to undef
        return partial;
    }

    fn airWasmMemorySize(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const index = pl_op.payload;
        const llvm_u32 = self.context.intType(32);
        const llvm_fn = self.getIntrinsic("llvm.wasm.memory.size", &.{llvm_u32});
        const args: [1]*const llvm.Value = .{llvm_u32.constInt(index, .False)};
        return self.builder.buildCall(llvm_fn, &args, args.len, .Fast, .Auto, "");
    }

    fn airWasmMemoryGrow(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const index = pl_op.payload;
        const operand = try self.resolveInst(pl_op.operand);
        const llvm_u32 = self.context.intType(32);
        const llvm_fn = self.getIntrinsic("llvm.wasm.memory.grow", &.{llvm_u32});
        const args: [2]*const llvm.Value = .{
            llvm_u32.constInt(index, .False),
            operand,
        };
        return self.builder.buildCall(llvm_fn, &args, args.len, .Fast, .Auto, "");
    }

    fn airMin(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const scalar_ty = self.air.typeOfIndex(inst).scalarType();

        if (scalar_ty.isAnyFloat()) return self.builder.buildMinNum(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildSMin(lhs, rhs, "");
        return self.builder.buildUMin(lhs, rhs, "");
    }

    fn airMax(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const scalar_ty = self.air.typeOfIndex(inst).scalarType();

        if (scalar_ty.isAnyFloat()) return self.builder.buildMaxNum(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildSMax(lhs, rhs, "");
        return self.builder.buildUMax(lhs, rhs, "");
    }

    fn airSlice(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const llvm_slice_ty = try self.dg.llvmType(inst_ty);

        // In case of slicing a global, the result type looks something like `{ i8*, i64 }`
        // but `ptr` is pointing to the global directly. If it's an array, we would want to
        // do GEP(0,0), or we can just bitcast it to be correct, like we do here.
        // This prevents an assertion failure.
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const ptr_ty = inst_ty.slicePtrFieldType(&buf);
        const ptr_llvm_ty = try self.dg.llvmType(ptr_ty);
        const casted_ptr = self.builder.buildBitCast(ptr, ptr_llvm_ty, "");
        const partial = self.builder.buildInsertValue(llvm_slice_ty.getUndef(), casted_ptr, 0, "");
        return self.builder.buildInsertValue(partial, len, 1, "");
    }

    fn airAdd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.builder.buildFAdd(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildNSWAdd(lhs, rhs, "");
        return self.builder.buildNUWAdd(lhs, rhs, "");
    }

    fn airAddWrap(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.builder.buildAdd(lhs, rhs, "");
    }

    fn airAddSat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float add", .{});
        if (scalar_ty.isSignedInt()) return self.builder.buildSAddSat(lhs, rhs, "");

        return self.builder.buildUAddSat(lhs, rhs, "");
    }

    fn airSub(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.builder.buildFSub(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildNSWSub(lhs, rhs, "");
        return self.builder.buildNUWSub(lhs, rhs, "");
    }

    fn airSubWrap(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.builder.buildSub(lhs, rhs, "");
    }

    fn airSubSat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float sub", .{});
        if (scalar_ty.isSignedInt()) return self.builder.buildSSubSat(lhs, rhs, "");
        return self.builder.buildUSubSat(lhs, rhs, "");
    }

    fn airMul(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.builder.buildFMul(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildNSWMul(lhs, rhs, "");
        return self.builder.buildNUWMul(lhs, rhs, "");
    }

    fn airMulWrap(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.builder.buildMul(lhs, rhs, "");
    }

    fn airMulSat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float mul", .{});
        if (scalar_ty.isSignedInt()) return self.builder.buildSMulFixSat(lhs, rhs, "");
        return self.builder.buildUMulFixSat(lhs, rhs, "");
    }

    fn airDivFloat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.builder.buildFDiv(lhs, rhs, "");
    }

    fn airDivTrunc(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isRuntimeFloat()) {
            const result = self.builder.buildFDiv(lhs, rhs, "");
            return self.callTrunc(result, inst_ty);
        }
        if (scalar_ty.isSignedInt()) return self.builder.buildSDiv(lhs, rhs, "");
        return self.builder.buildUDiv(lhs, rhs, "");
    }

    fn airDivFloor(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isRuntimeFloat()) {
            const result = self.builder.buildFDiv(lhs, rhs, "");
            return try self.callFloor(result, inst_ty);
        }
        if (scalar_ty.isSignedInt()) {
            // const d = @divTrunc(a, b);
            // const r = @rem(a, b);
            // return if (r == 0) d else d - ((a < 0) ^ (b < 0));
            const result_llvm_ty = try self.dg.llvmType(inst_ty);
            const zero = result_llvm_ty.constNull();
            const div_trunc = self.builder.buildSDiv(lhs, rhs, "");
            const rem = self.builder.buildSRem(lhs, rhs, "");
            const rem_eq_0 = self.builder.buildICmp(.EQ, rem, zero, "");
            const a_lt_0 = self.builder.buildICmp(.SLT, lhs, zero, "");
            const b_lt_0 = self.builder.buildICmp(.SLT, rhs, zero, "");
            const a_b_xor = self.builder.buildXor(a_lt_0, b_lt_0, "");
            const a_b_xor_ext = self.builder.buildZExt(a_b_xor, div_trunc.typeOf(), "");
            const d_sub_xor = self.builder.buildSub(div_trunc, a_b_xor_ext, "");
            return self.builder.buildSelect(rem_eq_0, div_trunc, d_sub_xor, "");
        }
        return self.builder.buildUDiv(lhs, rhs, "");
    }

    fn airDivExact(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isRuntimeFloat()) return self.builder.buildFDiv(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildExactSDiv(lhs, rhs, "");
        return self.builder.buildExactUDiv(lhs, rhs, "");
    }

    fn airRem(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isRuntimeFloat()) return self.builder.buildFRem(lhs, rhs, "");
        if (scalar_ty.isSignedInt()) return self.builder.buildSRem(lhs, rhs, "");
        return self.builder.buildURem(lhs, rhs, "");
    }

    fn airMod(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const inst_llvm_ty = try self.dg.llvmType(inst_ty);
        const scalar_ty = inst_ty.scalarType();

        if (scalar_ty.isRuntimeFloat()) {
            const a = self.builder.buildFRem(lhs, rhs, "");
            const b = self.builder.buildFAdd(a, rhs, "");
            const c = self.builder.buildFRem(b, rhs, "");
            const zero = inst_llvm_ty.constNull();
            const ltz = self.builder.buildFCmp(.OLT, lhs, zero, "");
            return self.builder.buildSelect(ltz, c, a, "");
        }
        if (scalar_ty.isSignedInt()) {
            const a = self.builder.buildSRem(lhs, rhs, "");
            const b = self.builder.buildNSWAdd(a, rhs, "");
            const c = self.builder.buildSRem(b, rhs, "");
            const zero = inst_llvm_ty.constNull();
            const ltz = self.builder.buildICmp(.SLT, lhs, zero, "");
            return self.builder.buildSelect(ltz, c, a, "");
        }
        return self.builder.buildURem(lhs, rhs, "");
    }

    fn airPtrAdd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const base_ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        if (ptr_ty.ptrSize() == .One) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            const indices: [2]*const llvm.Value = .{
                self.context.intType(32).constNull(), offset,
            };
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        } else {
            const indices: [1]*const llvm.Value = .{offset};
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        }
    }

    fn airPtrSub(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const base_ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const negative_offset = self.builder.buildNeg(offset, "");
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        if (ptr_ty.ptrSize() == .One) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            const indices: [2]*const llvm.Value = .{
                self.context.intType(32).constNull(), negative_offset,
            };
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        } else {
            const indices: [1]*const llvm.Value = .{negative_offset};
            return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
        }
    }

    fn airOverflow(
        self: *FuncGen,
        inst: Air.Inst.Index,
        signed_intrinsic: []const u8,
        unsigned_intrinsic: []const u8,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.air.typeOf(extra.lhs);

        const intrinsic_name = if (lhs_ty.isSignedInt()) signed_intrinsic else unsigned_intrinsic;

        const llvm_lhs_ty = try self.dg.llvmType(lhs_ty);

        const llvm_fn = self.getIntrinsic(intrinsic_name, &.{llvm_lhs_ty});
        const result_struct = self.builder.buildCall(llvm_fn, &[_]*const llvm.Value{ lhs, rhs }, 2, .Fast, .Auto, "");
        return result_struct;
    }

    fn airMulAdd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

        const mulend1 = try self.resolveInst(extra.lhs);
        const mulend2 = try self.resolveInst(extra.rhs);
        const addend = try self.resolveInst(pl_op.operand);

        const ty = self.air.typeOfIndex(inst);
        const llvm_ty = try self.dg.llvmType(ty);
        const scalar_ty = ty.scalarType();
        const target = self.dg.module.getTarget();

        const Strat = union(enum) {
            intrinsic,
            libc: [*:0]const u8,
        };

        const strat: Strat = switch (scalar_ty.floatBits(target)) {
            16, 32, 64 => Strat.intrinsic,
            80 => if (CType.longdouble.sizeInBits(target) == 80) Strat{ .intrinsic = {} } else Strat{ .libc = "__fmax" },
            // LLVM always lowers the fma builtin for f128 to fmal, which is for `long double`.
            // On some targets this will be correct; on others it will be incorrect.
            128 => if (CType.longdouble.sizeInBits(target) == 128) Strat{ .intrinsic = {} } else Strat{ .libc = "fmaq" },
            else => unreachable,
        };

        switch (strat) {
            .intrinsic => {
                const llvm_fn = self.getIntrinsic("llvm.fma", &.{llvm_ty});
                const params = [_]*const llvm.Value{ mulend1, mulend2, addend };
                return self.builder.buildCall(llvm_fn, &params, params.len, .C, .Auto, "");
            },
            .libc => |fn_name| {
                const scalar_llvm_ty = try self.dg.llvmType(scalar_ty);
                const llvm_fn = self.dg.object.llvm_module.getNamedFunction(fn_name) orelse b: {
                    const param_types = [_]*const llvm.Type{ scalar_llvm_ty, scalar_llvm_ty, scalar_llvm_ty };
                    const fn_type = llvm.functionType(scalar_llvm_ty, &param_types, param_types.len, .False);
                    break :b self.dg.object.llvm_module.addFunction(fn_name, fn_type);
                };

                if (ty.zigTypeTag() == .Vector) {
                    const llvm_i32 = self.context.intType(32);
                    const vector_llvm_ty = try self.dg.llvmType(ty);

                    var i: usize = 0;
                    var vector = vector_llvm_ty.getUndef();
                    while (i < ty.vectorLen()) : (i += 1) {
                        const index_i32 = llvm_i32.constInt(i, .False);

                        const mulend1_elem = self.builder.buildExtractElement(mulend1, index_i32, "");
                        const mulend2_elem = self.builder.buildExtractElement(mulend2, index_i32, "");
                        const addend_elem = self.builder.buildExtractElement(addend, index_i32, "");

                        const params = [_]*const llvm.Value{ mulend1_elem, mulend2_elem, addend_elem };
                        const mul_add = self.builder.buildCall(llvm_fn, &params, params.len, .C, .Auto, "");

                        vector = self.builder.buildInsertElement(vector, mul_add, index_i32, "");
                    }

                    return vector;
                } else {
                    const params = [_]*const llvm.Value{ mulend1, mulend2, addend };
                    return self.builder.buildCall(llvm_fn, &params, params.len, .C, .Auto, "");
                }
            },
        }
    }

    fn airShlWithOverflow(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.air.typeOf(extra.lhs);
        const rhs_ty = self.air.typeOf(extra.rhs);
        const dest_ty = self.air.typeOfIndex(inst);
        const llvm_dest_ty = try self.dg.llvmType(dest_ty);

        const tg = self.dg.module.getTarget();

        const casted_rhs = if (rhs_ty.bitSize(tg) < lhs_ty.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_ty), "")
        else
            rhs;

        const result = self.builder.buildShl(lhs, casted_rhs, "");
        const reconstructed = if (lhs_ty.isSignedInt())
            self.builder.buildAShr(result, casted_rhs, "")
        else
            self.builder.buildLShr(result, casted_rhs, "");

        const overflow_bit = self.builder.buildICmp(.NE, lhs, reconstructed, "");

        const partial = self.builder.buildInsertValue(llvm_dest_ty.getUndef(), result, 0, "");
        return self.builder.buildInsertValue(partial, overflow_bit, 1, "");
    }

    fn airAnd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.builder.buildAnd(lhs, rhs, "");
    }

    fn airOr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.builder.buildOr(lhs, rhs, "");
    }

    fn airXor(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.builder.buildXor(lhs, rhs, "");
    }

    fn airShlExact(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.air.typeOf(bin_op.lhs);
        const rhs_ty = self.air.typeOf(bin_op.rhs);
        const lhs_scalar_ty = lhs_ty.scalarType();
        const rhs_scalar_ty = rhs_ty.scalarType();

        const tg = self.dg.module.getTarget();

        const casted_rhs = if (rhs_scalar_ty.bitSize(tg) < lhs_scalar_ty.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_ty), "")
        else
            rhs;
        if (lhs_scalar_ty.isSignedInt()) return self.builder.buildNSWShl(lhs, casted_rhs, "");
        return self.builder.buildNUWShl(lhs, casted_rhs, "");
    }

    fn airShl(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_type = self.air.typeOf(bin_op.lhs);
        const rhs_type = self.air.typeOf(bin_op.rhs);
        const lhs_scalar_ty = lhs_type.scalarType();
        const rhs_scalar_ty = rhs_type.scalarType();

        const tg = self.dg.module.getTarget();

        const casted_rhs = if (rhs_scalar_ty.bitSize(tg) < lhs_scalar_ty.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_type), "")
        else
            rhs;
        return self.builder.buildShl(lhs, casted_rhs, "");
    }

    fn airShlSat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.air.typeOf(bin_op.lhs);
        const rhs_ty = self.air.typeOf(bin_op.rhs);
        const lhs_scalar_ty = lhs_ty.scalarType();
        const rhs_scalar_ty = rhs_ty.scalarType();

        const tg = self.dg.module.getTarget();

        const casted_rhs = if (rhs_scalar_ty.bitSize(tg) < lhs_scalar_ty.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_ty), "")
        else
            rhs;
        if (lhs_scalar_ty.isSignedInt()) return self.builder.buildSShlSat(lhs, casted_rhs, "");
        return self.builder.buildUShlSat(lhs, casted_rhs, "");
    }

    fn airShr(self: *FuncGen, inst: Air.Inst.Index, is_exact: bool) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.air.typeOf(bin_op.lhs);
        const rhs_ty = self.air.typeOf(bin_op.rhs);
        const lhs_scalar_ty = lhs_ty.scalarType();
        const rhs_scalar_ty = rhs_ty.scalarType();

        const tg = self.dg.module.getTarget();

        const casted_rhs = if (rhs_scalar_ty.bitSize(tg) < lhs_scalar_ty.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_ty), "")
        else
            rhs;
        const is_signed_int = lhs_scalar_ty.isSignedInt();

        if (is_exact) {
            if (is_signed_int) {
                return self.builder.buildAShrExact(lhs, casted_rhs, "");
            } else {
                return self.builder.buildLShrExact(lhs, casted_rhs, "");
            }
        } else {
            if (is_signed_int) {
                return self.builder.buildAShr(lhs, casted_rhs, "");
            } else {
                return self.builder.buildLShr(lhs, casted_rhs, "");
            }
        }
    }

    fn airIntCast(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const target = self.dg.module.getTarget();
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const dest_ty = self.air.typeOfIndex(inst);
        const dest_info = dest_ty.intInfo(target);
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand_info = operand_ty.intInfo(target);

        if (operand_info.bits < dest_info.bits) {
            switch (operand_info.signedness) {
                .signed => return self.builder.buildSExt(operand, dest_llvm_ty, ""),
                .unsigned => return self.builder.buildZExt(operand, dest_llvm_ty, ""),
            }
        } else if (operand_info.bits > dest_info.bits) {
            return self.builder.buildTrunc(operand, dest_llvm_ty, "");
        } else {
            return operand;
        }
    }

    fn airTrunc(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const dest_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
        return self.builder.buildTrunc(operand, dest_llvm_ty, "");
    }

    fn airFptrunc(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const dest_ty = self.air.typeOfIndex(inst);
        const target = self.dg.module.getTarget();
        const dest_bits = dest_ty.floatBits(target);
        const src_bits = operand_ty.floatBits(target);
        if (!backendSupportsF80(target) and (src_bits == 80 or dest_bits == 80)) {
            return softF80TruncOrExt(self, operand, src_bits, dest_bits);
        }
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);
        return self.builder.buildFPTrunc(operand, dest_llvm_ty, "");
    }

    fn airFpext(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const dest_ty = self.air.typeOfIndex(inst);
        const target = self.dg.module.getTarget();
        const dest_bits = dest_ty.floatBits(target);
        const src_bits = operand_ty.floatBits(target);
        if (!backendSupportsF80(target) and (src_bits == 80 or dest_bits == 80)) {
            return softF80TruncOrExt(self, operand, src_bits, dest_bits);
        }
        const dest_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
        return self.builder.buildFPExt(operand, dest_llvm_ty, "");
    }

    fn airPtrToInt(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const dest_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
        return self.builder.buildPtrToInt(operand, dest_llvm_ty, "");
    }

    fn airBitCast(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        const inst_ty = self.air.typeOfIndex(inst);
        const operand_is_ref = isByRef(operand_ty);
        const result_is_ref = isByRef(inst_ty);
        const llvm_dest_ty = try self.dg.llvmType(inst_ty);
        const target = self.dg.module.getTarget();

        if (operand_is_ref and result_is_ref) {
            // They are both pointers; just do a bitcast on the pointers :)
            return self.builder.buildBitCast(operand, llvm_dest_ty.pointerType(0), "");
        }

        if (operand_ty.zigTypeTag() == .Int and inst_ty.isPtrAtRuntime()) {
            return self.builder.buildIntToPtr(operand, llvm_dest_ty, "");
        }

        if (operand_ty.zigTypeTag() == .Vector and inst_ty.zigTypeTag() == .Array) {
            const elem_ty = operand_ty.childType();
            if (!result_is_ref) {
                return self.dg.todo("implement bitcast vector to non-ref array", .{});
            }
            const array_ptr = self.buildAlloca(llvm_dest_ty);
            const bitcast_ok = elem_ty.bitSize(target) == elem_ty.abiSize(target) * 8;
            if (bitcast_ok) {
                const llvm_vector_ty = try self.dg.llvmType(operand_ty);
                const casted_ptr = self.builder.buildBitCast(array_ptr, llvm_vector_ty.pointerType(0), "");
                const llvm_store = self.builder.buildStore(operand, casted_ptr);
                llvm_store.setAlignment(inst_ty.abiAlignment(target));
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const llvm_usize = try self.dg.llvmType(Type.usize);
                const llvm_u32 = self.context.intType(32);
                const zero = llvm_usize.constNull();
                const vector_len = operand_ty.arrayLen();
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const index_usize = llvm_usize.constInt(i, .False);
                    const index_u32 = llvm_u32.constInt(i, .False);
                    const indexes: [2]*const llvm.Value = .{ zero, index_usize };
                    const elem_ptr = self.builder.buildInBoundsGEP(array_ptr, &indexes, indexes.len, "");
                    const elem = self.builder.buildExtractElement(operand, index_u32, "");
                    _ = self.builder.buildStore(elem, elem_ptr);
                }
            }
            return array_ptr;
        } else if (operand_ty.zigTypeTag() == .Array and inst_ty.zigTypeTag() == .Vector) {
            const elem_ty = operand_ty.childType();
            const llvm_vector_ty = try self.dg.llvmType(inst_ty);
            if (!operand_is_ref) {
                return self.dg.todo("implement bitcast non-ref array to vector", .{});
            }

            const bitcast_ok = elem_ty.bitSize(target) == elem_ty.abiSize(target) * 8;
            if (bitcast_ok) {
                const llvm_vector_ptr_ty = llvm_vector_ty.pointerType(0);
                const casted_ptr = self.builder.buildBitCast(operand, llvm_vector_ptr_ty, "");
                const vector = self.builder.buildLoad(casted_ptr, "");
                // The array is aligned to the element's alignment, while the vector might have a completely
                // different alignment. This means we need to enforce the alignment of this load.
                vector.setAlignment(elem_ty.abiAlignment(target));
                return vector;
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const llvm_usize = try self.dg.llvmType(Type.usize);
                const llvm_u32 = self.context.intType(32);
                const zero = llvm_usize.constNull();
                const vector_len = operand_ty.arrayLen();
                var vector = llvm_vector_ty.getUndef();
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const index_usize = llvm_usize.constInt(i, .False);
                    const index_u32 = llvm_u32.constInt(i, .False);
                    const indexes: [2]*const llvm.Value = .{ zero, index_usize };
                    const elem_ptr = self.builder.buildInBoundsGEP(operand, &indexes, indexes.len, "");
                    const elem = self.builder.buildLoad(elem_ptr, "");
                    vector = self.builder.buildInsertElement(vector, elem, index_u32, "");
                }

                return vector;
            }
        }

        if (operand_is_ref) {
            // Bitcast the operand pointer, then load.
            const casted_ptr = self.builder.buildBitCast(operand, llvm_dest_ty.pointerType(0), "");
            const load_inst = self.builder.buildLoad(casted_ptr, "");
            load_inst.setAlignment(operand_ty.abiAlignment(target));
            return load_inst;
        }

        if (result_is_ref) {
            // Bitcast the result pointer, then store.
            const alignment = @maximum(operand_ty.abiAlignment(target), inst_ty.abiAlignment(target));
            const result_ptr = self.buildAlloca(llvm_dest_ty);
            result_ptr.setAlignment(alignment);
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            const casted_ptr = self.builder.buildBitCast(result_ptr, operand_llvm_ty.pointerType(0), "");
            const store_inst = self.builder.buildStore(operand, casted_ptr);
            store_inst.setAlignment(alignment);
            return result_ptr;
        }

        if (llvm_dest_ty.getTypeKind() == .Struct) {
            // Both our operand and our result are values, not pointers,
            // but LLVM won't let us bitcast struct values.
            // Therefore, we store operand to bitcasted alloca, then load for result.
            const alignment = @maximum(operand_ty.abiAlignment(target), inst_ty.abiAlignment(target));
            const result_ptr = self.buildAlloca(llvm_dest_ty);
            result_ptr.setAlignment(alignment);
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            const casted_ptr = self.builder.buildBitCast(result_ptr, operand_llvm_ty.pointerType(0), "");
            const store_inst = self.builder.buildStore(operand, casted_ptr);
            store_inst.setAlignment(alignment);
            const load_inst = self.builder.buildLoad(result_ptr, "");
            load_inst.setAlignment(alignment);
            return load_inst;
        }

        return self.builder.buildBitCast(operand, llvm_dest_ty, "");
    }

    fn airBoolToInt(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        return operand;
    }

    fn airArg(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const arg_val = self.args[self.arg_index];
        self.arg_index += 1;

        const inst_ty = self.air.typeOfIndex(inst);
        if (self.dg.object.di_builder) |dib| {
            const src_index = self.getSrcArgIndex(self.arg_index - 1);
            const func = self.dg.decl.getFunction().?;
            const lbrace_line = self.dg.module.declPtr(func.owner_decl).src_line + func.lbrace_line + 1;
            const lbrace_col = func.lbrace_column + 1;
            const di_local_var = dib.createParameterVariable(
                self.di_scope.?,
                func.getParamName(src_index).ptr, // TODO test 0 bit args
                self.di_file.?,
                lbrace_line,
                try self.dg.object.lowerDebugType(inst_ty, .full),
                true, // always preserve
                0, // flags
                self.arg_index, // includes +1 because 0 is return type
            );

            const debug_loc = llvm.getDebugLoc(lbrace_line, lbrace_col, self.di_scope.?, null);
            const insert_block = self.builder.getInsertBlock();
            if (isByRef(inst_ty)) {
                _ = dib.insertDeclareAtEnd(arg_val, di_local_var, debug_loc, insert_block);
            } else {
                _ = dib.insertDbgValueIntrinsicAtEnd(arg_val, di_local_var, debug_loc, insert_block);
            }
        }

        return arg_val;
    }

    fn getSrcArgIndex(self: *FuncGen, runtime_index: u32) u32 {
        const fn_info = self.dg.decl.ty.fnInfo();
        var i: u32 = 0;
        for (fn_info.param_types) |param_ty, src_index| {
            if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;
            if (i == runtime_index) return @intCast(u32, src_index);
            i += 1;
        } else unreachable;
    }

    fn airAlloc(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;
        const ptr_ty = self.air.typeOfIndex(inst);
        const pointee_type = ptr_ty.childType();
        if (!pointee_type.isFnOrHasRuntimeBitsIgnoreComptime()) return self.dg.lowerPtrToVoid(ptr_ty);

        const pointee_llvm_ty = try self.dg.llvmType(pointee_type);
        const alloca_inst = self.buildAlloca(pointee_llvm_ty);
        const target = self.dg.module.getTarget();
        const alignment = ptr_ty.ptrAlignment(target);
        alloca_inst.setAlignment(alignment);
        return alloca_inst;
    }

    fn airRetPtr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;
        const ptr_ty = self.air.typeOfIndex(inst);
        const ret_ty = ptr_ty.childType();
        if (!ret_ty.isFnOrHasRuntimeBitsIgnoreComptime()) return self.dg.lowerPtrToVoid(ptr_ty);
        if (self.ret_ptr) |ret_ptr| return ret_ptr;
        const ret_llvm_ty = try self.dg.llvmType(ret_ty);
        const target = self.dg.module.getTarget();
        const alloca_inst = self.buildAlloca(ret_llvm_ty);
        alloca_inst.setAlignment(ptr_ty.ptrAlignment(target));
        return alloca_inst;
    }

    /// Use this instead of builder.buildAlloca, because this function makes sure to
    /// put the alloca instruction at the top of the function!
    fn buildAlloca(self: *FuncGen, llvm_ty: *const llvm.Type) *const llvm.Value {
        const prev_block = self.builder.getInsertBlock();
        const prev_debug_location = self.builder.getCurrentDebugLocation2();
        defer {
            self.builder.positionBuilderAtEnd(prev_block);
            if (self.di_scope != null) {
                self.builder.setCurrentDebugLocation2(prev_debug_location);
            }
        }

        const entry_block = self.llvm_func.getFirstBasicBlock().?;
        if (entry_block.getFirstInstruction()) |first_inst| {
            self.builder.positionBuilder(entry_block, first_inst);
        } else {
            self.builder.positionBuilderAtEnd(entry_block);
        }
        self.builder.clearCurrentDebugLocation();

        return self.builder.buildAlloca(llvm_ty, "");
    }

    fn airStore(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const dest_ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType();
        if (!operand_ty.isFnOrHasRuntimeBitsIgnoreComptime()) return null;

        // TODO Sema should emit a different instruction when the store should
        // possibly do the safety 0xaa bytes for undefined.
        const val_is_undef = if (self.air.value(bin_op.rhs)) |val| val.isUndefDeep() else false;
        if (val_is_undef) {
            const target = self.dg.module.getTarget();
            const operand_size = operand_ty.abiSize(target);
            const u8_llvm_ty = self.context.intType(8);
            const ptr_u8_llvm_ty = u8_llvm_ty.pointerType(0);
            const dest_ptr_u8 = self.builder.buildBitCast(dest_ptr, ptr_u8_llvm_ty, "");
            const fill_char = u8_llvm_ty.constInt(0xaa, .False);
            const dest_ptr_align = ptr_ty.ptrAlignment(target);
            const usize_llvm_ty = try self.dg.llvmType(Type.usize);
            const len = usize_llvm_ty.constInt(operand_size, .False);
            _ = self.builder.buildMemSet(dest_ptr_u8, fill_char, len, dest_ptr_align, ptr_ty.isVolatilePtr());
            if (self.dg.module.comp.bin_file.options.valgrind) {
                // TODO generate valgrind client request to mark byte range as undefined
                // see gen_valgrind_undef() in codegen.cpp
            }
        } else {
            const src_operand = try self.resolveInst(bin_op.rhs);
            self.store(dest_ptr, ptr_ty, src_operand, .NotAtomic);
        }
        return null;
    }

    fn airLoad(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const ptr_ty = self.air.typeOf(ty_op.operand);
        if (!ptr_ty.isVolatilePtr() and self.liveness.isUnused(inst))
            return null;
        const ptr = try self.resolveInst(ty_op.operand);
        return self.load(ptr, ptr_ty);
    }

    fn airBreakpoint(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        _ = inst;
        const llvm_fn = self.getIntrinsic("llvm.debugtrap", &.{});
        _ = self.builder.buildCall(llvm_fn, undefined, 0, .C, .Auto, "");
        return null;
    }

    fn airRetAddr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const llvm_i32 = self.context.intType(32);
        const llvm_fn = self.getIntrinsic("llvm.returnaddress", &.{});
        const params = [_]*const llvm.Value{llvm_i32.constNull()};
        const ptr_val = self.builder.buildCall(llvm_fn, &params, params.len, .Fast, .Auto, "");
        const llvm_usize = try self.dg.llvmType(Type.usize);
        return self.builder.buildPtrToInt(ptr_val, llvm_usize, "");
    }

    fn airFrameAddress(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const llvm_i32 = self.context.intType(32);
        const llvm_fn_name = "llvm.frameaddress.p0i8";
        const llvm_fn = self.dg.object.llvm_module.getNamedFunction(llvm_fn_name) orelse blk: {
            const llvm_p0i8 = self.context.intType(8).pointerType(0);
            const param_types = [_]*const llvm.Type{llvm_i32};
            const fn_type = llvm.functionType(llvm_p0i8, &param_types, param_types.len, .False);
            break :blk self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        };

        const params = [_]*const llvm.Value{llvm_i32.constNull()};
        const ptr_val = self.builder.buildCall(llvm_fn, &params, params.len, .Fast, .Auto, "");
        const llvm_usize = try self.dg.llvmType(Type.usize);
        return self.builder.buildPtrToInt(ptr_val, llvm_usize, "");
    }

    fn airFence(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const atomic_order = self.air.instructions.items(.data)[inst].fence;
        const llvm_memory_order = toLlvmAtomicOrdering(atomic_order);
        const single_threaded = llvm.Bool.fromBool(self.single_threaded);
        _ = self.builder.buildFence(llvm_memory_order, single_threaded, "");
        return null;
    }

    fn airCmpxchg(self: *FuncGen, inst: Air.Inst.Index, is_weak: bool) !?*const llvm.Value {
        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
        var ptr = try self.resolveInst(extra.ptr);
        var expected_value = try self.resolveInst(extra.expected_value);
        var new_value = try self.resolveInst(extra.new_value);
        const operand_ty = self.air.typeOf(extra.ptr).elemType();
        const opt_abi_ty = self.dg.getAtomicAbiType(operand_ty, false);
        if (opt_abi_ty) |abi_ty| {
            // operand needs widening and truncating
            ptr = self.builder.buildBitCast(ptr, abi_ty.pointerType(0), "");
            if (operand_ty.isSignedInt()) {
                expected_value = self.builder.buildSExt(expected_value, abi_ty, "");
                new_value = self.builder.buildSExt(new_value, abi_ty, "");
            } else {
                expected_value = self.builder.buildZExt(expected_value, abi_ty, "");
                new_value = self.builder.buildZExt(new_value, abi_ty, "");
            }
        }
        const result = self.builder.buildAtomicCmpXchg(
            ptr,
            expected_value,
            new_value,
            toLlvmAtomicOrdering(extra.successOrder()),
            toLlvmAtomicOrdering(extra.failureOrder()),
            llvm.Bool.fromBool(self.single_threaded),
        );
        result.setWeak(llvm.Bool.fromBool(is_weak));

        const optional_ty = self.air.typeOfIndex(inst);

        var payload = self.builder.buildExtractValue(result, 0, "");
        if (opt_abi_ty != null) {
            payload = self.builder.buildTrunc(payload, try self.dg.llvmType(operand_ty), "");
        }
        const success_bit = self.builder.buildExtractValue(result, 1, "");

        if (optional_ty.isPtrLikeOptional()) {
            return self.builder.buildSelect(success_bit, payload.typeOf().constNull(), payload, "");
        }

        const optional_llvm_ty = try self.dg.llvmType(optional_ty);
        const non_null_bit = self.builder.buildNot(success_bit, "");
        const partial = self.builder.buildInsertValue(optional_llvm_ty.getUndef(), payload, 0, "");
        return self.builder.buildInsertValue(partial, non_null_bit, 1, "");
    }

    fn airAtomicRmw(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;
        const ptr = try self.resolveInst(pl_op.operand);
        const ptr_ty = self.air.typeOf(pl_op.operand);
        const operand_ty = ptr_ty.elemType();
        const operand = try self.resolveInst(extra.operand);
        const is_signed_int = operand_ty.isSignedInt();
        const is_float = operand_ty.isRuntimeFloat();
        const op = toLlvmAtomicRmwBinOp(extra.op(), is_signed_int, is_float);
        const ordering = toLlvmAtomicOrdering(extra.ordering());
        const single_threaded = llvm.Bool.fromBool(self.single_threaded);
        const opt_abi_ty = self.dg.getAtomicAbiType(operand_ty, op == .Xchg);
        if (opt_abi_ty) |abi_ty| {
            // operand needs widening and truncating or bitcasting.
            const casted_ptr = self.builder.buildBitCast(ptr, abi_ty.pointerType(0), "");
            const casted_operand = if (is_float)
                self.builder.buildBitCast(operand, abi_ty, "")
            else if (is_signed_int)
                self.builder.buildSExt(operand, abi_ty, "")
            else
                self.builder.buildZExt(operand, abi_ty, "");

            const uncasted_result = self.builder.buildAtomicRmw(
                op,
                casted_ptr,
                casted_operand,
                ordering,
                single_threaded,
            );
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            if (is_float) {
                return self.builder.buildBitCast(uncasted_result, operand_llvm_ty, "");
            } else {
                return self.builder.buildTrunc(uncasted_result, operand_llvm_ty, "");
            }
        }

        if (operand.typeOf().getTypeKind() != .Pointer) {
            return self.builder.buildAtomicRmw(op, ptr, operand, ordering, single_threaded);
        }

        // It's a pointer but we need to treat it as an int.
        const usize_llvm_ty = try self.dg.llvmType(Type.usize);
        const casted_ptr = self.builder.buildBitCast(ptr, usize_llvm_ty.pointerType(0), "");
        const casted_operand = self.builder.buildPtrToInt(operand, usize_llvm_ty, "");
        const uncasted_result = self.builder.buildAtomicRmw(
            op,
            casted_ptr,
            casted_operand,
            ordering,
            single_threaded,
        );
        const operand_llvm_ty = try self.dg.llvmType(operand_ty);
        return self.builder.buildIntToPtr(uncasted_result, operand_llvm_ty, "");
    }

    fn airAtomicLoad(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const atomic_load = self.air.instructions.items(.data)[inst].atomic_load;
        const ptr = try self.resolveInst(atomic_load.ptr);
        const ptr_ty = self.air.typeOf(atomic_load.ptr);
        if (!ptr_ty.isVolatilePtr() and self.liveness.isUnused(inst))
            return null;
        const ordering = toLlvmAtomicOrdering(atomic_load.order);
        const operand_ty = ptr_ty.elemType();
        const opt_abi_ty = self.dg.getAtomicAbiType(operand_ty, false);

        if (opt_abi_ty) |abi_ty| {
            // operand needs widening and truncating
            const casted_ptr = self.builder.buildBitCast(ptr, abi_ty.pointerType(0), "");
            const load_inst = (try self.load(casted_ptr, ptr_ty)).?;
            load_inst.setOrdering(ordering);
            return self.builder.buildTrunc(load_inst, try self.dg.llvmType(operand_ty), "");
        }
        const load_inst = (try self.load(ptr, ptr_ty)).?;
        load_inst.setOrdering(ordering);
        return load_inst;
    }

    fn airAtomicStore(
        self: *FuncGen,
        inst: Air.Inst.Index,
        ordering: llvm.AtomicOrdering,
    ) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType();
        if (!operand_ty.isFnOrHasRuntimeBitsIgnoreComptime()) return null;
        var ptr = try self.resolveInst(bin_op.lhs);
        var element = try self.resolveInst(bin_op.rhs);
        const opt_abi_ty = self.dg.getAtomicAbiType(operand_ty, false);

        if (opt_abi_ty) |abi_ty| {
            // operand needs widening
            ptr = self.builder.buildBitCast(ptr, abi_ty.pointerType(0), "");
            if (operand_ty.isSignedInt()) {
                element = self.builder.buildSExt(element, abi_ty, "");
            } else {
                element = self.builder.buildZExt(element, abi_ty, "");
            }
        }
        self.store(ptr, ptr_ty, element, ordering);
        return null;
    }

    fn airMemset(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
        const dest_ptr = try self.resolveInst(pl_op.operand);
        const ptr_ty = self.air.typeOf(pl_op.operand);
        const value = try self.resolveInst(extra.lhs);
        const val_is_undef = if (self.air.value(extra.lhs)) |val| val.isUndefDeep() else false;
        const len = try self.resolveInst(extra.rhs);
        const u8_llvm_ty = self.context.intType(8);
        const ptr_u8_llvm_ty = u8_llvm_ty.pointerType(0);
        const dest_ptr_u8 = self.builder.buildBitCast(dest_ptr, ptr_u8_llvm_ty, "");
        const fill_char = if (val_is_undef) u8_llvm_ty.constInt(0xaa, .False) else value;
        const target = self.dg.module.getTarget();
        const dest_ptr_align = ptr_ty.ptrAlignment(target);
        _ = self.builder.buildMemSet(dest_ptr_u8, fill_char, len, dest_ptr_align, ptr_ty.isVolatilePtr());

        if (val_is_undef and self.dg.module.comp.bin_file.options.valgrind) {
            // TODO generate valgrind client request to mark byte range as undefined
            // see gen_valgrind_undef() in codegen.cpp
        }
        return null;
    }

    fn airMemcpy(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
        const dest_ptr = try self.resolveInst(pl_op.operand);
        const dest_ptr_ty = self.air.typeOf(pl_op.operand);
        const src_ptr = try self.resolveInst(extra.lhs);
        const src_ptr_ty = self.air.typeOf(extra.lhs);
        const len = try self.resolveInst(extra.rhs);
        const llvm_ptr_u8 = self.context.intType(8).pointerType(0);
        const dest_ptr_u8 = self.builder.buildBitCast(dest_ptr, llvm_ptr_u8, "");
        const src_ptr_u8 = self.builder.buildBitCast(src_ptr, llvm_ptr_u8, "");
        const is_volatile = src_ptr_ty.isVolatilePtr() or dest_ptr_ty.isVolatilePtr();
        const target = self.dg.module.getTarget();
        _ = self.builder.buildMemCpy(
            dest_ptr_u8,
            dest_ptr_ty.ptrAlignment(target),
            src_ptr_u8,
            src_ptr_ty.ptrAlignment(target),
            len,
            is_volatile,
        );
        return null;
    }

    fn airSetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const un_ty = self.air.typeOf(bin_op.lhs).childType();
        const target = self.dg.module.getTarget();
        const layout = un_ty.unionGetLayout(target);
        if (layout.tag_size == 0) return null;
        const union_ptr = try self.resolveInst(bin_op.lhs);
        const new_tag = try self.resolveInst(bin_op.rhs);
        if (layout.payload_size == 0) {
            _ = self.builder.buildStore(new_tag, union_ptr);
            return null;
        }
        const tag_index = @boolToInt(layout.tag_align < layout.payload_align);
        const tag_field_ptr = self.builder.buildStructGEP(union_ptr, tag_index, "");
        _ = self.builder.buildStore(new_tag, tag_field_ptr);
        return null;
    }

    fn airGetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const un_ty = self.air.typeOf(ty_op.operand);
        const target = self.dg.module.getTarget();
        const layout = un_ty.unionGetLayout(target);
        if (layout.tag_size == 0) return null;
        const union_handle = try self.resolveInst(ty_op.operand);
        if (isByRef(un_ty)) {
            if (layout.payload_size == 0) {
                return self.builder.buildLoad(union_handle, "");
            }
            const tag_index = @boolToInt(layout.tag_align < layout.payload_align);
            const tag_field_ptr = self.builder.buildStructGEP(union_handle, tag_index, "");
            return self.builder.buildLoad(tag_field_ptr, "");
        } else {
            if (layout.payload_size == 0) {
                return union_handle;
            }
            const tag_index = @boolToInt(layout.tag_align < layout.payload_align);
            return self.builder.buildExtractValue(union_handle, tag_index, "");
        }
    }

    fn airUnaryOp(self: *FuncGen, inst: Air.Inst.Index, llvm_fn_name: []const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.air.typeOf(un_op);

        return self.callFloatUnary(operand, operand_ty, llvm_fn_name);
    }

    fn airClzCtz(self: *FuncGen, inst: Air.Inst.Index, llvm_fn_name: []const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const llvm_i1 = self.context.intType(1);
        const operand_llvm_ty = try self.dg.llvmType(operand_ty);
        const fn_val = self.getIntrinsic(llvm_fn_name, &.{operand_llvm_ty});

        const params = [_]*const llvm.Value{ operand, llvm_i1.constNull() };
        const wrong_size_result = self.builder.buildCall(fn_val, &params, params.len, .C, .Auto, "");
        const result_ty = self.air.typeOfIndex(inst);
        const result_llvm_ty = try self.dg.llvmType(result_ty);

        const target = self.dg.module.getTarget();
        const bits = operand_ty.intInfo(target).bits;
        const result_bits = result_ty.intInfo(target).bits;
        if (bits > result_bits) {
            return self.builder.buildTrunc(wrong_size_result, result_llvm_ty, "");
        } else if (bits < result_bits) {
            return self.builder.buildZExt(wrong_size_result, result_llvm_ty, "");
        } else {
            return wrong_size_result;
        }
    }

    fn airBitOp(self: *FuncGen, inst: Air.Inst.Index, llvm_fn_name: []const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const params = [_]*const llvm.Value{operand};
        const operand_llvm_ty = try self.dg.llvmType(operand_ty);
        const fn_val = self.getIntrinsic(llvm_fn_name, &.{operand_llvm_ty});

        const wrong_size_result = self.builder.buildCall(fn_val, &params, params.len, .C, .Auto, "");
        const result_ty = self.air.typeOfIndex(inst);
        const result_llvm_ty = try self.dg.llvmType(result_ty);

        const target = self.dg.module.getTarget();
        const bits = operand_ty.intInfo(target).bits;
        const result_bits = result_ty.intInfo(target).bits;
        if (bits > result_bits) {
            return self.builder.buildTrunc(wrong_size_result, result_llvm_ty, "");
        } else if (bits < result_bits) {
            return self.builder.buildZExt(wrong_size_result, result_llvm_ty, "");
        } else {
            return wrong_size_result;
        }
    }

    fn airByteSwap(self: *FuncGen, inst: Air.Inst.Index, llvm_fn_name: []const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const target = self.dg.module.getTarget();
        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        var bits = operand_ty.intInfo(target).bits;
        assert(bits % 8 == 0);

        var operand = try self.resolveInst(ty_op.operand);
        var operand_llvm_ty = try self.dg.llvmType(operand_ty);

        if (bits % 16 == 8) {
            // If not an even byte-multiple, we need zero-extend + shift-left 1 byte
            // The truncated result at the end will be the correct bswap
            const scalar_llvm_ty = self.context.intType(bits + 8);
            if (operand_ty.zigTypeTag() == .Vector) {
                const vec_len = operand_ty.vectorLen();
                operand_llvm_ty = scalar_llvm_ty.vectorType(vec_len);

                const shifts = try self.gpa.alloc(*const llvm.Value, vec_len);
                defer self.gpa.free(shifts);

                for (shifts) |*elem| {
                    elem.* = scalar_llvm_ty.constInt(8, .False);
                }
                const shift_vec = llvm.constVector(shifts.ptr, vec_len);

                const extended = self.builder.buildZExt(operand, operand_llvm_ty, "");
                operand = self.builder.buildShl(extended, shift_vec, "");
            } else {
                const extended = self.builder.buildZExt(operand, scalar_llvm_ty, "");
                operand = self.builder.buildShl(extended, scalar_llvm_ty.constInt(8, .False), "");
                operand_llvm_ty = scalar_llvm_ty;
            }
            bits = bits + 8;
        }

        const params = [_]*const llvm.Value{operand};
        const fn_val = self.getIntrinsic(llvm_fn_name, &.{operand_llvm_ty});

        const wrong_size_result = self.builder.buildCall(fn_val, &params, params.len, .C, .Auto, "");

        const result_ty = self.air.typeOfIndex(inst);
        const result_llvm_ty = try self.dg.llvmType(result_ty);
        const result_bits = result_ty.intInfo(target).bits;
        if (bits > result_bits) {
            return self.builder.buildTrunc(wrong_size_result, result_llvm_ty, "");
        } else if (bits < result_bits) {
            return self.builder.buildZExt(wrong_size_result, result_llvm_ty, "");
        } else {
            return wrong_size_result;
        }
    }

    fn airTagName(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        var arena_allocator = std.heap.ArenaAllocator.init(self.gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);
        const enum_ty = self.air.typeOf(un_op);

        const mod = self.dg.module;
        const llvm_fn_name = try std.fmt.allocPrintZ(arena, "__zig_tag_name_{s}", .{
            try mod.declPtr(enum_ty.getOwnerDecl()).getFullyQualifiedName(mod),
        });

        const llvm_fn = try self.getEnumTagNameFunction(enum_ty, llvm_fn_name);
        const params = [_]*const llvm.Value{operand};
        return self.builder.buildCall(llvm_fn, &params, params.len, .Fast, .Auto, "");
    }

    fn getEnumTagNameFunction(
        self: *FuncGen,
        enum_ty: Type,
        llvm_fn_name: [:0]const u8,
    ) !*const llvm.Value {
        // TODO: detect when the type changes and re-emit this function.
        if (self.dg.object.llvm_module.getNamedFunction(llvm_fn_name)) |llvm_fn| {
            return llvm_fn;
        }

        const slice_ty = Type.initTag(.const_slice_u8_sentinel_0);
        const llvm_ret_ty = try self.dg.llvmType(slice_ty);
        const usize_llvm_ty = try self.dg.llvmType(Type.usize);
        const target = self.dg.module.getTarget();
        const slice_alignment = slice_ty.abiAlignment(target);

        var int_tag_type_buffer: Type.Payload.Bits = undefined;
        const int_tag_ty = enum_ty.intTagType(&int_tag_type_buffer);
        const param_types = [_]*const llvm.Type{try self.dg.llvmType(int_tag_ty)};

        const fn_type = llvm.functionType(llvm_ret_ty, &param_types, param_types.len, .False);
        const fn_val = self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        fn_val.setLinkage(.Internal);
        fn_val.setFunctionCallConv(.Fast);
        self.dg.addCommonFnAttributes(fn_val);

        const prev_block = self.builder.getInsertBlock();
        const prev_debug_location = self.builder.getCurrentDebugLocation2();
        defer {
            self.builder.positionBuilderAtEnd(prev_block);
            if (self.di_scope != null) {
                self.builder.setCurrentDebugLocation2(prev_debug_location);
            }
        }

        const entry_block = self.dg.context.appendBasicBlock(fn_val, "Entry");
        self.builder.positionBuilderAtEnd(entry_block);
        self.builder.clearCurrentDebugLocation();

        const fields = enum_ty.enumFields();
        const bad_value_block = self.dg.context.appendBasicBlock(fn_val, "BadValue");
        const tag_int_value = fn_val.getParam(0);
        const switch_instr = self.builder.buildSwitch(tag_int_value, bad_value_block, @intCast(c_uint, fields.count()));

        const array_ptr_indices = [_]*const llvm.Value{
            usize_llvm_ty.constNull(), usize_llvm_ty.constNull(),
        };

        for (fields.keys()) |name, field_index| {
            const str_init = self.dg.context.constString(name.ptr, @intCast(c_uint, name.len), .False);
            const str_global = self.dg.object.llvm_module.addGlobal(str_init.typeOf(), "");
            str_global.setInitializer(str_init);
            str_global.setLinkage(.Private);
            str_global.setGlobalConstant(.True);
            str_global.setUnnamedAddr(.True);
            str_global.setAlignment(1);

            const slice_fields = [_]*const llvm.Value{
                str_global.constInBoundsGEP(&array_ptr_indices, array_ptr_indices.len),
                usize_llvm_ty.constInt(name.len, .False),
            };
            const slice_init = llvm_ret_ty.constNamedStruct(&slice_fields, slice_fields.len);
            const slice_global = self.dg.object.llvm_module.addGlobal(slice_init.typeOf(), "");
            slice_global.setInitializer(slice_init);
            slice_global.setLinkage(.Private);
            slice_global.setGlobalConstant(.True);
            slice_global.setUnnamedAddr(.True);
            slice_global.setAlignment(slice_alignment);

            const return_block = self.dg.context.appendBasicBlock(fn_val, "Name");
            const this_tag_int_value = int: {
                var tag_val_payload: Value.Payload.U32 = .{
                    .base = .{ .tag = .enum_field_index },
                    .data = @intCast(u32, field_index),
                };
                break :int try self.dg.genTypedValue(.{
                    .ty = enum_ty,
                    .val = Value.initPayload(&tag_val_payload.base),
                });
            };
            switch_instr.addCase(this_tag_int_value, return_block);

            self.builder.positionBuilderAtEnd(return_block);
            const loaded = self.builder.buildLoad(slice_global, "");
            loaded.setAlignment(slice_alignment);
            _ = self.builder.buildRet(loaded);
        }

        self.builder.positionBuilderAtEnd(bad_value_block);
        _ = self.builder.buildUnreachable();
        return fn_val;
    }

    fn getCmpLtErrorsLenFunction(self: *FuncGen) !*const llvm.Value {
        if (self.dg.object.llvm_module.getNamedFunction(lt_errors_fn_name)) |llvm_fn| {
            return llvm_fn;
        }

        // Function signature: fn (anyerror) bool

        const ret_llvm_ty = try self.dg.llvmType(Type.bool);
        const anyerror_llvm_ty = try self.dg.llvmType(Type.anyerror);
        const param_types = [_]*const llvm.Type{anyerror_llvm_ty};

        const fn_type = llvm.functionType(ret_llvm_ty, &param_types, param_types.len, .False);
        const llvm_fn = self.dg.object.llvm_module.addFunction(lt_errors_fn_name, fn_type);
        llvm_fn.setLinkage(.Internal);
        llvm_fn.setFunctionCallConv(.Fast);
        self.dg.addCommonFnAttributes(llvm_fn);
        return llvm_fn;
    }

    fn airErrorName(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const operand = try self.resolveInst(un_op);

        const error_name_table_ptr = try self.getErrorNameTable();
        const error_name_table = self.builder.buildLoad(error_name_table_ptr, "");
        const indices = [_]*const llvm.Value{operand};
        const error_name_ptr = self.builder.buildInBoundsGEP(error_name_table, &indices, indices.len, "");
        return self.builder.buildLoad(error_name_ptr, "");
    }

    fn airSplat(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const scalar = try self.resolveInst(ty_op.operand);
        const scalar_ty = self.air.typeOf(ty_op.operand);
        const vector_ty = self.air.typeOfIndex(inst);
        const len = vector_ty.vectorLen();
        const scalar_llvm_ty = try self.dg.llvmType(scalar_ty);
        const op_llvm_ty = scalar_llvm_ty.vectorType(1);
        const u32_llvm_ty = self.context.intType(32);
        const mask_llvm_ty = u32_llvm_ty.vectorType(len);
        const undef_vector = op_llvm_ty.getUndef();
        const u32_zero = u32_llvm_ty.constNull();
        const op_vector = self.builder.buildInsertElement(undef_vector, scalar, u32_zero, "");
        return self.builder.buildShuffleVector(op_vector, undef_vector, mask_llvm_ty.constNull(), "");
    }

    fn airSelect(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
        const pred = try self.resolveInst(pl_op.operand);
        const a = try self.resolveInst(extra.lhs);
        const b = try self.resolveInst(extra.rhs);

        return self.builder.buildSelect(pred, a, b, "");
    }

    fn airShuffle(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
        const a = try self.resolveInst(extra.a);
        const b = try self.resolveInst(extra.b);
        const mask = self.air.values[extra.mask];
        const mask_len = extra.mask_len;
        const a_len = self.air.typeOf(extra.a).vectorLen();

        // LLVM uses integers larger than the length of the first array to
        // index into the second array. This was deemed unnecessarily fragile
        // when changing code, so Zig uses negative numbers to index the
        // second vector. These start at -1 and go down, and are easiest to use
        // with the ~ operator. Here we convert between the two formats.
        const values = try self.gpa.alloc(*const llvm.Value, mask_len);
        defer self.gpa.free(values);

        const llvm_i32 = self.context.intType(32);

        for (values) |*val, i| {
            var buf: Value.ElemValueBuffer = undefined;
            const elem = mask.elemValueBuffer(self.dg.module, i, &buf);
            if (elem.isUndef()) {
                val.* = llvm_i32.getUndef();
            } else {
                const int = elem.toSignedInt();
                const unsigned = if (int >= 0) @intCast(u32, int) else @intCast(u32, ~int + a_len);
                val.* = llvm_i32.constInt(unsigned, .False);
            }
        }

        const llvm_mask_value = llvm.constVector(values.ptr, mask_len);
        return self.builder.buildShuffleVector(a, b, llvm_mask_value, "");
    }

    fn airReduce(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const reduce = self.air.instructions.items(.data)[inst].reduce;
        const operand = try self.resolveInst(reduce.operand);
        const scalar_ty = self.air.typeOfIndex(inst);

        // TODO handle the fast math setting

        switch (reduce.operation) {
            .And => return self.builder.buildAndReduce(operand),
            .Or => return self.builder.buildOrReduce(operand),
            .Xor => return self.builder.buildXorReduce(operand),
            .Min => switch (scalar_ty.zigTypeTag()) {
                .Int => return self.builder.buildIntMinReduce(operand, scalar_ty.isSignedInt()),
                .Float => return self.builder.buildFPMinReduce(operand),
                else => unreachable,
            },
            .Max => switch (scalar_ty.zigTypeTag()) {
                .Int => return self.builder.buildIntMaxReduce(operand, scalar_ty.isSignedInt()),
                .Float => return self.builder.buildFPMaxReduce(operand),
                else => unreachable,
            },
            .Add => switch (scalar_ty.zigTypeTag()) {
                .Int => return self.builder.buildAddReduce(operand),
                .Float => {
                    const scalar_llvm_ty = try self.dg.llvmType(scalar_ty);
                    const neutral_value = scalar_llvm_ty.constReal(-0.0);
                    return self.builder.buildFPAddReduce(neutral_value, operand);
                },
                else => unreachable,
            },
            .Mul => switch (scalar_ty.zigTypeTag()) {
                .Int => return self.builder.buildMulReduce(operand),
                .Float => {
                    const scalar_llvm_ty = try self.dg.llvmType(scalar_ty);
                    const neutral_value = scalar_llvm_ty.constReal(1.0);
                    return self.builder.buildFPMulReduce(neutral_value, operand);
                },
                else => unreachable,
            },
        }
    }

    fn airAggregateInit(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const result_ty = self.air.typeOfIndex(inst);
        const len = @intCast(usize, result_ty.arrayLen());
        const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
        const llvm_result_ty = try self.dg.llvmType(result_ty);
        const target = self.dg.module.getTarget();

        switch (result_ty.zigTypeTag()) {
            .Vector => {
                const llvm_u32 = self.context.intType(32);

                var vector = llvm_result_ty.getUndef();
                for (elements) |elem, i| {
                    const index_u32 = llvm_u32.constInt(i, .False);
                    const llvm_elem = try self.resolveInst(elem);
                    vector = self.builder.buildInsertElement(vector, llvm_elem, index_u32, "");
                }
                return vector;
            },
            .Struct => {
                if (result_ty.containerLayout() == .Packed) {
                    const struct_obj = result_ty.castTag(.@"struct").?.data;
                    const big_bits = struct_obj.packedIntegerBits(target);
                    const int_llvm_ty = self.dg.context.intType(big_bits);
                    const fields = struct_obj.fields.values();
                    comptime assert(Type.packed_struct_layout_version == 2);
                    var running_int: *const llvm.Value = int_llvm_ty.constNull();
                    var running_bits: u16 = 0;
                    for (elements) |elem, i| {
                        const field = fields[i];
                        if (!field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                        const non_int_val = try self.resolveInst(elem);
                        const ty_bit_size = @intCast(u16, field.ty.bitSize(target));
                        const small_int_ty = self.dg.context.intType(ty_bit_size);
                        const small_int_val = self.builder.buildBitCast(non_int_val, small_int_ty, "");
                        const shift_rhs = int_llvm_ty.constInt(running_bits, .False);
                        // If the field is as large as the entire packed struct, this
                        // zext would go from, e.g. i16 to i16. This is legal with
                        // constZExtOrBitCast but not legal with constZExt.
                        const extended_int_val = self.builder.buildZExtOrBitCast(small_int_val, int_llvm_ty, "");
                        const shifted = self.builder.buildShl(extended_int_val, shift_rhs, "");
                        running_int = self.builder.buildOr(running_int, shifted, "");
                        running_bits += ty_bit_size;
                    }
                    return running_int;
                }

                var ptr_ty_buf: Type.Payload.Pointer = undefined;

                if (isByRef(result_ty)) {
                    const llvm_u32 = self.context.intType(32);
                    const alloca_inst = self.buildAlloca(llvm_result_ty);
                    // TODO in debug builds init to undef so that the padding will be 0xaa
                    // even if we fully populate the fields.
                    alloca_inst.setAlignment(result_ty.abiAlignment(target));

                    var indices: [2]*const llvm.Value = .{ llvm_u32.constNull(), undefined };
                    for (elements) |elem, i| {
                        if (result_ty.structFieldValueComptime(i) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = llvmFieldIndex(result_ty, i, target, &ptr_ty_buf).?;
                        indices[1] = llvm_u32.constInt(llvm_i, .False);
                        const field_ptr = self.builder.buildInBoundsGEP(alloca_inst, &indices, indices.len, "");
                        var field_ptr_payload: Type.Payload.Pointer = .{
                            .data = .{
                                .pointee_type = self.air.typeOf(elem),
                                .@"align" = result_ty.structFieldAlign(i, target),
                                .@"addrspace" = .generic,
                            },
                        };
                        const field_ptr_ty = Type.initPayload(&field_ptr_payload.base);
                        self.store(field_ptr, field_ptr_ty, llvm_elem, .NotAtomic);
                    }

                    return alloca_inst;
                } else {
                    var result = llvm_result_ty.getUndef();
                    for (elements) |elem, i| {
                        if (result_ty.structFieldValueComptime(i) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = llvmFieldIndex(result_ty, i, target, &ptr_ty_buf).?;
                        result = self.builder.buildInsertValue(result, llvm_elem, llvm_i, "");
                    }
                    return result;
                }
            },
            .Array => {
                assert(isByRef(result_ty));

                const llvm_usize = try self.dg.llvmType(Type.usize);
                const alloca_inst = self.buildAlloca(llvm_result_ty);
                alloca_inst.setAlignment(result_ty.abiAlignment(target));

                const elem_ty = result_ty.childType();

                for (elements) |elem, i| {
                    const indices: [2]*const llvm.Value = .{
                        llvm_usize.constNull(),
                        llvm_usize.constInt(@intCast(c_uint, i), .False),
                    };
                    const elem_ptr = self.builder.buildInBoundsGEP(alloca_inst, &indices, indices.len, "");
                    const llvm_elem = try self.resolveInst(elem);
                    var elem_ptr_payload: Type.Payload.Pointer = .{
                        .data = .{
                            .pointee_type = elem_ty,
                            .@"addrspace" = .generic,
                        },
                    };
                    const elem_ptr_ty = Type.initPayload(&elem_ptr_payload.base);
                    self.store(elem_ptr, elem_ptr_ty, llvm_elem, .NotAtomic);
                }

                return alloca_inst;
            },
            else => unreachable,
        }
    }

    fn airUnionInit(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
        const union_ty = self.air.typeOfIndex(inst);
        const union_llvm_ty = try self.dg.llvmType(union_ty);
        const target = self.dg.module.getTarget();
        const layout = union_ty.unionGetLayout(target);
        if (layout.payload_size == 0) {
            if (layout.tag_size == 0) {
                return null;
            }
            assert(!isByRef(union_ty));
            return union_llvm_ty.constInt(extra.field_index, .False);
        }
        assert(isByRef(union_ty));
        // The llvm type of the alloca will the the named LLVM union type, which will not
        // necessarily match the format that we need, depending on which tag is active. We
        // must construct the correct unnamed struct type here and bitcast, in order to
        // then set the fields appropriately.
        const result_ptr = self.buildAlloca(union_llvm_ty);
        const llvm_payload = try self.resolveInst(extra.init);
        const union_obj = union_ty.cast(Type.Payload.Union).?.data;
        assert(union_obj.haveFieldTypes());
        const field = union_obj.fields.values()[extra.field_index];
        const field_llvm_ty = try self.dg.llvmType(field.ty);
        const tag_llvm_ty = try self.dg.llvmType(union_obj.tag_ty);
        const field_size = field.ty.abiSize(target);
        const field_align = field.normalAlignment(target);

        const llvm_union_ty = t: {
            const payload = p: {
                if (!field.ty.hasRuntimeBitsIgnoreComptime()) {
                    const padding_len = @intCast(c_uint, layout.payload_size);
                    break :p self.context.intType(8).arrayType(padding_len);
                }
                if (field_size == layout.payload_size) {
                    break :p field_llvm_ty;
                }
                const padding_len = @intCast(c_uint, layout.payload_size - field_size);
                const fields: [2]*const llvm.Type = .{
                    field_llvm_ty, self.context.intType(8).arrayType(padding_len),
                };
                break :p self.context.structType(&fields, fields.len, .False);
            };
            if (layout.tag_size == 0) {
                const fields: [1]*const llvm.Type = .{payload};
                break :t self.context.structType(&fields, fields.len, .False);
            }
            var fields: [3]*const llvm.Type = undefined;
            var fields_len: c_uint = 2;
            if (layout.tag_align >= layout.payload_align) {
                fields = .{ tag_llvm_ty, payload, undefined };
            } else {
                fields = .{ payload, tag_llvm_ty, undefined };
            }
            if (layout.padding != 0) {
                fields[2] = self.context.intType(8).arrayType(layout.padding);
                fields_len = 3;
            }
            break :t self.context.structType(&fields, fields_len, .False);
        };

        const casted_ptr = self.builder.buildBitCast(result_ptr, llvm_union_ty.pointerType(0), "");

        // Now we follow the layout as expressed above with GEP instructions to set the
        // tag and the payload.
        const index_type = self.context.intType(32);

        var field_ptr_payload: Type.Payload.Pointer = .{
            .data = .{
                .pointee_type = field.ty,
                .@"align" = field_align,
                .@"addrspace" = .generic,
            },
        };
        const field_ptr_ty = Type.initPayload(&field_ptr_payload.base);
        if (layout.tag_size == 0) {
            const indices: [3]*const llvm.Value = .{
                index_type.constNull(),
                index_type.constNull(),
                index_type.constNull(),
            };
            const len: c_uint = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr = self.builder.buildInBoundsGEP(casted_ptr, &indices, len, "");
            self.store(field_ptr, field_ptr_ty, llvm_payload, .NotAtomic);
            return result_ptr;
        }

        {
            const indices: [3]*const llvm.Value = .{
                index_type.constNull(),
                index_type.constInt(@boolToInt(layout.tag_align >= layout.payload_align), .False),
                index_type.constNull(),
            };
            const len: c_uint = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr = self.builder.buildInBoundsGEP(casted_ptr, &indices, len, "");
            self.store(field_ptr, field_ptr_ty, llvm_payload, .NotAtomic);
        }
        {
            const indices: [2]*const llvm.Value = .{
                index_type.constNull(),
                index_type.constInt(@boolToInt(layout.tag_align < layout.payload_align), .False),
            };
            const field_ptr = self.builder.buildInBoundsGEP(casted_ptr, &indices, indices.len, "");
            const llvm_tag = tag_llvm_ty.constInt(extra.field_index, .False);
            const store_inst = self.builder.buildStore(llvm_tag, field_ptr);
            store_inst.setAlignment(union_obj.tag_ty.abiAlignment(target));
        }

        return result_ptr;
    }

    fn airPrefetch(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const prefetch = self.air.instructions.items(.data)[inst].prefetch;

        comptime assert(@enumToInt(std.builtin.PrefetchOptions.Rw.read) == 0);
        comptime assert(@enumToInt(std.builtin.PrefetchOptions.Rw.write) == 1);

        // TODO these two asserts should be able to be comptime because the type is a u2
        assert(prefetch.locality >= 0);
        assert(prefetch.locality <= 3);

        comptime assert(@enumToInt(std.builtin.PrefetchOptions.Cache.instruction) == 0);
        comptime assert(@enumToInt(std.builtin.PrefetchOptions.Cache.data) == 1);

        // LLVM fails during codegen of instruction cache prefetchs for these architectures.
        // This is an LLVM bug as the prefetch intrinsic should be a noop if not supported
        // by the target.
        // To work around this, don't emit llvm.prefetch in this case.
        // See https://bugs.llvm.org/show_bug.cgi?id=21037
        const target = self.dg.module.getTarget();
        switch (prefetch.cache) {
            .instruction => switch (target.cpu.arch) {
                .x86_64, .i386 => return null,
                .arm, .armeb, .thumb, .thumbeb => {
                    switch (prefetch.rw) {
                        .write => return null,
                        else => {},
                    }
                },
                else => {},
            },
            .data => {},
        }

        const llvm_u8 = self.context.intType(8);
        const llvm_ptr_u8 = llvm_u8.pointerType(0);
        const llvm_u32 = self.context.intType(32);

        const llvm_fn_name = "llvm.prefetch.p0i8";
        const fn_val = self.dg.object.llvm_module.getNamedFunction(llvm_fn_name) orelse blk: {
            // declare void @llvm.prefetch(i8*, i32, i32, i32)
            const llvm_void = self.context.voidType();
            const param_types = [_]*const llvm.Type{
                llvm_ptr_u8, llvm_u32, llvm_u32, llvm_u32,
            };
            const fn_type = llvm.functionType(llvm_void, &param_types, param_types.len, .False);
            break :blk self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        };

        const ptr = try self.resolveInst(prefetch.ptr);
        const ptr_u8 = self.builder.buildBitCast(ptr, llvm_ptr_u8, "");

        const params = [_]*const llvm.Value{
            ptr_u8,
            llvm_u32.constInt(@enumToInt(prefetch.rw), .False),
            llvm_u32.constInt(prefetch.locality, .False),
            llvm_u32.constInt(@enumToInt(prefetch.cache), .False),
        };
        _ = self.builder.buildCall(fn_val, &params, params.len, .C, .Auto, "");
        return null;
    }

    fn softF80TruncOrExt(
        self: *FuncGen,
        operand: *const llvm.Value,
        src_bits: u16,
        dest_bits: u16,
    ) !?*const llvm.Value {
        const target = self.dg.module.getTarget();

        var param_llvm_ty: *const llvm.Type = self.context.intType(80);
        var ret_llvm_ty: *const llvm.Type = param_llvm_ty;
        var fn_name: [*:0]const u8 = undefined;
        var arg = operand;
        var final_cast: ?*const llvm.Type = null;

        assert(src_bits == 80 or dest_bits == 80);

        if (src_bits == 80) switch (dest_bits) {
            16 => {
                // See corresponding condition at definition of
                // __truncxfhf2 in compiler-rt.
                if (target.cpu.arch.isAARCH64()) {
                    ret_llvm_ty = self.context.halfType();
                } else {
                    ret_llvm_ty = self.context.intType(16);
                    final_cast = self.context.halfType();
                }
                fn_name = "__truncxfhf2";
            },
            32 => {
                ret_llvm_ty = self.context.floatType();
                fn_name = "__truncxfsf2";
            },
            64 => {
                ret_llvm_ty = self.context.doubleType();
                fn_name = "__truncxfdf2";
            },
            80 => return operand,
            128 => {
                ret_llvm_ty = self.context.fp128Type();
                fn_name = "__extendxftf2";
            },
            else => unreachable,
        } else switch (src_bits) {
            16 => {
                // See corresponding condition at definition of
                // __extendhfxf2 in compiler-rt.
                param_llvm_ty = if (target.cpu.arch.isAARCH64())
                    self.context.halfType()
                else
                    self.context.intType(16);
                arg = self.builder.buildBitCast(arg, param_llvm_ty, "");
                fn_name = "__extendhfxf2";
            },
            32 => {
                param_llvm_ty = self.context.floatType();
                fn_name = "__extendsfxf2";
            },
            64 => {
                param_llvm_ty = self.context.doubleType();
                fn_name = "__extenddfxf2";
            },
            80 => return operand,
            128 => {
                param_llvm_ty = self.context.fp128Type();
                fn_name = "__trunctfxf2";
            },
            else => unreachable,
        }

        const llvm_fn = self.dg.object.llvm_module.getNamedFunction(fn_name) orelse f: {
            const param_types = [_]*const llvm.Type{param_llvm_ty};
            const fn_type = llvm.functionType(ret_llvm_ty, &param_types, param_types.len, .False);
            break :f self.dg.object.llvm_module.addFunction(fn_name, fn_type);
        };

        var args: [1]*const llvm.Value = .{arg};
        const result = self.builder.buildCall(llvm_fn, &args, args.len, .C, .Auto, "");
        const final_cast_llvm_ty = final_cast orelse return result;
        return self.builder.buildBitCast(result, final_cast_llvm_ty, "");
    }

    fn getErrorNameTable(self: *FuncGen) !*const llvm.Value {
        if (self.dg.object.error_name_table) |table| {
            return table;
        }

        const slice_ty = Type.initTag(.const_slice_u8_sentinel_0);
        const slice_alignment = slice_ty.abiAlignment(self.dg.module.getTarget());
        const llvm_slice_ty = try self.dg.llvmType(slice_ty);
        const llvm_slice_ptr_ty = llvm_slice_ty.pointerType(0); // TODO: Address space

        const error_name_table_global = self.dg.object.llvm_module.addGlobal(llvm_slice_ptr_ty, "__zig_err_name_table");
        error_name_table_global.setInitializer(llvm_slice_ptr_ty.getUndef());
        error_name_table_global.setLinkage(.Private);
        error_name_table_global.setGlobalConstant(.True);
        error_name_table_global.setUnnamedAddr(.True);
        error_name_table_global.setAlignment(slice_alignment);

        self.dg.object.error_name_table = error_name_table_global;
        return error_name_table_global;
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optIsNonNull(self: *FuncGen, opt_handle: *const llvm.Value, is_by_ref: bool) *const llvm.Value {
        if (is_by_ref) {
            const index_type = self.context.intType(32);

            const indices: [2]*const llvm.Value = .{
                index_type.constNull(),
                index_type.constInt(1, .False),
            };

            const field_ptr = self.builder.buildInBoundsGEP(opt_handle, &indices, indices.len, "");
            return self.builder.buildLoad(field_ptr, "");
        }

        return self.builder.buildExtractValue(opt_handle, 1, "");
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optPayloadHandle(self: *FuncGen, opt_handle: *const llvm.Value, is_by_ref: bool) *const llvm.Value {
        if (is_by_ref) {
            // We have a pointer and we need to return a pointer to the first field.
            const index_type = self.context.intType(32);
            const indices: [2]*const llvm.Value = .{
                index_type.constNull(), // dereference the pointer
                index_type.constNull(), // first field is the payload
            };
            return self.builder.buildInBoundsGEP(opt_handle, &indices, indices.len, "");
        }

        return self.builder.buildExtractValue(opt_handle, 0, "");
    }

    fn callFloor(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "floor");
    }

    fn callCeil(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "ceil");
    }

    fn callTrunc(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "trunc");
    }

    fn callFloatUnary(
        self: *FuncGen,
        arg: *const llvm.Value,
        ty: Type,
        name: []const u8,
    ) !*const llvm.Value {
        const target = self.dg.module.getTarget();

        var fn_name_buf: [100]u8 = undefined;
        const llvm_fn_name = switch (ty.zigTypeTag()) {
            .Vector => std.fmt.bufPrintZ(&fn_name_buf, "llvm.{s}.v{d}f{d}", .{
                name, ty.vectorLen(), ty.childType().floatBits(target),
            }) catch unreachable,
            .Float => std.fmt.bufPrintZ(&fn_name_buf, "llvm.{s}.f{d}", .{
                name, ty.floatBits(target),
            }) catch unreachable,
            else => unreachable,
        };

        const llvm_fn = self.dg.object.llvm_module.getNamedFunction(llvm_fn_name) orelse blk: {
            const operand_llvm_ty = try self.dg.llvmType(ty);
            const param_types = [_]*const llvm.Type{operand_llvm_ty};
            const fn_type = llvm.functionType(operand_llvm_ty, &param_types, param_types.len, .False);
            break :blk self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        };

        const args: [1]*const llvm.Value = .{arg};
        return self.builder.buildCall(llvm_fn, &args, args.len, .C, .Auto, "");
    }

    fn fieldPtr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        struct_ptr: *const llvm.Value,
        struct_ptr_ty: Type,
        field_index: u32,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;
        const struct_ty = struct_ptr_ty.childType();
        switch (struct_ty.zigTypeTag()) {
            .Struct => switch (struct_ty.containerLayout()) {
                .Packed => {
                    // From LLVM's perspective, a pointer to a packed struct and a pointer
                    // to a field of a packed struct are the same. The difference is in the
                    // Zig pointer type which provides information for how to mask and shift
                    // out the relevant bits when accessing the pointee.
                    // Here we perform a bitcast because we want to use the host_size
                    // as the llvm pointer element type.
                    const result_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
                    // TODO this can be removed if we change host_size to be bits instead
                    // of bytes.
                    return self.builder.buildBitCast(struct_ptr, result_llvm_ty, "");
                },
                else => {
                    const target = self.dg.module.getTarget();
                    var ty_buf: Type.Payload.Pointer = undefined;
                    if (llvmFieldIndex(struct_ty, field_index, target, &ty_buf)) |llvm_field_index| {
                        return self.builder.buildStructGEP(struct_ptr, llvm_field_index, "");
                    } else {
                        // If we found no index then this means this is a zero sized field at the
                        // end of the struct. Treat our struct pointer as an array of two and get
                        // the index to the element at index `1` to get a pointer to the end of
                        // the struct.
                        const llvm_usize = try self.dg.llvmType(Type.usize);
                        const llvm_index = llvm_usize.constInt(1, .False);
                        const indices: [1]*const llvm.Value = .{llvm_index};
                        return self.builder.buildInBoundsGEP(struct_ptr, &indices, indices.len, "");
                    }
                },
            },
            .Union => return self.unionFieldPtr(inst, struct_ptr, struct_ty, field_index),
            else => unreachable,
        }
    }

    fn unionFieldPtr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        union_ptr: *const llvm.Value,
        union_ty: Type,
        field_index: c_uint,
    ) !?*const llvm.Value {
        const union_obj = union_ty.cast(Type.Payload.Union).?.data;
        const field = &union_obj.fields.values()[field_index];
        const result_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));
        if (!field.ty.hasRuntimeBitsIgnoreComptime()) {
            return null;
        }
        const target = self.dg.module.getTarget();
        const layout = union_ty.unionGetLayout(target);
        const payload_index = @boolToInt(layout.tag_align >= layout.payload_align);
        const union_field_ptr = self.builder.buildStructGEP(union_ptr, payload_index, "");
        return self.builder.buildBitCast(union_field_ptr, result_llvm_ty, "");
    }

    fn sliceElemPtr(
        self: *FuncGen,
        slice: *const llvm.Value,
        index: *const llvm.Value,
    ) *const llvm.Value {
        const base_ptr = self.builder.buildExtractValue(slice, 0, "");
        const indices: [1]*const llvm.Value = .{index};
        return self.builder.buildInBoundsGEP(base_ptr, &indices, indices.len, "");
    }

    fn getIntrinsic(self: *FuncGen, name: []const u8, types: []const *const llvm.Type) *const llvm.Value {
        const id = llvm.lookupIntrinsicID(name.ptr, name.len);
        assert(id != 0);
        return self.llvmModule().getIntrinsicDeclaration(id, types.ptr, types.len);
    }

    /// This function always performs a copy. For isByRef=true types, it creates a new
    /// alloca and copies the value into it, then returns the alloca instruction.
    /// For isByRef=false types, it creates a load instruction and returns it.
    fn load(self: *FuncGen, ptr: *const llvm.Value, ptr_ty: Type) !?*const llvm.Value {
        const info = ptr_ty.ptrInfo().data;
        if (!info.pointee_type.hasRuntimeBitsIgnoreComptime()) return null;

        const target = self.dg.module.getTarget();
        const ptr_alignment = ptr_ty.ptrAlignment(target);
        const ptr_volatile = llvm.Bool.fromBool(ptr_ty.isVolatilePtr());
        if (info.host_size == 0) {
            if (isByRef(info.pointee_type)) {
                const elem_llvm_ty = try self.dg.llvmType(info.pointee_type);
                const result_align = info.pointee_type.abiAlignment(target);
                const max_align = @maximum(result_align, ptr_alignment);
                const result_ptr = self.buildAlloca(elem_llvm_ty);
                result_ptr.setAlignment(max_align);
                const llvm_ptr_u8 = self.context.intType(8).pointerType(0);
                const llvm_usize = self.context.intType(Type.usize.intInfo(target).bits);
                const size_bytes = info.pointee_type.abiSize(target);
                _ = self.builder.buildMemCpy(
                    self.builder.buildBitCast(result_ptr, llvm_ptr_u8, ""),
                    max_align,
                    self.builder.buildBitCast(ptr, llvm_ptr_u8, ""),
                    max_align,
                    llvm_usize.constInt(size_bytes, .False),
                    info.@"volatile",
                );
                return result_ptr;
            }
            const llvm_inst = self.builder.buildLoad(ptr, "");
            llvm_inst.setAlignment(ptr_alignment);
            llvm_inst.setVolatile(ptr_volatile);
            return llvm_inst;
        }

        const int_ptr_ty = self.context.intType(info.host_size * 8).pointerType(0);
        const int_ptr = self.builder.buildBitCast(ptr, int_ptr_ty, "");
        const containing_int = self.builder.buildLoad(int_ptr, "");
        containing_int.setAlignment(ptr_alignment);
        containing_int.setVolatile(ptr_volatile);

        const elem_bits = @intCast(c_uint, ptr_ty.elemType().bitSize(target));
        const shift_amt = containing_int.typeOf().constInt(info.bit_offset, .False);
        const shifted_value = self.builder.buildLShr(containing_int, shift_amt, "");
        const elem_llvm_ty = try self.dg.llvmType(info.pointee_type);

        if (isByRef(info.pointee_type)) {
            const result_align = info.pointee_type.abiAlignment(target);
            const result_ptr = self.buildAlloca(elem_llvm_ty);
            result_ptr.setAlignment(result_align);

            const same_size_int = self.context.intType(elem_bits);
            const truncated_int = self.builder.buildTrunc(shifted_value, same_size_int, "");
            const bitcasted_ptr = self.builder.buildBitCast(result_ptr, same_size_int.pointerType(0), "");
            const store_inst = self.builder.buildStore(truncated_int, bitcasted_ptr);
            store_inst.setAlignment(result_align);
            return result_ptr;
        }

        if (info.pointee_type.zigTypeTag() == .Float) {
            const same_size_int = self.context.intType(elem_bits);
            const truncated_int = self.builder.buildTrunc(shifted_value, same_size_int, "");
            return self.builder.buildBitCast(truncated_int, elem_llvm_ty, "");
        }

        return self.builder.buildTrunc(shifted_value, elem_llvm_ty, "");
    }

    fn store(
        self: *FuncGen,
        ptr: *const llvm.Value,
        ptr_ty: Type,
        elem: *const llvm.Value,
        ordering: llvm.AtomicOrdering,
    ) void {
        const info = ptr_ty.ptrInfo().data;
        const elem_ty = info.pointee_type;
        if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime()) {
            return;
        }
        const target = self.dg.module.getTarget();
        const ptr_alignment = ptr_ty.ptrAlignment(target);
        const ptr_volatile = llvm.Bool.fromBool(info.@"volatile");
        if (info.host_size != 0) {
            const int_ptr_ty = self.context.intType(info.host_size * 8).pointerType(0);
            const int_ptr = self.builder.buildBitCast(ptr, int_ptr_ty, "");
            const containing_int = self.builder.buildLoad(int_ptr, "");
            assert(ordering == .NotAtomic);
            containing_int.setAlignment(ptr_alignment);
            containing_int.setVolatile(ptr_volatile);
            const elem_bits = @intCast(c_uint, ptr_ty.elemType().bitSize(target));
            const containing_int_ty = containing_int.typeOf();
            const shift_amt = containing_int_ty.constInt(info.bit_offset, .False);
            // Convert to equally-sized integer type in order to perform the bit
            // operations on the value to store
            const value_bits_type = self.context.intType(elem_bits);
            const value_bits = self.builder.buildBitCast(elem, value_bits_type, "");

            var mask_val = value_bits_type.constAllOnes();
            mask_val = mask_val.constZExt(containing_int_ty);
            mask_val = mask_val.constShl(shift_amt);
            mask_val = mask_val.constNot();

            const anded_containing_int = self.builder.buildAnd(containing_int, mask_val, "");
            const extended_value = self.builder.buildZExt(value_bits, containing_int_ty, "");
            const shifted_value = self.builder.buildShl(extended_value, shift_amt, "");
            const ored_value = self.builder.buildOr(shifted_value, anded_containing_int, "");

            const store_inst = self.builder.buildStore(ored_value, int_ptr);
            assert(ordering == .NotAtomic);
            store_inst.setAlignment(ptr_alignment);
            store_inst.setVolatile(ptr_volatile);
            return;
        }
        if (!isByRef(elem_ty)) {
            const store_inst = self.builder.buildStore(elem, ptr);
            store_inst.setOrdering(ordering);
            store_inst.setAlignment(ptr_alignment);
            store_inst.setVolatile(ptr_volatile);
            return;
        }
        assert(ordering == .NotAtomic);
        const llvm_ptr_u8 = self.context.intType(8).pointerType(0);
        const size_bytes = elem_ty.abiSize(target);
        _ = self.builder.buildMemCpy(
            self.builder.buildBitCast(ptr, llvm_ptr_u8, ""),
            ptr_ty.ptrAlignment(target),
            self.builder.buildBitCast(elem, llvm_ptr_u8, ""),
            elem_ty.abiAlignment(target),
            self.context.intType(Type.usize.intInfo(target).bits).constInt(size_bytes, .False),
            info.@"volatile",
        );
    }
};

fn initializeLLVMTarget(arch: std.Target.Cpu.Arch) void {
    switch (arch) {
        .aarch64, .aarch64_be, .aarch64_32 => {
            llvm.LLVMInitializeAArch64Target();
            llvm.LLVMInitializeAArch64TargetInfo();
            llvm.LLVMInitializeAArch64TargetMC();
            llvm.LLVMInitializeAArch64AsmPrinter();
            llvm.LLVMInitializeAArch64AsmParser();
        },
        .amdgcn => {
            llvm.LLVMInitializeAMDGPUTarget();
            llvm.LLVMInitializeAMDGPUTargetInfo();
            llvm.LLVMInitializeAMDGPUTargetMC();
            llvm.LLVMInitializeAMDGPUAsmPrinter();
            llvm.LLVMInitializeAMDGPUAsmParser();
        },
        .thumb, .thumbeb, .arm, .armeb => {
            llvm.LLVMInitializeARMTarget();
            llvm.LLVMInitializeARMTargetInfo();
            llvm.LLVMInitializeARMTargetMC();
            llvm.LLVMInitializeARMAsmPrinter();
            llvm.LLVMInitializeARMAsmParser();
        },
        .avr => {
            llvm.LLVMInitializeAVRTarget();
            llvm.LLVMInitializeAVRTargetInfo();
            llvm.LLVMInitializeAVRTargetMC();
            llvm.LLVMInitializeAVRAsmPrinter();
            llvm.LLVMInitializeAVRAsmParser();
        },
        .bpfel, .bpfeb => {
            llvm.LLVMInitializeBPFTarget();
            llvm.LLVMInitializeBPFTargetInfo();
            llvm.LLVMInitializeBPFTargetMC();
            llvm.LLVMInitializeBPFAsmPrinter();
            llvm.LLVMInitializeBPFAsmParser();
        },
        .hexagon => {
            llvm.LLVMInitializeHexagonTarget();
            llvm.LLVMInitializeHexagonTargetInfo();
            llvm.LLVMInitializeHexagonTargetMC();
            llvm.LLVMInitializeHexagonAsmPrinter();
            llvm.LLVMInitializeHexagonAsmParser();
        },
        .lanai => {
            llvm.LLVMInitializeLanaiTarget();
            llvm.LLVMInitializeLanaiTargetInfo();
            llvm.LLVMInitializeLanaiTargetMC();
            llvm.LLVMInitializeLanaiAsmPrinter();
            llvm.LLVMInitializeLanaiAsmParser();
        },
        .mips, .mipsel, .mips64, .mips64el => {
            llvm.LLVMInitializeMipsTarget();
            llvm.LLVMInitializeMipsTargetInfo();
            llvm.LLVMInitializeMipsTargetMC();
            llvm.LLVMInitializeMipsAsmPrinter();
            llvm.LLVMInitializeMipsAsmParser();
        },
        .msp430 => {
            llvm.LLVMInitializeMSP430Target();
            llvm.LLVMInitializeMSP430TargetInfo();
            llvm.LLVMInitializeMSP430TargetMC();
            llvm.LLVMInitializeMSP430AsmPrinter();
            llvm.LLVMInitializeMSP430AsmParser();
        },
        .nvptx, .nvptx64 => {
            llvm.LLVMInitializeNVPTXTarget();
            llvm.LLVMInitializeNVPTXTargetInfo();
            llvm.LLVMInitializeNVPTXTargetMC();
            llvm.LLVMInitializeNVPTXAsmPrinter();
            // There is no LLVMInitializeNVPTXAsmParser function available.
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => {
            llvm.LLVMInitializePowerPCTarget();
            llvm.LLVMInitializePowerPCTargetInfo();
            llvm.LLVMInitializePowerPCTargetMC();
            llvm.LLVMInitializePowerPCAsmPrinter();
            llvm.LLVMInitializePowerPCAsmParser();
        },
        .riscv32, .riscv64 => {
            llvm.LLVMInitializeRISCVTarget();
            llvm.LLVMInitializeRISCVTargetInfo();
            llvm.LLVMInitializeRISCVTargetMC();
            llvm.LLVMInitializeRISCVAsmPrinter();
            llvm.LLVMInitializeRISCVAsmParser();
        },
        .sparc, .sparcv9, .sparcel => {
            llvm.LLVMInitializeSparcTarget();
            llvm.LLVMInitializeSparcTargetInfo();
            llvm.LLVMInitializeSparcTargetMC();
            llvm.LLVMInitializeSparcAsmPrinter();
            llvm.LLVMInitializeSparcAsmParser();
        },
        .s390x => {
            llvm.LLVMInitializeSystemZTarget();
            llvm.LLVMInitializeSystemZTargetInfo();
            llvm.LLVMInitializeSystemZTargetMC();
            llvm.LLVMInitializeSystemZAsmPrinter();
            llvm.LLVMInitializeSystemZAsmParser();
        },
        .wasm32, .wasm64 => {
            llvm.LLVMInitializeWebAssemblyTarget();
            llvm.LLVMInitializeWebAssemblyTargetInfo();
            llvm.LLVMInitializeWebAssemblyTargetMC();
            llvm.LLVMInitializeWebAssemblyAsmPrinter();
            llvm.LLVMInitializeWebAssemblyAsmParser();
        },
        .i386, .x86_64 => {
            llvm.LLVMInitializeX86Target();
            llvm.LLVMInitializeX86TargetInfo();
            llvm.LLVMInitializeX86TargetMC();
            llvm.LLVMInitializeX86AsmPrinter();
            llvm.LLVMInitializeX86AsmParser();
        },
        .xcore => {
            llvm.LLVMInitializeXCoreTarget();
            llvm.LLVMInitializeXCoreTargetInfo();
            llvm.LLVMInitializeXCoreTargetMC();
            llvm.LLVMInitializeXCoreAsmPrinter();
            // There is no LLVMInitializeXCoreAsmParser function.
        },
        .m68k => {
            if (build_options.llvm_has_m68k) {
                llvm.LLVMInitializeM68kTarget();
                llvm.LLVMInitializeM68kTargetInfo();
                llvm.LLVMInitializeM68kTargetMC();
                llvm.LLVMInitializeM68kAsmPrinter();
                llvm.LLVMInitializeM68kAsmParser();
            }
        },
        .csky => {
            if (build_options.llvm_has_csky) {
                llvm.LLVMInitializeCSKYTarget();
                llvm.LLVMInitializeCSKYTargetInfo();
                llvm.LLVMInitializeCSKYTargetMC();
                // There is no LLVMInitializeCSKYAsmPrinter function.
                llvm.LLVMInitializeCSKYAsmParser();
            }
        },
        .ve => {
            if (build_options.llvm_has_ve) {
                llvm.LLVMInitializeVETarget();
                llvm.LLVMInitializeVETargetInfo();
                llvm.LLVMInitializeVETargetMC();
                llvm.LLVMInitializeVEAsmPrinter();
                llvm.LLVMInitializeVEAsmParser();
            }
        },
        .arc => {
            if (build_options.llvm_has_arc) {
                llvm.LLVMInitializeARCTarget();
                llvm.LLVMInitializeARCTargetInfo();
                llvm.LLVMInitializeARCTargetMC();
                llvm.LLVMInitializeARCAsmPrinter();
                // There is no LLVMInitializeARCAsmParser function.
            }
        },

        // LLVM backends that have no initialization functions.
        .tce,
        .tcele,
        .r600,
        .le32,
        .le64,
        .amdil,
        .amdil64,
        .hsail,
        .hsail64,
        .shave,
        .spir,
        .spir64,
        .kalimba,
        .renderscript32,
        .renderscript64,
        => {},

        .spu_2 => unreachable, // LLVM does not support this backend
        .spirv32 => unreachable, // LLVM does not support this backend
        .spirv64 => unreachable, // LLVM does not support this backend
    }
}

fn toLlvmAtomicOrdering(atomic_order: std.builtin.AtomicOrder) llvm.AtomicOrdering {
    return switch (atomic_order) {
        .Unordered => .Unordered,
        .Monotonic => .Monotonic,
        .Acquire => .Acquire,
        .Release => .Release,
        .AcqRel => .AcquireRelease,
        .SeqCst => .SequentiallyConsistent,
    };
}

fn toLlvmAtomicRmwBinOp(
    op: std.builtin.AtomicRmwOp,
    is_signed: bool,
    is_float: bool,
) llvm.AtomicRMWBinOp {
    return switch (op) {
        .Xchg => .Xchg,
        .Add => if (is_float) llvm.AtomicRMWBinOp.FAdd else return .Add,
        .Sub => if (is_float) llvm.AtomicRMWBinOp.FSub else return .Sub,
        .And => .And,
        .Nand => .Nand,
        .Or => .Or,
        .Xor => .Xor,
        .Max => if (is_signed) llvm.AtomicRMWBinOp.Max else return .UMax,
        .Min => if (is_signed) llvm.AtomicRMWBinOp.Min else return .UMin,
    };
}

fn toLlvmCallConv(cc: std.builtin.CallingConvention, target: std.Target) llvm.CallConv {
    return switch (cc) {
        .Unspecified, .Inline, .Async => .Fast,
        .C, .Naked => .C,
        .Stdcall => .X86_StdCall,
        .Fastcall => .X86_FastCall,
        .Vectorcall => return switch (target.cpu.arch) {
            .i386, .x86_64 => .X86_VectorCall,
            .aarch64, .aarch64_be, .aarch64_32 => .AArch64_VectorCall,
            else => unreachable,
        },
        .Thiscall => .X86_ThisCall,
        .APCS => .ARM_APCS,
        .AAPCS => .ARM_AAPCS,
        .AAPCSVFP => .ARM_AAPCS_VFP,
        .Interrupt => return switch (target.cpu.arch) {
            .i386, .x86_64 => .X86_INTR,
            .avr => .AVR_INTR,
            .msp430 => .MSP430_INTR,
            else => unreachable,
        },
        .Signal => .AVR_SIGNAL,
        .SysV => .X86_64_SysV,
        .PtxKernel => return switch (target.cpu.arch) {
            .nvptx, .nvptx64 => .PTX_Kernel,
            else => unreachable,
        },
    };
}

/// Take into account 0 bit fields and padding. Returns null if an llvm
/// field could not be found.
/// This only happens if you want the field index of a zero sized field at
/// the end of the struct.
fn llvmFieldIndex(
    ty: Type,
    field_index: usize,
    target: std.Target,
    ptr_pl_buf: *Type.Payload.Pointer,
) ?c_uint {
    // Detects where we inserted extra padding fields so that we can skip
    // over them in this function.
    comptime assert(struct_layout_version == 2);
    var offset: u64 = 0;
    var big_align: u32 = 0;

    if (ty.isTupleOrAnonStruct()) {
        const tuple = ty.tupleFields();
        var llvm_field_index: c_uint = 0;
        for (tuple.types) |field_ty, i| {
            if (tuple.values[i].tag() != .unreachable_value) continue;

            const field_align = field_ty.abiAlignment(target);
            big_align = @maximum(big_align, field_align);
            const prev_offset = offset;
            offset = std.mem.alignForwardGeneric(u64, offset, field_align);

            const padding_len = offset - prev_offset;
            if (padding_len > 0) {
                llvm_field_index += 1;
            }

            if (field_index == i) {
                ptr_pl_buf.* = .{
                    .data = .{
                        .pointee_type = field_ty,
                        .@"align" = field_align,
                        .@"addrspace" = .generic,
                    },
                };
                return llvm_field_index;
            }

            llvm_field_index += 1;
            offset += field_ty.abiSize(target);
        }
        return null;
    }
    assert(ty.containerLayout() != .Packed);

    var llvm_field_index: c_uint = 0;
    for (ty.structFields().values()) |field, i| {
        if (field.is_comptime or !field.ty.hasRuntimeBitsIgnoreComptime()) continue;

        const field_align = field.normalAlignment(target);
        big_align = @maximum(big_align, field_align);
        const prev_offset = offset;
        offset = std.mem.alignForwardGeneric(u64, offset, field_align);

        const padding_len = offset - prev_offset;
        if (padding_len > 0) {
            llvm_field_index += 1;
        }

        if (field_index == i) {
            ptr_pl_buf.* = .{
                .data = .{
                    .pointee_type = field.ty,
                    .@"align" = field_align,
                    .@"addrspace" = .generic,
                },
            };
            return llvm_field_index;
        }

        llvm_field_index += 1;
        offset += field.ty.abiSize(target);
    } else {
        // We did not find an llvm field that corresponds to this zig field.
        return null;
    }
}

fn firstParamSRet(fn_info: Type.Payload.Function.Data, target: std.Target) bool {
    switch (fn_info.cc) {
        .Unspecified, .Inline => return isByRef(fn_info.return_type),
        .C => switch (target.cpu.arch) {
            .mips, .mipsel => return false,
            .x86_64 => switch (target.os.tag) {
                .windows => return x86_64_abi.classifyWindows(fn_info.return_type, target) == .memory,
                else => return x86_64_abi.classifySystemV(fn_info.return_type, target)[0] == .memory,
            },
            else => return false, // TODO investigate C ABI for other architectures
        },
        else => return false,
    }
}

/// In order to support the C calling convention, some return types need to be lowered
/// completely differently in the function prototype to honor the C ABI, and then
/// be effectively bitcasted to the actual return type.
fn lowerFnRetTy(dg: *DeclGen, fn_info: Type.Payload.Function.Data) !*const llvm.Type {
    if (!fn_info.return_type.hasRuntimeBitsIgnoreComptime()) {
        return dg.context.voidType();
    }
    const target = dg.module.getTarget();
    switch (fn_info.cc) {
        .Unspecified, .Inline => {
            if (isByRef(fn_info.return_type)) {
                return dg.context.voidType();
            } else {
                return dg.llvmType(fn_info.return_type);
            }
        },
        .C => {
            const is_scalar = switch (fn_info.return_type.zigTypeTag()) {
                .Void,
                .Bool,
                .NoReturn,
                .Int,
                .Float,
                .Pointer,
                .Optional,
                .ErrorSet,
                .Enum,
                .AnyFrame,
                .Vector,
                => true,

                else => false,
            };
            switch (target.cpu.arch) {
                .mips, .mipsel => return dg.llvmType(fn_info.return_type),
                .x86_64 => switch (target.os.tag) {
                    .windows => switch (x86_64_abi.classifyWindows(fn_info.return_type, target)) {
                        .integer => {
                            if (is_scalar) {
                                return dg.llvmType(fn_info.return_type);
                            } else {
                                const abi_size = fn_info.return_type.abiSize(target);
                                return dg.context.intType(@intCast(c_uint, abi_size * 8));
                            }
                        },
                        .memory => return dg.context.voidType(),
                        .sse => return dg.llvmType(fn_info.return_type),
                        else => unreachable,
                    },
                    else => {
                        if (is_scalar) {
                            return dg.llvmType(fn_info.return_type);
                        }
                        const classes = x86_64_abi.classifySystemV(fn_info.return_type, target);
                        if (classes[0] == .memory) {
                            return dg.context.voidType();
                        }
                        var llvm_types_buffer: [8]*const llvm.Type = undefined;
                        var llvm_types_index: u32 = 0;
                        for (classes) |class| {
                            switch (class) {
                                .integer => {
                                    llvm_types_buffer[llvm_types_index] = dg.context.intType(64);
                                    llvm_types_index += 1;
                                },
                                .sse => {
                                    @panic("TODO");
                                },
                                .sseup => {
                                    @panic("TODO");
                                },
                                .x87 => {
                                    @panic("TODO");
                                },
                                .x87up => {
                                    @panic("TODO");
                                },
                                .complex_x87 => {
                                    @panic("TODO");
                                },
                                .memory => unreachable, // handled above
                                .none => break,
                            }
                        }
                        if (classes[0] == .integer and classes[1] == .none) {
                            return llvm_types_buffer[0];
                        }
                        return dg.context.structType(&llvm_types_buffer, llvm_types_index, .False);
                    },
                },
                // TODO investigate C ABI for other architectures
                else => return dg.llvmType(fn_info.return_type),
            }
        },
        else => return dg.llvmType(fn_info.return_type),
    }
}

fn lowerFnParamTy(dg: *DeclGen, cc: std.builtin.CallingConvention, ty: Type) !*const llvm.Type {
    assert(ty.hasRuntimeBitsIgnoreComptime());
    const target = dg.module.getTarget();
    switch (cc) {
        .Unspecified, .Inline => {
            const raw_llvm_ty = try dg.llvmType(ty);
            if (isByRef(ty)) {
                return raw_llvm_ty.pointerType(0);
            } else {
                return raw_llvm_ty;
            }
        },
        .C => {
            const is_scalar = switch (ty.zigTypeTag()) {
                .Void,
                .Bool,
                .NoReturn,
                .Int,
                .Float,
                .Pointer,
                .Optional,
                .ErrorSet,
                .Enum,
                .AnyFrame,
                .Vector,
                => true,

                else => false,
            };
            switch (target.cpu.arch) {
                .mips, .mipsel => return dg.llvmType(ty),
                .x86_64 => switch (target.os.tag) {
                    .windows => switch (x86_64_abi.classifyWindows(ty, target)) {
                        .integer => {
                            if (is_scalar) {
                                return dg.llvmType(ty);
                            } else {
                                const abi_size = ty.abiSize(target);
                                return dg.context.intType(@intCast(c_uint, abi_size * 8));
                            }
                        },
                        .memory => return (try dg.llvmType(ty)).pointerType(0),
                        .sse => return dg.llvmType(ty),
                        else => unreachable,
                    },
                    else => {
                        if (is_scalar) {
                            return dg.llvmType(ty);
                        }
                        const classes = x86_64_abi.classifySystemV(ty, target);
                        if (classes[0] == .memory) {
                            return (try dg.llvmType(ty)).pointerType(0);
                        }
                        var llvm_types_buffer: [8]*const llvm.Type = undefined;
                        var llvm_types_index: u32 = 0;
                        for (classes) |class| {
                            switch (class) {
                                .integer => {
                                    llvm_types_buffer[llvm_types_index] = dg.context.intType(64);
                                    llvm_types_index += 1;
                                },
                                .sse => {
                                    @panic("TODO");
                                },
                                .sseup => {
                                    @panic("TODO");
                                },
                                .x87 => {
                                    @panic("TODO");
                                },
                                .x87up => {
                                    @panic("TODO");
                                },
                                .complex_x87 => {
                                    @panic("TODO");
                                },
                                .memory => unreachable, // handled above
                                .none => break,
                            }
                        }
                        if (classes[0] == .integer and classes[1] == .none) {
                            return llvm_types_buffer[0];
                        }
                        return dg.context.structType(&llvm_types_buffer, llvm_types_index, .False);
                    },
                },
                // TODO investigate C ABI for other architectures
                else => return dg.llvmType(ty),
            }
        },
        else => return dg.llvmType(ty),
    }
}

fn isByRef(ty: Type) bool {
    // For tuples and structs, if there are more than this many non-void
    // fields, then we make it byref, otherwise byval.
    const max_fields_byval = 2;

    switch (ty.zigTypeTag()) {
        .Type,
        .ComptimeInt,
        .ComptimeFloat,
        .EnumLiteral,
        .Undefined,
        .Null,
        .BoundFn,
        .Opaque,
        => unreachable,

        .NoReturn,
        .Void,
        .Bool,
        .Int,
        .Float,
        .Pointer,
        .ErrorSet,
        .Fn,
        .Enum,
        .Vector,
        .AnyFrame,
        => return false,

        .Array, .Frame => return ty.hasRuntimeBitsIgnoreComptime(),
        .Struct => {
            // Packed structs are represented to LLVM as integers.
            if (ty.containerLayout() == .Packed) return false;
            if (ty.isTupleOrAnonStruct()) {
                const tuple = ty.tupleFields();
                var count: usize = 0;
                for (tuple.values) |field_val, i| {
                    if (field_val.tag() != .unreachable_value) continue;

                    count += 1;
                    if (count > max_fields_byval) return true;
                    if (isByRef(tuple.types[i])) return true;
                }
                return false;
            }
            var count: usize = 0;
            const fields = ty.structFields();
            for (fields.values()) |field| {
                if (field.is_comptime or !field.ty.hasRuntimeBitsIgnoreComptime()) continue;

                count += 1;
                if (count > max_fields_byval) return true;
                if (isByRef(field.ty)) return true;
            }
            return false;
        },
        .Union => return ty.hasRuntimeBitsIgnoreComptime(),
        .ErrorUnion => return isByRef(ty.errorUnionPayload()),
        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            return isByRef(ty.optionalChild(&buf));
        },
    }
}

/// This function returns true if we expect LLVM to lower x86_fp80 correctly
/// and false if we expect LLVM to crash if it counters an x86_fp80 type.
fn backendSupportsF80(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .x86_64, .i386 => true,
        else => false,
    };
}

/// We need to insert extra padding if LLVM's isn't enough.
/// However we don't want to ever call LLVMABIAlignmentOfType or
/// LLVMABISizeOfType because these functions will trip assertions
/// when using them for self-referential types. So our strategy is
/// to use non-packed llvm structs but to emit all padding explicitly.
/// We can do this because for all types, Zig ABI alignment >= LLVM ABI
/// alignment.
const struct_layout_version = 2;

/// We use the least significant bit of the pointer address to tell us
/// whether the type is fully resolved. Types that are only fwd declared
/// have the LSB flipped to a 1.
const AnnotatedDITypePtr = enum(usize) {
    _,

    fn initFwd(di_type: *llvm.DIType) AnnotatedDITypePtr {
        const addr = @ptrToInt(di_type);
        assert(@truncate(u1, addr) == 0);
        return @intToEnum(AnnotatedDITypePtr, addr | 1);
    }

    fn initFull(di_type: *llvm.DIType) AnnotatedDITypePtr {
        const addr = @ptrToInt(di_type);
        return @intToEnum(AnnotatedDITypePtr, addr);
    }

    fn init(di_type: *llvm.DIType, resolve: Object.DebugResolveStatus) AnnotatedDITypePtr {
        const addr = @ptrToInt(di_type);
        const bit = @boolToInt(resolve == .fwd);
        return @intToEnum(AnnotatedDITypePtr, addr | bit);
    }

    fn toDIType(self: AnnotatedDITypePtr) *llvm.DIType {
        const fixed_addr = @enumToInt(self) & ~@as(usize, 1);
        return @intToPtr(*llvm.DIType, fixed_addr);
    }

    fn isFwdOnly(self: AnnotatedDITypePtr) bool {
        return @truncate(u1, @enumToInt(self)) != 0;
    }
};

const lt_errors_fn_name = "__zig_lt_errors_len";
