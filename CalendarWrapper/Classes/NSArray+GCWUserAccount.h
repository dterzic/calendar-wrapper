#import <Foundation/Foundation.h>

@class GCWUserAccount;

@interface NSArray (GCWUserAccount)

@property (nonatomic, readonly) NSArray <GCWUserAccount *> *userAccounts;

+ (NSArray *)unarchiveUserAccountsFrom:(NSArray *)archive;
- (NSArray *)archiveUserAccounts;

@end
