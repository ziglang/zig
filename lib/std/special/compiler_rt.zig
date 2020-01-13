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
        .i386, .x86_64 => @export(@import("compiler_rt/stack_probe.zig").zig_probe_stack, .{ .name = "__zig_probe_stack", .linkage = linkage }),
        else => {},
    }

    @export(@import("compiler_rt/comparesf2.zig").__lesf2, .{ .name = "__lesf2", .linkage = linkage });
    @export(@import("compiler_rt/comparedf2.zig").__ledf2, .{ .name = "__ledf2", .linkage = linkage });
    @export(@import("compiler_rt/comparetf2.zig").__letf2, .{ .name = "__letf2", .linkage = linkage });

    @export(@import("compiler_rt/comparesf2.zig").__gesf2, .{ .name = "__gesf2", .linkage = linkage });
    @export(@import("compiler_rt/comparedf2.zig").__gedf2, .{ .name = "__gedf2", .linkage = linkage });
    @export(@import("compiler_rt/comparetf2.zig").__getf2, .{ .name = "__getf2", .linkage = linkage });

    if (!is_test) {
        @export(@import("compiler_rt/comparesf2.zig").__lesf2, .{ .name = "__cmpsf2", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__ledf2, .{ .name = "__cmpdf2", .linkage = linkage });
        @export(@import("compiler_rt/comparetf2.zig").__letf2, .{ .name = "__cmptf2", .linkage = linkage });

        @export(@import("compiler_rt/comparesf2.zig").__eqsf2, .{ .name = "__eqsf2", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__eqdf2, .{ .name = "__eqdf2", .linkage = linkage });
        @export(@import("compiler_rt/comparetf2.zig").__letf2, .{ .name = "__eqtf2", .linkage = linkage });

        @export(@import("compiler_rt/comparesf2.zig").__ltsf2, .{ .name = "__ltsf2", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__ltdf2, .{ .name = "__ltdf2", .linkage = linkage });
        @export(@import("compiler_rt/comparetf2.zig").__letf2, .{ .name = "__lttf2", .linkage = linkage });

        @export(@import("compiler_rt/comparesf2.zig").__nesf2, .{ .name = "__nesf2", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__nedf2, .{ .name = "__nedf2", .linkage = linkage });
        @export(@import("compiler_rt/comparetf2.zig").__letf2, .{ .name = "__netf2", .linkage = linkage });

        @export(@import("compiler_rt/comparesf2.zig").__gtsf2, .{ .name = "__gtsf2", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__gtdf2, .{ .name = "__gtdf2", .linkage = linkage });
        @export(@import("compiler_rt/comparetf2.zig").__getf2, .{ .name = "__gttf2", .linkage = linkage });

        @export(@import("compiler_rt/extendXfYf2.zig").__extendhfsf2, .{ .name = "__gnu_h2f_ieee", .linkage = linkage });
        @export(@import("compiler_rt/truncXfYf2.zig").__truncsfhf2, .{ .name = "__gnu_f2h_ieee", .linkage = linkage });
    }

    @export(@import("compiler_rt/comparesf2.zig").__unordsf2, .{ .name = "__unordsf2", .linkage = linkage });
    @export(@import("compiler_rt/comparedf2.zig").__unorddf2, .{ .name = "__unorddf2", .linkage = linkage });
    @export(@import("compiler_rt/comparetf2.zig").__unordtf2, .{ .name = "__unordtf2", .linkage = linkage });

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

    @export(@import("compiler_rt/ashlti3.zig").__ashlti3, .{ .name = "__ashlti3", .linkage = linkage });
    @export(@import("compiler_rt/lshrti3.zig").__lshrti3, .{ .name = "__lshrti3", .linkage = linkage });
    @export(@import("compiler_rt/ashrti3.zig").__ashrti3, .{ .name = "__ashrti3", .linkage = linkage });

    @export(@import("compiler_rt/floatsiXf.zig").__floatsidf, .{ .name = "__floatsidf", .linkage = linkage });
    @export(@import("compiler_rt/floatsiXf.zig").__floatsisf, .{ .name = "__floatsisf", .linkage = linkage });
    @export(@import("compiler_rt/floatdidf.zig").__floatdidf, .{ .name = "__floatdidf", .linkage = linkage });
    @export(@import("compiler_rt/floatsiXf.zig").__floatsitf, .{ .name = "__floatsitf", .linkage = linkage });

    @export(@import("compiler_rt/floatunsisf.zig").__floatunsisf, .{ .name = "__floatunsisf", .linkage = linkage });
    @export(@import("compiler_rt/floatundisf.zig").__floatundisf, .{ .name = "__floatundisf", .linkage = linkage });
    @export(@import("compiler_rt/floatunsidf.zig").__floatunsidf, .{ .name = "__floatunsidf", .linkage = linkage });
    @export(@import("compiler_rt/floatundidf.zig").__floatundidf, .{ .name = "__floatundidf", .linkage = linkage });

    @export(@import("compiler_rt/floattitf.zig").__floattitf, .{ .name = "__floattitf", .linkage = linkage });
    @export(@import("compiler_rt/floattidf.zig").__floattidf, .{ .name = "__floattidf", .linkage = linkage });
    @export(@import("compiler_rt/floattisf.zig").__floattisf, .{ .name = "__floattisf", .linkage = linkage });

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

    @export(@import("compiler_rt/udivmoddi4.zig").__udivmoddi4, .{ .name = "__udivmoddi4", .linkage = linkage });
    @export(@import("compiler_rt/popcountdi2.zig").__popcountdi2, .{ .name = "__popcountdi2", .linkage = linkage });

    @export(@import("compiler_rt/muldi3.zig").__muldi3, .{ .name = "__muldi3", .linkage = linkage });
    @export(__divmoddi4, .{ .name = "__divmoddi4", .linkage = linkage });
    @export(__divsi3, .{ .name = "__divsi3", .linkage = linkage });
    @export(__divdi3, .{ .name = "__divdi3", .linkage = linkage });
    @export(__udivsi3, .{ .name = "__udivsi3", .linkage = linkage });
    @export(__udivdi3, .{ .name = "__udivdi3", .linkage = linkage });
    @export(__modsi3, .{ .name = "__modsi3", .linkage = linkage });
    @export(__moddi3, .{ .name = "__moddi3", .linkage = linkage });
    @export(__umodsi3, .{ .name = "__umodsi3", .linkage = linkage });
    @export(__umoddi3, .{ .name = "__umoddi3", .linkage = linkage });
    @export(__divmodsi4, .{ .name = "__divmodsi4", .linkage = linkage });
    @export(__udivmodsi4, .{ .name = "__udivmodsi4", .linkage = linkage });

    @export(@import("compiler_rt/negXf2.zig").__negsf2, .{ .name = "__negsf2", .linkage = linkage });
    @export(@import("compiler_rt/negXf2.zig").__negdf2, .{ .name = "__negdf2", .linkage = linkage });

    if (is_arm_arch and !is_arm_64 and !is_test) {
        @export(__aeabi_unwind_cpp_pr0, .{ .name = "__aeabi_unwind_cpp_pr0", .linkage = strong_linkage });
        @export(__aeabi_unwind_cpp_pr1, .{ .name = "__aeabi_unwind_cpp_pr1", .linkage = linkage });
        @export(__aeabi_unwind_cpp_pr2, .{ .name = "__aeabi_unwind_cpp_pr2", .linkage = linkage });

        @export(@import("compiler_rt/muldi3.zig").__muldi3, .{ .name = "__aeabi_lmul", .linkage = linkage });

        @export(__aeabi_ldivmod, .{ .name = "__aeabi_ldivmod", .linkage = linkage });
        @export(__aeabi_uldivmod, .{ .name = "__aeabi_uldivmod", .linkage = linkage });

        @export(__divsi3, .{ .name = "__aeabi_idiv", .linkage = linkage });
        @export(__aeabi_idivmod, .{ .name = "__aeabi_idivmod", .linkage = linkage });
        @export(__udivsi3, .{ .name = "__aeabi_uidiv", .linkage = linkage });
        @export(__aeabi_uidivmod, .{ .name = "__aeabi_uidivmod", .linkage = linkage });

        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy", .linkage = linkage });
        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy4", .linkage = linkage });
        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy8", .linkage = linkage });

        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove", .linkage = linkage });
        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove4", .linkage = linkage });
        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove8", .linkage = linkage });

        @export(__aeabi_memset, .{ .name = "__aeabi_memset", .linkage = linkage });
        @export(__aeabi_memset, .{ .name = "__aeabi_memset4", .linkage = linkage });
        @export(__aeabi_memset, .{ .name = "__aeabi_memset8", .linkage = linkage });

        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr", .linkage = linkage });
        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr4", .linkage = linkage });
        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr8", .linkage = linkage });

        @export(__aeabi_memcmp, .{ .name = "__aeabi_memcmp", .linkage = linkage });
        @export(__aeabi_memcmp, .{ .name = "__aeabi_memcmp4", .linkage = linkage });
        @export(__aeabi_memcmp, .{ .name = "__aeabi_memcmp8", .linkage = linkage });

        @export(@import("compiler_rt/extendXfYf2.zig").__aeabi_f2d, .{ .name = "__aeabi_f2d", .linkage = linkage });
        @export(@import("compiler_rt/floatsiXf.zig").__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = linkage });
        @export(@import("compiler_rt/floatdidf.zig").__aeabi_l2d, .{ .name = "__aeabi_l2d", .linkage = linkage });
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

        @export(@import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpeq, .{ .name = "__aeabi_fcmpeq", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmplt, .{ .name = "__aeabi_fcmplt", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmple, .{ .name = "__aeabi_fcmple", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpge, .{ .name = "__aeabi_fcmpge", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_fcmp.zig").__aeabi_fcmpgt, .{ .name = "__aeabi_fcmpgt", .linkage = linkage });
        @export(@import("compiler_rt/comparesf2.zig").__aeabi_fcmpun, .{ .name = "__aeabi_fcmpun", .linkage = linkage });

        @export(@import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpeq, .{ .name = "__aeabi_dcmpeq", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmplt, .{ .name = "__aeabi_dcmplt", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmple, .{ .name = "__aeabi_dcmple", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpge, .{ .name = "__aeabi_dcmpge", .linkage = linkage });
        @export(@import("compiler_rt/arm/aeabi_dcmp.zig").__aeabi_dcmpgt, .{ .name = "__aeabi_dcmpgt", .linkage = linkage });
        @export(@import("compiler_rt/comparedf2.zig").__aeabi_dcmpun, .{ .name = "__aeabi_dcmpun", .linkage = linkage });
    }
    if (builtin.os == .windows) {
        // Default stack-probe functions emitted by LLVM
        if (is_mingw) {
            @export(@import("compiler_rt/stack_probe.zig")._chkstk, .{ .name = "_alloca", .linkage = strong_linkage });
            @export(@import("compiler_rt/stack_probe.zig").___chkstk_ms, .{ .name = "___chkstk_ms", .linkage = strong_linkage });
        } else if (!builtin.link_libc) {
            // This symbols are otherwise exported by MSVCRT.lib
            @export(@import("compiler_rt/stack_probe.zig")._chkstk, .{ .name = "_chkstk", .linkage = strong_linkage });
            @export(@import("compiler_rt/stack_probe.zig").__chkstk, .{ .name = "__chkstk", .linkage = strong_linkage });
        }

        if (is_mingw) {
            @export(__stack_chk_fail, .{ .name = "__stack_chk_fail", .linkage = strong_linkage });
            @export(__stack_chk_guard, .{ .name = "__stack_chk_guard", .linkage = strong_linkage });
        }

        switch (builtin.arch) {
            .i386 => {
                // Don't let LLVM apply the stdcall name mangling on those MSVC
                // builtin functions
                @export(@import("compiler_rt/aulldiv.zig")._alldiv, .{ .name = "\x01__alldiv", .linkage = strong_linkage });
                @export(@import("compiler_rt/aulldiv.zig")._aulldiv, .{ .name = "\x01__aulldiv", .linkage = strong_linkage });
                @export(@import("compiler_rt/aullrem.zig")._allrem, .{ .name = "\x01__allrem", .linkage = strong_linkage });
                @export(@import("compiler_rt/aullrem.zig")._aullrem, .{ .name = "\x01__aullrem", .linkage = strong_linkage });

                @export(@import("compiler_rt/divti3.zig").__divti3, .{ .name = "__divti3", .linkage = linkage });
                @export(@import("compiler_rt/modti3.zig").__modti3, .{ .name = "__modti3", .linkage = linkage });
                @export(@import("compiler_rt/multi3.zig").__multi3, .{ .name = "__multi3", .linkage = linkage });
                @export(@import("compiler_rt/udivti3.zig").__udivti3, .{ .name = "__udivti3", .linkage = linkage });
                @export(@import("compiler_rt/udivmodti4.zig").__udivmodti4, .{ .name = "__udivmodti4", .linkage = linkage });
                @export(@import("compiler_rt/umodti3.zig").__umodti3, .{ .name = "__umodti3", .linkage = linkage });
            },
            .x86_64 => {
                // The "ti" functions must use @Vector(2, u64) parameter types to adhere to the ABI
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
        if (builtin.glibc_version != null) {
            @export(__stack_chk_guard, .{ .name = "__stack_chk_guard", .linkage = linkage });
        }
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

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const __udivmoddi4 = @import("compiler_rt/udivmoddi4.zig").__udivmoddi4;

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    if (is_test) {
        std.debug.panic("{}", .{msg});
    } else {
        unreachable;
    }
}

fn __stack_chk_fail() callconv(.C) noreturn {
    @panic("stack smashing detected");
}

extern var __stack_chk_guard: usize = blk: {
    var buf = [1]u8{0} ** @sizeOf(usize);
    buf[@sizeOf(usize) - 1] = 255;
    buf[@sizeOf(usize) - 2] = '\n';
    break :blk @bitCast(usize, buf);
};

fn __aeabi_unwind_cpp_pr0() callconv(.C) void {
    unreachable;
}
fn __aeabi_unwind_cpp_pr1() callconv(.C) void {
    unreachable;
}
fn __aeabi_unwind_cpp_pr2() callconv(.C) void {
    unreachable;
}

fn __divmoddi4(a: i64, b: i64, rem: *i64) callconv(.C) i64 {
    @setRuntimeSafety(is_test);

    const d = __divdi3(a, b);
    rem.* = a -% (d *% b);
    return d;
}

fn __divdi3(a: i64, b: i64) callconv(.C) i64 {
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

fn __moddi3(a: i64, b: i64) callconv(.C) i64 {
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

fn __udivdi3(a: u64, b: u64) callconv(.C) u64 {
    @setRuntimeSafety(is_test);
    return __udivmoddi4(a, b, null);
}

fn __umoddi3(a: u64, b: u64) callconv(.C) u64 {
    @setRuntimeSafety(is_test);

    var r: u64 = undefined;
    _ = __udivmoddi4(a, b, &r);
    return r;
}

fn __aeabi_uidivmod(n: u32, d: u32) callconv(.C) extern struct {
    q: u32,
    r: u32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uidivmod).ReturnType = undefined;
    result.q = __udivmodsi4(n, d, &result.r);
    return result;
}

fn __aeabi_uldivmod(n: u64, d: u64) callconv(.C) extern struct {
    q: u64,
    r: u64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uldivmod).ReturnType = undefined;
    result.q = __udivmoddi4(n, d, &result.r);
    return result;
}

fn __aeabi_idivmod(n: i32, d: i32) callconv(.C) extern struct {
    q: i32,
    r: i32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_idivmod).ReturnType = undefined;
    result.q = __divmodsi4(n, d, &result.r);
    return result;
}

fn __aeabi_ldivmod(n: i64, d: i64) callconv(.C) extern struct {
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

fn __aeabi_memcpy() callconv(.Naked) noreturn {
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

fn __aeabi_memmove() callconv(.Naked) noreturn {
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

fn __aeabi_memset() callconv(.Naked) noreturn {
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

fn __aeabi_memclr() callconv(.Naked) noreturn {
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

fn __aeabi_memcmp() callconv(.Naked) noreturn {
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

fn __divmodsi4(a: i32, b: i32, rem: *i32) callconv(.C) i32 {
    @setRuntimeSafety(is_test);

    const d = __divsi3(a, b);
    rem.* = a -% (d * b);
    return d;
}

fn __udivmodsi4(a: u32, b: u32, rem: *u32) callconv(.C) u32 {
    @setRuntimeSafety(is_test);

    const d = __udivsi3(a, b);
    rem.* = @bitCast(u32, @bitCast(i32, a) -% (@bitCast(i32, d) * @bitCast(i32, b)));
    return d;
}

fn __divsi3(n: i32, d: i32) callconv(.C) i32 {
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

fn __udivsi3(n: u32, d: u32) callconv(.C) u32 {
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

fn __modsi3(n: i32, d: i32) callconv(.C) i32 {
    @setRuntimeSafety(is_test);

    return n -% __divsi3(n, d) *% d;
}

fn __umodsi3(n: u32, d: u32) callconv(.C) u32 {
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
