pub const Mnemonic = enum(u16) {
    // Arithmetics
    addi,
    add,
    addw,

    sub,
    subw,

    // Bits
    xori,
    xor,
    @"or",

    @"and",
    andi,

    slt,
    sltu,
    sltiu,

    slli,
    srli,
    srai,

    slliw,
    srliw,
    sraiw,

    sll,
    srl,
    sra,

    sllw,
    srlw,
    sraw,

    // Control Flow
    jalr,
    jal,

    beq,

    // Memory
    lui,
    auipc,

    ld,
    lw,
    lh,
    lb,
    lbu,
    lhu,
    lwu,

    sd,
    sw,
    sh,
    sb,

    // System
    ebreak,
    ecall,
    unimp,
    nop,

    // M extension
    mul,
    mulh,
    mulhu,
    mulhsu,
    mulw,

    div,
    divu,
    divw,
    divuw,

    rem,
    remu,
    remw,
    remuw,

    // F extension (32-bit float)
    fadds,
    fsubs,
    fmuls,
    fdivs,

    fmins,
    fmaxs,

    fsqrts,

    flw,
    fsw,

    feqs,
    flts,
    fles,

    // D extension (64-bit float)
    faddd,
    fsubd,
    fmuld,
    fdivd,

    fmind,
    fmaxd,

    fsqrtd,

    fld,
    fsd,

    feqd,
    fltd,
    fled,

    fcvtws,
    fcvtwus,
    fcvtls,
    fcvtlus,

    fcvtwd,
    fcvtwud,
    fcvtld,
    fcvtlud,

    fcvtsw,
    fcvtswu,
    fcvtsl,
    fcvtslu,

    fcvtdw,
    fcvtdwu,
    fcvtdl,
    fcvtdlu,

    fsgnjns,
    fsgnjnd,

    fsgnjxs,
    fsgnjxd,

    // Zicsr Extension Instructions
    csrrs,

    // V Extension Instructions
    vsetvli,
    vsetivli,
    vaddvv,
    vfaddvv,
    vsubvv,
    vfsubvv,
    vmulvv,
    vfmulvv,
    vslidedownvx,

    vle8v,
    vle16v,
    vle32v,
    vle64v,

    vse8v,
    vse16v,
    vse32v,
    vse64v,

    vadcvv,
    vmvvx,

    // Zbb Extension Instructions
    clz,
    clzw,

    // A Extension Instructions
    fence,
    fencetso,

    amoswapw,
    amoaddw,
    amoandw,
    amoorw,
    amoxorw,
    amomaxw,
    amominw,
    amomaxuw,
    amominuw,

    amoswapd,
    amoaddd,
    amoandd,
    amoord,
    amoxord,
    amomaxd,
    amomind,
    amomaxud,
    amominud,

    // Pseudo-instructions. Used for anything that isn't 1:1 with an
    // assembly instruction.

    /// Pseudo-instruction that will generate a backpatched
    /// function prologue.
    pseudo_prologue,
    /// Pseudo-instruction that will generate a backpatched
    /// function epilogue
    pseudo_epilogue,

    /// Pseudo-instruction: End of prologue
    pseudo_dbg_prologue_end,
    /// Pseudo-instruction: Beginning of epilogue
    pseudo_dbg_epilogue_begin,
    /// Pseudo-instruction: Update debug line
    pseudo_dbg_line_column,

    /// Pseudo-instruction that loads from memory into a register.
    pseudo_load_rm,
    /// Pseudo-instruction that stores from a register into memory
    pseudo_store_rm,
    /// Pseudo-instruction that loads the address of memory into a register.
    pseudo_lea_rm,
    /// Jumps. Uses `inst` payload.
    pseudo_j,
    /// Dead inst, ignored by the emitter.
    pseudo_dead,
    /// Loads the address of a value that hasn't yet been allocated in memory.
    pseudo_load_symbol,

    /// Moves the value of rs1 to rd.
    pseudo_mv,

    pseudo_restore_regs,
    pseudo_spill_regs,

    pseudo_compare,
    pseudo_not,
    pseudo_extern_fn_reloc,
    pseudo_fence,
    pseudo_amo,
};
