#import "GCWRefreshTokenOperation.h"

@interface GCWRefreshTokenOperation ()

@property (nonatomic) GCWCalendar *calendar;

@end

@implementation GCWRefreshTokenOperation

- (instancetype)initWithCalendar:(GCWCalendar *)calendar {
    self = [super init];
    if (self) {
        self.calendar = calendar;
    }
    return self;
}

- (void)main {
    __block dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.calendar refreshAllTokensOnSuccess:^{
            dispatch_group_leave(group);
        } failure:^(NSError *error) {
            self.error = error;
            dispatch_group_leave(group);
        }];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
