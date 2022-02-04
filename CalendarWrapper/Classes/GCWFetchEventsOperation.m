#import "GCWFetchEventsOperation.h"

@interface GCWFetchEventsOperation ()

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic) NSDate *startDate;
@property (nonatomic) BOOL ascending;
@property (nonatomic) NSString *filter;

@end

@implementation GCWFetchEventsOperation

- (instancetype)initWithCalendar:(GCWCalendar *)calendar startDate:(NSDate *)startDate ascending:(BOOL)ascending filter:(NSString *)filter {
    self = [super init];
    if (self) {
        self.calendar = calendar;
        self.startDate = startDate;
        self.ascending = ascending;
        self.filter = filter;
    }
    return self;
}

- (void)main {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.calendar fetchFrom:self.startDate
                         ascending:self.ascending
                            filter:self.filter
                           success:^(NSArray *errors, NSDictionary *fetchPageTokens) {
            self.fetchPageTokens = fetchPageTokens;
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
