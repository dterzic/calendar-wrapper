#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWCalendarAuthorization: NSObject

@property (nonatomic, readonly) NSString *userID;
@property (nonatomic, readonly) GTMAppAuthFetcherAuthorization *fetcherAuthorization;

- (instancetype)initWithFetcherAuthorization:(GTMAppAuthFetcherAuthorization *)fetcherAuthorization;

@end
