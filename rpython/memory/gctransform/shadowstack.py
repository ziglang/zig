from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomePtr
from rpython.rlib.debug import ll_assert
from rpython.rlib.nonconst import NonConstant
from rpython.rlib import rgc
from rpython.rlib.objectmodel import specialize
from rpython.rtyper import rmodel
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.llannotation import SomeAddress
from rpython.memory.gctransform.framework import (
     BaseFrameworkGCTransformer, BaseRootWalker, sizeofaddr)
from rpython.rtyper.rbuiltin import gen_cast
from rpython.memory.gctransform.log import log


class ShadowStackFrameworkGCTransformer(BaseFrameworkGCTransformer):
    def annotate_walker_functions(self, getfn):
        self.incr_stack_ptr = getfn(self.root_walker.incr_stack,
                                   [annmodel.SomeInteger()],
                                   SomeAddress(),
                                   inline = True)
        self.decr_stack_ptr = getfn(self.root_walker.decr_stack,
                                   [annmodel.SomeInteger()],
                                   SomeAddress(),
                                   inline = True)

    def build_root_walker(self):
        return ShadowStackRootWalker(self)

    def push_roots(self, hop, keep_current_args=False):
        livevars = self.get_livevars_for_roots(hop, keep_current_args)
        self.num_pushs += len(livevars)
        hop.genop("gc_push_roots", livevars)
        return livevars

    def pop_roots(self, hop, livevars):
        hop.genop("gc_pop_roots", livevars)
        # NB. we emit it even if len(livevars) == 0; this is needed for
        # shadowcolor.move_pushes_earlier()


@specialize.call_location()
def walk_stack_root(invoke, arg0, arg1, start, addr, is_minor):
    skip = 0
    while addr != start:
        addr -= sizeofaddr
        #XXX reintroduce support for tagged values?
        #if gc.points_to_valid_gc_object(addr):
        #    callback(gc, addr)

        if skip & 1 == 0:
            content = addr.address[0]
            n = llmemory.cast_adr_to_int(content)
            if n & 1 == 0:
                if content:   # non-0, non-odd: a regular ptr
                    invoke(arg0, arg1, addr)
            else:
                # odd number: a skip bitmask
                if n > 0:       # initially, an unmarked value
                    if is_minor:
                        newcontent = llmemory.cast_int_to_adr(-n)
                        addr.address[0] = newcontent   # mark
                    skip = n
                else:
                    # a marked value
                    if is_minor:
                        return
                    skip = -n
        skip >>= 1


