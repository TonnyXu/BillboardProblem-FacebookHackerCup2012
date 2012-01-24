//
//  TXAppDelegate.m
//  billboard
//
//  Created by Tonny Xu on 12/01/23.
//  Copyright (c) 2012年 totodotnet.net. All rights reserved.
//

#import "TXAppDelegate.h"
#import "FileReader.h"

#define LOWER_BOUND_KEY @"lowerBound"
#define UPPER_BOUND_KEY @"upperBound"


@interface TXAppDelegate()

@property (assign) NSInteger numberOfCases;
@property (strong) NSMutableArray *allCases;

- (void)readInputFrom:(NSURL *)fileURL;
- (void)analyzeAllCases:(NSArray *)cases;

- (NSInteger)maxFontSizeForText:(NSString *)text 
                withTextInArray:(NSArray *)textInArray 
               constraintToArea:(NSInteger)rectArea 
                     withBounds:(NSDictionary *)bounds;
- (NSInteger)correctMaxFontSizeForNoHyphenationFor:(NSArray *)textInArray 
                                      constraintTo:(NSInteger)possibleMaxFontSize 
                                        boardWidth:(NSInteger)width 
                                       boardHeight:(NSInteger)height;
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
  FileReader *reader = [[FileReader alloc] initWithFilePath:filePath];
  
  NSInteger lineDelimiterLength = 1;//[[reader lineDelimiter] length];
  
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
  
  NSString *outputPath = [@"~/billboard.output.txt" stringByExpandingTildeInPath];
  NSMutableString *outputData = [NSMutableString string];

  [cases enumerateObjectsUsingBlock:^(NSDictionary *aCase, NSUInteger idx, BOOL *stop) {
    NSInteger width = [[aCase objectForKey:@"width"] integerValue];
    NSInteger height = [[aCase objectForKey:@"height"] integerValue];
    NSString *text = [aCase objectForKey:@"text"];
    
    NSArray *textArray = [text componentsSeparatedByString:@" "];
    
    // assume we only need to show one character in one line or one column, that's the max font size.
    NSInteger maxFontSize = MIN(width,height);

    NSInteger maxArea = maxFontSize * maxFontSize * ([text length] - ([textArray count] - 1));
    if (maxArea > width*height && maxFontSize > 1) {
      // find the max font size for all the character, not counting words and space.
      NSDictionary *boundsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInteger:1], LOWER_BOUND_KEY,
                                  [NSNumber numberWithInteger:maxFontSize], UPPER_BOUND_KEY,
                                  nil];
      maxFontSize = [self maxFontSizeForText:text 
                             withTextInArray:textArray 
                            constraintToArea:width*height 
                                  withBounds:boundsDict];
    }else if (maxArea > width*height) {
      maxFontSize--;
    }
    NSLog(@"*** Possible size: %ld", maxFontSize);
    
    // after find the max possible font size, we need to verify and adjust the font to suit for billboard.
    /*
     We want you to tell us how large we can print the text, such that it fits on the billboard without splitting any words across lines
     */
    NSInteger realFontSize = [self correctMaxFontSizeForNoHyphenationFor:textArray 
                                                            constraintTo:maxFontSize 
                                                              boardWidth:width 
                                                             boardHeight:height];
    [self.outputLabel setTitleWithMnemonic:[NSString stringWithFormat:@"%@\nCase #%ld: %ld", [self.outputLabel stringValue], (idx + 1), realFontSize]];
    NSString *outputStr = [NSString stringWithFormat:@"Case #%ld: %ld\n", (idx + 1), realFontSize];
    NSLog(@"%@",outputStr);
    [outputData appendString:outputStr];
    
  }];

  [outputData writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// Main algorithm! Using recurrsive algorithm to make a good guess.
- (NSInteger)maxFontSizeForText:(NSString *)text 
                withTextInArray:(NSArray *)textInArray 
               constraintToArea:(NSInteger)rectArea 
                     withBounds:(NSDictionary *)bounds
{
  NSParameterAssert(text);
  NSParameterAssert(textInArray);
  NSParameterAssert(bounds);
  
  NSInteger upperSize = [[bounds objectForKey:UPPER_BOUND_KEY] integerValue];
  NSInteger lowerSize = [[bounds objectForKey:LOWER_BOUND_KEY] integerValue];
  NSLog(@"*** finding max size between %4ld...%ld", lowerSize, upperSize);

  NSInteger upperArea = upperSize * upperSize * ([text length] - ([textInArray count] - 1));
  NSInteger lowerArea = lowerSize * ([text length] - ([textInArray count] - 1));

  // No need to go further, there will be one size suitable for rectArea
  if (1 >= (upperSize - lowerSize)) { // there could be a case of 0
    if (upperArea <= rectArea) {
      return upperSize;
    }else if (lowerArea <= rectArea){
      return lowerSize;
    }else {
      return 0;
    }
  }
  
  // Otherwise, we need to go recursive routine to find the max size in lower...upper
  NSInteger middleSize = lowerSize + ((upperSize - lowerSize) >> 1);
  NSInteger middleArea = middleSize * middleSize * ([text length] - ([textInArray count] - 1));
  if (middleArea > rectArea) {
    NSDictionary *boundsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                [bounds objectForKey:LOWER_BOUND_KEY], LOWER_BOUND_KEY,
                                [NSNumber numberWithInteger:middleSize], UPPER_BOUND_KEY,
                                nil];
    return [self maxFontSizeForText:text withTextInArray:textInArray constraintToArea:rectArea withBounds:boundsDict];
  }else {
    NSDictionary *boundsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInteger:middleSize], LOWER_BOUND_KEY,
                                [bounds objectForKey:UPPER_BOUND_KEY], UPPER_BOUND_KEY,
                                nil];
    return [self maxFontSizeForText:text withTextInArray:textInArray constraintToArea:rectArea withBounds:boundsDict];
  }
}

