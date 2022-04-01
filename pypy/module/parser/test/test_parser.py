class ParserModuleTest:
    spaceconfig = dict(usemodules=["parser"])

    def setup_class(cls):
        cls.w_m = cls.space.appexec([], """():
    import parser
    return parser""")
        cls.w_symbol = cls.space.appexec([], """():
    import symbol
    return symbol""")


class AppTestParser(ParserModuleTest):

    def test_suite(self):
        s = self.m.suite("x = 4")
        assert isinstance(s, self.m.STType)
        assert self.m.issuite(s)
        assert s.issuite()
        assert not self.m.isexpr(s)
        assert not s.isexpr()

    def test_expr(self):
        s = self.m.expr("x")
        assert isinstance(s, self.m.STType)
        assert self.m.isexpr(s)
        assert s.isexpr()
        assert not self.m.issuite(s)
        assert not s.issuite()

    def test_totuple_and_tolist(self):
        for meth, tp in (("totuple", tuple), ("tolist", list)):
            s = self.m.suite("x = 4")
            seq = getattr(s, meth)()
            assert isinstance(seq, tp)
            assert len(seq) == 4
            assert seq[0] == self.symbol.file_input
            assert len(seq[2]) == 2
            assert len(seq[3]) == 2
            assert seq[2][0] == 4
            assert seq[3][0] == 0
            seq = getattr(s, meth)(True)
            assert len(seq[2]) == 3
            assert seq[2][2] == 1
            seq = getattr(s, meth)(True, True)
            assert len(seq[2]) == 4
            assert seq[2][2] == 1
            assert seq[2][3] == 0

    def test_error(self):
        assert repr(self.m.ParserError) == "<class 'parser.ParserError'>"

    def test_roundtrip(self):
        def roundtrip(f, s):
            st1 = f(s)
            t = st1.totuple()
            st2 = self.m.sequence2st(t)
            assert t == st2.totuple()

        def check_expr(s):
            roundtrip(self.m.expr, s)
        def check_suite(s):
            roundtrip(self.m.suite, s)

        check_expr("foo(1)")
        check_suite("def f(): yield 1")

    def test_bad_tree(self):
        import parser
        # from import a
        tree = \
            (257,
             (267,
              (268,
               (269,
                (281,
                 (283, (1, 'from'), (1, 'import'),
                  (286, (284, (1, 'fred')))))),
               (4, ''))),
             (4, ''), (0, ''))
        raises(parser.ParserError,
               parser.sequence2st, tree)
