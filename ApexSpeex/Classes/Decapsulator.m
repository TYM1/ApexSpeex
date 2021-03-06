//
//  Decapsulator.m
//  OggSpeex
//
//  Created by Jiang Chuncheng on 6/25/13.
//  Copyright (c) 2013 Sense Force. All rights reserved.
//

#import "Decapsulator.h"
#import "RawAudioDataPlayer.h"

#define DESIRED_BUFFER_SIZE 512

@interface Decapsulator()

@property (nonatomic, strong) NSOperationQueue *queue;

//将ogg格式数据转换为pcm数据
- (void)convertOggToPCMWithData:(NSData *)oggData;

//packet转换完成
- (void)packetDecoded:(Byte *)decodedData size:(int)dataSize;

- (void)error:(NSString *)errorDesription;

@end

@implementation Decapsulator


- (id)initWithFileName:(NSString *)filename {
    if (self = [super init]) {
        mFileName = [NSString stringWithString:filename];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ( ! [fileManager fileExistsAtPath:filename]) {
            NSLog(@"要播放的文件不存在:%@", filename);
        }
        operationQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (instancetype)initWithData:(NSMutableData *)data size:(int)size {
    if (self = [super init]) {
        operationQueue = [[NSOperationQueue alloc] init];
        _sourceData = data;
        _sourceDataSize = size;
    }
    return self;
}

- (void)play {
    isPlaying = YES;
    
    if ( ! self.player) {
        self.player = [[RawAudioDataPlayer alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingingOver:) name:NOTIFICATION_PLAY_OVER object:nil];
    }
    [self.player startPlay];
    
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(convertOggToPCMWithData:) object:[NSData dataWithContentsOfFile:mFileName]];
    [[[NSOperationQueue alloc] init] addOperation:operation];
    
}

- (void)playStream {
    isPlaying = YES;
    
    if ( ! self.player) {
        self.player = [[RawAudioDataPlayer alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingingOver:) name:NOTIFICATION_PLAY_OVER object:nil];
    }
    [self.player startPlay];
    
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(beginConvertOggToPCM) object:nil];
    _queue = [[NSOperationQueue alloc] init];
    [_queue addOperation:operation];
    
}

- (void)reNewData:(NSMutableData *)data {
    _sourceData = data;
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(goOnConvertOggToPCM) object:nil];
    [_queue addOperation:operation];
}

- (void)pausePlaying {
    isPlaying = NO;
    if (self.player) {
        [self.player pausePlay];
    }
}

-(void)continuePlaying {
    isPlaying = YES;
    if (self.player) {
        [self.player continuePlay];
    }
}

- (void)stopPlaying {
    isPlaying = NO;
    if (self.player) {
        [self.player stopPlay];
    }
//    [self playingingOver:nil];
}

-(void)setVolume:(CGFloat)volume {
    if (self.player) {
        [self.player setVolume:volume];
    }
}

#pragma mark -

//packet转换完成
- (void)packetDecoded:(Byte *)decodedData size:(int)dataSize {
    [self.player inputNewDataFromBuffer:decodedData size:dataSize];
}

//将ogg格式数据转换为pcm数据
- (void )convertOggToPCMWithData:(NSData *)oggData {
    const Byte *oggBytes = [oggData bytes];
    int oggByteSize = [oggData length];
    int readedBytes = 0;
    NSUInteger decodedByteLength = 0;
    
    packetNo = 0;
    pageNo = 0;
    
    ogg_sync_init(&oggSyncState);
    ogg_stream_init(&oggStreamState, 0);
    
    while (isPlaying) {
        
        int byteSizeToRead = oggByteSize - readedBytes;
        if (byteSizeToRead > DESIRED_BUFFER_SIZE) {
            byteSizeToRead = DESIRED_BUFFER_SIZE;
        }
        char *buffer = ogg_sync_buffer(&oggSyncState, DESIRED_BUFFER_SIZE);
        memcpy(buffer, oggBytes, byteSizeToRead);    //!!!
        oggBytes += byteSizeToRead;
        readedBytes += byteSizeToRead;
        NSLog(@"byteSizeToRead = %d, oggByteSize = %d, readedBytes = %d", byteSizeToRead, oggByteSize, readedBytes);
//        oggSyncState.bodybytes = byteSizeToRead;
        
        int resultSyncWrote = ogg_sync_wrote(&oggSyncState, byteSizeToRead);
        if (resultSyncWrote == -1) {
            [self error:@"error:the number of bytes written overflows the internal storage of the ogg_sync_state struct or an internal error occurred."];
            return;
        }
        
        while (YES) {
            ogg_page oggPage;
            int resultSyncPageout= ogg_sync_pageout(&oggSyncState, &oggPage);
            if (resultSyncPageout == 1) {
                NSLog(@"to decode a page which was synced and returned");
                
                //检查header和comment
                if(packetNo == 0) {
                    NSLog(@"it's the header page, check the header later");
                    if ([self readOggHeaderToStreamState:&oggStreamState fromOggPage:&oggPage]) {
                        oggStreamState.packetno = packetNo ++;
                        pageNo ++;
                    }
                    else {
                        packetNo = 0;
                    }
                    continue;
                }
                else if(packetNo == 1) {
                    NSLog(@"it's the comment");
                    oggStreamState.packetno = packetNo ++;
                    pageNo ++;
                    continue;
                }
                else {
                    oggStreamState.pageno = pageNo ++;
                }
                
                int resultStreamPagein = ogg_stream_pagein(&oggStreamState, &oggPage);
                if (resultStreamPagein == -1) {
                    [self error:@"ogg_stream_pagein failure"];
                    return;
                }
                
                SpeexCodec *codec = [[SpeexCodec alloc] init];
                [codec open:8];    // *****modify
                short decodedBuffer[1024];
                
                while (YES) {
                    ogg_packet oggPacket;
                    int packetResult = ogg_stream_packetout(&oggStreamState, &oggPacket);
                    if (packetResult == 1) {
                        //decode speex
//                        NSLog(@"to decode a packet");
                        packetNo ++;
                        int nDecodedByte = sizeof(short) * [codec decode:oggPacket.packet length:oggPacket.bytes output:decodedBuffer];
                        decodedByteLength += nDecodedByte;
                        [self packetDecoded:(Byte *)decodedBuffer size:nDecodedByte];
                    }
                    else if (packetResult == 0) {
                        //need more
                        break;
                    }
                    else {
                        break;
                    }
                }
                
                [codec close];
                codec = nil;
            }
            else if (resultSyncPageout == 0) {
                NSLog(@"not enough to decode a page or error");
                break;
            }
            else {
                [self error:@"stream has not yet captured sync"];
            }
        }
        
        if (byteSizeToRead < DESIRED_BUFFER_SIZE) {
            break;
        }
    }
    self.player.isDataInputOver = YES;
    
    NSLog(@"decode ogg to pcm: %d -> %d", [oggData length], decodedByteLength);
}

