
def signals_enter(space):
    space.threadlocals.enable_signals(space)

def signals_exit(space, w_ignored1=None, w_ignored2=None, w_ignored3=None):
    space.threadlocals.disable_signals(space)
