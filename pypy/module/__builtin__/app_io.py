# NOT_RPYTHON (but maybe soon)
"""
Plain Python definition of the builtin I/O-related functions.
"""

import sys

def _write_prompt(stdout, prompt):
    print(prompt, file=stdout, end='')
    try:
        flush = stdout.flush
    except AttributeError:
        pass
    else:
        flush()

def _is_std_tty(stdin, stdout):
    try:
        infileno, outfileno = stdin.fileno(), stdout.fileno()
    except:
        return False
    return infileno == 0 and stdin.isatty() and outfileno == 1

def input(prompt=''):
    """input([prompt]) -> string

Read a string from standard input.  The trailing newline is stripped.
If the user hits EOF (Unix: Ctl-D, Windows: Ctl-Z+Return), raise EOFError.
On Unix, GNU readline is used if enabled.  The prompt string, if given,
is printed without a trailing newline before reading."""

    sys.audit("builtins.input", prompt)
    try:
        stdin = sys.stdin
    except AttributeError:
        raise RuntimeError("input: lost sys.stdin")
    try:
        stdout = sys.stdout
    except AttributeError:
        raise RuntimeError("input: lost sys.stdout")
    try:
        stderr = sys.stderr
    except AttributeError:
        raise RuntimeError("input: lost sys.stderr")

    stderr.flush()

    # hook for the readline module
    if hasattr(sys, '__raw_input__') and _is_std_tty(stdin, stdout):
        _write_prompt(stdout, '')
        res = sys.__raw_input__(str(prompt))
        sys.audit("builtins.input/result", res)
        return res

    _write_prompt(stdout, prompt)
    line = stdin.readline()
    if not line:    # inputting an empty line gives line == '\n'
        raise EOFError
    if line[-1] == '\n':
        res = line[:-1]
    else:
        res = line
    sys.audit("builtins.input/result", res)
    return res

def print_(*args, sep=' ', end='\n', file=None, flush=False):
    r"""print(value, ..., sep=' ', end='\n', file=sys.stdout, flush=False)

    Prints the values to a stream, or to sys.stdout by default.
    Optional keyword arguments:
    file:  a file-like object (stream); defaults to the current sys.stdout.
    sep:   string inserted between values, default a space.
    end:   string appended after the last value, default a newline.
    flush: whether to forcibly flush the stream.
    """
    fp = file
    if fp is None:
        fp = sys.stdout
        if fp is None:
            return
    if sep is None:
        sep = ' '
    if not isinstance(sep, str):
        raise TypeError("sep must be None or a string")
    if end is None:
        end = '\n'
    if not isinstance(end, str):
        raise TypeError("end must be None or a string")
    for i, arg in enumerate(args):
        if i:
            fp.write(sep)
        fp.write(str(arg))
    fp.write(end)
    if flush:
        fp.flush()
