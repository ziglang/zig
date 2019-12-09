const builtin = @import("builtin");
const is_test = builtin.is_test;

const is_gnu = switch (builtin.abi) {
    .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => true,
    else => false,
};
const is_mingw = builtin.os == .windows and is_gnu;

comptime {
    const linkage = if (is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.Weak;
    const strong_linkage = if (is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.Strong;

    switch (builtin.arch) {
        .i386, .x86_64 => @export("__zig_probe_stack", @import("compiler_rt/stack_probe.zig").zig_probe_stack, linkage),
        else => {},
    }

    @export("__lesf2", @import("compiler_rt/comparesf2.zig").__lesf2, linkage);
    @export("__ledf2", @import("compiler_rt/comparedf2.zig").__ledf2, linkage);
    @export("__letf2", @import("compiler_rt/comparetf2.zig").__letf2, linkage);

    @export("__gesf2", @import("compiler_rt/comparesf2.zig").__gesf2, linkage);
    @export("__gedf2", @import("compiler_rt/comparedf2.zig").__gedf2, linkage);
    @export("__getf2", @import("compiler_rt/comparetf2.zig").__getf2, linkage);

    if (!is_test) {
        @export("__cmpsf2", @import("compiler_rt/comparesf2.zig").__lesf2, linkage);
        @export("__cmpdf2", @import("compiler_rt/comparedf2.zig").__ledf2, linkage);
        @export("__cmptf2", @import("compiler_rt/comparetf2.zig").__letf2, linkage);

        @export("__eqsf2", @import("compiler_rt/comparesf2.zig").__eqsf2, linkage);
        @export("__eqdf2", @import("compiler_rt/comparedf2.zig").__eqdf2, linkage);
        @export("__eqtf2", @import("compiler_rt/comparetf2.zig").__letf2, linkage);

        @export("__ltsf2", @import("compiler_rt/comparesf2.zig").__ltsf2, linkage);
        @export("__ltdf2", @import("compiler_rt/comparedf2.zig").__ltdf2, linkage);
        @export("__lttf2", @import("compiler_rt/comparetf2.zig").__letf2, linkage);

        @export("__nesf2", @import("compiler_rt/comparesf2.zig").__nesf2, linkage);
        @export("__nedf2", @import("compiler_rt/comparedf2.zig").__nedf2, linkage);
        @export("__netf2", @import("compiler_rt/comparetf2.zig").__letf2, linkage);

        @export("__gtsf2", @import("compiler_rt/comparesf2.zig").__gtsf2, linkage);
        @export("__gtdf2", @import("compiler_rt/comparedf2.zig").__gtdf2, linkage);
        @export("__gttf2", @import("compiler_rt/comparetf2.zig").__getf2, linkage);

        @export("__gnu_h2f_ieee", @import("compiler_rt/extendXfYf2.zig").__extendhfsf2, linkage);
        @export("__gnu_f2h_ieee", @import("compiler_rt/truncXfYf2.zig").__truncsfhf2, linkage);
    }

    @export("__unordsf2", @import("compiler_rt/comparesf2.zig").__unordsf2, linkage);
    @export("__unorddf2", @import("compiler_rt/comparedf2.zig").__unorddf2, linkage);
    @export("__unordtf2", @import("compiler_rt/comparetf2.zig").__unordtf2, linkage);

    @export("__addsf3", @import("compiler_rt/addXf3.zig").__addsf3, linkage);
    @export("__adddf3", @import("compiler_rt/addXf3.zig").__adddf3, linkage);
    @export("__addtf3", @import("compiler_rt/addXf3.zig").__addtf3, linkage);
    @export("__subsf3", @import("compiler_rt/addXf3.zig").__subsf3, linkage);
    @export("__subdf3", @import("compiler_rt/addXf3.zig").__subdf3, linkage);
    @export("__subtf3", @import("compiler_rt/addXf3.zig").__subtf3, linkage);

    @export("__mulsf3", @import("compiler_rt/mulXf3.zig").__mulsf3, linkage);
    @export("__muldf3", @import("compiler_rt/mulXf3.zig").__muldf3, linkage);
    @export("__multf3", @import("compiler_rt/mulXf3.zig").__multf3, linkage);

    @export("__divsf3", @import("compiler_rt/divsf3.zig").__divsf3, linkage);
    @export("__divdf3", @import("compiler_rt/divdf3.zig").__divdf3, linkage);

    @export("__ashlti3", @import("compiler_rt/ashlti3.zig").__ashlti3, linkage);
    @export("__lshrti3", @import("compiler_rt/lshrti3.zig").__lshrti3, linkage);
    @export("__ashrti3", @import("compiler_rt/ashrti3.zig").__ashrti3, linkage);

    @export("__floatsidf", @import("compiler_rt/floatsiXf.zig").__floatsidf, linkage);
    @export("__floatsisf", @import("compiler_rt/floatsiXf.zig").__floatsisf, linkage);
    @export("__floatdidf", @import("compiler_rt/floatdidf.zig").__floatdidf, linkage);
    @export("__floatsitf", @import("compiler_rt/floatsiXf.zig").__floatsitf, linkage);
    @export("__floatunsidf", @import("compiler_rt/floatunsidf.zig").__floatunsidf, linkage);
    @export("__floatundidf", @import("compiler_rt/floatundidf.zig").__floatundidf, linkage);

    @export("__floattitf", @import("compiler_rt/floattitf.zig").__floattitf, linkage);
    @export("__floattidf", @import("compiler_rt/floattidf.zig").__floattidf, linkage);
    @export("__floattisf", @import("compiler_rt/floattisf.zig").__floattisf, linkage);

    @export("__floatunditf", @import("compiler_rt/floatunditf.zig").__floatunditf, linkage);
    @export("__floatunsitf", @import("compiler_rt/floatunsitf.zig").__floatunsitf, linkage);

    @export("__floatuntitf", @import("compiler_rt/floatuntitf.zig").__floatuntitf, linkage);
    @export("__floatuntidf", @import("compiler_rt/floatuntidf.zig").__floatuntidf, linkage);
    @export("__floatuntisf", @import("compiler_rt/floatuntisf.zig").__floatuntisf, linkage);

    @export("__extenddftf2", @import("compiler_rt/extendXfYf2.zig").__extenddftf2, linkage);
    @export("__extendsftf2", @import("compiler_rt/extendXfYf2.zig").__extendsftf2, linkage);
    @export("__extendhfsf2", @import("compiler_rt/extendXfYf2.zig").__extendhfsf2, linkage);

    @export("__truncsfhf2", @import("compiler_rt/truncXfYf2.zig").__truncsfhf2, linkage);
    @export("__truncdfhf2", @import("compiler_rt/truncXfYf2.zig").__truncdfhf2, linkage);
    @export("__trunctfdf2", @import("compiler_rt/truncXfYf2.zig").__trunctfdf2, linkage);
    @export("__trunctfsf2", @import("compiler_rt/truncXfYf2.zig").__trunctfsf2, linkage);

    @export("__truncdfsf2", @import("compiler_rt/truncXfYf2.zig").__truncdfsf2, linkage);

    @export("__extendsfdf2", @import("compiler_rt/extendXfYf2.zig").__extendsfdf2, linkage);

    @export("__fixunssfsi", @import("compiler_rt/fixunssfsi.zig").__fixunssfsi, linkage);
    @export("__fixunssfdi", @import("compiler_rt/fixunssfdi.zig").__fixunssfdi, linkage);
    @export("__fixunssfti", @import("compiler_rt/fixunssfti.zig").__fixunssfti, linkage);

    @export("__fixunsdfsi", @import("compiler_rt/fixunsdfsi.zig").__fixunsdfsi, linkage);
    @export("__fixunsdfdi", @import("compiler_rt/fixunsdfdi.zig").__fixunsdfdi, linkage);
    @export("__fixunsdfti", @import("compiler_rt/fixunsdfti.zig").__fixunsdfti, linkage);

    @export("__fixunstfsi", @import("compiler_rt/fixunstfsi.zig").__fixunstfsi, linkage);
    @export("__fixunstfdi", @import("compiler_rt/fixunstfdi.zig").__fixunstfdi, linkage);
    @export("__fixunstfti", @import("compiler_rt/fixunstfti.zig").__fixunstfti, linkage);

    @export("__fixdfdi", @import("compiler_rt/fixdfdi.zig").__fixdfdi, linkage);
    @export("__fixdfsi", @import("compiler_rt/fixdfsi.zig").__fixdfsi, linkage);
    @export("__fixdfti", @import("compiler_rt/fixdfti.zig").__fixdfti, linkage);
    @export("__fixsfdi", @import("compiler_rt/fixsfdi.zig").__fixsfdi, linkage);
    @export("__fixsfsi", @import("compiler_rt/fixsfsi.zig").__fixsfsi, linkage);
    @export("__fixsfti", @import("compiler_rt/fixsfti.zig").__fixsfti, linkage);
    @export("__fixtfdi", @import("compiler_rt/fixtfdi.zig").__fixtfdi, linkage);
    @export("__fixtfsi", @import("compiler_rt/fixtfsi.zig").__fixtfsi, linkage);
    @export("__fixtfti", @import("compiler_rt/fixtfti.zig").__fixtfti, linkage);

    @export("__udivmoddi4", @import("compiler_rt/udivmoddi4.zig").__udivmoddi4, linkage);
    @export("__popcountdi2", @import("compiler_rt/popcountdi2.zig").__popcountdi2, linkage);

    @export("__muldi3", @import("compiler_rt/muldi3.zig").__muldi3, linkage);
    @export("__divmoddi4", __divmoddi4, linkage);
    @export("__divsi3", __divsi3, linkage);
    @export("__divdi3", __divdi3, linkage);
    @export("__udivsi3", __udivsi3, linkage);
    @export("__udivdi3", __udivdi3, linkage);
    @export("__modsi3", __modsi3, linkage);
    @export("__moddi3", __moddi3, linkage);
    @export("__umodsi3", __umodsi3, linkage);
    @export("__umoddi3", __umoddi3, linkage);
    @export("__divmodsi4", __divmodsi4, linkage);
    @export("__udivmodsi4", __udivmodsi4, linkage);

    @export("__negsf2", @import("compiler_rt/negXf2.zig").__negsf2, linkage);
    @export("__negdf2", @import("compiler_rt/negXf2.zig").__negdf2, linkage);

    if (is_arm_arch and !is_arm_64 and !is_test) {
        @export("__aeabi_unwind_cpp_pr0", __aeabi_unwind_cpp_pr0, strong_linkage);
        @export("__aeabi_unwind_cpp_pr1", __aeabi_unwind_cpp_pr1, linkage);
        @export("__aeabi_unwind_cpp_pr2", __aeabi_unwind_cpp_pr2, linkage);

        @export("__aeabi_lmul", @import("compiler_rt/muldi3.zig").__muldi3, linkage);

        @export("__aeabi_ldivmod", __aeabi_ldivmod, linkage);
        @export("__aeabi_uldivmod", __aeabi_uldivmod, linkage);

        @export("__aeabi_idiv", __divsi3, linkage);
        @export("__aeabi_idivmod", __aeabi_idivmod, linkage);
        @export("__aeabi_uidiv", __udivsi3, linkage);
        @export("__aeabi_uidivmod", __aeabi_uidivmod, linkage);

        @export("__aeabi_memcpy", __aeabi_memcpy, linkage);
        @export("__aeabi_memcpy4", __aeabi_memcpy, linkage);
        @export("__aeabi_memcpy8", __aeabi_memcpy, linkage);

        @export("__aeabi_memmove", __aeabi_memmove, linkage);
        @export("__aeabi_memmove4", __aeabi_memmove, linkage);
        @export("__aeabi_memmove8", __aeabi_memmove, linkage);

        @export("__aeabi_memset", __aeabi_memset, linkage);
        @export("__aeabi_memset4", __aeabi_memset, linkage);
        @export("__aeabi_memset8", __aeabi_memset, linkage);

        @export("__aeabi_memclr", __aeabi_memclr, linkage);
        @export("__aeabi_memclr4", __aeabi_memclr, linkage);
        @export("__aeabi_memclr8", __aeabi_memclr, linkage);

        @export("__aeabi_memcmp", __aeabi_memcmp, linkage);
        @export("__aeabi_memcmp4", __aeabi_memcmp, linkage);
        @export("__aeabi_memcmp8", __aeabi_memcmp, linkage);

        @export("__aeabi_f2d", @import("compiler_rt/extendXfYf2.zig").__extendsfdf2, linkage);
        @export("__aeabi_i2d", @import("compiler_rt/floatsiXf.zig").__floatsidf, linkage);
        @export("__aeabi_l2d", @import("compiler_rt/floatdidf.zig").__floatdidf, linkage);
        @export("__aeabi_ui2d", @import("compiler_rt/floatunsidf.zig").__floatunsidf, linkage);
        @export("__aeabi_ul2d", @import("compiler_rt/floatundidf.zig").__floatundidf, linkage);

        @export("__aeabi_fneg", @import("compiler_rt/negXf2.zig").__negsf2, linkage);
        @export("__aeabi_dneg", @import("compiler_rt/negXf2.zig").__negdf2, linkage);

        @export("__aeabi_fmul", @import("compiler_rt/mulXf3.zig").__mulsf3, linkage);
        @export("__aeabi_dmul", @import("compiler_rt/mulXf3.zig").__muldf3, linkage);

        @export("__aeabi_d2h", @import("compiler_rt/truncXfYf2.zig").__truncdfhf2, linkage);

        @export("__aeabi_f2ulz", @import("compiler_rt/fixunssfdi.zig").__fixunssfdi, linkage);
        @export("__aeabi_d2ulz", @import("compiler_rt/fixunsdfdi.zig").__fixunsdfdi, linkage);

        @export("__aeabi_f2lz", @import("compiler_rt/fixsfdi.zig").__fixsfdi, linkage);
        @export("__aeabi_d2lz", @import("compiler_rt/fixdfdi.zig").__fixdfdi, linkage);

        @export("__aeabi_d2uiz", @import("compiler_rt/fixunsdfsi.zig").__fixunsdfsi, linkage);

        @export("__aeabi_h2f", @import("compiler_rt/extendXfYf2.zig").__extendhfsf2, linkage);
        @export("__aeabi_f2h", @import("compiler_rt/truncXfYf2.zig").__truncsfhf2, linkage);

        @export("__aeabi_i2f", @import("compiler_rt/floatsiXf.zig").__floatsisf, linkage);
        @export("__aeabi_d2f", @import("compiler_rt/truncXfYf2.zig").__truncdfsf2, linkage);

        @export("__aeabi_fadd", @import("compiler_rt/addXf3.zig").__addsf3, linkage);
        @export("__aeabi_dadd", @import("compiler_rt/addXf3.zig").__adddf3, linkage);
        @export("__aeabi_fsub", @import("compiler_rt/addXf3.zig").__subsf3, linkage);
        @export("__aeabi_dsub", @import("compiler_rt/addXf3.zig").__subdf3, linkage);

        @export("__aeabi_f2uiz", @import("compiler_rt/fixunssfsi.zig").__fixunssfsi, linkage);

        @export("__aeabi_f2iz", @import("compiler_rt/fixsfsi.zig").__fixsfsi, linkage);
        @export("__aeabi_d2iz", @import("compiler_rt/fixdfsi.zig").__fixdfsi, linkage);

        @export("__aeabi_fdiv", @import("compiler_rt/divsf3.zig").__divsf3, linkage);
        @export("__aeabi_ddiv", @import("compiler_rt/divdf3.zig").__divdf3, linkage);

        @export("__aeabi_fcmpeq", @import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpeq, linkage);
        @export("__aeabi_fcmplt", @import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmplt, linkage);
        @export("__aeabi_fcmple", @import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmple, linkage);
        @export("__aeabi_fcmpge", @import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpge, linkage);
        @export("__aeabi_fcmpgt", @import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpgt, linkage);
        @export("__aeabi_fcmpun", @import("compiler_rt/comparesf2.zig").__unordsf2, linkage);

        @export("__aeabi_dcmpeq", @import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpeq, linkage);
        @export("__aeabi_dcmplt", @import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmplt, linkage);
        @export("__aeabi_dcmple", @import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmple, linkage);
        @export("__aeabi_dcmpge", @import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpge, linkage);
        @export("__aeabi_dcmpgt", @import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpgt, linkage);
        @export("__aeabi_dcmpun", @import("compiler_rt/comparedf2.zig").__unorddf2, linkage);
    }
    if (builtin.os == .windows) {
        // Default stack-probe functions emitted by LLVM
        if (is_mingw) {
            @export("_alloca", @import("compiler_rt/stack_probe.zig")._chkstk, strong_linkage);
            @export("___chkstk_ms", @import("compiler_rt/stack_probe.zig").___chkstk_ms, strong_linkage);
        } else if (!builtin.link_libc) {
            // This symbols are otherwise exported by MSVCRT.lib
            @export("_chkstk", @import("compiler_rt/stack_probe.zig")._chkstk, strong_linkage);
            @export("__chkstk", @import("compiler_rt/stack_probe.zig").__chkstk, strong_linkage);
        }

        if (is_mingw) {
            @export("__stack_chk_fail", __stack_chk_fail, strong_linkage);
            @export("__stack_chk_guard", __stack_chk_guard, strong_linkage);
        }

        switch (builtin.arch) {
            .i386 => {
                // Don't let LLVM apply the stdcall name mangling on those MSVC
                // builtin functions
                @export("\x01__alldiv", @import("compiler_rt/aulldiv.zig")._alldiv, strong_linkage);
                @export("\x01__aulldiv", @import("compiler_rt/aulldiv.zig")._aulldiv, strong_linkage);
                @export("\x01__allrem", @import("compiler_rt/aullrem.zig")._allrem, strong_linkage);
                @export("\x01__aullrem", @import("compiler_rt/aullrem.zig")._aullrem, strong_linkage);

                @export("__divti3", @import("compiler_rt/divti3.zig").__divti3, linkage);
                @export("__modti3", @import("compiler_rt/modti3.zig").__modti3, linkage);
                @export("__multi3", @import("compiler_rt/multi3.zig").__multi3, linkage);
                @export("__udivti3", @import("compiler_rt/udivti3.zig").__udivti3, linkage);
                @export("__udivmodti4", @import("compiler_rt/udivmodti4.zig").__udivmodti4, linkage);
                @export("__umodti3", @import("compiler_rt/umodti3.zig").__umodti3, linkage);
            },
            .x86_64 => {
                // The "ti" functions must use @Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                @export("__divti3", @import("compiler_rt/divti3.zig").__divti3_windows_x86_64, linkage);
                @export("__modti3", @import("compiler_rt/modti3.zig").__modti3_windows_x86_64, linkage);
                @export("__multi3", @import("compiler_rt/multi3.zig").__multi3_windows_x86_64, linkage);
                @export("__udivti3", @import("compiler_rt/udivti3.zig").__udivti3_windows_x86_64, linkage);
                @export("__udivmodti4", @import("compiler_rt/udivmodti4.zig").__udivmodti4_windows_x86_64, linkage);
                @export("__umodti3", @import("compiler_rt/umodti3.zig").__umodti3_windows_x86_64, linkage);
            },
            else => {},
        }
    } else {
        if (builtin.glibc_version != null) {
            @export("__stack_chk_guard", __stack_chk_guard, linkage);
        }
        @export("__divti3", @import("compiler_rt/divti3.zig").__divti3, linkage);
        @export("__modti3", @import("compiler_rt/modti3.zig").__modti3, linkage);
        @export("__multi3", @import("compiler_rt/multi3.zig").__multi3, linkage);
        @export("__udivti3", @import("compiler_rt/udivti3.zig").__udivti3, linkage);
        @export("__udivmodti4", @import("compiler_rt/udivmodti4.zig").__udivmodti4, linkage);
        @export("__umodti3", @import("compiler_rt/umodti3.zig").__umodti3, linkage);
    }
    @export("__muloti4", @import("compiler_rt/muloti4.zig").__muloti4, linkage);
    @export("__mulodi4", @import("compiler_rt/mulodi4.zig").__mulodi4, linkage);
}

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const __udivmoddi4 = @import("compiler_rt/udivmoddi4.zig").__udivmoddi4;

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    if (is_test) {
        std.debug.panic("{}", msg);
    } else {
        unreachable;
    }
}

extern fn __stack_chk_fail() noreturn {
    @panic("stack smashing detected");
}

extern var __stack_chk_guard: usize = blk: {
    var buf = [1]u8{0} ** @sizeOf(usize);
    buf[@sizeOf(usize) - 1] = 255;
    buf[@sizeOf(usize) - 2] = '\n';
    break :blk @bitCast(usize, buf);
};

extern fn __aeabi_unwind_cpp_pr0() void {
    unreachable;
}
extern fn __aeabi_unwind_cpp_pr1() void {
    unreachable;
}
extern fn __aeabi_unwind_cpp_pr2() void {
    unreachable;
}

extern fn __divmoddi4(a: i64, b: i64, rem: *i64) i64 {
    @setRuntimeSafety(is_test);

    const d = __divdi3(a, b);
    rem.* = a -% (d *% b);
    return d;
}

extern fn __divdi3(a: i64, b: i64) i64 {
    @setRuntimeSafety(is_test);

    // Set aside the sign of the quotient.
    const sign = @bitCast(u64, (a ^ b) >> 63);
    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    const res = __udivmoddi4(@bitCast(u64, abs_a), @bitCast(u64, abs_b), null);
    // Apply sign of quotient to result and return.
    return @bitCast(i64, (res ^ sign) -% sign);
}

extern fn __moddi3(a: i64, b: i64) i64 {
    @setRuntimeSafety(is_test);

    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    var r: u64 = undefined;
    _ = __udivmoddi4(@bitCast(u64, abs_a), @bitCast(u64, abs_b), &r);
    // Apply the sign of the dividend and return.
    return (@bitCast(i64, r) ^ (a >> 63)) -% (a >> 63);
}

extern fn __udivdi3(a: u64, b: u64) u64 {
    @setRuntimeSafety(is_test);
    return __udivmoddi4(a, b, null);
}

extern fn __umoddi3(a: u64, b: u64) u64 {
    @setRuntimeSafety(is_test);

    var r: u64 = undefined;
    _ = __udivmoddi4(a, b, &r);
    return r;
}

extern fn __aeabi_uidivmod(n: u32, d: u32) extern struct {
    q: u32,
    r: u32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uidivmod).ReturnType = undefined;
    result.q = __udivmodsi4(n, d, &result.r);
    return result;
}

