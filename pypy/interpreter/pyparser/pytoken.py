"""Python token definitions."""

python_tokens = {}
python_opmap = {}
token_names = {}

def _add_tok(name, *values):
    index = len(python_tokens)
    assert index < 256
    python_tokens[name] = index
    token_names[index] = name
    for value in values:
        python_opmap[value] = index

_add_tok('ENDMARKER')
_add_tok('NAME')
_add_tok('NUMBER')
_add_tok('STRING')
_add_tok('NEWLINE')
_add_tok('INDENT')
_add_tok('DEDENT')
_add_tok('LPAR', "(")
_add_tok('RPAR', ")")
_add_tok('LSQB', "[")
_add_tok('RSQB', "]")
_add_tok('COLON', ":")
_add_tok('COMMA',  "," )
_add_tok('SEMI', ";" )
_add_tok('PLUS', "+" )
_add_tok('MINUS', "-" )
_add_tok('STAR', "*" )
_add_tok('SLASH', "/" )
_add_tok('VBAR', "|" )
_add_tok('AMPER', "&" )
_add_tok('LESS', "<" )
_add_tok('GREATER', ">" )
_add_tok('EQUAL', "=" )
_add_tok('DOT', "." )
_add_tok('PERCENT', "%" )
_add_tok('BACKQUOTE', "`" )
_add_tok('LBRACE', "{" )
_add_tok('RBRACE', "}" )
_add_tok('EQEQUAL', "==" )
_add_tok('NOTEQUAL', "!=", "<>" )
_add_tok('LESSEQUAL', "<=" )
_add_tok('GREATEREQUAL', ">=" )
_add_tok('TILDE', "~" )
_add_tok('CIRCUMFLEX', "^" )
_add_tok('LEFTSHIFT', "<<" )
_add_tok('RIGHTSHIFT', ">>" )
_add_tok('DOUBLESTAR', "**" )
_add_tok('PLUSEQUAL', "+=" )
_add_tok('MINEQUAL', "-=" )
_add_tok('STAREQUAL', "*=" )
_add_tok('SLASHEQUAL', "/=" )
_add_tok('PERCENTEQUAL', "%=" )
_add_tok('AMPEREQUAL', "&=" )
_add_tok('VBAREQUAL', "|=" )
_add_tok('CIRCUMFLEXEQUAL', "^=" )
_add_tok('LEFTSHIFTEQUAL', "<<=" )
_add_tok('RIGHTSHIFTEQUAL', ">>=" )
_add_tok('DOUBLESTAREQUAL', "**=" )
_add_tok('DOUBLESLASH', "//" )
_add_tok('DOUBLESLASHEQUAL',"//=" )
_add_tok('AT', "@" )
_add_tok('ATEQUAL', "@=" )
_add_tok('RARROW', "->")
_add_tok('ELLIPSIS', "...")
_add_tok('COLONEQUAL', ':=')
_add_tok('OP')
_add_tok('TYPE_IGNORE')
_add_tok('TYPE_COMMENT')
_add_tok('ASYNC') # unused, just keywords now
_add_tok('AWAIT') # unused, just keywords now
_add_tok('ERRORTOKEN')

# extra PyPy-specific tokens
_add_tok("COMMENT")
_add_tok("NL")
_add_tok("ENCODING")
_add_tok("REVDBMETAVAR", "$NUM")

del _add_tok
