class AppTestToken:

    def setup_class(cls):
        cls.w_token = cls.space.appexec([], """():
    import token
    return token""")

    def test_isterminal(self):
        assert self.token.ISTERMINAL(self.token.ENDMARKER)
        assert not self.token.ISTERMINAL(300)

    def test_isnonterminal(self):
        assert self.token.ISNONTERMINAL(300)
        assert not self.token.ISNONTERMINAL(self.token.NAME)

    def test_iseof(self):
        assert self.token.ISEOF(self.token.ENDMARKER)
        assert not self.token.ISEOF(self.token.NAME)

    def test_nl_and_comment_exist_in_all(self):
        assert "NL" in self.token.__all__
        assert "COMMENT" in self.token.__all__

    def test_encoding_exists(self):
        self.token.ISTERMINAL(self.token.ENCODING)

    def test_exact_token_types(self):
        assert self.token.EXACT_TOKEN_TYPES[":="] == self.token.COLONEQUAL
