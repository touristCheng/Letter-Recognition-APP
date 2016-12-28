//
//  MatchAlphabet.h
//  test_cv
//
//  Created by chengshuo on 16/5/27.
//  Copyright © 2016年 chengshuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "opencv2/opencv.hpp"
#import "opencv2/nonfree/features2d.hpp"
#import <algorithm>
#import <UIKit/UIKit.h>

@protocol MyMatchMachineProtocol <NSObject>

@required
- (void) InitTrainer;
//SIFT: InitTrainerWithFlag match+flag
//match: InitMatchTrainer  match

- (void) MatchCompletedWithString:(NSString *)Result;

- (void) ShowHandlePic:(UIImage *)image;

@end

@interface MatchAlphabet : NSObject

@property (nonatomic, assign) int cnt;

@property(nonatomic) id<MyMatchMachineProtocol> Mydelegate;

- (void) InitMatchTrainer;

- (void) InitTrainerWithFlag:(int)flag;

- (NSString *) HandleImage:(cv::Mat &)TestImageMat;

@end
