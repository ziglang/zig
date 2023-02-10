#ifndef WASM_H
#define WASM_H

#include "panic.h"

enum WasmSectionId {
    WasmSectionId_type      =  1,
    WasmSectionId_import    =  2,
    WasmSectionId_func      =  3,
    WasmSectionId_table     =  4,
    WasmSectionId_mem       =  5,
    WasmSectionId_global    =  6,
    WasmSectionId_export    =  7,
    WasmSectionId_start     =  8,
    WasmSectionId_elem      =  9,
    WasmSectionId_code      = 10,
    WasmSectionId_data      = 11,
    WasmSectionId_datacount = 12,
};

enum WasmValType {
    WasmValType_i32       = -0x01,
    WasmValType_i64       = -0x02,
    WasmValType_f32       = -0x03,
    WasmValType_f64       = -0x04,
    WasmValType_v128      = -0x05,
    WasmValType_funcref   = -0x10,
    WasmValType_externref = -0x11,
    WasmValType_empty     = -0x40,
};
static const char *WasmValType_toC(enum WasmValType val_type) {
    switch (val_type) {
        case WasmValType_i32: return "uint32_t";
        case WasmValType_i64: return "uint64_t";
        case WasmValType_f32: return "float";
        case WasmValType_f64: return "double";
        case WasmValType_v128: panic("vector types are unsupported");
        case WasmValType_funcref: return "void (*)(void)";
        case WasmValType_externref: return "void *";
        default: panic("unsupported value type");
    }
    return NULL;
}

enum WasmMut {
    WasmMut_const = 0x00,
    WasmMut_var   = 0x01,
};
static const char *WasmMut_toC(enum WasmMut val_type) {
    switch (val_type) {
        case WasmMut_const: return "const ";
        case WasmMut_var: return "";
        default: panic("unsupported mut");
    }
}

enum WasmOpcode {
    WasmOpcode_unreachable         = 0x00,
    WasmOpcode_nop                 = 0x01,
    WasmOpcode_block               = 0x02,
    WasmOpcode_loop                = 0x03,
    WasmOpcode_if                  = 0x04,
    WasmOpcode_else                = 0x05,
    WasmOpcode_end                 = 0x0B,
    WasmOpcode_br                  = 0x0C,
    WasmOpcode_br_if               = 0x0D,
    WasmOpcode_br_table            = 0x0E,
    WasmOpcode_return              = 0x0F,
    WasmOpcode_call                = 0x10,
    WasmOpcode_call_indirect       = 0x11,

    WasmOpcode_drop                = 0x1A,
    WasmOpcode_select              = 0x1B,
    WasmOpcode_select_t            = 0x1C,

    WasmOpcode_local_get           = 0x20,
    WasmOpcode_local_set           = 0x21,
    WasmOpcode_local_tee           = 0x22,
    WasmOpcode_global_get          = 0x23,
    WasmOpcode_global_set          = 0x24,

    WasmOpcode_table_get           = 0x25,
    WasmOpcode_table_set           = 0x26,

    WasmOpcode_i32_load            = 0x28,
    WasmOpcode_i64_load            = 0x29,
    WasmOpcode_f32_load            = 0x2A,
    WasmOpcode_f64_load            = 0x2B,
    WasmOpcode_i32_load8_s         = 0x2C,
    WasmOpcode_i32_load8_u         = 0x2D,
    WasmOpcode_i32_load16_s        = 0x2E,
    WasmOpcode_i32_load16_u        = 0x2F,
    WasmOpcode_i64_load8_s         = 0x30,
    WasmOpcode_i64_load8_u         = 0x31,
    WasmOpcode_i64_load16_s        = 0x32,
    WasmOpcode_i64_load16_u        = 0x33,
    WasmOpcode_i64_load32_s        = 0x34,
    WasmOpcode_i64_load32_u        = 0x35,
    WasmOpcode_i32_store           = 0x36,
    WasmOpcode_i64_store           = 0x37,
    WasmOpcode_f32_store           = 0x38,
    WasmOpcode_f64_store           = 0x39,
    WasmOpcode_i32_store8          = 0x3A,
    WasmOpcode_i32_store16         = 0x3B,
    WasmOpcode_i64_store8          = 0x3C,
    WasmOpcode_i64_store16         = 0x3D,
    WasmOpcode_i64_store32         = 0x3E,
    WasmOpcode_memory_size         = 0x3F,
    WasmOpcode_memory_grow         = 0x40,

    WasmOpcode_i32_const           = 0x41,
    WasmOpcode_i64_const           = 0x42,
    WasmOpcode_f32_const           = 0x43,
    WasmOpcode_f64_const           = 0x44,

