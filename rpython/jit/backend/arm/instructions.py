load_store = {
    'STR_ri': {'A': 0, 'op1': 0x0, 'op1not': 0x2, 'imm': True},
    'STR_rr': {'A': 1, 'op1': 0x0, 'op1not': 0x2, 'B': 0, 'imm': False},
    'LDR_ri': {'A': 0, 'op1': 0x1, 'op1not': 0x3, 'imm': True},
    'LDR_rr': {'A': 1, 'op1': 0x1, 'op1not': 0x3, 'B': 0, 'imm': False},
    'STRB_ri': {'A': 0, 'op1': 0x4, 'op1not': 0x6, 'rn': '!0xF', 'imm': True},
    'STRB_rr': {'A': 1, 'op1': 0x4, 'op1not': 0x6, 'B': 0, 'imm': False},
    'LDRB_ri': {'A': 0, 'op1': 0x5, 'op1not': 0x7, 'rn': '!0xF', 'imm': True},
    'LDRB_rr': {'A': 1, 'op1': 0x5, 'op1not': 0x7, 'B': 0, 'imm': False},
}
extra_load_store = {  # Section 5.2.8
    'STRH_rr':  {'op2': 0x1, 'op1': 0x0},
    'LDRH_rr':  {'op2': 0x1, 'op1': 0x1},
    'STRH_ri':  {'op2': 0x1, 'op1': 0x4},
    'LDRH_ri':  {'op2': 0x1, 'op1': 0x5, 'rn': '!0xF'},
    'LDRD_rr':  {'op2': 0x2, 'op1': 0x0},
    'LDRSB_rr': {'op2': 0x2, 'op1': 0x1},
    'LDRD_ri':  {'op2': 0x2, 'op1': 0x4},
    'LDRSB_ri': {'op2': 0x2, 'op1': 0x5, 'rn': '!0xF'},
    'STRD_rr':  {'op2': 0x3, 'op1': 0x0},
    'LDRSH_rr': {'op2': 0x3, 'op1': 0x1},
    'STRD_ri':  {'op2': 0x3, 'op1': 0x4},
    'LDRSH_ri': {'op2': 0x3, 'op1': 0x5, 'rn': '!0xF'},
}


