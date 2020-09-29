#import <Foundation/Foundation.h>

@class GCWCalendarEntry;

@interface NSArray (GCWCalendarEntry)

@property (nonatomic, readonly) NSArray <GCWCalendarEntry *> *calendars;

- (GCWCalendarEntry *)calendarWithId:(NSString *)calendarId;
- (GCWCalendarEntry *)calendarWithTitle:(NSString *)title;

@end
