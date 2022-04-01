# -*- coding: utf-8 -*-
import py
import pytest
from pypy.interpreter.pyparser import pyparse
from pypy.interpreter.pyparser.pygram import syms, tokens
from pypy.interpreter.pyparser.error import SyntaxError, IndentationError, TabError
from pypy.interpreter.astcompiler import consts


class TestPythonParserOnly: # not subclassed for Peg
    spaceconfig = {}

    def setup_class(self):
        self.parser = pyparse.PythonParser(self.space)

    def parse(self, source, mode="exec", info=None, flags=0):
        if info is None:
            info = pyparse.CompileInfo("<test>", mode, flags=flags)
        return self.parser.parse_source(source, info)

    def test_clear_state(self):
        assert self.parser.root is None
        tree = self.parse("name = 32")
        assert self.parser.root is None

    def test_encoding(self):
        info = pyparse.CompileInfo("<test>", "exec")
        tree = self.parse("""# coding: latin-1
stuff = "nothing"
""", info=info)
        assert tree.type == syms.file_input
        assert info.encoding == "iso-8859-1"
        sentence = u"u'Die Männer ärgern sich!'"
        input = (u"# coding: utf-7\nstuff = %s" % (sentence,)).encode("utf-7")
        tree = self.parse(input, info=info)
        assert info.encoding == "utf-7"
        input = "# coding: iso-8859-15\nx"
        self.parse(input, info=info)
        assert info.encoding == "iso-8859-15"
        input = "\xEF\xBB\xBF# coding: utf-8\nx"
        self.parse(input, info=info)
        assert info.encoding == "utf-8"
        input = "\xEF\xBB\xBF# coding: latin-1\nx"
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == "UTF-8 BOM with latin-1 coding cookie"
        input = "\xEF\xBB\xBF# coding: UtF-8-yadda-YADDA\nx"
        self.parse(input)    # this does not raise
        input = "# coding: not-here"
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == "Unknown encoding: not-here"
        input = u"# coding: ascii\n\xe2".encode('utf-8')
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == ("'ascii' codec can't decode byte 0xc3 "
                           "in position 16: ordinal not in range(128)")

    def test_mode(self):
        assert self.parse("x = 43*54").type == syms.file_input
        tree = self.parse("43**54", "eval")
        assert tree.type == syms.eval_input
        py.test.raises(SyntaxError, self.parse, "x = 54", "eval")
        tree = self.parse("x = 43", "single")
        assert tree.type == syms.single_input

    def test_universal_newlines(self):
        fmt = 'stuff = """hello%sworld"""'
        expected_tree = self.parse(fmt % '\n')
        for linefeed in ["\r\n","\r"]:
            tree = self.parse(fmt % linefeed)
            assert expected_tree == tree

    def test_end_positions(self):
        tree = self.parse("45 * a", "eval").get_child(0)
        assert tree.get_end_column() == 6