class ShadowStackRootWalker(BaseRootWalker):
    def __init__(self, gctransformer):
        BaseRootWalker.__init__(self, gctransformer)
        # NB. 'self' is frozen, but we can use self.gcdata to store state
        gcdata = self.gcdata
        gcdata.can_look_at_partial_stack = True

        def incr_stack(n):
            top = gcdata.root_stack_top
            gcdata.root_stack_top = top + n*sizeofaddr
            return top
        self.incr_stack = incr_stack

        def decr_stack(n):
            top = gcdata.root_stack_top - n*sizeofaddr
            gcdata.root_stack_top = top
            return top
        self.decr_stack = decr_stack

        self.invoke_collect_stack_root = specialize.call_location()(
            lambda arg0, arg1, addr: arg0(self.gc, addr))

        self.shadow_stack_pool = ShadowStackPool(gcdata)
        rsd = gctransformer.root_stack_depth
        if rsd is not None:
            self.shadow_stack_pool.root_stack_depth = rsd

    def push_stack(self, addr):
        top = self.incr_stack(1)
        top.address[0] = addr

    def pop_stack(self):
        top = self.decr_stack(1)
        return top.address[0]

    def setup_root_walker(self):
        self.shadow_stack_pool.initial_setup()
        BaseRootWalker.setup_root_walker(self)

    def walk_stack_roots(self, collect_stack_root, is_minor=False):
        # Note that if we're the first minor collection after a thread
        # switch, then we also need to disable the 'is_minor'
        # optimization.  The reason is subtle: we need to walk the whole
        # stack because otherwise, we can be in the middle of an
        # incremental major collection, and the new stack was just moved
        # off a ShadowStackRef object (gctransform/shadowstack.py) which
        # was not seen yet.  We might completely miss some old objects
        # from the parts of that stack that are skipped by this is_minor
        # optimization.
        gcdata = self.gcdata
        if is_minor and not gcdata.can_look_at_partial_stack:
            is_minor = False
            gcdata.can_look_at_partial_stack = True
        walk_stack_root(self.invoke_collect_stack_root, collect_stack_root,
                        None, gcdata.root_stack_base, gcdata.root_stack_top,
                        is_minor=is_minor)

    def need_thread_support(self, gctransformer, getfn):
        from rpython.rlib import rthread    # xxx fish
        gcdata = self.gcdata
        # the interfacing between the threads and the GC is done via
        # two completely ad-hoc operations at the moment:
        # gc_thread_run and gc_thread_die.  See docstrings below.

        shadow_stack_pool = self.shadow_stack_pool
        SHADOWSTACKREF = get_shadowstackref(self, gctransformer)

        # this is a dict {tid: SHADOWSTACKREF}, where the tid for the
        # current thread may be missing so far
        gcdata.thread_stacks = None
        shadow_stack_pool.has_threads = True

        # Return the thread identifier, as an integer.
        get_tid = rthread.get_ident

        def thread_setup():
            tid = get_tid()
            gcdata.main_tid = tid
            gcdata.active_tid = tid

        def thread_run():
            """Called whenever the current thread (re-)acquired the GIL.
            This should ensure that the shadow stack installed in
            gcdata.root_stack_top/root_stack_base is the one corresponding
            to the current thread.
            No GC operation here, e.g. no mallocs or storing in a dict!

            Note that here specifically we don't call rthread.get_ident(),
            but rthread.get_or_make_ident().  We are possibly in a fresh
            new thread, so we need to be careful.
            """
            tid = rthread.get_or_make_ident()
            if gcdata.active_tid != tid:
                switch_shadow_stacks(tid)

        def thread_die():
            """Called just before the final GIL release done by a dying
            thread.  After a thread_die(), no more gc operation should
            occur in this thread.
            """
            tid = get_tid()
            if tid == gcdata.main_tid:
                return   # ignore calls to thread_die() in the main thread
                         # (which can occur after a fork()).
            # we need to switch somewhere else, so go to main_tid
            gcdata.active_tid = gcdata.main_tid
            thread_stacks = gcdata.thread_stacks
            new_ref = thread_stacks[gcdata.active_tid]
            try:
                del thread_stacks[tid]
            except KeyError:
                pass
            # no more GC operation from here -- switching shadowstack!
            shadow_stack_pool.forget_current_state()
            shadow_stack_pool.restore_state_from(new_ref)

        def switch_shadow_stacks(new_tid):
            # we have the wrong shadowstack right now, but it should not matter
            thread_stacks = gcdata.thread_stacks
            try:
                if thread_stacks is None:
                    gcdata.thread_stacks = thread_stacks = {}
                    raise KeyError
                new_ref = thread_stacks[new_tid]
            except KeyError:
                new_ref = lltype.nullptr(SHADOWSTACKREF)
            try:
                old_ref = thread_stacks[gcdata.active_tid]
            except KeyError:
                # first time we ask for a SHADOWSTACKREF for this active_tid
                old_ref = shadow_stack_pool.allocate(SHADOWSTACKREF)
                thread_stacks[gcdata.active_tid] = old_ref
            #
            # no GC operation from here -- switching shadowstack!
            shadow_stack_pool.save_current_state_away(old_ref)
            if new_ref:
                shadow_stack_pool.restore_state_from(new_ref)
            else:
                shadow_stack_pool.start_fresh_new_state()
            # done
            #
            gcdata.active_tid = new_tid
        switch_shadow_stacks._dont_inline_ = True

        def thread_after_fork(result_of_fork, opaqueaddr):
            # we don't need a thread_before_fork in this case, so
            # opaqueaddr == NULL.  This is called after fork().
            if result_of_fork == 0:
                # We are in the child process.  Assumes that only the
                # current thread survived, so frees the shadow stacks
                # of all the other ones.
                gcdata.thread_stacks = None
                # Finally, reset the stored thread IDs, in case it
                # changed because of fork().  Also change the main
                # thread to the current one (because there is not any
                # other left).
                tid = get_tid()
                gcdata.main_tid = tid
                gcdata.active_tid = tid

        self.thread_setup = thread_setup
        self.thread_run_ptr = getfn(thread_run, [], annmodel.s_None,
                                    minimal_transform=False)
        self.thread_die_ptr = getfn(thread_die, [], annmodel.s_None,
                                    minimal_transform=False)
        # no thread_before_fork_ptr here
        self.thread_after_fork_ptr = getfn(thread_after_fork,
                                           [annmodel.SomeInteger(),
                                            SomeAddress()],
                                           annmodel.s_None,
                                           minimal_transform=False)

    def need_stacklet_support(self, gctransformer, getfn):
        from rpython.rlib import _stacklet_shadowstack
        _stacklet_shadowstack.complete_destrptr(gctransformer)

        gcdata = self.gcdata
        def gc_modified_shadowstack():
            gcdata.can_look_at_partial_stack = False

        self.gc_modified_shadowstack_ptr = getfn(gc_modified_shadowstack,
                                                 [], annmodel.s_None)

    def build_increase_root_stack_depth_ptr(self, getfn):
        shadow_stack_pool = self.shadow_stack_pool
        def gc_increase_root_stack_depth(new_size):
            shadow_stack_pool.increase_root_stack_depth(new_size)

        self.gc_increase_root_stack_depth_ptr = getfn(
                gc_increase_root_stack_depth, [annmodel.SomeInteger()],
                annmodel.s_None)

    def postprocess_graph(self, gct, graph, any_inlining):
        from rpython.memory.gctransform import shadowcolor
        if any_inlining:
            shadowcolor.postprocess_inlining(graph)
        use_push_pop = shadowcolor.postprocess_graph(graph, gct.c_const_gcdata)
        if use_push_pop and graph in gct.graphs_to_inline:
            log.WARNING("%r is marked for later inlining, "
                        "but is using push/pop roots.  Disabled" % (graph,))
            del gct.graphs_to_inline[graph]

