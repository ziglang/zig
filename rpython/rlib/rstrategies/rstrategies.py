
import weakref, sys
from rpython.rlib.rstrategies import logger
from rpython.rlib import jit, objectmodel, rerased, rarithmetic
from rpython.rlib.objectmodel import specialize, not_rpython

def make_accessors(strategy='strategy', storage='storage'):
    """
    Instead of using this generator, the methods can be implemented manually.
    A third way is to overwrite the getter/setter methods in StrategyFactory.
    """
    def make_getter(attr):
        def getter(self): return getattr(self, attr)
        return getter
    def make_setter(attr):
        def setter(self, val): setattr(self, attr, val)
        return setter
    classdef = sys._getframe(1).f_locals
    classdef['_get_strategy'] = make_getter(strategy)
    classdef['_set_strategy'] = make_setter(strategy)
    classdef['_get_storage'] = make_getter(storage)
    classdef['_set_storage'] = make_setter(storage)

class StrategyMetaclass(type):
    """
    A metaclass is required, because we need certain attributes to be special
    for every single strategy class.
    """
    def __new__(self, name, bases, attrs):
        attrs['_is_strategy'] = False
        attrs['_is_singleton'] = False
        attrs['_specializations'] = []
        # Not every strategy uses rerased-pairs, but they won't hurt
        erase, unerase = rerased.new_erasing_pair(name)
        def get_storage(self, w_self):
            erased = self.strategy_factory().get_storage(w_self)
            return unerase(erased)
        def set_storage(self, w_self, storage):
            erased = erase(storage)
            self.strategy_factory().set_storage(w_self, erased)
        attrs['get_storage'] = get_storage
        attrs['set_storage'] = set_storage
        return type.__new__(self, name, bases, attrs)

def strategy(generalize=None, singleton=True):
    """
    Strategy classes must be decorated with this.
    generalize is a list of other strategies, that can be switched to from the decorated strategy.
    If the singleton flag is set to False, new strategy instances will be created,
    instead of always reusing the singleton object.
    """
    def decorator(strategy_class):
        # Patch strategy class: Add generalized_strategy_for and mark as strategy class.
        if generalize:
            @jit.unroll_safe
            def generalized_strategy_for(self, value):
                # TODO - optimize this method
                for strategy in generalize:
                    if self.strategy_factory().strategy_singleton_instance(strategy)._check_can_handle(value):
                        return strategy
                raise Exception("Could not find generalized strategy for %s coming from %s" % (value, self))
            strategy_class.generalized_strategy_for = generalized_strategy_for
            for generalized in generalize:
                generalized._specializations.append(strategy_class)
        strategy_class._is_strategy = True
        strategy_class._generalizations = generalize
        strategy_class._is_singleton = singleton
        return strategy_class
    return decorator