data_proc = {
    'AND_rr': {'op1': 0x0, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'EOR_rr': {'op1': 0x2, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'SUB_rr': {'op1': 0x4, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'RSB_rr': {'op1': 0x6, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'ADD_rr': {'op1': 0x8, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'ADC_rr': {'op1': 0xA, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'SBC_rr': {'op1': 0xC, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'RSC_rr': {'op1': 0xE, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'TST_rr': {'op1': 0x11, 'op2': 0, 'op3': 0, 'result': False, 'base': True},
    'TEQ_rr': {'op1': 0x13, 'op2': 0, 'op3': 0, 'result': False, 'base': True},
    'CMP_rr': {'op1': 0x15, 'op2': 0, 'op3': 0, 'result': False, 'base': True},
    'CMN_rr': {'op1': 0x17, 'op2': 0, 'op3': 0, 'result': False, 'base': True},
    'ORR_rr': {'op1': 0x18, 'op2': 0, 'op3': 0, 'result': True, 'base': True},
    'MOV_rr': {'op1': 0x1A, 'op2': 0, 'op3': 0, 'result': True, 'base': False},
    'LSL_ri': {'op1': 0x1A, 'op2': 0x0, 'op3': 0, 'op2cond': '!0',
                                                'result': False, 'base': True},
    'LSR_ri': {'op1': 0x1A, 'op2': 0, 'op3': 0x1, 'op2cond': '',
                                                'result': False, 'base': True},
    'ASR_ri': {'op1': 0x1A, 'op2': 0, 'op3': 0x2, 'op2cond': '',
                                                'result': False, 'base': True},
    'ROR_ri': {'op1': 0x1A, 'op2': 0x0, 'op3': 0x3, 'op2cond': '!0',
                                                'result': True, 'base': False},
    'MVN_rr': {'op1': 0x1E, 'op2': 0x0, 'op3': 0x0, 'result': True,
                                                                'base': False},

}

data_proc_reg_shift_reg = {
    'AND_rr_sr': {'op1': 0x0,  'op2': 0},
    'EOR_rr_sr': {'op1': 0x2,  'op2': 0},
    'SUB_rr_sr': {'op1': 0x4,  'op2': 0},
    'RSB_rr_sr': {'op1': 0x6,  'op2': 0},
    'ADD_rr_sr': {'op1': 0x8,  'op2': 0},
    'ADC_rr_sr': {'op1': 0xA,  'op2': 0},
    'SBC_rr_sr': {'op1': 0xC,  'op2': 0},
    'RSC_rr_sr': {'op1': 0xE,  'op2': 0},
    'TST_rr_sr': {'op1': 0x11, 'op2': 0, 'result': False},
    'TEQ_rr_sr': {'op1': 0x13, 'op2': 0, 'result': False},
    'CMP_rr_sr': {'op1': 0x15, 'op2': 0, 'result': False},
    'CMN_rr_sr': {'op1': 0x17, 'op2': 0, 'result': False},
    'ORR_rr_sr': {'op1': 0x18, 'op2': 0},
    'LSL_rr': {'op1': 0x1A, 'op2': 0, },
    'LSR_rr': {'op1': 0x1A, 'op2': 0x1},
    'ASR_rr': {'op1': 0x1A, 'op2': 0x2},
    'ROR_rr': {'op1': 0x1A, 'op2': 0x3},
}

data_proc_imm = {
    'AND_ri': {'op': 0, 'result': True, 'base': True},
    'EOR_ri': {'op': 0x2, 'result': True, 'base': True},
    'SUB_ri': {'op': 0x4, 'result': True, 'base': True},
    'RSB_ri': {'op': 0x6, 'result': True, 'base': True},
    'ADD_ri': {'op': 0x8, 'result': True, 'base': True},
    'ADC_ri': {'op': 0xA, 'result': True, 'base': True},
    'SBC_ri': {'op': 0xC, 'result': True, 'base': True},
    'RSC_ri': {'op': 0xE, 'result': True, 'base': True},
    'TST_ri': {'op': 0x11, 'result': False, 'base': True},
    'TEQ_ri': {'op': 0x13, 'result': False, 'base': True},
    'CMP_ri': {'op': 0x15, 'result': False, 'base': True},
    'CMN_ri': {'op': 0x17, 'result': False, 'base': True},
    'ORR_ri': {'op': 0x18, 'result': True, 'base': True},
    'MOV_ri': {'op': 0x1A, 'result': True, 'base': False},
    'BIC_ri': {'op': 0x1C, 'result': True, 'base': True},
    'MVN_ri': {'op': 0x1E, 'result': True, 'base': False},
}

supervisor_and_coproc = {
    'MCR': {'op1': 0x20, 'op': 1, 'rn':0, 'coproc':0},
    'MRC': {'op1': 0x21, 'op': 1, 'rn':0, 'coproc':0},
}

block_data = {
    'STMDA': {'op': 0x0},
    'LDMDA': {'op': 0x1},
    'STMIA': {'op': 0x8},
    'LDMDB': {'op': 0x11},
    'STMIB': {'op': 0x18},
    'LDMIB': {'op': 0x19},
    #'STM':   {'op': 0x4},
    #'LDM':   {'op': 0x5},
}
branch = {
    'B':     {'op': 0x20},
    'BL':    {'op': 0x30},
}

multiply = {
    'MUL':   {'op':0x0},
    'MLA':   {'op':0x2, 'acc': True, 'update_flags':True},
    'UMAAL': {'op':0x4, 'long': True},
    'MLS':   {'op':0x6, 'acc': True},
    'UMULL': {'op':0x8, 'long': True},
    'UMLAL': {'op':0xA, 'long': True},
    'SMULL': {'op':0xC, 'long': True},
    'SMLAL': {'op':0xE, 'long': True},
}

float_load_store = {
    'VSTR':    {'opcode': 0x10},
    'VLDR':    {'opcode': 0x11},
}


# based on encoding from A7.5 VFP data-processing instructions
# opc2 is one of the parameters and therefore ignored here
float64_data_proc_instructions = {
    'VADD'  : {'opc1':0x3, 'opc3':0x0},
    'VSUB'  : {'opc1':0x3, 'opc3':0x1},
    'VMUL'  : {'opc1':0x2, 'opc3':0x0},
    'VDIV'  : {'opc1':0x8, 'opc3':0x0},
    'VCMP'  : {'opc1':0xB, 'opc2':0x4, 'opc3':0x1, 'result': False},
    'VNEG'  : {'opc1':0xB, 'opc2':0x1, 'opc3':0x1, 'base': False},
    'VABS'  : {'opc1':0xB, 'opc2':0x0, 'opc3':0x3, 'base': False},
    'VSQRT' : {'opc1':0xB, 'opc2':0x1, 'opc3':0x3, 'base': False},
    #'VCVT' : {'opc1':0xB, 'opc2':0xE, 'opc3':0x1, 'base': False},
}

# ARMv7 only
simd_instructions_3regs = {
    'VADD_i64': {'A': 0x8, 'B': 0, 'U': 0},
    'VSUB_i64': {'A': 0x8, 'B': 0, 'U': 1},
    'VAND_i64': {'A': 0x1, 'B': 1, 'U': 0, 'C': 0},
    'VORR_i64': {'A': 0x1, 'B': 1, 'U': 0, 'C': 0x2},
    'VEOR_i64': {'A': 0x1, 'B': 1, 'U': 1, 'C': 0x0},
}
