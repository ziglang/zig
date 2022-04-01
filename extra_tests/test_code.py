import sys
from io import StringIO
import code


def test_flush_stdout_on_error():
    runner = code.InteractiveInterpreter()
    old_stdout = sys.stdout
    try:
        mystdout = StringIO()
        sys.stdout = mystdout
        runner.runcode(compile("print(5);0/0", "<interactive>", "exec"))
    finally:
        sys.stdout = old_stdout

    assert mystdout.getvalue() == "5\n"