extern fn __aeabi_uldivmod(n: u64, d: u64) extern struct {
    q: u64,
    r: u64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uldivmod).ReturnType = undefined;
    result.q = __udivmoddi4(n, d, &result.r);
    return result;
}

extern fn __aeabi_idivmod(n: i32, d: i32) extern struct {
    q: i32,
    r: i32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_idivmod).ReturnType = undefined;
    result.q = __divmodsi4(n, d, &result.r);
    return result;
}

extern fn __aeabi_ldivmod(n: i64, d: i64) extern struct {
    q: i64,
    r: i64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_ldivmod).ReturnType = undefined;
    result.q = __divmoddi4(n, d, &result.r);
    return result;
}

const is_arm_64 = switch (builtin.arch) {
    builtin.Arch.aarch64,
    builtin.Arch.aarch64_be,
    => true,
    else => false,
};

const is_arm_arch = switch (builtin.arch) {
    builtin.Arch.arm,
    builtin.Arch.armeb,
    builtin.Arch.aarch64,
    builtin.Arch.aarch64_be,
    builtin.Arch.thumb,
    builtin.Arch.thumbeb,
    => true,
    else => false,
};

const is_arm_32 = is_arm_arch and !is_arm_64;

const use_thumb_1 = usesThumb1(builtin.arch);

