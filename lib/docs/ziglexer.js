'use strict';

const Tag = {
    whitespace: "whitespace",
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
    line_comment: "line_comment",
    invalid_periodasterisks: "invalid_periodasterisks",
    bang: "bang",
    pipe: "pipe",
    pipe_pipe: "pipe_pipe",
    pipe_equal: "pipe_equal",
    equal: "equal",
    equal_equal: "equal_equal",
    equal_angle_bracket_right: "equal_angle_bracket_right",
    bang_equal: "bang_equal",
    l_paren: "l_paren",
    r_paren: "r_paren",
    semicolon: "semicolon",
    percent: "percent",
    percent_equal: "percent_equal",
    l_brace: "l_brace",
    r_brace: "r_brace",
    l_bracket: "l_bracket",
    r_bracket: "r_bracket",
    period: "period",
    period_asterisk: "period_asterisk",
    ellipsis2: "ellipsis2",
    ellipsis3: "ellipsis3",
    caret: "caret",
    caret_equal: "caret_equal",
    plus: "plus",
    plus_plus: "plus_plus",
    plus_equal: "plus_equal",
    plus_percent: "plus_percent",
    plus_percent_equal: "plus_percent_equal",
    plus_pipe: "plus_pipe",
    plus_pipe_equal: "plus_pipe_equal",
    minus: "minus",
    minus_equal: "minus_equal",
    minus_percent: "minus_percent",
    minus_percent_equal: "minus_percent_equal",
    minus_pipe: "minus_pipe",
    minus_pipe_equal: "minus_pipe_equal",
    asterisk: "asterisk",
    asterisk_equal: "asterisk_equal",
    asterisk_asterisk: "asterisk_asterisk",
    asterisk_percent: "asterisk_percent",
    asterisk_percent_equal: "asterisk_percent_equal",
    asterisk_pipe: "asterisk_pipe",
    asterisk_pipe_equal: "asterisk_pipe_equal",
    arrow: "arrow",
    colon: "colon",
    slash: "slash",
    slash_equal: "slash_equal",
    comma: "comma",
    ampersand: "ampersand",
    ampersand_equal: "ampersand_equal",
    question_mark: "question_mark",
    angle_bracket_left: "angle_bracket_left",
    angle_bracket_left_equal: "angle_bracket_left_equal",
    angle_bracket_angle_bracket_left: "angle_bracket_angle_bracket_left",
    angle_bracket_angle_bracket_left_equal: "angle_bracket_angle_bracket_left_equal",
    angle_bracket_angle_bracket_left_pipe: "angle_bracket_angle_bracket_left_pipe",
    angle_bracket_angle_bracket_left_pipe_equal: "angle_bracket_angle_bracket_left_pipe_equal",
    angle_bracket_right: "angle_bracket_right",
    angle_bracket_right_equal: "angle_bracket_right_equal",
    angle_bracket_angle_bracket_right: "angle_bracket_angle_bracket_right",
    angle_bracket_angle_bracket_right_equal: "angle_bracket_angle_bracket_right_equal",
    tilde: "tilde",
    keyword_addrspace: "keyword_addrspace",
    keyword_align: "keyword_align",
    keyword_allowzero: "keyword_allowzero",
    keyword_and: "keyword_and",
    keyword_anyframe: "keyword_anyframe",
    keyword_anytype: "keyword_anytype",
    keyword_asm: "keyword_asm",
    keyword_async: "keyword_async",
    keyword_await: "keyword_await",
    keyword_break: "keyword_break",
    keyword_callconv: "keyword_callconv",
    keyword_catch: "keyword_catch",
    keyword_comptime: "keyword_comptime",
    keyword_const: "keyword_const",
    keyword_continue: "keyword_continue",
    keyword_defer: "keyword_defer",
    keyword_else: "keyword_else",
    keyword_enum: "keyword_enum",
    keyword_errdefer: "keyword_errdefer",
    keyword_error: "keyword_error",
    keyword_export: "keyword_export",
    keyword_extern: "keyword_extern",
    keyword_fn: "keyword_fn",
    keyword_for: "keyword_for",
    keyword_if: "keyword_if",
    keyword_inline: "keyword_inline",
    keyword_noalias: "keyword_noalias",
    keyword_noinline: "keyword_noinline",
    keyword_nosuspend: "keyword_nosuspend",
    keyword_opaque: "keyword_opaque",
    keyword_or: "keyword_or",
    keyword_orelse: "keyword_orelse",
    keyword_packed: "keyword_packed",
    keyword_pub: "keyword_pub",
    keyword_resume: "keyword_resume",
    keyword_return: "keyword_return",
    keyword_linksection: "keyword_linksection",
    keyword_struct: "keyword_struct",
    keyword_suspend: "keyword_suspend",
    keyword_switch: "keyword_switch",
    keyword_test: "keyword_test",
    keyword_threadlocal: "keyword_threadlocal",
    keyword_try: "keyword_try",
    keyword_union: "keyword_union",
    keyword_unreachable: "keyword_unreachable",
    keyword_usingnamespace: "keyword_usingnamespace",
    keyword_var: "keyword_var",
    keyword_volatile: "keyword_volatile",
    keyword_while: "keyword_while"
}

