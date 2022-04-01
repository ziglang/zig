import py
from rpython.jit.metainterp.test import support
from rpython.rlib.rsre.test.test_match import get_code
from rpython.rlib.rsre import rsre_core
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.annlowlevel import llstr, hlstr

def entrypoint1(r, string, repeat):
    r = rsre_core.CompiledPattern(array2list(r), 0)
    string = hlstr(string)
    match = None
    for i in range(repeat):
        match = rsre_core.match(r, string)
        if match is None:
            return -1
    if match is None:
        return -1
    else:
        return match.match_end

def entrypoint2(r, string, repeat):
    r = rsre_core.CompiledPattern(array2list(r), 0)
    string = hlstr(string)
    match = None
    for i in range(repeat):
        match = rsre_core.search(r, string)
    if match is None:
        return -1
    else:
        return match.match_start

def list2array(lst):
    a = lltype.malloc(lltype.GcArray(lltype.Signed), len(lst))
    for i, x in enumerate(lst):
        a[i] = int(x)
    return a

def array2list(a):
    return [a[i] for i in range(len(a))]


def test_jit_unroll_safe():
    # test that the decorators are applied in the right order
    assert not hasattr(rsre_core.sre_match, '_jit_unroll_safe_')
    for m in rsre_core.sre_match._specialized_methods_:
        assert m._jit_unroll_safe_


class TestJitRSre(support.LLJitMixin):

    def meta_interp_match(self, pattern, string, repeat=1):
        r = get_code(pattern)
        return self.meta_interp(entrypoint1, [list2array(r.pattern), llstr(string),
                                              repeat],
                                listcomp=True, backendopt=True)

    def meta_interp_search(self, pattern, string, repeat=1):
        r = get_code(pattern)
        return self.meta_interp(entrypoint2, [list2array(r.pattern), llstr(string),
                                              repeat],
                                listcomp=True, backendopt=True)

    def test_simple_match_1(self):
        res = self.meta_interp_match(r"ab*bbbbbbbc", "abbbbbbbbbcdef")
        assert res == 11

    def test_simple_match_2(self):
        res = self.meta_interp_match(r".*abc", "xxabcyyyyyyyyyyyyy")
        assert res == 5

    def test_simple_match_repeated(self):
        res = self.meta_interp_match(r"abcdef", "abcdef", repeat=10)
        assert res == 6
        self.check_trace_count(1)
        self.check_jitcell_token_count(1)

    def test_match_minrepeat_1(self):
        res = self.meta_interp_match(r".*?abc", "xxxxxxxxxxxxxxabc")
        assert res == 17

    #def test_match_maxuntil_1(self):
    #    res = self.meta_interp_match(r"(ab)*c", "ababababababababc")
    #    assert res == 17

    def test_branch_1(self):
        res = self.meta_interp_match(r".*?(ab|x)c", "xxxxxxxxxxxxxxabc")
        assert res == 17

    def test_match_minrepeat_2(self):
        s = ("xxxxxxxxxxabbbbbbbbbb" +
             "xxxxxxxxxxabbbbbbbbbb" +
             "xxxxxxxxxxabbbbbbbbbb" +
             "xxxxxxxxxxabbbbbbbbbbc")
        res = self.meta_interp_match(r".*?ab+?c", s)
        assert res == len(s)


    def test_fast_search(self):
        res = self.meta_interp_search(r"<foo\w+>", "e<f<f<foxd<f<fh<foobar>ua")
        assert res == 15
        self.check_resops(guard_value=0)

    def test_regular_search(self):
        res = self.meta_interp_search(r"<\w+>", "eiofweoxdiwhdoh<foobar>ua")
        assert res == 15

    def test_regular_search_upcase(self):
        res = self.meta_interp_search(r"<\w+>", "EIOFWEOXDIWHDOH<FOOBAR>UA")
        assert res == 15

    def test_max_until_1(self):
        res = self.meta_interp_match(r"(ab)*abababababc",
                                     "ababababababababababc")
        assert res == 21

    def test_example_1(self):
        res = self.meta_interp_search(
            r"Active\s+20\d\d-\d\d-\d\d\s+[[]\d+[]]([^[]+)",
            "Active"*20 + "Active 2010-04-07 [42] Foobar baz boz blah[43]")
        assert res == 6*20

    def test_aorbstar(self):
        res = self.meta_interp_match("(a|b)*a", "a" * 100)
        assert res == 100
        self.check_resops(guard_value=0)


    # group guards tests

    def test_group_range(self):
        res = self.meta_interp_match(r"<[^b-c]+>", "<aeaeaea>")
        assert res == 9
        self.check_enter_count(1)

    def test_group_single_chars(self):
        res = self.meta_interp_match(r"<[ae]+>", "<aeaeaea>")
        assert res == 9
        self.check_enter_count(1)

    def test_group_digit(self):
        res = self.meta_interp_match(r"<[^\d]+>", "<..a..aa>")
        assert res == 9
        self.check_enter_count(1)

    def test_group_space(self):
        res = self.meta_interp_match(r"<\S+>", "<..a..aa>")
        assert res == 9
        self.check_enter_count(1)

    def test_group_word(self):
        res = self.meta_interp_match(r"<\w+>", "<ab09_a1>")
        assert res == 9
        self.check_enter_count(1)

    def test_group_complex(self):
        res = self.meta_interp_match(r"<[a@h\d\s]+>", "<a93919a @ a23>")
        assert res == 15
        self.check_enter_count(1)

    @py.test.mark.xfail
    def test_group_space_but_not_space(self):
        res = self.meta_interp_match(r"<[\S ]+>", "<..a   .. aa>")
        assert res == 13
        self.check_enter_count(1)


    def test_find_repetition_end_fastpath(self):
        res = self.meta_interp_search(r"b+", "a"*30 + "b")
        assert res == 30
        self.check_resops(call=0)

    def test_match_jit_bug(self):
        pattern = ".a" * 2500
        text = "a" * 6000
        res = self.meta_interp_match(pattern, text, repeat=10)
        assert res != -1

    def test_getlower_branch_free(self):
        pattern = "(?i)a[bx]*c"
        text = "a" + "bBbbB" * 1000 + "c"
        res = self.meta_interp_match(pattern, text)
        self.check_enter_count(1)
