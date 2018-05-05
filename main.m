//
//  main.m
//  unfairplay
//
//  Created by ipad_kid on 5/4/18.
//  Copyright © 2018 BlackJacket. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "SharedStrings.h"

@interface LSBundleProxy
@property (nonatomic, readonly) NSURL *dataContainerURL;
@end

@interface LSApplicationProxy : LSBundleProxy
+ (instancetype)applicationProxyForIdentifier:(NSString *)bundleID;
@end

@interface LSApplicationWorkspace : NSObject
+ (LSApplicationWorkspace *)defaultWorkspace;
- (BOOL)applicationIsInstalled:(NSString *)appIdentifier;
- (BOOL)openApplicationWithBundleID:(NSString *)identifier;
@end


int main(int argc, char *argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *bundleID = [NSString stringWithUTF8String:argv[i]];
            NSURL *container = [[LSApplicationProxy applicationProxyForIdentifier:bundleID] dataContainerURL];
            NSString *readPath = [container.path stringByAppendingPathComponent:@"com.ipadkid.unfairplay"];
            NSDictionary *writeDict = @{ bundleID : readPath };
            [writeDict writeToFile:@kDictPath atomically:YES];
            NSString *mvDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Decrypted"];
            
            NSFileManager *fileManager = NSFileManager.defaultManager ;
            [fileManager createDirectoryAtPath:mvDir withIntermediateDirectories:YES attributes:NULL error:NULL];
            
            LSApplicationWorkspace *workspace = LSApplicationWorkspace.defaultWorkspace;
            const char *bundleChar = bundleID.UTF8String;
            if ([workspace applicationIsInstalled:bundleID]) {
                printf("%s will be launched for decryption\n", bundleChar);
                [workspace openApplicationWithBundleID:bundleID];
                
                CFRunLoopRef runLoop = CFRunLoopGetCurrent();
                
                int doneToken = 0;
                notify_register_dispatch(kPostDoneKey, &doneToken, dispatch_get_main_queue(), ^(int token) {
                    unlink(kDictPath);
                    NSDictionary *readDict = [NSDictionary dictionaryWithContentsOfFile:[readPath stringByAppendingPathComponent:@"Info.plist"]];
                    NSString *retPath = readDict[bundleID];
                    NSString *dirName = [mvDir stringByAppendingPathComponent:retPath.lastPathComponent];
                    [fileManager moveItemAtPath:retPath toPath:dirName error:NULL];
                    [fileManager removeItemAtPath:readPath error:NULL];
                    printf("%s finished: Please check %s\n", bundleChar, dirName.UTF8String);
                    CFRunLoopStop(runLoop);
                });
                
                int failToken = 0;
                notify_register_dispatch(kPostFailKey, &failToken, dispatch_get_main_queue(), ^(int token) {
                    printf("%s failed\n", bundleChar);
                    CFRunLoopStop(runLoop);
                });
                
                CFRunLoopRun();
            } else {
                printf("Could not find %s\n", bundleChar);
            }
        }
    }
    
    return 0;
}
