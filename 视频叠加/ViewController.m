//
//  ViewController.m
//  视频叠加
//
//  Created by cc on 2020/1/3.
//  Copyright © 2020 mac. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "CustomVideoCompositor.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray<NSURL*>* videos = @[
        [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"1.mp4" ofType:nil]],
        [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"2.mp4" ofType:nil]]
    ];
    
    NSString* outPath = [NSString stringWithFormat:@"%@/cache.mp4",[self dirDoc]];
    [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
    
    [self addVideos:videos outPath:outPath];
}

- (void)addVideos:(NSArray<NSURL*>*)videos outPath:(NSString*)outPath{

    //assets
    NSMutableArray<AVAsset*>* assets = [NSMutableArray array];
    //AVMutableComposition 用来加载轨道
    AVMutableComposition *mix = [AVMutableComposition composition];
    //音视频轨道
    NSMutableArray<AVAssetTrack*>* videoTracks = [NSMutableArray array];
    NSMutableArray<AVAssetTrack*>* aduioTracks = [NSMutableArray array];
    

    //用来管理视频中的所有视频轨道
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];

    //输出对象 会影响分辨率
    AVAssetExportSession* exporter = [[AVAssetExportSession alloc] initWithAsset:mix presetName:AVAssetExportPresetHighestQuality];

    //加载视频轨道
    [videos enumerateObjectsUsingBlock:^(NSURL* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        AVAsset* asset = [AVAsset assetWithURL:obj];
        AVAssetTrack* videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];

        [videoTracks addObject:videoTrack];
        [assets addObject: asset];

        //使用第一个资源时间
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, assets[0].duration);

        //视频轨道容器
        AVMutableCompositionTrack *videoCompositionTrack = [mix addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:(int)idx + 1];
        //加载视频轨道
        [videoCompositionTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    }];
    
    //加载音频轨道
    [videos enumerateObjectsUsingBlock:^(NSURL* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        AVAsset* asset = [AVAsset assetWithURL:obj];
        AVAssetTrack* audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];

        [aduioTracks addObject:audioTrack];

        //使用第一个资源时间
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, assets[0].duration);

        //音频轨道容器
        AVMutableCompositionTrack *audioCompositionTrack = [mix addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        //加载音频轨道
        [audioCompositionTrack insertTimeRange:timeRange ofTrack:audioTrack atTime:kCMTimeZero error:nil];
        
    }];

    //设置视频资源 分辨率 位置 是否旋转
    [videoTracks enumerateObjectsUsingBlock:^(AVAssetTrack * _Nonnull videoTrack, NSUInteger idx, BOOL * _Nonnull stop) {
        //存储视频分辨率、位置、旋转角度
        CGSize size = [self getNaturalSize:videoTrack];
        if (idx == 0) {
            [self setTransfromWithTrackID:1 transfrom:videoTrack.preferredTransform];
            [self setVideoRectWithTrackID:1 renderRect:CGRectMake(0, 0, size.width, size.height)];
        }else{
            [self setTransfromWithTrackID:2 transfrom:videoTrack.preferredTransform];
            [self setVideoRectWithTrackID:2 renderRect:CGRectMake(0, 0, size.width/2, size.height/2)];
        }
    }];
    
    //获取第一个资源时长、分辨率
    __block CMTime maxTime = assets[0].duration;
    CGSize renderSize1 = [self getNaturalSize:videoTracks[0]];
//    CGSize renderSize2 = [self getNaturalSize:videoTracks[1]];
    
//    float width = MAX(renderSize1.width, renderSize2.width);
//    float height = MAX(renderSize1.height, renderSize2.height);
    
    //设置分辨率
    mainCompositionInst.renderSize = renderSize1;
    //可加载多个轨道
    mainCompositionInst.instructions = @[[self getCompositionInstructions:videoTracks maxTime:maxTime]];
    //设置视频帧率
    mainCompositionInst.frameDuration = videoTracks[0].minFrameDuration;
    mainCompositionInst.renderScale = 1.0;
    
    //自定义合成器  需要遵循AVVideoCompositing协议
    mainCompositionInst.customVideoCompositorClass = [CustomVideoCompositor class];

    //exporter设置
    exporter.outputURL = [NSURL fileURLWithPath:outPath];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;//适合网络传输
    exporter.videoComposition = mainCompositionInst;

    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                NSLog(@"成功");
                [self playVideoWithUrl:[NSURL fileURLWithPath:outPath]];
            }else{
                NSLog(@"失败--%@",exporter.error);
            }
        });
    }];
}

- (AVMutableVideoCompositionInstruction*)getCompositionInstructions:(NSArray<AVAssetTrack*>*)videoTracks maxTime:(CMTime)maxTime{

    NSMutableArray<AVMutableVideoCompositionLayerInstruction*>* layerInstructions = [NSMutableArray array];

    //视频轨道中的一个视频，可以缩放、旋转等
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, maxTime);

    [videoTracks enumerateObjectsUsingBlock:^(AVAssetTrack * _Nonnull track, NSUInteger idx, BOOL * _Nonnull stop) {
        
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
        layerInstruction.trackID = (int)idx + 1;
        [layerInstructions addObject:layerInstruction];
        
    }];

    mainInstruction.layerInstructions = layerInstructions;

    return mainInstruction;
}

//给customVideoCompositorClass传递旋转矩阵
- (void)setTransfromWithTrackID:(int)trackID transfrom:(CGAffineTransform)transfrom{
    NSString* key = [NSString stringWithFormat:@"videoTrackID_transfrom_%d",trackID];
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGAffineTransform(transfrom) forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//给customVideoCompositorClass传递每个图层显示的分辨率
- (void)setVideoRectWithTrackID:(int)trackID renderRect:(CGRect)renderRect{
    NSString* key = [NSString stringWithFormat:@"videoTrackID_videoRect_%d",trackID];
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGRect(renderRect) forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CGSize)getNaturalSize:(AVAssetTrack*)track{
    
    //设置视频的旋转角度,否则可能输出的视频会旋转
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = track.preferredTransform;

    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation_ =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation_ = UIImageOrientationDown;
    }

    //根据视频中的naturalSize及获取到的视频旋转角度是否是竖屏来决定输出的视频图层的横竖屏
    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake(track.naturalSize.height, track.naturalSize.width);
    } else {
        naturalSize = track.naturalSize;
    }
    return naturalSize;
}

-(void)playVideoWithUrl:(NSURL *)url{
    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc]init];
    playerViewController.player = [[AVPlayer alloc]initWithURL:url];
    playerViewController.view.frame = self.view.frame;
    [playerViewController.player play];
    [self presentViewController:playerViewController animated:YES completion:nil];
}

//获取Documents目录
-(NSString *)dirDoc{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}


@end
