//
//  ViewController.m
//  Crash
//
//  Created by stone on 2020/12/22.
//

#import "ViewController.h"
#import "MachViewController.h"
#import "SignalViewController.h"
#import "NSExceptionViewController.h"


#include "CTest.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    c_catchCPPExceptions();
//    catchMachExceptions();
//    catchSignalExceptions();
//    catchNSExceptions();
}


// 闪退
- (void)makeCrash1 {
    NSLog(@"------->Make a [BAD MEM ACCESS] now.");
    *((int *)(0x1234)) = 122;
}

// 闪退
- (void)makeCrash2 {
    NSLog(@"------->插入nil");
    NSString *sring;
    NSMutableArray *array = [NSMutableArray array];
    [array addObject:sring];
}

- (void)makeCrash3 {
    NSLog(@"------->数组越界");
    NSMutableArray *array = [NSMutableArray array];
    NSLog(@"%@", array[1]);
}

- (void)makeCrash4 {
    NSLog(@"------->c++野指针");
    c_crash();
}

- (IBAction)crash:(id)sender {
    [self makeCrash4];
}

- (IBAction)mach:(id)sender {
    MachViewController *vc = [[MachViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)Signal:(id)sender {
    SignalViewController *vc = [[SignalViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];

}

- (IBAction)NSException:(id)sender {
    NSExceptionViewController *vc = [[NSExceptionViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