fn usesThumb1(arch: builtin.Arch) bool {
    return switch (arch) {
        .arm => |sub_arch| switch (sub_arch) {
            .v6m => true,
            else => false,
        },
        .armeb => |sub_arch| switch (sub_arch) {
            .v6m => true,
            else => false,
        },
        .thumb => |sub_arch| switch (sub_arch) {
            .v5,
            .v5te,
            .v4t,
            .v6,
            .v6m,
            .v6k,
            => true,
            else => false,
        },
        .thumbeb => |sub_arch| switch (sub_arch) {
            .v5,
            .v5te,
            .v4t,
            .v6,
            .v6m,
            .v6k,
            => true,
            else => false,
        },
        else => false,
    };
}

test "usesThumb1" {
    testing.expect(usesThumb1(builtin.Arch{ .arm = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .arm = .v5 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .armeb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .armeb = .v5 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v5 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v5te }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v4t }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6k }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .thumb = .v6t2 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v5 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v5te }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v4t }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6k }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .thumbeb = .v6t2 }));
    //etc.

    testing.expect(!usesThumb1(builtin.Arch{ .aarch64 = .v8 }));
    testing.expect(!usesThumb1(builtin.Arch{ .aarch64_be = .v8 }));
    testing.expect(!usesThumb1(builtin.Arch.x86_64));
    testing.expect(!usesThumb1(builtin.Arch.riscv32));
    //etc.
}

