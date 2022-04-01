from pypy.interpreter.astcompiler import ast, consts
from pypy.interpreter.pyparser import parsestring, error as parseerror
from pypy.interpreter import error
from pypy.interpreter import unicodehelper
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rutf8 import codepoints_in_utf8

from rpython.rlib.objectmodel import specialize

@specialize.arg(0)
def build(cls, *args):
    token = args[-1]
    newargs = args[:-1] + (token.lineno, token.column,
        token.end_lineno, token.end_column)
    return cls(*newargs)

@specialize.arg(0)
def build_tokens(cls, *args):
    tokens = args[-1]
    newargs = args[:-1] + (tokens[0].lineno, tokens[0].column,
        tokens[-1].end_lineno, tokens[-1].end_column)
    return cls(*newargs)

def add_constant_string(astbuilder, joined_pieces, w_string, token,
                        kind=None):
    space = astbuilder.space
    is_unicode = space.isinstance_w(w_string, space.w_unicode)
    # Implement implicit string concatenation.
    start_lineno = token.lineno
    start_column = token.column
    end_lineno = token.end_lineno
    end_column = token.end_column
    if joined_pieces:
        prev = joined_pieces[-1]
        if isinstance(prev, ast.Constant):
            if is_unicode is space.isinstance_w(prev.value, space.w_unicode):
                w_string = space.add(prev.value, w_string)
                start_lineno = joined_pieces[-1].lineno
                start_column = joined_pieces[-1].col_offset
                del joined_pieces[-1]
    joined_pieces.append(ast.Constant(w_string, space.newtext_or_none(kind),
        start_lineno, start_column, end_lineno, end_column))

def f_string_compile(astbuilder, source, token, fstr, start_offset):
    # Note: a f-string is kept as a single literal up to here.
    # At this point only, we recursively call the AST compiler
    # on all the '{expr}' parts.  The 'expr' part is not parsed
    # or even tokenized together with the rest of the source code!
    from pypy.interpreter.pyparser import pyparse

    # complain if 'source' is only whitespace or an empty string
    for c in source:
        if c not in ' \t\n\r\v\f':
            break
    else:
        astbuilder.raise_syntax_error_known_location("f-string: empty expression not allowed", token)

    assert isinstance(source, str)    # utf-8 encoded

    paren_source = '(%s)' % source  # to deal with whitespace at the start of source

    lineno = 0
    column_offset = 0
    # overview:
    # here's the input, after the | in a simple case, no newlines:
    # |a + f" ??? {x}"
    # offset of the f" that starts the f-string is fstr.stnode.get_column()
    # offset of the start of the content of the f-string is +
    # fstr.content_offset
    # offset of the content of the {curly parens} we are parsing now is
    # start_offset
    if fstr.token:
        token = fstr.token
        lineno = token.lineno - 1 # one-based
        value = token.value
        if value is not None:
            offset = start_offset + fstr.content_offset
            assert offset >= 0
            after_last_nl = max(0, value.rfind('\n', 0, offset) + 1)
            column_offset = offset - after_last_nl + token.column
            lineno += value.count('\n', 0, after_last_nl)

    info = pyparse.CompileInfo("<fstring>", "eval",
                               consts.PyCF_SOURCE_IS_UTF8 |
                               consts.PyCF_IGNORE_COOKIE,
                               optimize=astbuilder.compile_info.optimize)
    try:
        ast = astbuilder.recursive_parse_to_ast(paren_source, info)
    except parseerror.SyntaxError as e:
        # same logic as fixup_fstring_positions
        if e.lineno == 1:
            e.offset += column_offset - 1
        e.lineno += lineno
        e.text = None # better to get it from the source
        e.msg = "f-string: " + e.msg
        raise
    # column_offset - 1 to exclude prefixed ( in paren_source
    fixup_fstring_positions(ast, lineno, column_offset - 1)
    return ast

def fixup_fstring_positions(ast, line_offset, column_offset):
    visitor = FixPosVisitor(line_offset, column_offset)
    ast.walkabout(visitor)

class FixPosVisitor(ast.GenericASTVisitor):
    def __init__(self, line_offset, column_offset):
        self.line_offset = line_offset
        self.column_offset = column_offset

    def visited(self, node):
        if isinstance(node, ast.stmt) or isinstance(node, ast.expr):
            if node.lineno == 1:
                node.col_offset += self.column_offset
                node.end_col_offset += self.column_offset
            node.lineno += self.line_offset
            node.end_lineno += self.line_offset


def unexpected_end_of_string(astbuilder, tok):
    astbuilder.raise_syntax_error_known_location("f-string: expecting '}'", tok)


