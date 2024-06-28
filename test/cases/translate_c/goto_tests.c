void cleanup1(void);
void cleanup2(void);
void cleanup3(void);

int doSth(void);
void doSth2(void);
int getState(void);
int getIters(void);

void foo(void)
{

    if (doSth() != 0)
    {
        goto cleanup_3;
    }

loop:;
    int state = getState();

    switch (state)
    {
    label:
        if (doSth() != 0)
            goto cleanup_2;
    case 0:
        if (doSth() != 0)
        {
            goto cleanup_3;
        }
        break;
    case 1:;
        int iters = getIters();
        for (int i = 0; i < iters; i++)
        {
        label2:
            doSth2();
        }

        goto label;
    case 2:
        iters = 2048;
        goto label2;
    }

    goto loop;

a_unused_label:
cleanup_1:
    cleanup1();
cleanup_2:
    cleanup2();
cleanup_3:
    cleanup3();
}
// translate-c
// target=x86_64-linux
// c_frontend=clang
//
// pub export fn foo() void {
//     var goto_label: bool = false;
//     var goto_label2: bool = false;
//     var goto_cleanup_3: bool = false;
//     var goto_loop: bool = false;
//     var goto_cleanup_2: bool = false;
//     if (!(goto_cleanup_2 or (goto_loop or (goto_cleanup_3 or goto_cleanup_3)))) {
//         blk: {
//             if (doSth() != @as(c_int, 0)) {
//                 {
//                     goto_cleanup_3 = true;
//                     break :blk;
//                 }
//             }
//         }
//     }
//     var state: c_int = undefined;
//     _ = &state;
//     while (true) blk: {
//         if (!(goto_cleanup_2 or (goto_cleanup_3 or goto_cleanup_3))) {
//             {
//                 goto_loop = false;
//                 {}
//             }
//             state = getState();
//             blk_1: {
//                 {
//                     var iters: c_int = undefined;
//                     _ = &iters;
//                     while (true) blk_2: {
//                         switch (@as(enum {
//                             goto_case_1,
//                             case_1,
//                             case_2,
//                             goto_case_2,
//                             case_4,
//                         }, if (goto_label2) .goto_case_2 else if (goto_label) .goto_case_1 else switch (state) {
//                             @as(c_int, 0) => .case_1,
//                             @as(c_int, 1) => .case_2,
//                             @as(c_int, 2) => .case_4,
//                             else => break,
//                         })) {
//                             .goto_case_1 => {
//                                 {
//                                     goto_label = false;
//                                     if (doSth() != @as(c_int, 0)) {
//                                         {
//                                             goto_cleanup_2 = true;
//                                             break :blk_1;
//                                         }
//                                     }
//                                 }
//                                 if (doSth() != @as(c_int, 0)) {
//                                     {
//                                         goto_cleanup_3 = true;
//                                         break :blk_1;
//                                     }
//                                 }
//                                 break;
//                             },
//                             .case_1 => {
//                                 if (doSth() != @as(c_int, 0)) {
//                                     {
//                                         goto_cleanup_3 = true;
//                                         break :blk_1;
//                                     }
//                                 }
//                                 break;
//                             },
//                             .case_2 => {
//                                 {}
//                                 iters = getIters();
//                                 {
//                                     var i: c_int = undefined;
//                                     _ = &i;
//                                     if (!goto_label2) {
//                                         i = 0;
//                                     }
//                                     while (goto_label2 or (i < iters)) : (i += 1) {
//                                         {
//                                             goto_label2 = false;
//                                             doSth2();
//                                         }
//                                     }
//                                 }
//                                 {
//                                     goto_label = true;
//                                     break :blk_2;
//                                 }
//                                 iters = 2048;
//                                 {
//                                     goto_label2 = true;
//                                     break :blk_2;
//                                 }
//                             },
//                             .goto_case_2 => {
//                                 {
//                                     var i: c_int = undefined;
//                                     _ = &i;
//                                     if (!goto_label2) {
//                                         i = 0;
//                                     }
//                                     while (goto_label2 or (i < iters)) : (i += 1) {
//                                         {
//                                             goto_label2 = false;
//                                             doSth2();
//                                         }
//                                     }
//                                 }
//                                 {
//                                     goto_label = true;
//                                     break :blk_2;
//                                 }
//                                 iters = 2048;
//                                 {
//                                     goto_label2 = true;
//                                     break :blk_2;
//                                 }
//                             },
//                             .case_4 => {
//                                 iters = 2048;
//                                 {
//                                     goto_label2 = true;
//                                     break :blk_2;
//                                 }
//                             },
//                         }
//                         break;
//                     }
//                 }
//             }
//         }
//         if (!(goto_cleanup_2 or (goto_cleanup_3 or goto_cleanup_3))) {
//             {
//                 goto_loop = true;
//                 break :blk;
//             }
//         }
//         break;
//     }
//     if (!(goto_cleanup_2 or (goto_cleanup_3 or goto_cleanup_3))) {
//         {
//             {
//                 cleanup1();
//             }
//         }
//     }
//     if (!(goto_cleanup_3 or goto_cleanup_3)) {
//         {
//             goto_cleanup_2 = false;
//             cleanup2();
//         }
//     }
//     {
//         goto_cleanup_3 = false;
//         cleanup3();
//     }
// }
