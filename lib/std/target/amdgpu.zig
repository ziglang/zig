const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    @"16_bit_insts",
    DumpCode,
    add_no_carry_insts,
    aperture_regs,
    atomic_fadd_insts,
    auto_waitcnt_before_barrier,
    ci_insts,
    code_object_v3,
    cumode,
    dl_insts,
    dot1_insts,
    dot2_insts,
    dot3_insts,
    dot4_insts,
    dot5_insts,
    dot6_insts,
    dpp,
    dpp8,
    dumpcode,
    enable_ds128,
    enable_prt_strict_null,
    fast_fmaf,
    flat_address_space,
    flat_for_global,
    flat_global_insts,
    flat_inst_offsets,
    flat_scratch_insts,
    flat_segment_offset_bug,
    fma_mix_insts,
    fmaf,
    fp_exceptions,
    fp16_denormals,
    fp32_denormals,
    fp64,
    fp64_denormals,
    fp64_fp16_denormals,
    gcn3_encoding,
    gfx10,
    gfx10_insts,
    gfx7_gfx8_gfx9_insts,
    gfx8_insts,
    gfx9,
    gfx9_insts,
    half_rate_64_ops,
    inst_fwd_prefetch_bug,
    int_clamp_insts,
    inv_2pi_inline_imm,
    lds_branch_vmem_war_hazard,
    lds_misaligned_bug,
    ldsbankcount16,
    ldsbankcount32,
    load_store_opt,
    localmemorysize0,
    localmemorysize32768,
    localmemorysize65536,
    mad_mix_insts,
    mai_insts,
    max_private_element_size_16,
    max_private_element_size_4,
    max_private_element_size_8,
    mfma_inline_literal_bug,
    mimg_r128,
    movrel,
    no_data_dep_hazard,
    no_sdst_cmpx,
    no_sram_ecc_support,
    no_xnack_support,
    nsa_encoding,
    nsa_to_vmem_bug,
    offset_3f_bug,
    pk_fmac_f16_inst,
    promote_alloca,
    r128_a16,
    register_banking,
    s_memrealtime,
    scalar_atomics,
    scalar_flat_scratch_insts,
    scalar_stores,
    sdwa,
    sdwa_mav,
    sdwa_omod,
    sdwa_out_mods_vopc,
    sdwa_scalar,
    sdwa_sdst,
    sea_islands,
    sgpr_init_bug,
    si_scheduler,
    smem_to_vector_write_hazard,
    southern_islands,
    sram_ecc,
    trap_handler,
    trig_reduced_range,
    unaligned_buffer_access,
    unaligned_scratch_access,
    unpacked_d16_vmem,
    unsafe_ds_offset_folding,
    vcmpx_exec_war_hazard,
    vcmpx_permlane_hazard,
    vgpr_index_mode,
    vmem_to_scalar_write_hazard,
    volcanic_islands,
    vop3_literal,
    vop3p,
    vscnt,
    wavefrontsize16,
    wavefrontsize32,
    wavefrontsize64,
    xnack,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.@"16_bit_insts")] = .{
        .llvm_name = "16-bit-insts",
        .description = "Has i16/f16 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.DumpCode)] = .{
        .llvm_name = "DumpCode",
        .description = "Dump MachineInstrs in the CodeEmitter",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.add_no_carry_insts)] = .{
        .llvm_name = "add-no-carry-insts",
        .description = "Have VALU add/sub instructions without carry out",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.aperture_regs)] = .{
        .llvm_name = "aperture-regs",
        .description = "Has Memory Aperture Base and Size Registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.atomic_fadd_insts)] = .{
        .llvm_name = "atomic-fadd-insts",
        .description = "Has buffer_atomic_add_f32, buffer_atomic_pk_add_f16, global_atomic_add_f32, global_atomic_pk_add_f16 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.auto_waitcnt_before_barrier)] = .{
        .llvm_name = "auto-waitcnt-before-barrier",
        .description = "Hardware automatically inserts waitcnt before barrier",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ci_insts)] = .{
        .llvm_name = "ci-insts",
        .description = "Additional instructions for CI+",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.code_object_v3)] = .{
        .llvm_name = "code-object-v3",
        .description = "Generate code object version 3",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.cumode)] = .{
        .llvm_name = "cumode",
        .description = "Enable CU wavefront execution mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dl_insts)] = .{
        .llvm_name = "dl-insts",
        .description = "Has v_fmac_f32 and v_xnor_b32 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot1_insts)] = .{
        .llvm_name = "dot1-insts",
        .description = "Has v_dot4_i32_i8 and v_dot8_i32_i4 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot2_insts)] = .{
        .llvm_name = "dot2-insts",
        .description = "Has v_dot2_f32_f16, v_dot2_i32_i16, v_dot2_u32_u16, v_dot4_u32_u8, v_dot8_u32_u4 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot3_insts)] = .{
        .llvm_name = "dot3-insts",
        .description = "Has v_dot8c_i32_i4 instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot4_insts)] = .{
        .llvm_name = "dot4-insts",
        .description = "Has v_dot2c_i32_i16 instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot5_insts)] = .{
        .llvm_name = "dot5-insts",
        .description = "Has v_dot2c_f32_f16 instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dot6_insts)] = .{
        .llvm_name = "dot6-insts",
        .description = "Has v_dot4c_i32_i8 instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dpp)] = .{
        .llvm_name = "dpp",
        .description = "Support DPP (Data Parallel Primitives) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dpp8)] = .{
        .llvm_name = "dpp8",
        .description = "Support DPP8 (Data Parallel Primitives) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dumpcode)] = .{
        .llvm_name = "dumpcode",
        .description = "Dump MachineInstrs in the CodeEmitter",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.enable_ds128)] = .{
        .llvm_name = "enable-ds128",
        .description = "Use ds_read|write_b128",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.enable_prt_strict_null)] = .{
        .llvm_name = "enable-prt-strict-null",
        .description = "Enable zeroing of result registers for sparse texture fetches",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fast_fmaf)] = .{
        .llvm_name = "fast-fmaf",
        .description = "Assuming f32 fma is at least as fast as mul + add",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_address_space)] = .{
        .llvm_name = "flat-address-space",
        .description = "Support flat address space",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_for_global)] = .{
        .llvm_name = "flat-for-global",
        .description = "Force to generate flat instruction for global",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_global_insts)] = .{
        .llvm_name = "flat-global-insts",
        .description = "Have global_* flat memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_inst_offsets)] = .{
        .llvm_name = "flat-inst-offsets",
        .description = "Flat instructions have immediate offset addressing mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_scratch_insts)] = .{
        .llvm_name = "flat-scratch-insts",
        .description = "Have scratch_* flat memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.flat_segment_offset_bug)] = .{
        .llvm_name = "flat-segment-offset-bug",
        .description = "GFX10 bug, inst_offset ignored in flat segment",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fma_mix_insts)] = .{
        .llvm_name = "fma-mix-insts",
        .description = "Has v_fma_mix_f32, v_fma_mixlo_f16, v_fma_mixhi_f16 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fmaf)] = .{
        .llvm_name = "fmaf",
        .description = "Enable single precision FMA (not as fast as mul+add, but fused)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp_exceptions)] = .{
        .llvm_name = "fp-exceptions",
        .description = "Enable floating point exceptions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp16_denormals)] = .{
        .llvm_name = "fp16-denormals",
        .description = "Enable half precision denormal handling",
        .dependencies = featureSet(&[_]Feature{
            .fp64_fp16_denormals,
        }),
    };
    result[@enumToInt(Feature.fp32_denormals)] = .{
        .llvm_name = "fp32-denormals",
        .description = "Enable single precision denormal handling",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp64)] = .{
        .llvm_name = "fp64",
        .description = "Enable double precision operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp64_denormals)] = .{
        .llvm_name = "fp64-denormals",
        .description = "Enable double and half precision denormal handling",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .fp64_fp16_denormals,
        }),
    };
    result[@enumToInt(Feature.fp64_fp16_denormals)] = .{
        .llvm_name = "fp64-fp16-denormals",
        .description = "Enable double and half precision denormal handling",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
        }),
    };
    result[@enumToInt(Feature.gcn3_encoding)] = .{
        .llvm_name = "gcn3-encoding",
        .description = "Encoding format for VI",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.gfx10)] = .{
        .llvm_name = "gfx10",
        .description = "GFX10 GPU generation",
        .dependencies = featureSet(&[_]Feature{
            .@"16_bit_insts",
            .add_no_carry_insts,
            .aperture_regs,
            .ci_insts,
            .dpp,
            .dpp8,
            .fast_fmaf,
            .flat_address_space,
            .flat_global_insts,
            .flat_inst_offsets,
            .flat_scratch_insts,
            .fma_mix_insts,
            .fp64,
            .gfx10_insts,
            .gfx8_insts,
            .gfx9_insts,
            .int_clamp_insts,
            .inv_2pi_inline_imm,
            .localmemorysize65536,
            .mimg_r128,
            .movrel,
            .no_data_dep_hazard,
            .no_sdst_cmpx,
            .no_sram_ecc_support,
            .pk_fmac_f16_inst,
            .register_banking,
            .s_memrealtime,
            .sdwa,
            .sdwa_omod,
            .sdwa_scalar,
            .sdwa_sdst,
            .vop3_literal,
            .vop3p,
            .vscnt,
        }),
    };
    result[@enumToInt(Feature.gfx10_insts)] = .{
        .llvm_name = "gfx10-insts",
        .description = "Additional instructions for GFX10+",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.gfx7_gfx8_gfx9_insts)] = .{
        .llvm_name = "gfx7-gfx8-gfx9-insts",
        .description = "Instructions shared in GFX7, GFX8, GFX9",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.gfx8_insts)] = .{
        .llvm_name = "gfx8-insts",
        .description = "Additional instructions for GFX8+",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.gfx9)] = .{
        .llvm_name = "gfx9",
        .description = "GFX9 GPU generation",
        .dependencies = featureSet(&[_]Feature{
            .@"16_bit_insts",
            .add_no_carry_insts,
            .aperture_regs,
            .ci_insts,
            .dpp,
            .fast_fmaf,
            .flat_address_space,
            .flat_global_insts,
            .flat_inst_offsets,
            .flat_scratch_insts,
            .fp64,
            .gcn3_encoding,
            .gfx7_gfx8_gfx9_insts,
            .gfx8_insts,
            .gfx9_insts,
            .int_clamp_insts,
            .inv_2pi_inline_imm,
            .localmemorysize65536,
            .r128_a16,
            .s_memrealtime,
            .scalar_atomics,
            .scalar_flat_scratch_insts,
            .scalar_stores,
            .sdwa,
            .sdwa_omod,
            .sdwa_scalar,
            .sdwa_sdst,
            .vgpr_index_mode,
            .vop3p,
            .wavefrontsize64,
        }),
    };
    result[@enumToInt(Feature.gfx9_insts)] = .{
        .llvm_name = "gfx9-insts",
        .description = "Additional instructions for GFX9+",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.half_rate_64_ops)] = .{
        .llvm_name = "half-rate-64-ops",
        .description = "Most fp64 instructions are half rate instead of quarter",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.inst_fwd_prefetch_bug)] = .{
        .llvm_name = "inst-fwd-prefetch-bug",
        .description = "S_INST_PREFETCH instruction causes shader to hang",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.int_clamp_insts)] = .{
        .llvm_name = "int-clamp-insts",
        .description = "Support clamp for integer destination",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.inv_2pi_inline_imm)] = .{
        .llvm_name = "inv-2pi-inline-imm",
        .description = "Has 1 / (2 * pi) as inline immediate",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lds_branch_vmem_war_hazard)] = .{
        .llvm_name = "lds-branch-vmem-war-hazard",
        .description = "Switching between LDS and VMEM-tex not waiting VM_VSRC=0",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lds_misaligned_bug)] = .{
        .llvm_name = "lds-misaligned-bug",
        .description = "Some GFX10 bug with misaligned multi-dword LDS access in WGP mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ldsbankcount16)] = .{
        .llvm_name = "ldsbankcount16",
        .description = "The number of LDS banks per compute unit.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ldsbankcount32)] = .{
        .llvm_name = "ldsbankcount32",
        .description = "The number of LDS banks per compute unit.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.load_store_opt)] = .{
        .llvm_name = "load-store-opt",
        .description = "Enable SI load/store optimizer pass",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.localmemorysize0)] = .{
        .llvm_name = "localmemorysize0",
        .description = "The size of local memory in bytes",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.localmemorysize32768)] = .{
        .llvm_name = "localmemorysize32768",
        .description = "The size of local memory in bytes",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.localmemorysize65536)] = .{
        .llvm_name = "localmemorysize65536",
        .description = "The size of local memory in bytes",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mad_mix_insts)] = .{
        .llvm_name = "mad-mix-insts",
        .description = "Has v_mad_mix_f32, v_mad_mixlo_f16, v_mad_mixhi_f16 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mai_insts)] = .{
        .llvm_name = "mai-insts",
        .description = "Has mAI instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.max_private_element_size_16)] = .{
        .llvm_name = "max-private-element-size-16",
        .description = "Maximum private access size may be 16",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.max_private_element_size_4)] = .{
        .llvm_name = "max-private-element-size-4",
        .description = "Maximum private access size may be 4",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.max_private_element_size_8)] = .{
        .llvm_name = "max-private-element-size-8",
        .description = "Maximum private access size may be 8",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mfma_inline_literal_bug)] = .{
        .llvm_name = "mfma-inline-literal-bug",
        .description = "MFMA cannot use inline literal as SrcC",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mimg_r128)] = .{
        .llvm_name = "mimg-r128",
        .description = "Support 128-bit texture resources",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.movrel)] = .{
        .llvm_name = "movrel",
        .description = "Has v_movrel*_b32 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_data_dep_hazard)] = .{
        .llvm_name = "no-data-dep-hazard",
        .description = "Does not need SW waitstates",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_sdst_cmpx)] = .{
        .llvm_name = "no-sdst-cmpx",
        .description = "V_CMPX does not write VCC/SGPR in addition to EXEC",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_sram_ecc_support)] = .{
        .llvm_name = "no-sram-ecc-support",
        .description = "Hardware does not support SRAM ECC",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_xnack_support)] = .{
        .llvm_name = "no-xnack-support",
        .description = "Hardware does not support XNACK",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nsa_encoding)] = .{
        .llvm_name = "nsa-encoding",
        .description = "Support NSA encoding for image instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nsa_to_vmem_bug)] = .{
        .llvm_name = "nsa-to-vmem-bug",
        .description = "MIMG-NSA followed by VMEM fail if EXEC_LO or EXEC_HI equals zero",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.offset_3f_bug)] = .{
        .llvm_name = "offset-3f-bug",
        .description = "Branch offset of 3f hardware bug",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.pk_fmac_f16_inst)] = .{
        .llvm_name = "pk-fmac-f16-inst",
        .description = "Has v_pk_fmac_f16 instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.promote_alloca)] = .{
        .llvm_name = "promote-alloca",
        .description = "Enable promote alloca pass",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.r128_a16)] = .{
        .llvm_name = "r128-a16",
        .description = "Support 16 bit coordindates/gradients/lod/clamp/mip types on gfx9",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.register_banking)] = .{
        .llvm_name = "register-banking",
        .description = "Has register banking",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.s_memrealtime)] = .{
        .llvm_name = "s-memrealtime",
        .description = "Has s_memrealtime instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.scalar_atomics)] = .{
        .llvm_name = "scalar-atomics",
        .description = "Has atomic scalar memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.scalar_flat_scratch_insts)] = .{
        .llvm_name = "scalar-flat-scratch-insts",
        .description = "Have s_scratch_* flat memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.scalar_stores)] = .{
        .llvm_name = "scalar-stores",
        .description = "Has store scalar memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa)] = .{
        .llvm_name = "sdwa",
        .description = "Support SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa_mav)] = .{
        .llvm_name = "sdwa-mav",
        .description = "Support v_mac_f32/f16 with SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa_omod)] = .{
        .llvm_name = "sdwa-omod",
        .description = "Support OMod with SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa_out_mods_vopc)] = .{
        .llvm_name = "sdwa-out-mods-vopc",
        .description = "Support clamp for VOPC with SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa_scalar)] = .{
        .llvm_name = "sdwa-scalar",
        .description = "Support scalar register with SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sdwa_sdst)] = .{
        .llvm_name = "sdwa-sdst",
        .description = "Support scalar dst for VOPC with SDWA (Sub-DWORD Addressing) extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sea_islands)] = .{
        .llvm_name = "sea-islands",
        .description = "SEA_ISLANDS GPU generation",
        .dependencies = featureSet(&[_]Feature{
            .ci_insts,
            .flat_address_space,
            .fp64,
            .gfx7_gfx8_gfx9_insts,
            .localmemorysize65536,
            .mimg_r128,
            .movrel,
            .no_sram_ecc_support,
            .trig_reduced_range,
            .wavefrontsize64,
        }),
    };
    result[@enumToInt(Feature.sgpr_init_bug)] = .{
        .llvm_name = "sgpr-init-bug",
        .description = "VI SGPR initialization bug requiring a fixed SGPR allocation size",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.si_scheduler)] = .{
        .llvm_name = "si-scheduler",
        .description = "Enable SI Machine Scheduler",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.smem_to_vector_write_hazard)] = .{
        .llvm_name = "smem-to-vector-write-hazard",
        .description = "s_load_dword followed by v_cmp page faults",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.southern_islands)] = .{
        .llvm_name = "southern-islands",
        .description = "SOUTHERN_ISLANDS GPU generation",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .ldsbankcount32,
            .localmemorysize32768,
            .mimg_r128,
            .movrel,
            .no_sram_ecc_support,
            .no_xnack_support,
            .trig_reduced_range,
            .wavefrontsize64,
        }),
    };
    result[@enumToInt(Feature.sram_ecc)] = .{
        .llvm_name = "sram-ecc",
        .description = "Enable SRAM ECC",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.trap_handler)] = .{
        .llvm_name = "trap-handler",
        .description = "Trap handler support",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.trig_reduced_range)] = .{
        .llvm_name = "trig-reduced-range",
        .description = "Requires use of fract on arguments to trig instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.unaligned_buffer_access)] = .{
        .llvm_name = "unaligned-buffer-access",
        .description = "Support unaligned global loads and stores",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.unaligned_scratch_access)] = .{
        .llvm_name = "unaligned-scratch-access",
        .description = "Support unaligned scratch loads and stores",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.unpacked_d16_vmem)] = .{
        .llvm_name = "unpacked-d16-vmem",
        .description = "Has unpacked d16 vmem instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.unsafe_ds_offset_folding)] = .{
        .llvm_name = "unsafe-ds-offset-folding",
        .description = "Force using DS instruction immediate offsets on SI",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vcmpx_exec_war_hazard)] = .{
        .llvm_name = "vcmpx-exec-war-hazard",
        .description = "V_CMPX WAR hazard on EXEC (V_CMPX issue ONLY)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vcmpx_permlane_hazard)] = .{
        .llvm_name = "vcmpx-permlane-hazard",
        .description = "TODO: describe me",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vgpr_index_mode)] = .{
        .llvm_name = "vgpr-index-mode",
        .description = "Has VGPR mode register indexing",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vmem_to_scalar_write_hazard)] = .{
        .llvm_name = "vmem-to-scalar-write-hazard",
        .description = "VMEM instruction followed by scalar writing to EXEC mask, M0 or SGPR leads to incorrect execution.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.volcanic_islands)] = .{
        .llvm_name = "volcanic-islands",
        .description = "VOLCANIC_ISLANDS GPU generation",
        .dependencies = featureSet(&[_]Feature{
            .@"16_bit_insts",
            .ci_insts,
            .dpp,
            .flat_address_space,
            .fp64,
            .gcn3_encoding,
            .gfx7_gfx8_gfx9_insts,
            .gfx8_insts,
            .int_clamp_insts,
            .inv_2pi_inline_imm,
            .localmemorysize65536,
            .mimg_r128,
            .movrel,
            .no_sram_ecc_support,
            .s_memrealtime,
            .scalar_stores,
            .sdwa,
            .sdwa_mav,
            .sdwa_out_mods_vopc,
            .trig_reduced_range,
            .vgpr_index_mode,
            .wavefrontsize64,
        }),
    };
    result[@enumToInt(Feature.vop3_literal)] = .{
        .llvm_name = "vop3-literal",
        .description = "Can use one literal in VOP3",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vop3p)] = .{
        .llvm_name = "vop3p",
        .description = "Has VOP3P packed instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vscnt)] = .{
        .llvm_name = "vscnt",
        .description = "Has separate store vscnt counter",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.wavefrontsize16)] = .{
        .llvm_name = "wavefrontsize16",
        .description = "The number of threads per wavefront",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.wavefrontsize32)] = .{
        .llvm_name = "wavefrontsize32",
        .description = "The number of threads per wavefront",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.wavefrontsize64)] = .{
        .llvm_name = "wavefrontsize64",
        .description = "The number of threads per wavefront",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.xnack)] = .{
        .llvm_name = "xnack",
        .description = "Enable XNACK support",
        .dependencies = featureSet(&[_]Feature{}),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const bonaire = CpuModel{
        .name = "bonaire",
        .llvm_name = "bonaire",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const carrizo = CpuModel{
        .name = "carrizo",
        .llvm_name = "carrizo",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .unpacked_d16_vmem,
            .volcanic_islands,
            .xnack,
        }),
    };
    pub const fiji = CpuModel{
        .name = "fiji",
        .llvm_name = "fiji",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .wavefrontsize64,
        }),
    };
    pub const generic_hsa = CpuModel{
        .name = "generic_hsa",
        .llvm_name = "generic-hsa",
        .features = featureSet(&[_]Feature{
            .flat_address_space,
            .wavefrontsize64,
        }),
    };
    pub const gfx1010 = CpuModel{
        .name = "gfx1010",
        .llvm_name = "gfx1010",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .dl_insts,
            .flat_segment_offset_bug,
            .gfx10,
            .inst_fwd_prefetch_bug,
            .lds_branch_vmem_war_hazard,
            .lds_misaligned_bug,
            .ldsbankcount32,
            .no_xnack_support,
            .nsa_encoding,
            .nsa_to_vmem_bug,
            .offset_3f_bug,
            .scalar_atomics,
            .scalar_flat_scratch_insts,
            .scalar_stores,
            .smem_to_vector_write_hazard,
            .vcmpx_exec_war_hazard,
            .vcmpx_permlane_hazard,
            .vmem_to_scalar_write_hazard,
            .wavefrontsize32,
        }),
    };
    pub const gfx1011 = CpuModel{
        .name = "gfx1011",
        .llvm_name = "gfx1011",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .dl_insts,
            .dot1_insts,
            .dot2_insts,
            .dot5_insts,
            .dot6_insts,
            .flat_segment_offset_bug,
            .gfx10,
            .inst_fwd_prefetch_bug,
            .lds_branch_vmem_war_hazard,
            .ldsbankcount32,
            .no_xnack_support,
            .nsa_encoding,
            .nsa_to_vmem_bug,
            .offset_3f_bug,
            .scalar_atomics,
            .scalar_flat_scratch_insts,
            .scalar_stores,
            .smem_to_vector_write_hazard,
            .vcmpx_exec_war_hazard,
            .vcmpx_permlane_hazard,
            .vmem_to_scalar_write_hazard,
            .wavefrontsize32,
        }),
    };
    pub const gfx1012 = CpuModel{
        .name = "gfx1012",
        .llvm_name = "gfx1012",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .dl_insts,
            .dot1_insts,
            .dot2_insts,
            .dot5_insts,
            .dot6_insts,
            .flat_segment_offset_bug,
            .gfx10,
            .inst_fwd_prefetch_bug,
            .lds_branch_vmem_war_hazard,
            .lds_misaligned_bug,
            .ldsbankcount32,
            .no_xnack_support,
            .nsa_encoding,
            .nsa_to_vmem_bug,
            .offset_3f_bug,
            .scalar_atomics,
            .scalar_flat_scratch_insts,
            .scalar_stores,
            .smem_to_vector_write_hazard,
            .vcmpx_exec_war_hazard,
            .vcmpx_permlane_hazard,
            .vmem_to_scalar_write_hazard,
            .wavefrontsize32,
        }),
    };
    pub const gfx600 = CpuModel{
        .name = "gfx600",
        .llvm_name = "gfx600",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const gfx601 = CpuModel{
        .name = "gfx601",
        .llvm_name = "gfx601",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const gfx700 = CpuModel{
        .name = "gfx700",
        .llvm_name = "gfx700",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const gfx701 = CpuModel{
        .name = "gfx701",
        .llvm_name = "gfx701",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const gfx702 = CpuModel{
        .name = "gfx702",
        .llvm_name = "gfx702",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .ldsbankcount16,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const gfx703 = CpuModel{
        .name = "gfx703",
        .llvm_name = "gfx703",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount16,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const gfx704 = CpuModel{
        .name = "gfx704",
        .llvm_name = "gfx704",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const gfx801 = CpuModel{
        .name = "gfx801",
        .llvm_name = "gfx801",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .unpacked_d16_vmem,
            .volcanic_islands,
            .xnack,
        }),
    };
    pub const gfx802 = CpuModel{
        .name = "gfx802",
        .llvm_name = "gfx802",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sgpr_init_bug,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const gfx803 = CpuModel{
        .name = "gfx803",
        .llvm_name = "gfx803",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const gfx810 = CpuModel{
        .name = "gfx810",
        .llvm_name = "gfx810",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount16,
            .volcanic_islands,
            .xnack,
        }),
    };
    pub const gfx900 = CpuModel{
        .name = "gfx900",
        .llvm_name = "gfx900",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .gfx9,
            .ldsbankcount32,
            .mad_mix_insts,
            .no_sram_ecc_support,
            .no_xnack_support,
        }),
    };
    pub const gfx902 = CpuModel{
        .name = "gfx902",
        .llvm_name = "gfx902",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .gfx9,
            .ldsbankcount32,
            .mad_mix_insts,
            .no_sram_ecc_support,
            .xnack,
        }),
    };
    pub const gfx904 = CpuModel{
        .name = "gfx904",
        .llvm_name = "gfx904",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fma_mix_insts,
            .gfx9,
            .ldsbankcount32,
            .no_sram_ecc_support,
            .no_xnack_support,
        }),
    };
    pub const gfx906 = CpuModel{
        .name = "gfx906",
        .llvm_name = "gfx906",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .dl_insts,
            .dot1_insts,
            .dot2_insts,
            .fma_mix_insts,
            .gfx9,
            .half_rate_64_ops,
            .ldsbankcount32,
            .no_xnack_support,
        }),
    };
    pub const gfx908 = CpuModel{
        .name = "gfx908",
        .llvm_name = "gfx908",
        .features = featureSet(&[_]Feature{
            .atomic_fadd_insts,
            .code_object_v3,
            .dl_insts,
            .dot1_insts,
            .dot2_insts,
            .dot3_insts,
            .dot4_insts,
            .dot5_insts,
            .dot6_insts,
            .fma_mix_insts,
            .gfx9,
            .half_rate_64_ops,
            .ldsbankcount32,
            .mai_insts,
            .mfma_inline_literal_bug,
            .pk_fmac_f16_inst,
            .sram_ecc,
        }),
    };
    pub const gfx909 = CpuModel{
        .name = "gfx909",
        .llvm_name = "gfx909",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .gfx9,
            .ldsbankcount32,
            .mad_mix_insts,
            .xnack,
        }),
    };
    pub const hainan = CpuModel{
        .name = "hainan",
        .llvm_name = "hainan",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const hawaii = CpuModel{
        .name = "hawaii",
        .llvm_name = "hawaii",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const iceland = CpuModel{
        .name = "iceland",
        .llvm_name = "iceland",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sgpr_init_bug,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const kabini = CpuModel{
        .name = "kabini",
        .llvm_name = "kabini",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount16,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const kaveri = CpuModel{
        .name = "kaveri",
        .llvm_name = "kaveri",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const mullins = CpuModel{
        .name = "mullins",
        .llvm_name = "mullins",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount16,
            .no_xnack_support,
            .sea_islands,
        }),
    };
    pub const oland = CpuModel{
        .name = "oland",
        .llvm_name = "oland",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const pitcairn = CpuModel{
        .name = "pitcairn",
        .llvm_name = "pitcairn",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const polaris10 = CpuModel{
        .name = "polaris10",
        .llvm_name = "polaris10",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const polaris11 = CpuModel{
        .name = "polaris11",
        .llvm_name = "polaris11",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const stoney = CpuModel{
        .name = "stoney",
        .llvm_name = "stoney",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount16,
            .volcanic_islands,
            .xnack,
        }),
    };
    pub const tahiti = CpuModel{
        .name = "tahiti",
        .llvm_name = "tahiti",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .fast_fmaf,
            .half_rate_64_ops,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
    pub const tonga = CpuModel{
        .name = "tonga",
        .llvm_name = "tonga",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .sgpr_init_bug,
            .unpacked_d16_vmem,
            .volcanic_islands,
        }),
    };
    pub const verde = CpuModel{
        .name = "verde",
        .llvm_name = "verde",
        .features = featureSet(&[_]Feature{
            .code_object_v3,
            .ldsbankcount32,
            .no_xnack_support,
            .southern_islands,
        }),
    };
};