class StrategyFactory(object):
    _immutable_fields_ = ["strategies[*]", "logger", "strategy_singleton_field"]
    factory_instance_counter = 0

    def __init__(self, root_class, all_strategy_classes=None):
        if all_strategy_classes is None:
            all_strategy_classes = self._collect_subclasses(root_class)
        self.strategies = []
        self.logger = logger.Logger()

        # This is to avoid confusion between multiple factories existing simultaneously (e.g. in tests)
        self.strategy_singleton_field = "__singleton_%i" % StrategyFactory.factory_instance_counter
        StrategyFactory.factory_instance_counter += 1

        self._create_strategy_instances(root_class, all_strategy_classes)

    def _create_strategy_instances(self, root_class, all_strategy_classes):
        for strategy_class in all_strategy_classes:
            if strategy_class._is_strategy:
                setattr(strategy_class, self.strategy_singleton_field, self.instantiate_strategy(strategy_class))
                self.strategies.append(strategy_class)
            self._patch_strategy_class(strategy_class, root_class)
        self._order_strategies()

    # =============================
    # API methods
    # =============================

    def switch_strategy(self, w_self, new_strategy_type, new_element=None):
        """
        Switch the strategy of w_self to the new type.
        new_element can be given as as hint, purely for logging purposes.
        It should be the object that was added to w_self, causing the strategy switch.
        """
        old_strategy = self.get_strategy(w_self)
        if new_strategy_type._is_singleton:
            new_strategy = self.strategy_singleton_instance(new_strategy_type)
        else:
            size = old_strategy.size(w_self)
            new_strategy = self.instantiate_strategy(new_strategy_type, w_self, size)
        self.set_strategy(w_self, new_strategy)
        old_strategy._convert_storage_to(w_self, new_strategy)
        new_strategy.strategy_switched(w_self)
        self.log(w_self, new_strategy, old_strategy, new_element)
        return new_strategy

    def set_initial_strategy(self, w_self, strategy_type, size, elements=None):
        """
        Initialize the strategy and storage fields of w_self.
        This must be called before switch_strategy or any strategy method can be used.
        elements is an optional list of values initially stored in w_self.
        If given, then len(elements) == size must hold.
        """
        assert self.get_strategy(w_self) is None, "Strategy should not be initialized yet!"
        if strategy_type._is_singleton:
            strategy = self.strategy_singleton_instance(strategy_type)
        else:
            strategy = self.instantiate_strategy(strategy_type, w_self, size)
        self.set_strategy(w_self, strategy)
        strategy._initialize_storage(w_self, size)
        element = None
        if elements:
            strategy.store_all(w_self, elements)
            if len(elements) > 0: element = elements[0]
        strategy.strategy_switched(w_self)
        self.log(w_self, strategy, None, element)
        return strategy

    @jit.unroll_safe
    def strategy_type_for(self, objects):
        """
        Return the best-fitting strategy to hold all given objects.
        """
        specialized_strategies = len(self.strategies)
        can_handle = [True] * specialized_strategies
        for obj in objects:
            if specialized_strategies <= 1:
                break
            for i, strategy in enumerate(self.strategies):
                if can_handle[i] and not self.strategy_singleton_instance(strategy)._check_can_handle(obj):
                    can_handle[i] = False
                    specialized_strategies -= 1
        for i, strategy_type in enumerate(self.strategies):
            if can_handle[i]:
                return strategy_type
        raise ValueError("Could not find strategy to handle: %s" % objects)

    @not_rpython
    def decorate_strategies(self, transitions):
        """
        As an alternative to decorating all strategies with @strategy,
        invoke this in the constructor of your StrategyFactory subclass, before
        calling __init__. transitions is a dict mapping all strategy classes to
        their 'generalize' list parameter (see @strategy decorator).
        """
        for strategy_class, generalized in transitions.items():
            strategy(generalized)(strategy_class)

    # =============================
    # The following methods can be overwritten to customize certain aspects of the factory.
    # =============================

    def instantiate_strategy(self, strategy_type, w_self=None, initial_size=0):
        """
        Return a functional instance of strategy_type.
        Overwrite this if you need a non-default constructor.
        The two additional parameters should be ignored for singleton-strategies.
        """
        return strategy_type()

    def log(self, w_self, new_strategy, old_strategy=None, new_element=None):
        """
        This can be overwritten into a more appropriate call to self.logger.log
        """
        if not self.logger.active: return
        new_strategy_str = self.log_string_for_object(new_strategy)
        old_strategy_str = self.log_string_for_object(old_strategy)
        element_typename = self.log_string_for_object(new_element)
        size = new_strategy.size(w_self)
        typename = ""
        cause = "Switched" if old_strategy else "Created"
        self.logger.log(new_strategy_str, size, cause, old_strategy_str, typename, element_typename)

    @specialize.call_location()
    def log_string_for_object(self, obj):
        """
        This can be overwritten instead of the entire log() method.
        Keep the specialize-annotation in order to handle different kinds of objects here.
        """
        return obj.__class__.__name__ if obj else ""

    # These storage accessors are specialized because the storage field is
    # populated by erased-objects which seem to be incompatible sometimes.
    @specialize.call_location()
    def get_storage(self, obj):
        return obj._get_storage()
    @specialize.call_location()
    def set_storage(self, obj, val):
        return obj._set_storage(val)

    def get_strategy(self, obj):
        return obj._get_strategy()
    def set_strategy(self, obj, val):
        return obj._set_strategy(val)

    # =============================
    # Internal methods
    # =============================

    @not_rpython
    def _patch_strategy_class(self, strategy_class, root_class):
        # Patch root class: Add default handler for visitor
        def _convert_storage_from_OTHER(self, w_self, previous_strategy):
            self._convert_storage_from(w_self, previous_strategy)
        funcname = "_convert_storage_from_" + strategy_class.__name__
        _convert_storage_from_OTHER.__name__ = funcname
        setattr(root_class, funcname, _convert_storage_from_OTHER)

        # Patch strategy class: Add polymorphic visitor function
        def _convert_storage_to(self, w_self, new_strategy):
            getattr(new_strategy, funcname)(w_self, self)
        strategy_class._convert_storage_to = _convert_storage_to

    @not_rpython
    def _collect_subclasses(self, cls):
        subclasses = []
        for subcls in cls.__subclasses__():
            subclasses.append(subcls)
            subclasses.extend(self._collect_subclasses(subcls))
        return subclasses

    @not_rpython
    def _order_strategies(self):
        def get_generalization_depth(strategy, visited=None):
            if visited is None:
                visited = set()
            if strategy._generalizations:
                if strategy in visited:
                    raise Exception("Cycle in generalization-tree of %s" % strategy)
                visited.add(strategy)
                depth = 0
                for generalization in strategy._generalizations:
                    other_depth = get_generalization_depth(generalization, set(visited))
                    depth = max(depth, other_depth)
                return depth + 1
            else:
                return 0
        self.strategies.sort(key=get_generalization_depth, reverse=True)

    @jit.elidable
    def strategy_singleton_instance(self, strategy_class):
        return getattr(strategy_class, self.strategy_singleton_field)

    def _freeze_(self):
        # Instance will be frozen at compile time, making accesses constant.
        # The constructor does meta stuff which is not possible after translation.
        return True

