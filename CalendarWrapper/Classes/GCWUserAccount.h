#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWUserAccount : NSObject

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *email;

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo;

@end