def fstring_find_expr(astbuilder, fstr, token, rec):
    # Parse the f-string at fstr.current_index.  We know it starts an
    # expression (so it must be at '{'). Returns the FormattedValue node,
    # which includes the expression, conversion character, and
    # format_spec expression.
    conversion = -1      # the conversion char.  -1 if not specified.
    format_spec = None
    expr_text = None     # Stores the text representation of the expression part
                         # in order to be used for f-string debugging (f'{x = }')

    # 0 if we're not in a string, else the quote char we're trying to
    # match (single or double quote).
    quote_char = 0

    # If we're inside a string, 1=normal, 3=triple-quoted.
    string_type = 0

    # Keep track of nesting level for braces/parens/brackets in
    # expressions.
    nested_depth = 0
    parenstack = [''] * 200

    # Can only nest one level deep.
    if rec >= 2:
        astbuilder.raise_syntax_error_known_location("f-string: expressions nested too deeply", token)

    # The first char must be a left brace, or we wouldn't have gotten
    # here. Skip over it.
    s = fstr.unparsed
    i = fstr.current_index
    assert s[i] == '{'
    i += 1

    expr_start = i
    while i < len(s):

        # Loop invariants.
        assert nested_depth >= 0
        if quote_char:
            assert string_type == 1 or string_type == 3
        else:
            assert string_type == 0

        ch = s[i]
        # Nowhere inside an expression is a backslash allowed.
        if ch == '\\':
            # Error: can't include a backslash character, inside
            # parens or strings or not.
            astbuilder.raise_syntax_error_known_location("f-string expression part "
                             "cannot include a backslash", token)

        if quote_char:
            # We're inside a string. See if we're at the end.
            # <a long comment goes here about how we're duplicating
            # some existing logic>
            if ord(ch) == quote_char:
                # Does this match the string_type (single or triple
                # quoted)?
                if string_type == 3:
                    if i + 2 < len(s) and s[i + 1] == s[i + 2] == ch:
                        # We're at the end of a triple quoted string.
                        i += 3
                        string_type = 0
                        quote_char = 0
                        continue
                else:
                    # We're at the end of a normal string.
                    i += 1
                    string_type = 0
                    quote_char = 0
                    continue
        elif ch == "'" or ch == '"':
            # Is this a triple quoted string?
            if i + 2 < len(s) and s[i + 1] == s[i + 2] == ch:
                string_type = 3
                i += 2
            else:
                # Start of a normal string.
                string_type = 1
            # Start looking for the end of the string.
            quote_char = ord(ch)
        elif ch in "[{(":
            if nested_depth > len(parenstack):
                astbuilder.raise_syntax_error_known_location('f-string: too many nested parenthesis',
                                 token)
            parenstack[nested_depth] = ch
            nested_depth += 1
        elif ch == '#':
            # Error: can't include a comment character, inside parens
            # or not.
            astbuilder.raise_syntax_error_known_location("f-string expression part cannot include '#'",
                             token)
        elif nested_depth == 0 and ch in ":}!=<>":
            # First, test for the special case of comparison operators
            # that also contains equal sign ("!="/">="/"=="/"<=").
            if i + 1 < len(s):
                nextch = s[i + 1]
                if ch in '!=<>' and nextch == '=':
                    # This is an operator, just skip it.
                    i += 2
                    continue
                # don't get out of the loop for just < or > if they are single
                # chars (ie not part of a two-char token).
            if ch in "<>":
                i += 1
                continue
            # Normal way out of this loop.
            break
        elif ch in ']})':
            if nested_depth == 0:
                astbuilder.raise_syntax_error_known_location("f-string: unmatched '%s'" % ch, token)
            nested_depth -=1
            opening = parenstack[nested_depth]
            if not ((opening == '(' and ch ==')') or
                    (opening == '[' and ch ==']') or
                    (opening == '{' and ch =='}')):
                astbuilder.raise_syntax_error_known_location("f-string: closing parenthesis '%s' "
                                 "does not match opening parenthesis '%s'"
                                 % (ch, opening), token)
        #else:
        #   This isn't a conversion character, just continue.
        i += 1

    # If we leave this loop in a string or with mismatched parens, we
    # don't care. We'll get a syntax error when compiling the
    # expression. But, we can produce a better error message, so
    # let's just do that.
    if quote_char:
        astbuilder.raise_syntax_error_known_location("f-string: unterminated string", token)

    if nested_depth:
        opening = parenstack[nested_depth - 1]
        astbuilder.raise_syntax_error_known_location("f-string: unmatched '%s'" % opening,
                         token)

    if i >= len(s):
        unexpected_end_of_string(astbuilder, token)

    # Compile the expression as soon as possible, so we show errors
    # related to the expression before errors related to the
    # conversion or format_spec.
    expr = f_string_compile(astbuilder, s[expr_start:i], token, fstr, expr_start)
    assert isinstance(expr, ast.Expression)

    # Check for the equal sign (debugging expr)
    if s[i] == '=':
        astbuilder.check_version(
            (3, 8),
            "f-string: self documenting expressions are",
            token
        )
        i += 1
        if i >= len(s):
            unexpected_end_of_string(astbuilder, token)

        # The whitespace after the equal sign (f'{x=    }') can be
        # safely ignored (since it will be preserved in expr_text).
        while s[i].isspace():
            i += 1
            if i >= len(s):
                unexpected_end_of_string(astbuilder, token)

        expr_text = s[expr_start:i]

    # Check for a conversion char, if present.
    if s[i] == '!':
        i += 1
        if i >= len(s):
            unexpected_end_of_string(astbuilder, token)

        conversion = ord(s[i])
        i += 1
        if conversion not in (ord('s'), ord('r'), ord('a')):
            astbuilder.raise_syntax_error_known_location("f-string: invalid conversion character: "
                             "expected 's', 'r', or 'a'", token)

    # Check for the format spec, if present.
    if i >= len(s):
        unexpected_end_of_string(astbuilder, token)
    if s[i] == ':':
        i += 1
        if i >= len(s):
            unexpected_end_of_string(astbuilder, token)
        fstr.current_index = i
        subpieces = []
        parse_f_string(astbuilder, subpieces, fstr, token, rec + 1)
        format_spec = f_string_to_ast_node(astbuilder, subpieces, [token])
        i = fstr.current_index

    if i >= len(s) or s[i] != '}':
        unexpected_end_of_string(astbuilder, token)

    w_expr_text = None
    if expr_text is not None:
        # If there are no format spec and conversion, debugging exprs will
        # default to using !r for their conversion.
        if format_spec is None and conversion == -1:
            conversion = ord('r')

        w_expr_text = astbuilder.space.newtext(expr_text)

    # We're at a right brace. Consume it.
    i += 1
    fstr.current_index = i

    # And now create the FormattedValue node that represents this
    # entire expression with the conversion and format spec.
    return build(ast.FormattedValue, expr.body, conversion, format_spec,
            token), w_expr_text


