from rpython.rtyper.lltypesystem import lltype
from rpython.translator.gensupp import NameManager

#
# use __slots__ declarations for node classes etc
# possible to turn it off while refactoring, experimenting
#
USESLOTS = True

def barebonearray(ARRAY):
    """Check if ARRAY is a 'simple' array type,
    i.e. doesn't need a length nor GC headers."""
    return (ARRAY._hints.get('nolength', False) and ARRAY._gckind != 'gc'
            and ARRAY.OF is not lltype.Void)


#
# helpers
#
def cdecl(ctype, cname, is_thread_local=False):
    """
    Produce a C declaration from a 'type template' and an identifier.
    The type template must contain a '@' sign at the place where the
    name should be inserted, according to the strange C syntax rules.
    """
    # the (@) case is for functions, where if there is a plain (@) around
    # the function name, we don't need the very confusing parenthesis
    __thread = ""
    if is_thread_local:
        __thread = "__thread "
    return __thread + ctype.replace('(@)', '@').replace('@', cname).strip()

def forward_cdecl(ctype, cname, standalone, is_thread_local=False,
                  is_exported=False):
    # 'standalone' ignored
    if is_exported:
        assert not is_thread_local
        prefix = "RPY_EXPORTED "
    else:
        prefix = "RPY_EXTERN "
        if is_thread_local:
            prefix += "__thread "
    return prefix + cdecl(ctype, cname)

def somelettersfrom(s):
    upcase = [c for c in s if c.isupper()]
    if not upcase:
        upcase = [c for c in s.title() if c.isupper()]
    locase = [c for c in s if c.islower()]
    if locase and upcase:
        return ''.join(upcase).lower()
    else:
        return s[:2].lower()

def is_pointer_to_forward_ref(T):
    if not isinstance(T, lltype.Ptr):
        return False
    return isinstance(T.TO, lltype.ForwardReference)

def llvalue_from_constant(c):
    T = c.concretetype
    if T == lltype.Void:
        return None
    else:
        ACTUAL_TYPE = lltype.typeOf(c.value)
        # If the type is still uncomputed, we can't make this
        # check.  Something else will blow up instead, probably
        # very confusingly.
        if not is_pointer_to_forward_ref(ACTUAL_TYPE):
            assert ACTUAL_TYPE == T
        return c.value


class CNameManager(NameManager):
    def __init__(self, global_prefix='pypy_'):
        NameManager.__init__(self, global_prefix=global_prefix)
        # keywords cannot be reused.  This is the C99 draft's list.
        self.make_reserved_names('''
           auto      enum      restrict  unsigned
           break     extern    return    void
           case      float     short     volatile
           char      for       signed    while
           const     goto      sizeof    _Bool
           continue  if        static    _Complex
           default   inline    struct    _Imaginary
           do        int       switch
           double    long      typedef
           else      register  union
           ''')

def _char_repr(c):
    # escape with a '\' the characters '\', '"' or (for trigraphs) '?'
    if c in '\\"?': return '\\' + c
    if ' ' <= c < '\x7F': return c
    return '\\%03o' % ord(c)

def _line_repr(s):
    return ''.join([_char_repr(c) for c in s])


def c_string_constant(s):
    '''Returns a " "-delimited string literal for C.'''
    lines = []
    for i in range(0, len(s), 64):
        lines.append('"%s"' % _line_repr(s[i:i+64]))
    return '\n'.join(lines)


def c_char_array_constant(s):
    '''Returns an initializer for a constant char[N] array,
    where N is exactly len(s).  This is either a " "-delimited
    string or a { }-delimited array of small integers.
    '''
    if s.endswith('\x00') and 1 < len(s) < 1024:
        # C++ is stricter than C: we can only use a " " literal
        # if the last character is NULL, because such a literal
        # always has an extra implicit NULL terminator.
        return c_string_constant(s[:-1])
    else:
        lines = []
        for i in range(0, len(s), 20):
            lines.append(','.join([str(ord(c)) for c in s[i:i+20]]))
        if len(lines) > 1:
            return '{\n%s}' % ',\n'.join(lines)
        else:
            return '{%s}' % ', '.join(lines)


def gen_assignments(assignments):
    # Generate a sequence of assignments that is possibly reordered
    # to avoid clashes -- i.e. do the equivalent of a tuple assignment,
    # reading all sources first, writing all targets next, but optimized

    srccount = {}
    dest2src = {}
    for typename, dest, src in assignments:
        if src != dest:   # ignore 'v=v;'
            srccount[src] = srccount.get(src, 0) + 1
            dest2src[dest] = src, typename

    while dest2src:
        progress = False
        for dst in dest2src.keys():
            if dst not in srccount:
                src, typename = dest2src.pop(dst)
                yield '%s = %s;' % (dst, src)
                srccount[src] -= 1
                if not srccount[src]:
                    del srccount[src]
                progress = True
        if not progress:
            # we are left with only pure disjoint cycles; break them
            while dest2src:
                dst, (src, typename) = dest2src.popitem()
                assert srccount[dst] == 1
                startingpoint = dst
                tmpdecl = cdecl(typename, 'tmp')
                code = ['{ %s = %s;' % (tmpdecl, dst)]
                while src != startingpoint:
                    code.append('%s = %s;' % (dst, src))
                    dst = src
                    src, typename = dest2src.pop(dst)
                    assert srccount[dst] == 1
                code.append('%s = tmp; }' % (dst,))
                yield ' '.join(code)

# logging

from rpython.tool.ansi_print import AnsiLogger
log = AnsiLogger("c")
