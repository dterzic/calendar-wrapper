#import <Foundation/Foundation.h>

@class GCWCalendarEvent;

@interface NSArray (GCWEventsSorting)

@property (nonatomic, readonly) NSArray <GCWCalendarEvent *> *eventsFlatMap;

@end
