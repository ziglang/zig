import os
from pypy.interpreter.pyparser import parser, pytoken, metaparser

class PythonGrammar(parser.Grammar):

    KEYWORD_TOKEN = pytoken.python_tokens["NAME"]
    TOKENS = pytoken.python_tokens
    OPERATOR_MAP = pytoken.python_opmap

def _get_python_grammar():
    here = os.path.dirname(__file__)
    fp = open(os.path.join(here, "data", "Grammar3.9"))
    try:
        gram_source = fp.read()
    finally:
        fp.close()
    pgen = metaparser.ParserGenerator(gram_source)
    return pgen.build_grammar(PythonGrammar)


python_grammar = _get_python_grammar()

python_grammar_revdb = python_grammar.shared_copy()
copied_token_ids = python_grammar.token_ids.copy()
python_grammar_revdb.token_ids = copied_token_ids

metavar_token_id = pytoken.python_tokens['REVDBMETAVAR']
del python_grammar.token_ids[metavar_token_id]

class _Tokens(object):
    pass
for tok_name, idx in pytoken.python_tokens.iteritems():
    setattr(_Tokens, tok_name, idx)
tokens = _Tokens()

class _Symbols(object):
    pass
rev_lookup = {}
for sym_name, idx in python_grammar.symbol_ids.iteritems():
    setattr(_Symbols, sym_name, idx)
    rev_lookup[idx] = sym_name
syms = _Symbols()
syms._rev_lookup = rev_lookup # for debugging

del _get_python_grammar, _Tokens, tok_name, sym_name, idx

def choose_grammar(print_function, revdb):
    assert print_function
    if revdb:
        return python_grammar_revdb
    else:
        return python_grammar