class TestPythonParser:
    spaceconfig = {}

    def setup_class(self):
        self.parser = pyparse.PythonParser(self.space)

    def parse(self, source, mode="exec", info=None, flags=0):
        if info is None:
            info = pyparse.CompileInfo("<test>", mode, flags=flags)
        return self.parser.parse_source(source, info)

    def test_with_and_as(self):
        py.test.raises(SyntaxError, self.parse, "with = 23")
        py.test.raises(SyntaxError, self.parse, "as = 2")

    def test_dont_imply_dedent(self):
        info = pyparse.CompileInfo("<test>", "single",
                                   consts.PyCF_DONT_IMPLY_DEDENT)
        self.parse('if 1:\n  x\n', info=info)
        self.parse('x = 5 ', info=info)
        py.test.raises(SyntaxError, self.parse, "if 1:\n  x", info=info)
        excinfo = py.test.raises(SyntaxError, self.parse, "if 1:\n  x x\n", info=info)

    def test_encoding_pep3120(self):
        info = pyparse.CompileInfo("<test>", "exec")
        tree = self.parse("""foo = '日本'""", info=info)
        assert info.encoding == 'utf-8'

    def test_unicode_identifier(self):
        tree = self.parse("a日本 = 32")
        tree = self.parse("日本 = 32")

    def test_syntax_error(self):
        parse = self.parse
        exc = py.test.raises(SyntaxError, parse, "name another for").value
        assert exc.msg.startswith("invalid syntax")
        assert exc.lineno == 1
        assert exc.offset in (1, 6)
        assert exc.text.startswith("name another for")
        exc = py.test.raises(SyntaxError, parse, "x = \"blah\n\n\n").value
        assert exc.msg == "end of line (EOL) while scanning string literal"
        assert exc.lineno == 1
        assert exc.offset == 5
        exc = py.test.raises(SyntaxError, parse, "x = '''\n\n\n").value
        assert exc.msg == "end of file (EOF) while scanning triple-quoted string literal"
        assert exc.lineno == 1
        assert exc.offset == 5
        assert exc.lastlineno == 3
        for input in ("())", "(()", "((", "))"):
            py.test.raises(SyntaxError, parse, input)
        exc = py.test.raises(SyntaxError, parse, "x = (\n\n(),\n(),").value
        assert exc.msg == "parenthesis is never closed"
        assert exc.lineno == 1
        assert exc.offset == 5
        assert exc.lastlineno == 5
        exc = py.test.raises(SyntaxError, parse, "abc)").value
        assert exc.msg == "unmatched ')'"
        assert exc.lineno == 1
        assert exc.offset == 4
        exc = py.test.raises(SyntaxError, parse, "\\").value
        assert exc.msg == "end of file (EOF) in multi-line statement"

    def test_is(self):
        self.parse("x is y")
        self.parse("x is not y")

    def test_indentation_error(self):
        parse = self.parse
        input = """
def f():
pass"""
        exc = py.test.raises(IndentationError, parse, input).value
        assert exc.msg == "expected an indented block after function definition on line 2"
        assert exc.lineno == 3
        assert exc.text.startswith("pass")
        assert exc.offset == 1
        input = "hi\n    indented"
        exc = py.test.raises(IndentationError, parse, input).value
        assert exc.msg == "unexpected indent"
        input = "def f():\n    pass\n  next_stmt"
        exc = py.test.raises(IndentationError, parse, input).value
        assert exc.msg == "unindent does not match any outer indentation level"
        assert exc.lineno == 3
        assert exc.offset == 3

        input = """
if 1\
        > 3:
pass"""
        exc = py.test.raises(IndentationError, parse, input).value
        assert exc.msg == "expected an indented block after 'if' statement on line 2"
        assert exc.lineno == 3
        assert exc.text.startswith("pass")
        assert exc.offset == 1

        input = """
if x > 1:
    pass
elif x < 1:
pass"""
        exc = py.test.raises(IndentationError, parse, input).value
        assert exc.msg == "expected an indented block after 'elif' statement on line 4"
        assert exc.lineno == 5
        assert exc.text.startswith("pass")
        assert exc.offset == 1


    def test_taberror(self):
        src = """
if 1:
        pass
    \tpass
"""
        exc = py.test.raises(TabError, "self.parse(src)").value
        assert exc.msg == "inconsistent use of tabs and spaces in indentation"
        assert exc.lineno == 4
        assert exc.offset == 5
        assert exc.text == "    \tpass\n"

    def test_mac_newline(self):
        self.parse("this_is\ra_mac\rfile")

    def test_multiline_string(self):
        self.parse("''' \n '''")
        self.parse("r''' \n '''")

    def test_bytes_literal(self):
        self.parse('b" "')
        self.parse('br" "')
        self.parse('b""" """')
        self.parse("b''' '''")
        self.parse("br'\\\n'")

        py.test.raises(SyntaxError, self.parse, "b'a\\n")

    def test_new_octal_literal(self):
        self.parse('0o777')
        py.test.raises(SyntaxError, self.parse, '0o777L')
        py.test.raises(SyntaxError, self.parse, "0o778")

    def test_new_binary_literal(self):
        self.parse('0b1101')
        py.test.raises(SyntaxError, self.parse, '0b0l')
        py.test.raises(SyntaxError, self.parse, "0b112")

    def test_print_function(self):
        self.parse("from __future__ import print_function\nx = print\n")

    def test_revdb_dollar_num(self):
        assert not self.space.config.translation.reverse_debugger
        py.test.raises(SyntaxError, self.parse, '$0')
        py.test.raises(SyntaxError, self.parse, '$0 + 5')
        py.test.raises(SyntaxError, self.parse,
                "from __future__ import print_function\nx = ($0, print)")

    def test_py3k_reject_old_binary_literal(self):
        py.test.raises(SyntaxError, self.parse, '0777')

    def test_py3k_extended_unpacking(self):
        self.parse('a, *rest, b = 1, 2, 3, 4, 5')
        self.parse('(a, *rest, b) = 1, 2, 3, 4, 5')

    def test_u_triple_quote(self):
        self.parse('u""""""')
        self.parse('U""""""')
        self.parse("u''''''")
        self.parse("U''''''")

    def test_bad_single_statement(self):
        py.test.raises(SyntaxError, self.parse, '1\n2', "single")
        py.test.raises(SyntaxError, self.parse, 'a = 13\nb = 187', "single")
        py.test.raises(SyntaxError, self.parse, 'del x\ndel y', "single")
        py.test.raises(SyntaxError, self.parse, 'f()\ng()', "single")
        py.test.raises(SyntaxError, self.parse, 'f()\n# blah\nblah()', "single")
        py.test.raises(SyntaxError, self.parse, 'f()\nxy # blah\nblah()', "single")
        py.test.raises(SyntaxError, self.parse, 'x = 5 # comment\nx = 6\n', "single")
    
    def test_unpack(self):
        self.parse('[*{2}, 3, *[4]]')
        self.parse('{*{2}, 3, *[4]}')
        self.parse('{**{}, 3:4, **{5:6, 7:8}}')
        self.parse('f(2, *a, *b, **b, **c, **d)')

    def test_async_await(self):
        self.parse("async def coro(): await func")
        self.parse("await x")
        #Test as var and func name
        with pytest.raises(SyntaxError):
            self.parse("async = 1")
        with pytest.raises(SyntaxError):
            self.parse("await = 1")
        with pytest.raises(SyntaxError):
            self.parse("def async(): pass")
        #async for
        self.parse("""async def foo():
    async for a in b:
        pass""")
        self.parse("""def foo():
    async for a in b:
        pass""")
        #async with
        self.parse("""async def foo():
    async with a:
        pass""")
        self.parse('''def foo():
        async with a:
            pass''')

    def test_async_await_hacks(self):
        def parse(source):
            return self.parse(source, flags=consts.PyCF_ASYNC_HACKS)

        # legal syntax
        parse("async def coro(): await func")

        # legal syntax for 3.6<=
        parse("async = 1")
        parse("await = 1")
        parse("def async(): pass")
        parse("def await(): pass")
        parse("""async def foo():
    async for a in b:
        pass""")

        # illegal syntax for 3.6<=
        with pytest.raises(SyntaxError):
            parse("await x")
        with pytest.raises(SyntaxError):
            parse("async for a in b: pass")
        with pytest.raises(SyntaxError):
            parse("def foo(): async for a in b: pass")
        with pytest.raises(SyntaxError):
            parse("def foo(): async for a in b: pass")

    def test_number_underscores(self):
        VALID_UNDERSCORE_LITERALS = [
            '0_0_0',
            '4_2',
            '1_0000_0000',
            '0b1001_0100',
            '0xffff_ffff',
            '0o5_7_7',
            '1_00_00.5',
            '1_00_00.5e5',
            '1_00_00e5_1',
            '1e1_0',
            '.1_4',
            '.1_4e1',
            '0b_0',
            '0x_f',
            '0o_5',
            '1_00_00j',
            '1_00_00.5j',
            '1_00_00e5_1j',
            '.1_4j',
            '(1_2.5+3_3j)',
            '(.5_6j)',
            '.2_3',
            '.2_3e4',
            '1.2_3',
            '1.2_3_4',
            '12.000_400',
            '1_2.3_4',
            '1_2.3_4e5_6',
        ]
        INVALID_UNDERSCORE_LITERALS = [
            # Trailing underscores:
            '0_',
            '42_',
            '1.4j_',
            '0x_',
            '0b1_',
            '0xf_',
            '0o5_',
            '0 if 1_Else 1',
            # Underscores in the base selector:
            '0_b0',
            '0_xf',
            '0_o5',
            # Old-style octal, still disallowed:
            '0_7',
            '09_99',
            # Multiple consecutive underscores:
            '4_______2',
            '0.1__4',
            '0.1__4j',
            '0b1001__0100',
            '0xffff__ffff',
            '0x___',
            '0o5__77',
            '1e1__0',
            '1e1__0j',
            # Underscore right before a dot:
            '1_.4',
            '1_.4j',
            # Underscore right after a dot:
            '1._4',
            '1._4j',
            '._5',
            '._5j',
            # Underscore right after a sign:
            '1.0e+_1',
            '1.0e+_1j',
            # Underscore right before j:
            '1.4_j',
            '1.4e5_j',
            # Underscore right before e:
            '1_e1',
            '1.4_e1',
            '1.4_e1j',
            # Underscore right after e:
            '1e_1',
            '1.4e_1',
            '1.4e_1j',
            # Complex cases with parens:
            '(1+1.5_j_)',
            '(1+1.5_j)',
            # Extra underscores around decimal part
            '._3',
            '._3e4',
            '1.2_',
            '1._3_4',
            '12._',
            '1_2._3',
        ]
        for x in VALID_UNDERSCORE_LITERALS:
            tree = self.parse(x)
        for x in INVALID_UNDERSCORE_LITERALS:
            print x
            py.test.raises(SyntaxError, self.parse, "x = %s" % x)

    def test_relaxed_decorators(self):
        self.parse("@(1 + 2)\ndef f(x): pass") # does not crash



