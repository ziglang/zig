
class SyntaxError(Exception):
    """Base class for exceptions raised by the parser."""

    def __init__(self, msg, lineno=0, offset=0, text=None, filename=None,
                 lastlineno=0):
        self.msg = msg
        self.lineno = lineno
        # NB: offset is a 1-based index into the bytes source
        self.offset = offset
        self.text = text
        self.filename = filename
        self.lastlineno = lastlineno

    def find_sourceline_and_wrap_info(self, space, source=None):
        """ search for the line of input that caused the error and then return
        a wrapped tuple that can be used to construct a wrapped SyntaxError.
        Optionally pass source, to get better error messages for the case where
        this instance was constructed without a source line (.text
        attribute)"""
        text = self.text
        if text is None and source is not None and self.lineno:
            lines = source.splitlines(True)
            text = lines[self.lineno - 1]
        w_text = w_filename = space.w_None
        offset = self.offset
        w_lineno = space.newint(self.lineno)
        if self.filename is not None:
            w_filename = space.newfilename(self.filename)
        if text is None and self.filename is not None:
            w_text = space.appexec([w_filename, w_lineno],
                """(filename, lineno):
                    try:
                        with open(filename) as f:
                            for _ in range(lineno - 1):
                                f.readline()
                            return f.readline()
                    except:  # we can't allow any exceptions here!
                        return None""")
        elif text is not None:
            from pypy.interpreter.unicodehelper import _str_decode_utf8_slowpath
            # text may not be UTF-8 in case of decoding errors.
            # adjust the encoded text offset to a decoded offset
            # XXX do the right thing about continuation lines, which
            # XXX are their own fun, sometimes giving offset >
            # XXX len(text) for example (right now, avoid crashing)

            # this also converts the byte-based self.offset to a
            # codepoint-based index into the decoded unicode-version of
            # self.text

            def replace_error_handler(errors, encoding, msg, s, startpos, endpos):
                return b'\xef\xbf\xbd', endpos, 'b', s

            replacedtext, unilength, _ = _str_decode_utf8_slowpath(
                    text, 'replace', False, replace_error_handler, True)
            if offset > len(text):
                offset = unilength
            elif offset >= 1:
                offset = offset - 1 # 1-based to 0-based
                assert offset >= 0
                # slightly inefficient, call the decoder for text[:offset] too
                _, offset, _ = _str_decode_utf8_slowpath(
                        text[:offset], 'replace', False, replace_error_handler,
                        True)
                offset += 1 # convert to 1-based
            else:
                offset = 0
            w_text = space.newutf8(replacedtext, unilength)
        return space.newtuple([
            space.newtext(self.msg),
            space.newtuple([
                w_filename, w_lineno, space.newint(offset),
                w_text, space.newint(self.lastlineno)])])

    def __str__(self):
        return "%s at pos (%d, %d) in %r" % (
            self.__class__.__name__, self.lineno, self.offset, self.text)

class IndentationError(SyntaxError):
    pass

class TabError(IndentationError):
    def __init__(self, lineno=0, offset=0, text=None, filename=None,
                 lastlineno=0):
        msg = "inconsistent use of tabs and spaces in indentation"
        IndentationError.__init__(
            self, msg, lineno, offset, text, filename, lastlineno)

class ASTError(Exception):
    def __init__(self, msg, ast_node):
        self.msg = msg
        self.ast_node = ast_node


class TokenError(SyntaxError):

    def __init__(self, msg, line, lineno, column, tokens, lastlineno=0):
        SyntaxError.__init__(self, msg, lineno, column, line,
                             lastlineno=lastlineno)
        self.tokens = tokens

class TokenIndentationError(IndentationError):

    def __init__(self, msg, line, lineno, column, tokens):
        SyntaxError.__init__(self, msg, lineno, column, line)
        self.tokens = tokens
