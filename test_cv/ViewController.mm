//
//  ViewController.m
//  test_cv
//
//  Created by chengshuo on 16/5/26.
//  Copyright © 2016年 chengshuo. All rights reserved.
//

#import "ViewController.h"
#import "opencv2/opencv.hpp"
#import "MatchAlphabet.h"
#import "opencv2/highgui/cap_ios.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

#define FrameRate 10
#define RatioX self.CameraImgWidth/self.CameraView.frame.size.width
#define RatioY self.CameraImgHeight/self.CameraView.frame.size.height
#define BLACK 0
#define GRAY 1

using namespace std;
using namespace cv;

@interface ViewController () <MyMatchMachineProtocol,AVCaptureVideoDataOutputSampleBufferDelegate> {
    int cnt, cntFrame;
    dispatch_queue_t videoDataOutputQueue;
}

@property (weak, nonatomic) IBOutlet UIView *BottomView;
@property (weak, nonatomic) IBOutlet UILabel *Select;


@property (weak, nonatomic) IBOutlet UIButton *Match;
@property (weak, nonatomic) IBOutlet UIImageView *CameraView;
@property (weak, nonatomic) IBOutlet UILabel *MatchResult;
@property (weak, nonatomic) IBOutlet UISlider *ScaleChange;
@property (weak, nonatomic) IBOutlet UIImageView *testResult;


@property (assign, nonatomic) int CameraImgWidth;
@property (assign, nonatomic) int CameraImgHeight;
@property (assign, nonatomic) bool grayscaleMode;

@property (nonatomic, retain) MatchAlphabet *MyMatch;
@property (nonatomic, retain) AVCaptureSession *CaptureSession;
@property (nonatomic, retain) AVCaptureDeviceInput *InputDevice;
@property (nonatomic, retain) AVCaptureVideoDataOutput *CaptureOutput;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer* PreviewLayer;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    cnt = 0;
    cntFrame = 0;
    [self InitTrainer];
    [self Start];
    [self InitROIArea];
}

- (void) InitTrainer {
    self.MyMatch = [[MatchAlphabet alloc]init];
    [self.MyMatch InitMatchTrainer];
    self.MyMatch.Mydelegate = self;
}

- (void) InitROIArea {
    self.Select.layer.borderColor = [UIColor colorWithRed:0.0 green:255.0 blue:0.0 alpha:1.0].CGColor;
    self.Select.layer.borderWidth = 2;
    self.Match.layer.cornerRadius = self.Match.frame.size.width/2;
    
    [self.BottomView bringSubviewToFront:self.Select];
    self.ScaleChange.minimumValue = 1.0;
    self.ScaleChange.maximumValue = 5.0;
}

- (void) Start {
    if (![NSThread isMainThread]) {
        NSLog(@"[Camera] Warning: Call start only from main thread");
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    [self InitCamera];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            return device;
        }
    }
    
    return nil;
}

- (void) CreateCaptureSession {
    self.CaptureSession = [[AVCaptureSession alloc]init];
    self.CaptureSession.sessionPreset = AVCaptureSessionPreset640x480;
    self.CameraImgWidth = 480;
    self.CameraImgHeight = 640;
}

- (void) CreateInputDevice {
    NSError *error;
    AVCaptureDevice *device = [self cameraWithPosition: AVCaptureDevicePositionBack];
    self.InputDevice = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    else {
        if ([self.CaptureSession canAddInput:self.InputDevice]) {
            [self.CaptureSession addInput:self.InputDevice];
        }
    }
}

