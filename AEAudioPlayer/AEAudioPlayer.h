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
- (void)audioPlayerBeginInterruption:(AEAudioPlayer *)player;
- (void)audioPlayerEndInterruption:(AEAudioPlayer *)player withOptions:(AVAudioSessionInterruptionOptions)flags;
@end


@interface AEAudioPlayer : NSObject


- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;
- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError frequencies:(NSArray*)frequencies;

- (void)play;
- (void)pause;
- (void)stop;

/// -96 -> 24 db. Setup the bands in initialization.
- (void)setEqGain:(CGFloat)gain forBand:(int)bandIndex;

/// -1.0 -> 1.0
- (void)setPan:(CGFloat)pan;

/// -96 -> 24 db
- (void)setOverallGain:(CGFloat)overallGain;

/// Set the frequency and the bypass (false for enabled, otherwise true)
- (void)setBandPassFrequency:(CGFloat)freq bypass:(BOOL)bypass;

/// Set the frequency and the bypass (false for enabled, otherwise true)
- (void)setHighPassFrequency:(CGFloat)freq bypass:(BOOL)bypass;

/// Set the frequency and the bypass (false for enabled, otherwise true)
- (void)setLowPassFrequency:(CGFloat)freq bypass:(BOOL)bypass;


@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic,readonly) NSURL* url;
@property (nonatomic,weak) id<AEAudioPlayerDelegate> delegate;

@property (nonatomic) AVAudioPlayerNode* player;
@property (nonatomic) AVAudioFile* file;
@end
