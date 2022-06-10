const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const os_tag = builtin.os.tag;
const arch = builtin.cpu.arch;
const abi = builtin.abi;

const is_gnu = abi.isGnu();
const is_mingw = os_tag == .windows and is_gnu;
const is_darwin = std.Target.Os.Tag.isDarwin(os_tag);
const is_ppc = arch.isPPC() or arch.isPPC64();

const linkage = if (is_test)
    std.builtin.GlobalLinkage.Internal
else
    std.builtin.GlobalLinkage.Weak;

const strong_linkage = if (is_test)
    std.builtin.GlobalLinkage.Internal
else
    std.builtin.GlobalLinkage.Strong;

comptime {
    // These files do their own comptime exporting logic.
    _ = @import("compiler_rt/atomics.zig");
    if (builtin.zig_backend != .stage2_llvm) { // TODO
        _ = @import("compiler_rt/clear_cache.zig").clear_cache;
    }

    const __extenddftf2 = @import("compiler_rt/extendXfYf2.zig").__extenddftf2;
    @export(__extenddftf2, .{ .name = "__extenddftf2", .linkage = linkage });
    const __extendsftf2 = @import("compiler_rt/extendXfYf2.zig").__extendsftf2;
    @export(__extendsftf2, .{ .name = "__extendsftf2", .linkage = linkage });
    const __extendhfsf2 = @import("compiler_rt/extendXfYf2.zig").__extendhfsf2;
    @export(__extendhfsf2, .{ .name = "__extendhfsf2", .linkage = linkage });
    const __extendhftf2 = @import("compiler_rt/extendXfYf2.zig").__extendhftf2;
    @export(__extendhftf2, .{ .name = "__extendhftf2", .linkage = linkage });

    const __extendhfxf2 = @import("compiler_rt/extend_f80.zig").__extendhfxf2;
    @export(__extendhfxf2, .{ .name = "__extendhfxf2", .linkage = linkage });
    const __extendsfxf2 = @import("compiler_rt/extend_f80.zig").__extendsfxf2;
    @export(__extendsfxf2, .{ .name = "__extendsfxf2", .linkage = linkage });
    const __extenddfxf2 = @import("compiler_rt/extend_f80.zig").__extenddfxf2;
    @export(__extenddfxf2, .{ .name = "__extenddfxf2", .linkage = linkage });
    const __extendxftf2 = @import("compiler_rt/extend_f80.zig").__extendxftf2;
    @export(__extendxftf2, .{ .name = "__extendxftf2", .linkage = linkage });

    const __lesf2 = @import("compiler_rt/compareXf2.zig").__lesf2;
    @export(__lesf2, .{ .name = "__lesf2", .linkage = linkage });
    const __ledf2 = @import("compiler_rt/compareXf2.zig").__ledf2;
    @export(__ledf2, .{ .name = "__ledf2", .linkage = linkage });
    const __letf2 = @import("compiler_rt/compareXf2.zig").__letf2;
    @export(__letf2, .{ .name = "__letf2", .linkage = linkage });
    const __lexf2 = @import("compiler_rt/compareXf2.zig").__lexf2;
    @export(__lexf2, .{ .name = "__lexf2", .linkage = linkage });

    const __gesf2 = @import("compiler_rt/compareXf2.zig").__gesf2;
    @export(__gesf2, .{ .name = "__gesf2", .linkage = linkage });
    const __gedf2 = @import("compiler_rt/compareXf2.zig").__gedf2;
    @export(__gedf2, .{ .name = "__gedf2", .linkage = linkage });
    const __getf2 = @import("compiler_rt/compareXf2.zig").__getf2;
    @export(__getf2, .{ .name = "__getf2", .linkage = linkage });
    const __gexf2 = @import("compiler_rt/compareXf2.zig").__gexf2;
    @export(__gexf2, .{ .name = "__gexf2", .linkage = linkage });

    const __eqsf2 = @import("compiler_rt/compareXf2.zig").__eqsf2;
    @export(__eqsf2, .{ .name = "__eqsf2", .linkage = linkage });
    const __eqdf2 = @import("compiler_rt/compareXf2.zig").__eqdf2;
    @export(__eqdf2, .{ .name = "__eqdf2", .linkage = linkage });
    const __eqxf2 = @import("compiler_rt/compareXf2.zig").__eqxf2;
    @export(__eqxf2, .{ .name = "__eqxf2", .linkage = linkage });

    const __ltsf2 = @import("compiler_rt/compareXf2.zig").__ltsf2;
    @export(__ltsf2, .{ .name = "__ltsf2", .linkage = linkage });
    const __ltdf2 = @import("compiler_rt/compareXf2.zig").__ltdf2;
    @export(__ltdf2, .{ .name = "__ltdf2", .linkage = linkage });
    const __ltxf2 = @import("compiler_rt/compareXf2.zig").__ltxf2;
    @export(__ltxf2, .{ .name = "__ltxf2", .linkage = linkage });

    const __nesf2 = @import("compiler_rt/compareXf2.zig").__nesf2;
    @export(__nesf2, .{ .name = "__nesf2", .linkage = linkage });
    const __nedf2 = @import("compiler_rt/compareXf2.zig").__nedf2;
    @export(__nedf2, .{ .name = "__nedf2", .linkage = linkage });
    const __nexf2 = @import("compiler_rt/compareXf2.zig").__nexf2;
    @export(__nexf2, .{ .name = "__nexf2", .linkage = linkage });

    const __gtsf2 = @import("compiler_rt/compareXf2.zig").__gtsf2;
    @export(__gtsf2, .{ .name = "__gtsf2", .linkage = linkage });
    const __gtdf2 = @import("compiler_rt/compareXf2.zig").__gtdf2;
    @export(__gtdf2, .{ .name = "__gtdf2", .linkage = linkage });
    const __gtxf2 = @import("compiler_rt/compareXf2.zig").__gtxf2;
    @export(__gtxf2, .{ .name = "__gtxf2", .linkage = linkage });

    if (!is_test) {
        @export(__lesf2, .{ .name = "__cmpsf2", .linkage = linkage });
        @export(__ledf2, .{ .name = "__cmpdf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__cmptf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__eqtf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__lttf2", .linkage = linkage });
        @export(__getf2, .{ .name = "__gttf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__netf2", .linkage = linkage });
        @export(__extendhfsf2, .{ .name = "__gnu_h2f_ieee", .linkage = linkage });
    }

    if (builtin.os.tag == .windows) {
        // Default stack-probe functions emitted by LLVM
        if (is_mingw) {
            const _chkstk = @import("compiler_rt/stack_probe.zig")._chkstk;
            @export(_chkstk, .{ .name = "_alloca", .linkage = strong_linkage });
            const ___chkstk_ms = @import("compiler_rt/stack_probe.zig").___chkstk_ms;
            @export(___chkstk_ms, .{ .name = "___chkstk_ms", .linkage = strong_linkage });
        } else if (!builtin.link_libc) {
            // This symbols are otherwise exported by MSVCRT.lib
            const _chkstk = @import("compiler_rt/stack_probe.zig")._chkstk;
            @export(_chkstk, .{ .name = "_chkstk", .linkage = strong_linkage });
            const __chkstk = @import("compiler_rt/stack_probe.zig").__chkstk;
            @export(__chkstk, .{ .name = "__chkstk", .linkage = strong_linkage });
        }

        switch (arch) {
            .i386 => {
                const __divti3 = @import("compiler_rt/divti3.zig").__divti3;
                @export(__divti3, .{ .name = "__divti3", .linkage = linkage });
                const __modti3 = @import("compiler_rt/modti3.zig").__modti3;
                @export(__modti3, .{ .name = "__modti3", .linkage = linkage });
                const __multi3 = @import("compiler_rt/multi3.zig").__multi3;
                @export(__multi3, .{ .name = "__multi3", .linkage = linkage });
                const __udivti3 = @import("compiler_rt/udivti3.zig").__udivti3;
                @export(__udivti3, .{ .name = "__udivti3", .linkage = linkage });
                const __udivmodti4 = @import("compiler_rt/udivmodti4.zig").__udivmodti4;
                @export(__udivmodti4, .{ .name = "__udivmodti4", .linkage = linkage });
                const __umodti3 = @import("compiler_rt/umodti3.zig").__umodti3;
                @export(__umodti3, .{ .name = "__umodti3", .linkage = linkage });
            },
            .x86_64 => {
                // The "ti" functions must use Vector(2, u64) parameter types to adhere to the ABI
                // that LLVM expects compiler-rt to have.
                const __divti3_windows_x86_64 = @import("compiler_rt/divti3.zig").__divti3_windows_x86_64;
                @export(__divti3_windows_x86_64, .{ .name = "__divti3", .linkage = linkage });
                const __modti3_windows_x86_64 = @import("compiler_rt/modti3.zig").__modti3_windows_x86_64;
                @export(__modti3_windows_x86_64, .{ .name = "__modti3", .linkage = linkage });
                const __multi3_windows_x86_64 = @import("compiler_rt/multi3.zig").__multi3_windows_x86_64;
                @export(__multi3_windows_x86_64, .{ .name = "__multi3", .linkage = linkage });
                const __udivti3_windows_x86_64 = @import("compiler_rt/udivti3.zig").__udivti3_windows_x86_64;
                @export(__udivti3_windows_x86_64, .{ .name = "__udivti3", .linkage = linkage });
                const __udivmodti4_windows_x86_64 = @import("compiler_rt/udivmodti4.zig").__udivmodti4_windows_x86_64;
                @export(__udivmodti4_windows_x86_64, .{ .name = "__udivmodti4", .linkage = linkage });
                const __umodti3_windows_x86_64 = @import("compiler_rt/umodti3.zig").__umodti3_windows_x86_64;
                @export(__umodti3_windows_x86_64, .{ .name = "__umodti3", .linkage = linkage });
            },
            else => {},
        }
        if (arch.isAARCH64()) {
            const __chkstk = @import("compiler_rt/stack_probe.zig").__chkstk;
            @export(__chkstk, .{ .name = "__chkstk", .linkage = strong_linkage });
            const __divti3_windows = @import("compiler_rt/divti3.zig").__divti3;
            @export(__divti3_windows, .{ .name = "__divti3", .linkage = linkage });
            const __modti3 = @import("compiler_rt/modti3.zig").__modti3;
            @export(__modti3, .{ .name = "__modti3", .linkage = linkage });
            const __udivti3_windows = @import("compiler_rt/udivti3.zig").__udivti3;
            @export(__udivti3_windows, .{ .name = "__udivti3", .linkage = linkage });
            const __umodti3 = @import("compiler_rt/umodti3.zig").__umodti3;
            @export(__umodti3, .{ .name = "__umodti3", .linkage = linkage });
        }
    } else {
        const __divti3 = @import("compiler_rt/divti3.zig").__divti3;
        @export(__divti3, .{ .name = "__divti3", .linkage = linkage });
        const __modti3 = @import("compiler_rt/modti3.zig").__modti3;
        @export(__modti3, .{ .name = "__modti3", .linkage = linkage });
        const __multi3 = @import("compiler_rt/multi3.zig").__multi3;
        @export(__multi3, .{ .name = "__multi3", .linkage = linkage });
        const __udivti3 = @import("compiler_rt/udivti3.zig").__udivti3;
        @export(__udivti3, .{ .name = "__udivti3", .linkage = linkage });
        const __udivmodti4 = @import("compiler_rt/udivmodti4.zig").__udivmodti4;
        @export(__udivmodti4, .{ .name = "__udivmodti4", .linkage = linkage });
        const __umodti3 = @import("compiler_rt/umodti3.zig").__umodti3;
        @export(__umodti3, .{ .name = "__umodti3", .linkage = linkage });
    }

    const __truncdfhf2 = @import("compiler_rt/truncXfYf2.zig").__truncdfhf2;
    @export(__truncdfhf2, .{ .name = "__truncdfhf2", .linkage = linkage });
    const __trunctfhf2 = @import("compiler_rt/truncXfYf2.zig").__trunctfhf2;
    @export(__trunctfhf2, .{ .name = "__trunctfhf2", .linkage = linkage });
    const __trunctfdf2 = @import("compiler_rt/truncXfYf2.zig").__trunctfdf2;
    @export(__trunctfdf2, .{ .name = "__trunctfdf2", .linkage = linkage });
    const __trunctfsf2 = @import("compiler_rt/truncXfYf2.zig").__trunctfsf2;
    @export(__trunctfsf2, .{ .name = "__trunctfsf2", .linkage = linkage });

    const __truncdfsf2 = @import("compiler_rt/truncXfYf2.zig").__truncdfsf2;
    @export(__truncdfsf2, .{ .name = "__truncdfsf2", .linkage = linkage });

    const __truncxfhf2 = @import("compiler_rt/trunc_f80.zig").__truncxfhf2;
    @export(__truncxfhf2, .{ .name = "__truncxfhf2", .linkage = linkage });
    const __truncxfsf2 = @import("compiler_rt/trunc_f80.zig").__truncxfsf2;
    @export(__truncxfsf2, .{ .name = "__truncxfsf2", .linkage = linkage });
    const __truncxfdf2 = @import("compiler_rt/trunc_f80.zig").__truncxfdf2;
    @export(__truncxfdf2, .{ .name = "__truncxfdf2", .linkage = linkage });
    const __trunctfxf2 = @import("compiler_rt/trunc_f80.zig").__trunctfxf2;
    @export(__trunctfxf2, .{ .name = "__trunctfxf2", .linkage = linkage });

    switch (arch) {
        .i386,
        .x86_64,
        => {
            const zig_probe_stack = @import("compiler_rt/stack_probe.zig").zig_probe_stack;
            @export(zig_probe_stack, .{
                .name = "__zig_probe_stack",
                .linkage = linkage,
            });
        },
        else => {},
    }

    const __unordsf2 = @import("compiler_rt/compareXf2.zig").__unordsf2;
    @export(__unordsf2, .{ .name = "__unordsf2", .linkage = linkage });
    const __unorddf2 = @import("compiler_rt/compareXf2.zig").__unorddf2;
    @export(__unorddf2, .{ .name = "__unorddf2", .linkage = linkage });
    const __unordtf2 = @import("compiler_rt/compareXf2.zig").__unordtf2;
    @export(__unordtf2, .{ .name = "__unordtf2", .linkage = linkage });

    const __addsf3 = @import("compiler_rt/addXf3.zig").__addsf3;
    @export(__addsf3, .{ .name = "__addsf3", .linkage = linkage });
    const __adddf3 = @import("compiler_rt/addXf3.zig").__adddf3;
    @export(__adddf3, .{ .name = "__adddf3", .linkage = linkage });
    const __addxf3 = @import("compiler_rt/addXf3.zig").__addxf3;
    @export(__addxf3, .{ .name = "__addxf3", .linkage = linkage });
    const __addtf3 = @import("compiler_rt/addXf3.zig").__addtf3;
    @export(__addtf3, .{ .name = "__addtf3", .linkage = linkage });

    const __subsf3 = @import("compiler_rt/addXf3.zig").__subsf3;
    @export(__subsf3, .{ .name = "__subsf3", .linkage = linkage });
    const __subdf3 = @import("compiler_rt/addXf3.zig").__subdf3;
    @export(__subdf3, .{ .name = "__subdf3", .linkage = linkage });
    const __subxf3 = @import("compiler_rt/addXf3.zig").__subxf3;
    @export(__subxf3, .{ .name = "__subxf3", .linkage = linkage });
    const __subtf3 = @import("compiler_rt/addXf3.zig").__subtf3;
    @export(__subtf3, .{ .name = "__subtf3", .linkage = linkage });

    const __mulsf3 = @import("compiler_rt/mulXf3.zig").__mulsf3;
    @export(__mulsf3, .{ .name = "__mulsf3", .linkage = linkage });
    const __muldf3 = @import("compiler_rt/mulXf3.zig").__muldf3;
    @export(__muldf3, .{ .name = "__muldf3", .linkage = linkage });
    const __mulxf3 = @import("compiler_rt/mulXf3.zig").__mulxf3;
    @export(__mulxf3, .{ .name = "__mulxf3", .linkage = linkage });
    const __multf3 = @import("compiler_rt/mulXf3.zig").__multf3;
    @export(__multf3, .{ .name = "__multf3", .linkage = linkage });

    const __divsf3 = @import("compiler_rt/divsf3.zig").__divsf3;
    @export(__divsf3, .{ .name = "__divsf3", .linkage = linkage });
    const __divdf3 = @import("compiler_rt/divdf3.zig").__divdf3;
    @export(__divdf3, .{ .name = "__divdf3", .linkage = linkage });
    const __divxf3 = @import("compiler_rt/divxf3.zig").__divxf3;
    @export(__divxf3, .{ .name = "__divxf3", .linkage = linkage });
    const __divtf3 = @import("compiler_rt/divtf3.zig").__divtf3;
    @export(__divtf3, .{ .name = "__divtf3", .linkage = linkage });

    // Integer Bit operations
    const __clzsi2 = @import("compiler_rt/count0bits.zig").__clzsi2;
    @export(__clzsi2, .{ .name = "__clzsi2", .linkage = linkage });
    const __clzdi2 = @import("compiler_rt/count0bits.zig").__clzdi2;
    @export(__clzdi2, .{ .name = "__clzdi2", .linkage = linkage });
    const __clzti2 = @import("compiler_rt/count0bits.zig").__clzti2;
    @export(__clzti2, .{ .name = "__clzti2", .linkage = linkage });
    const __ctzsi2 = @import("compiler_rt/count0bits.zig").__ctzsi2;
    @export(__ctzsi2, .{ .name = "__ctzsi2", .linkage = linkage });
    const __ctzdi2 = @import("compiler_rt/count0bits.zig").__ctzdi2;
    @export(__ctzdi2, .{ .name = "__ctzdi2", .linkage = linkage });
    const __ctzti2 = @import("compiler_rt/count0bits.zig").__ctzti2;
    @export(__ctzti2, .{ .name = "__ctzti2", .linkage = linkage });
    const __ffssi2 = @import("compiler_rt/count0bits.zig").__ffssi2;
    @export(__ffssi2, .{ .name = "__ffssi2", .linkage = linkage });
    const __ffsdi2 = @import("compiler_rt/count0bits.zig").__ffsdi2;
    @export(__ffsdi2, .{ .name = "__ffsdi2", .linkage = linkage });
    const __ffsti2 = @import("compiler_rt/count0bits.zig").__ffsti2;
    @export(__ffsti2, .{ .name = "__ffsti2", .linkage = linkage });
    const __paritysi2 = @import("compiler_rt/parity.zig").__paritysi2;
    @export(__paritysi2, .{ .name = "__paritysi2", .linkage = linkage });
    const __paritydi2 = @import("compiler_rt/parity.zig").__paritydi2;
    @export(__paritydi2, .{ .name = "__paritydi2", .linkage = linkage });
    const __parityti2 = @import("compiler_rt/parity.zig").__parityti2;
    @export(__parityti2, .{ .name = "__parityti2", .linkage = linkage });
    const __popcountsi2 = @import("compiler_rt/popcount.zig").__popcountsi2;
    @export(__popcountsi2, .{ .name = "__popcountsi2", .linkage = linkage });
    const __popcountdi2 = @import("compiler_rt/popcount.zig").__popcountdi2;
    @export(__popcountdi2, .{ .name = "__popcountdi2", .linkage = linkage });
    const __popcountti2 = @import("compiler_rt/popcount.zig").__popcountti2;
    @export(__popcountti2, .{ .name = "__popcountti2", .linkage = linkage });
    const __bswapsi2 = @import("compiler_rt/bswap.zig").__bswapsi2;
    @export(__bswapsi2, .{ .name = "__bswapsi2", .linkage = linkage });
    const __bswapdi2 = @import("compiler_rt/bswap.zig").__bswapdi2;
    @export(__bswapdi2, .{ .name = "__bswapdi2", .linkage = linkage });
    const __bswapti2 = @import("compiler_rt/bswap.zig").__bswapti2;
    @export(__bswapti2, .{ .name = "__bswapti2", .linkage = linkage });

    // Integral -> Float Conversion

    // Conversion to f32
    const __floatsisf = @import("compiler_rt/floatXiYf.zig").__floatsisf;
    @export(__floatsisf, .{ .name = "__floatsisf", .linkage = linkage });
    const __floatunsisf = @import("compiler_rt/floatXiYf.zig").__floatunsisf;
    @export(__floatunsisf, .{ .name = "__floatunsisf", .linkage = linkage });

    const __floatundisf = @import("compiler_rt/floatXiYf.zig").__floatundisf;
    @export(__floatundisf, .{ .name = "__floatundisf", .linkage = linkage });
    const __floatdisf = @import("compiler_rt/floatXiYf.zig").__floatdisf;
    @export(__floatdisf, .{ .name = "__floatdisf", .linkage = linkage });

    const __floattisf = @import("compiler_rt/floatXiYf.zig").__floattisf;
    @export(__floattisf, .{ .name = "__floattisf", .linkage = linkage });
    const __floatuntisf = @import("compiler_rt/floatXiYf.zig").__floatuntisf;
    @export(__floatuntisf, .{ .name = "__floatuntisf", .linkage = linkage });

    // Conversion to f64
    const __floatsidf = @import("compiler_rt/floatXiYf.zig").__floatsidf;
    @export(__floatsidf, .{ .name = "__floatsidf", .linkage = linkage });
    const __floatunsidf = @import("compiler_rt/floatXiYf.zig").__floatunsidf;
    @export(__floatunsidf, .{ .name = "__floatunsidf", .linkage = linkage });

    const __floatdidf = @import("compiler_rt/floatXiYf.zig").__floatdidf;
    @export(__floatdidf, .{ .name = "__floatdidf", .linkage = linkage });
    const __floatundidf = @import("compiler_rt/floatXiYf.zig").__floatundidf;
    @export(__floatundidf, .{ .name = "__floatundidf", .linkage = linkage });

    const __floattidf = @import("compiler_rt/floatXiYf.zig").__floattidf;
    @export(__floattidf, .{ .name = "__floattidf", .linkage = linkage });
    const __floatuntidf = @import("compiler_rt/floatXiYf.zig").__floatuntidf;
    @export(__floatuntidf, .{ .name = "__floatuntidf", .linkage = linkage });

    // Conversion to f80
    const __floatsixf = @import("compiler_rt/floatXiYf.zig").__floatsixf;
    @export(__floatsixf, .{ .name = "__floatsixf", .linkage = linkage });
    const __floatunsixf = @import("compiler_rt/floatXiYf.zig").__floatunsixf;
    @export(__floatunsixf, .{ .name = "__floatunsixf", .linkage = linkage });

    const __floatdixf = @import("compiler_rt/floatXiYf.zig").__floatdixf;
    @export(__floatdixf, .{ .name = "__floatdixf", .linkage = linkage });
    const __floatundixf = @import("compiler_rt/floatXiYf.zig").__floatundixf;
    @export(__floatundixf, .{ .name = "__floatundixf", .linkage = linkage });

    const __floattixf = @import("compiler_rt/floatXiYf.zig").__floattixf;
    @export(__floattixf, .{ .name = "__floattixf", .linkage = linkage });
    const __floatuntixf = @import("compiler_rt/floatXiYf.zig").__floatuntixf;
    @export(__floatuntixf, .{ .name = "__floatuntixf", .linkage = linkage });

    // Conversion to f128
    const __floatsitf = @import("compiler_rt/floatXiYf.zig").__floatsitf;
    @export(__floatsitf, .{ .name = "__floatsitf", .linkage = linkage });
    const __floatunsitf = @import("compiler_rt/floatXiYf.zig").__floatunsitf;
    @export(__floatunsitf, .{ .name = "__floatunsitf", .linkage = linkage });

    const __floatditf = @import("compiler_rt/floatXiYf.zig").__floatditf;
    @export(__floatditf, .{ .name = "__floatditf", .linkage = linkage });
    const __floatunditf = @import("compiler_rt/floatXiYf.zig").__floatunditf;
    @export(__floatunditf, .{ .name = "__floatunditf", .linkage = linkage });

    const __floattitf = @import("compiler_rt/floatXiYf.zig").__floattitf;
    @export(__floattitf, .{ .name = "__floattitf", .linkage = linkage });
    const __floatuntitf = @import("compiler_rt/floatXiYf.zig").__floatuntitf;
    @export(__floatuntitf, .{ .name = "__floatuntitf", .linkage = linkage });

    // Float -> Integral Conversion

    // Conversion from f32
    const __fixsfsi = @import("compiler_rt/fixXfYi.zig").__fixsfsi;
    @export(__fixsfsi, .{ .name = "__fixsfsi", .linkage = linkage });
    const __fixunssfsi = @import("compiler_rt/fixXfYi.zig").__fixunssfsi;
    @export(__fixunssfsi, .{ .name = "__fixunssfsi", .linkage = linkage });

    const __fixsfdi = @import("compiler_rt/fixXfYi.zig").__fixsfdi;
    @export(__fixsfdi, .{ .name = "__fixsfdi", .linkage = linkage });
    const __fixunssfdi = @import("compiler_rt/fixXfYi.zig").__fixunssfdi;
    @export(__fixunssfdi, .{ .name = "__fixunssfdi", .linkage = linkage });

    const __fixsfti = @import("compiler_rt/fixXfYi.zig").__fixsfti;
    @export(__fixsfti, .{ .name = "__fixsfti", .linkage = linkage });
    const __fixunssfti = @import("compiler_rt/fixXfYi.zig").__fixunssfti;
    @export(__fixunssfti, .{ .name = "__fixunssfti", .linkage = linkage });

    // Conversion from f64
    const __fixdfsi = @import("compiler_rt/fixXfYi.zig").__fixdfsi;
    @export(__fixdfsi, .{ .name = "__fixdfsi", .linkage = linkage });
    const __fixunsdfsi = @import("compiler_rt/fixXfYi.zig").__fixunsdfsi;
    @export(__fixunsdfsi, .{ .name = "__fixunsdfsi", .linkage = linkage });

    const __fixdfdi = @import("compiler_rt/fixXfYi.zig").__fixdfdi;
    @export(__fixdfdi, .{ .name = "__fixdfdi", .linkage = linkage });
    const __fixunsdfdi = @import("compiler_rt/fixXfYi.zig").__fixunsdfdi;
    @export(__fixunsdfdi, .{ .name = "__fixunsdfdi", .linkage = linkage });

    const __fixdfti = @import("compiler_rt/fixXfYi.zig").__fixdfti;
    @export(__fixdfti, .{ .name = "__fixdfti", .linkage = linkage });
    const __fixunsdfti = @import("compiler_rt/fixXfYi.zig").__fixunsdfti;
    @export(__fixunsdfti, .{ .name = "__fixunsdfti", .linkage = linkage });

    // Conversion from f80
    const __fixxfsi = @import("compiler_rt/fixXfYi.zig").__fixxfsi;
    @export(__fixxfsi, .{ .name = "__fixxfsi", .linkage = linkage });
    const __fixunsxfsi = @import("compiler_rt/fixXfYi.zig").__fixunsxfsi;
    @export(__fixunsxfsi, .{ .name = "__fixunsxfsi", .linkage = linkage });

    const __fixxfdi = @import("compiler_rt/fixXfYi.zig").__fixxfdi;
    @export(__fixxfdi, .{ .name = "__fixxfdi", .linkage = linkage });
    const __fixunsxfdi = @import("compiler_rt/fixXfYi.zig").__fixunsxfdi;
    @export(__fixunsxfdi, .{ .name = "__fixunsxfdi", .linkage = linkage });

    const __fixxfti = @import("compiler_rt/fixXfYi.zig").__fixxfti;
    @export(__fixxfti, .{ .name = "__fixxfti", .linkage = linkage });
    const __fixunsxfti = @import("compiler_rt/fixXfYi.zig").__fixunsxfti;
    @export(__fixunsxfti, .{ .name = "__fixunsxfti", .linkage = linkage });

    // Conversion from f128
    const __fixtfsi = @import("compiler_rt/fixXfYi.zig").__fixtfsi;
    @export(__fixtfsi, .{ .name = "__fixtfsi", .linkage = linkage });
    const __fixunstfsi = @import("compiler_rt/fixXfYi.zig").__fixunstfsi;
    @export(__fixunstfsi, .{ .name = "__fixunstfsi", .linkage = linkage });

    const __fixtfdi = @import("compiler_rt/fixXfYi.zig").__fixtfdi;
    @export(__fixtfdi, .{ .name = "__fixtfdi", .linkage = linkage });
    const __fixunstfdi = @import("compiler_rt/fixXfYi.zig").__fixunstfdi;
    @export(__fixunstfdi, .{ .name = "__fixunstfdi", .linkage = linkage });

    const __fixtfti = @import("compiler_rt/fixXfYi.zig").__fixtfti;
    @export(__fixtfti, .{ .name = "__fixtfti", .linkage = linkage });
    const __fixunstfti = @import("compiler_rt/fixXfYi.zig").__fixunstfti;
    @export(__fixunstfti, .{ .name = "__fixunstfti", .linkage = linkage });

    const __udivmoddi4 = @import("compiler_rt/int.zig").__udivmoddi4;
    @export(__udivmoddi4, .{ .name = "__udivmoddi4", .linkage = linkage });

    const __truncsfhf2 = @import("compiler_rt/truncXfYf2.zig").__truncsfhf2;
    @export(__truncsfhf2, .{ .name = "__truncsfhf2", .linkage = linkage });
    if (!is_test) {
        @export(__truncsfhf2, .{ .name = "__gnu_f2h_ieee", .linkage = linkage });
    }
    const __extendsfdf2 = @import("compiler_rt/extendXfYf2.zig").__extendsfdf2;
    @export(__extendsfdf2, .{ .name = "__extendsfdf2", .linkage = linkage });

    if (is_darwin) {
        const __isPlatformVersionAtLeast = @import("compiler_rt/os_version_check.zig").__isPlatformVersionAtLeast;
        @export(__isPlatformVersionAtLeast, .{ .name = "__isPlatformVersionAtLeast", .linkage = linkage });
    }

    // Integer Arithmetic
    const __ashldi3 = @import("compiler_rt/shift.zig").__ashldi3;
    @export(__ashldi3, .{ .name = "__ashldi3", .linkage = linkage });
    const __ashlti3 = @import("compiler_rt/shift.zig").__ashlti3;
    @export(__ashlti3, .{ .name = "__ashlti3", .linkage = linkage });
    const __ashrdi3 = @import("compiler_rt/shift.zig").__ashrdi3;
    @export(__ashrdi3, .{ .name = "__ashrdi3", .linkage = linkage });
    const __ashrti3 = @import("compiler_rt/shift.zig").__ashrti3;
    @export(__ashrti3, .{ .name = "__ashrti3", .linkage = linkage });
    const __lshrdi3 = @import("compiler_rt/shift.zig").__lshrdi3;
    @export(__lshrdi3, .{ .name = "__lshrdi3", .linkage = linkage });
    const __lshrti3 = @import("compiler_rt/shift.zig").__lshrti3;
    @export(__lshrti3, .{ .name = "__lshrti3", .linkage = linkage });
    const __negsi2 = @import("compiler_rt/negXi2.zig").__negsi2;
    @export(__negsi2, .{ .name = "__negsi2", .linkage = linkage });
    const __negdi2 = @import("compiler_rt/negXi2.zig").__negdi2;
    @export(__negdi2, .{ .name = "__negdi2", .linkage = linkage });
    const __negti2 = @import("compiler_rt/negXi2.zig").__negti2;
    @export(__negti2, .{ .name = "__negti2", .linkage = linkage });

    const __mulsi3 = @import("compiler_rt/int.zig").__mulsi3;
    @export(__mulsi3, .{ .name = "__mulsi3", .linkage = linkage });
    const __muldi3 = @import("compiler_rt/muldi3.zig").__muldi3;
    @export(__muldi3, .{ .name = "__muldi3", .linkage = linkage });
    const __divmoddi4 = @import("compiler_rt/int.zig").__divmoddi4;
    @export(__divmoddi4, .{ .name = "__divmoddi4", .linkage = linkage });
    const __divsi3 = @import("compiler_rt/int.zig").__divsi3;
    @export(__divsi3, .{ .name = "__divsi3", .linkage = linkage });
    const __divdi3 = @import("compiler_rt/int.zig").__divdi3;
    @export(__divdi3, .{ .name = "__divdi3", .linkage = linkage });
    const __udivsi3 = @import("compiler_rt/int.zig").__udivsi3;
    @export(__udivsi3, .{ .name = "__udivsi3", .linkage = linkage });
    const __udivdi3 = @import("compiler_rt/int.zig").__udivdi3;
    @export(__udivdi3, .{ .name = "__udivdi3", .linkage = linkage });
    const __modsi3 = @import("compiler_rt/int.zig").__modsi3;
    @export(__modsi3, .{ .name = "__modsi3", .linkage = linkage });
    const __moddi3 = @import("compiler_rt/int.zig").__moddi3;
    @export(__moddi3, .{ .name = "__moddi3", .linkage = linkage });
    const __umodsi3 = @import("compiler_rt/int.zig").__umodsi3;
    @export(__umodsi3, .{ .name = "__umodsi3", .linkage = linkage });
    const __umoddi3 = @import("compiler_rt/int.zig").__umoddi3;
    @export(__umoddi3, .{ .name = "__umoddi3", .linkage = linkage });
    const __divmodsi4 = @import("compiler_rt/int.zig").__divmodsi4;
    @export(__divmodsi4, .{ .name = "__divmodsi4", .linkage = linkage });
    const __udivmodsi4 = @import("compiler_rt/int.zig").__udivmodsi4;
    @export(__udivmodsi4, .{ .name = "__udivmodsi4", .linkage = linkage });

    // Integer Arithmetic with trapping overflow
    const __absvsi2 = @import("compiler_rt/absv.zig").__absvsi2;
    @export(__absvsi2, .{ .name = "__absvsi2", .linkage = linkage });
    const __absvdi2 = @import("compiler_rt/absv.zig").__absvdi2;
    @export(__absvdi2, .{ .name = "__absvdi2", .linkage = linkage });
    const __absvti2 = @import("compiler_rt/absv.zig").__absvti2;
    @export(__absvti2, .{ .name = "__absvti2", .linkage = linkage });
    const __negvsi2 = @import("compiler_rt/negv.zig").__negvsi2;
    @export(__negvsi2, .{ .name = "__negvsi2", .linkage = linkage });
    const __negvdi2 = @import("compiler_rt/negv.zig").__negvdi2;
    @export(__negvdi2, .{ .name = "__negvdi2", .linkage = linkage });
    const __negvti2 = @import("compiler_rt/negv.zig").__negvti2;
    @export(__negvti2, .{ .name = "__negvti2", .linkage = linkage });

    // Integer arithmetic which returns if overflow
    const __addosi4 = @import("compiler_rt/addo.zig").__addosi4;
    @export(__addosi4, .{ .name = "__addosi4", .linkage = linkage });
    const __addodi4 = @import("compiler_rt/addo.zig").__addodi4;
    @export(__addodi4, .{ .name = "__addodi4", .linkage = linkage });
    const __addoti4 = @import("compiler_rt/addo.zig").__addoti4;
    @export(__addoti4, .{ .name = "__addoti4", .linkage = linkage });
    const __subosi4 = @import("compiler_rt/subo.zig").__subosi4;
    @export(__subosi4, .{ .name = "__subosi4", .linkage = linkage });
    const __subodi4 = @import("compiler_rt/subo.zig").__subodi4;
    @export(__subodi4, .{ .name = "__subodi4", .linkage = linkage });
    const __suboti4 = @import("compiler_rt/subo.zig").__suboti4;
    @export(__suboti4, .{ .name = "__suboti4", .linkage = linkage });
    const __mulosi4 = @import("compiler_rt/mulo.zig").__mulosi4;
    @export(__mulosi4, .{ .name = "__mulosi4", .linkage = linkage });
    const __mulodi4 = @import("compiler_rt/mulo.zig").__mulodi4;
    @export(__mulodi4, .{ .name = "__mulodi4", .linkage = linkage });
    const __muloti4 = @import("compiler_rt/mulo.zig").__muloti4;
    @export(__muloti4, .{ .name = "__muloti4", .linkage = linkage });

    // Integer Comparison
    // (a <  b) => 0
    // (a == b) => 1
    // (a >  b) => 2
    const __cmpsi2 = @import("compiler_rt/cmp.zig").__cmpsi2;
    @export(__cmpsi2, .{ .name = "__cmpsi2", .linkage = linkage });
    const __cmpdi2 = @import("compiler_rt/cmp.zig").__cmpdi2;
    @export(__cmpdi2, .{ .name = "__cmpdi2", .linkage = linkage });
    const __cmpti2 = @import("compiler_rt/cmp.zig").__cmpti2;
    @export(__cmpti2, .{ .name = "__cmpti2", .linkage = linkage });
    const __ucmpsi2 = @import("compiler_rt/cmp.zig").__ucmpsi2;
    @export(__ucmpsi2, .{ .name = "__ucmpsi2", .linkage = linkage });
    const __ucmpdi2 = @import("compiler_rt/cmp.zig").__ucmpdi2;
    @export(__ucmpdi2, .{ .name = "__ucmpdi2", .linkage = linkage });
    const __ucmpti2 = @import("compiler_rt/cmp.zig").__ucmpti2;
    @export(__ucmpti2, .{ .name = "__ucmpti2", .linkage = linkage });

    // missing: Floating point raised to integer power

    // missing: Complex arithmetic
    // (a + ib) * (c + id)
    // (a + ib) / (c + id)

    const __negsf2 = @import("compiler_rt/negXf2.zig").__negsf2;
    @export(__negsf2, .{ .name = "__negsf2", .linkage = linkage });
    const __negdf2 = @import("compiler_rt/negXf2.zig").__negdf2;
    @export(__negdf2, .{ .name = "__negdf2", .linkage = linkage });

    if (builtin.link_libc and os_tag == .openbsd) {
        const __emutls_get_address = @import("compiler_rt/emutls.zig").__emutls_get_address;
        @export(__emutls_get_address, .{ .name = "__emutls_get_address", .linkage = linkage });
    }

    if ((arch.isARM() or arch.isThumb()) and !is_test) {
        const __aeabi_unwind_cpp_pr0 = @import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr0;
        @export(__aeabi_unwind_cpp_pr0, .{ .name = "__aeabi_unwind_cpp_pr0", .linkage = linkage });
        const __aeabi_unwind_cpp_pr1 = @import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr1;
        @export(__aeabi_unwind_cpp_pr1, .{ .name = "__aeabi_unwind_cpp_pr1", .linkage = linkage });
        const __aeabi_unwind_cpp_pr2 = @import("compiler_rt/arm.zig").__aeabi_unwind_cpp_pr2;
        @export(__aeabi_unwind_cpp_pr2, .{ .name = "__aeabi_unwind_cpp_pr2", .linkage = linkage });

        @export(__muldi3, .{ .name = "__aeabi_lmul", .linkage = linkage });

        const __aeabi_ldivmod = @import("compiler_rt/arm.zig").__aeabi_ldivmod;
        @export(__aeabi_ldivmod, .{ .name = "__aeabi_ldivmod", .linkage = linkage });
        const __aeabi_uldivmod = @import("compiler_rt/arm.zig").__aeabi_uldivmod;
        @export(__aeabi_uldivmod, .{ .name = "__aeabi_uldivmod", .linkage = linkage });

        @export(__divsi3, .{ .name = "__aeabi_idiv", .linkage = linkage });
        const __aeabi_idivmod = @import("compiler_rt/arm.zig").__aeabi_idivmod;
        @export(__aeabi_idivmod, .{ .name = "__aeabi_idivmod", .linkage = linkage });
        @export(__udivsi3, .{ .name = "__aeabi_uidiv", .linkage = linkage });
        const __aeabi_uidivmod = @import("compiler_rt/arm.zig").__aeabi_uidivmod;
        @export(__aeabi_uidivmod, .{ .name = "__aeabi_uidivmod", .linkage = linkage });

        const __aeabi_memcpy = @import("compiler_rt/arm.zig").__aeabi_memcpy;
        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy", .linkage = linkage });
        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy4", .linkage = linkage });
        @export(__aeabi_memcpy, .{ .name = "__aeabi_memcpy8", .linkage = linkage });

        const __aeabi_memmove = @import("compiler_rt/arm.zig").__aeabi_memmove;
        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove", .linkage = linkage });
        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove4", .linkage = linkage });
        @export(__aeabi_memmove, .{ .name = "__aeabi_memmove8", .linkage = linkage });

        const __aeabi_memset = @import("compiler_rt/arm.zig").__aeabi_memset;
        @export(__aeabi_memset, .{ .name = "__aeabi_memset", .linkage = linkage });
        @export(__aeabi_memset, .{ .name = "__aeabi_memset4", .linkage = linkage });
        @export(__aeabi_memset, .{ .name = "__aeabi_memset8", .linkage = linkage });

        const __aeabi_memclr = @import("compiler_rt/arm.zig").__aeabi_memclr;
        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr", .linkage = linkage });
        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr4", .linkage = linkage });
        @export(__aeabi_memclr, .{ .name = "__aeabi_memclr8", .linkage = linkage });

        if (os_tag == .linux) {
            const __aeabi_read_tp = @import("compiler_rt/arm.zig").__aeabi_read_tp;
            @export(__aeabi_read_tp, .{ .name = "__aeabi_read_tp", .linkage = linkage });
        }

        const __aeabi_f2d = @import("compiler_rt/extendXfYf2.zig").__aeabi_f2d;
        @export(__aeabi_f2d, .{ .name = "__aeabi_f2d", .linkage = linkage });
        const __aeabi_i2d = @import("compiler_rt/floatXiYf.zig").__aeabi_i2d;
        @export(__aeabi_i2d, .{ .name = "__aeabi_i2d", .linkage = linkage });
        const __aeabi_l2d = @import("compiler_rt/floatXiYf.zig").__aeabi_l2d;
        @export(__aeabi_l2d, .{ .name = "__aeabi_l2d", .linkage = linkage });
        const __aeabi_l2f = @import("compiler_rt/floatXiYf.zig").__aeabi_l2f;
        @export(__aeabi_l2f, .{ .name = "__aeabi_l2f", .linkage = linkage });
        const __aeabi_ui2d = @import("compiler_rt/floatXiYf.zig").__aeabi_ui2d;
        @export(__aeabi_ui2d, .{ .name = "__aeabi_ui2d", .linkage = linkage });
        const __aeabi_ul2d = @import("compiler_rt/floatXiYf.zig").__aeabi_ul2d;
        @export(__aeabi_ul2d, .{ .name = "__aeabi_ul2d", .linkage = linkage });
        const __aeabi_ui2f = @import("compiler_rt/floatXiYf.zig").__aeabi_ui2f;
        @export(__aeabi_ui2f, .{ .name = "__aeabi_ui2f", .linkage = linkage });
        const __aeabi_ul2f = @import("compiler_rt/floatXiYf.zig").__aeabi_ul2f;
        @export(__aeabi_ul2f, .{ .name = "__aeabi_ul2f", .linkage = linkage });

        const __aeabi_fneg = @import("compiler_rt/negXf2.zig").__aeabi_fneg;
        @export(__aeabi_fneg, .{ .name = "__aeabi_fneg", .linkage = linkage });
        const __aeabi_dneg = @import("compiler_rt/negXf2.zig").__aeabi_dneg;
        @export(__aeabi_dneg, .{ .name = "__aeabi_dneg", .linkage = linkage });

        const __aeabi_fmul = @import("compiler_rt/mulXf3.zig").__aeabi_fmul;
        @export(__aeabi_fmul, .{ .name = "__aeabi_fmul", .linkage = linkage });
        const __aeabi_dmul = @import("compiler_rt/mulXf3.zig").__aeabi_dmul;
        @export(__aeabi_dmul, .{ .name = "__aeabi_dmul", .linkage = linkage });

        const __aeabi_d2h = @import("compiler_rt/truncXfYf2.zig").__aeabi_d2h;
        @export(__aeabi_d2h, .{ .name = "__aeabi_d2h", .linkage = linkage });

        const __aeabi_f2ulz = @import("compiler_rt/fixXfYi.zig").__aeabi_f2ulz;
        @export(__aeabi_f2ulz, .{ .name = "__aeabi_f2ulz", .linkage = linkage });
        const __aeabi_d2ulz = @import("compiler_rt/fixXfYi.zig").__aeabi_d2ulz;
        @export(__aeabi_d2ulz, .{ .name = "__aeabi_d2ulz", .linkage = linkage });

        const __aeabi_f2lz = @import("compiler_rt/fixXfYi.zig").__aeabi_f2lz;
        @export(__aeabi_f2lz, .{ .name = "__aeabi_f2lz", .linkage = linkage });
        const __aeabi_d2lz = @import("compiler_rt/fixXfYi.zig").__aeabi_d2lz;
        @export(__aeabi_d2lz, .{ .name = "__aeabi_d2lz", .linkage = linkage });

        const __aeabi_d2uiz = @import("compiler_rt/fixXfYi.zig").__aeabi_d2uiz;
        @export(__aeabi_d2uiz, .{ .name = "__aeabi_d2uiz", .linkage = linkage });

        const __aeabi_h2f = @import("compiler_rt/extendXfYf2.zig").__aeabi_h2f;
        @export(__aeabi_h2f, .{ .name = "__aeabi_h2f", .linkage = linkage });
        const __aeabi_f2h = @import("compiler_rt/truncXfYf2.zig").__aeabi_f2h;
        @export(__aeabi_f2h, .{ .name = "__aeabi_f2h", .linkage = linkage });

        const __aeabi_i2f = @import("compiler_rt/floatXiYf.zig").__aeabi_i2f;
        @export(__aeabi_i2f, .{ .name = "__aeabi_i2f", .linkage = linkage });
        const __aeabi_d2f = @import("compiler_rt/truncXfYf2.zig").__aeabi_d2f;
        @export(__aeabi_d2f, .{ .name = "__aeabi_d2f", .linkage = linkage });

        const __aeabi_fadd = @import("compiler_rt/addXf3.zig").__aeabi_fadd;
        @export(__aeabi_fadd, .{ .name = "__aeabi_fadd", .linkage = linkage });
        const __aeabi_dadd = @import("compiler_rt/addXf3.zig").__aeabi_dadd;
        @export(__aeabi_dadd, .{ .name = "__aeabi_dadd", .linkage = linkage });
        const __aeabi_fsub = @import("compiler_rt/addXf3.zig").__aeabi_fsub;
        @export(__aeabi_fsub, .{ .name = "__aeabi_fsub", .linkage = linkage });
        const __aeabi_dsub = @import("compiler_rt/addXf3.zig").__aeabi_dsub;
        @export(__aeabi_dsub, .{ .name = "__aeabi_dsub", .linkage = linkage });

        const __aeabi_f2uiz = @import("compiler_rt/fixXfYi.zig").__aeabi_f2uiz;
        @export(__aeabi_f2uiz, .{ .name = "__aeabi_f2uiz", .linkage = linkage });

        const __aeabi_f2iz = @import("compiler_rt/fixXfYi.zig").__aeabi_f2iz;
        @export(__aeabi_f2iz, .{ .name = "__aeabi_f2iz", .linkage = linkage });
        const __aeabi_d2iz = @import("compiler_rt/fixXfYi.zig").__aeabi_d2iz;
        @export(__aeabi_d2iz, .{ .name = "__aeabi_d2iz", .linkage = linkage });

        const __aeabi_fdiv = @import("compiler_rt/divsf3.zig").__aeabi_fdiv;
        @export(__aeabi_fdiv, .{ .name = "__aeabi_fdiv", .linkage = linkage });
        const __aeabi_ddiv = @import("compiler_rt/divdf3.zig").__aeabi_ddiv;
        @export(__aeabi_ddiv, .{ .name = "__aeabi_ddiv", .linkage = linkage });

        const __aeabi_llsl = @import("compiler_rt/shift.zig").__aeabi_llsl;
        @export(__aeabi_llsl, .{ .name = "__aeabi_llsl", .linkage = linkage });
        const __aeabi_lasr = @import("compiler_rt/shift.zig").__aeabi_lasr;
        @export(__aeabi_lasr, .{ .name = "__aeabi_lasr", .linkage = linkage });
        const __aeabi_llsr = @import("compiler_rt/shift.zig").__aeabi_llsr;
        @export(__aeabi_llsr, .{ .name = "__aeabi_llsr", .linkage = linkage });

        const __aeabi_fcmpeq = @import("compiler_rt/compareXf2.zig").__aeabi_fcmpeq;
        @export(__aeabi_fcmpeq, .{ .name = "__aeabi_fcmpeq", .linkage = linkage });
        const __aeabi_fcmplt = @import("compiler_rt/compareXf2.zig").__aeabi_fcmplt;
        @export(__aeabi_fcmplt, .{ .name = "__aeabi_fcmplt", .linkage = linkage });
        const __aeabi_fcmple = @import("compiler_rt/compareXf2.zig").__aeabi_fcmple;
        @export(__aeabi_fcmple, .{ .name = "__aeabi_fcmple", .linkage = linkage });
        const __aeabi_fcmpge = @import("compiler_rt/compareXf2.zig").__aeabi_fcmpge;
        @export(__aeabi_fcmpge, .{ .name = "__aeabi_fcmpge", .linkage = linkage });
        const __aeabi_fcmpgt = @import("compiler_rt/compareXf2.zig").__aeabi_fcmpgt;
        @export(__aeabi_fcmpgt, .{ .name = "__aeabi_fcmpgt", .linkage = linkage });
        const __aeabi_fcmpun = @import("compiler_rt/compareXf2.zig").__aeabi_fcmpun;
        @export(__aeabi_fcmpun, .{ .name = "__aeabi_fcmpun", .linkage = linkage });

        const __aeabi_dcmpeq = @import("compiler_rt/compareXf2.zig").__aeabi_dcmpeq;
        @export(__aeabi_dcmpeq, .{ .name = "__aeabi_dcmpeq", .linkage = linkage });
        const __aeabi_dcmplt = @import("compiler_rt/compareXf2.zig").__aeabi_dcmplt;
        @export(__aeabi_dcmplt, .{ .name = "__aeabi_dcmplt", .linkage = linkage });
        const __aeabi_dcmple = @import("compiler_rt/compareXf2.zig").__aeabi_dcmple;
        @export(__aeabi_dcmple, .{ .name = "__aeabi_dcmple", .linkage = linkage });
        const __aeabi_dcmpge = @import("compiler_rt/compareXf2.zig").__aeabi_dcmpge;
        @export(__aeabi_dcmpge, .{ .name = "__aeabi_dcmpge", .linkage = linkage });
        const __aeabi_dcmpgt = @import("compiler_rt/compareXf2.zig").__aeabi_dcmpgt;
        @export(__aeabi_dcmpgt, .{ .name = "__aeabi_dcmpgt", .linkage = linkage });
        const __aeabi_dcmpun = @import("compiler_rt/compareXf2.zig").__aeabi_dcmpun;
        @export(__aeabi_dcmpun, .{ .name = "__aeabi_dcmpun", .linkage = linkage });
    }

    if (arch == .i386 and abi == .msvc) {
        // Don't let LLVM apply the stdcall name mangling on those MSVC builtins
        const _alldiv = @import("compiler_rt/aulldiv.zig")._alldiv;
        @export(_alldiv, .{ .name = "\x01__alldiv", .linkage = strong_linkage });
        const _aulldiv = @import("compiler_rt/aulldiv.zig")._aulldiv;
        @export(_aulldiv, .{ .name = "\x01__aulldiv", .linkage = strong_linkage });
        const _allrem = @import("compiler_rt/aullrem.zig")._allrem;
        @export(_allrem, .{ .name = "\x01__allrem", .linkage = strong_linkage });
        const _aullrem = @import("compiler_rt/aullrem.zig")._aullrem;
        @export(_aullrem, .{ .name = "\x01__aullrem", .linkage = strong_linkage });
    }

    mathExport("ceil", @import("./compiler_rt/ceil.zig"));
    mathExport("cos", @import("./compiler_rt/cos.zig"));
    mathExport("exp", @import("./compiler_rt/exp.zig"));
    mathExport("exp2", @import("./compiler_rt/exp2.zig"));
    mathExport("fabs", @import("./compiler_rt/fabs.zig"));
    mathExport("floor", @import("./compiler_rt/floor.zig"));
    mathExport("fma", @import("./compiler_rt/fma.zig"));
    mathExport("fmax", @import("./compiler_rt/fmax.zig"));
    mathExport("fmin", @import("./compiler_rt/fmin.zig"));
    mathExport("fmod", @import("./compiler_rt/fmod.zig"));
    mathExport("log", @import("./compiler_rt/log.zig"));
    mathExport("log10", @import("./compiler_rt/log10.zig"));
    mathExport("log2", @import("./compiler_rt/log2.zig"));
    mathExport("round", @import("./compiler_rt/round.zig"));
    mathExport("sin", @import("./compiler_rt/sin.zig"));
    mathExport("sincos", @import("./compiler_rt/sincos.zig"));
    mathExport("sqrt", @import("./compiler_rt/sqrt.zig"));
    mathExport("tan", @import("./compiler_rt/tan.zig"));
    mathExport("trunc", @import("./compiler_rt/trunc.zig"));

    if (arch.isSPARC()) {
        // SPARC systems use a different naming scheme
        const _Qp_add = @import("compiler_rt/sparc.zig")._Qp_add;
        @export(_Qp_add, .{ .name = "_Qp_add", .linkage = linkage });
        const _Qp_div = @import("compiler_rt/sparc.zig")._Qp_div;
        @export(_Qp_div, .{ .name = "_Qp_div", .linkage = linkage });
        const _Qp_mul = @import("compiler_rt/sparc.zig")._Qp_mul;
        @export(_Qp_mul, .{ .name = "_Qp_mul", .linkage = linkage });
        const _Qp_sub = @import("compiler_rt/sparc.zig")._Qp_sub;
        @export(_Qp_sub, .{ .name = "_Qp_sub", .linkage = linkage });

        const _Qp_cmp = @import("compiler_rt/sparc.zig")._Qp_cmp;
        @export(_Qp_cmp, .{ .name = "_Qp_cmp", .linkage = linkage });
        const _Qp_feq = @import("compiler_rt/sparc.zig")._Qp_feq;
        @export(_Qp_feq, .{ .name = "_Qp_feq", .linkage = linkage });
        const _Qp_fne = @import("compiler_rt/sparc.zig")._Qp_fne;
        @export(_Qp_fne, .{ .name = "_Qp_fne", .linkage = linkage });
        const _Qp_flt = @import("compiler_rt/sparc.zig")._Qp_flt;
        @export(_Qp_flt, .{ .name = "_Qp_flt", .linkage = linkage });
        const _Qp_fle = @import("compiler_rt/sparc.zig")._Qp_fle;
        @export(_Qp_fle, .{ .name = "_Qp_fle", .linkage = linkage });
        const _Qp_fgt = @import("compiler_rt/sparc.zig")._Qp_fgt;
        @export(_Qp_fgt, .{ .name = "_Qp_fgt", .linkage = linkage });
        const _Qp_fge = @import("compiler_rt/sparc.zig")._Qp_fge;
        @export(_Qp_fge, .{ .name = "_Qp_fge", .linkage = linkage });

        const _Qp_itoq = @import("compiler_rt/sparc.zig")._Qp_itoq;
        @export(_Qp_itoq, .{ .name = "_Qp_itoq", .linkage = linkage });
        const _Qp_uitoq = @import("compiler_rt/sparc.zig")._Qp_uitoq;
        @export(_Qp_uitoq, .{ .name = "_Qp_uitoq", .linkage = linkage });
        const _Qp_xtoq = @import("compiler_rt/sparc.zig")._Qp_xtoq;
        @export(_Qp_xtoq, .{ .name = "_Qp_xtoq", .linkage = linkage });
        const _Qp_uxtoq = @import("compiler_rt/sparc.zig")._Qp_uxtoq;
        @export(_Qp_uxtoq, .{ .name = "_Qp_uxtoq", .linkage = linkage });
        const _Qp_stoq = @import("compiler_rt/sparc.zig")._Qp_stoq;
        @export(_Qp_stoq, .{ .name = "_Qp_stoq", .linkage = linkage });
        const _Qp_dtoq = @import("compiler_rt/sparc.zig")._Qp_dtoq;
        @export(_Qp_dtoq, .{ .name = "_Qp_dtoq", .linkage = linkage });
        const _Qp_qtoi = @import("compiler_rt/sparc.zig")._Qp_qtoi;
        @export(_Qp_qtoi, .{ .name = "_Qp_qtoi", .linkage = linkage });
        const _Qp_qtoui = @import("compiler_rt/sparc.zig")._Qp_qtoui;
        @export(_Qp_qtoui, .{ .name = "_Qp_qtoui", .linkage = linkage });
        const _Qp_qtox = @import("compiler_rt/sparc.zig")._Qp_qtox;
        @export(_Qp_qtox, .{ .name = "_Qp_qtox", .linkage = linkage });
        const _Qp_qtoux = @import("compiler_rt/sparc.zig")._Qp_qtoux;
        @export(_Qp_qtoux, .{ .name = "_Qp_qtoux", .linkage = linkage });
        const _Qp_qtos = @import("compiler_rt/sparc.zig")._Qp_qtos;
        @export(_Qp_qtos, .{ .name = "_Qp_qtos", .linkage = linkage });
        const _Qp_qtod = @import("compiler_rt/sparc.zig")._Qp_qtod;
        @export(_Qp_qtod, .{ .name = "_Qp_qtod", .linkage = linkage });
    }

    if (is_ppc and !is_test) {
        @export(__addtf3, .{ .name = "__addkf3", .linkage = linkage });
        @export(__subtf3, .{ .name = "__subkf3", .linkage = linkage });
        @export(__multf3, .{ .name = "__mulkf3", .linkage = linkage });
        @export(__divtf3, .{ .name = "__divkf3", .linkage = linkage });
        @export(__extendsftf2, .{ .name = "__extendsfkf2", .linkage = linkage });
        @export(__extenddftf2, .{ .name = "__extenddfkf2", .linkage = linkage });
        @export(__trunctfsf2, .{ .name = "__trunckfsf2", .linkage = linkage });
        @export(__trunctfdf2, .{ .name = "__trunckfdf2", .linkage = linkage });
        @export(__fixtfdi, .{ .name = "__fixkfdi", .linkage = linkage });
        @export(__fixtfsi, .{ .name = "__fixkfsi", .linkage = linkage });
        @export(__fixunstfsi, .{ .name = "__fixunskfsi", .linkage = linkage });
        @export(__fixunstfdi, .{ .name = "__fixunskfdi", .linkage = linkage });
        @export(__floatsitf, .{ .name = "__floatsikf", .linkage = linkage });
        @export(__floatditf, .{ .name = "__floatdikf", .linkage = linkage });
        @export(__floatunditf, .{ .name = "__floatundikf", .linkage = linkage });
        @export(__floatunsitf, .{ .name = "__floatunsikf", .linkage = linkage });
        @export(__floatuntitf, .{ .name = "__floatuntikf", .linkage = linkage });

        @export(__letf2, .{ .name = "__eqkf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__nekf2", .linkage = linkage });
        @export(__getf2, .{ .name = "__gekf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__ltkf2", .linkage = linkage });
        @export(__letf2, .{ .name = "__lekf2", .linkage = linkage });
        @export(__getf2, .{ .name = "__gtkf2", .linkage = linkage });
        @export(__unordtf2, .{ .name = "__unordkf2", .linkage = linkage });
    }
}

