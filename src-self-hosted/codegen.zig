const std = @import("std");
const Compilation = @import("compilation.zig").Compilation;
// we go through llvm instead of c for 2 reasons:
// 1. to avoid accidentally calling the non-thread-safe functions
// 2. patch up some of the types to remove nullability
const llvm = @import("llvm.zig");
const ir = @import("ir.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const event = std.event;

pub async fn renderToLlvm(comp: *Compilation, fn_val: *Value.Fn, code: *ir.Code) !void {
    fn_val.base.ref();
    defer fn_val.base.deref(comp);
    defer code.destroy(comp.a());

    const llvm_handle = try comp.event_loop_local.getAnyLlvmContext();
    defer llvm_handle.release(comp.event_loop_local);

    const context = llvm_handle.node.data;

    const module = llvm.ModuleCreateWithNameInContext(comp.name.ptr(), context) orelse return error.OutOfMemory;
    defer llvm.DisposeModule(module);

    const builder = llvm.CreateBuilderInContext(context) orelse return error.OutOfMemory;
    defer llvm.DisposeBuilder(builder);

    var ofile = ObjectFile{
        .comp = comp,
        .module = module,
        .builder = builder,
        .context = context,
        .lock = event.Lock.init(comp.loop),
    };

    try renderToLlvmModule(&ofile, fn_val, code);

    if (comp.verbose_llvm_ir) {
        llvm.DumpModule(ofile.module);
    }
}

pub const ObjectFile = struct {
    comp: *Compilation,
    module: llvm.ModuleRef,
    builder: llvm.BuilderRef,
    context: llvm.ContextRef,
    lock: event.Lock,

    fn a(self: *ObjectFile) *std.mem.Allocator {
        return self.comp.a();
    }
};

pub fn renderToLlvmModule(ofile: *ObjectFile, fn_val: *Value.Fn, code: *ir.Code) !void {
    // TODO audit more of codegen.cpp:fn_llvm_value and port more logic
    const llvm_fn_type = try fn_val.base.typeof.getLlvmType(ofile);
    const llvm_fn = llvm.AddFunction(ofile.module, fn_val.symbol_name.ptr(), llvm_fn_type);
}
