#import "NSString+GCWSmartIcon.h"

@implementation NSString (GCWSmartIcon)

- (NSDictionary *)imageVocabularyDictionary {
    return @{@"Dinning" : @[@"dinner", @"dinning", @"lunch"],
             @"Cart" : @[@"shopping", @"store"],
             @"Drink" : @[@"happy hour", @"drink", @"wine"],
             @"Moive" : @[@"movie", @"theater"],
             @"Cake" : @[@"cake", @"birthday"],
             @"Coffee" : @[@"coffee", @"cafe", @"tea"],
             @"Fitness" : @[@"fitness", @"workout", @"gym"],
             @"Planning" : @[@"planning", @"plan", @"calendar"],
             @"Home" : @[@"home", @"house", @"family"],
             @"Pen" : @[@"write", @"writing", @"learn", @"learning"],
             @"Call" : @[@"call", @"phone", @"cell"],
             @"Moon" : @[@"moon", @"night", @"evening"],
             @"Keyboard" : @[@"coding", @"code", @"programming"],
             @"Meeting" : @[@"meeting", @"mtg", @"standup"],
             @"Sleep" : @[@"sleep", @"rest"]};
}

- (NSString *)matchIconName {
    NSString *iconName;
    for (NSString *key in [self imageVocabularyDictionary].allKeys) {
        for (NSString *vocabulary in [self imageVocabularyDictionary][key]) {
            if ([self.lowercaseString containsString:vocabulary]) {
                iconName = key;
            }
        }
    }

    return iconName;
}

@end
