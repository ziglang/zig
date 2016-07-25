/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "parser.hpp"
#include "errmsg.hpp"
#include "analyze.hpp"

#include <stdarg.h>
#include <stdio.h>
#include <limits.h>
#include <errno.h>

struct ParseContext {
    Buf *buf;
    AstNode *root;
    ZigList<Token> *tokens;
    ImportTableEntry *owner;
    ErrColor err_color;
    uint32_t *next_node_index;
};

__attribute__ ((format (printf, 4, 5)))
__attribute__ ((noreturn))
static void ast_asm_error(ParseContext *pc, AstNode *node, int offset, const char *format, ...) {
    assert(node->type == NodeTypeAsmExpr);


    SrcPos pos = node->data.asm_expr.offset_map.at(offset);

    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);

    ErrorMsg *err = err_msg_create_with_line(pc->owner->path, pos.line, pos.column,
            pc->owner->source_code, pc->owner->line_offsets, msg);

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

__attribute__ ((format (printf, 3, 4)))
__attribute__ ((noreturn))
static void ast_error(ParseContext *pc, Token *token, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    Buf *msg = buf_vprintf(format, ap);
    va_end(ap);


    ErrorMsg *err = err_msg_create_with_line(pc->owner->path, token->start_line, token->start_column,
            pc->owner->source_code, pc->owner->line_offsets, msg);
    err->line_start = token->start_line;
    err->column_start = token->start_column;

    print_err_msg(err, pc->err_color);
    exit(EXIT_FAILURE);
}

static AstNode *ast_create_node_no_line_info(ParseContext *pc, NodeType type) {
    AstNode *node = allocate<AstNode>(1);
    node->type = type;
    node->owner = pc->owner;
    node->create_index = *pc->next_node_index;
    *pc->next_node_index += 1;
    return node;
}

static void ast_update_node_line_info(AstNode *node, Token *first_token) {
    node->line = first_token->start_line;
    node->column = first_token->start_column;
}

static AstNode *ast_create_node(ParseContext *pc, NodeType type, Token *first_token) {
    AstNode *node = ast_create_node_no_line_info(pc, type);
    ast_update_node_line_info(node, first_token);
    return node;
}

static AstNode *ast_create_void_type_node(ParseContext *pc, Token *token) {
    AstNode *node = ast_create_node(pc, NodeTypeSymbol, token);
    buf_init_from_str(&node->data.symbol_expr.symbol, "void");
    return node;
}

static void parse_asm_template(ParseContext *pc, AstNode *node) {
    Buf *asm_template = &node->data.asm_expr.asm_template;

    enum State {
        StateStart,
        StatePercent,
        StateTemplate,
        StateVar,
    };

    ZigList<AsmToken> *tok_list = &node->data.asm_expr.token_list;
    assert(tok_list->length == 0);

    AsmToken *cur_tok = nullptr;

    enum State state = StateStart;

    for (int i = 0; i < buf_len(asm_template); i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(asm_template) + i);
        switch (state) {
            case StateStart:
                if (c == '%') {
                    tok_list->add_one();
                    cur_tok = &tok_list->last();
                    cur_tok->id = AsmTokenIdPercent;
                    cur_tok->start = i;
                    state = StatePercent;
                } else {
                    tok_list->add_one();
                    cur_tok = &tok_list->last();
                    cur_tok->id = AsmTokenIdTemplate;
                    cur_tok->start = i;
                    state = StateTemplate;
                }
                break;
            case StatePercent:
                if (c == '%') {
                    cur_tok->end = i;
                    state = StateStart;
                } else if (c == '[') {
                    cur_tok->id = AsmTokenIdVar;
                    state = StateVar;
                } else {
                    ast_asm_error(pc, node, i, "expected a '%%' or '['");
                }
                break;
            case StateTemplate:
                if (c == '%') {
                    cur_tok->end = i;
                    i -= 1;
                    cur_tok = nullptr;
                    state = StateStart;
                }
                break;
            case StateVar:
                if (c == ']') {
                    cur_tok->end = i;
                    state = StateStart;
                } else if ((c >= 'a' && c <= 'z') ||
                        (c >= '0' && c <= '9') ||
                        (c == '_'))
                {
                    // do nothing
                } else {
                    ast_asm_error(pc, node, i, "invalid substitution character: '%c'", c);
                }
                break;
        }
    }

    switch (state) {
        case StateStart:
            break;
        case StatePercent:
        case StateVar:
            ast_asm_error(pc, node, buf_len(asm_template), "unexpected end of assembly template");
            break;
        case StateTemplate:
            cur_tok->end = buf_len(asm_template);
            break;
    }
}

static uint8_t parse_char_literal(ParseContext *pc, Token *token) {
    // skip the single quotes at beginning and end
    // convert escape sequences
    bool escape = false;
    int return_count = 0;
    uint8_t return_value;
    for (int i = token->start_pos + 1; i < token->end_pos - 1; i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);
        if (escape) {
            switch (c) {
                case '\\':
                    return_value = '\\';
                    return_count += 1;
                    break;
                case 'r':
                    return_value = '\r';
                    return_count += 1;
                    break;
                case 'n':
                    return_value = '\n';
                    return_count += 1;
                    break;
                case 't':
                    return_value = '\t';
                    return_count += 1;
                    break;
                case '\'':
                    return_value = '\'';
                    return_count += 1;
                    break;
                default:
                    ast_error(pc, token, "invalid escape character");
            }
            escape = false;
        } else if (c == '\\') {
            escape = true;
        } else {
            return_value = c;
            return_count += 1;
        }
    }
    if (return_count == 0) {
        ast_error(pc, token, "character literal too short");
    } else if (return_count > 1) {
        ast_error(pc, token, "character literal too long");
    }
    return return_value;
}

static uint32_t get_hex_digit(uint8_t c) {
    switch (c) {
        case '0': return 0;
        case '1': return 1;
        case '2': return 2;
        case '3': return 3;
        case '4': return 4;
        case '5': return 5;
        case '6': return 6;
        case '7': return 7;
        case '8': return 8;
        case '9': return 9;

        case 'a':
        case 'A':
            return 10;
        case 'b':
        case 'B':
            return 11;
        case 'c':
        case 'C':
            return 12;
        case 'd':
        case 'D':
            return 13;
        case 'e':
        case 'E':
            return 14;
        case 'f':
        case 'F':
            return 15;
        default:
            return UINT32_MAX;
    }
}

static void parse_string_literal(ParseContext *pc, Token *token, Buf *buf, bool *out_c_str,
        ZigList<SrcPos> *offset_map)
{
    if (token->raw_string_start > 0) {
        uint8_t c1 = *((uint8_t*)buf_ptr(pc->buf) + token->start_pos);
        uint8_t c2 = *((uint8_t*)buf_ptr(pc->buf) + token->start_pos + 1);
        assert(c1 == 'r');
        if (out_c_str) {
            *out_c_str = (c2 == 'c');
        }
        const char *str = buf_ptr(pc->buf) + token->raw_string_start;
        buf_init_from_mem(buf, str, token->raw_string_end - token->raw_string_start);
        if (offset_map) {
            SrcPos pos = {token->start_line, token->start_column};
            for (int i = token->start_pos; i < token->raw_string_start; i += 1) {
                uint8_t c = buf_ptr(pc->buf)[i];
                if (c == '\n') {
                    pos.line += 1;
                    pos.column = 0;
                } else {
                    pos.column += 1;
                }
            }
            for (int i = token->raw_string_start; i < token->raw_string_end; i += 1) {
                offset_map->append(pos);

                uint8_t c = buf_ptr(pc->buf)[i];
                if (c == '\n') {
                    pos.line += 1;
                    pos.column = 0;
                } else {
                    pos.column += 1;
                }
            }
        }
        return;
    }

    // skip the double quotes at beginning and end
    // convert escape sequences
    // detect c string literal

    enum State {
        StatePre,
        StateSkipQuot,
        StateStart,
        StateEscape,
        StateHex1,
        StateHex2,
        StateUnicode,
    };

    buf_resize(buf, 0);

    int unicode_index;
    int unicode_end;

    State state = StatePre;
    SrcPos pos = {token->start_line, token->start_column};
    uint32_t hex_value = 0;
    for (int i = token->start_pos; i < token->end_pos - 1; i += 1) {
        uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);

        switch (state) {
            case StatePre:
                switch (c) {
                    case '@':
                        state = StateSkipQuot;
                        break;
                    case 'c':
                        if (out_c_str) {
                            *out_c_str = true;
                        } else {
                            ast_error(pc, token, "C string literal not allowed here");
                        }
                        state = StateSkipQuot;
                        break;
                    case '"':
                        state = StateStart;
                        break;
                    default:
                        ast_error(pc, token, "invalid string character");
                }
                break;
            case StateSkipQuot:
                state = StateStart;
                break;
            case StateStart:
                if (c == '\\') {
                    state = StateEscape;
                } else {
                    buf_append_char(buf, c);
                    if (offset_map) offset_map->append(pos);
                }
                break;
            case StateEscape:
                switch (c) {
                    case '\\':
                        buf_append_char(buf, '\\');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case 'r':
                        buf_append_char(buf, '\r');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case 'n':
                        buf_append_char(buf, '\n');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case 't':
                        buf_append_char(buf, '\t');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case '"':
                        buf_append_char(buf, '"');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case '\'':
                        buf_append_char(buf, '\'');
                        if (offset_map) offset_map->append(pos);
                        state = StateStart;
                        break;
                    case 'x':
                        state = StateHex1;
                        break;
                    case 'u':
                        state = StateUnicode;
                        unicode_index = 0;
                        unicode_end = 4;
                        hex_value = 0;
                        break;
                    case 'U':
                        state = StateUnicode;
                        unicode_index = 0;
                        unicode_end = 6;
                        hex_value = 0;
                        break;
                    default:
                        ast_error(pc, token, "invalid escape character");
                }
                break;
            case StateHex1:
                {
                    uint32_t hex_digit = get_hex_digit(c);
                    if (hex_digit == UINT32_MAX) {
                        ast_error(pc, token, "invalid hex digit: '%c'", c);
                    }
                    hex_value = hex_digit * 16;
                    state = StateHex2;
                    break;
                }
            case StateHex2:
                {
                    uint32_t hex_digit = get_hex_digit(c);
                    if (hex_digit == UINT32_MAX) {
                        ast_error(pc, token, "invalid hex digit: '%c'", c);
                    }
                    hex_value += hex_digit;
                    assert(hex_value >= 0 && hex_value <= 255);
                    buf_append_char(buf, hex_value);
                    state = StateStart;
                    break;
                }
            case StateUnicode:
                {
                    uint32_t hex_digit = get_hex_digit(c);
                    if (hex_digit == UINT32_MAX) {
                        ast_error(pc, token, "invalid hex digit: '%c'", c);
                    }
                    hex_value *= 16;
                    hex_value += hex_digit;
                    unicode_index += 1;
                    if (unicode_index >= unicode_end) {
                        if (hex_value <= 0x7f) {
                            // 00000000 00000000 00000000 0xxxxxxx
                            buf_append_char(buf, hex_value);
                        } else if (hex_value <= 0x7ff) {
                            // 00000000 00000000 00000xxx xx000000
                            buf_append_char(buf, (unsigned char)(0xc0 | (hex_value >> 6)));
                            // 00000000 00000000 00000000 00xxxxxx
                            buf_append_char(buf, (unsigned char)(0x80 | (hex_value & 0x3f)));
                        } else if (hex_value <= 0xffff) {
                            // 00000000 00000000 xxxx0000 00000000
                            buf_append_char(buf, (unsigned char)(0xe0 | (hex_value >> 12)));
                            // 00000000 00000000 0000xxxx xx000000
                            buf_append_char(buf, (unsigned char)(0x80 | ((hex_value >> 6) & 0x3f)));
                            // 00000000 00000000 00000000 00xxxxxx
                            buf_append_char(buf, (unsigned char)(0x80 | (hex_value & 0x3f)));
                        } else if (hex_value <= 0x10ffff) {
                            // 00000000 000xxx00 00000000 00000000
                            buf_append_char(buf, (unsigned char)(0xf0 | (hex_value >> 18)));
                            // 00000000 000000xx xxxx0000 00000000
                            buf_append_char(buf, (unsigned char)(0x80 | ((hex_value >> 12) & 0x3f)));
                            // 00000000 00000000 0000xxxx xx000000
                            buf_append_char(buf, (unsigned char)(0x80 | ((hex_value >> 6) & 0x3f)));
                            // 00000000 00000000 00000000 00xxxxxx
                            buf_append_char(buf, (unsigned char)(0x80 | (hex_value & 0x3f)));
                        } else {
                            ast_error(pc, token, "unicode value out of range: %x", hex_value);
                        }
                        state = StateStart;
                    }
                    break;
                }
        }
        if (c == '\n') {
            pos.line += 1;
            pos.column = 0;
        } else {
            pos.column += 1;
        }
    }
    assert(state == StateStart);
    if (offset_map) offset_map->append(pos);
}

static void ast_buf_from_token(ParseContext *pc, Token *token, Buf *buf) {
    uint8_t *first_char = (uint8_t *)buf_ptr(pc->buf) + token->start_pos;
    bool at_sign = *first_char == '@';
    if (at_sign) {
        parse_string_literal(pc, token, buf, nullptr, nullptr);
    } else {
        buf_init_from_mem(buf, buf_ptr(pc->buf) + token->start_pos, token->end_pos - token->start_pos);
    }
}


