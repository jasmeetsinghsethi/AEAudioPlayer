//
//  AAudioPlayer.m
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import "AEAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>

#define kAE_DEBUG 0

#define kNumBufferNodes 4

@interface AEAudioPlayer ()
{
    NSMutableArray* bufferArray;
    AVAudioPCMBuffer* skipBufferCompletion;
    
    NSTimer* runTimer;
    NSThread* runThread;
    
    BOOL wasInterrupted;
    
    double fileSampleRate;
    AVAudioFramePosition seekNewTimePosition;
    
    AVAudioUnitEQ* eq;
    NSArray* frequencies;
    NSMutableArray* frequencyGains;
    
    BOOL hasInitialized;
    
    BOOL isPaused;
    NSTimeInterval pausedTime;
    
    //used to prevent multiple interruption notifications
    BOOL isAudioInterruption;
}
@end

@implementation AEAudioPlayer

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError
{
    if(kAE_DEBUG) NSLog(@"Beginning new player initialization");
    return [self initWithContentsOfURL:url error:outError frequencies:@[]];
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError frequencies:(NSArray *)freqs
{
    self = [super init];
    if(self)
    {
        seekNewTimePosition = -1;
        
        _url = url;
        
        frequencies = freqs;
        frequencyGains = [[NSMutableArray alloc] init];
        for(int i=0; i<frequencies.count; i++)
        {
            [frequencyGains addObject:@(0)];
        }
        
        hasInitialized = false;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notification:) name:
         AVAudioSessionInterruptionNotification object:nil];
    }
    return self;
}

