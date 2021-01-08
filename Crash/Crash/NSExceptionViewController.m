//
//  NSExceptionViewController.m
//  Crash
//
//  Created by stone on 2020/12/24.
//

#import "NSExceptionViewController.h"

@interface NSExceptionViewController ()

@end

@implementation NSExceptionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    catchNSExceptions();
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self makeCrash];
}

// 闪退
- (void)makeCrash {
    NSString *sring;
    NSMutableArray *array = [NSMutableArray array];
    [array addObject:sring];
}


void catchNSExceptions(void) {
    NSSetUncaughtExceptionHandler(&handleException);
}

static void handleException(NSException* exception) {
    NSLog(@"NSExceptions------->Trapped exception %@", exception);
}

@end
