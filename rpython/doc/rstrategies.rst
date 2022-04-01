rstrategies
===========

A library to implement storage strategies in VMs based on the RPython
toolchain. rstrategies can be used in VMs for any language or language
family.

This library has been developed as part of a Masters Thesis by `Anton
Gulenko <https://github.com/antongulenko>`__.

The original paper describing the optimization "Storage Strategies for
collections in dynamically typed languages" by C.F. Bolz, L. Diekmann
and L. Tratt can be found
`here <http://stups.hhu.de/mediawiki/images/3/3b/Pub-BoDiTr13_246.pdf>`__.

So far, this library has been adpoted by 3 VMs:
`RSqueak <https://github.com/HPI-SWA-Lab/RSqueak>`__,
`Topaz <https://github.com/topazproject/topaz>`__ (`Forked
here <https://github.com/antongulenko/topaz/tree/rstrategies>`__) and
`Pycket <https://github.com/samth/pycket>`__ (`Forked
here <https://github.com/antongulenko/pycket/tree/rstrategies>`__).

Concept
-------

Collections are often used homogeneously, i.e. they contain only objects
of the same type. Primitive numeric types like ints or floats are
especially interesting for optimization. These cases can be optimized by
storing the unboxed data of these objects in consecutive memory. This is
done by letting a special "strategy" object handle the entire storage of
a collection. The collection object holds two separate references: one
to its strategy and one to its storage. Every operation on the
collection is delegated to the strategy, which accesses the storage when
needed. The strategy can be switched to a more suitable one, which might
require converting the storage array.

Usage
~~~~~

The following are the steps needed to integrated rstrategies in an
RPython VM. Because of the special nature of this library it is not
enough to simply call some API methods; the library must be integrated
within existing VM classes using a metaclass, mixins and other
meta-programming techniques.

The sequence of steps described here is something like a "setup
walkthrough", and might be a bit abstract. To see a concrete example,
look at
`SingletonStorageStrategy <https://github.com/HPI-SWA-Lab/RSqueak/blob/d048f713002c01c9b121c80e8eb9bea33ed742d6/spyvm/storage.py#L73>`__,
`StrategyFactory <https://github.com/HPI-SWA-Lab/RSqueak/blob/d048f713002c01c9b121c80e8eb9bea33ed742d6/spyvm/storage.py#L126>`__
and
`W\_PointersObject <https://github.com/HPI-SWA-Lab/RSqueak/blob/d048f713002c01c9b121c80e8eb9bea33ed742d6/spyvm/model.py#L616>`__
from the `RSqueak VM <https://github.com/HPI-SWA-Lab/RSqueak>`__. The
code is also well commented.

Basics
-------

Currently the rstrategies library supports fixed sized and variable
sized collections. This can be used to optimize a wide range of
primitive data structures like arrays, lists or regular objects. Any of
these are called 'collections' in this context. The VM should have a
central class or class hierarchy for collections. In order to extend
these classes and use strategies, the library needs accessor methods for
two attributes of collection objects: strategy and storage. The easiest
way is adding the following line to the body of the root collection
class:

::

    rstrategies.make_accessors(strategy='strategy', storage='storage')

This will generate the 4 accessor methods
``_[get/set]_[storage/strategy]()`` for the respective attributes.
Alternatively, implement these methods manually or overwrite the
getters/setters in ``StrategyFactory``.

Next, the strategy classes must be defined. This requires a small class
hierarchy with a dedicated root class. In the definition of this root
class, include the following lines:

::

        __metaclass__ = rstrategies.StrategyMetaclass
        import_from_mixin(rstrategies.AbstractStrategy)
        import_from_mixin(rstrategies.SafeIndexingMixin)

``import_from_mixin`` can be found in ``rpython.rlib.objectmodel``. If
index-checking is performed safely at other places in the VM, you can
use ``rstrategies.UnsafeIndexingMixin`` instead. If you need your own
metaclass, you can combine yours with the rstrategies one using multiple
inheritance `like
here <https://github.com/HPI-SWA-Lab/RSqueak/blob/d5ff2572106d23a5246884de6f8b86f46d85f4f7/spyvm/storage_contexts.py#L24>`__.
Also implement a ``storage_factory()`` method, which returns an instance
of ``rstrategies.StorageFactory``, which is described below.

