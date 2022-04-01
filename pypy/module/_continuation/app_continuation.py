
class error(Exception):
    "Usage error of the _continuation module."


import _continuation


class generator(object):

    def __init__(self, callable):
        self.__func__ = callable

    def __get__(self, obj, type=None):
        return generator(self.__func__.__get__(obj, type))

    def __call__(self, *args, **kwds):
        return genlet(self.__func__, *args, **kwds)


class genlet(_continuation.continulet):

    def __iter__(self):
        return self

    def __next__(self, value=None):
        res = self.switch(value)
        if self.is_pending():
            return res
        else:
            if res is not None:
                raise TypeError("_continuation.generator must return None")
            raise StopIteration

    send = next
