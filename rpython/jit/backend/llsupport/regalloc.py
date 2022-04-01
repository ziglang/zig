import sys
from rpython.jit.metainterp.history import Const, REF, JitCellToken
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.jit.metainterp.resoperation import rop, AbstractValue
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop

try:
    from collections import OrderedDict
except ImportError:
    OrderedDict = dict # too bad

SAVE_DEFAULT_REGS = 0
SAVE_GCREF_REGS = 2
SAVE_ALL_REGS = 1

class TempVar(AbstractValue):
    def __init__(self):
        pass

    def __repr__(self):
        return "<TempVar at %s>" % (id(self),)

class NoVariableToSpill(Exception):
    pass

class Node(object):
    def __init__(self, val, next):
        self.val = val
        self.next = next

    def __repr__(self):
        return '<Node %d %r>' % (self.val, next)

class LinkedList(object):
    def __init__(self, fm, lst=None):
        # assume the list is sorted
        if lst is not None:
            node = None
            for i in range(len(lst) - 1, -1, -1):
                item = lst[i]
                node = Node(item, node)
            self.master_node = node
        else:
            self.master_node = None
        self.fm = fm

    def append(self, size, item):
        key = self.fm.get_loc_index(item)
        if size == 2:
            self._append(key)
            self._append(key + 1)
        else:
            assert size == 1
            self._append(key)

    def _append(self, key):
        if self.master_node is None or self.master_node.val > key:
            self.master_node = Node(key, self.master_node)
        else:
            node = self.master_node
            prev_node = self.master_node
            while node and node.val < key:
                prev_node = node
                node = node.next
            prev_node.next = Node(key, node)

    @specialize.arg(1)
    def foreach(self, function, arg):
        # XXX unused?
        node = self.master_node
        while node is not None:
            function(arg, node.val)
            node = node.next

    def pop(self, size, tp, hint=-1):
        if size == 2:
            return self._pop_two(tp)   # 'hint' ignored for floats on 32-bit
        assert size == 1
        if not self.master_node:
            return None
        node = self.master_node
        #
        if hint >= 0:
            # Look for and remove the Node with the .val matching 'hint'.
            # If not found, fall back to removing the first Node.
            # Note that the loop below ignores the first Node, but
            # even if by chance it is the one with the correct .val,
            # it will be the one we remove at the end anyway.
            prev_node = node
            while prev_node.next:
                if prev_node.next.val == hint:
                    node = prev_node.next
                    prev_node.next = node.next
                    break
                prev_node = prev_node.next
            else:
                self.master_node = node.next
        else:
            self.master_node = node.next
        #
        return self.fm.frame_pos(node.val, tp)

    def _candidate(self, node):
        return (node.val & 1 == 0) and (node.val + 1 == node.next.val)

    def _pop_two(self, tp):
        node = self.master_node
        if node is None or node.next is None:
            return None
        if self._candidate(node):
            self.master_node = node.next.next
            return self.fm.frame_pos(node.val, tp)
        prev_node = node
        node = node.next
        while True:
            if node.next is None:
                return None
            if self._candidate(node):
                # pop two
                prev_node.next = node.next.next
                return self.fm.frame_pos(node.val, tp)
            node = node.next

    def len(self):
        node = self.master_node
        c = 0
        while node:
            node = node.next
            c += 1
        return c

    def __len__(self):
        """ For tests only
        """
        return self.len()

    def __repr__(self):
        if not self.master_node:
            return 'LinkedList(<empty>)'
        node = self.master_node
        l = []
        while node:
            l.append(str(node.val))
            node = node.next
        return 'LinkedList(%s)' % '->'.join(l)