const Tok = {
    const: { src: "const", tag: Tag.keyword_const },
    var: { src: "var", tag: Tag.keyword_var },
    colon: { src: ":", tag: Tag.colon },
    eql: { src: "=", tag: Tag.equals },
    space: { src: " ", tag: Tag.whitespace },
    tab: { src: "    ", tag: Tag.whitespace },
    enter: { src: "\n", tag: Tag.whitespace },
    semi: { src: ";", tag: Tag.semicolon },
    l_bracket: { src: "[", tag: Tag.l_bracket },
    r_bracket: { src: "]", tag: Tag.r_bracket },
    l_brace: { src: "{", tag: Tag.l_brace },
    r_brace: { src: "}", tag: Tag.r_brace },
    l_paren: { src: "(", tag: Tag.l_paren },
    r_paren: { src: ")", tag: Tag.r_paren },
    period: { src: ".", tag: Tag.period },
    comma: { src: ",", tag: Tag.comma },
    identifier: (name) => { return { src: name, tag: Tag.identifier } },
};


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
    whitespace: 49,
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

function dump_tokens(tokens, raw_source) {

    //TODO: this is not very fast
    function find_tag_key(tag) {
        for (const [key, value] of Object.entries(Tag)) {
            if (value == tag) return key;
        }
    }

    for (let i = 0; i < tokens.length; i++) {
        const tok = tokens[i];
        const z = raw_source.substring(tok.loc.start, tok.loc.end).toLowerCase();
        console.log(`${find_tag_key(tok.tag)} "${tok.tag}" '${z}'`)
    }
}

