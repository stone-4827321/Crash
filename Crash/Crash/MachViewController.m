//
//  MachViewController.m
//  Crash
//
//  Created by stone on 2020/12/22.
//

#import "MachViewController.h"
#include <mach/mach.h>
#include <pthread.h>


@interface MachViewController ()

@property (nonatomic) mach_port_t server_port;


@end

@implementation MachViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    catchMachExceptions();
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self makeCrash];
}

// 闪退
- (void)makeCrash {
    NSLog(@"Mach------->Make a [BAD MEM ACCESS] now.");
    *((int *)(0x1234)) = 122;
}

#pragma mark -

typedef struct
{
    /** Mach header. */
    mach_msg_header_t          header;

    // Start of the kernel processed data.

    /** Basic message body data. */
    mach_msg_body_t            body;

    /** The thread that raised the exception. */
    mach_msg_port_descriptor_t thread;

    /** The task that raised the exception. */
    mach_msg_port_descriptor_t task;

    // End of the kernel processed data.

    /** Network Data Representation. */
    NDR_record_t               NDR;

    /** The exception that was raised. */
    exception_type_t           exception;

    /** The number of codes. */
    mach_msg_type_number_t     codeCount;

    /** Exception code and subcode. */
    // ux_exception.c defines this as mach_exception_data_t for some reason.
    // But it's not actually a pointer; it's an embedded array.
    // On 32-bit systems, only the lower 32 bits of the code and subcode
    // are valid.
    mach_exception_data_type_t code[0];

    /** Padding to avoid RCV_TOO_LARGE. */
    char                       padding[512];
} MachExceptionMessage;

typedef struct
{
    /** Mach header. */
    mach_msg_header_t header;

    /** Network Data Representation. */
    NDR_record_t      NDR;

    /** Return code. */
    kern_return_t     returnCode;
} MachReplyMessage;

mach_port_t g_exceptionPort;

static void* handleMachExceptions(void *arg) {
    NSLog(@"Mach------->handle mach exception");
    MachExceptionMessage exceptionMessage = {{0}};
    kern_return_t kr;
    for(;;)
    {
        NSLog(@"Mach------->begin recv mach msg");
        // 接收消息，否则一直处于休眠状态
        kr = mach_msg(&exceptionMessage.header,
                      MACH_RCV_MSG | MACH_RCV_LARGE,
                      0,
                      sizeof(exceptionMessage),
                      g_exceptionPort,
                      MACH_MSG_TIMEOUT_NONE,
                      MACH_PORT_NULL);
        NSLog(@"Mach------->recv mach msg");
        if(kr == KERN_SUCCESS) {
            NSLog(@"Mach------->recv mach msg success");
            break;
        }
        
        // 如果mach_msg返回失败，则通过for循环重新调用
        NSLog(@"Mach------->mach_msg: %s", mach_error_string(kr));
    }
    
    NSLog(@"Mach------->Receive message %d. Exception: %d. Code: %lld/%lld. Thread:%u" , exceptionMessage.header.msgh_id, exceptionMessage.exception, exceptionMessage.code[0], exceptionMessage.code[1], exceptionMessage.thread.name);
    
    // 回复消息才能让应用闪退
    MachReplyMessage replyMessage = {{0}};
    NSLog(@"Mach------->Replying to mach exception message.");
    replyMessage.header = exceptionMessage.header;
    replyMessage.NDR = exceptionMessage.NDR;
    replyMessage.returnCode = KERN_FAILURE;

    kr = mach_msg(&replyMessage.header,
                  MACH_SEND_MSG,
                  sizeof(replyMessage),
                  0,
                  MACH_PORT_NULL,
                  MACH_MSG_TIMEOUT_NONE,
                  MACH_PORT_NULL);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Mach------->Fail to reply exception msg: %s", mach_error_string(kr));
    }
    
    return NULL;
}

void catchMachExceptions(void) {
    kern_return_t kr = 0;
    
    // 创建异常处理端口
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &g_exceptionPort);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Mach------->Fail to allocate exception port: %s", mach_error_string(kr));
        return;
    }
    
    // 申请接收消息权限
    kr = mach_port_insert_right(mach_task_self(), g_exceptionPort, g_exceptionPort, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Mach------->Fail to insert right: %s", mach_error_string(kr));
        return;
    }
    
    // 当前进程注册异常端口来接收Mach异常消息
    exception_mask_t excMask = EXC_MASK_BAD_ACCESS |
                               EXC_MASK_BAD_INSTRUCTION |
                               EXC_MASK_ARITHMETIC |
                               EXC_MASK_SOFTWARE |
                               EXC_MASK_BREAKPOINT;
    kr = thread_set_exception_ports(mach_thread_self(), excMask, g_exceptionPort, EXCEPTION_DEFAULT, MACHINE_THREAD_STATE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Mach------->Fail to  set exception: %s", mach_error_string(kr));
        return;
    }
    
    // 创建异常处理线程来接收Mach异常消息
    pthread_t thread;
    pthread_create(&thread, NULL, handleMachExceptions, NULL);
}

@end

