import sys

def f():
    try:
        return f()
    except RuntimeError:
        return sys.exc_info()

def do_check():
    f()
    assert sys.exc_info() == (None, None, None)


def recurse(n):
    if n > 0:
        return recurse(n-1)
    else:
        return do_check()

def test_recursion():
    """
    Test that sys.exc_info() is cleared after RecursionError was raised.

    The issue only appeared intermittently, depending on the contents of the
    call stack, hence the need for the recurse() helper to trigger it reliably.
    """
    for i in range(50):
        recurse(i)
