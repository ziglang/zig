"""
Plain Python definition of the builtin functions oriented towards
functional programming.
"""

# ____________________________________________________________
def sorted(iterable, /, *, key=None, reverse=False):
    "sorted(iterable, key=None, reverse=False) --> new sorted list"
    sorted_lst = list(iterable)
    sorted_lst.sort(key=key, reverse=reverse)
    return sorted_lst

def any(seq):
    """any(iterable) -> bool

Return True if bool(x) is True for any x in the iterable."""
    for x in seq:
        if x:
            return True
    return False

def all(seq):
    """all(iterable) -> bool

Return True if bool(x) is True for all values x in the iterable."""
    for x in seq:
        if not x:
            return False
    return True

def sum(sequence, start=0):
    """sum(sequence[, start]) -> value

Returns the sum of a sequence of numbers (NOT strings) plus the value
of parameter 'start' (which defaults to 0).  When the sequence is
empty, returns start."""
    if isinstance(start, str):
        raise TypeError("sum() can't sum strings [use ''.join(seq) instead]")
    if isinstance(start, bytes):
        raise TypeError("sum() can't sum bytes [use b''.join(seq) instead]")
    if isinstance(start, bytearray):
        raise TypeError("sum() can't sum bytearray [use b''.join(seq) instead]")

    # Avoiding isinstance here, since subclasses can override `+`
    if type(start) is list:
        return _list_sum(sequence, start)

    if type(start) is tuple:
        return _tuple_sum(sequence, start)

    return _regular_sum(sequence, start)


def _regular_sum(sequence, start):
    # Default implementation for sum (no specialization)
    last = start
    for x in sequence:
        # Very intentionally *not* +=, that would have different semantics if
        # start was a mutable type, such as a list
        last = last + x
    return last


def _list_sum(sequence, start):
    # Specialization avoiding quadratic complexity for lists
    iterator = iter(sequence)

    try:
        first = next(iterator)
    except StopIteration:
        return start

    if type(first) is not list:
        return _regular_sum(iterator, start + first)

    last = start + first
    for item in iterator:
        if type(item) is list:
            last += item
        else:
            # Non-trivial sum. Use _regular_sum.
            return _regular_sum(iterator, last + item)

    return last


def _tuple_sum(sequence, start):
    # Specialization avoiding quadratic complexity for tuples
    iterator = iter(sequence)

    try:
        first = next(iterator)
    except StopIteration:
        return start

    if type(first) is not tuple:
        return _regular_sum(iterator, start + first)

    last = list(start)
    last.extend(first)
    for item in iterator:
        if type(item) is tuple:
            last.extend(item)
        else:
            # Non-trivial sum. Cast back to tuple and use regular_sum.
            return _regular_sum(iterator, tuple(last) + item)

    return tuple(last)

def filter(func, seq):
    """filter(function or None, sequence) -> list, tuple, or string

Return those items of sequence for which function(item) is true.  If
function is None, return the items that are true.  If sequence is a tuple
or string, return the same type, else return a list."""
    if func is None:
        func = bool
    return _filter(func, iter(seq))

def _filter(func, iterator):
    for item in iterator:
        if func(item):
            yield item
