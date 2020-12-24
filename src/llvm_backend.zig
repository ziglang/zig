const std = @import("std");
const Allocator = std.mem.Allocator;
const Compilation = @import("Compilation.zig");
const llvm = @import("llvm_bindings.zig");
const link = @import("link.zig");

const Module = @import("Module.zig");
const TypedValue = @import("TypedValue.zig");
const ir = @import("ir.zig");
const Inst = ir.Inst;

const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;

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
        .hexagon => "hexagon",
        .mips => "mips",
        .mipsel => "mipsel",
        .mips64 => "mips64",
        .mips64el => "mips64el",
        .msp430 => "msp430",
        .powerpc => "powerpc",
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
        .spu_2 => return error.LLVMBackendDoesNotSupportSPUMarkII,
    };
    // TODO Add a sub-arch for some architectures depending on CPU features.

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
        .haiku => "haiku",
        .minix => "minix",
        .rtems => "rtems",
        .nacl => "nacl",
        .cnk => "cnk",
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
        .other => "unknown",
    };

    const llvm_abi = switch (target.abi) {
        .none => "unknown",
        .gnu => "gnu",
        .gnuabin32 => "gnuabin32",
        .gnuabi64 => "gnuabi64",
        .gnueabi => "gnueabi",
        .gnueabihf => "gnueabihf",
        .gnux32 => "gnux32",
        .code16 => "code16",
        .eabi => "eabi",
        .eabihf => "eabihf",
        .android => "android",
        .musl => "musl",
        .musleabi => "musleabi",
        .musleabihf => "musleabihf",
        .msvc => "msvc",
        .itanium => "itanium",
        .cygnus => "cygnus",
        .coreclr => "coreclr",
        .simulator => "simulator",
        .macabi => "macabi",
    };

    return std.fmt.allocPrintZ(allocator, "{}-unknown-{}-{}", .{ llvm_arch, llvm_os, llvm_abi });
}