static unsigned long long parse_int_digits(ParseContext *pc, int digits_start, int digits_end, int radix,
    int skip_index, bool *overflow)
{
    unsigned long long x = 0;

    for (int i = digits_start; i < digits_end; i++) {
        if (i == skip_index)
            continue;
        uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + i);
        unsigned long long digit = get_digit_value(c);

        // x *= radix;
        if (__builtin_umulll_overflow(x, radix, &x)) {
            *overflow = true;
            return 0;
        }

        // x += digit
        if (__builtin_uaddll_overflow(x, digit, &x)) {
            *overflow = true;
            return 0;
        }
    }
    return x;
}

static void parse_number_literal(ParseContext *pc, Token *token, AstNodeNumberLiteral *num_lit) {
    assert(token->id == TokenIdNumberLiteral);

    int whole_number_start = token->start_pos;
    if (token->radix != 10) {
        // skip the "0x"
        whole_number_start += 2;
    }

    int whole_number_end = token->decimal_point_pos;
    if (whole_number_end <= whole_number_start) {
        // TODO: error for empty whole number part
        num_lit->overflow = true;
        return;
    }

    if (token->decimal_point_pos == token->end_pos) {
        // integer
        unsigned long long whole_number = parse_int_digits(pc, whole_number_start, whole_number_end,
            token->radix, -1, &num_lit->overflow);
        if (num_lit->overflow) return;

        num_lit->data.x_uint = whole_number;
        num_lit->kind = NumLitUInt;
    } else {
        // float

        if (token->radix == 10) {
            // use a third-party base-10 float parser
            char *str_begin = buf_ptr(pc->buf) + whole_number_start;
            char *str_end;
            errno = 0;
            double x = strtod(str_begin, &str_end);
            if (errno) {
                // TODO: forward error to user
                num_lit->overflow = true;
                return;
            }
            assert(str_end == buf_ptr(pc->buf) + token->end_pos);
            num_lit->data.x_float = x;
            num_lit->kind = NumLitFloat;
            return;
        }

        if (token->decimal_point_pos < token->exponent_marker_pos) {
            // fraction
            int fraction_start = token->decimal_point_pos + 1;
            int fraction_end = token->exponent_marker_pos;
            if (fraction_end <= fraction_start) {
                // TODO: error for empty fraction part
                num_lit->overflow = true;
                return;
            }
        }

        // trim leading and trailing zeros in the significand digit sequence
        int significand_start = whole_number_start;
        for (; significand_start < token->exponent_marker_pos; significand_start++) {
            if (significand_start == token->decimal_point_pos)
                continue;
            uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + significand_start);
            if (c != '0')
                break;
        }
        int significand_end = token->exponent_marker_pos;
        for (; significand_end - 1 > significand_start; significand_end--) {
            if (significand_end - 1 <= token->decimal_point_pos) {
                significand_end = token->decimal_point_pos;
                break;
            }
            uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + significand_end - 1);
            if (c != '0')
                break;
        }

        unsigned long long significand_as_int = parse_int_digits(pc, significand_start, significand_end,
            token->radix, token->decimal_point_pos, &num_lit->overflow);
        if (num_lit->overflow) return;

        int exponent_in_bin_or_dec = 0;
        if (significand_end > token->decimal_point_pos) {
            exponent_in_bin_or_dec = token->decimal_point_pos + 1 - significand_end;
            if (token->radix == 2) {
                // already good
            } else if (token->radix == 8) {
                exponent_in_bin_or_dec *= 3;
            } else if (token->radix == 10) {
                // already good
            } else if (token->radix == 16) {
                exponent_in_bin_or_dec *= 4;
            } else zig_unreachable();
        }

        if (token->exponent_marker_pos < token->end_pos) {
            // exponent
            int exponent_start = token->exponent_marker_pos + 1;
            int exponent_end = token->end_pos;
            if (exponent_end <= exponent_start) {
                // TODO: error for empty exponent part
                num_lit->overflow = true;
                return;
            }
            bool is_exponent_negative = false;
            uint8_t c = *((uint8_t*)buf_ptr(pc->buf) + exponent_start);
            if (c == '+') {
                exponent_start += 1;
            } else if (c == '-') {
                exponent_start += 1;
                is_exponent_negative = true;
            }

            if (exponent_end <= exponent_start) {
                // TODO: error for empty exponent part
                num_lit->overflow = true;
                return;
            }

            unsigned long long specified_exponent = parse_int_digits(pc, exponent_start, exponent_end,
                10, -1, &num_lit->overflow);
            // TODO: this check is a little silly
            if (specified_exponent >= LLONG_MAX) {
                num_lit->overflow = true;
                return;
            }

            if (is_exponent_negative) {
                exponent_in_bin_or_dec -= specified_exponent;
            } else {
                exponent_in_bin_or_dec += specified_exponent;
            }
        }

        uint64_t significand_bits;
        uint64_t exponent_bits;
        if (significand_as_int != 0) {
            // normalize the significand
            if (token->radix == 10) {
                zig_panic("TODO: decimal floats");
            } else {
                int significand_magnitude_in_bin = __builtin_clzll(1) - __builtin_clzll(significand_as_int);
                exponent_in_bin_or_dec += significand_magnitude_in_bin;
                if (!(-1023 <= exponent_in_bin_or_dec && exponent_in_bin_or_dec < 1023)) {
                    num_lit->overflow = true;
                    return;
                }

                // this should chop off exactly one 1 bit from the top.
                significand_bits = ((uint64_t)significand_as_int << (52 - significand_magnitude_in_bin)) & 0xfffffffffffffULL;
                exponent_bits = exponent_in_bin_or_dec + 1023;
            }
        } else {
            // 0 is all 0's
            significand_bits = 0;
            exponent_bits = 0;
        }

        uint64_t double_bits = (exponent_bits << 52) | significand_bits;
        double x = *(double *)&double_bits;

        num_lit->data.x_float = x;
        num_lit->kind = NumLitFloat;
    }
}


__attribute__ ((noreturn))
static void ast_invalid_token_error(ParseContext *pc, Token *token) {
    Buf token_value = BUF_INIT;
    ast_buf_from_token(pc, token, &token_value);
    ast_error(pc, token, "invalid token: '%s'", buf_ptr(&token_value));
}

static AstNode *ast_parse_expression(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_block(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_if_expr(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_block_expr(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_unwrap_expr(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_prefix_op_expr(ParseContext *pc, int *token_index, bool mandatory);
static AstNode *ast_parse_fn_proto(ParseContext *pc, int *token_index, bool mandatory,
        ZigList<AstNode*> *directives, VisibMod visib_mod);
static AstNode *ast_parse_return_expr(ParseContext *pc, int *token_index);
static AstNode *ast_parse_grouped_expr(ParseContext *pc, int *token_index, bool mandatory);

static void ast_expect_token(ParseContext *pc, Token *token, TokenId token_id) {
    if (token->id == token_id) {
        return;
    }

    Buf token_value = BUF_INIT;
    ast_buf_from_token(pc, token, &token_value);
    ast_error(pc, token, "expected token '%s', found '%s'", token_name(token_id), token_name(token->id));
}

static Token *ast_eat_token(ParseContext *pc, int *token_index, TokenId token_id) {
    Token *token = &pc->tokens->at(*token_index);
    ast_expect_token(pc, token, token_id);
    *token_index += 1;
    return token;
}

/*
Directive = "#" "Symbol" "(" Expression ")"
*/
static AstNode *ast_parse_directive(ParseContext *pc, int *token_index) {
    Token *number_sign = ast_eat_token(pc, token_index, TokenIdNumberSign);

    AstNode *node = ast_create_node(pc, NodeTypeDirective, number_sign);

    Token *name_symbol = ast_eat_token(pc, token_index, TokenIdSymbol);

    ast_buf_from_token(pc, name_symbol, &node->data.directive.name);

    node->data.directive.expr = ast_parse_grouped_expr(pc, token_index, true);

    normalize_parent_ptrs(node);
    return node;
}

static void ast_parse_directives(ParseContext *pc, int *token_index,
        ZigList<AstNode *> *directives)
{
    for (;;) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id == TokenIdNumberSign) {
            AstNode *directive_node = ast_parse_directive(pc, token_index);
            directives->append(directive_node);
        } else {
            return;
        }
    }
    zig_unreachable();
}

/*
ParamDecl = option("noalias" | "inline") option("Symbol" ":") TypeExpr | "..."
*/
static AstNode *ast_parse_param_decl(ParseContext *pc, int *token_index) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id == TokenIdEllipsis) {
        *token_index += 1;
        return nullptr;
    }

    AstNode *node = ast_create_node(pc, NodeTypeParamDecl, token);

    if (token->id == TokenIdKeywordNoAlias) {
        node->data.param_decl.is_noalias = true;
        *token_index += 1;
        token = &pc->tokens->at(*token_index);
    } else if (token->id == TokenIdKeywordInline) {
        node->data.param_decl.is_inline = true;
        *token_index += 1;
        token = &pc->tokens->at(*token_index);
    }

    buf_resize(&node->data.param_decl.name, 0);

    if (token->id == TokenIdSymbol) {
        Token *next_token = &pc->tokens->at(*token_index + 1);
        if (next_token->id == TokenIdColon) {
            ast_buf_from_token(pc, token, &node->data.param_decl.name);
            *token_index += 2;
        }
    }

    node->data.param_decl.type = ast_parse_prefix_op_expr(pc, token_index, true);

    normalize_parent_ptrs(node);
    return node;
}


static void ast_parse_param_decl_list(ParseContext *pc, int *token_index,
        ZigList<AstNode *> *params, bool *is_var_args)
{
    *is_var_args = false;

    ast_eat_token(pc, token_index, TokenIdLParen);

    Token *token = &pc->tokens->at(*token_index);
    if (token->id == TokenIdRParen) {
        *token_index += 1;
        return;
    }

    for (;;) {
        AstNode *param_decl_node = ast_parse_param_decl(pc, token_index);
        bool expect_end = false;
        if (param_decl_node) {
            params->append(param_decl_node);
        } else {
            *is_var_args = true;
            expect_end = true;
        }

        Token *token = &pc->tokens->at(*token_index);
        *token_index += 1;
        if (token->id == TokenIdRParen) {
            return;
        } else if (expect_end) {
            ast_invalid_token_error(pc, token);
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

static void ast_parse_fn_call_param_list(ParseContext *pc, int *token_index, ZigList<AstNode*> *params) {
    Token *token = &pc->tokens->at(*token_index);
    if (token->id == TokenIdRParen) {
        *token_index += 1;
        return;
    }

    for (;;) {
        AstNode *expr = ast_parse_expression(pc, token_index, true);
        params->append(expr);

        Token *token = &pc->tokens->at(*token_index);
        *token_index += 1;
        if (token->id == TokenIdRParen) {
            return;
        } else {
            ast_expect_token(pc, token, TokenIdComma);
        }
    }
    zig_unreachable();
}

/*
GroupedExpression : token(LParen) Expression token(RParen)
*/
static AstNode *ast_parse_grouped_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *l_paren = &pc->tokens->at(*token_index);
    if (l_paren->id != TokenIdLParen) {
        if (mandatory) {
            ast_expect_token(pc, l_paren, TokenIdLParen);
        } else {
            return nullptr;
        }
    }

    *token_index += 1;

    AstNode *node = ast_parse_expression(pc, token_index, true);

    Token *r_paren = &pc->tokens->at(*token_index);
    *token_index += 1;
    ast_expect_token(pc, r_paren, TokenIdRParen);

    return node;
}

/*
ArrayType : "[" option(Expression) "]" option("const") PrefixOpExpression
*/
static AstNode *ast_parse_array_type_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *l_bracket = &pc->tokens->at(*token_index);
    if (l_bracket->id != TokenIdLBracket) {
        if (mandatory) {
            ast_expect_token(pc, l_bracket, TokenIdLBracket);
        } else {
            return nullptr;
        }
    }

    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeArrayType, l_bracket);
    node->data.array_type.size = ast_parse_expression(pc, token_index, false);

    ast_eat_token(pc, token_index, TokenIdRBracket);

    Token *const_tok = &pc->tokens->at(*token_index);
    if (const_tok->id == TokenIdKeywordConst) {
        *token_index += 1;
        node->data.array_type.is_const = true;
    }

    node->data.array_type.child_type = ast_parse_prefix_op_expr(pc, token_index, true);

    normalize_parent_ptrs(node);
    return node;
}

/*
AsmInputItem : token(LBracket) token(Symbol) token(RBracket) token(String) token(LParen) Expression token(RParen)
*/
static void ast_parse_asm_input_item(ParseContext *pc, int *token_index, AstNode *node) {
    ast_eat_token(pc, token_index, TokenIdLBracket);
    Token *alias = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdRBracket);

    Token *constraint = ast_eat_token(pc, token_index, TokenIdStringLiteral);

    ast_eat_token(pc, token_index, TokenIdLParen);
    AstNode *expr_node = ast_parse_expression(pc, token_index, true);
    ast_eat_token(pc, token_index, TokenIdRParen);

    AsmInput *asm_input = allocate<AsmInput>(1);
    ast_buf_from_token(pc, alias, &asm_input->asm_symbolic_name);
    parse_string_literal(pc, constraint, &asm_input->constraint, nullptr, nullptr);
    asm_input->expr = expr_node;
    node->data.asm_expr.input_list.append(asm_input);
}

