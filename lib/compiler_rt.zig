const builtin = @import("builtin");

pub const panic = @import("compiler_rt/common.zig").panic;

comptime {
    // Integer routines
    _ = @import("compiler_rt/count0bits.zig");
    _ = @import("compiler_rt/parity.zig");
    _ = @import("compiler_rt/popcount.zig");
    _ = @import("compiler_rt/bswap.zig");
    _ = @import("compiler_rt/cmp.zig");

    _ = @import("compiler_rt/shift.zig");
    _ = @import("compiler_rt/negXi2.zig");
    _ = @import("compiler_rt/int.zig");
    _ = @import("compiler_rt/mulXi3.zig");
    _ = @import("compiler_rt/divti3.zig");
    _ = @import("compiler_rt/udivti3.zig");
    _ = @import("compiler_rt/modti3.zig");
    _ = @import("compiler_rt/umodti3.zig");

    _ = @import("compiler_rt/absv.zig");
    _ = @import("compiler_rt/absvsi2.zig");
    _ = @import("compiler_rt/absvdi2.zig");
    _ = @import("compiler_rt/absvti2.zig");
    _ = @import("compiler_rt/negv.zig");

    _ = @import("compiler_rt/addo.zig");
    _ = @import("compiler_rt/subo.zig");
    _ = @import("compiler_rt/mulo.zig");

    // Float routines
    // conversion
    _ = @import("compiler_rt/extendf.zig");
    _ = @import("compiler_rt/extendhfsf2.zig");
    _ = @import("compiler_rt/extendhfdf2.zig");
    _ = @import("compiler_rt/extendhftf2.zig");
    _ = @import("compiler_rt/extendhfxf2.zig");
    _ = @import("compiler_rt/extendsfdf2.zig");
    _ = @import("compiler_rt/extendsftf2.zig");
    _ = @import("compiler_rt/extendsfxf2.zig");
    _ = @import("compiler_rt/extenddftf2.zig");
    _ = @import("compiler_rt/extenddfxf2.zig");
    _ = @import("compiler_rt/extendxftf2.zig");

    _ = @import("compiler_rt/truncf.zig");
    _ = @import("compiler_rt/truncsfhf2.zig");
    _ = @import("compiler_rt/truncdfhf2.zig");
    _ = @import("compiler_rt/truncdfsf2.zig");
    _ = @import("compiler_rt/truncxfhf2.zig");
    _ = @import("compiler_rt/truncxfsf2.zig");
    _ = @import("compiler_rt/truncxfdf2.zig");
    _ = @import("compiler_rt/trunctfhf2.zig");
    _ = @import("compiler_rt/trunctfsf2.zig");
    _ = @import("compiler_rt/trunctfdf2.zig");
    _ = @import("compiler_rt/trunctfxf2.zig");

    _ = @import("compiler_rt/int_from_float.zig");
    _ = @import("compiler_rt/fixhfsi.zig");
    _ = @import("compiler_rt/fixhfdi.zig");
    _ = @import("compiler_rt/fixhfti.zig");
    _ = @import("compiler_rt/fixsfsi.zig");
    _ = @import("compiler_rt/fixsfdi.zig");
    _ = @import("compiler_rt/fixsfti.zig");
    _ = @import("compiler_rt/fixdfsi.zig");
    _ = @import("compiler_rt/fixdfdi.zig");
    _ = @import("compiler_rt/fixdfti.zig");
    _ = @import("compiler_rt/fixtfsi.zig");
    _ = @import("compiler_rt/fixtfdi.zig");
    _ = @import("compiler_rt/fixtfti.zig");
    _ = @import("compiler_rt/fixxfsi.zig");
    _ = @import("compiler_rt/fixxfdi.zig");
    _ = @import("compiler_rt/fixxfti.zig");
    _ = @import("compiler_rt/fixunshfsi.zig");
    _ = @import("compiler_rt/fixunshfdi.zig");
    _ = @import("compiler_rt/fixunshfti.zig");
    _ = @import("compiler_rt/fixunssfsi.zig");
    _ = @import("compiler_rt/fixunssfdi.zig");
    _ = @import("compiler_rt/fixunssfti.zig");
    _ = @import("compiler_rt/fixunsdfsi.zig");
    _ = @import("compiler_rt/fixunsdfdi.zig");
    _ = @import("compiler_rt/fixunsdfti.zig");
    _ = @import("compiler_rt/fixunstfsi.zig");
    _ = @import("compiler_rt/fixunstfdi.zig");
    _ = @import("compiler_rt/fixunstfti.zig");
    _ = @import("compiler_rt/fixunsxfsi.zig");
    _ = @import("compiler_rt/fixunsxfdi.zig");
    _ = @import("compiler_rt/fixunsxfti.zig");

    _ = @import("compiler_rt/float_from_int.zig");
    _ = @import("compiler_rt/floatsihf.zig");
    _ = @import("compiler_rt/floatsisf.zig");
    _ = @import("compiler_rt/floatsidf.zig");
    _ = @import("compiler_rt/floatsitf.zig");
    _ = @import("compiler_rt/floatsixf.zig");
    _ = @import("compiler_rt/floatdihf.zig");
    _ = @import("compiler_rt/floatdisf.zig");
    _ = @import("compiler_rt/floatdidf.zig");
    _ = @import("compiler_rt/floatditf.zig");
    _ = @import("compiler_rt/floatdixf.zig");
    _ = @import("compiler_rt/floattihf.zig");
    _ = @import("compiler_rt/floattisf.zig");
    _ = @import("compiler_rt/floattidf.zig");
    _ = @import("compiler_rt/floattitf.zig");
    _ = @import("compiler_rt/floattixf.zig");
    _ = @import("compiler_rt/floatundihf.zig");
    _ = @import("compiler_rt/floatundisf.zig");
    _ = @import("compiler_rt/floatundidf.zig");
    _ = @import("compiler_rt/floatunditf.zig");
    _ = @import("compiler_rt/floatundixf.zig");
    _ = @import("compiler_rt/floatunsihf.zig");
    _ = @import("compiler_rt/floatunsisf.zig");
    _ = @import("compiler_rt/floatunsidf.zig");
    _ = @import("compiler_rt/floatunsitf.zig");
    _ = @import("compiler_rt/floatunsixf.zig");
    _ = @import("compiler_rt/floatuntihf.zig");
    _ = @import("compiler_rt/floatuntisf.zig");
    _ = @import("compiler_rt/floatuntidf.zig");
    _ = @import("compiler_rt/floatuntitf.zig");
    _ = @import("compiler_rt/floatuntixf.zig");

    // comparison
    _ = @import("compiler_rt/comparef.zig");
    _ = @import("compiler_rt/cmphf2.zig");
    _ = @import("compiler_rt/cmpsf2.zig");
    _ = @import("compiler_rt/cmpdf2.zig");
    _ = @import("compiler_rt/cmptf2.zig");
    _ = @import("compiler_rt/cmpxf2.zig");
    _ = @import("compiler_rt/unordhf2.zig");
    _ = @import("compiler_rt/unordsf2.zig");
    _ = @import("compiler_rt/unorddf2.zig");
    _ = @import("compiler_rt/unordxf2.zig");
    _ = @import("compiler_rt/unordtf2.zig");
    _ = @import("compiler_rt/gehf2.zig");
    _ = @import("compiler_rt/gesf2.zig");
    _ = @import("compiler_rt/gedf2.zig");
    _ = @import("compiler_rt/gexf2.zig");
    _ = @import("compiler_rt/getf2.zig");

    // arithmetic
    _ = @import("compiler_rt/addf3.zig");
    _ = @import("compiler_rt/addhf3.zig");
    _ = @import("compiler_rt/addsf3.zig");
    _ = @import("compiler_rt/adddf3.zig");
    _ = @import("compiler_rt/addtf3.zig");
    _ = @import("compiler_rt/addxf3.zig");

    _ = @import("compiler_rt/subhf3.zig");
    _ = @import("compiler_rt/subsf3.zig");
    _ = @import("compiler_rt/subdf3.zig");
    _ = @import("compiler_rt/subtf3.zig");
    _ = @import("compiler_rt/subxf3.zig");

    _ = @import("compiler_rt/mulf3.zig");
    _ = @import("compiler_rt/mulhf3.zig");
    _ = @import("compiler_rt/mulsf3.zig");
    _ = @import("compiler_rt/muldf3.zig");
    _ = @import("compiler_rt/multf3.zig");
    _ = @import("compiler_rt/mulxf3.zig");

    _ = @import("compiler_rt/divhf3.zig");
    _ = @import("compiler_rt/divsf3.zig");
    _ = @import("compiler_rt/divdf3.zig");
    _ = @import("compiler_rt/divxf3.zig");
    _ = @import("compiler_rt/divtf3.zig");

    _ = @import("compiler_rt/neghf2.zig");
    _ = @import("compiler_rt/negsf2.zig");
    _ = @import("compiler_rt/negdf2.zig");
    _ = @import("compiler_rt/negtf2.zig");
    _ = @import("compiler_rt/negxf2.zig");

    // other
    _ = @import("compiler_rt/powiXf2.zig");
    _ = @import("compiler_rt/mulc3.zig");
    _ = @import("compiler_rt/mulhc3.zig");
    _ = @import("compiler_rt/mulsc3.zig");
    _ = @import("compiler_rt/muldc3.zig");
    _ = @import("compiler_rt/mulxc3.zig");
    _ = @import("compiler_rt/multc3.zig");

    _ = @import("compiler_rt/divc3.zig");
    _ = @import("compiler_rt/divhc3.zig");
    _ = @import("compiler_rt/divsc3.zig");
    _ = @import("compiler_rt/divdc3.zig");
    _ = @import("compiler_rt/divxc3.zig");
    _ = @import("compiler_rt/divtc3.zig");

    // Math routines. Alphabetically sorted.
    _ = @import("compiler_rt/ceil.zig");
    _ = @import("compiler_rt/cos.zig");
    _ = @import("compiler_rt/exp.zig");
    _ = @import("compiler_rt/exp2.zig");
    _ = @import("compiler_rt/fabs.zig");
    _ = @import("compiler_rt/floor.zig");
    _ = @import("compiler_rt/fma.zig");
    _ = @import("compiler_rt/fmax.zig");
    _ = @import("compiler_rt/fmin.zig");
    _ = @import("compiler_rt/fmod.zig");
    _ = @import("compiler_rt/log.zig");
    _ = @import("compiler_rt/log10.zig");
    _ = @import("compiler_rt/log2.zig");
    _ = @import("compiler_rt/round.zig");
    _ = @import("compiler_rt/sin.zig");
    _ = @import("compiler_rt/sincos.zig");
    _ = @import("compiler_rt/sqrt.zig");
    _ = @import("compiler_rt/tan.zig");
    _ = @import("compiler_rt/trunc.zig");

    // BigInt. Alphabetically sorted.
    _ = @import("compiler_rt/udivmodei4.zig");
    _ = @import("compiler_rt/udivmodti4.zig");

    // extra
    _ = @import("compiler_rt/os_version_check.zig");
    _ = @import("compiler_rt/emutls.zig");
    _ = @import("compiler_rt/arm.zig");
    _ = @import("compiler_rt/aulldiv.zig");
    _ = @import("compiler_rt/aullrem.zig");
    _ = @import("compiler_rt/clear_cache.zig");

    if (@import("builtin").object_format != .c) {
        _ = @import("compiler_rt/atomics.zig");
        _ = @import("compiler_rt/stack_probe.zig");

        // macOS has these functions inside libSystem.
        if (builtin.cpu.arch.isAARCH64() and !builtin.os.tag.isDarwin()) {
            _ = @import("compiler_rt/aarch64_outline_atomics.zig");
        }

        _ = @import("compiler_rt/memcpy.zig");
        _ = @import("compiler_rt/memset.zig");
        _ = @import("compiler_rt/memmove.zig");
        _ = @import("compiler_rt/memcmp.zig");
        _ = @import("compiler_rt/bcmp.zig");
    }
}
