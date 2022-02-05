const std = @import("std");
const Compilation = @import("Compilation.zig");
const Type = @import("Type.zig");

const Builtins = @This();

const Builtin = struct {
    spec: Type.Specifier,
    func_ty: Type.Func,
    attrs: Attributes,

    const Attributes = packed struct {
        printf_like: u8 = 0,
        vprintf_like: u8 = 0,
        noreturn: bool = false,
        libm: bool = false,
        libc: bool = false,
        returns_twice: bool = false,
        eval_args: bool = true,
    };
};
const BuiltinMap = std.StringHashMapUnmanaged(Builtin);

_builtins: BuiltinMap = .{},
_params: []Type.Func.Param = &.{},

pub fn deinit(b: *Builtins, gpa: std.mem.Allocator) void {
    b._builtins.deinit(gpa);
    gpa.free(b._params);
}

fn add(
    a: std.mem.Allocator,
    b: *BuiltinMap,
    name: []const u8,
    ret_ty: Type,
    param_types: []const Type,
    spec: Type.Specifier,
    attrs: Builtin.Attributes,
) void {
    var params = a.alloc(Type.Func.Param, param_types.len) catch unreachable; // fib
    for (param_types) |param_ty, i| {
        params[i] = .{ .name_tok = 0, .ty = param_ty, .name = "" };
    }
    b.putAssumeCapacity(name, .{
        .spec = spec,
        .func_ty = .{
            .return_type = ret_ty,
            .params = params,
        },
        .attrs = attrs,
    });
}

pub fn create(comp: *Compilation) !Builtins {
    const builtin_count = 3;
    const param_count = 5;

    var b = BuiltinMap{};
    try b.ensureTotalCapacity(comp.gpa, builtin_count);
    errdefer b.deinit(comp.gpa);
    var _params = try comp.gpa.alloc(Type.Func.Param, param_count);
    errdefer comp.gpa.free(_params);
    var fib_state = std.heap.FixedBufferAllocator.init(std.mem.sliceAsBytes(_params));
    const a = fib_state.allocator();

    const void_ty = Type{ .specifier = .void };
    var va_list = comp.types.va_list;
    if (va_list.isArray()) va_list.decayArray();

    add(a, &b, "__builtin_va_start", void_ty, &.{ va_list, .{ .specifier = .special_va_start } }, .func, .{});
    add(a, &b, "__builtin_va_end", void_ty, &.{va_list}, .func, .{});
    add(a, &b, "__builtin_va_copy", void_ty, &.{ va_list, va_list }, .func, .{});

    return Builtins{ ._builtins = b, ._params = _params };
}

pub fn hasBuiltin(b: Builtins, name: []const u8) bool {
    if (std.mem.eql(u8, name, "__builtin_va_arg") or
        std.mem.eql(u8, name, "__builtin_choose_expr")) return true;
    return b._builtins.getPtr(name) != null;
}

pub fn get(b: Builtins, name: []const u8) ?Type {
    const builtin = b._builtins.getPtr(name) orelse return null;
    return Type{
        .specifier = builtin.spec,
        .data = .{ .func = &builtin.func_ty },
    };
}
