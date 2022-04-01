import py
from rpython.rlib.parsing.parsing import PackratParser, Rule, Nonterminal
from rpython.rlib.parsing.parsing import Symbol, ParseError
from rpython.rlib.parsing.ebnfparse import parse_ebnf, make_parse_function
from rpython.rlib.parsing.deterministic import LexerError
from rpython.rlib.parsing.tree import RPythonVisitor

class TestDictError(object):
    dictebnf = """
        QUOTED_STRING: "'[^\\']*'";
        IGNORE: " |\n";
        data: <dict> | <QUOTED_STRING> | <list>;
        dict: ["{"] (dictentry [","])* dictentry ["}"];
        dictentry: QUOTED_STRING [":"] data;
        list: ["["] (data [","])* data ["]"];
    """

    def setup_class(cls):
        regexs, rules, ToAST = parse_ebnf(cls.dictebnf)
        cls.ToAST = ToAST
        parse = make_parse_function(regexs, rules, eof=True)
        cls.parse = staticmethod(parse)

    def test_lexererror(self):
        excinfo = py.test.raises(LexerError, self.parse, """
{
    'type': 'SCRIPT',$#
    'funDecls': '',
    'length': '1',
}""")
        msg = excinfo.value.nice_error_message("<stdin>")
        print msg
        assert msg == """\
  File <stdin>, line 3
    'type': 'SCRIPT',$#
                     ^
LexerError"""

    def test_parseerror(self):
        source = """
{
    'type': 'SCRIPT',
    'funDecls': '',
    'length':: '1',
}"""
        excinfo = py.test.raises(ParseError, self.parse, source)
        error = excinfo.value.errorinformation
        source_pos = excinfo.value.source_pos
        assert source_pos.lineno == 4
        assert source_pos.columnno == 13
        msg = excinfo.value.nice_error_message("<stdin>", source)
        print msg
        assert msg == """\
  File <stdin>, line 5
    'length':: '1',
             ^
ParseError: expected '{', 'QUOTED_STRING' or '['"""