class TestPythonParserWithSpace:

    def setup_class(self):
        self.parser = pyparse.PythonParser(self.space)

    def parse(self, source, mode="exec", info=None):
        if info is None:
            info = pyparse.CompileInfo("<test>", mode)
        return self.parser.parse_source(source, info)

    def test_encoding(self):
        info = pyparse.CompileInfo("<test>", "exec")
        tree = self.parse("""# coding: latin-1
stuff = "nothing"
""", info=info)
        assert tree.type == syms.file_input
        assert info.encoding == "iso-8859-1"
        sentence = u"'Die Männer ärgen sich!'"
        input = (u"# coding: utf-7\nstuff = %s" % (sentence,)).encode("utf-7")
        tree = self.parse(input, info=info)
        assert info.encoding == "utf-7"
        input = "# coding: iso-8859-15\nx"
        self.parse(input, info=info)
        assert info.encoding == "iso-8859-15"
        input = "\xEF\xBB\xBF# coding: utf-8\nx"
        self.parse(input, info=info)
        assert info.encoding == "utf-8"
        #
        info.flags |= consts.PyCF_SOURCE_IS_UTF8
        input = "#\nx"
        info.encoding = None
        self.parse(input, info=info)
        assert info.encoding == "utf-8"
        input = "# coding: latin1\nquux"
        self.parse(input, info=info)
        assert info.encoding == "latin1"
        info.flags |= consts.PyCF_IGNORE_COOKIE
        self.parse(input, info=info)
        assert info.encoding == "utf-8"
        info.flags &= ~(consts.PyCF_SOURCE_IS_UTF8 | consts.PyCF_IGNORE_COOKIE)
        #
        input = "\xEF\xBB\xBF# coding: latin-1\nx"
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == "UTF-8 BOM with latin-1 coding cookie"
        input = "# coding: not-here"
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == "Unknown encoding: not-here"
        input = u"# coding: ascii\n\xe2".encode('utf-8')
        exc = py.test.raises(SyntaxError, self.parse, input).value
        assert exc.msg == ("'ascii' codec can't decode byte 0xc3 "
                           "in position 16: ordinal not in range(128)")

    def test_error_forgotten_chars(self):
        info = py.test.raises(SyntaxError, self.parse, "if 1\n    print 4")
        assert "(expected ':')" in info.value.msg
        info = py.test.raises(SyntaxError, self.parse, "for i in range(10)\n    print i")
        assert "(expected ':')" in info.value.msg
        info = py.test.raises(SyntaxError, self.parse, "def f:\n print 1")
        assert "(expected '(')" in info.value.msg

    def test_positional_only_args(self):
        self.parse("def f(a, /): pass")

    def test_error_print_without_parens(self):
        info = py.test.raises(SyntaxError, self.parse, "print 1")
        assert "Missing parentheses in call to 'print'" in info.value.msg
        info = py.test.raises(SyntaxError, self.parse, "print 1)")
        assert "unmatched" in info.value.msg

    def test_error_exec_without_parens_bug(self):
        info = py.test.raises(SyntaxError, self.parse, "exec {1:(foo.)}")
        assert "Missing parentheses in call to 'exec'" in info.value.msg
        assert info.value.offset == 6


