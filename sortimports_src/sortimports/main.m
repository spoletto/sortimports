//
//  main.m
//  sortimports
//
//  Created by Stephen Poletto on 2/7/13.
//  Copyright (c) 2013 Stephen Poletto. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NEWLINE_MARKER @"???"

/*
 * Given an input directory, returns a list of all .h and .m files inside the directory.
 */
NSArray *fileURLsInDirectory(NSURL *directoryToScan) {
    NSFileManager *localFileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *dirEnumerator = [localFileManager enumeratorAtURL:directoryToScan includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSMutableArray *fileURLs = [NSMutableArray array];
    for (NSURL *theURL in dirEnumerator) {
        NSError *error = nil;
        NSString *fileName = nil;
        [theURL getResourceValue:&fileName forKey:NSURLNameKey error:&error];
        if (error) {
            NSLog(@"Error getting filename at %@\n%@", theURL, [error localizedFailureReason]);
            continue;
        }
        
        NSNumber *isDirectory = nil;
        [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        if (error) {
            NSLog(@"Error determining if the file is a directory at %@\n%@", theURL, [error localizedFailureReason]);
            continue;
        }
        
        // Get the extension string: .m, .xcodeproj, etc.
        NSString *extension = [theURL pathExtension];
        if ([isDirectory boolValue]) {
            // Ignore files under the .xcodeproj directory
            if (([extension caseInsensitiveCompare:@"xcodeproj"] == NSOrderedSame)) {
                [dirEnumerator skipDescendants];
            }
        } else {
            // We only care about .h and .m files
            if (([extension caseInsensitiveCompare:@"m"] == NSOrderedSame) ||
                ([extension caseInsensitiveCompare:@"h"] == NSOrderedSame)) {
                [fileURLs addObject:theURL];
            }
        }
    }
    return fileURLs;
}

/*
 * Sorts #import directives alphabetically, with framework imports <> last.
 */
void sortImportDirectives(NSMutableArray *lines) {
    NSMutableArray *importDirectives = [NSMutableArray arrayWithCapacity:50];
    NSInteger firstImportOccurance = 0;
    BOOL isFirstOccurance = YES;
    BOOL isInComment = NO;
    
    for (NSInteger i = 0; i < lines.count; i++) {
        NSString *line = [lines objectAtIndex:i];
        if (isInComment) {
            if ([line rangeOfString:@"*/"].location != NSNotFound) {
                // Leave comment
                isInComment = NO;
            }
        } else {
            if ([line rangeOfString:@"/*"].location != NSNotFound) {
                isInComment = YES;
            } else {
                // Searching non commented text
                if ([line rangeOfString:@"#import"].location != NSNotFound) {
                    [importDirectives addObject:line];
                    if (isFirstOccurance) {
                        firstImportOccurance = i;
                        isFirstOccurance = NO;
                    }
                }
                
                if (([line rangeOfString:@"@interface"].location != NSNotFound) || ([line rangeOfString:@"@implementation"].location != NSNotFound)) {
                    // Stop search. We've reached @interfance or @implementation where there shouldn't be any more #imports
                    break;
                }
            }
        }
    }
    
    NSArray *sortedDirectives = [importDirectives sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger importCount = importDirectives.count;
    for (int i = 0; i < importCount; i++) {
        NSString *importString = [sortedDirectives objectAtIndex:importCount-i-1];
        [lines removeObject:importString];
        [lines insertObject:importString atIndex:firstImportOccurance];
    }
}

/*
 * Writes the provided string to the output path.
 */
void writeFileContentsToPath(NSString *fileString, NSURL *path) {
    NSError *error = nil;
    BOOL success = [fileString writeToURL:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!success) {
        NSLog(@"Error writing file to path at %@\n%@", path, [error localizedFailureReason]);
    }
}

/*
 * Reads in the file contents at the provided path and performs code beautification as needed
 * (right now it just sorts #import directives alphabetically).
 */
void processFile(NSURL *path) {
    NSError *error = nil;
    NSMutableString *fileContents = [[NSMutableString alloc] initWithContentsOfURL:path encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"Error reading file at %@\n%@", path, [error localizedFailureReason]);
        return;
    }
    
    NSRange fullRange = NSMakeRange(0, fileContents.length);
    NSString *newlineMarker = [NSString stringWithFormat:@"\n%@", NEWLINE_MARKER];
    [fileContents replaceOccurrencesOfString:@"\n" withString:newlineMarker options:0 range:fullRange];
    
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]]];
    sortImportDirectives(lines);
    
    // We could do additional code cleanups here...
    
    NSString *finalStr = [lines componentsJoinedByString:@"\n"];
    finalStr = [finalStr stringByReplacingOccurrencesOfString:newlineMarker withString:@"\n"];
    
    writeFileContentsToPath(finalStr, path);
}

/*
 * Finds all .h and .m files within a given directory and processes each one in turn.
 */
void processFilesInDirectory(NSURL *directoryToScan) {
    NSArray *fileURLs = fileURLsInDirectory(directoryToScan);
    
    if (fileURLs.count == 0) {
        NSLog(@"No Files To Process!");
    }
    
    for (NSURL *fileURL in fileURLs) {
        processFile(fileURL);
    }
}

/*
 * Command line entry point.
 */
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            NSLog(@"Usage: sortimports </path/to/directory>");
            return -1;
        }
        NSString *directoryName = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        processFilesInDirectory([NSURL URLWithString:directoryName]);
        NSLog(@"FINISHED!");
    }
    return 0;
}

