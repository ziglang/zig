
const Tag = {
    invalid: "invalid",
    identifier: "identifier",
    string_literal: "string_literal",
    multiline_string_literal_line: "multiline_string_literal_line",
    char_literal: "char_literal",
    eof: "eof",
    builtin: "builtin",
    number_literal: "number_literal",
    doc_comment: "doc_comment",
    container_doc_comment: "container_doc_comment",
    invalid_periodasterisks: ".**",
    bang: "!",
    pipe: "|",
    pipe_pipe: "||",
    pipe_equal: "|=",
    equal: "=",
    equal_equal: "==",
    equal_angle_bracket_right: "=>",
    bang_equal: "!=",
    l_paren: "(",
    r_paren: ")",
    semicolon: ";",
    percent: "%",
    percent_equal: "%=",
    l_brace: "{",
    r_brace: "}",
    l_bracket: "[",
    r_bracket: "]",
    period: ".",
    period_asterisk: ".*",
    ellipsis2: "..",
    ellipsis3: "...",
    caret: "^",
    caret_equal: "^=",
    plus: "+",
    plus_plus: "++",
    plus_equal: "+=",
    plus_percent: "+%",
    plus_percent_equal: "+%=",
    plus_pipe: "+|",
    plus_pipe_equal: "+|=",
    minus: "-",
    minus_equal: "-=",
    minus_percent: "-%",
    minus_percent_equal: "-%=",
    minus_pipe: "-|",
    minus_pipe_equal: "-|=",
    asterisk: "*",
    asterisk_equal: "*=",
    asterisk_asterisk: "**",
    asterisk_percent: "*%",
    asterisk_percent_equal: "*%=",
    asterisk_pipe: "*|",
    asterisk_pipe_equal: "*|=",
    arrow: "->",
    colon: ":",
    slash: "/",
    slash_equal: "/=",
    comma: ",",
    ampersand: "&",
    ampersand_equal: "&=",
    question_mark: "?",
    angle_bracket_left: "<",
    angle_bracket_left_equal: "<=",
    angle_bracket_angle_bracket_left: "<<",
    angle_bracket_angle_bracket_left_equal: "<<=",
    angle_bracket_angle_bracket_left_pipe: "<<|",
    angle_bracket_angle_bracket_left_pipe_equal: "<<|=",
    angle_bracket_right: ">",
    angle_bracket_right_equal: ">=",
    angle_bracket_angle_bracket_right: ">>",
    angle_bracket_angle_bracket_right_equal: ">>=",
    tilde: "~",
    keyword_addrspace: "addrspace",
    keyword_align: "align",
    keyword_allowzero: "allowzero",
    keyword_and: "and",
    keyword_anyframe: "anyframe",
    keyword_anytype: "anytype",
    keyword_asm: "asm",
    keyword_async: "async",
    keyword_await: "await",
    keyword_break: "break",
    keyword_callconv: "callconv",
    keyword_catch: "catch",
    keyword_comptime: "comptime",
    keyword_const: "const",
    keyword_continue: "continue",
    keyword_defer: "defer",
    keyword_else: "else",
    keyword_enum: "enum",
    keyword_errdefer: "errdefer",
    keyword_error: "error",
    keyword_export: "export",
    keyword_extern: "extern",
    keyword_fn: "fn",
    keyword_for: "for",
    keyword_if: "if",
    keyword_inline: "inline",
    keyword_noalias: "noalias",
    keyword_noinline: "noinline",
    keyword_nosuspend: "nosuspend",
    keyword_opaque: "opaque",
    keyword_or: "or",
    keyword_orelse: "orelse",
    keyword_packed: "packed",
    keyword_pub: "pub",
    keyword_resume: "resume",
    keyword_return: "return",
    keyword_linksection: "linksection",
    keyword_struct: "struct",
    keyword_suspend: "suspend",
    keyword_switch: "switch",
    keyword_test: "test",
    keyword_threadlocal: "threadlocal",
    keyword_try: "try",
    keyword_union: "union",
    keyword_unreachable: "unreachable",
    keyword_usingnamespace: "usingnamespace",
    keyword_var: "var",
    keyword_volatile: "volatile",
    keyword_while: "while"
}

