//
//  SignalViewController.m
//  Crash
//
//  Created by stone on 2020/12/23.
//

#import "SignalViewController.h"
#include <signal.h>

@interface SignalViewController ()

@end

@implementation SignalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    catchSignalExceptions();
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self makeCrash];
}

// 闪退
- (void)makeCrash {
    NSLog(@"Signal------->Make a [BAD MEM ACCESS] now.");
    *((int *)(0x1234)) = 122;
}


#pragma mark -

static void handleSignal(int sigNum, siginfo_t* signalInfo, void* userContext) {
    NSLog(@"Signal------->Receive Signal %d. Signal number:%d. Signal code:%d. Sigal errno:%d. Sigal address:%lu" , sigNum, signalInfo->si_signo, signalInfo->si_code, signalInfo->si_errno, (uintptr_t)signalInfo->si_addr);
    
    //raise(sigNum);
}

void catchSignalExceptions(void) {
    struct sigaction action;
    action.sa_flags = SA_NODEFER | SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = handleSignal;
    
    sigaction(SIGABRT, &action, 0);
    sigaction(SIGBUS, &action, 0);
    sigaction(SIGFPE, &action, 0);
    sigaction(SIGILL, &action, 0);
    sigaction(SIGPIPE, &action, 0);
    sigaction(SIGSEGV, &action, 0);
    sigaction(SIGSYS, &action, 0);
    sigaction(SIGTRAP, &action, 0);
}



@end
