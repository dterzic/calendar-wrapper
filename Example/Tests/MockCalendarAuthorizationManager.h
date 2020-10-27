#import <UIKit/UIKit.h>
#import "GCWCalendarAuthorizationManager.h"

@interface MockCalendarAuthorizationManager: NSObject <CalendarAuthorizationProtocol>

@property (nonatomic) NSMutableArray *authorizations;
@property (nonatomic) BOOL canAuthorize;

@end