const use_thumb_1_pre_armv6 = usesThumb1PreArmv6(builtin.arch);

fn usesThumb1PreArmv6(arch: builtin.Arch) bool {
    return switch (arch) {
        .thumb => |sub_arch| switch (sub_arch) {
            .v5, .v5te, .v4t => true,
            else => false,
        },
        .thumbeb => |sub_arch| switch (sub_arch) {
            .v5, .v5te, .v4t => true,
            else => false,
        },
        else => false,
    };
}

nakedcc fn __aeabi_memcpy() noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memcpy
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memcpy
        );
    }
    unreachable;
}

nakedcc fn __aeabi_memmove() noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memmove
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memmove
        );
    }
    unreachable;
}

nakedcc fn __aeabi_memset() noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1_pre_armv6) {
        asm volatile (
            \\ eors    r1, r2
            \\ eors    r2, r1
            \\ eors    r1, r2
            \\ push    {r7, lr}
            \\ b       memset
            \\ pop     {r7, pc}
        );
    } else if (use_thumb_1) {
        asm volatile (
            \\ mov     r3, r1
            \\ mov     r1, r2
            \\ mov     r2, r3
            \\ push    {r7, lr}
            \\ b       memset
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ mov     r3, r1
            \\ mov     r1, r2
            \\ mov     r2, r3
            \\ b       memset
        );
    }
    unreachable;
}