# ____________________________________________________________

class ShadowStackPool(object):
    """Manages a pool of shadowstacks.
    """
    _alloc_flavor_ = "raw"
    root_stack_depth = 163840
    has_threads = False

    def __init__(self, gcdata):
        self.unused_full_stack = llmemory.NULL
        self.gcdata = gcdata

    def initial_setup(self):
        self._prepare_unused_stack()
        self.start_fresh_new_state()

    def allocate(self, SHADOWSTACKREF):
        """Allocate an empty SHADOWSTACKREF object."""
        return lltype.malloc(SHADOWSTACKREF, zero=True)

    def save_current_state_away(self, shadowstackref):
        """Save the current state away into 'shadowstackref'.
        This either works, or raise MemoryError and nothing is done.
        To do a switch, first call save_current_state_away() or
        forget_current_state(), and then call restore_state_from()
        or start_fresh_new_state().
        """
        self._prepare_unused_stack()
        shadowstackref.base = self.gcdata.root_stack_base
        shadowstackref.top  = self.gcdata.root_stack_top
        ll_assert(shadowstackref.base <= shadowstackref.top,
                  "save_current_state_away: broken shadowstack")
        #
        # cannot use llop.gc_writebarrier() here, because
        # we are in a minimally-transformed GC helper :-/
        gc = self.gcdata.gc
        if hasattr(gc.__class__, 'write_barrier'):
            shadowstackadr = llmemory.cast_ptr_to_adr(shadowstackref)
            gc.write_barrier(shadowstackadr)
        #
        self.gcdata.root_stack_top = llmemory.NULL  # to detect missing restore

    def forget_current_state(self):
        ll_assert(self.gcdata.root_stack_base == self.gcdata.root_stack_top,
                  "forget_current_state: shadowstack not empty!")
        if self.unused_full_stack:
            llmemory.raw_free(self.unused_full_stack)
        self.unused_full_stack = self.gcdata.root_stack_base
        self.gcdata.root_stack_top = llmemory.NULL  # to detect missing restore

    def restore_state_from(self, shadowstackref):
        ll_assert(bool(shadowstackref.base), "empty shadowstackref!")
        ll_assert(shadowstackref.base <= shadowstackref.top,
                  "restore_state_from: broken shadowstack")
        self.gcdata.root_stack_base = shadowstackref.base
        self.gcdata.root_stack_top  = shadowstackref.top
        self.gcdata.can_look_at_partial_stack = False
        self._cleanup(shadowstackref)

    def start_fresh_new_state(self):
        self.gcdata.root_stack_base = self.unused_full_stack
        self.gcdata.root_stack_top  = self.unused_full_stack
        self.unused_full_stack = llmemory.NULL

    def _cleanup(self, shadowstackref):
        shadowstackref.base = llmemory.NULL
        shadowstackref.top = llmemory.NULL

    def _prepare_unused_stack(self):
        if self.unused_full_stack == llmemory.NULL:
            root_stack_size = sizeofaddr * self.root_stack_depth
            self.unused_full_stack = llmemory.raw_malloc(root_stack_size)
            if self.unused_full_stack == llmemory.NULL:
                raise MemoryError

    def increase_root_stack_depth(self, new_depth):
        if new_depth <= self.root_stack_depth:
            return     # can't easily decrease the size
        if self.unused_full_stack:
            llmemory.raw_free(self.unused_full_stack)
            self.unused_full_stack = llmemory.NULL
        used = self.gcdata.root_stack_top - self.gcdata.root_stack_base
        addr = self._resize(self.gcdata.root_stack_base, used, new_depth)
        self.gcdata.root_stack_base = addr
        self.gcdata.root_stack_top  = addr + used
        # no gc operations above: we just switched shadowstacks
        if self.has_threads:
            self._resize_thread_shadowstacks(new_depth)
        self.root_stack_depth = new_depth

    def _resize_thread_shadowstacks(self, new_depth):
        if self.gcdata.thread_stacks is not None:
            for ssref in self.gcdata.thread_stacks.values():
                if ssref.base:
                    used = ssref.top - ssref.base
                    addr = self._resize(ssref.base, used, new_depth)
                    ssref.base = addr
                    ssref.top = addr + used
    _resize_thread_shadowstacks._dont_inline_ = True

    def _resize(self, base, used, new_depth):
        new_size = sizeofaddr * new_depth
        ll_assert(used <= new_size, "shadowstack resize: overflow detected")
        addr = llmemory.raw_malloc(new_size)
        if addr == llmemory.NULL:
            raise MemoryError
        # note that we don't know the total memory size of 'base', but we
        # know the size of the part that is used right now, and we only need
        # to copy that
        llmemory.raw_memmove(base, addr, used)
        llmemory.raw_free(base)
        return addr


