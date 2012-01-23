//
//  TXAppDelegate.m
//  billboard
//
//  Created by  on 12/01/23.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "TXAppDelegate.h"
#import "FileReader.h"

@interface TXAppDelegate()

@property (assign) NSInteger numberOfCases;
@property (strong) NSMutableArray *allCases;

- (void)readInputFrom:(NSURL *)fileURL;
- (void)analyzeAllCases:(NSArray *)cases;
- (NSInteger)maxFontSizeFrom:(NSInteger)aSize 
                    withText:(NSString *)text 
             withTextInArray:(NSArray *)textInArray 
            constraintToArea:(NSInteger)rectArea 
              recursiveDepth:(NSInteger *)depth 
               possibleSizes:(NSMutableArray *)possibleSizes;

@end

@implementation TXAppDelegate
@synthesize inputFileLabel;

@synthesize window = _window;
@synthesize outputLabel;
@synthesize numberOfCases;
@synthesize allCases;

- (void)readInputFrom:(NSURL *)fileURL{
  NSParameterAssert(fileURL);
  
  NSString *filePath = [fileURL path];
  NSLog(@"Got a file path: %@", filePath);
  FileReader *reader = [[FileReader alloc] initWithFilePath:filePath];
  
  NSInteger lineDelimiterLength = [[reader lineDelimiter] length];
  
  if (nil == reader) {
    [self.outputLabel setTitleWithMnemonic:@"There are some error with your text file."];
    return;
  }
  
  __block int readLineIndex = 0;
  [reader enumerateLinesUsingBlock:^(NSString *aLine, BOOL *stop) {
    NSRange firstSpace = [aLine rangeOfString:@" "];
    
    if (firstSpace.location == NSNotFound) {
      // First line. 
      NSInteger cases = [aLine intValue];
      if (0 != cases && INT_MAX != cases && INT_MIN != cases) {
        self.numberOfCases = cases;
        [self.outputLabel setTitleWithMnemonic:[NSString stringWithFormat:@"Start analyzing %d cases;", self.numberOfCases]];
      }else{
        self.numberOfCases = 0;
        [self.outputLabel setTitleWithMnemonic:[NSString stringWithFormat:@"No valid case number: %@", aLine]];
        *stop = YES;
        return ;
      }
    }else{
      if (readLineIndex >= self.numberOfCases) {
        *stop = YES;
        return;
      }
      
      NSRange secondSapce = [aLine rangeOfString:@" " options:NSLiteralSearch range:NSMakeRange(firstSpace.location + 1, [aLine length] - firstSpace.location - 1)];
      NSString *billboardWidth = [aLine substringToIndex:firstSpace.location];
      NSString *billboardHeight = [aLine substringWithRange:NSMakeRange(firstSpace.location + 1, secondSapce.location - firstSpace.location - 1)];
      NSString *billboardText = [aLine substringWithRange:NSMakeRange(secondSapce.location + 1, aLine.length - secondSapce.location - 1 - lineDelimiterLength)];

      NSDictionary *aCase = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt:[billboardWidth intValue]], @"width", 
                             [NSNumber numberWithInt:[billboardHeight intValue]], @"height", 
                             billboardText, @"text", 
                             nil];
      [self.allCases addObject:aCase];
      
      NSLog(@"W: %@, H:%@, S:\"%@\"", [aCase objectForKey:@"width"], [aCase objectForKey:@"height"], [aCase objectForKey:@"text"]);
      readLineIndex ++;
    }
  }];
}

- (void)analyzeAllCases:(NSArray *)cases{
  NSParameterAssert(cases);

  [cases enumerateObjectsUsingBlock:^(NSDictionary *aCase, NSUInteger idx, BOOL *stop) {
    NSInteger width = [[aCase objectForKey:@"width"] integerValue];
    NSInteger height = [[aCase objectForKey:@"height"] integerValue];
    NSString *text = [aCase objectForKey:@"text"];
    
    NSArray *textArray = [text componentsSeparatedByString:@" "];
    
    // start from one line or one column.
    NSInteger maxFontSize = MIN(width,height);
    
    // find the max font size for all the character, not counting words and space.
    NSInteger *recursiveDepth = 0;
    NSMutableArray *possibleSizes = [NSMutableArray array];
    maxFontSize = [self maxFontSizeFrom:maxFontSize 
                               withText:text 
                        withTextInArray:textArray 
                       constraintToArea:width*height 
                         recursiveDepth:recursiveDepth 
                          possibleSizes:possibleSizes];
    
    [self.outputLabel setTitleWithMnemonic:[NSString stringWithFormat:@"%@\nCase #%d: %d", [self.outputLabel stringValue], (idx + 1), maxFontSize]];
  }];
  
}

// Main algorithm! Using recurrsive algorithm to find the max font size.
- (NSInteger)maxFontSizeFrom:(NSInteger)aSize 
                    withText:(NSString *)text 
             withTextInArray:(NSArray *)textInArray 
            constraintToArea:(NSInteger)rectArea 
              recursiveDepth:(NSInteger *)depth 
               possibleSizes:(NSMutableArray *)possibleSizes
{
  NSParameterAssert(text);
  NSParameterAssert(textInArray);
  
  if (0 == aSize) {
    return 0;
  }
  
  // recursion depth + 1;
  (*depth)++;
  
  // according to page:  The characters in our font are of equal width and height
  NSInteger maxSize = aSize;
  NSInteger maxCharArea = ([text length] - ([textInArray count] - 1)) * aSize;
  //                       -------------   -------------------------    -----
  //                       number of char  number of spaces             current size
  if (maxCharArea <= rectArea) {
    if (maxSize == aSize) {
      
    }
  }else{
    // try size/2
    return [self maxFontSizeFrom:maxSize>>1 
                        withText:text 
                 withTextInArray:textInArray 
                constraintToArea:rectArea 
                  recursiveDepth:depth 
                   possibleSizes:possibleSizes];
  }
  
  return maxSize;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  self.allCases = [NSMutableArray array];
}

- (IBAction)selectFileAction:(id)sender {
  
  NSOpenPanel *fileDialog = [NSOpenPanel openPanel];
  [fileDialog setCanChooseFiles:YES];
  [fileDialog setAllowsMultipleSelection:NO];
  [fileDialog setCanChooseDirectories:NO];
  [fileDialog setResolvesAliases:YES];
  
  [fileDialog 
   beginSheetModalForWindow:self.window
   completionHandler:^(NSInteger result){
     if (result == NSFileHandlingPanelOKButton) {
       // A file selected. Only a valid file path will be returned, even if it is a symblo link.
       NSURL *fileURL = [[fileDialog URLs] objectAtIndex:0];
       if (NO == [fileURL checkResourceIsReachableAndReturnError:nil]) return;
       
       [self readInputFrom:fileURL];
       [self analyzeAllCases:self.allCases];
     }
   }];
  
}
@end
