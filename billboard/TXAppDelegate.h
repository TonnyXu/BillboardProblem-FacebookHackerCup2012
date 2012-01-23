//
//  TXAppDelegate.h
//  billboard
//
//  Created by Tonny Xu on 12/01/23.
//  Copyright (c) 2012年 totodotnet.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TXAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSTextField *outputLabel;
- (IBAction)selectFileAction:(id)sender;
@property (weak) IBOutlet NSTextField *inputFileLabel;

@end
