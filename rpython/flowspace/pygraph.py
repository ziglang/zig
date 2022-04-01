"""
Implements flow graphs for Python callables
"""
from rpython.flowspace.model import FunctionGraph, Constant, Variable
from rpython.flowspace.framestate import FrameState

class PyGraph(FunctionGraph):
    """
    Flow graph for a Python function
    """

    def __init__(self, func, code):
        from rpython.flowspace.flowcontext import SpamBlock
        locals = [None] * code.co_nlocals
        for i in range(code.formalargcount):
            locals[i] = Variable(code.co_varnames[i])
        state = FrameState(locals, [], None, [], 0)
        initialblock = SpamBlock(state)
        super(PyGraph, self).__init__(self._sanitize_funcname(func), initialblock)
        self.func = func
        self.signature = code.signature
        self.defaults = func.__defaults__ or ()

    @staticmethod
    def _sanitize_funcname(func):
        # CallableFactory.pycall may add class_ to functions that are methods
        name = func.__name__
        class_ = getattr(func, 'class_', None)
        if class_ is not None:
            name = '%s.%s' % (class_.__name__, name)
        for c in "<>&!":
            name = name.replace(c, '_')
        return name