class FrameManager(object):
    """ Manage frame positions

    start_free_depth is the start where we can allocate in whatever order
    we like.
    """
    def __init__(self, start_free_depth=0, freelist=None):
        self.bindings = {}
        self.current_frame_depth = start_free_depth
        self.hint_frame_pos = {}
        self.freelist = LinkedList(self, freelist)

    def get_frame_depth(self):
        return self.current_frame_depth

    def get(self, box):
        return self.bindings.get(box, None)

    def loc(self, box):
        """Return or create the frame location associated with 'box'."""
        # first check if it's already in the frame_manager
        try:
            return self.bindings[box]
        except KeyError:
            pass
        return self.get_new_loc(box)

    def get_new_loc(self, box):
        size = self.frame_size(box.type)
        hint = self.hint_frame_pos.get(box, -1)
        # frame_depth is rounded up to a multiple of 'size', assuming
        # that 'size' is a power of two.  The reason for doing so is to
        # avoid obscure issues in jump.py with stack locations that try
        # to move from position (6,7) to position (7,8).
        newloc = self.freelist.pop(size, box.type, hint)
        if newloc is None:
            #
            index = self.get_frame_depth()
            if index & 1 and size == 2:
                # we can't allocate it at odd position
                self.freelist._append(index)
                newloc = self.frame_pos(index + 1, box.type)
                self.current_frame_depth += 3
                index += 1 # for test
            else:
                newloc = self.frame_pos(index, box.type)
                self.current_frame_depth += size
            #
            if not we_are_translated():    # extra testing
                testindex = self.get_loc_index(newloc)
                assert testindex == index
            #

        self.bindings[box] = newloc
        if not we_are_translated():
            self._check_invariants()
        return newloc

    def bind(self, box, loc):
        pos = self.get_loc_index(loc)
        size = self.frame_size(box.type)
        self.current_frame_depth = max(pos + size, self.current_frame_depth)
        self.bindings[box] = loc

    def finish_binding(self):
        all = [0] * self.get_frame_depth()
        for b, loc in self.bindings.iteritems():
            size = self.frame_size(b.type)
            pos = self.get_loc_index(loc)
            for i in range(pos, pos + size):
                all[i] = 1
        self.freelist = LinkedList(self) # we don't care
        for elem in range(len(all)):
            if not all[elem]:
                self.freelist._append(elem)
        if not we_are_translated():
            self._check_invariants()

    def mark_as_free(self, box):
        try:
            loc = self.bindings[box]
        except KeyError:
            return    # already gone
        del self.bindings[box]
        size = self.frame_size(box.type)
        self.freelist.append(size, loc)
        if not we_are_translated():
            self._check_invariants()

    def _check_invariants(self):
        all = [0] * self.get_frame_depth()
        for b, loc in self.bindings.iteritems():
            size = self.frame_size(b)
            pos = self.get_loc_index(loc)
            for i in range(pos, pos + size):
                assert not all[i]
                all[i] = 1
        node = self.freelist.master_node
        while node is not None:
            assert not all[node.val]
            all[node.val] = 1
            node = node.next

    @staticmethod
    def _gather_gcroots(lst, var):
        lst.append(var)

    # abstract methods that need to be overwritten for specific assemblers

    def frame_pos(loc, type):
        raise NotImplementedError("Purely abstract")

    @staticmethod
    def frame_size(type):
        return 1

    @staticmethod
    def get_loc_index(loc):
        raise NotImplementedError("Purely abstract")

    @staticmethod
    def newloc(pos, size, tp):
        """ Reverse of get_loc_index
        """
        raise NotImplementedError("Purely abstract")

