//
//  PreventScreentShotService.h
//  PreventScreenShot
//
//  Created by Kyang on 2019/12/23.
//  Copyright © 2019 OLC3. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreventScreentShotService : NSObject

/**
 需要控制成一个单利
 */
+ (instancetype)shareService;
/**
 检查权限
 */
- (void)checkAuthorization;

@end

NS_ASSUME_NONNULL_END
