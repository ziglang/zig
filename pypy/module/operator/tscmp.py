"""
Provides _compare_digest method, which is a safe comparing to prevent timing
attacks for the hmac module.
"""
import py

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator import cdir
from rpython.translator.tool.cbuild import ExternalCompilationInfo

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.unicodehelper import encode

cwd = py.path.local(__file__).dirpath()
eci = ExternalCompilationInfo(
    includes=[cwd.join('tscmp.h')],
    include_dirs=[str(cwd), cdir],
    separate_module_files=[cwd.join('tscmp.c')])


def llexternal(*args, **kwargs):
    kwargs.setdefault('compilation_info', eci)
    kwargs.setdefault('sandboxsafe', True)
    return rffi.llexternal(*args, **kwargs)


pypy_tscmp = llexternal(
    'pypy_tscmp',
    [rffi.CCHARP, rffi.CCHARP, rffi.SIGNED, rffi.SIGNED],
    rffi.INT)


def compare_digest(space, w_a, w_b):
    """compare_digest(a, b) -> bool

    Return 'a == b'.  This function uses an approach designed to prevent
    timing analysis, making it appropriate for cryptography.  a and b
    must both be of the same type: either str (ASCII only), or any type
    that supports the buffer protocol (e.g. bytes).

    Note: If a and b are of different lengths, or if an error occurs, a
    timing attack could theoretically reveal information about the types
    and lengths of a and b--but not their values.

    XXX note that here the strings have to have the same length as UTF8,
    not only as unicode. Not sure how to do better
    """
    if (space.isinstance_w(w_a, space.w_unicode) and
        space.isinstance_w(w_b, space.w_unicode)):
        try:
            w_a = encode(space, w_a, 'ascii')
            w_b = encode(space, w_b, 'ascii')
        except OperationError as e:
            if not e.match(space, space.w_UnicodeEncodeError):
                raise
            raise oefmt(space.w_TypeError,
                        "comparing strings with non-ASCII characters is not "
                        "supported")
    return compare_digest_buffer(space, w_a, w_b)


def compare_digest_buffer(space, w_a, w_b):
    a = space.charbuf_w(w_a)
    b = space.charbuf_w(w_b)
    return space.newbool(_compare_two_strings(a, b))

def _compare_two_strings(a, b):
    with rffi.scoped_nonmovingbuffer(a) as a_buf:
        with rffi.scoped_nonmovingbuffer(b) as b_buf:
            result = pypy_tscmp(a_buf, b_buf, len(a), len(b))
    return rffi.cast(lltype.Bool, result)
