import sys

fil = open(sys.argv[1], 'r')
sel_arch = sys.argv[2]

template_call = "syscall{syscall_arg_count}({syscall_args})"
template_basic = """pub fn {fn_name}{fn_params} {fn_return} {{
    return {expr};
}}
"""
template_noreturn = """pub fn {fn_name}{fn_params} {fn_return} {{
    _ = {expr};
    unreachable;
}}
"""

def is_ptr_type(ty):
    return ty[0] in {'*', '?'} or ty.startswith('[*]')

def gen_return_cast_expr(expr_ty, expr):
    if expr_ty == 'usize':
        return expr
    elif expr_ty in ['i8', 'i16', 'i32']:
        return '@bitCast({}, @truncate(u{}, {}))'.format(expr_ty, expr_ty[1:], expr)
    elif expr_ty in ['u8', 'u16', 'u32']:
        return '@truncate({}, {})'.format(expr_ty, expr)
    else:
        print('Cannot handle return type \'{}\''.format(expr_ty))
        sys.exit(1)

def gen_param_cast_expr(expr_ty, expr, split_64):
    if is_ptr_type(expr_ty):
        return ['@ptrToInt({})'.format(expr)]
    elif expr_ty in ['i8','i16','i32']:
        return ['@bitCast(usize, isize({}))'.format(expr)]
    elif expr_ty in ['u8','u16','u32']:
        return ['usize({})'.format(expr)]
    elif expr_ty in ['i64', 'u64']:
        # Split the parameter into a hi/lo pair
        if split_64:
            if expr_ty[0] == 'i':
                return ['@truncate(usize, @bitCast(u64, {}) >> 32)'.format(expr),
                        '@truncate(usize, @bitCast(u64, {}))'.format(expr)]
            else:
                return ['@truncate(usize, {} >> 32)'.format(expr),
                        '@truncate(usize, {})'.format(expr)]
        else:
            if expr_ty[0] == 'i':
                return ['@bitCast(usize, {})'.format(expr)]
            else:
                return ['usize({})'.format(expr)]
    elif expr_ty == 'isize':
        return ['@bitCast(usize, {})'.format(expr)]
    elif expr_ty == 'usize':
        return [expr]
    else:
        print('Cannot handle param type \'{}\''.format(expr_ty))
        sys.exit(1)

print('''use @import("{}.zig");
const std = @import("../../std.zig");
const linux = std.os.linux;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const sigset_t = linux.sigset_t;
'''.format(sel_arch))

for line in fil:
    line = line.strip()

    if len(line) == 0 or line[0] == '#':
        continue

    chunks = line.split('\t')

    if len(chunks) < 5:
        print('malformed entry:')
        print(line)
        sys.exit(1)

    stub_name = chunks[0]
    arch      = chunks[1]
    syscall   = chunks[2]
    params    = chunks[3]
    return_ty = chunks[4]
    flags     = chunks[5] if len(chunks) == 6 else ''

    if arch.startswith('any'):
        if len(arch) > 3 and ('64' in arch) != ('64' in sel_arch):
            continue
    elif arch != sel_arch:
        continue

    args = []

    lpar = params.index('(')
    rpar = params.index(')')
    param_list_inner = params[lpar+1:rpar]

    for param in param_list_inner.split(','):
        if len(param) == 0:
            continue

        param_name = param.split(':')[0].strip()
        param_type = param.split(':')[1].strip()

        expr = gen_param_cast_expr(param_type, param_name, True)

        if len(expr) > 1 and len(args) & 1 != 0:
            args.append('0')

        args.extend(expr)

    has_return_ty = return_ty != 'noreturn'

    call_str = template_call.format(**{
        'syscall_arg_count': len(args),
        'syscall_args': ', '.join(['SYS_' + syscall] + args)
        })

    template = template_basic if has_return_ty else template_noreturn

    body = template.format(**{
        'fn_name': stub_name,
        'fn_params': params,
        'fn_return': return_ty,
        'expr': gen_return_cast_expr(return_ty, call_str) if has_return_ty else call_str
        })

    print(body)