    WasmOpcode_i32_eqz             = 0x45,
    WasmOpcode_i32_eq              = 0x46,
    WasmOpcode_i32_ne              = 0x47,
    WasmOpcode_i32_lt_s            = 0x48,
    WasmOpcode_i32_lt_u            = 0x49,
    WasmOpcode_i32_gt_s            = 0x4A,
    WasmOpcode_i32_gt_u            = 0x4B,
    WasmOpcode_i32_le_s            = 0x4C,
    WasmOpcode_i32_le_u            = 0x4D,
    WasmOpcode_i32_ge_s            = 0x4E,
    WasmOpcode_i32_ge_u            = 0x4F,

    WasmOpcode_i64_eqz             = 0x50,
    WasmOpcode_i64_eq              = 0x51,
    WasmOpcode_i64_ne              = 0x52,
    WasmOpcode_i64_lt_s            = 0x53,
    WasmOpcode_i64_lt_u            = 0x54,
    WasmOpcode_i64_gt_s            = 0x55,
    WasmOpcode_i64_gt_u            = 0x56,
    WasmOpcode_i64_le_s            = 0x57,
    WasmOpcode_i64_le_u            = 0x58,
    WasmOpcode_i64_ge_s            = 0x59,
    WasmOpcode_i64_ge_u            = 0x5A,

    WasmOpcode_f32_eq              = 0x5B,
    WasmOpcode_f32_ne              = 0x5C,
    WasmOpcode_f32_lt              = 0x5D,
    WasmOpcode_f32_gt              = 0x5E,
    WasmOpcode_f32_le              = 0x5F,
    WasmOpcode_f32_ge              = 0x60,

    WasmOpcode_f64_eq              = 0x61,
    WasmOpcode_f64_ne              = 0x62,
    WasmOpcode_f64_lt              = 0x63,
    WasmOpcode_f64_gt              = 0x64,
    WasmOpcode_f64_le              = 0x65,
    WasmOpcode_f64_ge              = 0x66,

    WasmOpcode_i32_clz             = 0x67,
    WasmOpcode_i32_ctz             = 0x68,
    WasmOpcode_i32_popcnt          = 0x69,
    WasmOpcode_i32_add             = 0x6A,
    WasmOpcode_i32_sub             = 0x6B,
    WasmOpcode_i32_mul             = 0x6C,
    WasmOpcode_i32_div_s           = 0x6D,
    WasmOpcode_i32_div_u           = 0x6E,
    WasmOpcode_i32_rem_s           = 0x6F,
    WasmOpcode_i32_rem_u           = 0x70,
    WasmOpcode_i32_and             = 0x71,
    WasmOpcode_i32_or              = 0x72,
    WasmOpcode_i32_xor             = 0x73,
    WasmOpcode_i32_shl             = 0x74,
    WasmOpcode_i32_shr_s           = 0x75,
    WasmOpcode_i32_shr_u           = 0x76,
    WasmOpcode_i32_rotl            = 0x77,
    WasmOpcode_i32_rotr            = 0x78,

    WasmOpcode_i64_clz             = 0x79,
    WasmOpcode_i64_ctz             = 0x7A,
    WasmOpcode_i64_popcnt          = 0x7B,
    WasmOpcode_i64_add             = 0x7C,
    WasmOpcode_i64_sub             = 0x7D,
    WasmOpcode_i64_mul             = 0x7E,
    WasmOpcode_i64_div_s           = 0x7F,
    WasmOpcode_i64_div_u           = 0x80,
    WasmOpcode_i64_rem_s           = 0x81,
    WasmOpcode_i64_rem_u           = 0x82,
    WasmOpcode_i64_and             = 0x83,
    WasmOpcode_i64_or              = 0x84,
    WasmOpcode_i64_xor             = 0x85,
    WasmOpcode_i64_shl             = 0x86,
    WasmOpcode_i64_shr_s           = 0x87,
    WasmOpcode_i64_shr_u           = 0x88,
    WasmOpcode_i64_rotl            = 0x89,
    WasmOpcode_i64_rotr            = 0x8A,

    WasmOpcode_f32_abs             = 0x8B,
    WasmOpcode_f32_neg             = 0x8C,
    WasmOpcode_f32_ceil            = 0x8D,
    WasmOpcode_f32_floor           = 0x8E,
    WasmOpcode_f32_trunc           = 0x8F,
    WasmOpcode_f32_nearest         = 0x90,
    WasmOpcode_f32_sqrt            = 0x91,
    WasmOpcode_f32_add             = 0x92,
    WasmOpcode_f32_sub             = 0x93,
    WasmOpcode_f32_mul             = 0x94,
    WasmOpcode_f32_div             = 0x95,
    WasmOpcode_f32_min             = 0x96,
    WasmOpcode_f32_max             = 0x97,
    WasmOpcode_f32_copysign        = 0x98,

