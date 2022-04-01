from .thread import _signals_enter, _signals_exit
# ^^ relative import of __pypy__.thread.  Note that some tests depend on
# this (test_enable_signals in test_signal.py) to work properly,
# otherwise they get caught in some deadlock waiting for the import
# lock...


class SignalsEnabled(object):
    '''A context manager to use in non-main threads:
enables receiving signals in a "with" statement.  More precisely, if a
signal is received by the process, then the signal handler might be
called either in the main thread (as usual) or within another thread
that is within a "with signals_enabled:".  This other thread should be
ready to handle unexpected exceptions that the signal handler might
raise --- notably KeyboardInterrupt.'''
    __enter__ = _signals_enter
    __exit__  = _signals_exit

signals_enabled = SignalsEnabled()