//将ogg格式数据转换为pcm数据
- (void )beginConvertOggToPCM{
    
    readedBytes = 0;
    decodedByteLength = 0;
    
    packetNo = 0;
    pageNo = 0;
    
    ogg_sync_init(&oggSyncState);
    ogg_stream_init(&oggStreamState, 0);
    
    if (isPlaying) {
        
        if (_sourceData.length <= readedBytes) {
            //数据不够
            return;
        }
        
        int byteSizeToRead = _sourceDataSize - readedBytes;
        if (byteSizeToRead > DESIRED_BUFFER_SIZE) {
            byteSizeToRead = DESIRED_BUFFER_SIZE;
        }
        char *buffer = ogg_sync_buffer(&oggSyncState, DESIRED_BUFFER_SIZE);
        
        Byte *oggBytes = [[_sourceData subdataWithRange:NSMakeRange(readedBytes, byteSizeToRead)] bytes];
        
        memcpy(buffer, oggBytes, byteSizeToRead);
        
        //!!!
        //        oggBytes += byteSizeToRead;
        readedBytes += byteSizeToRead;
        NSLog(@"byteSizeToRead = %d, oggByteSize = %d, readedBytes = %d", byteSizeToRead, _sourceDataSize, readedBytes);
        
        
        int resultSyncWrote = ogg_sync_wrote(&oggSyncState, byteSizeToRead);
        if (resultSyncWrote == -1) {
            [self error:@"error:the number of bytes written overflows the internal storage of the ogg_sync_state struct or an internal error occurred."];
            return;
        }
        
        while (YES) {
            ogg_page oggPage;
            int resultSyncPageout= ogg_sync_pageout(&oggSyncState, &oggPage);
            if (resultSyncPageout == 1) {
                NSLog(@"to decode a page which was synced and returned");
                
                //检查header和comment
                if(packetNo == 0) {
                    NSLog(@"it's the header page, check the header later");
                    if ([self readOggHeaderToStreamState:&oggStreamState fromOggPage:&oggPage]) {
                        oggStreamState.packetno = packetNo ++;
                        pageNo ++;
                    }
                    else {
                        packetNo = 0;
                    }
                    continue;
                }
                else if(packetNo == 1) {
                    NSLog(@"it's the comment");
                    oggStreamState.packetno = packetNo ++;
                    pageNo ++;
                    continue;
                }
                else {
                    oggStreamState.pageno = pageNo ++;
                }
                
                int resultStreamPagein = ogg_stream_pagein(&oggStreamState, &oggPage);
                if (resultStreamPagein == -1) {
                    [self error:@"ogg_stream_pagein failure"];
                    return;
                }
                
                SpeexCodec *codec = [[SpeexCodec alloc] init];
                [codec open:8];    // *****modify
                short decodedBuffer[1024];
                
                while (YES) {
                    ogg_packet oggPacket;
                    int packetResult = ogg_stream_packetout(&oggStreamState, &oggPacket);
                    if (packetResult == 1) {
                        //decode speex
                        //                        NSLog(@"to decode a packet");
                        packetNo ++;
                        int nDecodedByte = sizeof(short) * [codec decode:oggPacket.packet length:oggPacket.bytes output:decodedBuffer];
                        decodedByteLength += nDecodedByte;
                        [self packetDecoded:(Byte *)decodedBuffer size:nDecodedByte];
                    }
                    else if (packetResult == 0) {
                        //need more
                        break;
                    }
                    else {
                        break;
                    }
                }
                
                [codec close];
                codec = nil;
            }
            else if (resultSyncPageout == 0) {
                NSLog(@"not enough to decode a page or error");
                break;
            }
            else {
                [self error:@"stream has not yet captured sync"];
            }
        }
        
        //        if (byteSizeToRead < DESIRED_BUFFER_SIZE) {
        //            break;
        //        }
    }
    //    self.player.isDataInputOver = YES;
    
    NSLog(@"decode ogg to pcm: %d -> %d", [_sourceData length], decodedByteLength);
}


