//
//  CPPException.cpp
//  Crash
//
//  Created by stone on 2020/12/29.
//

#include "CPPException.h"
#include <typeinfo>
#include <stdlib.h>
#include <iostream>

static void CPPExceptionTerminate(void) {
    std::cout << "c++ crash " << std::endl;
}

void catchCPPExceptions(void) {
    std::cout << "catchNSExceptions" << std::endl;

    std::set_terminate(CPPExceptionTerminate);
}

void crash(void) {
    throw 0;
}
