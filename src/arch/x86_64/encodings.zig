const Encoding = @import("Encoding.zig");
const Mnemonic = Encoding.Mnemonic;
const OpEn = Encoding.OpEn;
const Op = Encoding.Op;
const Mode = Encoding.Mode;
const Feature = Encoding.Feature;

const modrm_ext = u3;

pub const Entry = struct { Mnemonic, OpEn, []const Op, []const u8, modrm_ext, Mode, Feature };

// TODO move this into a .zon file when Zig is capable of importing .zon files
// zig fmt: off
pub const table = [_]Entry{
    // General-purpose
    .{ .adc, .zi, &.{ .al,   .imm8   }, &.{ 0x14 }, 0, .none,  .none },
    .{ .adc, .zi, &.{ .ax,   .imm16  }, &.{ 0x15 }, 0, .short, .none },
    .{ .adc, .zi, &.{ .eax,  .imm32  }, &.{ 0x15 }, 0, .none,  .none },
    .{ .adc, .zi, &.{ .rax,  .imm32s }, &.{ 0x15 }, 0, .long,  .none },
    .{ .adc, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 2, .none,  .none },
    .{ .adc, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 2, .rex,   .none },
    .{ .adc, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 2, .short, .none },
    .{ .adc, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 2, .none,  .none },
    .{ .adc, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 2, .long,  .none },
    .{ .adc, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 2, .short, .none },
    .{ .adc, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 2, .none,  .none },
    .{ .adc, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 2, .long,  .none },
    .{ .adc, .mr, &.{ .rm8,  .r8     }, &.{ 0x10 }, 0, .none,  .none },
    .{ .adc, .mr, &.{ .rm8,  .r8     }, &.{ 0x10 }, 0, .rex,   .none },
    .{ .adc, .mr, &.{ .rm16, .r16    }, &.{ 0x11 }, 0, .short, .none },
    .{ .adc, .mr, &.{ .rm32, .r32    }, &.{ 0x11 }, 0, .none,  .none },
    .{ .adc, .mr, &.{ .rm64, .r64    }, &.{ 0x11 }, 0, .long,  .none },
    .{ .adc, .rm, &.{ .r8,   .rm8    }, &.{ 0x12 }, 0, .none,  .none },
    .{ .adc, .rm, &.{ .r8,   .rm8    }, &.{ 0x12 }, 0, .rex,   .none },
    .{ .adc, .rm, &.{ .r16,  .rm16   }, &.{ 0x13 }, 0, .short, .none },
    .{ .adc, .rm, &.{ .r32,  .rm32   }, &.{ 0x13 }, 0, .none,  .none },
    .{ .adc, .rm, &.{ .r64,  .rm64   }, &.{ 0x13 }, 0, .long,  .none },

    .{ .add, .zi, &.{ .al,   .imm8   }, &.{ 0x04 }, 0, .none,  .none },
    .{ .add, .zi, &.{ .ax,   .imm16  }, &.{ 0x05 }, 0, .short, .none },
    .{ .add, .zi, &.{ .eax,  .imm32  }, &.{ 0x05 }, 0, .none,  .none },
    .{ .add, .zi, &.{ .rax,  .imm32s }, &.{ 0x05 }, 0, .long,  .none },
    .{ .add, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 0, .none,  .none },
    .{ .add, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 0, .rex,   .none },
    .{ .add, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 0, .short, .none },
    .{ .add, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 0, .none,  .none },
    .{ .add, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 0, .long,  .none },
    .{ .add, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 0, .short, .none },
    .{ .add, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 0, .none,  .none },
    .{ .add, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 0, .long,  .none },
    .{ .add, .mr, &.{ .rm8,  .r8     }, &.{ 0x00 }, 0, .none,  .none },
    .{ .add, .mr, &.{ .rm8,  .r8     }, &.{ 0x00 }, 0, .rex,   .none },
    .{ .add, .mr, &.{ .rm16, .r16    }, &.{ 0x01 }, 0, .short, .none },
    .{ .add, .mr, &.{ .rm32, .r32    }, &.{ 0x01 }, 0, .none,  .none },
    .{ .add, .mr, &.{ .rm64, .r64    }, &.{ 0x01 }, 0, .long,  .none },
    .{ .add, .rm, &.{ .r8,   .rm8    }, &.{ 0x02 }, 0, .none,  .none },
    .{ .add, .rm, &.{ .r8,   .rm8    }, &.{ 0x02 }, 0, .rex,   .none },
    .{ .add, .rm, &.{ .r16,  .rm16   }, &.{ 0x03 }, 0, .short, .none },
    .{ .add, .rm, &.{ .r32,  .rm32   }, &.{ 0x03 }, 0, .none,  .none },
    .{ .add, .rm, &.{ .r64,  .rm64   }, &.{ 0x03 }, 0, .long,  .none },

    .{ .@"and", .zi, &.{ .al,   .imm8   }, &.{ 0x24 }, 0, .none,  .none },
    .{ .@"and", .zi, &.{ .ax,   .imm16  }, &.{ 0x25 }, 0, .short, .none },
    .{ .@"and", .zi, &.{ .eax,  .imm32  }, &.{ 0x25 }, 0, .none,  .none },
    .{ .@"and", .zi, &.{ .rax,  .imm32s }, &.{ 0x25 }, 0, .long,  .none },
    .{ .@"and", .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 4, .none,  .none },
    .{ .@"and", .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 4, .rex,   .none },
    .{ .@"and", .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 4, .short, .none },
    .{ .@"and", .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 4, .none,  .none },
    .{ .@"and", .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 4, .long,  .none },
    .{ .@"and", .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 4, .short, .none },
    .{ .@"and", .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 4, .none,  .none },
    .{ .@"and", .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 4, .long,  .none },
    .{ .@"and", .mr, &.{ .rm8,  .r8     }, &.{ 0x20 }, 0, .none,  .none },
    .{ .@"and", .mr, &.{ .rm8,  .r8     }, &.{ 0x20 }, 0, .rex,   .none },
    .{ .@"and", .mr, &.{ .rm16, .r16    }, &.{ 0x21 }, 0, .short, .none },
    .{ .@"and", .mr, &.{ .rm32, .r32    }, &.{ 0x21 }, 0, .none,  .none },
    .{ .@"and", .mr, &.{ .rm64, .r64    }, &.{ 0x21 }, 0, .long,  .none },
    .{ .@"and", .rm, &.{ .r8,   .rm8    }, &.{ 0x22 }, 0, .none,  .none },
    .{ .@"and", .rm, &.{ .r8,   .rm8    }, &.{ 0x22 }, 0, .rex,   .none },
    .{ .@"and", .rm, &.{ .r16,  .rm16   }, &.{ 0x23 }, 0, .short, .none },
    .{ .@"and", .rm, &.{ .r32,  .rm32   }, &.{ 0x23 }, 0, .none,  .none },
    .{ .@"and", .rm, &.{ .r64,  .rm64   }, &.{ 0x23 }, 0, .long,  .none },

    .{ .bsf, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0xbc }, 0, .short, .none },
    .{ .bsf, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0xbc }, 0, .none,  .none },
    .{ .bsf, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0xbc }, 0, .long,  .none },

    .{ .bsr, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0xbd }, 0, .short, .none },
    .{ .bsr, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0xbd }, 0, .none,  .none },
    .{ .bsr, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0xbd }, 0, .long,  .none },

    .{ .bswap, .o, &.{ .r32 }, &.{ 0x0f, 0xc8 }, 0, .none, .none },
    .{ .bswap, .o, &.{ .r64 }, &.{ 0x0f, 0xc8 }, 0, .long, .none },

    .{ .bt, .mr, &.{ .rm16, .r16  }, &.{ 0x0f, 0xa3 }, 0, .short, .none },
    .{ .bt, .mr, &.{ .rm32, .r32  }, &.{ 0x0f, 0xa3 }, 0, .none,  .none },
    .{ .bt, .mr, &.{ .rm64, .r64  }, &.{ 0x0f, 0xa3 }, 0, .long,  .none },
    .{ .bt, .mi, &.{ .rm16, .imm8 }, &.{ 0x0f, 0xba }, 4, .short, .none },
    .{ .bt, .mi, &.{ .rm32, .imm8 }, &.{ 0x0f, 0xba }, 4, .none,  .none },
    .{ .bt, .mi, &.{ .rm64, .imm8 }, &.{ 0x0f, 0xba }, 4, .long,  .none },

    .{ .btc, .mr, &.{ .rm16, .r16  }, &.{ 0x0f, 0xbb }, 0, .short, .none },
    .{ .btc, .mr, &.{ .rm32, .r32  }, &.{ 0x0f, 0xbb }, 0, .none,  .none },
    .{ .btc, .mr, &.{ .rm64, .r64  }, &.{ 0x0f, 0xbb }, 0, .long,  .none },
    .{ .btc, .mi, &.{ .rm16, .imm8 }, &.{ 0x0f, 0xba }, 7, .short, .none },
    .{ .btc, .mi, &.{ .rm32, .imm8 }, &.{ 0x0f, 0xba }, 7, .none,  .none },
    .{ .btc, .mi, &.{ .rm64, .imm8 }, &.{ 0x0f, 0xba }, 7, .long,  .none },

    .{ .btr, .mr, &.{ .rm16, .r16  }, &.{ 0x0f, 0xb3 }, 0, .short, .none },
    .{ .btr, .mr, &.{ .rm32, .r32  }, &.{ 0x0f, 0xb3 }, 0, .none,  .none },
    .{ .btr, .mr, &.{ .rm64, .r64  }, &.{ 0x0f, 0xb3 }, 0, .long,  .none },
    .{ .btr, .mi, &.{ .rm16, .imm8 }, &.{ 0x0f, 0xba }, 6, .short, .none },
    .{ .btr, .mi, &.{ .rm32, .imm8 }, &.{ 0x0f, 0xba }, 6, .none,  .none },
    .{ .btr, .mi, &.{ .rm64, .imm8 }, &.{ 0x0f, 0xba }, 6, .long,  .none },

    .{ .bts, .mr, &.{ .rm16, .r16  }, &.{ 0x0f, 0xab }, 0, .short, .none },
    .{ .bts, .mr, &.{ .rm32, .r32  }, &.{ 0x0f, 0xab }, 0, .none,  .none },
    .{ .bts, .mr, &.{ .rm64, .r64  }, &.{ 0x0f, 0xab }, 0, .long,  .none },
    .{ .bts, .mi, &.{ .rm16, .imm8 }, &.{ 0x0f, 0xba }, 5, .short, .none },
    .{ .bts, .mi, &.{ .rm32, .imm8 }, &.{ 0x0f, 0xba }, 5, .none,  .none },
    .{ .bts, .mi, &.{ .rm64, .imm8 }, &.{ 0x0f, 0xba }, 5, .long,  .none },

    .{ .call, .d, &.{ .rel32 }, &.{ 0xe8 }, 0, .none, .none },
    .{ .call, .m, &.{ .rm64  }, &.{ 0xff }, 2, .none, .none },

    .{ .cbw,  .zo, &.{ .o16 }, &.{ 0x98 }, 0, .short, .none },
    .{ .cwde, .zo, &.{ .o32 }, &.{ 0x98 }, 0, .none,  .none },
    .{ .cdqe, .zo, &.{ .o64 }, &.{ 0x98 }, 0, .long,  .none },

    .{ .cwd, .zo, &.{ .o16 }, &.{ 0x99 }, 0, .short, .none },
    .{ .cdq, .zo, &.{ .o32 }, &.{ 0x99 }, 0, .none,  .none },
    .{ .cqo, .zo, &.{ .o64 }, &.{ 0x99 }, 0, .long,  .none },

    .{ .clflush, .m, &.{ .m8 }, &.{ 0x0f, 0xae }, 7, .none, .none },

    .{ .cmova,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x47 }, 0, .short, .none },
    .{ .cmova,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x47 }, 0, .none,  .none },
    .{ .cmova,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x47 }, 0, .long,  .none },
    .{ .cmovae,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x43 }, 0, .short, .none },
    .{ .cmovae,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x43 }, 0, .none,  .none },
    .{ .cmovae,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x43 }, 0, .long,  .none },
    .{ .cmovb,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x42 }, 0, .short, .none },
    .{ .cmovb,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x42 }, 0, .none,  .none },
    .{ .cmovb,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x42 }, 0, .long,  .none },
    .{ .cmovbe,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x46 }, 0, .short, .none },
    .{ .cmovbe,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x46 }, 0, .none,  .none },
    .{ .cmovbe,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x46 }, 0, .long,  .none },
    .{ .cmovc,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x42 }, 0, .short, .none },
    .{ .cmovc,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x42 }, 0, .none,  .none },
    .{ .cmovc,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x42 }, 0, .long,  .none },
    .{ .cmove,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x44 }, 0, .short, .none },
    .{ .cmove,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x44 }, 0, .none,  .none },
    .{ .cmove,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x44 }, 0, .long,  .none },
    .{ .cmovg,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4f }, 0, .short, .none },
    .{ .cmovg,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4f }, 0, .none,  .none },
    .{ .cmovg,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4f }, 0, .long,  .none },
    .{ .cmovge,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4d }, 0, .short, .none },
    .{ .cmovge,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4d }, 0, .none,  .none },
    .{ .cmovge,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4d }, 0, .long,  .none },
    .{ .cmovl,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4c }, 0, .short, .none },
    .{ .cmovl,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4c }, 0, .none,  .none },
    .{ .cmovl,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4c }, 0, .long,  .none },
    .{ .cmovle,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4e }, 0, .short, .none },
    .{ .cmovle,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4e }, 0, .none,  .none },
    .{ .cmovle,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4e }, 0, .long,  .none },
    .{ .cmovna,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x46 }, 0, .short, .none },
    .{ .cmovna,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x46 }, 0, .none,  .none },
    .{ .cmovna,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x46 }, 0, .long,  .none },
    .{ .cmovnae, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x42 }, 0, .short, .none },
    .{ .cmovnae, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x42 }, 0, .none,  .none },
    .{ .cmovnae, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x42 }, 0, .long,  .none },
    .{ .cmovnb,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x43 }, 0, .short, .none },
    .{ .cmovnb,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x43 }, 0, .none,  .none },
    .{ .cmovnb,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x43 }, 0, .long,  .none },
    .{ .cmovnbe, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x47 }, 0, .short, .none },
    .{ .cmovnbe, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x47 }, 0, .none,  .none },
    .{ .cmovnbe, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x47 }, 0, .long,  .none },
    .{ .cmovnc,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x43 }, 0, .short, .none },
    .{ .cmovnc,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x43 }, 0, .none,  .none },
    .{ .cmovnc,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x43 }, 0, .long,  .none },
    .{ .cmovne,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x45 }, 0, .short, .none },
    .{ .cmovne,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x45 }, 0, .none,  .none },
    .{ .cmovne,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x45 }, 0, .long,  .none },
    .{ .cmovng,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4e }, 0, .short, .none },
    .{ .cmovng,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4e }, 0, .none,  .none },
    .{ .cmovng,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4e }, 0, .long,  .none },
    .{ .cmovnge, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4c }, 0, .short, .none },
    .{ .cmovnge, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4c }, 0, .none,  .none },
    .{ .cmovnge, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4c }, 0, .long,  .none },
    .{ .cmovnl,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4d }, 0, .short, .none },
    .{ .cmovnl,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4d }, 0, .none,  .none },
    .{ .cmovnl,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4d }, 0, .long,  .none },
    .{ .cmovnle, .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4f }, 0, .short, .none },
    .{ .cmovnle, .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4f }, 0, .none,  .none },
    .{ .cmovnle, .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4f }, 0, .long,  .none },
    .{ .cmovno,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x41 }, 0, .short, .none },
    .{ .cmovno,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x41 }, 0, .none,  .none },
    .{ .cmovno,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x41 }, 0, .long,  .none },
    .{ .cmovnp,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4b }, 0, .short, .none },
    .{ .cmovnp,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4b }, 0, .none,  .none },
    .{ .cmovnp,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4b }, 0, .long,  .none },
    .{ .cmovns,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x49 }, 0, .short, .none },
    .{ .cmovns,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x49 }, 0, .none,  .none },
    .{ .cmovns,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x49 }, 0, .long,  .none },
    .{ .cmovnz,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x45 }, 0, .short, .none },
    .{ .cmovnz,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x45 }, 0, .none,  .none },
    .{ .cmovnz,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x45 }, 0, .long,  .none },
    .{ .cmovo,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x40 }, 0, .short, .none },
    .{ .cmovo,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x40 }, 0, .none,  .none },
    .{ .cmovo,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x40 }, 0, .long,  .none },
    .{ .cmovp,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4a }, 0, .short, .none },
    .{ .cmovp,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4a }, 0, .none,  .none },
    .{ .cmovp,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4a }, 0, .long,  .none },
    .{ .cmovpe,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4a }, 0, .short, .none },
    .{ .cmovpe,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4a }, 0, .none,  .none },
    .{ .cmovpe,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4a }, 0, .long,  .none },
    .{ .cmovpo,  .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x4b }, 0, .short, .none },
    .{ .cmovpo,  .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x4b }, 0, .none,  .none },
    .{ .cmovpo,  .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x4b }, 0, .long,  .none },
    .{ .cmovs,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x48 }, 0, .short, .none },
    .{ .cmovs,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x48 }, 0, .none,  .none },
    .{ .cmovs,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x48 }, 0, .long,  .none },
    .{ .cmovz,   .rm, &.{ .r16, .rm16 }, &.{ 0x0f, 0x44 }, 0, .short, .none },
    .{ .cmovz,   .rm, &.{ .r32, .rm32 }, &.{ 0x0f, 0x44 }, 0, .none,  .none },
    .{ .cmovz,   .rm, &.{ .r64, .rm64 }, &.{ 0x0f, 0x44 }, 0, .long,  .none },

    .{ .cmp, .zi, &.{ .al,   .imm8   }, &.{ 0x3c }, 0, .none,  .none },
    .{ .cmp, .zi, &.{ .ax,   .imm16  }, &.{ 0x3d }, 0, .short, .none },
    .{ .cmp, .zi, &.{ .eax,  .imm32  }, &.{ 0x3d }, 0, .none,  .none },
    .{ .cmp, .zi, &.{ .rax,  .imm32s }, &.{ 0x3d }, 0, .long,  .none },
    .{ .cmp, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 7, .none,  .none },
    .{ .cmp, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 7, .rex,   .none },
    .{ .cmp, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 7, .short, .none },
    .{ .cmp, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 7, .none,  .none },
    .{ .cmp, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 7, .long,  .none },
    .{ .cmp, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 7, .short, .none },
    .{ .cmp, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 7, .none,  .none },
    .{ .cmp, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 7, .long,  .none },
    .{ .cmp, .mr, &.{ .rm8,  .r8     }, &.{ 0x38 }, 0, .none,  .none },
    .{ .cmp, .mr, &.{ .rm8,  .r8     }, &.{ 0x38 }, 0, .rex,   .none },
    .{ .cmp, .mr, &.{ .rm16, .r16    }, &.{ 0x39 }, 0, .short, .none },
    .{ .cmp, .mr, &.{ .rm32, .r32    }, &.{ 0x39 }, 0, .none,  .none },
    .{ .cmp, .mr, &.{ .rm64, .r64    }, &.{ 0x39 }, 0, .long,  .none },
    .{ .cmp, .rm, &.{ .r8,   .rm8    }, &.{ 0x3a }, 0, .none,  .none },
    .{ .cmp, .rm, &.{ .r8,   .rm8    }, &.{ 0x3a }, 0, .rex,   .none },
    .{ .cmp, .rm, &.{ .r16,  .rm16   }, &.{ 0x3b }, 0, .short, .none },
    .{ .cmp, .rm, &.{ .r32,  .rm32   }, &.{ 0x3b }, 0, .none,  .none },
    .{ .cmp, .rm, &.{ .r64,  .rm64   }, &.{ 0x3b }, 0, .long,  .none },

    .{ .cmps,  .zo, &.{ .m8,   .m8   }, &.{ 0xa6 }, 0, .none,  .none },
    .{ .cmps,  .zo, &.{ .m16,  .m16  }, &.{ 0xa7 }, 0, .short, .none },
    .{ .cmps,  .zo, &.{ .m32,  .m32  }, &.{ 0xa7 }, 0, .none,  .none },
    .{ .cmps,  .zo, &.{ .m64,  .m64  }, &.{ 0xa7 }, 0, .long,  .none },

    .{ .cmpsb, .zo, &.{}, &.{ 0xa6 }, 0, .none,  .none },
    .{ .cmpsw, .zo, &.{}, &.{ 0xa7 }, 0, .short, .none },
    .{ .cmpsd, .zo, &.{}, &.{ 0xa7 }, 0, .none,  .none },
    .{ .cmpsq, .zo, &.{}, &.{ 0xa7 }, 0, .long,  .none },

    .{ .cmpxchg, .mr, &.{ .rm8,  .r8  }, &.{ 0x0f, 0xb0 }, 0, .none,  .none },
    .{ .cmpxchg, .mr, &.{ .rm8,  .r8  }, &.{ 0x0f, 0xb0 }, 0, .rex,   .none },
    .{ .cmpxchg, .mr, &.{ .rm16, .r16 }, &.{ 0x0f, 0xb1 }, 0, .short, .none },
    .{ .cmpxchg, .mr, &.{ .rm32, .r32 }, &.{ 0x0f, 0xb1 }, 0, .none,  .none },
    .{ .cmpxchg, .mr, &.{ .rm64, .r64 }, &.{ 0x0f, 0xb1 }, 0, .long,  .none },

    .{ .cmpxchg8b,  .m, &.{ .m64  }, &.{ 0x0f, 0xc7 }, 1, .none, .none },
    .{ .cmpxchg16b, .m, &.{ .m128 }, &.{ 0x0f, 0xc7 }, 1, .long, .none },

    .{ .cpuid, .zo, &.{}, &.{ 0x0f, 0xa2 }, 0, .none, .none },

    .{ .dec, .m, &.{ .rm8  }, &.{ 0xfe }, 1, .none,  .none },
    .{ .dec, .m, &.{ .rm8  }, &.{ 0xfe }, 1, .rex,   .none },
    .{ .dec, .m, &.{ .rm16 }, &.{ 0xff }, 1, .short, .none },
    .{ .dec, .m, &.{ .rm32 }, &.{ 0xff }, 1, .none,  .none },
    .{ .dec, .m, &.{ .rm64 }, &.{ 0xff }, 1, .long,  .none },

    .{ .div, .m, &.{ .rm8  }, &.{ 0xf6 }, 6, .none,  .none },
    .{ .div, .m, &.{ .rm8  }, &.{ 0xf6 }, 6, .rex,   .none },
    .{ .div, .m, &.{ .rm16 }, &.{ 0xf7 }, 6, .short, .none },
    .{ .div, .m, &.{ .rm32 }, &.{ 0xf7 }, 6, .none,  .none },
    .{ .div, .m, &.{ .rm64 }, &.{ 0xf7 }, 6, .long,  .none },

    .{ .idiv, .m, &.{ .rm8  }, &.{ 0xf6 }, 7, .none,  .none },
    .{ .idiv, .m, &.{ .rm8  }, &.{ 0xf6 }, 7, .rex,   .none },
    .{ .idiv, .m, &.{ .rm16 }, &.{ 0xf7 }, 7, .short, .none },
    .{ .idiv, .m, &.{ .rm32 }, &.{ 0xf7 }, 7, .none,  .none },
    .{ .idiv, .m, &.{ .rm64 }, &.{ 0xf7 }, 7, .long,  .none },

    .{ .imul, .m,   &.{ .rm8                 }, &.{ 0xf6       }, 5, .none,  .none },
    .{ .imul, .m,   &.{ .rm8                 }, &.{ 0xf6       }, 5, .rex,   .none },
    .{ .imul, .m,   &.{ .rm16,               }, &.{ 0xf7       }, 5, .short, .none },
    .{ .imul, .m,   &.{ .rm32,               }, &.{ 0xf7       }, 5, .none,  .none },
    .{ .imul, .m,   &.{ .rm64,               }, &.{ 0xf7       }, 5, .long,  .none },
    .{ .imul, .rm,  &.{ .r16,  .rm16,        }, &.{ 0x0f, 0xaf }, 0, .short, .none },
    .{ .imul, .rm,  &.{ .r32,  .rm32,        }, &.{ 0x0f, 0xaf }, 0, .none,  .none },
    .{ .imul, .rm,  &.{ .r64,  .rm64,        }, &.{ 0x0f, 0xaf }, 0, .long,  .none },
    .{ .imul, .rmi, &.{ .r16,  .rm16, .imm8s }, &.{ 0x6b       }, 0, .short, .none },
    .{ .imul, .rmi, &.{ .r32,  .rm32, .imm8s }, &.{ 0x6b       }, 0, .none,  .none },
    .{ .imul, .rmi, &.{ .r64,  .rm64, .imm8s }, &.{ 0x6b       }, 0, .long,  .none },
    .{ .imul, .rmi, &.{ .r16,  .rm16, .imm16 }, &.{ 0x69       }, 0, .short, .none },
    .{ .imul, .rmi, &.{ .r32,  .rm32, .imm32 }, &.{ 0x69       }, 0, .none,  .none },
    .{ .imul, .rmi, &.{ .r64,  .rm64, .imm32 }, &.{ 0x69       }, 0, .long,  .none },

    .{ .inc, .m, &.{ .rm8  }, &.{ 0xfe }, 0, .none,  .none },
    .{ .inc, .m, &.{ .rm8  }, &.{ 0xfe }, 0, .rex,   .none },
    .{ .inc, .m, &.{ .rm16 }, &.{ 0xff }, 0, .short, .none },
    .{ .inc, .m, &.{ .rm32 }, &.{ 0xff }, 0, .none,  .none },
    .{ .inc, .m, &.{ .rm64 }, &.{ 0xff }, 0, .long,  .none },

    .{ .int3, .zo, &.{}, &.{ 0xcc }, 0, .none, .none },

    .{ .ja,    .d, &.{ .rel32 }, &.{ 0x0f, 0x87 }, 0, .none, .none },
    .{ .jae,   .d, &.{ .rel32 }, &.{ 0x0f, 0x83 }, 0, .none, .none },
    .{ .jb,    .d, &.{ .rel32 }, &.{ 0x0f, 0x82 }, 0, .none, .none },
    .{ .jbe,   .d, &.{ .rel32 }, &.{ 0x0f, 0x86 }, 0, .none, .none },
    .{ .jc,    .d, &.{ .rel32 }, &.{ 0x0f, 0x82 }, 0, .none, .none },
    .{ .jrcxz, .d, &.{ .rel32 }, &.{ 0xe3       }, 0, .none, .none },
    .{ .je,    .d, &.{ .rel32 }, &.{ 0x0f, 0x84 }, 0, .none, .none },
    .{ .jg,    .d, &.{ .rel32 }, &.{ 0x0f, 0x8f }, 0, .none, .none },
    .{ .jge,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8d }, 0, .none, .none },
    .{ .jl,    .d, &.{ .rel32 }, &.{ 0x0f, 0x8c }, 0, .none, .none },
    .{ .jle,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8e }, 0, .none, .none },
    .{ .jna,   .d, &.{ .rel32 }, &.{ 0x0f, 0x86 }, 0, .none, .none },
    .{ .jnae,  .d, &.{ .rel32 }, &.{ 0x0f, 0x82 }, 0, .none, .none },
    .{ .jnb,   .d, &.{ .rel32 }, &.{ 0x0f, 0x83 }, 0, .none, .none },
    .{ .jnbe,  .d, &.{ .rel32 }, &.{ 0x0f, 0x87 }, 0, .none, .none },
    .{ .jnc,   .d, &.{ .rel32 }, &.{ 0x0f, 0x83 }, 0, .none, .none },
    .{ .jne,   .d, &.{ .rel32 }, &.{ 0x0f, 0x85 }, 0, .none, .none },
    .{ .jng,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8e }, 0, .none, .none },
    .{ .jnge,  .d, &.{ .rel32 }, &.{ 0x0f, 0x8c }, 0, .none, .none },
    .{ .jnl,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8d }, 0, .none, .none },
    .{ .jnle,  .d, &.{ .rel32 }, &.{ 0x0f, 0x8f }, 0, .none, .none },
    .{ .jno,   .d, &.{ .rel32 }, &.{ 0x0f, 0x81 }, 0, .none, .none },
    .{ .jnp,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8b }, 0, .none, .none },
    .{ .jns,   .d, &.{ .rel32 }, &.{ 0x0f, 0x89 }, 0, .none, .none },
    .{ .jnz,   .d, &.{ .rel32 }, &.{ 0x0f, 0x85 }, 0, .none, .none },
    .{ .jo,    .d, &.{ .rel32 }, &.{ 0x0f, 0x80 }, 0, .none, .none },
    .{ .jp,    .d, &.{ .rel32 }, &.{ 0x0f, 0x8a }, 0, .none, .none },
    .{ .jpe,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8a }, 0, .none, .none },
    .{ .jpo,   .d, &.{ .rel32 }, &.{ 0x0f, 0x8b }, 0, .none, .none },
    .{ .js,    .d, &.{ .rel32 }, &.{ 0x0f, 0x88 }, 0, .none, .none },
    .{ .jz,    .d, &.{ .rel32 }, &.{ 0x0f, 0x84 }, 0, .none, .none },

    .{ .jmp, .d, &.{ .rel32 }, &.{ 0xe9 }, 0, .none, .none },
    .{ .jmp, .m, &.{ .rm64  }, &.{ 0xff }, 4, .none, .none },

    .{ .lea, .rm, &.{ .r16, .m }, &.{ 0x8d }, 0, .short, .none },
    .{ .lea, .rm, &.{ .r32, .m }, &.{ 0x8d }, 0, .none,  .none },
    .{ .lea, .rm, &.{ .r64, .m }, &.{ 0x8d }, 0, .long,  .none },

    .{ .lfence, .zo, &.{}, &.{ 0x0f, 0xae, 0xe8 }, 0, .none, .none },

    .{ .lods,  .zo, &.{ .m8  }, &.{ 0xac }, 0, .none,  .none },
    .{ .lods,  .zo, &.{ .m16 }, &.{ 0xad }, 0, .short, .none },
    .{ .lods,  .zo, &.{ .m32 }, &.{ 0xad }, 0, .none,  .none },
    .{ .lods,  .zo, &.{ .m64 }, &.{ 0xad }, 0, .long,  .none },

    .{ .lodsb, .zo, &.{}, &.{ 0xac }, 0, .none,  .none },
    .{ .lodsw, .zo, &.{}, &.{ 0xad }, 0, .short, .none },
    .{ .lodsd, .zo, &.{}, &.{ 0xad }, 0, .none,  .none },
    .{ .lodsq, .zo, &.{}, &.{ 0xad }, 0, .long,  .none },

    .{ .lzcnt, .rm, &.{ .r16, .rm16 }, &.{ 0xf3, 0x0f, 0xbd }, 0, .short, .lzcnt },
    .{ .lzcnt, .rm, &.{ .r32, .rm32 }, &.{ 0xf3, 0x0f, 0xbd }, 0, .none,  .lzcnt },
    .{ .lzcnt, .rm, &.{ .r64, .rm64 }, &.{ 0xf3, 0x0f, 0xbd }, 0, .long,  .lzcnt },

    .{ .mfence, .zo, &.{}, &.{ 0x0f, 0xae, 0xf0 }, 0, .none, .none },

    .{ .mov, .mr, &.{ .rm8,     .r8      }, &.{ 0x88 }, 0, .none,  .none },
    .{ .mov, .mr, &.{ .rm8,     .r8      }, &.{ 0x88 }, 0, .rex,   .none },
    .{ .mov, .mr, &.{ .rm16,    .r16     }, &.{ 0x89 }, 0, .short, .none },
    .{ .mov, .mr, &.{ .rm32,    .r32     }, &.{ 0x89 }, 0, .none,  .none },
    .{ .mov, .mr, &.{ .rm64,    .r64     }, &.{ 0x89 }, 0, .long,  .none },
    .{ .mov, .rm, &.{ .r8,      .rm8     }, &.{ 0x8a }, 0, .none,  .none },
    .{ .mov, .rm, &.{ .r8,      .rm8     }, &.{ 0x8a }, 0, .rex,   .none },
    .{ .mov, .rm, &.{ .r16,     .rm16    }, &.{ 0x8b }, 0, .short, .none },
    .{ .mov, .rm, &.{ .r32,     .rm32    }, &.{ 0x8b }, 0, .none,  .none },
    .{ .mov, .rm, &.{ .r64,     .rm64    }, &.{ 0x8b }, 0, .long,  .none },
    .{ .mov, .mr, &.{ .rm16,    .sreg    }, &.{ 0x8c }, 0, .short, .none },
    .{ .mov, .mr, &.{ .r32_m16, .sreg    }, &.{ 0x8c }, 0, .none,  .none },
    .{ .mov, .mr, &.{ .r64_m16, .sreg    }, &.{ 0x8c }, 0, .long,  .none },
    .{ .mov, .rm, &.{ .sreg,    .rm16    }, &.{ 0x8e }, 0, .short, .none },
    .{ .mov, .rm, &.{ .sreg,    .r32_m16 }, &.{ 0x8e }, 0, .none,  .none },
    .{ .mov, .rm, &.{ .sreg,    .r64_m16 }, &.{ 0x8e }, 0, .long,  .none },
    .{ .mov, .fd, &.{ .al,      .moffs   }, &.{ 0xa0 }, 0, .none,  .none },
    .{ .mov, .fd, &.{ .ax,      .moffs   }, &.{ 0xa1 }, 0, .short, .none },
    .{ .mov, .fd, &.{ .eax,     .moffs   }, &.{ 0xa1 }, 0, .none,  .none },
    .{ .mov, .fd, &.{ .rax,     .moffs   }, &.{ 0xa1 }, 0, .long,  .none },
    .{ .mov, .td, &.{ .moffs,   .al      }, &.{ 0xa2 }, 0, .none,  .none },
    .{ .mov, .td, &.{ .moffs,   .ax      }, &.{ 0xa3 }, 0, .short, .none },
    .{ .mov, .td, &.{ .moffs,   .eax     }, &.{ 0xa3 }, 0, .none,  .none },
    .{ .mov, .td, &.{ .moffs,   .rax     }, &.{ 0xa3 }, 0, .long,  .none },
    .{ .mov, .oi, &.{ .r8,      .imm8    }, &.{ 0xb0 }, 0, .none,  .none },
    .{ .mov, .oi, &.{ .r8,      .imm8    }, &.{ 0xb0 }, 0, .rex,   .none },
    .{ .mov, .oi, &.{ .r16,     .imm16   }, &.{ 0xb8 }, 0, .short, .none },
    .{ .mov, .oi, &.{ .r32,     .imm32   }, &.{ 0xb8 }, 0, .none,  .none },
    .{ .mov, .oi, &.{ .r64,     .imm64   }, &.{ 0xb8 }, 0, .long,  .none },
    .{ .mov, .mi, &.{ .rm8,     .imm8    }, &.{ 0xc6 }, 0, .none,  .none },
    .{ .mov, .mi, &.{ .rm8,     .imm8    }, &.{ 0xc6 }, 0, .rex,   .none },
    .{ .mov, .mi, &.{ .rm16,    .imm16   }, &.{ 0xc7 }, 0, .short, .none },
    .{ .mov, .mi, &.{ .rm32,    .imm32   }, &.{ 0xc7 }, 0, .none,  .none },
    .{ .mov, .mi, &.{ .rm64,    .imm32s  }, &.{ 0xc7 }, 0, .long,  .none },

    .{ .movbe, .rm, &.{ .r16, .m16 }, &.{ 0x0f, 0x38, 0xf0 }, 0, .short, .movbe },
    .{ .movbe, .rm, &.{ .r32, .m32 }, &.{ 0x0f, 0x38, 0xf0 }, 0, .none,  .movbe },
    .{ .movbe, .rm, &.{ .r64, .m64 }, &.{ 0x0f, 0x38, 0xf0 }, 0, .long,  .movbe },
    .{ .movbe, .mr, &.{ .m16, .r16 }, &.{ 0x0f, 0x38, 0xf1 }, 0, .short, .movbe },
    .{ .movbe, .mr, &.{ .m32, .r32 }, &.{ 0x0f, 0x38, 0xf1 }, 0, .none,  .movbe },
    .{ .movbe, .mr, &.{ .m64, .r64 }, &.{ 0x0f, 0x38, 0xf1 }, 0, .long,  .movbe },

    .{ .movs,  .zo, &.{ .m8,  .m8  }, &.{ 0xa4 }, 0, .none,  .none },
    .{ .movs,  .zo, &.{ .m16, .m16 }, &.{ 0xa5 }, 0, .short, .none },
    .{ .movs,  .zo, &.{ .m32, .m32 }, &.{ 0xa5 }, 0, .none,  .none },
    .{ .movs,  .zo, &.{ .m64, .m64 }, &.{ 0xa5 }, 0, .long,  .none },

    .{ .movsb, .zo, &.{}, &.{ 0xa4 }, 0, .none,  .none },
    .{ .movsw, .zo, &.{}, &.{ 0xa5 }, 0, .short, .none },
    .{ .movsd, .zo, &.{}, &.{ 0xa5 }, 0, .none,  .none },
    .{ .movsq, .zo, &.{}, &.{ 0xa5 }, 0, .long,  .none },

    .{ .movsx, .rm, &.{ .r16, .rm8  }, &.{ 0x0f, 0xbe }, 0, .short,     .none },
    .{ .movsx, .rm, &.{ .r16, .rm8  }, &.{ 0x0f, 0xbe }, 0, .rex_short, .none },
    .{ .movsx, .rm, &.{ .r32, .rm8  }, &.{ 0x0f, 0xbe }, 0, .none,      .none },
    .{ .movsx, .rm, &.{ .r32, .rm8  }, &.{ 0x0f, 0xbe }, 0, .rex,       .none },
    .{ .movsx, .rm, &.{ .r64, .rm8  }, &.{ 0x0f, 0xbe }, 0, .long,      .none },
    .{ .movsx, .rm, &.{ .r32, .rm16 }, &.{ 0x0f, 0xbf }, 0, .none,      .none },
    .{ .movsx, .rm, &.{ .r32, .rm16 }, &.{ 0x0f, 0xbf }, 0, .rex,       .none },
    .{ .movsx, .rm, &.{ .r64, .rm16 }, &.{ 0x0f, 0xbf }, 0, .long,      .none },

    // This instruction is discouraged.
    .{ .movsxd, .rm, &.{ .r32, .rm32 }, &.{ 0x63 }, 0, .none, .none },
    .{ .movsxd, .rm, &.{ .r64, .rm32 }, &.{ 0x63 }, 0, .long, .none },

    .{ .movzx, .rm, &.{ .r16, .rm8  }, &.{ 0x0f, 0xb6 }, 0, .short,     .none },
    .{ .movzx, .rm, &.{ .r16, .rm8  }, &.{ 0x0f, 0xb6 }, 0, .rex_short, .none },
    .{ .movzx, .rm, &.{ .r32, .rm8  }, &.{ 0x0f, 0xb6 }, 0, .none,      .none },
    .{ .movzx, .rm, &.{ .r32, .rm8  }, &.{ 0x0f, 0xb6 }, 0, .rex,       .none },
    .{ .movzx, .rm, &.{ .r64, .rm8  }, &.{ 0x0f, 0xb6 }, 0, .long,      .none },
    .{ .movzx, .rm, &.{ .r32, .rm16 }, &.{ 0x0f, 0xb7 }, 0, .none,      .none },
    .{ .movzx, .rm, &.{ .r32, .rm16 }, &.{ 0x0f, 0xb7 }, 0, .rex,       .none },
    .{ .movzx, .rm, &.{ .r64, .rm16 }, &.{ 0x0f, 0xb7 }, 0, .long,      .none },

    .{ .mul, .m, &.{ .rm8  }, &.{ 0xf6 }, 4, .none,  .none },
    .{ .mul, .m, &.{ .rm8  }, &.{ 0xf6 }, 4, .rex,   .none },
    .{ .mul, .m, &.{ .rm16 }, &.{ 0xf7 }, 4, .short, .none },
    .{ .mul, .m, &.{ .rm32 }, &.{ 0xf7 }, 4, .none,  .none },
    .{ .mul, .m, &.{ .rm64 }, &.{ 0xf7 }, 4, .long,  .none },

    .{ .neg, .m, &.{ .rm8  }, &.{ 0xf6 }, 3, .none,  .none },
    .{ .neg, .m, &.{ .rm8  }, &.{ 0xf6 }, 3, .rex,   .none },
    .{ .neg, .m, &.{ .rm16 }, &.{ 0xf7 }, 3, .short, .none },
    .{ .neg, .m, &.{ .rm32 }, &.{ 0xf7 }, 3, .none,  .none },
    .{ .neg, .m, &.{ .rm64 }, &.{ 0xf7 }, 3, .long,  .none },

    .{ .nop, .zo, &.{}, &.{ 0x90 }, 0, .none, .none },

    .{ .not, .m, &.{ .rm8  }, &.{ 0xf6 }, 2, .none,  .none },
    .{ .not, .m, &.{ .rm8  }, &.{ 0xf6 }, 2, .rex,   .none },
    .{ .not, .m, &.{ .rm16 }, &.{ 0xf7 }, 2, .short, .none },
    .{ .not, .m, &.{ .rm32 }, &.{ 0xf7 }, 2, .none,  .none },
    .{ .not, .m, &.{ .rm64 }, &.{ 0xf7 }, 2, .long,  .none },

    .{ .@"or", .zi, &.{ .al,   .imm8   }, &.{ 0x0c }, 0, .none,  .none },
    .{ .@"or", .zi, &.{ .ax,   .imm16  }, &.{ 0x0d }, 0, .short, .none },
    .{ .@"or", .zi, &.{ .eax,  .imm32  }, &.{ 0x0d }, 0, .none,  .none },
    .{ .@"or", .zi, &.{ .rax,  .imm32s }, &.{ 0x0d }, 0, .long,  .none },
    .{ .@"or", .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 1, .none,  .none },
    .{ .@"or", .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 1, .rex,   .none },
    .{ .@"or", .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 1, .short, .none },
    .{ .@"or", .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 1, .none,  .none },
    .{ .@"or", .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 1, .long,  .none },
    .{ .@"or", .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 1, .short, .none },
    .{ .@"or", .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 1, .none,  .none },
    .{ .@"or", .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 1, .long,  .none },
    .{ .@"or", .mr, &.{ .rm8,  .r8     }, &.{ 0x08 }, 0, .none,  .none },
    .{ .@"or", .mr, &.{ .rm8,  .r8     }, &.{ 0x08 }, 0, .rex,   .none },
    .{ .@"or", .mr, &.{ .rm16, .r16    }, &.{ 0x09 }, 0, .short, .none },
    .{ .@"or", .mr, &.{ .rm32, .r32    }, &.{ 0x09 }, 0, .none,  .none },
    .{ .@"or", .mr, &.{ .rm64, .r64    }, &.{ 0x09 }, 0, .long,  .none },
    .{ .@"or", .rm, &.{ .r8,   .rm8    }, &.{ 0x0a }, 0, .none,  .none },
    .{ .@"or", .rm, &.{ .r8,   .rm8    }, &.{ 0x0a }, 0, .rex,   .none },
    .{ .@"or", .rm, &.{ .r16,  .rm16   }, &.{ 0x0b }, 0, .short, .none },
    .{ .@"or", .rm, &.{ .r32,  .rm32   }, &.{ 0x0b }, 0, .none,  .none },
    .{ .@"or", .rm, &.{ .r64,  .rm64   }, &.{ 0x0b }, 0, .long,  .none },

    .{ .pause, .zo, &.{}, &.{ 0xf3, 0x90 }, 0, .none, .none },

    .{ .pop, .o, &.{ .r16  }, &.{ 0x58 }, 0, .short, .none },
    .{ .pop, .o, &.{ .r64  }, &.{ 0x58 }, 0, .none,  .none },
    .{ .pop, .m, &.{ .rm16 }, &.{ 0x8f }, 0, .short, .none },
    .{ .pop, .m, &.{ .rm64 }, &.{ 0x8f }, 0, .none,  .none },

    .{ .popcnt, .rm, &.{ .r16, .rm16 }, &.{ 0xf3, 0x0f, 0xb8 }, 0, .short, .popcnt },
    .{ .popcnt, .rm, &.{ .r32, .rm32 }, &.{ 0xf3, 0x0f, 0xb8 }, 0, .none,  .popcnt },
    .{ .popcnt, .rm, &.{ .r64, .rm64 }, &.{ 0xf3, 0x0f, 0xb8 }, 0, .long,  .popcnt },

    .{ .popfq, .zo, &.{}, &.{ 0x9d }, 0, .none, .none },

    .{ .push, .o, &.{ .r16   }, &.{ 0x50 }, 0, .short, .none },
    .{ .push, .o, &.{ .r64   }, &.{ 0x50 }, 0, .none,  .none },
    .{ .push, .m, &.{ .rm16  }, &.{ 0xff }, 6, .short, .none },
    .{ .push, .m, &.{ .rm64  }, &.{ 0xff }, 6, .none,  .none },
    .{ .push, .i, &.{ .imm8  }, &.{ 0x6a }, 0, .none,  .none },
    .{ .push, .i, &.{ .imm16 }, &.{ 0x68 }, 0, .short, .none },
    .{ .push, .i, &.{ .imm32 }, &.{ 0x68 }, 0, .none,  .none },

    .{ .pushfq, .zo, &.{}, &.{ 0x9c }, 0, .none, .none },

    .{ .ret, .zo, &.{}, &.{ 0xc3 }, 0, .none, .none },

    .{ .rcl, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 2, .none,  .none },
    .{ .rcl, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 2, .rex,   .none },
    .{ .rcl, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 2, .none,  .none },
    .{ .rcl, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 2, .rex,   .none },
    .{ .rcl, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 2, .none,  .none },
    .{ .rcl, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 2, .rex,   .none },
    .{ .rcl, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 2, .short, .none },
    .{ .rcl, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 2, .short, .none },
    .{ .rcl, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 2, .short, .none },
    .{ .rcl, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 2, .none,  .none },
    .{ .rcl, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 2, .long,  .none },
    .{ .rcl, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 2, .none,  .none },
    .{ .rcl, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 2, .long,  .none },
    .{ .rcl, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 2, .none,  .none },
    .{ .rcl, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 2, .long,  .none },

    .{ .rcr, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 3, .none,  .none },
    .{ .rcr, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 3, .rex,   .none },
    .{ .rcr, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 3, .none,  .none },
    .{ .rcr, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 3, .rex,   .none },
    .{ .rcr, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 3, .none,  .none },
    .{ .rcr, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 3, .rex,   .none },
    .{ .rcr, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 3, .short, .none },
    .{ .rcr, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 3, .short, .none },
    .{ .rcr, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 3, .short, .none },
    .{ .rcr, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 3, .none,  .none },
    .{ .rcr, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 3, .long,  .none },
    .{ .rcr, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 3, .none,  .none },
    .{ .rcr, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 3, .long,  .none },
    .{ .rcr, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 3, .none,  .none },
    .{ .rcr, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 3, .long,  .none },

    .{ .rol, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 0, .none,  .none },
    .{ .rol, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 0, .rex,   .none },
    .{ .rol, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 0, .none,  .none },
    .{ .rol, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 0, .rex,   .none },
    .{ .rol, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 0, .none,  .none },
    .{ .rol, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 0, .rex,   .none },
    .{ .rol, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 0, .short, .none },
    .{ .rol, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 0, .short, .none },
    .{ .rol, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 0, .short, .none },
    .{ .rol, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 0, .none,  .none },
    .{ .rol, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 0, .long,  .none },
    .{ .rol, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 0, .none,  .none },
    .{ .rol, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 0, .long,  .none },
    .{ .rol, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 0, .none,  .none },
    .{ .rol, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 0, .long,  .none },

    .{ .ror, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 1, .none,  .none },
    .{ .ror, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 1, .rex,   .none },
    .{ .ror, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 1, .none,  .none },
    .{ .ror, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 1, .rex,   .none },
    .{ .ror, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 1, .none,  .none },
    .{ .ror, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 1, .rex,   .none },
    .{ .ror, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 1, .short, .none },
    .{ .ror, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 1, .short, .none },
    .{ .ror, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 1, .short, .none },
    .{ .ror, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 1, .none,  .none },
    .{ .ror, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 1, .long,  .none },
    .{ .ror, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 1, .none,  .none },
    .{ .ror, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 1, .long,  .none },
    .{ .ror, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 1, .none,  .none },
    .{ .ror, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 1, .long,  .none },

    .{ .sal, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 4, .none,  .none },
    .{ .sal, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 4, .rex,   .none },
    .{ .sal, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 4, .short, .none },
    .{ .sal, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 4, .none,  .none },
    .{ .sal, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 4, .long,  .none },
    .{ .sal, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 4, .none,  .none },
    .{ .sal, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 4, .rex,   .none },
    .{ .sal, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 4, .short, .none },
    .{ .sal, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 4, .none,  .none },
    .{ .sal, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 4, .long,  .none },
    .{ .sal, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 4, .none,  .none },
    .{ .sal, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 4, .rex,   .none },
    .{ .sal, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 4, .short, .none },
    .{ .sal, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 4, .none,  .none },
    .{ .sal, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 4, .long,  .none },

    .{ .sar, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 7, .none,  .none },
    .{ .sar, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 7, .rex,   .none },
    .{ .sar, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 7, .short, .none },
    .{ .sar, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 7, .none,  .none },
    .{ .sar, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 7, .long,  .none },
    .{ .sar, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 7, .none,  .none },
    .{ .sar, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 7, .rex,   .none },
    .{ .sar, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 7, .short, .none },
    .{ .sar, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 7, .none,  .none },
    .{ .sar, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 7, .long,  .none },
    .{ .sar, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 7, .none,  .none },
    .{ .sar, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 7, .rex,   .none },
    .{ .sar, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 7, .short, .none },
    .{ .sar, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 7, .none,  .none },
    .{ .sar, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 7, .long,  .none },

    .{ .sbb, .zi, &.{ .al,   .imm8   }, &.{ 0x1c }, 0, .none,  .none },
    .{ .sbb, .zi, &.{ .ax,   .imm16  }, &.{ 0x1d }, 0, .short, .none },
    .{ .sbb, .zi, &.{ .eax,  .imm32  }, &.{ 0x1d }, 0, .none,  .none },
    .{ .sbb, .zi, &.{ .rax,  .imm32s }, &.{ 0x1d }, 0, .long,  .none },
    .{ .sbb, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 3, .none,  .none },
    .{ .sbb, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 3, .rex,   .none },
    .{ .sbb, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 3, .short, .none },
    .{ .sbb, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 3, .none,  .none },
    .{ .sbb, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 3, .long,  .none },
    .{ .sbb, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 3, .short, .none },
    .{ .sbb, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 3, .none,  .none },
    .{ .sbb, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 3, .long,  .none },
    .{ .sbb, .mr, &.{ .rm8,  .r8     }, &.{ 0x18 }, 0, .none,  .none },
    .{ .sbb, .mr, &.{ .rm8,  .r8     }, &.{ 0x18 }, 0, .rex,   .none },
    .{ .sbb, .mr, &.{ .rm16, .r16    }, &.{ 0x19 }, 0, .short, .none },
    .{ .sbb, .mr, &.{ .rm32, .r32    }, &.{ 0x19 }, 0, .none,  .none },
    .{ .sbb, .mr, &.{ .rm64, .r64    }, &.{ 0x19 }, 0, .long,  .none },
    .{ .sbb, .rm, &.{ .r8,   .rm8    }, &.{ 0x1a }, 0, .none,  .none },
    .{ .sbb, .rm, &.{ .r8,   .rm8    }, &.{ 0x1a }, 0, .rex,   .none },
    .{ .sbb, .rm, &.{ .r16,  .rm16   }, &.{ 0x1b }, 0, .short, .none },
    .{ .sbb, .rm, &.{ .r32,  .rm32   }, &.{ 0x1b }, 0, .none,  .none },
    .{ .sbb, .rm, &.{ .r64,  .rm64   }, &.{ 0x1b }, 0, .long,  .none },

    .{ .scas,  .zo, &.{ .m8  }, &.{ 0xae }, 0, .none,  .none },
    .{ .scas,  .zo, &.{ .m16 }, &.{ 0xaf }, 0, .short, .none },
    .{ .scas,  .zo, &.{ .m32 }, &.{ 0xaf }, 0, .none,  .none },
    .{ .scas,  .zo, &.{ .m64 }, &.{ 0xaf }, 0, .long,  .none },

    .{ .scasb, .zo, &.{}, &.{ 0xae }, 0, .none,  .none },
    .{ .scasw, .zo, &.{}, &.{ 0xaf }, 0, .short, .none },
    .{ .scasd, .zo, &.{}, &.{ 0xaf }, 0, .none,  .none },
    .{ .scasq, .zo, &.{}, &.{ 0xaf }, 0, .long,  .none },

    .{ .seta,   .m, &.{ .rm8 }, &.{ 0x0f, 0x97 }, 0, .none, .none },
    .{ .seta,   .m, &.{ .rm8 }, &.{ 0x0f, 0x97 }, 0, .rex,  .none },
    .{ .setae,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .none, .none },
    .{ .setae,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .rex,  .none },
    .{ .setb,   .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .none, .none },
    .{ .setb,   .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .rex,  .none },
    .{ .setbe,  .m, &.{ .rm8 }, &.{ 0x0f, 0x96 }, 0, .none, .none },
    .{ .setbe,  .m, &.{ .rm8 }, &.{ 0x0f, 0x96 }, 0, .rex,  .none },
    .{ .setc,   .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .none, .none },
    .{ .setc,   .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .rex,  .none },
    .{ .sete,   .m, &.{ .rm8 }, &.{ 0x0f, 0x94 }, 0, .none, .none },
    .{ .sete,   .m, &.{ .rm8 }, &.{ 0x0f, 0x94 }, 0, .rex,  .none },
    .{ .setg,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9f }, 0, .none, .none },
    .{ .setg,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9f }, 0, .rex,  .none },
    .{ .setge,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9d }, 0, .none, .none },
    .{ .setge,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9d }, 0, .rex,  .none },
    .{ .setl,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9c }, 0, .none, .none },
    .{ .setl,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9c }, 0, .rex,  .none },
    .{ .setle,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9e }, 0, .none, .none },
    .{ .setle,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9e }, 0, .rex,  .none },
    .{ .setna,  .m, &.{ .rm8 }, &.{ 0x0f, 0x96 }, 0, .none, .none },
    .{ .setna,  .m, &.{ .rm8 }, &.{ 0x0f, 0x96 }, 0, .rex,  .none },
    .{ .setnae, .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .none, .none },
    .{ .setnae, .m, &.{ .rm8 }, &.{ 0x0f, 0x92 }, 0, .rex,  .none },
    .{ .setnb,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .none, .none },
    .{ .setnb,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .rex,  .none },
    .{ .setnbe, .m, &.{ .rm8 }, &.{ 0x0f, 0x97 }, 0, .none, .none },
    .{ .setnbe, .m, &.{ .rm8 }, &.{ 0x0f, 0x97 }, 0, .rex,  .none },
    .{ .setnc,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .none, .none },
    .{ .setnc,  .m, &.{ .rm8 }, &.{ 0x0f, 0x93 }, 0, .rex,  .none },
    .{ .setne,  .m, &.{ .rm8 }, &.{ 0x0f, 0x95 }, 0, .none, .none },
    .{ .setne,  .m, &.{ .rm8 }, &.{ 0x0f, 0x95 }, 0, .rex,  .none },
    .{ .setng,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9e }, 0, .none, .none },
    .{ .setng,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9e }, 0, .rex,  .none },
    .{ .setnge, .m, &.{ .rm8 }, &.{ 0x0f, 0x9c }, 0, .none, .none },
    .{ .setnge, .m, &.{ .rm8 }, &.{ 0x0f, 0x9c }, 0, .rex,  .none },
    .{ .setnl,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9d }, 0, .none, .none },
    .{ .setnl,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9d }, 0, .rex,  .none },
    .{ .setnle, .m, &.{ .rm8 }, &.{ 0x0f, 0x9f }, 0, .none, .none },
    .{ .setnle, .m, &.{ .rm8 }, &.{ 0x0f, 0x9f }, 0, .rex,  .none },
    .{ .setno,  .m, &.{ .rm8 }, &.{ 0x0f, 0x91 }, 0, .none, .none },
    .{ .setno,  .m, &.{ .rm8 }, &.{ 0x0f, 0x91 }, 0, .rex,  .none },
    .{ .setnp,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9b }, 0, .none, .none },
    .{ .setnp,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9b }, 0, .rex,  .none },
    .{ .setns,  .m, &.{ .rm8 }, &.{ 0x0f, 0x99 }, 0, .none, .none },
    .{ .setns,  .m, &.{ .rm8 }, &.{ 0x0f, 0x99 }, 0, .rex,  .none },
    .{ .setnz,  .m, &.{ .rm8 }, &.{ 0x0f, 0x95 }, 0, .none, .none },
    .{ .setnz,  .m, &.{ .rm8 }, &.{ 0x0f, 0x95 }, 0, .rex,  .none },
    .{ .seto,   .m, &.{ .rm8 }, &.{ 0x0f, 0x90 }, 0, .none, .none },
    .{ .seto,   .m, &.{ .rm8 }, &.{ 0x0f, 0x90 }, 0, .rex,  .none },
    .{ .setp,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9a }, 0, .none, .none },
    .{ .setp,   .m, &.{ .rm8 }, &.{ 0x0f, 0x9a }, 0, .rex,  .none },
    .{ .setpe,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9a }, 0, .none, .none },
    .{ .setpe,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9a }, 0, .rex,  .none },
    .{ .setpo,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9b }, 0, .none, .none },
    .{ .setpo,  .m, &.{ .rm8 }, &.{ 0x0f, 0x9b }, 0, .rex,  .none },
    .{ .sets,   .m, &.{ .rm8 }, &.{ 0x0f, 0x98 }, 0, .none, .none },
    .{ .sets,   .m, &.{ .rm8 }, &.{ 0x0f, 0x98 }, 0, .rex,  .none },
    .{ .setz,   .m, &.{ .rm8 }, &.{ 0x0f, 0x94 }, 0, .none, .none },
    .{ .setz,   .m, &.{ .rm8 }, &.{ 0x0f, 0x94 }, 0, .rex,  .none },

    .{ .sfence, .zo, &.{}, &.{ 0x0f, 0xae, 0xf8 }, 0, .none, .none },

    .{ .shl, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 4, .none,  .none },
    .{ .shl, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 4, .rex,   .none },
    .{ .shl, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 4, .short, .none },
    .{ .shl, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 4, .none,  .none },
    .{ .shl, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 4, .long,  .none },
    .{ .shl, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 4, .none,  .none },
    .{ .shl, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 4, .rex,   .none },
    .{ .shl, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 4, .short, .none },
    .{ .shl, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 4, .none,  .none },
    .{ .shl, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 4, .long,  .none },
    .{ .shl, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 4, .none,  .none },
    .{ .shl, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 4, .rex,   .none },
    .{ .shl, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 4, .short, .none },
    .{ .shl, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 4, .none,  .none },
    .{ .shl, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 4, .long,  .none },

    .{ .shld, .mri, &.{ .rm16, .r16, .imm8 }, &.{ 0x0f, 0xa4 }, 0, .short, .none },
    .{ .shld, .mrc, &.{ .rm16, .r16, .cl   }, &.{ 0x0f, 0xa5 }, 0, .short, .none },
    .{ .shld, .mri, &.{ .rm32, .r32, .imm8 }, &.{ 0x0f, 0xa4 }, 0, .none,  .none },
    .{ .shld, .mri, &.{ .rm64, .r64, .imm8 }, &.{ 0x0f, 0xa4 }, 0, .long,  .none },
    .{ .shld, .mrc, &.{ .rm32, .r32, .cl   }, &.{ 0x0f, 0xa5 }, 0, .none,  .none },
    .{ .shld, .mrc, &.{ .rm64, .r64, .cl   }, &.{ 0x0f, 0xa5 }, 0, .long,  .none },

    .{ .shr, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 5, .none,  .none },
    .{ .shr, .m1, &.{ .rm8,  .unity }, &.{ 0xd0 }, 5, .rex,   .none },
    .{ .shr, .m1, &.{ .rm16, .unity }, &.{ 0xd1 }, 5, .short, .none },
    .{ .shr, .m1, &.{ .rm32, .unity }, &.{ 0xd1 }, 5, .none,  .none },
    .{ .shr, .m1, &.{ .rm64, .unity }, &.{ 0xd1 }, 5, .long,  .none },
    .{ .shr, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 5, .none,  .none },
    .{ .shr, .mc, &.{ .rm8,  .cl    }, &.{ 0xd2 }, 5, .rex,   .none },
    .{ .shr, .mc, &.{ .rm16, .cl    }, &.{ 0xd3 }, 5, .short, .none },
    .{ .shr, .mc, &.{ .rm32, .cl    }, &.{ 0xd3 }, 5, .none,  .none },
    .{ .shr, .mc, &.{ .rm64, .cl    }, &.{ 0xd3 }, 5, .long,  .none },
    .{ .shr, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 5, .none,  .none },
    .{ .shr, .mi, &.{ .rm8,  .imm8  }, &.{ 0xc0 }, 5, .rex,   .none },
    .{ .shr, .mi, &.{ .rm16, .imm8  }, &.{ 0xc1 }, 5, .short, .none },
    .{ .shr, .mi, &.{ .rm32, .imm8  }, &.{ 0xc1 }, 5, .none,  .none },
    .{ .shr, .mi, &.{ .rm64, .imm8  }, &.{ 0xc1 }, 5, .long,  .none },

    .{ .shrd, .mri, &.{ .rm16, .r16, .imm8 }, &.{ 0x0f, 0xac }, 0, .short, .none },
    .{ .shrd, .mrc, &.{ .rm16, .r16, .cl   }, &.{ 0x0f, 0xad }, 0, .short, .none },
    .{ .shrd, .mri, &.{ .rm32, .r32, .imm8 }, &.{ 0x0f, 0xac }, 0, .none,  .none },
    .{ .shrd, .mri, &.{ .rm64, .r64, .imm8 }, &.{ 0x0f, 0xac }, 0, .long,  .none },
    .{ .shrd, .mrc, &.{ .rm32, .r32, .cl   }, &.{ 0x0f, 0xad }, 0, .none,  .none },
    .{ .shrd, .mrc, &.{ .rm64, .r64, .cl   }, &.{ 0x0f, 0xad }, 0, .long,  .none },

    .{ .stos,  .zo, &.{ .m8  }, &.{ 0xaa }, 0, .none,  .none },
    .{ .stos,  .zo, &.{ .m16 }, &.{ 0xab }, 0, .short, .none },
    .{ .stos,  .zo, &.{ .m32 }, &.{ 0xab }, 0, .none,  .none },
    .{ .stos,  .zo, &.{ .m64 }, &.{ 0xab }, 0, .long,  .none },

    .{ .stosb, .zo, &.{}, &.{ 0xaa }, 0, .none,  .none },
    .{ .stosw, .zo, &.{}, &.{ 0xab }, 0, .short, .none },
    .{ .stosd, .zo, &.{}, &.{ 0xab }, 0, .none,  .none },
    .{ .stosq, .zo, &.{}, &.{ 0xab }, 0, .long,  .none },

    .{ .sub, .zi, &.{ .al,   .imm8   }, &.{ 0x2c }, 0, .none,  .none },
    .{ .sub, .zi, &.{ .ax,   .imm16  }, &.{ 0x2d }, 0, .short, .none },
    .{ .sub, .zi, &.{ .eax,  .imm32  }, &.{ 0x2d }, 0, .none,  .none },
    .{ .sub, .zi, &.{ .rax,  .imm32s }, &.{ 0x2d }, 0, .long,  .none },
    .{ .sub, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 5, .none,  .none },
    .{ .sub, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 5, .rex,   .none },
    .{ .sub, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 5, .short, .none },
    .{ .sub, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 5, .none,  .none },
    .{ .sub, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 5, .long,  .none },
    .{ .sub, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 5, .short, .none },
    .{ .sub, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 5, .none,  .none },
    .{ .sub, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 5, .long,  .none },
    .{ .sub, .mr, &.{ .rm8,  .r8     }, &.{ 0x28 }, 0, .none,  .none },
    .{ .sub, .mr, &.{ .rm8,  .r8     }, &.{ 0x28 }, 0, .rex,   .none },
    .{ .sub, .mr, &.{ .rm16, .r16    }, &.{ 0x29 }, 0, .short, .none },
    .{ .sub, .mr, &.{ .rm32, .r32    }, &.{ 0x29 }, 0, .none,  .none },
    .{ .sub, .mr, &.{ .rm64, .r64    }, &.{ 0x29 }, 0, .long,  .none },
    .{ .sub, .rm, &.{ .r8,   .rm8    }, &.{ 0x2a }, 0, .none,  .none },
    .{ .sub, .rm, &.{ .r8,   .rm8    }, &.{ 0x2a }, 0, .rex,   .none },
    .{ .sub, .rm, &.{ .r16,  .rm16   }, &.{ 0x2b }, 0, .short, .none },
    .{ .sub, .rm, &.{ .r32,  .rm32   }, &.{ 0x2b }, 0, .none,  .none },
    .{ .sub, .rm, &.{ .r64,  .rm64   }, &.{ 0x2b }, 0, .long,  .none },

    .{ .syscall, .zo, &.{}, &.{ 0x0f, 0x05 }, 0, .none, .none },

    .{ .@"test", .zi, &.{ .al,   .imm8   }, &.{ 0xa8 }, 0, .none,  .none },
    .{ .@"test", .zi, &.{ .ax,   .imm16  }, &.{ 0xa9 }, 0, .short, .none },
    .{ .@"test", .zi, &.{ .eax,  .imm32  }, &.{ 0xa9 }, 0, .none,  .none },
    .{ .@"test", .zi, &.{ .rax,  .imm32s }, &.{ 0xa9 }, 0, .long,  .none },
    .{ .@"test", .mi, &.{ .rm8,  .imm8   }, &.{ 0xf6 }, 0, .none,  .none },
    .{ .@"test", .mi, &.{ .rm8,  .imm8   }, &.{ 0xf6 }, 0, .rex,   .none },
    .{ .@"test", .mi, &.{ .rm16, .imm16  }, &.{ 0xf7 }, 0, .short, .none },
    .{ .@"test", .mi, &.{ .rm32, .imm32  }, &.{ 0xf7 }, 0, .none,  .none },
    .{ .@"test", .mi, &.{ .rm64, .imm32s }, &.{ 0xf7 }, 0, .long,  .none },
    .{ .@"test", .mr, &.{ .rm8,  .r8     }, &.{ 0x84 }, 0, .none,  .none },
    .{ .@"test", .mr, &.{ .rm8,  .r8     }, &.{ 0x84 }, 0, .rex,   .none },
    .{ .@"test", .mr, &.{ .rm16, .r16    }, &.{ 0x85 }, 0, .short, .none },
    .{ .@"test", .mr, &.{ .rm32, .r32    }, &.{ 0x85 }, 0, .none,  .none },
    .{ .@"test", .mr, &.{ .rm64, .r64    }, &.{ 0x85 }, 0, .long,  .none },

    .{ .tzcnt, .rm, &.{ .r16, .rm16 }, &.{ 0xf3, 0x0f, 0xbc }, 0, .short, .bmi },
    .{ .tzcnt, .rm, &.{ .r32, .rm32 }, &.{ 0xf3, 0x0f, 0xbc }, 0, .none,  .bmi },
    .{ .tzcnt, .rm, &.{ .r64, .rm64 }, &.{ 0xf3, 0x0f, 0xbc }, 0, .long,  .bmi },

    .{ .ud2, .zo, &.{}, &.{ 0x0f, 0x0b }, 0, .none, .none },

    .{ .xadd, .mr, &.{ .rm8,  .r8  }, &.{ 0x0f, 0xc0 }, 0, .none,  .none },
    .{ .xadd, .mr, &.{ .rm8,  .r8  }, &.{ 0x0f, 0xc0 }, 0, .rex,   .none },
    .{ .xadd, .mr, &.{ .rm16, .r16 }, &.{ 0x0f, 0xc1 }, 0, .short, .none },
    .{ .xadd, .mr, &.{ .rm32, .r32 }, &.{ 0x0f, 0xc1 }, 0, .none,  .none },
    .{ .xadd, .mr, &.{ .rm64, .r64 }, &.{ 0x0f, 0xc1 }, 0, .long,  .none },

    .{ .xchg, .o,  &.{ .ax,   .r16  }, &.{ 0x90 }, 0, .short, .none },
    .{ .xchg, .o,  &.{ .r16,  .ax   }, &.{ 0x90 }, 0, .short, .none },
    .{ .xchg, .o,  &.{ .eax,  .r32  }, &.{ 0x90 }, 0, .none,  .none },
    .{ .xchg, .o,  &.{ .rax,  .r64  }, &.{ 0x90 }, 0, .long,  .none },
    .{ .xchg, .o,  &.{ .r32,  .eax  }, &.{ 0x90 }, 0, .none,  .none },
    .{ .xchg, .o,  &.{ .r64,  .rax  }, &.{ 0x90 }, 0, .long,  .none },
    .{ .xchg, .mr, &.{ .rm8,  .r8   }, &.{ 0x86 }, 0, .none,  .none },
    .{ .xchg, .mr, &.{ .rm8,  .r8   }, &.{ 0x86 }, 0, .rex,   .none },
    .{ .xchg, .rm, &.{ .r8,   .rm8  }, &.{ 0x86 }, 0, .none,  .none },
    .{ .xchg, .rm, &.{ .r8,   .rm8  }, &.{ 0x86 }, 0, .rex,   .none },
    .{ .xchg, .mr, &.{ .rm16, .r16  }, &.{ 0x87 }, 0, .short, .none },
    .{ .xchg, .rm, &.{ .r16,  .rm16 }, &.{ 0x87 }, 0, .short, .none },
    .{ .xchg, .mr, &.{ .rm32, .r32  }, &.{ 0x87 }, 0, .none,  .none },
    .{ .xchg, .mr, &.{ .rm64, .r64  }, &.{ 0x87 }, 0, .long,  .none },
    .{ .xchg, .rm, &.{ .r32,  .rm32 }, &.{ 0x87 }, 0, .none,  .none },
    .{ .xchg, .rm, &.{ .r64,  .rm64 }, &.{ 0x87 }, 0, .long,  .none },

    .{ .xgetbv, .zo, &.{}, &.{ 0x0f, 0x01, 0xd0 }, 0, .none, .none },

    .{ .xor, .zi, &.{ .al,   .imm8   }, &.{ 0x34 }, 0, .none,  .none },
    .{ .xor, .zi, &.{ .ax,   .imm16  }, &.{ 0x35 }, 0, .short, .none },
    .{ .xor, .zi, &.{ .eax,  .imm32  }, &.{ 0x35 }, 0, .none,  .none },
    .{ .xor, .zi, &.{ .rax,  .imm32s }, &.{ 0x35 }, 0, .long,  .none },
    .{ .xor, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 6, .none,  .none },
    .{ .xor, .mi, &.{ .rm8,  .imm8   }, &.{ 0x80 }, 6, .rex,   .none },
    .{ .xor, .mi, &.{ .rm16, .imm16  }, &.{ 0x81 }, 6, .short, .none },
    .{ .xor, .mi, &.{ .rm32, .imm32  }, &.{ 0x81 }, 6, .none,  .none },
    .{ .xor, .mi, &.{ .rm64, .imm32s }, &.{ 0x81 }, 6, .long,  .none },
    .{ .xor, .mi, &.{ .rm16, .imm8s  }, &.{ 0x83 }, 6, .short, .none },
    .{ .xor, .mi, &.{ .rm32, .imm8s  }, &.{ 0x83 }, 6, .none,  .none },
    .{ .xor, .mi, &.{ .rm64, .imm8s  }, &.{ 0x83 }, 6, .long,  .none },
    .{ .xor, .mr, &.{ .rm8,  .r8     }, &.{ 0x30 }, 0, .none,  .none },
    .{ .xor, .mr, &.{ .rm8,  .r8     }, &.{ 0x30 }, 0, .rex,   .none },
    .{ .xor, .mr, &.{ .rm16, .r16    }, &.{ 0x31 }, 0, .short, .none },
    .{ .xor, .mr, &.{ .rm32, .r32    }, &.{ 0x31 }, 0, .none,  .none },
    .{ .xor, .mr, &.{ .rm64, .r64    }, &.{ 0x31 }, 0, .long,  .none },
    .{ .xor, .rm, &.{ .r8,   .rm8    }, &.{ 0x32 }, 0, .none,  .none },
    .{ .xor, .rm, &.{ .r8,   .rm8    }, &.{ 0x32 }, 0, .rex,   .none },
    .{ .xor, .rm, &.{ .r16,  .rm16   }, &.{ 0x33 }, 0, .short, .none },
    .{ .xor, .rm, &.{ .r32,  .rm32   }, &.{ 0x33 }, 0, .none,  .none },
    .{ .xor, .rm, &.{ .r64,  .rm64   }, &.{ 0x33 }, 0, .long,  .none },

    // X87
    .{ .fabs, .zo, &.{}, &.{ 0xd9, 0xe1 }, 0, .none, .x87 },

    .{ .fchs, .zo, &.{}, &.{ 0xd9, 0xe0 }, 0, .none, .x87 },

    .{ .ffree, .o, &.{ .st }, &.{ 0xdd, 0xc0 }, 0, .none, .x87 },

    .{ .fisttp, .m, &.{ .m16 }, &.{ 0xdf }, 1, .none, .x87 },
    .{ .fisttp, .m, &.{ .m32 }, &.{ 0xdb }, 1, .none, .x87 },
    .{ .fisttp, .m, &.{ .m64 }, &.{ 0xdd }, 1, .none, .x87 },

    .{ .fld, .m, &.{ .m32 }, &.{ 0xd9       }, 0, .none, .x87 },
    .{ .fld, .m, &.{ .m64 }, &.{ 0xdd       }, 0, .none, .x87 },
    .{ .fld, .m, &.{ .m80 }, &.{ 0xdb       }, 5, .none, .x87 },
    .{ .fld, .o, &.{ .st  }, &.{ 0xd9, 0xc0 }, 0, .none, .x87 },

    .{ .fldenv, .m, &.{ .m }, &.{ 0xd9 }, 4, .none, .x87 },

    .{ .fst,  .m, &.{ .m32 }, &.{ 0xd9       }, 2, .none, .x87 },
    .{ .fst,  .m, &.{ .m64 }, &.{ 0xdd       }, 2, .none, .x87 },
    .{ .fst,  .o, &.{ .st  }, &.{ 0xdd, 0xd0 }, 0, .none, .x87 },
    .{ .fstp, .m, &.{ .m32 }, &.{ 0xd9       }, 3, .none, .x87 },
    .{ .fstp, .m, &.{ .m64 }, &.{ 0xdd       }, 3, .none, .x87 },
    .{ .fstp, .m, &.{ .m80 }, &.{ 0xdb       }, 7, .none, .x87 },
    .{ .fstp, .o, &.{ .st  }, &.{ 0xdd, 0xd8 }, 0, .none, .x87 },

    .{ .fstenv,  .m, &.{ .m }, &.{ 0x9b, 0xd9 }, 6, .none, .x87 },
    .{ .fnstenv, .m, &.{ .m }, &.{       0xd9 }, 6, .none, .x87 },

    // SSE
    .{ .addps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x58 }, 0, .none, .sse },

    .{ .addss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x58 }, 0, .none, .sse },

    .{ .andnps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x55 }, 0, .none, .sse },

    .{ .andps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x54 }, 0, .none, .sse },

    .{ .cmpps, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x0f, 0xc2 }, 0, .none, .sse },

    .{ .cmpss, .rmi, &.{ .xmm, .xmm_m32, .imm8 }, &.{ 0xf3, 0x0f, 0xc2 }, 0, .none, .sse },

    .{ .cvtpi2ps, .rm, &.{ .xmm, .mm_m64 }, &.{ 0x0f, 0x2a }, 0, .none, .sse },

    .{ .cvtps2pi, .rm, &.{ .mm, .xmm_m64 }, &.{ 0x0f, 0x2d }, 0, .none, .sse },

    .{ .cvtsi2ss, .rm, &.{ .xmm, .rm32 }, &.{ 0xf3, 0x0f, 0x2a }, 0, .none, .sse },
    .{ .cvtsi2ss, .rm, &.{ .xmm, .rm64 }, &.{ 0xf3, 0x0f, 0x2a }, 0, .long, .sse },

    .{ .cvtss2si, .rm, &.{ .r32, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2d }, 0, .none, .sse },
    .{ .cvtss2si, .rm, &.{ .r64, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2d }, 0, .long, .sse },

    .{ .cvttps2pi, .rm, &.{ .mm, .xmm_m64 }, &.{ 0x0f, 0x2c }, 0, .none, .sse },

    .{ .cvttss2si, .rm, &.{ .r32, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2c }, 0, .none, .sse },
    .{ .cvttss2si, .rm, &.{ .r64, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2c }, 0, .long, .sse },

    .{ .divps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5e }, 0, .none, .sse },

    .{ .divss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5e }, 0, .none, .sse },

    .{ .ldmxcsr, .m, &.{ .m32 }, &.{ 0x0f, 0xae }, 2, .none, .sse },

    .{ .maxps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5f }, 0, .none, .sse },

    .{ .maxss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5f }, 0, .none, .sse },

    .{ .minps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5d }, 0, .none, .sse },

    .{ .minss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5d }, 0, .none, .sse },

    .{ .movaps, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x0f, 0x28 }, 0, .none, .sse },
    .{ .movaps, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x0f, 0x29 }, 0, .none, .sse },

    .{ .movhlps, .rm, &.{ .xmm, .xmm }, &.{ 0x0f, 0x12 }, 0, .none, .sse },

    .{ .movlhps, .rm, &.{ .xmm, .xmm }, &.{ 0x0f, 0x16 }, 0, .none, .sse },

    .{ .movmskps, .rm, &.{ .r32, .xmm }, &.{ 0x0f, 0x50 }, 0, .none, .sse },
    .{ .movmskps, .rm, &.{ .r64, .xmm }, &.{ 0x0f, 0x50 }, 0, .none, .sse },

    .{ .movss, .rm, &.{ .xmm,     .xmm_m32 }, &.{ 0xf3, 0x0f, 0x10 }, 0, .none, .sse },
    .{ .movss, .mr, &.{ .xmm_m32, .xmm     }, &.{ 0xf3, 0x0f, 0x11 }, 0, .none, .sse },

    .{ .movups, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x0f, 0x10 }, 0, .none, .sse },
    .{ .movups, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x0f, 0x11 }, 0, .none, .sse },

    .{ .mulps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x59 }, 0, .none, .sse },

    .{ .mulss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x59 }, 0, .none, .sse },

    .{ .orps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x56 }, 0, .none, .sse },

    .{ .pmovmskb, .rm, &.{ .r32, .xmm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .none, .sse },
    .{ .pmovmskb, .rm, &.{ .r64, .xmm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .none, .sse },

    .{ .shufps, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x0f, 0xc6 }, 0, .none, .sse },

    .{ .sqrtps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x51 }, 0, .none, .sse },

    .{ .sqrtss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x51 }, 0, .none, .sse },

    .{ .stmxcsr, .m, &.{ .m32 }, &.{ 0x0f, 0xae }, 3, .none, .sse },

    .{ .subps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5c }, 0, .none, .sse },

    .{ .subss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5c }, 0, .none, .sse },

    .{ .ucomiss, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x0f, 0x2e }, 0, .none, .sse },

    .{ .xorps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x57 }, 0, .none, .sse },

    // SSE2
    .{ .addpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x58 }, 0, .none, .sse2 },

    .{ .addsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x58 }, 0, .none, .sse2 },

    .{ .andnpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x55 }, 0, .none, .sse2 },

    .{ .andpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x54 }, 0, .none, .sse2 },

    .{ .cmppd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0xc2 }, 0, .none, .sse2 },

    .{ .cmpsd, .rmi, &.{ .xmm, .xmm_m64, .imm8 }, &.{ 0xf2, 0x0f, 0xc2 }, 0, .none, .sse2 },

    .{ .cvtdq2pd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf3, 0x0f, 0xe6 }, 0, .none, .sse2 },

    .{ .cvtdq2ps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5b }, 0, .none, .sse2 },

    .{ .cvtpd2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf2, 0x0f, 0xe6 }, 0, .none, .sse2 },

    .{ .cvtpd2pi, .rm, &.{ .mm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x2d }, 0, .none, .sse2 },

    .{ .cvtpd2ps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5a }, 0, .none, .sse2 },

    .{ .cvtpi2pd, .rm, &.{ .xmm, .mm_m64 }, &.{ 0x66, 0x0f, 0x2a }, 0, .none, .sse2 },

    .{ .cvtps2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5b }, 0, .none, .sse2 },

    .{ .cvtps2pd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x0f, 0x5a }, 0, .none, .sse2 },

    .{ .cvtsd2si, .rm, &.{ .r32, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2d }, 0, .none, .sse2 },
    .{ .cvtsd2si, .rm, &.{ .r64, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2d }, 0, .long, .sse2 },

    .{ .cvtsd2ss, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5a }, 0, .none, .sse2 },

    .{ .cvtsi2sd, .rm, &.{ .xmm, .rm32 }, &.{ 0xf2, 0x0f, 0x2a }, 0, .none, .sse2 },
    .{ .cvtsi2sd, .rm, &.{ .xmm, .rm64 }, &.{ 0xf2, 0x0f, 0x2a }, 0, .long, .sse2 },

    .{ .cvtss2sd, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5a }, 0, .none, .sse2 },

    .{ .cvttpd2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe6 }, 0, .none, .sse2 },

    .{ .cvttpd2pi, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x2c }, 0, .none, .sse2 },

    .{ .cvttps2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x5b }, 0, .none, .sse2 },

    .{ .cvttsd2si, .rm, &.{ .r32, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2c }, 0, .none, .sse2 },
    .{ .cvttsd2si, .rm, &.{ .r64, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2c }, 0, .long, .sse2 },

    .{ .divpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5e }, 0, .none, .sse2 },

    .{ .divsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5e }, 0, .none, .sse2 },

    .{ .maxpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5f }, 0, .none, .sse2 },

    .{ .maxsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5f }, 0, .none, .sse2 },

    .{ .minpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5d }, 0, .none, .sse2 },

    .{ .minsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5d }, 0, .none, .sse2 },

    .{ .movapd, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x28 }, 0, .none, .sse2 },
    .{ .movapd, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x29 }, 0, .none, .sse2 },

    .{ .movd, .rm, &.{ .xmm,  .rm32 }, &.{ 0x66, 0x0f, 0x6e }, 0, .none, .sse2 },
    .{ .movq, .rm, &.{ .xmm,  .rm64 }, &.{ 0x66, 0x0f, 0x6e }, 0, .long, .sse2 },
    .{ .movd, .mr, &.{ .rm32, .xmm  }, &.{ 0x66, 0x0f, 0x7e }, 0, .none, .sse2 },
    .{ .movq, .mr, &.{ .rm64, .xmm  }, &.{ 0x66, 0x0f, 0x7e }, 0, .long, .sse2 },

    .{ .movdqa, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x6f }, 0, .none, .sse2 },
    .{ .movdqa, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x7f }, 0, .none, .sse2 },

    .{ .movdqu, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0xf3, 0x0f, 0x6f }, 0, .none, .sse2 },
    .{ .movdqu, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0xf3, 0x0f, 0x7f }, 0, .none, .sse2 },

    .{ .movmskpd, .rm, &.{ .r32, .xmm }, &.{ 0x66, 0x0f, 0x50 }, 0, .none, .sse2 },
    .{ .movmskpd, .rm, &.{ .r64, .xmm }, &.{ 0x66, 0x0f, 0x50 }, 0, .none, .sse2 },

    .{ .movsd, .rm, &.{ .xmm,     .xmm_m64 }, &.{ 0xf2, 0x0f, 0x10 }, 0, .none, .sse2 },
    .{ .movsd, .mr, &.{ .xmm_m64, .xmm     }, &.{ 0xf2, 0x0f, 0x11 }, 0, .none, .sse2 },

    .{ .movq, .rm, &.{ .xmm,     .xmm_m64 }, &.{ 0xf3, 0x0f, 0x7e }, 0, .none, .sse2 },
    .{ .movq, .mr, &.{ .xmm_m64, .xmm     }, &.{ 0x66, 0x0f, 0xd6 }, 0, .none, .sse2 },

    .{ .movupd, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x10 }, 0, .none, .sse2 },
    .{ .movupd, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x11 }, 0, .none, .sse2 },

    .{ .mulpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x59 }, 0, .none, .sse2 },

    .{ .mulsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x59 }, 0, .none, .sse2 },

    .{ .orpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x56 }, 0, .none, .sse2 },

    .{ .packsswb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x63 }, 0, .none, .sse2 },
    .{ .packssdw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6b }, 0, .none, .sse2 },

    .{ .packuswb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x67 }, 0, .none, .sse2 },

    .{ .paddb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfc }, 0, .none, .sse2 },
    .{ .paddw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfd }, 0, .none, .sse2 },
    .{ .paddd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfe }, 0, .none, .sse2 },
    .{ .paddq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd4 }, 0, .none, .sse2 },

    .{ .paddsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xec }, 0, .none, .sse2 },
    .{ .paddsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xed }, 0, .none, .sse2 },

    .{ .paddusb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdc }, 0, .none, .sse2 },
    .{ .paddusw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdd }, 0, .none, .sse2 },

    .{ .pand, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdb }, 0, .none, .sse2 },

    .{ .pandn, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdf }, 0, .none, .sse2 },

    .{ .pcmpeqb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x74 }, 0, .none, .sse2 },
    .{ .pcmpeqw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x75 }, 0, .none, .sse2 },
    .{ .pcmpeqd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x76 }, 0, .none, .sse2 },

    .{ .pcmpgtb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x64 }, 0, .none, .sse2 },
    .{ .pcmpgtw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x65 }, 0, .none, .sse2 },
    .{ .pcmpgtd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x66 }, 0, .none, .sse2 },

    .{ .pextrw, .rmi, &.{ .r32, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0xc5 }, 0, .none, .sse2 },

    .{ .pinsrw, .rmi, &.{ .xmm, .r32_m16, .imm8 }, &.{ 0x66, 0x0f, 0xc4 }, 0, .none, .sse2 },

    .{ .pmaxsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xee }, 0, .none, .sse2 },

    .{ .pmaxub, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xde }, 0, .none, .sse2 },

    .{ .pminsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xea }, 0, .none, .sse2 },

    .{ .pminub, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xda }, 0, .none, .sse2 },

    .{ .pmulhw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe5 }, 0, .none, .sse2 },

    .{ .pmullw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd5 }, 0, .none, .sse2 },

    .{ .por, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xeb }, 0, .none, .sse2 },

    .{ .pshufd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x70 }, 0, .none, .sse2 },

    .{ .pshufhw, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0xf3, 0x0f, 0x70 }, 0, .none, .sse2 },

    .{ .pshuflw, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0xf2, 0x0f, 0x70 }, 0, .none, .sse2 },

    .{ .psllw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf1 }, 0, .none, .sse2 },
    .{ .psllw, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 6, .none, .sse2 },
    .{ .pslld, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf2 }, 0, .none, .sse2 },
    .{ .pslld, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 6, .none, .sse2 },
    .{ .psllq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf3 }, 0, .none, .sse2 },
    .{ .psllq, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 6, .none, .sse2 },

    .{ .pslldq, .mi, &.{ .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 7, .none, .sse2 },

    .{ .psraw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe1 }, 0, .none, .sse2 },
    .{ .psraw, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 4, .none, .sse2 },
    .{ .psrad, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe2 }, 0, .none, .sse2 },
    .{ .psrad, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 4, .none, .sse2 },

    .{ .psrlw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd1 }, 0, .none, .sse2 },
    .{ .psrlw, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 2, .none, .sse2 },
    .{ .psrld, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd2 }, 0, .none, .sse2 },
    .{ .psrld, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 2, .none, .sse2 },
    .{ .psrlq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd3 }, 0, .none, .sse2 },
    .{ .psrlq, .mi, &.{ .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 2, .none, .sse2 },

    .{ .psrldq, .mi, &.{ .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 3, .none, .sse2 },

    .{ .psubb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf8 }, 0, .none, .sse2 },
    .{ .psubw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf9 }, 0, .none, .sse2 },
    .{ .psubd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfa }, 0, .none, .sse2 },

    .{ .psubsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe8 }, 0, .none, .sse2 },
    .{ .psubsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe9 }, 0, .none, .sse2 },

    .{ .psubq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfb }, 0, .none, .sse2 },

    .{ .psubusb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd8 }, 0, .none, .sse2 },
    .{ .psubusw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd9 }, 0, .none, .sse2 },

    .{ .punpckhbw,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x68 }, 0, .none, .sse2 },
    .{ .punpckhwd,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x69 }, 0, .none, .sse2 },
    .{ .punpckhdq,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6a }, 0, .none, .sse2 },
    .{ .punpckhqdq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6d }, 0, .none, .sse2 },

    .{ .punpcklbw,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x60 }, 0, .none, .sse2 },
    .{ .punpcklwd,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x61 }, 0, .none, .sse2 },
    .{ .punpckldq,  .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x62 }, 0, .none, .sse2 },
    .{ .punpcklqdq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6c }, 0, .none, .sse2 },

    .{ .pxor, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xef }, 0, .none, .sse2 },

    .{ .shufpd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0xc6 }, 0, .none, .sse2 },

    .{ .sqrtpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x51 }, 0, .none, .sse2 },

    .{ .sqrtsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x51 }, 0, .none, .sse2 },

    .{ .subpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5c }, 0, .none, .sse2 },

    .{ .subsd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5c }, 0, .none, .sse2 },

    .{ .ucomisd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x2e }, 0, .none, .sse2 },

    .{ .xorpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x57 }, 0, .none, .sse2 },

    // SSE3
    .{ .movddup, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x12 }, 0, .none, .sse3 },

    .{ .movshdup, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x16 }, 0, .none, .sse3 },

    .{ .movsldup, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x12 }, 0, .none, .sse3 },

    // SSSE3
    .{ .pabsb, .rm, &.{  .mm,  .mm_m64  }, &.{       0x0f, 0x38, 0x1c }, 0, .none, .ssse3 },
    .{ .pabsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1c }, 0, .none, .ssse3 },
    .{ .pabsd, .rm, &.{  .mm,  .mm_m64  }, &.{       0x0f, 0x38, 0x1e }, 0, .none, .ssse3 },
    .{ .pabsd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1e }, 0, .none, .ssse3 },
    .{ .pabsw, .rm, &.{  .mm,  .mm_m64  }, &.{       0x0f, 0x38, 0x1d }, 0, .none, .ssse3 },
    .{ .pabsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1d }, 0, .none, .ssse3 },

    .{ .palignr, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0f }, 0, .none, .ssse3 },

    .{ .pshufb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x00 }, 0, .none, .ssse3 },

    // SSE4.1
    .{ .blendpd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0d }, 0, .none, .sse4_1 },

    .{ .blendps, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0c }, 0, .none, .sse4_1 },

    .{ .blendvpd, .rm,  &.{ .xmm, .xmm_m128        }, &.{ 0x66, 0x0f, 0x38, 0x15 }, 0, .none, .sse4_1 },
    .{ .blendvpd, .rm0, &.{ .xmm, .xmm_m128, .xmm0 }, &.{ 0x66, 0x0f, 0x38, 0x15 }, 0, .none, .sse4_1 },

    .{ .blendvps, .rm,  &.{ .xmm, .xmm_m128        }, &.{ 0x66, 0x0f, 0x38, 0x14 }, 0, .none, .sse4_1 },
    .{ .blendvps, .rm0, &.{ .xmm, .xmm_m128, .xmm0 }, &.{ 0x66, 0x0f, 0x38, 0x14 }, 0, .none, .sse4_1 },

    .{ .extractps, .mri, &.{ .rm32, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x17 }, 0, .none, .sse4_1 },

    .{ .insertps, .rmi, &.{ .xmm, .xmm_m32, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x21 }, 0, .none, .sse4_1 },

    .{ .packusdw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x2b }, 0, .none, .sse4_1 },

    .{ .pblendvb, .rm, &.{ .xmm, .xmm_m128        }, &.{ 0x66, 0x0f, 0x38, 0x10 }, 0, .none, .sse4_1 },
    .{ .pblendvb, .rm, &.{ .xmm, .xmm_m128, .xmm0 }, &.{ 0x66, 0x0f, 0x38, 0x10 }, 0, .none, .sse4_1 },

    .{ .pblendw, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0e }, 0, .none, .sse4_1 },

    .{ .pcmpeqq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x29 }, 0, .none, .sse4_1 },

    .{ .pextrb, .mri, &.{ .r32_m8, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x14 }, 0, .none, .sse4_1 },
    .{ .pextrd, .mri, &.{ .rm32,   .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x16 }, 0, .none, .sse4_1 },
    .{ .pextrq, .mri, &.{ .rm64,   .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x16 }, 0, .long, .sse4_1 },

    .{ .pextrw, .mri, &.{ .r32_m16, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x15 }, 0, .none, .sse4_1 },

    .{ .pinsrb, .rmi, &.{ .xmm, .r32_m8, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x20 }, 0, .none, .sse4_1 },
    .{ .pinsrd, .rmi, &.{ .xmm, .rm32,   .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x22 }, 0, .none, .sse4_1 },
    .{ .pinsrq, .rmi, &.{ .xmm, .rm64,   .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x22 }, 0, .long, .sse4_1 },

    .{ .pmaxsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3c }, 0, .none, .sse4_1 },
    .{ .pmaxsd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3d }, 0, .none, .sse4_1 },

    .{ .pmaxuw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3e }, 0, .none, .sse4_1 },

    .{ .pmaxud, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3f }, 0, .none, .sse4_1 },

    .{ .pminsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x38 }, 0, .none, .sse4_1 },
    .{ .pminsd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x39 }, 0, .none, .sse4_1 },

    .{ .pminuw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3a }, 0, .none, .sse4_1 },

    .{ .pminud, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3b }, 0, .none, .sse4_1 },

    .{ .pmovsxbw, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x20 }, 0, .none, .sse4_1 },
    .{ .pmovsxbd, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x21 }, 0, .none, .sse4_1 },
    .{ .pmovsxbq, .rm, &.{ .xmm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x22 }, 0, .none, .sse4_1 },
    .{ .pmovsxwd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x23 }, 0, .none, .sse4_1 },
    .{ .pmovsxwq, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x24 }, 0, .none, .sse4_1 },
    .{ .pmovsxdq, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x25 }, 0, .none, .sse4_1 },

    .{ .pmovzxbw, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x30 }, 0, .none, .sse4_1 },
    .{ .pmovzxbd, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x31 }, 0, .none, .sse4_1 },
    .{ .pmovzxbq, .rm, &.{ .xmm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x32 }, 0, .none, .sse4_1 },
    .{ .pmovzxwd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x33 }, 0, .none, .sse4_1 },
    .{ .pmovzxwq, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x34 }, 0, .none, .sse4_1 },
    .{ .pmovzxdq, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x35 }, 0, .none, .sse4_1 },

    .{ .pmulld, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x40 }, 0, .none, .sse4_1 },

    .{ .roundpd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x09 }, 0, .none, .sse4_1 },

    .{ .roundps, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x08 }, 0, .none, .sse4_1 },

    .{ .roundsd, .rmi, &.{ .xmm, .xmm_m64, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0b }, 0, .none, .sse4_1 },

    .{ .roundss, .rmi, &.{ .xmm, .xmm_m32, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0a }, 0, .none, .sse4_1 },

    // SSE4.2
    .{ .pcmpgtq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x37 }, 0, .none, .sse4_2 },

    // PCLMUL
    .{ .pclmulqdq, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x44 }, 0, .none, .pclmul },

    // AES
    .{ .aesdec, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xde }, 0, .none, .aes },

    .{ .aesdeclast, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdf }, 0, .none, .aes },

    .{ .aesenc, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdc }, 0, .none, .aes },

    .{ .aesenclast, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdd }, 0, .none, .aes },

    .{ .aesimc, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdb }, 0, .none, .aes },

    .{ .aeskeygenassist, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0xdf }, 0, .none, .aes },

    // SHA
    .{ .sha256msg1, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x38, 0xcc }, 0, .none, .sha },

    .{ .sha256msg2, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x38, 0xcd }, 0, .none, .sha },

    .{ .sha256rnds2, .rm,  &.{ .xmm, .xmm_m128        }, &.{ 0x0f, 0x38, 0xcb }, 0, .none, .sha },
    .{ .sha256rnds2, .rm0, &.{ .xmm, .xmm_m128, .xmm0 }, &.{ 0x0f, 0x38, 0xcb }, 0, .none, .sha },

    // AVX
    .{ .vaddpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x58 }, 0, .vex_128_wig, .avx },
    .{ .vaddpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x58 }, 0, .vex_256_wig, .avx },

    .{ .vaddps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x58 }, 0, .vex_128_wig, .avx },
    .{ .vaddps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x58 }, 0, .vex_256_wig, .avx },

    .{ .vaddsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x58 }, 0, .vex_lig_wig, .avx },

    .{ .vaddss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x58 }, 0, .vex_lig_wig, .avx },

    .{ .vaesdec, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xde }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vaesdeclast, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdf }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vaesenc, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdc }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vaesenclast, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdd }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vaesimc, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xdb }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vaeskeygenassist, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0xdf }, 0, .vex_128_wig, .@"aes avx" },

    .{ .vandnpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x55 }, 0, .vex_128_wig, .avx },
    .{ .vandnpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x55 }, 0, .vex_256_wig, .avx },

    .{ .vandnps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x55 }, 0, .vex_128_wig, .avx },
    .{ .vandnps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x55 }, 0, .vex_256_wig, .avx },

    .{ .vandpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x54 }, 0, .vex_128_wig, .avx },
    .{ .vandpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x54 }, 0, .vex_256_wig, .avx },

    .{ .vandps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x54 }, 0, .vex_128_wig, .avx },
    .{ .vandps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x54 }, 0, .vex_256_wig, .avx },

    .{ .vblendpd, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0d }, 0, .vex_128_wig, .avx },
    .{ .vblendpd, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0d }, 0, .vex_256_wig, .avx },

    .{ .vblendps, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0c }, 0, .vex_128_wig, .avx },
    .{ .vblendps, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0c }, 0, .vex_256_wig, .avx },

    .{ .vblendvpd, .rvmr, &.{ .xmm, .xmm, .xmm_m128, .xmm }, &.{ 0x66, 0x0f, 0x3a, 0x4b }, 0, .vex_128_w0, .avx },
    .{ .vblendvpd, .rvmr, &.{ .ymm, .ymm, .ymm_m256, .ymm }, &.{ 0x66, 0x0f, 0x3a, 0x4b }, 0, .vex_256_w0, .avx },

    .{ .vblendvps, .rvmr, &.{ .xmm, .xmm, .xmm_m128, .xmm }, &.{ 0x66, 0x0f, 0x3a, 0x4a }, 0, .vex_128_w0, .avx },
    .{ .vblendvps, .rvmr, &.{ .ymm, .ymm, .ymm_m256, .ymm }, &.{ 0x66, 0x0f, 0x3a, 0x4a }, 0, .vex_256_w0, .avx },

    .{ .vbroadcastss,   .rm, &.{ .xmm, .m32  }, &.{ 0x66, 0x0f, 0x38, 0x18 }, 0, .vex_128_w0, .avx },
    .{ .vbroadcastss,   .rm, &.{ .ymm, .m32  }, &.{ 0x66, 0x0f, 0x38, 0x18 }, 0, .vex_256_w0, .avx },
    .{ .vbroadcastsd,   .rm, &.{ .ymm, .m64  }, &.{ 0x66, 0x0f, 0x38, 0x19 }, 0, .vex_256_w0, .avx },
    .{ .vbroadcastf128, .rm, &.{ .ymm, .m128 }, &.{ 0x66, 0x0f, 0x38, 0x1a }, 0, .vex_256_w0, .avx },

    .{ .vcmppd, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0xc2 }, 0, .vex_128_wig, .avx },
    .{ .vcmppd, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0xc2 }, 0, .vex_256_wig, .avx },

    .{ .vcmpps, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x0f, 0xc2 }, 0, .vex_128_wig, .avx },
    .{ .vcmpps, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x0f, 0xc2 }, 0, .vex_256_wig, .avx },

    .{ .vcmpsd, .rvmi, &.{ .xmm, .xmm, .xmm_m64, .imm8 }, &.{ 0xf2, 0x0f, 0xc2 }, 0, .vex_lig_wig, .avx },

    .{ .vcmpss, .rvmi, &.{ .xmm, .xmm, .xmm_m32, .imm8 }, &.{ 0xf3, 0x0f, 0xc2 }, 0, .vex_lig_wig, .avx },

    .{ .vcvtdq2pd, .rm, &.{ .xmm, .xmm_m64  }, &.{ 0xf3, 0x0f, 0xe6 }, 0, .vex_128_wig, .avx },
    .{ .vcvtdq2pd, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0xe6 }, 0, .vex_256_wig, .avx },

    .{ .vcvtdq2ps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x5b }, 0, .vex_128_wig, .avx },
    .{ .vcvtdq2ps, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x0f, 0x5b }, 0, .vex_256_wig, .avx },

    .{ .vcvtpd2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf2, 0x0f, 0xe6 }, 0, .vex_128_wig, .avx },
    .{ .vcvtpd2dq, .rm, &.{ .xmm, .ymm_m256 }, &.{ 0xf2, 0x0f, 0xe6 }, 0, .vex_256_wig, .avx },

    .{ .vcvtpd2ps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5a }, 0, .vex_128_wig, .avx },
    .{ .vcvtpd2ps, .rm, &.{ .xmm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5a }, 0, .vex_256_wig, .avx },

    .{ .vcvtps2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5b }, 0, .vex_128_wig, .avx },
    .{ .vcvtps2dq, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5b }, 0, .vex_256_wig, .avx },

    .{ .vcvtps2pd, .rm, &.{ .xmm, .xmm_m64  }, &.{ 0x0f, 0x5a }, 0, .vex_128_wig, .avx },
    .{ .vcvtps2pd, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x0f, 0x5a }, 0, .vex_256_wig, .avx },

    .{ .vcvtsd2si, .rm, &.{ .r32, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2d }, 0, .vex_lig_w0, .sse2 },
    .{ .vcvtsd2si, .rm, &.{ .r64, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2d }, 0, .vex_lig_w1, .sse2 },

    .{ .vcvtsd2ss, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5a }, 0, .vex_lig_wig, .avx },

    .{ .vcvtsi2sd, .rvm, &.{ .xmm, .xmm, .rm32 }, &.{ 0xf2, 0x0f, 0x2a }, 0, .vex_lig_w0, .avx },
    .{ .vcvtsi2sd, .rvm, &.{ .xmm, .xmm, .rm64 }, &.{ 0xf2, 0x0f, 0x2a }, 0, .vex_lig_w1, .avx },

    .{ .vcvtsi2ss, .rvm, &.{ .xmm, .xmm, .rm32 }, &.{ 0xf3, 0x0f, 0x2a }, 0, .vex_lig_w0, .avx },
    .{ .vcvtsi2ss, .rvm, &.{ .xmm, .xmm, .rm64 }, &.{ 0xf3, 0x0f, 0x2a }, 0, .vex_lig_w1, .avx },

    .{ .vcvtss2sd, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5a }, 0, .vex_lig_wig, .avx },

    .{ .vcvtss2si, .rm, &.{ .r32, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2d }, 0, .vex_lig_w0, .avx },
    .{ .vcvtss2si, .rm, &.{ .r64, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2d }, 0, .vex_lig_w1, .avx },

    .{ .vcvttpd2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe6 }, 0, .vex_128_wig, .avx },
    .{ .vcvttpd2dq, .rm, &.{ .xmm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xe6 }, 0, .vex_256_wig, .avx },

    .{ .vcvttps2dq, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x5b }, 0, .vex_128_wig, .avx },
    .{ .vcvttps2dq, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0xf3, 0x0f, 0x5b }, 0, .vex_256_wig, .avx },

    .{ .vcvttsd2si, .rm, &.{ .r32, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2c }, 0, .vex_lig_w0, .sse2 },
    .{ .vcvttsd2si, .rm, &.{ .r64, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x2c }, 0, .vex_lig_w1, .sse2 },

    .{ .vcvttss2si, .rm, &.{ .r32, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2c }, 0, .vex_lig_w0, .avx },
    .{ .vcvttss2si, .rm, &.{ .r64, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x2c }, 0, .vex_lig_w1, .avx },

    .{ .vdivpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5e }, 0, .vex_128_wig, .avx },
    .{ .vdivpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5e }, 0, .vex_256_wig, .avx },

    .{ .vdivps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x5e }, 0, .vex_128_wig, .avx },
    .{ .vdivps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x5e }, 0, .vex_256_wig, .avx },

    .{ .vdivsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5e }, 0, .vex_lig_wig, .avx },

    .{ .vdivss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5e }, 0, .vex_lig_wig, .avx },

    .{ .vextractf128, .mri, &.{ .xmm_m128, .ymm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x19 }, 0, .vex_256_w0, .avx },

    .{ .vextractps, .mri, &.{ .rm32, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x17 }, 0, .vex_128_wig, .avx },

    .{ .vinsertf128, .rvmi, &.{ .ymm, .ymm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x18 }, 0, .vex_256_w0, .avx },

    .{ .vinsertps, .rvmi, &.{ .xmm, .xmm, .xmm_m32, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x21 }, 0, .vex_128_wig, .avx },

    .{ .vldmxcsr, .m, &.{ .m32 }, &.{ 0x0f, 0xae }, 2, .vex_lz_wig, .avx },

    .{ .vmaxpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5f }, 0, .vex_128_wig, .avx },
    .{ .vmaxpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5f }, 0, .vex_256_wig, .avx },

    .{ .vmaxps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x5f }, 0, .vex_128_wig, .avx },
    .{ .vmaxps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x5f }, 0, .vex_256_wig, .avx },

    .{ .vmaxsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5f }, 0, .vex_lig_wig, .avx },

    .{ .vmaxss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5f }, 0, .vex_lig_wig, .avx },

    .{ .vmovmskps, .rm, &.{ .r32, .xmm }, &.{ 0x0f, 0x50 }, 0, .vex_128_wig, .avx },
    .{ .vmovmskps, .rm, &.{ .r64, .xmm }, &.{ 0x0f, 0x50 }, 0, .vex_128_wig, .avx },
    .{ .vmovmskps, .rm, &.{ .r32, .ymm }, &.{ 0x0f, 0x50 }, 0, .vex_256_wig, .avx },
    .{ .vmovmskps, .rm, &.{ .r64, .ymm }, &.{ 0x0f, 0x50 }, 0, .vex_256_wig, .avx },

    .{ .vmovmskpd, .rm, &.{ .r32, .xmm }, &.{ 0x66, 0x0f, 0x50 }, 0, .vex_128_wig, .avx },
    .{ .vmovmskpd, .rm, &.{ .r64, .xmm }, &.{ 0x66, 0x0f, 0x50 }, 0, .vex_128_wig, .avx },
    .{ .vmovmskpd, .rm, &.{ .r32, .ymm }, &.{ 0x66, 0x0f, 0x50 }, 0, .vex_256_wig, .avx },
    .{ .vmovmskpd, .rm, &.{ .r64, .ymm }, &.{ 0x66, 0x0f, 0x50 }, 0, .vex_256_wig, .avx },

    .{ .vminpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5d }, 0, .vex_128_wig, .avx },
    .{ .vminpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5d }, 0, .vex_256_wig, .avx },

    .{ .vminps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x5d }, 0, .vex_128_wig, .avx },
    .{ .vminps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x5d }, 0, .vex_256_wig, .avx },

    .{ .vminsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5d }, 0, .vex_lig_wig, .avx },

    .{ .vminss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5d }, 0, .vex_lig_wig, .avx },

    .{ .vmovapd, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x28 }, 0, .vex_128_wig, .avx },
    .{ .vmovapd, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x29 }, 0, .vex_128_wig, .avx },
    .{ .vmovapd, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0x66, 0x0f, 0x28 }, 0, .vex_256_wig, .avx },
    .{ .vmovapd, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0x66, 0x0f, 0x29 }, 0, .vex_256_wig, .avx },

    .{ .vmovaps, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x0f, 0x28 }, 0, .vex_128_wig, .avx },
    .{ .vmovaps, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x0f, 0x29 }, 0, .vex_128_wig, .avx },
    .{ .vmovaps, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0x0f, 0x28 }, 0, .vex_256_wig, .avx },
    .{ .vmovaps, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0x0f, 0x29 }, 0, .vex_256_wig, .avx },

    .{ .vmovd, .rm, &.{ .xmm,  .rm32 }, &.{ 0x66, 0x0f, 0x6e }, 0, .vex_128_w0, .avx },
    .{ .vmovq, .rm, &.{ .xmm,  .rm64 }, &.{ 0x66, 0x0f, 0x6e }, 0, .vex_128_w1, .avx },
    .{ .vmovd, .mr, &.{ .rm32, .xmm  }, &.{ 0x66, 0x0f, 0x7e }, 0, .vex_128_w0, .avx },
    .{ .vmovq, .mr, &.{ .rm64, .xmm  }, &.{ 0x66, 0x0f, 0x7e }, 0, .vex_128_w1, .avx },

    .{ .vmovddup, .rm, &.{ .xmm, .xmm_m64  }, &.{ 0xf2, 0x0f, 0x12 }, 0, .vex_128_wig, .avx },
    .{ .vmovddup, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0xf2, 0x0f, 0x12 }, 0, .vex_256_wig, .avx },

    .{ .vmovdqa, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x6f }, 0, .vex_128_wig, .avx },
    .{ .vmovdqa, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x7f }, 0, .vex_128_wig, .avx },
    .{ .vmovdqa, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0x66, 0x0f, 0x6f }, 0, .vex_256_wig, .avx },
    .{ .vmovdqa, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0x66, 0x0f, 0x7f }, 0, .vex_256_wig, .avx },

    .{ .vmovdqu, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0xf3, 0x0f, 0x6f }, 0, .vex_128_wig, .avx },
    .{ .vmovdqu, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0xf3, 0x0f, 0x7f }, 0, .vex_128_wig, .avx },
    .{ .vmovdqu, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0xf3, 0x0f, 0x6f }, 0, .vex_256_wig, .avx },
    .{ .vmovdqu, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0xf3, 0x0f, 0x7f }, 0, .vex_256_wig, .avx },

    .{ .vmovhlps, .rvm, &.{ .xmm, .xmm, .xmm }, &.{ 0x0f, 0x12 }, 0, .vex_128_wig, .avx },

    .{ .vmovlhps, .rvm, &.{ .xmm, .xmm, .xmm }, &.{ 0x0f, 0x16 }, 0, .vex_128_wig, .avx },

    .{ .vmovq, .rm, &.{ .xmm,     .xmm_m64 }, &.{ 0xf3, 0x0f, 0x7e }, 0, .vex_128_wig, .avx },
    .{ .vmovq, .mr, &.{ .xmm_m64, .xmm     }, &.{ 0x66, 0x0f, 0xd6 }, 0, .vex_128_wig, .avx },

    .{ .vmovsd, .rvm, &.{ .xmm, .xmm, .xmm }, &.{ 0xf2, 0x0f, 0x10 }, 0, .vex_lig_wig, .avx },
    .{ .vmovsd, .rm,  &.{       .xmm, .m64 }, &.{ 0xf2, 0x0f, 0x10 }, 0, .vex_lig_wig, .avx },
    .{ .vmovsd, .mvr, &.{ .xmm, .xmm, .xmm }, &.{ 0xf2, 0x0f, 0x11 }, 0, .vex_lig_wig, .avx },
    .{ .vmovsd, .mr,  &.{       .m64, .xmm }, &.{ 0xf2, 0x0f, 0x11 }, 0, .vex_lig_wig, .avx },

    .{ .vmovshdup, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x16 }, 0, .vex_128_wig, .avx },
    .{ .vmovshdup, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0xf3, 0x0f, 0x16 }, 0, .vex_256_wig, .avx },

    .{ .vmovsldup, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0xf3, 0x0f, 0x12 }, 0, .vex_128_wig, .avx },
    .{ .vmovsldup, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0xf3, 0x0f, 0x12 }, 0, .vex_256_wig, .avx },

    .{ .vmovss, .rvm, &.{ .xmm, .xmm, .xmm }, &.{ 0xf3, 0x0f, 0x10 }, 0, .vex_lig_wig, .avx },
    .{ .vmovss, .rm,  &.{       .xmm, .m32 }, &.{ 0xf3, 0x0f, 0x10 }, 0, .vex_lig_wig, .avx },
    .{ .vmovss, .mvr, &.{ .xmm, .xmm, .xmm }, &.{ 0xf3, 0x0f, 0x11 }, 0, .vex_lig_wig, .avx },
    .{ .vmovss, .mr,  &.{       .m32, .xmm }, &.{ 0xf3, 0x0f, 0x11 }, 0, .vex_lig_wig, .avx },

    .{ .vmovupd, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x66, 0x0f, 0x10 }, 0, .vex_128_wig, .avx },
    .{ .vmovupd, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x66, 0x0f, 0x11 }, 0, .vex_128_wig, .avx },
    .{ .vmovupd, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0x66, 0x0f, 0x10 }, 0, .vex_256_wig, .avx },
    .{ .vmovupd, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0x66, 0x0f, 0x11 }, 0, .vex_256_wig, .avx },

    .{ .vmovups, .rm, &.{ .xmm,      .xmm_m128 }, &.{ 0x0f, 0x10 }, 0, .vex_128_wig, .avx },
    .{ .vmovups, .mr, &.{ .xmm_m128, .xmm      }, &.{ 0x0f, 0x11 }, 0, .vex_128_wig, .avx },
    .{ .vmovups, .rm, &.{ .ymm,      .ymm_m256 }, &.{ 0x0f, 0x10 }, 0, .vex_256_wig, .avx },
    .{ .vmovups, .mr, &.{ .ymm_m256, .ymm      }, &.{ 0x0f, 0x11 }, 0, .vex_256_wig, .avx },

    .{ .vmulpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x59 }, 0, .vex_128_wig, .avx },
    .{ .vmulpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x59 }, 0, .vex_256_wig, .avx },

    .{ .vmulps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x59 }, 0, .vex_128_wig, .avx },
    .{ .vmulps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x59 }, 0, .vex_256_wig, .avx },

    .{ .vmulsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x59 }, 0, .vex_lig_wig, .avx },

    .{ .vmulss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x59 }, 0, .vex_lig_wig, .avx },

    .{ .vorpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x56 }, 0, .vex_128_wig, .avx },
    .{ .vorpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x56 }, 0, .vex_256_wig, .avx },

    .{ .vorps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x56 }, 0, .vex_128_wig, .avx },
    .{ .vorps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x56 }, 0, .vex_256_wig, .avx },

    .{ .vpabsb, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1c }, 0, .vex_128_wig, .avx },
    .{ .vpabsd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1e }, 0, .vex_128_wig, .avx },
    .{ .vpabsw, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x1d }, 0, .vex_128_wig, .avx },

    .{ .vpacksswb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x63 }, 0, .vex_128_wig, .avx },
    .{ .vpackssdw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6b }, 0, .vex_128_wig, .avx },

    .{ .vpackusdw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x2b }, 0, .vex_128_wig, .avx },

    .{ .vpackuswb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x67 }, 0, .vex_128_wig, .avx },

    .{ .vpaddb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfc }, 0, .vex_128_wig, .avx },
    .{ .vpaddw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfd }, 0, .vex_128_wig, .avx },
    .{ .vpaddd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfe }, 0, .vex_128_wig, .avx },
    .{ .vpaddq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd4 }, 0, .vex_128_wig, .avx },

    .{ .vpaddsb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xec }, 0, .vex_128_wig, .avx },
    .{ .vpaddsw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xed }, 0, .vex_128_wig, .avx },

    .{ .vpaddusb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdc }, 0, .vex_128_wig, .avx },
    .{ .vpaddusw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdd }, 0, .vex_128_wig, .avx },

    .{ .vpalignr, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0f }, 0, .vex_128_wig, .avx },

    .{ .vpand, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdb }, 0, .vex_128_wig, .avx },

    .{ .vpandn, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xdf }, 0, .vex_128_wig, .avx },

    .{ .vpblendvb, .rvmr, &.{ .xmm, .xmm, .xmm_m128, .xmm }, &.{ 0x66, 0x0f, 0x3a, 0x4c }, 0, .vex_128_w0, .avx },

    .{ .vpblendw, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0e }, 0, .vex_128_wig, .avx },

    .{ .vpclmulqdq, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x44 }, 0, .vex_128_wig, .@"pclmul avx" },

    .{ .vpcmpeqb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x74 }, 0, .vex_128_wig, .avx },
    .{ .vpcmpeqw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x75 }, 0, .vex_128_wig, .avx },
    .{ .vpcmpeqd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x76 }, 0, .vex_128_wig, .avx },

    .{ .vpcmpeqq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x29 }, 0, .vex_128_wig, .avx },

    .{ .vpcmpgtb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x64 }, 0, .vex_128_wig, .avx },
    .{ .vpcmpgtw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x65 }, 0, .vex_128_wig, .avx },
    .{ .vpcmpgtd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x66 }, 0, .vex_128_wig, .avx },

    .{ .vpcmpgtq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x37 }, 0, .vex_128_wig, .avx },

    .{ .vpextrb, .mri, &.{ .r32_m8, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x14 }, 0, .vex_128_w0, .avx },
    .{ .vpextrd, .mri, &.{ .rm32,   .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x16 }, 0, .vex_128_w0, .avx },
    .{ .vpextrq, .mri, &.{ .rm64,   .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x16 }, 0, .vex_128_w1, .avx },

    .{ .vpextrw, .rmi, &.{ .r32,     .xmm, .imm8 }, &.{ 0x66, 0x0f,       0x15 }, 0, .vex_128_wig, .avx },
    .{ .vpextrw, .mri, &.{ .r32_m16, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x15 }, 0, .vex_128_wig, .avx },

    .{ .vpinsrb, .rmi, &.{ .xmm, .r32_m8, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x20 }, 0, .vex_128_w0, .avx },
    .{ .vpinsrd, .rmi, &.{ .xmm, .rm32,   .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x22 }, 0, .vex_128_w0, .avx },
    .{ .vpinsrq, .rmi, &.{ .xmm, .rm64,   .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x22 }, 0, .vex_128_w1, .avx },

    .{ .vpinsrw, .rvmi, &.{ .xmm, .xmm, .r32_m16, .imm8 }, &.{ 0x66, 0x0f, 0xc4 }, 0, .vex_128_wig, .avx },

    .{ .vpmaxsb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3c }, 0, .vex_128_wig, .avx },
    .{ .vpmaxsw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f,       0xee }, 0, .vex_128_wig, .avx },
    .{ .vpmaxsd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3d }, 0, .vex_128_wig, .avx },

    .{ .vpmaxub, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f,       0xde }, 0, .vex_128_wig, .avx },
    .{ .vpmaxuw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3e }, 0, .vex_128_wig, .avx },

    .{ .vpmaxud, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3f }, 0, .vex_128_wig, .avx },

    .{ .vpminsb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x38 }, 0, .vex_128_wig, .avx },
    .{ .vpminsw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f,       0xea }, 0, .vex_128_wig, .avx },
    .{ .vpminsd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x39 }, 0, .vex_128_wig, .avx },

    .{ .vpminub, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f,       0xda }, 0, .vex_128_wig, .avx },
    .{ .vpminuw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3a }, 0, .vex_128_wig, .avx },

    .{ .vpminud, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x3b }, 0, .vex_128_wig, .avx },

    .{ .vpmovmskb, .rm, &.{ .r32, .xmm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .vex_128_wig, .avx },
    .{ .vpmovmskb, .rm, &.{ .r64, .xmm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .vex_128_wig, .avx },

    .{ .vpmovsxbw, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x20 }, 0, .vex_128_wig, .avx },
    .{ .vpmovsxbd, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x21 }, 0, .vex_128_wig, .avx },
    .{ .vpmovsxbq, .rm, &.{ .xmm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x22 }, 0, .vex_128_wig, .avx },
    .{ .vpmovsxwd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x23 }, 0, .vex_128_wig, .avx },
    .{ .vpmovsxwq, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x24 }, 0, .vex_128_wig, .avx },
    .{ .vpmovsxdq, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x25 }, 0, .vex_128_wig, .avx },

    .{ .vpmovzxbw, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x30 }, 0, .vex_128_wig, .avx },
    .{ .vpmovzxbd, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x31 }, 0, .vex_128_wig, .avx },
    .{ .vpmovzxbq, .rm, &.{ .xmm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x32 }, 0, .vex_128_wig, .avx },
    .{ .vpmovzxwd, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x33 }, 0, .vex_128_wig, .avx },
    .{ .vpmovzxwq, .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x34 }, 0, .vex_128_wig, .avx },
    .{ .vpmovzxdq, .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x35 }, 0, .vex_128_wig, .avx },

    .{ .vpmulhw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe5 }, 0, .vex_128_wig, .avx },

    .{ .vpmulld, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x40 }, 0, .vex_128_wig, .avx },

    .{ .vpmullw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd5 }, 0, .vex_128_wig, .avx },

    .{ .vpor, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xeb }, 0, .vex_128_wig, .avx },

    .{ .vpshufb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x00 }, 0, .vex_128_wig, .avx },

    .{ .vpshufd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x70 }, 0, .vex_128_wig, .avx },

    .{ .vpshufhw, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0xf3, 0x0f, 0x70 }, 0, .vex_128_wig, .avx },

    .{ .vpshuflw, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0xf2, 0x0f, 0x70 }, 0, .vex_128_wig, .avx },

    .{ .vpsllw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf1 }, 0, .vex_128_wig, .avx },
    .{ .vpsllw, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 6, .vex_128_wig, .avx },
    .{ .vpslld, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf2 }, 0, .vex_128_wig, .avx },
    .{ .vpslld, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 6, .vex_128_wig, .avx },
    .{ .vpsllq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf3 }, 0, .vex_128_wig, .avx },
    .{ .vpsllq, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 6, .vex_128_wig, .avx },

    .{ .vpslldq, .vmi, &.{ .xmm, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 7, .vex_128_wig, .avx },

    .{ .vpsraw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe1 }, 0, .vex_128_wig, .avx },
    .{ .vpsraw, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 4, .vex_128_wig, .avx },
    .{ .vpsrad, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe2 }, 0, .vex_128_wig, .avx },
    .{ .vpsrad, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 4, .vex_128_wig, .avx },

    .{ .vpsrlw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd1 }, 0, .vex_128_wig, .avx },
    .{ .vpsrlw, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 2, .vex_128_wig, .avx },
    .{ .vpsrld, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd2 }, 0, .vex_128_wig, .avx },
    .{ .vpsrld, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 2, .vex_128_wig, .avx },
    .{ .vpsrlq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd3 }, 0, .vex_128_wig, .avx },
    .{ .vpsrlq, .vmi, &.{ .xmm, .xmm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 2, .vex_128_wig, .avx },

    .{ .vpsrldq, .vmi, &.{ .xmm, .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 3, .vex_128_wig, .avx },

    .{ .vpsubb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf8 }, 0, .vex_128_wig, .avx },
    .{ .vpsubw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf9 }, 0, .vex_128_wig, .avx },
    .{ .vpsubd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfa }, 0, .vex_128_wig, .avx },

    .{ .vpsubsb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe8 }, 0, .vex_128_wig, .avx },
    .{ .vpsubsw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe9 }, 0, .vex_128_wig, .avx },

    .{ .vpsubq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xfb }, 0, .vex_128_wig, .avx },

    .{ .vpsubusb, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd8 }, 0, .vex_128_wig, .avx },
    .{ .vpsubusw, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd9 }, 0, .vex_128_wig, .avx },

    .{ .vpunpckhbw,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x68 }, 0, .vex_128_wig, .avx },
    .{ .vpunpckhwd,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x69 }, 0, .vex_128_wig, .avx },
    .{ .vpunpckhdq,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6a }, 0, .vex_128_wig, .avx },
    .{ .vpunpckhqdq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6d }, 0, .vex_128_wig, .avx },

    .{ .vpunpcklbw,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x60 }, 0, .vex_128_wig, .avx },
    .{ .vpunpcklwd,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x61 }, 0, .vex_128_wig, .avx },
    .{ .vpunpckldq,  .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x62 }, 0, .vex_128_wig, .avx },
    .{ .vpunpcklqdq, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x6c }, 0, .vex_128_wig, .avx },

    .{ .vpxor, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xef }, 0, .vex_128_wig, .avx },

    .{ .vroundpd, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x09 }, 0, .vex_128_wig, .avx },
    .{ .vroundpd, .rmi, &.{ .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x09 }, 0, .vex_256_wig, .avx },

    .{ .vroundps, .rmi, &.{ .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x08 }, 0, .vex_128_wig, .avx },
    .{ .vroundps, .rmi, &.{ .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x08 }, 0, .vex_256_wig, .avx },

    .{ .vroundsd, .rvmi, &.{ .xmm, .xmm, .xmm_m64, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0b }, 0, .vex_lig_wig, .avx },

    .{ .vroundss, .rvmi, &.{ .xmm, .xmm, .xmm_m32, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0a }, 0, .vex_lig_wig, .avx },

    .{ .vshufpd, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0xc6 }, 0, .vex_128_wig, .avx },
    .{ .vshufpd, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0xc6 }, 0, .vex_256_wig, .avx },

    .{ .vshufps, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x0f, 0xc6 }, 0, .vex_128_wig, .avx },
    .{ .vshufps, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x0f, 0xc6 }, 0, .vex_256_wig, .avx },

    .{ .vsqrtpd, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x51 }, 0, .vex_128_wig, .avx },
    .{ .vsqrtpd, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x51 }, 0, .vex_256_wig, .avx },

    .{ .vsqrtps, .rm, &.{ .xmm, .xmm_m128 }, &.{ 0x0f, 0x51 }, 0, .vex_128_wig, .avx },
    .{ .vsqrtps, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x0f, 0x51 }, 0, .vex_256_wig, .avx },

    .{ .vsqrtsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x51 }, 0, .vex_lig_wig, .avx },

    .{ .vsqrtss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x51 }, 0, .vex_lig_wig, .avx },

    .{ .vstmxcsr, .m, &.{ .m32 }, &.{ 0x0f, 0xae }, 3, .vex_lz_wig, .avx },

    .{ .vsubpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x5c }, 0, .vex_128_wig, .avx },
    .{ .vsubpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x5c }, 0, .vex_256_wig, .avx },

    .{ .vsubps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x5c }, 0, .vex_128_wig, .avx },
    .{ .vsubps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x5c }, 0, .vex_256_wig, .avx },

    .{ .vsubsd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0xf2, 0x0f, 0x5c }, 0, .vex_lig_wig, .avx },

    .{ .vsubss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0xf3, 0x0f, 0x5c }, 0, .vex_lig_wig, .avx },

    .{ .vxorpd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x57 }, 0, .vex_128_wig, .avx },
    .{ .vxorpd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x57 }, 0, .vex_256_wig, .avx },

    .{ .vxorps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x0f, 0x57 }, 0, .vex_128_wig, .avx },
    .{ .vxorps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x0f, 0x57 }, 0, .vex_256_wig, .avx },

    // F16C
    .{ .vcvtph2ps, .rm, &.{ .xmm, .xmm_m64  }, &.{ 0x66, 0x0f, 0x38, 0x13 }, 0, .vex_128_w0, .f16c },
    .{ .vcvtph2ps, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x13 }, 0, .vex_256_w0, .f16c },

    .{ .vcvtps2ph, .mri, &.{ .xmm_m64,  .xmm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x1d }, 0, .vex_128_w0, .f16c },
    .{ .vcvtps2ph, .mri, &.{ .xmm_m128, .ymm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x1d }, 0, .vex_256_w0, .f16c },

    // FMA
    .{ .vfmadd132pd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x98 }, 0, .vex_128_w1, .fma },
    .{ .vfmadd213pd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xa8 }, 0, .vex_128_w1, .fma },
    .{ .vfmadd231pd, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xb8 }, 0, .vex_128_w1, .fma },
    .{ .vfmadd132pd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x98 }, 0, .vex_256_w1, .fma },
    .{ .vfmadd213pd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xa8 }, 0, .vex_256_w1, .fma },
    .{ .vfmadd231pd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xb8 }, 0, .vex_256_w1, .fma },

    .{ .vfmadd132ps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x98 }, 0, .vex_128_w0, .fma },
    .{ .vfmadd213ps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xa8 }, 0, .vex_128_w0, .fma },
    .{ .vfmadd231ps, .rvm, &.{ .xmm, .xmm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0xb8 }, 0, .vex_128_w0, .fma },
    .{ .vfmadd132ps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x98 }, 0, .vex_256_w0, .fma },
    .{ .vfmadd213ps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xa8 }, 0, .vex_256_w0, .fma },
    .{ .vfmadd231ps, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xb8 }, 0, .vex_256_w0, .fma },

    .{ .vfmadd132sd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x99 }, 0, .vex_lig_w1, .fma },
    .{ .vfmadd213sd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0xa9 }, 0, .vex_lig_w1, .fma },
    .{ .vfmadd231sd, .rvm, &.{ .xmm, .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0xb9 }, 0, .vex_lig_w1, .fma },

    .{ .vfmadd132ss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x99 }, 0, .vex_lig_w0, .fma },
    .{ .vfmadd213ss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0xa9 }, 0, .vex_lig_w0, .fma },
    .{ .vfmadd231ss, .rvm, &.{ .xmm, .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0xb9 }, 0, .vex_lig_w0, .fma },

    // VPCLMULQDQ
    .{ .vpclmulqdq, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x44 }, 0, .vex_256_wig, .vpclmulqdq },

    // VAES
    .{ .vaesdec, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xde }, 0, .vex_256_wig, .vaes },

    .{ .vaesdeclast, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xdf }, 0, .vex_256_wig, .vaes },

    .{ .vaesenc, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xdc }, 0, .vex_256_wig, .vaes },

    .{ .vaesenclast, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0xdd }, 0, .vex_256_wig, .vaes },

    // AVX2
    .{ .vbroadcastss, .rm, &.{ .xmm, .xmm }, &.{ 0x66, 0x0f, 0x38, 0x18 }, 0, .vex_128_w0, .avx2 },
    .{ .vbroadcastss, .rm, &.{ .ymm, .xmm }, &.{ 0x66, 0x0f, 0x38, 0x18 }, 0, .vex_256_w0, .avx2 },
    .{ .vbroadcastsd, .rm, &.{ .ymm, .xmm }, &.{ 0x66, 0x0f, 0x38, 0x19 }, 0, .vex_256_w0, .avx2 },

    .{ .vextracti128, .mri, &.{ .xmm_m128, .ymm, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x39 }, 0, .vex_256_w0, .avx2 },

    .{ .vinserti128, .rvmi, &.{ .ymm, .ymm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x38 }, 0, .vex_256_w0, .avx2 },

    .{ .vpabsb, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x1c }, 0, .vex_256_wig, .avx2 },
    .{ .vpabsd, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x1e }, 0, .vex_256_wig, .avx2 },
    .{ .vpabsw, .rm, &.{ .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x1d }, 0, .vex_256_wig, .avx2 },

    .{ .vpacksswb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x63 }, 0, .vex_256_wig, .avx2 },
    .{ .vpackssdw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x6b }, 0, .vex_256_wig, .avx2 },

    .{ .vpackusdw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x2b }, 0, .vex_256_wig, .avx2 },

    .{ .vpackuswb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x67 }, 0, .vex_256_wig, .avx2 },

    .{ .vpaddb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xfc }, 0, .vex_256_wig, .avx2 },
    .{ .vpaddw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xfd }, 0, .vex_256_wig, .avx2 },
    .{ .vpaddd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xfe }, 0, .vex_256_wig, .avx2 },
    .{ .vpaddq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xd4 }, 0, .vex_256_wig, .avx2 },

    .{ .vpaddsb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xec }, 0, .vex_256_wig, .avx2 },
    .{ .vpaddsw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xed }, 0, .vex_256_wig, .avx2 },

    .{ .vpaddusb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xdc }, 0, .vex_256_wig, .avx2 },
    .{ .vpaddusw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xdd }, 0, .vex_256_wig, .avx2 },

    .{ .vpalignr, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0f }, 0, .vex_256_wig, .avx2 },

    .{ .vpand, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xdb }, 0, .vex_256_wig, .avx2 },

    .{ .vpandn, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xdf }, 0, .vex_256_wig, .avx2 },

    .{ .vpblendd, .rvmi, &.{ .xmm, .xmm, .xmm_m128, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x02 }, 0, .vex_128_w0, .avx2 },
    .{ .vpblendd, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x02 }, 0, .vex_256_w0, .avx2 },

    .{ .vpblendvb, .rvmr, &.{ .ymm, .ymm, .ymm_m256, .ymm }, &.{ 0x66, 0x0f, 0x3a, 0x4c }, 0, .vex_256_w0, .avx2 },

    .{ .vpblendw, .rvmi, &.{ .ymm, .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x3a, 0x0e }, 0, .vex_256_wig, .avx2 },

    .{ .vpbroadcastb,    .rm, &.{ .xmm, .xmm_m8  }, &.{ 0x66, 0x0f, 0x38, 0x78 }, 0, .vex_128_w0, .avx2 },
    .{ .vpbroadcastb,    .rm, &.{ .ymm, .xmm_m8  }, &.{ 0x66, 0x0f, 0x38, 0x78 }, 0, .vex_256_w0, .avx2 },
    .{ .vpbroadcastw,    .rm, &.{ .xmm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x79 }, 0, .vex_128_w0, .avx2 },
    .{ .vpbroadcastw,    .rm, &.{ .ymm, .xmm_m16 }, &.{ 0x66, 0x0f, 0x38, 0x79 }, 0, .vex_256_w0, .avx2 },
    .{ .vpbroadcastd,    .rm, &.{ .xmm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x58 }, 0, .vex_128_w0, .avx2 },
    .{ .vpbroadcastd,    .rm, &.{ .ymm, .xmm_m32 }, &.{ 0x66, 0x0f, 0x38, 0x58 }, 0, .vex_256_w0, .avx2 },
    .{ .vpbroadcastq,    .rm, &.{ .xmm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x59 }, 0, .vex_128_w0, .avx2 },
    .{ .vpbroadcastq,    .rm, &.{ .ymm, .xmm_m64 }, &.{ 0x66, 0x0f, 0x38, 0x59 }, 0, .vex_256_w0, .avx2 },
    .{ .vbroadcasti128,  .rm, &.{ .ymm, .m128    }, &.{ 0x66, 0x0f, 0x38, 0x5a }, 0, .vex_256_w0, .avx2 },

    .{ .vpcmpeqb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x74 }, 0, .vex_256_wig, .avx2 },
    .{ .vpcmpeqw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x75 }, 0, .vex_256_wig, .avx2 },
    .{ .vpcmpeqd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x76 }, 0, .vex_256_wig, .avx2 },

    .{ .vpcmpeqq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x29 }, 0, .vex_256_wig, .avx2 },

    .{ .vpcmpgtb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x64 }, 0, .vex_256_wig, .avx2 },
    .{ .vpcmpgtw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x65 }, 0, .vex_256_wig, .avx2 },
    .{ .vpcmpgtd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x66 }, 0, .vex_256_wig, .avx2 },

    .{ .vpcmpgtq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x37 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmaxsb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3c }, 0, .vex_256_wig, .avx2 },
    .{ .vpmaxsw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f,       0xee }, 0, .vex_256_wig, .avx2 },
    .{ .vpmaxsd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3d }, 0, .vex_256_wig, .avx2 },

    .{ .vpmaxub, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f,       0xde }, 0, .vex_256_wig, .avx2 },
    .{ .vpmaxuw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3e }, 0, .vex_256_wig, .avx2 },

    .{ .vpmaxud, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3f }, 0, .vex_256_wig, .avx2 },

    .{ .vpminsb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x38 }, 0, .vex_256_wig, .avx2 },
    .{ .vpminsw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f,       0xea }, 0, .vex_256_wig, .avx2 },
    .{ .vpminsd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x39 }, 0, .vex_256_wig, .avx2 },

    .{ .vpminub, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f,       0xda }, 0, .vex_256_wig, .avx2 },
    .{ .vpminuw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3a }, 0, .vex_256_wig, .avx2 },

    .{ .vpminud, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x3b }, 0, .vex_256_wig, .avx2 },

    .{ .vpmovmskb, .rm, &.{ .r32, .ymm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovmskb, .rm, &.{ .r64, .ymm }, &.{ 0x66, 0x0f, 0xd7 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmovsxbw, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x20 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovsxbd, .rm, &.{ .ymm, .xmm_m64  }, &.{ 0x66, 0x0f, 0x38, 0x21 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovsxbq, .rm, &.{ .ymm, .xmm_m32  }, &.{ 0x66, 0x0f, 0x38, 0x22 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovsxwd, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x23 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovsxwq, .rm, &.{ .ymm, .xmm_m64  }, &.{ 0x66, 0x0f, 0x38, 0x24 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovsxdq, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x25 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmovzxbw, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x30 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovzxbd, .rm, &.{ .ymm, .xmm_m64  }, &.{ 0x66, 0x0f, 0x38, 0x31 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovzxbq, .rm, &.{ .ymm, .xmm_m32  }, &.{ 0x66, 0x0f, 0x38, 0x32 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovzxwd, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x33 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovzxwq, .rm, &.{ .ymm, .xmm_m64  }, &.{ 0x66, 0x0f, 0x38, 0x34 }, 0, .vex_256_wig, .avx2 },
    .{ .vpmovzxdq, .rm, &.{ .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0x38, 0x35 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmulhw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xe5 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmulld, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x40 }, 0, .vex_256_wig, .avx2 },

    .{ .vpmullw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xd5 }, 0, .vex_256_wig, .avx2 },

    .{ .vpor, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xeb }, 0, .vex_256_wig, .avx2 },

    .{ .vpshufb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x38, 0x00 }, 0, .vex_256_wig, .avx2 },
    .{ .vpshufd, .rmi, &.{ .ymm, .ymm_m256, .imm8 }, &.{ 0x66, 0x0f, 0x70 }, 0, .vex_256_wig, .avx2 },

    .{ .vpshufhw, .rmi, &.{ .ymm, .ymm_m256, .imm8 }, &.{ 0xf3, 0x0f, 0x70 }, 0, .vex_256_wig, .avx2 },

    .{ .vpshuflw, .rmi, &.{ .ymm, .ymm_m256, .imm8 }, &.{ 0xf2, 0x0f, 0x70 }, 0, .vex_256_wig, .avx2 },

    .{ .vpsllw, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf1 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsllw, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 6, .vex_256_wig, .avx2 },
    .{ .vpslld, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf2 }, 0, .vex_256_wig, .avx2 },
    .{ .vpslld, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 6, .vex_256_wig, .avx2 },
    .{ .vpsllq, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xf3 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsllq, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 6, .vex_256_wig, .avx2 },

    .{ .vpslldq, .vmi, &.{ .ymm, .ymm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 7, .vex_256_wig, .avx2 },

    .{ .vpsraw, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe1 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsraw, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 4, .vex_256_wig, .avx2 },
    .{ .vpsrad, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xe2 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsrad, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 4, .vex_256_wig, .avx2 },

    .{ .vpsrlw, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd1 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsrlw, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x71 }, 2, .vex_256_wig, .avx2 },
    .{ .vpsrld, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd2 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsrld, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x72 }, 2, .vex_256_wig, .avx2 },
    .{ .vpsrlq, .rvm, &.{ .ymm, .ymm, .xmm_m128 }, &.{ 0x66, 0x0f, 0xd3 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsrlq, .vmi, &.{ .ymm, .ymm, .imm8     }, &.{ 0x66, 0x0f, 0x73 }, 2, .vex_256_wig, .avx2 },

    .{ .vpsrldq, .vmi, &.{ .ymm, .ymm, .imm8 }, &.{ 0x66, 0x0f, 0x73 }, 3, .vex_128_wig, .avx2 },

    .{ .vpsubb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xf8 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsubw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xf9 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsubd, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xfa }, 0, .vex_256_wig, .avx2 },

    .{ .vpsubsb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xe8 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsubsw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xe9 }, 0, .vex_256_wig, .avx2 },

    .{ .vpsubq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xfb }, 0, .vex_256_wig, .avx2 },

    .{ .vpsubusb, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xd8 }, 0, .vex_256_wig, .avx2 },
    .{ .vpsubusw, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xd9 }, 0, .vex_256_wig, .avx2 },

    .{ .vpunpckhbw,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x68 }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpckhwd,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x69 }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpckhdq,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x6a }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpckhqdq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x6d }, 0, .vex_256_wig, .avx2 },

    .{ .vpunpcklbw,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x60 }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpcklwd,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x61 }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpckldq,  .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x62 }, 0, .vex_256_wig, .avx2 },
    .{ .vpunpcklqdq, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0x6c }, 0, .vex_256_wig, .avx2 },

    .{ .vpxor, .rvm, &.{ .ymm, .ymm, .ymm_m256 }, &.{ 0x66, 0x0f, 0xef }, 0, .vex_256_wig, .avx2 },
};
// zig fmt: on
