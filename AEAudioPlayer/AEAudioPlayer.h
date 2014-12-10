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

@class AEAudioPlayer;

@protocol AEAudioPlayerDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(AEAudioPlayer *)player successfully:(BOOL)flag;

@optional
//May fire multiple times
- (void)audioPlayerBeginInterruption:(AEAudioPlayer *)player;
- (void)audioPlayerEndInterruption:(AEAudioPlayer *)player withOptions:(AVAudioSessionInterruptionOptions)flags;
- (void)audioPlayerRouteChange:(AEAudioPlayer *)player
                        reason:(AVAudioSessionRouteChangeReason)reason
                 previousRoute:(AVAudioSessionRouteDescription*)previous;
@end

@interface AEAudioPlayer : NSObject

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;
- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError frequencies:(NSArray*)frequencies;

- (void)play;
- (void)pause;
- (void)stop;

- (void)setEqGain:(CGFloat)gain forBand:(int)bandIndex;

@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic,weak) id<AEAudioPlayerDelegate> delegate;

@property (nonatomic) AVAudioPlayerNode* player;
@property (nonatomic) AVAudioFile* file;
@end