/*
AsmOutputItem : "[" "Symbol" "]" "String" "(" ("Symbol" | "->" PrefixOpExpression) ")"
*/
static void ast_parse_asm_output_item(ParseContext *pc, int *token_index, AstNode *node) {
    ast_eat_token(pc, token_index, TokenIdLBracket);
    Token *alias = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdRBracket);

    Token *constraint = ast_eat_token(pc, token_index, TokenIdStringLiteral);

    AsmOutput *asm_output = allocate<AsmOutput>(1);

    ast_eat_token(pc, token_index, TokenIdLParen);

    Token *token = &pc->tokens->at(*token_index);
    *token_index += 1;
    if (token->id == TokenIdSymbol) {
        ast_buf_from_token(pc, token, &asm_output->variable_name);
    } else if (token->id == TokenIdArrow) {
        asm_output->return_type = ast_parse_prefix_op_expr(pc, token_index, true);
    } else {
        ast_invalid_token_error(pc, token);
    }

    ast_eat_token(pc, token_index, TokenIdRParen);

    ast_buf_from_token(pc, alias, &asm_output->asm_symbolic_name);
    parse_string_literal(pc, constraint, &asm_output->constraint, nullptr, nullptr);
    node->data.asm_expr.output_list.append(asm_output);
}

/*
AsmClobbers: token(Colon) list(token(String), token(Comma))
*/
static void ast_parse_asm_clobbers(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    for (;;) {
        Token *string_tok = &pc->tokens->at(*token_index);
        ast_expect_token(pc, string_tok, TokenIdStringLiteral);
        *token_index += 1;

        Buf *clobber_buf = buf_alloc();
        parse_string_literal(pc, string_tok, clobber_buf, nullptr, nullptr);
        node->data.asm_expr.clobber_list.append(clobber_buf);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }
}

/*
AsmInput : token(Colon) list(AsmInputItem, token(Comma)) option(AsmClobbers)
*/
static void ast_parse_asm_input(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    for (;;) {
        ast_parse_asm_input_item(pc, token_index, node);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }

    ast_parse_asm_clobbers(pc, token_index, node);
}

/*
AsmOutput : token(Colon) list(AsmOutputItem, token(Comma)) option(AsmInput)
*/
static void ast_parse_asm_output(ParseContext *pc, int *token_index, AstNode *node) {
    Token *colon_tok = &pc->tokens->at(*token_index);

    if (colon_tok->id != TokenIdColon)
        return;

    *token_index += 1;

    Token *colon_again = &pc->tokens->at(*token_index);
    if (colon_again->id == TokenIdColon) {
        ast_parse_asm_input(pc, token_index, node);
        return;
    }

    for (;;) {
        ast_parse_asm_output_item(pc, token_index, node);

        Token *comma = &pc->tokens->at(*token_index);

        if (comma->id == TokenIdComma) {
            *token_index += 1;
            continue;
        } else {
            break;
        }
    }

    ast_parse_asm_input(pc, token_index, node);
}

/*
AsmExpression : token(Asm) option(token(Volatile)) token(LParen) token(String) option(AsmOutput) token(RParen)
*/
static AstNode *ast_parse_asm_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *asm_token = &pc->tokens->at(*token_index);

    if (asm_token->id != TokenIdKeywordAsm) {
        if (mandatory) {
            ast_expect_token(pc, asm_token, TokenIdKeywordAsm);
        } else {
            return nullptr;
        }
    }

    AstNode *node = ast_create_node(pc, NodeTypeAsmExpr, asm_token);

    *token_index += 1;
    Token *lparen_tok = &pc->tokens->at(*token_index);

    if (lparen_tok->id == TokenIdKeywordVolatile) {
        node->data.asm_expr.is_volatile = true;

        *token_index += 1;
        lparen_tok = &pc->tokens->at(*token_index);
    }

    ast_expect_token(pc, lparen_tok, TokenIdLParen);
    *token_index += 1;

    Token *template_tok = &pc->tokens->at(*token_index);
    ast_expect_token(pc, template_tok, TokenIdStringLiteral);
    *token_index += 1;

    parse_string_literal(pc, template_tok, &node->data.asm_expr.asm_template, nullptr,
            &node->data.asm_expr.offset_map);
    parse_asm_template(pc, node);

    ast_parse_asm_output(pc, token_index, node);

    Token *rparen_tok = &pc->tokens->at(*token_index);
    ast_expect_token(pc, rparen_tok, TokenIdRParen);
    *token_index += 1;

    normalize_parent_ptrs(node);
    return node;
}

/*
PrimaryExpression = "Number" | "String" | "CharLiteral" | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression | "Symbol" | ("@" "Symbol" FnCallExpression) | ArrayType | FnProto | AsmExpression | ("error" "." "Symbol")
KeywordLiteral = "true" | "false" | "null" | "break" | "continue" | "undefined" | "error" | "type"
*/
static AstNode *ast_parse_primary_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id == TokenIdNumberLiteral) {
        AstNode *node = ast_create_node(pc, NodeTypeNumberLiteral, token);
        parse_number_literal(pc, token, &node->data.number_literal);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdStringLiteral) {
        AstNode *node = ast_create_node(pc, NodeTypeStringLiteral, token);
        parse_string_literal(pc, token, &node->data.string_literal.buf, &node->data.string_literal.c, nullptr);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdCharLiteral) {
        AstNode *node = ast_create_node(pc, NodeTypeCharLiteral, token);
        node->data.char_literal.value = parse_char_literal(pc, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordTrue) {
        AstNode *node = ast_create_node(pc, NodeTypeBoolLiteral, token);
        node->data.bool_literal.value = true;
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordFalse) {
        AstNode *node = ast_create_node(pc, NodeTypeBoolLiteral, token);
        node->data.bool_literal.value = false;
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordNull) {
        AstNode *node = ast_create_node(pc, NodeTypeNullLiteral, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordBreak) {
        AstNode *node = ast_create_node(pc, NodeTypeBreak, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordContinue) {
        AstNode *node = ast_create_node(pc, NodeTypeContinue, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordUndefined) {
        AstNode *node = ast_create_node(pc, NodeTypeUndefinedLiteral, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordType) {
        AstNode *node = ast_create_node(pc, NodeTypeTypeLiteral, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordError) {
        AstNode *node = ast_create_node(pc, NodeTypeErrorType, token);
        *token_index += 1;
        return node;
    } else if (token->id == TokenIdKeywordExtern) {
        *token_index += 1;
        AstNode *node = ast_parse_fn_proto(pc, token_index, true, nullptr, VisibModPrivate);
        node->data.fn_proto.is_extern = true;
        return node;
    } else if (token->id == TokenIdAtSign) {
        *token_index += 1;
        Token *name_tok = ast_eat_token(pc, token_index, TokenIdSymbol);
        AstNode *name_node = ast_create_node(pc, NodeTypeSymbol, name_tok);
        ast_buf_from_token(pc, name_tok, &name_node->data.symbol_expr.symbol);

        AstNode *node = ast_create_node(pc, NodeTypeFnCallExpr, token);
        node->data.fn_call_expr.fn_ref_expr = name_node;
        ast_eat_token(pc, token_index, TokenIdLParen);
        ast_parse_fn_call_param_list(pc, token_index, &node->data.fn_call_expr.params);
        node->data.fn_call_expr.is_builtin = true;

        normalize_parent_ptrs(node);
        return node;
    } else if (token->id == TokenIdSymbol) {
        *token_index += 1;
        AstNode *node = ast_create_node(pc, NodeTypeSymbol, token);
        ast_buf_from_token(pc, token, &node->data.symbol_expr.symbol);
        return node;
    } else if (token->id == TokenIdKeywordGoto) {
        AstNode *node = ast_create_node(pc, NodeTypeGoto, token);
        *token_index += 1;

        Token *dest_symbol = &pc->tokens->at(*token_index);
        *token_index += 1;
        ast_expect_token(pc, dest_symbol, TokenIdSymbol);

        ast_buf_from_token(pc, dest_symbol, &node->data.goto_expr.name);
        return node;
    }

    AstNode *grouped_expr_node = ast_parse_grouped_expr(pc, token_index, false);
    if (grouped_expr_node) {
        return grouped_expr_node;
    }

    AstNode *block_expr_node = ast_parse_block_expr(pc, token_index, false);
    if (block_expr_node) {
        return block_expr_node;
    }

    AstNode *array_type_node = ast_parse_array_type_expr(pc, token_index, false);
    if (array_type_node) {
        return array_type_node;
    }

    AstNode *fn_proto_node = ast_parse_fn_proto(pc, token_index, false, nullptr, VisibModPrivate);
    if (fn_proto_node) {
        return fn_proto_node;
    }

    AstNode *asm_expr = ast_parse_asm_expr(pc, token_index, false);
    if (asm_expr) {
        return asm_expr;
    }

    if (!mandatory)
        return nullptr;

    ast_invalid_token_error(pc, token);
}

/*
CurlySuffixExpression : PrefixOpExpression option(ContainerInitExpression)
ContainerInitExpression : token(LBrace) ContainerInitBody token(RBrace)
ContainerInitBody : list(StructLiteralField, token(Comma)) | list(Expression, token(Comma))
*/
static AstNode *ast_parse_curly_suffix_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *prefix_op_expr = ast_parse_prefix_op_expr(pc, token_index, mandatory);
    if (!prefix_op_expr) {
        return nullptr;
    }

    while (true) {
        Token *first_token = &pc->tokens->at(*token_index);
        if (first_token->id == TokenIdLBrace) {
            *token_index += 1;

            AstNode *node = ast_create_node(pc, NodeTypeContainerInitExpr, first_token);
            node->data.container_init_expr.type = prefix_op_expr;

            Token *token = &pc->tokens->at(*token_index);
            if (token->id == TokenIdDot) {
                node->data.container_init_expr.kind = ContainerInitKindStruct;
                for (;;) {
                    if (token->id == TokenIdDot) {
                        ast_eat_token(pc, token_index, TokenIdDot);
                        Token *field_name_tok = ast_eat_token(pc, token_index, TokenIdSymbol);
                        ast_eat_token(pc, token_index, TokenIdEq);

                        AstNode *field_node = ast_create_node(pc, NodeTypeStructValueField, token);

                        ast_buf_from_token(pc, field_name_tok, &field_node->data.struct_val_field.name);
                        field_node->data.struct_val_field.expr = ast_parse_expression(pc, token_index, true);

                        normalize_parent_ptrs(field_node);
                        node->data.container_init_expr.entries.append(field_node);

                        Token *comma_tok = &pc->tokens->at(*token_index);
                        if (comma_tok->id == TokenIdComma) {
                            *token_index += 1;
                            token = &pc->tokens->at(*token_index);
                            continue;
                        } else if (comma_tok->id != TokenIdRBrace) {
                            ast_expect_token(pc, comma_tok, TokenIdRBrace);
                        } else {
                            *token_index += 1;
                            break;
                        }
                    } else if (token->id == TokenIdRBrace) {
                        *token_index += 1;
                        break;
                    } else {
                        ast_invalid_token_error(pc, token);
                    }
                }

            } else {
                node->data.container_init_expr.kind = ContainerInitKindArray;
                for (;;) {
                    if (token->id == TokenIdRBrace) {
                        *token_index += 1;
                        break;
                    } else {
                        AstNode *elem_node = ast_parse_expression(pc, token_index, true);
                        node->data.container_init_expr.entries.append(elem_node);

                        Token *comma_tok = &pc->tokens->at(*token_index);
                        if (comma_tok->id == TokenIdComma) {
                            *token_index += 1;
                            token = &pc->tokens->at(*token_index);
                            continue;
                        } else if (comma_tok->id != TokenIdRBrace) {
                            ast_expect_token(pc, comma_tok, TokenIdRBrace);
                        } else {
                            *token_index += 1;
                            break;
                        }
                    }
                }
            }

            normalize_parent_ptrs(node);
            prefix_op_expr = node;
        } else {
            return prefix_op_expr;
        }
    }
}

/*
SuffixOpExpression : PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)
FnCallExpression : token(LParen) list(Expression, token(Comma)) token(RParen)
ArrayAccessExpression : token(LBracket) Expression token(RBracket)
SliceExpression : token(LBracket) Expression token(Ellipsis) option(Expression) token(RBracket) option(token(Const))
FieldAccessExpression : token(Dot) token(Symbol)
StructLiteralField : token(Dot) token(Symbol) token(Eq) Expression
*/
static AstNode *ast_parse_suffix_op_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *primary_expr = ast_parse_primary_expr(pc, token_index, mandatory);
    if (!primary_expr) {
        return nullptr;
    }

    while (true) {
        Token *first_token = &pc->tokens->at(*token_index);
        if (first_token->id == TokenIdLParen) {
            *token_index += 1;

            AstNode *node = ast_create_node(pc, NodeTypeFnCallExpr, first_token);
            node->data.fn_call_expr.fn_ref_expr = primary_expr;
            ast_parse_fn_call_param_list(pc, token_index, &node->data.fn_call_expr.params);

            normalize_parent_ptrs(node);
            primary_expr = node;
        } else if (first_token->id == TokenIdLBracket) {
            *token_index += 1;

            AstNode *expr_node = ast_parse_expression(pc, token_index, true);

            Token *ellipsis_or_r_bracket = &pc->tokens->at(*token_index);

            if (ellipsis_or_r_bracket->id == TokenIdEllipsis) {
                *token_index += 1;

                AstNode *node = ast_create_node(pc, NodeTypeSliceExpr, first_token);
                node->data.slice_expr.array_ref_expr = primary_expr;
                node->data.slice_expr.start = expr_node;
                node->data.slice_expr.end = ast_parse_expression(pc, token_index, false);

                ast_eat_token(pc, token_index, TokenIdRBracket);

                Token *const_tok = &pc->tokens->at(*token_index);
                if (const_tok->id == TokenIdKeywordConst) {
                    *token_index += 1;
                    node->data.slice_expr.is_const = true;
                }

                normalize_parent_ptrs(node);
                primary_expr = node;
            } else if (ellipsis_or_r_bracket->id == TokenIdRBracket) {
                *token_index += 1;

                AstNode *node = ast_create_node(pc, NodeTypeArrayAccessExpr, first_token);
                node->data.array_access_expr.array_ref_expr = primary_expr;
                node->data.array_access_expr.subscript = expr_node;

                normalize_parent_ptrs(node);
                primary_expr = node;
            } else {
                ast_invalid_token_error(pc, first_token);
            }
        } else if (first_token->id == TokenIdDot) {
            *token_index += 1;

            Token *name_token = ast_eat_token(pc, token_index, TokenIdSymbol);

            AstNode *node = ast_create_node(pc, NodeTypeFieldAccessExpr, first_token);
            node->data.field_access_expr.struct_expr = primary_expr;
            ast_buf_from_token(pc, name_token, &node->data.field_access_expr.field_name);

            normalize_parent_ptrs(node);
            primary_expr = node;
        } else {
            return primary_expr;
        }
    }
}

static PrefixOp tok_to_prefix_op(Token *token) {
    switch (token->id) {
        case TokenIdBang: return PrefixOpBoolNot;
        case TokenIdDash: return PrefixOpNegation;
        case TokenIdTilde: return PrefixOpBinNot;
        case TokenIdAmpersand: return PrefixOpAddressOf;
        case TokenIdStar: return PrefixOpDereference;
        case TokenIdMaybe: return PrefixOpMaybe;
        case TokenIdPercent: return PrefixOpError;
        case TokenIdPercentPercent: return PrefixOpUnwrapError;
        case TokenIdDoubleQuestion: return PrefixOpUnwrapMaybe;
        case TokenIdBoolAnd: return PrefixOpAddressOf;
        case TokenIdStarStar: return PrefixOpDereference;
        default: return PrefixOpInvalid;
    }
}

/*
PrefixOpExpression : PrefixOp PrefixOpExpression | SuffixOpExpression
PrefixOp : token(Not) | token(Dash) | token(Tilde) | token(Star) | (token(Ampersand) option(token(Const)))
*/
static AstNode *ast_parse_prefix_op_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    PrefixOp prefix_op = tok_to_prefix_op(token);
    if (prefix_op == PrefixOpInvalid) {
        return ast_parse_suffix_op_expr(pc, token_index, mandatory);
    }

    if (prefix_op == PrefixOpError || prefix_op == PrefixOpMaybe) {
        Token *maybe_return = &pc->tokens->at(*token_index + 1);
        if (maybe_return->id == TokenIdKeywordReturn) {
            return ast_parse_return_expr(pc, token_index);
        }
    }

    *token_index += 1;


    AstNode *node = ast_create_node(pc, NodeTypePrefixOpExpr, token);
    AstNode *parent_node = node;
    if (token->id == TokenIdBoolAnd) {
        // pretend that we got 2 ampersand tokens

        parent_node = ast_create_node(pc, NodeTypePrefixOpExpr, token);
        parent_node->data.prefix_op_expr.primary_expr = node;
        parent_node->data.prefix_op_expr.prefix_op = PrefixOpAddressOf;

        node->column += 1;
    } else if (token->id == TokenIdStarStar) {
        // pretend that we got 2 star tokens

        parent_node = ast_create_node(pc, NodeTypePrefixOpExpr, token);
        parent_node->data.prefix_op_expr.primary_expr = node;
        parent_node->data.prefix_op_expr.prefix_op = PrefixOpDereference;

        node->column += 1;
    }

    if (prefix_op == PrefixOpAddressOf) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id == TokenIdKeywordConst) {
            *token_index += 1;
            prefix_op = PrefixOpConstAddressOf;
        }
    }

    AstNode *prefix_op_expr = ast_parse_prefix_op_expr(pc, token_index, true);
    node->data.prefix_op_expr.primary_expr = prefix_op_expr;
    node->data.prefix_op_expr.prefix_op = prefix_op;

    normalize_parent_ptrs(node);
    normalize_parent_ptrs(parent_node);
    return parent_node;
}


