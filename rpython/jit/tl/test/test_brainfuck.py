
from rpython.jit.tl.braininterp import BrainInterpreter

from StringIO import StringIO

def run_code(code, inp):
    inp_s = StringIO(inp)
    out = StringIO()
    b = BrainInterpreter()
    b.interpret(code, inp_s, out)
    return out.getvalue()

def test_braintone():
    assert run_code("+++.","") == chr(3)
    assert run_code("+++>+++.","") == chr(3)
    assert run_code("""++++++++++
[                   The initial loop to set up useful values in the array
   >+++++++>++++++++++>+++>+<<<<-
]
>++.                print 'H'
>+.                 print 'e'
+++++++.                  'l'
.                         'l'
+++.                      'o'
>++.                      space
<<+++++++++++++++.        'W'
>.                        'o'
+++.                      'r'
------.                   'l'
--------.                 'd'
>+.                       '!'
>.                        newline
""", "") == "Hello World!\n"

    code = ",----------[----------------------.,----------]"
    assert run_code(code, "\x0a") == ""
    assert run_code(code, "a\x0a") == "A"
    assert run_code(code, "aa\x0a") == "AA"
    assert run_code(code, "lowercase\x0a") == "LOWERCASE"

    add_code = ",>++++++[<-------->-],[<+>-],<.>."

    assert run_code(add_code, "43 ") == "7 "
    assert run_code(add_code, "12 ") == "3 "

