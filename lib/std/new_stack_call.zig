const std = @import("std.zig");
const TypeId = std.builtin.TypeId;

fn fmt(comptime format: []const u8, args: var) []u8 {
    var strBuf: [1024]u8 = undefined;
    return std.fmt.bufPrint(strBuf[0..], format, args) catch unreachable;
}

fn hashType(comptime T: type) []u8 {
    const name = @typeName(T);
    const hash = std.hash.Wyhash.hash(0, name);
    return fmt("{x}", .{hash});
}

pub fn newStackCall(buf: []u8, comptime func: var, args: var) @typeInfo(@TypeOf(func)).Fn.return_type.? {
    std.debug.assert(buf.len > 0xF);
    const ReturnType = @typeInfo(@TypeOf(func)).Fn.return_type.?;
    const ArgsType = @TypeOf(args);
    std.debug.assert(@as(TypeId, @typeInfo(ArgsType)) == .Struct);
    const isNoreturn = @as(TypeId, @typeInfo(ReturnType)) == .NoReturn;
    const isRet0bit = @sizeOf(ReturnType) < 1;
    const isArgs0bit = @sizeOf(ArgsType) < 1;

    const name = "__zig_call_" ++ comptime hashType(ArgsType);
    _ = struct {
        comptime {
            @export(@This().call, .{.name = name});
        }

        fn call(result_ptr: usize, args_ptr: usize, old_sp: usize) callconv(.C) usize {
            const typed_args: ArgsType = if (isArgs0bit) undefined else @intToPtr(*ArgsType, args_ptr).*;
            if (isNoreturn) {
                @call(.{}, func, typed_args);
                unreachable;
            } else if (isRet0bit) {
                _ = @call(.{}, func, typed_args);
            } else {
                @intToPtr(*ReturnType, result_ptr).* = @call(.{}, func, typed_args);
            }
            return old_sp;
        }
    };

    const buf_end = @ptrToInt(buf.ptr) + buf.len;
    const stack_ptr = buf_end - (buf_end & 0xF);

    var result: if (isNoreturn) void else ReturnType = undefined;
    const result_ptr: usize = if (isRet0bit) undefined else @ptrToInt(&result);
    const args_ptr: usize = if (isArgs0bit) undefined else @ptrToInt(&args);

    if (isNoreturn) {
        asm volatile (
            comptime fmt(
                \\ movq %%rax, %%rsp
                \\ callq {}
                \\ ud2
            , .{name})
            :
            : [stack_ptr] "{rax}" (stack_ptr),
              [args_ptr] "{rsi}" (args_ptr),
            : "rdi", "rsi", "rdx",
              "rcx", "r8", "r9",
              "rax", "rbp",
              "r10", "r11", "memory",
        );
        unreachable;
    } else {
        asm volatile (
            comptime fmt(
                \\ movq %%rsp, %%rdx
                \\ movq %%rax, %%rsp
                \\ callq {}
                \\ movq %%rax, %%rsp
            , .{name})
            :
            : [stack_ptr] "{rax}" (stack_ptr),
              [result_ptr] "{rdi}" (result_ptr),
              [args_ptr] "{rsi}" (args_ptr),
            : "rdi", "rsi", "rdx",
              "rcx", "r8", "r9",
              "rax", "rbp",
              "r10", "r11", "memory",
        );
        return result;
    }
}
