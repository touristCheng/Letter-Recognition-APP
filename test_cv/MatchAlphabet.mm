//
//  MatchAlphabet.m
//  test_cv
//
//  Created by chengshuo on 16/5/27.
//  Copyright © 2016年 chengshuo. All rights reserved.
//

#import "MatchAlphabet.h"
#define thresh 80
#define BLACK 0
#define GRAY 1


using namespace std;
using namespace cv;

@interface MatchAlphabet() {
    std::vector<std::vector<cv::KeyPoint>> KP2S;
    std::vector<cv::Mat> DS2S;
    std::vector<cv::Mat> Gray_Template_Mats;
    
    cv::SiftFeatureDetector detector;
    cv::SiftDescriptorExtractor extractor;
    cv::FlannBasedMatcher matcher;
    
    cv::Point2f focusCenter;
}

@end

@implementation MatchAlphabet

@synthesize Mydelegate = _Mydelegate;

bool cmp(const cv::Rect &a, const cv::Rect &b) {
    return a.x<b.x;
}

- (void)InitTrainerWithFlag:(int)flag {
    for (int i=0; i<26; i++) {
        NSString *str = [NSString stringWithFormat:@"f%d.jpg",i];
        cv::Mat dst;
        if (flag == 1) {
            dst = [self cvMatGrayFromUIImage:[UIImage imageNamed:str]];
        }
        else {
            dst = [self cvMatBinaryFromUIImage:[UIImage imageNamed:str]];
        }
        std::vector<cv::KeyPoint> kp2;
        cv::Mat ds2;
        detector.detect(dst, kp2);
        KP2S.push_back(kp2);
        extractor.compute(dst, KP2S[i], ds2);
        DS2S.push_back(ds2);
    }
}

- (void)InitMatchTrainer {
    for (int i=0; i<26; i++) {
        NSString *str = [NSString stringWithFormat:@"m%d.jpg",i];
        cv::Mat train_mat = [self cvMatGrayFromUIImage:[UIImage imageNamed:str]];
        Gray_Template_Mats.push_back(train_mat);
    }
}

