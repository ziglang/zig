import py, os

class NullPyPathLocal(py.path.local):

    def join(self, *args):
        return self.__class__(py.path.local.join(self, *args))

    def open(self, mode):
        return open(os.devnull, mode)

    def __repr__(self):
        return py.path.local.__repr__(self) + ' [fake]'
