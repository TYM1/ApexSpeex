//
//  PlayerManager.h
//  OggSpeex
//
//  Created by Jiang Chuncheng on 6/25/13.
//  Copyright (c) 2013 Sense Force. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "Decapsulator.h"

@protocol PlayingDelegate <NSObject>

- (void)playingStoped;

@optional
- (void)playingStart;
- (void)playingPause;
- (void)playingContinue;

@end

@interface PlayerManager : NSObject <DecapsulatingDelegate, AVAudioPlayerDelegate> {
    Decapsulator *decapsulator;
    AVAudioPlayer *avAudioPlayer;
}

@property (nonatomic, strong) Decapsulator *decapsulator;
@property (nonatomic, strong) AVAudioPlayer *avAudioPlayer;
@property (nonatomic, weak)  id<PlayingDelegate> delegate;

+ (PlayerManager *)sharedManager;

- (void)playAudioWithFileName:(NSString *)filename delegate:(id<PlayingDelegate>)newDelegate;
- (void)playAudioWithData:(NSMutableData *)data size:(NSInteger)size delegate:(id<PlayingDelegate>)newDelegate;
- (void)appendAudioData:(NSData *)data;
- (void)pausePlaying;
- (void)continuePlaying;
- (void)stopPlaying;
- (void)setVolume:(CGFloat)volume;

@end