pub const LLVMIRModule = struct {
    module: *Module,
    llvm_module: *const llvm.ModuleRef,
    target_machine: *const llvm.TargetMachineRef,
    builder: *const llvm.BuilderRef,

    output_path: []const u8,

    gpa: *Allocator,
    err_msg: ?*Compilation.ErrorMsg = null,

    pub fn create(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*LLVMIRModule {
        const self = try allocator.create(LLVMIRModule);
        errdefer allocator.destroy(self);

        const gpa = options.module.?.gpa;

        initializeLLVMTargets();

        const root_nameZ = try gpa.dupeZ(u8, options.root_name);
        defer gpa.free(root_nameZ);
        const llvm_module = llvm.ModuleRef.createWithName(root_nameZ.ptr);
        errdefer llvm_module.disposeModule();

        const llvm_target_triple = try targetTriple(gpa, options.target);
        defer gpa.free(llvm_target_triple);

        var error_message: [*:0]const u8 = undefined;
        var target_ref: *const llvm.TargetRef = undefined;
        if (llvm.TargetRef.getTargetFromTriple(llvm_target_triple.ptr, &target_ref, &error_message)) {
            defer llvm.disposeMessage(error_message);

            const stderr = std.io.getStdErr().outStream();
            try stderr.print(
                \\Zig is expecting LLVM to understand this target: '{s}'
                \\However LLVM responded with: "{s}"
                \\Zig is unable to continue. This is a bug in Zig:
                \\https://github.com/ziglang/zig/issues/438
                \\
            ,
                .{
                    llvm_target_triple,
                    error_message,
                },
            );
            return error.InvalidLLVMTriple;
        }

        const opt_level: llvm.CodeGenOptLevel = if (options.optimize_mode == .Debug) .None else .Aggressive;
        const target_machine = llvm.TargetMachineRef.createTargetMachine(
            target_ref,
            llvm_target_triple.ptr,
            "",
            "",
            opt_level,
            .Static,
            .Default,
        );
        errdefer target_machine.disposeTargetMachine();

        const builder = llvm.BuilderRef.createBuilder();
        errdefer builder.disposeBuilder();

        self.* = .{
            .module = options.module.?,
            .llvm_module = llvm_module,
            .target_machine = target_machine,
            .builder = builder,
            .output_path = sub_path,
            .gpa = gpa,
        };
        return self;
    }

    pub fn deinit(self: *LLVMIRModule, allocator: *Allocator) void {
        self.builder.disposeBuilder();
        self.target_machine.disposeTargetMachine();
        self.llvm_module.disposeModule();
        allocator.destroy(self);
    }

    fn initializeLLVMTargets() void {
        llvm.initializeAllTargets();
        llvm.initializeAllTargetInfos();
        llvm.initializeAllTargetMCs();
        llvm.initializeAllAsmPrinters();
        llvm.initializeAllAsmParsers();
    }

    pub fn flushModule(self: *LLVMIRModule, comp: *Compilation) !void {
        if (comp.verbose_llvm_ir) {
            const dump = self.llvm_module.printToString();
            defer llvm.disposeMessage(dump);

            const stderr = std.io.getStdErr().outStream();
            try stderr.writeAll(std.mem.spanZ(dump));
        }

        {
            var error_message: [*:0]const u8 = undefined;
            // verifyModule always allocs the error_message even if there is no error
            defer llvm.disposeMessage(error_message);

            if (self.llvm_module.verifyModule(.ReturnStatus, &error_message)) {
                const stderr = std.io.getStdErr().outStream();
                try stderr.print("broken LLVM module found: {s}\nThis is a bug in the Zig compiler.", .{error_message});
                return error.BrokenLLVMModule;
            }
        }

        const output_pathZ = try self.gpa.dupeZ(u8, self.output_path);
        defer self.gpa.free(output_pathZ);

        var error_message: [*:0]const u8 = undefined;
        // TODO: where to put the output object, zig-cache something?
        // TODO: caching?
        if (self.target_machine.emitToFile(
            self.llvm_module,
            output_pathZ.ptr,
            .ObjectFile,
            &error_message,
        )) {
            defer llvm.disposeMessage(error_message);

            const stderr = std.io.getStdErr().outStream();
            try stderr.print("LLVM failed to emit file: {s}\n", .{error_message});
            return error.FailedToEmit;
        }
    }

    pub fn updateDecl(self: *LLVMIRModule, module: *Module, decl: *Module.Decl) !void {
        const typed_value = decl.typed_value.most_recent.typed_value;
        self.gen(module, typed_value, decl.src()) catch |err| switch (err) {
            error.CodegenFail => {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl, self.err_msg.?);
                return;
            },
            else => |e| return e,
        };
    }

    fn gen(self: *LLVMIRModule, module: *Module, typed_value: TypedValue, src: usize) !void {
        switch (typed_value.ty.zigTypeTag()) {
            .Fn => {
                const func = typed_value.val.cast(Value.Payload.Function).?.func;

                const llvm_func = try self.resolveLLVMFunction(func);

                // We remove all the basic blocks of a function to support incremental
                // compilation!
                // TODO: remove all basic blocks if functions can have more than one
                if (llvm_func.getFirstBasicBlock()) |bb| {
                    bb.deleteBasicBlock();
                }

                const entry_block = llvm_func.appendBasicBlock("Entry");
                self.builder.positionBuilderAtEnd(entry_block);

                const instructions = func.analysis.success.instructions;
                for (instructions) |inst| {
                    switch (inst.tag) {
                        .breakpoint => try self.genBreakpoint(inst.castTag(.breakpoint).?),
                        .call => try self.genCall(inst.castTag(.call).?),
                        .unreach => self.genUnreach(inst.castTag(.unreach).?),
                        .retvoid => self.genRetVoid(inst.castTag(.retvoid).?),
                        .arg => self.genArg(inst.castTag(.arg).?),
                        .dbg_stmt => {
                            // TODO: implement debug info
                        },
                        else => |tag| return self.fail(src, "TODO implement LLVM codegen for Zir instruction: {}", .{tag}),
                    }
                }
            },
            else => |ty| return self.fail(src, "TODO implement LLVM codegen for top-level decl type: {}", .{ty}),
        }
    }

    fn genCall(self: *LLVMIRModule, inst: *Inst.Call) !void {
        if (inst.func.cast(Inst.Constant)) |func_inst| {
            if (func_inst.val.cast(Value.Payload.Function)) |func_val| {
                const func = func_val.func;
                const zig_fn_type = func.owner_decl.typed_value.most_recent.typed_value.ty;
                const llvm_fn = try self.resolveLLVMFunction(func);

                const num_args = inst.args.len;

                const llvm_param_vals = try self.gpa.alloc(*const llvm.ValueRef, num_args);
                defer self.gpa.free(llvm_param_vals);

                for (inst.args) |arg, i| {
                    llvm_param_vals[i] = try self.resolveInst(arg);
                }

                // TODO: LLVMBuildCall2 handles opaque function pointers, according to llvm docs
                //       Do we need that?
                const call = self.builder.buildCall(
                    llvm_fn,
                    if (num_args == 0) null else llvm_param_vals.ptr,
                    @intCast(c_uint, num_args),
                    "",
                );

                if (zig_fn_type.fnReturnType().zigTypeTag() == .NoReturn) {
                    _ = self.builder.buildUnreachable();
                }
            }
        }
    }

    fn genRetVoid(self: *LLVMIRModule, inst: *Inst.NoOp) void {
        _ = self.builder.buildRetVoid();
    }

    fn genUnreach(self: *LLVMIRModule, inst: *Inst.NoOp) void {
        _ = self.builder.buildUnreachable();
    }

    fn genArg(self: *LLVMIRModule, inst: *Inst.Arg) void {
        // TODO: implement this
    }

    fn genBreakpoint(self: *LLVMIRModule, inst: *Inst.NoOp) !void {
        // TODO: Store this function somewhere such that we dont have to add it again
        const fn_type = llvm.TypeRef.functionType(llvm.voidType(), null, 0, false);
        const func = self.llvm_module.addFunction("llvm.debugtrap", fn_type);
        // TODO: add assertion: LLVMGetIntrinsicID
        _ = self.builder.buildCall(func, null, 0, "");
    }

    fn resolveInst(self: *LLVMIRModule, inst: *ir.Inst) !*const llvm.ValueRef {
        if (inst.castTag(.constant)) |const_inst| {
            return self.genTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val });
        }
        return self.fail(inst.src, "TODO implement resolveInst", .{});
    }

    fn genTypedValue(self: *LLVMIRModule, src: usize, typed_value: TypedValue) !*const llvm.ValueRef {
        const llvm_type = self.getLLVMType(typed_value.ty);

        if (typed_value.val.isUndef())
            return llvm_type.getUndef();

        switch (typed_value.ty.zigTypeTag()) {
            .Bool => return if (typed_value.val.toBool()) llvm_type.constAllOnes() else llvm_type.constNull(),
            else => return self.fail(src, "TODO implement const of type '{}'", .{typed_value.ty}),
        }
    }

    /// If the llvm function does not exist, create it
    fn resolveLLVMFunction(self: *LLVMIRModule, func: *Module.Fn) !*const llvm.ValueRef {
        // TODO: do we want to store this in our own datastructure?
        if (self.llvm_module.getNamedFunction(func.owner_decl.name)) |llvm_fn| return llvm_fn;

        const zig_fn_type = func.owner_decl.typed_value.most_recent.typed_value.ty;
        const return_type = zig_fn_type.fnReturnType();

        const fn_param_len = zig_fn_type.fnParamLen();

        const fn_param_types = try self.gpa.alloc(Type, fn_param_len);
        defer self.gpa.free(fn_param_types);
        zig_fn_type.fnParamTypes(fn_param_types);

        const llvm_param = try self.gpa.alloc(*const llvm.TypeRef, fn_param_len);
        defer self.gpa.free(llvm_param);

        for (fn_param_types) |fn_param, i| {
            llvm_param[i] = self.getLLVMType(fn_param);
        }

        const fn_type = llvm.TypeRef.functionType(
            self.getLLVMType(return_type),
            if (fn_param_len == 0) null else llvm_param.ptr,
            @intCast(c_uint, fn_param_len),
            false,
        );
        const llvm_fn = self.llvm_module.addFunction(func.owner_decl.name, fn_type);

        if (return_type.zigTypeTag() == .NoReturn) {
            llvm_fn.addFnAttr("noreturn");
        }

        return llvm_fn;
    }

    fn getLLVMType(self: *LLVMIRModule, t: Type) *const llvm.TypeRef {
        switch (t.zigTypeTag()) {
            .Void => return llvm.voidType(),
            .NoReturn => return llvm.voidType(),
            .Int => {
                const info = t.intInfo(self.module.getTarget());
                return llvm.intType(info.bits);
            },
            .Bool => return llvm.intType(1),
            else => unreachable,
        }
    }

    pub fn fail(self: *LLVMIRModule, src: usize, comptime format: []const u8, args: anytype) error{ OutOfMemory, CodegenFail } {
        @setCold(true);
        std.debug.assert(self.err_msg == null);
        self.err_msg = try Compilation.ErrorMsg.create(self.gpa, src, format, args);
        return error.CodegenFail;
    }
};