def fstring_find_literal(astbuilder, fstr, token, rec):
    space = astbuilder.space
    raw = fstr.raw_mode

    # Return the next literal part.  Updates the current index inside 'fstr'.
    # Differs from CPython: this version handles double-braces on its own.
    s = fstr.unparsed
    literal_start = fstr.current_index
    assert literal_start >= 0

    # Get any literal string. It ends when we hit an un-doubled left
    # brace (which isn't part of a unicode name escape such as
    # "\N{EULER CONSTANT}"), or the end of the string.
    i = literal_start
    builder = StringBuilder()
    while i < len(s):
        ch = s[i]
        i += 1
        if not raw and ch == '\\' and i < len(s):
            ch = s[i]
            i += 1
            if ch == 'N':
                if i < len(s) and s[i] == '{':
                    while i < len(s) and s[i] != '}':
                        i += 1
                    if i < len(s):
                        i += 1
                    continue
                elif i < len(s):
                    i += 1
                break
            if ch == '{':
                msg = "invalid escape sequence '%s'"
                astbuilder.deprecation_warn(msg % ch, token)
        if ch == '{' or ch == '}':
            # Check for doubled braces, but only at the top level. If
            # we checked at every level, then f'{0:{3}}' would fail
            # with the two closing braces.
            if rec == 0 and i < len(s) and s[i] == ch:
                assert 0 <= i <= len(s)
                builder.append(s[literal_start:i])
                i += 1   # skip over the second brace
                literal_start = i
            elif rec == 0 and ch == '}':
                i -= 1
                assert i >= 0
                fstr.current_index = i
                # Where a single '{' is the start of a new expression, a
                # single '}' is not allowed.
                astbuilder.raise_syntax_error_known_location("f-string: single '}' is not allowed",
                                 token)
            else:
                # We're either at a '{', which means we're starting another
                # expression; or a '}', which means we're at the end of this
                # f-string (for a nested format_spec).
                i -= 1
                break
    assert 0 <= i <= len(s)
    # this is in theory true as well, for valid strings:
    # assert i == len(s) or s[i] == '{' or s[i] == '}'
    # but for mal-formed escapes it can be false. in that case the
    # decode_unicode_escape call below produces an error
    builder.append(s[literal_start:i])

    fstr.current_index = i
    literal = builder.build()
    lgt = codepoints_in_utf8(literal)
    if not raw and '\\' in literal:
        literal = parsestring.decode_unicode_utf8(space, literal, 0,
                                                  len(literal))
        literal, lgt, pos = parsestring.decode_unicode_escape(space, literal, astbuilder, token)
    return space.newtext(literal, lgt)