function* Tokenizer(raw_source) {
    let tokenizer = new InnerTokenizer(raw_source);
    while (true) {
        let t = tokenizer.next(); 
        if (t.tag == Tag.eof) 
            return;
        
        t.src = raw_source.slice(t.loc.start, t.loc.end);
        
        yield t;
    }

}
function InnerTokenizer(raw_source) {
    this.index = 0;
    this.flag = false;

    this.seen_escape_digits = undefined;
    this.remaining_code_units = undefined;

    this.next = () => {
        let state = State.start;

        var result = {
            tag: -1,
            loc: {
                start: this.index,
                end: undefined,
            },
            src: undefined,
        };

        //having a while (true) loop seems like a bad idea the loop should never
        //take more iterations than twice the length of the source code
        const MAX_ITERATIONS = raw_source.length * 2;
        let iterations = 0;

        while (iterations <= MAX_ITERATIONS) {

            if (this.flag) {
                return make_token(Tag.eof, this.index - 2, this.index - 2);
            }
            iterations += 1; // avoid death loops

            var c = raw_source[this.index];

            if (c === undefined) {
                c = ' '; // push the last token
                this.flag = true;
            }

            switch (state) {
                case State.start:
                    switch (c) {
                        case 0: {
                            if (this.index != raw_source.length) {
                                result.tag = Tag.invalid;
                                result.loc.start = this.index;
                                this.index += 1;
                                result.loc.end = this.index;
                                return result;
                            }
                            result.loc.end = this.index;
                            return result;
                        }
                        case ' ':
                        case '\n':
                        case '\t':
                        case '\r': {
                            state = State.whitespace;
                            result.tag = Tag.whitespace;
                            result.loc.start = this.index;
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
                            break;
                        }
                        case '(': {
                            result.tag = Tag.l_paren;
                            this.index += 1;
                            result.loc.end = this.index;

                            return result;
                            
                        }
                        case ')': {
                            result.tag = Tag.r_paren;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case '[': {
                            result.tag = Tag.l_bracket;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case ']': {
                            result.tag = Tag.r_bracket;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case ';': {
                            result.tag = Tag.semicolon;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case ',': {
                            result.tag = Tag.comma;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case '?': {
                            result.tag = Tag.question_mark;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case ':': {
                            result.tag = Tag.colon;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
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
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case '}': {
                            result.tag = Tag.r_brace;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
                        }
                        case '~': {
                            result.tag = Tag.tilde;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                            
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
                            result.loc.end = this.index;
                            this.index += 1;
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
                            result.tag = Tag.builtin;
                            break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.ampersand:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.ampersand_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.ampersand; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.asterisk: switch (c) {
                    case '=': {
                        result.tag = Tag.asterisk_equal;
                        this.index += 1; result.loc.end = this.index;
                        return result;
                    }
                    case '*': {
                        result.tag = Tag.asterisk_asterisk;
                        this.index += 1; result.loc.end = this.index;
                        return result;
                    }
                    case '%': {
                        state = State.asterisk_percent; break;
                    }
                    case '|': {
                        state = State.asterisk_pipe; break;
                    }
                    default: {
                        result.tag = Tag.asterisk;
                        result.loc.end = this.index;
                        return result;
                    }
                }
                    break;
                case State.asterisk_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.asterisk_percent_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.asterisk_percent;
                            result.loc.end = this.index;
                            return result; 
                        }
                    }
                    break;
                case State.asterisk_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.asterisk_pipe_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.asterisk_pipe; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.percent_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.percent; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.plus:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        case '+': {
                            result.tag = Tag.plus_plus;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        case '%': {
                            state = State.plus_percent; break;
                        }
                        case '|': {
                            state = State.plus_pipe; break;
                        }
                        default: {
                            result.tag = Tag.plus; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.plus_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_percent_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.plus_percent; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.plus_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.plus_pipe_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.plus_pipe; result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.caret:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.caret_equal;
                            this.index += 1; result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.caret; result.loc.end = this.index;
                            return result;
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
                            // if (Token.getKeyword(buffer[result.loc.start..this.index])) | tag | {
                            const z = raw_source.substring(result.loc.start, this.index);
                            if (z in keywords) {
                                result.tag = keywords[z];
                            }
                            result.loc.end = this.index;
                            return result; 
                        }


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
                    default: result.loc.end = this.index;
                        return result;
                }
                    break;
                case State.backslash:
                    switch (c) {
                        case '\\': {
                            state = State.multiline_string_literal_line;
                            break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.string_literal:
                    switch (c) {
                        case '\\': {
                            state = State.string_literal_backslash; break;
                        }
                        case '"': {
                            this.index += 1;
                            result.loc.end = this.index;

                            return result; 
                        }
                        case 0: {
                            //TODO: PORT
                            // if (this.index == buffer.len) {
                            //     result.tag = .invalid;
                            //     break;
                            // } else {
                            //     checkLiteralCharacter();
                            // }
                            result.loc.end = this.index;
                            return result; 
                        }
                        case '\n': {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result; 
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
                            result.loc.end = this.index;
                            return result; 
                        }
                        default: {
                            state = State.string_literal; break;
                        }
                    }
                    break;
                case State.char_literal: switch (c) {
                    case 0: {
                        result.tag = Tag.invalid;
                        result.loc.end = this.index;
                        return result; 
                    }
                    case '\\': {
                        state = State.char_literal_backslash;
                        break;
                    }
                    //TODO: PORT
                    // '\'', 0x80...0xbf, 0xf8...0xff => {
                    //     result.tag = .invalid;
                    //     break;
                    // },
                    // 0xc0...0xdf => { // 110xxxxx
                    //     this.remaining_code_units = 1;
                    //     state = .char_literal_unicode;
                    // },
                    // 0xe0...0xef => { // 1110xxxx
                    //     this.remaining_code_units = 2;
                    //     state = .char_literal_unicode;
                    // },
                    // 0xf0...0xf7 => { // 11110xxx
                    //     this.remaining_code_units = 3;
                    //     state = .char_literal_unicode;
                    // },

                    // case 0x80:
                    // case 0x81:
                    // case 0x82:
                    // case 0x83:
                    // case 0x84:
                    // case 0x85:
                    // case 0x86:
                    // case 0x87:
                    // case 0x88:
                    // case 0x89:
                    // case 0x8a:
                    // case 0x8b:
                    // case 0x8c:
                    // case 0x8d:
                    // case 0x8e:
                    // case 0x8f:
                    // case 0x90:
                    // case 0x91:
                    // case 0x92:
                    // case 0x93:
                    // case 0x94:
                    // case 0x95:
                    // case 0x96:
                    // case 0x97:
                    // case 0x98:
                    // case 0x99:
                    // case 0x9a:
                    // case 0x9b:
                    // case 0x9c:
                    // case 0x9d:
                    // case 0x9e:
                    // case 0x9f:
                    // case 0xa0:
                    // case 0xa1:
                    // case 0xa2:
                    // case 0xa3:
                    // case 0xa4:
                    // case 0xa5:
                    // case 0xa6:
                    // case 0xa7:
                    // case 0xa8:
                    // case 0xa9:
                    // case 0xaa:
                    // case 0xab:
                    // case 0xac:
                    // case 0xad:
                    // case 0xae:
                    // case 0xaf:
                    // case 0xb0:
                    // case 0xb1:
                    // case 0xb2:
                    // case 0xb3:
                    // case 0xb4:
                    // case 0xb5:
                    // case 0xb6:
                    // case 0xb7:
                    // case 0xb8:
                    // case 0xb9:
                    // case 0xba:
                    // case 0xbb:
                    // case 0xbc:
                    // case 0xbd:
                    // case 0xbe:
                    // case 0xbf:
                    // case 0xf8:
                    // case 0xf9:
                    // case 0xfa:
                    // case 0xfb:
                    // case 0xfc:
                    // case 0xfd:
                    // case 0xfe:
                    // case 0xff:
                    //     result.tag = .invalid;
                    //     break;
                    // case 0xc0:
                    // case 0xc1:
                    // case 0xc2:
                    // case 0xc3:
                    // case 0xc4:
                    // case 0xc5:
                    // case 0xc6:
                    // case 0xc7:
                    // case 0xc8:
                    // case 0xc9:
                    // case 0xca:
                    // case 0xcb:
                    // case 0xcc:
                    // case 0xcd:
                    // case 0xce:
                    // case 0xcf:
                    // case 0xd0:
                    // case 0xd1:
                    // case 0xd2:
                    // case 0xd3:
                    // case 0xd4:
                    // case 0xd5:
                    // case 0xd6:
                    // case 0xd7:
                    // case 0xd8:
                    // case 0xd9:
                    // case 0xda:
                    // case 0xdb:
                    // case 0xdc:
                    // case 0xdd:
                    // case 0xde:
                    // case 0xdf:
                    //     this.remaining_code_units = 1;
                    //     state = .char_literal_unicode;
                    // case 0xe0:
                    // case 0xe1:
                    // case 0xe2:
                    // case 0xe3:
                    // case 0xe4:
                    // case 0xe5:
                    // case 0xe6:
                    // case 0xe7:
                    // case 0xe8:
                    // case 0xe9:
                    // case 0xea:
                    // case 0xeb:
                    // case 0xec:
                    // case 0xed:
                    // case 0xee:
                    // case 0xef:
                    //     this.remaining_code_units = 2;
                    //     state = .char_literal_unicode;
                    // case 0xf0:
                    // case 0xf1:
                    // case 0xf2:
                    // case 0xf3:
                    // case 0xf4:
                    // case 0xf5:
                    // case 0xf6:
                    // case 0xf7:
                    //     this.remaining_code_units = 3;
                    //     state = .char_literal_unicode;

                    case '\n': {
                        result.tag = Tag.invalid;
                        result.loc.end = this.index;
                        return result; 
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
                            result.loc.end = this.index;
                            return result; 
                        }
                        case 'x': {
                            state = State.char_literal_hex_escape;
                            this.seen_escape_digits = 0; break;
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
                            this.seen_escape_digits += 1;
                            if (this.seen_escape_digits == 2) {
                                state = State.char_literal_end;
                            } break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            esult.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.char_literal_unicode_escape_saw_u:
                    switch (c) {
                        case 0: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result;
                        }
                        case '{': {
                            state = State.char_literal_unicode_escape; break;
                        }
                        default: {
                            result.tag = Tag.invalid;
                            state = State.char_literal_unicode_invalid; break;
                        }
                    }
                    break;
                case State.char_literal_unicode_escape:
                    switch (c) {
                        case 0: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result;
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
                            this.index += 1;
                            result.loc.end = this.index;
                            return result; 
                        }
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result; 
                        }
                    }
                    break;
                case State.char_literal_unicode:
                    switch (c) {
                        // 0x80...0xbf => {
                        //         this.remaining_code_units -= 1;
                        //         if (this.remaining_code_units == 0) {
                        //             state = .char_literal_end;
                        //         }
                        //     },
                        default: {
                            result.tag = Tag.invalid;
                            result.loc.end = this.index;
                            return result; 
                        }
                    }
                    break;
                case State.multiline_string_literal_line:
                    switch (c) {
                        case 0:
                            result.loc.end = this.index;
                            return result;
                        case '\n': {

                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
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
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.bang;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.pipe_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        case '|': {
                            result.tag = Tag.pipe_pipe;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.pipe;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.equal: switch (c) {
                    case '=': {
                        result.tag = Tag.equal_equal;
                        this.index += 1;
                        result.loc.end = this.index;
                        return result;
                    }
                    case '>': {
                        result.tag = Tag.equal_angle_bracket_right;
                        this.index += 1;
                        result.loc.end = this.index;
                        return result;
                    }
                    default: {
                        result.tag = Tag.equal;
                        result.loc.end = this.index;
                        return result;
                    }
                }
                    break;
                case State.minus: switch (c) {
                    case '>': {
                        result.tag = Tag.arrow;
                        this.index += 1;
                        result.loc.end = this.index;
                        return result;
                    }
                    case '=': {
                        result.tag = Tag.minus_equal;
                        this.index += 1;
                        result.loc.end = this.index;
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
                        result.loc.end = this.index;
                        return result;
                    }
                }
                    break;
                case State.minus_percent:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.minus_percent_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.minus_percent;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.minus_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.minus_pipe_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.minus_pipe;
                            result.loc.end = this.index;
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
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_left;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_left:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_left_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        case '|': {
                            state = State.angle_bracket_angle_bracket_left_pipe;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_left;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_left_pipe:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_left_pipe_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_left_pipe;
                            result.loc.end = this.index;
                            return result;
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
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_right;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.angle_bracket_angle_bracket_right:
                    switch (c) {
                        case '=': {
                            result.tag = Tag.angle_bracket_angle_bracket_right_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.angle_bracket_angle_bracket_right;
                            result.loc.end = this.index;
                            return result;
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
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.period_2:
                    switch (c) {
                        case '.': {
                            result.tag = Tag.ellipsis3;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.ellipsis2;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.period_asterisk:
                    switch (c) {
                        case '*': {
                            result.tag = Tag.invalid_periodasterisks;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.period_asterisk;
                            result.loc.end = this.index;
                            return result;
                        }
                    }
                    break;
                case State.slash:
                    switch (c) {
                        case '/': {
                            state = State.line_comment_start;
                            break;
                        }
                        case '=': {
                            result.tag = Tag.slash_equal;
                            this.index += 1;
                            result.loc.end = this.index;
                            return result;
                        }
                        default: {
                            result.tag = Tag.slash;
                            result.loc.end = this.index;
                            return result;
                        }
                    } break;
                case State.line_comment_start:
                    switch (c) {
                        case 0: {
                            if (this.index != raw_source.length) {
                                result.tag = Tag.invalid;
                                this.index += 1;
                            }
                            result.loc.end = this.index;
                            return result;
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
                            result.loc.start = this.index + 1; break;
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
                                result.loc.end = this.index;
                                return result;
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
                            if (this.index != raw_source.length) {
                                result.tag = Tag.invalid;
                                this.index += 1;
                            }
                            result.loc.end = this.index;
                            return result;
                        }
                        case '\n': {
                            result.tag = Tag.line_comment;
                            result.loc.end = this.index;
                            return result;
                        }
                        case '\t': break;
                        //TODO: PORT
                        //default: checkLiteralCharacter(),
                    } break;
                case State.doc_comment:
                    switch (c) {
                        case 0://
                        case '\n':
                            result.loc.end = this.index;
                            return result;
                        case '\t': break;
                        //TODOL PORT
                        // default: checkLiteralCharacter(),
                        default:
                            break;
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
                        default: result.loc.end = this.index;
                            return result;
                    } break;
                case State.int_exponent:
                    switch (c) {
                        case '-':
                        case '+':
                            {
                                ``
                                state = State.float; break;
                            }
                        default: {
                            this.index -= 1;
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
                    case 'P':
                        state = State.float_exponent; break;
                    default: {
                        this.index -= 1;
                        result.loc.end = this.index;
                        return result;
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
                        case '9':
                            break;

                        case 'e':
                        case 'E':
                        case 'p':
                        case 'P':
                            state = State.float_exponent; break;
                        default: result.loc.end = this.index;
                            return result;
                    } break;
                case State.float_exponent:
                    switch (c) {
                        case '-':
                        case '+':
                            state = State.float; break;
                        default: {
                            this.index -= 1;
                            state = State.float; break;
                        }
                    }
                    break;

                case State.whitespace:
                    switch(c) {
                        case ' ':
                        case '\n':
                        case '\t':
                        case '\r': {
                            break;
                        }
                        default: {
                            result.loc.end = this.index;
                            return result;
                        }
                   }
            }
            this.index += 1;
        }

        //TODO: PORT
        // if (result.tag == Tag.eof) {
        //     if (pending_invalid_token) | token | {
        //         pending_invalid_token = null;
        //         return token;
        //     }
        //     result.loc.start = sindex;
        // }

        result.loc.end = this.index;
        return result;

    }
}


const builtin_types = [
    "f16",          "f32",     "f64",        "f80",          "f128",
    "c_longdouble", "c_short", "c_ushort",   "c_int",        "c_uint",
    "c_long",       "c_ulong", "c_longlong", "c_ulonglong",  "c_char",
    "anyopaque",    "void",    "bool",       "isize",        "usize",
    "noreturn",     "type",    "anyerror",   "comptime_int", "comptime_float",
];

function isSimpleType(typeName) {
    return builtin_types.includes(typeName) || isIntType(typeName);
}

function isIntType(typeName) {
    if (typeName[0] != 'u' && typeName[0] != 'i') return false;
    let i = 1;
    if (i == typeName.length) return false;
    for (; i < typeName.length; i += 1) {
        if (typeName[i] < '0' || typeName[i] > '9') return false;
    }
    return true;
}

function isSpecialIndentifier(identifier) {
    return ["null", "true", "false", ,"undefined"].includes(identifier);
}

//const fs = require('fs');
//const src = fs.readFileSync("../std/c.zig", 'utf8');
//console.log(generate_html_for_src(src));


// gist for zig_lexer_test code: https://gist.github.com/Myvar/2684ba4fb86b975274629d6f21eddc7b
// // Just for testing not to commit in pr
// var isNode = new Function("try {return this===global;}catch(e){return false;}");
// if (isNode()) {


//     //const s = "const std = @import(\"std\");";
//     //const toksa = tokenize_zig_source(s);
//     //dump_tokens(toksa, s);
//     //console.log(JSON.stringify(toksa));

//     const fs = require('fs');

//     function testFile(fileName) {
//         //console.log(fileName);
//         var exec = require('child_process').execFileSync;
//         var passed = true;
//         const zig_data = exec('./zig_lexer_test', [fileName]);
//         const data = fs.readFileSync(fileName, 'utf8');

//         const toks = tokenize_zig_source(data);
//         const a_json = toks;

//         // dump_tokens(a_json, data);
//         // return;

//         const b_json = JSON.parse(zig_data.toString());

//         if (a_json.length !== b_json.length) {
//             console.log("FAILED a and be is not the same length");
//             passed = false;
//             //return;
//         }

//         let len = a_json.length;
//         if (len >= b_json.length) len = b_json.length;

//         for (let i = 0; i < len; i++) {
//             const a = a_json[i];
//             const b = b_json[i];

//             // console.log(a.tag + " == " + b.tag);

//             if (a.tag !== b.tag) {

//                 // console.log("Around here:");
//                 // console.log(
//                 //     data.substring(b_json[i - 2].loc.start, b_json[i - 2].loc.end),
//                 //     data.substring(b_json[i - 1].loc.start, b_json[i - 1].loc.end),
//                 //     data.substring(b_json[i].loc.start, b_json[i].loc.end),
//                 //     data.substring(b_json[i + 1].loc.start, b_json[i + 1].loc.end),
//                 //     data.substring(b_json[i + 2].loc.start, b_json[i + 2].loc.end),
//                 // );

//                 console.log("TAG: a != b");
//                 console.log("js", a.tag);
//                 console.log("zig", b.tag);
//                 passed = false;
//                 return;
//             }

//             if (a.tag !== Tag.eof && a.loc.start !== b.loc.start) {
//                 console.log("START: a != b");

//                 console.log("js",  "\"" + data.substring(a_json[i ].loc.start, a_json[i].loc.end) + "\"");
//                 console.log("zig",  "\"" + data.substring(b_json[i ].loc.start, b_json[i].loc.end) + "\"");


//                 passed = false;
//                 return;
//             }

//             // if (a.tag !== Tag.eof && a.loc.end !== b.loc.end) {
//             //     console.log("END: a != b");
//             //     // console.log("Around here:");
//             //     // console.log(
//             //     //    // data.substring(b_json[i - 2].loc.start, b_json[i - 2].loc.end),
//             //     //    // data.substring(b_json[i - 1].loc.start, b_json[i - 1].loc.end),
//             //     //     data.substring(b_json[i ].loc.start, b_json[i].loc.end),
//             //     //    // data.substring(b_json[i + 1].loc.start, b_json[i + 1].loc.end),
//             //     //    // data.substring(b_json[i + 2].loc.start, b_json[i + 2].loc.end),
//             //     // );
//             //     console.log("js",  "\"" + data.substring(a_json[i ].loc.start, a_json[i].loc.end) + "\"");
//             //     console.log("zig",  "\"" + data.substring(b_json[i ].loc.start, b_json[i].loc.end) + "\"");
//             //     passed = false;
//             //     return;
//             // }
//         }
//         return passed;
//     }
//     var path = require('path');
//     function fromDir(startPath, filter) {
//         if (!fs.existsSync(startPath)) {
//             console.log("no dir ", startPath);
//             return;
//         }
//         var files = fs.readdirSync(startPath);
//         for (var i = 0; i < files.length; i++) {
//             var filename = path.join(startPath, files[i]);
//             var stat = fs.lstatSync(filename);
//             if (stat.isDirectory()) {
//                 fromDir(filename, filter); //recurse
//             } else if (filename.endsWith(filter)) {
//                 try {
//                     console.log('-- TESTING: ', filename);
//                     console.log("\t\t", testFile(filename));
//                 }
//                 catch {
//                 }
//             };
//         };
//     };
//       fromDir('../std', '.zig');
//     //console.log(testFile("/home/myvar/code/zig/lib/std/fmt/errol.zig"));
//     //console.log(testFile("test.zig"));
// }