const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Compilation = @import("../Compilation.zig");
const llvm = @import("llvm/bindings.zig");
const link = @import("../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const native_endian = builtin.cpu.arch.endian();

const build_options = @import("build_options");
const Module = @import("../Module.zig");
const TypedValue = @import("../TypedValue.zig");
const Zir = @import("../Zir.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");

const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;

const LazySrcLoc = Module.LazySrcLoc;

const Error = error{ OutOfMemory, CodegenFail };

pub fn targetTriple(allocator: *Allocator, target: std.Target) ![:0]u8 {
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
    llvm_module: *const llvm.Module,
    context: *const llvm.Context,
    target_machine: *const llvm.TargetMachine,
    /// Ideally we would use `llvm_module.getNamedFunction` to go from *Decl to LLVM function,
    /// but that has some downsides:
    /// * we have to compute the fully qualified name every time we want to do the lookup
    /// * for externally linked functions, the name is not fully qualified, but when
    ///   a Decl goes from exported to not exported and vice-versa, we would use the wrong
    ///   version of the name and incorrectly get function not found in the llvm module.
    /// * it works for functions not all globals.
    /// Therefore, this table keeps track of the mapping.
    decl_map: std.AutoHashMapUnmanaged(*const Module.Decl, *const llvm.Value),
    /// Maps Zig types to LLVM types. The table memory itself is backed by the GPA of
    /// the compiler, but the Type/Value memory here is backed by `type_map_arena`.
    /// TODO we need to remove entries from this map in response to incremental compilation
    /// but I think the frontend won't tell us about types that get deleted because
    /// hasCodeGenBits() is false for types.
    type_map: TypeMap,
    /// The backing memory for `type_map`. Periodically garbage collected after flush().
    /// The code for doing the periodical GC is not yet implemented.
    type_map_arena: std.heap.ArenaAllocator,
    /// Where to put the output object file, relative to bin_file.options.emit directory.
    sub_path: []const u8,

    pub const TypeMap = std.HashMapUnmanaged(
        Type,
        *const llvm.Type,
        Type.HashContext64,
        std.hash_map.default_max_load_percentage,
    );

    pub fn create(gpa: *Allocator, sub_path: []const u8, options: link.Options) !*Object {
        const obj = try gpa.create(Object);
        errdefer gpa.destroy(obj);
        obj.* = try Object.init(gpa, sub_path, options);
        return obj;
    }

    pub fn init(gpa: *Allocator, sub_path: []const u8, options: link.Options) !Object {
        const context = llvm.Context.create();
        errdefer context.dispose();

        initializeLLVMTarget(options.target.cpu.arch);

        const root_nameZ = try gpa.dupeZ(u8, options.root_name);
        defer gpa.free(root_nameZ);
        const llvm_module = llvm.Module.createWithName(root_nameZ.ptr, context);
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

        // TODO a way to override this as part of std.Target ABI?
        const abi_name: ?[*:0]const u8 = switch (options.target.cpu.arch) {
            .riscv32 => switch (options.target.os.tag) {
                .linux => "ilp32d",
                else => "ilp32",
            },
            .riscv64 => switch (options.target.os.tag) {
                .linux => "lp64d",
                else => "lp64",
            },
            else => null,
        };

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
            abi_name,
        );
        errdefer target_machine.dispose();

        const target_data = target_machine.createTargetDataLayout();
        defer target_data.dispose();

        llvm_module.setModuleDataLayout(target_data);

        return Object{
            .llvm_module = llvm_module,
            .context = context,
            .target_machine = target_machine,
            .decl_map = .{},
            .type_map = .{},
            .type_map_arena = std.heap.ArenaAllocator.init(gpa),
            .sub_path = sub_path,
        };
    }

    pub fn deinit(self: *Object, gpa: *Allocator) void {
        self.target_machine.dispose();
        self.llvm_module.dispose();
        self.context.dispose();
        self.decl_map.deinit(gpa);
        self.type_map.deinit(gpa);
        self.type_map_arena.deinit();
        self.* = undefined;
    }

    pub fn destroy(self: *Object, gpa: *Allocator) void {
        self.deinit(gpa);
        gpa.destroy(self);
    }

    fn locPath(
        arena: *Allocator,
        opt_loc: ?Compilation.EmitLoc,
        cache_directory: Compilation.Directory,
    ) !?[*:0]u8 {
        const loc = opt_loc orelse return null;
        const directory = loc.directory orelse cache_directory;
        const slice = try directory.joinZ(arena, &[_][]const u8{loc.basename});
        return slice.ptr;
    }

    pub fn flushModule(self: *Object, comp: *Compilation) !void {
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
        const arena = &arena_allocator.allocator;

        const mod = comp.bin_file.options.module.?;
        const cache_dir = mod.zig_cache_artifact_directory;

        const emit_bin_path: ?[*:0]const u8 = if (comp.bin_file.options.emit) |emit|
            try emit.directory.joinZ(arena, &[_][]const u8{self.sub_path})
        else
            null;

        const emit_asm_path = try locPath(arena, comp.emit_asm, cache_dir);
        const emit_llvm_ir_path = try locPath(arena, comp.emit_llvm_ir, cache_dir);
        const emit_llvm_bc_path = try locPath(arena, comp.emit_llvm_bc, cache_dir);

        const debug_emit_path = emit_bin_path orelse "(none)";
        log.debug("emit LLVM object to {s}", .{debug_emit_path});

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

            const emit_asm_msg = emit_asm_path orelse "(none)";
            const emit_bin_msg = emit_bin_path orelse "(none)";
            const emit_llvm_ir_msg = emit_llvm_ir_path orelse "(none)";
            const emit_llvm_bc_msg = emit_llvm_bc_path orelse "(none)";
            log.err("LLVM failed to emit asm={s} bin={s} ir={s} bc={s}: {s}", .{
                emit_asm_msg,  emit_bin_msg, emit_llvm_ir_msg, emit_llvm_bc_msg,
                error_message,
            });
            return error.FailedToEmit;
        }
    }

    pub fn updateFunc(
        self: *Object,
        module: *Module,
        func: *Module.Fn,
        air: Air,
        liveness: Liveness,
    ) !void {
        const decl = func.owner_decl;

        var dg: DeclGen = .{
            .context = self.context,
            .object = self,
            .module = module,
            .decl = decl,
            .err_msg = null,
            .gpa = module.gpa,
        };

        const llvm_func = try dg.resolveLlvmFunction(decl);

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

        // This gets the LLVM values from the function and stores them in `dg.args`.
        const fn_info = decl.ty.fnInfo();
        const ret_ty_by_ref = isByRef(fn_info.return_type);
        const ret_ptr = if (ret_ty_by_ref) llvm_func.getParam(0) else null;

        var args = std.ArrayList(*const llvm.Value).init(dg.gpa);
        defer args.deinit();

        const param_offset: c_uint = @boolToInt(ret_ptr != null);
        for (fn_info.param_types) |param_ty| {
            if (!param_ty.hasCodeGenBits()) continue;

            const llvm_arg_i = @intCast(c_uint, args.items.len) + param_offset;
            try args.append(llvm_func.getParam(llvm_arg_i));
        }

        // Remove all the basic blocks of a function in order to start over, generating
        // LLVM IR from an empty function body.
        while (llvm_func.getFirstBasicBlock()) |bb| {
            bb.deleteBasicBlock();
        }

        const builder = dg.context.createBuilder();

        const entry_block = dg.context.appendBasicBlock(llvm_func, "Entry");
        builder.positionBuilderAtEnd(entry_block);

        var fg: FuncGen = .{
            .gpa = dg.gpa,
            .air = air,
            .liveness = liveness,
            .context = dg.context,
            .dg = &dg,
            .builder = builder,
            .ret_ptr = ret_ptr,
            .args = args.toOwnedSlice(),
            .arg_index = 0,
            .func_inst_table = .{},
            .llvm_func = llvm_func,
            .blocks = .{},
            .single_threaded = module.comp.bin_file.options.single_threaded,
        };
        defer fg.deinit();

        fg.genBody(air.getMainBody()) catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };

        const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
        try self.updateDeclExports(module, decl, decl_exports);
    }

    pub fn updateDecl(self: *Object, module: *Module, decl: *Module.Decl) !void {
        var dg: DeclGen = .{
            .context = self.context,
            .object = self,
            .module = module,
            .decl = decl,
            .err_msg = null,
            .gpa = module.gpa,
        };
        dg.genDecl() catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl, dg.err_msg.?);
                dg.err_msg = null;
                return;
            },
            else => |e| return e,
        };
        const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
        try self.updateDeclExports(module, decl, decl_exports);
    }

    pub fn updateDeclExports(
        self: *Object,
        module: *const Module,
        decl: *const Module.Decl,
        exports: []const *Module.Export,
    ) !void {
        // If the module does not already have the function, we ignore this function call
        // because we call `updateDeclExports` at the end of `updateFunc` and `updateDecl`.
        const llvm_global = self.decl_map.get(decl) orelse return;
        const is_extern = decl.isExtern();
        if (is_extern) {
            llvm_global.setValueName(decl.name);
            llvm_global.setUnnamedAddr(.False);
            llvm_global.setLinkage(.External);
        } else if (exports.len != 0) {
            const exp_name = exports[0].options.name;
            llvm_global.setValueName2(exp_name.ptr, exp_name.len);
            llvm_global.setUnnamedAddr(.False);
            switch (exports[0].options.linkage) {
                .Internal => unreachable,
                .Strong => llvm_global.setLinkage(.External),
                .Weak => llvm_global.setLinkage(.WeakODR),
                .LinkOnce => llvm_global.setLinkage(.LinkOnceODR),
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
            const fqn = try decl.getFullyQualifiedName(module.gpa);
            defer module.gpa.free(fqn);
            llvm_global.setValueName2(fqn.ptr, fqn.len);
            llvm_global.setLinkage(.Internal);
            llvm_global.setUnnamedAddr(.True);
        }
    }

    pub fn freeDecl(self: *Object, decl: *Module.Decl) void {
        const llvm_value = self.decl_map.get(decl) orelse return;
        llvm_value.deleteGlobal();
    }
};

