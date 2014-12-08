AAudioPlayer
============

A Music Player that utilizes Apple's new AVAudioEngine framework in order to mimic AVAudioPlayer. The class uses a PCM buffer in order to perform seeking. To install just copy AAudioPlayer.h and AAudioPlayer.m to your project. The class should behave almost exactly like AVAudioPlayer.

To use the equalizer. Initialize with an array of NSNumbers that indicate the frequencies. Then set the gain for each frequency. One problem, that id love to find a solution for is that there is a slight crackle when adjusting frequencies while playing. 
