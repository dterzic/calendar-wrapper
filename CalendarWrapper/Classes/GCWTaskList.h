#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@class GTLRTasks_TaskList;

@interface GCWTaskList : NSObject

@property (nonatomic) NSString *identifier;
@property (nonatomic) NSString *calendarId;
@property (nonatomic) NSString *title;

- (instancetype)initWithTaskList:(GTLRTasks_TaskList *)taskList calendar:(NSString *)calendarId;

@end
