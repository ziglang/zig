from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rlib.objectmodel import free_non_gc_object, we_are_translated
from rpython.rlib.debug import ll_assert
from rpython.tool.identity_dict import identity_dict
from rpython.rtyper.rclass import NONGCOBJECTPTR
from rpython.rtyper.annlowlevel import cast_nongc_instance_to_base_ptr
from rpython.rtyper.annlowlevel import cast_base_ptr_to_nongc_instance


def mangle_hash(i):
    # To hash pointers in dictionaries.  Assumes that i shows some
    # alignment (to 4, 8, maybe 16 bytes), so we use the following
    # formula to avoid the trailing bits being always 0.
    return i ^ (i >> 4)

# ____________________________________________________________

DEFAULT_CHUNK_SIZE = 1019


def get_chunk_manager(chunk_size=DEFAULT_CHUNK_SIZE, cache={}):
    try:
        return cache[chunk_size]
    except KeyError:
        pass

    CHUNK = lltype.ForwardReference()
    CHUNK.become(lltype.Struct('AddressChunk',
                               ('next', lltype.Ptr(CHUNK)),
                               ('items', lltype.FixedSizeArray(
                                   llmemory.Address, chunk_size))))
    null_chunk = lltype.nullptr(CHUNK)

    class FreeList(object):
        _alloc_flavor_ = "raw"

        def __init__(self):
            self.free_list = null_chunk

        def get(self):
            if not self.free_list:
                # we zero-initialize the chunks to make the translation
                # backends happy, but we don't need to do it at run-time.
                zero = not we_are_translated()
                return lltype.malloc(CHUNK, flavor="raw", zero=zero,
                                     track_allocation=False)
                
            result = self.free_list
            self.free_list = result.next
            return result

        def put(self, chunk):
            if we_are_translated():
                chunk.next = self.free_list
                self.free_list = chunk
            else:
                # Don't cache the old chunks but free them immediately.
                # Helps debugging, and avoids that old chunks full of
                # addresses left behind by a test end up in genc...
                lltype.free(chunk, flavor="raw", track_allocation=False)

    unused_chunks = FreeList()
    cache[chunk_size] = unused_chunks, null_chunk

    def partition(array, left, right):
        last_item = array[right]
        pivot = last_item
        storeindex = left
        for i in range(left, right):
            if array[i] >= pivot:
                array[i], array[storeindex] = array[storeindex], array[i]
                storeindex += 1
        # Move pivot to its final place
        array[storeindex], array[right] = last_item, array[storeindex]
        return storeindex

    def quicksort(array, left, right):
        # sort array[left:right+1] (i.e. bounds included)
        if right > left:
            pivotnewindex = partition(array, left, right)
            quicksort(array, left, pivotnewindex - 1)
            quicksort(array, pivotnewindex + 1, right)

    def sort_chunk(chunk, size):
        quicksort(chunk.items, 0, size - 1)
        
    return unused_chunks, null_chunk, sort_chunk


