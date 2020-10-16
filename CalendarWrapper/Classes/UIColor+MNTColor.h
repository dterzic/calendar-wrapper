//
//  UIColor+MNTColor.h
//  Moment
//
//  Created by Jiashu Wang on 7/9/16.
//  Copyright © 2016 Reverse. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (MNTColor)

+ (UIColor *)colorWithR:(CGFloat)red G:(CGFloat)green B:(CGFloat)blue A:(CGFloat)alpha;
+ (UIColor *)colorWithR:(CGFloat)red G:(CGFloat)green B:(CGFloat)blue;
+ (UIColor *)colorWithHex:(NSString *)hex;

+ (UIColor *)orange;

-(UIColor*) inverseColor;

@end
