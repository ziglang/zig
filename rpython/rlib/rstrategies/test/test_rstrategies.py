
import py
from rpython.rlib.rstrategies import rstrategies as rs
from rpython.rlib.objectmodel import import_from_mixin

# === Define small model tree

class W_AbstractObject(object):
    pass

class W_Object(W_AbstractObject):
    pass

class W_Integer(W_AbstractObject):
    def __init__(self, value):
        self.value = value
    def __eq__(self, other):
        return isinstance(other, W_Integer) and self.value == other.value

class W_List(W_AbstractObject):
    rs.make_accessors()
    def __init__(self, strategy=None, size=0, elements=None):
        self.strategy = None
        if strategy:
            factory.set_initial_strategy(self, strategy, size, elements)
    def fetch(self, i):
        assert self.strategy
        return self.strategy.fetch(self, i)
    def store(self, i, value):
        assert self.strategy
        return self.strategy.store(self, i, value)
    def size(self):
        assert self.strategy
        return self.strategy.size(self)
    def insert(self, index0, list_w):
        assert self.strategy
        return self.strategy.insert(self, index0, list_w)
    def delete(self, start, end):
        assert self.strategy
        return self.strategy.delete(self, start, end)
    def append(self, list_w):
        assert self.strategy
        return self.strategy.append(self, list_w)
    def pop(self, index0):
        assert self.strategy
        return self.strategy.pop(self, index0)
    def slice(self, start, end):
        assert self.strategy
        return self.strategy.slice(self, start, end)
    def fetch_all(self):
        assert self.strategy
        return self.strategy.fetch_all(self)
    def store_all(self, elements):
        assert self.strategy
        return self.strategy.store_all(self, elements)

w_nil = W_Object()

# === Define concrete strategy classes

class AbstractStrategy(object):
    __metaclass__ = rs.StrategyMetaclass
    import_from_mixin(rs.AbstractStrategy)
    import_from_mixin(rs.SafeIndexingMixin)
    def __init__(self, factory, w_self=None, size=0):
        self.factory = factory
    def strategy_factory(self):
        return self.factory

class Factory(rs.StrategyFactory):
    switching_log = []

    def __init__(self, root_class):
        self.decorate_strategies({
            EmptyStrategy: [NilStrategy, IntegerStrategy, IntegerOrNilStrategy, GenericStrategy],
            NilStrategy: [IntegerOrNilStrategy, GenericStrategy],
            GenericStrategy: [],
            IntegerStrategy: [IntegerOrNilStrategy, GenericStrategy],
            IntegerOrNilStrategy: [GenericStrategy],
        })
        rs.StrategyFactory.__init__(self, root_class)

    def instantiate_strategy(self, strategy_type, w_self=None, size=0):
        return strategy_type(self, w_self, size)

    def set_strategy(self, w_list, strategy):
        old_strategy = self.get_strategy(w_list)
        self.switching_log.append((old_strategy, strategy))
        super(Factory, self).set_strategy(w_list, strategy)

    def clear_log(self):
        del self.switching_log[:]

class EmptyStrategy(AbstractStrategy):
    import_from_mixin(rs.EmptyStrategy)
    # TODO - implement and test transition from Generic back to Empty

class NilStrategy(AbstractStrategy):
    import_from_mixin(rs.SingleValueStrategy)
    def value(self): return w_nil

class GenericStrategy(AbstractStrategy):
    import_from_mixin(rs.GenericStrategy)
    import_from_mixin(rs.UnsafeIndexingMixin)
    def default_value(self): return w_nil

class WeakGenericStrategy(AbstractStrategy):
    import_from_mixin(rs.WeakGenericStrategy)
    def default_value(self): return w_nil

class IntegerStrategy(AbstractStrategy):
    import_from_mixin(rs.SingleTypeStrategy)
    contained_type = W_Integer
    def wrap(self, value): return W_Integer(value)
    def unwrap(self, value): return value.value
    def default_value(self): return W_Integer(0)

