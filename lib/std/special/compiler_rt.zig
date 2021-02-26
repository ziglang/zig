// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const builtin = std.builtin;
const is_test = builtin.is_test;

const is_gnu = std.Target.current.abi.isGnu();
const is_mingw = builtin.os.tag == .windows and is_gnu;

comptime {
    const linkage = if (is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.Weak;
    const strong_linkage = if (is_test) builtin.GlobalLinkage.Internal else builtin.GlobalLinkage.Strong;

    switch (builtin.arch) {
        .i386,
        .x86_64,
        => @export(@import("compiler_rt/stack_probe.zig").zig_probe_stack, .{
            .name = "__zig_probe_stack",
            .linkage = linkage,
        }),

        else => {},
    }

    // __clear_cache manages its own logic about whether to be exported or not.
    _ = @import("compiler_rt/clear_cache.zig").clear_cache;

    @export(@import("compiler_rt/compareXf2.zig").__lesf2, .{ .name = "__lesf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__ledf2, .{ .name = "__ledf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__letf2, .{ .name = "__letf2", .linkage = linkage });

    @export(@import("compiler_rt/compareXf2.zig").__gesf2, .{ .name = "__gesf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__gedf2, .{ .name = "__gedf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__getf2, .{ .name = "__getf2", .linkage = linkage });

    if (!is_test) {
        @export(@import("compiler_rt/compareXf2.zig").__lesf2, .{ .name = "__cmpsf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__ledf2, .{ .name = "__cmpdf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__letf2, .{ .name = "__cmptf2", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__eqsf2, .{ .name = "__eqsf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__eqdf2, .{ .name = "__eqdf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__letf2, .{ .name = "__eqtf2", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__ltsf2, .{ .name = "__ltsf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__ltdf2, .{ .name = "__ltdf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__letf2, .{ .name = "__lttf2", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__nesf2, .{ .name = "__nesf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__nedf2, .{ .name = "__nedf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__letf2, .{ .name = "__netf2", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__gtsf2, .{ .name = "__gtsf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__gtdf2, .{ .name = "__gtdf2", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__getf2, .{ .name = "__gttf2", .linkage = linkage });

        @export(@import("compiler_rt/extendXfYf2.zig").__extendhfsf2, .{ .name = "__gnu_h2f_ieee", .linkage = linkage });
        @export(@import("compiler_rt/truncXfYf2.zig").__truncsfhf2, .{ .name = "__gnu_f2h_ieee", .linkage = linkage });
    }

    @export(@import("compiler_rt/compareXf2.zig").__unordsf2, .{ .name = "__unordsf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__unorddf2, .{ .name = "__unorddf2", .linkage = linkage });
    @export(@import("compiler_rt/compareXf2.zig").__unordtf2, .{ .name = "__unordtf2", .linkage = linkage });

    @export(@import("compiler_rt/addXf3.zig").__addsf3, .{ .name = "__addsf3", .linkage = linkage });
    @export(@import("compiler_rt/addXf3.zig").__adddf3, .{ .name = "__adddf3", .linkage = linkage });
    @export(@import("compiler_rt/addXf3.zig").__addtf3, .{ .name = "__addtf3", .linkage = linkage });
    @export(@import("compiler_rt/addXf3.zig").__subsf3, .{ .name = "__subsf3", .linkage = linkage });
    @export(@import("compiler_rt/addXf3.zig").__subdf3, .{ .name = "__subdf3", .linkage = linkage });
    @export(@import("compiler_rt/addXf3.zig").__subtf3, .{ .name = "__subtf3", .linkage = linkage });

    @export(@import("compiler_rt/mulXf3.zig").__mulsf3, .{ .name = "__mulsf3", .linkage = linkage });
    @export(@import("compiler_rt/mulXf3.zig").__muldf3, .{ .name = "__muldf3", .linkage = linkage });
    @export(@import("compiler_rt/mulXf3.zig").__multf3, .{ .name = "__multf3", .linkage = linkage });

    @export(@import("compiler_rt/divsf3.zig").__divsf3, .{ .name = "__divsf3", .linkage = linkage });
    @export(@import("compiler_rt/divdf3.zig").__divdf3, .{ .name = "__divdf3", .linkage = linkage });
    @export(@import("compiler_rt/divtf3.zig").__divtf3, .{ .name = "__divtf3", .linkage = linkage });

    @export(@import("compiler_rt/shift.zig").__ashldi3, .{ .name = "__ashldi3", .linkage = linkage });
    @export(@import("compiler_rt/shift.zig").__ashlti3, .{ .name = "__ashlti3", .linkage = linkage });
    @export(@import("compiler_rt/shift.zig").__ashrdi3, .{ .name = "__ashrdi3", .linkage = linkage });
    @export(@import("compiler_rt/shift.zig").__ashrti3, .{ .name = "__ashrti3", .linkage = linkage });
    @export(@import("compiler_rt/shift.zig").__lshrdi3, .{ .name = "__lshrdi3", .linkage = linkage });
    @export(@import("compiler_rt/shift.zig").__lshrti3, .{ .name = "__lshrti3", .linkage = linkage });

    @export(@import("compiler_rt/floatsiXf.zig").__floatsidf, .{ .name = "__floatsidf", .linkage = linkage });
    @export(@import("compiler_rt/floatsiXf.zig").__floatsisf, .{ .name = "__floatsisf", .linkage = linkage });
    @export(@import("compiler_rt/floatdidf.zig").__floatdidf, .{ .name = "__floatdidf", .linkage = linkage });
    @export(@import("compiler_rt/floatsiXf.zig").__floatsitf, .{ .name = "__floatsitf", .linkage = linkage });

    @export(@import("compiler_rt/floatunsisf.zig").__floatunsisf, .{ .name = "__floatunsisf", .linkage = linkage });
    @export(@import("compiler_rt/floatundisf.zig").__floatundisf, .{ .name = "__floatundisf", .linkage = linkage });
    @export(@import("compiler_rt/floatunsidf.zig").__floatunsidf, .{ .name = "__floatunsidf", .linkage = linkage });
    @export(@import("compiler_rt/floatundidf.zig").__floatundidf, .{ .name = "__floatundidf", .linkage = linkage });

    @export(@import("compiler_rt/floatditf.zig").__floatditf, .{ .name = "__floatditf", .linkage = linkage });
    @export(@import("compiler_rt/floattitf.zig").__floattitf, .{ .name = "__floattitf", .linkage = linkage });
    @export(@import("compiler_rt/floattidf.zig").__floattidf, .{ .name = "__floattidf", .linkage = linkage });
    @export(@import("compiler_rt/floatXisf.zig").__floattisf, .{ .name = "__floattisf", .linkage = linkage });
    @export(@import("compiler_rt/floatXisf.zig").__floatdisf, .{ .name = "__floatdisf", .linkage = linkage });

    @export(@import("compiler_rt/floatunditf.zig").__floatunditf, .{ .name = "__floatunditf", .linkage = linkage });
    @export(@import("compiler_rt/floatunsitf.zig").__floatunsitf, .{ .name = "__floatunsitf", .linkage = linkage });

    @export(@import("compiler_rt/floatuntitf.zig").__floatuntitf, .{ .name = "__floatuntitf", .linkage = linkage });
    @export(@import("compiler_rt/floatuntidf.zig").__floatuntidf, .{ .name = "__floatuntidf", .linkage = linkage });
    @export(@import("compiler_rt/floatuntisf.zig").__floatuntisf, .{ .name = "__floatuntisf", .linkage = linkage });

    @export(@import("compiler_rt/extendXfYf2.zig").__extenddftf2, .{ .name = "__extenddftf2", .linkage = linkage });
    @export(@import("compiler_rt/extendXfYf2.zig").__extendsftf2, .{ .name = "__extendsftf2", .linkage = linkage });
    @export(@import("compiler_rt/extendXfYf2.zig").__extendhfsf2, .{ .name = "__extendhfsf2", .linkage = linkage });

    @export(@import("compiler_rt/truncXfYf2.zig").__truncsfhf2, .{ .name = "__truncsfhf2", .linkage = linkage });
    @export(@import("compiler_rt/truncXfYf2.zig").__truncdfhf2, .{ .name = "__truncdfhf2", .linkage = linkage });
    @export(@import("compiler_rt/truncXfYf2.zig").__trunctfdf2, .{ .name = "__trunctfdf2", .linkage = linkage });
    @export(@import("compiler_rt/truncXfYf2.zig").__trunctfsf2, .{ .name = "__trunctfsf2", .linkage = linkage });

    @export(@import("compiler_rt/truncXfYf2.zig").__truncdfsf2, .{ .name = "__truncdfsf2", .linkage = linkage });

    @export(@import("compiler_rt/extendXfYf2.zig").__extendsfdf2, .{ .name = "__extendsfdf2", .linkage = linkage });

    @export(@import("compiler_rt/fixunssfsi.zig").__fixunssfsi, .{ .name = "__fixunssfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixunssfdi.zig").__fixunssfdi, .{ .name = "__fixunssfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixunssfti.zig").__fixunssfti, .{ .name = "__fixunssfti", .linkage = linkage });

    @export(@import("compiler_rt/fixunsdfsi.zig").__fixunsdfsi, .{ .name = "__fixunsdfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixunsdfdi.zig").__fixunsdfdi, .{ .name = "__fixunsdfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixunsdfti.zig").__fixunsdfti, .{ .name = "__fixunsdfti", .linkage = linkage });

    @export(@import("compiler_rt/fixunstfsi.zig").__fixunstfsi, .{ .name = "__fixunstfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixunstfdi.zig").__fixunstfdi, .{ .name = "__fixunstfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixunstfti.zig").__fixunstfti, .{ .name = "__fixunstfti", .linkage = linkage });

    @export(@import("compiler_rt/fixdfdi.zig").__fixdfdi, .{ .name = "__fixdfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixdfsi.zig").__fixdfsi, .{ .name = "__fixdfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixdfti.zig").__fixdfti, .{ .name = "__fixdfti", .linkage = linkage });
    @export(@import("compiler_rt/fixsfdi.zig").__fixsfdi, .{ .name = "__fixsfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixsfsi.zig").__fixsfsi, .{ .name = "__fixsfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixsfti.zig").__fixsfti, .{ .name = "__fixsfti", .linkage = linkage });
    @export(@import("compiler_rt/fixtfdi.zig").__fixtfdi, .{ .name = "__fixtfdi", .linkage = linkage });
    @export(@import("compiler_rt/fixtfsi.zig").__fixtfsi, .{ .name = "__fixtfsi", .linkage = linkage });
    @export(@import("compiler_rt/fixtfti.zig").__fixtfti, .{ .name = "__fixtfti", .linkage = linkage });

    @export(@import("compiler_rt/int.zig").__udivmoddi4, .{ .name = "__udivmoddi4", .linkage = linkage });
    @export(@import("compiler_rt/popcountdi2.zig").__popcountdi2, .{ .name = "__popcountdi2", .linkage = linkage });

    @export(@import("compiler_rt/int.zig").__mulsi3, .{ .name = "__mulsi3", .linkage = linkage });
    @export(@import("compiler_rt/muldi3.zig").__muldi3, .{ .name = "__muldi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__divmoddi4, .{ .name = "__divmoddi4", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__divsi3, .{ .name = "__divsi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__divdi3, .{ .name = "__divdi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__udivsi3, .{ .name = "__udivsi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__udivdi3, .{ .name = "__udivdi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__modsi3, .{ .name = "__modsi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__moddi3, .{ .name = "__moddi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__umodsi3, .{ .name = "__umodsi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__umoddi3, .{ .name = "__umoddi3", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__divmodsi4, .{ .name = "__divmodsi4", .linkage = linkage });
    @export(@import("compiler_rt/int.zig").__udivmodsi4, .{ .name = "__udivmodsi4", .linkage = linkage });

    @export(@import("compiler_rt/negXf2.zig").__negsf2, .{ .name = "__negsf2", .linkage = linkage });
    @export(@import("compiler_rt/negXf2.zig").__negdf2, .{ .name = "__negdf2", .linkage = linkage });

    @export(@import("compiler_rt/clzsi2.zig").__clzsi2, .{ .name = "__clzsi2", .linkage = linkage });

    if (builtin.link_libc and builtin.os.tag == .openbsd) {
        @export(@import("compiler_rt/emutls.zig").__emutls_get_address, .{ .name = "__emutls_get_address", .linkage = linkage });
    }

    if ((builtin.arch.isARM() or builtin.arch.isThumb()) and !is_test) {
        @export(@import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr0, .{ .name = "__aeabi_unwind_cpp_pr0", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr1, .{ .name = "__aeabi_unwind_cpp_pr1", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr2, .{ .name = "__aeabi_unwind_cpp_pr2", .linkage = linkage });

        @export(@import("compiler_rt/muldi3.zig").__muldi3, .{ .name = "__aeabi_lmul", .linkage = linkage });

        @export(@import("compiler_rt/arm.zig").__aeabi_ldivmod, .{ .name = "__aeabi_ldivmod", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_uldivmod, .{ .name = "__aeabi_uldivmod", .linkage = linkage });

        @export(@import("compiler_rt/int.zig").__divsi3, .{ .name = "__aeabi_idiv", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_idivmod, .{ .name = "__aeabi_idivmod", .linkage = linkage });
        @export(@import("compiler_rt/int.zig").__udivsi3, .{ .name = "__aeabi_uidiv", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_uidivmod, .{ .name = "__aeabi_uidivmod", .linkage = linkage });

        @export(@import("compiler_rt/arm.zig").__aeabi_memcpy, .{ .name = "__aeabi_memcpy", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memcpy, .{ .name = "__aeabi_memcpy4", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memcpy, .{ .name = "__aeabi_memcpy8", .linkage = linkage });

        @export(@import("compiler_rt/arm.zig").__aeabi_memmove, .{ .name = "__aeabi_memmove", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memmove, .{ .name = "__aeabi_memmove4", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memmove, .{ .name = "__aeabi_memmove8", .linkage = linkage });

        @export(@import("compiler_rt/arm.zig").__aeabi_memset, .{ .name = "__aeabi_memset", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memset, .{ .name = "__aeabi_memset4", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memset, .{ .name = "__aeabi_memset8", .linkage = linkage });

        @export(@import("compiler_rt/arm.zig").__aeabi_memclr, .{ .name = "__aeabi_memclr", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memclr, .{ .name = "__aeabi_memclr4", .linkage = linkage });
        @export(@import("compiler_rt/arm.zig").__aeabi_memclr, .{ .name = "__aeabi_memclr8", .linkage = linkage });

        if (builtin.os.tag == .linux) {
            @export(@import("compiler_rt/arm.zig").__aeabi_read_tp, .{ .name = "__aeabi_read_tp", .linkage = linkage });
        }

        @export(@import("compiler_rt/extendXfYf2.zig").__aeabi_f2d, .{ .name = "__aeabi_f2d", .linkage = linkage });
        @export(@import("compiler_rt/floatsiXf.zig").__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = linkage });
        @export(@import("compiler_rt/floatdidf.zig").__aeabi_l2d, .{ .name = "__aeabi_l2d", .linkage = linkage });
        @export(@import("compiler_rt/floatXisf.zig").__aeabi_l2f, .{ .name = "__aeabi_l2f", .linkage = linkage });
        @export(@import("compiler_rt/floatunsidf.zig").__aeabi_ui2d, .{ .name = "__aeabi_ui2d", .linkage = linkage });
        @export(@import("compiler_rt/floatundidf.zig").__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = linkage });
        @export(@import("compiler_rt/floatunsisf.zig").__aeabi_ui2f, .{ .name = "__aeabi_ui2f", .linkage = linkage });
        @export(@import("compiler_rt/floatundisf.zig").__aeabi_ul2f, .{ .name = "__aeabi_ul2f", .linkage = linkage });

        @export(@import("compiler_rt/negXf2.zig").__aeabi_fneg, .{ .name = "__aeabi_fneg", .linkage = linkage });
        @export(@import("compiler_rt/negXf2.zig").__aeabi_dneg, .{ .name = "__aeabi_dneg", .linkage = linkage });

        @export(@import("compiler_rt/mulXf3.zig").__aeabi_fmul, .{ .name = "__aeabi_fmul", .linkage = linkage });
        @export(@import("compiler_rt/mulXf3.zig").__aeabi_dmul, .{ .name = "__aeabi_dmul", .linkage = linkage });

        @export(@import("compiler_rt/truncXfYf2.zig").__aeabi_d2h, .{ .name = "__aeabi_d2h", .linkage = linkage });

        @export(@import("compiler_rt/fixunssfdi.zig").__aeabi_f2ulz, .{ .name = "__aeabi_f2ulz", .linkage = linkage });
        @export(@import("compiler_rt/fixunsdfdi.zig").__aeabi_d2ulz, .{ .name = "__aeabi_d2ulz", .linkage = linkage });

        @export(@import("compiler_rt/fixsfdi.zig").__aeabi_f2lz, .{ .name = "__aeabi_f2lz", .linkage = linkage });
        @export(@import("compiler_rt/fixdfdi.zig").__aeabi_d2lz, .{ .name = "__aeabi_d2lz", .linkage = linkage });

        @export(@import("compiler_rt/fixunsdfsi.zig").__aeabi_d2uiz, .{ .name = "__aeabi_d2uiz", .linkage = linkage });

        @export(@import("compiler_rt/extendXfYf2.zig").__aeabi_h2f, .{ .name = "__aeabi_h2f", .linkage = linkage });
        @export(@import("compiler_rt/truncXfYf2.zig").__aeabi_f2h, .{ .name = "__aeabi_f2h", .linkage = linkage });

        @export(@import("compiler_rt/floatsiXf.zig").__aeabi_i2f, .{ .name = "__aeabi_i2f", .linkage = linkage });
        @export(@import("compiler_rt/truncXfYf2.zig").__aeabi_d2f, .{ .name = "__aeabi_d2f", .linkage = linkage });

        @export(@import("compiler_rt/addXf3.zig").__aeabi_fadd, .{ .name = "__aeabi_fadd", .linkage = linkage });
        @export(@import("compiler_rt/addXf3.zig").__aeabi_dadd, .{ .name = "__aeabi_dadd", .linkage = linkage });
        @export(@import("compiler_rt/addXf3.zig").__aeabi_fsub, .{ .name = "__aeabi_fsub", .linkage = linkage });
        @export(@import("compiler_rt/addXf3.zig").__aeabi_dsub, .{ .name = "__aeabi_dsub", .linkage = linkage });

        @export(@import("compiler_rt/fixunssfsi.zig").__aeabi_f2uiz, .{ .name = "__aeabi_f2uiz", .linkage = linkage });

        @export(@import("compiler_rt/fixsfsi.zig").__aeabi_f2iz, .{ .name = "__aeabi_f2iz", .linkage = linkage });
        @export(@import("compiler_rt/fixdfsi.zig").__aeabi_d2iz, .{ .name = "__aeabi_d2iz", .linkage = linkage });

        @export(@import("compiler_rt/divsf3.zig").__aeabi_fdiv, .{ .name = "__aeabi_fdiv", .linkage = linkage });
        @export(@import("compiler_rt/divdf3.zig").__aeabi_ddiv, .{ .name = "__aeabi_ddiv", .linkage = linkage });

        @export(@import("compiler_rt/shift.zig").__aeabi_llsl, .{ .name = "__aeabi_llsl", .linkage = linkage });
        @export(@import("compiler_rt/shift.zig").__aeabi_lasr, .{ .name = "__aeabi_lasr", .linkage = linkage });
        @export(@import("compiler_rt/shift.zig").__aeabi_llsr, .{ .name = "__aeabi_llsr", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmpeq, .{ .name = "__aeabi_fcmpeq", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmplt, .{ .name = "__aeabi_fcmplt", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmple, .{ .name = "__aeabi_fcmple", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmpge, .{ .name = "__aeabi_fcmpge", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmpgt, .{ .name = "__aeabi_fcmpgt", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_fcmpun, .{ .name = "__aeabi_fcmpun", .linkage = linkage });

        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmpeq, .{ .name = "__aeabi_dcmpeq", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmplt, .{ .name = "__aeabi_dcmplt", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmple, .{ .name = "__aeabi_dcmple", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmpge, .{ .name = "__aeabi_dcmpge", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmpgt, .{ .name = "__aeabi_dcmpgt", .linkage = linkage });
        @export(@import("compiler_rt/compareXf2.zig").__aeabi_dcmpun, .{ .name = "__aeabi_dcmpun", .linkage = linkage });
    }

    if (builtin.arch == .i386 and builtin.abi == .msvc) {
        // Don't let LLVM apply the stdcall name mangling on those MSVC builtins
        @export(@import("compiler_rt/aulldiv.zig")._alldiv, .{ .name = "\x01__alldiv", .linkage = strong_linkage });
        @export(@import("compiler_rt/aulldiv.zig")._aulldiv, .{ .name = "\x01__aulldiv", .linkage = strong_linkage });
        @export(@import("compiler_rt/aullrem.zig")._allrem, .{ .name = "\x01__allrem", .linkage = strong_linkage });
        @export(@import("compiler_rt/aullrem.zig")._aullrem, .{ .name = "\x01__aullrem", .linkage = strong_linkage });
    }

    if (builtin.arch.isSPARC()) {
        // SPARC systems use a different naming scheme
        @export(@import("compiler_rt/sparc.zig")._Qp_add, .{ .name = "_Qp_add", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_div, .{ .name = "_Qp_div", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_mul, .{ .name = "_Qp_mul", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_sub, .{ .name = "_Qp_sub", .linkage = linkage });

        @export(@import("compiler_rt/sparc.zig")._Qp_cmp, .{ .name = "_Qp_cmp", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_feq, .{ .name = "_Qp_feq", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_fne, .{ .name = "_Qp_fne", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_flt, .{ .name = "_Qp_flt", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_fle, .{ .name = "_Qp_fle", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_fgt, .{ .name = "_Qp_fgt", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_fge, .{ .name = "_Qp_fge", .linkage = linkage });

        @export(@import("compiler_rt/sparc.zig")._Qp_dtoq, .{ .name = "_Qp_dtoq", .linkage = linkage });
        @export(@import("compiler_rt/sparc.zig")._Qp_qtod, .{ .name = "_Qp_qtod", .linkage = linkage });
    }

    if (builtin.os.tag == .windows) {
        // Default stack-probe functions emitted by LLVM
        if (is_mingw) {
            @export(@import("compiler_rt/stack_probe.zig")._chkstk, .{ .name = "_alloca", .linkage = strong_linkage });
            @export(@import("compiler_rt/stack_probe.zig").___chkstk_ms, .{ .name = "___chkstk_ms", .linkage = strong_linkage });
        } else if (!builtin.link_libc) {
            // This symbols are otherwise exported by MSVCRT.lib
            @export(@import("compiler_rt/stack_probe.zig")._chkstk, .{ .name = "_chkstk", .linkage = strong_linkage });
            @export(@import("compiler_rt/stack_probe.zig").__chkstk, .{ .name = "__chkstk", .linkage = strong_linkage });
        }

        switch (builtin.arch) {
            .i386 => {
                @export(@import("compiler_rt/divti3.zig").__divti3, .{ .name = "__divti3", .linkage = linkage });
                @export(@import("compiler_rt/modti3.zig").__modti3, .{ .name = "__modti3", .linkage = linkage });
                @export(@import("compiler_rt/multi3.zig").__multi3, .{ .name = "__multi3", .linkage = linkage });
                @export(@import("compiler_rt/udivti3.zig").__udivti3, .{ .name = "__udivti3", .linkage = linkage });
                @export(@import("compiler_rt/udivmodti4.zig").__udivmodti4, .{ .name = "__udivmodti4", .linkage = linkage });
                @export(@import("compiler_rt/umodti3.zig").__umodti3, .{ .name = "__umodti3", .linkage = linkage });
            },
            .x86_64 => {
                // The "ti" functions must use Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                @export(@import("compiler_rt/divti3.zig").__divti3_windows_x86_64, .{ .name = "__divti3", .linkage = linkage });
                @export(@import("compiler_rt/modti3.zig").__modti3_windows_x86_64, .{ .name = "__modti3", .linkage = linkage });
                @export(@import("compiler_rt/multi3.zig").__multi3_windows_x86_64, .{ .name = "__multi3", .linkage = linkage });
                @export(@import("compiler_rt/udivti3.zig").__udivti3_windows_x86_64, .{ .name = "__udivti3", .linkage = linkage });
                @export(@import("compiler_rt/udivmodti4.zig").__udivmodti4_windows_x86_64, .{ .name = "__udivmodti4", .linkage = linkage });
                @export(@import("compiler_rt/umodti3.zig").__umodti3_windows_x86_64, .{ .name = "__umodti3", .linkage = linkage });
            },
            else => {},
        }
    } else {
        @export(@import("compiler_rt/divti3.zig").__divti3, .{ .name = "__divti3", .linkage = linkage });
        @export(@import("compiler_rt/modti3.zig").__modti3, .{ .name = "__modti3", .linkage = linkage });
        @export(@import("compiler_rt/multi3.zig").__multi3, .{ .name = "__multi3", .linkage = linkage });
        @export(@import("compiler_rt/udivti3.zig").__udivti3, .{ .name = "__udivti3", .linkage = linkage });
        @export(@import("compiler_rt/udivmodti4.zig").__udivmodti4, .{ .name = "__udivmodti4", .linkage = linkage });
        @export(@import("compiler_rt/umodti3.zig").__umodti3, .{ .name = "__umodti3", .linkage = linkage });
    }
    @export(@import("compiler_rt/muloti4.zig").__muloti4, .{ .name = "__muloti4", .linkage = linkage });
    @export(@import("compiler_rt/mulodi4.zig").__mulodi4, .{ .name = "__mulodi4", .linkage = linkage });
}

pub usingnamespace @import("compiler_rt/atomics.zig");

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    if (is_test) {
        std.debug.panic("{s}", .{msg});
    } else {
        unreachable;
    }
}
