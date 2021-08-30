#import "GCWLoadEventsOperation.h"

@interface GCWLoadEventsOperation ()

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic) NSDate *startDate;
@property (nonatomic) NSDate *endDate;
@property (nonatomic) NSString *filter;

@end

@implementation GCWLoadEventsOperation

- (instancetype)initWithCalendar:(GCWCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate filter:(NSString *)filter {
    self = [super init];
    if (self) {
        self.calendar = calendar;
        self.startDate = startDate;
        self.endDate = endDate;
        self.filter = filter;
    }
    return self;
}

- (void)main {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.calendar loadEventsListFrom:self.startDate
                                       to:self.endDate
                                   filter:self.filter
                                  success:^(NSDictionary *loadedEvents, NSArray *removedEvents, NSUInteger filteredEventsCount, NSArray *errors) {
            self.loadedEvents = loadedEvents;
            self.removedEvents = removedEvents;
            self.filteredEventsCount = filteredEventsCount;
            if (errors.count > 0) {
                NSError *firstError = (NSError *)errors.firstObject;
                self.error = [firstError copy];
            }
            dispatch_group_leave(group);
        } failure:^(NSError *error) {
            self.error = error;
            dispatch_group_leave(group);
        }];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