class RegisterManager(object):

    """ Class that keeps track of register allocations
    """
    box_types             = None       # or a list of acceptable types
    all_regs              = []
    no_lower_byte_regs    = []
    save_around_call_regs = []
    frame_reg             = None
    FORBID_TEMP_BOXES     = False

    def __init__(self, longevity, frame_manager=None, assembler=None):
        self.free_regs = self.all_regs[:]
        self.free_regs.reverse()
        self.longevity = longevity
        self.temp_boxes = []
        if not we_are_translated():
            self.reg_bindings = OrderedDict()
        else:
            self.reg_bindings = {}
        self.bindings_to_frame_reg = {}
        self.position = -1
        self.frame_manager = frame_manager
        self.assembler = assembler

    def is_still_alive(self, v):
        # Check if 'v' is alive at the current position.
        # Return False if the last usage is strictly before.
        return self.longevity[v].last_usage >= self.position

    def stays_alive(self, v):
        # Check if 'v' stays alive after the current position.
        # Return False if the last usage is before or at position.
        return self.longevity[v].last_usage > self.position

    def next_instruction(self, incr=1):
        self.position += incr

    def _check_type(self, v):
        if not we_are_translated() and self.box_types is not None:
            assert isinstance(v, TempVar) or v.type in self.box_types

    def possibly_free_var(self, v):
        """ If v is stored in a register and v is not used beyond the
            current position, then free it.  Must be called at some
            point for all variables that might be in registers.
        """
        self._check_type(v)
        if isinstance(v, Const):
            return
        if v not in self.longevity or self.longevity[v].last_usage <= self.position:
            if v in self.reg_bindings:
                self.free_regs.append(self.reg_bindings[v])
                del self.reg_bindings[v]
            if self.frame_manager is not None:
                self.frame_manager.mark_as_free(v)

    def possibly_free_vars(self, vars):
        """ Same as 'possibly_free_var', but for all v in vars.
        """
        for v in vars:
            self.possibly_free_var(v)

    def possibly_free_vars_for_op(self, op):
        for i in range(op.numargs()):
            self.possibly_free_var(op.getarg(i))

    def free_temp_vars(self):
        self.possibly_free_vars(self.temp_boxes)
        self.temp_boxes = []

    def _check_invariants(self):
        if not we_are_translated():
            # make sure no duplicates
            assert len(dict.fromkeys(self.reg_bindings.values())) == len(self.reg_bindings)
            rev_regs = dict.fromkeys(self.reg_bindings.values())
            for reg in self.free_regs:
                assert reg not in rev_regs
            assert len(rev_regs) + len(self.free_regs) == len(self.all_regs)
        else:
            assert len(self.reg_bindings) + len(self.free_regs) == len(self.all_regs)
        assert len(self.temp_boxes) == 0
        if self.longevity:
            for v in self.reg_bindings:
                if v not in self.longevity:
                    llop.debug_print(lltype.Void, "variable %s not in longevity\n" % v.repr({}))
                assert self.longevity[v].last_usage > self.position

    def try_allocate_reg(self, v, selected_reg=None, need_lower_byte=False):
        """ Try to allocate a register, if we have one free.
        need_lower_byte - if True, allocate one that has a lower byte reg
                          (e.g. eax has al)
        selected_reg    - if not None, force a specific register

        returns allocated register or None, if not possible.
        """
        self._check_type(v)
        if isinstance(v, TempVar):
            self.longevity[v] = Lifetime(self.position, self.position)
        # YYY all subtly similar code
        assert not isinstance(v, Const)
        if selected_reg is not None:
            res = self.reg_bindings.get(v, None)
            if res is not None:
                if res is selected_reg:
                    return res
                else:
                    del self.reg_bindings[v]
                    self.free_regs.append(res)
            if selected_reg in self.free_regs:
                self.free_regs = [reg for reg in self.free_regs
                                  if reg is not selected_reg]
                self.reg_bindings[v] = selected_reg
                return selected_reg
            return None
        if need_lower_byte:
            loc = self.reg_bindings.get(v, None)
            if loc is not None and loc not in self.no_lower_byte_regs:
                return loc
            free_regs = [reg for reg in self.free_regs
                         if reg not in self.no_lower_byte_regs]
            newloc = self.longevity.try_pick_free_reg(
                self.position, v, free_regs)
            if newloc is None:
                return None
            self.free_regs.remove(newloc)
            if loc is not None:
                self.free_regs.append(loc)
            self.reg_bindings[v] = newloc
            return newloc
        try:
            return self.reg_bindings[v]
        except KeyError:
            loc = self.longevity.try_pick_free_reg(
                self.position, v, self.free_regs)
            if loc is None:
                return None
            self.reg_bindings[v] = loc
            self.free_regs.remove(loc)
            return loc

    def _spill_var(self, forbidden_vars, selected_reg,
                   need_lower_byte=False):
        v_to_spill = self._pick_variable_to_spill(forbidden_vars,
                               selected_reg, need_lower_byte=need_lower_byte)
        loc = self.reg_bindings[v_to_spill]
        self._sync_var_to_stack(v_to_spill)
        del self.reg_bindings[v_to_spill]
        return loc

    def _pick_variable_to_spill(self, forbidden_vars, selected_reg=None,
                                need_lower_byte=False, regs=None):

        # try to spill a variable that has no further real usages, ie that only
        # appears in failargs or in a jump
        # if that doesn't exist, spill the variable that has a real_usage that
        # is the furthest away from the current position

        # YYY check for fixed variable usages
        if regs is None:
            regs = self.reg_bindings.keys()

        cur_max_use_distance = -1
        position = self.position
        candidate = None
        cur_max_age_failargs = -1
        candidate_from_failargs = None
        for next in regs:
            reg = self.reg_bindings[next]
            if next in forbidden_vars:
                continue
            if self.FORBID_TEMP_BOXES and next in self.temp_boxes:
                continue
            if selected_reg is not None:
                if reg is selected_reg:
                    return next
                else:
                    continue
            if need_lower_byte and reg in self.no_lower_byte_regs:
                continue
            lifetime = self.longevity[next]
            if lifetime.is_last_real_use_before(position):
                # this variable has no "real" use as an argument to an op left
                # it is only used in failargs, and maybe in a jump. spilling is
                # fine
                max_age = lifetime.last_usage
                if cur_max_age_failargs < max_age:
                    cur_max_age_failargs = max_age
                    candidate_from_failargs = next
            else:
                use_distance = lifetime.next_real_usage(position) - position
                if cur_max_use_distance < use_distance:
                    cur_max_use_distance = use_distance
                    candidate = next
        if candidate_from_failargs is not None:
            return candidate_from_failargs
        if candidate is not None:
            return candidate
        raise NoVariableToSpill

    def force_allocate_reg(self, v, forbidden_vars=[], selected_reg=None,
                           need_lower_byte=False):
        """ Forcibly allocate a register for the new variable v.
        It must not be used so far.  If we don't have a free register,
        spill some other variable, according to algorithm described in
        '_pick_variable_to_spill'.

        Will not spill a variable from 'forbidden_vars'.
        """
        self._check_type(v)
        if isinstance(v, TempVar):
            self.longevity[v] = Lifetime(self.position, self.position)
        loc = self.try_allocate_reg(v, selected_reg,
                                    need_lower_byte=need_lower_byte)
        if loc:
            return loc
        loc = self._spill_var(forbidden_vars, selected_reg,
                              need_lower_byte=need_lower_byte)
        prev_loc = self.reg_bindings.get(v, None)
        if prev_loc is not None:
            self.free_regs.append(prev_loc)
        self.reg_bindings[v] = loc
        return loc

    def force_allocate_frame_reg(self, v):
        """ Allocate the new variable v in the frame register."""
        self.bindings_to_frame_reg[v] = None

    def force_spill_var(self, var):
        self._sync_var_to_stack(var)
        try:
            loc = self.reg_bindings[var]
            del self.reg_bindings[var]
            self.free_regs.append(loc)
        except KeyError:
            pass   # 'var' is already not in a register

    def loc(self, box, must_exist=False):
        """ Return the location of 'box'.
        """
        self._check_type(box)
        if isinstance(box, Const):
            return self.convert_to_imm(box)
        try:
            return self.reg_bindings[box]
        except KeyError:
            if box in self.bindings_to_frame_reg:
                return self.frame_reg
            if must_exist:
                return self.frame_manager.bindings[box]
            return self.frame_manager.loc(box)

    def return_constant(self, v, forbidden_vars=[], selected_reg=None):
        """ Return the location of the constant v.  If 'selected_reg' is
        not None, it will first load its value into this register.
        """
        self._check_type(v)
        assert isinstance(v, Const)
        immloc = self.convert_to_imm(v)
        if selected_reg:
            if selected_reg in self.free_regs:
                self.assembler.regalloc_mov(immloc, selected_reg)
                return selected_reg
            loc = self._spill_var(forbidden_vars, selected_reg)
            self.free_regs.append(loc)
            self.assembler.regalloc_mov(immloc, loc)
            return loc
        return immloc

    def make_sure_var_in_reg(self, v, forbidden_vars=[], selected_reg=None,
                             need_lower_byte=False):
        """ Make sure that an already-allocated variable v is in some
        register.  Return the register.  See 'force_allocate_reg' for
        the meaning of the optional arguments.
        """
        self._check_type(v)
        if isinstance(v, Const):
            return self.return_constant(v, forbidden_vars, selected_reg)
        prev_loc = self.loc(v, must_exist=True)
        if prev_loc is self.frame_reg and selected_reg is None:
            return prev_loc
        loc = self.force_allocate_reg(v, forbidden_vars, selected_reg,
                                      need_lower_byte=need_lower_byte)
        if prev_loc is not loc:
            self.assembler.num_reloads += 1
            self.assembler.regalloc_mov(prev_loc, loc)
        return loc

    def _reallocate_from_to(self, from_v, to_v):
        reg = self.reg_bindings[from_v]
        del self.reg_bindings[from_v]
        self.reg_bindings[to_v] = reg
        return reg

    def force_result_in_reg(self, result_v, v, forbidden_vars=[]):
        """ Make sure that result is in the same register as v.
        The variable v is copied away if it's further used.  The meaning
        of 'forbidden_vars' is the same as in 'force_allocate_reg'.
        """
        self._check_type(result_v)
        self._check_type(v)
        if isinstance(v, Const):
            result_loc = self.force_allocate_reg(result_v, forbidden_vars)
            self.assembler.regalloc_mov(self.convert_to_imm(v), result_loc)
            return result_loc
        v_keeps_living = self.longevity[v].last_usage > self.position
        # there are two cases where we should allocate a new register for
        # result:
        # 1) v is itself not in a register
        # 2) v keeps on being live. if there is a free register, we need a move
        # anyway, so we can use force_allocate_reg on result_v to make sure any
        # fixed registers are used
        if (v not in self.reg_bindings or (v_keeps_living and self.free_regs)):
            v_loc = self.loc(v)
            result_loc = self.force_allocate_reg(result_v, forbidden_vars)
            self.assembler.regalloc_mov(v_loc, result_loc)
            return result_loc
        if v_keeps_living:
            # since there are no free registers, v needs to go to the stack.
            # sync it there.
            self._sync_var_to_stack(v)
        return self._reallocate_from_to(v, result_v)

    def _sync_var_to_stack(self, v):
        self.assembler.num_spills += 1
        if not self.frame_manager.get(v):
            reg = self.reg_bindings[v]
            to = self.frame_manager.loc(v)
            self.assembler.regalloc_mov(reg, to)
        else:
            self.assembler.num_spills_to_existing += 1
        # otherwise it's clean

    def _bc_spill(self, v, new_free_regs):
        self._sync_var_to_stack(v)
        new_free_regs.append(self.reg_bindings.pop(v))

    def before_call(self, force_store=[], save_all_regs=0):
        self.spill_or_move_registers_before_call(self.save_around_call_regs,
                                                 force_store, save_all_regs)

    def spill_or_move_registers_before_call(self, save_sublist,
                                            force_store=[],
                                            save_all_regs=SAVE_DEFAULT_REGS):
        """Spill or move some registers before a call.

        By default, this means: for every register in 'save_sublist',
        if there is a variable there and it survives longer than
        the current operation, then it is spilled/moved somewhere else.

        WARNING: this might do the equivalent of possibly_free_vars()
        on variables dying in the current operation.  It won't
        immediately overwrite registers that used to be occupied by
        these variables, though.  Use this function *after* you finished
        calling self.loc() or self.make_sure_var_in_reg(), i.e. when you
        know the location of all input arguments.  These locations stay
        valid, but only *if they are in self.save_around_call_regs,*
        not if they are callee-saved registers!

        'save_all_regs' can be SAVE_DEFAULT_REGS (default set of registers),
        SAVE_ALL_REGS (do that for all registers), or SAVE_GCREF_REGS (default
        + gc ptrs).

        Overview of what we do (the implementation does it differently,
        for the same result):

        * we first check the set of registers that are free: call it F.

        * possibly_free_vars() is implied for all variables (except
          the ones listed in force_store): if they don't survive past
          the current operation, they are forgotten now.  (Their
          register remain not in F, because they are typically
          arguments to the call, so they should not be overwritten by
          the next step.)

        * then for every variable that needs to be spilled/moved: if
          there is an entry in F that is acceptable, pick it and emit a
          move.  Otherwise, emit a spill.  Start doing this with the
          variables that survive the shortest time, to give them a
          better change to remain in a register---similar algo as
          _pick_variable_to_spill().

        Note: when a register is moved, it often (but not always) means
        we could have been more clever and picked a better register in
        the first place, when we did so earlier.  It is done this way
        anyway, as a local hack in this function, because on x86 CPUs
        such register-register moves are almost free.
        """
        if not we_are_translated():
            # 'save_sublist' is either the whole
            # 'self.save_around_call_regs', or a sublist thereof, and
            # then only those registers are spilled/moved.  But when
            # we move them, we never move them to other registers in
            # 'self.save_around_call_regs', to avoid ping-pong effects
            # where the same value is constantly moved around.
            for reg in save_sublist:
                assert reg in self.save_around_call_regs

        new_free_regs = []
        move_or_spill = []

        for v, reg in self.reg_bindings.items():
            max_age = self.longevity[v].last_usage
            if v not in force_store and max_age <= self.position:
                # variable dies
                del self.reg_bindings[v]
                new_free_regs.append(reg)
                continue

            if save_all_regs == SAVE_ALL_REGS:
                # we need to spill all registers in this mode
                self._bc_spill(v, new_free_regs)
                #
            elif save_all_regs == SAVE_GCREF_REGS and v.type == REF:
                # we need to spill all GC ptrs in this mode
                self._bc_spill(v, new_free_regs)
                #
            elif reg not in save_sublist:
                continue  # in a register like ebx/rbx: it is fine where it is
                #
            else:
                # this is a register like eax/rax, which needs either
                # spilling or moving.
                move_or_spill.append(v)

        if len(move_or_spill) > 0:
            free_regs = [reg for reg in self.free_regs
                             if reg not in self.save_around_call_regs]
            # chose which to spill using the usual spill heuristics
            while len(move_or_spill) > len(free_regs):
                v = self._pick_variable_to_spill([], regs=move_or_spill)
                self._bc_spill(v, new_free_regs)
                move_or_spill.remove(v)
            assert len(move_or_spill) <= len(free_regs)
            for v in move_or_spill:
                # search next good reg
                new_reg = None
                while True:
                    new_reg = self.free_regs.pop()
                    if new_reg in self.save_around_call_regs:
                        new_free_regs.append(new_reg)    # not this register...
                        continue
                    break
                assert new_reg is not None # must succeed
                reg = self.reg_bindings[v]
                self.assembler.num_moves_calls += 1
                self.assembler.regalloc_mov(reg, new_reg)
                self.reg_bindings[v] = new_reg    # change the binding
                new_free_regs.append(reg)

        # re-add registers in 'new_free_regs', but in reverse order,
        # so that the last ones (added just above, from
        # save_around_call_regs) are picked last by future '.pop()'
        while len(new_free_regs) > 0:
            self.free_regs.append(new_free_regs.pop())

    def after_call(self, v):
        """ Adjust registers according to the result of the call,
        which is in variable v.
        """
        self._check_type(v)
        r = self.call_result_location(v)
        if not we_are_translated():
            assert r not in self.reg_bindings.values()
        self.reg_bindings[v] = r
        self.free_regs = [fr for fr in self.free_regs if fr is not r]
        return r

    # abstract methods, override

    def convert_to_imm(self, c):
        """ Platform specific - convert a constant to imm
        """
        raise NotImplementedError("Abstract")

    def call_result_location(self, v):
        """ Platform specific - tell where the result of a call will
        be stored by the cpu, according to the variable type
        """
        raise NotImplementedError("Abstract")

    def get_scratch_reg(self, type, forbidden_vars=[], selected_reg=None):
        """ Platform specific - Allocates a temporary register """
        raise NotImplementedError("Abstract")