const State = {
    start: 0,
    identifier: 1,
    builtin: 2,
    string_literal: 3,
    string_literal_backslash: 4,
    multiline_string_literal_line: 5,
    char_literal: 6,
    char_literal_backslash: 7,
    char_literal_hex_escape: 8,
    char_literal_unicode_escape_saw_u: 9,
    char_literal_unicode_escape: 10,
    char_literal_unicode_invalid: 11,
    char_literal_unicode: 12,
    char_literal_end: 13,
    backslash: 14,
    equal: 15,
    bang: 16,
    pipe: 17,
    minus: 18,
    minus_percent: 19,
    minus_pipe: 20,
    asterisk: 21,
    asterisk_percent: 22,
    asterisk_pipe: 23,
    slash: 24,
    line_comment_start: 25,
    line_comment: 26,
    doc_comment_start: 27,
    doc_comment: 28,
    int: 29,
    int_exponent: 30,
    int_period: 31,
    float: 32,
    float_exponent: 33,
    ampersand: 34,
    caret: 35,
    percent: 36,
    plus: 37,
    plus_percent: 38,
    plus_pipe: 39,
    angle_bracket_left: 40,
    angle_bracket_angle_bracket_left: 41,
    angle_bracket_angle_bracket_left_pipe: 42,
    angle_bracket_right: 43,
    angle_bracket_angle_bracket_right: 44,
    period: 45,
    period_2: 46,
    period_asterisk: 47,
    saw_at_sign: 48,
}

const keywords = {
    "addrspace": Tag.keyword_addrspace,
    "align": Tag.keyword_align,
    "allowzero": Tag.keyword_allowzero,
    "and": Tag.keyword_and,
    "anyframe": Tag.keyword_anyframe,
    "anytype": Tag.keyword_anytype,
    "asm": Tag.keyword_asm,
    "async": Tag.keyword_async,
    "await": Tag.keyword_await,
    "break": Tag.keyword_break,
    "callconv": Tag.keyword_callconv,
    "catch": Tag.keyword_catch,
    "comptime": Tag.keyword_comptime,
    "const": Tag.keyword_const,
    "continue": Tag.keyword_continue,
    "defer": Tag.keyword_defer,
    "else": Tag.keyword_else,
    "enum": Tag.keyword_enum,
    "errdefer": Tag.keyword_errdefer,
    "error": Tag.keyword_error,
    "export": Tag.keyword_export,
    "extern": Tag.keyword_extern,
    "fn": Tag.keyword_fn,
    "for": Tag.keyword_for,
    "if": Tag.keyword_if,
    "inline": Tag.keyword_inline,
    "noalias": Tag.keyword_noalias,
    "noinline": Tag.keyword_noinline,
    "nosuspend": Tag.keyword_nosuspend,
    "opaque": Tag.keyword_opaque,
    "or": Tag.keyword_or,
    "orelse": Tag.keyword_orelse,
    "packed": Tag.keyword_packed,
    "pub": Tag.keyword_pub,
    "resume": Tag.keyword_resume,
    "return": Tag.keyword_return,
    "linksection": Tag.keyword_linksection,
    "struct": Tag.keyword_struct,
    "suspend": Tag.keyword_suspend,
    "switch": Tag.keyword_switch,
    "test": Tag.keyword_test,
    "threadlocal": Tag.keyword_threadlocal,
    "try": Tag.keyword_try,
    "union": Tag.keyword_union,
    "unreachable": Tag.keyword_unreachable,
    "usingnamespace": Tag.keyword_usingnamespace,
    "var": Tag.keyword_var,
    "volatile": Tag.keyword_volatile,
    "while": Tag.keyword_while,
};

function make_token(tag, start, end) {
    return {
        tag: tag,
        loc: {
            start: start,
            end: end
        }
    }

}

function dump_tokens(tokens) {

    //TODO: this is not very fast
    function find_tag_key(tag) {
        for (const [key, value] of Object.entries(Tag)) {
            if (value == tag) return key;
        }
    }

    for (let i = 0; i < tokens.length; i++) {
        const tok = tokens[i];
        console.log(`${find_tag_key(tok.tag)} "${tok.tag}"`)
    }
}