static BinOpType tok_to_mult_op(Token *token) {
    switch (token->id) {
        case TokenIdStar: return BinOpTypeMult;
        case TokenIdStarStar: return BinOpTypeArrayMult;
        case TokenIdSlash: return BinOpTypeDiv;
        case TokenIdPercent: return BinOpTypeMod;
        default: return BinOpTypeInvalid;
    }
}

/*
MultiplyOperator = "*" | "/" | "%" | "**"
*/
static BinOpType ast_parse_mult_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_mult_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
MultiplyExpression : CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression
*/
static AstNode *ast_parse_mult_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_curly_suffix_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType mult_op = ast_parse_mult_op(pc, token_index, false);
        if (mult_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_curly_suffix_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = mult_op;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

static BinOpType tok_to_add_op(Token *token) {
    switch (token->id) {
        case TokenIdPlus: return BinOpTypeAdd;
        case TokenIdDash: return BinOpTypeSub;
        case TokenIdPlusPlus: return BinOpTypeArrayCat;
        default: return BinOpTypeInvalid;
    }
}

/*
AdditionOperator : "+" | "-" | "++"
*/
static BinOpType ast_parse_add_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_add_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
AdditionExpression : MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression
*/
static AstNode *ast_parse_add_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_mult_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType add_op = ast_parse_add_op(pc, token_index, false);
        if (add_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_mult_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = add_op;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

static BinOpType tok_to_bit_shift_op(Token *token) {
    switch (token->id) {
        case TokenIdBitShiftLeft: return BinOpTypeBitShiftLeft;
        case TokenIdBitShiftRight: return BinOpTypeBitShiftRight;
        default: return BinOpTypeInvalid;
    }
}

/*
BitShiftOperator : token(BitShiftLeft) | token(BitShiftRight)
*/
static BinOpType ast_parse_bit_shift_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_bit_shift_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
BitShiftExpression : AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression
*/
static AstNode *ast_parse_bit_shift_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_add_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        BinOpType bit_shift_op = ast_parse_bit_shift_op(pc, token_index, false);
        if (bit_shift_op == BinOpTypeInvalid)
            return operand_1;

        AstNode *operand_2 = ast_parse_add_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = bit_shift_op;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}


/*
BinaryAndExpression : BitShiftExpression token(Ampersand) BinaryAndExpression | BitShiftExpression
*/
static AstNode *ast_parse_bin_and_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bit_shift_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdAmpersand)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bit_shift_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinAnd;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

/*
BinaryXorExpression : BinaryAndExpression token(BinXor) BinaryXorExpression | BinaryAndExpression
*/
static AstNode *ast_parse_bin_xor_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_and_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBinXor)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bin_and_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinXor;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

/*
BinaryOrExpression : BinaryXorExpression token(BinOr) BinaryOrExpression | BinaryXorExpression
*/
static AstNode *ast_parse_bin_or_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_xor_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBinOr)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bin_xor_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBinOr;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

static BinOpType tok_to_cmp_op(Token *token) {
    switch (token->id) {
        case TokenIdCmpEq: return BinOpTypeCmpEq;
        case TokenIdCmpNotEq: return BinOpTypeCmpNotEq;
        case TokenIdCmpLessThan: return BinOpTypeCmpLessThan;
        case TokenIdCmpGreaterThan: return BinOpTypeCmpGreaterThan;
        case TokenIdCmpLessOrEq: return BinOpTypeCmpLessOrEq;
        case TokenIdCmpGreaterOrEq: return BinOpTypeCmpGreaterOrEq;
        default: return BinOpTypeInvalid;
    }
}

static BinOpType ast_parse_comparison_operator(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_cmp_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
ComparisonExpression : BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression
*/
static AstNode *ast_parse_comparison_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bin_or_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    Token *token = &pc->tokens->at(*token_index);
    BinOpType cmp_op = ast_parse_comparison_operator(pc, token_index, false);
    if (cmp_op == BinOpTypeInvalid)
        return operand_1;

    AstNode *operand_2 = ast_parse_bin_or_expr(pc, token_index, true);

    AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
    node->data.bin_op_expr.op1 = operand_1;
    node->data.bin_op_expr.bin_op = cmp_op;
    node->data.bin_op_expr.op2 = operand_2;

    normalize_parent_ptrs(node);
    return node;
}

/*
BoolAndExpression : ComparisonExpression token(BoolAnd) BoolAndExpression | ComparisonExpression
 */
static AstNode *ast_parse_bool_and_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_comparison_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBoolAnd)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_comparison_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBoolAnd;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

/*
Else : token(Else) Expression
*/
static AstNode *ast_parse_else(ParseContext *pc, int *token_index, bool mandatory) {
    Token *else_token = &pc->tokens->at(*token_index);

    if (else_token->id != TokenIdKeywordElse) {
        if (mandatory) {
            ast_expect_token(pc, else_token, TokenIdKeywordElse);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    return ast_parse_expression(pc, token_index, true);
}

/*
IfExpression : IfVarExpression | IfBoolExpression
IfBoolExpression : token(If) token(LParen) Expression token(RParen) Expression option(Else)
IfVarExpression = "if" "(" ("const" | "var") option("*") "Symbol" option(":" TypeExpr) "?=" Expression ")" Expression Option(Else)
*/
static AstNode *ast_parse_if_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *if_tok = &pc->tokens->at(*token_index);
    if (if_tok->id != TokenIdKeywordIf) {
        if (mandatory) {
            ast_expect_token(pc, if_tok, TokenIdKeywordIf);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    ast_eat_token(pc, token_index, TokenIdLParen);

    Token *token = &pc->tokens->at(*token_index);
    if (token->id == TokenIdKeywordConst || token->id == TokenIdKeywordVar) {
        AstNode *node = ast_create_node(pc, NodeTypeIfVarExpr, if_tok);
        node->data.if_var_expr.var_decl.is_const = (token->id == TokenIdKeywordConst);
        *token_index += 1;

        Token *star_or_symbol = &pc->tokens->at(*token_index);
        if (star_or_symbol->id == TokenIdStar) {
            *token_index += 1;
            node->data.if_var_expr.var_is_ptr = true;
            Token *name_token = ast_eat_token(pc, token_index, TokenIdSymbol);
            ast_buf_from_token(pc, name_token, &node->data.if_var_expr.var_decl.symbol);
        } else if (star_or_symbol->id == TokenIdSymbol) {
            *token_index += 1;
            ast_buf_from_token(pc, star_or_symbol, &node->data.if_var_expr.var_decl.symbol);
        } else {
            ast_invalid_token_error(pc, star_or_symbol);
        }


        Token *eq_or_colon = &pc->tokens->at(*token_index);
        if (eq_or_colon->id == TokenIdMaybeAssign) {
            *token_index += 1;
            node->data.if_var_expr.var_decl.expr = ast_parse_expression(pc, token_index, true);
        } else if (eq_or_colon->id == TokenIdColon) {
            *token_index += 1;
            node->data.if_var_expr.var_decl.type = ast_parse_prefix_op_expr(pc, token_index, true);

            ast_eat_token(pc, token_index, TokenIdMaybeAssign);
            node->data.if_var_expr.var_decl.expr = ast_parse_expression(pc, token_index, true);
        } else {
            ast_invalid_token_error(pc, eq_or_colon);
        }
        ast_eat_token(pc, token_index, TokenIdRParen);
        node->data.if_var_expr.then_block = ast_parse_expression(pc, token_index, true);
        node->data.if_var_expr.else_node = ast_parse_else(pc, token_index, false);

        normalize_parent_ptrs(node);
        return node;
    } else {
        AstNode *node = ast_create_node(pc, NodeTypeIfBoolExpr, if_tok);
        node->data.if_bool_expr.condition = ast_parse_expression(pc, token_index, true);
        ast_eat_token(pc, token_index, TokenIdRParen);
        node->data.if_bool_expr.then_block = ast_parse_expression(pc, token_index, true);
        node->data.if_bool_expr.else_node = ast_parse_else(pc, token_index, false);

        normalize_parent_ptrs(node);
        return node;
    }
}

/*
ReturnExpression : option("%" | "?") "return" option(Expression)
*/
static AstNode *ast_parse_return_expr(ParseContext *pc, int *token_index) {
    Token *token = &pc->tokens->at(*token_index);

    NodeType node_type;
    ReturnKind kind;

    if (token->id == TokenIdPercent) {
        Token *next_token = &pc->tokens->at(*token_index + 1);
        if (next_token->id == TokenIdKeywordReturn) {
            kind = ReturnKindError;
            node_type = NodeTypeReturnExpr;
            *token_index += 2;
        } else {
            return nullptr;
        }
    } else if (token->id == TokenIdMaybe) {
        Token *next_token = &pc->tokens->at(*token_index + 1);
        if (next_token->id == TokenIdKeywordReturn) {
            kind = ReturnKindMaybe;
            node_type = NodeTypeReturnExpr;
            *token_index += 2;
        } else {
            return nullptr;
        }
    } else if (token->id == TokenIdKeywordReturn) {
        kind = ReturnKindUnconditional;
        node_type = NodeTypeReturnExpr;
        *token_index += 1;
    } else {
        return nullptr;
    }

    AstNode *node = ast_create_node(pc, node_type, token);
    node->data.return_expr.kind = kind;
    node->data.return_expr.expr = ast_parse_expression(pc, token_index, false);

    normalize_parent_ptrs(node);
    return node;
}

/*
Defer = option("%" | "?") "defer" option(Expression)
*/
static AstNode *ast_parse_defer_expr(ParseContext *pc, int *token_index) {
    Token *token = &pc->tokens->at(*token_index);

    NodeType node_type;
    ReturnKind kind;

    if (token->id == TokenIdPercent) {
        Token *next_token = &pc->tokens->at(*token_index + 1);
        if (next_token->id == TokenIdKeywordDefer) {
            kind = ReturnKindError;
            node_type = NodeTypeDefer;
            *token_index += 2;
        } else {
            return nullptr;
        }
    } else if (token->id == TokenIdMaybe) {
        Token *next_token = &pc->tokens->at(*token_index + 1);
        if (next_token->id == TokenIdKeywordDefer) {
            kind = ReturnKindMaybe;
            node_type = NodeTypeDefer;
            *token_index += 2;
        } else {
            return nullptr;
        }
    } else if (token->id == TokenIdKeywordDefer) {
        kind = ReturnKindUnconditional;
        node_type = NodeTypeDefer;
        *token_index += 1;
    } else {
        return nullptr;
    }

    AstNode *node = ast_create_node(pc, node_type, token);
    node->data.defer.kind = kind;
    node->data.defer.expr = ast_parse_expression(pc, token_index, false);

    normalize_parent_ptrs(node);
    return node;
}

/*
VariableDeclaration : ("var" | "const") "Symbol" ("=" Expression | ":" PrefixOpExpression option("=" Expression))
*/
static AstNode *ast_parse_variable_declaration_expr(ParseContext *pc, int *token_index, bool mandatory,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);

    bool is_const;

    if (first_token->id == TokenIdKeywordVar) {
        is_const = false;
    } else if (first_token->id == TokenIdKeywordConst) {
        is_const = true;
    } else if (mandatory) {
        ast_invalid_token_error(pc, first_token);
    } else {
        return nullptr;
    }

    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeVariableDeclaration, first_token);

    node->data.variable_declaration.is_const = is_const;
    node->data.variable_declaration.top_level_decl.visib_mod = visib_mod;
    node->data.variable_declaration.top_level_decl.directives = directives;

    Token *name_token = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_buf_from_token(pc, name_token, &node->data.variable_declaration.symbol);

    Token *eq_or_colon = &pc->tokens->at(*token_index);
    *token_index += 1;
    if (eq_or_colon->id == TokenIdEq) {
        node->data.variable_declaration.expr = ast_parse_expression(pc, token_index, true);

        normalize_parent_ptrs(node);
        return node;
    } else if (eq_or_colon->id == TokenIdColon) {
        node->data.variable_declaration.type = ast_parse_prefix_op_expr(pc, token_index, true);
        Token *eq_token = &pc->tokens->at(*token_index);
        if (eq_token->id == TokenIdEq) {
            *token_index += 1;

            node->data.variable_declaration.expr = ast_parse_expression(pc, token_index, true);
        }

        normalize_parent_ptrs(node);
        return node;
    } else {
        ast_invalid_token_error(pc, eq_or_colon);
    }
}

/*
BoolOrExpression : BoolAndExpression token(BoolOr) BoolOrExpression | BoolAndExpression
*/
static AstNode *ast_parse_bool_or_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *operand_1 = ast_parse_bool_and_expr(pc, token_index, mandatory);
    if (!operand_1)
        return nullptr;

    while (true) {
        Token *token = &pc->tokens->at(*token_index);
        if (token->id != TokenIdBoolOr)
            return operand_1;
        *token_index += 1;

        AstNode *operand_2 = ast_parse_bool_and_expr(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = operand_1;
        node->data.bin_op_expr.bin_op = BinOpTypeBoolOr;
        node->data.bin_op_expr.op2 = operand_2;

        normalize_parent_ptrs(node);
        operand_1 = node;
    }
}

/*
WhileExpression = "while" "(" Expression option(";" Expression) ")" Expression
*/
static AstNode *ast_parse_while_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id != TokenIdKeywordWhile) {
        if (mandatory) {
            ast_expect_token(pc, token, TokenIdKeywordWhile);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeWhileExpr, token);

    ast_eat_token(pc, token_index, TokenIdLParen);
    node->data.while_expr.condition = ast_parse_expression(pc, token_index, true);

    Token *semi_or_rparen = &pc->tokens->at(*token_index);

    if (semi_or_rparen->id == TokenIdRParen) {
        *token_index += 1;
        node->data.while_expr.body = ast_parse_expression(pc, token_index, true);
    } else if (semi_or_rparen->id == TokenIdSemicolon) {
        *token_index += 1;
        node->data.while_expr.continue_expr = ast_parse_expression(pc, token_index, true);
        ast_eat_token(pc, token_index, TokenIdRParen);
        node->data.while_expr.body = ast_parse_expression(pc, token_index, true);
    } else {
        ast_invalid_token_error(pc, semi_or_rparen);
    }


    normalize_parent_ptrs(node);
    return node;
}

