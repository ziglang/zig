int downwards_0(void)
{
    goto l;
    return 1;
l:
    return 0;
}

int downwards_1(void)
{
    int ret = 0;
    goto l;
    ret = 1;
l:
    return ret;
}

int upwards(void)
{
    int ret = 1;
l:
    if (ret != 1)
    {
        return ret;
    }

    ret--;
    goto l;
}

int two_labels(void)
{
    int ret = 1;
    goto l;
    return 1;
k:
    return ret;
l:
    ret = 0;
    goto k;
}

int simple_scope_0(void)
{
    goto l;
    return 1;
    {
        return 1;
    l:
        return 0;
    }
    return 1;
}

int simple_scope_1(void)
{
    {
        goto l;
        return 1;
    }
    return 1;
l:
    return 0;
}

int into_if_0(void)
{
    int b = 0;
    goto l;
    return 1;
    if (b)
    {
        return 1;
    l:
        return 0;
    }
    return 1;
}

int into_if_1(void)
{
    int b = 0;
    if (b)
    {
        return 1;
    l:
        return 0;
    }
    goto l;
}

int out_of_if_0(void)
{
    if (1)
    {
        goto l;
        return 1;
    }
    return 1;
l:
    return 0;
}

int out_of_if_1(void)
{
    goto l;
k:
    return 0;
l:
    if (1)
    {
        goto k;
        return 1;
    }
    return 1;
}

int in_and_out_of_if(void)
{
    if (1)
    {
        goto l;
    k:
        return 0;
    }
    return 1;
l:
    goto k;
    return 1;
}

int many_labels_and_gotos(void)
{
    int i = 1;
    int j = 1;
l:
    if (i)
    {
        goto k;
    }
    if (j)
    {
        j = 0;
        goto k;
    }

    return i || j;

k:
    if (j)
    {
        i = 0;
        goto l;
    }
    goto l;

    return 1;
}

int into_else(void)
{
    int i = 1;
    goto l;
    if (i)
        return 1;
    else
    l:
        return 0;
    return 1;
}

int if_to_else(void)
{
    int ret = 1;
    if (ret = 0, 1)
    {
        goto l;
        return 1;
    }
    else
    {
        return 1;
    l:
        return ret;
    }
    return 1;
}

int else_to_if(void)
{
    if (0)
    {
        return 1;
    l:
        return 0;
    }
    else
    {
        goto l;
        return 1;
    }
    return 1;
}

int if_cond(void)
{
    int ret = 0;
    goto l;
    if (ret = 1)
    {
        return 1;
    l:
        return ret;
    }
    return 1;
}

int else_cond(void)
{
    int ret = 0;
    goto l;
    if (ret = 1, 0)
    {
        return 1;
    }
    else
    {
        return 1;
    l:
        return ret;
    }
    return 1;
}

int into_while_loop_0(void)
{
    int ret = 0;
    goto l;
    while (ret = 1, 0)
    {
        return 1;
    l:
        return 0;
    }
    return 1;
}

int into_while_loop_1(void)
{
    while (0)
    {
        return 1;
    l:
        return 0;
    }
    goto l;
    return 1;
}

int out_of_while_loop_0(void)
{
    while (1)
    {
        goto l;
        return 1;
    }
    return 1;
l:
    return 0;
}

int out_of_while_loop_1(void)
{
    int i = 1;
l:
    while (i)
    {
        i = 0;
        goto l;
        return 1;
    }
    return 0;
}

int into_for_loop_0(void)
{
    int ret = 0;
    goto l;
    for (ret = 1; ret = 1, 0; ret = 1)
    {
        return 1;
    l:
        return ret;
    }
    return 1;
}

int into_for_loop_1(void)
{
    int ret = 2;
    for (ret = 2; ret = 1, 0; ret = 2)
    {
        return 1;
    l:
        return ret;
    }

    if (ret != 1)
    {
        return 1;
    }
    ret = 0;

    goto l;
    return 1;
}

int out_of_for_loop_0(void)
{
    int ret0 = 1;
    int ret1 = 1;
    int ret2 = 0;
    for (ret0 = 0; ret1 = 0, 1; ret2 = 1)
    {
        goto l;
        return 1;
    }
    return 1;
l:
    return ret0 || ret1 || ret2;
}

