"""
PyPy-oriented interface to pdb.
"""

import pdb

def fire(operationerr):
    if not operationerr.debug_excs:
        return
    exc, val, tb = operationerr.debug_excs[-1]
    pdb.post_mortem(tb)