static AstNode *ast_parse_symbol(ParseContext *pc, int *token_index) {
    Token *token = ast_eat_token(pc, token_index, TokenIdSymbol);
    AstNode *node = ast_create_node(pc, NodeTypeSymbol, token);
    ast_buf_from_token(pc, token, &node->data.symbol_expr.symbol);
    return node;
}

/*
ForExpression = "for" "(" Expression ")" option("|" option("*") "Symbol" option("," "Symbol") "|") Expression
*/
static AstNode *ast_parse_for_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id != TokenIdKeywordFor) {
        if (mandatory) {
            ast_expect_token(pc, token, TokenIdKeywordFor);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeForExpr, token);

    ast_eat_token(pc, token_index, TokenIdLParen);
    node->data.for_expr.array_expr = ast_parse_expression(pc, token_index, true);
    ast_eat_token(pc, token_index, TokenIdRParen);

    Token *maybe_bar = &pc->tokens->at(*token_index);
    if (maybe_bar->id == TokenIdBinOr) {
        *token_index += 1;

        Token *maybe_star = &pc->tokens->at(*token_index);
        if (maybe_star->id == TokenIdStar) {
            *token_index += 1;
            node->data.for_expr.elem_is_ptr = true;
        }

        node->data.for_expr.elem_node = ast_parse_symbol(pc, token_index);

        Token *maybe_comma = &pc->tokens->at(*token_index);
        if (maybe_comma->id == TokenIdComma) {
            *token_index += 1;

            node->data.for_expr.index_node = ast_parse_symbol(pc, token_index);
        }

        ast_eat_token(pc, token_index, TokenIdBinOr);
    }

    node->data.for_expr.body = ast_parse_expression(pc, token_index, true);

    normalize_parent_ptrs(node);
    return node;
}

/*
SwitchExpression : "switch" "(" Expression ")" "{" many(SwitchProng) "}"
SwitchProng = (list(SwitchItem, ",") | "else") "=>" option("|" "Symbol" "|") Expression ","
SwitchItem : Expression | (Expression "..." Expression)
*/
static AstNode *ast_parse_switch_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    if (token->id != TokenIdKeywordSwitch) {
        if (mandatory) {
            ast_expect_token(pc, token, TokenIdKeywordSwitch);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeSwitchExpr, token);

    ast_eat_token(pc, token_index, TokenIdLParen);
    node->data.switch_expr.expr = ast_parse_expression(pc, token_index, true);
    ast_eat_token(pc, token_index, TokenIdRParen);
    ast_eat_token(pc, token_index, TokenIdLBrace);

    for (;;) {
        Token *token = &pc->tokens->at(*token_index);

        if (token->id == TokenIdRBrace) {
            *token_index += 1;

            normalize_parent_ptrs(node);
            return node;
        }

        AstNode *prong_node = ast_create_node(pc, NodeTypeSwitchProng, token);
        node->data.switch_expr.prongs.append(prong_node);

        if (token->id == TokenIdKeywordElse) {
            *token_index += 1;
        } else for (;;) {
            AstNode *expr1 = ast_parse_expression(pc, token_index, true);
            Token *ellipsis_tok = &pc->tokens->at(*token_index);
            if (ellipsis_tok->id == TokenIdEllipsis) {
                *token_index += 1;

                AstNode *range_node = ast_create_node(pc, NodeTypeSwitchRange, ellipsis_tok);
                prong_node->data.switch_prong.items.append(range_node);

                range_node->data.switch_range.start = expr1;
                range_node->data.switch_range.end = ast_parse_expression(pc, token_index, true);

                normalize_parent_ptrs(range_node);
            } else {
                prong_node->data.switch_prong.items.append(expr1);
            }
            Token *comma_tok = &pc->tokens->at(*token_index);
            if (comma_tok->id == TokenIdComma) {
                *token_index += 1;
                continue;
            }
            break;
        }

        ast_eat_token(pc, token_index, TokenIdFatArrow);

        Token *maybe_bar = &pc->tokens->at(*token_index);
        if (maybe_bar->id == TokenIdBinOr) {
            *token_index += 1;
            prong_node->data.switch_prong.var_symbol = ast_parse_symbol(pc, token_index);
            ast_eat_token(pc, token_index, TokenIdBinOr);
        }

        prong_node->data.switch_prong.expr = ast_parse_expression(pc, token_index, true);
        ast_eat_token(pc, token_index, TokenIdComma);

        normalize_parent_ptrs(prong_node);
    }
}

/*
BlockExpression : IfExpression | Block | WhileExpression | ForExpression | SwitchExpression
*/
static AstNode *ast_parse_block_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *if_expr = ast_parse_if_expr(pc, token_index, false);
    if (if_expr)
        return if_expr;

    AstNode *while_expr = ast_parse_while_expr(pc, token_index, false);
    if (while_expr)
        return while_expr;

    AstNode *for_expr = ast_parse_for_expr(pc, token_index, false);
    if (for_expr)
        return for_expr;

    AstNode *switch_expr = ast_parse_switch_expr(pc, token_index, false);
    if (switch_expr)
        return switch_expr;

    AstNode *block = ast_parse_block(pc, token_index, false);
    if (block)
        return block;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

static BinOpType tok_to_ass_op(Token *token) {
    switch (token->id) {
        case TokenIdEq: return BinOpTypeAssign;
        case TokenIdTimesEq: return BinOpTypeAssignTimes;
        case TokenIdDivEq: return BinOpTypeAssignDiv;
        case TokenIdModEq: return BinOpTypeAssignMod;
        case TokenIdPlusEq: return BinOpTypeAssignPlus;
        case TokenIdMinusEq: return BinOpTypeAssignMinus;
        case TokenIdBitShiftLeftEq: return BinOpTypeAssignBitShiftLeft;
        case TokenIdBitShiftRightEq: return BinOpTypeAssignBitShiftRight;
        case TokenIdBitAndEq: return BinOpTypeAssignBitAnd;
        case TokenIdBitXorEq: return BinOpTypeAssignBitXor;
        case TokenIdBitOrEq: return BinOpTypeAssignBitOr;
        case TokenIdBoolAndEq: return BinOpTypeAssignBoolAnd;
        case TokenIdBoolOrEq: return BinOpTypeAssignBoolOr;
        default: return BinOpTypeInvalid;
    }
}

/*
AssignmentOperator : token(Eq) | token(TimesEq) | token(DivEq) | token(ModEq) | token(PlusEq) | token(MinusEq) | token(BitShiftLeftEq) | token(BitShiftRightEq) | token(BitAndEq) | token(BitXorEq) | token(BitOrEq) | token(BoolAndEq) | token(BoolOrEq)
*/
static BinOpType ast_parse_ass_op(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);
    BinOpType result = tok_to_ass_op(token);
    if (result == BinOpTypeInvalid) {
        if (mandatory) {
            ast_invalid_token_error(pc, token);
        } else {
            return BinOpTypeInvalid;
        }
    }
    *token_index += 1;
    return result;
}

/*
UnwrapExpression : BoolOrExpression (UnwrapMaybe | UnwrapError) | BoolOrExpression
UnwrapMaybe : "??" BoolOrExpression
UnwrapError : "%%" option("|" "Symbol" "|") BoolOrExpression
*/
static AstNode *ast_parse_unwrap_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *lhs = ast_parse_bool_or_expr(pc, token_index, mandatory);
    if (!lhs)
        return nullptr;

    Token *token = &pc->tokens->at(*token_index);

    if (token->id == TokenIdDoubleQuestion) {
        *token_index += 1;

        AstNode *rhs = ast_parse_expression(pc, token_index, true);

        AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
        node->data.bin_op_expr.op1 = lhs;
        node->data.bin_op_expr.bin_op = BinOpTypeUnwrapMaybe;
        node->data.bin_op_expr.op2 = rhs;

        normalize_parent_ptrs(node);
        return node;
    } else if (token->id == TokenIdPercentPercent) {
        *token_index += 1;

        AstNode *node = ast_create_node(pc, NodeTypeUnwrapErrorExpr, token);
        node->data.unwrap_err_expr.op1 = lhs;

        Token *maybe_bar_tok = &pc->tokens->at(*token_index);
        if (maybe_bar_tok->id == TokenIdBinOr) {
            *token_index += 1;
            node->data.unwrap_err_expr.symbol = ast_parse_symbol(pc, token_index);
            ast_eat_token(pc, token_index, TokenIdBinOr);
        }
        node->data.unwrap_err_expr.op2 = ast_parse_expression(pc, token_index, true);

        normalize_parent_ptrs(node);
        return node;
    } else {
        return lhs;
    }
}

