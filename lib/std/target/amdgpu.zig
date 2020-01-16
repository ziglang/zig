const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_BitInsts16 = Feature{
    .name = "BitInsts16",
    .llvm_name = "16-bit-insts",
    .description = "Has i16/f16 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_addNoCarryInsts = Feature{
    .name = "addNoCarryInsts",
    .llvm_name = "add-no-carry-insts",
    .description = "Have VALU add/sub instructions without carry out",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_apertureRegs = Feature{
    .name = "apertureRegs",
    .llvm_name = "aperture-regs",
    .description = "Has Memory Aperture Base and Size Registers",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_atomicFaddInsts = Feature{
    .name = "atomicFaddInsts",
    .llvm_name = "atomic-fadd-insts",
    .description = "Has buffer_atomic_add_f32, buffer_atomic_pk_add_f16, global_atomic_add_f32, global_atomic_pk_add_f16 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_autoWaitcntBeforeBarrier = Feature{
    .name = "autoWaitcntBeforeBarrier",
    .llvm_name = "auto-waitcnt-before-barrier",
    .description = "Hardware automatically inserts waitcnt before barrier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ciInsts = Feature{
    .name = "ciInsts",
    .llvm_name = "ci-insts",
    .description = "Additional instructions for CI+",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_codeObjectV3 = Feature{
    .name = "codeObjectV3",
    .llvm_name = "code-object-v3",
    .description = "Generate code object version 3",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_cumode = Feature{
    .name = "cumode",
    .llvm_name = "cumode",
    .description = "Enable CU wavefront execution mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dlInsts = Feature{
    .name = "dlInsts",
    .llvm_name = "dl-insts",
    .description = "Has v_fmac_f32 and v_xnor_b32 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dpp = Feature{
    .name = "dpp",
    .llvm_name = "dpp",
    .description = "Support DPP (Data Parallel Primitives) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dpp8 = Feature{
    .name = "dpp8",
    .llvm_name = "dpp8",
    .description = "Support DPP8 (Data Parallel Primitives) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noSramEccSupport = Feature{
    .name = "noSramEccSupport",
    .llvm_name = "no-sram-ecc-support",
    .description = "Hardware does not support SRAM ECC",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noXnackSupport = Feature{
    .name = "noXnackSupport",
    .llvm_name = "no-xnack-support",
    .description = "Hardware does not support XNACK",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot1Insts = Feature{
    .name = "dot1Insts",
    .llvm_name = "dot1-insts",
    .description = "Has v_dot4_i32_i8 and v_dot8_i32_i4 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot2Insts = Feature{
    .name = "dot2Insts",
    .llvm_name = "dot2-insts",
    .description = "Has v_dot2_f32_f16, v_dot2_i32_i16, v_dot2_u32_u16, v_dot4_u32_u8, v_dot8_u32_u4 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot3Insts = Feature{
    .name = "dot3Insts",
    .llvm_name = "dot3-insts",
    .description = "Has v_dot8c_i32_i4 instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot4Insts = Feature{
    .name = "dot4Insts",
    .llvm_name = "dot4-insts",
    .description = "Has v_dot2c_i32_i16 instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot5Insts = Feature{
    .name = "dot5Insts",
    .llvm_name = "dot5-insts",
    .description = "Has v_dot2c_f32_f16 instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dot6Insts = Feature{
    .name = "dot6Insts",
    .llvm_name = "dot6-insts",
    .description = "Has v_dot4c_i32_i8 instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_DumpCode = Feature{
    .name = "DumpCode",
    .llvm_name = "DumpCode",
    .description = "Dump MachineInstrs in the CodeEmitter",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dumpcode = Feature{
    .name = "dumpcode",
    .llvm_name = "dumpcode",
    .description = "Dump MachineInstrs in the CodeEmitter",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_enableDs128 = Feature{
    .name = "enableDs128",
    .llvm_name = "enable-ds128",
    .description = "Use ds_{read|write}_b128",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_loadStoreOpt = Feature{
    .name = "loadStoreOpt",
    .llvm_name = "load-store-opt",
    .description = "Enable SI load/store optimizer pass",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_enablePrtStrictNull = Feature{
    .name = "enablePrtStrictNull",
    .llvm_name = "enable-prt-strict-null",
    .description = "Enable zeroing of result registers for sparse texture fetches",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_siScheduler = Feature{
    .name = "siScheduler",
    .llvm_name = "si-scheduler",
    .description = "Enable SI Machine Scheduler",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_unsafeDsOffsetFolding = Feature{
    .name = "unsafeDsOffsetFolding",
    .llvm_name = "unsafe-ds-offset-folding",
    .description = "Force using DS instruction immediate offsets on SI",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fmaf = Feature{
    .name = "fmaf",
    .llvm_name = "fmaf",
    .description = "Enable single precision FMA (not as fast as mul+add, but fused)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fp16Denormals = Feature{
    .name = "fp16Denormals",
    .llvm_name = "fp16-denormals",
    .description = "Enable half precision denormal handling",
    .dependencies = &[_]*const Feature {
        &feature_fp64,
    },
};

pub const feature_fp32Denormals = Feature{
    .name = "fp32Denormals",
    .llvm_name = "fp32-denormals",
    .description = "Enable single precision denormal handling",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fp64 = Feature{
    .name = "fp64",
    .llvm_name = "fp64",
    .description = "Enable double precision operations",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fp64Denormals = Feature{
    .name = "fp64Denormals",
    .llvm_name = "fp64-denormals",
    .description = "Enable double and half precision denormal handling",
    .dependencies = &[_]*const Feature {
        &feature_fp64,
    },
};

pub const feature_fp64Fp16Denormals = Feature{
    .name = "fp64Fp16Denormals",
    .llvm_name = "fp64-fp16-denormals",
    .description = "Enable double and half precision denormal handling",
    .dependencies = &[_]*const Feature {
        &feature_fp64,
    },
};

pub const feature_fpExceptions = Feature{
    .name = "fpExceptions",
    .llvm_name = "fp-exceptions",
    .description = "Enable floating point exceptions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastFmaf = Feature{
    .name = "fastFmaf",
    .llvm_name = "fast-fmaf",
    .description = "Assuming f32 fma is at least as fast as mul + add",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatAddressSpace = Feature{
    .name = "flatAddressSpace",
    .llvm_name = "flat-address-space",
    .description = "Support flat address space",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatForGlobal = Feature{
    .name = "flatForGlobal",
    .llvm_name = "flat-for-global",
    .description = "Force to generate flat instruction for global",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatGlobalInsts = Feature{
    .name = "flatGlobalInsts",
    .llvm_name = "flat-global-insts",
    .description = "Have global_* flat memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatInstOffsets = Feature{
    .name = "flatInstOffsets",
    .llvm_name = "flat-inst-offsets",
    .description = "Flat instructions have immediate offset addressing mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatScratchInsts = Feature{
    .name = "flatScratchInsts",
    .llvm_name = "flat-scratch-insts",
    .description = "Have scratch_* flat memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_flatSegmentOffsetBug = Feature{
    .name = "flatSegmentOffsetBug",
    .llvm_name = "flat-segment-offset-bug",
    .description = "GFX10 bug, inst_offset ignored in flat segment",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fmaMixInsts = Feature{
    .name = "fmaMixInsts",
    .llvm_name = "fma-mix-insts",
    .description = "Has v_fma_mix_f32, v_fma_mixlo_f16, v_fma_mixhi_f16 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gcn3Encoding = Feature{
    .name = "gcn3Encoding",
    .llvm_name = "gcn3-encoding",
    .description = "Encoding format for VI",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gfx7Gfx8Gfx9Insts = Feature{
    .name = "gfx7Gfx8Gfx9Insts",
    .llvm_name = "gfx7-gfx8-gfx9-insts",
    .description = "Instructions shared in GFX7, GFX8, GFX9",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gfx8Insts = Feature{
    .name = "gfx8Insts",
    .llvm_name = "gfx8-insts",
    .description = "Additional instructions for GFX8+",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gfx9Insts = Feature{
    .name = "gfx9Insts",
    .llvm_name = "gfx9-insts",
    .description = "Additional instructions for GFX9+",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gfx10Insts = Feature{
    .name = "gfx10Insts",
    .llvm_name = "gfx10-insts",
    .description = "Additional instructions for GFX10+",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_instFwdPrefetchBug = Feature{
    .name = "instFwdPrefetchBug",
    .llvm_name = "inst-fwd-prefetch-bug",
    .description = "S_INST_PREFETCH instruction causes shader to hang",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_intClampInsts = Feature{
    .name = "intClampInsts",
    .llvm_name = "int-clamp-insts",
    .description = "Support clamp for integer destination",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_inv2piInlineImm = Feature{
    .name = "inv2piInlineImm",
    .llvm_name = "inv-2pi-inline-imm",
    .description = "Has 1 / (2 * pi) as inline immediate",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ldsbankcount16 = Feature{
    .name = "ldsbankcount16",
    .llvm_name = "ldsbankcount16",
    .description = "The number of LDS banks per compute unit.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ldsbankcount32 = Feature{
    .name = "ldsbankcount32",
    .llvm_name = "ldsbankcount32",
    .description = "The number of LDS banks per compute unit.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ldsBranchVmemWarHazard = Feature{
    .name = "ldsBranchVmemWarHazard",
    .llvm_name = "lds-branch-vmem-war-hazard",
    .description = "Switching between LDS and VMEM-tex not waiting VM_VSRC=0",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ldsMisalignedBug = Feature{
    .name = "ldsMisalignedBug",
    .llvm_name = "lds-misaligned-bug",
    .description = "Some GFX10 bug with misaligned multi-dword LDS access in WGP mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_localmemorysize0 = Feature{
    .name = "localmemorysize0",
    .llvm_name = "localmemorysize0",
    .description = "The size of local memory in bytes",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_localmemorysize32768 = Feature{
    .name = "localmemorysize32768",
    .llvm_name = "localmemorysize32768",
    .description = "The size of local memory in bytes",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_localmemorysize65536 = Feature{
    .name = "localmemorysize65536",
    .llvm_name = "localmemorysize65536",
    .description = "The size of local memory in bytes",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_maiInsts = Feature{
    .name = "maiInsts",
    .llvm_name = "mai-insts",
    .description = "Has mAI instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mimgR128 = Feature{
    .name = "mimgR128",
    .llvm_name = "mimg-r128",
    .description = "Support 128-bit texture resources",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_madMixInsts = Feature{
    .name = "madMixInsts",
    .llvm_name = "mad-mix-insts",
    .description = "Has v_mad_mix_f32, v_mad_mixlo_f16, v_mad_mixhi_f16 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_maxPrivateElementSize4 = Feature{
    .name = "maxPrivateElementSize4",
    .llvm_name = "max-private-element-size-4",
    .description = "Maximum private access size may be 4",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_maxPrivateElementSize8 = Feature{
    .name = "maxPrivateElementSize8",
    .llvm_name = "max-private-element-size-8",
    .description = "Maximum private access size may be 8",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_maxPrivateElementSize16 = Feature{
    .name = "maxPrivateElementSize16",
    .llvm_name = "max-private-element-size-16",
    .description = "Maximum private access size may be 16",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_movrel = Feature{
    .name = "movrel",
    .llvm_name = "movrel",
    .description = "Has v_movrel*_b32 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nsaEncoding = Feature{
    .name = "nsaEncoding",
    .llvm_name = "nsa-encoding",
    .description = "Support NSA encoding for image instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nsaToVmemBug = Feature{
    .name = "nsaToVmemBug",
    .llvm_name = "nsa-to-vmem-bug",
    .description = "MIMG-NSA followed by VMEM fail if EXEC_LO or EXEC_HI equals zero",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noDataDepHazard = Feature{
    .name = "noDataDepHazard",
    .llvm_name = "no-data-dep-hazard",
    .description = "Does not need SW waitstates",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noSdstCmpx = Feature{
    .name = "noSdstCmpx",
    .llvm_name = "no-sdst-cmpx",
    .description = "V_CMPX does not write VCC/SGPR in addition to EXEC",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_offset3fBug = Feature{
    .name = "offset3fBug",
    .llvm_name = "offset-3f-bug",
    .description = "Branch offset of 3f hardware bug",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_pkFmacF16Inst = Feature{
    .name = "pkFmacF16Inst",
    .llvm_name = "pk-fmac-f16-inst",
    .description = "Has v_pk_fmac_f16 instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_promoteAlloca = Feature{
    .name = "promoteAlloca",
    .llvm_name = "promote-alloca",
    .description = "Enable promote alloca pass",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_r128A16 = Feature{
    .name = "r128A16",
    .llvm_name = "r128-a16",
    .description = "Support 16 bit coordindates/gradients/lod/clamp/mip types on gfx9",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_registerBanking = Feature{
    .name = "registerBanking",
    .llvm_name = "register-banking",
    .description = "Has register banking",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwa = Feature{
    .name = "sdwa",
    .llvm_name = "sdwa",
    .description = "Support SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwaMav = Feature{
    .name = "sdwaMav",
    .llvm_name = "sdwa-mav",
    .description = "Support v_mac_f32/f16 with SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwaOmod = Feature{
    .name = "sdwaOmod",
    .llvm_name = "sdwa-omod",
    .description = "Support OMod with SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwaOutModsVopc = Feature{
    .name = "sdwaOutModsVopc",
    .llvm_name = "sdwa-out-mods-vopc",
    .description = "Support clamp for VOPC with SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwaScalar = Feature{
    .name = "sdwaScalar",
    .llvm_name = "sdwa-scalar",
    .description = "Support scalar register with SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sdwaSdst = Feature{
    .name = "sdwaSdst",
    .llvm_name = "sdwa-sdst",
    .description = "Support scalar dst for VOPC with SDWA (Sub-DWORD Addressing) extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sgprInitBug = Feature{
    .name = "sgprInitBug",
    .llvm_name = "sgpr-init-bug",
    .description = "VI SGPR initialization bug requiring a fixed SGPR allocation size",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_smemToVectorWriteHazard = Feature{
    .name = "smemToVectorWriteHazard",
    .llvm_name = "smem-to-vector-write-hazard",
    .description = "s_load_dword followed by v_cmp page faults",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sMemrealtime = Feature{
    .name = "sMemrealtime",
    .llvm_name = "s-memrealtime",
    .description = "Has s_memrealtime instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sramEcc = Feature{
    .name = "sramEcc",
    .llvm_name = "sram-ecc",
    .description = "Enable SRAM ECC",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_scalarAtomics = Feature{
    .name = "scalarAtomics",
    .llvm_name = "scalar-atomics",
    .description = "Has atomic scalar memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_scalarFlatScratchInsts = Feature{
    .name = "scalarFlatScratchInsts",
    .llvm_name = "scalar-flat-scratch-insts",
    .description = "Have s_scratch_* flat memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_scalarStores = Feature{
    .name = "scalarStores",
    .llvm_name = "scalar-stores",
    .description = "Has store scalar memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_trapHandler = Feature{
    .name = "trapHandler",
    .llvm_name = "trap-handler",
    .description = "Trap handler support",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_trigReducedRange = Feature{
    .name = "trigReducedRange",
    .llvm_name = "trig-reduced-range",
    .description = "Requires use of fract on arguments to trig instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_unalignedBufferAccess = Feature{
    .name = "unalignedBufferAccess",
    .llvm_name = "unaligned-buffer-access",
    .description = "Support unaligned global loads and stores",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_unalignedScratchAccess = Feature{
    .name = "unalignedScratchAccess",
    .llvm_name = "unaligned-scratch-access",
    .description = "Support unaligned scratch loads and stores",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_unpackedD16Vmem = Feature{
    .name = "unpackedD16Vmem",
    .llvm_name = "unpacked-d16-vmem",
    .description = "Has unpacked d16 vmem instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vgprIndexMode = Feature{
    .name = "vgprIndexMode",
    .llvm_name = "vgpr-index-mode",
    .description = "Has VGPR mode register indexing",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vmemToScalarWriteHazard = Feature{
    .name = "vmemToScalarWriteHazard",
    .llvm_name = "vmem-to-scalar-write-hazard",
    .description = "VMEM instruction followed by scalar writing to EXEC mask, M0 or SGPR leads to incorrect execution.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vop3Literal = Feature{
    .name = "vop3Literal",
    .llvm_name = "vop3-literal",
    .description = "Can use one literal in VOP3",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vop3p = Feature{
    .name = "vop3p",
    .llvm_name = "vop3p",
    .description = "Has VOP3P packed instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vcmpxExecWarHazard = Feature{
    .name = "vcmpxExecWarHazard",
    .llvm_name = "vcmpx-exec-war-hazard",
    .description = "V_CMPX WAR hazard on EXEC (V_CMPX issue ONLY)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vcmpxPermlaneHazard = Feature{
    .name = "vcmpxPermlaneHazard",
    .llvm_name = "vcmpx-permlane-hazard",
    .description = "TODO: describe me",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vscnt = Feature{
    .name = "vscnt",
    .llvm_name = "vscnt",
    .description = "Has separate store vscnt counter",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_wavefrontsize16 = Feature{
    .name = "wavefrontsize16",
    .llvm_name = "wavefrontsize16",
    .description = "The number of threads per wavefront",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_wavefrontsize32 = Feature{
    .name = "wavefrontsize32",
    .llvm_name = "wavefrontsize32",
    .description = "The number of threads per wavefront",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_wavefrontsize64 = Feature{
    .name = "wavefrontsize64",
    .llvm_name = "wavefrontsize64",
    .description = "The number of threads per wavefront",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_xnack = Feature{
    .name = "xnack",
    .llvm_name = "xnack",
    .description = "Enable XNACK support",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_halfRate64Ops = Feature{
    .name = "halfRate64Ops",
    .llvm_name = "half-rate-64-ops",
    .description = "Most fp64 instructions are half rate instead of quarter",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_BitInsts16,
    &feature_addNoCarryInsts,
    &feature_apertureRegs,
    &feature_atomicFaddInsts,
    &feature_autoWaitcntBeforeBarrier,
    &feature_ciInsts,
    &feature_codeObjectV3,
    &feature_cumode,
    &feature_dlInsts,
    &feature_dpp,
    &feature_dpp8,
    &feature_noSramEccSupport,
    &feature_noXnackSupport,
    &feature_dot1Insts,
    &feature_dot2Insts,
    &feature_dot3Insts,
    &feature_dot4Insts,
    &feature_dot5Insts,
    &feature_dot6Insts,
    &feature_DumpCode,
    &feature_dumpcode,
    &feature_enableDs128,
    &feature_loadStoreOpt,
    &feature_enablePrtStrictNull,
    &feature_siScheduler,
    &feature_unsafeDsOffsetFolding,
    &feature_fmaf,
    &feature_fp16Denormals,
    &feature_fp32Denormals,
    &feature_fp64,
    &feature_fp64Denormals,
    &feature_fp64Fp16Denormals,
    &feature_fpExceptions,
    &feature_fastFmaf,
    &feature_flatAddressSpace,
    &feature_flatForGlobal,
    &feature_flatGlobalInsts,
    &feature_flatInstOffsets,
    &feature_flatScratchInsts,
    &feature_flatSegmentOffsetBug,
    &feature_fmaMixInsts,
    &feature_gcn3Encoding,
    &feature_gfx7Gfx8Gfx9Insts,
    &feature_gfx8Insts,
    &feature_gfx9Insts,
    &feature_gfx10Insts,
    &feature_instFwdPrefetchBug,
    &feature_intClampInsts,
    &feature_inv2piInlineImm,
    &feature_ldsbankcount16,
    &feature_ldsbankcount32,
    &feature_ldsBranchVmemWarHazard,
    &feature_ldsMisalignedBug,
    &feature_localmemorysize0,
    &feature_localmemorysize32768,
    &feature_localmemorysize65536,
    &feature_maiInsts,
    &feature_mimgR128,
    &feature_madMixInsts,
    &feature_maxPrivateElementSize4,
    &feature_maxPrivateElementSize8,
    &feature_maxPrivateElementSize16,
    &feature_movrel,
    &feature_nsaEncoding,
    &feature_nsaToVmemBug,
    &feature_noDataDepHazard,
    &feature_noSdstCmpx,
    &feature_offset3fBug,
    &feature_pkFmacF16Inst,
    &feature_promoteAlloca,
    &feature_r128A16,
    &feature_registerBanking,
    &feature_sdwa,
    &feature_sdwaMav,
    &feature_sdwaOmod,
    &feature_sdwaOutModsVopc,
    &feature_sdwaScalar,
    &feature_sdwaSdst,
    &feature_sgprInitBug,
    &feature_smemToVectorWriteHazard,
    &feature_sMemrealtime,
    &feature_sramEcc,
    &feature_scalarAtomics,
    &feature_scalarFlatScratchInsts,
    &feature_scalarStores,
    &feature_trapHandler,
    &feature_trigReducedRange,
    &feature_unalignedBufferAccess,
    &feature_unalignedScratchAccess,
    &feature_unpackedD16Vmem,
    &feature_vgprIndexMode,
    &feature_vmemToScalarWriteHazard,
    &feature_vop3Literal,
    &feature_vop3p,
    &feature_vcmpxExecWarHazard,
    &feature_vcmpxPermlaneHazard,
    &feature_vscnt,
    &feature_wavefrontsize16,
    &feature_wavefrontsize32,
    &feature_wavefrontsize64,
    &feature_xnack,
    &feature_halfRate64Ops,
};

pub const cpu_bonaire = Cpu{
    .name = "bonaire",
    .llvm_name = "bonaire",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_carrizo = Cpu{
    .name = "carrizo",
    .llvm_name = "carrizo",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_xnack,
        &feature_halfRate64Ops,
    },
};

pub const cpu_fiji = Cpu{
    .name = "fiji",
    .llvm_name = "fiji",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
        &feature_wavefrontsize64,
    },
};

pub const cpu_genericHsa = Cpu{
    .name = "genericHsa",
    .llvm_name = "generic-hsa",
    .dependencies = &[_]*const Feature {
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
    },
};

pub const cpu_gfx1010 = Cpu{
    .name = "gfx1010",
    .llvm_name = "gfx1010",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_dlInsts,
        &feature_noXnackSupport,
        &feature_flatSegmentOffsetBug,
        &feature_fmaMixInsts,
        &feature_movrel,
        &feature_registerBanking,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_mimgR128,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_noSdstCmpx,
        &feature_vop3p,
        &feature_sdwa,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_noDataDepHazard,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_sMemrealtime,
        &feature_pkFmacF16Inst,
        &feature_dpp8,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_noSramEccSupport,
        &feature_gfx10Insts,
        &feature_localmemorysize65536,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_vop3Literal,
        &feature_sdwaOmod,
        &feature_vscnt,
        &feature_instFwdPrefetchBug,
        &feature_ldsbankcount32,
        &feature_ldsBranchVmemWarHazard,
        &feature_ldsMisalignedBug,
        &feature_nsaEncoding,
        &feature_nsaToVmemBug,
        &feature_offset3fBug,
        &feature_smemToVectorWriteHazard,
        &feature_scalarAtomics,
        &feature_scalarFlatScratchInsts,
        &feature_scalarStores,
        &feature_vmemToScalarWriteHazard,
        &feature_vcmpxExecWarHazard,
        &feature_vcmpxPermlaneHazard,
        &feature_wavefrontsize32,
    },
};

pub const cpu_gfx1011 = Cpu{
    .name = "gfx1011",
    .llvm_name = "gfx1011",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_dlInsts,
        &feature_noXnackSupport,
        &feature_dot1Insts,
        &feature_dot2Insts,
        &feature_dot5Insts,
        &feature_dot6Insts,
        &feature_flatSegmentOffsetBug,
        &feature_fmaMixInsts,
        &feature_movrel,
        &feature_registerBanking,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_mimgR128,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_noSdstCmpx,
        &feature_vop3p,
        &feature_sdwa,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_noDataDepHazard,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_sMemrealtime,
        &feature_pkFmacF16Inst,
        &feature_dpp8,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_noSramEccSupport,
        &feature_gfx10Insts,
        &feature_localmemorysize65536,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_vop3Literal,
        &feature_sdwaOmod,
        &feature_vscnt,
        &feature_instFwdPrefetchBug,
        &feature_ldsbankcount32,
        &feature_ldsBranchVmemWarHazard,
        &feature_nsaEncoding,
        &feature_nsaToVmemBug,
        &feature_offset3fBug,
        &feature_smemToVectorWriteHazard,
        &feature_scalarAtomics,
        &feature_scalarFlatScratchInsts,
        &feature_scalarStores,
        &feature_vmemToScalarWriteHazard,
        &feature_vcmpxExecWarHazard,
        &feature_vcmpxPermlaneHazard,
        &feature_wavefrontsize32,
    },
};

pub const cpu_gfx1012 = Cpu{
    .name = "gfx1012",
    .llvm_name = "gfx1012",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_dlInsts,
        &feature_noXnackSupport,
        &feature_dot1Insts,
        &feature_dot2Insts,
        &feature_dot5Insts,
        &feature_dot6Insts,
        &feature_flatSegmentOffsetBug,
        &feature_fmaMixInsts,
        &feature_movrel,
        &feature_registerBanking,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_mimgR128,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_noSdstCmpx,
        &feature_vop3p,
        &feature_sdwa,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_noDataDepHazard,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_sMemrealtime,
        &feature_pkFmacF16Inst,
        &feature_dpp8,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_noSramEccSupport,
        &feature_gfx10Insts,
        &feature_localmemorysize65536,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_vop3Literal,
        &feature_sdwaOmod,
        &feature_vscnt,
        &feature_instFwdPrefetchBug,
        &feature_ldsbankcount32,
        &feature_ldsBranchVmemWarHazard,
        &feature_ldsMisalignedBug,
        &feature_nsaEncoding,
        &feature_nsaToVmemBug,
        &feature_offset3fBug,
        &feature_smemToVectorWriteHazard,
        &feature_scalarAtomics,
        &feature_scalarFlatScratchInsts,
        &feature_scalarStores,
        &feature_vmemToScalarWriteHazard,
        &feature_vcmpxExecWarHazard,
        &feature_vcmpxPermlaneHazard,
        &feature_wavefrontsize32,
    },
};

pub const cpu_gfx600 = Cpu{
    .name = "gfx600",
    .llvm_name = "gfx600",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
        &feature_halfRate64Ops,
    },
};

pub const cpu_gfx601 = Cpu{
    .name = "gfx601",
    .llvm_name = "gfx601",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
    },
};

pub const cpu_gfx700 = Cpu{
    .name = "gfx700",
    .llvm_name = "gfx700",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_gfx701 = Cpu{
    .name = "gfx701",
    .llvm_name = "gfx701",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
        &feature_halfRate64Ops,
    },
};

pub const cpu_gfx702 = Cpu{
    .name = "gfx702",
    .llvm_name = "gfx702",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_fastFmaf,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_gfx703 = Cpu{
    .name = "gfx703",
    .llvm_name = "gfx703",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_gfx704 = Cpu{
    .name = "gfx704",
    .llvm_name = "gfx704",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_gfx801 = Cpu{
    .name = "gfx801",
    .llvm_name = "gfx801",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_xnack,
        &feature_halfRate64Ops,
    },
};

pub const cpu_gfx802 = Cpu{
    .name = "gfx802",
    .llvm_name = "gfx802",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_sgprInitBug,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_gfx803 = Cpu{
    .name = "gfx803",
    .llvm_name = "gfx803",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_gfx810 = Cpu{
    .name = "gfx810",
    .llvm_name = "gfx810",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_xnack,
    },
};

pub const cpu_gfx900 = Cpu{
    .name = "gfx900",
    .llvm_name = "gfx900",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noSramEccSupport,
        &feature_noXnackSupport,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
        &feature_madMixInsts,
    },
};

pub const cpu_gfx902 = Cpu{
    .name = "gfx902",
    .llvm_name = "gfx902",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noSramEccSupport,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
        &feature_madMixInsts,
        &feature_xnack,
    },
};

pub const cpu_gfx904 = Cpu{
    .name = "gfx904",
    .llvm_name = "gfx904",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noSramEccSupport,
        &feature_noXnackSupport,
        &feature_fmaMixInsts,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
    },
};

pub const cpu_gfx906 = Cpu{
    .name = "gfx906",
    .llvm_name = "gfx906",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_dlInsts,
        &feature_noXnackSupport,
        &feature_dot1Insts,
        &feature_dot2Insts,
        &feature_fmaMixInsts,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
        &feature_halfRate64Ops,
    },
};

pub const cpu_gfx908 = Cpu{
    .name = "gfx908",
    .llvm_name = "gfx908",
    .dependencies = &[_]*const Feature {
        &feature_atomicFaddInsts,
        &feature_codeObjectV3,
        &feature_dlInsts,
        &feature_dot1Insts,
        &feature_dot2Insts,
        &feature_dot3Insts,
        &feature_dot4Insts,
        &feature_dot5Insts,
        &feature_dot6Insts,
        &feature_fmaMixInsts,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
        &feature_maiInsts,
        &feature_pkFmacF16Inst,
        &feature_sramEcc,
        &feature_halfRate64Ops,
    },
};

pub const cpu_gfx909 = Cpu{
    .name = "gfx909",
    .llvm_name = "gfx909",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_vgprIndexMode,
        &feature_addNoCarryInsts,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_sdwaScalar,
        &feature_flatGlobalInsts,
        &feature_scalarFlatScratchInsts,
        &feature_flatInstOffsets,
        &feature_apertureRegs,
        &feature_vop3p,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_sdwaSdst,
        &feature_flatScratchInsts,
        &feature_ciInsts,
        &feature_r128A16,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_scalarAtomics,
        &feature_inv2piInlineImm,
        &feature_fastFmaf,
        &feature_wavefrontsize64,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx9Insts,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_sdwaOmod,
        &feature_ldsbankcount32,
        &feature_madMixInsts,
        &feature_xnack,
    },
};

pub const cpu_hainan = Cpu{
    .name = "hainan",
    .llvm_name = "hainan",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
    },
};

pub const cpu_hawaii = Cpu{
    .name = "hawaii",
    .llvm_name = "hawaii",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
        &feature_halfRate64Ops,
    },
};

pub const cpu_iceland = Cpu{
    .name = "iceland",
    .llvm_name = "iceland",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_sgprInitBug,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_kabini = Cpu{
    .name = "kabini",
    .llvm_name = "kabini",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_kaveri = Cpu{
    .name = "kaveri",
    .llvm_name = "kaveri",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_mullins = Cpu{
    .name = "mullins",
    .llvm_name = "mullins",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_movrel,
        &feature_flatAddressSpace,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_ciInsts,
        &feature_localmemorysize65536,
    },
};

pub const cpu_oland = Cpu{
    .name = "oland",
    .llvm_name = "oland",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
    },
};

pub const cpu_pitcairn = Cpu{
    .name = "pitcairn",
    .llvm_name = "pitcairn",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
    },
};

pub const cpu_polaris10 = Cpu{
    .name = "polaris10",
    .llvm_name = "polaris10",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_polaris11 = Cpu{
    .name = "polaris11",
    .llvm_name = "polaris11",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_stoney = Cpu{
    .name = "stoney",
    .llvm_name = "stoney",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_ldsbankcount16,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
        &feature_xnack,
    },
};

pub const cpu_tahiti = Cpu{
    .name = "tahiti",
    .llvm_name = "tahiti",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_fastFmaf,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
        &feature_halfRate64Ops,
    },
};

pub const cpu_tonga = Cpu{
    .name = "tonga",
    .llvm_name = "tonga",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_sgprInitBug,
        &feature_unpackedD16Vmem,
        &feature_trigReducedRange,
        &feature_vgprIndexMode,
        &feature_movrel,
        &feature_fp64,
        &feature_gcn3Encoding,
        &feature_mimgR128,
        &feature_sdwa,
        &feature_gfx7Gfx8Gfx9Insts,
        &feature_intClampInsts,
        &feature_ciInsts,
        &feature_sdwaOutModsVopc,
        &feature_sMemrealtime,
        &feature_flatAddressSpace,
        &feature_inv2piInlineImm,
        &feature_wavefrontsize64,
        &feature_noSramEccSupport,
        &feature_sdwaMav,
        &feature_localmemorysize65536,
        &feature_scalarStores,
        &feature_gfx8Insts,
        &feature_dpp,
        &feature_BitInsts16,
    },
};

pub const cpu_verde = Cpu{
    .name = "verde",
    .llvm_name = "verde",
    .dependencies = &[_]*const Feature {
        &feature_codeObjectV3,
        &feature_noXnackSupport,
        &feature_ldsbankcount32,
        &feature_trigReducedRange,
        &feature_movrel,
        &feature_wavefrontsize64,
        &feature_fp64,
        &feature_mimgR128,
        &feature_noSramEccSupport,
        &feature_localmemorysize32768,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_bonaire,
    &cpu_carrizo,
    &cpu_fiji,
    &cpu_generic,
    &cpu_genericHsa,
    &cpu_gfx1010,
    &cpu_gfx1011,
    &cpu_gfx1012,
    &cpu_gfx600,
    &cpu_gfx601,
    &cpu_gfx700,
    &cpu_gfx701,
    &cpu_gfx702,
    &cpu_gfx703,
    &cpu_gfx704,
    &cpu_gfx801,
    &cpu_gfx802,
    &cpu_gfx803,
    &cpu_gfx810,
    &cpu_gfx900,
    &cpu_gfx902,
    &cpu_gfx904,
    &cpu_gfx906,
    &cpu_gfx908,
    &cpu_gfx909,
    &cpu_hainan,
    &cpu_hawaii,
    &cpu_iceland,
    &cpu_kabini,
    &cpu_kaveri,
    &cpu_mullins,
    &cpu_oland,
    &cpu_pitcairn,
    &cpu_polaris10,
    &cpu_polaris11,
    &cpu_stoney,
    &cpu_tahiti,
    &cpu_tonga,
    &cpu_verde,
};