def get_address_stack(chunk_size=DEFAULT_CHUNK_SIZE, cache={}):
    try:
        return cache[chunk_size]
    except KeyError:
        pass

    unused_chunks, null_chunk, sort_chunk = get_chunk_manager(chunk_size)

    class AddressStack(object):
        _alloc_flavor_ = "raw"
        
        def __init__(self):
            self.chunk = unused_chunks.get()
            self.chunk.next = null_chunk
            self.used_in_last_chunk = 0
            # invariant: self.used_in_last_chunk == 0 if and only if
            # the AddressStack is empty

        def enlarge(self):
            new = unused_chunks.get()
            new.next = self.chunk
            self.chunk = new
            self.used_in_last_chunk = 0
        enlarge._dont_inline_ = True

        def shrink(self):
            old = self.chunk
            self.chunk = old.next
            unused_chunks.put(old)
            self.used_in_last_chunk = chunk_size
        shrink._dont_inline_ = True

        def append(self, addr):
            used = self.used_in_last_chunk
            if used == chunk_size:
                self.enlarge()
                used = 0
            self.chunk.items[used] = addr
            self.used_in_last_chunk = used + 1      # always > 0 here

        def non_empty(self):
            return self.used_in_last_chunk != 0

        def pop(self):
            used = self.used_in_last_chunk - 1
            ll_assert(used >= 0, "pop on empty AddressStack")
            result = self.chunk.items[used]
            self.used_in_last_chunk = used
            if used == 0 and self.chunk.next:
                self.shrink()
            return result

        def delete(self):
            cur = self.chunk
            while cur:
                next = cur.next
                unused_chunks.put(cur)
                cur = next
            free_non_gc_object(self)

        def length(self):
            chunk = self.chunk
            result = 0
            count = self.used_in_last_chunk
            while chunk:
                result += count
                chunk = chunk.next
                count = chunk_size
            return result

        def foreach(self, callback, arg):
            """Invoke 'callback(address, arg)' for all addresses in the stack.
            Typically, 'callback' is a bound method and 'arg' can be None.
            """
            chunk = self.chunk
            count = self.used_in_last_chunk
            while chunk:
                while count > 0:
                    count -= 1
                    callback(chunk.items[count], arg)
                chunk = chunk.next
                count = chunk_size
        foreach._annspecialcase_ = 'specialize:arg(1)'

        def stack2dict(self):
            result = AddressDict(self.length())
            self.foreach(_add_in_dict, result)
            return result

        def tolist(self):
            """NOT_RPYTHON.  Returns the content as a list."""
            lst = []
            def _add(obj, lst):
                lst.append(obj)
            self.foreach(_add, lst)
            return lst

        def remove(self, addr):
            """Remove 'addr' from the stack.  The addr *must* be in the list,
            and preferrably near the top.
            """
            got = self.pop()
            chunk = self.chunk
            count = self.used_in_last_chunk
            while got != addr:
                count -= 1
                if count < 0:
                    chunk = chunk.next
                    count = chunk_size - 1
                next = chunk.items[count]
                chunk.items[count] = got
                got = next

        def sort(self):
            """Sorts the items in the AddressStack.  They must not be more
            than one chunk of them.  This results in a **reverse** order,
            so that the first pop()ped items are the smallest ones."""
            ll_assert(self.chunk.next == null_chunk, "too big for sorting")
            sort_chunk(self.chunk, self.used_in_last_chunk)

    cache[chunk_size] = AddressStack
    return AddressStack

def _add_in_dict(item, d):
    d.add(item)


def get_address_deque(chunk_size=DEFAULT_CHUNK_SIZE, cache={}):
    try:
        return cache[chunk_size]
    except KeyError:
        pass

    unused_chunks, null_chunk = get_chunk_manager(chunk_size)

    class AddressDeque(object):
        _alloc_flavor_ = "raw"
        
        def __init__(self):
            chunk = unused_chunks.get()
            chunk.next = null_chunk
            self.oldest_chunk = self.newest_chunk = chunk
            self.index_in_oldest = 0
            self.index_in_newest = 0

        def enlarge(self):
            new = unused_chunks.get()
            new.next = null_chunk
            self.newest_chunk.next = new
            self.newest_chunk = new
            self.index_in_newest = 0
        enlarge._dont_inline_ = True

        def shrink(self):
            old = self.oldest_chunk
            self.oldest_chunk = old.next
            unused_chunks.put(old)
            self.index_in_oldest = 0
        shrink._dont_inline_ = True

        def append(self, addr):
            index = self.index_in_newest
            if index == chunk_size:
                self.enlarge()
                index = 0
            self.newest_chunk.items[index] = addr
            self.index_in_newest = index + 1

        def non_empty(self):
            return (self.oldest_chunk != self.newest_chunk
                    or self.index_in_oldest < self.index_in_newest)

        def popleft(self):
            ll_assert(self.non_empty(), "pop on empty AddressDeque")
            index = self.index_in_oldest
            if index == chunk_size:
                self.shrink()
                index = 0
            result = self.oldest_chunk.items[index]
            self.index_in_oldest = index + 1
            return result

        def foreach(self, callback, arg, step=1):
            """Invoke 'callback(address, arg)' for all addresses in the deque.
            Typically, 'callback' is a bound method and 'arg' can be None.
            If step > 1, only calls it for addresses multiple of 'step'.
            """
            chunk = self.oldest_chunk
            index = self.index_in_oldest
            while chunk is not self.newest_chunk:
                while index < chunk_size:
                    callback(chunk.items[index], arg)
                    index += step
                chunk = chunk.next
                index -= chunk_size
            limit = self.index_in_newest
            while index < limit:
                callback(chunk.items[index], arg)
                index += step
        foreach._annspecialcase_ = 'specialize:arg(1)'

        def delete(self):
            cur = self.oldest_chunk
            while cur:
                next = cur.next
                unused_chunks.put(cur)
                cur = next
            free_non_gc_object(self)

        def _was_freed(self):
            return False    # otherwise, the __class__ changes

    cache[chunk_size] = AddressDeque
    return AddressDeque

