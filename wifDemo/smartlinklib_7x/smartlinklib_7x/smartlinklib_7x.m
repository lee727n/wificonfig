//
//  smartlinklib_7x.m
//  smartlinklib_7x
//
//  Created by Peter on 15/11/26.
//  Copyright © 2015年 Peter. All rights reserved.
//

#import "smartlinklib_7x.h"

@implementation smartlinklib_7x

+(instancetype)shareInstence{
    static smartlinklib_7x * me = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        me = [[smartlinklib_7x alloc]init];
    });
    return me;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

-(NSString *)getSsid
{
    return @"ForTest......";
}

@end