- (void)goOnConvertOggToPCM
{
    if (isPlaying) {
        
        if (_sourceData.length <= readedBytes) {
            //数据不够
            return;
        }
        int byteSizeToRead = _sourceDataSize - readedBytes;
        if (byteSizeToRead > DESIRED_BUFFER_SIZE) {
            byteSizeToRead = DESIRED_BUFFER_SIZE;
        }
        char *buffer = ogg_sync_buffer(&oggSyncState, DESIRED_BUFFER_SIZE);
        
        Byte *oggBytes = [[_sourceData subdataWithRange:NSMakeRange(readedBytes, byteSizeToRead)] bytes];
        
        memcpy(buffer, oggBytes, byteSizeToRead);
        
        //!!!
        //        oggBytes += byteSizeToRead;
        readedBytes += byteSizeToRead;
        NSLog(@"byteSizeToRead = %d, oggByteSize = %d, readedBytes = %d", byteSizeToRead, _sourceDataSize, readedBytes);
        
        
        int resultSyncWrote = ogg_sync_wrote(&oggSyncState, byteSizeToRead);
        if (resultSyncWrote == -1) {
            [self error:@"error:the number of bytes written overflows the internal storage of the ogg_sync_state struct or an internal error occurred."];
            return;
        }
        
        while (YES) {
            ogg_page oggPage;
            int resultSyncPageout= ogg_sync_pageout(&oggSyncState, &oggPage);
            if (resultSyncPageout == 1) {
                NSLog(@"to decode a page which was synced and returned");
                
                //检查header和comment
                if(packetNo == 0) {
                    NSLog(@"it's the header page, check the header later");
                    if ([self readOggHeaderToStreamState:&oggStreamState fromOggPage:&oggPage]) {
                        oggStreamState.packetno = packetNo ++;
                        pageNo ++;
                    }
                    else {
                        packetNo = 0;
                    }
                    continue;
                }
                else if(packetNo == 1) {
                    NSLog(@"it's the comment");
                    oggStreamState.packetno = packetNo ++;
                    pageNo ++;
                    continue;
                }
                else {
                    oggStreamState.pageno = pageNo ++;
                }
                
                int resultStreamPagein = ogg_stream_pagein(&oggStreamState, &oggPage);
                if (resultStreamPagein == -1) {
                    [self error:@"ogg_stream_pagein failure"];
                    return;
                }
                
                SpeexCodec *codec = [[SpeexCodec alloc] init];
                [codec open:8];    // *****modify
                short decodedBuffer[1024];
                
                while (YES) {
                    ogg_packet oggPacket;
                    int packetResult = ogg_stream_packetout(&oggStreamState, &oggPacket);
                    if (packetResult == 1) {
                        //decode speex
                        //                        NSLog(@"to decode a packet");
                        packetNo ++;
                        int nDecodedByte = sizeof(short) * [codec decode:oggPacket.packet length:oggPacket.bytes output:decodedBuffer];
                        decodedByteLength += nDecodedByte;
                        [self packetDecoded:(Byte *)decodedBuffer size:nDecodedByte];
                    }
                    else if (packetResult == 0) {
                        //need more
                        break;
                    }
                    else {
                        break;
                    }
                }
                
                [codec close];
                codec = nil;
            }
            else if (resultSyncPageout == 0) {
                NSLog(@"not enough to decode a page or error");
                break;
            }
            else {
                [self error:@"stream has not yet captured sync"];
            }
        }
        
    }
    
    
    if ([_sourceData length] == _sourceDataSize) {
        self.player.isDataInputOver = YES;
    }
    
}

- (BOOL)readOggHeaderToStreamState:(ogg_stream_state *)os fromOggPage:(ogg_page *)op {
    if (op->body_len != 80) {
        return NO;
    }
//    if ( ! [[NSString stringWithCharacters:(unichar *)op->header length:4] isEqualToString:@"OggS"]) {
//        return NO;
//    }
    os->serialno = ogg_page_serialno(op);
    return YES;
}

- (void)error:(NSString *)errorDesription {
    NSLog(@"error:%@", errorDesription);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - DecapsulatingDelegate

- (void)playingingOver:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(decapsulatingAndPlayingOver)]) {
        [self.delegate decapsulatingAndPlayingOver];
    }
}

@end