# ____________________________________________________________

def AddressDict(length_estimate=0):
    if we_are_translated():
        from rpython.memory import lldict
        return lldict.newdict(length_estimate)
    else:
        return BasicAddressDict()

def null_address_dict():
    from rpython.memory import lldict
    return lltype.nullptr(lldict.DICT)

class BasicAddressDict(object):

    def __init__(self):
        self.data = identity_dict()      # {_key(addr): value}

    def _key(self, addr):
        "NOT_RPYTHON: prebuilt AddressDicts are not supported"
        return addr._fixup().ptr._obj

    def _wrapkey(self, obj):
        return llmemory.cast_ptr_to_adr(obj._as_ptr())

    def delete(self):
        pass

    def length(self):
        return len(self.data)

    def contains(self, keyaddr):
        return self._key(keyaddr) in self.data

    def get(self, keyaddr, default=llmemory.NULL):
        return self.data.get(self._key(keyaddr), default)

    def setitem(self, keyaddr, valueaddr):
        assert keyaddr
        self.data[self._key(keyaddr)] = valueaddr

    def insertclean(self, keyaddr, valueaddr):
        assert keyaddr
        key = self._key(keyaddr)
        assert key not in self.data
        self.data[key] = valueaddr

    def add(self, keyaddr):
        self.setitem(keyaddr, llmemory.NULL)

    def clear(self):
        self.data.clear()

    def foreach(self, callback, arg):
        """Invoke 'callback(key, value, arg)' for all items in the dict.
        Typically, 'callback' is a bound method and 'arg' can be None."""
        for key, value in self.data.iteritems():
            callback(self._wrapkey(key), value, arg)


def copy_and_update(dict, surviving, updated_address):
    """Make a copy of 'dict' in which the keys are updated as follows:
       * if surviving(key) returns False, the item is removed
       * otherwise, updated_address(key) is inserted in the copy.
    """
    newdict = AddressDict
    if not we_are_translated():
        # when not translated, return a dict of the same kind as 'dict'
        if not isinstance(dict, BasicAddressDict):
            from rpython.memory.lldict import newdict
    result = newdict(dict.length())
    dict.foreach(_get_updater(surviving, updated_address), result)
    return result
copy_and_update._annspecialcase_ = 'specialize:arg(1,2)'

def _get_updater(surviving, updated_address):
    def callback(key, value, arg):
        if surviving(key):
            newkey = updated_address(key)
            arg.setitem(newkey, value)
    return callback
_get_updater._annspecialcase_ = 'specialize:memo'


def copy_without_null_values(dict):
    """Make a copy of 'dict' without the key/value pairs where value==NULL."""
    newdict = AddressDict
    if not we_are_translated():
        # when not translated, return a dict of the same kind as 'dict'
        if not isinstance(dict, BasicAddressDict):
            from rpython.memory.lldict import newdict
    result = newdict()
    dict.foreach(_null_value_checker, result)
    return result

def _null_value_checker(key, value, arg):
    if value:
        arg.setitem(key, value)