class BaseRegalloc(object):
    """ Base class on which all the backend regallocs should be based
    """
    def _set_initial_bindings(self, inputargs, looptoken):
        """ Set the bindings at the start of the loop
        """
        locs = []
        base_ofs = self.assembler.cpu.get_baseofs_of_frame_field()
        for box in inputargs:
            assert not isinstance(box, Const)
            loc = self.fm.get_new_loc(box)
            locs.append(loc.value - base_ofs)
        if looptoken.compiled_loop_token is not None:   # <- for tests
            looptoken.compiled_loop_token._ll_initial_locs = locs

    def next_op_can_accept_cc(self, operations, i):
        op = operations[i]
        next_op = operations[i + 1]
        opnum = next_op.getopnum()
        if (opnum != rop.GUARD_TRUE and opnum != rop.GUARD_FALSE
                                    and opnum != rop.COND_CALL):
            return False
        # NB: don't list COND_CALL_VALUE_I/R here, these two variants
        # of COND_CALL don't accept a cc as input
        if next_op.getarg(0) is not op:
            return False
        if self.longevity[op].last_usage > i + 1:
            return False
        if opnum != rop.COND_CALL:
            if op in operations[i + 1].getfailargs():
                return False
        else:
            if op in operations[i + 1].getarglist()[1:]:
                return False
        return True

    def locs_for_call_assembler(self, op):
        descr = op.getdescr()
        assert isinstance(descr, JitCellToken)
        if op.numargs() == 2:
            self.rm._sync_var_to_stack(op.getarg(1))
            return [self.loc(op.getarg(0)), self.fm.loc(op.getarg(1))]
        else:
            assert op.numargs() == 1
            return [self.loc(op.getarg(0))]


