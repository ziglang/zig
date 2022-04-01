from .methodobject import W_PyCFunctionObject

def is_cpyext_function(space, w_arg):
    return space.newbool(isinstance(w_arg, W_PyCFunctionObject))