/*
AssignmentExpression : UnwrapExpression AssignmentOperator UnwrapExpression | UnwrapExpression
*/
static AstNode *ast_parse_ass_expr(ParseContext *pc, int *token_index, bool mandatory) {
    AstNode *lhs = ast_parse_unwrap_expr(pc, token_index, mandatory);
    if (!lhs)
        return nullptr;

    Token *token = &pc->tokens->at(*token_index);
    BinOpType ass_op = ast_parse_ass_op(pc, token_index, false);
    if (ass_op == BinOpTypeInvalid)
        return lhs;

    AstNode *rhs = ast_parse_unwrap_expr(pc, token_index, true);

    AstNode *node = ast_create_node(pc, NodeTypeBinOpExpr, token);
    node->data.bin_op_expr.op1 = lhs;
    node->data.bin_op_expr.bin_op = ass_op;
    node->data.bin_op_expr.op2 = rhs;

    normalize_parent_ptrs(node);
    return node;
}

/*
NonBlockExpression : ReturnExpression | AssignmentExpression
*/
static AstNode *ast_parse_non_block_expr(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *return_expr = ast_parse_return_expr(pc, token_index);
    if (return_expr)
        return return_expr;

    AstNode *ass_expr = ast_parse_ass_expr(pc, token_index, false);
    if (ass_expr)
        return ass_expr;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

/*
Expression : BlockExpression | NonBlockExpression
*/
static AstNode *ast_parse_expression(ParseContext *pc, int *token_index, bool mandatory) {
    Token *token = &pc->tokens->at(*token_index);

    AstNode *block_expr = ast_parse_block_expr(pc, token_index, false);
    if (block_expr)
        return block_expr;

    AstNode *non_block_expr = ast_parse_non_block_expr(pc, token_index, false);
    if (non_block_expr)
        return non_block_expr;

    if (mandatory)
        ast_invalid_token_error(pc, token);

    return nullptr;
}

/*
Label: token(Symbol) token(Colon)
*/
static AstNode *ast_parse_label(ParseContext *pc, int *token_index, bool mandatory) {
    Token *symbol_token = &pc->tokens->at(*token_index);
    if (symbol_token->id != TokenIdSymbol) {
        if (mandatory) {
            ast_expect_token(pc, symbol_token, TokenIdSymbol);
        } else {
            return nullptr;
        }
    }

    Token *colon_token = &pc->tokens->at(*token_index + 1);
    if (colon_token->id != TokenIdColon) {
        if (mandatory) {
            ast_expect_token(pc, colon_token, TokenIdColon);
        } else {
            return nullptr;
        }
    }

    *token_index += 2;

    AstNode *node = ast_create_node(pc, NodeTypeLabel, symbol_token);
    ast_buf_from_token(pc, symbol_token, &node->data.label.name);
    return node;
}

static AstNode *ast_create_void_expr(ParseContext *pc, Token *token) {
    AstNode *node = ast_create_node(pc, NodeTypeContainerInitExpr, token);
    node->data.container_init_expr.type = ast_create_node(pc, NodeTypeSymbol, token);
    node->data.container_init_expr.kind = ContainerInitKindArray;
    buf_init_from_str(&node->data.container_init_expr.type->data.symbol_expr.symbol, "void");
    normalize_parent_ptrs(node);
    return node;
}

/*
Block : token(LBrace) list(option(Statement), token(Semicolon)) token(RBrace)
Statement = Label | VariableDeclaration ";" | Defer ";" | NonBlockExpression ";" | BlockExpression
*/
static AstNode *ast_parse_block(ParseContext *pc, int *token_index, bool mandatory) {
    Token *last_token = &pc->tokens->at(*token_index);

    if (last_token->id != TokenIdLBrace) {
        if (mandatory) {
            ast_expect_token(pc, last_token, TokenIdLBrace);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeBlock, last_token);

    // {}   -> {void}
    // {;}  -> {void;void}
    // {2}  -> {2}
    // {2;} -> {2;void}
    // {;2} -> {void;2}
    for (;;) {
        AstNode *statement_node = ast_parse_label(pc, token_index, false);
        bool semicolon_expected;
        if (statement_node) {
            semicolon_expected = false;
        } else {
            statement_node = ast_parse_variable_declaration_expr(pc, token_index, false,
                    nullptr, VisibModPrivate);
            if (!statement_node) {
                statement_node = ast_parse_defer_expr(pc, token_index);
            }
            if (statement_node) {
                semicolon_expected = true;
            } else {
                statement_node = ast_parse_block_expr(pc, token_index, false);
                semicolon_expected = !statement_node;
                if (!statement_node) {
                    statement_node = ast_parse_non_block_expr(pc, token_index, false);
                    if (!statement_node) {
                        statement_node = ast_create_void_expr(pc, last_token);
                    }
                }
            }
        }
        node->data.block.statements.append(statement_node);

        last_token = &pc->tokens->at(*token_index);
        if (last_token->id == TokenIdRBrace) {
            *token_index += 1;

            normalize_parent_ptrs(node);
            return node;
        } else if (!semicolon_expected) {
            continue;
        } else if (last_token->id == TokenIdSemicolon) {
            *token_index += 1;
        } else {
            ast_invalid_token_error(pc, last_token);
        }
    }
    zig_unreachable();
}

/*
FnProto = "fn" option("Symbol") ParamDeclList option("->" TypeExpr)
*/
static AstNode *ast_parse_fn_proto(ParseContext *pc, int *token_index, bool mandatory,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);

    if (first_token->id != TokenIdKeywordFn) {
        if (mandatory) {
            ast_expect_token(pc, first_token, TokenIdKeywordFn);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeFnProto, first_token);
    node->data.fn_proto.top_level_decl.visib_mod = visib_mod;
    node->data.fn_proto.top_level_decl.directives = directives;

    Token *fn_name = &pc->tokens->at(*token_index);
    if (fn_name->id == TokenIdSymbol) {
        *token_index += 1;
        ast_buf_from_token(pc, fn_name, &node->data.fn_proto.name);
    } else {
        buf_resize(&node->data.fn_proto.name, 0);
    }

    ast_parse_param_decl_list(pc, token_index, &node->data.fn_proto.params, &node->data.fn_proto.is_var_args);

    Token *next_token = &pc->tokens->at(*token_index);
    if (next_token->id == TokenIdArrow) {
        *token_index += 1;
        node->data.fn_proto.return_type = ast_parse_prefix_op_expr(pc, token_index, false);
    } else {
        node->data.fn_proto.return_type = ast_create_void_type_node(pc, next_token);
    }

    normalize_parent_ptrs(node);
    return node;
}

/*
FnDef = option("inline" | "extern") FnProto Block
*/
static AstNode *ast_parse_fn_def(ParseContext *pc, int *token_index, bool mandatory,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);
    bool is_inline;
    bool is_extern;
    if (first_token->id == TokenIdKeywordInline) {
        *token_index += 1;
        is_inline = true;
        is_extern = false;
    } else if (first_token->id == TokenIdKeywordExtern) {
        *token_index += 1;
        is_extern = true;
        is_inline = false;
    } else {
        is_inline = false;
        is_extern = false;
    }

    AstNode *fn_proto = ast_parse_fn_proto(pc, token_index, mandatory, directives, visib_mod);
    if (!fn_proto) {
        if (is_inline || is_extern) {
            *token_index -= 1;
        }
        return nullptr;
    }

    fn_proto->data.fn_proto.is_inline = is_inline;
    fn_proto->data.fn_proto.is_extern = is_extern;

    Token *semi_token = &pc->tokens->at(*token_index);
    if (semi_token->id == TokenIdSemicolon) {
        *token_index += 1;
        normalize_parent_ptrs(fn_proto);
        return fn_proto;
    }

    AstNode *node = ast_create_node(pc, NodeTypeFnDef, first_token);
    node->data.fn_def.fn_proto = fn_proto;
    node->data.fn_def.body = ast_parse_block(pc, token_index, true);
    normalize_parent_ptrs(node);
    return node;
}

/*
ExternDecl = "extern" (FnProto | VariableDeclaration) ";"
*/
static AstNode *ast_parse_extern_decl(ParseContext *pc, int *token_index, bool mandatory,
        ZigList<AstNode *> *directives, VisibMod visib_mod)
{
    Token *extern_kw = &pc->tokens->at(*token_index);
    if (extern_kw->id != TokenIdKeywordExtern) {
        if (mandatory) {
            ast_expect_token(pc, extern_kw, TokenIdKeywordExtern);
        } else {
            return nullptr;
        }
    }
    *token_index += 1;

    AstNode *fn_proto_node = ast_parse_fn_proto(pc, token_index, false, directives, visib_mod);
    if (fn_proto_node) {
        ast_eat_token(pc, token_index, TokenIdSemicolon);

        fn_proto_node->data.fn_proto.is_extern = true;

        normalize_parent_ptrs(fn_proto_node);
        return fn_proto_node;
    }

    AstNode *var_decl_node = ast_parse_variable_declaration_expr(pc, token_index, false, directives, visib_mod);
    if (var_decl_node) {
        ast_eat_token(pc, token_index, TokenIdSemicolon);

        var_decl_node->data.variable_declaration.is_extern = true;

        normalize_parent_ptrs(var_decl_node);
        return var_decl_node;
    }

    Token *token = &pc->tokens->at(*token_index);
    ast_invalid_token_error(pc, token);
}

/*
UseDecl = "use" Expression ";"
*/
static AstNode *ast_parse_use(ParseContext *pc, int *token_index,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *use_kw = &pc->tokens->at(*token_index);
    if (use_kw->id != TokenIdKeywordUse)
        return nullptr;
    *token_index += 1;

    AstNode *node = ast_create_node(pc, NodeTypeUse, use_kw);
    node->data.use.top_level_decl.visib_mod = visib_mod;
    node->data.use.top_level_decl.directives = directives;
    node->data.use.expr = ast_parse_expression(pc, token_index, true);

    ast_eat_token(pc, token_index, TokenIdSemicolon);

    normalize_parent_ptrs(node);
    return node;
}

/*
ContainerDecl = ("struct" | "enum" | "union") "Symbol" option(ParamDeclList) "{" many(StructMember) "}"
StructMember = many(Directive) option(VisibleMod) (StructField | FnDef | GlobalVarDecl | ContainerDecl)
StructField : "Symbol" option(":" Expression) ",")
*/
static AstNode *ast_parse_container_decl(ParseContext *pc, int *token_index,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);

    ContainerKind kind;

    if (first_token->id == TokenIdKeywordStruct) {
        kind = ContainerKindStruct;
    } else if (first_token->id == TokenIdKeywordEnum) {
        kind = ContainerKindEnum;
    } else if (first_token->id == TokenIdKeywordUnion) {
        kind = ContainerKindUnion;
    } else {
        return nullptr;
    }
    *token_index += 1;

    Token *struct_name = ast_eat_token(pc, token_index, TokenIdSymbol);

    AstNode *node = ast_create_node(pc, NodeTypeContainerDecl, first_token);
    node->data.struct_decl.kind = kind;
    ast_buf_from_token(pc, struct_name, &node->data.struct_decl.name);
    node->data.struct_decl.top_level_decl.visib_mod = visib_mod;
    node->data.struct_decl.top_level_decl.directives = directives;

    Token *paren_or_brace = &pc->tokens->at(*token_index);
    if (paren_or_brace->id == TokenIdLParen) {
        ast_parse_param_decl_list(pc, token_index, &node->data.struct_decl.generic_params,
                &node->data.struct_decl.generic_params_is_var_args);
        ast_eat_token(pc, token_index, TokenIdLBrace);
    } else if (paren_or_brace->id == TokenIdLBrace) {
        *token_index += 1;
    } else {
        ast_invalid_token_error(pc, paren_or_brace);
    }

    for (;;) {
        Token *directive_token = &pc->tokens->at(*token_index);
        ZigList<AstNode *> *directive_list = allocate<ZigList<AstNode*>>(1);
        ast_parse_directives(pc, token_index, directive_list);

        Token *visib_tok = &pc->tokens->at(*token_index);
        VisibMod visib_mod;
        if (visib_tok->id == TokenIdKeywordPub) {
            *token_index += 1;
            visib_mod = VisibModPub;
        } else if (visib_tok->id == TokenIdKeywordExport) {
            *token_index += 1;
            visib_mod = VisibModExport;
        } else {
            visib_mod = VisibModPrivate;
        }

        AstNode *fn_def_node = ast_parse_fn_def(pc, token_index, false, directive_list, visib_mod);
        if (fn_def_node) {
            node->data.struct_decl.decls.append(fn_def_node);
            continue;
        }

        AstNode *var_decl_node = ast_parse_variable_declaration_expr(pc, token_index, false, directive_list, visib_mod);
        if (var_decl_node) {
            ast_eat_token(pc, token_index, TokenIdSemicolon);
            node->data.struct_decl.decls.append(var_decl_node);
            continue;
        }

        AstNode *container_decl_node = ast_parse_container_decl(pc, token_index, directive_list, visib_mod);
        if (container_decl_node) {
            node->data.struct_decl.decls.append(container_decl_node);
            continue;
        }

        Token *token = &pc->tokens->at(*token_index);

        if (token->id == TokenIdRBrace) {
            if (directive_list->length > 0) {
                ast_error(pc, directive_token, "invalid directive");
            }

            *token_index += 1;
            break;
        } else if (token->id == TokenIdSymbol) {
            AstNode *field_node = ast_create_node(pc, NodeTypeStructField, token);
            *token_index += 1;

            field_node->data.struct_field.top_level_decl.visib_mod = visib_mod;
            field_node->data.struct_field.top_level_decl.directives = directive_list;

            ast_buf_from_token(pc, token, &field_node->data.struct_field.name);

            Token *expr_or_comma = &pc->tokens->at(*token_index);
            if (expr_or_comma->id == TokenIdComma) {
                field_node->data.struct_field.type = ast_create_void_type_node(pc, expr_or_comma);
                *token_index += 1;
            } else {
                ast_eat_token(pc, token_index, TokenIdColon);
                field_node->data.struct_field.type = ast_parse_expression(pc, token_index, true);
                ast_eat_token(pc, token_index, TokenIdComma);
            }

            node->data.struct_decl.fields.append(field_node);
            normalize_parent_ptrs(field_node);
        } else {
            ast_invalid_token_error(pc, token);
        }
    }

    normalize_parent_ptrs(node);
    return node;
}

