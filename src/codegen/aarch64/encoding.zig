/// B1.2 Registers in AArch64 Execution state
pub const Register = struct {
    alias: Alias,
    format: Format,

    pub const Format = union(enum) {
        alias,
        integer: IntegerSize,
        scalar: VectorSize,
        vector: Arrangement,
        element: struct { size: VectorSize, index: u4 },
    };

    pub const IntegerSize = enum(u1) {
        word = 0b0,
        doubleword = 0b1,

        pub fn prefix(is: IntegerSize) u8 {
            return (comptime std.enums.EnumArray(IntegerSize, u8).init(.{
                .word = 'w',
                .doubleword = 'x',
            })).get(is);
        }
    };

    pub const VectorSize = enum(u3) {
        byte = 0,
        half = 1,
        single = 2,
        double = 3,
        quad = 4,
        scalable,
        predicate,

        pub fn prefix(vs: VectorSize) u8 {
            return (comptime std.enums.EnumArray(VectorSize, u8).init(.{
                .byte = 'b',
                .half = 'h',
                .single = 's',
                .double = 'd',
                .quad = 'q',
                .scalable = 'z',
                .predicate = 'p',
            })).get(vs);
        }
    };

    pub const Arrangement = enum {
        @"2d",
        @"4s",
        @"8h",
        @"16b",

        @"1d",
        @"2s",
        @"4h",
        @"8b",

        pub fn len(arrangement: Arrangement) u5 {
            return switch (arrangement) {
                .@"1d" => 1,
                .@"2d", .@"2s" => 2,
                .@"4s", .@"4h" => 4,
                .@"8h", .@"8b" => 8,
                .@"16b" => 16,
            };
        }

        pub fn size(arrangement: Arrangement) Instruction.DataProcessingVector.Q {
            return switch (arrangement) {
                .@"2d", .@"4s", .@"8h", .@"16b" => .quad,
                .@"1d", .@"2s", .@"4h", .@"8b" => .double,
            };
        }

        pub fn elemSize(arrangement: Arrangement) Instruction.DataProcessingVector.Size {
            return switch (arrangement) {
                .@"2d", .@"1d" => .double,
                .@"4s", .@"2s" => .single,
                .@"8h", .@"4h" => .half,
                .@"16b", .@"8b" => .byte,
            };
        }
    };

    pub const x0: Register = .{ .alias = .r0, .format = .{ .integer = .doubleword } };
    pub const x1: Register = .{ .alias = .r1, .format = .{ .integer = .doubleword } };
    pub const x2: Register = .{ .alias = .r2, .format = .{ .integer = .doubleword } };
    pub const x3: Register = .{ .alias = .r3, .format = .{ .integer = .doubleword } };
    pub const x4: Register = .{ .alias = .r4, .format = .{ .integer = .doubleword } };
    pub const x5: Register = .{ .alias = .r5, .format = .{ .integer = .doubleword } };
    pub const x6: Register = .{ .alias = .r6, .format = .{ .integer = .doubleword } };
    pub const x7: Register = .{ .alias = .r7, .format = .{ .integer = .doubleword } };
    pub const x8: Register = .{ .alias = .r8, .format = .{ .integer = .doubleword } };
    pub const x9: Register = .{ .alias = .r9, .format = .{ .integer = .doubleword } };
    pub const x10: Register = .{ .alias = .r10, .format = .{ .integer = .doubleword } };
    pub const x11: Register = .{ .alias = .r11, .format = .{ .integer = .doubleword } };
    pub const x12: Register = .{ .alias = .r12, .format = .{ .integer = .doubleword } };
    pub const x13: Register = .{ .alias = .r13, .format = .{ .integer = .doubleword } };
    pub const x14: Register = .{ .alias = .r14, .format = .{ .integer = .doubleword } };
    pub const x15: Register = .{ .alias = .r15, .format = .{ .integer = .doubleword } };
    pub const x16: Register = .{ .alias = .r16, .format = .{ .integer = .doubleword } };
    pub const x17: Register = .{ .alias = .r17, .format = .{ .integer = .doubleword } };
    pub const x18: Register = .{ .alias = .r18, .format = .{ .integer = .doubleword } };
    pub const x19: Register = .{ .alias = .r19, .format = .{ .integer = .doubleword } };
    pub const x20: Register = .{ .alias = .r20, .format = .{ .integer = .doubleword } };
    pub const x21: Register = .{ .alias = .r21, .format = .{ .integer = .doubleword } };
    pub const x22: Register = .{ .alias = .r22, .format = .{ .integer = .doubleword } };
    pub const x23: Register = .{ .alias = .r23, .format = .{ .integer = .doubleword } };
    pub const x24: Register = .{ .alias = .r24, .format = .{ .integer = .doubleword } };
    pub const x25: Register = .{ .alias = .r25, .format = .{ .integer = .doubleword } };
    pub const x26: Register = .{ .alias = .r26, .format = .{ .integer = .doubleword } };
    pub const x27: Register = .{ .alias = .r27, .format = .{ .integer = .doubleword } };
    pub const x28: Register = .{ .alias = .r28, .format = .{ .integer = .doubleword } };
    pub const x29: Register = .{ .alias = .r29, .format = .{ .integer = .doubleword } };
    pub const x30: Register = .{ .alias = .r30, .format = .{ .integer = .doubleword } };
    pub const xzr: Register = .{ .alias = .zr, .format = .{ .integer = .doubleword } };
    pub const sp: Register = .{ .alias = .sp, .format = .{ .integer = .doubleword } };

    pub const w0: Register = .{ .alias = .r0, .format = .{ .integer = .word } };
    pub const w1: Register = .{ .alias = .r1, .format = .{ .integer = .word } };
    pub const w2: Register = .{ .alias = .r2, .format = .{ .integer = .word } };
    pub const w3: Register = .{ .alias = .r3, .format = .{ .integer = .word } };
    pub const w4: Register = .{ .alias = .r4, .format = .{ .integer = .word } };
    pub const w5: Register = .{ .alias = .r5, .format = .{ .integer = .word } };
    pub const w6: Register = .{ .alias = .r6, .format = .{ .integer = .word } };
    pub const w7: Register = .{ .alias = .r7, .format = .{ .integer = .word } };
    pub const w8: Register = .{ .alias = .r8, .format = .{ .integer = .word } };
    pub const w9: Register = .{ .alias = .r9, .format = .{ .integer = .word } };
    pub const w10: Register = .{ .alias = .r10, .format = .{ .integer = .word } };
    pub const w11: Register = .{ .alias = .r11, .format = .{ .integer = .word } };
    pub const w12: Register = .{ .alias = .r12, .format = .{ .integer = .word } };
    pub const w13: Register = .{ .alias = .r13, .format = .{ .integer = .word } };
    pub const w14: Register = .{ .alias = .r14, .format = .{ .integer = .word } };
    pub const w15: Register = .{ .alias = .r15, .format = .{ .integer = .word } };
    pub const w16: Register = .{ .alias = .r16, .format = .{ .integer = .word } };
    pub const w17: Register = .{ .alias = .r17, .format = .{ .integer = .word } };
    pub const w18: Register = .{ .alias = .r18, .format = .{ .integer = .word } };
    pub const w19: Register = .{ .alias = .r19, .format = .{ .integer = .word } };
    pub const w20: Register = .{ .alias = .r20, .format = .{ .integer = .word } };
    pub const w21: Register = .{ .alias = .r21, .format = .{ .integer = .word } };
    pub const w22: Register = .{ .alias = .r22, .format = .{ .integer = .word } };
    pub const w23: Register = .{ .alias = .r23, .format = .{ .integer = .word } };
    pub const w24: Register = .{ .alias = .r24, .format = .{ .integer = .word } };
    pub const w25: Register = .{ .alias = .r25, .format = .{ .integer = .word } };
    pub const w26: Register = .{ .alias = .r26, .format = .{ .integer = .word } };
    pub const w27: Register = .{ .alias = .r27, .format = .{ .integer = .word } };
    pub const w28: Register = .{ .alias = .r28, .format = .{ .integer = .word } };
    pub const w29: Register = .{ .alias = .r29, .format = .{ .integer = .word } };
    pub const w30: Register = .{ .alias = .r30, .format = .{ .integer = .word } };
    pub const wzr: Register = .{ .alias = .zr, .format = .{ .integer = .word } };
    pub const wsp: Register = .{ .alias = .sp, .format = .{ .integer = .word } };

    pub const ip0 = x16;
    pub const ip1 = x17;
    pub const fp = x29;
    pub const lr = x30;
    pub const pc: Register = .{ .alias = .pc, .format = .{ .integer = .doubleword } };

    pub const q0: Register = .{ .alias = .v0, .format = .{ .scalar = .quad } };
    pub const q1: Register = .{ .alias = .v1, .format = .{ .scalar = .quad } };
    pub const q2: Register = .{ .alias = .v2, .format = .{ .scalar = .quad } };
    pub const q3: Register = .{ .alias = .v3, .format = .{ .scalar = .quad } };
    pub const q4: Register = .{ .alias = .v4, .format = .{ .scalar = .quad } };
    pub const q5: Register = .{ .alias = .v5, .format = .{ .scalar = .quad } };
    pub const q6: Register = .{ .alias = .v6, .format = .{ .scalar = .quad } };
    pub const q7: Register = .{ .alias = .v7, .format = .{ .scalar = .quad } };
    pub const q8: Register = .{ .alias = .v8, .format = .{ .scalar = .quad } };
    pub const q9: Register = .{ .alias = .v9, .format = .{ .scalar = .quad } };
    pub const q10: Register = .{ .alias = .v10, .format = .{ .scalar = .quad } };
    pub const q11: Register = .{ .alias = .v11, .format = .{ .scalar = .quad } };
    pub const q12: Register = .{ .alias = .v12, .format = .{ .scalar = .quad } };
    pub const q13: Register = .{ .alias = .v13, .format = .{ .scalar = .quad } };
    pub const q14: Register = .{ .alias = .v14, .format = .{ .scalar = .quad } };
    pub const q15: Register = .{ .alias = .v15, .format = .{ .scalar = .quad } };
    pub const q16: Register = .{ .alias = .v16, .format = .{ .scalar = .quad } };
    pub const q17: Register = .{ .alias = .v17, .format = .{ .scalar = .quad } };
    pub const q18: Register = .{ .alias = .v18, .format = .{ .scalar = .quad } };
    pub const q19: Register = .{ .alias = .v19, .format = .{ .scalar = .quad } };
    pub const q20: Register = .{ .alias = .v20, .format = .{ .scalar = .quad } };
    pub const q21: Register = .{ .alias = .v21, .format = .{ .scalar = .quad } };
    pub const q22: Register = .{ .alias = .v22, .format = .{ .scalar = .quad } };
    pub const q23: Register = .{ .alias = .v23, .format = .{ .scalar = .quad } };
    pub const q24: Register = .{ .alias = .v24, .format = .{ .scalar = .quad } };
    pub const q25: Register = .{ .alias = .v25, .format = .{ .scalar = .quad } };
    pub const q26: Register = .{ .alias = .v26, .format = .{ .scalar = .quad } };
    pub const q27: Register = .{ .alias = .v27, .format = .{ .scalar = .quad } };
    pub const q28: Register = .{ .alias = .v28, .format = .{ .scalar = .quad } };
    pub const q29: Register = .{ .alias = .v29, .format = .{ .scalar = .quad } };
    pub const q30: Register = .{ .alias = .v30, .format = .{ .scalar = .quad } };
    pub const q31: Register = .{ .alias = .v31, .format = .{ .scalar = .quad } };

    pub const d0: Register = .{ .alias = .v0, .format = .{ .scalar = .double } };
    pub const d1: Register = .{ .alias = .v1, .format = .{ .scalar = .double } };
    pub const d2: Register = .{ .alias = .v2, .format = .{ .scalar = .double } };
    pub const d3: Register = .{ .alias = .v3, .format = .{ .scalar = .double } };
    pub const d4: Register = .{ .alias = .v4, .format = .{ .scalar = .double } };
    pub const d5: Register = .{ .alias = .v5, .format = .{ .scalar = .double } };
    pub const d6: Register = .{ .alias = .v6, .format = .{ .scalar = .double } };
    pub const d7: Register = .{ .alias = .v7, .format = .{ .scalar = .double } };
    pub const d8: Register = .{ .alias = .v8, .format = .{ .scalar = .double } };
    pub const d9: Register = .{ .alias = .v9, .format = .{ .scalar = .double } };
    pub const d10: Register = .{ .alias = .v10, .format = .{ .scalar = .double } };
    pub const d11: Register = .{ .alias = .v11, .format = .{ .scalar = .double } };
    pub const d12: Register = .{ .alias = .v12, .format = .{ .scalar = .double } };
    pub const d13: Register = .{ .alias = .v13, .format = .{ .scalar = .double } };
    pub const d14: Register = .{ .alias = .v14, .format = .{ .scalar = .double } };
    pub const d15: Register = .{ .alias = .v15, .format = .{ .scalar = .double } };
    pub const d16: Register = .{ .alias = .v16, .format = .{ .scalar = .double } };
    pub const d17: Register = .{ .alias = .v17, .format = .{ .scalar = .double } };
    pub const d18: Register = .{ .alias = .v18, .format = .{ .scalar = .double } };
    pub const d19: Register = .{ .alias = .v19, .format = .{ .scalar = .double } };
    pub const d20: Register = .{ .alias = .v20, .format = .{ .scalar = .double } };
    pub const d21: Register = .{ .alias = .v21, .format = .{ .scalar = .double } };
    pub const d22: Register = .{ .alias = .v22, .format = .{ .scalar = .double } };
    pub const d23: Register = .{ .alias = .v23, .format = .{ .scalar = .double } };
    pub const d24: Register = .{ .alias = .v24, .format = .{ .scalar = .double } };
    pub const d25: Register = .{ .alias = .v25, .format = .{ .scalar = .double } };
    pub const d26: Register = .{ .alias = .v26, .format = .{ .scalar = .double } };
    pub const d27: Register = .{ .alias = .v27, .format = .{ .scalar = .double } };
    pub const d28: Register = .{ .alias = .v28, .format = .{ .scalar = .double } };
    pub const d29: Register = .{ .alias = .v29, .format = .{ .scalar = .double } };
    pub const d30: Register = .{ .alias = .v30, .format = .{ .scalar = .double } };
    pub const d31: Register = .{ .alias = .v31, .format = .{ .scalar = .double } };

    pub const s0: Register = .{ .alias = .v0, .format = .{ .scalar = .single } };
    pub const s1: Register = .{ .alias = .v1, .format = .{ .scalar = .single } };
    pub const s2: Register = .{ .alias = .v2, .format = .{ .scalar = .single } };
    pub const s3: Register = .{ .alias = .v3, .format = .{ .scalar = .single } };
    pub const s4: Register = .{ .alias = .v4, .format = .{ .scalar = .single } };
    pub const s5: Register = .{ .alias = .v5, .format = .{ .scalar = .single } };
    pub const s6: Register = .{ .alias = .v6, .format = .{ .scalar = .single } };
    pub const s7: Register = .{ .alias = .v7, .format = .{ .scalar = .single } };
    pub const s8: Register = .{ .alias = .v8, .format = .{ .scalar = .single } };
    pub const s9: Register = .{ .alias = .v9, .format = .{ .scalar = .single } };
    pub const s10: Register = .{ .alias = .v10, .format = .{ .scalar = .single } };
    pub const s11: Register = .{ .alias = .v11, .format = .{ .scalar = .single } };
    pub const s12: Register = .{ .alias = .v12, .format = .{ .scalar = .single } };
    pub const s13: Register = .{ .alias = .v13, .format = .{ .scalar = .single } };
    pub const s14: Register = .{ .alias = .v14, .format = .{ .scalar = .single } };
    pub const s15: Register = .{ .alias = .v15, .format = .{ .scalar = .single } };
    pub const s16: Register = .{ .alias = .v16, .format = .{ .scalar = .single } };
    pub const s17: Register = .{ .alias = .v17, .format = .{ .scalar = .single } };
    pub const s18: Register = .{ .alias = .v18, .format = .{ .scalar = .single } };
    pub const s19: Register = .{ .alias = .v19, .format = .{ .scalar = .single } };
    pub const s20: Register = .{ .alias = .v20, .format = .{ .scalar = .single } };
    pub const s21: Register = .{ .alias = .v21, .format = .{ .scalar = .single } };
    pub const s22: Register = .{ .alias = .v22, .format = .{ .scalar = .single } };
    pub const s23: Register = .{ .alias = .v23, .format = .{ .scalar = .single } };
    pub const s24: Register = .{ .alias = .v24, .format = .{ .scalar = .single } };
    pub const s25: Register = .{ .alias = .v25, .format = .{ .scalar = .single } };
    pub const s26: Register = .{ .alias = .v26, .format = .{ .scalar = .single } };
    pub const s27: Register = .{ .alias = .v27, .format = .{ .scalar = .single } };
    pub const s28: Register = .{ .alias = .v28, .format = .{ .scalar = .single } };
    pub const s29: Register = .{ .alias = .v29, .format = .{ .scalar = .single } };
    pub const s30: Register = .{ .alias = .v30, .format = .{ .scalar = .single } };
    pub const s31: Register = .{ .alias = .v31, .format = .{ .scalar = .single } };

    pub const h0: Register = .{ .alias = .v0, .format = .{ .scalar = .half } };
    pub const h1: Register = .{ .alias = .v1, .format = .{ .scalar = .half } };
    pub const h2: Register = .{ .alias = .v2, .format = .{ .scalar = .half } };
    pub const h3: Register = .{ .alias = .v3, .format = .{ .scalar = .half } };
    pub const h4: Register = .{ .alias = .v4, .format = .{ .scalar = .half } };
    pub const h5: Register = .{ .alias = .v5, .format = .{ .scalar = .half } };
    pub const h6: Register = .{ .alias = .v6, .format = .{ .scalar = .half } };
    pub const h7: Register = .{ .alias = .v7, .format = .{ .scalar = .half } };
    pub const h8: Register = .{ .alias = .v8, .format = .{ .scalar = .half } };
    pub const h9: Register = .{ .alias = .v9, .format = .{ .scalar = .half } };
    pub const h10: Register = .{ .alias = .v10, .format = .{ .scalar = .half } };
    pub const h11: Register = .{ .alias = .v11, .format = .{ .scalar = .half } };
    pub const h12: Register = .{ .alias = .v12, .format = .{ .scalar = .half } };
    pub const h13: Register = .{ .alias = .v13, .format = .{ .scalar = .half } };
    pub const h14: Register = .{ .alias = .v14, .format = .{ .scalar = .half } };
    pub const h15: Register = .{ .alias = .v15, .format = .{ .scalar = .half } };
    pub const h16: Register = .{ .alias = .v16, .format = .{ .scalar = .half } };
    pub const h17: Register = .{ .alias = .v17, .format = .{ .scalar = .half } };
    pub const h18: Register = .{ .alias = .v18, .format = .{ .scalar = .half } };
    pub const h19: Register = .{ .alias = .v19, .format = .{ .scalar = .half } };
    pub const h20: Register = .{ .alias = .v20, .format = .{ .scalar = .half } };
    pub const h21: Register = .{ .alias = .v21, .format = .{ .scalar = .half } };
    pub const h22: Register = .{ .alias = .v22, .format = .{ .scalar = .half } };
    pub const h23: Register = .{ .alias = .v23, .format = .{ .scalar = .half } };
    pub const h24: Register = .{ .alias = .v24, .format = .{ .scalar = .half } };
    pub const h25: Register = .{ .alias = .v25, .format = .{ .scalar = .half } };
    pub const h26: Register = .{ .alias = .v26, .format = .{ .scalar = .half } };
    pub const h27: Register = .{ .alias = .v27, .format = .{ .scalar = .half } };
    pub const h28: Register = .{ .alias = .v28, .format = .{ .scalar = .half } };
    pub const h29: Register = .{ .alias = .v29, .format = .{ .scalar = .half } };
    pub const h30: Register = .{ .alias = .v30, .format = .{ .scalar = .half } };
    pub const h31: Register = .{ .alias = .v31, .format = .{ .scalar = .half } };

    pub const b0: Register = .{ .alias = .v0, .format = .{ .scalar = .byte } };
    pub const b1: Register = .{ .alias = .v1, .format = .{ .scalar = .byte } };
    pub const b2: Register = .{ .alias = .v2, .format = .{ .scalar = .byte } };
    pub const b3: Register = .{ .alias = .v3, .format = .{ .scalar = .byte } };
    pub const b4: Register = .{ .alias = .v4, .format = .{ .scalar = .byte } };
    pub const b5: Register = .{ .alias = .v5, .format = .{ .scalar = .byte } };
    pub const b6: Register = .{ .alias = .v6, .format = .{ .scalar = .byte } };
    pub const b7: Register = .{ .alias = .v7, .format = .{ .scalar = .byte } };
    pub const b8: Register = .{ .alias = .v8, .format = .{ .scalar = .byte } };
    pub const b9: Register = .{ .alias = .v9, .format = .{ .scalar = .byte } };
    pub const b10: Register = .{ .alias = .v10, .format = .{ .scalar = .byte } };
    pub const b11: Register = .{ .alias = .v11, .format = .{ .scalar = .byte } };
    pub const b12: Register = .{ .alias = .v12, .format = .{ .scalar = .byte } };
    pub const b13: Register = .{ .alias = .v13, .format = .{ .scalar = .byte } };
    pub const b14: Register = .{ .alias = .v14, .format = .{ .scalar = .byte } };
    pub const b15: Register = .{ .alias = .v15, .format = .{ .scalar = .byte } };
    pub const b16: Register = .{ .alias = .v16, .format = .{ .scalar = .byte } };
    pub const b17: Register = .{ .alias = .v17, .format = .{ .scalar = .byte } };
    pub const b18: Register = .{ .alias = .v18, .format = .{ .scalar = .byte } };
    pub const b19: Register = .{ .alias = .v19, .format = .{ .scalar = .byte } };
    pub const b20: Register = .{ .alias = .v20, .format = .{ .scalar = .byte } };
    pub const b21: Register = .{ .alias = .v21, .format = .{ .scalar = .byte } };
    pub const b22: Register = .{ .alias = .v22, .format = .{ .scalar = .byte } };
    pub const b23: Register = .{ .alias = .v23, .format = .{ .scalar = .byte } };
    pub const b24: Register = .{ .alias = .v24, .format = .{ .scalar = .byte } };
    pub const b25: Register = .{ .alias = .v25, .format = .{ .scalar = .byte } };
    pub const b26: Register = .{ .alias = .v26, .format = .{ .scalar = .byte } };
    pub const b27: Register = .{ .alias = .v27, .format = .{ .scalar = .byte } };
    pub const b28: Register = .{ .alias = .v28, .format = .{ .scalar = .byte } };
    pub const b29: Register = .{ .alias = .v29, .format = .{ .scalar = .byte } };
    pub const b30: Register = .{ .alias = .v30, .format = .{ .scalar = .byte } };
    pub const b31: Register = .{ .alias = .v31, .format = .{ .scalar = .byte } };

    pub const fpcr: Register = .{ .alias = .fpcr, .format = .{ .integer = .doubleword } };
    pub const fpsr: Register = .{ .alias = .fpsr, .format = .{ .integer = .doubleword } };

    pub const z0: Register = .{ .alias = .v0, .format = .{ .scalar = .scalable } };
    pub const z1: Register = .{ .alias = .v1, .format = .{ .scalar = .scalable } };
    pub const z2: Register = .{ .alias = .v2, .format = .{ .scalar = .scalable } };
    pub const z3: Register = .{ .alias = .v3, .format = .{ .scalar = .scalable } };
    pub const z4: Register = .{ .alias = .v4, .format = .{ .scalar = .scalable } };
    pub const z5: Register = .{ .alias = .v5, .format = .{ .scalar = .scalable } };
    pub const z6: Register = .{ .alias = .v6, .format = .{ .scalar = .scalable } };
    pub const z7: Register = .{ .alias = .v7, .format = .{ .scalar = .scalable } };
    pub const z8: Register = .{ .alias = .v8, .format = .{ .scalar = .scalable } };
    pub const z9: Register = .{ .alias = .v9, .format = .{ .scalar = .scalable } };
    pub const z10: Register = .{ .alias = .v10, .format = .{ .scalar = .scalable } };
    pub const z11: Register = .{ .alias = .v11, .format = .{ .scalar = .scalable } };
    pub const z12: Register = .{ .alias = .v12, .format = .{ .scalar = .scalable } };
    pub const z13: Register = .{ .alias = .v13, .format = .{ .scalar = .scalable } };
    pub const z14: Register = .{ .alias = .v14, .format = .{ .scalar = .scalable } };
    pub const z15: Register = .{ .alias = .v15, .format = .{ .scalar = .scalable } };
    pub const z16: Register = .{ .alias = .v16, .format = .{ .scalar = .scalable } };
    pub const z17: Register = .{ .alias = .v17, .format = .{ .scalar = .scalable } };
    pub const z18: Register = .{ .alias = .v18, .format = .{ .scalar = .scalable } };
    pub const z19: Register = .{ .alias = .v19, .format = .{ .scalar = .scalable } };
    pub const z20: Register = .{ .alias = .v20, .format = .{ .scalar = .scalable } };
    pub const z21: Register = .{ .alias = .v21, .format = .{ .scalar = .scalable } };
    pub const z22: Register = .{ .alias = .v22, .format = .{ .scalar = .scalable } };
    pub const z23: Register = .{ .alias = .v23, .format = .{ .scalar = .scalable } };
    pub const z24: Register = .{ .alias = .v24, .format = .{ .scalar = .scalable } };
    pub const z25: Register = .{ .alias = .v25, .format = .{ .scalar = .scalable } };
    pub const z26: Register = .{ .alias = .v26, .format = .{ .scalar = .scalable } };
    pub const z27: Register = .{ .alias = .v27, .format = .{ .scalar = .scalable } };
    pub const z28: Register = .{ .alias = .v28, .format = .{ .scalar = .scalable } };
    pub const z29: Register = .{ .alias = .v29, .format = .{ .scalar = .scalable } };
    pub const z30: Register = .{ .alias = .v30, .format = .{ .scalar = .scalable } };
    pub const z31: Register = .{ .alias = .v31, .format = .{ .scalar = .scalable } };

    pub const p0: Register = .{ .alias = .v0, .format = .{ .scalar = .predicate } };
    pub const p1: Register = .{ .alias = .v1, .format = .{ .scalar = .predicate } };
    pub const p2: Register = .{ .alias = .v2, .format = .{ .scalar = .predicate } };
    pub const p3: Register = .{ .alias = .v3, .format = .{ .scalar = .predicate } };
    pub const p4: Register = .{ .alias = .v4, .format = .{ .scalar = .predicate } };
    pub const p5: Register = .{ .alias = .v5, .format = .{ .scalar = .predicate } };
    pub const p6: Register = .{ .alias = .v6, .format = .{ .scalar = .predicate } };
    pub const p7: Register = .{ .alias = .v7, .format = .{ .scalar = .predicate } };
    pub const p8: Register = .{ .alias = .v8, .format = .{ .scalar = .predicate } };
    pub const p9: Register = .{ .alias = .v9, .format = .{ .scalar = .predicate } };
    pub const p10: Register = .{ .alias = .v10, .format = .{ .scalar = .predicate } };
    pub const p11: Register = .{ .alias = .v11, .format = .{ .scalar = .predicate } };
    pub const p12: Register = .{ .alias = .v12, .format = .{ .scalar = .predicate } };
    pub const p13: Register = .{ .alias = .v13, .format = .{ .scalar = .predicate } };
    pub const p14: Register = .{ .alias = .v14, .format = .{ .scalar = .predicate } };
    pub const p15: Register = .{ .alias = .v15, .format = .{ .scalar = .predicate } };

    pub const ffr: Register = .{ .alias = .ffr, .format = .{ .integer = .doubleword } };

    pub const Encoded = enum(u5) {
        _,

        pub fn decodeInteger(enc: Encoded, sf_enc: IntegerSize, opts: struct { sp: bool = false }) Register {
            return switch (sf_enc) {
                .word => switch (@intFromEnum(enc)) {
                    0 => .w0,
                    1 => .w1,
                    2 => .w2,
                    3 => .w3,
                    4 => .w4,
                    5 => .w5,
                    6 => .w6,
                    7 => .w7,
                    8 => .w8,
                    9 => .w9,
                    10 => .w10,
                    11 => .w11,
                    12 => .w12,
                    13 => .w13,
                    14 => .w14,
                    15 => .w15,
                    16 => .w16,
                    17 => .w17,
                    18 => .w18,
                    19 => .w19,
                    20 => .w20,
                    21 => .w21,
                    22 => .w22,
                    23 => .w23,
                    24 => .w24,
                    25 => .w25,
                    26 => .w26,
                    27 => .w27,
                    28 => .w28,
                    29 => .w29,
                    30 => .w30,
                    31 => if (opts.sp) .wsp else .wzr,
                },
                .doubleword => switch (@intFromEnum(enc)) {
                    0 => .x0,
                    1 => .x1,
                    2 => .x2,
                    3 => .x3,
                    4 => .x4,
                    5 => .x5,
                    6 => .x6,
                    7 => .x7,
                    8 => .x8,
                    9 => .x9,
                    10 => .x10,
                    11 => .x11,
                    12 => .x12,
                    13 => .x13,
                    14 => .x14,
                    15 => .x15,
                    16 => .x16,
                    17 => .x17,
                    18 => .x18,
                    19 => .x19,
                    20 => .x20,
                    21 => .x21,
                    22 => .x22,
                    23 => .x23,
                    24 => .x24,
                    25 => .x25,
                    26 => .x26,
                    27 => .x27,
                    28 => .x28,
                    29 => .x29,
                    30 => .x30,
                    31 => if (opts.sp) .sp else .xzr,
                },
            };
        }

        pub fn decodeVector(enc: Encoded, vs_enc: VectorSize) Register {
            return switch (vs_enc) {
                .byte => switch (@intFromEnum(enc)) {
                    0 => .b0,
                    1 => .b1,
                    2 => .b2,
                    3 => .b3,
                    4 => .b4,
                    5 => .b5,
                    6 => .b6,
                    7 => .b7,
                    8 => .b8,
                    9 => .b9,
                    10 => .b10,
                    11 => .b11,
                    12 => .b12,
                    13 => .b13,
                    14 => .b14,
                    15 => .b15,
                    16 => .b16,
                    17 => .b17,
                    18 => .b18,
                    19 => .b19,
                    20 => .b20,
                    21 => .b21,
                    22 => .b22,
                    23 => .b23,
                    24 => .b24,
                    25 => .b25,
                    26 => .b26,
                    27 => .b27,
                    28 => .b28,
                    29 => .b29,
                    30 => .b30,
                    31 => .b31,
                },
                .half => switch (@intFromEnum(enc)) {
                    0 => .h0,
                    1 => .h1,
                    2 => .h2,
                    3 => .h3,
                    4 => .h4,
                    5 => .h5,
                    6 => .h6,
                    7 => .h7,
                    8 => .h8,
                    9 => .h9,
                    10 => .h10,
                    11 => .h11,
                    12 => .h12,
                    13 => .h13,
                    14 => .h14,
                    15 => .h15,
                    16 => .h16,
                    17 => .h17,
                    18 => .h18,
                    19 => .h19,
                    20 => .h20,
                    21 => .h21,
                    22 => .h22,
                    23 => .h23,
                    24 => .h24,
                    25 => .h25,
                    26 => .h26,
                    27 => .h27,
                    28 => .h28,
                    29 => .h29,
                    30 => .h30,
                    31 => .h31,
                },
                .single => switch (@intFromEnum(enc)) {
                    0 => .s0,
                    1 => .s1,
                    2 => .s2,
                    3 => .s3,
                    4 => .s4,
                    5 => .s5,
                    6 => .s6,
                    7 => .s7,
                    8 => .s8,
                    9 => .s9,
                    10 => .s10,
                    11 => .s11,
                    12 => .s12,
                    13 => .s13,
                    14 => .s14,
                    15 => .s15,
                    16 => .s16,
                    17 => .s17,
                    18 => .s18,
                    19 => .s19,
                    20 => .s20,
                    21 => .s21,
                    22 => .s22,
                    23 => .s23,
                    24 => .s24,
                    25 => .s25,
                    26 => .s26,
                    27 => .s27,
                    28 => .s28,
                    29 => .s29,
                    30 => .s30,
                    31 => .s31,
                },
                .double => switch (@intFromEnum(enc)) {
                    0 => .d0,
                    1 => .d1,
                    2 => .d2,
                    3 => .d3,
                    4 => .d4,
                    5 => .d5,
                    6 => .d6,
                    7 => .d7,
                    8 => .d8,
                    9 => .d9,
                    10 => .d10,
                    11 => .d11,
                    12 => .d12,
                    13 => .d13,
                    14 => .d14,
                    15 => .d15,
                    16 => .d16,
                    17 => .d17,
                    18 => .d18,
                    19 => .d19,
                    20 => .d20,
                    21 => .d21,
                    22 => .d22,
                    23 => .d23,
                    24 => .d24,
                    25 => .d25,
                    26 => .d26,
                    27 => .d27,
                    28 => .d28,
                    29 => .d29,
                    30 => .d30,
                    31 => .d31,
                },
                .quad => switch (@intFromEnum(enc)) {
                    0 => .q0,
                    1 => .q1,
                    2 => .q2,
                    3 => .q3,
                    4 => .q4,
                    5 => .q5,
                    6 => .q6,
                    7 => .q7,
                    8 => .q8,
                    9 => .q9,
                    10 => .q10,
                    11 => .q11,
                    12 => .q12,
                    13 => .q13,
                    14 => .q14,
                    15 => .q15,
                    16 => .q16,
                    17 => .q17,
                    18 => .q18,
                    19 => .q19,
                    20 => .q20,
                    21 => .q21,
                    22 => .q22,
                    23 => .q23,
                    24 => .q24,
                    25 => .q25,
                    26 => .q26,
                    27 => .q27,
                    28 => .q28,
                    29 => .q29,
                    30 => .q30,
                    31 => .q31,
                },
                .scalable => switch (@intFromEnum(enc)) {
                    0 => .z0,
                    1 => .z1,
                    2 => .z2,
                    3 => .z3,
                    4 => .z4,
                    5 => .z5,
                    6 => .z6,
                    7 => .z7,
                    8 => .z8,
                    9 => .z9,
                    10 => .z10,
                    11 => .z11,
                    12 => .z12,
                    13 => .z13,
                    14 => .z14,
                    15 => .z15,
                    16 => .z16,
                    17 => .z17,
                    18 => .z18,
                    19 => .z19,
                    20 => .z20,
                    21 => .z21,
                    22 => .z22,
                    23 => .z23,
                    24 => .z24,
                    25 => .z25,
                    26 => .z26,
                    27 => .z27,
                    28 => .z28,
                    29 => .z29,
                    30 => .z30,
                    31 => .z31,
                },
                .predicate => switch (@as(u4, @intCast(@intFromEnum(enc)))) {
                    0 => .p0,
                    1 => .p1,
                    2 => .p2,
                    3 => .p3,
                    4 => .p4,
                    5 => .p5,
                    6 => .p6,
                    7 => .p7,
                    8 => .p8,
                    9 => .p9,
                    10 => .p10,
                    11 => .p11,
                    12 => .p12,
                    13 => .p13,
                    14 => .p14,
                    15 => .p15,
                },
            };
        }
    };

    /// One tag per set of aliasing registers.
    pub const Alias = enum(u7) {
        r0,
        r1,
        r2,
        r3,
        r4,
        r5,
        r6,
        r7,
        r8,
        r9,
        r10,
        r11,
        r12,
        r13,
        r14,
        r15,
        r16,
        r17,
        r18,
        r19,
        r20,
        r21,
        r22,
        r23,
        r24,
        r25,
        r26,
        r27,
        r28,
        r29,
        r30,
        zr,
        sp,

        pc,

        v0,
        v1,
        v2,
        v3,
        v4,
        v5,
        v6,
        v7,
        v8,
        v9,
        v10,
        v11,
        v12,
        v13,
        v14,
        v15,
        v16,
        v17,
        v18,
        v19,
        v20,
        v21,
        v22,
        v23,
        v24,
        v25,
        v26,
        v27,
        v28,
        v29,
        v30,
        v31,

        fpcr,
        fpsr,

        p0,
        p1,
        p2,
        p3,
        p4,
        p5,
        p6,
        p7,
        p8,
        p9,
        p10,
        p11,
        p12,
        p13,
        p14,
        p15,

        ffr,

        pub const ip0: Alias = .r16;
        pub const ip1: Alias = .r17;
        pub const fp: Alias = .r29;
        pub const lr: Alias = .r30;

        pub fn r(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.r0) and @intFromEnum(ra) <= @intFromEnum(Alias.pc));
            return .{ .alias = ra, .format = .alias };
        }
        pub fn x(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.r0) and @intFromEnum(ra) <= @intFromEnum(Alias.sp));
            return .{ .alias = ra, .format = .{ .integer = .doubleword } };
        }
        pub fn w(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.r0) and @intFromEnum(ra) <= @intFromEnum(Alias.sp));
            return .{ .alias = ra, .format = .{ .integer = .word } };
        }
        pub fn v(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .alias };
        }
        pub fn q(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .quad } };
        }
        pub fn d(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .double } };
        }
        pub fn s(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .single } };
        }
        pub fn h(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .half } };
        }
        pub fn b(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .byte } };
        }
        pub fn z(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .scalar = .scalable } };
        }
        pub fn p(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.p0) and @intFromEnum(ra) <= @intFromEnum(Alias.p15));
            return .{ .alias = ra, .format = .{ .scalar = .predicate } };
        }
        pub fn @"2d"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"2d" } };
        }
        pub fn @"4s"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"4s" } };
        }
        pub fn @"8h"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"8h" } };
        }
        pub fn @"16b"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"16b" } };
        }
        pub fn @"1d"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"1d" } };
        }
        pub fn @"2s"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"2s" } };
        }
        pub fn @"4h"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"4h" } };
        }
        pub fn @"8b"(ra: Alias) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .vector = .@"8b" } };
        }
        pub fn @"d[]"(ra: Alias, index: u1) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .element = .{ .size = .double, .index = index } } };
        }
        pub fn @"s[]"(ra: Alias, index: u2) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .element = .{ .size = .single, .index = index } } };
        }
        pub fn @"h[]"(ra: Alias, index: u3) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .element = .{ .size = .half, .index = index } } };
        }
        pub fn @"b[]"(ra: Alias, index: u4) Register {
            assert(@intFromEnum(ra) >= @intFromEnum(Alias.v0) and @intFromEnum(ra) <= @intFromEnum(Alias.v31));
            return .{ .alias = ra, .format = .{ .element = .{ .size = .byte, .index = index } } };
        }

        pub fn isVector(ra: Alias) bool {
            return switch (ra) {
                .r0,
                .r1,
                .r2,
                .r3,
                .r4,
                .r5,
                .r6,
                .r7,
                .r8,
                .r9,
                .r10,
                .r11,
                .r12,
                .r13,
                .r14,
                .r15,
                .r16,
                .r17,
                .r18,
                .r19,
                .r20,
                .r21,
                .r22,
                .r23,
                .r24,
                .r25,
                .r26,
                .r27,
                .r28,
                .r29,
                .r30,
                .zr,
                .sp,

                .pc,

                .fpcr,
                .fpsr,

                .ffr,
                => false,

                .v0,
                .v1,
                .v2,
                .v3,
                .v4,
                .v5,
                .v6,
                .v7,
                .v8,
                .v9,
                .v10,
                .v11,
                .v12,
                .v13,
                .v14,
                .v15,
                .v16,
                .v17,
                .v18,
                .v19,
                .v20,
                .v21,
                .v22,
                .v23,
                .v24,
                .v25,
                .v26,
                .v27,
                .v28,
                .v29,
                .v30,
                .v31,

                .p0,
                .p1,
                .p2,
                .p3,
                .p4,
                .p5,
                .p6,
                .p7,
                .p8,
                .p9,
                .p10,
                .p11,
                .p12,
                .p13,
                .p14,
                .p15,
                => true,
            };
        }

        pub fn encode(ra: Alias, comptime opts: struct { sp: bool = false, V: bool = false }) Encoded {
            return @enumFromInt(@as(u5, switch (ra) {
                .r0 => if (opts.V) unreachable else 0,
                .r1 => if (opts.V) unreachable else 1,
                .r2 => if (opts.V) unreachable else 2,
                .r3 => if (opts.V) unreachable else 3,
                .r4 => if (opts.V) unreachable else 4,
                .r5 => if (opts.V) unreachable else 5,
                .r6 => if (opts.V) unreachable else 6,
                .r7 => if (opts.V) unreachable else 7,
                .r8 => if (opts.V) unreachable else 8,
                .r9 => if (opts.V) unreachable else 9,
                .r10 => if (opts.V) unreachable else 10,
                .r11 => if (opts.V) unreachable else 11,
                .r12 => if (opts.V) unreachable else 12,
                .r13 => if (opts.V) unreachable else 13,
                .r14 => if (opts.V) unreachable else 14,
                .r15 => if (opts.V) unreachable else 15,
                .r16 => if (opts.V) unreachable else 16,
                .r17 => if (opts.V) unreachable else 17,
                .r18 => if (opts.V) unreachable else 18,
                .r19 => if (opts.V) unreachable else 19,
                .r20 => if (opts.V) unreachable else 20,
                .r21 => if (opts.V) unreachable else 21,
                .r22 => if (opts.V) unreachable else 22,
                .r23 => if (opts.V) unreachable else 23,
                .r24 => if (opts.V) unreachable else 24,
                .r25 => if (opts.V) unreachable else 25,
                .r26 => if (opts.V) unreachable else 26,
                .r27 => if (opts.V) unreachable else 27,
                .r28 => if (opts.V) unreachable else 28,
                .r29 => if (opts.V) unreachable else 29,
                .r30 => if (opts.V) unreachable else 30,
                .zr => if (opts.sp or opts.V) unreachable else 31,
                .sp => if (opts.sp and !opts.V) 31 else unreachable,
                .pc => unreachable,
                .v0 => if (opts.V) 0 else unreachable,
                .v1 => if (opts.V) 1 else unreachable,
                .v2 => if (opts.V) 2 else unreachable,
                .v3 => if (opts.V) 3 else unreachable,
                .v4 => if (opts.V) 4 else unreachable,
                .v5 => if (opts.V) 5 else unreachable,
                .v6 => if (opts.V) 6 else unreachable,
                .v7 => if (opts.V) 7 else unreachable,
                .v8 => if (opts.V) 8 else unreachable,
                .v9 => if (opts.V) 9 else unreachable,
                .v10 => if (opts.V) 10 else unreachable,
                .v11 => if (opts.V) 11 else unreachable,
                .v12 => if (opts.V) 12 else unreachable,
                .v13 => if (opts.V) 13 else unreachable,
                .v14 => if (opts.V) 14 else unreachable,
                .v15 => if (opts.V) 15 else unreachable,
                .v16 => if (opts.V) 16 else unreachable,
                .v17 => if (opts.V) 17 else unreachable,
                .v18 => if (opts.V) 18 else unreachable,
                .v19 => if (opts.V) 19 else unreachable,
                .v20 => if (opts.V) 20 else unreachable,
                .v21 => if (opts.V) 21 else unreachable,
                .v22 => if (opts.V) 22 else unreachable,
                .v23 => if (opts.V) 23 else unreachable,
                .v24 => if (opts.V) 24 else unreachable,
                .v25 => if (opts.V) 25 else unreachable,
                .v26 => if (opts.V) 26 else unreachable,
                .v27 => if (opts.V) 27 else unreachable,
                .v28 => if (opts.V) 28 else unreachable,
                .v29 => if (opts.V) 29 else unreachable,
                .v30 => if (opts.V) 30 else unreachable,
                .v31 => if (opts.V) 31 else unreachable,
                .fpcr, .fpsr => unreachable,
                .p0, .p1, .p2, .p3, .p4, .p5, .p6, .p7, .p8, .p9, .p10, .p11, .p12, .p13, .p14, .p15 => unreachable,
                .ffr => unreachable,
            }));
        }
    };

    pub fn isVector(reg: Register) bool {
        return reg.alias.isVector();
    }

    pub fn size(reg: Register) ?u5 {
        return format: switch (reg.format) {
            .alias => unreachable,
            .integer => |sf| switch (sf) {
                .word => 4,
                .doubleword => 8,
            },
            .vector => |vs| switch (vs) {
                .byte => 1,
                .word => 2,
                .single => 4,
                .double => 8,
                .quad => 16,
                .scalable, .predicate => null,
            },
            .arrangement => |arrangement| switch (arrangement) {
                .@"2d", .@"4s", .@"8h", .@"16b" => 16,
                .@"1d", .@"2s", .@"4h", .@"8b" => 8,
            },
            .element => |element| continue :format .{ .vector = element.size },
        };
    }

    pub fn parse(reg: []const u8) ?Register {
        return if (reg.len == 0) null else switch (std.ascii.toLower(reg[0])) {
            else => null,
            'r' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| switch (n) {
                0...30 => .{
                    .alias = @enumFromInt(@intFromEnum(Alias.r0) + n),
                    .format = .alias,
                },
                31 => null,
            } else |_| null,
            'x' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| switch (n) {
                0...30 => .{
                    .alias = @enumFromInt(@intFromEnum(Alias.r0) + n),
                    .format = .{ .integer = .doubleword },
                },
                31 => null,
            } else |_| if (toLowerEqlAssertLower(reg, "xzr")) .xzr else null,
            'w' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| switch (n) {
                0...30 => .{
                    .alias = @enumFromInt(@intFromEnum(Alias.r0) + n),
                    .format = .{ .integer = .word },
                },
                31 => null,
            } else |_| if (toLowerEqlAssertLower(reg, "wzr"))
                .wzr
            else if (toLowerEqlAssertLower(reg, "wsp"))
                .wsp
            else
                null,
            'i' => return if (toLowerEqlAssertLower(reg, "ip") or toLowerEqlAssertLower(reg, "ip0"))
                .ip0
            else if (toLowerEqlAssertLower(reg, "ip1"))
                .ip1
            else
                null,
            'f' => return if (toLowerEqlAssertLower(reg, "fp")) .fp else null,
            'p' => return if (toLowerEqlAssertLower(reg, "pc")) .pc else null,
            'v' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .alias,
            } else |_| null,
            'q' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .{ .scalar = .quad },
            } else |_| null,
            'd' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .{ .scalar = .double },
            } else |_| null,
            's' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .{ .scalar = .single },
            } else |_| if (toLowerEqlAssertLower(reg, "sp")) .sp else null,
            'h' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .{ .scalar = .half },
            } else |_| null,
            'b' => if (std.fmt.parseInt(u5, reg[1..], 10)) |n| .{
                .alias = @enumFromInt(@intFromEnum(Alias.v0) + n),
                .format = .{ .scalar = .byte },
            } else |_| null,
        };
    }

    pub fn fmt(reg: Register) aarch64.Disassemble.RegisterFormatter {
        return reg.fmtCase(.lower);
    }
    pub fn fmtCase(reg: Register, case: aarch64.Disassemble.Case) aarch64.Disassemble.RegisterFormatter {
        return .{ .reg = reg, .case = case };
    }

    pub const System = packed struct(u16) {
        op2: u3,
        CRm: u4,
        CRn: u4,
        op1: u3,
        op0: u2,

        // D19.2 General system control registers
        /// D19.2.1 ACCDATA_EL1, Accelerator Data
        pub const accdata_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b101 };
        /// D19.2.2 ACTLR_EL1, Auxiliary Control Register (EL1)
        pub const actlr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.3 ACTLR_EL2, Auxiliary Control Register (EL2)
        pub const actlr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.4 ACTLR_EL3, Auxiliary Control Register (EL3)
        pub const actlr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.5 AFSR0_EL1, Auxiliary Fault Status Register 0 (EL1)
        pub const afsr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.5 AFSR0_EL12, Auxiliary Fault Status Register 0 (EL12)
        pub const afsr0_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.6 AFSR0_EL2, Auxiliary Fault Status Register 0 (EL2)
        pub const afsr0_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.7 AFSR0_EL3, Auxiliary Fault Status Register 0 (EL3)
        pub const afsr0_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.8 AFSR1_EL1, Auxiliary Fault Status Register 1 (EL1)
        pub const afsr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.8 AFSR1_EL12, Auxiliary Fault Status Register 1 (EL12)
        pub const afsr1_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.9 AFSR1_EL2, Auxiliary Fault Status Register 1 (EL2)
        pub const afsr1_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.10 AFSR1_EL3, Auxiliary Fault Status Register 1 (EL3)
        pub const afsr1_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0101, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.11 AIDR_EL1, Auxiliary ID Register
        pub const aidr_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.12 AMAIR_EL1, Auxiliary Memory Attribute Indirection Register (EL1)
        pub const amair_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.12 AMAIR_EL12, Auxiliary Memory Attribute Indirection Register (EL12)
        pub const amair_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b1010, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.13 AMAIR_EL2, Auxiliary Memory Attribute Indirection Register (EL2)
        pub const amair_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1010, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.14 AMAIR_EL3, Auxiliary Memory Attribute Indirection Register (EL3)
        pub const amair_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1010, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.15 APDAKeyHi_EL1, Pointer Authentication Key A for Data (bits[127:64])
        pub const apdakeyhi_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0010, .op2 = 0b001 };
        /// D19.2.16 APDAKeyLo_EL1, Pointer Authentication Key A for Data (bits[63:0])
        pub const apdakeylo_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.17 APDBKeyHi_EL1, Pointer Authentication Key B for Data (bits[127:64])
        pub const apdbkeyhi_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0010, .op2 = 0b011 };
        /// D19.2.18 APDAKeyHi_EL1, Pointer Authentication Key B for Data (bits[63:0])
        pub const apdbkeylo_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0010, .op2 = 0b010 };
        /// D19.2.19 APGAKeyHi_EL1, Pointer Authentication Key A for Code (bits[127:64])
        pub const apgakeyhi_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0011, .op2 = 0b001 };
        /// D19.2.20 APGAKeyLo_EL1, Pointer Authentication Key A for Code (bits[63:0])
        pub const apgakeylo_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.21 APIAKeyHi_EL1, Pointer Authentication Key A for Instruction (bits[127:64])
        pub const apiakeyhi_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.22 APIAKeyLo_EL1, Pointer Authentication Key A for Instruction (bits[63:0])
        pub const apiakeylo_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.23 APIBKeyHi_EL1, Pointer Authentication Key B for Instruction (bits[127:64])
        pub const apibkeyhi_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b011 };
        /// D19.2.24 APIBKeyLo_EL1, Pointer Authentication Key B for Instruction (bits[63:0])
        pub const apibkeylo_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b010 };
        /// D19.2.25 CCSIDR2_EL1, Current Cache Size ID Register 2
        pub const ccsidr2_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.26 CCSIDR_EL1, Current Cache Size ID Register
        pub const ccsidr_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.27 CLIDR_EL1, Cache Level ID Register
        pub const clidr_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.28 CONTEXTIDR_EL1, Context ID Register (EL1)
        pub const contextidr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.28 CONTEXTIDR_EL12, Context ID Register (EL12)
        pub const contextidr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.29 CONTEXTIDR_EL2, Context ID Register (EL2)
        pub const contextidr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.30 CPACR_EL1, Architectural Feature Access Control Register
        pub const cpacr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.30 CPACR_EL12, Architectural Feature Access Control Register
        pub const cpacr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.31 CPACR_EL2, Architectural Feature Trap Register (EL2)
        pub const cptr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b010 };
        /// D19.2.32 CPACR_EL3, Architectural Feature Trap Register (EL3)
        pub const cptr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b010 };
        /// D19.2.33 CSSELR_EL1, Cache Size Selection Register
        pub const csselr_el1: System = .{ .op0 = 0b11, .op1 = 0b010, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.34 CTR_EL0, Cache Type Register
        pub const ctr_el0: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.35 DACR32_EL2, Domain Access Control Register
        pub const dacr32_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0011, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.36 DCZID_EL0, Data Cache Zero ID Register
        pub const dczid_el0: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.37 ESR_EL1, Exception Syndrome Register (EL1)
        pub const esr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0101, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.37 ESR_EL12, Exception Syndrome Register (EL12)
        pub const esr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0101, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.38 ESR_EL2, Exception Syndrome Register (EL2)
        pub const esr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.39 ESR_EL3, Exception Syndrome Register (EL3)
        pub const esr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0101, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.40 FAR_EL1, Fault Address Register (EL1)
        pub const far_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0110, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.40 FAR_EL12, Fault Address Register (EL12)
        pub const far_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0110, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.41 FAR_EL2, Fault Address Register (EL2)
        pub const far_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0110, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.42 FAR_EL3, Fault Address Register (EL3)
        pub const far_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0110, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.43 FPEXC32_EL2, Floating-Point Exception Control Register
        pub const fpexc32_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.44 GCR_EL1, Tag Control Register
        pub const gcr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b110 };
        /// D19.2.45 GMID_EL1, Tag Control Register
        pub const gmid_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b100 };
        /// D19.2.46 HACR_EL2, Hypervisor Auxiliary Control Register
        pub const hacr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b111 };
        /// D19.2.47 HAFGRTR_EL2, Hypervisor Activity Monitors Fine-Grained Read Trap Register
        pub const hafgrtr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0011, .CRm = 0b0001, .op2 = 0b110 };
        /// D19.2.48 HCR_EL2, Hypervisor Configuration Register
        pub const hcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.49 HCRX_EL2, Extended Hypervisor Configuration Register
        pub const hcrx_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b010 };
        /// D19.2.50 HDFGRTR_EL2, Hypervisor Debug Fine-Grained Read Trap Register
        pub const hdfgrtr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0011, .CRm = 0b0001, .op2 = 0b100 };
        /// D19.2.51 HDFGWTR_EL2, Hypervisor Debug Fine-Grained Write Trap Register
        pub const hdfgwtr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0011, .CRm = 0b0001, .op2 = 0b101 };
        /// D19.2.52 HFGITR_EL2, Hypervisor Fine-Grained Instruction Trap Register
        pub const hfgitr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b110 };
        /// D19.2.53 HFGRTR_EL2, Hypervisor Fine-Grained Read Trap Register
        pub const hfgrtr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b100 };
        /// D19.2.54 HFGWTR_EL2, Hypervisor Fine-Grained Write Trap Register
        pub const hfgwtr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b101 };
        /// D19.2.55 HPFAR_EL2, Hypervisor IPA Fault Address Register
        pub const hpfar_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0110, .CRm = 0b0000, .op2 = 0b100 };
        /// D19.2.56 HSTR_EL2, Hypervisor System Trap Register
        pub const hstr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b011 };
        /// D19.2.57 ID_AA64AFR0_EL1, AArch64 Auxiliary Feature Register 0
        pub const id_aa64afr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0101, .op2 = 0b100 };
        /// D19.2.58 ID_AA64AFR1_EL1, AArch64 Auxiliary Feature Register 1
        pub const id_aa64afr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0101, .op2 = 0b101 };
        /// D19.2.59 ID_AA64DFR0_EL1, AArch64 Debug Feature Register 0
        pub const id_aa64dfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0101, .op2 = 0b000 };
        /// D19.2.60 ID_AA64DFR1_EL1, AArch64 Debug Feature Register 1
        pub const id_aa64dfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0101, .op2 = 0b001 };
        /// D19.2.61 ID_AA64ISAR0_EL1, AArch64 Instruction Set Attribute Register 0
        pub const id_aa64isar0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.62 ID_AA64ISAR1_EL1, AArch64 Instruction Set Attribute Register 1
        pub const id_aa64isar1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0110, .op2 = 0b001 };
        /// D19.2.63 ID_AA64ISAR2_EL1, AArch64 Instruction Set Attribute Register 2
        pub const id_aa64isar2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0110, .op2 = 0b010 };
        /// D19.2.64 ID_AA64MMFR0_EL1, AArch64 Memory Model Feature Register 0
        pub const id_aa64mmfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0111, .op2 = 0b000 };
        /// D19.2.65 ID_AA64MMFR1_EL1, AArch64 Memory Model Feature Register 1
        pub const id_aa64mmfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0111, .op2 = 0b001 };
        /// D19.2.66 ID_AA64MMFR2_EL1, AArch64 Memory Model Feature Register 2
        pub const id_aa64mmfr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0111, .op2 = 0b010 };
        /// D19.2.67 ID_AA64MMFR3_EL1, AArch64 Memory Model Feature Register 3
        pub const id_aa64mmfr3_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0111, .op2 = 0b011 };
        /// D19.2.68 ID_AA64MMFR4_EL1, AArch64 Memory Model Feature Register 4
        pub const id_aa64mmfr4_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0111, .op2 = 0b100 };
        /// D19.2.69 ID_AA64PFR0_EL1, AArch64 Processor Feature Register 0
        pub const id_aa64pfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0100, .op2 = 0b000 };
        /// D19.2.70 ID_AA64PFR1_EL1, AArch64 Processor Feature Register 1
        pub const id_aa64pfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0100, .op2 = 0b001 };
        /// D19.2.71 ID_AA64PFR2_EL1, AArch64 Processor Feature Register 2
        pub const id_aa64pfr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0100, .op2 = 0b010 };
        /// D19.2.72 ID_AA64SMFR0_EL1, SME Feature ID Register 0
        pub const id_aa64smfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0100, .op2 = 0b101 };
        /// D19.2.73 ID_AA64ZFR0_EL1, SVE Feature ID Register 0
        pub const id_aa64zfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0100, .op2 = 0b100 };
        /// D19.2.74 ID_AFR0_EL1, AArch32 Auxiliary Feature Register 0
        pub const id_afr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b011 };
        /// D19.2.75 ID_DFR0_EL1, AArch32 Debug Feature Register 0
        pub const id_dfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b010 };
        /// D19.2.76 ID_DFR1_EL1, AArch32 Debug Feature Register 1
        pub const id_dfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b101 };
        /// D19.2.77 ID_ISAR0_EL1, AArch32 Instruction Set Attribute Register 0
        pub const id_isar0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.78 ID_ISAR1_EL1, AArch32 Instruction Set Attribute Register 1
        pub const id_isar1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b001 };
        /// D19.2.79 ID_ISAR2_EL1, AArch32 Instruction Set Attribute Register 2
        pub const id_isar2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b010 };
        /// D19.2.80 ID_ISAR3_EL1, AArch32 Instruction Set Attribute Register 3
        pub const id_isar3_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b011 };
        /// D19.2.81 ID_ISAR4_EL1, AArch32 Instruction Set Attribute Register 4
        pub const id_isar4_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b100 };
        /// D19.2.82 ID_ISAR5_EL1, AArch32 Instruction Set Attribute Register 5
        pub const id_isar5_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b101 };
        /// D19.2.83 ID_ISAR6_EL1, AArch32 Instruction Set Attribute Register 6
        pub const id_isar6_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b111 };
        /// D19.2.84 ID_MMFR0_EL1, AArch32 Memory Model Feature Register 0
        pub const id_mmfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b100 };
        /// D19.2.85 ID_MMFR1_EL1, AArch32 Memory Model Feature Register 1
        pub const id_mmfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b101 };
        /// D19.2.86 ID_MMFR2_EL1, AArch32 Memory Model Feature Register 2
        pub const id_mmfr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b110 };
        /// D19.2.87 ID_MMFR3_EL1, AArch32 Memory Model Feature Register 3
        pub const id_mmfr3_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b111 };
        /// D19.2.88 ID_MMFR4_EL1, AArch32 Memory Model Feature Register 4
        pub const id_mmfr4_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0010, .op2 = 0b110 };
        /// D19.2.89 ID_MMFR5_EL1, AArch32 Memory Model Feature Register 5
        pub const id_mmfr5_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b110 };
        /// D19.2.90 ID_PFR0_EL1, AArch32 Processor Feature Register 0
        pub const id_pfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.91 ID_PFR1_EL1, AArch32 Processor Feature Register 1
        pub const id_pfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0001, .op2 = 0b001 };
        /// D19.2.92 ID_PFR2_EL1, AArch32 Processor Feature Register 2
        pub const id_pfr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b100 };
        /// D19.2.93 IFSR32_EL2, Instruction Fault Status Register (EL2)
        pub const ifsr32_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.94 ISR_EL1, Interrupt Status Register
        pub const isr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1100, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.95 LORC_EL1, LORegion Control (EL1)
        pub const lorc_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0100, .op2 = 0b011 };
        /// D19.2.96 LOREA_EL1, LORegion End Address (EL1)
        pub const lorea_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0100, .op2 = 0b001 };
        /// D19.2.97 SORID_EL1, LORegionID (EL1)
        pub const lorid_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0100, .op2 = 0b111 };
        /// D19.2.98 LORN_EL1, LORegion Number (EL1)
        pub const lorn_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0100, .op2 = 0b010 };
        /// D19.2.99 LORSA_EL1, LORegion Start Address (EL1)
        pub const lorsa_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0100, .op2 = 0b000 };
        /// D19.2.100 MAIR_EL1, Memory Attribute Indirection Register (EL1)
        pub const mair_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.100 MAIR_EL12, Memory Attribute Indirection Register (EL12)
        pub const mair_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b1010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.101 MAIR_EL2, Memory Attribute Indirection Register (EL2)
        pub const mair_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.102 MAIR_EL3, Memory Attribute Indirection Register (EL3)
        pub const mair_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.103 MIDR_EL1, Main ID Register
        pub const midr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.104 MPIDR_EL1, Multiprocessor Affinity Register
        pub const mpidr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b101 };
        /// D19.2.105 MVFR0_EL1, AArch32 Media and VFP Feature Register 0
        pub const mvfr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b000 };
        /// D19.2.106 MVFR1_EL1, AArch32 Media and VFP Feature Register 1
        pub const mvfr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b001 };
        /// D19.2.107 MVFR2_EL1, AArch32 Media and VFP Feature Register 2
        pub const mvfr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0011, .op2 = 0b010 };
        /// D19.2.108 PAR_EL1, Physical Address Register
        pub const par_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0111, .CRm = 0b0100, .op2 = 0b000 };
        /// D19.2.109 REVIDR_EL1, Revision ID Register
        pub const revidr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b110 };
        /// D19.2.110 RGSR_EL1, Random Allocation Tag Seed Register
        pub const rgsr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b101 };
        /// D19.2.111 RMR_EL1, Reset Management Register (EL1)
        pub const rmr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.112 RMR_EL2, Reset Management Register (EL2)
        pub const rmr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.113 RMR_EL3, Reset Management Register (EL3)
        pub const rmr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.114 RNDR, Random Number
        pub const rndr: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b0010, .CRm = 0b0100, .op2 = 0b000 };
        /// D19.2.115 RNDRRS, Reseeded Random Number
        pub const rndrrs: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b0010, .CRm = 0b0100, .op2 = 0b001 };
        /// D19.2.116 RVBAR_EL1, Reset Vector Base Address Register (if EL2 and EL3 not implemented)
        pub const rvbar_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.117 RVBAR_EL2, Reset Vector Base Address Register (if EL3 not implemented)
        pub const rvbar_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.118 RVBAR_EL3, Reset Vector Base Address Register (if EL3 implemented)
        pub const rvbar_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.120 SCR_EL3, Secure Configuration Register
        pub const scr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.121 SCTLR2_EL1, System Control Register (EL1)
        pub const sctlr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.121 SCTLR2_EL12, System Control Register (EL12)
        pub const sctlr2_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.122 SCTLR2_EL2, System Control Register (EL2)
        pub const sctlr2_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.123 SCTLR2_EL3, System Control Register (EL3)
        pub const sctlr2_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.124 SCTLR_EL1, System Control Register (EL1)
        pub const sctlr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.124 SCTLR_EL12, System Control Register (EL12)
        pub const sctlr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.125 SCTLR_EL2, System Control Register (EL2)
        pub const sctlr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.126 SCTLR_EL3, System Control Register (EL3)
        pub const sctlr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.127 SCXTNUM_EL0, EL0 Read/Write Software Context Number
        pub const scxtnum_el0: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.128 SCXTNUM_EL1, EL1 Read/Write Software Context Number
        pub const scxtnum_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.128 SCXTNUM_EL12, EL12 Read/Write Software Context Number
        pub const scxtnum_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.129 SCXTNUM_EL2, EL2 Read/Write Software Context Number
        pub const scxtnum_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.130 SCXTNUM_EL3, EL3 Read/Write Software Context Number
        pub const scxtnum_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b111 };
        /// D19.2.131 SMCR_EL1, SME Control Register (EL1)
        pub const smcr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b110 };
        /// D19.2.131 SMCR_EL12, SME Control Register (EL12)
        pub const smcr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b110 };
        /// D19.2.132 SMCR_EL2, SME Control Register (EL2)
        pub const smcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b110 };
        /// D19.2.133 SMCR_EL3, SME Control Register (EL3)
        pub const smcr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b110 };
        /// D19.2.134 SMIDR_EL1, Streaming Mode Identification Register
        pub const smidr_el1: System = .{ .op0 = 0b11, .op1 = 0b001, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b110 };
        /// D19.2.135 SMPRIMAP_EL2, Streaming Mode Priority Mapping Register
        pub const smprimap_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b101 };
        /// D19.2.136 SMPRI_EL1, Streaming Mode Priority Register
        pub const smpri_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b100 };
        /// D19.2.137 TCR2_EL1, Extended Translation Control Register (EL1)
        pub const tcr2_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.137 TCR2_EL12, Extended Translation Control Register (EL12)
        pub const tcr2_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.138 TCR2_EL2, Extended Translation Control Register (EL2)
        pub const tcr2_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.139 TCR_EL1, Translation Control Register (EL1)
        pub const tcr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.139 TCR_EL12, Translation Control Register (EL12)
        pub const tcr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.140 TCR_EL2, Translation Control Register (EL2)
        pub const tcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.141 TCR_EL3, Translation Control Register (EL3)
        pub const tcr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.142 TFSRE0_EL1, Tag Fault Status Register (EL0)
        pub const tfsre0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0101, .CRm = 0b0110, .op2 = 0b001 };
        /// D19.2.143 TFSR_EL1, Tag Fault Status Register (EL1)
        pub const tfsr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0101, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.143 TFSR_EL12, Tag Fault Status Register (EL12)
        pub const tfsr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0101, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.144 TFSR_EL2, Tag Fault Status Register (EL2)
        pub const tfsr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0101, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.145 TFSR_EL3, Tag Fault Status Register (EL3)
        pub const tfsr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0101, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.146 TPIDR2_EL0, EL0 Read/Write Software Thread ID Register 2
        pub const tpidr2_el0: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b101 };
        /// D19.2.147 TPIDR_EL0, EL0 Read/Write Software Thread ID Register
        pub const tpidr_el0: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.148 TPIDR_EL1, EL1 Read/Write Software Thread ID Register
        pub const tpidr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b100 };
        /// D19.2.149 TPIDR_EL2, EL2 Read/Write Software Thread ID Register
        pub const tpidr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.150 TPIDR_EL3, EL3 Read/Write Software Thread ID Register
        pub const tpidr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b010 };
        /// D19.2.151 TPIDRRO_EL0, EL0 Read-Only Software Thread ID Register
        pub const tpidrro_el3: System = .{ .op0 = 0b11, .op1 = 0b011, .CRn = 0b1101, .CRm = 0b0000, .op2 = 0b011 };
        /// D19.2.152 TTBR0_EL1, Translation Table Base Register 0 (EL1)
        pub const ttbr0_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.152 TTBR0_EL12, Translation Table Base Register 0 (EL12)
        pub const ttbr0_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.153 TTBR0_EL2, Translation Table Base Register 0 (EL2)
        pub const ttbr0_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.154 TTBR0_EL3, Translation Table Base Register 0 (EL3)
        pub const ttbr0_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.155 TTBR1_EL1, Translation Table Base Register 1 (EL1)
        pub const ttbr1_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.155 TTBR1_EL12, Translation Table Base Register 1 (EL12)
        pub const ttbr1_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.156 TTBR1_EL2, Translation Table Base Register 1 (EL2)
        pub const ttbr1_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0000, .op2 = 0b001 };
        /// D19.2.157 VBAR_EL1, Vector Base Address Register (EL1)
        pub const vbar_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.157 VBAR_EL12, Vector Base Address Register (EL12)
        pub const vbar_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.158 VBAR_EL2, Vector Base Address Register (EL2)
        pub const vbar_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.159 VBAR_EL3, Vector Base Address Register (EL3)
        pub const vbar_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b1100, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.160 VMPIDR_EL2, Virtualization Multiprocessor ID Register
        pub const vmpidr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b101 };
        /// D19.2.161 VNCR_EL2, Virtual Nested Control Register
        pub const nvcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.162 VPIDR_EL2, Virtualization Processor ID Register
        pub const vpidr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0000, .CRm = 0b0000, .op2 = 0b000 };
        /// D19.2.163 VSTCR_EL2, Virtualization Secure Translation Control Register
        pub const vstcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0110, .op2 = 0b010 };
        /// D19.2.164 VSTTBR_EL2, Virtualization Secure Translation Table Base Register
        pub const vsttbr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0110, .op2 = 0b000 };
        /// D19.2.165 VTCR_EL2, Virtualization Translation Control Register
        pub const vtcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b010 };
        /// D19.2.166 VTTBR_EL2, Virtualization Translation Table Base Register
        pub const vttbr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0010, .CRm = 0b0001, .op2 = 0b000 };
        /// D19.2.167 ZCR_EL1, SVE Control Register (EL1)
        pub const zcr_el1: System = .{ .op0 = 0b11, .op1 = 0b000, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.167 ZCR_EL12, SVE Control Register (EL12)
        pub const zcr_el12: System = .{ .op0 = 0b11, .op1 = 0b101, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.168 ZCR_EL2, SVE Control Register (EL2)
        pub const zcr_el2: System = .{ .op0 = 0b11, .op1 = 0b100, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b000 };
        /// D19.2.169 ZCR_EL3, SVE Control Register (EL3)
        pub const zcr_el3: System = .{ .op0 = 0b11, .op1 = 0b110, .CRn = 0b0001, .CRm = 0b0010, .op2 = 0b000 };

        pub fn parse(reg: []const u8) ?System {
            if (reg.len >= 10 and std.ascii.toLower(reg[0]) == 's') encoded: {
                var symbol_it = std.mem.splitScalar(u8, reg[1..], '_');
                const op0 = std.fmt.parseInt(u2, symbol_it.next() orelse break :encoded, 10) catch break :encoded;
                if (op0 < 0b10) break :encoded;
                const op1 = std.fmt.parseInt(u3, symbol_it.next() orelse break :encoded, 10) catch break :encoded;
                const n = symbol_it.next() orelse break :encoded;
                if (n.len == 0 or std.ascii.toLower(n[0]) != 'c') break :encoded;
                const CRn = std.fmt.parseInt(u4, n[1..], 10) catch break :encoded;
                const m = symbol_it.next() orelse break :encoded;
                if (m.len == 0 or std.ascii.toLower(m[0]) != 'c') break :encoded;
                const CRm = std.fmt.parseInt(u4, m[1..], 10) catch break :encoded;
                const op2 = std.fmt.parseInt(u3, symbol_it.next() orelse break :encoded, 10) catch break :encoded;
                if (symbol_it.next() != null) break :encoded;
                return .{ .op0 = op0, .op1 = op1, .CRn = CRn, .CRm = CRm, .op2 = op2 };
            }
            inline for (@typeInfo(System).@"struct".decls) |decl| {
                if (@TypeOf(@field(System, decl.name)) != System) continue;
                if (toLowerEqlAssertLower(reg, decl.name)) return @field(System, decl.name);
            }
            return null;
        }
    };

    fn toLowerEqlAssertLower(lhs: []const u8, rhs: []const u8) bool {
        if (lhs.len != rhs.len) return false;
        for (lhs, rhs) |l, r| {
            assert(!std.ascii.isUpper(r));
            if (std.ascii.toLower(l) != r) return false;
        }
        return true;
    }
};

