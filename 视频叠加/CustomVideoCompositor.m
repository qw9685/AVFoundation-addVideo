
//  CustomVideoCompositor.h
//  视频叠加
//
//  Created by cc on 2020/1/3.
//  Copyright © 2020 mac. All rights reserved.
//

@import  UIKit;
#import "CustomVideoCompositor.h"

#define degreesToRadians(degrees) ((degrees) / 180.0 * M_PI)

@interface CustomVideoCompositor()

@end

@implementation CustomVideoCompositor

- (instancetype)init
{
    return self;
}

//异步创建一个新的像素缓冲区  以sourceTrackIDs获取对应视频资源
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    NSMutableArray *videoArray = [[NSMutableArray alloc] init];
    CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
    
    if (request.sourceTrackIDs.count > 0)
    {
        for (NSUInteger i = 0; i < [request.sourceTrackIDs count]; ++i)
        {
            //获取
            CVPixelBufferRef videoBufferRef = [request sourceFrameByTrackID:[[request.sourceTrackIDs objectAtIndex:i] intValue]];
            if (videoBufferRef)
            {
                [videoArray addObject:(__bridge id)(videoBufferRef)];
            }
        }
        
        for (NSUInteger i = 0; i < [videoArray count]; ++i)
        {
            CVPixelBufferRef video = (__bridge CVPixelBufferRef)([videoArray objectAtIndex:i]);
            CVPixelBufferLockBaseAddress(video, kCVPixelBufferLock_ReadOnly);
        }
        CVPixelBufferLockBaseAddress(destination, 0);
        
        [self renderBuffer:videoArray toBuffer:destination sourceTrackIDs:request.sourceTrackIDs];
        
        CVPixelBufferUnlockBaseAddress(destination, 0);
        for (NSUInteger i = 0; i < [videoArray count]; ++i)
        {
            CVPixelBufferRef video = (__bridge CVPixelBufferRef)([videoArray objectAtIndex:i]);
            CVPixelBufferUnlockBaseAddress(video, kCVPixelBufferLock_ReadOnly);
        }
    }
    NSLog(@"加载中");
    [request finishWithComposedVideoFrame:destination];
    CVBufferRelease(destination);
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

#pragma mark - renderBuffer
- (void)renderBuffer:(NSMutableArray *)videoBufferRefArray toBuffer:(CVPixelBufferRef)destination sourceTrackIDs:(NSArray*)sourceTrackIDs
{
    size_t width = CVPixelBufferGetWidth(destination);
    size_t height = CVPixelBufferGetHeight(destination);
    NSMutableArray *imageRefArray = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < [videoBufferRefArray count]; ++i)
    {
        CVPixelBufferRef videoFrame = (__bridge CVPixelBufferRef)([videoBufferRefArray objectAtIndex:i]);
        CGImageRef imageRef = [self createSourceImageFromBuffer:videoFrame];
        if (imageRef)
        {
            if ([self shouldRightRotate90ByTrackID:i+1])
            {
                // Right rotation 90
                imageRef = CGImageRotated(imageRef, degreesToRadians(90));
            }
            
            [imageRefArray addObject:(__bridge id)(imageRef)];
        }
        CGImageRelease(imageRef);
    }
    
    if ([imageRefArray count] < 1)
    {
        NSLog(@"imageRefArray is empty.");
        return;
    }
    
    CGContextRef gc = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), width, height, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace((CGImageRef)imageRefArray[0]), CGImageGetBitmapInfo((CGImageRef)imageRefArray[0]));

    CGFloat cornerRadius = 10;
    for (int i = 0; i < [imageRefArray count]; ++i)
    {
        CGRect frame = [self setVideoRectWithTrackID:[sourceTrackIDs[i] intValue]];
        
        if (i > 0)
        {
            // 以左上角为原点转换y
            frame.origin.y = height - frame.origin.y - CGRectGetHeight(frame);
        }
        
        [self drawImage:frame withContextRef:gc withImageRef:(CGImageRef)imageRefArray[i] withCornerRadius:cornerRadius];
    }
    
    CGContextRelease(gc);
}

#pragma mark - createSourceImageFromBuffer
- (CGImageRef)createSourceImageFromBuffer:(CVPixelBufferRef)buffer
{
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    void *data = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, height * stride, NULL);
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, rgb, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgb);
    
    return image;
}

#pragma mark - CGImageRotated
CGImageRef CGImageRotated(CGImageRef originalCGImage, double radians)
{
    CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
    CGSize rotatedSize;
    if (radians == M_PI_2 || radians == -M_PI_2)
    {
        rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
    }
    else
    {
        rotatedSize = imageSize;
    }
    
    double rotatedCenterX = rotatedSize.width / 2.f;
    double rotatedCenterY = rotatedSize.height / 2.f;
     
    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
    CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
    if (radians == 0.f || radians == M_PI)
    {
        // 0 or 180 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        if (radians == 0.0f)
        {
            CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        }
        else
        {
            CGContextScaleCTM(rotatedContext, -1.f, 1.f);
        }
        CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
    }
    else if (radians == M_PI_2 || radians == -M_PI_2)
    {
        // +/- 90 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        CGContextRotateCTM(rotatedContext, radians);
        CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
    }
    
    CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
    CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
    CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);
    
    UIGraphicsEndImageContext();
    
    return rotatedCGImage;
}

#pragma mark - drawImage
- (void)drawImage:(CGRect)frame withContextRef:(CGContextRef)contextRef withImageRef:(CGImageRef)imageRef
{
    CGFloat cornerRadius = 0;
    [self drawImage:frame withContextRef:contextRef withImageRef:imageRef withCornerRadius:cornerRadius];
}

- (void)drawImage:(CGRect)frame withContextRef:(CGContextRef)contextRef withImageRef:(CGImageRef)imageRef withCornerRadius:(CGFloat)cornerRadius
{
    if (!CGRectIsEmpty(frame)){
        CGContextDrawImage(contextRef, frame, imageRef);
    }
}

#pragma mark - NSUserDefaults
//根据旋转角度 是否旋转
- (BOOL)shouldRightRotate90ByTrackID:(NSInteger)trackID
{
    NSString* key = [NSString stringWithFormat:@"videoTrackID_transfrom_%ld",(long)trackID];
    CGAffineTransform transfrom = CGAffineTransformFromString([[NSUserDefaults standardUserDefaults] objectForKey:key]);
    
    if (transfrom.a == 0 && transfrom.b == 1.0 && transfrom.c == -1.0 && transfrom.d == 0) {
        return YES;
    }
    return NO;
}
//获取图层显示frame
- (CGRect)setVideoRectWithTrackID:(int)trackID{
    NSString* key = [NSString stringWithFormat:@"videoTrackID_videoRect_%d",trackID];
    return CGRectFromString([[NSUserDefaults standardUserDefaults] objectForKey:key]);
}


@end
