const std = @import("std");
// TODO codegen pretends that Module is renamed to Build because I plan to
// do that refactor at some point
const Build = @import("module.zig").Module;
// we go through llvm instead of c for 2 reasons:
// 1. to avoid accidentally calling the non-thread-safe functions
// 2. patch up some of the types to remove nullability
const llvm = @import("llvm.zig");
const ir = @import("ir.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const event = std.event;

pub async fn renderToLlvm(build: *Build, fn_val: *Value.Fn, code: *ir.Code) !void {
    fn_val.base.ref();
    defer fn_val.base.deref(build);
    defer code.destroy(build.a());

    const llvm_handle = try build.event_loop_local.getAnyLlvmContext();
    defer llvm_handle.release(build.event_loop_local);

    const context = llvm_handle.node.data;

    const module = llvm.ModuleCreateWithNameInContext(build.name.ptr(), context) orelse return error.OutOfMemory;
    defer llvm.DisposeModule(module);

    const builder = llvm.CreateBuilderInContext(context) orelse return error.OutOfMemory;
    defer llvm.DisposeBuilder(builder);

    var cunit = CompilationUnit{
        .build = build,
        .module = module,
        .builder = builder,
        .context = context,
        .lock = event.Lock.init(build.loop),
    };

    try renderToLlvmModule(&cunit, fn_val, code);

    if (build.verbose_llvm_ir) {
        llvm.DumpModule(cunit.module);
    }
}

pub const CompilationUnit = struct {
    build: *Build,
    module: llvm.ModuleRef,
    builder: llvm.BuilderRef,
    context: llvm.ContextRef,
    lock: event.Lock,

    fn a(self: *CompilationUnit) *std.mem.Allocator {
        return self.build.a();
    }
};

pub fn renderToLlvmModule(cunit: *CompilationUnit, fn_val: *Value.Fn, code: *ir.Code) !void {
    // TODO audit more of codegen.cpp:fn_llvm_value and port more logic
    const llvm_fn_type = try fn_val.base.typeof.getLlvmType(cunit);
    const llvm_fn = llvm.AddFunction(cunit.module, fn_val.symbol_name.ptr(), llvm_fn_type);
}
