"""
A simple deeply recursive target. 

The target below specifies None as the argument types list.
This is a case treated specially in driver.py . If the list
of input types is empty, it is meant to be a list of strings,
actually implementing argv of the executable.
"""

import os, sys

def debug(msg): 
    os.write(2, "debug: " + msg + '\n')

# __________  Entry point  __________

def ackermann(x, y):
    if x == 0:
        return y + 1
    if y == 0:
        return ackermann(x - 1, 1)
    return ackermann(x - 1, ackermann(x, y - 1))

def entry_point(argv):
    debug(str(ackermann(3, 12)) + "\n")
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None