class IntegerOrNilStrategy(AbstractStrategy):
    import_from_mixin(rs.TaggingStrategy)
    contained_type = W_Integer
    def wrap(self, value): return W_Integer(value)
    def unwrap(self, value): return value.value
    def default_value(self): return w_nil
    def wrapped_tagged_value(self): return w_nil
    def unwrapped_tagged_value(self): import sys; return sys.maxint

@rs.strategy(generalize=[], singleton=False)
class NonSingletonStrategy(GenericStrategy):
    def __init__(self, factory, w_list=None, size=0):
        super(NonSingletonStrategy, self).__init__(factory, w_list, size)
        self.w_list = w_list
        self.the_size = size

class NonStrategy(NonSingletonStrategy):
    pass

@rs.strategy(generalize=[])
class InefficientStrategy(GenericStrategy):
    def _convert_storage_from(self, w_self, previous_strategy):
        return AbstractStrategy._convert_storage_from(self, w_self, previous_strategy)

factory = Factory(AbstractStrategy)

def check_contents(list, expected):
    assert list.size() == len(expected)
    for i, val in enumerate(expected):
        assert list.fetch(i) == val

def teardown():
    factory.clear_log()

# === Test Initialization and fetch

def test_setup():
    pass

def test_factory_setup():
    expected_strategies = 7
    assert len(factory.strategies) == expected_strategies
    assert len(set(factory.strategies)) == len(factory.strategies)
    for strategy in factory.strategies:
        assert isinstance(factory.strategy_singleton_instance(strategy), strategy)

def test_factory_setup_singleton_instances():
    new_factory = Factory(AbstractStrategy)
    s1 = factory.strategy_singleton_instance(GenericStrategy)
    s2 = new_factory.strategy_singleton_instance(GenericStrategy)
    assert s1 is not s2
    assert s1.strategy_factory() is factory
    assert s2.strategy_factory() is new_factory

def test_metaclass():
    assert NonStrategy._is_strategy == False
    assert IntegerOrNilStrategy._is_strategy == True
    assert IntegerOrNilStrategy._is_singleton == True
    assert NonSingletonStrategy._is_singleton == False
    assert NonStrategy._is_singleton == False
    assert NonStrategy.get_storage is not NonSingletonStrategy.get_storage

def test_singletons():
    def do_test_singletons(cls, expected_true):
        l1 = W_List(cls, 0)
        l2 = W_List(cls, 0)
        if expected_true:
            assert l1.strategy is l2.strategy
        else:
            assert l1.strategy is not l2.strategy
    do_test_singletons(EmptyStrategy, True)
    do_test_singletons(NonSingletonStrategy, False)
    do_test_singletons(NonStrategy, False)
    do_test_singletons(GenericStrategy, True)

def do_test_initialization(cls, default_value=w_nil, is_safe=True):
    size = 10
    l = W_List(cls, size)
    s = l.strategy
    assert s.size(l) == size
    assert s.fetch(l,0) == default_value
    assert s.fetch(l,size/2) == default_value
    assert s.fetch(l,size-1) == default_value
    py.test.raises(IndexError, s.fetch, l, size)
    py.test.raises(IndexError, s.fetch, l, size+1)
    py.test.raises(IndexError, s.fetch, l, size+5)
    if is_safe:
        py.test.raises(IndexError, s.fetch, l, -1)
    else:
        py.test.raises(AssertionError, s.fetch, l, -1)

def test_init_Empty():
    l = W_List(EmptyStrategy, 0)
    s = l.strategy
    assert s.size(l) == 0
    py.test.raises(IndexError, s.fetch, l, 0)
    py.test.raises(IndexError, s.fetch, l, 10)
    py.test.raises(IndexError, s.delete, l, 0, 1)
    py.test.raises(AssertionError, W_List, EmptyStrategy, 2) # Only size 0 possible.

def test_init_Nil():
    do_test_initialization(NilStrategy)

def test_init_Generic():
    do_test_initialization(GenericStrategy, is_safe=False)

def test_init_WeakGeneric():
    do_test_initialization(WeakGenericStrategy)

def test_init_Integer():
    do_test_initialization(IntegerStrategy, default_value=W_Integer(0))

def test_init_IntegerOrNil():
    do_test_initialization(IntegerOrNilStrategy)

# === Test Simple store

