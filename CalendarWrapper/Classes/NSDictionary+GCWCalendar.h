#import <Foundation/Foundation.h>

@class GCWCalendarEntry;

@interface NSDictionary (GCWCalendarEntry)

@property (nonatomic, readonly) NSDictionary <NSString*, GCWCalendarEntry *> *calendars;

+ (NSDictionary *)unarchiveCalendarEntriesFrom:(NSDictionary *)archive;
- (NSDictionary *)archiveCalendarEntries;

@end
