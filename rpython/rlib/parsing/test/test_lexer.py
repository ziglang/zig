import py
from rpython.rlib.parsing.lexer import *
from rpython.rlib.parsing.regex import *
from rpython.rlib.parsing import deterministic

class TestDirectLexer(object):
    def get_lexer(self, rexs, names, ignore=None):
        return Lexer(rexs, names, ignore)

    def test_simple(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" ")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE"]
        l = self.get_lexer(rexs, names)
        r = l.get_runner("if: else: while:")
        t = r.find_next_token()
        assert t == Token("IF", "if", SourcePos(0, 0, 0))
        t = r.find_next_token()
        assert t == Token("COLON", ":", SourcePos(2, 0, 2))
        t = r.find_next_token()
        assert t == Token("WHITE", " ", SourcePos(3, 0, 3))
        t = r.find_next_token()
        assert t == Token("ELSE", "else", SourcePos(4, 0, 4))
        t = r.find_next_token()
        assert t == Token("COLON", ":", SourcePos(8, 0, 8))
        t = r.find_next_token()
        assert t == Token("WHITE", " ", SourcePos(9, 0, 9))
        t = r.find_next_token()
        assert t == Token("WHILE", "while", SourcePos(10, 0, 10))
        t = r.find_next_token()
        assert t == Token("COLON", ":", SourcePos(15, 0, 15))
        py.test.raises(StopIteration, r.find_next_token)
        assert [t.name for t in l.tokenize("if if if: else while")] == "IF WHITE IF WHITE IF COLON WHITE ELSE WHITE WHILE".split()

    def test_pro(self):
        digits = RangeExpression("0", "9")
        lower = RangeExpression("a", "z")
        upper = RangeExpression("A", "Z")
        keywords = StringExpression("if") | StringExpression("else") | StringExpression("def") | StringExpression("class")
        underscore = StringExpression("_")
        atoms = lower + (upper | lower | digits | underscore).kleene()
        vars = underscore | (upper + (upper | lower | underscore | digits).kleene())
        integers = StringExpression("0") | (RangeExpression("1", "9") + digits.kleene())
        white = StringExpression(" ")
        l = self.get_lexer([keywords, atoms, vars, integers, white], ["KEYWORD", "ATOM", "VAR", "INT", "WHITE"])
        assert ([t.name for t in l.tokenize("if A a 12341 0 else")] ==
                "KEYWORD WHITE VAR WHITE ATOM WHITE INT WHITE INT WHITE KEYWORD".split())

    def test_ignore(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" ")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE"]
        l = self.get_lexer(rexs, names, ["WHITE"])
        assert [t.name for t in l.tokenize("if if if: else while")] == "IF IF IF COLON ELSE WHILE".split()
      
    def test_errors(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" ")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE"]
        l = self.get_lexer(rexs, names, ["WHITE"])
        info = py.test.raises(deterministic.LexerError, l.tokenize, "if if if: a else while")
        print dir(info)
        print info.__class__
        exc = info.value
        assert exc.input[exc.source_pos.i] == "a"

    def test_eof(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" ")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE"]
        l = self.get_lexer(rexs, names, ["WHITE"])
        s = "if if if: else while"
        tokens = list(l.get_runner(s, eof=True))
        print tokens
        assert tokens[-1] == Token("EOF", "EOF", SourcePos(len(s), 0, len(s)))
        tokens = l.tokenize(s, eof=True)
        print tokens
        assert tokens[-1] == Token("EOF", "EOF", SourcePos(len(s), 0, len(s)))

    def test_position(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" "), StringExpression("\n")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE", "NL"]
        l = self.get_lexer(rexs, names, ["WHITE"])
        s = "if\nif if:\nelse while\n"
        tokens = list(l.get_runner(s, eof=True))
        assert tokens[0] == Token("IF", "if", SourcePos(0, 0, 0))
        assert tokens[1] == Token("NL", "\n", SourcePos(2, 0, 2))
        assert tokens[2] == Token("IF", "if", SourcePos(3, 1, 0))
        assert tokens[3] == Token("IF", "if", SourcePos(6, 1, 3))
        assert tokens[4] == Token("COLON", ":", SourcePos(8, 1, 5))
        assert tokens[5] == Token("NL", "\n", SourcePos(9, 1, 6))
        assert tokens[6] == Token("ELSE", "else", SourcePos(10, 2, 0))
        assert tokens[7] == Token("WHILE", "while", SourcePos(15, 2, 5))
        assert tokens[8] == Token("NL", "\n", SourcePos(20, 2, 10))
        assert tokens[9] == Token("EOF", "EOF", SourcePos(21, 3, 0))

    def test_position_ignore(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" "), StringExpression("\n")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE", "NL"]
        l = self.get_lexer(rexs, names, ["WHITE", "NL"])
        s = "if\nif if:\nelse while\n"
        tokens = list(l.get_runner(s, eof=True))
        assert tokens[0] == Token("IF", "if", SourcePos(0, 0, 0))
        assert tokens[1] == Token("IF", "if", SourcePos(3, 1, 0))
        assert tokens[2] == Token("IF", "if", SourcePos(6, 1, 3))
        assert tokens[3] == Token("COLON", ":", SourcePos(8, 1, 5))
        assert tokens[4] == Token("ELSE", "else", SourcePos(10, 2, 0))
        assert tokens[5] == Token("WHILE", "while", SourcePos(15, 2, 5))
        assert tokens[6] == Token("EOF", "EOF", SourcePos(21, 3, 0))

    def test_left_stuff_at_eof(self):
        rexs = [StringExpression("if"), StringExpression("else"),
                StringExpression("while"), StringExpression(":"),
                StringExpression(" "), StringExpression("\n")]
        names = ["IF", "ELSE", "WHILE", "COLON", "WHITE", "NL"]
        l = self.get_lexer(rexs, names)
        s = "if: whi"
        runner = l.get_runner(s, eof=True)
        tokens = []
        tok = runner.find_next_token()
        assert tok.name == "IF"
        tok = runner.find_next_token()
        assert tok.name == "COLON"
        tok = runner.find_next_token()
        assert tok.name == "WHITE"
        py.test.raises(deterministic.LexerError, runner.find_next_token)

class TestSourcePos(object):
    def test_copy(self):
        base = SourcePos(1, 2, 3)
        attributes = {'i':4, 'lineno': 5, 'columnno': 6}
        for attr, new_val in attributes.iteritems():
            copy = base.copy()
            assert base==copy
            setattr(copy, attr, new_val)    # change one attribute
            assert base!=copy

class TestToken(object):
    def test_copy(self):
        base = Token('test', 'spource', SourcePos(1,2,3))
        attributes = {'name': 'xxx', 'source': 'yyy', 'source_pos': SourcePos(4,5,6)}
        for attr, new_val in attributes.iteritems():
            copy = base.copy()
            assert base==copy
            setattr(copy, attr, new_val)    # change one attribute
            assert base!=copy
        # copy() is not deep... verify this.
        copy = base.copy()
        copy.source_pos.i = 0 # changes base too
        assert base==copy