def do_test_store(cls, stored_value=W_Object(), is_safe=True, is_varsize=False):
    size = 10
    l = W_List(cls, size)
    s = l.strategy
    def store_test(index):
        s.store(l, index, stored_value)
        assert s.fetch(l, index) == stored_value
    store_test(0)
    store_test(size/2)
    store_test(size-1)
    if not is_varsize:
        py.test.raises(IndexError, s.store, l, size, stored_value)
        py.test.raises(IndexError, s.store, l, size+1, stored_value)
        py.test.raises(IndexError, s.store, l, size+5, stored_value)
    if is_safe:
        py.test.raises(IndexError, s.store, l, -1, stored_value)
    else:
        py.test.raises(AssertionError, s.store, l, -1, stored_value)

def test_store_Nil():
    do_test_store(NilStrategy, stored_value=w_nil)

def test_store_Generic():
    do_test_store(GenericStrategy, is_safe=False)

def test_store_WeakGeneric():
    do_test_store(WeakGenericStrategy, stored_value=w_nil)

def test_store_Integer():
    do_test_store(IntegerStrategy, stored_value=W_Integer(100))

def test_store_IntegerOrNil():
    do_test_store(IntegerOrNilStrategy, stored_value=W_Integer(100))
    do_test_store(IntegerOrNilStrategy, stored_value=w_nil)

# === Test Insert

def do_test_insert(cls, values):
    l = W_List(cls, 0)
    assert len(values) >= 6
    values0 = values[0:1]
    values1 = values[1:2]
    values2 = values[2:4]
    values3 = values[4:6]
    l.insert(3, values0) # Will still be inserted at the very beginning
    check_contents(l, values0)
    l.insert(1, values1+values3)
    check_contents(l, values0+values1+values3)
    l.insert(2, values2)
    check_contents(l, values)
    return l

def test_insert_Nil():
    do_test_insert(NilStrategy, [w_nil]*6)

def test_insert_Generic():
    do_test_insert(GenericStrategy, [W_Object() for _ in range(6)])

def test_insert_WeakGeneric():
    do_test_insert(WeakGenericStrategy, [W_Object() for _ in range(6)])

def test_insert_Integer():
    do_test_insert(IntegerStrategy, [W_Integer(x) for x in range(6)])

def test_insert_IntegerOrNil():
    do_test_insert(IntegerOrNilStrategy, [w_nil]+[W_Integer(x) for x in range(4)]+[w_nil])
    do_test_insert(IntegerOrNilStrategy, [w_nil]*6)

# === Test Delete

def do_test_delete(cls, values, indexing_unsafe=False):
    assert len(values) >= 6
    l = W_List(cls, len(values), values)
    if not indexing_unsafe:
        py.test.raises(IndexError, l.delete, 2, 1)
    l.delete(2, 4)
    del values[2: 4]
    check_contents(l, values)
    l.delete(1, 2)
    del values[1: 2]
    check_contents(l, values)

def test_delete_Nil():
    do_test_delete(NilStrategy, [w_nil]*6)

def test_delete_Generic():
    do_test_delete(GenericStrategy, [W_Object() for _ in range(6)], indexing_unsafe=True)

def test_delete_WeakGeneric():
    do_test_delete(WeakGenericStrategy, [W_Object() for _ in range(6)])

def test_delete_Integer():
    do_test_delete(IntegerStrategy, [W_Integer(x) for x in range(6)])

def test_delete_IntegerOrNil():
    do_test_delete(IntegerOrNilStrategy, [w_nil]+[W_Integer(x) for x in range(4)]+[w_nil])
    do_test_delete(IntegerOrNilStrategy, [w_nil]*6)

# === Test Transitions

def test_CheckCanHandle():
    def assert_handles(cls, good, bad):
        s = cls(0)
        for val in good:
            assert s._check_can_handle(val)
        for val in bad:
            assert not s._check_can_handle(val)
    obj = W_Object()
    i = W_Integer(0)
    nil = w_nil

    assert_handles(EmptyStrategy, [], [nil, obj, i])
    assert_handles(NilStrategy, [nil], [obj, i])
    assert_handles(GenericStrategy, [nil, obj, i], [])
    assert_handles(WeakGenericStrategy, [nil, obj, i], [])
    assert_handles(IntegerStrategy, [i], [nil, obj])
    assert_handles(IntegerOrNilStrategy, [nil, i], [obj])

