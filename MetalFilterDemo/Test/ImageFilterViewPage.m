//
//  ImageFilterViewPage.m
//  ImageFilterViewPage
//
//  Created by yasic on 2018/9/27.
//  Copyright © 2018年 yasic. All rights reserved.
//

#import "ImageFilterViewPage.h"
#import <Metal/Metal.h>
#import <MetalKit/MTKView.h>
#import "ImageFilterProcessor.h"

@interface ImageFilterViewPage ()<MTKViewDelegate>

@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) ImageFilterProcessor *filterProcessor;
@property (nonatomic, strong) id<MTLDevice> mtlDevice;

@property (nonatomic, strong) UIView *swipeView;

@property (nonatomic, assign) NSInteger lutImageIndex;
@property (nonatomic, strong) NSArray<UIImage *> *lutImages;
@property (nonatomic, strong) UILabel *lutImageLabel;

@end

@implementation ImageFilterViewPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.filterProcessor = [[ImageFilterProcessor alloc] init];
    self.mtlDevice = self.filterProcessor.mtlDevice;
    [self addViews];
    
    NSString *path = [NSBundle.mainBundle pathForResource:@"FilterTargetImage.png" ofType:@""];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    [self.filterProcessor loadOriginalImage:image];
    
    UIImage *image1 = [UIImage imageNamed:@"zx_test"];
    [self.filterProcessor loadLUTImage:image1];
}

- (void)addViews
{
    [self.view addSubview:self.mtkView];
    self.filterProcessor.mtlView = self.mtkView;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    [self.filterProcessor renderImage];
}

- (MTKView *)mtkView
{
    if (!_mtkView) {
        _mtkView = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) device:self.mtlDevice];
        _mtkView.delegate = self;
    }
    return _mtkView;
}

@end
