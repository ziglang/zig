import sys
from pypy.interpreter.error import OperationError

class BaseFSEncodeTest:

    def setup_class(cls):
        space = cls.space
        cls.testfn_unencodable = get_unencodable()
        cls.w_testfn_unencodable = space.wrap(cls.testfn_unencodable)
        cls.special_char = get_special_char()
        cls.w_special_char = space.wrap(cls.special_char)

def get_unencodable():
    """Copy of the stdlib's support.TESTFN_UNENCODABLE:

    A filename (py3k str type) that should *not* be able to be encoded
    by the filesystem encoding (in strict mode). It can be None if we
    cannot generate such filename.
    """
    testfn_unencodable = None
    testfn = u'test_tmp'

    if sys.platform == 'win32':
        testfn_unencodable = testfn + u"-\u5171\u0141\u2661\u0363\uDC80"
    elif sys.platform != 'darwin':
        try:
            '\xff'.decode(sys.getfilesystemencoding())
        except UnicodeDecodeError:
            testfn_unencodable = testfn + u'-\udcff'
    return testfn_unencodable

def get_special_char():
    """Copy of the stdlib's test_imp.test_issue5604 special_char:

    A non-ascii filename (py3k str type) that *should* be able to be
    encoded by the filesystem encoding (in strict mode). It can be None
    if we cannot generate such filename.
    """
    fsenc = sys.getfilesystemencoding()
    # covers utf-8 and Windows ANSI code pages one non-space symbol from
    # every page (http://en.wikipedia.org/wiki/Code_page)
    known_locales = {
        'utf-8' : b'\xc3\xa4',
        'cp1250' : b'\x8C',
        'cp1251' : b'\xc0',
        'cp1252' : b'\xc0',
        'cp1253' : b'\xc1',
        'cp1254' : b'\xc0',
        'cp1255' : b'\xe0',
        'cp1256' : b'\xe0',
        'cp1257' : b'\xc0',
        'cp1258' : b'\xc0',
        }

    if sys.platform == 'darwin':
        # Mac OS X uses the Normal Form D decomposition
        # http://developer.apple.com/mac/library/qa/qa2001/qa1173.html
        special_char = b'a\xcc\x88'
    else:
        special_char = known_locales.get(fsenc)

    if special_char:
        return special_char.decode(fsenc)

class TestFSEncode(BaseFSEncodeTest):
    def test_fsencode_fsdecode(self):
        space = self.space
        strs = [u"/home/bar/baz", u"c:\\"]
        if self.special_char:
            strs.append(self.special_char)
        for st in strs:
            # check roundtrip
            w_st = space.newtext(st.encode('utf8'), len(st))
            w_enc = space.fsencode(w_st)
            w_st2 = space.fsdecode(w_enc)
            assert space.eq_w(w_st, w_st2)
            assert space.fsdecode_w(w_enc) == st

            assert space.fsencode_w(w_enc) == space.bytes_w(w_enc)
            assert space.eq_w(space.newfilename(space.bytes_w(w_enc)), w_st2)

    def test_null_byte(self):
        space = self.space
        uni = u'abc\x00def'
        w_u = space.newtext(uni.encode('utf8'), len(uni))
        # this can behave in two different ways depending on how
        # much initialized the space is: space.fsencode() can raise
        # ValueError directly, or return a wrapped bytes with the 0
        # embedded---and then space.fsencode_w() should raise ValueError.
        space.raises_w(space.w_ValueError, space.fsencode_w, w_u)

    def test_interface_from___pypy__(self):
        space = self.space
        strs = [u"/home/bar/baz", u"c:\\"]
        if self.special_char:
            strs.append(self.special_char)
        for st in strs:
            w_st = space.newtext(st.encode('utf8'), len(st))
            w_enc = space.fsencode(w_st)
            space.appexec([w_st, w_enc], """(u, s):
                import __pypy__
                assert __pypy__.fsencode(u) == s
                assert __pypy__.fsdecode(s) == u
            """)
