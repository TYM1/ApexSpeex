//
//  Decapsulator.h
//  OggSpeex
//
//  Created by Jiang Chuncheng on 6/25/13.
//  Copyright (c) 2013 Sense Force. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SpeexCodec.h"

@class RawAudioDataPlayer;

@protocol DecapsulatingDelegate <NSObject>

- (void)decapsulatingAndPlayingOver;

@end

@interface Decapsulator : NSObject {
    NSString *mFileName;
    
    BOOL isPlaying;
    
    NSOperationQueue *operationQueue;
    
    ogg_stream_state oggStreamState;
    ogg_sync_state oggSyncState;
    int packetNo;
    int pageNo;//new
    int readedBytes;
    NSUInteger decodedByteLength;
}

@property (atomic, strong) RawAudioDataPlayer *player;
@property (nonatomic, weak) id<DecapsulatingDelegate> delegate;

//生成对象
- (id)initWithFileName:(NSString *)filename;
- (void)play;
- (void)stopPlaying;
- (void)pausePlaying;
- (void)continuePlaying;
- (void)setVolume:(CGFloat)volume;

- (instancetype)initWithData:(NSMutableData *)data size:(int)size;
- (void)playStream;
- (void)reNewData:(NSMutableData *)data;

@end