# ____________________________________________________________



UNDEF_POS = -42

class Lifetime(object):
    def __init__(self, definition_pos=UNDEF_POS, last_usage=UNDEF_POS):
        # all positions are indexes into the operations list

        # the position where the variable is defined
        self.definition_pos = definition_pos
        # the position where the variable is last used. this includes failargs
        # and jumps
        self.last_usage = last_usage

        # *real* usages, ie as an argument to an operation (as opposed to jump
        # arguments or in failargs)
        self.real_usages = None

        # fixed registers are positions where the variable *needs* to be in a
        # specific register
        self.fixed_positions = None

        # another Lifetime that lives after the current one that would like to
        # share a register with this variable
        self.share_with = None

        # the other lifetime will have this variable set to self.definition_pos
        self._definition_pos_shared = UNDEF_POS

    def last_usage_including_sharing(self):
        while self.share_with is not None:
            self = self.share_with
        return self.last_usage

    def is_last_real_use_before(self, position):
        if self.real_usages is None:
            return True
        return self.real_usages[-1] <= position

    def next_real_usage(self, position):
        assert position >= self.definition_pos
        # binary search
        l = self.real_usages
        low = 0
        high = len(l)
        if position >= l[-1]:
            return -1
        while low < high:
            mid = low + (high - low) // 2 # no overflow ;-)
            if position < l[mid]:
                high = mid
            else:
                low = mid + 1
        return l[low]

    def definition_pos_shared(self):
        if self._definition_pos_shared != UNDEF_POS:
            return self._definition_pos_shared
        else:
            return self.definition_pos

    def fixed_register(self, position, reg):
        """ registers a fixed register use for the variable at position in
        register reg. returns the position from where on the register should be
        held free. """
        assert self.definition_pos <= position <= self.last_usage
        if self.fixed_positions is None:
            self.fixed_positions = []
            res = self.definition_pos_shared()
        else:
            assert position > self.fixed_positions[-1][0]
            res = self.fixed_positions[-1][0]
        self.fixed_positions.append((position, reg))
        return res

    def find_fixed_register(self, opindex):
        # XXX could use binary search
        if self.fixed_positions is not None:
            for (index, reg) in self.fixed_positions:
                if opindex <= index:
                    return reg
        if self.share_with is not None:
            return self.share_with.find_fixed_register(opindex)

    def _check_invariants(self):
        assert self.definition_pos <= self.last_usage
        if self.real_usages is not None:
            assert sorted(self.real_usages) == self.real_usages
            assert self.last_usage >= max(self.real_usages)
            assert self.definition_pos < min(self.real_usages)

    def __repr__(self):
        if self.fixed_positions:
            s = " " + ", ".join("@%s in %s" % (index, reg) for (index, reg) in self.fixed_positions)
        else:
            s = ""
        return "%s:%s(%s)%s" % (self.definition_pos, self.real_usages, self.last_usage, s)


