//
//  ViewController.m
//  wifDemo
//
//  Created by liu zixuan on 2019/5/17.
//  Copyright © 2019 liu zixuan. All rights reserved.
//
#define ScreenWidth             [UIScreen mainScreen].bounds.size.width
#define ScreenHeight            [UIScreen mainScreen].bounds.size.height

#import "ViewController.h"
#import <SystemConfiguration/CaptiveNetwork.h>
//#import "smartlinklib_7x.h"
#import "HFSmartLink.h"
#import "HFSmartLinkDeviceInfo.h"

@interface ViewController ()
@property(nonatomic,strong)UILabel *wifiName;
@property(nonatomic,strong)UITextField *wifiPW;
@property (nonatomic, strong)UILabel *lbprogress;
@property (nonatomic, strong)UILabel *tips;
@property(nonatomic,strong) UIButton *linkBtn;
@property (nonatomic,strong) UIProgressView *progress;
@property(nonatomic,assign) BOOL finish;
////wifi连接
@property (nonatomic, strong)  HFSmartLink * smtlk;
//是否正在连接
@property (nonatomic, assign)  BOOL isconnecting;;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = @"wifi 配置";
    self.view.backgroundColor = [UIColor whiteColor];
    _wifiName = [[UILabel alloc]initWithFrame:CGRectMake((ScreenWidth - 150)/2, 100, 150, 25)];
    //_wifiName.text = @"TP-LINK_FFAC";
    _wifiName.text = @"";
    _wifiName.textAlignment = 0 ;
    _wifiName.numberOfLines = 1;
    _wifiName.textColor = [UIColor blackColor];
    _wifiName.font = [UIFont systemFontOfSize:18];
    _wifiName.layer.borderColor = [UIColor blackColor].CGColor;
    _wifiName.layer.borderWidth = 1;
    [self.view addSubview:_wifiName];
    
    _wifiPW = [[UITextField alloc]initWithFrame:CGRectMake((ScreenWidth - 150)/2, 150, 150, 25)];
    _wifiPW.placeholder = @"wifi 密码";
//    _wifiPW.text = @"12345678";
    _wifiPW.text = @"";
    _wifiPW.textAlignment = NSTextAlignmentLeft;
    _wifiPW.font = [UIFont systemFontOfSize:16];
    _wifiPW.keyboardType = UIReturnKeyDefault;
    [self.view addSubview:_wifiPW];
    

    
    _lbprogress = [[UILabel alloc]initWithFrame:CGRectMake((ScreenWidth - 150)/2, 250, 150, 25)];
    _lbprogress.text = @"";
    _lbprogress.textAlignment = 0 ;
    _lbprogress.numberOfLines = 1;
    _lbprogress.textColor = [UIColor blackColor];
    _lbprogress.font = [UIFont systemFontOfSize:18];
    _lbprogress.layer.borderColor = [UIColor blackColor].CGColor;
    _lbprogress.layer.borderWidth = 1;
    [self.view addSubview:_lbprogress];
    
    _tips = [[UILabel alloc]initWithFrame:CGRectMake((ScreenWidth - 150)/2, 300, 150, 25)];
    _tips.text = @"";
    _tips.textAlignment = 0 ;
    _tips.numberOfLines = 1;
    _tips.textColor = [UIColor blackColor];
    _tips.font = [UIFont systemFontOfSize:18];
    _tips.layer.borderColor = [UIColor blackColor].CGColor;
    _tips.layer.borderWidth = 1;
    [self.view addSubview:_tips];
    
    
    _linkBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _linkBtn.frame = CGRectMake((ScreenWidth - 150)/2, 200, 150, 25);
    [_linkBtn setTitle:@"连接" forState:UIControlStateNormal];
    [_linkBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_linkBtn setBackgroundColor:[UIColor greenColor]];
    [_linkBtn addTarget:self action:@selector(btnclick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_linkBtn];
    
    [self.view addSubview:self.progress];
    
    NSString *wifi =  [self fetchSSIDInfo];
    _wifiName.text = wifi;
    HFSmartLink * smtlk = [HFSmartLink shareInstence];
    

    self.smtlk = [HFSmartLink shareInstence];
    self.smtlk.isConfigOneDevice = true;
    self.smtlk.waitTimers = 60;
    self.isconnecting=false;
    
    self.finish = 0;
    
}

-(UIProgressView *)progress {
    if (!_progress) {
        
        //进度条高度不可修改
        _progress = [[UIProgressView alloc] initWithFrame:CGRectMake((ScreenWidth - 150)/2, 250, 150, 20)];
        CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, 3.0f);
        _progress.transform = transform;
        //设置进度条的颜色
        _progress.progressTintColor = [UIColor blueColor];
        
        //设置进度条的当前值，范围：0~1；
        _progress.progress = 0;
        
        /*
         typedef NS_ENUM(NSInteger, UIProgressViewStyle) {
         UIProgressViewStyleDefault,     // normal progress bar
         UIProgressViewStyleBar __TVOS_PROHIBITED,     // for use in a toolbar
         };
         */
        _progress.progressViewStyle = UIProgressViewStyleDefault;
        
        _progress.progress = 0.5;
    }
    return _progress;
}

-(void)btnclick{
    
     [self setWifiSet];
    
}
-(void)setWifiSet{
    if(!self.isconnecting){
        self.isconnecting = true;
        __weak typeof(*&self) weakSelf = self;
        [self.smtlk startWithSSID:_wifiName.text Key:_wifiPW.text UserStr:@"" withV3x:false
                     processblock: ^(NSInteger pro) {
                         
                       
                         dispatch_async(dispatch_get_main_queue(), ^{
                            // UI更新代码
                             if (!weakSelf.finish) {
                                 weakSelf.lbprogress.text = [NSString stringWithFormat:@"%ld%%",(pro)];
                                 weakSelf.progress.progress = (float)(pro)/100.0;
                             }

                        });

                     } successBlock:^(HFSmartLinkDeviceInfo *dev) {
                       
                         dispatch_async(dispatch_get_main_queue(), ^{
                             // UI更新代码
                             weakSelf.tips.text = @"配置成功";
                             self.finish = YES;
                             weakSelf.lbprogress.text = [NSString stringWithFormat:@"%ld%%",100];
                             weakSelf.progress.progress = 1;
                         });
                
                         
                     } failBlock:^(NSString *failmsg) {
                       
                     
                         
                     } endBlock:^(NSDictionary *deviceDic) {
                         self.isconnecting  = false;
                         //                    [BOEProgressHUD showInfoWithStatus:@"配置失败"];
                         [self.navigationController popViewControllerAnimated:YES];
                     }];
        
    }else{
        
    }
}


-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:YES];
    [self.smtlk stopWithBlock:^(NSString *stopMsg, BOOL isOk) {
        if(isOk){
            self.isconnecting  = false;
        }
    }];
    //    [[LSWifiConfig shared]stop];
}
//iOS获取当前手机WIFI名称信息
-(NSString *)fetchSSIDInfo
{
    NSString *currentSSID = @"Not Found";
    CFArrayRef myArray = CNCopySupportedInterfaces();
    if (myArray != nil){
        NSDictionary* myDict = (__bridge NSDictionary *) CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(myArray, 0));
        NSLog(@"%@",myDict);
        if (myDict!=nil){
            currentSSID=[myDict valueForKey:@"SSID"];
        } else {
            currentSSID=@"未连接Wi-Fi";
        }
    } else {
        currentSSID=@"未连接Wi-Fi";
    }
    CFRelease(myArray);
    
    return currentSSID;
}


@end