class AbstractStrategy(object):
    """
    == Required:
    strategy_factory(self) - Access to StorageFactory
    """

    def strategy_switched(self, w_self):
        # Overwrite this method for a hook whenever the strategy
        # of w_self was switched to self.
        pass

    # Main Fixedsize API

    def store(self, w_self, index0, value):
        raise NotImplementedError("Abstract method")

    def fetch(self, w_self, index0):
        raise NotImplementedError("Abstract method")

    def size(self, w_self):
        raise NotImplementedError("Abstract method")

    # Fixedsize utility methods

    def slice(self, w_self, start, end):
        return [ self.fetch(w_self, i) for i in range(start, end)]

    def fetch_all(self, w_self):
        return self.slice(w_self, 0, self.size(w_self))

    def store_all(self, w_self, elements):
        for i, e in enumerate(elements):
            self.store(w_self, i, e)

    # Main Varsize API

    def insert(self, w_self, index0, list_w):
        raise NotImplementedError("Abstract method")

    def delete(self, w_self, start, end):
        raise NotImplementedError("Abstract method")

    # Varsize utility methods

    def append(self, w_self, list_w):
        self.insert(w_self, self.size(w_self), list_w)

    def pop(self, w_self, index0):
        e = self.fetch(w_self, index0)
        self.delete(w_self, index0, index0+1)
        return e

    # Internal methods

    def _initialize_storage(self, w_self, initial_size):
        raise NotImplementedError("Abstract method")

    def _check_can_handle(self, value):
        raise NotImplementedError("Abstract method")

    def _convert_storage_to(self, w_self, new_strategy):
        # This will be overwritten in _patch_strategy_class
        new_strategy._convert_storage_from(w_self, self)

    @jit.unroll_safe
    def _convert_storage_from(self, w_self, previous_strategy):
        # This is a very unefficient (but most generic) way to do this.
        # Subclasses should specialize.
        storage = previous_strategy.fetch_all(w_self)
        self._initialize_storage(w_self, previous_strategy.size(w_self))
        for i, field in enumerate(storage):
            self.store(w_self, i, field)

    def _generalize_for_value(self, w_self, value):
        strategy_type = self.generalized_strategy_for(value)
        new_instance = self.strategy_factory().switch_strategy(w_self, strategy_type, new_element=value)
        return new_instance

    def _cannot_handle_store(self, w_self, index0, value):
        new_instance = self._generalize_for_value(w_self, value)
        new_instance.store(w_self, index0, value)

    def _cannot_handle_insert(self, w_self, index0, list_w):
        # TODO - optimize. Prevent multiple generalizations and slicing done by callers.
        new_strategy = self._generalize_for_value(w_self, list_w[0])
        new_strategy.insert(w_self, index0, list_w)