class FixedRegisterPositions(object):
    def __init__(self, register):
        self.register = register

        self.index_lifetimes = []

    def fixed_register(self, opindex, definition_pos):
        if self.index_lifetimes:
            assert opindex > self.index_lifetimes[-1][0]
        self.index_lifetimes.append((opindex, definition_pos))

    def free_until_pos(self, opindex):
        # XXX could use binary search
        for (index, definition_pos) in self.index_lifetimes:
            if opindex <= index:
                if definition_pos >= opindex:
                    return definition_pos
                else:
                    # the variable doesn't exist or didn't make it into the
                    # register despite being defined already. so we don't care
                    # too much, and can say that the variable is free until
                    # index
                    return index
        return sys.maxint

    def __repr__(self):
        return "%s: fixed at %s" % (self.register, self.index_lifetimes)


class LifetimeManager(object):
    def __init__(self, longevity):
        self.longevity = longevity

        # dictionary maps register to FixedRegisterPositions
        self.fixed_register_use = {}

    def fixed_register(self, opindex, register, var=None):
        """ Tell the LifetimeManager that variable var *must* be in register at
        operation opindex. var can be None, if no variable at all can be in
        that register at the point."""
        if var is None:
            definition_pos = opindex
        else:
            varlifetime = self.longevity[var]
            definition_pos = varlifetime.fixed_register(opindex, register)
        if register not in self.fixed_register_use:
            self.fixed_register_use[register] = FixedRegisterPositions(register)
        self.fixed_register_use[register].fixed_register(opindex, definition_pos)

    def try_use_same_register(self, v0, v1):
        """ Try to arrange things to put v0 and v1 into the same register.
        v0 must be defined before v1"""
        # only works in limited situations now
        longevityvar0 = self[v0]
        longevityvar1 = self[v1]
        assert longevityvar0.definition_pos < longevityvar1.definition_pos
        if longevityvar0.last_usage != longevityvar1.definition_pos:
            return # not supported for now
        longevityvar0.share_with = longevityvar1
        longevityvar1._definition_pos_shared = longevityvar0.definition_pos_shared()

    def longest_free_reg(self, position, free_regs):
        """ for every register in free_regs, compute how far into the future
        that register can remain free, according to the constraints of the
        fixed registers. Find the register that is free the longest. Return a
        tuple (reg, free_until_pos). """
        free_until_pos = {}
        max_free_pos = position
        best_reg = None
        # reverse for compatibility with old code
        for i in range(len(free_regs) - 1, -1, -1):
            reg = free_regs[i]
            fixed_reg_pos = self.fixed_register_use.get(reg, None)
            if fixed_reg_pos is None:
                return reg, sys.maxint
            else:
                free_until_pos = fixed_reg_pos.free_until_pos(position)
                if free_until_pos > max_free_pos:
                    best_reg = reg
                    max_free_pos = free_until_pos
        return best_reg, max_free_pos

    def free_reg_whole_lifetime(self, position, v, free_regs):
        """ try to find a register from free_regs for v at position that's
        free for the whole lifetime of v. pick the one that is blocked first
        *after* the lifetime of v. """
        longevityvar = self[v]
        min_fixed_use_after = sys.maxint
        best_reg = None
        unfixed_reg = None
        for reg in free_regs:
            fixed_reg_pos = self.fixed_register_use.get(reg, None)
            if fixed_reg_pos is None:
                unfixed_reg = reg
                continue
            use_after = fixed_reg_pos.free_until_pos(position)
            if use_after <= longevityvar.last_usage_including_sharing():
                # can't fit
                continue
            assert use_after >= longevityvar.last_usage_including_sharing()
            if use_after < min_fixed_use_after:
                best_reg = reg
                min_fixed_use_after = use_after
        if best_reg is not None:
            return best_reg

        # no fitting fixed registers. pick a non-fixed one
        return unfixed_reg

    def try_pick_free_reg(self, position, v, free_regs):
        if not free_regs:
            return None
        longevityvar = self[v]
        # check whether there is a fixed register and whether it's free
        reg = longevityvar.find_fixed_register(position)
        if reg is not None and reg in free_regs:
            return reg

        # try to find a register that's free for the whole lifetime of v
        # pick the one that is blocked first *after* the lifetime of v
        loc = self.free_reg_whole_lifetime(position, v, free_regs)
        if loc is not None:
            return loc

        # can't fit v completely, so pick the register that's free the longest
        loc, free_until = self.longest_free_reg(position, free_regs)
        if loc is not None:
            return loc
        # YYY could check whether it's best to spill v here, but hard
        # to do in the current system
        return None

    def __contains__(self, var):
        return var in self.longevity

    def __getitem__(self, var):
        return self.longevity[var]

    def __setitem__(self, var, val):
        self.longevity[var] = val

