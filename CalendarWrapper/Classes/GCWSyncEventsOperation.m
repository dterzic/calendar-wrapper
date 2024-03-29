#import "GCWSyncEventsOperation.h"

@interface GCWSyncEventsOperation ()

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic) NSDate *startDate;
@property (nonatomic) NSDate *endDate;
@property (nonatomic, copy) void (^onProgress)(CGFloat);

@end

@implementation GCWSyncEventsOperation

- (instancetype)initWithCalendar:(GCWCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate progress:(void (^)(CGFloat))progress {
    self = [super init];
    if (self) {
        self.calendar = calendar;
        self.startDate = startDate;
        self.endDate = endDate;
        self.onProgress = progress;
    }
    return self;
}

- (void)main {
    __block dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.calendar syncEventsFrom:self.startDate to:self.endDate success:^(NSDictionary *syncedEvents, NSArray *removedEvents, NSArray *expiredTokens, NSArray *errors) {

            [self.calendar syncTasksOnSuccess:^{
                self.syncedEvents = syncedEvents;
                self.removedEvents = removedEvents;
                self.expiredTokens = expiredTokens;
                if (errors.count > 0) {
                    NSError *firstError = (NSError *)errors.firstObject;
                    self.error = [firstError copy];
                }
                dispatch_group_leave(group);
            } failure:^(NSError *error) {
                self.error = error;
                dispatch_group_leave(group);
            }];
        } failure:^(NSError *error) {
            self.error = error;
            dispatch_group_leave(group);
        } progress:^(CGFloat percent) {
            self.onProgress(percent);
        }];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