def fstring_find_literal_and_expr(astbuilder, fstr, token, rec):
    # Return a tuple with the next literal part as a W_Unicode, and optionally the
    # following expression node.  Updates the current index inside 'fstr'.
    w_u = fstring_find_literal(astbuilder, fstr, token, rec)

    s = fstr.unparsed
    i = fstr.current_index
    if i >= len(s) or s[i] == '}':
        # We're at the end of the string or the end of a nested
        # f-string: no expression.
        expr, w_expr_text = None, None
    else:
        # We must now be the start of an expression, on a '{'.
        assert s[i] == '{'
        expr, w_expr_text = fstring_find_expr(astbuilder, fstr, token, rec)
    return w_u, expr, w_expr_text


def parse_f_string(astbuilder, joined_pieces, fstr, token, rec=0):
    # In our case, parse_f_string() and fstring_find_literal_and_expr()
    # could be merged into a single function with a clearer logic.  It's
    # done this way to follow CPython's source code more closely.
    space = astbuilder.space
    while True:
        w_u, expr, w_expr_text  = fstring_find_literal_and_expr(astbuilder, fstr,
                                                                token, rec)

        # add the literal part
        add_constant_string(astbuilder, joined_pieces, w_u, token)
        if expr is None:
            break         # We're done with this f-string.
        if w_expr_text is not None:
            add_constant_string(astbuilder, joined_pieces, w_expr_text, token)
        joined_pieces.append(expr)

    # If recurse_lvl is zero, then we must be at the end of the
    # string. Otherwise, we must be at a right brace.
    if rec == 0 and fstr.current_index < len(fstr.unparsed) - 1:
        astbuilder.raise_syntax_error_known_location("f-string: unexpected end of string", token)

    if rec != 0 and (fstr.current_index >= len(fstr.unparsed) or
                     fstr.unparsed[fstr.current_index] != '}'):
        astbuilder.raise_syntax_error_known_location("f-string: expecting '}'", token)


def f_string_to_ast_node(astbuilder, joined_pieces, tokens):
    # Remove empty Strs, but always return an ast.JoinedStr object.
    # In this way it cannot be grabbed later for being used as a
    # docstring.  In codegen.py we still special-case length-1 lists
    # and avoid calling "BUILD_STRING 1" in this case.
    space = astbuilder.space
    values = [node for node in joined_pieces
                   if not isinstance(node, ast.Constant)
                      or space.is_true(node.value)]
    return build_tokens(ast.JoinedStr, values, tokens)


def string_parse_literal(astbuilder, tokens):
    space = astbuilder.space
    encoding = astbuilder.compile_info.encoding
    joined_pieces = []
    fmode = False
    for i in range(len(tokens)):
        token = tokens[i]
        try:
            child_str = token.value
            w_next = parsestring.parsestr(
                    space, encoding, child_str, token,
                    astbuilder)
            if not isinstance(w_next, parsestring.W_FString):
                # u'' prefix can not be combined with
                # any other specifier, so it's safe to
                # check the initial letter for determining.
                kind = "u" if child_str[0] == "u" else None
                add_constant_string(astbuilder, joined_pieces,
                                    w_next, token, kind)
            else:
                parse_f_string(astbuilder, joined_pieces, w_next, token)
                fmode = True

        except error.OperationError as e:
            if e.match(space, space.w_UnicodeError):
                kind = '(unicode error) '
            elif e.match(space, space.w_ValueError):
                kind = '(value error) '
            elif e.match(space, space.w_SyntaxError):
                kind = ''
            else:
                raise
            # Unicode/ValueError/SyntaxError (without position information) in
            # literal: turn into SyntaxError with position information
            e.normalize_exception(space)
            errmsg = space.text_w(space.str(e.get_w_value(space)))
            raise astbuilder.raise_syntax_error_known_location('%s%s' % (kind, errmsg), token)

    if not fmode and len(joined_pieces) == 1:   # <= the common path
        return joined_pieces[0]   # ast.Constant or FormattedValue

    # with more than one piece, it is a combination of ast.Constant[str]
    # and FormattedValue pieces --- if there is a bytes value, then we got
    # an invalid mixture of bytes and unicode literals
    for node in joined_pieces:
        if isinstance(node, ast.Constant) and space.isinstance_w(node.value, space.w_bytes):
            astbuilder.raise_syntax_error_known_location(
                "cannot mix bytes and nonbytes literals",
                node)
    assert fmode
    result = f_string_to_ast_node(astbuilder, joined_pieces, tokens)
    astbuilder.check_version(
        (3, 6),
        "Format strings are",
        result
    )
    return result