/// C1.2.4 Condition code
pub const ConditionCode = enum(u4) {
    /// integer: Equal
    /// floating-point: Equal
    /// Z == 1
    eq = 0b0000,
    /// integer: Not equal
    /// floating-point: Not equal or unordered
    /// Z == 0
    ne = 0b0001,
    /// integer: Unsigned higher or same
    /// floating-point: Greater than, equal, or unordered
    /// C == 1
    hs = 0b0010,
    /// integer: Unsigned lower
    /// floating-point: Less than
    /// C == 0
    lo = 0b0011,
    /// integer: Minus, negative
    /// floating-point: Less than
    /// N == 1
    mi = 0b0100,
    /// integer: Plus, positive or zero
    /// floating-point: Greater than, equal, or unordered
    /// N == 0
    pl = 0b0101,
    /// integer: Overflow
    /// floating-point: Unordered
    /// V == 1
    vs = 0b0110,
    /// integer: No overflow
    /// floating-point: Ordered
    /// V == 0
    vc = 0b0111,
    /// integer: Unsigned higher
    /// floating-point: Greater than, or unordered
    /// C == 1 and Z == 0
    hi = 0b1000,
    /// integer: Unsigned lower or same
    /// floating-point: Less than or equal
    /// C == 0 or Z == 1
    ls = 0b1001,
    /// integer: Signed greater than or equal
    /// floating-point: Greater than or equal
    /// N == V
    ge = 0b1010,
    /// integer: Signed less than
    /// floating-point: Less than, or unordered
    /// N != V
    lt = 0b1011,
    /// integer: Signed greater than
    /// floating-point: Greater than
    /// Z == 0 and N == V
    gt = 0b1100,
    /// integer: Signed less than or equal
    /// floating-point: Less than, equal, or unordered
    /// Z == 1 or N != V
    le = 0b1101,
    /// integer: Always
    /// floating-point: Always
    /// true
    al = 0b1110,
    /// integer: Always
    /// floating-point: Always
    /// true
    nv = 0b1111,
    /// Carry set
    /// C == 1
    pub const cs: ConditionCode = .hs;
    /// Carry clear
    /// C == 0
    pub const cc: ConditionCode = .lo;

    pub fn invert(cond: ConditionCode) ConditionCode {
        return @enumFromInt(@intFromEnum(cond) ^ 0b0001);
    }
};

