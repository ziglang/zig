from rpython.flowspace.model import Constant, Variable, mkentrymap
from rpython.tool.ansi_print import AnsiLogger

log = AnsiLogger("backendopt")


def is_chain_block(block, first=False):
    if len(block.operations) == 0:
        return False
    if len(block.operations) > 1 and not first:
        return False
    op = block.operations[-1]
    if (op.opname not in ('int_eq', 'uint_eq', 'char_eq', 'unichar_eq')
        # note: 'llong_eq', 'ullong_eq' have been removed, as it's not
        # strictly C-compliant to do a switch() on a long long.  It also
        # crashes the JIT, and it's very very rare anyway.
        or op.result != block.exitswitch):
        return False
    if isinstance(op.args[0], Variable) and isinstance(op.args[1], Variable):
        return False
    if isinstance(op.args[0], Constant) and isinstance(op.args[1], Constant):
        return False
    # check that the constant is hashable (ie not a symbolic)
    try:
        if isinstance(op.args[0], Constant):
            hash(op.args[0].value)
        else:
            hash(op.args[1].value)
    except TypeError:
        return False
    return True

def merge_chain(chain, checkvar, varmap, graph):
    def get_new_arg(var_or_const):
        if isinstance(var_or_const, Constant):
            return var_or_const
        return varmap[var_or_const]
    firstblock, case = chain[0]
    firstblock.operations = firstblock.operations[:-1]
    firstblock.exitswitch = checkvar
    values = {}
    links = []
    default = chain[-1][0].exits[0]
    default.exitcase = "default"
    default.llexitcase = None
    default.args = [get_new_arg(arg) for arg in default.args]
    for block, case in chain:
        if case.value in values:
            # - ignore silently: it occurs in platform-dependent
            #   chains of tests, for example
            #log.WARNING("unreachable code with value %r in graph %s" % (
            #            case.value, graph))
            continue
        values[case.value] = True
        link = block.exits[1]
        links.append(link)
        link.exitcase = case.value
        link.llexitcase = case.value
        link.args = [get_new_arg(arg) for arg in link.args]
    links.append(default)
    firstblock.recloseblock(*links)

def merge_if_blocks_once(graph):
    """Convert consecutive blocks that all compare a variable (of Primitive type)
    with a constant into one block with multiple exits. The backends can in
    turn output this block as a switch statement.
    """
    candidates = [block for block in graph.iterblocks()
                      if is_chain_block(block, first=True)]
    entrymap = mkentrymap(graph)
    for firstblock in candidates:
        chain = []
        checkvars = []
        varmap = {}  # {var in a block in the chain: var in the first block}
        for var in firstblock.exits[0].args:
            varmap[var] = var
        for var in firstblock.exits[1].args:
            varmap[var] = var
        def add_to_varmap(var, newvar):
            if isinstance(var, Variable):
                varmap[newvar] = varmap[var]
            else:
                varmap[newvar] = var
        current = firstblock
        while 1:
            # check whether the chain can be extended with the block that follows the
            # False link
            checkvar = [var for var in current.operations[-1].args
                           if isinstance(var, Variable)][0]
            resvar = current.operations[-1].result
            case = [var for var in current.operations[-1].args
                       if isinstance(var, Constant)][0]
            checkvars.append(checkvar)
            falseexit = current.exits[0]
            assert not falseexit.exitcase
            trueexit = current.exits[1]
            targetblock = falseexit.target
            # if the result of the check is also passed through the link, we
            # cannot construct the chain
            if resvar in falseexit.args or resvar in trueexit.args:
                break
            chain.append((current, case))
            if len(entrymap[targetblock]) != 1:
                break
            if checkvar not in falseexit.args:
                break
            newcheckvar = targetblock.inputargs[falseexit.args.index(checkvar)]
            if not is_chain_block(targetblock):
                break
            if newcheckvar not in targetblock.operations[0].args:
                break
            for i, var in enumerate(trueexit.args):
                add_to_varmap(var, trueexit.target.inputargs[i])
            for i, var in enumerate(falseexit.args):
                add_to_varmap(var, falseexit.target.inputargs[i])
            current = targetblock
        if len(chain) > 1:
            break
    else:
        return False
    merge_chain(chain, checkvars[0], varmap, graph)
    return True

def merge_if_blocks(graph, verbose=True):
    merge = False
    while merge_if_blocks_once(graph):
        merge = True
    if merge:
        if verbose:
            log("merging blocks in %s" % (graph.name, ))
        else:
            log.dot()