# ============== Special Strategies with no storage array ==============

class EmptyStrategy(AbstractStrategy):
    # == Required:
    # See AbstractStrategy

    def _initialize_storage(self, w_self, initial_size):
        assert initial_size == 0
        self.set_storage(w_self, None)
    def _convert_storage_from(self, w_self, previous_strategy):
        self.set_storage(w_self, None)
    def _check_can_handle(self, value):
        return False

    def fetch(self, w_self, index0):
        raise IndexError
    def store(self, w_self, index0, value):
        self._cannot_handle_store(w_self, index0, [value])
    def insert(self, w_self, index0, list_w):
        self._cannot_handle_insert(w_self, index0, list_w)
    def delete(self, w_self, start, end):
        self.check_index_range(w_self, start, end)
    def size(self, w_self):
        return 0

class SingleValueStrategyStorage(object):
    """Small container object for a size value."""
    _attrs_ = ['size']
    def __init__(self, size=0):
        self.size = size

class SingleValueStrategy(AbstractStrategy):
    # == Required:
    # See AbstractStrategy
    # check_index_*(...) - use mixin SafeIndexingMixin or UnsafeIndexingMixin
    # value(self) - the single value contained in this strategy. Should be constant.

    def _initialize_storage(self, w_self, initial_size):
        storage_obj = SingleValueStrategyStorage(initial_size)
        self.set_storage(w_self, storage_obj)
    def _convert_storage_from(self, w_self, previous_strategy):
        self._initialize_storage(w_self, previous_strategy.size(w_self))
    def _check_can_handle(self, value):
        return value is self.value()

    def fetch(self, w_self, index0):
        self.check_index_fetch(w_self, index0)
        return self.value()
    def store(self, w_self, index0, value):
        self.check_index_store(w_self, index0)
        if self._check_can_handle(value):
            return
        self._cannot_handle_store(w_self, index0, value)
    def delete(self, w_self, start, end):
        self.check_index_range(w_self, start, end)
        self.get_storage(w_self).size -= (end - start)
    def size(self, w_self):
        return self.get_storage(w_self).size

    @jit.unroll_safe
    def insert(self, w_self, index0, list_w):
        storage_obj = self.get_storage(w_self)
        for i in range(len(list_w)):
            if self._check_can_handle(list_w[i]):
                storage_obj.size += 1
            else:
                self._cannot_handle_insert(w_self, index0 + i, list_w[i:])
                return

# ============== Basic strategies with storage ==============

