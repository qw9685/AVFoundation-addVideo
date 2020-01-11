
//  CustomVideoCompositor.h
//  视频叠加
//
//  Created by cc on 2020/1/3.
//  Copyright © 2020 mac. All rights reserved.
//


#import <Foundation/Foundation.h>
@import AVFoundation;

typedef NS_ENUM(NSInteger, MirrorType)
{
    kMirrorNone = 0,
    kMirrorLeftRightMirror,
    kMirrorUpDownReflection,
    kMirror4Square,
};

@interface CustomVideoCompositor : NSObject<AVVideoCompositing>

@end
