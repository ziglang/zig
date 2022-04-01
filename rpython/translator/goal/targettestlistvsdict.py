"""
A simple standalone target.

The target below specifies None as the argument types list.
This is a case treated specially in driver.py . If the list
of input types is empty, it is meant to be a list of strings,
actually implementing argv of the executable.
"""

import os, sys

def debug(msg): 
    os.write(2, "debug: " + msg + '\n')

# __________  Entry point  __________

numbers = range(1000, 5000)
test_list = map(str, numbers)
test_dict = dict(map(lambda x: (x, str(x)), numbers))

def entry_point(argv):
    if argv[1] == 'd':
        print test_dict[int(argv[2])]
    else:
        print test_list[int(argv[2])]
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None
