
from rpython.rlib.parsing.ebnfparse import parse_ebnf, make_parse_function
from rpython.rlib.parsing.parsing import ParseError, Rule
import py

def make_parser_from_file(filename):
    try:
        t = py.path.local(filename).read(mode='U')
        regexs, rules, ToAST = parse_ebnf(t)
    except ParseError as e:
        print e.nice_error_message(filename=filename, source=t)
        raise
    return make_parse_function(regexs, rules, eof=True)
