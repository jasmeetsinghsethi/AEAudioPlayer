//
//  AAudioPlayer.h
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AAudioPlayer;

@protocol AAudioPlayerDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(AAudioPlayer *)player successfully:(BOOL)flag;
@end

@interface AAudioPlayer : NSObject


//- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;
- (instancetype)initPCMBufferWithContentsOfURL:(NSURL *)url error:(NSError **)outError;

- (void)play;
- (void)pause;
- (void)stop;

//+ (int)getBandFrequencyWithBandIndex:(int)bandIndex;
//- (void)setEqGain:(CGFloat)gain forFrequency:(eqValue)frequency;


@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic) NSURL* url;
@property (nonatomic,weak) id<AAudioPlayerDelegate> delegate;

@property (nonatomic) AVAudioPlayerNode* player;
@property (nonatomic) AVAudioFile* file;
@end
