# 异常

- **软件异常**：软件异常主要来源于两个 API 的调用 `kill()` 、 `pthread_kill()`， 如 `NSException` 未捕获、 `abort()` 函数调用等，都属于这种情况。

- **硬件异常**：硬件产生的信号始于处理器 trap，处理器 trap 是平台相关的。比如野指针崩溃大部分是硬件异常。

- **Mach异常**：最底层的内核级异常。

- **UNIX信号**：如 SIGBUS、SIGSEGV、SIGABRT、SIGKILL 等信号。

  ![](https://tva1.sinaimg.cn/large/0081Kckwgy1glvqbc9chmj30ho0dsjrn.jpg)

  | Mach 异常           | UNIX 信号 | 信号值 | 简介         | 案例                                                         |
  | ------------------- | --------- | ------ | ------------ | ------------------------------------------------------------ |
  | EXC_BAD_ACCESS      | SIGBUS    | 10     | 总线错误     | 1.试图访问当时无法返回数据的内存；2.试图访问没有正确对齐的内存 |
  | EXC_BAD_ACCESS      | SIGSEGV   | 11     | 段错误       | 2.试图访问未映射的内存；2.试图使用受保护的有效内存           |
  | EXC_BAD_INSTRUCTION | SIGILL    | 4      | 非法指令     | 1.非法或未定义的指令或操作数                                 |
  | EXC_ARITHMETIC      | SIGFPE    | 8      | 算术运算出错 | 1.除以0或取余0，及发生数据溢出导致的除以0或取余0；2.浮点错误 |
  | EXC_CRASH           | SIGSYS    | 12     | 系统调用异常 |                                                              |
  | EXC_CRASH           | SIGPIPE   | 13     | 管道破裂     | 1.socket 通讯时，如读进程终止时写进程继续写入；2.根据苹果的文档，可以忽略这个信号 |
  | EXC_CRASH           | SIGABRT   | 6      | abort()      | 1.遇到未捕获的Objective-C或C ++异常                          |
  | EXC_CRASH           | SIGKILL   | 9      | 系统中止     |                                                              |
  | EXC_BREAKPOINT      | SIGTRAP   | 5      | 断点         | 1.__builtin_trap() 函数调用                                  |
  | EXC_GUARD           |           |        | 文件句柄错误 | 1.试图关闭一个内核的句柄                                     |
  | EXC_RESOURCE        |           |        | 资源受限     | 1.线程调用太频繁，子线程每秒被唤醒次数超过150                |

  - SIGKILL 表示系统中止进程。崩溃报告会包含代表中止原因的编码：
    - 0x8badf00d：ate bad food，系统监视程序由中止无响应应用。
    - 0xc00010ff：cool off，系统由于过热保护中止应用，通常与特定的手机和环境有关。
    - 0xdead10cc：dead lock，系统中止在挂起期间一直保持文件锁或 SQLite 数据库锁的应用。
    - 0xbaadca11：bad all，系统由于应用在响应PushKit通知时无法报告 CallKit 呼叫而中止它。

- 无论是硬件产生的信号，还是软件产生的信号，都会走到 `act_set_astbsd()` 进而唤醒收到信号的进程的某一个线程。这个机制就给自身进程内捕获 Crash 提供了可能性：**通过拦截 “UNIX信号” 或 “Mach异常” 来捕获崩溃**。

# 符号化

- 当应用发生闪退时，产生的奔溃日志中的堆栈信息一般是一串内存地址，很难从中获取有用的信息协助排查问题，如闪退发生的代码行。

  ```c
  0 CoreFoundation	0x000000019fa4986c 0x000000019f924000 + 1202284
  1 libobjc.A.dylib	0x00000001b49b8c50 objc_exception_throw + 60
  2 CoreFoundation	0x000000019f948904 0x000000019f924000 + 149764
  3 K3InteSDK	0x000000010289e5c0 +[NSObject(K3Add) crash] + 136
  4 K3InteSDK	0x0000000102765508 +[K3InteSDK updateRole:] + 164
  5 K3SDKInteTest	0x0000000102479e08 0x0000000102470000 + 40456
  ```

  - 其中第3行和第4行已经被符号化为函数，未符号化前应该为：

  ```c
  3 K3InteSDK	0x000000010289e5c0 0x00000001025d8000 + 2909632
  4 K3InteSDK	0x0000000102765508 0x00000001025d8000 + 1627400
  ```

  - 镜像文件：包括可执行二进制文件和二进制文件依赖的动态库，如 **K3SDKInteTest**、**K3InteSDK**；
  
  - 堆栈地址：代码在内存中执行的内存地址，如 **0x000000010289e5c0**；
  
  - 镜像的加载地址：程序执行时，内核会将包含程序代码的镜像加载到内存中，镜像在内存中的基地址就是加载地址。如 **0x00000001025d8000**；
  
  - 偏移量：堆栈地址相对于镜像地址的偏移量，如 **2909632**。

- 默认情况下，在编译发布版本时，调试符号会被剥离，以减少生成的二进制文件的大小。这些调试符号携带了从内存地址转换到相关源文件和行号所需的信息。幸运的是，剥离的调试符号存储在附带的 dSYM 文件中。应用程序的二进制文件和 dSYM 文件通过 UUID 进行匹配。Xcode 提供了许多工具，将调试符号从 dSYM 文件应用到堆栈跟踪，称为**符号化**。

- 计算堆栈帧的符号地址：**symbol address = stack_address（堆栈地址） - load_address（镜像的加载地址） + slide**

  - slide：dSYM 文件的 vmaddr，可以通过以下命令获取：

    ```plaintext
    otool -arch <arch> -l <path_to_DWARF> | grep __TEXT -m 2 -A 1 | grep vmaddr
    ```

    - arch 为 arm64、armv7s、armv7、arm64、x86_64 
    - path_to_DWARF 为 dSYM 文件中的 DWARF 文件路径，一般为 *xxx.app.dSYM/Contents/Resources/DWARF/xxx*
    - 主程序 slide 值一般为 0x0000000100000000；动态库 slide 值一般为 0x0000000000000000

## dSYM

- Xcode 设置生成 dSYM 文件：**Debug Information Format** 设置为 **DWARF with dSYM File**。

  ![](https://tva1.sinaimg.cn/large/0081Kckwgy1gm3fnhqkuuj3164044gm9.jpg)

- 文件位置：
  - Product -> Run：在  *Xcode preferences -> Locations -> Derived Data*
  - Product -> Archive：在 *Window -> Organizer*
  - 通过运行命令：`mdfind <uuid_of_app>` 寻找对应的 dSYM 文件

## UUID

- 通过对比 UUID 是否一致：判断 .dSYM 符号表或其他文件是否对应闪退日志，这样才能正确解析。

  - 命令行查看：`dwarfdump --uuid [文件路径]`；

  - 闪退文件查看： Binary Images 中项目名后面第一个尖括号中的字符串码。

    ![](https://tva1.sinaimg.cn/large/0081Kckwgy1glvrh34jdej321i04eq56.jpg)

  - MachOView 查看：Fat Binary -> Shared Library -> Load Commands -> LC_UUID

    ![](https://tva1.sinaimg.cn/large/0081Kckwgy1glvrkds2e0j31sa0eqjwr.jpg)

## dwarfdump

- 所需文件：dSYM 文件

  - 如 frame 发生在自定义动态库中（如第3行所示的 `K3InteSDK`），则需要自定义动态库的对应文件。

- 命令行：

  ```
  dwarfdump --arch=<arch> --lookup=<symbol_address> <path_to_dsym>
  ```

  >  最新的Mac系统中，指令中不要带 `--arch=<arch>`。

- 案例：

  - `K3SDKInteTest` 主程序

  ```objective-c
  dwarfdump --lookup 0x100009E08 K3SDKInteTest.app.dSYM
  
  // 输出
  0x00048e92: DW_TAG_compile_unit
                DW_AT_producer	("Apple clang version 12.0.0 (clang-1200.0.32.28)")
                DW_AT_language	(DW_LANG_ObjC)
                DW_AT_name	("/Users/3kmac/Desktop/K3InteSDK/K3InteTest/K3InteTest/ViewController.m")
                DW_AT_LLVM_sysroot	("/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.3.sdk")
                DW_AT_APPLE_sdk	("iPhoneOS14.3.sdk")
                DW_AT_stmt_list	(0x0000b5a8)
                DW_AT_comp_dir	("/Users/3kmac/Desktop/K3InteSDK/K3InteTest")
                DW_AT_APPLE_major_runtime_vers	(0x02)
                DW_AT_low_pc	(0x0000000100007eb0)
                DW_AT_high_pc	(0x000000010000f2e8)
  
  0x000496ae:   DW_TAG_subprogram
                  DW_AT_low_pc	(0x00000001000099a8)
                  DW_AT_high_pc	(0x000000010000a51c)
                  DW_AT_frame_base	(DW_OP_reg29 W29)
                  DW_AT_object_pointer	(0x000496c9)
                  DW_AT_name	("-[ViewController tableView:didSelectRowAtIndexPath:]")
                  DW_AT_decl_file	("/Users/3kmac/Desktop/K3InteSDK/K3InteTest/K3InteTest/ViewController.m")
                  DW_AT_decl_line	(310)
                  DW_AT_prototyped	(true)
  Line info: file 'ViewController.m', line 361, column 13, start line 310
  // 最后一行表示闪退发生在 ViewController.m 文件的第361行
  ```

  - `K3InteSDK` 动态库

  ```objective-c
  dwarfdump --lookup 0x2C65C0 K3InteSDK.framework.dSYM
  
  // 输出
  0x00190a7e: DW_TAG_compile_unit
                DW_AT_producer	("Apple clang version 12.0.0 (clang-1200.0.32.28)")
                DW_AT_language	(DW_LANG_ObjC)
                DW_AT_name	("/Users/3kmac/Desktop/HelperKit/K3HelperKit/K3HelperKit/Categories/NSObject+K3Add.m")
                DW_AT_LLVM_sysroot	("/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.3.sdk")
                DW_AT_APPLE_sdk	("iPhoneOS14.3.sdk")
                DW_AT_stmt_list	(0x000df50f)
                DW_AT_comp_dir	("/Users/3kmac/Desktop/HelperKit/K3HelperKit")
                DW_AT_APPLE_major_runtime_vers	(0x02)
                DW_AT_low_pc	(0x00000000002c5304)
                DW_AT_high_pc	(0x00000000002c6628)
  
  0x001913c7:   DW_TAG_subprogram
                  DW_AT_low_pc	(0x00000000002c6538)
                  DW_AT_high_pc	(0x00000000002c6628)
                  DW_AT_frame_base	(DW_OP_reg29 W29)
                  DW_AT_object_pointer	(0x001913e1)
                  DW_AT_name	("+[NSObject(K3Add) crash]")
                  DW_AT_decl_file	("/Users/3kmac/Desktop/HelperKit/K3HelperKit/K3HelperKit/Categories/NSObject+K3Add.m")
                  DW_AT_decl_line	(212)
                  DW_AT_prototyped	(true)
  Line info: file 'NSObject+K3Add.m', line 214, column 18, start line 212
  ```

## atos

- 所需文件：exec 文件或镜像的 DWARF 文件

  - exec 文件路径：*Payload/K3SDKInteTest.app/K3SDKInteTest*

  - DWARF 文件 文件路径：*K3SDKInteTest.app.dSYM/Contents/Resources/DWARF/K3SDKInteTest*

  - 如 frame 发生在动态库中（如第3行所示的 `K3InteSDK`，第1行所示的 `CoreFoundation` ），则需要动态库（系统动态库或自定义动态库）的对应文件。

    > 系统动态库的获取方式：同一个系统库在不同 iOS 系统版本下是有区别的，需要找到对应系统的真机连接 Xcode 后，在Mac 系统的 `/Users/xxx/Library/Developer/Xcode/iOS DeviceSupport` 目录下可找到对应版本的所有系统库。

- 命令行：

  ```c
  atos -arch <arch> -o <path_to_file> -l <load_address> <stack_address1> <stack_address2>
  ```

  > 最新的Mac系统中，指令中不要带 `-arch <arch>`

- 案例：

  - `K3SDKInteTest` 主程序

  ```objective-c
  atos -o K3SDKInteTest -l 0x0000000102470000 0x0000000102479e08
  
  // 输出
  -[ViewController tableView:didSelectRowAtIndexPath:] (in K3SDKInteTest) (ViewController.m:361)
  // (ViewController.m:361) 表示闪退发生在 ViewController.m 文件的第361行
  ```

  - `K3InteSDK` 动态库
  ```objective-c
  atos -o K3InteSDK -l 0x00000001025d8000 0x000000010289e5c0 0x0000000102765508
  
  // 输出
  +[NSObject(K3Add) crash] (in K3InteSDK) (NSObject+K3Add.m:214)
  +[K3InteSDK updateRole:] (in K3InteSDK) (K3InteSDK.m:228)
  ```

  - `CoreFoundation` 系统库
  ```objective-c
  atos -o CoreFoundation -l 0x000000019f924000 0x000000019f948904
  
  // 输出
  -[NSOrderedSet indexOfObject:inSortedRange:options:usingComparator:] (in CoreFoundation) + 0
  ```

## lldb

- 所需文件：exec 文件或镜像的 DWARF 文件

- 命令行：

  ```
  lldb
  target create --no-dependents --arch <arch> <path_to_file>
  image lookup --address <symbol_address>
  ```

- 案例：

  - `K3SDKInteTest` 主程序

  ```objective-c
  // lldb命令
  (base) lldb
  error: module importing failed: invalid pathname
  // target命令
  (lldb) target create --no-dependents --arch arm64 K3SDKInteTest
  Current executable set to '/Users/3kmac/Desktop/crash/K3SDKInteTest' (arm64).
  // image命令
  (lldb) image lookup --address 0x100009E08
        Address: K3SDKInteTest[0x0000000100009e08] (K3SDKInteTest.__TEXT.__text + 8024)
        Summary: K3SDKInteTest`-[ViewController tableView:didSelectRowAtIndexPath:] + 1120 at ViewController.m:361:13
  ```

  - `K3InteSDK` 动态库

  ```objective-c
  // lldb命令
  (base) lldb
  error: module importing failed: invalid pathname
  // target命令
  (lldb) target create --no-dependents --arch arm64 K3InteSDK
  Current executable set to '/Users/3kmac/Desktop/crash/K3InteSDK' (arm64).
  // image命令
  (lldb) image lookup --address 0x2C65C0
        Address: K3InteSDK[0x00000000002c65c0] (K3InteSDK.__TEXT.__text + 2884848)
        Summary: K3InteSDK`+[NSObject(K3Add) crash] + 136 at NSObject+K3Add.m:214:18
  ```

## 方法偏移量

- 如只能定位到闪退方法而无法获取闪退代码的具体行数时，可以使用 Hopper Disassembler + 汇编知识进行分析。

- `4 K3InteSDK	0x0000000102765508 +[K3InteSDK updateRole:] + 164` 中的 164 代表的含义？

- 使用 Hopper Disassembler  工具查看 `+[K3InteSDK updateRole:]` 方法的汇编代码：

  ![](https://tva1.sinaimg.cn/large/0081Kckwgy1glvmao2m9wj31d10u04qp.jpg)

- 方法的首地址为 000000000018d464  + 偏移地址 164 = 闪退地址 0x18D508。

  - 注意，这里 0x18D508 虽然是 ldr 这一行，但其实是 0x18D504 这一行，因为这是 iOS 堆栈采集的原理所决定的（LR寄存器保存着最后一次函数调用指令的下一条指令的内存地址），除了 frame 0 的堆栈地址是最后崩溃的地址，frame 序号 大于0的地址都是实际地址的下一行。

  - 根据 `imp___stubs__objc_msgSend`，可以大致定位于执行 `crash` 方法时发生闪退。

## 行号

- 在以上的符号化命令中，最终的结果中都包含了闪退代码所在的文件名和行号。

- 如需行号，必须将  **Optimization Level** 设置为 **None**，否则符号化出的结果中不指明行号。

  ![](https://tva1.sinaimg.cn/large/0081Kckwgy1gm3lcf4po5j30q6034q3g.jpg)

# 捕获异常

## Mach 异常

- Mach 是 Mac OS 和 iOS 操作系统的微内核核心，负责操作系统中基本职责：进程和线程抽象、虚拟内存管理、任务调度、进程间通信和消息传递机制。

- Mach 异常是指最底层的内核级异常。

- 通过 Mach API 设置 Threads，Tasks 的异常端口 Ports，来捕获 Mach 异常 Message。

  - Tasks：拥有一组系统资源的对象，允许 Threads 在其中执行。
  - Threads：执行的基本单位，拥有 Task 的上下文，并共享其资源。
  - Ports：Task之间通讯的一组受保护的消息队列；Task 可对任何 Port 发送/接收数据。
  - Message：有类型的数据对象集合，只可以发送到 Port。

  ```c
  typedef struct
  {
      mach_msg_header_t          header;
      mach_msg_body_t            body;
      mach_msg_port_descriptor_t thread;
      mach_msg_port_descriptor_t task;
      NDR_record_t               NDR;
      exception_type_t           exception;
      mach_msg_type_number_t     codeCount;
      mach_exception_data_type_t code[0];
      char                       padding[512];
  } MachExceptionMessage;
  
  typedef struct
  {
      mach_msg_header_t header;
      NDR_record_t      NDR;
      kern_return_t     returnCode;
  } MachReplyMessage;
  
  mach_port_t g_exceptionPort;
  
  static void* handleMachExceptions(void *arg) {
      MachExceptionMessage exceptionMessage = {{0}};
      kern_return_t kr;
      for(;;)
      {
          // 接收消息，否则一直处于休眠状态
          kr = mach_msg(&exceptionMessage.header,
                        MACH_RCV_MSG | MACH_RCV_LARGE,
                        0,
                        sizeof(exceptionMessage),
                        g_exceptionPort,
                        MACH_MSG_TIMEOUT_NONE,
                        MACH_PORT_NULL);
          if(kr == KERN_SUCCESS) {
              break;
          }
          
          // 如果mach_msg返回失败，则通过for循环重新调用
      }
      
      NSLog(@"------->Receive message %d. Exception: %d. Code: %lld/%lld. Thread:%u" , exceptionMessage.header.msgh_id, exceptionMessage.exception, exceptionMessage.code[0], exceptionMessage.code[1], exceptionMessage.thread.name);
      
      // 回复消息才能让应用闪退
      MachReplyMessage replyMessage = {{0}};
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
    
      return NULL;
  }
  
  void catchMACHExceptions() {
      kern_return_t kr = 0;
      
      // 创建异常处理端口
      kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &g_exceptionPort);
  
      // 申请接收消息权限
      kr = mach_port_insert_right(mach_task_self(), g_exceptionPort, g_exceptionPort, MACH_MSG_TYPE_MAKE_SEND);
  
      // 当前进程注册异常端口来接收Mach异常消息
      exception_mask_t excMask = EXC_MASK_BAD_ACCESS |
                                 EXC_MASK_BAD_INSTRUCTION |
                                 EXC_MASK_ARITHMETIC |
                                 EXC_MASK_SOFTWARE |
                                 EXC_MASK_BREAKPOINT;
      kr = thread_set_exception_ports(mach_thread_self(), excMask, g_exceptionPort, EXCEPTION_DEFAULT, MACHINE_THREAD_STATE);
  
      // 创建异常处理线程来接收Mach异常消息
      pthread_t thread;
      pthread_create(&thread, NULL, handleMachExceptions, NULL);
  }
  ```

## Signal 信号

- Signal 信号是一种异步处理的软中断，内核会发送给进程某些异步事件，这些异步事件可能来自硬件，比如除0或者访问了非法地址；也可能来自其他进程或用户输入，比如 *ctrl+c*。

- 硬件错误被 Mach 层捕获，然后转换为对应的 “UNIX信号”。为了维护一个统一的机制，操作系统和用户产生的信号首先被转换为 Mach 异常，然后再转换为 Signal 信号。

  - 不是所有的 Mach异常类型都映射到了 Signal 信号，如 EXC_GUARD；
  - 用户态的软件异常是直接走信号流程，不产生 Mach 异常。

- 通过注册信号处理函数 `signal()` 或 `sigaction()` 来捕获 Signal 信号。

  ```c
  static void handleSignal(int sigNum, siginfo_t* signalInfo, void* userContext) {
      NSLog(@"------->Receive signal %d. Signal number:%d. Signal code:%d. Sigal errno:%d. Sigal address:%lu" , sigNum, signalInfo->si_signo, signalInfo->si_code, signalInfo->si_errno, (uintptr_t)signalInfo->si_addr);
  }
  
  void catchSignalExceptions() {
      struct sigaction action;
      action.sa_flags = SA_NODEFER | SA_SIGINFO;
      sigemptyset(&action.sa_mask);
    	// 信号接收处理函数
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
  ```


## OC 异常

- 引发崩溃的代码本质上就两类：
  - 信号异常，C++ 语言层面的错误，比如野指针，除零，内存访问异常等。
  
  - 未捕获异常（`Uncaught Exception`），iOS 下面最常见的就是 `NSException`（通过 `@throw` 抛出），比如数组访问元素越界。
  
- 崩溃信息收集：

  - 对于第一种问题，由于 iOS 底层系统都是 Unix 或者类 Unix 系统，可以采用信号机制来捕获 signal 或 sigaction，通过设置的回调函数来收集信号的上下文信息。
  
  - 对于第二种问题，可以通过 `NSSetUncaughtExceptionHandler` 设置异常处理回调函数来收集异常的调用堆栈。
  
  - 当一个异常同时触发两种错误时，未捕获异常的捕获顺序高于信号异常。

- 如果多方通过 `NSSetUncaughtExceptionHandler` 注册异常处理程序，后注册的异常处理程序会覆盖前一个注册的 handler，导致之前注册的日志收集服务收不到相应的 `NSException`，丢失崩溃堆栈信息。

  - 在注册前保存之前的 handler；

  - 在处理后恢复之前的handler 或传递异常；

  ```c++
  static NSUncaughtExceptionHandler* g_previousUncaughtExceptionHandler;
  
  // 注册
  void InstallUncaughtExceptionHandler(void) {
      // 保存之前的handler
  		g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
      NSSetUncaughtExceptionHandler(&HandleException);
  }
  
  // 处理
  void HandleException(NSException *exception) {
      // 传递异常
      if (g_previousUncaughtExceptionHandler != NULL) {
          g_previousUncaughtExceptionHandler(exception);
      }
  }
  ```

## C++ 异常



## DeadLock

- 死锁通常是当多个线程在相互等待着对方的结束时，就会发生死锁，这时程序可能会被卡住。

  ```objective-c
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_main_queue(), ^{
      dispatch_semaphore_signal(semaphore);
  });
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  ```

- 检测方案：

  - 在子线程执行 `runMonitor` 方法，不断循环执行 `watchdogPulse` 方法，即在主线程里复位标志位。

  - 如果主线程不能及时复位标志位，说明发生了死锁。

  ```objective-c
  - (id)init {
      if (self = [super init]) {
          // 创建一个线程执行runMonitor方法
          self.monitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(runMonitor) object:nil];
          [self.monitorThread start];
      }
      return self;
  }
  
  - (void)runMonitor {
      do {
          @autoreleasepool {
              [NSThread sleepForTimeInterval:g_watchdogInterval];
              if (runWatchdogCheck) {
                  if (self.awaitingResponse) {
                      [self handleDeadlock];
                  }
                  else {
                      [self watchdogPulse];
                  }
              }
          }
      } while (YES);
  }
  
  - (void)watchdogPulse {
      self.awaitingResponse = YES;
      // 主线程如果不能及时设置awaitingResponse=NO，说明被卡住了
      dispatch_async(dispatch_get_main_queue(), ^ {
          self.awaitingResponse = NO;
      });
  }
  ```