int out_of_for_loop_1(void)
{
    int i = 1;
    int ret0 = 1;
    int ret1 = 1;
    int ret2 = 0;
l:
    for (ret0 = 0; ret1 = 0, i; ret2 = 1)
    {
        i = 0;
        goto l;
        return 1;
    }
    return i == 0 && (ret0 || ret1 || ret2);
}

int into_switch_case(void)
{
    goto l;
    switch (0)
    {
        return 1;
    case 1:
    l:
        return 0;
    default:
        return 1;
    }
    return 1;
}

int into_switch_case_not_at_the_beginning(void)
{
    int ret = 0;
    goto l;
    switch (0)
    {
        return 1;
    case 1:
        ret = 1;
    l:
        return ret;
    default:
        return 1;
    }
    return 1;
}

int into_switch_between_cases(void)
{
    int ret = 0;
    goto l;
    switch (0)
    {
        return 1;
    case 1:
        return 1;
    l:
        return ret;
    default:
        return 1;
    }
    return 1;
}

int into_switch_start(void)
{
    goto l;
    switch (0)
    {
    l:
        return 0;
    default:
        return 1;
    }
    return 1;
}

int into_switch_default(void)
{
    goto l;
    switch (0)
    {
    case 0:
        return 1;
    default:
    l:
        return 0;
    }
    return 1;
}

int switch_from_case_to_case(void)
{
    switch (0)
    {
    case 0:
        goto l;
        return 1;
    case 1:
    l:
        return 0;
    default:
        return 1;
    }
    return 1;
}

int switch_from_case_to_same_case(void)
{
    int i = 1;
    switch (0)
    {
    case 0:
    l:;
        if (i)
        {
            i = 0;
            goto l;
        }
        return 0;
    default:
        return 1;
    }
    return 1;
}

int switch_from_case_to_case_not_at_the_beginning(void)
{
    int ret = 1;
    switch (0)
    {
    case 0:
        ret = 0;
        goto l;
        return 1;
    case 1:
        ret = 1;
    l:
        return ret;
    default:
        return 1;
    }
    return 1;
}

int switch_from_case_to_between_cases(void)
{
    int ret = 1;
    switch (0)
    {
    case 0:
        ret = 0;
        goto l;
        return 1;
    case 1:
        return 1;
    l:
        return ret;
    default:
        return 1;
    }
    return 1;
}

int switch_from_case_to_start(void)
{
    int ret = 1;
    switch (0)
    {
    l:
        return ret;
    case 0:
        ret = 0;
        goto l;
        return 1;
    default:
        return 1;
    }
    return 1;
}

int switch_from_case_to_default(void)
{
    switch (0)
    {
    case 0:
        goto l;
        return 1;
    default:
    l:
        return 0;
    }
    return 1;
}

int gcd(void)
{
    int a = 48;
    int b = 18;

loop:
    if (a == b)
        goto finish;

    if (a < b)
        goto b_minus_a;

    a = a - b;
    goto loop;

b_minus_a:
    b = b - a;

    goto loop;

finish:

    return a == 6 ? 0 : 1;
}

int main()
{
    return downwards_0() ||
           downwards_1() ||
           upwards() ||
           two_labels() ||
           simple_scope_0() ||
           simple_scope_1() ||
           into_if_0() ||
           into_if_1() ||
           out_of_if_0() ||
           out_of_if_1() ||
           in_and_out_of_if() ||
           many_labels_and_gotos() ||
           into_else() ||
           if_to_else() ||
           else_to_if() ||
           if_cond() ||
           else_cond() ||
           into_while_loop_0() ||
           into_while_loop_1() ||
           out_of_while_loop_0() ||
           out_of_while_loop_1() ||
           into_for_loop_0() ||
           into_for_loop_1() ||
           out_of_for_loop_0() ||
           out_of_for_loop_1() ||
           into_switch_case() ||
           into_switch_case_not_at_the_beginning() ||
           into_switch_between_cases() ||
           into_switch_start() ||
           into_switch_default() ||
           switch_from_case_to_case() ||
           switch_from_case_to_same_case() ||
           switch_from_case_to_case_not_at_the_beginning() ||
           switch_from_case_to_between_cases() ||
           switch_from_case_to_start() ||
           switch_from_case_to_default() ||
           gcd();
}

// run-translated-c
// c_frontend=clang