nakedcc fn __aeabi_memclr() noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1_pre_armv6) {
        asm volatile (
            \\ adds    r2, r1, #0
            \\ movs    r1, #0
            \\ push    {r7, lr}
            \\ bl      memset
            \\ pop     {r7, pc}
        );
    } else if (use_thumb_1) {
        asm volatile (
            \\ mov     r2, r1
            \\ movs    r1, #0
            \\ push    {r7, lr}
            \\ bl      memset
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ mov     r2, r1
            \\ movs    r1, #0
            \\ b       memset
        );
    }
    unreachable;
}

nakedcc fn __aeabi_memcmp() noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memcmp
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memcmp
        );
    }
    unreachable;
}

extern fn __divmodsi4(a: i32, b: i32, rem: *i32) i32 {
    @setRuntimeSafety(is_test);

    const d = __divsi3(a, b);
    rem.* = a -% (d * b);
    return d;
}

extern fn __udivmodsi4(a: u32, b: u32, rem: *u32) u32 {
    @setRuntimeSafety(is_test);

    const d = __udivsi3(a, b);
    rem.* = @bitCast(u32, @bitCast(i32, a) -% (@bitCast(i32, d) * @bitCast(i32, b)));
    return d;
}

extern fn __divsi3(n: i32, d: i32) i32 {
    @setRuntimeSafety(is_test);

    // Set aside the sign of the quotient.
    const sign = @bitCast(u32, (n ^ d) >> 31);
    // Take absolute value of a and b via abs(x) = (x^(x >> 31)) - (x >> 31).
    const abs_n = (n ^ (n >> 31)) -% (n >> 31);
    const abs_d = (d ^ (d >> 31)) -% (d >> 31);
    // abs(a) / abs(b)
    const res = @bitCast(u32, abs_n) / @bitCast(u32, abs_d);
    // Apply sign of quotient to result and return.
    return @bitCast(i32, (res ^ sign) -% sign);
}

extern fn __udivsi3(n: u32, d: u32) u32 {
    @setRuntimeSafety(is_test);

    const n_uword_bits: c_uint = u32.bit_count;
    // special cases
    if (d == 0) return 0; // ?!
    if (n == 0) return 0;
    var sr = @bitCast(c_uint, @as(c_int, @clz(u32, d)) - @as(c_int, @clz(u32, n)));
    // 0 <= sr <= n_uword_bits - 1 or sr large
    if (sr > n_uword_bits - 1) {
        // d > r
        return 0;
    }
    if (sr == n_uword_bits - 1) {
        // d == 1
        return n;
    }
    sr += 1;
    // 1 <= sr <= n_uword_bits - 1
    // Not a special case
    var q: u32 = n << @intCast(u5, n_uword_bits - sr);
    var r: u32 = n >> @intCast(u5, sr);
    var carry: u32 = 0;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r = (r << 1) | (q >> @intCast(u5, n_uword_bits - 1));
        q = (q << 1) | carry;
        // carry = 0;
        // if (r.all >= d.all)
        // {
        //      r.all -= d.all;
        //      carry = 1;
        // }
        const s = @intCast(i32, d -% r -% 1) >> @intCast(u5, n_uword_bits - 1);
        carry = @intCast(u32, s & 1);
        r -= d & @bitCast(u32, s);
    }
    q = (q << 1) | carry;
    return q;
}