def get_shadowstackref(root_walker, gctransformer):
    if hasattr(gctransformer, '_SHADOWSTACKREF'):
        return gctransformer._SHADOWSTACKREF

    SHADOWSTACKREFPTR = lltype.Ptr(lltype.GcForwardReference())
    SHADOWSTACKREF = lltype.GcStruct('ShadowStackRef',
                                     ('base', llmemory.Address),
                                     ('top', llmemory.Address),
                                     rtti=True)
    SHADOWSTACKREFPTR.TO.become(SHADOWSTACKREF)

    def customtrace(gc, obj, callback, arg):
        obj = llmemory.cast_adr_to_ptr(obj, SHADOWSTACKREFPTR)
        walk_stack_root(gc._trace_callback, callback, arg, obj.base, obj.top,
                        is_minor=False)   # xxx optimize?

    gc = gctransformer.gcdata.gc
    assert not hasattr(gc, 'custom_trace_dispatcher')
    # ^^^ create_custom_trace_funcs() must not run before this
    gctransformer.translator.rtyper.custom_trace_funcs.append(
        (SHADOWSTACKREF, customtrace))

    def shadowstack_destructor(shadowstackref):
        base = shadowstackref.base
        shadowstackref.base    = llmemory.NULL
        shadowstackref.top     = llmemory.NULL
        llmemory.raw_free(base)

    destrptr = gctransformer.annotate_helper(shadowstack_destructor,
                                             [SHADOWSTACKREFPTR], lltype.Void)

    lltype.attachRuntimeTypeInfo(SHADOWSTACKREF, destrptr=destrptr)

    gctransformer._SHADOWSTACKREF = SHADOWSTACKREF
    return SHADOWSTACKREF