// Another core algorithm that will try and shrink the font size to fit the billboard
- (NSInteger)correctMaxFontSizeForNoHyphenationFor:(NSArray *)textInArray 
                                      constraintTo:(NSInteger)possibleMaxFontSize 
                                        boardWidth:(NSInteger)width 
                                       boardHeight:(NSInteger)height
{
  NSParameterAssert(textInArray);
  
  if (possibleMaxFontSize == 0) {
    return 0;
  }

  NSInteger realFontSize = possibleMaxFontSize;
  BOOL finished = NO;
  do {
    NSInteger currentLineWidth = 0;
    NSInteger currentLineIndex = 0;
    
    for (int idx= 0; idx < [textInArray count]; idx++) {
      NSString *aWord = [textInArray objectAtIndex:idx];
      NSInteger wordLengthAppliedFontSize = [aWord length]*realFontSize;
      // width is not enough for a single word
      if (wordLengthAppliedFontSize > width) {
        realFontSize = width/[aWord length];
        currentLineIndex = 0;
        currentLineWidth = 0;
        break;
      }
      
      // current word is safe for at least one line, see if it is safe to add to current line.
      if (currentLineWidth + wordLengthAppliedFontSize > width) {
        // need a new line
        currentLineIndex++;
        currentLineWidth = wordLengthAppliedFontSize;

      }else{
        currentLineWidth += wordLengthAppliedFontSize;
      }
      
      if (currentLineWidth + realFontSize < width) {
        // current line is safe for one more space.
        currentLineWidth += realFontSize;
      }else if (idx != ([textInArray count] -1)){
        // still have some word, need a new line
        currentLineIndex++;
        currentLineWidth = 0;
      }
      
      // height is not enough for the whole text
      if ((currentLineIndex + 1) * realFontSize > height){
        realFontSize = height/(currentLineIndex + 1);
        currentLineIndex = 0;
        currentLineWidth = 0;
        break;
      }
      // done.
      if (idx == [textInArray count] -1) {
        // last line
        finished = YES;
      }

    }
    
  } while (realFontSize > 0 && !finished);
  
  return realFontSize;
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