class StrategyWithStorage(AbstractStrategy):
    # == Required:
    # See AbstractStrategy
    # check_index_*(...) - use mixin SafeIndexingMixin or UnsafeIndexingMixin
    # default_value(self) - The value to be initially contained in this strategy

    def _initialize_storage(self, w_self, initial_size):
        default = self._unwrap(self.default_value())
        self.set_storage(w_self, [default] * initial_size)

    @jit.unroll_safe
    def _convert_storage_from(self, w_self, previous_strategy):
        size = previous_strategy.size(w_self)
        new_storage = [ self._unwrap(previous_strategy.fetch(w_self, i))
                        for i in range(size) ]
        self.set_storage(w_self, new_storage)

    def store(self, w_self, index0, wrapped_value):
        self.check_index_store(w_self, index0)
        assert index0 >= 0
        if self._check_can_handle(wrapped_value):
            unwrapped = self._unwrap(wrapped_value)
            self.get_storage(w_self)[index0] = unwrapped
        else:
            self._cannot_handle_store(w_self, index0, wrapped_value)

    def fetch(self, w_self, index0):
        self.check_index_fetch(w_self, index0)
        assert index0 >= 0
        unwrapped = self.get_storage(w_self)[index0]
        return self._wrap(unwrapped)

    def _wrap(self, value):
        raise NotImplementedError("Abstract method")

    def _unwrap(self, value):
        raise NotImplementedError("Abstract method")

    def size(self, w_self):
        return len(self.get_storage(w_self))

    @jit.unroll_safe
    def insert(self, w_self, start, list_w):
        # This is following Python's behaviour - insert automatically
        # happens at the beginning of an array, even if index is larger
        if start > self.size(w_self):
            start = self.size(w_self)
        for i in range(len(list_w)):
            if self._check_can_handle(list_w[i]):
                self.get_storage(w_self).insert(start + i, self._unwrap(list_w[i]))
            else:
                self._cannot_handle_insert(w_self, start + i, list_w[i:])
                return

    def delete(self, w_self, start, end):
        self.check_index_range(w_self, start, end)
        assert start >= 0 and end >= 0
        del self.get_storage(w_self)[start : end]

class GenericStrategy(StrategyWithStorage):
    # == Required:
    # See StrategyWithStorage

    def _wrap(self, value):
        return value
    def _unwrap(self, value):
        return value
    def _check_can_handle(self, wrapped_value):
        return True

class WeakGenericStrategy(StrategyWithStorage):
    # == Required:
    # See StrategyWithStorage

    def _wrap(self, value):
        return value() or self.default_value()
    def _unwrap(self, value):
        assert value is not None
        return weakref.ref(value)
    def _check_can_handle(self, wrapped_value):
        return True

# ============== Mixins for index checking operations ==============

class SafeIndexingMixin(object):
    def check_index_store(self, w_self, index0):
        self.check_index(w_self, index0)
    def check_index_fetch(self, w_self, index0):
        self.check_index(w_self, index0)
    def check_index_range(self, w_self, start, end):
        if end < start:
            raise IndexError
        self.check_index(w_self, start)
        self.check_index(w_self, end)
    def check_index(self, w_self, index0):
        if not rarithmetic.int_between(0, index0, self.size(w_self)):
            raise IndexError

class UnsafeIndexingMixin(object):
    def check_index_store(self, w_self, index0):
        pass
    def check_index_fetch(self, w_self, index0):
        pass
    def check_index_range(self, w_self, start, end):
        pass

# ============== Specialized Storage Strategies ==============

class SpecializedStrategy(StrategyWithStorage):
    # == Required:
    # See StrategyWithStorage
    # wrap(self, value) - Return a boxed object for the primitive value
    # unwrap(self, value) - Return the unboxed primitive value of value

    def _unwrap(self, value):
        return self.unwrap(value)
    def _wrap(self, value):
        return self.wrap(value)

class SingleTypeStrategy(SpecializedStrategy):
    # == Required Functions:
    # See SpecializedStrategy
    # contained_type - The wrapped type that can be stored in this strategy

    def _check_can_handle(self, value):
        return isinstance(value, self.contained_type)

class TaggingStrategy(SingleTypeStrategy):
    """This strategy uses a special tag value to represent a single additional object."""
    # == Required:
    # See SingleTypeStrategy
    # wrapped_tagged_value(self) - The tagged object
    # unwrapped_tagged_value(self) - The unwrapped tag value representing the tagged object

    def _check_can_handle(self, value):
        return value is self.wrapped_tagged_value() or \
                (isinstance(value, self.contained_type) and \
                self.unwrap(value) != self.unwrapped_tagged_value())

    def _unwrap(self, value):
        if value is self.wrapped_tagged_value():
            return self.unwrapped_tagged_value()
        return self.unwrap(value)

    def _wrap(self, value):
        if value == self.unwrapped_tagged_value():
            return self.wrapped_tagged_value()
        return self.wrap(value)
