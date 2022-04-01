import re

ASCII_IS_DEFAULT_ENCODING = False

cookie_re = re.compile(r"^[ \t\f]*#.*coding[:=][ \t]*[-\w.]+")
BOM_UTF8 = '\xef\xbb\xbf'

def _prepare_source(fn):
    """Read the source code for re-writing."""
    try:
        stat = fn.stat()
        source = fn.read("rb")
    except EnvironmentError:
        return None, None
    if ASCII_IS_DEFAULT_ENCODING:
        # ASCII is the default encoding in Python 2. Without a coding
        # declaration, Python 2 will complain about any bytes in the file
        # outside the ASCII range. Sadly, this behavior does not extend to
        # compile() or ast.parse(), which prefer to interpret the bytes as
        # latin-1. (At least they properly handle explicit coding cookies.) To
        # preserve this error behavior, we could force ast.parse() to use ASCII
        # as the encoding by inserting a coding cookie. Unfortunately, that
        # messes up line numbers. Thus, we have to check ourselves if anything
        # is outside the ASCII range in the case no encoding is explicitly
        # declared. For more context, see issue #269. Yay for Python 3 which
        # gets this right.
        end1 = source.find("\n")
        end2 = source.find("\n", end1 + 1)
        if (not source.startswith(BOM_UTF8) and
            cookie_re.match(source[0:end1]) is None and
            cookie_re.match(source[end1 + 1:end2]) is None):
            try:
                source.decode("ascii")
            except UnicodeDecodeError:
                # Let it fail in real import.
                return None, None
    # On Python versions which are not 2.7 and less than or equal to 3.1, the
    # parser expects *nix newlines.
    return stat, source