def do_test_transition(OldStrategy, value, NewStrategy, initial_size=10):
    w = W_List(OldStrategy, initial_size)
    old = w.strategy
    w.store(0, value)
    assert isinstance(w.strategy, NewStrategy)
    assert factory.switching_log == [(None, old), (old, w.strategy)]

def test_AllNil_to_Generic():
    do_test_transition(NilStrategy, W_Object(), GenericStrategy)

def test_AllNil_to_IntegerOrNil():
    do_test_transition(NilStrategy, W_Integer(0), IntegerOrNilStrategy)

def test_IntegerOrNil_to_Generic():
    do_test_transition(IntegerOrNilStrategy, W_Object(), GenericStrategy)

def test_Integer_to_IntegerOrNil():
    do_test_transition(IntegerStrategy, w_nil, IntegerOrNilStrategy)

def test_Generic_to_AllNil():
    w = W_List(GenericStrategy, 5)
    old = w.strategy
    factory.switch_strategy(w, NilStrategy)
    assert isinstance(w.strategy, NilStrategy)
    assert factory.switching_log == [(None, old), (old, w.strategy)]

def test_Integer_Generic():
    do_test_transition(IntegerStrategy, W_Object(), GenericStrategy)

def test_TaggingValue_not_storable():
    tag = IntegerOrNilStrategy(10).unwrapped_tagged_value() # sys.maxint
    do_test_transition(IntegerOrNilStrategy, W_Integer(tag), GenericStrategy)

def test_insert_StrategySwitch_IntOrNil():
    o = W_Object()
    l = do_test_insert(IntegerOrNilStrategy, [W_Integer(1), w_nil, o, o, w_nil, W_Integer(3)])
    assert isinstance(l.strategy, GenericStrategy)

def test_insert_StrategySwitch_AllNil():
    o = W_Object()
    l = do_test_insert(NilStrategy, [w_nil, w_nil, o, o, w_nil, w_nil])
    assert isinstance(l.strategy, GenericStrategy)

def test_transition_to_nonSingleton():
    l = W_List(NilStrategy, 5)
    factory.switch_strategy(l, NonSingletonStrategy)
    strategy1 = l.strategy
    assert isinstance(strategy1, NonSingletonStrategy)
    factory.switch_strategy(l, NonSingletonStrategy)
    assert strategy1 != l.strategy

def test_generic_convert_storage():
    l = W_List(NilStrategy, 5)
    # This triggers AbstractStrategy._convert_storage_from
    factory.switch_strategy(l, InefficientStrategy)
    assert isinstance(l.strategy, InefficientStrategy)
    assert l.fetch_all() == [w_nil] * 5

def test_Empty_store():
    l = W_List(EmptyStrategy, 0)
    o = W_Object()
    py.test.raises(IndexError, l.store, 0, o)
    py.test.raises(IndexError, l.store, 1, o)

def test_Empty_insert():
    def do_insert(obj, expected_strategy, default_element=w_nil):
        l = W_List(EmptyStrategy, 0)
        l.insert(0, [obj])
        assert l.size() == 1
        assert isinstance(l.strategy, expected_strategy)
        assert l.fetch_all() == [obj]
        # Also test insert with too-high index
        l = W_List(EmptyStrategy, 0)
        l.insert(5, [obj])
        assert l.fetch_all() == [obj]
    do_insert(W_Object(), GenericStrategy)
    do_insert(w_nil, NilStrategy)
    do_insert(W_Integer(1), IntegerStrategy)

# === Test helper methods

def generic_list():
    values = [W_Object() for _ in range(6)]
    return W_List(GenericStrategy, len(values), values), values

def test_slice():
    l, v = generic_list()
    assert l.slice(2, 4) == v[2:4]

def test_fetch_all():
    l, v = generic_list()
    assert l.fetch_all() == v

