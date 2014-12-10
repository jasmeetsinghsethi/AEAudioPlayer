//
//  ViewController.m
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import "ViewController.h"
#import "AEAudioPlayer.h"

@interface ViewController () <AEAudioPlayerDelegate>
{
    NSMutableArray* audioFiles;
    int index;
    AEAudioPlayer* player;
    IBOutlet UIProgressView *progressBar;
    
    NSTimer* timer;
    
    NSMutableArray* eqValues;
    
}

@property (strong, nonatomic) UISlider *frequency1;
@property (strong, nonatomic) UISlider *frequency2;
@property (strong, nonatomic) UISlider *frequency3;
@property (strong, nonatomic) UISlider *frequency4;
@property (strong, nonatomic) UISlider *frequency5;
@property (strong, nonatomic) UISlider *frequency6;
@property (strong, nonatomic) UISlider *frequency7;
@property (strong, nonatomic) UISlider *frequency8;
@property (strong, nonatomic) UISlider *frequency9;
@property (strong, nonatomic) UISlider *frequency10;

@end

@implementation ViewController


- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    audioFiles = [NSMutableArray new];
    [audioFiles addObject:[[NSBundle mainBundle] URLForResource: @"short"
                                                  withExtension: @"mp3"]];
    
    eqValues = [[NSMutableArray alloc] initWithCapacity:10];
    for( int i=0; i<10; i++)
    {
        eqValues[i] = @0;
    }
    index = 0;
    
    int i = 0;
    
    self.frequency1 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:0];
    self.frequency2 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:1];
    self.frequency3 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:2];
    self.frequency4 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:3];
    self.frequency5 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:4];
    self.frequency6 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.3 bandIndex:5];
    self.frequency7 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:6];
    self.frequency8 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:7];
    self.frequency9 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:8];
    self.frequency10 = [self createSliderAtYOffset:50+(40*i++) selector:@selector(setFreq:) value:0.5 bandIndex:9];
}

- (UISlider*)createSliderAtYOffset:(CGFloat)YOffset selector:(SEL)selector value:(CGFloat)value bandIndex:(int)bandIndex
{
    UISlider* slider = nil;
    
    CGRect frame = CGRectMake(50, YOffset, 250.0, 20);
    slider = [[UISlider alloc] initWithFrame:frame];
    slider.minimumValue = 0.0;
    slider.maximumValue = 1.0;
    slider.value = value;
    slider.tag = bandIndex;
    
    [slider addTarget:self action:selector forControlEvents:UIControlEventTouchDragInside];
    
    [self.view addSubview:slider];
    
    return slider;
}

- (void)setFreq:(UISlider*)sender {
    CGFloat value = [self getValueFromSlider:sender];
    [player setEqGain:value forBand:(int)sender.tag];
}

-(CGFloat)getValueFromSlider:(UISlider*)slider
{
    if(slider.value >= 0.5)
    {
        CGFloat newValue = (slider.value - 0.5) * 2;
        NSLog(@"%f #1 : %f",slider.value,newValue);
        return newValue * 24;
    }
    else
    {
        CGFloat newValue = slider.value * 2;
        NSLog(@"%f #2 : %f",slider.value,newValue);
        return -24 + (newValue * 24);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)playPausePressed:(id)sender
{
        if(player == nil)
        {
            progressBar.progress = 0.0;
            NSError* playingError = nil;
            player = [[AEAudioPlayer alloc] initWithContentsOfURL:audioFiles[index] error:&playingError frequencies:
                      @[ @32, @64, @125, @250, @500, @1000, @2000, @4000, @8000, @16000]];
            
            player.delegate = self;
            if(playingError)
            {
                NSLog(@"Playing error %@",playingError);
            }
        }
        
        if(player.playing)
        {
            [player pause];
            [timer invalidate];
            timer = nil;
        }
        else
        {
            [player play];
            
            [self setFreq:self.frequency1];
            [self setFreq:self.frequency2];
            [self setFreq:self.frequency3];
            [self setFreq:self.frequency4];
            [self setFreq:self.frequency5];
            [self setFreq:self.frequency6];
            [self setFreq:self.frequency7];
            [self setFreq:self.frequency8];
            [self setFreq:self.frequency9];
            [self setFreq:self.frequency10];
            
            [timer invalidate];
            timer = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTime) userInfo:nil repeats:YES];
            });
        }
}

- (void)updateTime
{
    static int setTime = 5;
    NSTimeInterval currentTime = player.currentTime;
    NSTimeInterval duration = player.duration;
    
    NSLog(@"Current Time: %f Duration: %f",currentTime,duration);
    
    float progress = currentTime/duration;
    progressBar.progress = progress;
    
    if(setTime-- == 0)
    {
        [player setCurrentTime:14.0];
    }
}

- (IBAction)prevPressed:(id)sender
{
    [player stop];
    index--;
    if(index < 0)
        index = (int)audioFiles.count-1;
    player = nil;
    [self playPausePressed:nil];
}
- (IBAction)nextPressed:(id)sender
{
    [player stop];
    index++;
    if(index >= audioFiles.count)
        index = 0;
    player = nil;
    [self playPausePressed:nil];
}

-(void)audioPlayerDidFinishPlaying:(AEAudioPlayer *)player successfully:(BOOL)flag
{
    [self nextPressed:nil];
    NSLog(@"Starting new song");
}

@end