extern fn __modsi3(n: i32, d: i32) i32 {
    @setRuntimeSafety(is_test);

    return n -% __divsi3(n, d) *% d;
}

extern fn __umodsi3(n: u32, d: u32) u32 {
    @setRuntimeSafety(is_test);

    return n -% __udivsi3(n, d) *% d;
}

test "test_umoddi3" {
    test_one_umoddi3(0, 1, 0);
    test_one_umoddi3(2, 1, 0);
    test_one_umoddi3(0x8000000000000000, 1, 0x0);
    test_one_umoddi3(0x8000000000000000, 2, 0x0);
    test_one_umoddi3(0xFFFFFFFFFFFFFFFF, 2, 0x1);
}

fn test_one_umoddi3(a: u64, b: u64, expected_r: u64) void {
    const r = __umoddi3(a, b);
    testing.expect(r == expected_r);
}

test "test_udivsi3" {
    const cases = [_][3]u32{
        [_]u32{
            0x00000000,
            0x00000001,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x00000002,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x00000003,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x00000010,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x0747AE14,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x00000000,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x00000001,
            0x00000001,
        },
        [_]u32{
            0x00000001,
            0x00000002,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x00000003,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x00000010,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x0747AE14,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x00000001,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x00000001,
            0x00000002,
        },
        [_]u32{
            0x00000002,
            0x00000002,
            0x00000001,
        },
        [_]u32{
            0x00000002,
            0x00000003,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x00000010,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x0747AE14,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x00000002,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0x00000001,
            0x00000003,
        },
        [_]u32{
            0x00000003,
            0x00000002,
            0x00000001,
        },
        [_]u32{
            0x00000003,
            0x00000003,
            0x00000001,
        },
        [_]u32{
            0x00000003,
            0x00000010,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0x0747AE14,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x00000003,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0x00000001,
            0x00000010,
        },
        [_]u32{
            0x00000010,
            0x00000002,
            0x00000008,
        },
        [_]u32{
            0x00000010,
            0x00000003,
            0x00000005,
        },
        [_]u32{
            0x00000010,
            0x00000010,
            0x00000001,
        },
        [_]u32{
            0x00000010,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0x0747AE14,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x00000010,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x078644FA,
            0x00000001,
            0x078644FA,
        },
        [_]u32{
            0x078644FA,
            0x00000002,
            0x03C3227D,
        },
        [_]u32{
            0x078644FA,
            0x00000003,
            0x028216FE,
        },
        [_]u32{
            0x078644FA,
            0x00000010,
            0x0078644F,
        },
        [_]u32{
            0x078644FA,
            0x078644FA,
            0x00000001,
        },
        [_]u32{
            0x078644FA,
            0x0747AE14,
            0x00000001,
        },
        [_]u32{
            0x078644FA,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x078644FA,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x078644FA,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x078644FA,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x078644FA,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0x00000001,
            0x0747AE14,
        },
        [_]u32{
            0x0747AE14,
            0x00000002,
            0x03A3D70A,
        },
        [_]u32{
            0x0747AE14,
            0x00000003,
            0x026D3A06,
        },
        [_]u32{
            0x0747AE14,
            0x00000010,
            0x00747AE1,
        },
        [_]u32{
            0x0747AE14,
            0x078644FA,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0x0747AE14,
            0x00000001,
        },
        [_]u32{
            0x0747AE14,
            0x7FFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x0747AE14,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x7FFFFFFF,
            0x00000001,
            0x7FFFFFFF,
        },
        [_]u32{
            0x7FFFFFFF,
            0x00000002,
            0x3FFFFFFF,
        },
        [_]u32{
            0x7FFFFFFF,
            0x00000003,
            0x2AAAAAAA,
        },
        [_]u32{
            0x7FFFFFFF,
            0x00000010,
            0x07FFFFFF,
        },
        [_]u32{
            0x7FFFFFFF,
            0x078644FA,
            0x00000011,
        },
        [_]u32{
            0x7FFFFFFF,
            0x0747AE14,
            0x00000011,
        },
        [_]u32{
            0x7FFFFFFF,
            0x7FFFFFFF,
            0x00000001,
        },
        [_]u32{
            0x7FFFFFFF,
            0x80000000,
            0x00000000,
        },
        [_]u32{
            0x7FFFFFFF,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x7FFFFFFF,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x7FFFFFFF,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0x80000000,
            0x00000001,
            0x80000000,
        },
        [_]u32{
            0x80000000,
            0x00000002,
            0x40000000,
        },
        [_]u32{
            0x80000000,
            0x00000003,
            0x2AAAAAAA,
        },
        [_]u32{
            0x80000000,
            0x00000010,
            0x08000000,
        },
        [_]u32{
            0x80000000,
            0x078644FA,
            0x00000011,
        },
        [_]u32{
            0x80000000,
            0x0747AE14,
            0x00000011,
        },
        [_]u32{
            0x80000000,
            0x7FFFFFFF,
            0x00000001,
        },
        [_]u32{
            0x80000000,
            0x80000000,
            0x00000001,
        },
        [_]u32{
            0x80000000,
            0xFFFFFFFD,
            0x00000000,
        },
        [_]u32{
            0x80000000,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0x80000000,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0xFFFFFFFD,
            0x00000001,
            0xFFFFFFFD,
        },
        [_]u32{
            0xFFFFFFFD,
            0x00000002,
            0x7FFFFFFE,
        },
        [_]u32{
            0xFFFFFFFD,
            0x00000003,
            0x55555554,
        },
        [_]u32{
            0xFFFFFFFD,
            0x00000010,
            0x0FFFFFFF,
        },
        [_]u32{
            0xFFFFFFFD,
            0x078644FA,
            0x00000022,
        },
        [_]u32{
            0xFFFFFFFD,
            0x0747AE14,
            0x00000023,
        },
        [_]u32{
            0xFFFFFFFD,
            0x7FFFFFFF,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFD,
            0x80000000,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFD,
            0xFFFFFFFD,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFD,
            0xFFFFFFFE,
            0x00000000,
        },
        [_]u32{
            0xFFFFFFFD,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0xFFFFFFFE,
            0x00000001,
            0xFFFFFFFE,
        },
        [_]u32{
            0xFFFFFFFE,
            0x00000002,
            0x7FFFFFFF,
        },
        [_]u32{
            0xFFFFFFFE,
            0x00000003,
            0x55555554,
        },
        [_]u32{
            0xFFFFFFFE,
            0x00000010,
            0x0FFFFFFF,
        },
        [_]u32{
            0xFFFFFFFE,
            0x078644FA,
            0x00000022,
        },
        [_]u32{
            0xFFFFFFFE,
            0x0747AE14,
            0x00000023,
        },
        [_]u32{
            0xFFFFFFFE,
            0x7FFFFFFF,
            0x00000002,
        },
        [_]u32{
            0xFFFFFFFE,
            0x80000000,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFE,
            0xFFFFFFFD,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFE,
            0xFFFFFFFE,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFE,
            0xFFFFFFFF,
            0x00000000,
        },
        [_]u32{
            0xFFFFFFFF,
            0x00000001,
            0xFFFFFFFF,
        },
        [_]u32{
            0xFFFFFFFF,
            0x00000002,
            0x7FFFFFFF,
        },
        [_]u32{
            0xFFFFFFFF,
            0x00000003,
            0x55555555,
        },
        [_]u32{
            0xFFFFFFFF,
            0x00000010,
            0x0FFFFFFF,
        },
        [_]u32{
            0xFFFFFFFF,
            0x078644FA,
            0x00000022,
        },
        [_]u32{
            0xFFFFFFFF,
            0x0747AE14,
            0x00000023,
        },
        [_]u32{
            0xFFFFFFFF,
            0x7FFFFFFF,
            0x00000002,
        },
        [_]u32{
            0xFFFFFFFF,
            0x80000000,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFF,
            0xFFFFFFFD,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFF,
            0xFFFFFFFE,
            0x00000001,
        },
        [_]u32{
            0xFFFFFFFF,
            0xFFFFFFFF,
            0x00000001,
        },
    };

    for (cases) |case| {
        test_one_udivsi3(case[0], case[1], case[2]);
    }
}