/*
ErrorValueDecl : "error" "Symbol" ";"
*/
static AstNode *ast_parse_error_value_decl(ParseContext *pc, int *token_index,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);

    if (first_token->id != TokenIdKeywordError) {
        return nullptr;
    }
    *token_index += 1;

    Token *name_tok = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdSemicolon);

    AstNode *node = ast_create_node(pc, NodeTypeErrorValueDecl, first_token);
    node->data.error_value_decl.top_level_decl.visib_mod = visib_mod;
    node->data.error_value_decl.top_level_decl.directives = directives;
    ast_buf_from_token(pc, name_tok, &node->data.error_value_decl.name);

    normalize_parent_ptrs(node);
    return node;
}

/*
TypeDecl = "type" "Symbol" "=" TypeExpr ";"
*/
static AstNode *ast_parse_type_decl(ParseContext *pc, int *token_index,
        ZigList<AstNode*> *directives, VisibMod visib_mod)
{
    Token *first_token = &pc->tokens->at(*token_index);

    if (first_token->id != TokenIdKeywordType) {
        return nullptr;
    }
    *token_index += 1;

    Token *name_tok = ast_eat_token(pc, token_index, TokenIdSymbol);
    ast_eat_token(pc, token_index, TokenIdEq);

    AstNode *node = ast_create_node(pc, NodeTypeTypeDecl, first_token);
    ast_buf_from_token(pc, name_tok, &node->data.type_decl.symbol);
    node->data.type_decl.child_type = ast_parse_prefix_op_expr(pc, token_index, true);

    ast_eat_token(pc, token_index, TokenIdSemicolon);

    node->data.type_decl.top_level_decl.visib_mod = visib_mod;
    node->data.type_decl.top_level_decl.directives = directives;

    normalize_parent_ptrs(node);
    return node;
}

/*
TopLevelDecl = many(Directive) option(VisibleMod) (FnDef | ExternDecl | Import | ContainerDecl | GlobalVarDecl | ErrorValueDecl | CImportDecl | TypeDecl)
*/
static void ast_parse_top_level_decls(ParseContext *pc, int *token_index, ZigList<AstNode *> *top_level_decls) {
    for (;;) {
        Token *directive_token = &pc->tokens->at(*token_index);
        ZigList<AstNode *> *directives = allocate<ZigList<AstNode*>>(1);
        ast_parse_directives(pc, token_index, directives);

        Token *visib_tok = &pc->tokens->at(*token_index);
        VisibMod visib_mod;
        if (visib_tok->id == TokenIdKeywordPub) {
            *token_index += 1;
            visib_mod = VisibModPub;
        } else if (visib_tok->id == TokenIdKeywordExport) {
            *token_index += 1;
            visib_mod = VisibModExport;
        } else {
            visib_mod = VisibModPrivate;
        }

        AstNode *fn_def_node = ast_parse_fn_def(pc, token_index, false, directives, visib_mod);
        if (fn_def_node) {
            top_level_decls->append(fn_def_node);
            continue;
        }

        AstNode *fn_proto_node = ast_parse_extern_decl(pc, token_index, false, directives, visib_mod);
        if (fn_proto_node) {
            top_level_decls->append(fn_proto_node);
            continue;
        }

        AstNode *use_node = ast_parse_use(pc, token_index, directives, visib_mod);
        if (use_node) {
            top_level_decls->append(use_node);
            continue;
        }

        AstNode *struct_node = ast_parse_container_decl(pc, token_index, directives, visib_mod);
        if (struct_node) {
            top_level_decls->append(struct_node);
            continue;
        }

        AstNode *var_decl_node = ast_parse_variable_declaration_expr(pc, token_index, false,
                directives, visib_mod);
        if (var_decl_node) {
            ast_eat_token(pc, token_index, TokenIdSemicolon);
            top_level_decls->append(var_decl_node);
            continue;
        }

        AstNode *error_value_node = ast_parse_error_value_decl(pc, token_index, directives, visib_mod);
        if (error_value_node) {
            top_level_decls->append(error_value_node);
            continue;
        }

        AstNode *type_decl_node = ast_parse_type_decl(pc, token_index, directives, visib_mod);
        if (type_decl_node) {
            top_level_decls->append(type_decl_node);
            continue;
        }

        if (directives->length > 0) {
            ast_error(pc, directive_token, "invalid directive");
        }

        return;
    }
    zig_unreachable();
}

/*
Root : many(TopLevelDecl) token(EOF)
 */
static AstNode *ast_parse_root(ParseContext *pc, int *token_index) {
    AstNode *node = ast_create_node(pc, NodeTypeRoot, &pc->tokens->at(*token_index));

    ast_parse_top_level_decls(pc, token_index, &node->data.root.top_level_decls);

    if (*token_index != pc->tokens->length - 1) {
        ast_invalid_token_error(pc, &pc->tokens->at(*token_index));
    }

    normalize_parent_ptrs(node);
    return node;
}

AstNode *ast_parse(Buf *buf, ZigList<Token> *tokens, ImportTableEntry *owner,
        ErrColor err_color, uint32_t *next_node_index)
{
    ParseContext pc = {0};
    pc.err_color = err_color;
    pc.owner = owner;
    pc.buf = buf;
    pc.tokens = tokens;
    pc.next_node_index = next_node_index;
    int token_index = 0;
    pc.root = ast_parse_root(&pc, &token_index);
    return pc.root;
}

static void visit_field(AstNode **node, void (*visit)(AstNode **, void *context), void *context) {
    if (*node) {
        visit(node, context);
    }
}

static void visit_node_list(ZigList<AstNode *> *list, void (*visit)(AstNode **, void *context), void *context) {
    if (list) {
        for (int i = 0; i < list->length; i += 1) {
            visit(&list->at(i), context);
        }
    }
}

void ast_visit_node_children(AstNode *node, void (*visit)(AstNode **, void *context), void *context) {
    switch (node->type) {
        case NodeTypeRoot:
            visit_node_list(&node->data.root.top_level_decls, visit, context);
            break;
        case NodeTypeFnProto:
            visit_field(&node->data.fn_proto.return_type, visit, context);
            visit_node_list(node->data.fn_proto.top_level_decl.directives, visit, context);
            visit_node_list(&node->data.fn_proto.params, visit, context);
            break;
        case NodeTypeFnDef:
            visit_field(&node->data.fn_def.fn_proto, visit, context);
            visit_field(&node->data.fn_def.body, visit, context);
            break;
        case NodeTypeFnDecl:
            visit_field(&node->data.fn_decl.fn_proto, visit, context);
            break;
        case NodeTypeParamDecl:
            visit_field(&node->data.param_decl.type, visit, context);
            break;
        case NodeTypeBlock:
            visit_node_list(&node->data.block.statements, visit, context);
            break;
        case NodeTypeDirective:
            visit_field(&node->data.directive.expr, visit, context);
            break;
        case NodeTypeReturnExpr:
            visit_field(&node->data.return_expr.expr, visit, context);
            break;
        case NodeTypeDefer:
            visit_field(&node->data.defer.expr, visit, context);
            break;
        case NodeTypeVariableDeclaration:
            visit_node_list(node->data.variable_declaration.top_level_decl.directives, visit, context);
            visit_field(&node->data.variable_declaration.type, visit, context);
            visit_field(&node->data.variable_declaration.expr, visit, context);
            break;
        case NodeTypeTypeDecl:
            visit_node_list(node->data.type_decl.top_level_decl.directives, visit, context);
            visit_field(&node->data.type_decl.child_type, visit, context);
            break;
        case NodeTypeErrorValueDecl:
            // none
            break;
        case NodeTypeBinOpExpr:
            visit_field(&node->data.bin_op_expr.op1, visit, context);
            visit_field(&node->data.bin_op_expr.op2, visit, context);
            break;
        case NodeTypeUnwrapErrorExpr:
            visit_field(&node->data.unwrap_err_expr.op1, visit, context);
            visit_field(&node->data.unwrap_err_expr.symbol, visit, context);
            visit_field(&node->data.unwrap_err_expr.op2, visit, context);
            break;
        case NodeTypeNumberLiteral:
            // none
            break;
        case NodeTypeStringLiteral:
            // none
            break;
        case NodeTypeCharLiteral:
            // none
            break;
        case NodeTypeSymbol:
            // none
            break;
        case NodeTypePrefixOpExpr:
            visit_field(&node->data.prefix_op_expr.primary_expr, visit, context);
            break;
        case NodeTypeFnCallExpr:
            visit_field(&node->data.fn_call_expr.fn_ref_expr, visit, context);
            visit_node_list(&node->data.fn_call_expr.params, visit, context);
            break;
        case NodeTypeArrayAccessExpr:
            visit_field(&node->data.array_access_expr.array_ref_expr, visit, context);
            visit_field(&node->data.array_access_expr.subscript, visit, context);
            break;
        case NodeTypeSliceExpr:
            visit_field(&node->data.slice_expr.array_ref_expr, visit, context);
            visit_field(&node->data.slice_expr.start, visit, context);
            visit_field(&node->data.slice_expr.end, visit, context);
            break;
        case NodeTypeFieldAccessExpr:
            visit_field(&node->data.field_access_expr.struct_expr, visit, context);
            break;
        case NodeTypeUse:
            visit_field(&node->data.use.expr, visit, context);
            visit_node_list(node->data.use.top_level_decl.directives, visit, context);
            break;
        case NodeTypeBoolLiteral:
            // none
            break;
        case NodeTypeNullLiteral:
            // none
            break;
        case NodeTypeUndefinedLiteral:
            // none
            break;
        case NodeTypeIfBoolExpr:
            visit_field(&node->data.if_bool_expr.condition, visit, context);
            visit_field(&node->data.if_bool_expr.then_block, visit, context);
            visit_field(&node->data.if_bool_expr.else_node, visit, context);
            break;
        case NodeTypeIfVarExpr:
            visit_field(&node->data.if_var_expr.var_decl.type, visit, context);
            visit_field(&node->data.if_var_expr.var_decl.expr, visit, context);
            visit_field(&node->data.if_var_expr.then_block, visit, context);
            visit_field(&node->data.if_var_expr.else_node, visit, context);
            break;
        case NodeTypeWhileExpr:
            visit_field(&node->data.while_expr.condition, visit, context);
            visit_field(&node->data.while_expr.body, visit, context);
            break;
        case NodeTypeForExpr:
            visit_field(&node->data.for_expr.elem_node, visit, context);
            visit_field(&node->data.for_expr.array_expr, visit, context);
            visit_field(&node->data.for_expr.index_node, visit, context);
            visit_field(&node->data.for_expr.body, visit, context);
            break;
        case NodeTypeSwitchExpr:
            visit_field(&node->data.switch_expr.expr, visit, context);
            visit_node_list(&node->data.switch_expr.prongs, visit, context);
            break;
        case NodeTypeSwitchProng:
            visit_node_list(&node->data.switch_prong.items, visit, context);
            visit_field(&node->data.switch_prong.var_symbol, visit, context);
            visit_field(&node->data.switch_prong.expr, visit, context);
            break;
        case NodeTypeSwitchRange:
            visit_field(&node->data.switch_range.start, visit, context);
            visit_field(&node->data.switch_range.end, visit, context);
            break;
        case NodeTypeLabel:
            // none
            break;
        case NodeTypeGoto:
            // none
            break;
        case NodeTypeBreak:
            // none
            break;
        case NodeTypeContinue:
            // none
            break;
        case NodeTypeAsmExpr:
            for (int i = 0; i < node->data.asm_expr.input_list.length; i += 1) {
                AsmInput *asm_input = node->data.asm_expr.input_list.at(i);
                visit_field(&asm_input->expr, visit, context);
            }
            for (int i = 0; i < node->data.asm_expr.output_list.length; i += 1) {
                AsmOutput *asm_output = node->data.asm_expr.output_list.at(i);
                visit_field(&asm_output->return_type, visit, context);
            }
            break;
        case NodeTypeContainerDecl:
            visit_node_list(&node->data.struct_decl.fields, visit, context);
            visit_node_list(&node->data.struct_decl.decls, visit, context);
            visit_node_list(node->data.struct_decl.top_level_decl.directives, visit, context);
            break;
        case NodeTypeStructField:
            visit_field(&node->data.struct_field.type, visit, context);
            visit_node_list(node->data.struct_field.top_level_decl.directives, visit, context);
            break;
        case NodeTypeContainerInitExpr:
            visit_field(&node->data.container_init_expr.type, visit, context);
            visit_node_list(&node->data.container_init_expr.entries, visit, context);
            break;
        case NodeTypeStructValueField:
            visit_field(&node->data.struct_val_field.expr, visit, context);
            break;
        case NodeTypeArrayType:
            visit_field(&node->data.array_type.size, visit, context);
            visit_field(&node->data.array_type.child_type, visit, context);
            break;
        case NodeTypeErrorType:
            // none
            break;
        case NodeTypeTypeLiteral:
            // none
            break;
    }
}

static void normalize_parent_ptrs_visit(AstNode **node, void *context) {
    (*node)->parent_field = node;
}

void normalize_parent_ptrs(AstNode *node) {
    ast_visit_node_children(node, normalize_parent_ptrs_visit, nullptr);
}

