# ______________________________________________________________________
"""Module pytokenize

This is a modified version of Ka-Ping Yee's tokenize module found in the
Python standard library.

The primary modification is the removal of the tokenizer's dependence on the
standard Python regular expression module, which is written in C.  The regular
expressions have been replaced with hand built DFA's using the
basil.util.automata module.

"""
# ______________________________________________________________________

from pypy.interpreter.pyparser import automata
from pypy.interpreter.pyparser.dfa_generated import *

__all__ = [ "tokenize" ]

endDFAs = {"'" : singleDFA,
           '"' : doubleDFA,
           'r' : None,
           'R' : None,
           "u" : None,
           "U" : None,
           'f' : None,
           'F' : None,
           'b' : None,
           'B' : None}

for uniPrefix in ("", "b", "B", "f", "F"):
    for rawPrefix in ("", "r", "R"):
        prefix_1 = uniPrefix + rawPrefix
        prefix_2 = rawPrefix + uniPrefix

        endDFAs[prefix_1 + "'''"] = single3DFA
        endDFAs[prefix_1 + '"""'] = double3DFA
        endDFAs[prefix_2 + "'''"] = single3DFA
        endDFAs[prefix_2 + '"""'] = double3DFA

for uniPrefix in ("u", "U"):
    endDFAs[uniPrefix + "'''"] = single3DFA
    endDFAs[uniPrefix + '"""'] = double3DFA

whiteSpaceStatesAccepts = [True]
whiteSpaceStates = [{'\t': 0, ' ': 0, '\x0c': 0}]
whiteSpaceDFA = automata.DFA(whiteSpaceStates, whiteSpaceStatesAccepts)

# ______________________________________________________________________
# COPIED:

triple_quoted = {}
for t in ("'''", '"""',
          "r'''", 'r"""', "R'''", 'R"""',
          "u'''", 'u"""', "U'''", 'U"""',
          "f'''", 'f"""', "F'''", 'F"""',
          "fr'''", 'fr"""', "Fr'''", 'Fr"""',
          "fR'''", 'fR"""', "FR'''", 'FR"""',
          "rf'''", 'rf"""', "rF'''", 'rF"""',
          "Rf'''", 'Rf"""', "RF'''", 'RF"""',
          "b'''", 'b"""', "B'''", 'B"""',
          "br'''", 'br"""', "Br'''", 'Br"""',
          "bR'''", 'bR"""', "BR'''", 'BR"""',
          "rb'''", 'rb"""', "rB'''", 'rB"""',
          "Rb'''", 'Rb"""', "RB'''", 'RB"""'):
    triple_quoted[t] = t
single_quoted = {}
for t in ("'", '"',
          "r'", 'r"', "R'", 'R"',
          "u'", 'u"', "U'", 'U"',
          "f'", 'f"', "F'", 'F"',
          "fr'", 'fr"', "Fr'", 'Fr"',
          "fR'", 'fR"', "FR'", 'FR"',
          "rf'", 'rf"', "rF'", 'rF"',
          "Rf'", 'Rf"', "RF'", 'RF"',
          "b'", 'b"', "B'", 'B"',
          "br'", 'br"', "Br'", 'Br"',
          "bR'", 'bR"', "BR'", 'BR"',
          "rb'", 'rb"', "rB'", 'rB"',
          "Rb'", 'Rb"', "RB'", 'RB"'):

    single_quoted[t] = t

tabsize = 8
alttabsize = 1