fn test_one_udivsi3(a: u32, b: u32, expected_q: u32) void {
    const q: u32 = __udivsi3(a, b);
    testing.expect(q == expected_q);
}

test "test_divsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 2, 1, 2 },
        [_]i32{ 2, -1, -2 },
        [_]i32{ -2, 1, -2 },
        [_]i32{ -2, -1, 2 },

        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 1, @bitCast(i32, @as(u32, 0x80000000)) },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), -1, @bitCast(i32, @as(u32, 0x80000000)) },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), -2, 0x40000000 },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 2, @bitCast(i32, @as(u32, 0xC0000000)) },
    };

    for (cases) |case| {
        test_one_divsi3(case[0], case[1], case[2]);
    }
}

fn test_one_divsi3(a: i32, b: i32, expected_q: i32) void {
    const q: i32 = __divsi3(a, b);
    testing.expect(q == expected_q);
}

test "test_divmodsi4" {
    const cases = [_][4]i32{
        [_]i32{ 0, 1, 0, 0 },
        [_]i32{ 0, -1, 0, 0 },
        [_]i32{ 2, 1, 2, 0 },
        [_]i32{ 2, -1, -2, 0 },
        [_]i32{ -2, 1, -2, 0 },
        [_]i32{ -2, -1, 2, 0 },
        [_]i32{ 7, 5, 1, 2 },
        [_]i32{ -7, 5, -1, -2 },
        [_]i32{ 19, 5, 3, 4 },
        [_]i32{ 19, -5, -3, 4 },

        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 8, @bitCast(i32, @as(u32, 0xf0000000)), 0 },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000007)), 8, @bitCast(i32, @as(u32, 0xf0000001)), -1 },
    };

    for (cases) |case| {
        test_one_divmodsi4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_divmodsi4(a: i32, b: i32, expected_q: i32, expected_r: i32) void {
    var r: i32 = undefined;
    const q: i32 = __divmodsi4(a, b, &r);
    testing.expect(q == expected_q and r == expected_r);
}

test "test_divdi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 2, 1, 2 },
        [_]i64{ 2, -1, -2 },
        [_]i64{ -2, 1, -2 },
        [_]i64{ -2, -1, 2 },

        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 1, @bitCast(i64, @as(u64, 0x8000000000000000)) },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -1, @bitCast(i64, @as(u64, 0x8000000000000000)) },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -2, 0x4000000000000000 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 2, @bitCast(i64, @as(u64, 0xC000000000000000)) },
    };

    for (cases) |case| {
        test_one_divdi3(case[0], case[1], case[2]);
    }
}

fn test_one_divdi3(a: i64, b: i64, expected_q: i64) void {
    const q: i64 = __divdi3(a, b);
    testing.expect(q == expected_q);
}

test "test_moddi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 5, 3, 2 },
        [_]i64{ 5, -3, 2 },
        [_]i64{ -5, 3, -2 },
        [_]i64{ -5, -3, -2 },

        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 1, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -1, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 2, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -2, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 3, -2 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -3, -2 },
    };

    for (cases) |case| {
        test_one_moddi3(case[0], case[1], case[2]);
    }
}

fn test_one_moddi3(a: i64, b: i64, expected_r: i64) void {
    const r: i64 = __moddi3(a, b);
    testing.expect(r == expected_r);
}

test "test_modsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 5, 3, 2 },
        [_]i32{ 5, -3, 2 },
        [_]i32{ -5, 3, -2 },
        [_]i32{ -5, -3, -2 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 1, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 2, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), -2, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 3, -2 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), -3, -2 },
    };

    for (cases) |case| {
        test_one_modsi3(case[0], case[1], case[2]);
    }
}

