#import "GCWTaskList.h"

@implementation GCWTaskList

- (instancetype)initWithTaskList:(GTLRTasks_TaskList *)taskList calendar:(NSString *)calendarId {
    self = [super init];
    if (self) {
        _identifier = [taskList.identifier copy];
        _calendarId = [calendarId copy];
        _title = [taskList.title copy];
    }
    return self;
}

@end
