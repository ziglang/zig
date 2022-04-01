
def f(a,b):
    return a+b

def g():
    raise ValueError("booh")

class FancyException(Exception):
    pass

def h():
    raise FancyException("booh")

def bomb():
    raise KeyboardInterrupt
