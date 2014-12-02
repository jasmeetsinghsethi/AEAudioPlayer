//
//  AAudioPlayer.m
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import "AAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define DEBUG 1

@interface AAudioPlayer ()
{
    NSMutableArray* bufferArray;
    AVAudioPCMBuffer* skipBufferCompletion;
    
    NSTimer* runnTimer;
    NSThread* runThread;
    
    BOOL wasInterrupted;
    AVAudioFramePosition seekOldFramePosition;
    AVAudioFramePosition seekNewTimePosition;
    
    AVAudioUnitEQ* eq;
    NSMutableArray* bandGains;
}
@end

@implementation AAudioPlayer

- (instancetype)initPCMBufferWithContentsOfURL:(NSURL *)url error:(NSError **)outError
{
    self = [super init];
    if(self)
    {
        seekNewTimePosition = -1;
        _url = url;
        [self startBufferingURL:url AtOffset:0 error:outError];
    }
    return self;
}

- (void)setParamIndex:(int)index freq:(int)freq gain:(CGFloat)gain
{
    AVAudioUnitEQFilterParameters* filterParameters = eq.bands[index];
    
    filterParameters.filterType = AVAudioUnitEQFilterTypeBandPass;
    filterParameters.frequency = 5000.0;
    filterParameters.bandwidth = 2.0;
    filterParameters.bypass = false;
    filterParameters.gain = gain;
}

- (void)startBufferingURL:(NSURL*)url AtOffset:(AVAudioFramePosition)offset error:(NSError**)outError
{
    
    if(DEBUG) NSLog(@"Initializing");
    
    AVAudioEngine* engine = [self.class sharedEngine];
    
    eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:1];
    
    _player = [[AVAudioPlayerNode alloc] init];
    _file = [[AVAudioFile alloc] initForReading:url error:outError];
    
    [engine attachNode:eq];
    [engine attachNode:_player];
    
    [self setParamIndex:0 freq:4000 gain:-96.0];
    eq.globalGain = 1.0;
    
    [engine connect:_player to:eq format:_file.processingFormat];
    [engine connect:eq to:[engine mainMixerNode] format:_file.processingFormat];
    
    _file.framePosition = offset;
    
    if(*outError != nil)
    {
        NSLog(@"ERROR READING FILE: %@",*outError);
        return;
    }
    
    if(!bufferArray)
        bufferArray = [NSMutableArray new];
    
    [engine startAndReturnError:outError];
    if(*outError != nil)
    {
        NSLog(@"START ERROR: %@",*outError);
        return;
    }
    
    seekNewTimePosition = seekOldFramePosition - offset;
    
    wasInterrupted = false;
    seekOldFramePosition = 0;
}

-(void)loadBuffer
{
    if(bufferArray.count < 2)
    {
        AVAudioPCMBuffer* newBuffer = [self createAndLoadBuffer];
        if(newBuffer != nil)
        {
            [bufferArray addObject:newBuffer];
            [self scheduleBuffer:newBuffer];
        }
    }
}
    
- (void)scheduleBuffer:(AVAudioPCMBuffer*)buffer
{
    [_player scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionHandler:^{
        
        if(bufferArray && bufferArray.count > 0) [bufferArray removeObjectAtIndex:0];

        if(bufferArray.count == 0 && !wasInterrupted)
        {
            if(DEBUG) NSLog(@"Song Finished");
           if(_delegate && [_delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:successfully:)])
           {
               [_delegate audioPlayerDidFinishPlaying:self successfully:true];
           }
        }
    }];
}

- (AVAudioPCMBuffer*)createAndLoadBuffer
{
    AVAudioFormat *format = _file.processingFormat;
    UInt32 frameCount = (64 * 1024);
    AVAudioPCMBuffer* buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameCount];
    NSError* error = nil;
    if(![_file readIntoBuffer:buffer error:&error])
    {
        NSLog(@"failed to read audio file: %@",error);
        return nil;
    }
    if(buffer.frameLength == 0)
        return nil;
    

    return buffer;
}

- (void)finished
{
    if(DEBUG) NSLog(@"Finished Playing");
}

- (void)play
{
    if(DEBUG) NSLog(@"Play");
    
    [self stopBufferLoop];
    
    [self startBufferLoop];
    
    if(seekNewTimePosition != -1)
    {
        AVAudioTime* newTime = [[AVAudioTime alloc] initWithSampleTime:seekNewTimePosition atRate:_file.fileFormat.sampleRate];
        [_player playAtTime:newTime];
    }
    else
    {
        [_player play];
    }
    seekNewTimePosition = -1;
}

- (void)pause
{
    [self stopBufferLoop];
    
    [_player pause];
}

- (void)stop
{
    if(DEBUG) NSLog(@"Stopping");
    wasInterrupted = true;
    
    [self stopBufferLoop];

    if(_player)
    {
        [_player stop];
        [[self.class sharedEngine] stop];
    }
    
    [bufferArray removeAllObjects];
    
    _player = nil;
    _file = nil;
}

- (BOOL)playing
{
    return _player.playing;
}

- (void)dealloc
{
    if(DEBUG) NSLog(@"Dealloc");
    _delegate = nil;
    [self stop];
}

- (NSTimeInterval)currentTime
{
    double sampleRate = _file.fileFormat.sampleRate;
    if(sampleRate == 0)
        return 0;
    
    double currentTime = ceil((double)[_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime / sampleRate);
    
    return currentTime;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    if(DEBUG) NSLog(@"Seeking");
    
    BOOL isPlaying = [_player isPlaying];
    
    seekOldFramePosition = [_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime;
    
    double sampleRate = _file.fileFormat.sampleRate;
    AVAudioFramePosition framePosition = (long long)(currentTime * sampleRate);
    NSLog(@"FRAME: %lld %lld", _file.framePosition, framePosition);
    
    [self stop];
    
    NSError* startError = nil;
    [self startBufferingURL:_url AtOffset:framePosition error:&startError];
    if(startError)
        NSLog(@"Start Error: %@",startError);
    
    if(isPlaying)
        [self play];
}

- (NSTimeInterval)duration
{
    double sampleRate = _file.fileFormat.sampleRate;
    if(sampleRate == 0)
        return 0;
    return ceil(((double)_file.length/sampleRate));// sampleRate;
}

#pragma mark Buffer Loop

- (void)startBufferLoop
{
    if(runThread)
    {
        [runThread cancel];
        runThread = nil;
    }
    runThread = [[NSThread alloc] initWithTarget:self selector:@selector(processBufferLoop) object:nil];
    [runThread start];
}

- (void)processBufferLoop
{
    while(true)
    {
        if(runThread != nil && !runThread.cancelled)
        {
            [self loadBuffer];
        }
        else
        {
            break;
        }
    }
}

- (void)stopBufferLoop
{
    if(runThread)
    {
        [runThread cancel];
        runThread = nil;
    }
}

#pragma mark GLOBAL ENGINE

+ (AVAudioEngine*)sharedEngine
{
    static dispatch_once_t once;
    static AVAudioEngine* result = nil;
    dispatch_once(&once, ^{
        result = [[AVAudioEngine alloc] init];
    });
    return result;
}

@end