An example ``AbstractStrategy`` class, which also stores an additional ``space`` parameter could looks like this:

::

    class AbstractStrategy(AbstractStrategy):
        _attrs_ = ['space']
        _immutable_fields_ = ['space']
        __metaclass__ = rstrat.StrategyMetaclass
        import_from_mixin(rstrat.AbstractStrategy)
        import_from_mixin(rstrategies.SafeIndexingMixin)
        
        def __init__(self, space):
            self.space = space
        
        def strategy_factory(self):
            return self.space.strategy_factory


Strategy classes
----------------

Now you can create the actual strategy classes, subclassing them from
the single root class. The following list summarizes the basic
strategies available.

- ``EmptyStrategy`` A strategy for empty collections; very efficient, but limited. Does not allocate anything.
- ``SingleValueStrategy`` A strategy for collections containing the same object ``n`` times. Only allocates memory to store the size of the collection.
- ``GenericStrategy`` A non-optimized strategy backed by a generic python list. This is the fallback strategy, since it can store everything, but is not optimized.
- ``WeakGenericStrategy`` Like ``GenericStrategy``, but uses ``weakref`` to hold on weakly to its elements.
- ``SingleTypeStrategy`` Can store a single unboxed type like int or float. This is the main optimizing strategy
- ``TaggingStrategy`` Extension of SingleTypeStrategy. Uses a specific value in the value range of the unboxed type to represent one additional, arbitrary object. For example, one of ``float``'s ``NaN`` representations can be used to represent special value like ``nil``.

There are also intermediate classes, which allow creating new, more
customized strategies. For this, you should get familiar with the code.

Include one of these mixin classes using ``import_from_mixin``. The
mixin classes contain comments describing methods or fields which are
also required in the strategy class in order to use them. Additionally,
add the ``@rstrategies.strategy(generalize=alist)`` decorator to all
strategy classes. The ``alist`` parameter must contain all strategies,
which the decorated strategy can switch to, if it can not represent a
new element anymore.
`Example <https://github.com/HPI-SWA-Lab/RSqueak/blob/d5ff2572106d23a5246884de6f8b86f46d85f4f7/spyvm/storage.py#L87>`__
for an implemented strategy. See the other strategy classes behind this
link for more examples.

An example strategy class for optimized ``int`` storage could look like this:

::

    @rstrat.strategy(generalize=[GenericStrategy])
    class IntegerOrNilStrategy(AbstractStrategy):
        import_from_mixin(rstrat.TaggingStrategy)
        contained_type = model.W_Integer
        def wrap(self, val): return self.space.wrap_int(val)
        def unwrap(self, w_val): return self.space.unwrap_int(w_val)
        def wrapped_tagged_value(self): return self.space.w_nil
        def unwrapped_tagged_value(self): return constants.MAXINT

Strategy Factory
----------------

The last part is subclassing ``rstrategies.StrategyFactory``,
overwriting the method ``instantiate_strategy`` if necessary and passing
the strategies root class to the constructor. The factory provides the
methods ``switch_strategy``, ``set_initial_strategy``,
``strategy_type_for`` which can be used by the VM code to use the
mechanism behind strategies. See the comments in the source code.

The strategy mixins offer the following methods to manipulate the
contents of the collection:

- basic API

  - ``size``

- fixed size API

  - ``store``, ``fetch``, ``slice``, ``store_all``, ``fetch_all``

- variable size API

  - ``insert``, ``delete``, ``append``, ``pop``

If the collection has a fixed size, simply never use any of the variable
size methods in the VM code. Since the strategies are singletons, these
methods need the collection object as first parameter. For convenience,
more fitting accessor methods should be implemented on the collection
class itself.

An example strategy factory for the ``AbstractStrategy`` class above could look like this:

::

    class StrategyFactory(rstrategies.StrategyFactory):
        _attrs_ = ['space']
        _immutable_fields_ = ['space']
        
        def __init__(self, space):
            self.space = space
            rstrat.StrategyFactory.__init__(self, AbstractStrategy)
        
        def instantiate_strategy(self, strategy_type):
            return strategy_type(self.space)
        
        def strategy_type_for(self, list_w, weak=False):
            """
            Helper method for handling weak objects specially
            """
            if weak:
                return WeakListStrategy
        return rstrategies.StrategyFactory.strategy_type_for(self, list_w)
    