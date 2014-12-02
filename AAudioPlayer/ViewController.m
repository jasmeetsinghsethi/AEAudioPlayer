//
//  ViewController.m
//  AAudioPlayer
//
//  Created by Daniel Jackson on 11/20/14.
//  Copyright (c) 2014 Daniel Jackson. All rights reserved.
//

#import "ViewController.h"
#import "AAudioPlayer.h"

@interface ViewController () <AAudioPlayerDelegate>
{
    NSMutableArray* audioFiles;
    int index;
    AAudioPlayer* player;
    IBOutlet UIProgressView *progressBar;
    
    NSTimer* timer;
    
    IBOutlet UILabel *frequencyLabel1;
    IBOutlet UILabel *frequencyLabel2;
    IBOutlet UILabel *frequencyLabel3;
    IBOutlet UILabel *frequencyLabel4;
    IBOutlet UILabel *frequencyLabel5;
    IBOutlet UILabel *frequencyLabel6;
    IBOutlet UILabel *frequencyLabel7;
    IBOutlet UILabel *frequencyLabel8;
    IBOutlet UILabel *frequencyLabel9;
    IBOutlet UILabel *frequencyLabel10;
}
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    audioFiles = [NSMutableArray new];
    [audioFiles addObject:[[NSBundle mainBundle] URLForResource: @"short"
                                                  withExtension: @"mp3"]];
    //[audioFiles addObject:[[NSBundle mainBundle] URLForResource:@"BachGavotteShort" withExtension:@"mp3"]];
    
    
    index = 0;
    
    /*frequencyLabel1.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:0]];
    frequencyLabel2.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:1]];
    frequencyLabel3.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:2]];
    frequencyLabel4.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:3]];
    frequencyLabel5.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:4]];
    frequencyLabel6.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:5]];
    frequencyLabel7.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:6]];
    frequencyLabel8.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:7]];
    frequencyLabel9.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:8]];
    frequencyLabel10.text = [NSString stringWithFormat:@"%d",[AAudioPlayer getBandFrequencyWithBandIndex:9]];*/
}

- (IBAction)setFrequency:(UISlider*)sender {
    
    NSInteger tag = [sender tag];
    CGFloat value = [sender value];
    
    int rangeTotal = 96 + 24;
    int theSpot = 24 - rangeTotal*value;
    
    
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
            player = [[AAudioPlayer alloc] initPCMBufferWithContentsOfURL:audioFiles[index] error:&playingError];
            
            
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

-(void)audioPlayerDidFinishPlaying:(AAudioPlayer *)player successfully:(BOOL)flag
{
    [self nextPressed:nil];
    NSLog(@"Starting new song");
}

@end
