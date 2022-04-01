# This is a dummy module imported for platforms where the built-in
# faulthandler module is not available.

def enable(*args, **kwargs):
    pass

def disable(*args, **kwargs):
    pass

def is_enabled(*args, **kwargs):
    return False

def register(*args, **kwargs):
    pass

def cancel_dump_traceback_later(*args, **kwargs):
    pass

def unregister(*args, **kwargs):
    pass

try:
    import _thread
except ImportError:
    pass
else:
    # need the _thread module
    def dump_traceback_later(*args, **kwargs):
        pass

