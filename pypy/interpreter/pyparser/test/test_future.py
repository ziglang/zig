import py
from pypy.interpreter.pyparser import future, pytokenizer
from pypy.tool import stdlib___future__ as fut

def run(s, expected_last_future=(0, 0)):
    source_lines = s.splitlines(True)
    tokens = pytokenizer.generate_tokens(source_lines, 0)
    #
    flags, last_future_import = future.add_future_flags(
        future.futureFlags_3_5, tokens)
    assert last_future_import == expected_last_future
    return flags

def test_docstring():
    s = '"Docstring\\" "\nfrom  __future__ import division\n'
    f = run(s, (2, 24))
    assert f == 0

def test_comment():
    s = '# A comment about nothing ;\n'
    f = run(s)
    assert f == 0

def test_tripledocstring():
    s = '''""" This is a
docstring with line
breaks in it. It even has a \n"""
'''
    f = run(s)
    assert f == 0

def test_escapedquote_in_tripledocstring():
    s = '''""" This is a
docstring with line
breaks in it. \\"""It even has an escaped quote!"""
'''
    f = run(s)
    assert f == 0

def test_empty_line():
    s = ' \t   \f \n   \n'
    f = run(s)
    assert f == 0

def test_from():
    s = 'from  __future__ import division\n'
    f = run(s, (1, 24))
    assert f == 0

def test_froms():
    s = 'from  __future__ import division, generators, with_statement\n'
    f = run(s, (1, 24))
    assert f == 0

def test_from_as():
    s = 'from  __future__ import division as b\n'
    f = run(s, (1, 24))
    assert f == 0

def test_froms_as():
    s = 'from  __future__ import division as b, generators as c\n'
    f = run(s, (1, 24))
    assert f == 0

def test_from_paren():
    s = 'from  __future__ import (division)\n'
    f = run(s, (1, 25))
    assert f == 0

def test_froms_paren():
    s = 'from  __future__ import (division, generators)\n'
    f = run(s, (1, 25))
    assert f == 0

def test_froms_paren_as():
    s = 'from  __future__ import (division as b, generators,)\n'
    f = run(s, (1, 25))
    assert f == 0

def test_paren_with_newline():
    s = 'from __future__ import (division,\nabsolute_import)\n'
    f = run(s, (1, 24))
    assert f == 0

def test_paren_with_newline_2():
    s = 'from __future__ import (\ndivision,\nabsolute_import)\n'
    f = run(s, (2, 0))
    assert f == 0

def test_multiline():
    s = '"abc" #def\n  #ghi\nfrom  __future__ import (division as b, generators,)\nfrom __future__ import with_statement\n'
    f = run(s, (4, 23))
    assert f == 0

def test_windows_style_lineendings():
    s = '"abc" #def\r\n  #ghi\r\nfrom  __future__ import (division as b, generators,)\r\nfrom __future__ import with_statement\r\n'
    f = run(s, (4, 23))
    assert f == 0

def test_mac_style_lineendings():
    s = '"abc" #def\r  #ghi\rfrom  __future__ import (division as b, generators,)\rfrom __future__ import with_statement\r'
    f = run(s, (4, 23))
    assert f == 0

def test_semicolon():
    s = '"abc" #def\n  #ghi\nfrom  __future__ import (division as b, generators,);  from __future__ import with_statement\n'
    f = run(s, (3, 78))
    assert f == 0

def test_semicolon_2():
    s = 'from  __future__ import division; from foo import bar'
    f = run(s, expected_last_future=(1, 24))
    assert f == 0

def test_full_chain():
    s = '"abc" #def\n  #ghi\nfrom  __future__ import (division as b, generators,);  from __future__ import with_statement\n'
    f = run(s, (3, 78))
    assert f == 0

def test_intervening_code():
    s = 'from  __future__ import (division as b, generators,)\nfrom sys import modules\nfrom __future__ import with_statement\n'
    f = run(s, expected_last_future=(1, 25))
    assert f == 0

def test_nonexisting():
    s = 'from  __future__ import non_existing_feature\n'
    f = run(s, (1, 24))
    assert f == 0

def test_nonexisting_2():
    s = 'from  __future__ import non_existing_feature, with_statement\n'
    f = run(s, (1, 24))
    assert f == 0

def test_from_import_abs_import():
    s = 'from  __future__ import absolute_import\n'
    f = run(s, (1, 24))
    assert f == 0

def test_raw_doc():
    s = 'r"Doc"\nfrom __future__ import with_statement\n'
    f = run(s, (2, 23))
    assert f == 0

def test_unicode_doc():
    s = 'u"Doc"\nfrom __future__ import with_statement\n'
    f = run(s, (2, 23))
    assert f == 0

def test_raw_unicode_doc():
    s = 'ru"Doc"\nfrom __future__ import with_statement\n'
    f = run(s, (2, 23))
    assert f == 0

def test_continuation_line():
    s = "\\\nfrom __future__ import with_statement\n"
    f = run(s, (2, 23))
    assert f == 0

def test_continuation_lines():
    s = "\\\n  \t\\\nfrom __future__ import with_statement\n"
    f = run(s, (3, 23))
    assert f == 0

def test_lots_of_continuation_lines():
    s = "\\\n\\\n\\\n\\\n\\\n\\\n\nfrom __future__ import with_statement\n"
    f = run(s, (8, 23))
    assert f == 0

def test_continuation_lines_in_docstring_single_quoted():
    s = '"\\\n\\\n\\\n\\\n\\\n\\\n"\nfrom  __future__ import division\n'
    f = run(s, (8, 24))
    assert f == 0

def test_continuation_lines_in_docstring_triple_quoted():
    s = '"""\\\n\\\n\\\n\\\n\\\n\\\n"""\nfrom  __future__ import division\n'
    f = run(s, (8, 24))
    assert f == 0

def test_blank_lines():
    s = ('\n\t\n\nfrom __future__ import with_statement'
         '  \n  \n  \nfrom __future__ import division')
    f = run(s, (7, 23))
    assert f == 0

def test_dummy_semicolons():
    s = ('from __future__ import division;\n'
         'from __future__ import with_statement;')
    f = run(s, (2, 23))
    assert f == 0
