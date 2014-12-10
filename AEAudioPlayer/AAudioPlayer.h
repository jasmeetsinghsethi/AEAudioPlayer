//
//  AAudioPlayer.h
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@class AAudioPlayer;

@protocol AAudioPlayerDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(AAudioPlayer *)player successfully:(BOOL)flag;

@optional
- (void)audioPlayerBeginInterruption:(AAudioPlayer *)player;
- (void)audioPlayerEndInterruption:(AAudioPlayer *)player withOptions:(AVAudioSessionInterruptionOptions)flags;
@end


@interface AAudioPlayer : NSObject


- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;
- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError frequencies:(NSArray*)frequencies;

- (void)play;
- (void)pause;
- (void)stop;

- (void)setEqGain:(CGFloat)gain forBand:(int)bandIndex;


@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic,readonly) NSURL* url;
@property (nonatomic,weak) id<AAudioPlayerDelegate> delegate;

@property (nonatomic) AVAudioPlayerNode* player;
@property (nonatomic) AVAudioFile* file;
@end