- (void) CreateCaptureOutput {
    self.CaptureOutput = [AVCaptureVideoDataOutput new];
    [self.CaptureOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    self.grayscaleMode = false;
    OSType format = self.grayscaleMode ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_32BGRA;
    
    self.CaptureOutput.videoSettings  = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:format]forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    if ( [self.CaptureSession canAddOutput:self.CaptureOutput] ) {
        [self.CaptureSession addOutput:self.CaptureOutput];
    }
    [[self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    
    // set default FPS
    if ([self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].supportsVideoMinFrameDuration) {
        [self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].videoMinFrameDuration = CMTimeMake(1, FrameRate);
    }
    if ([self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].supportsVideoMaxFrameDuration) {
        [self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].videoMaxFrameDuration = CMTimeMake(1, FrameRate);
    }
    
    if ([self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].supportsVideoOrientation) {
        [self.CaptureOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.CaptureOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    if ([self.CaptureSession canAddOutput:self.CaptureOutput] ) {
        [self.CaptureSession addOutput:self.CaptureOutput];
    }
}

- (void) CreatePreviewLayer {
    self.PreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.CaptureSession];
    
    self.PreviewLayer.frame = self.CameraView.bounds;
    
    self.PreviewLayer.videoGravity = AVLayerVideoGravityResize;
    
    [self.CameraView.layer addSublayer:self.PreviewLayer];
}

- (void) SetFocusPoint {
    CGPoint focusPoint = CGPointMake(0.5, self.Select.center.y/self.CameraView.frame.size.height);
    NSError *err;
    [self.InputDevice.device lockForConfiguration:&err];
    if (err) {
        NSLog(@"%@\n",err);
    }
    else {
        if ([self.InputDevice.device isFocusModeSupported:AVCaptureFocusModeLocked]) {
            [self.InputDevice.device setFocusPointOfInterest:focusPoint];
            [self.InputDevice.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
    }
    [self.InputDevice.device unlockForConfiguration];
}

- (void) SetVideoScale {
    
}

- (void) InitCamera {
    [self CreateCaptureSession];
    [self CreateInputDevice];
    [self CreateCaptureOutput];
    [self CreatePreviewLayer];
    [self SetFocusPoint];
    [self SetVideoScale];
    [self.CaptureSession startRunning];
}

- (void) Stop {
    [self.CaptureSession stopRunning];
    self.CaptureOutput = nil;
    videoDataOutputQueue = nil;
}

#pragma mark UI

- (IBAction)ChangeAcc:(id)sender {
    UISlider *temp = sender;
    NSError *err;
    [self.InputDevice.device lockForConfiguration: &err];
    if (err) {
        NSLog(@"%@\n",err);
    }
    else {
        self.InputDevice.device.videoZoomFactor = temp.value;
    }
    [self.InputDevice.device unlockForConfiguration];
}

- (IBAction)Cap:(id)sender {
    //长按running
    
}

#pragma mark match

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    (void)captureOutput;
    (void)connection;
    if (1) {
        //NSLog(@"called!!\n");
        // convert from Core Media to Core Video
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        void* bufferAddress;
        size_t width;
        size_t height;
        size_t bytesPerRow;
        int format_opencv;
        OSType format = CVPixelBufferGetPixelFormatType(imageBuffer);
        
        
        if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            format_opencv = CV_8UC1;
            
            bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
            width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
            height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
            bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        }
        else { // expect kCVPixelFormatType_32BGRA
            assert(format == kCVPixelFormatType_32BGRA);
            format_opencv = CV_8UC4;
            bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
            width = CVPixelBufferGetWidth(imageBuffer);
            height = CVPixelBufferGetHeight(imageBuffer);
            bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        }
        
        cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
        cv::cvtColor(image, image, CV_BGR2RGB);
        
        if (cntFrame >= FrameRate*0.2) {
            cntFrame = 0;
            int Sele_X = (self.Select.frame.origin.x-self.CameraView.frame.origin.x)*RatioX;
            int Sele_Y = (self.Select.frame.origin.y-self.CameraView.frame.origin.y)*RatioY;
            int Sele_Width = self.Select.frame.size.width*RatioX;
            int Sele_Height = self.Select.frame.size.height*RatioY;
           
            
            cv::Rect roiRect(Sele_X,Sele_Y,Sele_Width,Sele_Height);
            cv::Mat temp;
            image(roiRect).convertTo(temp, temp.type());
            
            [self.MyMatch HandleImage:temp];
        }
        else {
            cntFrame++;
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
}

- (void)MatchCompletedWithString:(NSString *)Result {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.MatchResult.text = Result;
    });
    
}

- (void) ShowHandlePic:(UIImage *)image {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.testResult.image = image;
    });
}

@end
