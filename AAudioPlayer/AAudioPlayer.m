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

#define kNumBufferNodes 3

@interface AAudioPlayer ()
{
    NSMutableArray* bufferArray;
    AVAudioPCMBuffer* skipBufferCompletion;
    
    NSTimer* runTimer;
    NSThread* runThread;
    
    BOOL wasInterrupted;
    //AVAudioFramePosition seekOldFramePosition;
    AVAudioFramePosition seekNewTimePosition;
    
    AVAudioUnitEQ* eq;
    NSArray* frequencies;
    NSMutableArray* frequencyGains;
    
    BOOL hasInitialized;
    
    BOOL isPaused;
    NSTimeInterval pausedTime;
}
@end

@implementation AAudioPlayer

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError
{
    NSLog(@"Beginning new player initialization");
    return [self initWithContentsOfURL:url error:outError frequencies:@[]];
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError frequencies:(NSArray *)freqs
{
    self = [super init];
    if(self)
    {
        seekNewTimePosition = -1;
        //seekOldFramePosition = -1;
        _url = url;
        
        frequencies = freqs;
        frequencyGains = [[NSMutableArray alloc] init];
        for(int i=0; i<frequencies.count; i++)
        {
            [frequencyGains addObject:@(0)];
        }
        
        hasInitialized = false;
    }
    return self;
}

- (void)setParamIndex:(int)index
{
    AVAudioUnitEQFilterParameters* filterParameters = eq.bands[index];
    
    NSNumber* currentFreq = frequencies[index];
    NSNumber* currentFreqGain = frequencyGains[index];
    
    filterParameters.filterType = AVAudioUnitEQFilterTypeParametric;
    filterParameters.frequency = currentFreq.intValue;
    filterParameters.bandwidth = 1.0;
    filterParameters.bypass = false;
    filterParameters.gain = currentFreqGain.floatValue;
}

- (void)setEqGain:(CGFloat)gain forBand:(int)bandIndex
{
    frequencyGains[bandIndex] = @(gain);
    [self setParamIndex:bandIndex];
}

- (void)startBufferingURL:(NSURL*)url AtOffset:(AVAudioFramePosition)offset error:(NSError**)outError
{
    [self stop];
    
    if(DEBUG) NSLog(@"Initializing");
    
    AVAudioEngine* engine = [self.class sharedEngine];
    
    _player = [[AVAudioPlayerNode alloc] init];
    _file = [[AVAudioFile alloc] initForReading:url error:outError];
    
    [engine attachNode:_player];
    
    if(frequencies.count == 0)
    {
        [engine connect:_player to:[engine mainMixerNode] format:_file.processingFormat];
    }
    else
    {
        eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:frequencies.count];
        [engine attachNode:eq];
        
        for( int i=0; i < frequencies.count; i++)
        {
            [self setParamIndex:i];
        }
        
        eq.globalGain = 1.0;
        
        [engine connect:_player to:eq format:_file.processingFormat];
        [engine connect:eq to:[engine mainMixerNode] format:_file.processingFormat];
    }
    
    _file.framePosition = offset;
    
    if(outError != nil && *outError != nil)
    {
        NSLog(@"ERROR READING FILE: %@",*outError);
        return;
    }
    
    bufferArray = [NSMutableArray new];
    
    if(!engine.isRunning)
    {
        [engine startAndReturnError:outError];
        if(outError != nil && *outError != nil)
        {
            NSLog(@"START ERROR: %@",*outError);
            return;
        }
    }
    
    seekNewTimePosition = offset;
    
    NSLog(@"(%s) N:%lld / Offset:%lld",__PRETTY_FUNCTION__,seekNewTimePosition,offset);
    
    //wasInterrupted = false;
}

-(void)loadBuffer
{
    while(bufferArray.count < kNumBufferNodes)
    {
        AVAudioPCMBuffer* newBuffer = [self createAndLoadBuffer];
        if(newBuffer != nil)
        {
            [bufferArray addObject:newBuffer];
            [self scheduleBuffer:newBuffer];
        }
        else
        {
            break;
        }
    }
}
    
