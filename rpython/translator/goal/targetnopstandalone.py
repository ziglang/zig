"""
A simple standalone target.

The target below specifies None as the argument types list.
This is a case treated specially in driver.py . If the list
of input types is empty, it is meant to be a list of strings,
actually implementing argv of the executable.
"""

def debug(msg):
    print "debug:", msg

# __________  Entry point  __________

def entry_point(argv):
    debug("hello world")
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point
