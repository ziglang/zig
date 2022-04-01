import weakref
from rpython.rlib.rweakref import dead_ref

INITIAL_SIZE = 4


class RWeakListMixin(object):
    """A mixin base class.  A collection that weakly maps indexes to objects.
    After an object goes away, its index is marked free and will be reused
    by some following add_handle() call.  So add_handle() might not append
    the object at the end of the list, but can put it anywhere.

    See also rpython.rlib.rshrinklist.
    """
    _mixin_ = True

    def initialize(self):
        self.handles = [dead_ref] * INITIAL_SIZE
        self.free_list = range(INITIAL_SIZE)

    def get_all_handles(self):
        return self.handles

    def reserve_next_handle_index(self):
        # (this algorithm should be amortized constant-time)
        # get the next 'free_list' entry, if any
        free_list = self.free_list
        try:
            return free_list.pop()
        except IndexError:
            pass
        # slow path: collect all now-free handles in 'free_list'
        handles = self.handles
        for i in range(len(handles)):
            if handles[i]() is None:
                free_list.append(i)
        # double the size of the self.handles list, but don't do that
        # if there are more than 66% of handles free already
        if len(free_list) * 3 < len(handles) * 2:
            free_list.extend(range(len(handles), len(handles) * 2))
            # don't use '+=' on 'self.handles'
            self.handles = handles = handles + [dead_ref] * len(handles)
        #
        return free_list.pop()

    def add_handle(self, content):
        index = self.reserve_next_handle_index()
        self.store_handle(index, content)
        return index

    def store_handle(self, index, content):
        self.handles[index] = weakref.ref(content)

    def fetch_handle(self, index):
        if 0 <= index < len(self.handles):
            return self.handles[index]()
        return None
