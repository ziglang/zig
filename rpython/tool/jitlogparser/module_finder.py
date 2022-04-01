
import os, sys, marshal, types, struct, imp

def _all_codes_from(code):
    res = {}
    more = [code]
    while more:
        next = more.pop()
        res[(next.co_firstlineno, next.co_name)] = next
        more += [co for co in next.co_consts
                 if isinstance(co, types.CodeType)]
    return res

def gather_all_code_objs(fname):
    """ Gathers all code objects from a give fname and sorts them by
    starting lineno
    """
    fname = str(fname)
    if fname.endswith('.pyc'):
        code = compile(open(fname[:-1]).read(), fname, 'exec')
    elif fname.endswith('.py'):
        code = compile(open(fname).read(), fname, 'exec')
    else:
        raise Exception("Unknown file extension: %s" % fname)
    return _all_codes_from(code)
