#import "GCWSyncEventsOperation.h"

@interface GCWSyncEventsOperation ()

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic) NSDate *startDate;
@property (nonatomic) NSDate *endDate;

@end

@implementation GCWSyncEventsOperation

- (instancetype)initWithCalendar:(GCWCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    self = [super init];
    if (self) {
        self.calendar = calendar;
        self.startDate = startDate;
        self.endDate = endDate;
    }
    return self;
}

- (void)main {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.calendar syncEventsFrom:self.startDate to:self.endDate success:^(NSDictionary *syncedEvents, NSArray *removedEvents, NSArray *expiredTokens) {
            self.syncedEvents = syncedEvents;
            self.removedEvents = removedEvents;
            self.expiredTokens = expiredTokens;
            dispatch_group_leave(group);
        } failure:^(NSError *error) {
            self.error = error;
            dispatch_group_leave(group);
        }];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
