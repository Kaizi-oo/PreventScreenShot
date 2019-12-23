//
//  PreventScreentShotService.m
//  PreventScreenShot
//
//  Created by Kyang on 2019/12/23.
//  Copyright © 2019 OLC3. All rights reserved.
//

#import "PreventScreentShotService.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface PreventScreentShotService ()

@property(nonatomic, strong)NSOperationQueue * snapshotQueue;
@property(nonatomic, assign)NSInteger snapshotCount;
@property(nonatomic, retain)dispatch_semaphore_t semaphore;

@end

@implementation PreventScreentShotService


+ (instancetype)shareService {
    
    static PreventScreentShotService * service;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[PreventScreentShotService alloc] init];
    });
    return service;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.snapshotCount = 0;
        self.snapshotQueue = [[NSOperationQueue alloc]init];
        self.snapshotQueue.maxConcurrentOperationCount = 1;
        self.semaphore = dispatch_semaphore_create(0);
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(receiveScreenShotNotification:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];

    }
    return self;
}

- (void)setSnapshotCount:(NSInteger)snapshotCount {
    BOOL needDelete = _snapshotCount < snapshotCount;
    _snapshotCount = snapshotCount;
    
    NSLog(@"setSnapshotCount changed: %ld",(long)needDelete);
    if (needDelete) {
        [self deleteCounted];
    }
}

- (void)checkAuthorization {
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        switch (status) {
            case PHAuthorizationStatusNotDetermined:
                // User has not yet made a choice with regards to this application
                break;
            case PHAuthorizationStatusRestricted:// This application is not authorized to access photo data.
                // The user cannot change this application’s status, possibly due to active restrictions
                //   such as parental controls being in place.
            case PHAuthorizationStatusDenied:           // User has explicitly denied this application access to photos data.
            {
                UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"权限异常" message:@"使用此APP需要相册使用权限,请前往设置-PreventScreenShot开启权限" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
                    abort();
                }]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alert animated:true completion:nil];
                });
                
            }
                break;
            case PHAuthorizationStatusAuthorized:
                break;
            default:
                break;
        }
    }];
}
-(void)deleteCounted {
    
    [self.snapshotQueue cancelAllOperations];
    
    [self.snapshotQueue addOperationWithBlock:^{
        if (self.snapshotCount == 0) { //如果count==0,那么不用再删除了
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"警告" message:@"APP禁止截屏,请自觉删除!" preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self deleteAssets];
            }]];
            [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alert animated:true completion:^{
                
            }];
        });
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    }];
    
}

-(void)deleteAssets {
    
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    PHFetchResult *assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
    
    NSMutableArray <PHAsset *>* assets = [NSMutableArray arrayWithCapacity:self.snapshotCount];
    if (self.snapshotCount >= 0) {
        for (int i = 0; i < self.snapshotCount; i ++) {
            PHAsset *asset = [assetsFetchResults objectAtIndex:i];
            [assets addObject:asset];
        }
    }
    
    __weak typeof(self) weakSelf = self;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        [PHAssetChangeRequest deleteAssets:assets];
        
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            
            [weakSelf deleteNewAssets:assets];
        } else {
            self.snapshotCount -= assets.count;
            dispatch_semaphore_signal(self.semaphore);
        }
    }];
}

- (void)deleteNewAssets:(NSArray<PHAsset *> *)assets {
    
    if (assets) {
        //        dispatch_async(dispatch_get_main_queue(), ^{
        __weak typeof(self) weakSelf = self;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            
            [PHAssetChangeRequest deleteAssets:assets];
            
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                [weakSelf deleteNewAssets:assets];
            } else {
                self.snapshotCount -= assets.count;
                dispatch_semaphore_signal(self.semaphore);
            }
        }];
    }
}

- (void)receiveScreenShotNotification:(NSNotification *)notify {
    NSLog(@"%@", notify.name);
    
    self.snapshotCount++;
}

@end
