from rpython.tool.sourcetools import func_with_new_name

def forbid(*args):
    raise TypeError("cannot mutate a frozenlist")

class frozenlist(list):
    __setitem__  = func_with_new_name(forbid, '__setitem__')
    __delitem__  = func_with_new_name(forbid, '__delitem__')
    __setslice__ = func_with_new_name(forbid, '__setslice__')
    __delslice__ = func_with_new_name(forbid, '__delslice__')
    __iadd__     = func_with_new_name(forbid, '__iadd__')
    __imul__     = func_with_new_name(forbid, '__imul__')
    append       = func_with_new_name(forbid, 'append')
    insert       = func_with_new_name(forbid, 'insert')
    pop          = func_with_new_name(forbid, 'pop')
    remove       = func_with_new_name(forbid, 'remove')
    reverse      = func_with_new_name(forbid, 'reverse')
    sort         = func_with_new_name(forbid, 'sort')
    extend       = func_with_new_name(forbid, 'extend')