/// C4.1 A64 instruction set encoding
pub const Instruction = packed union {
    group: Group,
    reserved: Reserved,
    sme: Sme,
    sve: Sve,
    data_processing_immediate: DataProcessingImmediate,
    branch_exception_generating_system: BranchExceptionGeneratingSystem,
    load_store: LoadStore,
    data_processing_register: DataProcessingRegister,
    data_processing_vector: DataProcessingVector,

    /// Table C4-1 Main encoding table for the A64 instruction set
    pub const Group = packed struct {
        encoded0: u25,
        op1: u4,
        encoded29: u2,
        op0: u1,
    };

    /// C4.1.1 Reserved
    pub const Reserved = packed union {
        group: @This().Group,
        udf: Udf,

        /// Table C4-2 Encoding table for the Reserved group
        pub const Group = packed struct {
            encoded0: u16,
            op1: u9,
            decoded25: u4 = 0b0000,
            op0: u2,
            decoded31: u1 = 0b0,
        };

        /// C6.2.387 UDF
        pub const Udf = packed struct {
            imm16: u16,
            decoded16: u16 = 0b0000000000000000,
        };

        pub const Decoded = union(enum) {
            unallocated,
            udf: Udf,
        };
        pub fn decode(inst: @This()) @This().Decoded {
            return switch (inst.group.op0) {
                0b00 => switch (inst.group.op1) {
                    0b000000000 => .{ .udf = inst.udf },
                    else => .unallocated,
                },
                else => .unallocated,
            };
        }
    };

    /// C4.1.2 SME encodings
    pub const Sme = packed union {
        group: @This().Group,

        /// Table C4-3 Encodings table for the SME encodings group
        pub const Group = packed struct {
            encoded0: u2,
            op2: u3,
            encoded5: u5,
            op1: u15,
            decoded25: u4 = 0b0000,
            op0: u2,
            decoded31: u1 = 0b1,
        };
    };

    /// C4.1.30 SVE encodings
    pub const Sve = packed union {
        group: @This().Group,

        /// Table C4-31 Encoding table for the SVE encodings group
        pub const Group = packed struct {
            encoded0: u4,
            op2: u1,
            encoded5: u5,
            op1: u15,
            decoded25: u4 = 0b0010,
            op0: u3,
        };
    };

    /// C4.1.86 Data Processing -- Immediate
    pub const DataProcessingImmediate = packed union {
        group: @This().Group,
        pc_relative_addressing: PcRelativeAddressing,
        add_subtract_immediate: AddSubtractImmediate,
        add_subtract_immediate_with_tags: AddSubtractImmediateWithTags,
        logical_immediate: LogicalImmediate,
        move_wide_immediate: MoveWideImmediate,
        bitfield: Bitfield,
        extract: Extract,

        /// Table C4-87 Encoding table for the Data Processing -- Immediate group
        pub const Group = packed struct {
            encoded0: u23,
            op0: u3,
            decoded26: u3 = 0b100,
            encoded29: u3,
        };

        /// PC-rel. addressing
        pub const PcRelativeAddressing = packed union {
            group: @This().Group,
            adr: Adr,
            adrp: Adrp,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                immhi: i19,
                decoded24: u5 = 0b10000,
                immlo: u2,
                op: Op,
            };

            /// C6.2.10 ADR
            pub const Adr = packed struct {
                Rd: Register.Encoded,
                immhi: i19,
                decoded24: u5 = 0b10000,
                immlo: u2,
                op: Op = .adr,
            };

            /// C6.2.11 ADRP
            pub const Adrp = packed struct {
                Rd: Register.Encoded,
                immhi: i19,
                decoded24: u5 = 0b10000,
                immlo: u2,
                op: Op = .adrp,
            };

            pub const Op = enum(u1) {
                adr = 0b0,
                adrp = 0b1,
            };
        };

        /// Add/subtract (immediate)
        pub const AddSubtractImmediate = packed union {
            group: @This().Group,
            add: Add,
            adds: Adds,
            sub: Sub,
            subs: Subs,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                sh: Shift,
                decoded23: u6 = 0b100010,
                S: bool,
                op: AddSubtractOp,
                sf: Register.IntegerSize,
            };

            /// C6.2.4 ADD (immediate)
            pub const Add = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                sh: Shift,
                decoded23: u6 = 0b100010,
                S: bool = false,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.8 ADDS (immediate)
            pub const Adds = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                sh: Shift,
                decoded23: u6 = 0b100010,
                S: bool = true,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.357 SUB (immediate)
            pub const Sub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                sh: Shift,
                decoded23: u6 = 0b100010,
                S: bool = false,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            /// C6.2.363 SUBS (immediate)
            pub const Subs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                sh: Shift,
                decoded23: u6 = 0b100010,
                S: bool = true,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            pub const Shift = enum(u1) {
                @"0" = 0b0,
                @"12" = 0b1,
            };
        };

        /// Add/subtract (immediate, with tags)
        pub const AddSubtractImmediateWithTags = packed union {
            group: @This().Group,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                uimm4: u4,
                op3: u2,
                uimm6: u6,
                o2: u1,
                decoded23: u6 = 0b100011,
                S: bool,
                op: AddSubtractOp,
                sf: Register.IntegerSize,
            };
        };

        /// Logical (immediate)
        pub const LogicalImmediate = packed union {
            group: @This().Group,
            @"and": And,
            orr: Orr,
            eor: Eor,
            ands: Ands,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100100,
                opc: LogicalOpc,
                sf: Register.IntegerSize,
            };

            /// C6.2.12 AND (immediate)
            pub const And = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100100,
                opc: LogicalOpc = .@"and",
                sf: Register.IntegerSize,
            };

            /// C6.2.240 ORR (immediate)
            pub const Orr = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100100,
                opc: LogicalOpc = .orr,
                sf: Register.IntegerSize,
            };

            /// C6.2.119 EOR (immediate)
            pub const Eor = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100100,
                opc: LogicalOpc = .eor,
                sf: Register.IntegerSize,
            };

            /// C6.2.14 ANDS (immediate)
            pub const Ands = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100100,
                opc: LogicalOpc = .ands,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                @"and": And,
                orr: Orr,
                eor: Eor,
                ands: Ands,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return if (!inst.group.imm.validImmediate(inst.group.sf))
                    .unallocated
                else switch (inst.group.opc) {
                    .@"and" => .{ .@"and" = inst.@"and" },
                    .orr => .{ .orr = inst.orr },
                    .eor => .{ .eor = inst.eor },
                    .ands => .{ .ands = inst.ands },
                };
            }
        };

        /// Move wide (immediate)
        pub const MoveWideImmediate = packed union {
            group: @This().Group,
            movn: Movn,
            movz: Movz,
            movk: Movk,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                imm16: u16,
                hw: Hw,
                decoded23: u6 = 0b100101,
                opc: Opc,
                sf: Register.IntegerSize,
            };

            /// C6.2.226 MOVN
            pub const Movn = packed struct {
                Rd: Register.Encoded,
                imm16: u16,
                hw: Hw,
                decoded23: u6 = 0b100101,
                opc: Opc = .movn,
                sf: Register.IntegerSize,
            };

            /// C6.2.227 MOVZ
            pub const Movz = packed struct {
                Rd: Register.Encoded,
                imm16: u16,
                hw: Hw,
                decoded23: u6 = 0b100101,
                opc: Opc = .movz,
                sf: Register.IntegerSize,
            };

            /// C6.2.225 MOVK
            pub const Movk = packed struct {
                Rd: Register.Encoded,
                imm16: u16,
                hw: Hw,
                decoded23: u6 = 0b100101,
                opc: Opc = .movk,
                sf: Register.IntegerSize,
            };

            pub const Hw = enum(u2) {
                @"0" = 0b00,
                @"16" = 0b01,
                @"32" = 0b10,
                @"48" = 0b11,

                pub fn int(hw: Hw) u6 {
                    return switch (hw) {
                        .@"0" => 0,
                        .@"16" => 16,
                        .@"32" => 32,
                        .@"48" => 48,
                    };
                }

                pub fn sf(hw: Hw) Register.IntegerSize {
                    return switch (hw) {
                        .@"0", .@"16" => .word,
                        .@"32", .@"48" => .doubleword,
                    };
                }
            };

            pub const Opc = enum(u2) {
                movn = 0b00,
                movz = 0b10,
                movk = 0b11,
                _,
            };

            pub const Decoded = union(enum) {
                unallocated,
                movn: Movn,
                movz: Movz,
                movk: Movk,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return if (inst.group.sf == .word and inst.group.hw.sf() == .doubleword)
                    .unallocated
                else switch (inst.group.opc) {
                    _ => .unallocated,
                    .movn => .{ .movn = inst.movn },
                    .movz => .{ .movz = inst.movz },
                    .movk => .{ .movk = inst.movk },
                };
            }
        };

        /// Bitfield
        pub const Bitfield = packed union {
            group: @This().Group,
            sbfm: Sbfm,
            bfm: Bfm,
            ubfm: Ubfm,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100110,
                opc: Opc,
                sf: Register.IntegerSize,
            };

            pub const Sbfm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100110,
                opc: Opc = .sbfm,
                sf: Register.IntegerSize,
            };

            pub const Bfm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100110,
                opc: Opc = .bfm,
                sf: Register.IntegerSize,
            };

            pub const Ubfm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm: Bitmask,
                decoded23: u6 = 0b100110,
                opc: Opc = .ubfm,
                sf: Register.IntegerSize,
            };

            pub const Opc = enum(u2) {
                sbfm = 0b00,
                bfm = 0b01,
                ubfm = 0b10,
                _,
            };

            pub const Decoded = union(enum) {
                unallocated,
                sbfm: Sbfm,
                bfm: Bfm,
                ubfm: Ubfm,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return if (!inst.group.imm.validBitfield(inst.group.sf))
                    .unallocated
                else switch (inst.group.opc) {
                    _ => .unallocated,
                    .sbfm => .{ .sbfm = inst.sbfm },
                    .bfm => .{ .bfm = inst.bfm },
                    .ubfm => .{ .ubfm = inst.ubfm },
                };
            }
        };

        /// Extract
        pub const Extract = packed union {
            group: @This().Group,
            extr: Extr,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imms: u6,
                Rm: Register.Encoded,
                o0: u1,
                N: Register.IntegerSize,
                decoded23: u6 = 0b100111,
                op21: u2,
                sf: Register.IntegerSize,
            };

            pub const Extr = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imms: u6,
                Rm: Register.Encoded,
                o0: u1 = 0b0,
                N: Register.IntegerSize,
                decoded23: u6 = 0b100111,
                op21: u2 = 0b00,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                extr: Extr,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.op21) {
                    0b01, 0b10...0b11 => .unallocated,
                    0b00 => switch (inst.group.o0) {
                        0b1 => .unallocated,
                        0b0 => if ((inst.group.sf == .word and @as(u1, @truncate(inst.group.imms >> 5)) == 0b1) or
                            inst.group.sf != inst.group.N)
                            .unallocated
                        else
                            .{ .extr = inst.extr },
                    },
                };
            }
        };

        pub const Bitmask = packed struct {
            imms: u6,
            immr: u6,
            N: Register.IntegerSize,

            fn lenHsb(bitmask: Bitmask) u7 {
                return @bitCast(packed struct {
                    not_imms: u6,
                    N: Register.IntegerSize,
                }{ .not_imms = ~bitmask.imms, .N = bitmask.N });
            }

            fn validImmediate(bitmask: Bitmask, sf: Register.IntegerSize) bool {
                if (sf == .word and bitmask.N == .doubleword) return false;
                const len_hsb = bitmask.lenHsb();
                return (len_hsb -% 1) & len_hsb != 0b0_000000;
            }

            fn validBitfield(bitmask: Bitmask, sf: Register.IntegerSize) bool {
                if (sf != bitmask.N) return false;
                if (sf == .word and (@as(u1, @truncate(bitmask.immr >> 5)) != 0b0 or
                    @as(u1, @truncate(bitmask.imms >> 5)) != 0b0)) return false;
                const len_hsb = bitmask.lenHsb();
                return len_hsb >= 0b0_000010;
            }

            fn decode(bitmask: Bitmask, sf: Register.IntegerSize) struct { u64, u64 } {
                const esize = @as(u7, 1 << 6) >> @clz(bitmask.lenHsb());
                const levels: u6 = @intCast(esize - 1);
                const s = bitmask.imms & levels;
                const r = bitmask.immr & levels;
                const d = (s -% r) & levels;
                const welem = @as(u64, std.math.maxInt(u64)) >> (63 - s);
                const telem = @as(u64, std.math.maxInt(u64)) >> (63 - d);
                const emask = @as(u64, std.math.maxInt(u64)) >> @intCast(64 - esize);
                const rmask = @divExact(std.math.maxInt(u64), emask);
                const wmask = std.math.rotr(u64, welem * rmask, r);
                const tmask = telem * rmask;
                return switch (sf) {
                    .word => .{ @as(u32, @truncate(wmask)), @as(u32, @truncate(tmask)) },
                    .doubleword => .{ wmask, tmask },
                };
            }

            pub fn decodeImmediate(bitmask: Bitmask, sf: Register.IntegerSize) u64 {
                assert(bitmask.validImmediate(sf));
                const imm, _ = bitmask.decode(sf);
                return imm;
            }

            pub fn decodeBitfield(bitmask: Bitmask, sf: Register.IntegerSize) struct { u64, u64 } {
                assert(bitmask.validBitfield(sf));
                return bitmask.decode(sf);
            }

            pub fn moveWidePreferred(bitmask: Bitmask, sf: Register.IntegerSize) bool {
                const s = bitmask.imms;
                const r = bitmask.immr;
                const width: u7 = switch (sf) {
                    .word => 32,
                    .doubleword => 64,
                };
                if (sf != bitmask.N) return false;
                if (sf == .word and @as(u1, @truncate(s >> 5)) != 0b0) return false;
                if (s < 16) return (-%r % 16) <= (15 - s);
                if (s >= width - 15) return (r % 16) <= (s - (width - 15));
                return false;
            }
        };

        pub const Decoded = union(enum) {
            unallocated,
            pc_relative_addressing: PcRelativeAddressing,
            add_subtract_immediate: AddSubtractImmediate,
            add_subtract_immediate_with_tags: AddSubtractImmediateWithTags,
            logical_immediate: LogicalImmediate,
            move_wide_immediate: MoveWideImmediate,
            bitfield: Bitfield,
            extract: Extract,
        };
        pub fn decode(inst: @This()) @This().Decoded {
            return switch (inst.group.op0) {
                0b000, 0b001 => .{ .pc_relative_addressing = inst.pc_relative_addressing },
                0b010 => .{ .add_subtract_immediate = inst.add_subtract_immediate },
                0b011 => .{ .add_subtract_immediate_with_tags = inst.add_subtract_immediate_with_tags },
                0b100 => .{ .logical_immediate = inst.logical_immediate },
                0b101 => .{ .move_wide_immediate = inst.move_wide_immediate },
                0b110 => .{ .bitfield = inst.bitfield },
                0b111 => .{ .extract = inst.extract },
            };
        }
    };

    /// C4.1.87 Branches, Exception Generating and System instructions
    pub const BranchExceptionGeneratingSystem = packed union {
        group: @This().Group,
        conditional_branch_immediate: ConditionalBranchImmediate,
        exception_generating: ExceptionGenerating,
        system_register_argument: SystemRegisterArgument,
        hints: Hints,
        barriers: Barriers,
        pstate: Pstate,
        system_result: SystemResult,
        system: System,
        system_register_move: SystemRegisterMove,
        unconditional_branch_register: UnconditionalBranchRegister,
        unconditional_branch_immediate: UnconditionalBranchImmediate,
        compare_branch_immediate: CompareBranchImmediate,
        test_branch_immediate: TestBranchImmediate,

        /// Table C4-88 Encoding table for the Branches, Exception Generating and System instructions group
        pub const Group = packed struct {
            op2: u5,
            encoded5: u7,
            op1: u14,
            decoded26: u3 = 0b101,
            op0: u3,
        };

        /// Conditional branch (immediate)
        pub const ConditionalBranchImmediate = packed union {
            group: @This().Group,
            b: B,
            bc: Bc,

            pub const Group = packed struct {
                cond: ConditionCode,
                o0: u1,
                imm19: i19,
                o1: u1,
                decoded25: u7 = 0b0101010,
            };

            /// C6.2.26 B.cond
            pub const B = packed struct {
                cond: ConditionCode,
                o0: u1 = 0b0,
                imm19: i19,
                o1: u1 = 0b0,
                decoded25: u7 = 0b0101010,
            };

            /// C6.2.27 BC.cond
            pub const Bc = packed struct {
                cond: ConditionCode,
                o0: u1 = 0b1,
                imm19: i19,
                o1: u1 = 0b0,
                decoded25: u7 = 0b0101010,
            };

            pub const Decoded = union(enum) {
                unallocated,
                b: B,
                bc: Bc,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.o1) {
                    0b0 => switch (inst.group.o0) {
                        0b0 => .{ .b = inst.b },
                        0b1 => .{ .bc = inst.bc },
                    },
                    0b1 => .unallocated,
                };
            }
        };

        /// Exception generating
        pub const ExceptionGenerating = packed union {
            group: @This().Group,
            svc: Svc,
            hvc: Hvc,
            smc: Smc,
            brk: Brk,
            hlt: Hlt,
            tcancel: Tcancel,
            dcps1: Dcps1,
            dcps2: Dcps2,
            dcps3: Dcps3,

            pub const Group = packed struct {
                LL: u2,
                op2: u3,
                imm16: u16,
                opc: u3,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.365 SVC
            pub const Svc = packed struct {
                decoded0: u2 = 0b01,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b000,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.128 HVC
            pub const Hvc = packed struct {
                decoded0: u2 = 0b10,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b000,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.283 SMC
            pub const Smc = packed struct {
                decoded0: u2 = 0b11,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b000,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.40 BRK
            pub const Brk = packed struct {
                decoded0: u2 = 0b00,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b001,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.127 HLT
            pub const Hlt = packed struct {
                decoded0: u2 = 0b00,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b010,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.376 TCANCEL
            pub const Tcancel = packed struct {
                decoded0: u2 = 0b00,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b011,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.110 DCPS1
            pub const Dcps1 = packed struct {
                LL: u2 = 0b01,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b101,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.110 DCPS2
            pub const Dcps2 = packed struct {
                LL: u2 = 0b10,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b101,
                decoded24: u8 = 0b11010100,
            };

            /// C6.2.110 DCPS3
            pub const Dcps3 = packed struct {
                LL: u2 = 0b11,
                decoded2: u3 = 0b000,
                imm16: u16,
                decoded21: u3 = 0b101,
                decoded24: u8 = 0b11010100,
            };

            pub const Decoded = union(enum) {
                unallocated,
                svc: Svc,
                hvc: Hvc,
                smc: Smc,
                brk: Brk,
                hlt: Hlt,
                tcancel: Tcancel,
                dcps1: Dcps1,
                dcps2: Dcps2,
                dcps3: Dcps3,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.op2) {
                    0b001 => .unallocated,
                    0b010...0b011 => .unallocated,
                    0b100...0b111 => .unallocated,
                    0b000 => switch (inst.group.opc) {
                        0b000 => switch (inst.group.LL) {
                            0b00 => .unallocated,
                            0b01 => .{ .svc = inst.svc },
                            0b10 => .{ .hvc = inst.hvc },
                            0b11 => .{ .smc = inst.smc },
                        },
                        0b001 => switch (inst.group.LL) {
                            0b01 => .unallocated,
                            0b00 => .{ .brk = inst.brk },
                            0b10...0b11 => .unallocated,
                        },
                        0b010 => switch (inst.group.LL) {
                            0b01 => .unallocated,
                            0b00 => .{ .hlt = inst.hlt },
                            0b10...0b11 => .unallocated,
                        },
                        0b011 => switch (inst.group.LL) {
                            0b00 => .{ .tcancel = inst.tcancel },
                            0b01 => .unallocated,
                            0b10...0b11 => .unallocated,
                        },
                        0b100 => .unallocated,
                        0b101 => switch (inst.group.LL) {
                            0b00 => .unallocated,
                            0b01 => .{ .dcps1 = inst.dcps1 },
                            0b10 => .{ .dcps2 = inst.dcps2 },
                            0b11 => .{ .dcps3 = inst.dcps3 },
                        },
                        0b110 => .unallocated,
                        0b111 => .unallocated,
                    },
                };
            }
        };

        /// System instructions with register argument
        pub const SystemRegisterArgument = packed struct {
            Rt: Register.Encoded,
            op2: u3,
            CRm: u4,
            decoded12: u20 = 0b11010101000000110001,
        };

        /// Hints
        pub const Hints = packed union {
            group: @This().Group,
            hint: Hint,
            nop: Nop,
            yield: Yield,
            wfe: Wfe,
            wfi: Wfi,
            sev: Sev,
            sevl: Sevl,

            pub const Group = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3,
                CRm: u4,
                decoded12: u20 = 0b11010101000000110010,
            };

            /// C6.2.126 HINT
            pub const Hint = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3,
                CRm: u4,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.238 NOP
            pub const Nop = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b000,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.402 YIELD
            pub const Yield = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b001,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.396 WFE
            pub const Wfe = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b010,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.398 WFI
            pub const Wfi = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b011,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.280 SEV
            pub const Sev = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b100,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.280 SEVL
            pub const Sevl = packed struct {
                decoded0: u5 = 0b11111,
                op2: u3 = 0b101,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0010,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            pub const Decoded = union(enum) {
                hint: Hint,
                nop: Nop,
                yield: Yield,
                wfe: Wfe,
                wfi: Wfi,
                sev: Sev,
                sevl: Sevl,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.CRm) {
                    else => .{ .hint = inst.hint },
                    0b0000 => switch (inst.group.op2) {
                        else => .{ .hint = inst.hint },
                        0b000 => .{ .nop = inst.nop },
                        0b001 => .{ .yield = inst.yield },
                        0b010 => .{ .wfe = inst.wfe },
                        0b011 => .{ .wfi = inst.wfi },
                        0b100 => .{ .sev = inst.sev },
                        0b101 => .{ .sevl = inst.sevl },
                    },
                };
            }
        };

        /// Barriers
        pub const Barriers = packed union {
            group: @This().Group,
            clrex: Clrex,
            dsb: Dsb,
            dmb: Dmb,
            isb: Isb,
            sb: Sb,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                op2: u3,
                CRm: u4,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.56 CLREX
            pub const Clrex = packed struct {
                Rt: Register.Encoded = @enumFromInt(0b11111),
                op2: u3 = 0b010,
                CRm: u4,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.116 DSB
            pub const Dsb = packed struct {
                Rt: Register.Encoded = @enumFromInt(0b11111),
                opc: u2 = 0b00,
                decoded7: u1 = 0b1,
                CRm: Option,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.114 DMB
            pub const Dmb = packed struct {
                Rt: Register.Encoded = @enumFromInt(0b11111),
                opc: u2 = 0b01,
                decoded7: u1 = 0b1,
                CRm: Option,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.131 ISB
            pub const Isb = packed struct {
                Rt: Register.Encoded = @enumFromInt(0b11111),
                opc: u2 = 0b10,
                decoded7: u1 = 0b1,
                CRm: Option,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.264 SB
            pub const Sb = packed struct {
                Rt: Register.Encoded = @enumFromInt(0b11111),
                opc: u2 = 0b11,
                decoded7: u1 = 0b1,
                CRm: u4 = 0b0000,
                decoded12: u4 = 0b0011,
                decoded16: u3 = 0b011,
                decoded19: u2 = 0b00,
                decoded21: u1 = 0b0,
                decoded22: u10 = 0b1101010100,
            };

            pub const Option = enum(u4) {
                oshld = 0b0001,
                oshst = 0b0010,
                osh = 0b0011,
                nshld = 0b0101,
                nshst = 0b0110,
                nsh = 0b0111,
                ishld = 0b1001,
                ishst = 0b1010,
                ish = 0b1011,
                ld = 0b1101,
                st = 0b1110,
                sy = 0b1111,
                _,
            };
        };

        /// PSTATE
        pub const Pstate = packed struct {
            Rt: Register.Encoded,
            op2: u3,
            CRm: u4,
            decoded12: u4 = 0b0100,
            op1: u3,
            decoded19: u13 = 0b1101010100000,
        };

        /// System with result
        pub const SystemResult = packed struct {
            Rt: Register.Encoded,
            op2: u3,
            CRm: u4,
            CRn: u4,
            op1: u3,
            decoded19: u13 = 0b1101010100100,
        };

        /// System instructions
        pub const System = packed union {
            group: @This().Group,
            sys: Sys,
            sysl: Sysl,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                op2: u3,
                CRm: u4,
                CRn: u4,
                op1: u3,
                decoded19: u2 = 0b01,
                L: L,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.372 SYS
            pub const Sys = packed struct {
                Rt: Register.Encoded,
                op2: u3,
                CRm: u4,
                CRn: u4,
                op1: u3,
                decoded19: u2 = 0b01,
                L: L = .sys,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.373 SYSL
            pub const Sysl = packed struct {
                Rt: Register.Encoded,
                op2: u3,
                CRm: u4,
                CRn: u4,
                op1: u3,
                decoded19: u2 = 0b01,
                L: L = .sysl,
                decoded22: u10 = 0b1101010100,
            };

            const L = enum(u1) {
                sys = 0b0,
                sysl = 0b1,
            };

            pub const Decoded = union(enum) {
                sys: Sys,
                sysl: Sysl,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.L) {
                    .sys => .{ .sys = inst.sys },
                    .sysl => .{ .sysl = inst.sysl },
                };
            }
        };

        /// System register move
        pub const SystemRegisterMove = packed union {
            group: @This().Group,
            msr: Msr,
            mrs: Mrs,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                systemreg: Register.System,
                L: L,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.230 MSR (register)
            pub const Msr = packed struct {
                Rt: Register.Encoded,
                systemreg: Register.System,
                L: L = .msr,
                decoded22: u10 = 0b1101010100,
            };

            /// C6.2.228 MRS
            pub const Mrs = packed struct {
                Rt: Register.Encoded,
                systemreg: Register.System,
                L: L = .mrs,
                decoded22: u10 = 0b1101010100,
            };

            pub const L = enum(u1) {
                msr = 0b0,
                mrs = 0b1,
            };

            pub const Decoded = union(enum) {
                msr: Msr,
                mrs: Mrs,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.L) {
                    .msr => .{ .msr = inst.msr },
                    .mrs => .{ .mrs = inst.mrs },
                };
            }
        };

        /// Unconditional branch (register)
        pub const UnconditionalBranchRegister = packed union {
            group: @This().Group,
            br: Br,
            blr: Blr,
            ret: Ret,

            pub const Group = packed struct {
                op4: u5,
                Rn: Register.Encoded,
                op3: u6,
                op2: u5,
                opc: u4,
                decoded25: u7 = 0b1101011,
            };

            /// C6.2.37 BR
            pub const Br = packed struct {
                Rm: Register.Encoded = @enumFromInt(0),
                Rn: Register.Encoded,
                M: bool = false,
                A: bool = false,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b11111,
                op: u2 = 0b00,
                decoded23: u1 = 0b0,
                Z: bool = false,
                decoded25: u7 = 0b1101011,
            };

            /// C6.2.35 BLR
            pub const Blr = packed struct {
                Rm: Register.Encoded = @enumFromInt(0),
                Rn: Register.Encoded,
                M: bool = false,
                A: bool = false,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b11111,
                op: u2 = 0b01,
                decoded23: u1 = 0b0,
                Z: bool = false,
                decoded25: u7 = 0b1101011,
            };

            /// C6.2.254 RET
            pub const Ret = packed struct {
                Rm: Register.Encoded = @enumFromInt(0),
                Rn: Register.Encoded,
                M: bool = false,
                A: bool = false,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b11111,
                op: u2 = 0b10,
                decoded23: u1 = 0b0,
                Z: bool = false,
                decoded25: u7 = 0b1101011,
            };

            pub const Decoded = union(enum) {
                unallocated,
                br: Br,
                blr: Blr,
                ret: Ret,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.op2) {
                    else => .unallocated,
                    0b11111 => switch (inst.group.opc) {
                        0b0000 => switch (inst.group.op4) {
                            else => .unallocated,
                            0b00000 => .{ .br = inst.br },
                        },
                        0b0001 => switch (inst.group.op4) {
                            else => .unallocated,
                            0b00000 => .{ .blr = inst.blr },
                        },
                        0b0010 => switch (inst.group.op4) {
                            else => .unallocated,
                            0b00000 => .{ .ret = inst.ret },
                        },
                        else => .unallocated,
                    },
                };
            }
        };

        /// Unconditional branch (immediate)
        pub const UnconditionalBranchImmediate = packed union {
            group: @This().Group,
            b: B,
            bl: Bl,

            pub const Group = packed struct {
                imm26: i26,
                decoded26: u5 = 0b00101,
                op: Op,
            };

            /// C6.2.25 B
            pub const B = packed struct {
                imm26: i26,
                decoded26: u5 = 0b00101,
                op: Op = .b,
            };

            /// C6.2.34 BL
            pub const Bl = packed struct {
                imm26: i26,
                decoded26: u5 = 0b00101,
                op: Op = .bl,
            };

            pub const Op = enum(u1) {
                b = 0b0,
                bl = 0b1,
            };
        };

        /// Compare and branch (immediate)
        pub const CompareBranchImmediate = packed union {
            group: @This().Group,
            cbz: Cbz,
            cbnz: Cbnz,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                imm19: i19,
                op: Op,
                decoded25: u6 = 0b011010,
                sf: Register.IntegerSize,
            };

            /// C6.2.47 CBZ
            pub const Cbz = packed struct {
                Rt: Register.Encoded,
                imm19: i19,
                op: Op = .cbz,
                decoded25: u6 = 0b011010,
                sf: Register.IntegerSize,
            };

            /// C6.2.46 CBNZ
            pub const Cbnz = packed struct {
                Rt: Register.Encoded,
                imm19: i19,
                op: Op = .cbnz,
                decoded25: u6 = 0b011010,
                sf: Register.IntegerSize,
            };

            pub const Op = enum(u1) {
                cbz = 0b0,
                cbnz = 0b1,
            };
        };

        /// Test and branch (immediate)
        pub const TestBranchImmediate = packed union {
            group: @This().Group,
            tbz: Tbz,
            tbnz: Tbnz,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                imm14: i14,
                b40: u5,
                op: Op,
                decoded25: u6 = 0b011011,
                b5: u1,
            };

            /// C6.2.375 TBZ
            pub const Tbz = packed struct {
                Rt: Register.Encoded,
                imm14: i14,
                b40: u5,
                op: Op = .tbz,
                decoded25: u6 = 0b011011,
                b5: u1,
            };

            /// C6.2.374 TBNZ
            pub const Tbnz = packed struct {
                Rt: Register.Encoded,
                imm14: i14,
                b40: u5,
                op: Op = .tbnz,
                decoded25: u6 = 0b011011,
                b5: u1,
            };

            pub const Op = enum(u1) {
                tbz = 0b0,
                tbnz = 0b1,
            };
        };

        pub const Decoded = union(enum) {
            unallocated,
            conditional_branch_immediate: ConditionalBranchImmediate,
            exception_generating: ExceptionGenerating,
            system_register_argument: SystemRegisterArgument,
            hints: Hints,
            barriers: Barriers,
            pstate: Pstate,
            system_result: SystemResult,
            system: System,
            system_register_move: SystemRegisterMove,
            unconditional_branch_register: UnconditionalBranchRegister,
            unconditional_branch_immediate: UnconditionalBranchImmediate,
            compare_branch_immediate: CompareBranchImmediate,
            test_branch_immediate: TestBranchImmediate,
        };
        pub fn decode(inst: @This()) @This().Decoded {
            return switch (inst.group.op0) {
                0b010 => switch (inst.group.op1) {
                    0b000000000000000...0b01111111111111 => .{ .conditional_branch_immediate = inst.conditional_branch_immediate },
                    else => .unallocated,
                },
                0b110 => switch (inst.group.op1) {
                    0b00000000000000...0b00111111111111 => .{ .exception_generating = inst.exception_generating },
                    0b01000000110001 => .{ .system_register_argument = inst.system_register_argument },
                    0b01000000110010 => switch (inst.group.op2) {
                        0b11111 => .{ .hints = inst.hints },
                        else => .unallocated,
                    },
                    0b01000000110011 => .{ .barriers = inst.barriers },
                    0b01000000000100,
                    0b01000000010100,
                    0b01000000100100,
                    0b01000000110100,
                    0b01000001000100,
                    0b01000001010100,
                    0b01000001100100,
                    0b01000001110100,
                    => .{ .pstate = inst.pstate },
                    0b01001000000000...0b01001001111111 => .{ .system_result = inst.system_result },
                    0b01000010000000...0b01000011111111, 0b01001010000000...0b01001011111111 => .{ .system = inst.system },
                    0b01000100000000...0b01000111111111, 0b01001100000000...0b01001111111111 => .{ .system_register_move = inst.system_register_move },
                    0b10000000000000...0b11111111111111 => .{ .unconditional_branch_register = inst.unconditional_branch_register },
                    else => .unallocated,
                },
                0b000, 0b100 => .{ .unconditional_branch_immediate = inst.unconditional_branch_immediate },
                0b001, 0b101 => switch (inst.group.op1) {
                    0b00000000000000...0b01111111111111 => .{ .compare_branch_immediate = inst.compare_branch_immediate },
                    0b10000000000000...0b11111111111111 => .{ .test_branch_immediate = inst.test_branch_immediate },
                },
                else => .unallocated,
            };
        }
    };

    /// C4.1.88 Loads and Stores
    pub const LoadStore = packed union {
        group: @This().Group,
        register_literal: RegisterLiteral,
        memory: Memory,
        no_allocate_pair_offset: NoAllocatePairOffset,
        register_pair_post_indexed: RegisterPairPostIndexed,
        register_pair_offset: RegisterPairOffset,
        register_pair_pre_indexed: RegisterPairPreIndexed,
        register_unscaled_immediate: RegisterUnscaledImmediate,
        register_immediate_post_indexed: RegisterImmediatePostIndexed,
        register_unprivileged: RegisterUnprivileged,
        register_immediate_pre_indexed: RegisterImmediatePreIndexed,
        register_register_offset: RegisterRegisterOffset,
        register_unsigned_immediate: RegisterUnsignedImmediate,

        /// Table C4-89 Encoding table for the Loads and Stores group
        pub const Group = packed struct {
            encoded0: u10,
            op4: u2,
            encoded12: u4,
            op3: u6,
            encoded22: u1,
            op2: u2,
            decoded25: u1 = 0b0,
            op1: bool,
            decoded27: u1 = 0b1,
            op0: u4,
        };

        /// Load register (literal)
        pub const RegisterLiteral = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                imm19: i19,
                decoded24: u2 = 0b00,
                V: bool,
                decoded27: u3 = 0b011,
                opc: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                ldr: Ldr,
                ldrsw: Ldrsw,
                prfm: Prfm,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b011,
                    opc: u2,
                };

                /// C6.2.167 LDR (literal)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b011,
                    sf: Register.IntegerSize,
                    opc1: u1 = 0b0,
                };

                /// C6.2.179 LDRSW (literal)
                pub const Ldrsw = packed struct {
                    Rt: Register.Encoded,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b011,
                    opc: u2 = 0b10,
                };

                /// C6.2.248 PRFM (literal)
                pub const Prfm = packed struct {
                    prfop: PrfOp,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b011,
                    opc: u2 = 0b11,
                };
            };

            pub const Vector = packed union {
                group: @This().Group,
                ldr: Ldr,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b011,
                    opc: VectorSize,
                };

                /// C7.2.192 LDR (literal, SIMD&FP)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    imm19: i19,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b011,
                    opc: VectorSize,
                };
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Memory Copy and Memory Set
        pub const Memory = packed struct {
            Rd: Register.Encoded,
            Rn: Register.Encoded,
            decoded10: u2 = 0b01,
            op2: u4,
            Rs: Register.Encoded,
            decoded21: u1 = 0b0,
            op1: u2,
            decoded24: u2 = 0b01,
            o0: u1,
            decoded27: u3 = 0b011,
            size: IntegerSize,
        };

        /// Load/store no-allocate pair (offset)
        pub const NoAllocatePairOffset = packed struct {
            Rt: Register.Encoded,
            Rn: Register.Encoded,
            Rt2: Register.Encoded,
            imm7: i7,
            L: L,
            decoded23: u3 = 0b000,
            V: bool,
            decoded27: u3 = 0b101,
            opc: u2,
        };

        /// Load/store register pair (post-indexed)
        pub const RegisterPairPostIndexed = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                Rt2: Register.Encoded,
                imm7: i7,
                L: L,
                decoded23: u3 = 0b001,
                V: bool,
                decoded27: u3 = 0b101,
                opc: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,
                ldpsw: Ldpsw,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b001,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc: u2,
                };

                /// C6.2.321 STP
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b001,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.164 LDP
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b001,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.165 LDPSW
                pub const Ldpsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b001,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc: u2 = 0b01,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                    ldpsw: Ldpsw,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        0b00, 0b10 => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        0b01 => switch (inst.group.L) {
                            else => .unallocated,
                            .load => .{ .ldpsw = inst.ldpsw },
                        },
                        else => .unallocated,
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b001,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.330 STP (SIMD&FP)
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b001,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.190 LDP (SIMD&FP)
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b001,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        .single, .double, .quad => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        _ => .unallocated,
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register pair (offset)
        pub const RegisterPairOffset = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                Rt2: Register.Encoded,
                imm7: i7,
                L: L,
                decoded23: u3 = 0b010,
                V: bool,
                decoded27: u3 = 0b101,
                opc: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,
                ldpsw: Ldpsw,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b010,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc: u2,
                };

                /// C6.2.321 STP
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b010,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.164 LDP
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b010,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.165 LDPSW
                pub const Ldpsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b010,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc: u2 = 0b01,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                    ldpsw: Ldpsw,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        0b00, 0b10 => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        0b01 => switch (inst.group.L) {
                            else => .unallocated,
                            .load => .{ .ldpsw = inst.ldpsw },
                        },
                        else => .unallocated,
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b010,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.330 STP (SIMD&FP)
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b010,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.190 LDP (SIMD&FP)
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b010,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        .single, .double, .quad => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        _ => .unallocated,
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register pair (pre-indexed)
        pub const RegisterPairPreIndexed = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                Rt2: Register.Encoded,
                imm7: i7,
                L: L,
                decoded23: u3 = 0b011,
                V: bool,
                decoded27: u3 = 0b101,
                opc: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,
                ldpsw: Ldpsw,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b011,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc: u2,
                };

                /// C6.2.321 STP
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b011,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.164 LDP
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b011,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u1 = 0b0,
                    sf: Register.IntegerSize,
                };

                /// C6.2.165 LDPSW
                pub const Ldpsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b011,
                    V: bool = false,
                    decoded27: u3 = 0b101,
                    opc0: u2 = 0b01,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                    ldpsw: Ldpsw,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        0b00, 0b10 => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        0b01 => switch (inst.group.L) {
                            else => .unallocated,
                            .load => .{ .ldpsw = inst.ldpsw },
                        },
                        else => .unallocated,
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                stp: Stp,
                ldp: Ldp,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L,
                    decoded23: u3 = 0b011,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.330 STP (SIMD&FP)
                pub const Stp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .store,
                    decoded23: u3 = 0b011,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                /// C7.2.190 LDP (SIMD&FP)
                pub const Ldp = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    Rt2: Register.Encoded,
                    imm7: i7,
                    L: L = .load,
                    decoded23: u3 = 0b011,
                    V: bool = true,
                    decoded27: u3 = 0b101,
                    opc: VectorSize,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stp: Stp,
                    ldp: Ldp,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.opc) {
                        .single, .double, .quad => switch (inst.group.L) {
                            .store => .{ .stp = inst.stp },
                            .load => .{ .ldp = inst.ldp },
                        },
                        _ => .unallocated,
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register (unscaled immediate)
        pub const RegisterUnscaledImmediate = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b00,
                imm9: i9,
                decoded21: u1 = 0b0,
                opc: u2,
                decoded24: u2 = 0b00,
                V: bool,
                decoded27: u3 = 0b111,
                size: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                sturb: Sturb,
                ldurb: Ldurb,
                ldursb: Ldursb,
                sturh: Sturh,
                ldurh: Ldurh,
                ldursh: Ldursh,
                stur: Stur,
                ldur: Ldur,
                ldursw: Ldursw,
                prfum: Prfum,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize,
                };

                /// C6.2.347 STURB
                pub const Sturb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.203 LDURB
                pub const Ldurb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.205 LDURSB
                pub const Ldursb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.348 STURH
                pub const Sturh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.204 LDURH
                pub const Ldurh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.206 LDURSH
                pub const Ldursh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.346 STUR
                pub const Stur = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.202 LDUR
                pub const Ldur = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.207 LDURSW
                pub const Ldursw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .word,
                };

                /// C6.2.250 PRFUM
                pub const Prfum = packed struct {
                    prfop: PrfOp,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .doubleword,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    sturb: Sturb,
                    ldurb: Ldurb,
                    ldursb: Ldursb,
                    sturh: Sturh,
                    ldurh: Ldurh,
                    ldursh: Ldursh,
                    stur: Stur,
                    ldur: Ldur,
                    ldursw: Ldursw,
                    prfum: Prfum,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size) {
                        .byte => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .sturb = inst.sturb },
                                0b01 => .{ .ldurb = inst.ldurb },
                                0b10, 0b11 => .{ .ldursb = inst.ldursb },
                            },
                            true => .unallocated,
                        },
                        .halfword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .sturh = inst.sturh },
                                0b01 => .{ .ldurh = inst.ldurh },
                                0b10, 0b11 => .{ .ldursh = inst.ldursh },
                            },
                            true => .unallocated,
                        },
                        .word => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .stur = inst.stur },
                                0b01 => .{ .ldur = inst.ldur },
                                0b10 => .{ .ldursw = inst.ldursw },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                        .doubleword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .stur = inst.stur },
                                0b01 => .{ .ldur = inst.ldur },
                                0b10 => .{ .prfum = inst.prfum },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                stur: Stur,
                ldur: Ldur,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.333 STUR (SIMD&FP)
                pub const Stur = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .store,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.194 LDUR (SIMD&FP)
                pub const Ldur = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b00,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .load,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                pub const Opc1 = packed struct {
                    encoded: u1,

                    pub fn encode(vs: Register.VectorSize) Opc1 {
                        return .{ .encoded = switch (vs) {
                            .byte, .half, .single, .double => 0b0,
                            .quad => 0b1,
                            else => unreachable,
                        } };
                    }

                    pub fn decode(enc_opc1: Opc1, enc_size: Size) Register.VectorSize {
                        return switch (enc_size.encoded) {
                            0b00 => switch (enc_opc1.encoded) {
                                0b0 => .byte,
                                0b1 => .quad,
                            },
                            0b01 => switch (enc_opc1.encoded) {
                                0b0 => .half,
                                0b1 => unreachable,
                            },
                            0b10 => switch (enc_opc1.encoded) {
                                0b0 => .single,
                                0b1 => unreachable,
                            },
                            0b11 => switch (enc_opc1.encoded) {
                                0b0 => .double,
                                0b1 => unreachable,
                            },
                        };
                    }
                };

                pub const Size = packed struct {
                    encoded: u2,

                    pub fn encode(vs: Register.VectorSize) Size {
                        return .{ .encoded = switch (vs) {
                            .byte, .quad => 0b00,
                            .half => 0b01,
                            .single => 0b10,
                            .double => 0b11,
                            else => unreachable,
                        } };
                    }
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    stur: Stur,
                    ldur: Ldur,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size.encoded) {
                        0b00 => switch (inst.group.opc0) {
                            .store => .{ .stur = inst.stur },
                            .load => .{ .ldur = inst.ldur },
                        },
                        0b01, 0b10, 0b11 => switch (inst.group.opc1.encoded) {
                            0b0 => switch (inst.group.opc0) {
                                .store => .{ .stur = inst.stur },
                                .load => .{ .ldur = inst.ldur },
                            },
                            0b1 => .unallocated,
                        },
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register (immediate post-indexed)
        pub const RegisterImmediatePostIndexed = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b01,
                imm9: i9,
                decoded21: u1 = 0b0,
                opc: u2,
                decoded24: u2 = 0b00,
                V: bool,
                decoded27: u3 = 0b111,
                size: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                strb: Strb,
                ldrb: Ldrb,
                ldrsb: Ldrsb,
                strh: Strh,
                ldrh: Ldrh,
                ldrsh: Ldrsh,
                str: Str,
                ldr: Ldr,
                ldrsw: Ldrsw,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize,
                };

                /// C6.2.324 STRB (immediate)
                pub const Strb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.170 LDRB (immediate)
                pub const Ldrb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.174 LDRSB (immediate)
                pub const Ldrsb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.326 STRH (immediate)
                pub const Strh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.172 LDRH (immediate)
                pub const Ldrh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.176 LDRSH (immediate)
                pub const Ldrsh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.322 STR (immediate)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.166 LDR (immediate)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.178 LDRSW (immediate)
                pub const Ldrsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .word,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    strb: Strb,
                    ldrb: Ldrb,
                    ldrsb: Ldrsb,
                    strh: Strh,
                    ldrh: Ldrh,
                    ldrsh: Ldrsh,
                    str: Str,
                    ldr: Ldr,
                    ldrsw: Ldrsw,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size) {
                        .byte => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strb = inst.strb },
                                0b01 => .{ .ldrb = inst.ldrb },
                                0b10, 0b11 => .{ .ldrsb = inst.ldrsb },
                            },
                            true => .unallocated,
                        },
                        .halfword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strh = inst.strh },
                                0b01 => .{ .ldrh = inst.ldrh },
                                0b10, 0b11 => .{ .ldrsh = inst.ldrsh },
                            },
                            true => .unallocated,
                        },
                        .word => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10 => .{ .ldrsw = inst.ldrsw },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                        .doubleword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10, 0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                str: Str,
                ldr: Ldr,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.331 STR (immediate, SIMD&FP)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .store,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.191 LDR (immediate, SIMD&FP)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b01,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .load,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                pub const Opc1 = packed struct {
                    encoded: u1,

                    pub fn encode(vs: Register.VectorSize) Opc1 {
                        return .{ .encoded = switch (vs) {
                            .byte, .half, .single, .double => 0b0,
                            .quad => 0b1,
                            else => unreachable,
                        } };
                    }

                    pub fn decode(enc_opc1: Opc1, enc_size: Size) Register.VectorSize {
                        return switch (enc_size.encoded) {
                            0b00 => switch (enc_opc1.encoded) {
                                0b0 => .byte,
                                0b1 => .quad,
                            },
                            0b01 => switch (enc_opc1.encoded) {
                                0b0 => .half,
                                0b1 => unreachable,
                            },
                            0b10 => switch (enc_opc1.encoded) {
                                0b0 => .single,
                                0b1 => unreachable,
                            },
                            0b11 => switch (enc_opc1.encoded) {
                                0b0 => .double,
                                0b1 => unreachable,
                            },
                        };
                    }
                };

                pub const Size = packed struct {
                    encoded: u2,

                    pub fn encode(vs: Register.VectorSize) Size {
                        return .{ .encoded = switch (vs) {
                            .byte, .quad => 0b00,
                            .half => 0b01,
                            .single => 0b10,
                            .double => 0b11,
                            else => unreachable,
                        } };
                    }
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    str: Str,
                    ldr: Ldr,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size.encoded) {
                        0b00 => switch (inst.group.opc0) {
                            .store => .{ .str = inst.str },
                            .load => .{ .ldr = inst.ldr },
                        },
                        0b01, 0b10, 0b11 => switch (inst.group.opc1.encoded) {
                            0b0 => switch (inst.group.opc0) {
                                .store => .{ .str = inst.str },
                                .load => .{ .ldr = inst.ldr },
                            },
                            0b1 => .unallocated,
                        },
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register (unprivileged)
        pub const RegisterUnprivileged = packed struct {
            Rt: Register.Encoded,
            Rn: Register.Encoded,
            decoded10: u2 = 0b10,
            imm9: i9,
            decoded21: u1 = 0b0,
            opc: u2,
            decoded24: u2 = 0b00,
            V: bool,
            decoded27: u3 = 0b111,
            size: IntegerSize,
        };

        /// Load/store register (immediate pre-indexed)
        pub const RegisterImmediatePreIndexed = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b11,
                imm9: i9,
                decoded21: u1 = 0b0,
                opc: u2,
                decoded24: u2 = 0b00,
                V: bool,
                decoded27: u3 = 0b111,
                size: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                strb: Strb,
                ldrb: Ldrb,
                ldrsb: Ldrsb,
                strh: Strh,
                ldrh: Ldrh,
                ldrsh: Ldrsh,
                str: Str,
                ldr: Ldr,
                ldrsw: Ldrsw,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize,
                };

                /// C6.2.324 STRB (immediate)
                pub const Strb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.170 LDRB (immediate)
                pub const Ldrb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.174 LDRSB (immediate)
                pub const Ldrsb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.326 STRH (immediate)
                pub const Strh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.172 LDRH (immediate)
                pub const Ldrh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.176 LDRSH (immediate)
                pub const Ldrsh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.322 STR (immediate)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.166 LDR (immediate)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.178 LDRSW (immediate)
                pub const Ldrsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .word,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    strb: Strb,
                    ldrb: Ldrb,
                    ldrsb: Ldrsb,
                    strh: Strh,
                    ldrh: Ldrh,
                    ldrsh: Ldrsh,
                    str: Str,
                    ldr: Ldr,
                    ldrsw: Ldrsw,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size) {
                        .byte => switch (inst.group.opc) {
                            0b00 => .{ .strb = inst.strb },
                            0b01 => .{ .ldrb = inst.ldrb },
                            0b10, 0b11 => .{ .ldrsb = inst.ldrsb },
                        },
                        .halfword => switch (inst.group.opc) {
                            0b00 => .{ .strh = inst.strh },
                            0b01 => .{ .ldrh = inst.ldrh },
                            0b10, 0b11 => .{ .ldrsh = inst.ldrsh },
                        },
                        .word => switch (inst.group.opc) {
                            0b00 => .{ .str = inst.str },
                            0b01 => .{ .ldr = inst.ldr },
                            0b10 => .{ .ldrsw = inst.ldrsw },
                            0b11 => .unallocated,
                        },
                        .doubleword => switch (inst.group.opc) {
                            0b00 => .{ .str = inst.str },
                            0b01 => .{ .ldr = inst.ldr },
                            0b10, 0b11 => .unallocated,
                        },
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                str: Str,
                ldr: Ldr,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.331 STR (immediate, SIMD&FP)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .store,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.191 LDR (immediate, SIMD&FP)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b11,
                    imm9: i9,
                    decoded21: u1 = 0b0,
                    opc0: L = .load,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                pub const Opc1 = packed struct {
                    encoded: u1,

                    pub fn encode(vs: Register.VectorSize) Opc1 {
                        return .{ .encoded = switch (vs) {
                            .byte, .half, .single, .double => 0b0,
                            .quad => 0b1,
                            else => unreachable,
                        } };
                    }

                    pub fn decode(enc_opc1: Opc1, enc_size: Size) Register.VectorSize {
                        return switch (enc_size.encoded) {
                            0b00 => switch (enc_opc1.encoded) {
                                0b0 => .byte,
                                0b1 => .quad,
                            },
                            0b01 => switch (enc_opc1.encoded) {
                                0b0 => .half,
                                0b1 => unreachable,
                            },
                            0b10 => switch (enc_opc1.encoded) {
                                0b0 => .single,
                                0b1 => unreachable,
                            },
                            0b11 => switch (enc_opc1.encoded) {
                                0b0 => .double,
                                0b1 => unreachable,
                            },
                        };
                    }
                };

                pub const Size = packed struct {
                    encoded: u2,

                    pub fn encode(vs: Register.VectorSize) Size {
                        return .{ .encoded = switch (vs) {
                            .byte, .quad => 0b00,
                            .half => 0b01,
                            .single => 0b10,
                            .double => 0b11,
                            else => unreachable,
                        } };
                    }
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    str: Str,
                    ldr: Ldr,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size.encoded) {
                        0b00 => switch (inst.group.opc0) {
                            .store => .{ .str = inst.str },
                            .load => .{ .ldr = inst.ldr },
                        },
                        0b01, 0b10, 0b11 => switch (inst.group.opc1.encoded) {
                            0b0 => switch (inst.group.opc0) {
                                .store => .{ .str = inst.str },
                                .load => .{ .ldr = inst.ldr },
                            },
                            0b1 => .unallocated,
                        },
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register (register offset)
        pub const RegisterRegisterOffset = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                S: bool,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opc: u2,
                decoded24: u2 = 0b00,
                V: bool,
                decoded27: u3 = 0b111,
                size: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                strb: Strb,
                ldrb: Ldrb,
                ldrsb: Ldrsb,
                strh: Strh,
                ldrh: Ldrh,
                ldrsh: Ldrsh,
                str: Str,
                ldr: Ldr,
                ldrsw: Ldrsw,
                prfm: Prfm,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize,
                };

                /// C6.2.325 STRB (register)
                pub const Strb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.171 LDRB (register)
                pub const Ldrb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.175 LDRSB (register)
                pub const Ldrsb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.327 STRH (register)
                pub const Strh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.173 LDRH (register)
                pub const Ldrh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.177 LDRSH (register)
                pub const Ldrsh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.323 STR (register)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.168 LDR (register)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.180 LDRSW (register)
                pub const Ldrsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .word,
                };

                /// C6.2.249 PRFM (register)
                pub const Prfm = packed struct {
                    prfop: PrfOp,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b00,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .doubleword,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    strb: Strb,
                    ldrb: Ldrb,
                    ldrsb: Ldrsb,
                    strh: Strh,
                    ldrh: Ldrh,
                    ldrsh: Ldrsh,
                    str: Str,
                    ldr: Ldr,
                    ldrsw: Ldrsw,
                    prfm: Prfm,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size) {
                        .byte => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strb = inst.strb },
                                0b01 => .{ .ldrb = inst.ldrb },
                                0b10, 0b11 => .{ .ldrsb = inst.ldrsb },
                            },
                            true => .unallocated,
                        },
                        .halfword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strh = inst.strh },
                                0b01 => .{ .ldrh = inst.ldrh },
                                0b10, 0b11 => .{ .ldrsh = inst.ldrsh },
                            },
                            true => .unallocated,
                        },
                        .word => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10 => .{ .ldrsw = inst.ldrsw },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                        .doubleword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10 => .{ .prfm = inst.prfm },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                str: Str,
                ldr: Ldr,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc: u2,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.332 STR (register, SIMD&FP)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc0: L = .store,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.193 LDR (register, SIMD&FP)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    decoded10: u2 = 0b10,
                    S: bool,
                    option: Option,
                    Rm: Register.Encoded,
                    decoded21: u1 = 0b1,
                    opc0: L = .load,
                    opc1: Opc1,
                    decoded24: u2 = 0b00,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                pub const Opc1 = packed struct {
                    encoded: u1,

                    pub fn encode(vs: Register.VectorSize) Opc1 {
                        return .{ .encoded = switch (vs) {
                            .byte, .half, .single, .double => 0b0,
                            .quad => 0b1,
                            else => unreachable,
                        } };
                    }

                    pub fn decode(enc_opc1: Opc1, enc_size: Size) Register.VectorSize {
                        return switch (enc_size.encoded) {
                            0b00 => switch (enc_opc1.encoded) {
                                0b0 => .byte,
                                0b1 => .quad,
                            },
                            0b01 => switch (enc_opc1.encoded) {
                                0b0 => .half,
                                0b1 => unreachable,
                            },
                            0b10 => switch (enc_opc1.encoded) {
                                0b0 => .single,
                                0b1 => unreachable,
                            },
                            0b11 => switch (enc_opc1.encoded) {
                                0b0 => .double,
                                0b1 => unreachable,
                            },
                        };
                    }
                };

                pub const Size = packed struct {
                    encoded: u2,

                    pub fn encode(vs: Register.VectorSize) Size {
                        return .{ .encoded = switch (vs) {
                            .byte, .quad => 0b00,
                            .half => 0b01,
                            .single => 0b10,
                            .double => 0b11,
                            else => unreachable,
                        } };
                    }
                };
            };

            pub const Option = enum(u3) {
                uxtw = 0b010,
                lsl = 0b011,
                sxtw = 0b110,
                sxtx = 0b111,
                _,

                pub fn sf(option: Option) Register.IntegerSize {
                    return switch (option) {
                        .uxtw, .sxtw => .word,
                        .lsl, .sxtx => .doubleword,
                        _ => unreachable,
                    };
                }
            };

            pub const Extend = union(Option) {
                uxtw: Amount,
                lsl: Amount,
                sxtw: Amount,
                sxtx: Amount,

                pub const Amount = u3;
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        /// Load/store register (unsigned immediate)
        pub const RegisterUnsignedImmediate = packed union {
            group: @This().Group,
            integer: Integer,
            vector: Vector,

            pub const Group = packed struct {
                Rt: Register.Encoded,
                Rn: Register.Encoded,
                imm12: u12,
                opc: u2,
                decoded24: u2 = 0b01,
                V: bool,
                decoded27: u3 = 0b111,
                size: u2,
            };

            pub const Integer = packed union {
                group: @This().Group,
                strb: Strb,
                ldrb: Ldrb,
                ldrsb: Ldrsb,
                strh: Strh,
                ldrh: Ldrh,
                ldrsh: Ldrsh,
                str: Str,
                ldr: Ldr,
                ldrsw: Ldrsw,
                prfm: Prfm,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize,
                };

                /// C6.2.324 STRB (immediate)
                pub const Strb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.170 LDRB (immediate)
                pub const Ldrb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.174 LDRSB (immediate)
                pub const Ldrsb = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .byte,
                };

                /// C6.2.326 STRH (immediate)
                pub const Strh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.172 LDRH (immediate)
                pub const Ldrh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.176 LDRSH (immediate)
                pub const Ldrsh = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc0: u1,
                    opc1: u1 = 0b1,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .halfword,
                };

                /// C6.2.322 STR (immediate)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b00,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.166 LDR (immediate)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b01,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    sf: Register.IntegerSize,
                    size1: u1 = 0b1,
                };

                /// C6.2.178 LDRSW (immediate)
                pub const Ldrsw = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .word,
                };

                /// C6.2.247 PRFM (immediate)
                pub const Prfm = packed struct {
                    prfop: PrfOp,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc: u2 = 0b10,
                    decoded24: u2 = 0b01,
                    V: bool = false,
                    decoded27: u3 = 0b111,
                    size: IntegerSize = .doubleword,
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    strb: Strb,
                    ldrb: Ldrb,
                    ldrsb: Ldrsb,
                    strh: Strh,
                    ldrh: Ldrh,
                    ldrsh: Ldrsh,
                    str: Str,
                    ldr: Ldr,
                    ldrsw: Ldrsw,
                    prfm: Prfm,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size) {
                        .byte => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strb = inst.strb },
                                0b01 => .{ .ldrb = inst.ldrb },
                                0b10, 0b11 => .{ .ldrsb = inst.ldrsb },
                            },
                            true => .unallocated,
                        },
                        .halfword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .strh = inst.strh },
                                0b01 => .{ .ldrh = inst.ldrh },
                                0b10, 0b11 => .{ .ldrsh = inst.ldrsh },
                            },
                            true => .unallocated,
                        },
                        .word => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10 => .{ .ldrsw = inst.ldrsw },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                        .doubleword => switch (inst.group.V) {
                            false => switch (inst.group.opc) {
                                0b00 => .{ .str = inst.str },
                                0b01 => .{ .ldr = inst.ldr },
                                0b10 => .{ .prfm = inst.prfm },
                                0b11 => .unallocated,
                            },
                            true => .unallocated,
                        },
                    };
                }
            };

            pub const Vector = packed union {
                group: @This().Group,
                str: Str,
                ldr: Ldr,

                pub const Group = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc0: L,
                    opc1: Opc1,
                    decoded24: u2 = 0b01,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.331 STR (immediate, SIMD&FP)
                pub const Str = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc0: L = .store,
                    opc1: Opc1,
                    decoded24: u2 = 0b01,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                /// C7.2.191 LDR (immediate, SIMD&FP)
                pub const Ldr = packed struct {
                    Rt: Register.Encoded,
                    Rn: Register.Encoded,
                    imm12: u12,
                    opc0: L = .load,
                    opc1: Opc1,
                    decoded24: u2 = 0b01,
                    V: bool = true,
                    decoded27: u3 = 0b111,
                    size: Size,
                };

                pub const Opc1 = packed struct {
                    encoded: u1,

                    pub fn encode(vs: Register.VectorSize) Opc1 {
                        return .{ .encoded = switch (vs) {
                            .byte, .half, .single, .double => 0b0,
                            .quad => 0b1,
                            else => unreachable,
                        } };
                    }

                    pub fn decode(enc_opc1: Opc1, enc_size: Size) Register.VectorSize {
                        return switch (enc_size.encoded) {
                            0b00 => switch (enc_opc1.encoded) {
                                0b0 => .byte,
                                0b1 => .quad,
                            },
                            0b01 => switch (enc_opc1.encoded) {
                                0b0 => .half,
                                0b1 => unreachable,
                            },
                            0b10 => switch (enc_opc1.encoded) {
                                0b0 => .single,
                                0b1 => unreachable,
                            },
                            0b11 => switch (enc_opc1.encoded) {
                                0b0 => .double,
                                0b1 => unreachable,
                            },
                        };
                    }
                };

                pub const Size = packed struct {
                    encoded: u2,

                    pub fn encode(vs: Register.VectorSize) Size {
                        return .{ .encoded = switch (vs) {
                            .byte, .quad => 0b00,
                            .half => 0b01,
                            .single => 0b10,
                            .double => 0b11,
                            else => unreachable,
                        } };
                    }
                };

                pub const Decoded = union(enum) {
                    unallocated,
                    str: Str,
                    ldr: Ldr,
                };
                pub fn decode(inst: @This()) @This().Decoded {
                    return switch (inst.group.size.encoded) {
                        0b00 => switch (inst.group.opc0) {
                            .store => .{ .str = inst.str },
                            .load => .{ .ldr = inst.ldr },
                        },
                        0b01, 0b10, 0b11 => switch (inst.group.opc1.encoded) {
                            0b0 => switch (inst.group.opc0) {
                                .store => .{ .str = inst.str },
                                .load => .{ .ldr = inst.ldr },
                            },
                            0b1 => .unallocated,
                        },
                    };
                }
            };

            pub const Decoded = union(enum) {
                integer: Integer,
                vector: Vector,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.V) {
                    false => .{ .integer = inst.integer },
                    true => .{ .vector = inst.vector },
                };
            }
        };

        pub const L = enum(u1) {
            store = 0b0,
            load = 0b1,
        };

        pub const IntegerSize = enum(u2) {
            byte = 0b00,
            halfword = 0b01,
            word = 0b10,
            doubleword = 0b11,
        };

        pub const VectorSize = enum(u2) {
            single = 0b00,
            double = 0b01,
            quad = 0b10,
            _,

            pub fn decode(vs: VectorSize) Register.VectorSize {
                return switch (vs) {
                    .single => .single,
                    .double => .double,
                    .quad => .quad,
                    _ => unreachable,
                };
            }

            pub fn encode(vs: Register.VectorSize) VectorSize {
                return switch (vs) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .quad => .quad,
                };
            }
        };

        pub const PrfOp = packed struct {
            policy: Policy,
            target: Target,
            type: Type,

            pub const Policy = enum(u1) {
                keep = 0b0,
                strm = 0b1,
            };

            pub const Target = enum(u2) {
                l1 = 0b00,
                l2 = 0b01,
                l3 = 0b10,
                _,
            };

            pub const Type = enum(u2) {
                pld = 0b00,
                pli = 0b01,
                pst = 0b10,
                _,
            };

            pub const pldl1keep: PrfOp = .{ .type = .pld, .target = .l1, .policy = .keep };
            pub const pldl1strm: PrfOp = .{ .type = .pld, .target = .l1, .policy = .strm };
            pub const pldl2keep: PrfOp = .{ .type = .pld, .target = .l2, .policy = .keep };
            pub const pldl2strm: PrfOp = .{ .type = .pld, .target = .l2, .policy = .strm };
            pub const pldl3keep: PrfOp = .{ .type = .pld, .target = .l3, .policy = .keep };
            pub const pldl3strm: PrfOp = .{ .type = .pld, .target = .l3, .policy = .strm };
            pub const plil1keep: PrfOp = .{ .type = .pli, .target = .l1, .policy = .keep };
            pub const plil1strm: PrfOp = .{ .type = .pli, .target = .l1, .policy = .strm };
            pub const plil2keep: PrfOp = .{ .type = .pli, .target = .l2, .policy = .keep };
            pub const plil2strm: PrfOp = .{ .type = .pli, .target = .l2, .policy = .strm };
            pub const plil3keep: PrfOp = .{ .type = .pli, .target = .l3, .policy = .keep };
            pub const plil3strm: PrfOp = .{ .type = .pli, .target = .l3, .policy = .strm };
            pub const pstl1keep: PrfOp = .{ .type = .pst, .target = .l1, .policy = .keep };
            pub const pstl1strm: PrfOp = .{ .type = .pst, .target = .l1, .policy = .strm };
            pub const pstl2keep: PrfOp = .{ .type = .pst, .target = .l2, .policy = .keep };
            pub const pstl2strm: PrfOp = .{ .type = .pst, .target = .l2, .policy = .strm };
            pub const pstl3keep: PrfOp = .{ .type = .pst, .target = .l3, .policy = .keep };
            pub const pstl3strm: PrfOp = .{ .type = .pst, .target = .l3, .policy = .strm_ };
        };

        pub const Decoded = union(enum) {
            unallocated,
            register_literal: RegisterLiteral,
            memory: Memory,
            no_allocate_pair_offset: NoAllocatePairOffset,
            register_pair_post_indexed: RegisterPairPostIndexed,
            register_pair_offset: RegisterPairOffset,
            register_pair_pre_indexed: RegisterPairPreIndexed,
            register_unscaled_immediate: RegisterUnscaledImmediate,
            register_immediate_post_indexed: RegisterImmediatePostIndexed,
            register_unprivileged: RegisterUnprivileged,
            register_immediate_pre_indexed: RegisterImmediatePreIndexed,
            register_register_offset: RegisterRegisterOffset,
            register_unsigned_immediate: RegisterUnsignedImmediate,
        };
        pub fn decode(inst: @This()) @This().Decoded {
            return switch (inst.group.op0) {
                else => .unallocated,
                0b0010, 0b0110, 0b1010, 0b1110 => switch (inst.group.op2) {
                    0b00 => .{ .no_allocate_pair_offset = inst.no_allocate_pair_offset },
                    0b01 => .{ .register_pair_post_indexed = inst.register_pair_post_indexed },
                    0b10 => .{ .register_pair_offset = inst.register_pair_offset },
                    0b11 => .{ .register_pair_pre_indexed = inst.register_pair_pre_indexed },
                },
                0b0011, 0b0111, 0b1011, 0b1111 => switch (inst.group.op2) {
                    0b00...0b01 => switch (inst.group.op3) {
                        0b000000...0b011111 => switch (inst.group.op4) {
                            0b00 => .{ .register_unscaled_immediate = inst.register_unscaled_immediate },
                            0b01 => .{ .register_immediate_post_indexed = inst.register_immediate_post_indexed },
                            0b10 => .{ .register_unprivileged = inst.register_unprivileged },
                            0b11 => .{ .register_immediate_pre_indexed = inst.register_immediate_pre_indexed },
                        },
                        0b100000...0b111111 => switch (inst.group.op4) {
                            0b00 => .unallocated,
                            0b10 => .{ .register_register_offset = inst.register_register_offset },
                            0b01, 0b11 => .unallocated,
                        },
                    },
                    0b10...0b11 => .{ .register_unsigned_immediate = inst.register_unsigned_immediate },
                },
            };
        }
    };

    /// C4.1.89 Data Processing -- Register
    pub const DataProcessingRegister = packed union {
        group: @This().Group,
        data_processing_two_source: DataProcessingTwoSource,
        data_processing_one_source: DataProcessingOneSource,
        logical_shifted_register: LogicalShiftedRegister,
        add_subtract_shifted_register: AddSubtractShiftedRegister,
        add_subtract_extended_register: AddSubtractExtendedRegister,
        add_subtract_with_carry: AddSubtractWithCarry,
        rotate_right_into_flags: RotateRightIntoFlags,
        evaluate_into_flags: EvaluateIntoFlags,
        conditional_compare_register: ConditionalCompareRegister,
        conditional_compare_immediate: ConditionalCompareImmediate,
        conditional_select: ConditionalSelect,
        data_processing_three_source: DataProcessingThreeSource,

        /// Table C4-90 Encoding table for the Data Processing -- Register group
        pub const Group = packed struct {
            encoded0: u10,
            op3: u6,
            encoded16: u5,
            op2: u4,
            decoded25: u3 = 0b101,
            op1: u1,
            encoded29: u1,
            op0: u1,
            encoded31: u1,
        };

        /// Data-processing (2 source)
        pub const DataProcessingTwoSource = packed union {
            group: @This().Group,
            udiv: Udiv,
            sdiv: Sdiv,
            lslv: Lslv,
            lsrv: Lsrv,
            asrv: Asrv,
            rorv: Rorv,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                opcode: u6,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.388 UDIV
            pub const Udiv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                o1: DivOp = .udiv,
                decoded11: u5 = 0b00001,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.270 SDIV
            pub const Sdiv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                o1: DivOp = .sdiv,
                decoded11: u5 = 0b00001,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.214 LSLV
            pub const Lslv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: ShiftOp = .lslv,
                decoded12: u4 = 0b0010,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.217 LSRV
            pub const Lsrv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: ShiftOp = .lsrv,
                decoded12: u4 = 0b0010,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.18 ASRV
            pub const Asrv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: ShiftOp = .asrv,
                decoded12: u4 = 0b0010,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.263 RORV
            pub const Rorv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: ShiftOp = .rorv,
                decoded12: u4 = 0b0010,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            pub const DivOp = enum(u1) {
                udiv = 0b0,
                sdiv = 0b1,
            };

            pub const ShiftOp = enum(u2) {
                lslv = 0b00,
                lsrv = 0b01,
                asrv = 0b10,
                rorv = 0b11,
            };

            pub const Decoded = union(enum) {
                unallocated,
                udiv: Udiv,
                sdiv: Sdiv,
                lslv: Lslv,
                lsrv: Lsrv,
                asrv: Asrv,
                rorv: Rorv,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.S) {
                    false => switch (inst.group.opcode) {
                        else => .unallocated,
                        0b000010 => .{ .udiv = inst.udiv },
                        0b000011 => .{ .sdiv = inst.sdiv },
                        0b001000 => .{ .lslv = inst.lslv },
                        0b001001 => .{ .lsrv = inst.lsrv },
                        0b001010 => .{ .asrv = inst.asrv },
                        0b001011 => .{ .rorv = inst.rorv },
                    },
                    true => .unallocated,
                };
            }
        };

        /// Data-processing (1 source)
        pub const DataProcessingOneSource = packed union {
            group: @This().Group,
            rbit: Rbit,
            rev16: Rev16,
            rev32: Rev32,
            rev: Rev,
            clz: Clz,
            cls: Cls,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                opcode: u6,
                opcode2: u5,
                decoded21: u8 = 0b11010110,
                S: bool,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.253 RBIT
            pub const Rbit = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b00,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.257 REV16
            pub const Rev16 = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                opc: u2 = 0b01,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.258 REV32
            pub const Rev32 = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                opc: u2 = 0b10,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.256 REV
            pub const Rev = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                opc0: Register.IntegerSize,
                opc1: u1 = 0b1,
                decoded12: u4 = 0b0000,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.58 CLZ
            pub const Clz = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op: u1 = 0b0,
                decoded11: u5 = 0b00010,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.57 CLS
            pub const Cls = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op: u1 = 0b1,
                decoded11: u5 = 0b00010,
                decoded16: u5 = 0b00000,
                decoded21: u8 = 0b11010110,
                S: bool = false,
                decoded30: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                rbit: Rbit,
                rev16: Rev16,
                rev32: Rev32,
                rev: Rev,
                clz: Clz,
                cls: Cls,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.S) {
                    true => .unallocated,
                    false => switch (inst.group.opcode2) {
                        else => .unallocated,
                        0b00000 => switch (inst.group.opcode) {
                            else => .unallocated,
                            0b000000 => .{ .rbit = inst.rbit },
                            0b000001 => .{ .rev16 = inst.rev16 },
                            0b000010 => switch (inst.group.sf) {
                                .word => .{ .rev = inst.rev },
                                .doubleword => .{ .rev32 = inst.rev32 },
                            },
                            0b000011 => switch (inst.group.sf) {
                                .word => .unallocated,
                                .doubleword => .{ .rev = inst.rev },
                            },
                            0b000100 => .{ .clz = inst.clz },
                            0b000101 => .{ .cls = inst.cls },
                        },
                    },
                };
            }
        };

        /// Logical (shifted register)
        pub const LogicalShiftedRegister = packed union {
            group: @This().Group,
            @"and": And,
            bic: Bic,
            orr: Orr,
            orn: Orn,
            eor: Eor,
            eon: Eon,
            ands: Ands,
            bics: Bics,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc,
                sf: Register.IntegerSize,
            };

            /// C6.2.13 AND (shifted register)
            pub const And = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = false,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .@"and",
                sf: Register.IntegerSize,
            };

            /// C6.2.32 BIC (shifted register)
            pub const Bic = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = true,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .@"and",
                sf: Register.IntegerSize,
            };

            /// C6.2.241 ORR (shifted register)
            pub const Orr = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = false,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .orr,
                sf: Register.IntegerSize,
            };

            /// C6.2.239 ORN (shifted register)
            pub const Orn = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = true,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .orr,
                sf: Register.IntegerSize,
            };

            /// C6.2.120 EOR (shifted register)
            pub const Eor = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = false,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .eor,
                sf: Register.IntegerSize,
            };

            /// C6.2.118 EON (shifted register)
            pub const Eon = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = true,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .eor,
                sf: Register.IntegerSize,
            };

            /// C6.2.15 ANDS (shifted register)
            pub const Ands = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = false,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .ands,
                sf: Register.IntegerSize,
            };

            /// C6.2.33 BICS (shifted register)
            pub const Bics = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                N: bool = true,
                shift: Shift.Op,
                decoded24: u5 = 0b01010,
                opc: LogicalOpc = .ands,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                @"and": And,
                bic: Bic,
                orr: Orr,
                orn: Orn,
                eor: Eor,
                eon: Eon,
                ands: Ands,
                bics: Bics,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return if (inst.group.sf == .word and @as(u1, @truncate(inst.group.imm6 >> 5)) == 0b1)
                    .unallocated
                else switch (inst.group.opc) {
                    .@"and" => switch (inst.group.N) {
                        false => .{ .@"and" = inst.@"and" },
                        true => .{ .bic = inst.bic },
                    },
                    .orr => switch (inst.group.N) {
                        false => .{ .orr = inst.orr },
                        true => .{ .orn = inst.orn },
                    },
                    .eor => switch (inst.group.N) {
                        false => .{ .eor = inst.eor },
                        true => .{ .eon = inst.eon },
                    },
                    .ands => switch (inst.group.N) {
                        false => .{ .ands = inst.ands },
                        true => .{ .bics = inst.bics },
                    },
                };
            }
        };

        /// Add/subtract (shifted register)
        pub const AddSubtractShiftedRegister = packed union {
            group: @This().Group,
            add: Add,
            adds: Adds,
            sub: Sub,
            subs: Subs,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                decoded21: u1 = 0b0,
                shift: Shift.Op,
                decoded24: u5 = 0b01011,
                S: bool,
                op: AddSubtractOp,
                sf: Register.IntegerSize,
            };

            /// C6.2.5 ADD (shifted register)
            pub const Add = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                decoded21: u1 = 0b0,
                shift: Shift.Op,
                decoded24: u5 = 0b01011,
                S: bool = false,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.9 ADDS (shifted register)
            pub const Adds = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                decoded21: u1 = 0b0,
                shift: Shift.Op,
                decoded24: u5 = 0b01011,
                S: bool = true,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.5 SUB (shifted register)
            pub const Sub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                decoded21: u1 = 0b0,
                shift: Shift.Op,
                decoded24: u5 = 0b01011,
                S: bool = false,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            /// C6.2.9 SUBS (shifted register)
            pub const Subs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm6: Shift.Amount,
                Rm: Register.Encoded,
                decoded21: u1 = 0b0,
                shift: Shift.Op,
                decoded24: u5 = 0b01011,
                S: bool = true,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                add: Add,
                adds: Adds,
                sub: Sub,
                subs: Subs,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.shift) {
                    .ror => .unallocated,
                    .lsl, .lsr, .asr => if (inst.group.sf == .word and @as(u1, @truncate(inst.group.imm6 >> 5)) == 0b1)
                        .unallocated
                    else switch (inst.group.op) {
                        .add => switch (inst.group.S) {
                            false => .{ .add = inst.add },
                            true => .{ .adds = inst.adds },
                        },
                        .sub => switch (inst.group.S) {
                            false => .{ .sub = inst.sub },
                            true => .{ .subs = inst.subs },
                        },
                    },
                };
            }
        };

        /// Add/subtract (extended register)
        pub const AddSubtractExtendedRegister = packed union {
            group: @This().Group,
            add: Add,
            adds: Adds,
            sub: Sub,
            subs: Subs,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm3: Extend.Amount,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opt: u2,
                decoded24: u5 = 0b01011,
                S: bool,
                op: AddSubtractOp,
                sf: Register.IntegerSize,
            };

            /// C6.2.3 ADD (extended register)
            pub const Add = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm3: Extend.Amount,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opt: u2 = 0b00,
                decoded24: u5 = 0b01011,
                S: bool = false,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.7 ADDS (extended register)
            pub const Adds = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm3: Extend.Amount,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opt: u2 = 0b00,
                decoded24: u5 = 0b01011,
                S: bool = true,
                op: AddSubtractOp = .add,
                sf: Register.IntegerSize,
            };

            /// C6.2.356 SUB (extended register)
            pub const Sub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm3: Extend.Amount,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opt: u2 = 0b00,
                decoded24: u5 = 0b01011,
                S: bool = false,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            /// C6.2.362 SUBS (extended register)
            pub const Subs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                imm3: Extend.Amount,
                option: Option,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                opt: u2 = 0b00,
                decoded24: u5 = 0b01011,
                S: bool = true,
                op: AddSubtractOp = .sub,
                sf: Register.IntegerSize,
            };

            pub const Option = enum(u3) {
                uxtb = 0b000,
                uxth = 0b001,
                uxtw = 0b010,
                uxtx = 0b011,
                sxtb = 0b100,
                sxth = 0b101,
                sxtw = 0b110,
                sxtx = 0b111,

                pub fn sf(option: Option) Register.IntegerSize {
                    return switch (option) {
                        .uxtb, .uxth, .uxtw, .sxtb, .sxth, .sxtw => .word,
                        .uxtx, .sxtx => .doubleword,
                    };
                }
            };

            pub const Extend = union(Option) {
                uxtb: Amount,
                uxth: Amount,
                uxtw: Amount,
                uxtx: Amount,
                sxtb: Amount,
                sxth: Amount,
                sxtw: Amount,
                sxtx: Amount,

                pub const Amount = u3;
            };

            pub const Decoded = union(enum) {
                unallocated,
                add: Add,
                adds: Adds,
                sub: Sub,
                subs: Subs,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.imm3) {
                    0b101 => .unallocated,
                    0b110...0b111 => .unallocated,
                    0b000...0b100 => switch (inst.group.opt) {
                        0b01 => .unallocated,
                        0b10...0b11 => .unallocated,
                        0b00 => switch (inst.group.op) {
                            .add => switch (inst.group.S) {
                                false => .{ .add = inst.add },
                                true => .{ .adds = inst.adds },
                            },
                            .sub => switch (inst.group.S) {
                                false => .{ .sub = inst.sub },
                                true => .{ .subs = inst.subs },
                            },
                        },
                    },
                };
            }
        };

        /// Add/subtract (with carry)
        pub const AddSubtractWithCarry = packed union {
            group: @This().Group,
            adc: Adc,
            adcs: Adcs,
            sbc: Sbc,
            sbcs: Sbcs,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010000,
                S: bool,
                op: Op,
                sf: Register.IntegerSize,
            };

            /// C6.2.1 ADC
            pub const Adc = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010000,
                S: bool = false,
                op: Op = .adc,
                sf: Register.IntegerSize,
            };

            /// C6.2.2 ADCS
            pub const Adcs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010000,
                S: bool = true,
                op: Op = .adc,
                sf: Register.IntegerSize,
            };

            /// C6.2.265 SBC
            pub const Sbc = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010000,
                S: bool = false,
                op: Op = .sbc,
                sf: Register.IntegerSize,
            };

            /// C6.2.266 SBCS
            pub const Sbcs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010000,
                S: bool = true,
                op: Op = .sbc,
                sf: Register.IntegerSize,
            };

            pub const Op = enum(u1) {
                adc = 0b0,
                sbc = 0b1,
            };

            pub const Decoded = union(enum) {
                adc: Adc,
                adcs: Adcs,
                sbc: Sbc,
                sbcs: Sbcs,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.op) {
                    .adc => switch (inst.group.S) {
                        false => .{ .adc = inst.adc },
                        true => .{ .adcs = inst.adcs },
                    },
                    .sbc => switch (inst.group.S) {
                        false => .{ .sbc = inst.sbc },
                        true => .{ .sbcs = inst.sbcs },
                    },
                };
            }
        };

        /// Rotate right into flags
        pub const RotateRightIntoFlags = packed union {
            group: @This().Group,

            pub const Group = packed struct {
                mask: Nzcv,
                o2: u1,
                Rn: Register.Encoded,
                decoded10: u5 = 0b0001,
                imm6: u6,
                decoded21: u8 = 0b11010000,
                S: bool,
                op: u1,
                sf: Register.IntegerSize,
            };
        };

        /// Evaluate into flags
        pub const EvaluateIntoFlags = packed union {
            group: @This().Group,

            pub const Group = packed struct {
                mask: Nzcv,
                o3: u1,
                Rn: Register.Encoded,
                decoded10: u4 = 0b0010,
                sz: enum(u1) {
                    byte = 0b0,
                    word = 0b1,
                },
                opcode2: u6,
                decoded21: u8 = 0b11010000,
                S: bool,
                op: u1,
                sf: Register.IntegerSize,
            };
        };

        /// Conditional compare (register)
        pub const ConditionalCompareRegister = packed union {
            group: @This().Group,
            ccmn: Ccmn,
            ccmp: Ccmp,

            pub const Group = packed struct {
                nzcv: Nzcv,
                o3: u1,
                Rn: Register.Encoded,
                o2: u1,
                decoded11: u1 = 0b0,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010010,
                S: bool,
                op: Op,
                sf: Register.IntegerSize,
            };

            /// C6.2.49 CCMN (register)
            pub const Ccmn = packed struct {
                nzcv: Nzcv,
                o3: u1 = 0b0,
                Rn: Register.Encoded,
                o2: u1 = 0b0,
                decoded11: u1 = 0b0,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010010,
                S: bool = true,
                op: Op = .ccmn,
                sf: Register.IntegerSize,
            };

            /// C6.2.51 CCMP (register)
            pub const Ccmp = packed struct {
                nzcv: Nzcv,
                o3: u1 = 0b0,
                Rn: Register.Encoded,
                o2: u1 = 0b0,
                decoded11: u1 = 0b0,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010010,
                S: bool = true,
                op: Op = .ccmp,
                sf: Register.IntegerSize,
            };

            pub const Op = enum(u1) {
                ccmn = 0b0,
                ccmp = 0b1,
            };
        };

        /// Conditional compare (immediate)
        pub const ConditionalCompareImmediate = packed union {
            group: @This().Group,
            ccmn: Ccmn,
            ccmp: Ccmp,

            pub const Group = packed struct {
                nzcv: Nzcv,
                o3: u1,
                Rn: Register.Encoded,
                o2: u1,
                decoded11: u1 = 0b1,
                cond: ConditionCode,
                imm5: u5,
                decoded21: u8 = 0b11010010,
                S: bool,
                op: Op,
                sf: Register.IntegerSize,
            };

            /// C6.2.48 CCMN (immediate)
            pub const Ccmn = packed struct {
                nzcv: Nzcv,
                o3: u1 = 0b0,
                Rn: Register.Encoded,
                o2: u1 = 0b0,
                decoded11: u1 = 0b1,
                cond: ConditionCode,
                imm5: u5,
                decoded21: u8 = 0b11010010,
                S: bool = true,
                op: Op = .ccmn,
                sf: Register.IntegerSize,
            };

            /// C6.2.50 CCMP (immediate)
            pub const Ccmp = packed struct {
                nzcv: Nzcv,
                o3: u1 = 0b0,
                Rn: Register.Encoded,
                o2: u1 = 0b0,
                decoded11: u1 = 0b1,
                cond: ConditionCode,
                imm5: u5,
                decoded21: u8 = 0b11010010,
                S: bool = true,
                op: Op = .ccmp,
                sf: Register.IntegerSize,
            };

            pub const Op = enum(u1) {
                ccmn = 0b0,
                ccmp = 0b1,
            };
        };

        /// Conditional select
        pub const ConditionalSelect = packed union {
            group: @This().Group,
            csel: Csel,
            csinc: Csinc,
            csinv: Csinv,
            csneg: Csneg,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: u2,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010100,
                S: bool,
                op: u1,
                sf: Register.IntegerSize,
            };

            /// C6.2.103 CSEL
            pub const Csel = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: u2 = 0b00,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010100,
                S: bool = false,
                op: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.106 CSINC
            pub const Csinc = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: u2 = 0b01,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010100,
                S: bool = false,
                op: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C6.2.107 CSINV
            pub const Csinv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: u2 = 0b00,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010100,
                S: bool = false,
                op: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            /// C6.2.108 CSNEG
            pub const Csneg = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                op2: u2 = 0b01,
                cond: ConditionCode,
                Rm: Register.Encoded,
                decoded21: u8 = 0b11010100,
                S: bool = false,
                op: u1 = 0b1,
                sf: Register.IntegerSize,
            };

            pub const Decoded = union(enum) {
                unallocated,
                csel: Csel,
                csinc: Csinc,
                csinv: Csinv,
                csneg: Csneg,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.S) {
                    true => .unallocated,
                    false => switch (inst.group.op) {
                        0b0 => switch (inst.group.op2) {
                            0b10...0b11 => .unallocated,
                            0b00 => .{ .csel = inst.csel },
                            0b01 => .{ .csinc = inst.csinc },
                        },
                        0b1 => switch (inst.group.op2) {
                            0b10...0b11 => .unallocated,
                            0b00 => .{ .csinv = inst.csinv },
                            0b01 => .{ .csneg = inst.csneg },
                        },
                    },
                };
            }
        };

        /// Data-processing (3 source)
        pub const DataProcessingThreeSource = packed union {
            group: @This().Group,
            madd: Madd,
            msub: Msub,
            smaddl: Smaddl,
            smsubl: Smsubl,
            smulh: Smulh,
            umaddl: Umaddl,
            umsubl: Umsubl,
            umulh: Umulh,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp,
                Rm: Register.Encoded,
                op31: u3,
                decoded24: u5 = 0b11011,
                op54: u2,
                sf: Register.IntegerSize,
            };

            /// C6.2.218 MADD
            pub const Madd = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                op31: u3 = 0b000,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize,
            };

            /// C6.2.231 MSUB
            pub const Msub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .sub,
                Rm: Register.Encoded,
                op31: u3 = 0b000,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize,
            };

            /// C6.2.282 SMADDL
            pub const Smaddl = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                op21: u2 = 0b01,
                U: bool = false,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.287 SMSUBL
            pub const Smsubl = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .sub,
                Rm: Register.Encoded,
                op21: u2 = 0b01,
                U: bool = false,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.288 SMULH
            pub const Smulh = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded = @enumFromInt(0b11111),
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                op21: u2 = 0b10,
                U: bool = false,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.389 UMADDL
            pub const Umaddl = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                op21: u2 = 0b01,
                U: bool = true,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.391 UMSUBL
            pub const Umsubl = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .sub,
                Rm: Register.Encoded,
                op21: u2 = 0b01,
                U: bool = true,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            /// C6.2.392 UMULH
            pub const Umulh = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded = @enumFromInt(0b11111),
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                op21: u2 = 0b10,
                U: bool = true,
                decoded24: u5 = 0b11011,
                op54: u2 = 0b00,
                sf: Register.IntegerSize = .doubleword,
            };

            pub const Decoded = union(enum) {
                unallocated,
                madd: Madd,
                msub: Msub,
                smaddl: Smaddl,
                smsubl: Smsubl,
                smulh: Smulh,
                umaddl: Umaddl,
                umsubl: Umsubl,
                umulh: Umulh,
            };
            pub fn decode(inst: @This()) @This().Decoded {
                return switch (inst.group.op54) {
                    0b01, 0b10...0b11 => .unallocated,
                    0b00 => switch (inst.group.op31) {
                        0b011, 0b100, 0b111 => .unallocated,
                        0b000 => switch (inst.group.o0) {
                            .add => .{ .madd = inst.madd },
                            .sub => .{ .msub = inst.msub },
                        },
                        0b001 => switch (inst.group.sf) {
                            .word => .unallocated,
                            .doubleword => switch (inst.group.o0) {
                                .add => .{ .smaddl = inst.smaddl },
                                .sub => .{ .smsubl = inst.smsubl },
                            },
                        },
                        0b010 => switch (inst.group.sf) {
                            .word => .unallocated,
                            .doubleword => switch (inst.group.o0) {
                                .add => .{ .smulh = inst.smulh },
                                .sub => .unallocated,
                            },
                        },
                        0b101 => switch (inst.group.sf) {
                            .word => .unallocated,
                            .doubleword => switch (inst.group.o0) {
                                .add => .{ .umaddl = inst.umaddl },
                                .sub => .{ .umsubl = inst.umsubl },
                            },
                        },
                        0b110 => switch (inst.group.sf) {
                            .word => .unallocated,
                            .doubleword => switch (inst.group.o0) {
                                .add => .{ .umulh = inst.umulh },
                                .sub => .unallocated,
                            },
                        },
                    },
                };
            }
        };

        pub const Shift = union(enum(u2)) {
            lsl: Amount = 0b00,
            lsr: Amount = 0b01,
            asr: Amount = 0b10,
            ror: Amount = 0b11,

            pub const Op = @typeInfo(Shift).@"union".tag_type.?;
            pub const Amount = u6;
            pub const none: Shift = .{ .lsl = 0 };
        };

        pub const Nzcv = packed struct { v: bool, c: bool, z: bool, n: bool };

        pub const Decoded = union(enum) {
            unallocated,
            data_processing_two_source: DataProcessingTwoSource,
            data_processing_one_source: DataProcessingOneSource,
            logical_shifted_register: LogicalShiftedRegister,
            add_subtract_shifted_register: AddSubtractShiftedRegister,
            add_subtract_extended_register: AddSubtractExtendedRegister,
            add_subtract_with_carry: AddSubtractWithCarry,
            rotate_right_into_flags: RotateRightIntoFlags,
            evaluate_into_flags: EvaluateIntoFlags,
            conditional_compare_register: ConditionalCompareRegister,
            conditional_compare_immediate: ConditionalCompareImmediate,
            conditional_select: ConditionalSelect,
            data_processing_three_source: DataProcessingThreeSource,
        };
        pub fn decode(inst: @This()) @This().Decoded {
            return switch (inst.group.op1) {
                0b0 => switch (@as(u1, @truncate(inst.group.op2 >> 3))) {
                    0b0 => .{ .logical_shifted_register = inst.logical_shifted_register },
                    0b1 => switch (@as(u1, @truncate(inst.group.op2 >> 0))) {
                        0b0 => .{ .add_subtract_shifted_register = inst.add_subtract_shifted_register },
                        0b1 => .{ .add_subtract_extended_register = inst.add_subtract_extended_register },
                    },
                },
                0b1 => switch (inst.group.op2) {
                    0b0000 => switch (inst.group.op3) {
                        0b000000 => .{ .add_subtract_with_carry = inst.add_subtract_with_carry },
                        0b000001, 0b100001 => .{ .rotate_right_into_flags = inst.rotate_right_into_flags },
                        0b000010, 0b010010, 0b100010, 0b110010 => .{ .evaluate_into_flags = inst.evaluate_into_flags },
                        else => .unallocated,
                    },
                    0b0010 => switch (@as(u1, @truncate(inst.group.op3 >> 1))) {
                        0b0 => .{ .conditional_compare_register = inst.conditional_compare_register },
                        0b1 => .{ .conditional_compare_immediate = inst.conditional_compare_immediate },
                    },
                    0b0100 => .{ .conditional_select = inst.conditional_select },
                    0b0110 => switch (inst.group.op0) {
                        0b0 => .{ .data_processing_two_source = inst.data_processing_two_source },
                        0b1 => .{ .data_processing_one_source = inst.data_processing_one_source },
                    },
                    0b1000...0b1111 => .{ .data_processing_three_source = inst.data_processing_three_source },
                    else => .unallocated,
                },
            };
        }
    };

    /// C4.1.90 Data Processing -- Scalar Floating-Point and Advanced SIMD
    pub const DataProcessingVector = packed union {
        group: @This().Group,
        simd_scalar_pairwise: SimdScalarPairwise,
        simd_copy: SimdCopy,
        simd_two_register_miscellaneous: SimdTwoRegisterMiscellaneous,
        simd_across_lanes: SimdAcrossLanes,
        simd_three_same: SimdThreeSame,
        simd_modified_immediate: SimdModifiedImmediate,
        convert_float_integer: ConvertFloatInteger,
        float_data_processing_one_source: FloatDataProcessingOneSource,
        float_compare: FloatCompare,
        float_immediate: FloatImmediate,
        float_data_processing_two_source: FloatDataProcessingTwoSource,
        float_data_processing_three_source: FloatDataProcessingThreeSource,

        /// Table C4-91 Encoding table for the Data Processing -- Scalar Floating-Point and Advanced SIMD group
        pub const Group = packed struct {
            encoded0: u10,
            op3: u9,
            op2: u4,
            op1: u2,
            decoded25: u3 = 0b111,
            op0: u4,
        };

        /// Advanced SIMD scalar pairwise
        pub const SimdScalarPairwise = packed union {
            group: @This().Group,
            addp: Addp,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5,
                decoded17: u5 = 0b11000,
                size: Size,
                decoded24: u5 = 0b11110,
                U: u1,
                decoded30: u2 = 0b01,
            };

            /// C7.2.4 ADDP (scalar)
            pub const Addp = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5 = 0b11011,
                decoded17: u5 = 0b11000,
                size: Size,
                decoded24: u5 = 0b11110,
                U: u1 = 0b0,
                decoded30: u2 = 0b01,
            };
        };

        /// Advanced SIMD copy
        pub const SimdCopy = packed union {
            group: @This().Group,
            smov: Smov,
            umov: Umov,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                imm4: u4,
                decoded15: u1 = 0b0,
                imm5: u5,
                decoded21: u8 = 0b01110000,
                op: u1,
                Q: Register.IntegerSize,
                decoded31: u1 = 0b0,
            };

            /// C7.2.279 SMOV
            pub const Smov = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                decoded11: u1 = 0b1,
                decoded12: u1 = 0b0,
                decoded13: u2 = 0b01,
                decoded15: u1 = 0b0,
                imm5: u5,
                decoded21: u8 = 0b01110000,
                decoded29: u1 = 0b0,
                Q: Register.IntegerSize,
                decoded31: u1 = 0b0,
            };

            /// C7.2.371 UMOV
            pub const Umov = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                decoded11: u1 = 0b1,
                decoded12: u1 = 0b1,
                decoded13: u2 = 0b01,
                decoded15: u1 = 0b0,
                imm5: u5,
                decoded21: u8 = 0b01110000,
                decoded29: u1 = 0b0,
                Q: Register.IntegerSize,
                decoded31: u1 = 0b0,
            };
        };

        /// Advanced SIMD two-register miscellaneous
        pub const SimdTwoRegisterMiscellaneous = packed union {
            group: @This().Group,
            cnt: Cnt,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5,
                decoded17: u5 = 0b10000,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.38 CNT
            pub const Cnt = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5 = 0b00101,
                decoded17: u5 = 0b10000,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };
        };

        /// Advanced SIMD across lanes
        pub const SimdAcrossLanes = packed union {
            group: @This().Group,
            addv: Addv,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5,
                decoded17: u5 = 0b11000,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.6 ADDV
            pub const Addv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: u5 = 0b11011,
                decoded17: u5 = 0b11000,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };
        };

        /// Advanced SIMD three same
        pub const SimdThreeSame = packed union {
            group: @This().Group,
            addp: Addp,
            @"and": And,
            bic: Bic,
            orr: Orr,
            orn: Orn,
            eor: Eor,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.5 ADDP (vector)
            pub const Addp = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b10111,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.11 AND (vector)
            pub const And = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b00011,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size = .byte,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.21 BIC (vector, register)
            pub const Bic = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b00011,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size = .half,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.213 ORR (vector, register)
            pub const Orr = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b00011,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size = .single,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.211 ORN (vector)
            pub const Orn = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b00011,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size = .double,
                decoded24: u5 = 0b01110,
                U: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.41 EOR (vector)
            pub const Eor = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u1 = 0b1,
                opcode: u5 = 0b00011,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                size: Size = .byte,
                decoded24: u5 = 0b01110,
                U: u1 = 0b1,
                Q: Q,
                decoded31: u1 = 0b0,
            };
        };

        /// Advanced SIMD modified immediate
        pub const SimdModifiedImmediate = packed union {
            group: @This().Group,
            movi: Movi,
            orr: Orr,
            fmov: Fmov,
            mvni: Mvni,
            bic: Bic,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1,
                cmode: u4,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.204 MOVI
            pub const Movi = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1 = 0b0,
                cmode: u4,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.212 ORR (vector, immediate)
            pub const Orr = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1 = 0b0,
                cmode0: u1 = 0b1,
                cmode: u3,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.129 FMOV (vector, immediate)
            pub const Fmov = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1 = 0b1,
                cmode: u4 = 0b1111,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1 = 0b0,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.208 MVNI
            pub const Mvni = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1 = 0b0,
                cmode: u4,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1 = 0b1,
                Q: Q,
                decoded31: u1 = 0b0,
            };

            /// C7.2.20 BIC (vector, immediate)
            pub const Bic = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u1 = 0b1,
                o2: u1 = 0b0,
                cmode0: u1 = 0b1,
                cmode: u3,
                imm3: u3,
                decoded19: u10 = 0b0111100000,
                op: u1 = 0b1,
                Q: Q,
                decoded31: u1 = 0b0,
            };
        };

        /// Conversion between floating-point and integer
        pub const ConvertFloatInteger = packed union {
            group: @This().Group,
            fcvtns: Fcvtns,
            fcvtnu: Fcvtnu,
            scvtf: Scvtf,
            ucvtf: Ucvtf,
            fcvtas: Fcvtas,
            fcvtau: Fcvtau,
            fmov: Fmov,
            fcvtps: Fcvtps,
            fcvtpu: Fcvtpu,
            fcvtms: Fcvtms,
            fcvtmu: Fcvtmu,
            fcvtzs: Fcvtzs,
            fcvtzu: Fcvtzu,
            fjcvtzs: Fjcvtzs,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3,
                rmode: u2,
                decoded21: u1 = 0b1,
                ptype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.81 FCVTNS (scalar)
            pub const Fcvtns = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b000,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.83 FCVTNU (scalar)
            pub const Fcvtnu = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b001,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.236 SCVTF (scalar, integer)
            pub const Scvtf = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b010,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.355 UCVTF (scalar, integer)
            pub const Ucvtf = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b011,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.71 FCVTAS (scalar)
            pub const Fcvtas = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b100,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.73 FCVTAU (scalar)
            pub const Fcvtau = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b101,
                rmode: Rmode = .n,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.131 FMOV (general)
            pub const Fmov = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: Opcode,
                rmode: Fmov.Rmode,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,

                pub const Opcode = enum(u3) {
                    float_to_integer = 0b110,
                    integer_to_float = 0b111,
                    _,
                };

                pub const Rmode = enum(u2) {
                    @"0" = 0b00,
                    @"1" = 0b01,
                    _,
                };
            };

            /// C7.2.85 FCVTPS (scalar)
            pub const Fcvtps = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b000,
                rmode: Rmode = .p,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.87 FCVTPU (scalar)
            pub const Fcvtpu = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b001,
                rmode: Rmode = .p,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.76 FCVTMS (scalar)
            pub const Fcvtms = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b000,
                rmode: Rmode = .m,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.78 FCVTMU (scalar)
            pub const Fcvtmu = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b001,
                rmode: Rmode = .m,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.92 FCVTZS (scalar, integer)
            pub const Fcvtzs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b000,
                rmode: Rmode = .z,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.96 FCVTZU (scalar, integer)
            pub const Fcvtzu = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b001,
                rmode: Rmode = .z,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize,
            };

            /// C7.2.99 FJCVTZS
            pub const Fjcvtzs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u6 = 0b000000,
                opcode: u3 = 0b110,
                rmode: Rmode = .z,
                decoded21: u1 = 0b1,
                ftype: Ftype = .double,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                sf: Register.IntegerSize = .word,
            };

            pub const Rmode = enum(u2) {
                /// to nearest
                n = 0b00,
                /// toward plus infinity
                p = 0b01,
                /// toward minus infinity
                m = 0b10,
                /// toward zero
                z = 0b11,
            };
        };

        /// Floating-point data-processing (1 source)
        pub const FloatDataProcessingOneSource = packed union {
            group: @This().Group,
            fmov: Fmov,
            fabs: Fabs,
            fneg: Fneg,
            fsqrt: Fsqrt,
            fcvt: Fcvt,
            frintn: Frintn,
            frintp: Frintp,
            frintm: Frintm,
            frintz: Frintz,
            frinta: Frinta,
            frintx: Frintx,
            frinti: Frinti,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opcode: u6,
                decoded21: u1 = 0b1,
                ptype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool,
                decoded30: u1 = 0b0,
                M: u1,
            };

            /// C7.2.130 FMOV (register)
            pub const Fmov = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opc: u2 = 0b00,
                decoded17: u4 = 0b0000,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.46 FABS (scalar)
            pub const Fabs = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opc: u2 = 0b01,
                decoded17: u4 = 0b0000,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.140 FNEG (scalar)
            pub const Fneg = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opc: u2 = 0b10,
                decoded17: u4 = 0b0000,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.172 FSQRT (scalar)
            pub const Fsqrt = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opc: u2 = 0b11,
                decoded17: u4 = 0b0000,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.69 FCVT
            pub const Fcvt = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                opc: Ftype,
                decoded17: u4 = 0b0001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.162 FRINTN (scalar)
            pub const Frintn = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .n,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.164 FRINTP (scalar)
            pub const Frintp = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .p,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.160 FRINTM (scalar)
            pub const Frintm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .m,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.168 FRINTZ (scalar)
            pub const Frintz = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .z,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.156 FRINTA (scalar)
            pub const Frinta = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .a,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.166 FRINTX (scalar)
            pub const Frintx = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .x,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.158 FRINTI (scalar)
            pub const Frinti = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u5 = 0b10000,
                rmode: Rmode = .i,
                decoded18: u3 = 0b001,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            pub const Rmode = enum(u3) {
                /// to nearest with ties to even
                n = 0b000,
                /// toward plus infinity
                p = 0b001,
                /// toward minus infinity
                m = 0b010,
                /// toward zero
                z = 0b011,
                /// to nearest with ties to away
                a = 0b100,
                /// exact, using current rounding mode
                x = 0b110,
                /// using current rounding mode
                i = 0b111,
                _,
            };
        };

        /// Floating-point compare
        pub const FloatCompare = packed union {
            group: @This().Group,
            fcmp: Fcmp,
            fcmpe: Fcmpe,

            pub const Group = packed struct {
                opcode2: u5,
                Rn: Register.Encoded,
                decoded10: u4 = 0b1000,
                op: u2,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ptype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool,
                decoded30: u1 = 0b0,
                M: u1,
            };

            /// C7.2.66 FCMP
            pub const Fcmp = packed struct {
                decoded0: u3 = 0b000,
                opc0: Opc0,
                opc1: u1 = 0b0,
                Rn: Register.Encoded,
                decoded10: u4 = 0b1000,
                op: u2 = 0b00,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.67 FCMPE
            pub const Fcmpe = packed struct {
                decoded0: u3 = 0b000,
                opc0: Opc0,
                opc1: u1 = 0b1,
                Rn: Register.Encoded,
                decoded10: u4 = 0b1000,
                op: u2 = 0b00,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            pub const Opc0 = enum(u1) {
                register = 0b00,
                zero = 0b01,
            };
        };

        /// Floating-point immediate
        pub const FloatImmediate = packed union {
            group: @This().Group,
            fmov: Fmov,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                imm5: u5,
                decoded10: u3 = 0b100,
                imm8: u8,
                decoded21: u1 = 0b1,
                ptype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool,
                decoded30: u1 = 0b0,
                M: u1,
            };

            /// C7.2.132 FMOV (scalar, immediate)
            pub const Fmov = packed struct {
                Rd: Register.Encoded,
                imm5: u5 = 0b00000,
                decoded10: u3 = 0b100,
                imm8: u8,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };
        };

        /// Floating-point data-processing (2 source)
        pub const FloatDataProcessingTwoSource = packed union {
            group: @This().Group,
            fmul: Fmul,
            fdiv: Fdiv,
            fadd: Fadd,
            fsub: Fsub,
            fmax: Fmax,
            fmin: Fmin,
            fmaxnm: Fmaxnm,
            fminnm: Fminnm,
            fnmul: Fnmul,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ptype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool,
                decoded30: u1 = 0b0,
                M: u1,
            };

            /// C7.2.136 FMUL (scalar)
            pub const Fmul = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fmul,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.98 FDIV (scalar)
            pub const Fdiv = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fdiv,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.50 FADD (scalar)
            pub const Fadd = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fadd,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.174 FSUB (scalar)
            pub const Fsub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fsub,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.102 FMAX (scalar)
            pub const Fmax = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fmax,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.112 FMIN (scalar)
            pub const Fmin = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fmin,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.104 FMAXNM (scalar)
            pub const Fmaxnm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fmaxnm,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.114 FMINNM (scalar)
            pub const Fminnm = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fminnm,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.143 FNMUL (scalar)
            pub const Fnmul = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                decoded10: u2 = 0b10,
                opcode: Opcode = .fnmul,
                Rm: Register.Encoded,
                decoded21: u1 = 0b1,
                ftype: Ftype,
                decoded24: u5 = 0b11110,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            pub const Opcode = enum(u4) {
                fmul = 0b0000,
                fdiv = 0b0001,
                fadd = 0b0010,
                fsub = 0b0011,
                fmax = 0b0100,
                fmin = 0b0101,
                fmaxnm = 0b0110,
                fminnm = 0b0111,
                fnmul = 0b1000,
                _,
            };
        };

        /// Floating-point data-processing (3 source)
        pub const FloatDataProcessingThreeSource = packed union {
            group: @This().Group,
            fmadd: Fmadd,
            fmsub: Fmsub,
            fnmadd: Fnmadd,
            fnmsub: Fnmsub,

            pub const Group = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp,
                Rm: Register.Encoded,
                o1: u1,
                ptype: Ftype,
                decoded24: u5 = 0b11111,
                S: bool,
                decoded30: u1 = 0b0,
                M: u1,
            };

            /// C7.2.100 FMADD
            pub const Fmadd = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                o1: O1 = .fm,
                ftype: Ftype,
                decoded24: u5 = 0b11111,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.133 FMSUB
            pub const Fmsub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .sub,
                Rm: Register.Encoded,
                o1: O1 = .fm,
                ftype: Ftype,
                decoded24: u5 = 0b11111,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.141 FNMADD
            pub const Fnmadd = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .add,
                Rm: Register.Encoded,
                o1: O1 = .fnm,
                ftype: Ftype,
                decoded24: u5 = 0b11111,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            /// C7.2.142 FNMSUB
            pub const Fnmsub = packed struct {
                Rd: Register.Encoded,
                Rn: Register.Encoded,
                Ra: Register.Encoded,
                o0: AddSubtractOp = .sub,
                Rm: Register.Encoded,
                o1: O1 = .fnm,
                ftype: Ftype,
                decoded24: u5 = 0b11111,
                S: bool = false,
                decoded30: u1 = 0b0,
                M: u1 = 0b0,
            };

            pub const O1 = enum(u1) {
                fm = 0b0,
                fnm = 0b1,
            };
        };

        pub const Q = enum(u1) {
            double = 0b0,
            quad = 0b1,
        };

        pub const Size = enum(u2) {
            byte = 0b00,
            half = 0b01,
            single = 0b10,
            double = 0b11,

            pub fn toVectorSize(s: Size) Register.VectorSize {
                return switch (s) {
                    .byte => .byte,
                    .half => .half,
                    .single => .single,
                    .double => .double,
                };
            }

            pub fn fromVectorSize(vs: Register.VectorSize) Size {
                return switch (vs) {
                    .byte => .byte,
                    .half => .half,
                    .single => .single,
                    .double => .double,
                };
            }
        };

        pub const Ftype = enum(u2) {
            single = 0b00,
            double = 0b01,
            quad = 0b10,
            half = 0b11,
        };
    };

    pub const AddSubtractOp = enum(u1) {
        add = 0b0,
        sub = 0b1,
    };

    pub const LogicalOpc = enum(u2) {
        @"and" = 0b00,
        orr = 0b01,
        eor = 0b10,
        ands = 0b11,
    };

    pub const Decoded = union(enum) {
        unallocated,
        reserved: Reserved,
        sme: Sme,
        sve: Sve,
        data_processing_immediate: DataProcessingImmediate,
        branch_exception_generating_system: BranchExceptionGeneratingSystem,
        load_store: LoadStore,
        data_processing_register: DataProcessingRegister,
        data_processing_vector: DataProcessingVector,
    };
    pub fn decode(inst: @This()) @This().Decoded {
        return switch (inst.group.op1) {
            0b0000 => switch (inst.group.op0) {
                0b0 => .{ .reserved = inst.reserved },
                0b1 => .{ .sme = inst.sme },
            },
            0b0001 => .unallocated,
            0b0010 => .{ .sve = inst.sve },
            0b0011 => .unallocated,
            0b1000, 0b1001 => .{ .data_processing_immediate = inst.data_processing_immediate },
            0b1010, 0b1011 => .{ .branch_exception_generating_system = inst.branch_exception_generating_system },
            0b0100, 0b0110, 0b1100, 0b1110 => .{ .load_store = inst.load_store },
            0b0101, 0b1101 => .{ .data_processing_register = inst.data_processing_register },
            0b0111, 0b1111 => .{ .data_processing_vector = inst.data_processing_vector },
        };
    }

    /// C6.2.1 ADC
    pub fn adc(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .add_subtract_with_carry = .{
            .adc = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.2 ADCS
    pub fn adcs(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .add_subtract_with_carry = .{
            .adcs = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.3 ADD (extended register)
    /// C6.2.4 ADD (immediate)
    /// C6.2.5 ADD (shifted register)
    pub fn add(d: Register, n: Register, form: union(enum) {
        extended_register_explicit: struct {
            register: Register,
            option: DataProcessingRegister.AddSubtractExtendedRegister.Option,
            amount: DataProcessingRegister.AddSubtractExtendedRegister.Extend.Amount,
        },
        extended_register: struct { register: Register, extend: DataProcessingRegister.AddSubtractExtendedRegister.Extend },
        immediate: u12,
        shifted_immediate: struct { immediate: u12, lsl: DataProcessingImmediate.AddSubtractImmediate.Shift = .@"0" },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.register.format.integer == extended_register_explicit.option.sf());
                return .{ .data_processing_register = .{ .add_subtract_extended_register = .{
                    .add = .{
                        .Rd = d.alias.encode(.{ .sp = true }),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm3 = switch (extended_register_explicit.amount) {
                            0...4 => |amount| amount,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.register.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .register = extended_register.register,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx => |amount| amount,
                },
            } },
            .immediate => |immediate| continue :form .{ .shifted_immediate = .{ .immediate = immediate } },
            .shifted_immediate => |shifted_immediate| {
                return .{ .data_processing_immediate = .{ .add_subtract_immediate = .{
                    .add = .{
                        .Rd = d.alias.encode(.{ .sp = true }),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm12 = shifted_immediate.immediate,
                        .sh = shifted_immediate.lsl,
                        .sf = sf,
                    },
                } } };
            },
            .register => |register| continue :form if (d.alias == .sp or n.alias == .sp or register.alias == .sp)
                .{ .extended_register = .{ .register = register, .extend = switch (sf) {
                    .word => .{ .uxtw = 0 },
                    .doubleword => .{ .uxtx = 0 },
                } } }
            else
                .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .add_subtract_shifted_register = .{
                    .add = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = switch (shifted_register_explicit.shift) {
                            .lsl, .lsr, .asr => |shift| shift,
                            .ror => unreachable,
                        },
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr => |amount| amount,
                    .ror => unreachable,
                },
            } },
        }
    }
    /// C7.2.4 ADDP (scalar)
    /// C7.2.5 ADDP (vector)
    pub fn addp(d: Register, n: Register, form: union(enum) {
        scalar,
        vector: Register,
    }) Instruction {
        switch (form) {
            .scalar => {
                assert(d.format.scalar == .double and n.format.vector == .@"2d");
                return .{ .data_processing_vector = .{ .simd_scalar_pairwise = .{
                    .addp = .{
                        .Rd = d.alias.encode(.{ .V = true }),
                        .Rn = n.alias.encode(.{ .V = true }),
                        .size = .double,
                    },
                } } };
            },
            .vector => |m| {
                const arrangement = d.format.vector;
                assert(arrangement != .@"1d" and n.format.vector == arrangement and m.format.vector == arrangement);
                return .{ .data_processing_vector = .{ .simd_three_same = .{
                    .addp = .{
                        .Rd = d.alias.encode(.{ .V = true }),
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .size = arrangement.elemSize(),
                        .Q = arrangement.size(),
                    },
                } } };
            },
        }
    }
    /// C6.2.7 ADDS (extended register)
    /// C6.2.8 ADDS (immediate)
    /// C6.2.9 ADDS (shifted register)
    pub fn adds(d: Register, n: Register, form: union(enum) {
        extended_register_explicit: struct {
            register: Register,
            option: DataProcessingRegister.AddSubtractExtendedRegister.Option,
            amount: DataProcessingRegister.AddSubtractExtendedRegister.Extend.Amount,
        },
        extended_register: struct { register: Register, extend: DataProcessingRegister.AddSubtractExtendedRegister.Extend },
        immediate: u12,
        shifted_immediate: struct { immediate: u12, lsl: DataProcessingImmediate.AddSubtractImmediate.Shift = .@"0" },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.register.format.integer == extended_register_explicit.option.sf());
                return .{ .data_processing_register = .{ .add_subtract_extended_register = .{
                    .adds = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm3 = switch (extended_register_explicit.amount) {
                            0...4 => |amount| amount,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.register.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .register = extended_register.register,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx => |amount| amount,
                },
            } },
            .immediate => |immediate| continue :form .{ .shifted_immediate = .{ .immediate = immediate } },
            .shifted_immediate => |shifted_immediate| {
                return .{ .data_processing_immediate = .{ .add_subtract_immediate = .{
                    .adds = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm12 = shifted_immediate.immediate,
                        .sh = shifted_immediate.lsl,
                        .sf = sf,
                    },
                } } };
            },
            .register => |register| continue :form if (d.alias == .sp or n.alias == .sp or register.alias == .sp)
                .{ .extended_register = .{ .register = register, .extend = switch (sf) {
                    .word => .{ .uxtw = 0 },
                    .doubleword => .{ .uxtx = 0 },
                } } }
            else
                .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .add_subtract_shifted_register = .{
                    .adds = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = switch (shifted_register_explicit.shift) {
                            .lsl, .lsr, .asr => |shift| shift,
                            .ror => unreachable,
                        },
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr => |amount| amount,
                    .ror => unreachable,
                },
            } },
        }
    }
    /// C7.2.6 ADDV
    pub fn addv(d: Register, n: Register) Instruction {
        const arrangement = n.format.vector;
        assert(arrangement.len() > 2 and d.format.scalar == arrangement.elemSize().toVectorSize());
        return .{ .data_processing_vector = .{ .simd_across_lanes = .{
            .addv = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .size = arrangement.elemSize(),
                .Q = arrangement.size(),
            },
        } } };
    }
    /// C6.2.10 ADR
    pub fn adr(d: Register, label: i21) Instruction {
        assert(d.format.integer == .doubleword);
        return .{ .data_processing_immediate = .{ .pc_relative_addressing = .{
            .adr = .{
                .Rd = d.alias.encode(.{}),
                .immhi = @intCast(label >> 2),
                .immlo = @truncate(@as(u21, @bitCast(label))),
            },
        } } };
    }
    /// C6.2.11 ADRP
    pub fn adrp(d: Register, label: i33) Instruction {
        assert(d.format.integer == .doubleword);
        const imm: i21 = @intCast(@shrExact(label, 12));
        return .{ .data_processing_immediate = .{ .pc_relative_addressing = .{
            .adrp = .{
                .Rd = d.alias.encode(.{}),
                .immhi = @intCast(imm >> 2),
                .immlo = @truncate(@as(u21, @bitCast(imm))),
            },
        } } };
    }
    /// C6.2.12 AND (immediate)
    /// C6.2.13 AND (shifted register)
    /// C7.2.11 AND (vector)
    pub fn @"and"(d: Register, n: Register, form: union(enum) {
        immediate: DataProcessingImmediate.Bitmask,
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        switch (d.format) {
            else => unreachable,
            .integer => |sf| {
                assert(n.format.integer == sf);
                form: switch (form) {
                    .immediate => |bitmask| {
                        assert(bitmask.validImmediate(sf));
                        return .{ .data_processing_immediate = .{ .logical_immediate = .{
                            .@"and" = .{
                                .Rd = d.alias.encode(.{ .sp = true }),
                                .Rn = n.alias.encode(.{}),
                                .imm = bitmask,
                                .sf = sf,
                            },
                        } } };
                    },
                    .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
                    .shifted_register_explicit => |shifted_register_explicit| {
                        assert(shifted_register_explicit.register.format.integer == sf);
                        return .{ .data_processing_register = .{ .logical_shifted_register = .{
                            .@"and" = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{}),
                                .imm6 = switch (sf) {
                                    .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                                    .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                                },
                                .Rm = shifted_register_explicit.register.alias.encode(.{}),
                                .shift = shifted_register_explicit.shift,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                        .register = shifted_register.register,
                        .shift = shifted_register.shift,
                        .amount = switch (shifted_register.shift) {
                            .lsl, .lsr, .asr, .ror => |amount| amount,
                        },
                    } },
                }
            },
            .vector => |arrangement| {
                const m = form.register;
                assert(arrangement.elemSize() == .byte and n.format.vector == arrangement and m.format.vector == arrangement);
                return .{ .data_processing_vector = .{ .simd_three_same = .{
                    .@"and" = .{
                        .Rd = d.alias.encode(.{ .V = true }),
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .Q = arrangement.size(),
                    },
                } } };
            },
        }
    }
    /// C6.2.14 ANDS (immediate)
    /// C6.2.15 ANDS (shifted register)
    pub fn ands(d: Register, n: Register, form: union(enum) {
        immediate: DataProcessingImmediate.Bitmask,
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .immediate => |bitmask| {
                assert(bitmask.validImmediate(sf));
                return .{ .data_processing_immediate = .{ .logical_immediate = .{
                    .ands = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm = bitmask,
                        .sf = sf,
                    },
                } } };
            },
            .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .logical_shifted_register = .{
                    .ands = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = shifted_register_explicit.shift,
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr, .ror => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.18 ASRV
    pub fn asrv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .asrv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.25 B
    pub fn b(label: i28) Instruction {
        return .{ .branch_exception_generating_system = .{ .unconditional_branch_immediate = .{
            .b = .{ .imm26 = @intCast(@shrExact(label, 2)) },
        } } };
    }
    /// C6.2.26 B.cond
    pub fn @"b."(cond: ConditionCode, label: i21) Instruction {
        return .{ .branch_exception_generating_system = .{ .conditional_branch_immediate = .{
            .b = .{
                .cond = cond,
                .imm19 = @intCast(@shrExact(label, 2)),
            },
        } } };
    }
    /// C6.2.27 BC.cond
    pub fn @"bc."(cond: ConditionCode, label: i21) Instruction {
        return .{ .branch_exception_generating_system = .{ .conditional_branch_immediate = .{
            .bc = .{
                .cond = cond,
                .imm19 = @intCast(@shrExact(label, 2)),
            },
        } } };
    }
    /// C6.2.30 BFM
    pub fn bfm(d: Register, n: Register, bitmask: DataProcessingImmediate.Bitmask) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and bitmask.validBitfield(sf));
        return .{ .data_processing_immediate = .{ .bitfield = .{
            .bfm = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .imm = bitmask,
                .sf = sf,
            },
        } } };
    }
    /// C6.2.32 BIC (shifted register)
    /// C7.2.20 BIC (vector, immediate)
    /// C7.2.21 BIC (vector, register)
    pub fn bic(d: Register, n: Register, form: union(enum) {
        shifted_immediate: struct { immediate: u8, lsl: u5 = 0 },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        switch (d.format) {
            else => unreachable,
            .integer => |sf| {
                assert(n.format.integer == sf);
                form: switch (form) {
                    else => unreachable,
                    .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
                    .shifted_register_explicit => |shifted_register_explicit| {
                        assert(shifted_register_explicit.register.format.integer == sf);
                        return .{ .data_processing_register = .{ .logical_shifted_register = .{
                            .bic = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{}),
                                .imm6 = switch (sf) {
                                    .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                                    .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                                },
                                .Rm = shifted_register_explicit.register.alias.encode(.{}),
                                .shift = shifted_register_explicit.shift,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                        .register = shifted_register.register,
                        .shift = shifted_register.shift,
                        .amount = switch (shifted_register.shift) {
                            .lsl, .lsr, .asr, .ror => |amount| amount,
                        },
                    } },
                }
            },
            .vector => |arrangement| switch (form) {
                else => unreachable,
                .shifted_immediate => |shifted_immediate| {
                    assert(n.alias == d.alias and n.format.vector == arrangement);
                    return .{ .data_processing_vector = .{ .simd_modified_immediate = .{
                        .bic = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .imm5 = @truncate(shifted_immediate.immediate >> 0),
                            .cmode = switch (arrangement) {
                                else => unreachable,
                                .@"4h", .@"8h" => @as(u3, 0b100) |
                                    @as(u3, @as(u1, @intCast(@shrExact(shifted_immediate.lsl, 3)))) << 0,
                                .@"2s", .@"4s" => @as(u3, 0b000) |
                                    @as(u3, @as(u2, @intCast(@shrExact(shifted_immediate.lsl, 3)))) << 0,
                            },
                            .imm3 = @intCast(shifted_immediate.immediate >> 5),
                            .Q = arrangement.size(),
                        },
                    } } };
                },
                .register => |m| {
                    assert(arrangement.elemSize() == .byte and n.format.vector == arrangement and m.format.vector == arrangement);
                    return .{ .data_processing_vector = .{ .simd_three_same = .{
                        .bic = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .Rn = n.alias.encode(.{ .V = true }),
                            .Rm = m.alias.encode(.{ .V = true }),
                            .Q = arrangement.size(),
                        },
                    } } };
                },
            },
        }
    }
    /// C6.2.33 BICS (shifted register)
    pub fn bics(d: Register, n: Register, form: union(enum) {
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .logical_shifted_register = .{
                    .bics = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = shifted_register_explicit.shift,
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr, .ror => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.34 BL
    pub fn bl(label: i28) Instruction {
        return .{ .branch_exception_generating_system = .{ .unconditional_branch_immediate = .{
            .bl = .{ .imm26 = @intCast(@shrExact(label, 2)) },
        } } };
    }
    /// C6.2.35 BLR
    pub fn blr(n: Register) Instruction {
        assert(n.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .unconditional_branch_register = .{
            .blr = .{ .Rn = n.alias.encode(.{}) },
        } } };
    }
    /// C6.2.37 BR
    pub fn br(n: Register) Instruction {
        assert(n.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .unconditional_branch_register = .{
            .br = .{ .Rn = n.alias.encode(.{}) },
        } } };
    }
    /// C6.2.40 BRK
    pub fn brk(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .brk = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.46 CBNZ
    pub fn cbnz(t: Register, label: i21) Instruction {
        return .{ .branch_exception_generating_system = .{ .compare_branch_immediate = .{
            .cbnz = .{
                .Rt = t.alias.encode(.{}),
                .imm19 = @intCast(@shrExact(label, 2)),
                .sf = t.format.integer,
            },
        } } };
    }
    /// C6.2.47 CBZ
    pub fn cbz(t: Register, label: i21) Instruction {
        return .{ .branch_exception_generating_system = .{ .compare_branch_immediate = .{
            .cbz = .{
                .Rt = t.alias.encode(.{}),
                .imm19 = @intCast(@shrExact(label, 2)),
                .sf = t.format.integer,
            },
        } } };
    }
    /// C6.2.48 CCMN (immediate)
    /// C6.2.49 CCMN (register)
    pub fn ccmn(
        n: Register,
        form: union(enum) { register: Register, immediate: u5 },
        nzcv: DataProcessingRegister.Nzcv,
        cond: ConditionCode,
    ) Instruction {
        const sf = n.format.integer;
        switch (form) {
            .register => |m| {
                assert(m.format.integer == sf);
                return .{ .data_processing_register = .{ .conditional_compare_register = .{
                    .ccmn = .{
                        .nzcv = nzcv,
                        .Rn = n.alias.encode(.{}),
                        .cond = cond,
                        .Rm = m.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .immediate => |imm| return .{ .data_processing_register = .{ .conditional_compare_immediate = .{
                .ccmn = .{
                    .nzcv = nzcv,
                    .Rn = n.alias.encode(.{}),
                    .cond = cond,
                    .imm5 = imm,
                    .sf = sf,
                },
            } } },
        }
    }
    /// C6.2.50 CCMP (immediate)
    /// C6.2.51 CCMP (register)
    pub fn ccmp(
        n: Register,
        form: union(enum) { register: Register, immediate: u5 },
        nzcv: DataProcessingRegister.Nzcv,
        cond: ConditionCode,
    ) Instruction {
        const sf = n.format.integer;
        switch (form) {
            .register => |m| {
                assert(m.format.integer == sf);
                return .{ .data_processing_register = .{ .conditional_compare_register = .{
                    .ccmp = .{
                        .nzcv = nzcv,
                        .Rn = n.alias.encode(.{}),
                        .cond = cond,
                        .Rm = m.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .immediate => |imm| return .{ .data_processing_register = .{ .conditional_compare_immediate = .{
                .ccmp = .{
                    .nzcv = nzcv,
                    .Rn = n.alias.encode(.{}),
                    .cond = cond,
                    .imm5 = imm,
                    .sf = sf,
                },
            } } },
        }
    }
    /// C6.2.56 CLREX
    pub fn clrex(imm: u4) Instruction {
        return .{ .branch_exception_generating_system = .{ .barriers = .{
            .clrex = .{
                .CRm = imm,
            },
        } } };
    }
    /// C6.2.58 CLZ
    pub fn clz(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_one_source = .{
            .clz = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C7.2.38 CNT
    pub fn cnt(d: Register, n: Register) Instruction {
        const arrangement = d.format.vector;
        assert(arrangement.elemSize() == .byte and n.format.vector == arrangement);
        return .{ .data_processing_vector = .{ .simd_two_register_miscellaneous = .{
            .cnt = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .size = arrangement.elemSize(),
                .Q = arrangement.size(),
            },
        } } };
    }
    /// C6.2.103 CSEL
    pub fn csel(d: Register, n: Register, m: Register, cond: ConditionCode) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .conditional_select = .{
            .csel = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .cond = cond,
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.106 CSINC
    pub fn csinc(d: Register, n: Register, m: Register, cond: ConditionCode) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .conditional_select = .{
            .csinc = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .cond = cond,
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.107 CSINV
    pub fn csinv(d: Register, n: Register, m: Register, cond: ConditionCode) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .conditional_select = .{
            .csinv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .cond = cond,
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.108 CSNEG
    pub fn csneg(d: Register, n: Register, m: Register, cond: ConditionCode) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .conditional_select = .{
            .csneg = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .cond = cond,
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.110 DCPS1
    pub fn dcps1(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .dcps1 = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.111 DCPS2
    pub fn dcps2(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .dcps2 = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.112 DCPS3
    pub fn dcps3(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .dcps3 = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.116 DSB
    pub fn dsb(option: BranchExceptionGeneratingSystem.Barriers.Option) Instruction {
        return .{ .branch_exception_generating_system = .{ .barriers = .{
            .dsb = .{
                .CRm = option,
            },
        } } };
    }
    /// C6.2.118 EON (shifted register)
    pub fn eon(d: Register, n: Register, form: union(enum) {
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .logical_shifted_register = .{
                    .eon = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = shifted_register_explicit.shift,
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr, .ror => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.119 EOR (immediate)
    /// C6.2.120 EOR (shifted register)
    /// C7.2.41 EOR (vector)
    pub fn eor(d: Register, n: Register, form: union(enum) {
        immediate: DataProcessingImmediate.Bitmask,
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        switch (d.format) {
            else => unreachable,
            .integer => |sf| {
                assert(n.format.integer == sf);
                form: switch (form) {
                    .immediate => |bitmask| {
                        assert(bitmask.validImmediate(sf));
                        return .{ .data_processing_immediate = .{ .logical_immediate = .{
                            .eor = .{
                                .Rd = d.alias.encode(.{ .sp = true }),
                                .Rn = n.alias.encode(.{}),
                                .imm = bitmask,
                                .sf = sf,
                            },
                        } } };
                    },
                    .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
                    .shifted_register_explicit => |shifted_register_explicit| {
                        assert(shifted_register_explicit.register.format.integer == sf);
                        return .{ .data_processing_register = .{ .logical_shifted_register = .{
                            .eor = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{}),
                                .imm6 = switch (sf) {
                                    .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                                    .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                                },
                                .Rm = shifted_register_explicit.register.alias.encode(.{}),
                                .shift = shifted_register_explicit.shift,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                        .register = shifted_register.register,
                        .shift = shifted_register.shift,
                        .amount = switch (shifted_register.shift) {
                            .lsl, .lsr, .asr, .ror => |amount| amount,
                        },
                    } },
                }
            },
            .vector => |arrangement| {
                const m = form.register;
                assert(arrangement.elemSize() == .byte and n.format.vector == arrangement and m.format.vector == arrangement);
                return .{ .data_processing_vector = .{ .simd_three_same = .{
                    .eor = .{
                        .Rd = d.alias.encode(.{ .V = true }),
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .Q = arrangement.size(),
                    },
                } } };
            },
        }
    }
    /// C6.2.124 EXTR
    pub fn extr(d: Register, n: Register, m: Register, lsb: u6) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_immediate = .{ .extract = .{
            .extr = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .imms = switch (sf) {
                    .word => @as(u5, @intCast(lsb)),
                    .doubleword => @as(u6, @intCast(lsb)),
                },
                .Rm = m.alias.encode(.{}),
                .N = sf,
                .sf = sf,
            },
        } } };
    }
    /// C7.2.46 FABS (scalar)
    pub fn fabs(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .fabs = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.50 FADD (scalar)
    pub fn fadd(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fadd = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.66 FCMP
    pub fn fcmp(n: Register, form: union(enum) { register: Register, zero }) Instruction {
        const ftype = n.format.scalar;
        switch (form) {
            .register => |m| {
                assert(m.format.scalar == ftype);
                return .{ .data_processing_vector = .{ .float_compare = .{
                    .fcmp = .{
                        .opc0 = .register,
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .ftype = switch (ftype) {
                            else => unreachable,
                            .single => .single,
                            .double => .double,
                            .half => .half,
                        },
                    },
                } } };
            },
            .zero => return .{ .data_processing_vector = .{ .float_compare = .{
                .fcmp = .{
                    .opc0 = .register,
                    .Rn = n.alias.encode(.{ .V = true }),
                    .Rm = @enumFromInt(0b00000),
                    .ftype = switch (ftype) {
                        else => unreachable,
                        .single => .single,
                        .double => .double,
                        .half => .half,
                    },
                },
            } } },
        }
    }
    /// C7.2.67 FCMPE
    pub fn fcmpe(n: Register, form: union(enum) { register: Register, zero }) Instruction {
        const ftype = n.format.scalar;
        switch (form) {
            .register => |m| {
                assert(m.format.scalar == ftype);
                return .{ .data_processing_vector = .{ .float_compare = .{
                    .fcmpe = .{
                        .opc0 = .zero,
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .ftype = switch (ftype) {
                            else => unreachable,
                            .single => .single,
                            .double => .double,
                            .half => .half,
                        },
                    },
                } } };
            },
            .zero => return .{ .data_processing_vector = .{ .float_compare = .{
                .fcmpe = .{
                    .opc0 = .zero,
                    .Rn = n.alias.encode(.{ .V = true }),
                    .Rm = @enumFromInt(0b00000),
                    .ftype = switch (ftype) {
                        else => unreachable,
                        .single => .single,
                        .double => .double,
                        .half => .half,
                    },
                },
            } } },
        }
    }
    /// C7.2.69 FCVT
    pub fn fcvt(d: Register, n: Register) Instruction {
        assert(d.format.scalar != n.format.scalar);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .fcvt = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .opc = switch (d.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.71 FCVTAS (scalar)
    pub fn fcvtas(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtas = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.73 FCVTAU (scalar)
    pub fn fcvtau(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtau = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.76 FCVTMS (scalar)
    pub fn fcvtms(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtms = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.78 FCVTMU (scalar)
    pub fn fcvtmu(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtmu = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.81 FCVTNS (scalar)
    pub fn fcvtns(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtns = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.83 FCVTNU (scalar)
    pub fn fcvtnu(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtnu = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.85 FCVTPS (scalar)
    pub fn fcvtps(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtps = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.87 FCVTPU (scalar)
    pub fn fcvtpu(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtpu = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.92 FCVTZS (scalar, integer)
    pub fn fcvtzs(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtzs = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.96 FCVTZU (scalar, integer)
    pub fn fcvtzu(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fcvtzu = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (n.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = d.format.integer,
            },
        } } };
    }
    /// C7.2.98 FDIV (scalar)
    pub fn fdiv(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fdiv = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.99 FJCVTZS
    pub fn fjcvtzs(d: Register, n: Register) Instruction {
        assert(d.format.integer == .word);
        assert(n.format.scalar == .double);
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .fjcvtzs = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
            },
        } } };
    }
    /// C7.2.100 FMADD
    pub fn fmadd(d: Register, n: Register, m: Register, a: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype and a.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_three_source = .{
            .fmadd = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .Ra = a.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.102 FMAX (scalar)
    pub fn fmax(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fmax = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.104 FMAXNM (scalar)
    pub fn fmaxnm(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fmaxnm = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.112 FMIN (scalar)
    pub fn fmin(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fmin = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.114 FMINNM (scalar)
    pub fn fminnm(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fminnm = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.129 FMOV (vector, immediate)
    /// C7.2.130 FMOV (register)
    /// C7.2.131 FMOV (general)
    /// C7.2.132 FMOV (scalar, immediate)
    pub fn fmov(d: Register, form: union(enum) { immediate: f16, register: Register }) Instruction {
        switch (form) {
            .immediate => |immediate| {
                const repr: std.math.FloatRepr(f16) = @bitCast(immediate);
                const imm: u8 = @bitCast(@as(packed struct(u8) {
                    mantissa: u4,
                    exponent: i3,
                    sign: std.math.Sign,
                }, .{
                    .mantissa = @intCast(@shrExact(repr.mantissa, 6)),
                    .exponent = @intCast(repr.exponent.unbias() - 1),
                    .sign = repr.sign,
                }));
                switch (d.format) {
                    else => unreachable,
                    .scalar => |ftype| return .{ .data_processing_vector = .{ .float_immediate = .{
                        .fmov = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .imm8 = imm,
                            .ftype = switch (ftype) {
                                else => unreachable,
                                .single => .single,
                                .double => .double,
                                .half => .half,
                            },
                        },
                    } } },
                    .vector => |arrangement| {
                        assert(arrangement.len() > 1 and arrangement.elemSize() != .byte);
                        return .{ .data_processing_vector = .{ .simd_modified_immediate = .{
                            .fmov = .{
                                .Rd = d.alias.encode(.{ .V = true }),
                                .imm5 = @truncate(imm >> 0),
                                .imm3 = @intCast(imm >> 5),
                                .Q = arrangement.size(),
                            },
                        } } };
                    },
                }
            },
            .register => |n| switch (d.format) {
                else => unreachable,
                .integer => |sf| switch (n.format) {
                    else => unreachable,
                    .scalar => |ftype| {
                        switch (ftype) {
                            else => unreachable,
                            .half => {},
                            .single => assert(sf == .word),
                            .double => assert(sf == .doubleword),
                        }
                        return .{ .data_processing_vector = .{ .convert_float_integer = .{
                            .fmov = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{ .V = true }),
                                .opcode = .float_to_integer,
                                .rmode = .@"0",
                                .ftype = switch (ftype) {
                                    else => unreachable,
                                    .single => .single,
                                    .double => .double,
                                    .half => .half,
                                },
                                .sf = sf,
                            },
                        } } };
                    },
                    .element => |element| return .{ .data_processing_vector = .{ .convert_float_integer = .{
                        .fmov = .{
                            .Rd = d.alias.encode(.{}),
                            .Rn = n.alias.encode(.{ .V = true }),
                            .opcode = .float_to_integer,
                            .rmode = switch (element.index) {
                                else => unreachable,
                                1 => .@"1",
                            },
                            .ftype = switch (element.size) {
                                else => unreachable,
                                .double => .quad,
                            },
                            .sf = sf,
                        },
                    } } },
                },
                .scalar => |ftype| switch (n.format) {
                    else => unreachable,
                    .integer => {
                        const sf = n.format.integer;
                        switch (ftype) {
                            else => unreachable,
                            .half => {},
                            .single => assert(sf == .word),
                            .double => assert(sf == .doubleword),
                        }
                        return .{ .data_processing_vector = .{ .convert_float_integer = .{
                            .fmov = .{
                                .Rd = d.alias.encode(.{ .V = true }),
                                .Rn = n.alias.encode(.{}),
                                .opcode = .integer_to_float,
                                .rmode = .@"0",
                                .ftype = switch (ftype) {
                                    else => unreachable,
                                    .single => .single,
                                    .double => .double,
                                    .half => .half,
                                },
                                .sf = sf,
                            },
                        } } };
                    },
                    .scalar => {
                        assert(n.format.scalar == ftype);
                        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
                            .fmov = .{
                                .Rd = d.alias.encode(.{ .V = true }),
                                .Rn = n.alias.encode(.{ .V = true }),
                                .ftype = switch (ftype) {
                                    else => unreachable,
                                    .single => .single,
                                    .double => .double,
                                    .half => .half,
                                },
                            },
                        } } };
                    },
                },
                .element => |element| switch (n.format) {
                    else => unreachable,
                    .integer => |sf| return .{ .data_processing_vector = .{ .convert_float_integer = .{
                        .fmov = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .Rn = n.alias.encode(.{}),
                            .opcode = .integer_to_float,
                            .rmode = switch (element.index) {
                                else => unreachable,
                                1 => .@"1",
                            },
                            .ftype = switch (element.size) {
                                else => unreachable,
                                .double => .quad,
                            },
                            .sf = sf,
                        },
                    } } },
                },
            },
        }
    }
    /// C7.2.133 FMSUB
    pub fn fmsub(d: Register, n: Register, m: Register, a: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype and a.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_three_source = .{
            .fmsub = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .Ra = a.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.136 FMUL (scalar)
    pub fn fmul(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fmul = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.140 FNEG (scalar)
    pub fn fneg(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .fneg = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.141 FNMADD
    pub fn fnmadd(d: Register, n: Register, m: Register, a: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype and a.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_three_source = .{
            .fnmadd = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .Ra = a.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.142 FNMSUB
    pub fn fnmsub(d: Register, n: Register, m: Register, a: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype and a.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_three_source = .{
            .fnmsub = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .Ra = a.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.143 FNMUL (scalar)
    pub fn fnmul(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fnmul = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.156 FRINTA (scalar)
    pub fn frinta(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frinta = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.158 FRINTI (scalar)
    pub fn frinti(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frinti = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.160 FRINTM (scalar)
    pub fn frintm(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frintm = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.162 FRINTN (scalar)
    pub fn frintn(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frintn = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.164 FRINTP (scalar)
    pub fn frintp(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frintp = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.166 FRINTX (scalar)
    pub fn frintx(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frintx = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.168 FRINTZ (scalar)
    pub fn frintz(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .frintz = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.172 FSQRT (scalar)
    pub fn fsqrt(d: Register, n: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_one_source = .{
            .fsqrt = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C7.2.174 FSUB (scalar)
    pub fn fsub(d: Register, n: Register, m: Register) Instruction {
        const ftype = d.format.scalar;
        assert(n.format.scalar == ftype and m.format.scalar == ftype);
        return .{ .data_processing_vector = .{ .float_data_processing_two_source = .{
            .fsub = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{ .V = true }),
                .Rm = m.alias.encode(.{ .V = true }),
                .ftype = switch (ftype) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
            },
        } } };
    }
    /// C6.2.126 HINT
    pub fn hint(imm: u7) Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .group = .{
                .op2 = @truncate(imm >> 0),
                .CRm = @intCast(imm >> 3),
            },
        } } };
    }
    /// C6.2.127 HLT
    pub fn hlt(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .hlt = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.128 HVC
    pub fn hvc(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .hvc = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.131 ISB
    pub fn isb(option: BranchExceptionGeneratingSystem.Barriers.Option) Instruction {
        return .{ .branch_exception_generating_system = .{ .barriers = .{
            .isb = .{
                .CRm = option,
            },
        } } };
    }
    /// C6.2.164 LDP
    /// C7.2.190 LDP (SIMD&FP)
    pub fn ldp(t1: Register, t2: Register, form: union(enum) {
        post_index: struct { base: Register, index: i10 },
        pre_index: struct { base: Register, index: i10 },
        signed_offset: struct { base: Register, offset: i10 = 0 },
        base: Register,
    }) Instruction {
        switch (t1.format) {
            else => unreachable,
            .integer => |sf| {
                assert(t2.format.integer == sf);
                form: switch (form) {
                    .post_index => |post_index| {
                        assert(post_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_post_indexed = .{ .integer = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = post_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(post_index.index, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .signed_offset => |signed_offset| {
                        assert(signed_offset.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_offset = .{ .integer = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = signed_offset.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(signed_offset.offset, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .pre_index => |pre_index| {
                        assert(pre_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_pre_indexed = .{ .integer = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(pre_index.index, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .base => |base| continue :form .{ .signed_offset = .{ .base = base } },
                }
            },
            .scalar => |vs| {
                assert(t2.format.scalar == vs);
                form: switch (form) {
                    .post_index => |post_index| {
                        assert(post_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_post_indexed = .{ .vector = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = post_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(post_index.index, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .signed_offset => |signed_offset| {
                        assert(signed_offset.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_offset = .{ .vector = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = signed_offset.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(signed_offset.offset, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .pre_index => |pre_index| {
                        assert(pre_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_pre_indexed = .{ .vector = .{
                            .ldp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(pre_index.index, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .base => |base| continue :form .{ .signed_offset = .{ .base = base } },
                }
            },
        }
    }
    /// C6.2.166 LDR (immediate)
    /// C6.2.167 LDR (literal)
    /// C6.2.168 LDR (register)
    /// C7.2.191 LDR (immediate, SIMD&FP)
    /// C7.2.192 LDR (literal, SIMD&FP)
    /// C7.2.193 LDR (register, SIMD&FP)
    pub fn ldr(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u16 = 0 },
        base: Register,
        literal: i21,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        switch (t.format) {
            else => unreachable,
            .integer => |sf| form: switch (form) {
                .post_index => |post_index| {
                    assert(post_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = post_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = post_index.index,
                            .sf = sf,
                        },
                    } } } };
                },
                .pre_index => |pre_index| {
                    assert(pre_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = pre_index.index,
                            .sf = sf,
                        },
                    } } } };
                },
                .unsigned_offset => |unsigned_offset| {
                    assert(unsigned_offset.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                            .imm12 = @intCast(@shrExact(unsigned_offset.offset, @as(u2, 2) + @intFromEnum(sf))),
                            .sf = sf,
                        },
                    } } } };
                },
                .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
                .literal => |offset| return .{ .load_store = .{ .register_literal = .{ .integer = .{
                    .ldr = .{
                        .Rt = t.alias.encode(.{}),
                        .imm19 = @intCast(@shrExact(offset, 2)),
                        .sf = sf,
                    },
                } } } },
                .extended_register_explicit => |extended_register_explicit| {
                    assert(extended_register_explicit.base.format.integer == .doubleword and
                        extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                    return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                            .S = switch (sf) {
                                .word => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    2 => true,
                                    else => unreachable,
                                },
                                .doubleword => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    3 => true,
                                    else => unreachable,
                                },
                            },
                            .option = extended_register_explicit.option,
                            .Rm = extended_register_explicit.index.alias.encode(.{}),
                            .sf = sf,
                        },
                    } } } };
                },
                .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                    .base = extended_register.base,
                    .index = extended_register.index,
                    .option = extended_register.extend,
                    .amount = switch (extended_register.extend) {
                        .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                    },
                } },
            },
            .scalar => |vs| form: switch (form) {
                .post_index => |post_index| {
                    assert(post_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_post_indexed = .{ .vector = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = post_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = post_index.index,
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .pre_index => |pre_index| {
                    assert(pre_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .vector = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = pre_index.index,
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .unsigned_offset => |unsigned_offset| {
                    assert(unsigned_offset.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_unsigned_immediate = .{ .vector = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                            .imm12 = @intCast(@shrExact(unsigned_offset.offset, @intFromEnum(vs))),
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
                .literal => |offset| return .{ .load_store = .{ .register_literal = .{ .vector = .{
                    .ldr = .{
                        .Rt = t.alias.encode(.{ .V = true }),
                        .imm19 = @intCast(@shrExact(offset, 2)),
                        .opc = .encode(vs),
                    },
                } } } },
                .extended_register_explicit => |extended_register_explicit| {
                    assert(extended_register_explicit.base.format.integer == .doubleword and
                        extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                    return .{ .load_store = .{ .register_register_offset = .{ .vector = .{
                        .ldr = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                            .S = switch (vs) {
                                else => unreachable,
                                .byte => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    else => unreachable,
                                },
                                .half => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    1 => true,
                                    else => unreachable,
                                },
                                .single => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    2 => true,
                                    else => unreachable,
                                },
                                .double => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    3 => true,
                                    else => unreachable,
                                },
                                .quad => switch (extended_register_explicit.amount) {
                                    0 => false,
                                    4 => true,
                                    else => unreachable,
                                },
                            },
                            .option = extended_register_explicit.option,
                            .Rm = extended_register_explicit.index.alias.encode(.{}),
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                    .base = extended_register.base,
                    .index = extended_register.index,
                    .option = extended_register.extend,
                    .amount = switch (extended_register.extend) {
                        .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                    },
                } },
            },
        }
    }
    /// C6.2.170 LDRB (immediate)
    /// C6.2.171 LDRB (register)
    pub fn ldrb(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u12 = 0 },
        base: Register,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        assert(t.format.integer == .word);
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .ldrb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .ldrb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .ldrb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = unsigned_offset.offset,
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .ldrb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => false,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.172 LDRH (immediate)
    /// C6.2.173 LDRH (register)
    pub fn ldrh(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u13 = 0 },
        base: Register,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        assert(t.format.integer == .word);
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .ldrh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .ldrh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .ldrh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = @intCast(@shrExact(unsigned_offset.offset, 1)),
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .ldrh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => false,
                            1 => true,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.174 LDRSB (immediate)
    /// C6.2.175 LDRSB (register)
    pub fn ldrsb(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u12 = 0 },
        base: Register,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        const sf = t.format.integer;
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .ldrsb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .ldrsb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .ldrsb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = unsigned_offset.offset,
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .ldrsb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => false,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.176 LDRSH (immediate)
    /// C6.2.177 LDRSH (register)
    pub fn ldrsh(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u13 = 0 },
        base: Register,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        const sf = t.format.integer;
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .ldrsh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .ldrsh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .ldrsh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = @intCast(@shrExact(unsigned_offset.offset, 1)),
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .ldrsh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => false,
                            1 => true,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                        .opc0 = ~@intFromEnum(sf),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.178 LDRSW (immediate)
    /// C6.2.179 LDRSW (literal)
    /// C6.2.180 LDRSW (register)
    pub fn ldrsw(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u14 = 0 },
        base: Register,
        literal: i21,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Integer.Option,
            amount: LoadStore.RegisterRegisterOffset.Integer.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Integer.Extend,
        },
    }) Instruction {
        assert(t.format.integer == .doubleword);
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{
                    .ldrsw = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                    },
                } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .ldrsw = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{
                    .ldrsw = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = @intCast(@shrExact(unsigned_offset.offset, 2)),
                    },
                } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .literal => |offset| return .{ .load_store = .{ .register_literal = .{
                .ldrsw = .{
                    .Rt = t.alias.encode(.{}),
                    .imm19 = @intCast(@shrExact(offset, 2)),
                },
            } } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .ldrsw = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => 0b0,
                            2 => 0b1,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.202 LDUR
    /// C7.2.194 LDUR (SIMD&FP)
    pub fn ldur(t: Register, n: Register, simm: i9) Instruction {
        assert(n.format.integer == .doubleword);
        switch (t.format) {
            else => unreachable,
            .integer => |sf| return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
                .ldur = .{
                    .Rt = t.alias.encode(.{}),
                    .Rn = n.alias.encode(.{ .sp = true }),
                    .imm9 = simm,
                    .sf = sf,
                },
            } } } },
            .scalar => |vs| return .{ .load_store = .{ .register_unscaled_immediate = .{ .vector = .{
                .ldur = .{
                    .Rt = t.alias.encode(.{ .V = true }),
                    .Rn = n.alias.encode(.{ .sp = true }),
                    .imm9 = simm,
                    .opc1 = .encode(vs),
                    .size = .encode(vs),
                },
            } } } },
        }
    }
    /// C6.2.203 LDURB
    pub fn ldurb(t: Register, n: Register, simm: i9) Instruction {
        assert(t.format.integer == .word and n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .ldurb = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
            },
        } } } };
    }
    /// C6.2.204 LDURH
    pub fn ldurh(t: Register, n: Register, simm: i9) Instruction {
        assert(t.format.integer == .word and n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .ldurh = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
            },
        } } } };
    }
    /// C6.2.205 LDURSB
    pub fn ldursb(t: Register, n: Register, simm: i9) Instruction {
        assert(n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .ldursb = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
                .opc0 = ~@intFromEnum(t.format.integer),
            },
        } } } };
    }
    /// C6.2.206 LDURSH
    pub fn ldursh(t: Register, n: Register, simm: i9) Instruction {
        assert(n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .ldursh = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
                .opc0 = ~@intFromEnum(t.format.integer),
            },
        } } } };
    }
    /// C6.2.207 LDURSW
    pub fn ldursw(t: Register, n: Register, simm: i9) Instruction {
        assert(t.format.integer == .doubleword and n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .ldursw = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
            },
        } } } };
    }
    /// C6.2.214 LSLV
    pub fn lslv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .lslv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.217 LSRV
    pub fn lsrv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .lsrv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.218 MADD
    pub fn madd(d: Register, n: Register, m: Register, a: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf and a.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .madd = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C7.2.204 MOVI
    pub fn movi(d: Register, imm8: u8, shift: union(enum) { lsl: u5, msl: u5, replicate }) Instruction {
        const arrangement = switch (d.format) {
            else => unreachable,
            .scalar => |vs| switch (vs) {
                else => unreachable,
                .double => .@"1d",
            },
            .vector => |arrangement| switch (arrangement) {
                .@"1d" => unreachable,
                else => arrangement,
            },
        };
        return .{ .data_processing_vector = .{ .simd_modified_immediate = .{
            .movi = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .imm5 = @truncate(imm8 >> 0),
                .cmode = switch (shift) {
                    .lsl => |amount| switch (arrangement) {
                        else => unreachable,
                        .@"8b", .@"16b" => @as(u4, 0b1110) |
                            @as(u4, @as(u0, @intCast(@shrExact(amount, 3)))) << 1,
                        .@"4h", .@"8h" => @as(u4, 0b1000) |
                            @as(u4, @as(u1, @intCast(@shrExact(amount, 3)))) << 1,
                        .@"2s", .@"4s" => @as(u4, 0b0000) |
                            @as(u4, @as(u2, @intCast(@shrExact(amount, 3)))) << 1,
                    },
                    .msl => |amount| switch (arrangement) {
                        else => unreachable,
                        .@"2s", .@"4s" => @as(u4, 0b1100) |
                            @as(u4, @as(u1, @intCast(@shrExact(amount, 3) - 1))) << 0,
                    },
                    .replicate => switch (arrangement) {
                        else => unreachable,
                        .@"1d", .@"2d" => 0b1110,
                    },
                },
                .imm3 = @intCast(imm8 >> 5),
                .op = switch (shift) {
                    .lsl, .msl => 0b0,
                    .replicate => 0b1,
                },
                .Q = arrangement.size(),
            },
        } } };
    }
    /// C6.2.225 MOVK
    pub fn movk(
        d: Register,
        imm: u16,
        shift: struct { lsl: DataProcessingImmediate.MoveWideImmediate.Hw = .@"0" },
    ) Instruction {
        const sf = d.format.integer;
        assert(sf == .doubleword or shift.lsl.sf() == .word);
        return .{ .data_processing_immediate = .{ .move_wide_immediate = .{
            .movk = .{
                .Rd = d.alias.encode(.{}),
                .imm16 = imm,
                .hw = shift.lsl,
                .sf = sf,
            },
        } } };
    }
    /// C6.2.226 MOVN
    pub fn movn(
        d: Register,
        imm: u16,
        shift: struct { lsl: DataProcessingImmediate.MoveWideImmediate.Hw = .@"0" },
    ) Instruction {
        const sf = d.format.integer;
        assert(sf == .doubleword or shift.lsl.sf() == .word);
        return .{ .data_processing_immediate = .{ .move_wide_immediate = .{
            .movn = .{
                .Rd = d.alias.encode(.{}),
                .imm16 = imm,
                .hw = shift.lsl,
                .sf = sf,
            },
        } } };
    }
    /// C6.2.227 MOVZ
    pub fn movz(
        d: Register,
        imm: u16,
        shift: struct { lsl: DataProcessingImmediate.MoveWideImmediate.Hw = .@"0" },
    ) Instruction {
        const sf = d.format.integer;
        assert(sf == .doubleword or shift.lsl.sf() == .word);
        return .{ .data_processing_immediate = .{ .move_wide_immediate = .{
            .movz = .{
                .Rd = d.alias.encode(.{}),
                .imm16 = imm,
                .hw = shift.lsl,
                .sf = sf,
            },
        } } };
    }
    /// C6.2.228 MRS
    pub fn mrs(t: Register, systemreg: Register.System) Instruction {
        assert(t.format.integer == .doubleword and systemreg.op0 >= 0b10);
        return .{ .branch_exception_generating_system = .{ .system_register_move = .{
            .mrs = .{
                .Rt = t.alias.encode(.{}),
                .systemreg = systemreg,
            },
        } } };
    }
    /// C6.2.230 MSR (register)
    pub fn msr(systemreg: Register.System, t: Register) Instruction {
        assert(systemreg.op0 >= 0b10 and t.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .system_register_move = .{
            .msr = .{
                .Rt = t.alias.encode(.{}),
                .systemreg = systemreg,
            },
        } } };
    }
    /// C6.2.231 MSUB
    pub fn msub(d: Register, n: Register, m: Register, a: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf and a.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .msub = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.238 NOP
    pub fn nop() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .nop = .{},
        } } };
    }
    /// C6.2.239 ORN (shifted register)
    /// C7.2.211 ORN (vector)
    pub fn orn(d: Register, n: Register, form: union(enum) {
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        switch (d.format) {
            else => unreachable,
            .integer => |sf| {
                assert(n.format.integer == sf);
                form: switch (form) {
                    .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
                    .shifted_register_explicit => |shifted_register_explicit| {
                        assert(shifted_register_explicit.register.format.integer == sf);
                        return .{ .data_processing_register = .{ .logical_shifted_register = .{
                            .orn = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{}),
                                .imm6 = switch (sf) {
                                    .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                                    .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                                },
                                .Rm = shifted_register_explicit.register.alias.encode(.{}),
                                .shift = shifted_register_explicit.shift,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                        .register = shifted_register.register,
                        .shift = shifted_register.shift,
                        .amount = switch (shifted_register.shift) {
                            .lsl, .lsr, .asr, .ror => |amount| amount,
                        },
                    } },
                }
            },
            .vector => |arrangement| {
                const m = form.register;
                assert(arrangement.elemSize() == .byte and n.format.vector == arrangement and m.format.vector == arrangement);
                return .{ .data_processing_vector = .{ .simd_three_same = .{
                    .orn = .{
                        .Rd = d.alias.encode(.{ .V = true }),
                        .Rn = n.alias.encode(.{ .V = true }),
                        .Rm = m.alias.encode(.{ .V = true }),
                        .Q = arrangement.size(),
                    },
                } } };
            },
        }
    }
    /// C6.2.240 ORR (immediate)
    /// C6.2.241 ORR (shifted register)
    /// C7.2.212 ORR (vector, immediate)
    /// C7.2.213 ORR (vector, register)
    pub fn orr(d: Register, n: Register, form: union(enum) {
        immediate: DataProcessingImmediate.Bitmask,
        shifted_immediate: struct { immediate: u8, lsl: u5 = 0 },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        switch (d.format) {
            else => unreachable,
            .integer => |sf| {
                assert(n.format.integer == sf);
                form: switch (form) {
                    .immediate => |bitmask| {
                        assert(bitmask.validImmediate(sf));
                        return .{ .data_processing_immediate = .{ .logical_immediate = .{
                            .orr = .{
                                .Rd = d.alias.encode(.{ .sp = true }),
                                .Rn = n.alias.encode(.{}),
                                .imm = bitmask,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_immediate => unreachable,
                    .register => |register| continue :form .{ .shifted_register = .{ .register = register } },
                    .shifted_register_explicit => |shifted_register_explicit| {
                        assert(shifted_register_explicit.register.format.integer == sf);
                        return .{ .data_processing_register = .{ .logical_shifted_register = .{
                            .orr = .{
                                .Rd = d.alias.encode(.{}),
                                .Rn = n.alias.encode(.{}),
                                .imm6 = switch (sf) {
                                    .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                                    .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                                },
                                .Rm = shifted_register_explicit.register.alias.encode(.{}),
                                .shift = shifted_register_explicit.shift,
                                .sf = sf,
                            },
                        } } };
                    },
                    .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                        .register = shifted_register.register,
                        .shift = shifted_register.shift,
                        .amount = switch (shifted_register.shift) {
                            .lsl, .lsr, .asr, .ror => |amount| amount,
                        },
                    } },
                }
            },
            .vector => |arrangement| switch (form) {
                else => unreachable,
                .shifted_immediate => |shifted_immediate| {
                    assert(n.alias == d.alias and n.format.vector == arrangement);
                    return .{ .data_processing_vector = .{ .simd_modified_immediate = .{
                        .orr = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .imm5 = @truncate(shifted_immediate.immediate >> 0),
                            .cmode = switch (arrangement) {
                                else => unreachable,
                                .@"4h", .@"8h" => @as(u3, 0b100) |
                                    @as(u3, @as(u1, @intCast(@shrExact(shifted_immediate.lsl, 3)))) << 0,
                                .@"2s", .@"4s" => @as(u3, 0b000) |
                                    @as(u3, @as(u2, @intCast(@shrExact(shifted_immediate.lsl, 3)))) << 0,
                            },
                            .imm3 = @intCast(shifted_immediate.immediate >> 5),
                            .Q = arrangement.size(),
                        },
                    } } };
                },
                .register => |m| {
                    assert(arrangement.elemSize() == .byte and n.format.vector == arrangement and m.format.vector == arrangement);
                    return .{ .data_processing_vector = .{ .simd_three_same = .{
                        .orr = .{
                            .Rd = d.alias.encode(.{ .V = true }),
                            .Rn = n.alias.encode(.{ .V = true }),
                            .Rm = m.alias.encode(.{ .V = true }),
                            .Q = arrangement.size(),
                        },
                    } } };
                },
            },
        }
    }
    /// C6.2.247 PRFM (immediate)
    /// C6.2.248 PRFM (literal)
    /// C6.2.249 PRFM (register)
    pub fn prfm(prfop: LoadStore.PrfOp, form: union(enum) {
        unsigned_offset: struct { base: Register, offset: u15 = 0 },
        base: Register,
        literal: i21,
        extended_register_explicit: struct {
            base: Register,
            index: Register,
            option: LoadStore.RegisterRegisterOffset.Option,
            amount: LoadStore.RegisterRegisterOffset.Extend.Amount,
        },
        extended_register: struct {
            base: Register,
            index: Register,
            extend: LoadStore.RegisterRegisterOffset.Extend,
        },
    }) Instruction {
        form: switch (form) {
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .prfm = .{
                        .prfop = prfop,
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = @intCast(@shrExact(unsigned_offset.offset, 3)),
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            .literal => |offset| return .{ .load_store = .{ .register_literal = .{ .integer = .{
                .prfm = .{
                    .prfop = prfop,
                    .imm19 = @intCast(@shrExact(offset, 2)),
                },
            } } } },
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.base.format.integer == .doubleword and
                    extended_register_explicit.index.format.integer == extended_register_explicit.option.sf());
                return .{ .load_store = .{ .register_register_offset = .{ .integer = .{
                    .prfm = .{
                        .prfop = prfop,
                        .Rn = extended_register_explicit.base.alias.encode(.{ .sp = true }),
                        .S = switch (extended_register_explicit.amount) {
                            0 => false,
                            3 => true,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.index.alias.encode(.{}),
                    },
                } } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .base = extended_register.base,
                .index = extended_register.index,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtw, .lsl, .sxtw, .sxtx => |amount| amount,
                },
            } },
        }
    }
    /// C6.2.253 RBIT
    pub fn rbit(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_one_source = .{
            .rbit = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.254 RET
    pub fn ret(n: Register) Instruction {
        assert(n.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .unconditional_branch_register = .{
            .ret = .{ .Rn = n.alias.encode(.{}) },
        } } };
    }
    /// C6.2.256 REV
    pub fn rev(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_one_source = .{
            .rev = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .opc0 = sf,
                .sf = sf,
            },
        } } };
    }
    /// C6.2.257 REV16
    pub fn rev16(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_one_source = .{
            .rev16 = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.258 REV32
    pub fn rev32(d: Register, n: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_one_source = .{
            .rev32 = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.263 RORV
    pub fn rorv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .rorv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.264 SB
    pub fn sb() Instruction {
        return .{ .branch_exception_generating_system = .{ .barriers = .{
            .sb = .{},
        } } };
    }
    /// C6.2.265 SBC
    pub fn sbc(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .add_subtract_with_carry = .{
            .sbc = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.266 SBCS
    pub fn sbcs(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .add_subtract_with_carry = .{
            .sbcs = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.268 SBFM
    pub fn sbfm(d: Register, n: Register, bitmask: DataProcessingImmediate.Bitmask) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and bitmask.validBitfield(sf));
        return .{ .data_processing_immediate = .{ .bitfield = .{
            .sbfm = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .imm = bitmask,
                .sf = sf,
            },
        } } };
    }
    /// C7.2.236 SCVTF (scalar, integer)
    pub fn scvtf(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .scvtf = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{}),
                .ftype = switch (d.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = n.format.integer,
            },
        } } };
    }
    /// C6.2.270 SDIV
    pub fn sdiv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .sdiv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.280 SEV
    pub fn sev() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .sev = .{},
        } } };
    }
    /// C6.2.281 SEVL
    pub fn sevl() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .sevl = .{},
        } } };
    }
    /// C6.2.282 SMADDL
    pub fn smaddl(d: Register, n: Register, m: Register, a: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .word and m.format.integer == .word and a.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .smaddl = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.283 SMC
    pub fn smc(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .smc = .{ .imm16 = imm },
        } } };
    }
    /// C7.2.279 SMOV
    pub fn smov(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        const vs = n.format.element.size;
        switch (vs) {
            else => unreachable,
            .byte, .half => {},
            .single => assert(sf == .doubleword),
        }
        return .{ .data_processing_vector = .{ .simd_copy = .{
            .smov = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .imm5 = switch (vs) {
                    else => unreachable,
                    .byte => @as(u5, @as(u4, @intCast(n.format.element.index))) << 1 | @as(u5, 0b1) << 0,
                    .half => @as(u5, @as(u3, @intCast(n.format.element.index))) << 2 | @as(u5, 0b10) << 0,
                    .single => @as(u5, @as(u2, @intCast(n.format.element.index))) << 3 | @as(u5, 0b100) << 0,
                },
                .Q = sf,
            },
        } } };
    }
    /// C6.2.287 SMSUBL
    pub fn smsubl(d: Register, n: Register, m: Register, a: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .word and m.format.integer == .word and a.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .smsubl = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.288 SMULH
    pub fn smulh(d: Register, n: Register, m: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .doubleword and m.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .smulh = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.321 STP
    /// C7.2.330 STP (SIMD&FP)
    pub fn stp(t1: Register, t2: Register, form: union(enum) {
        post_index: struct { base: Register, index: i10 },
        pre_index: struct { base: Register, index: i10 },
        signed_offset: struct { base: Register, offset: i10 = 0 },
        base: Register,
    }) Instruction {
        switch (t1.format) {
            else => unreachable,
            .integer => |sf| {
                assert(t2.format.integer == sf);
                form: switch (form) {
                    .post_index => |post_index| {
                        assert(post_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_post_indexed = .{ .integer = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = post_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(post_index.index, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .signed_offset => |signed_offset| {
                        assert(signed_offset.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_offset = .{ .integer = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = signed_offset.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(signed_offset.offset, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .pre_index => |pre_index| {
                        assert(pre_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_pre_indexed = .{ .integer = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{}),
                                .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{}),
                                .imm7 = @intCast(@shrExact(pre_index.index, @as(u2, 2) + @intFromEnum(sf))),
                                .sf = sf,
                            },
                        } } } };
                    },
                    .base => |base| continue :form .{ .signed_offset = .{ .base = base } },
                }
            },
            .scalar => |vs| {
                assert(t2.format.scalar == vs);
                form: switch (form) {
                    .post_index => |post_index| {
                        assert(post_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_post_indexed = .{ .vector = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = post_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(post_index.index, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .signed_offset => |signed_offset| {
                        assert(signed_offset.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_offset = .{ .vector = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = signed_offset.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(signed_offset.offset, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .pre_index => |pre_index| {
                        assert(pre_index.base.format.integer == .doubleword);
                        return .{ .load_store = .{ .register_pair_pre_indexed = .{ .vector = .{
                            .stp = .{
                                .Rt = t1.alias.encode(.{ .V = true }),
                                .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                                .Rt2 = t2.alias.encode(.{ .V = true }),
                                .imm7 = @intCast(@shrExact(pre_index.index, @intFromEnum(vs))),
                                .opc = .encode(vs),
                            },
                        } } } };
                    },
                    .base => |base| continue :form .{ .signed_offset = .{ .base = base } },
                }
            },
        }
    }
    /// C6.2.322 STR (immediate)
    /// C7.2.331 STR (immediate, SIMD&FP)
    pub fn str(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u16 = 0 },
        base: Register,
    }) Instruction {
        switch (t.format) {
            else => unreachable,
            .integer => |sf| form: switch (form) {
                .post_index => |post_index| {
                    assert(post_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                        .str = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = post_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = post_index.index,
                            .sf = sf,
                        },
                    } } } };
                },
                .pre_index => |pre_index| {
                    assert(pre_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                        .str = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = pre_index.index,
                            .sf = sf,
                        },
                    } } } };
                },
                .unsigned_offset => |unsigned_offset| {
                    assert(unsigned_offset.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                        .str = .{
                            .Rt = t.alias.encode(.{}),
                            .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                            .imm12 = @intCast(@shrExact(unsigned_offset.offset, @as(u2, 2) + @intFromEnum(sf))),
                            .sf = sf,
                        },
                    } } } };
                },
                .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            },
            .scalar => |vs| form: switch (form) {
                .post_index => |post_index| {
                    assert(post_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_post_indexed = .{ .vector = .{
                        .str = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = post_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = post_index.index,
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .pre_index => |pre_index| {
                    assert(pre_index.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .vector = .{
                        .str = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                            .imm9 = pre_index.index,
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .unsigned_offset => |unsigned_offset| {
                    assert(unsigned_offset.base.format.integer == .doubleword);
                    return .{ .load_store = .{ .register_unsigned_immediate = .{ .vector = .{
                        .str = .{
                            .Rt = t.alias.encode(.{ .V = true }),
                            .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                            .imm12 = @intCast(@shrExact(unsigned_offset.offset, @intFromEnum(vs))),
                            .opc1 = .encode(vs),
                            .size = .encode(vs),
                        },
                    } } } };
                },
                .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
            },
        }
    }
    /// C6.2.324 STRB (immediate)
    pub fn strb(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u12 = 0 },
        base: Register,
    }) Instruction {
        assert(t.format.integer == .word);
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .strb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .strb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .strb = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = unsigned_offset.offset,
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
        }
    }
    /// C6.2.326 STRH (immediate)
    pub fn strh(t: Register, form: union(enum) {
        post_index: struct { base: Register, index: i9 },
        pre_index: struct { base: Register, index: i9 },
        unsigned_offset: struct { base: Register, offset: u13 = 0 },
        base: Register,
    }) Instruction {
        assert(t.format.integer == .word);
        form: switch (form) {
            .post_index => |post_index| {
                assert(post_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_post_indexed = .{ .integer = .{
                    .strh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = post_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = post_index.index,
                    },
                } } } };
            },
            .pre_index => |pre_index| {
                assert(pre_index.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_immediate_pre_indexed = .{ .integer = .{
                    .strh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = pre_index.base.alias.encode(.{ .sp = true }),
                        .imm9 = pre_index.index,
                    },
                } } } };
            },
            .unsigned_offset => |unsigned_offset| {
                assert(unsigned_offset.base.format.integer == .doubleword);
                return .{ .load_store = .{ .register_unsigned_immediate = .{ .integer = .{
                    .strh = .{
                        .Rt = t.alias.encode(.{}),
                        .Rn = unsigned_offset.base.alias.encode(.{ .sp = true }),
                        .imm12 = @intCast(@shrExact(unsigned_offset.offset, 1)),
                    },
                } } } };
            },
            .base => |base| continue :form .{ .unsigned_offset = .{ .base = base } },
        }
    }
    /// C6.2.346 STUR
    /// C7.2.333 STUR (SIMD&FP)
    pub fn stur(t: Register, n: Register, simm: i9) Instruction {
        assert(n.format.integer == .doubleword);
        switch (t.format) {
            else => unreachable,
            .integer => |sf| return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
                .stur = .{
                    .Rt = t.alias.encode(.{}),
                    .Rn = n.alias.encode(.{ .sp = true }),
                    .imm9 = simm,
                    .sf = sf,
                },
            } } } },
            .scalar => |vs| return .{ .load_store = .{ .register_unscaled_immediate = .{ .vector = .{
                .stur = .{
                    .Rt = t.alias.encode(.{ .V = true }),
                    .Rn = n.alias.encode(.{ .sp = true }),
                    .imm9 = simm,
                    .opc1 = .encode(vs),
                    .size = .encode(vs),
                },
            } } } },
        }
    }
    /// C6.2.347 STURB
    pub fn sturb(t: Register, n: Register, simm: i9) Instruction {
        assert(t.format.integer == .word and n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .sturb = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
            },
        } } } };
    }
    /// C6.2.348 STURH
    pub fn sturh(t: Register, n: Register, simm: i9) Instruction {
        assert(t.format.integer == .word and n.format.integer == .doubleword);
        return .{ .load_store = .{ .register_unscaled_immediate = .{ .integer = .{
            .sturh = .{
                .Rt = t.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .sp = true }),
                .imm9 = simm,
            },
        } } } };
    }
    /// C6.2.356 SUB (extended register)
    /// C6.2.357 SUB (immediate)
    /// C6.2.358 SUB (shifted register)
    pub fn sub(d: Register, n: Register, form: union(enum) {
        extended_register_explicit: struct {
            register: Register,
            option: DataProcessingRegister.AddSubtractExtendedRegister.Option,
            amount: DataProcessingRegister.AddSubtractExtendedRegister.Extend.Amount,
        },
        extended_register: struct { register: Register, extend: DataProcessingRegister.AddSubtractExtendedRegister.Extend },
        immediate: u12,
        shifted_immediate: struct { immediate: u12, lsl: DataProcessingImmediate.AddSubtractImmediate.Shift = .@"0" },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.register.format.integer == extended_register_explicit.option.sf());
                return .{ .data_processing_register = .{ .add_subtract_extended_register = .{
                    .sub = .{
                        .Rd = d.alias.encode(.{ .sp = true }),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm3 = switch (extended_register_explicit.amount) {
                            0...4 => |amount| amount,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.register.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .register = extended_register.register,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx => |amount| amount,
                },
            } },
            .immediate => |immediate| continue :form .{ .shifted_immediate = .{ .immediate = immediate } },
            .shifted_immediate => |shifted_immediate| {
                return .{ .data_processing_immediate = .{ .add_subtract_immediate = .{
                    .sub = .{
                        .Rd = d.alias.encode(.{ .sp = true }),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm12 = shifted_immediate.immediate,
                        .sh = shifted_immediate.lsl,
                        .sf = sf,
                    },
                } } };
            },
            .register => |register| continue :form if (d.alias == .sp or n.alias == .sp or register.alias == .sp)
                .{ .extended_register = .{ .register = register, .extend = switch (sf) {
                    .word => .{ .uxtw = 0 },
                    .doubleword => .{ .uxtx = 0 },
                } } }
            else
                .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .add_subtract_shifted_register = .{
                    .sub = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = switch (shifted_register_explicit.shift) {
                            .lsl, .lsr, .asr => |shift| shift,
                            .ror => unreachable,
                        },
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr => |amount| amount,
                    .ror => unreachable,
                },
            } },
        }
    }
    /// C6.2.362 SUBS (extended register)
    /// C6.2.363 SUBS (immediate)
    /// C6.2.364 SUBS (shifted register)
    pub fn subs(d: Register, n: Register, form: union(enum) {
        extended_register_explicit: struct {
            register: Register,
            option: DataProcessingRegister.AddSubtractExtendedRegister.Option,
            amount: DataProcessingRegister.AddSubtractExtendedRegister.Extend.Amount,
        },
        extended_register: struct { register: Register, extend: DataProcessingRegister.AddSubtractExtendedRegister.Extend },
        immediate: u12,
        shifted_immediate: struct { immediate: u12, lsl: DataProcessingImmediate.AddSubtractImmediate.Shift = .@"0" },
        register: Register,
        shifted_register_explicit: struct { register: Register, shift: DataProcessingRegister.Shift.Op, amount: u6 },
        shifted_register: struct { register: Register, shift: DataProcessingRegister.Shift = .none },
    }) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf);
        form: switch (form) {
            .extended_register_explicit => |extended_register_explicit| {
                assert(extended_register_explicit.register.format.integer == extended_register_explicit.option.sf());
                return .{ .data_processing_register = .{ .add_subtract_extended_register = .{
                    .subs = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm3 = switch (extended_register_explicit.amount) {
                            0...4 => |amount| amount,
                            else => unreachable,
                        },
                        .option = extended_register_explicit.option,
                        .Rm = extended_register_explicit.register.alias.encode(.{}),
                        .sf = sf,
                    },
                } } };
            },
            .extended_register => |extended_register| continue :form .{ .extended_register_explicit = .{
                .register = extended_register.register,
                .option = extended_register.extend,
                .amount = switch (extended_register.extend) {
                    .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx => |amount| amount,
                },
            } },
            .immediate => |immediate| continue :form .{ .shifted_immediate = .{ .immediate = immediate } },
            .shifted_immediate => |shifted_immediate| {
                return .{ .data_processing_immediate = .{ .add_subtract_immediate = .{
                    .subs = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{ .sp = true }),
                        .imm12 = shifted_immediate.immediate,
                        .sh = shifted_immediate.lsl,
                        .sf = sf,
                    },
                } } };
            },
            .register => |register| continue :form if (d.alias == .sp or n.alias == .sp or register.alias == .sp)
                .{ .extended_register = .{ .register = register, .extend = switch (sf) {
                    .word => .{ .uxtw = 0 },
                    .doubleword => .{ .uxtx = 0 },
                } } }
            else
                .{ .shifted_register = .{ .register = register } },
            .shifted_register_explicit => |shifted_register_explicit| {
                assert(shifted_register_explicit.register.format.integer == sf);
                return .{ .data_processing_register = .{ .add_subtract_shifted_register = .{
                    .subs = .{
                        .Rd = d.alias.encode(.{}),
                        .Rn = n.alias.encode(.{}),
                        .imm6 = switch (sf) {
                            .word => @as(u5, @intCast(shifted_register_explicit.amount)),
                            .doubleword => @as(u6, @intCast(shifted_register_explicit.amount)),
                        },
                        .Rm = shifted_register_explicit.register.alias.encode(.{}),
                        .shift = switch (shifted_register_explicit.shift) {
                            .lsl, .lsr, .asr => |shift| shift,
                            .ror => unreachable,
                        },
                        .sf = sf,
                    },
                } } };
            },
            .shifted_register => |shifted_register| continue :form .{ .shifted_register_explicit = .{
                .register = shifted_register.register,
                .shift = shifted_register.shift,
                .amount = switch (shifted_register.shift) {
                    .lsl, .lsr, .asr => |amount| amount,
                    .ror => unreachable,
                },
            } },
        }
    }
    /// C6.2.365 SVC
    pub fn svc(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .svc = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.372 SYS
    pub fn sys(op1: u3, n: u4, m: u4, op2: u3, t: Register) Instruction {
        assert(t.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .system = .{
            .sys = .{
                .Rt = t.alias.encode(.{}),
                .op2 = op2,
                .CRm = m,
                .CRn = n,
                .op1 = op1,
            },
        } } };
    }
    /// C6.2.373 SYSL
    pub fn sysl(t: Register, op1: u3, n: u4, m: u4, op2: u3) Instruction {
        assert(t.format.integer == .doubleword);
        return .{ .branch_exception_generating_system = .{ .system = .{
            .sysl = .{
                .Rt = t.alias.encode(.{}),
                .op2 = op2,
                .CRm = m,
                .CRn = n,
                .op1 = op1,
            },
        } } };
    }
    /// C6.2.374 TBNZ
    pub fn tbnz(t: Register, imm: u6, label: i16) Instruction {
        return .{ .branch_exception_generating_system = .{ .test_branch_immediate = .{
            .tbnz = .{
                .Rt = t.alias.encode(.{}),
                .imm14 = @intCast(@shrExact(label, 2)),
                .b40 = @truncate(switch (t.format.integer) {
                    .word => @as(u5, @intCast(imm)),
                    .doubleword => imm,
                }),
                .b5 = @intCast(imm >> 5),
            },
        } } };
    }
    /// C6.2.375 TBZ
    pub fn tbz(t: Register, imm: u6, label: i16) Instruction {
        return .{ .branch_exception_generating_system = .{ .test_branch_immediate = .{
            .tbz = .{
                .Rt = t.alias.encode(.{}),
                .imm14 = @intCast(@shrExact(label, 2)),
                .b40 = @truncate(switch (t.format.integer) {
                    .word => @as(u5, @intCast(imm)),
                    .doubleword => imm,
                }),
                .b5 = @intCast(imm >> 5),
            },
        } } };
    }
    /// C6.2.376 TCANCEL
    pub fn tcancel(imm: u16) Instruction {
        return .{ .branch_exception_generating_system = .{ .exception_generating = .{
            .tcancel = .{ .imm16 = imm },
        } } };
    }
    /// C6.2.385 UBFM
    pub fn ubfm(d: Register, n: Register, bitmask: DataProcessingImmediate.Bitmask) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and bitmask.validBitfield(sf));
        return .{ .data_processing_immediate = .{ .bitfield = .{
            .ubfm = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .imm = bitmask,
                .sf = sf,
            },
        } } };
    }
    /// C7.2.355 UCVTF (scalar, integer)
    pub fn ucvtf(d: Register, n: Register) Instruction {
        return .{ .data_processing_vector = .{ .convert_float_integer = .{
            .ucvtf = .{
                .Rd = d.alias.encode(.{ .V = true }),
                .Rn = n.alias.encode(.{}),
                .ftype = switch (d.format.scalar) {
                    else => unreachable,
                    .single => .single,
                    .double => .double,
                    .half => .half,
                },
                .sf = n.format.integer,
            },
        } } };
    }
    /// C6.2.387 UDF
    pub fn udf(imm: u16) Instruction {
        return .{ .reserved = .{
            .udf = .{ .imm16 = imm },
        } };
    }
    /// C6.2.388 UDIV
    pub fn udiv(d: Register, n: Register, m: Register) Instruction {
        const sf = d.format.integer;
        assert(n.format.integer == sf and m.format.integer == sf);
        return .{ .data_processing_register = .{ .data_processing_two_source = .{
            .udiv = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
                .sf = sf,
            },
        } } };
    }
    /// C6.2.389 UMADDL
    pub fn umaddl(d: Register, n: Register, m: Register, a: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .word and m.format.integer == .word and a.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .umaddl = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.391 UMSUBL
    pub fn umsubl(d: Register, n: Register, m: Register, a: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .word and m.format.integer == .word and a.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .umsubl = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Ra = a.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C7.2.371 UMOV
    pub fn umov(d: Register, n: Register) Instruction {
        const sf = d.format.integer;
        const vs = n.format.element.size;
        switch (vs) {
            else => unreachable,
            .byte, .half, .single => assert(sf == .word),
            .double => assert(sf == .doubleword),
        }
        return .{ .data_processing_vector = .{ .simd_copy = .{
            .umov = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{ .V = true }),
                .imm5 = switch (vs) {
                    else => unreachable,
                    .byte => @as(u5, @as(u4, @intCast(n.format.element.index))) << 1 | @as(u5, 0b1) << 0,
                    .half => @as(u5, @as(u3, @intCast(n.format.element.index))) << 2 | @as(u5, 0b10) << 0,
                    .single => @as(u5, @as(u2, @intCast(n.format.element.index))) << 3 | @as(u5, 0b100) << 0,
                    .double => @as(u5, @as(u1, @intCast(n.format.element.index))) << 4 | @as(u5, 0b1000) << 0,
                },
                .Q = sf,
            },
        } } };
    }
    /// C6.2.392 UMULH
    pub fn umulh(d: Register, n: Register, m: Register) Instruction {
        assert(d.format.integer == .doubleword and n.format.integer == .doubleword and m.format.integer == .doubleword);
        return .{ .data_processing_register = .{ .data_processing_three_source = .{
            .umulh = .{
                .Rd = d.alias.encode(.{}),
                .Rn = n.alias.encode(.{}),
                .Rm = m.alias.encode(.{}),
            },
        } } };
    }
    /// C6.2.396 WFE
    pub fn wfe() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .wfe = .{},
        } } };
    }
    /// C6.2.398 WFI
    pub fn wfi() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .wfi = .{},
        } } };
    }
    /// C6.2.402 YIELD
    pub fn yield() Instruction {
        return .{ .branch_exception_generating_system = .{ .hints = .{
            .yield = .{},
        } } };
    }

    pub const size = @divExact(@bitSizeOf(Backing), 8);
    pub const Backing = u32;
    pub fn read(mem: *const [size]u8) Instruction {
        return @bitCast(std.mem.readInt(Backing, mem, .little));
    }
    pub fn write(inst: Instruction, mem: *[size]u8) void {
        std.mem.writeInt(Backing, mem, @bitCast(inst), .little);
    }

    pub fn format(inst: Instruction, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const dis: aarch64.Disassemble = .{};
        try dis.printInstruction(inst, writer);
    }

    comptime {
        @setEvalBranchQuota(68_000);
        verify(@typeName(Instruction), Instruction);
    }
    fn verify(name: []const u8, Type: type) void {
        switch (@typeInfo(Type)) {
            .@"union" => |info| {
                if (info.layout != .@"packed" or @bitSizeOf(Type) != @bitSizeOf(Backing)) {
                    @compileLog(name ++ " should have u32 abi");
                }
                for (info.fields) |field| verify(name ++ "." ++ field.name, field.type);
            },
            .@"struct" => |info| {
                if (info.layout != .@"packed" or info.backing_integer != Backing) {
                    @compileLog(name ++ " should have u32 abi");
                }
                var bit_offset = 0;
                for (info.fields) |field| {
                    if (std.mem.startsWith(u8, field.name, "encoded")) {
                        if (if (std.fmt.parseInt(u5, field.name["encoded".len..], 10)) |encoded_bit_offset| encoded_bit_offset != bit_offset else |_| true) {
                            @compileError(std.fmt.comptimePrint("{s}.{s} should be named encoded{d}", .{ name, field.name, bit_offset }));
                        }
                        if (field.default_value_ptr != null) {
                            @compileError(std.fmt.comptimePrint("{s}.{s} should be named decoded{d}", .{ name, field.name, bit_offset }));
                        }
                    } else if (std.mem.startsWith(u8, field.name, "decoded")) {
                        if (if (std.fmt.parseInt(u5, field.name["decoded".len..], 10)) |decoded_bit_offset| decoded_bit_offset != bit_offset else |_| true) {
                            @compileError(std.fmt.comptimePrint("{s}.{s} should be named decoded{d}", .{ name, field.name, bit_offset }));
                        }
                        if (field.default_value_ptr == null) {
                            @compileError(std.fmt.comptimePrint("{s}.{s} should be named encoded{d}", .{ name, field.name, bit_offset }));
                        }
                    }
                    bit_offset += @bitSizeOf(field.type);
                }
            },
            else => @compileError(name ++ " has an unexpected field type"),
        }
    }
};

const aarch64 = @import("../aarch64.zig");
const assert = std.debug.assert;
const std = @import("std");