- (void) SplitLetters:(cv::Mat &)srcMat InVec:(std::vector<cv::Mat> &)results {
    cv::Mat grayMat;
    if ( srcMat.channels() == 1 ) {
        grayMat = srcMat;
    }
    else {
        grayMat = cv :: Mat( srcMat.rows,srcMat.cols, CV_8UC1 );
        cv::cvtColor( srcMat, grayMat, CV_BGR2GRAY );
    }
    
    cv::Mat bwMat;
    cv::threshold(grayMat, bwMat, thresh, 255, CV_THRESH_BINARY);
    
    //^ with bwMat
    
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
    std::vector<cv::Rect> allrect;
    
    cv::findContours(bwMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
    
    for(int idx=0; idx<contours.size(); idx++ ) {
        cv::Rect rect= cv::boundingRect(cv::Mat(contours[idx]));
        cv::drawContours(srcMat, contours, idx, cv::Scalar::all(-1));
        
        
        
        if ((hierarchy[idx][3]==0||hierarchy[idx][3]==1)&&[self IsValidRect:rect]) {
            cv::rectangle(srcMat, rect, cv::Scalar(0, 255, 0));
            allrect.push_back(rect);
        }
    }
    std::sort(allrect.begin(), allrect.end(), cmp);
    
    for (int i=0; i<allrect.size(); i++) {
        cv::Mat resMat;
        grayMat(allrect[i]).convertTo(resMat, resMat.type());
        results.push_back(resMat);
    }
}

- (cv::Rect) MergeRect:(cv::Rect &)rect1 WithRect:(cv::Rect &)rect2 {
    int left = min(rect1.x, rect2.x);
    int top = min(rect1.y, rect2.y);
    int right = max(rect1.x+rect1.width, rect2.x+rect2.width);
    int bottom = max(rect1.y+rect1.height, rect2.y+rect2.height);
    cv::Rect res(left, top, right-left, bottom-top);
    return res;
}

- (NSString *) HandleImage:(cv::Mat &)TestImageMat {
    
    //TestImageMat = [self cvMatFromUIImage:[UIImage imageNamed:@"test1.jpg"]];
    
    focusCenter.x = TestImageMat.cols/2;
    focusCenter.y = TestImageMat.rows/2;
    
    std::vector<cv::Mat> results;
    [self SplitLetters:TestImageMat InVec:results];
    
    UIImage *testImg = [self UIImageFromCVMat:TestImageMat];
    [self.Mydelegate ShowHandlePic:testImg];
    NSMutableString *MatchString = [[NSMutableString alloc]init];
    
    for (int mat_id=0; mat_id<results.size(); mat_id++) {
        int c = [self MatchAlphabet:results[mat_id]];
        printf("Character: %c\n\n",c+'a');
        [MatchString appendString:[NSString stringWithFormat:@"%c",c+'a']];
    }
    NSLog(@"Match String: %@\n\n\n",MatchString);
    [self.Mydelegate MatchCompletedWithString:MatchString];
    return MatchString;
}

- (bool) IsValidRect:(cv::Rect &)rect {
    int tot = rect.width*rect.height;
    float cenY = (rect.tl().y+rect.br().y)/2;
    
    if ( tot < 80 ) return false;
    if ( abs(cenY - focusCenter.y) > rect.height*0.2 ) return false;
    
    printf("valid_rect## width:%d height:%d tot:%d cenY:%f l:%d r:%d\n",rect.width,rect.height,tot,cenY,rect.tl().x,rect.br().x);
    
   
    return true;
}


- (int) MatchAlphabet:(cv::Mat &)src WithFlag:(int)flag {
    std::vector<cv::KeyPoint> kp1;
    cv::Mat ds1;
    detector.detect(src, kp1);
    extractor.compute(src, kp1, ds1);
    int pos = 'l'-'a';
    float aver = 1000.0;
    for (int i=0; i<26; i++) {
        std::vector<cv::DMatch> matches;
        matcher.match(ds1, DS2S[i], matches);
        cv::Mat showImg, img2;
        img2 = [self cvMatGrayFromUIImage:[UIImage imageNamed:[NSString stringWithFormat:@"f%i.jpg",i]]];
        cv::drawMatches(src, kp1, img2, KP2S[i], matches, showImg);
        if (flag) [_Mydelegate ShowHandlePic:[self UIImageFromCVMat:showImg]];
        if (matches.empty()) continue;
        std::sort(matches.begin(), matches.end());
        printf("\n\n%c\n",i+'a');
        float sum=0, all=0;
        for (int j=0; j<matches.size(); j++) {
            if (matches[j].distance > 2*matches[0].distance) break;
            printf("$dis:%f\n",matches[j].distance);
            sum += matches[j].distance;
            all++;
        }
        sum /= all;
        printf("aver: %lf\n",sum);
        if (sum < aver) {
            aver = sum;
            pos = i;
        }
    }
    printf("%d\n", pos);
    return pos;
}

- (int) MatchAlphabet:(cv::Mat &)src {//use matchTemplate method
    float cnt = -1;
    int pos = 0;
    for (int i=0; i<26; i++) {
        cv::Mat match_result;
        cv::Mat query_mat = cv::Mat::zeros(Gray_Template_Mats[i].rows, Gray_Template_Mats[i].cols, Gray_Template_Mats[i].type());
        cv::resize(src, query_mat, query_mat.size());
        matchTemplate(query_mat, Gray_Template_Mats[i], match_result, cv::TM_CCOEFF_NORMED);
        printf("%c %f\n",i+'a',match_result.at<float>(0, 0));
        if (match_result.at<float>(0,0) > cnt) {
            cnt = match_result.at<float>(0,0);
            pos = i;
        }
    }
    return pos;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image {
    cv::Mat tempMat = [self cvMatFromUIImage:image];
    cv::Mat grayMat;
    if ( tempMat.channels() == 1 ) {
        grayMat = tempMat;
    }
    else {
        grayMat = cv :: Mat( tempMat.rows,tempMat.cols, CV_8UC1 );
        cv::cvtColor( tempMat, grayMat, CV_BGR2GRAY );
    }
    return grayMat;
}

- (UIImage *)UIImageFromCVMat:(cv::Mat &)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImage *imageRef = CGImageCreate(cvMat.cols, cvMat.rows, 8, 8 * cvMat.elemSize(), cvMat.step, colorSpace,  kCGImageAlphaNoneSkipLast|kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

- (cv::Mat)cvMatBinaryFromUIImage:(UIImage *)image {
    cv::Mat temp = [self cvMatGrayFromUIImage:image];
    cv::Mat BinaryMat;
    cv::threshold(temp, BinaryMat, thresh, 255, CV_THRESH_BINARY);
    return BinaryMat;
}

@end