def compute_vars_longevity(inputargs, operations):
    # compute a dictionary that maps variables to Lifetime information
    # if a variable is not in the dictionary, it's operation is dead because
    # it's side-effect-free and the result is unused
    longevity = {}
    for i in range(len(operations)-1, -1, -1):
        op = operations[i]
        opnum = op.getopnum()
        if op not in longevity:
            if op.type != 'v' and rop.has_no_side_effect(opnum):
                # result not used, operation has no side-effect, it can be
                # removed
                continue
            longevity[op] = Lifetime(definition_pos=i, last_usage=i)
        else:
            longevity[op].definition_pos = i
        for j in range(op.numargs()):
            arg = op.getarg(j)
            if isinstance(arg, Const):
                continue
            if arg not in longevity:
                lifetime = longevity[arg] = Lifetime(last_usage=i)
            else:
                lifetime = longevity[arg]
            if opnum != rop.JUMP and opnum != rop.LABEL:
                if lifetime.real_usages is None:
                    lifetime.real_usages = []
                lifetime.real_usages.append(i)
        if rop.is_guard(op.opnum):
            for arg in op.getfailargs():
                if arg is None: # hole
                    continue
                assert not isinstance(arg, Const)
                if arg not in longevity:
                    longevity[arg] = Lifetime(last_usage=i)
    #
    for arg in inputargs:
        assert not isinstance(arg, Const)
        if arg not in longevity:
            longevity[arg] = Lifetime(-1, -1)

    if not we_are_translated():
        produced = {}
        for arg in inputargs:
            produced[arg] = None
        for op in operations:
            for arg in op.getarglist():
                if not isinstance(arg, Const):
                    assert arg in produced
            produced[op] = None
    for lifetime in longevity.itervalues():
        if lifetime.real_usages is not None:
            lifetime.real_usages.reverse()
        if not we_are_translated():
            lifetime._check_invariants()

    return LifetimeManager(longevity)

# YYY unused?
def is_comparison_or_ovf_op(opnum):
    return rop.is_comparison(opnum) or rop.is_ovf(opnum)

def valid_addressing_size(size):
    return size == 1 or size == 2 or size == 4 or size == 8

def get_scale(size):
    assert valid_addressing_size(size)
    if size < 4:
        return size - 1         # 1, 2 => 0, 1
    else:
        return (size >> 2) + 1  # 4, 8 => 2, 3


def not_implemented(msg):
    msg = '[llsupport/regalloc] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)