- (void)scheduleBuffer:(AVAudioPCMBuffer*)buffer
{
    [_player scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionHandler:^{
        
        if(bufferArray != nil && bufferArray.count > 0) [bufferArray removeObjectAtIndex:0];
        else
        {
            return;
        }
        [self loadBuffer];

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
    if(_file == nil || _player == nil || ![[self.class sharedEngine] isRunning])
    {
        return nil;
    }
    
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
    if([self playing])
        return;
    
    if(!hasInitialized)
    {
        [self startBufferingURL:self.url AtOffset:0 error:nil];
        hasInitialized = true;
    }
    
    wasInterrupted = false;
    
    if(![[self.class sharedEngine] isRunning])
    {
        NSLog(@"The Player Wasnt Running");
        [self setCurrentTime:[self currentTime]];
    }
    
    isPaused = false;
    pausedTime = -1;
    
    if(DEBUG) NSLog(@"Play %lld %f %lld",seekNewTimePosition, _file.processingFormat.sampleRate, _player.lastRenderTime.sampleTime);
    
    [self startBuffer];
    
    if(seekNewTimePosition != -1)
    {
        if(seekNewTimePosition == 0)
        {
            seekNewTimePosition = self.currentTime;
        }
        
        AVAudioFramePosition curPos = _player.lastRenderTime.sampleTime;
        
        AVAudioTime* newTime = [[AVAudioTime alloc] initWithSampleTime:curPos-seekNewTimePosition atRate:_file.processingFormat.sampleRate];
        [_player playAtTime:newTime];
    }
    else
    {
        [_player play];
    }
    
    seekNewTimePosition = -1;
    wasInterrupted = false;
   // seekOldFramePosition = -1;
}

- (void)pause
{
    pausedTime = self.currentTime;
    
    if(DEBUG) NSLog(@"Seeking");
    
    double sampleRate = _file.fileFormat.sampleRate;
    AVAudioFramePosition framePosition = (long long)(self.currentTime * sampleRate);
    if(DEBUG) NSLog(@"FRAME: %lld %lld", _file.framePosition, framePosition);
    
    NSError* startError = nil;
    
    [self startBufferingURL:_url AtOffset:framePosition error:&startError];
    
    if(startError)
        NSLog(@"Start Error: %@",startError);
    
    isPaused = true;
    
}

- (void)stop
{
    if(DEBUG) NSLog(@"Stopping");
    wasInterrupted = true;
    
    //[self stopBufferLoop];

    if(_player)
    {
        [_player stop];
    }
    
    if(bufferArray != nil)
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
    
    if(_player)
    {
        [_player stop];
        _player = nil;
    }
    
    //[self stopBufferLoop];
}

- (NSTimeInterval)currentTime
{
    double sampleRate = _file.fileFormat.sampleRate;
    if(sampleRate == 0)
    {
        //NSLog(@"(%s) Sample Rate == 0",__PRETTY_FUNCTION__);
        return 0;
    }
    
    NSTimeInterval currentTime = ((NSTimeInterval)[_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime / sampleRate);
    
    //NSLog(@"Current Time: %f",currentTime);
    
    if(isPaused)
        return pausedTime;
    
    return currentTime;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    if(DEBUG) NSLog(@"Seeking");
    
    BOOL isPlaying = [_player isPlaying];
    
    //seekOldFramePosition = [_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime;
    
    double sampleRate = _file.fileFormat.sampleRate;
    AVAudioFramePosition framePosition = (long long)(currentTime * sampleRate);
    if(DEBUG) NSLog(@"FRAME: %lld %lld", _file.framePosition, framePosition);
    
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
    return (((NSTimeInterval)_file.length/sampleRate));// sampleRate;
}

#pragma mark Buffer Loop

- (void)startBuffer
{
    [self loadBuffer];
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