- (void)notification:(NSNotification*)notificaiton
{
    if( [notificaiton.userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan )
    {
        if (_file != nil)
        {
            fileSampleRate = _file.fileFormat.sampleRate;
            seekNewTimePosition = self.currentTime * fileSampleRate;
            pausedTime = self.currentTime;
        }
        
        wasInterrupted = true;
        isAudioInterruption = true;
        isPaused = true;
        
        _file = nil;
        
        if(_delegate != nil && [_delegate respondsToSelector:@selector(audioPlayerBeginInterruption:)])
        {
            [_delegate audioPlayerBeginInterruption:self];
        }
        
        [_player pause];
        [[self.class sharedEngine] pause];
        
        if(bufferArray != nil)
            [bufferArray removeAllObjects];
        _player = nil;
    }
    
    if( [notificaiton.userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeEnded )
    {
        if(_delegate != nil && [_delegate respondsToSelector:@selector(audioPlayerEndInterruption:withOptions:)])
        {
            NSInteger options = [notificaiton.userInfo[AVAudioSessionInterruptionOptionKey] intValue];
            [_delegate audioPlayerEndInterruption:self withOptions:options];
        }
    }
}

#pragma mark

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

- (void)initializePlayerNodeError:(NSError**)outError offset:(AVAudioFramePosition)offset {
    AVAudioEngine* engine = [self.class sharedEngine];
    
    _player = [[AVAudioPlayerNode alloc] init];
    _file = [[AVAudioFile alloc] initForReading:_url error:outError];
    
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
    
    @try {
        _file.framePosition = offset;
    }
    @catch (NSException *exception) {
        _file.framePosition = offset;
        NSLog(@"(%s) EXCEPTION: %@",__PRETTY_FUNCTION__,exception.description);
        
        if(kAE_DEBUG)
        {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"EXCEPTION" message:[NSString stringWithFormat:@"(%s) EXCEPTION: %@",__PRETTY_FUNCTION__,exception.description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alertView show];
        }
    }
    @finally {
    }
}

- (void)startBufferingURL:(NSURL*)url AtOffset:(AVAudioFramePosition)offset error:(NSError**)outError
{
    _url = url;
    
    [self stop];
    
    if(kAE_DEBUG) NSLog(@"Initializing");
    
    AVAudioEngine* engine = [self.class sharedEngine];
    
    [self initializePlayerNodeError:outError offset:offset];
    
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
    
    if(kAE_DEBUG) NSLog(@"(%s) N:%lld / Offset:%lld",__PRETTY_FUNCTION__,seekNewTimePosition,offset);
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
            if(kAE_DEBUG) NSLog(@"Song Finished");
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
    
    AVAudioPCMBuffer* buffer = nil;
    
    @try
    {
        
        AVAudioFormat *format = _file.processingFormat;
        UInt32 frameCount = (64 * 1024);
        buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameCount];
        NSError* error = nil;
        if(![_file readIntoBuffer:buffer error:&error])
        {
            NSLog(@"failed to read audio file: %@",error);
            return nil;
        }
        if(buffer.frameLength == 0)
            return nil;
        
    }
    @catch (NSException *exception) {
        
        NSLog(@"(%s) EXCEPTION: %@",__PRETTY_FUNCTION__,exception.description);
        
        if(kAE_DEBUG)
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"EXCEPTION" message:[NSString stringWithFormat:@"(%s) EXCEPTION: %@",__PRETTY_FUNCTION__,exception.description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
    }
    
    return buffer;
}

- (void)finished
{
    if(kAE_DEBUG) NSLog(@"Finished Playing");
}

- (void)play
{
    if([self playing])
        return;
    
    _player = nil;
    _file = nil;
    
    isAudioInterruption = false;
    isPaused = false;
    
    if(!hasInitialized)
    {
        [self startBufferingURL:self.url AtOffset:0 error:nil];
        hasInitialized = true;
    }
    
    wasInterrupted = false;
    
    @try
    {
        if( _player == nil ) {
            if(seekNewTimePosition == -1)
                seekNewTimePosition = 0;
            [self initializePlayerNodeError:nil offset:seekNewTimePosition];
        }
        
        if(![[self.class sharedEngine] isRunning])
        {
            NSError* startError = nil;
            [[self.class sharedEngine] startAndReturnError:&startError];
            if(startError)
            {
                NSLog(@"Error Starting Player: %@",startError);
            }
        }
    }
    @catch (NSException *exception) {
    }
    
    if(kAE_DEBUG) NSLog(@"[-(void)play]: seekNewTimeP:%lld SampleRate:%f SampleTime:%lld",seekNewTimePosition, _file.processingFormat.sampleRate, _player.lastRenderTime.sampleTime);
    
    fileSampleRate = _file.fileFormat.sampleRate;
    
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
}

- (void)pause
{
    if(_file == nil && _player == nil) {
        return;
    }
    
    wasInterrupted = true;
    isAudioInterruption = false;
    
    if (_file != nil)
    {
        fileSampleRate = _file.fileFormat.sampleRate;
        seekNewTimePosition = self.currentTime * _file.fileFormat.sampleRate;
        pausedTime = self.currentTime;
    }
    
    [_player pause];
    [[self.class sharedEngine] pause];
    
    isPaused = true;
    
    if(bufferArray != nil)
        [bufferArray removeAllObjects];
    _player = nil;
    _file = nil;
}

- (void)stop
{
    if(kAE_DEBUG) NSLog(@"Stopping");
    wasInterrupted = true;
    isAudioInterruption = false;
    
    seekNewTimePosition = 0;
    
    if(_file.fileFormat.sampleRate != 0) fileSampleRate = _file.fileFormat.sampleRate;
    
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
    if(kAE_DEBUG) NSLog(@"[-(BOOL)playing]: %d",_player.isPlaying);
    return _player.playing;
}

- (void)dealloc
{
    if(kAE_DEBUG) NSLog(@"Dealloc");
    _delegate = nil;
    
    if(_player)
    {
        [_player stop];
        _player = nil;
    }
}

- (NSTimeInterval)currentTime
{
    if(isPaused)
        return pausedTime;
    
    double sampleRate = _file.fileFormat.sampleRate;
    if(sampleRate == 0)
    {
        return 0;
    }
    
    NSTimeInterval currentTime = ((NSTimeInterval)[_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime / sampleRate);
    
    return currentTime;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    if(kAE_DEBUG) NSLog(@"Seeking To Location: %f",currentTime);
    
    BOOL isPlaying = [_player isPlaying];
    
    [self pause];
    
    if(fileSampleRate != 0) seekNewTimePosition = currentTime * fileSampleRate;
    pausedTime = currentTime;
    
    /*isPaused = false;
     seekNewTimePosition = -1;
     
     BOOL isPlaying = [_player isPlaying];
     
     //seekOldFramePosition = [_player playerTimeForNodeTime:_player.lastRenderTime].sampleTime;
     
     double sampleRate = _file.fileFormat.sampleRate;
     AVAudioFramePosition framePosition = (long long)(currentTime * sampleRate);
     if(kAE_DEBUG) NSLog(@"FRAME: %lld %lld", _file.framePosition, framePosition);
     
     NSError* startError = nil;
     
     [self startBufferingURL:_url AtOffset:framePosition error:&startError];
     
     if(startError)
     NSLog(@"Start Error: %@",startError);*/
    
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
