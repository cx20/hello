#import <Foundation/Foundation.h>

#include <iostream>

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    @autoreleasepool {
        std::cout << "Hello, C++ World!" << std::endl;
        NSLog(@"Hello, Objective-C++ World!");
    }

    return 0;
}