    WasmOpcode_f64_abs             = 0x99,
    WasmOpcode_f64_neg             = 0x9A,
    WasmOpcode_f64_ceil            = 0x9B,
    WasmOpcode_f64_floor           = 0x9C,
    WasmOpcode_f64_trunc           = 0x9D,
    WasmOpcode_f64_nearest         = 0x9E,
    WasmOpcode_f64_sqrt            = 0x9F,
    WasmOpcode_f64_add             = 0xA0,
    WasmOpcode_f64_sub             = 0xA1,
    WasmOpcode_f64_mul             = 0xA2,
    WasmOpcode_f64_div             = 0xA3,
    WasmOpcode_f64_min             = 0xA4,
    WasmOpcode_f64_max             = 0xA5,
    WasmOpcode_f64_copysign        = 0xA6,

    WasmOpcode_i32_wrap_i64        = 0xA7,
    WasmOpcode_i32_trunc_f32_s     = 0xA8,
    WasmOpcode_i32_trunc_f32_u     = 0xA9,
    WasmOpcode_i32_trunc_f64_s     = 0xAA,
    WasmOpcode_i32_trunc_f64_u     = 0xAB,
    WasmOpcode_i64_extend_i32_s    = 0xAC,
    WasmOpcode_i64_extend_i32_u    = 0xAD,
    WasmOpcode_i64_trunc_f32_s     = 0xAE,
    WasmOpcode_i64_trunc_f32_u     = 0xAF,
    WasmOpcode_i64_trunc_f64_s     = 0xB0,
    WasmOpcode_i64_trunc_f64_u     = 0xB1,
    WasmOpcode_f32_convert_i32_s   = 0xB2,
    WasmOpcode_f32_convert_i32_u   = 0xB3,
    WasmOpcode_f32_convert_i64_s   = 0xB4,
    WasmOpcode_f32_convert_i64_u   = 0xB5,
    WasmOpcode_f32_demote_f64      = 0xB6,
    WasmOpcode_f64_convert_i32_s   = 0xB7,
    WasmOpcode_f64_convert_i32_u   = 0xB8,
    WasmOpcode_f64_convert_i64_s   = 0xB9,
    WasmOpcode_f64_convert_i64_u   = 0xBA,
    WasmOpcode_f64_promote_f32     = 0xBB,
    WasmOpcode_i32_reinterpret_f32 = 0xBC,
    WasmOpcode_i64_reinterpret_f64 = 0xBD,
    WasmOpcode_f32_reinterpret_i32 = 0xBE,
    WasmOpcode_f64_reinterpret_i64 = 0xBF,

    WasmOpcode_i32_extend8_s       = 0xC0,
    WasmOpcode_i32_extend16_s      = 0xC1,
    WasmOpcode_i64_extend8_s       = 0xC2,
    WasmOpcode_i64_extend16_s      = 0xC3,
    WasmOpcode_i64_extend32_s      = 0xC4,

    WasmOpcode_prefixed            = 0xFC,
};

enum WasmPrefixedOpcode {
    WasmPrefixedOpcode_i32_trunc_sat_f32_s =  0,
    WasmPrefixedOpcode_i32_trunc_sat_f32_u =  1,
    WasmPrefixedOpcode_i32_trunc_sat_f64_s =  2,
    WasmPrefixedOpcode_i32_trunc_sat_f64_u =  3,
    WasmPrefixedOpcode_i64_trunc_sat_f32_s =  4,
    WasmPrefixedOpcode_i64_trunc_sat_f32_u =  5,
    WasmPrefixedOpcode_i64_trunc_sat_f64_s =  6,
    WasmPrefixedOpcode_i64_trunc_sat_f64_u =  7,

    WasmPrefixedOpcode_memory_init         =  8,
    WasmPrefixedOpcode_data_drop           =  9,
    WasmPrefixedOpcode_memory_copy         = 10,
    WasmPrefixedOpcode_memory_fill         = 11,

    WasmPrefixedOpcode_table_init          = 12,
    WasmPrefixedOpcode_elem_drop           = 13,
    WasmPrefixedOpcode_table_copy          = 14,
    WasmPrefixedOpcode_table_grow          = 15,
    WasmPrefixedOpcode_table_size          = 16,
    WasmPrefixedOpcode_table_fill          = 17,
};

#endif /* WASM_H */