static void clone_subtree_list(ZigList<AstNode *> *dest, ZigList<AstNode *> *src, uint32_t *next_node_index) {
    memset(dest, 0, sizeof(ZigList<AstNode *>));
    dest->resize(src->length);
    for (int i = 0; i < src->length; i += 1) {
        dest->at(i) = ast_clone_subtree(src->at(i), next_node_index);
        dest->at(i)->parent_field = &dest->at(i);
    }
}

static void clone_subtree_list_omit_inline_params(ZigList<AstNode *> *dest, ZigList<AstNode *> *src,
        uint32_t *next_node_index)
{
    memset(dest, 0, sizeof(ZigList<AstNode *>));
    dest->ensure_capacity(src->length);
    for (int i = 0; i < src->length; i += 1) {
        AstNode *src_node = src->at(i);
        assert(src_node->type == NodeTypeParamDecl);
        if (src_node->data.param_decl.is_inline) {
            continue;
        }
        dest->append(ast_clone_subtree(src_node, next_node_index));
        dest->last()->parent_field = &dest->last();
    }
}

static void clone_subtree_list_ptr(ZigList<AstNode *> **dest_ptr, ZigList<AstNode *> *src,
        uint32_t *next_node_index)
{
    if (src) {
        ZigList<AstNode *> *dest = allocate<ZigList<AstNode *>>(1);
        *dest_ptr = dest;
        clone_subtree_list(dest, src, next_node_index);
    }
}

static void clone_subtree_field_special(AstNode **dest, AstNode *src, uint32_t *next_node_index,
        enum AstCloneSpecial special)
{
    if (src) {
        *dest = ast_clone_subtree_special(src, next_node_index, special);
        (*dest)->parent_field = dest;
    } else {
        *dest = nullptr;
    }
}

static void clone_subtree_field(AstNode **dest, AstNode *src, uint32_t *next_node_index) {
    return clone_subtree_field_special(dest, src, next_node_index, AstCloneSpecialNone);
}

static void clone_subtree_tld(TopLevelDecl *dest, TopLevelDecl *src, uint32_t *next_node_index) {
    clone_subtree_list_ptr(&dest->directives, src->directives, next_node_index);
}

AstNode *ast_clone_subtree_special(AstNode *old_node, uint32_t *next_node_index, enum AstCloneSpecial special) {
    AstNode *new_node = allocate_nonzero<AstNode>(1);
    memcpy(new_node, old_node, sizeof(AstNode));
    new_node->create_index = *next_node_index;
    *next_node_index += 1;
    new_node->parent_field = nullptr;

    switch (new_node->type) {
        case NodeTypeRoot:
            clone_subtree_list(&new_node->data.root.top_level_decls,
                               &old_node->data.root.top_level_decls, next_node_index);
            break;
        case NodeTypeFnProto:
            clone_subtree_tld(&new_node->data.fn_proto.top_level_decl, &old_node->data.fn_proto.top_level_decl,
                    next_node_index);
            clone_subtree_field(&new_node->data.fn_proto.return_type, old_node->data.fn_proto.return_type,
                    next_node_index);

            if (special == AstCloneSpecialOmitInlineParams) {
                clone_subtree_list_omit_inline_params(&new_node->data.fn_proto.params, &old_node->data.fn_proto.params,
                        next_node_index);
            } else {
                clone_subtree_list(&new_node->data.fn_proto.params, &old_node->data.fn_proto.params,
                        next_node_index);
            }

            break;
        case NodeTypeFnDef:
            clone_subtree_field_special(&new_node->data.fn_def.fn_proto, old_node->data.fn_def.fn_proto,
                    next_node_index, special);
            new_node->data.fn_def.fn_proto->data.fn_proto.fn_def_node = new_node;
            clone_subtree_field(&new_node->data.fn_def.body, old_node->data.fn_def.body, next_node_index);
            break;
        case NodeTypeFnDecl:
            clone_subtree_field(&new_node->data.fn_decl.fn_proto, old_node->data.fn_decl.fn_proto,
                    next_node_index);
            break;
        case NodeTypeParamDecl:
            clone_subtree_field(&new_node->data.param_decl.type, old_node->data.param_decl.type, next_node_index);
            break;
        case NodeTypeBlock:
            clone_subtree_list(&new_node->data.block.statements, &old_node->data.block.statements,
                    next_node_index);
            break;
        case NodeTypeDirective:
            clone_subtree_field(&new_node->data.directive.expr, old_node->data.directive.expr, next_node_index);
            break;
        case NodeTypeReturnExpr:
            clone_subtree_field(&new_node->data.return_expr.expr, old_node->data.return_expr.expr, next_node_index);
            break;
        case NodeTypeDefer:
            clone_subtree_field(&new_node->data.defer.expr, old_node->data.defer.expr, next_node_index);
            break;
        case NodeTypeVariableDeclaration:
            clone_subtree_list_ptr(&new_node->data.variable_declaration.top_level_decl.directives,
                    old_node->data.variable_declaration.top_level_decl.directives, next_node_index);
            clone_subtree_field(&new_node->data.variable_declaration.type, old_node->data.variable_declaration.type, next_node_index);
            clone_subtree_field(&new_node->data.variable_declaration.expr, old_node->data.variable_declaration.expr, next_node_index);
            break;
        case NodeTypeTypeDecl:
            clone_subtree_list_ptr(&new_node->data.type_decl.top_level_decl.directives,
                    old_node->data.type_decl.top_level_decl.directives, next_node_index);
            clone_subtree_field(&new_node->data.type_decl.child_type, old_node->data.type_decl.child_type, next_node_index);
            break;
        case NodeTypeErrorValueDecl:
            // none
            break;
        case NodeTypeBinOpExpr:
            clone_subtree_field(&new_node->data.bin_op_expr.op1, old_node->data.bin_op_expr.op1, next_node_index);
            clone_subtree_field(&new_node->data.bin_op_expr.op2, old_node->data.bin_op_expr.op2, next_node_index);
            break;
        case NodeTypeUnwrapErrorExpr:
            clone_subtree_field(&new_node->data.unwrap_err_expr.op1, old_node->data.unwrap_err_expr.op1, next_node_index);
            clone_subtree_field(&new_node->data.unwrap_err_expr.symbol, old_node->data.unwrap_err_expr.symbol, next_node_index);
            clone_subtree_field(&new_node->data.unwrap_err_expr.op2, old_node->data.unwrap_err_expr.op2, next_node_index);
            break;
        case NodeTypeNumberLiteral:
            // none
            break;
        case NodeTypeStringLiteral:
            // none
            break;
        case NodeTypeCharLiteral:
            // none
            break;
        case NodeTypeSymbol:
            // none
            break;
        case NodeTypePrefixOpExpr:
            clone_subtree_field(&new_node->data.prefix_op_expr.primary_expr,
                                 old_node->data.prefix_op_expr.primary_expr, next_node_index);
            break;
        case NodeTypeFnCallExpr:
            assert(!old_node->data.fn_call_expr.resolved_expr.has_global_const);
            clone_subtree_field(&new_node->data.fn_call_expr.fn_ref_expr,
                                 old_node->data.fn_call_expr.fn_ref_expr, next_node_index);
            clone_subtree_list(&new_node->data.fn_call_expr.params,
                               &old_node->data.fn_call_expr.params, next_node_index);
            break;
        case NodeTypeArrayAccessExpr:
            clone_subtree_field(&new_node->data.array_access_expr.array_ref_expr,
                                 old_node->data.array_access_expr.array_ref_expr, next_node_index);
            clone_subtree_field(&new_node->data.array_access_expr.subscript,
                                 old_node->data.array_access_expr.subscript, next_node_index);
            break;
        case NodeTypeSliceExpr:
            clone_subtree_field(&new_node->data.slice_expr.array_ref_expr, old_node->data.slice_expr.array_ref_expr, next_node_index);
            clone_subtree_field(&new_node->data.slice_expr.start, old_node->data.slice_expr.start, next_node_index);
            clone_subtree_field(&new_node->data.slice_expr.end, old_node->data.slice_expr.end, next_node_index);
            break;
        case NodeTypeFieldAccessExpr:
            clone_subtree_field(&new_node->data.field_access_expr.struct_expr, old_node->data.field_access_expr.struct_expr, next_node_index);
            break;
        case NodeTypeUse:
            clone_subtree_field(&new_node->data.use.expr, old_node->data.use.expr, next_node_index);
            clone_subtree_list_ptr(&new_node->data.use.top_level_decl.directives,
                    old_node->data.use.top_level_decl.directives, next_node_index);
            break;
        case NodeTypeBoolLiteral:
            // none
            break;
        case NodeTypeNullLiteral:
            // none
            break;
        case NodeTypeUndefinedLiteral:
            // none
            break;
        case NodeTypeIfBoolExpr:
            clone_subtree_field(&new_node->data.if_bool_expr.condition, old_node->data.if_bool_expr.condition, next_node_index);
            clone_subtree_field(&new_node->data.if_bool_expr.then_block, old_node->data.if_bool_expr.then_block, next_node_index);
            clone_subtree_field(&new_node->data.if_bool_expr.else_node, old_node->data.if_bool_expr.else_node, next_node_index);
            break;
        case NodeTypeIfVarExpr:
            clone_subtree_field(&new_node->data.if_var_expr.var_decl.type, old_node->data.if_var_expr.var_decl.type, next_node_index);
            clone_subtree_field(&new_node->data.if_var_expr.var_decl.expr, old_node->data.if_var_expr.var_decl.expr, next_node_index);
            clone_subtree_field(&new_node->data.if_var_expr.then_block, old_node->data.if_var_expr.then_block, next_node_index);
            clone_subtree_field(&new_node->data.if_var_expr.else_node, old_node->data.if_var_expr.else_node, next_node_index);
            break;
        case NodeTypeWhileExpr:
            clone_subtree_field(&new_node->data.while_expr.condition, old_node->data.while_expr.condition, next_node_index);
            clone_subtree_field(&new_node->data.while_expr.body, old_node->data.while_expr.body, next_node_index);
            break;
        case NodeTypeForExpr:
            clone_subtree_field(&new_node->data.for_expr.elem_node, old_node->data.for_expr.elem_node, next_node_index);
            clone_subtree_field(&new_node->data.for_expr.array_expr, old_node->data.for_expr.array_expr, next_node_index);
            clone_subtree_field(&new_node->data.for_expr.index_node, old_node->data.for_expr.index_node, next_node_index);
            clone_subtree_field(&new_node->data.for_expr.body, old_node->data.for_expr.body, next_node_index);
            break;
        case NodeTypeSwitchExpr:
            clone_subtree_field(&new_node->data.switch_expr.expr, old_node->data.switch_expr.expr, next_node_index);
            clone_subtree_list(&new_node->data.switch_expr.prongs, &old_node->data.switch_expr.prongs,
                    next_node_index);
            break;
        case NodeTypeSwitchProng:
            clone_subtree_list(&new_node->data.switch_prong.items, &old_node->data.switch_prong.items,
                    next_node_index);
            clone_subtree_field(&new_node->data.switch_prong.var_symbol, old_node->data.switch_prong.var_symbol, next_node_index);
            clone_subtree_field(&new_node->data.switch_prong.expr, old_node->data.switch_prong.expr, next_node_index);
            break;
        case NodeTypeSwitchRange:
            clone_subtree_field(&new_node->data.switch_range.start, old_node->data.switch_range.start, next_node_index);
            clone_subtree_field(&new_node->data.switch_range.end, old_node->data.switch_range.end, next_node_index);
            break;
        case NodeTypeLabel:
            // none
            break;
        case NodeTypeGoto:
            // none
            break;
        case NodeTypeBreak:
            // none
            break;
        case NodeTypeContinue:
            // none
            break;
        case NodeTypeAsmExpr:
            zig_panic("TODO");
            break;
        case NodeTypeContainerDecl:
            clone_subtree_list(&new_node->data.struct_decl.fields, &old_node->data.struct_decl.fields,
                    next_node_index);
            clone_subtree_list(&new_node->data.struct_decl.decls, &old_node->data.struct_decl.decls,
                    next_node_index);
            clone_subtree_list_ptr(&new_node->data.struct_decl.top_level_decl.directives,
                    old_node->data.struct_decl.top_level_decl.directives, next_node_index);
            break;
        case NodeTypeStructField:
            clone_subtree_field(&new_node->data.struct_field.type, old_node->data.struct_field.type, next_node_index);
            clone_subtree_list_ptr(&new_node->data.struct_field.top_level_decl.directives,
                    old_node->data.struct_field.top_level_decl.directives, next_node_index);
            break;
        case NodeTypeContainerInitExpr:
            clone_subtree_field(&new_node->data.container_init_expr.type, old_node->data.container_init_expr.type, next_node_index);
            clone_subtree_list(&new_node->data.container_init_expr.entries,
                    &old_node->data.container_init_expr.entries, next_node_index);
            break;
        case NodeTypeStructValueField:
            clone_subtree_field(&new_node->data.struct_val_field.expr, old_node->data.struct_val_field.expr, next_node_index);
            break;
        case NodeTypeArrayType:
            clone_subtree_field(&new_node->data.array_type.size, old_node->data.array_type.size, next_node_index);
            clone_subtree_field(&new_node->data.array_type.child_type, old_node->data.array_type.child_type, next_node_index);
            break;
        case NodeTypeErrorType:
            // none
            break;
        case NodeTypeTypeLiteral:
            // none
            break;
    }

    return new_node;
}

AstNode *ast_clone_subtree(AstNode *old_node, uint32_t *next_node_index) {
    return ast_clone_subtree_special(old_node, next_node_index, AstCloneSpecialNone);
}
