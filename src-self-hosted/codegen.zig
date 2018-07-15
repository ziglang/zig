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
const assert = std.debug.assert;

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

    // TODO module level assembly
    //if (buf_len(&g->global_asm) != 0) {
    //    LLVMSetModuleInlineAsm(g->module, buf_ptr(&g->global_asm));
    //}

    // TODO
    //ZigLLVMDIBuilderFinalize(g->dbuilder);

    if (comp.verbose_llvm_ir) {
        llvm.DumpModule(ofile.module);
    }

    // verify the llvm module when safety is on
    if (std.debug.runtime_safety) {
        var error_ptr: ?[*]u8 = null;
        _ = llvm.VerifyModule(ofile.module, llvm.AbortProcessAction, &error_ptr);
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
    const llvm_fn = llvm.AddFunction(
        ofile.module,
        fn_val.symbol_name.ptr(),
        llvm_fn_type,
    ) orelse return error.OutOfMemory;

    const want_fn_safety = fn_val.block_scope.safety.get(ofile.comp);
    if (want_fn_safety and ofile.comp.haveLibC()) {
        try addLLVMFnAttr(ofile, llvm_fn, "sspstrong");
        try addLLVMFnAttrStr(ofile, llvm_fn, "stack-protector-buffer-size", "4");
    }

    // TODO
    //if (fn_val.align_stack) |align_stack| {
    //    try addLLVMFnAttrInt(ofile, llvm_fn, "alignstack", align_stack);
    //}

    const fn_type = fn_val.base.typeof.cast(Type.Fn).?;

    try addLLVMFnAttr(ofile, llvm_fn, "nounwind");
    //add_uwtable_attr(g, fn_table_entry->llvm_value);
    try addLLVMFnAttr(ofile, llvm_fn, "nobuiltin");

    //if (g->build_mode == BuildModeDebug && fn_table_entry->fn_inline != FnInlineAlways) {
    //    ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim", "true");
    //    ZigLLVMAddFunctionAttr(fn_table_entry->llvm_value, "no-frame-pointer-elim-non-leaf", nullptr);
    //}

    //if (fn_table_entry->section_name) {
    //    LLVMSetSection(fn_table_entry->llvm_value, buf_ptr(fn_table_entry->section_name));
    //}
    //if (fn_table_entry->align_bytes > 0) {
    //    LLVMSetAlignment(fn_table_entry->llvm_value, (unsigned)fn_table_entry->align_bytes);
    //} else {
    //    // We'd like to set the best alignment for the function here, but on Darwin LLVM gives
    //    // "Cannot getTypeInfo() on a type that is unsized!" assertion failure when calling
    //    // any of the functions for getting alignment. Not specifying the alignment should
    //    // use the ABI alignment, which is fine.
    //}

    //if (!type_has_bits(return_type)) {
    //    // nothing to do
    //} else if (type_is_codegen_pointer(return_type)) {
    //    addLLVMAttr(fn_table_entry->llvm_value, 0, "nonnull");
    //} else if (handle_is_ptr(return_type) &&
    //        calling_convention_does_first_arg_return(fn_type->data.fn.fn_type_id.cc))
    //{
    //    addLLVMArgAttr(fn_table_entry->llvm_value, 0, "sret");
    //    addLLVMArgAttr(fn_table_entry->llvm_value, 0, "nonnull");
    //}

    // TODO set parameter attributes

    // TODO
    //uint32_t err_ret_trace_arg_index = get_err_ret_trace_arg_index(g, fn_table_entry);
    //if (err_ret_trace_arg_index != UINT32_MAX) {
    //    addLLVMArgAttr(fn_table_entry->llvm_value, (unsigned)err_ret_trace_arg_index, "nonnull");
    //}

    const cur_ret_ptr = if (fn_type.return_type.handleIsPtr()) llvm.GetParam(llvm_fn, 0) else null;

    // build all basic blocks
    for (code.basic_block_list.toSlice()) |bb| {
        bb.llvm_block = llvm.AppendBasicBlockInContext(
            ofile.context,
            llvm_fn,
            bb.name_hint,
        ) orelse return error.OutOfMemory;
    }
    const entry_bb = code.basic_block_list.at(0);
    llvm.PositionBuilderAtEnd(ofile.builder, entry_bb.llvm_block);

    llvm.ClearCurrentDebugLocation(ofile.builder);

    // TODO set up error return tracing
    // TODO allocate temporary stack values
    // TODO create debug variable declarations for variables and allocate all local variables
    // TODO finishing error return trace setup. we have to do this after all the allocas.
    // TODO create debug variable declarations for parameters

    for (code.basic_block_list.toSlice()) |current_block| {
        llvm.PositionBuilderAtEnd(ofile.builder, current_block.llvm_block);
        for (current_block.instruction_list.toSlice()) |instruction| {
            if (instruction.ref_count == 0 and !instruction.hasSideEffects()) continue;

            instruction.llvm_value = try instruction.render(ofile, fn_val);
        }
        current_block.llvm_exit_block = llvm.GetInsertBlock(ofile.builder);
    }
}

fn addLLVMAttr(
    ofile: *ObjectFile,
    val: llvm.ValueRef,
    attr_index: llvm.AttributeIndex,
    attr_name: []const u8,
) !void {
    const kind_id = llvm.GetEnumAttributeKindForName(attr_name.ptr, attr_name.len);
    assert(kind_id != 0);
    const llvm_attr = llvm.CreateEnumAttribute(ofile.context, kind_id, 0) orelse return error.OutOfMemory;
    llvm.AddAttributeAtIndex(val, attr_index, llvm_attr);
}

fn addLLVMAttrStr(
    ofile: *ObjectFile,
    val: llvm.ValueRef,
    attr_index: llvm.AttributeIndex,
    attr_name: []const u8,
    attr_val: []const u8,
) !void {
    const llvm_attr = llvm.CreateStringAttribute(
        ofile.context,
        attr_name.ptr,
        @intCast(c_uint, attr_name.len),
        attr_val.ptr,
        @intCast(c_uint, attr_val.len),
    ) orelse return error.OutOfMemory;
    llvm.AddAttributeAtIndex(val, attr_index, llvm_attr);
}

fn addLLVMAttrInt(
    val: llvm.ValueRef,
    attr_index: llvm.AttributeIndex,
    attr_name: []const u8,
    attr_val: u64,
) !void {
    const kind_id = llvm.GetEnumAttributeKindForName(attr_name.ptr, attr_name.len);
    assert(kind_id != 0);
    const llvm_attr = llvm.CreateEnumAttribute(ofile.context, kind_id, attr_val) orelse return error.OutOfMemory;
    llvm.AddAttributeAtIndex(val, attr_index, llvm_attr);
}

fn addLLVMFnAttr(ofile: *ObjectFile, fn_val: llvm.ValueRef, attr_name: []const u8) !void {
    return addLLVMAttr(ofile, fn_val, @maxValue(llvm.AttributeIndex), attr_name);
}

fn addLLVMFnAttrStr(ofile: *ObjectFile, fn_val: llvm.ValueRef, attr_name: []const u8, attr_val: []const u8) !void {
    return addLLVMAttrStr(ofile, fn_val, @maxValue(llvm.AttributeIndex), attr_name, attr_val);
}

fn addLLVMFnAttrInt(ofile: *ObjectFile, fn_val: llvm.ValueRef, attr_name: []const u8, attr_val: u64) !void {
    return addLLVMAttrInt(ofile, fn_val, @maxValue(llvm.AttributeIndex), attr_name, attr_val);
}