pub const DeclGen = struct {
    context: *const llvm.Context,
    object: *Object,
    module: *Module,
    decl: *Module.Decl,
    gpa: *Allocator,
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

    fn genDecl(self: *DeclGen) !void {
        const decl = self.decl;
        assert(decl.has_tv);

        log.debug("gen: {s} type: {}, value: {}", .{ decl.name, decl.ty, decl.val });

        if (decl.val.castTag(.function)) |func_payload| {
            _ = func_payload;
            @panic("TODO llvm backend genDecl function pointer");
        } else if (decl.val.castTag(.extern_fn)) |extern_fn| {
            _ = try self.resolveLlvmFunction(extern_fn.data);
        } else {
            const target = self.module.getTarget();
            const global = try self.resolveGlobalDecl(decl);
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
                const llvm_init = try self.genTypedValue(.{ .ty = decl.ty, .val = init_val });
                global.setInitializer(llvm_init);
            }
        }
    }

    /// If the llvm function does not exist, create it.
    /// Note that this can be called before the function's semantic analysis has
    /// completed, so if any attributes rely on that, they must be done in updateFunc, not here.
    fn resolveLlvmFunction(dg: *DeclGen, decl: *Module.Decl) !*const llvm.Value {
        const gop = try dg.object.decl_map.getOrPut(dg.gpa, decl);
        if (gop.found_existing) return gop.value_ptr.*;

        assert(decl.has_tv);
        const zig_fn_type = decl.ty;
        const fn_info = zig_fn_type.fnInfo();
        const target = dg.module.getTarget();
        const sret = firstParamSRet(fn_info, target);

        const return_type = fn_info.return_type;
        const raw_llvm_ret_ty = try dg.llvmType(return_type);

        const fn_type = try dg.llvmType(zig_fn_type);

        const fqn = try decl.getFullyQualifiedName(dg.gpa);
        defer dg.gpa.free(fqn);

        const llvm_addrspace = dg.llvmAddressSpace(decl.@"addrspace");
        const llvm_fn = dg.llvmModule().addFunctionInAddressSpace(fqn, fn_type, llvm_addrspace);
        gop.value_ptr.* = llvm_fn;

        const is_extern = decl.val.tag() == .extern_fn;
        if (!is_extern) {
            llvm_fn.setLinkage(.Internal);
            llvm_fn.setUnnamedAddr(.True);
        }

        if (sret) {
            dg.addArgAttr(llvm_fn, 0, "nonnull"); // Sret pointers must not be address 0
            dg.addArgAttr(llvm_fn, 0, "noalias");
            llvm_fn.addSretAttr(0, raw_llvm_ret_ty);
        }

        // Set parameter attributes.
        var llvm_param_i: c_uint = @boolToInt(sret);
        for (fn_info.param_types) |param_ty| {
            if (!param_ty.hasCodeGenBits()) continue;

            if (isByRef(param_ty)) {
                dg.addArgAttr(llvm_fn, llvm_param_i, "nonnull");
                // TODO readonly, noalias, align
            }
            llvm_param_i += 1;
        }

        if (dg.module.comp.bin_file.options.skip_linker_dependencies) {
            // The intent here is for compiler-rt and libc functions to not generate
            // infinite recursion. For example, if we are compiling the memcpy function,
            // and llvm detects that the body is equivalent to memcpy, it may replace the
            // body of memcpy with a call to memcpy, which would then cause a stack
            // overflow instead of performing memcpy.
            dg.addFnAttr(llvm_fn, "nobuiltin");
        }

        // TODO: more attributes. see codegen.cpp `make_fn_llvm_value`.
        if (fn_info.cc == .Naked) {
            dg.addFnAttr(llvm_fn, "naked");
        } else {
            llvm_fn.setFunctionCallConv(toLlvmCallConv(fn_info.cc, target));
        }

        // Function attributes that are independent of analysis results of the function body.
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
        if (dg.module.comp.bin_file.options.optimize_mode == .ReleaseSmall) {
            dg.addFnAttr(llvm_fn, "minsize");
            dg.addFnAttr(llvm_fn, "optsize");
        }
        if (dg.module.comp.bin_file.options.tsan) {
            dg.addFnAttr(llvm_fn, "sanitize_thread");
        }
        // TODO add target-cpu and target-features fn attributes
        if (return_type.isNoReturn()) {
            dg.addFnAttr(llvm_fn, "noreturn");
        }

        return llvm_fn;
    }

    fn resolveGlobalDecl(dg: *DeclGen, decl: *Module.Decl) Error!*const llvm.Value {
        const gop = try dg.object.decl_map.getOrPut(dg.gpa, decl);
        if (gop.found_existing) return gop.value_ptr.*;
        errdefer assert(dg.object.decl_map.remove(decl));

        const fqn = try decl.getFullyQualifiedName(dg.gpa);
        defer dg.gpa.free(fqn);

        const llvm_type = try dg.llvmType(decl.ty);
        const llvm_addrspace = dg.llvmAddressSpace(decl.@"addrspace");
        const llvm_global = dg.object.llvm_module.addGlobalInAddressSpace(llvm_type, fqn, llvm_addrspace);
        gop.value_ptr.* = llvm_global;

        const is_extern = decl.val.tag() == .unreachable_value;
        if (!is_extern) {
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
            },
            else => switch (address_space) {
                .generic => llvm.address_space.default,
                else => unreachable,
            },
        };
    }

    fn llvmType(dg: *DeclGen, t: Type) Error!*const llvm.Type {
        const gpa = dg.gpa;
        log.debug("llvmType for {}", .{t});
        switch (t.zigTypeTag()) {
            .Void, .NoReturn => return dg.context.voidType(),
            .Int => {
                const info = t.intInfo(dg.module.getTarget());
                return dg.context.intType(info.bits);
            },
            .Enum => {
                var buffer: Type.Payload.Bits = undefined;
                const int_ty = t.intTagType(&buffer);
                const bit_count = int_ty.intInfo(dg.module.getTarget()).bits;
                return dg.context.intType(bit_count);
            },
            .Float => switch (t.floatBits(dg.module.getTarget())) {
                16 => return dg.context.halfType(),
                32 => return dg.context.floatType(),
                64 => return dg.context.doubleType(),
                80 => return dg.context.x86FP80Type(),
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
                const llvm_addrspace = dg.llvmAddressSpace(t.ptrAddressSpace());
                const elem_ty = t.childType();
                const llvm_elem_ty = if (elem_ty.hasCodeGenBits() or elem_ty.zigTypeTag() == .Array)
                    try dg.llvmType(elem_ty)
                else
                    dg.context.intType(8);
                return llvm_elem_ty.pointerType(llvm_addrspace);
            },
            .Opaque => {
                const gop = try dg.object.type_map.getOrPut(gpa, t);
                if (gop.found_existing) return gop.value_ptr.*;

                // The Type memory is ephemeral; since we want to store a longer-lived
                // reference, we need to copy it here.
                gop.key_ptr.* = try t.copy(&dg.object.type_map_arena.allocator);

                const opaque_obj = t.castTag(.@"opaque").?.data;
                const name = try opaque_obj.getFullyQualifiedName(gpa);
                defer gpa.free(name);

                const llvm_struct_ty = dg.context.structCreateNamed(name);
                gop.value_ptr.* = llvm_struct_ty; // must be done before any recursive calls
                return llvm_struct_ty;
            },
            .Array => {
                const elem_type = try dg.llvmType(t.childType());
                const total_len = t.arrayLen() + @boolToInt(t.sentinel() != null);
                return elem_type.arrayType(@intCast(c_uint, total_len));
            },
            .Vector => {
                const elem_type = try dg.llvmType(t.childType());
                return elem_type.vectorType(@intCast(c_uint, t.arrayLen()));
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const child_type = t.optionalChild(&buf);
                if (!child_type.hasCodeGenBits()) {
                    return dg.context.intType(1);
                }
                const payload_llvm_ty = try dg.llvmType(child_type);
                if (t.isPtrLikeOptional()) {
                    return payload_llvm_ty;
                } else if (!child_type.hasCodeGenBits()) {
                    return dg.context.intType(1);
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
                if (!payload_type.hasCodeGenBits()) {
                    return llvm_error_type;
                }
                const llvm_payload_type = try dg.llvmType(payload_type);

                const fields: [2]*const llvm.Type = .{ llvm_error_type, llvm_payload_type };
                return dg.context.structType(&fields, fields.len, .False);
            },
            .ErrorSet => {
                return dg.context.intType(16);
            },
            .Struct => {
                const gop = try dg.object.type_map.getOrPut(gpa, t);
                if (gop.found_existing) return gop.value_ptr.*;

                // The Type memory is ephemeral; since we want to store a longer-lived
                // reference, we need to copy it here.
                gop.key_ptr.* = try t.copy(&dg.object.type_map_arena.allocator);

                const struct_obj = t.castTag(.@"struct").?.data;

                const name = try struct_obj.getFullyQualifiedName(gpa);
                defer gpa.free(name);

                const llvm_struct_ty = dg.context.structCreateNamed(name);
                gop.value_ptr.* = llvm_struct_ty; // must be done before any recursive calls

                assert(struct_obj.haveFieldTypes());

                var llvm_field_types = try std.ArrayListUnmanaged(*const llvm.Type).initCapacity(gpa, struct_obj.fields.count());
                defer llvm_field_types.deinit(gpa);

                for (struct_obj.fields.values()) |field| {
                    if (!field.ty.hasCodeGenBits()) continue;
                    llvm_field_types.appendAssumeCapacity(try dg.llvmType(field.ty));
                }

                llvm_struct_ty.structSetBody(
                    llvm_field_types.items.ptr,
                    @intCast(c_uint, llvm_field_types.items.len),
                    llvm.Bool.fromBool(struct_obj.layout == .Packed),
                );

                return llvm_struct_ty;
            },
            .Union => {
                const gop = try dg.object.type_map.getOrPut(gpa, t);
                if (gop.found_existing) return gop.value_ptr.*;

                // The Type memory is ephemeral; since we want to store a longer-lived
                // reference, we need to copy it here.
                gop.key_ptr.* = try t.copy(&dg.object.type_map_arena.allocator);

                const union_obj = t.cast(Type.Payload.Union).?.data;
                const target = dg.module.getTarget();
                if (t.unionTagType()) |enum_tag_ty| {
                    const enum_tag_llvm_ty = try dg.llvmType(enum_tag_ty);
                    const layout = union_obj.getLayout(target, true);

                    if (layout.payload_size == 0) {
                        gop.value_ptr.* = enum_tag_llvm_ty;
                        return enum_tag_llvm_ty;
                    }

                    const name = try union_obj.getFullyQualifiedName(gpa);
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
                        break :t dg.context.structType(&fields, fields.len, .False);
                    };

                    if (layout.tag_size == 0) {
                        var llvm_fields: [1]*const llvm.Type = .{llvm_payload_ty};
                        llvm_union_ty.structSetBody(&llvm_fields, llvm_fields.len, .False);
                        return llvm_union_ty;
                    }

                    // Put the tag before or after the payload depending on which one's
                    // alignment is greater.
                    var llvm_fields: [2]*const llvm.Type = undefined;
                    if (layout.tag_align >= layout.payload_align) {
                        llvm_fields[0] = enum_tag_llvm_ty;
                        llvm_fields[1] = llvm_payload_ty;
                    } else {
                        llvm_fields[0] = llvm_payload_ty;
                        llvm_fields[1] = enum_tag_llvm_ty;
                    }
                    llvm_union_ty.structSetBody(&llvm_fields, llvm_fields.len, .False);
                    return llvm_union_ty;
                }
                // Untagged union
                const layout = union_obj.getLayout(target, false);

                const name = try union_obj.getFullyQualifiedName(gpa);
                defer gpa.free(name);

                const llvm_union_ty = dg.context.structCreateNamed(name);
                gop.value_ptr.* = llvm_union_ty; // must be done before any recursive calls

                const big_field = union_obj.fields.values()[layout.biggest_field];
                const llvm_big_field_ty = try dg.llvmType(big_field.ty);

                var llvm_fields: [1]*const llvm.Type = .{llvm_big_field_ty};
                llvm_union_ty.structSetBody(&llvm_fields, llvm_fields.len, .False);
                return llvm_union_ty;
            },
            .Fn => {
                const fn_info = t.fnInfo();
                const target = dg.module.getTarget();
                const sret = firstParamSRet(fn_info, target);
                const return_type = fn_info.return_type;
                const raw_llvm_ret_ty = try dg.llvmType(return_type);
                const llvm_ret_ty = if (!return_type.hasCodeGenBits() or sret)
                    dg.context.voidType()
                else
                    raw_llvm_ret_ty;

                var llvm_params = std.ArrayList(*const llvm.Type).init(dg.gpa);
                defer llvm_params.deinit();

                if (sret) {
                    try llvm_params.append(raw_llvm_ret_ty.pointerType(0));
                }

                for (fn_info.param_types) |param_ty| {
                    if (!param_ty.hasCodeGenBits()) continue;

                    const raw_llvm_ty = try dg.llvmType(param_ty);
                    const actual_llvm_ty = if (!isByRef(param_ty)) raw_llvm_ty else raw_llvm_ty.pointerType(0);
                    try llvm_params.append(actual_llvm_ty);
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

            .Frame,
            .AnyFrame,
            => return dg.todo("implement llvmType for type '{}'", .{t}),
        }
    }

    fn genTypedValue(self: *DeclGen, tv: TypedValue) Error!*const llvm.Value {
        if (tv.val.isUndef()) {
            const llvm_type = try self.llvmType(tv.ty);
            return llvm_type.getUndef();
        }

        switch (tv.ty.zigTypeTag()) {
            .Bool => {
                const llvm_type = try self.llvmType(tv.ty);
                return if (tv.val.toBool()) llvm_type.constAllOnes() else llvm_type.constNull();
            },
            .Int => {
                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = tv.val.toBigInt(&bigint_space);
                const target = self.module.getTarget();
                const int_info = tv.ty.intInfo(target);
                const llvm_type = self.context.intType(int_info.bits);

                const unsigned_val = if (bigint.limbs.len == 1)
                    llvm_type.constInt(bigint.limbs[0], .False)
                else
                    llvm_type.constIntOfArbitraryPrecision(@intCast(c_uint, bigint.limbs.len), bigint.limbs.ptr);
                if (!bigint.positive) {
                    return llvm.constNeg(unsigned_val);
                }
                return unsigned_val;
            },
            .Enum => {
                var int_buffer: Value.Payload.U64 = undefined;
                const int_val = tv.enumToInt(&int_buffer);

                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = int_val.toBigInt(&bigint_space);

                const target = self.module.getTarget();
                const int_info = tv.ty.intInfo(target);
                const llvm_type = self.context.intType(int_info.bits);

                const unsigned_val = if (bigint.limbs.len == 1)
                    llvm_type.constInt(bigint.limbs[0], .False)
                else
                    llvm_type.constIntOfArbitraryPrecision(@intCast(c_uint, bigint.limbs.len), bigint.limbs.ptr);
                if (!bigint.positive) {
                    return llvm.constNeg(unsigned_val);
                }
                return unsigned_val;
            },
            .Float => {
                const llvm_ty = try self.llvmType(tv.ty);
                if (tv.ty.floatBits(self.module.getTarget()) <= 64) {
                    return llvm_ty.constReal(tv.val.toFloat(f64));
                }

                var buf: [2]u64 = @bitCast([2]u64, tv.val.toFloat(f128));
                // LLVM seems to require that the lower half of the f128 be placed first
                // in the buffer.
                if (native_endian == .Big) {
                    std.mem.swap(u64, &buf[0], &buf[1]);
                }

                const int = self.context.intType(128).constIntOfArbitraryPrecision(buf.len, &buf);
                return int.constBitCast(llvm_ty);
            },
            .Pointer => switch (tv.val.tag()) {
                .decl_ref_mut => return lowerDeclRefValue(self, tv, tv.val.castTag(.decl_ref_mut).?.data.decl),
                .decl_ref => return lowerDeclRefValue(self, tv, tv.val.castTag(.decl_ref).?.data),
                .variable => {
                    const decl = tv.val.castTag(.variable).?.data.owner_decl;
                    decl.alive = true;
                    const val = try self.resolveGlobalDecl(decl);
                    const llvm_var_type = try self.llvmType(tv.ty);
                    const llvm_addrspace = self.llvmAddressSpace(decl.@"addrspace");
                    const llvm_type = llvm_var_type.pointerType(llvm_addrspace);
                    return val.constBitCast(llvm_type);
                },
                .slice => {
                    const slice = tv.val.castTag(.slice).?.data;
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const fields: [2]*const llvm.Value = .{
                        try self.genTypedValue(.{
                            .ty = tv.ty.slicePtrFieldType(&buf),
                            .val = slice.ptr,
                        }),
                        try self.genTypedValue(.{
                            .ty = Type.usize,
                            .val = slice.len,
                        }),
                    };
                    return self.context.constStruct(&fields, fields.len, .False);
                },
                .int_u64 => {
                    const llvm_usize = try self.llvmType(Type.usize);
                    const llvm_int = llvm_usize.constInt(tv.val.toUnsignedInt(), .False);
                    return llvm_int.constIntToPtr(try self.llvmType(tv.ty));
                },
                .field_ptr => {
                    const field_ptr = tv.val.castTag(.field_ptr).?.data;
                    const parent_ptr = try self.lowerParentPtr(field_ptr.container_ptr);
                    const llvm_u32 = self.context.intType(32);
                    const indices: [2]*const llvm.Value = .{
                        llvm_u32.constInt(0, .False),
                        llvm_u32.constInt(field_ptr.field_index, .False),
                    };
                    return parent_ptr.constInBoundsGEP(&indices, indices.len);
                },
                .elem_ptr => {
                    const elem_ptr = tv.val.castTag(.elem_ptr).?.data;
                    const parent_ptr = try self.lowerParentPtr(elem_ptr.array_ptr);
                    const llvm_usize = try self.llvmType(Type.usize);
                    if (parent_ptr.typeOf().getElementType().getTypeKind() == .Array) {
                        const indices: [2]*const llvm.Value = .{
                            llvm_usize.constInt(0, .False),
                            llvm_usize.constInt(elem_ptr.index, .False),
                        };
                        return parent_ptr.constInBoundsGEP(&indices, indices.len);
                    } else {
                        const indices: [1]*const llvm.Value = .{
                            llvm_usize.constInt(elem_ptr.index, .False),
                        };
                        return parent_ptr.constInBoundsGEP(&indices, indices.len);
                    }
                },
                .null_value, .zero => {
                    const llvm_type = try self.llvmType(tv.ty);
                    return llvm_type.constNull();
                },
                else => |tag| return self.todo("implement const of pointer type '{}' ({})", .{ tv.ty, tag }),
            },
            .Array => switch (tv.val.tag()) {
                .bytes => {
                    const bytes = tv.val.castTag(.bytes).?.data;
                    return self.context.constString(
                        bytes.ptr,
                        @intCast(c_uint, bytes.len),
                        .True, // don't null terminate. bytes has the sentinel, if any.
                    );
                },
                .array => {
                    const elem_vals = tv.val.castTag(.array).?.data;
                    const elem_ty = tv.ty.elemType();
                    const gpa = self.gpa;
                    const llvm_elems = try gpa.alloc(*const llvm.Value, elem_vals.len);
                    defer gpa.free(llvm_elems);
                    for (elem_vals) |elem_val, i| {
                        llvm_elems[i] = try self.genTypedValue(.{ .ty = elem_ty, .val = elem_val });
                    }
                    const llvm_elem_ty = try self.llvmType(elem_ty);
                    return llvm_elem_ty.constArray(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                .repeated => {
                    const val = tv.val.castTag(.repeated).?.data;
                    const elem_ty = tv.ty.elemType();
                    const sentinel = tv.ty.sentinel();
                    const len = tv.ty.arrayLen();
                    const len_including_sent = len + @boolToInt(sentinel != null);
                    const gpa = self.gpa;
                    const llvm_elems = try gpa.alloc(*const llvm.Value, len_including_sent);
                    defer gpa.free(llvm_elems);
                    for (llvm_elems[0..len]) |*elem| {
                        elem.* = try self.genTypedValue(.{ .ty = elem_ty, .val = val });
                    }
                    if (sentinel) |sent| {
                        llvm_elems[len] = try self.genTypedValue(.{ .ty = elem_ty, .val = sent });
                    }
                    const llvm_elem_ty = try self.llvmType(elem_ty);
                    return llvm_elem_ty.constArray(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                .empty_array_sentinel => {
                    const elem_ty = tv.ty.elemType();
                    const sent_val = tv.ty.sentinel().?;
                    const sentinel = try self.genTypedValue(.{ .ty = elem_ty, .val = sent_val });
                    const llvm_elems: [1]*const llvm.Value = .{sentinel};
                    const llvm_elem_ty = try self.llvmType(elem_ty);
                    return llvm_elem_ty.constArray(&llvm_elems, llvm_elems.len);
                },
                else => unreachable,
            },
            .Optional => {
                var buf: Type.Payload.ElemType = undefined;
                const payload_ty = tv.ty.optionalChild(&buf);
                const llvm_i1 = self.context.intType(1);
                const is_pl = !tv.val.isNull();
                const non_null_bit = if (is_pl) llvm_i1.constAllOnes() else llvm_i1.constNull();
                if (!payload_ty.hasCodeGenBits()) {
                    return non_null_bit;
                }
                if (tv.ty.isPtrLikeOptional()) {
                    if (tv.val.castTag(.opt_payload)) |payload| {
                        return self.genTypedValue(.{ .ty = payload_ty, .val = payload.data });
                    } else if (is_pl) {
                        return self.genTypedValue(.{ .ty = payload_ty, .val = tv.val });
                    } else {
                        const llvm_ty = try self.llvmType(tv.ty);
                        return llvm_ty.constNull();
                    }
                }
                const fields: [2]*const llvm.Value = .{
                    try self.genTypedValue(.{
                        .ty = payload_ty,
                        .val = if (tv.val.castTag(.opt_payload)) |pl| pl.data else Value.initTag(.undef),
                    }),
                    non_null_bit,
                };
                return self.context.constStruct(&fields, fields.len, .False);
            },
            .Fn => {
                const fn_decl = switch (tv.val.tag()) {
                    .extern_fn => tv.val.castTag(.extern_fn).?.data,
                    .function => tv.val.castTag(.function).?.data.owner_decl,
                    else => unreachable,
                };
                fn_decl.alive = true;
                return self.resolveLlvmFunction(fn_decl);
            },
            .ErrorSet => {
                const llvm_ty = try self.llvmType(tv.ty);
                switch (tv.val.tag()) {
                    .@"error" => {
                        const err_name = tv.val.castTag(.@"error").?.data.name;
                        const kv = try self.module.getErrorValue(err_name);
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

                if (!payload_type.hasCodeGenBits()) {
                    // We use the error type directly as the type.
                    const err_val = if (!is_pl) tv.val else Value.initTag(.zero);
                    return self.genTypedValue(.{ .ty = error_type, .val = err_val });
                }

                const fields: [2]*const llvm.Value = .{
                    try self.genTypedValue(.{
                        .ty = error_type,
                        .val = if (is_pl) Value.initTag(.zero) else tv.val,
                    }),
                    try self.genTypedValue(.{
                        .ty = payload_type,
                        .val = if (tv.val.castTag(.eu_payload)) |pl| pl.data else Value.initTag(.undef),
                    }),
                };
                return self.context.constStruct(&fields, fields.len, .False);
            },
            .Struct => {
                const llvm_struct_ty = try self.llvmType(tv.ty);
                const field_vals = tv.val.castTag(.@"struct").?.data;
                const gpa = self.gpa;

                var llvm_fields = try std.ArrayListUnmanaged(*const llvm.Value).initCapacity(gpa, field_vals.len);
                defer llvm_fields.deinit(gpa);

                for (field_vals) |field_val, i| {
                    const field_ty = tv.ty.structFieldType(i);
                    if (!field_ty.hasCodeGenBits()) continue;

                    llvm_fields.appendAssumeCapacity(try self.genTypedValue(.{
                        .ty = field_ty,
                        .val = field_val,
                    }));
                }
                return llvm_struct_ty.constNamedStruct(
                    llvm_fields.items.ptr,
                    @intCast(c_uint, llvm_fields.items.len),
                );
            },
            .Union => {
                const llvm_union_ty = try self.llvmType(tv.ty);
                const tag_and_val = tv.val.castTag(.@"union").?.data;

                const target = self.module.getTarget();
                const layout = tv.ty.unionGetLayout(target);

                if (layout.payload_size == 0) {
                    return genTypedValue(self, .{ .ty = tv.ty.unionTagType().?, .val = tag_and_val.tag });
                }
                const field_ty = tv.ty.unionFieldType(tag_and_val.tag);
                const payload = p: {
                    if (!field_ty.hasCodeGenBits()) {
                        const padding_len = @intCast(c_uint, layout.payload_size);
                        break :p self.context.intType(8).arrayType(padding_len).getUndef();
                    }
                    const field = try genTypedValue(self, .{ .ty = field_ty, .val = tag_and_val.val });
                    const field_size = field_ty.abiSize(target);
                    if (field_size == layout.payload_size) {
                        break :p field;
                    }
                    const padding_len = @intCast(c_uint, layout.payload_size - field_size);
                    const fields: [2]*const llvm.Value = .{
                        field, self.context.intType(8).arrayType(padding_len).getUndef(),
                    };
                    break :p self.context.constStruct(&fields, fields.len, .False);
                };
                if (layout.tag_size == 0) {
                    const llvm_payload_ty = llvm_union_ty.structGetTypeAtIndex(0);
                    const fields: [1]*const llvm.Value = .{payload.constBitCast(llvm_payload_ty)};
                    return llvm_union_ty.constNamedStruct(&fields, fields.len);
                }
                const llvm_tag_value = try genTypedValue(self, .{
                    .ty = tv.ty.unionTagType().?,
                    .val = tag_and_val.tag,
                });
                var fields: [2]*const llvm.Value = undefined;
                if (layout.tag_align >= layout.payload_align) {
                    fields[0] = llvm_tag_value;
                    fields[1] = payload.constBitCast(llvm_union_ty.structGetTypeAtIndex(1));
                } else {
                    fields[0] = payload.constBitCast(llvm_union_ty.structGetTypeAtIndex(0));
                    fields[1] = llvm_tag_value;
                }
                return llvm_union_ty.constNamedStruct(&fields, fields.len);
            },
            .Vector => switch (tv.val.tag()) {
                .bytes => {
                    // Note, sentinel is not stored even if the type has a sentinel.
                    const bytes = tv.val.castTag(.bytes).?.data;
                    const vector_len = tv.ty.arrayLen();
                    assert(vector_len == bytes.len or vector_len + 1 == bytes.len);

                    const elem_ty = tv.ty.elemType();
                    const llvm_elems = try self.gpa.alloc(*const llvm.Value, vector_len);
                    defer self.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem, i| {
                        var byte_payload: Value.Payload.U64 = .{
                            .base = .{ .tag = .int_u64 },
                            .data = bytes[i],
                        };

                        elem.* = try self.genTypedValue(.{
                            .ty = elem_ty,
                            .val = Value.initPayload(&byte_payload.base),
                        });
                    }
                    return llvm.constVector(
                        llvm_elems.ptr,
                        @intCast(c_uint, llvm_elems.len),
                    );
                },
                .array => {
                    // Note, sentinel is not stored even if the type has a sentinel.
                    // The value includes the sentinel in those cases.
                    const elem_vals = tv.val.castTag(.array).?.data;
                    const vector_len = tv.ty.arrayLen();
                    assert(vector_len == elem_vals.len or vector_len + 1 == elem_vals.len);
                    const elem_ty = tv.ty.elemType();
                    const llvm_elems = try self.gpa.alloc(*const llvm.Value, vector_len);
                    defer self.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem, i| {
                        elem.* = try self.genTypedValue(.{ .ty = elem_ty, .val = elem_vals[i] });
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
                    const len = tv.ty.arrayLen();
                    const llvm_elems = try self.gpa.alloc(*const llvm.Value, len);
                    defer self.gpa.free(llvm_elems);
                    for (llvm_elems) |*elem| {
                        elem.* = try self.genTypedValue(.{ .ty = elem_ty, .val = val });
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
            => return self.todo("implement const of type '{}'", .{tv.ty}),
        }
    }

    const ParentPtr = struct {
        ty: Type,
        llvm_ptr: *const llvm.Value,
    };

    fn lowerParentPtrDecl(
        dg: *DeclGen,
        ptr_val: Value,
        decl: *Module.Decl,
    ) Error!ParentPtr {
        decl.alive = true;
        var ptr_ty_payload: Type.Payload.ElemType = .{
            .base = .{ .tag = .single_mut_pointer },
            .data = decl.ty,
        };
        const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
        const llvm_ptr = try dg.lowerDeclRefValue(.{ .ty = ptr_ty, .val = ptr_val }, decl);
        return ParentPtr{
            .llvm_ptr = llvm_ptr,
            .ty = decl.ty,
        };
    }

    fn lowerParentPtr(dg: *DeclGen, ptr_val: Value) Error!*const llvm.Value {
        switch (ptr_val.tag()) {
            .decl_ref_mut => {
                const decl = ptr_val.castTag(.decl_ref_mut).?.data.decl;
                return (try dg.lowerParentPtrDecl(ptr_val, decl)).llvm_ptr;
            },
            .decl_ref => {
                const decl = ptr_val.castTag(.decl_ref).?.data;
                return (try dg.lowerParentPtrDecl(ptr_val, decl)).llvm_ptr;
            },
            .variable => {
                const decl = ptr_val.castTag(.variable).?.data.owner_decl;
                return (try dg.lowerParentPtrDecl(ptr_val, decl)).llvm_ptr;
            },
            .field_ptr => {
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;
                const parent_ptr = try dg.lowerParentPtr(field_ptr.container_ptr);
                const llvm_u32 = dg.context.intType(32);
                const indices: [2]*const llvm.Value = .{
                    llvm_u32.constInt(0, .False),
                    llvm_u32.constInt(field_ptr.field_index, .False),
                };
                return parent_ptr.constInBoundsGEP(&indices, indices.len);
            },
            .elem_ptr => {
                const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
                const parent_ptr = try dg.lowerParentPtr(elem_ptr.array_ptr);
                const llvm_usize = try dg.llvmType(Type.usize);
                const indices: [2]*const llvm.Value = .{
                    llvm_usize.constInt(0, .False),
                    llvm_usize.constInt(elem_ptr.index, .False),
                };
                return parent_ptr.constInBoundsGEP(&indices, indices.len);
            },
            .opt_payload_ptr => return dg.todo("implement lowerParentPtr for optional payload", .{}),
            .eu_payload_ptr => return dg.todo("implement lowerParentPtr for error union payload", .{}),
            else => unreachable,
        }
    }

    fn lowerDeclRefValue(
        self: *DeclGen,
        tv: TypedValue,
        decl: *Module.Decl,
    ) Error!*const llvm.Value {
        if (tv.ty.isSlice()) {
            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            const ptr_ty = tv.ty.slicePtrFieldType(&buf);
            var slice_len: Value.Payload.U64 = .{
                .base = .{ .tag = .int_u64 },
                .data = tv.val.sliceLen(),
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

        const llvm_type = try self.llvmType(tv.ty);
        if (!tv.ty.childType().hasCodeGenBits() or !decl.ty.hasCodeGenBits()) {
            return self.lowerPtrToVoid(tv.ty);
        }

        decl.alive = true;

        const llvm_val = if (decl.ty.zigTypeTag() == .Fn)
            try self.resolveLlvmFunction(decl)
        else
            try self.resolveGlobalDecl(decl);
        return llvm_val.constBitCast(llvm_type);
    }

    fn lowerPtrToVoid(dg: *DeclGen, ptr_ty: Type) !*const llvm.Value {
        const target = dg.module.getTarget();
        const alignment = ptr_ty.ptrAlignment(target);
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
    gpa: *Allocator,
    dg: *DeclGen,
    air: Air,
    liveness: Liveness,
    context: *const llvm.Context,

    builder: *const llvm.Builder,

    /// This stores the LLVM values used in a function, such that they can be referred to
    /// in other instructions. This table is cleared before every function is generated.
    func_inst_table: std.AutoHashMapUnmanaged(Air.Inst.Ref, *const llvm.Value),

    /// If the return type isByRef, this is the result pointer. Otherwise null.
    ret_ptr: ?*const llvm.Value,
    /// These fields are used to refer to the LLVM value of the function parameters
    /// in an Arg instruction.
    /// This list may be shorter than the list according to the zig type system;
    /// it omits 0-bit types.
    args: []*const llvm.Value,
    arg_index: usize,

    llvm_func: *const llvm.Value,

    /// This data structure is used to implement breaking to blocks.
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
        parent_bb: *const llvm.BasicBlock,
        break_bbs: *BreakBasicBlocks,
        break_vals: *BreakValues,
    }),

    single_threaded: bool,

    const BreakBasicBlocks = std.ArrayListUnmanaged(*const llvm.BasicBlock);
    const BreakValues = std.ArrayListUnmanaged(*const llvm.Value);

    fn deinit(self: *FuncGen) void {
        self.builder.dispose();
        self.func_inst_table.deinit(self.gpa);
        self.gpa.free(self.args);
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
        gop.value_ptr.* = global;
        return global;
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

                .bit_and, .bool_and => try self.airAnd(inst),
                .bit_or, .bool_or   => try self.airOr(inst),
                .xor                => try self.airXor(inst),
                .shr                => try self.airShr(inst),

                .cmp_eq  => try self.airCmp(inst, .eq),
                .cmp_gt  => try self.airCmp(inst, .gt),
                .cmp_gte => try self.airCmp(inst, .gte),
                .cmp_lt  => try self.airCmp(inst, .lt),
                .cmp_lte => try self.airCmp(inst, .lte),
                .cmp_neq => try self.airCmp(inst, .neq),

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
                .call           => try self.airCall(inst),
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
                .clz            => try self.airClzCtz(inst, "ctlz"),
                .ctz            => try self.airClzCtz(inst, "cttz"),
                .popcount       => try self.airPopCount(inst, "ctpop"),

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

                .wrap_optional         => try self.airWrapOptional(inst),
                .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
                .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

                .constant => unreachable,
                .const_ty => unreachable,
                .unreach  => self.airUnreach(inst),
                .dbg_stmt => blk: {
                    // TODO: implement debug info
                    break :blk null;
                },
                // zig fmt: on
            };
            if (opt_value) |val| {
                const ref = Air.indexToRef(inst);
                try self.func_inst_table.putNoClobber(self.gpa, ref, val);
            }
        }
    }

    fn airCall(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const pl_op = self.air.instructions.items(.data)[inst].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args = @bitCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);
        const callee_ty = self.air.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag()) {
            .Fn => callee_ty,
            .Pointer => callee_ty.childType(),
            else => unreachable,
        };
        const fn_info = zig_fn_ty.fnInfo();
        const return_type = fn_info.return_type;
        const llvm_ret_ty = try self.dg.llvmType(return_type);
        const llvm_fn = try self.resolveInst(pl_op.operand);
        const target = self.dg.module.getTarget();
        const sret = firstParamSRet(fn_info, target);

        var llvm_args = std.ArrayList(*const llvm.Value).init(self.gpa);
        defer llvm_args.deinit();

        const ret_ptr = if (!sret) null else blk: {
            const ret_ptr = self.buildAlloca(llvm_ret_ty);
            ret_ptr.setAlignment(return_type.abiAlignment(target));
            try llvm_args.append(ret_ptr);
            break :blk ret_ptr;
        };

        if (fn_info.is_var_args) {
            for (args) |arg| {
                try llvm_args.append(try self.resolveInst(arg));
            }
        } else {
            for (args) |arg, i| {
                const param_ty = fn_info.param_types[i];
                if (!param_ty.hasCodeGenBits()) continue;

                try llvm_args.append(try self.resolveInst(arg));
            }
        }

        const call = self.builder.buildCall(
            llvm_fn,
            llvm_args.items.ptr,
            @intCast(c_uint, llvm_args.items.len),
            toLlvmCallConv(zig_fn_ty.fnCallingConvention(), target),
            .Auto,
            "",
        );

        if (return_type.isNoReturn()) {
            _ = self.builder.buildUnreachable();
            return null;
        } else if (self.liveness.isUnused(inst) or !return_type.hasCodeGenBits()) {
            return null;
        } else if (sret) {
            call.setCallSret(llvm_ret_ty);
            return ret_ptr;
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
        if (!ret_ty.hasCodeGenBits()) {
            _ = self.builder.buildRetVoid();
            return null;
        }
        const operand = try self.resolveInst(un_op);
        _ = self.builder.buildRet(operand);
        return null;
    }

    fn airRetLoad(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const un_op = self.air.instructions.items(.data)[inst].un_op;
        const ptr_ty = self.air.typeOf(un_op);
        const ret_ty = ptr_ty.childType();
        if (!ret_ty.hasCodeGenBits() or isByRef(ret_ty)) {
            _ = self.builder.buildRetVoid();
            return null;
        }
        const ptr = try self.resolveInst(un_op);
        const loaded = self.builder.buildLoad(ptr, "");
        _ = self.builder.buildRet(loaded);
        return null;
    }

    fn airCmp(self: *FuncGen, inst: Air.Inst.Index, op: math.CompareOperator) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const operand_ty = self.air.typeOf(bin_op.lhs);
        var buffer: Type.Payload.Bits = undefined;

        const int_ty = switch (operand_ty.zigTypeTag()) {
            .Enum => operand_ty.intTagType(&buffer),
            .Int, .Bool, .Pointer, .Optional, .ErrorSet => operand_ty,
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
        const parent_bb = self.context.createBasicBlock("Block");

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
        const inst_ty = self.air.typeOfIndex(inst);
        if (!inst_ty.hasCodeGenBits()) return null;

        const raw_llvm_ty = try self.dg.llvmType(inst_ty);

        const llvm_ty = ty: {
            // If the zig tag type is a function, this represents an actual function body; not
            // a pointer to it. LLVM IR allows the call instruction to use function bodies instead
            // of function pointers, however the phi makes it a runtime value and therefore
            // the LLVM type has to be wrapped in a pointer.
            if (inst_ty.zigTypeTag() == .Fn or isByRef(inst_ty)) {
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
        if (self.air.typeOf(branch.operand).hasCodeGenBits()) {
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
        const llvm_switch = self.builder.buildSwitch(cond, else_block, switch_br.data.cases_len);

        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;

        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
            const items = @bitCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
            const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + case.data.items_len + case_body.len;

            const case_block = self.context.appendBasicBlock(self.llvm_func, "Case");

            for (items) |item| {
                const llvm_item = try self.resolveInst(item);
                llvm_switch.addCase(llvm_item, case_block);
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
        if (!array_ty.hasCodeGenBits()) {
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
        const dest_ty = self.air.typeOfIndex(inst);
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);

        if (dest_ty.isSignedInt()) {
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
        const dest_llvm_ty = try self.dg.llvmType(dest_ty);

        // TODO set fast math flag

        if (dest_ty.isSignedInt()) {
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
        assert(isByRef(array_ty));
        const indices: [2]*const llvm.Value = .{ self.context.intType(32).constNull(), rhs };
        const elem_ptr = self.builder.buildInBoundsGEP(array_llvm_val, &indices, indices.len, "");
        const elem_ty = array_ty.childType();
        if (isByRef(elem_ty)) {
            return elem_ptr;
        } else {
            return self.builder.buildLoad(elem_ptr, "");
        }
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
        if (!elem_ty.hasCodeGenBits()) return null;

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
        if (!field_ty.hasCodeGenBits()) {
            return null;
        }

        assert(isByRef(struct_ty));

        const field_ptr = switch (struct_ty.zigTypeTag()) {
            .Struct => blk: {
                const llvm_field_index = llvmFieldIndex(struct_ty, field_index);
                break :blk self.builder.buildStructGEP(struct_llvm_val, llvm_field_index, "");
            },
            .Union => blk: {
                const llvm_field_ty = try self.dg.llvmType(field_ty);
                const target = self.dg.module.getTarget();
                const layout = struct_ty.unionGetLayout(target);
                const payload_index = @boolToInt(layout.tag_align >= layout.payload_align);
                const union_field_ptr = self.builder.buildStructGEP(struct_llvm_val, payload_index, "");
                break :blk self.builder.buildBitCast(union_field_ptr, llvm_field_ty.pointerType(0), "");
            },
            else => unreachable,
        };

        if (isByRef(field_ty)) {
            return field_ptr;
        } else {
            return self.builder.buildLoad(field_ptr, "");
        }
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

    fn airAssembly(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        // Eventually, the Zig compiler needs to be reworked to have inline assembly go
        // through the same parsing code regardless of backend, and have LLVM-flavored
        // inline assembly be *output* from that assembler.
        // We don't have such an assembler implemented yet though. For now, this
        // implementation feeds the inline assembly code directly to LLVM, same
        // as stage1.

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const air_asm = self.air.extraData(Air.Asm, ty_pl.payload);
        const zir = self.dg.decl.getFileScope().zir;
        const extended = zir.instructions.items(.data)[air_asm.data.zir_index].extended;
        const is_volatile = @truncate(u1, extended.small >> 15) != 0;
        if (!is_volatile and self.liveness.isUnused(inst)) {
            return null;
        }
        const outputs_len = @truncate(u5, extended.small);
        if (outputs_len > 1) {
            return self.todo("implement llvm codegen for asm with more than 1 output", .{});
        }
        const args_len = @truncate(u5, extended.small >> 5);
        const clobbers_len = @truncate(u5, extended.small >> 10);
        const zir_extra = zir.extraData(Zir.Inst.Asm, extended.operand);
        const asm_source = zir.nullTerminatedString(zir_extra.data.asm_source);
        const args = @bitCast([]const Air.Inst.Ref, self.air.extra[air_asm.end..][0..args_len]);

        var extra_i: usize = zir_extra.end;
        const output_constraint: ?[]const u8 = out: {
            var i: usize = 0;
            while (i < outputs_len) : (i += 1) {
                const output = zir.extraData(Zir.Inst.Asm.Output, extra_i);
                extra_i = output.end;
                break :out zir.nullTerminatedString(output.data.constraint);
            }
            break :out null;
        };

        var llvm_constraints: std.ArrayListUnmanaged(u8) = .{};
        defer llvm_constraints.deinit(self.gpa);

        var arena_allocator = std.heap.ArenaAllocator.init(self.gpa);
        defer arena_allocator.deinit();
        const arena = &arena_allocator.allocator;

        const llvm_params_len = args.len;
        const llvm_param_types = try arena.alloc(*const llvm.Type, llvm_params_len);
        const llvm_param_values = try arena.alloc(*const llvm.Value, llvm_params_len);

        var llvm_param_i: usize = 0;
        var total_i: usize = 0;

        if (output_constraint) |constraint| {
            try llvm_constraints.ensureUnusedCapacity(self.gpa, constraint.len + 1);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendAssumeCapacity('=');
            llvm_constraints.appendSliceAssumeCapacity(constraint[1..]);

            total_i += 1;
        }

        for (args) |arg| {
            const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
            extra_i = input.end;
            const constraint = zir.nullTerminatedString(input.data.constraint);
            const arg_llvm_value = try self.resolveInst(arg);

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

        const clobbers = zir.extra[extra_i..][0..clobbers_len];
        for (clobbers) |clobber_index| {
            const clobber = zir.nullTerminatedString(clobber_index);
            try llvm_constraints.ensureUnusedCapacity(self.gpa, clobber.len + 4);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendSliceAssumeCapacity("~{");
            llvm_constraints.appendSliceAssumeCapacity(clobber);
            llvm_constraints.appendSliceAssumeCapacity("}");

            total_i += 1;
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
            asm_source.ptr,
            asm_source.len,
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
        if (!payload_ty.hasCodeGenBits()) {
            if (invert) {
                return self.builder.buildNot(operand, "");
            } else {
                return operand;
            }
        }

        if (operand_is_ptr or isByRef(optional_ty)) {
            const index_type = self.context.intType(32);

            const indices: [2]*const llvm.Value = .{
                index_type.constNull(),
                index_type.constInt(1, .False),
            };

            const field_ptr = self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
            const non_null_bit = self.builder.buildLoad(field_ptr, "");
            if (invert) {
                return self.builder.buildNot(non_null_bit, "");
            } else {
                return non_null_bit;
            }
        }

        const non_null_bit = self.builder.buildExtractValue(operand, 1, "");
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

        if (!payload_ty.hasCodeGenBits()) {
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
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        if (!payload_ty.hasCodeGenBits()) {
            // We have a pointer to a zero-bit value and we need to return
            // a pointer to a zero-bit value.
            return operand;
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
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        const non_null_bit = self.context.intType(1).constAllOnes();
        if (!payload_ty.hasCodeGenBits()) {
            // We have a pointer to a i1. We need to set it to 1 and then return the same pointer.
            _ = self.builder.buildStore(non_null_bit, operand);
            return operand;
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
        // Then return the payload pointer.
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
        if (!payload_ty.hasCodeGenBits()) return null;

        if (optional_ty.isPtrLikeOptional()) {
            // Payload value is the same as the optional value.
            return operand;
        }

        if (isByRef(payload_ty)) {
            // We have a pointer and we need to return a pointer to the first field.
            const index_type = self.context.intType(32);
            const indices: [2]*const llvm.Value = .{
                index_type.constNull(), // dereference the pointer
                index_type.constNull(), // first field is the payload
            };
            return self.builder.buildInBoundsGEP(operand, &indices, indices.len, "");
        }

        return self.builder.buildExtractValue(operand, 0, "");
    }

    fn airErrUnionPayload(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
    ) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const err_union_ty = self.air.typeOf(ty_op.operand);
        const payload_ty = err_union_ty.errorUnionPayload();
        if (!payload_ty.hasCodeGenBits()) return null;
        if (operand_is_ptr or isByRef(payload_ty)) {
            return self.builder.buildStructGEP(operand, 1, "");
        }
        return self.builder.buildExtractValue(operand, 1, "");
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

        const payload_ty = operand_ty.errorUnionPayload();
        if (!payload_ty.hasCodeGenBits()) {
            if (!operand_is_ptr) return operand;
            return self.builder.buildLoad(operand, "");
        }

        if (operand_is_ptr or isByRef(payload_ty)) {
            const err_field_ptr = self.builder.buildStructGEP(operand, 0, "");
            return self.builder.buildLoad(err_field_ptr, "");
        }

        return self.builder.buildExtractValue(operand, 0, "");
    }

    fn airWrapOptional(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const payload_ty = self.air.typeOf(ty_op.operand);
        const non_null_bit = self.context.intType(1).constAllOnes();
        if (!payload_ty.hasCodeGenBits()) return non_null_bit;
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
        if (!payload_ty.hasCodeGenBits()) {
            return operand;
        }
        const inst_ty = self.air.typeOfIndex(inst);
        const ok_err_code = self.context.intType(16).constNull();
        const err_un_llvm_ty = try self.dg.llvmType(inst_ty);
        if (isByRef(inst_ty)) {
            const result_ptr = self.buildAlloca(err_un_llvm_ty);
            const err_ptr = self.builder.buildStructGEP(result_ptr, 0, "");
            _ = self.builder.buildStore(ok_err_code, err_ptr);
            const payload_ptr = self.builder.buildStructGEP(result_ptr, 1, "");
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = payload_ty,
            };
            const payload_ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            self.store(payload_ptr, payload_ptr_ty, operand, .NotAtomic);
            return result_ptr;
        }

        const partial = self.builder.buildInsertValue(err_un_llvm_ty.getUndef(), ok_err_code, 0, "");
        return self.builder.buildInsertValue(partial, operand, 1, "");
    }

    fn airWrapErrUnionErr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const err_un_ty = self.air.typeOfIndex(inst);
        const payload_ty = err_un_ty.errorUnionPayload();
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasCodeGenBits()) {
            return operand;
        }
        const err_un_llvm_ty = try self.dg.llvmType(err_un_ty);
        if (isByRef(err_un_ty)) {
            const result_ptr = self.buildAlloca(err_un_llvm_ty);
            const err_ptr = self.builder.buildStructGEP(result_ptr, 0, "");
            _ = self.builder.buildStore(operand, err_ptr);
            const payload_ptr = self.builder.buildStructGEP(result_ptr, 1, "");
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

        const partial = self.builder.buildInsertValue(llvm_slice_ty.getUndef(), ptr, 0, "");
        return self.builder.buildInsertValue(partial, len, 1, "");
    }

    fn airAdd(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);

        if (inst_ty.isAnyFloat()) return self.builder.buildFAdd(lhs, rhs, "");
        if (inst_ty.isSignedInt()) return self.builder.buildNSWAdd(lhs, rhs, "");
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

        if (inst_ty.isAnyFloat()) return self.todo("saturating float add", .{});
        if (inst_ty.isSignedInt()) return self.builder.buildSAddSat(lhs, rhs, "");

        return self.builder.buildUAddSat(lhs, rhs, "");
    }

    fn airSub(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);

        if (inst_ty.isAnyFloat()) return self.builder.buildFSub(lhs, rhs, "");
        if (inst_ty.isSignedInt()) return self.builder.buildNSWSub(lhs, rhs, "");
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

        if (inst_ty.isAnyFloat()) return self.todo("saturating float sub", .{});
        if (inst_ty.isSignedInt()) return self.builder.buildSSubSat(lhs, rhs, "");
        return self.builder.buildUSubSat(lhs, rhs, "");
    }

    fn airMul(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);

        if (inst_ty.isAnyFloat()) return self.builder.buildFMul(lhs, rhs, "");
        if (inst_ty.isSignedInt()) return self.builder.buildNSWMul(lhs, rhs, "");
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

        if (inst_ty.isAnyFloat()) return self.todo("saturating float mul", .{});
        if (inst_ty.isSignedInt()) return self.builder.buildSMulFixSat(lhs, rhs, "");
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

        if (inst_ty.isRuntimeFloat()) {
            const result = self.builder.buildFDiv(lhs, rhs, "");
            return self.callTrunc(result, inst_ty);
        }
        if (inst_ty.isSignedInt()) return self.builder.buildSDiv(lhs, rhs, "");
        return self.builder.buildUDiv(lhs, rhs, "");
    }

    fn airDivFloor(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);

        if (inst_ty.isRuntimeFloat()) {
            const result = self.builder.buildFDiv(lhs, rhs, "");
            return try self.callFloor(result, inst_ty);
        }
        if (inst_ty.isSignedInt()) {
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

        if (inst_ty.isRuntimeFloat()) return self.builder.buildFDiv(lhs, rhs, "");
        if (inst_ty.isSignedInt()) return self.builder.buildExactSDiv(lhs, rhs, "");
        return self.builder.buildExactUDiv(lhs, rhs, "");
    }

    fn airRem(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);

        if (inst_ty.isRuntimeFloat()) return self.builder.buildFRem(lhs, rhs, "");
        if (inst_ty.isSignedInt()) return self.builder.buildSRem(lhs, rhs, "");
        return self.builder.buildURem(lhs, rhs, "");
    }

    fn airMod(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.air.typeOfIndex(inst);
        const inst_llvm_ty = try self.dg.llvmType(inst_ty);

        if (inst_ty.isRuntimeFloat()) {
            const a = self.builder.buildFRem(lhs, rhs, "");
            const b = self.builder.buildFAdd(a, rhs, "");
            const c = self.builder.buildFRem(b, rhs, "");
            const zero = inst_llvm_ty.constNull();
            const ltz = self.builder.buildFCmp(.OLT, lhs, zero, "");
            return self.builder.buildSelect(ltz, c, a, "");
        }
        if (inst_ty.isSignedInt()) {
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
        const lhs_type = self.air.typeOf(bin_op.lhs);
        const tg = self.dg.module.getTarget();
        const casted_rhs = if (self.air.typeOf(bin_op.rhs).bitSize(tg) < lhs_type.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_type), "")
        else
            rhs;
        if (lhs_type.isSignedInt()) return self.builder.buildNSWShl(lhs, casted_rhs, "");
        return self.builder.buildNUWShl(lhs, casted_rhs, "");
    }

    fn airShl(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_type = self.air.typeOf(bin_op.lhs);
        const tg = self.dg.module.getTarget();
        const casted_rhs = if (self.air.typeOf(bin_op.rhs).bitSize(tg) < lhs_type.bitSize(tg))
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
        const lhs_type = self.air.typeOf(bin_op.lhs);
        const tg = self.dg.module.getTarget();
        const casted_rhs = if (self.air.typeOf(bin_op.rhs).bitSize(tg) < lhs_type.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_type), "")
        else
            rhs;
        if (lhs_type.isSignedInt()) return self.builder.buildSShlSat(lhs, casted_rhs, "");
        return self.builder.buildUShlSat(lhs, casted_rhs, "");
    }

    fn airShr(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_type = self.air.typeOf(bin_op.lhs);
        const tg = self.dg.module.getTarget();
        const casted_rhs = if (self.air.typeOf(bin_op.rhs).bitSize(tg) < lhs_type.bitSize(tg))
            self.builder.buildZExt(rhs, try self.dg.llvmType(lhs_type), "")
        else
            rhs;

        if (self.air.typeOfIndex(inst).isSignedInt()) {
            return self.builder.buildAShr(lhs, casted_rhs, "");
        } else {
            return self.builder.buildLShr(lhs, casted_rhs, "");
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
        const dest_llvm_ty = try self.dg.llvmType(self.air.typeOfIndex(inst));

        return self.builder.buildFPTrunc(operand, dest_llvm_ty, "");
    }

    fn airFpext(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst))
            return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
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

        if (operand_is_ref and result_is_ref) {
            // They are both pointers; just do a bitcast on the pointers :)
            return self.builder.buildBitCast(operand, llvm_dest_ty.pointerType(0), "");
        }

        if (operand_ty.zigTypeTag() == .Int and inst_ty.zigTypeTag() == .Pointer) {
            return self.builder.buildIntToPtr(operand, llvm_dest_ty, "");
        }

        if (operand_ty.zigTypeTag() == .Vector and inst_ty.zigTypeTag() == .Array) {
            const target = self.dg.module.getTarget();
            const elem_ty = operand_ty.childType();
            if (!result_is_ref) {
                return self.dg.todo("implement bitcast vector to non-ref array", .{});
            }
            const array_ptr = self.buildAlloca(llvm_dest_ty);
            const bitcast_ok = elem_ty.bitSize(target) == elem_ty.abiSize(target) * 8;
            if (bitcast_ok) {
                const llvm_vector_ty = try self.dg.llvmType(operand_ty);
                const casted_ptr = self.builder.buildBitCast(array_ptr, llvm_vector_ty.pointerType(0), "");
                _ = self.builder.buildStore(operand, casted_ptr);
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
            const target = self.dg.module.getTarget();
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
            return self.builder.buildLoad(casted_ptr, "");
        }

        if (result_is_ref) {
            // Bitcast the result pointer, then store.
            const result_ptr = self.buildAlloca(llvm_dest_ty);
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            const casted_ptr = self.builder.buildBitCast(result_ptr, operand_llvm_ty.pointerType(0), "");
            _ = self.builder.buildStore(operand, casted_ptr);
            return result_ptr;
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
        if (isByRef(inst_ty)) {
            // TODO declare debug variable
            return arg_val;
        } else {
            const ptr_val = self.buildAlloca(try self.dg.llvmType(inst_ty));
            _ = self.builder.buildStore(arg_val, ptr_val);
            // TODO declare debug variable
            return arg_val;
        }
    }

    fn airAlloc(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;
        const ptr_ty = self.air.typeOfIndex(inst);
        const pointee_type = ptr_ty.childType();
        if (!pointee_type.hasCodeGenBits()) return self.dg.lowerPtrToVoid(ptr_ty);

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
        if (!ret_ty.hasCodeGenBits()) return null;
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

        const entry_block = self.llvm_func.getFirstBasicBlock().?;
        if (entry_block.getFirstInstruction()) |first_inst| {
            self.builder.positionBuilder(entry_block, first_inst);
        } else {
            self.builder.positionBuilderAtEnd(entry_block);
        }

        const alloca = self.builder.buildAlloca(llvm_ty, "");
        self.builder.positionBuilderAtEnd(prev_block);
        return alloca;
    }

    fn airStore(self: *FuncGen, inst: Air.Inst.Index) !?*const llvm.Value {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;
        const dest_ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const src_operand = try self.resolveInst(bin_op.rhs);
        self.store(dest_ptr, ptr_ty, src_operand, .NotAtomic);
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
        const llvm_fn = self.getIntrinsic("llvm.debugtrap");
        _ = self.builder.buildCall(llvm_fn, undefined, 0, .C, .Auto, "");
        return null;
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
            const load_inst = self.load(casted_ptr, ptr_ty).?;
            load_inst.setOrdering(ordering);
            return self.builder.buildTrunc(load_inst, try self.dg.llvmType(operand_ty), "");
        }
        const load_inst = self.load(ptr, ptr_ty).?;
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
        if (!operand_ty.hasCodeGenBits()) return null;
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
        const val_is_undef = if (self.air.value(extra.lhs)) |val| val.isUndef() else false;
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

    fn airClzCtz(self: *FuncGen, inst: Air.Inst.Index, prefix: [*:0]const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);
        const target = self.dg.module.getTarget();
        const bits = operand_ty.intInfo(target).bits;

        var fn_name_buf: [100]u8 = undefined;
        const llvm_fn_name = std.fmt.bufPrintZ(&fn_name_buf, "llvm.{s}.i{d}", .{
            prefix, bits,
        }) catch unreachable;
        const llvm_i1 = self.context.intType(1);
        const fn_val = self.dg.object.llvm_module.getNamedFunction(llvm_fn_name) orelse blk: {
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            const param_types = [_]*const llvm.Type{ operand_llvm_ty, llvm_i1 };
            const fn_type = llvm.functionType(operand_llvm_ty, &param_types, param_types.len, .False);
            break :blk self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        };

        const params = [_]*const llvm.Value{ operand, llvm_i1.constNull() };
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

    fn airPopCount(self: *FuncGen, inst: Air.Inst.Index, prefix: [*:0]const u8) !?*const llvm.Value {
        if (self.liveness.isUnused(inst)) return null;

        const ty_op = self.air.instructions.items(.data)[inst].ty_op;
        const operand_ty = self.air.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);
        const target = self.dg.module.getTarget();
        const bits = operand_ty.intInfo(target).bits;

        var fn_name_buf: [100]u8 = undefined;
        const llvm_fn_name = std.fmt.bufPrintZ(&fn_name_buf, "llvm.{s}.i{d}", .{
            prefix, bits,
        }) catch unreachable;
        const fn_val = self.dg.object.llvm_module.getNamedFunction(llvm_fn_name) orelse blk: {
            const operand_llvm_ty = try self.dg.llvmType(operand_ty);
            const param_types = [_]*const llvm.Type{operand_llvm_ty};
            const fn_type = llvm.functionType(operand_llvm_ty, &param_types, param_types.len, .False);
            break :blk self.dg.object.llvm_module.addFunction(llvm_fn_name, fn_type);
        };

        const params = [_]*const llvm.Value{operand};
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

    fn callFloor(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "floor");
    }

    fn callCeil(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "ceil");
    }

    fn callTrunc(self: *FuncGen, arg: *const llvm.Value, ty: Type) !*const llvm.Value {
        return self.callFloatUnary(arg, ty, "trunc");
    }

    fn callFloatUnary(self: *FuncGen, arg: *const llvm.Value, ty: Type, name: []const u8) !*const llvm.Value {
        const target = self.dg.module.getTarget();

        var fn_name_buf: [100]u8 = undefined;
        const llvm_fn_name = std.fmt.bufPrintZ(&fn_name_buf, "llvm.{s}.f{d}", .{
            name, ty.floatBits(target),
        }) catch unreachable;

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
        const struct_ty = struct_ptr_ty.childType();
        switch (struct_ty.zigTypeTag()) {
            .Struct => {
                const llvm_field_index = llvmFieldIndex(struct_ty, field_index);
                return self.builder.buildStructGEP(struct_ptr, llvm_field_index, "");
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
        if (!field.ty.hasCodeGenBits()) {
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

    fn getIntrinsic(self: *FuncGen, name: []const u8) *const llvm.Value {
        const id = llvm.lookupIntrinsicID(name.ptr, name.len);
        assert(id != 0);
        // TODO: add support for overload intrinsics by passing the prefix of the intrinsic
        //       to `lookupIntrinsicID` and then passing the correct types to
        //       `getIntrinsicDeclaration`
        return self.llvmModule().getIntrinsicDeclaration(id, null, 0);
    }

    fn load(self: *FuncGen, ptr: *const llvm.Value, ptr_ty: Type) ?*const llvm.Value {
        const pointee_ty = ptr_ty.childType();
        if (!pointee_ty.hasCodeGenBits()) return null;
        if (isByRef(pointee_ty)) return ptr;
        const llvm_inst = self.builder.buildLoad(ptr, "");
        const target = self.dg.module.getTarget();
        llvm_inst.setAlignment(ptr_ty.ptrAlignment(target));
        llvm_inst.setVolatile(llvm.Bool.fromBool(ptr_ty.isVolatilePtr()));
        return llvm_inst;
    }

    fn store(
        self: *FuncGen,
        ptr: *const llvm.Value,
        ptr_ty: Type,
        elem: *const llvm.Value,
        ordering: llvm.AtomicOrdering,
    ) void {
        const elem_ty = ptr_ty.childType();
        if (!elem_ty.hasCodeGenBits()) {
            return;
        }
        const target = self.dg.module.getTarget();
        if (!isByRef(elem_ty)) {
            const store_inst = self.builder.buildStore(elem, ptr);
            store_inst.setOrdering(ordering);
            store_inst.setAlignment(ptr_ty.ptrAlignment(target));
            store_inst.setVolatile(llvm.Bool.fromBool(ptr_ty.isVolatilePtr()));
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
            ptr_ty.isVolatilePtr(),
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
    };
}

/// Take into account 0 bit fields.
fn llvmFieldIndex(ty: Type, index: u32) c_uint {
    const struct_obj = ty.castTag(.@"struct").?.data;
    var result: c_uint = 0;
    for (struct_obj.fields.values()[0..index]) |field| {
        if (field.ty.hasCodeGenBits()) {
            result += 1;
        }
    }
    return result;
}

fn firstParamSRet(fn_info: Type.Payload.Function.Data, target: std.Target) bool {
    switch (fn_info.cc) {
        .Unspecified, .Inline => return isByRef(fn_info.return_type),
        .C => {},
        else => return false,
    }
    switch (target.cpu.arch) {
        .mips, .mipsel => return false,
        .x86_64 => switch (target.os.tag) {
            .windows => return @import("../arch/x86_64/abi.zig").classifyWindows(fn_info.return_type, target) == .memory,
            else => return @import("../arch/x86_64/abi.zig").classifySystemV(fn_info.return_type, target)[0] == .memory,
        },
        else => return false, // TODO investigate C ABI for other architectures
    }
}

fn isByRef(ty: Type) bool {
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

        .Array, .Struct, .Frame => return ty.hasCodeGenBits(),
        .Union => return ty.hasCodeGenBits(),
        .ErrorUnion => return isByRef(ty.errorUnionPayload()),
        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            return isByRef(ty.optionalChild(&buf));
        },
    }
}