inline fn mathExport(double_name: []const u8, comptime import: type) void {
    const half_name = "__" ++ double_name ++ "h";
    const half_fn = @field(import, half_name);
    const float_name = double_name ++ "f";
    const float_fn = @field(import, float_name);
    const double_fn = @field(import, double_name);
    const long_double_name = double_name ++ "l";
    const xf80_name = "__" ++ double_name ++ "x";
    const xf80_fn = @field(import, xf80_name);
    const quad_name = double_name ++ "q";
    const quad_fn = @field(import, quad_name);

    @export(half_fn, .{ .name = half_name, .linkage = linkage });
    @export(float_fn, .{ .name = float_name, .linkage = linkage });
    @export(double_fn, .{ .name = double_name, .linkage = linkage });
    @export(xf80_fn, .{ .name = xf80_name, .linkage = linkage });
    @export(quad_fn, .{ .name = quad_name, .linkage = linkage });

    if (is_test) return;

    const pairs = .{
        .{ f16, half_fn },
        .{ f32, float_fn },
        .{ f64, double_fn },
        .{ f80, xf80_fn },
        .{ f128, quad_fn },
    };

    if (builtin.os.tag == .windows) {
        // Weak aliases don't work on Windows, so we have to provide the 'l' variants
        // as additional function definitions that jump to the real definition.
        const long_double_fn = @field(import, long_double_name);
        @export(long_double_fn, .{ .name = long_double_name, .linkage = linkage });
    } else {
        inline for (pairs) |pair| {
            const F = pair[0];
            const func = pair[1];
            if (builtin.target.longDoubleIs(F)) {
                @export(func, .{ .name = long_double_name, .linkage = linkage });
            }
        }
    }

    if (is_ppc) {
        // LLVM PPC backend lowers f128 ops with the suffix `f128` instead of `l`.
        @export(quad_fn, .{ .name = double_name ++ "f128", .linkage = linkage });
    }
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    _ = error_return_trace;
    @setCold(true);
    if (is_test) {
        std.debug.panic("{s}", .{msg});
    } else {
        unreachable;
    }
}
