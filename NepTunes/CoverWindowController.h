//
//  CoverWindowController.h
//  NepTunes
//
//  Created by rurza on 11/02/16.
//  Copyright © 2016 micropixels. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class Track;
@class ControlViewController;

@interface CoverWindowController : NSWindowController

@property (weak) IBOutlet ControlViewController *controlViewController;

-(void)updateCoverWithTrack:(Track *)track;
-(void)fadeCover:(BOOL)direction;
-(void)showControls;
-(void)hideControls;

@end