def test_append():
    l, v = generic_list()
    o1 = W_Object()
    o2 = W_Object()
    l.append([o1])
    assert l.fetch_all() == v + [o1]
    l.append([o1, o2])
    assert l.fetch_all() == v + [o1, o1, o2]

def test_pop():
    l, v = generic_list()
    o = l.pop(3)
    del v[3]
    assert l.fetch_all() == v
    o = l.pop(3)
    del v[3]
    assert l.fetch_all() == v

def test_store_all():
    l, v = generic_list()
    v2 = [W_Object() for _ in range(4) ]
    v3 = [W_Object() for _ in range(l.size()) ]
    assert v2 != v
    assert v3 != v

    l.store_all(v2)
    assert l.fetch_all() == v2+v[4:]
    l.store_all(v3)
    assert l.fetch_all() == v3

    py.test.raises(IndexError, l.store_all, [W_Object() for _ in range(8) ])

# === Test Weak Strategy
# TODO

# === Other tests

def test_optimized_strategy_switch(monkeypatch):
    l = W_List(NilStrategy, 5)
    s = l.strategy
    s.copied = 0
    def convert_storage_from_default(self, w_self, other):
        assert False, "The default convert_storage_from() should not be called!"
    def convert_storage_from_special(self, w_self, other):
        s.copied += 1

    monkeypatch.setattr(AbstractStrategy, "_convert_storage_from_NilStrategy", convert_storage_from_special)
    monkeypatch.setattr(AbstractStrategy, "_convert_storage_from", convert_storage_from_default)
    try:
        factory.switch_strategy(l, IntegerOrNilStrategy)
    finally:
        monkeypatch.undo()
    assert s.copied == 1, "Optimized switching routine not called exactly one time."

def test_strategy_type_for(monkeypatch):
    assert factory.strategy_type_for([w_nil, w_nil]) == NilStrategy
    assert factory.strategy_type_for([W_Integer(2), W_Integer(1)]) == IntegerStrategy
    assert factory.strategy_type_for([w_nil, W_Integer(2), w_nil]) == IntegerOrNilStrategy
    assert factory.strategy_type_for([w_nil, W_Integer(2), W_Object()]) == GenericStrategy
    assert factory.strategy_type_for([W_Integer(2), w_nil, W_Object()]) == GenericStrategy
    assert factory.strategy_type_for([W_Object(), W_Integer(2), w_nil]) == GenericStrategy
    assert factory.strategy_type_for([]) == EmptyStrategy
    monkeypatch.setattr(GenericStrategy, '_check_can_handle', lambda self, o: False)
    try:
        with py.test.raises(ValueError):
            factory.strategy_type_for([W_Object(), W_Object()])
    finally:
        monkeypatch.undo()

# === Logger tests

def test_logger(monkeypatch):
    strings = []
    def string_collector(str): strings.append(str)
    factory.logger.activate()
    monkeypatch.setattr(factory.logger, 'do_print', string_collector)
    try:
        W_List(EmptyStrategy, 0)
        l = W_List(IntegerStrategy, 3)
        l.store(1, w_nil)
    finally:
        monkeypatch.undo()
        factory.logger.active = False
    assert strings == [
        'Created (EmptyStrategy) size 0 objects 1',
        'Created (IntegerStrategy) size 3 objects 1',
        'Switched (IntegerStrategy -> IntegerOrNilStrategy) size 3 objects 1 elements: W_Object']

def test_aggregating_logger(monkeypatch):
    strings = []
    def string_collector(str): strings.append(str)
    factory.logger.activate(aggregate = True)
    monkeypatch.setattr(factory.logger, 'do_print', string_collector)
    try:
        W_List(EmptyStrategy, 0)
        l = W_List(IntegerStrategy, 3)
        l.store(1, w_nil)
        factory.logger.print_aggregated_log()
    finally:
        monkeypatch.undo()
        factory.logger.active = False
    # Order of aggregated log entries is random.
    strings.sort()
    assert strings == [
        'Created (EmptyStrategy) size 0 objects 1',
        'Created (IntegerStrategy) size 3 objects 1',
        'Switched (IntegerStrategy -> IntegerOrNilStrategy) size 3 objects 1 elements: W_Object']
