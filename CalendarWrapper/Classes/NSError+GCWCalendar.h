#import <Foundation/Foundation.h>

@interface NSError (GCWCalendar)

+ (NSError *)createErrorWithCode:(NSInteger)code description:(NSString *)description;

@end