class TestPythonParserRevDB(TestPythonParser):
    spaceconfig = {"translation.reverse_debugger": True}

    def test_revdb_dollar_num(self):
        self.parse('$0')
        self.parse('$5')
        self.parse('$42')
        self.parse('2+$42.attrname')
        self.parse("from __future__ import print_function\nx = ($0, print)")
        py.test.raises(SyntaxError, self.parse, '$')
        py.test.raises(SyntaxError, self.parse, '$a')
        py.test.raises(SyntaxError, self.parse, '$.5')


class TestPythonPegParser(TestPythonParser):
    spaceconfig = {}

    def setup_class(self):
        self.parser = pyparse.PegParser(self.space)

    def test_crash_with(self):
        # used to crash
        py.test.raises(SyntaxError, self.parse,
                "async with a:\n    pass", "single",
                flags=consts.PyCF_DONT_IMPLY_DEDENT | consts.PyCF_ALLOW_TOP_LEVEL_AWAIT)

    def test_crash_eval_empty(self):
        # used to crash
        py.test.raises(SyntaxError, self.parse,
                       '', 'eval', flags=consts.PyCF_DONT_IMPLY_DEDENT)


    def test_dont_imply_dedent_ignored_on_exec(self):
        self.parse(
            "if 1: \n pass", "exec",
            flags=consts.PyCF_DONT_IMPLY_DEDENT)