fn test_one_modsi3(a: i32, b: i32, expected_r: i32) void {
    const r: i32 = __modsi3(a, b);
    testing.expect(r == expected_r);
}

test "test_umodsi3" {
    const cases = [_][3]u32{
        [_]u32{ 0x00000000, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000000, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000000, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000000, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000000, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000001, 0x00000003, 0x00000001 },
        [_]u32{ 0x00000001, 0x00000010, 0x00000001 },
        [_]u32{ 0x00000001, 0x078644FA, 0x00000001 },
        [_]u32{ 0x00000001, 0x0747AE14, 0x00000001 },
        [_]u32{ 0x00000001, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x00000001, 0x80000000, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFF, 0x00000001 },
        [_]u32{ 0x00000002, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000003, 0x00000002 },
        [_]u32{ 0x00000002, 0x00000010, 0x00000002 },
        [_]u32{ 0x00000002, 0x078644FA, 0x00000002 },
        [_]u32{ 0x00000002, 0x0747AE14, 0x00000002 },
        [_]u32{ 0x00000002, 0x7FFFFFFF, 0x00000002 },
        [_]u32{ 0x00000002, 0x80000000, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFD, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFE, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFF, 0x00000002 },
        [_]u32{ 0x00000003, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000003, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000003, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000003, 0x00000010, 0x00000003 },
        [_]u32{ 0x00000003, 0x078644FA, 0x00000003 },
        [_]u32{ 0x00000003, 0x0747AE14, 0x00000003 },
        [_]u32{ 0x00000003, 0x7FFFFFFF, 0x00000003 },
        [_]u32{ 0x00000003, 0x80000000, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFD, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFE, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFF, 0x00000003 },
        [_]u32{ 0x00000010, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000010, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000010, 0x00000003, 0x00000001 },
        [_]u32{ 0x00000010, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000010, 0x078644FA, 0x00000010 },
        [_]u32{ 0x00000010, 0x0747AE14, 0x00000010 },
        [_]u32{ 0x00000010, 0x7FFFFFFF, 0x00000010 },
        [_]u32{ 0x00000010, 0x80000000, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFD, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFE, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFF, 0x00000010 },
        [_]u32{ 0x078644FA, 0x00000001, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000002, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000003, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000010, 0x0000000A },
        [_]u32{ 0x078644FA, 0x078644FA, 0x00000000 },
        [_]u32{ 0x078644FA, 0x0747AE14, 0x003E96E6 },
        [_]u32{ 0x078644FA, 0x7FFFFFFF, 0x078644FA },
        [_]u32{ 0x078644FA, 0x80000000, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFD, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFE, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFF, 0x078644FA },
        [_]u32{ 0x0747AE14, 0x00000001, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x00000002, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x00000003, 0x00000002 },
        [_]u32{ 0x0747AE14, 0x00000010, 0x00000004 },
        [_]u32{ 0x0747AE14, 0x078644FA, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x7FFFFFFF, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0x80000000, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFD, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFE, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFF, 0x0747AE14 },
        [_]u32{ 0x7FFFFFFF, 0x00000001, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0x00000002, 0x00000001 },
        [_]u32{ 0x7FFFFFFF, 0x00000003, 0x00000001 },
        [_]u32{ 0x7FFFFFFF, 0x00000010, 0x0000000F },
        [_]u32{ 0x7FFFFFFF, 0x078644FA, 0x00156B65 },
        [_]u32{ 0x7FFFFFFF, 0x0747AE14, 0x043D70AB },
        [_]u32{ 0x7FFFFFFF, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0x80000000, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFD, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFE, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFF },
        [_]u32{ 0x80000000, 0x00000001, 0x00000000 },
        [_]u32{ 0x80000000, 0x00000002, 0x00000000 },
        [_]u32{ 0x80000000, 0x00000003, 0x00000002 },
        [_]u32{ 0x80000000, 0x00000010, 0x00000000 },
        [_]u32{ 0x80000000, 0x078644FA, 0x00156B66 },
        [_]u32{ 0x80000000, 0x0747AE14, 0x043D70AC },
        [_]u32{ 0x80000000, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x80000000, 0x80000000, 0x00000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFD, 0x80000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFE, 0x80000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFF, 0x80000000 },
        [_]u32{ 0xFFFFFFFD, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0x00000002, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0x00000003, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0x00000010, 0x0000000D },
        [_]u32{ 0xFFFFFFFD, 0x078644FA, 0x002AD6C9 },
        [_]u32{ 0xFFFFFFFD, 0x0747AE14, 0x01333341 },
        [_]u32{ 0xFFFFFFFD, 0x7FFFFFFF, 0x7FFFFFFE },
        [_]u32{ 0xFFFFFFFD, 0x80000000, 0x7FFFFFFD },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFE, 0xFFFFFFFD },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFF, 0xFFFFFFFD },
        [_]u32{ 0xFFFFFFFE, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x00000002, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x00000003, 0x00000002 },
        [_]u32{ 0xFFFFFFFE, 0x00000010, 0x0000000E },
        [_]u32{ 0xFFFFFFFE, 0x078644FA, 0x002AD6CA },
        [_]u32{ 0xFFFFFFFE, 0x0747AE14, 0x01333342 },
        [_]u32{ 0xFFFFFFFE, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x80000000, 0x7FFFFFFE },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFE },
        [_]u32{ 0xFFFFFFFF, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFF, 0x00000002, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0x00000003, 0x00000000 },
        [_]u32{ 0xFFFFFFFF, 0x00000010, 0x0000000F },
        [_]u32{ 0xFFFFFFFF, 0x078644FA, 0x002AD6CB },
        [_]u32{ 0xFFFFFFFF, 0x0747AE14, 0x01333343 },
        [_]u32{ 0xFFFFFFFF, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFD, 0x00000002 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000 },
    };

    for (cases) |case| {
        test_one_umodsi3(case[0], case[1], case[2]);
    }
}

fn test_one_umodsi3(a: u32, b: u32, expected_r: u32) void {
    const r: u32 = __umodsi3(a, b);
    testing.expect(r == expected_r);
}
