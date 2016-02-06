//
//  MusicController.m
//  NepTunes
//
//  Created by rurza on 02/02/16.
//  Copyright © 2016 micropixels. All rights reserved.
//

#import "MusicController.h"
#import "MusicScrobbler.h"
#import "SettingsController.h"
#import "MenuController.h"
#import "Track.h"

#define FOUR_MINUTES 60 * 4

@interface MusicController ()
@property (nonatomic) MusicScrobbler *musicScrobbler;
@property (nonatomic) SettingsController *settingsController;
@property (nonatomic) IBOutlet MenuController *menuController;
@property (nonatomic) NSTimer* scrobbleTimer;
@property (nonatomic) NSTimer* nowPlayingTimer;
@property (nonatomic) NSTimer* mainTimer;
@end

@implementation MusicController

#pragma mark - Responding to notifications

+ (instancetype)sharedController
{
    __strong static id _sharedInstance = nil;
    static dispatch_once_t onlyOnce;
    dispatch_once(&onlyOnce, ^{
        _sharedInstance = [[self _alloc] _init];
        
    });
    return _sharedInstance;
}

+ (id) allocWithZone:(NSZone*)z { return [self sharedController];              }
+ (id) alloc                    { return [self sharedController];              }
- (id) init                     { return self;}
+ (id)_alloc                    { return [super allocWithZone:NULL]; }
- (id)_init                     { return [super init];               }

-(void)awakeFromNib
{
    [self setupNotifications];
}

-(void)setupNotifications
{
    [self updateTrackInfo:nil];

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(updateTrackInfo:)
                                                            name:@"com.apple.iTunes.playerInfo"
                                                          object:nil];
    
    
}


-(void)updateTrackInfo:(NSNotification *)note
{
    if (self.settingsController.debugMode) {
        NSLog(@"Notification sent from iTunes");
    }
    [self invalidateTimers];
    self.mainTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(prepareTrack:) userInfo:note.userInfo ? note.userInfo : nil repeats:NO];
    [self getInfoAboutTrackFromNotificationOrFromiTunes:note.userInfo];
    [self updateMenu];
}

-(void)prepareTrack:(NSTimer *)timer
{
    if (self.settingsController.debugMode) {
        NSLog(@"prepareTrack called");
    }
   
    if ([timer isValid]) {
//        [self invalidateTimers];
        [self getInfoAboutTrackFromNotificationOrFromiTunes:timer.userInfo];
        //        [self updateMenu];
        
        if (self.isiTunesRunning) {
            if (self.settingsController.debugMode) {
                NSLog(@"iTunes is running");
            }

            if (self.playerState == iTunesEPlSPlaying) {
                NSTimeInterval trackLength;
                
                
                if (self.iTunes.currentTrack.artist && self.iTunes.currentTrack.artist.length) {
                    trackLength = (NSTimeInterval)self.iTunes.currentTrack.duration;
                }
                else {
                    trackLength = (NSTimeInterval)self.musicScrobbler.currentTrack.duration;
                }
                
                NSTimeInterval scrobbleTime = ((trackLength * (self.settingsController.percentForScrobbleTime.floatValue / 100)) < FOUR_MINUTES) ? (trackLength * (self.settingsController.percentForScrobbleTime.floatValue / 100)) : FOUR_MINUTES;
                
                if ((self.settingsController.percentForScrobbleTime.floatValue / 100) > 0.95) {
                    scrobbleTime -= 2;
                }
                if (self.settingsController.debugMode) {
                    NSLog(@"Scrobble time for track %@ is %f", self.musicScrobbler.currentTrack, scrobbleTime); 
                }
                
                scrobbleTime -=2;
                
                if (scrobbleTime == 0) {
                    scrobbleTime = 16.0f;
                }
                
                if (trackLength >= 31.0f) {
                    self.nowPlayingTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                                            target:self
                                                                          selector:@selector(nowPlaying)
                                                                          userInfo:nil
                                                                           repeats:NO];
                }
                if (trackLength >= 31.0f) {
                    NSDictionary *userInfo = [timer.userInfo copy];
                    self.scrobbleTimer = [NSTimer scheduledTimerWithTimeInterval:scrobbleTime
                                                                          target:self
                                                                        selector:@selector(scrobble:)
                                                                        userInfo:userInfo
                                                                         repeats:NO];
                }
            }
        }
    }
}

-(void)invalidateTimers
{
    if (self.mainTimer) {
        [self.mainTimer invalidate];
        self.mainTimer = nil;
    }
    if (self.scrobbleTimer) {
        [self.scrobbleTimer invalidate];
        self.scrobbleTimer = nil;
    }
    if (self.nowPlayingTimer) {
        [self.nowPlayingTimer invalidate];
        self.nowPlayingTimer = nil;
    }
    if (self.settingsController.debugMode) {
        NSLog(@"Timers invalidated");
    }
}

-(void)getInfoAboutTrackFromNotificationOrFromiTunes:(NSDictionary *)userInfo
{
    [self.musicScrobbler updateCurrentTrackWithUserInfo:userInfo];
    //2s są po to by Itunes sie ponownie nie wlaczal
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (self.isiTunesRunning) {
        if (self.musicScrobbler.currentTrack.trackName && self.musicScrobbler.currentTrack.artist && self.musicScrobbler.currentTrack.duration == 0 && self.iTunes.currentTrack.artist.length) {
            self.musicScrobbler.currentTrack.duration = self.iTunes.currentTrack.duration;
        }
        else if (self.iTunes.currentTrack.name && self.iTunes.currentTrack.album) {
            self.musicScrobbler.currentTrack = [Track trackWithiTunesTrack:self.iTunes.currentTrack];
//            [self updateMenu];
        }
    }
}

-(void)loveTrackIniTunes
{
//    self.iTunes
    self.iTunes.currentTrack.loved = YES;
}

-(void)updateMenu
{
    [self.menuController updateMenu];
}

-(void)scrobble:(NSTimer *)timer
{
    [self.musicScrobbler scrobbleCurrentTrack];
}

-(void)nowPlaying
{
    [self.musicScrobbler nowPlayingCurrentTrack];
}

#pragma mark - Getters
-(MusicScrobbler *)musicScrobbler
{
    if (!_musicScrobbler) {
        _musicScrobbler = [MusicScrobbler sharedScrobbler];
    }
    return _musicScrobbler;
}


-(SettingsController *)settingsController
{
    if (!_settingsController) {
        _settingsController = [SettingsController sharedSettings];
    }
    return _settingsController;
}


-(iTunesApplication *)iTunes
{
    if (!_iTunes) {
        _iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    }
    return _iTunes;
}

-(iTunesEPlS)playerState
{
    if (self.isiTunesRunning) {
        return self.iTunes.playerState;
    }
    return iTunesEPlSStopped;
}

-(BOOL)isiTunesRunning
{
    return self.iTunes.isRunning;
}

@end