function tokenize_zig_source(raw_source) {

    var index = -1;
    var flag = false;

    let seen_escape_digits = undefined;
    let remaining_code_units = undefined;

    const next = () => {
        let state = State.start;

        var result = {
            tag: -1,
            loc: {
                start: index,
                end: undefined,
            },
        };

        //having a while (true) loop seems like a bad idea the loop should never
        //take more iterations than twice the length of the source code
        const MAX_ITERATIONS = raw_source.length * 2;
        let iterations = 0;

        while (iterations <= MAX_ITERATIONS) {

            if (flag) {
                return make_token(Tag.eof, index, index);
            }
            iterations += 1; // avoid death loops
            index += 1;
            var c = raw_source[index];

            if (c === undefined) {
                c = ' '; // push the last token
                flag = true;
            }

            switch (state) {
                case State.start:
                    switch (c) {
                        case 0: {
                            if (index != raw_source.length) {
                                result.tag = Tag.invalid;
                                result.loc.start = index;
                                index += 1;
                                result.loc.end = index;
                                return result;
                            }
                            result.loc.end = index;
                            return result;
                        }
                        case ' ':
                        case '\n':
                        case '\t':
                        case '\r': {
                            result.loc.start = index + 1;
                            break;
                        }
                        case '"': {
                            state = State.string_literal;
                            result.tag = Tag.string_literal;
                            break;
                        }
                        case '\'': {
                            state = State.char_literal;
                            break;
                        }
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':
                        case 'p':
                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'P':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '_': {
                            state = State.identifier;
                            result.tag = Tag.identifier;
                            break;
                        }
                        case '@': {
                            state = State.saw_at_sign;
                            break;
                        }
                        case '=': {
                            state = State.equal;
                            break;
                        }
                        case '!': {
                            state = State.bang;
                            break;
                        }
                        case '|': {
                            state = State.pipe;
                        }
                        case '(': {
                            result.tag = Tag.l_paren;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case ')': {
                            result.tag = Tag.r_paren;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '[': {
                            result.tag = Tag.l_bracket;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case ']': {
                            result.tag = Tag.r_bracket;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case ';': {
                            result.tag = Tag.semicolon;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case ',': {
                            result.tag = Tag.comma;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '?': {
                            result.tag = Tag.question_mark;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case ':': {
                            result.tag = Tag.colon;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '%': {
                            state = State.percent; break;
                        }
                        case '*': {
                            state = State.asterisk; break;
                        }
                        case '+': {
                            state = State.plus; break;
                        }
                        case '<': {
                            state = State.angle_bracket_left; break;
                        }
                        case '>': {
                            state = State.angle_bracket_right; break;
                        }
                        case '^': {
                            state = State.caret; break;
                        }
                        case '\\': {
                            state = State.backslash;
                            result.tag = Tag.multiline_string_literal_line; break;
                        }
                        case '{': {
                            result.tag = Tag.l_brace;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '}': {
                            result.tag = Tag.r_brace;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '~': {
                            result.tag = Tag.tilde;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '.': {
                            state = State.period; break;
                        }
                        case '-': {
                            state = State.minus; break;
                        }
                        case '/': {
                            state = State.slash; break;
                        }
                        case '&': {
                            state = State.ampersand; break;
                        }
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9':
                            {
                                state = State.int;
                                result.tag = Tag.number_literal; break;
                            }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            index += 1;
                            return result;
                        }
                    }
                    break;
                case State.saw_at_sign:
                    switch (c) {
                        case '"': {
                            result.tag = Tag.identifier;
                            state = State.string_literal; break;
                        }
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':
                        case 'p':
                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'P':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '_': {
                            state = State.builtin;
                            result.tag = Tag.builtin; break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.ampersand:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.ampersand_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.ampersand; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.asterisk: switch (c) {
                    case '=': {
                        result.tag = Tag.asterisk_equal;
                        index += 1; result.loc.end = index;
                        return result;
                        break;
                    }
                    case '*': {
                        result.tag = Tag.asterisk_asterisk;
                        index += 1; result.loc.end = index;
                        return result;
                        break;
                    }
                    case '%': {
                        state = State.asterisk_percent; break;
                    }
                    case '|': {
                        state = State.asterisk_pipe; break;
                    }
                    default: {
                        result.tag = State.asterisk; result.loc.end = index;
                        return result;
                        break;
                    }
                }
                    break;
                case State.asterisk_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.asterisk_percent_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.asterisk_percent;
                            result.loc.end = index;
                            return result; break;
                        }
                    }
                    break;
                case State.asterisk_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.asterisk_pipe_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.asterisk_pipe; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.percent_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.percent; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.plus:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '+': {
                            result.tag = Tag.plus_plus;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        case '%': {
                            state = State.plus_percent; break;
                        }
                        case '|': {
                            state = State.plus_pipe; break;
                        }
                        default: {
                            result.tag = Tag.plus; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.plus_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_percent_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.plus_percent; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.plus_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_pipe_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.plus_pipe; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.caret:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.caret_equal;
                            index += 1; result.loc.end = index;
                            return result;
                            break;
                        }
                        default: {
                            result.tag = Tag.caret; result.loc.end = index;
                            return result;
                            break;
                        }
                    }
                    break;
                case State.identifier:
                    switch (c) {
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':
                        case 'p':
                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'P':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '_':
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9': break;
                        default: {
                            // if (Token.getKeyword(buffer[result.loc.start..index])) | tag | {
                            const z = raw_source.substring(result.loc.start, index).toLowerCase();
                            if (z in keywords) {
                                result.tag = keywords[z];
                            }
                        }
                            result.loc.end = index;
                            return result; break;

                    }
                    break;
                case State.builtin: switch (c) {
                    case 'a':
                    case 'b':
                    case 'c':
                    case 'd':
                    case 'e':
                    case 'f':
                    case 'g':
                    case 'h':
                    case 'i':
                    case 'j':
                    case 'k':
                    case 'l':
                    case 'm':
                    case 'n':
                    case 'o':
                    case 'p':
                    case 'q':
                    case 'r':
                    case 's':
                    case 't':
                    case 'u':
                    case 'v':
                    case 'w':
                    case 'x':
                    case 'y':
                    case 'z':
                    case 'A':
                    case 'B':
                    case 'C':
                    case 'D':
                    case 'E':
                    case 'F':
                    case 'G':
                    case 'H':
                    case 'I':
                    case 'J':
                    case 'K':
                    case 'L':
                    case 'M':
                    case 'N':
                    case 'O':
                    case 'P':
                    case 'Q':
                    case 'R':
                    case 'S':
                    case 'T':
                    case 'U':
                    case 'V':
                    case 'W':
                    case 'X':
                    case 'Y':
                    case 'Z':
                    case '_':
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9': break;
                    default: result.loc.end = index;
                        return result;
                }
                    break;
                case State.backslash:
                    switch (c) {
                        case '\\': {
                            state = State.multiline_string_literal_line; break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                    }
                    break;
                case State.string_literal:
                    switch (c) {
                        case '\\': {
                            state = State.string_literal_backslash; break;
                        }
                        case '"': {
                            index += 1;
                            result.loc.end = index;
                            return result; break;
                        }
                        case 0: {
                            //TODO: PORT
                            // if (index == buffer.len) {
                            //     result.tag = .invalid;
                            //     break;
                            // } else {
                            //     checkLiteralCharacter();
                            // }
                            result.loc.end = index;
                            return result; break;
                        }
                        case '\n': {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                        //TODO: PORT
                        //default: checkLiteralCharacter(),
                    }
                    break;
                case State.string_literal_backslash:
                    switch (c) {
                        case 0:
                        case '\n': {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                        default: {
                            state = State.string_literal; break;
                        }
                    }
                    break;
                case State.char_literal: switch (c) {
                    case 0: {
                        result.tag = Tag.invalid;
                        result.loc.end = index;
                        return result; break;
                    }
                    case '\\': {
                        state = State.char_literal_backslash;
                        result.loc.end = index;
                        return result; break;
                    }
                    //TODO: PORT
                    // '\'', 0x80...0xbf, 0xf8...0xff => {
                    //     result.tag = .invalid;
                    //     break;
                    // },
                    // 0xc0...0xdf => { // 110xxxxx
                    //     remaining_code_units = 1;
                    //     state = .char_literal_unicode;
                    // },
                    // 0xe0...0xef => { // 1110xxxx
                    //     remaining_code_units = 2;
                    //     state = .char_literal_unicode;
                    // },
                    // 0xf0...0xf7 => { // 11110xxx
                    //     remaining_code_units = 3;
                    //     state = .char_literal_unicode;
                    // },
                    case '\n': {
                        result.tag = Tag.invalid;
                        result.loc.end = index;
                        return result; break;
                    }
                    default: {
                        state = State.char_literal_end; break;
                    }
                }
                    break;
                case State.char_literal_backslash:
                    switch (c) {
                        case 0:
                        case '\n': {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                        case 'x': {
                            state = State.char_literal_hex_escape;
                            seen_escape_digits = 0; break;
                        }
                        case 'u': {
                            state = State.char_literal_unicode_escape_saw_u; break;
                        }
                        default: {
                            state = State.char_literal_end; break;
                        }
                    }
                    break;
                case State.char_literal_hex_escape:
                    switch (c) {
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9':
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F': {
                            seen_escape_digits += 1;
                            if (seen_escape_digits == 2) {
                                state = State.char_literal_end;
                            } break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            esult.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.char_literal_unicode_escape_saw_u:
                    switch (c) {
                        case 0: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                        case '{': {
                            state = State.char_literal_unicode_escape; break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            state = State.char_literal_unicode_invalid; break;
                            break;
                        }
                    }
                    break;
                case State.char_literal_unicode_escape:
                    switch (c) {
                        case 0: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9':
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F': break;
                        case '}': {
                            state = State.char_literal_end; // too many/few digits handled later
                            break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            state = State.char_literal_unicode_invalid; break;
                        }
                    }
                    break;
                case State.char_literal_unicode_invalid:
                    switch (c) {
                        // Keep consuming characters until an obvious stopping point.
                        // This consolidates e.g. `u{0ab1Q}` into a single invalid token
                        // instead of creating the tokens `u{0ab1`, `Q`, `}`
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'e':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':
                        case 'p':
                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'E':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'P':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '}':
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9': break;
                        default: break;
                    }
                    break;
                case State.char_literal_end:
                    switch (c) {
                        case '\'': {
                            result.tag = Tag.char_literal;
                            index += 1;
                            result.loc.end = index;
                            return result; break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                    }
                    break;
                case State.char_literal_unicode:
                    switch (c) {
                        // 0x80...0xbf => {
                        //         remaining_code_units -= 1;
                        //         if (remaining_code_units == 0) {
                        //             state = .char_literal_end;
                        //         }
                        //     },
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = index;
                            return result; break;
                        }
                    }
                    break;
                case Tag.multiline_string_literal_line:
                    switch (c) {
                        case 0: result.loc.end = index;
                            return result;;
                        case '\n': {
                            index += 1;
                            esult.loc.end = index;
                            return result;;
                        }
                        case '\t': break;
                        //TODO: PORT
                        //default: checkLiteralCharacter(),

                    }
                    break;
                case State.bang:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.bang_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.bang;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.pipe_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        case '|': {
                            result.tag = Tag.pipe_pipe;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.pipe;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.equal: switch (c) {
                    case '=': {
                        result.tag = Tag.equal_equal;
                        index += 1;
                        result.loc.end = index;
                        return result;;
                    }
                    case '>': {
                        result.tag = Tag.equal_angle_bracket_right;
                        index += 1;
                        result.loc.end = index;
                        return result;;
                    }
                    default: {
                        result.tag = Tag.equal;
                        result.loc.end = index;
                        return result;;
                    }
                }
                    break;
                case State.minus: switch (c) {
                    case '>': {
                        result.tag = Tag.arrow;
                        index += 1;
                        result.loc.end = index;
                        return result;;
                    }
                    case '=': {
                        result.tag = Tag.minus_equal;
                        index += 1;
                        result.loc.end = index;
                        return result;
                    }
                    case '%': {
                        state = State.minus_percent; break;
                    }
                    case '|': {
                        state = State.minus_pipe; break;
                    }
                    default: {
                        result.tag = Tag.minus;
                        result.loc.end = index;
                        return result;;
                    }
                }
                    break;
                case State.minus_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.minus_percent_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.minus_percent;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.minus_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.minus_pipe_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.minus_pipe;
                            result.loc.end = index;
                            return result;
                        }
                    }
                    break;
                case State.angle_bracket_left:
                    switch (c) {
                        case '<': {
                            state = State.angle_bracket_angle_bracket_left; break;
                        }
                        case '=': {
                            result.tag = Tag.angle_bracket_left_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_left;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_left:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_left_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        case '|': {
                            state = State.angle_bracket_angle_bracket_left_pipe;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_left;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_left_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_left_pipe_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_left_pipe;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.angle_bracket_right:
                    switch (c) {
                        case '>': {
                            state = State.angle_bracket_angle_bracket_right; break;
                        }
                        case '=': {
                            result.tag = Tag.angle_bracket_right_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_right;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_right:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_right_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_right;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.period:
                    switch (c) {
                        case '.': {
                            state = State.period_2; break;
                        }
                        case '*': {
                            state = State.period_asterisk; break;
                        }
                        default: {
                            result.tag = Tag.period;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.period_2:
                    switch (c) {
                        case '.': {
                            result.tag = Tag.ellipsis3;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.ellipsis2;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.period_asterisk:
                    switch (c) {
                        case '*': {
                            result.tag = Tag.invalid_periodasterisks;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.period_asterisk;
                            result.loc.end = index;
                            return result;;
                        }
                    }
                    break;
                case State.slash:
                    switch (c) {
                        case '/': {
                            state = State.line_comment_start;
                        }
                        case '=': {
                            result.tag = Tag.slash_equal;
                            index += 1;
                            result.loc.end = index;
                            return result;;
                        }
                        default: {
                            result.tag = Tag.slash;
                            result.loc.end = index;
                            return result;;
                        }
                    } break;
                case State.line_comment_start:
                    switch (c) {
                        case 0: {
                            if (index != raw_source.length) {
                                result.tag = Tag.invalid;
                                index += 1;
                            }
                            result.loc.end = index;
                            return result;;
                        }
                        case '/': {
                            state = State.doc_comment_start; break;
                        }
                        case '!': {
                            result.tag = Tag.container_doc_comment;
                            state = State.doc_comment; break;
                        }
                        case '\n': {
                            state = State.start;
                            result.loc.start = index + 1; break;
                        }
                        case '\t':
                            state = State.line_comment; break;
                        default: {
                            state = State.line_comment;
                            //TODO: PORT
                            //checkLiteralCharacter();
                            break;
                        }
                    } break;
                case State.doc_comment_start:
                    switch (c) {
                        case '/': {
                            state = State.line_comment; break;
                        }
                        case 0:
                        case '\n':
                            {
                                result.tag = Tag.doc_comment;
                                result.loc.end = index;
                                return result;;
                            }
                        case '\t': {
                            state = State.doc_comment;
                            result.tag = Tag.doc_comment; break;
                        }
                        default: {
                            state = State.doc_comment;
                            result.tag = Tag.doc_comment;
                            //TODO: PORT
                            //checkLiteralCharacter();
                            break;
                        }
                    } break;
                case State.line_comment:
                    switch (c) {
                        case 0: {
                            if (index != raw_source.length) {
                                result.tag = Tag.invalid;
                                index += 1;
                            }
                            result.loc.end = index;
                            return result;;
                        }
                        case '\n': {
                            state = State.start;
                            result.loc.start = index + 1;
                            break;
                        }
                        case '\t': break;
                        //TODO: PORT
                        //default: checkLiteralCharacter(),
                    } break;
                case State.doc_comment:
                    switch (c) {
                        case 0:
                        case '\n': result.loc.end = index;
                            return result;;
                        case '\t': break;
                        //TODOL PORT
                        // default: checkLiteralCharacter(),
                    } break;
                case State.int:
                    switch (c) {
                        case '.':
                            state = State.int_period;
                            break;
                        case '_':
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':

                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9':
                            break;
                        case 'e':
                        case 'E':
                        case 'p':
                        case 'P':
                            state = State.int_exponent;
                            break;
                        default: result.loc.end = index;
                            return result;;
                    } break;
                case State.int_exponent:
                    switch (c) {
                        case '-':
                        case '+':
                            {
                                state = State.float; break;
                            }
                        default: {
                            index -= 1;
                            state = State.int; break;
                        }
                    } break;
                case State.int_period: switch (c) {
                    case '_':
                    case 'a':
                    case 'b':
                    case 'c':
                    case 'd':
                    case 'f':
                    case 'g':
                    case 'h':
                    case 'i':
                    case 'j':
                    case 'k':
                    case 'l':
                    case 'm':
                    case 'n':
                    case 'o':
                    case 'q':
                    case 'r':
                    case 's':
                    case 't':
                    case 'u':
                    case 'v':
                    case 'w':
                    case 'x':
                    case 'y':
                    case 'z':
                    case 'A':
                    case 'B':
                    case 'C':
                    case 'D':
                    case 'F':
                    case 'G':
                    case 'H':
                    case 'I':
                    case 'J':
                    case 'K':
                    case 'L':
                    case 'M':
                    case 'N':
                    case 'O':
                    case 'Q':
                    case 'R':
                    case 'S':
                    case 'T':
                    case 'U':
                    case 'V':
                    case 'W':
                    case 'X':
                    case 'Y':
                    case 'Z':
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9': {
                        state = State.float; break;
                    }
                    case 'e':
                    case 'E':
                    case 'p':
                    case 'P': state = State.float_exponent; break;
                    default: {
                        index -= 1;
                        result.loc.end = index;
                        return result;;
                    }
                } break;
                case State.float:
                    switch (c) {
                        case '_':
                        case 'a':
                        case 'b':
                        case 'c':
                        case 'd':
                        case 'f':
                        case 'g':
                        case 'h':
                        case 'i':
                        case 'j':
                        case 'k':
                        case 'l':
                        case 'm':
                        case 'n':
                        case 'o':
                        case 'q':
                        case 'r':
                        case 's':
                        case 't':
                        case 'u':
                        case 'v':
                        case 'w':
                        case 'x':
                        case 'y':
                        case 'z':
                        case 'A':
                        case 'B':
                        case 'C':
                        case 'D':
                        case 'F':
                        case 'G':
                        case 'H':
                        case 'I':
                        case 'J':
                        case 'K':
                        case 'L':
                        case 'M':
                        case 'N':
                        case 'O':
                        case 'Q':
                        case 'R':
                        case 'S':
                        case 'T':
                        case 'U':
                        case 'V':
                        case 'W':
                        case 'X':
                        case 'Y':
                        case 'Z':
                        case '0':
                        case '1':
                        case '2':
                        case '3':
                        case '4':
                        case '5':
                        case '6':
                        case '7':
                        case '8':
                        case '9': state = State.float_exponent; break;
                        default: result.loc.end = index;
                            return result;;
                    } break;
                case State.float_exponent:
                    switch (c) {
                        case '-':
                        case '+':
                            state = State.float; break;
                        default: {
                            index -= 1;
                            state = State.float; break;
                        }
                    }
                    break;
            }

        }

        // if (result.tag == Tag.eof) {
        //     if (pending_invalid_token) | token | {
        //         pending_invalid_token = null;
        //         return token;
        //     }
        //     result.loc.start = sindex;
        // }

        result.loc.end = index;
        return result;

    }

    toks = []

    for (let i = 0; i < raw_source.length * 2; i++) {
        const tok = next();

        if (toks.length == 32) {
            debugger;
        }
        toks.push(tok);

        if (tok.tag == Tag.eof) {
            break;
        }
    }

    return toks;
}

// Just for testing not to commit in pr
var isNode = new Function("try {return this===global;}catch(e){return false;}");
if (isNode()) {


    // const toksa = tokenize_zig_source("10 * 10");
    // dump_tokens(toksa);

    const fs = require('fs');
    fs.readFile('../c.zig', 'utf8', (err, data) => {
        if (err) {
            console.error(err);
            return;
        }

        const toks = tokenize_zig_source(data);
        dump_tokens(toks);
        console.log(toks.length);
        //console.log(toks);
    });
}