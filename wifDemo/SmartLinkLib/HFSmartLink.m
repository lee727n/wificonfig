//
//  HFSmartLink.m
//  SmartlinkLib
//
//  Created by wangmeng on 15/3/16.
//  Copyright (c) 2015年 HF. All rights reserved.
//

#import "HFSmartLink.h"
#import "Udpproxy.h"
#include "hf-pmk-generator.h"

#define SMTV30_BASELEN      76
#define SMTV30_STARTCODE      '\r'
#define SMTV30_STOPCODE       '\n'
#define V8_RANDOM_NUM          0xAA
#define PWD_USR_INTER          0x1B

// for 机智云
//#define GIZWITS

@implementation HFSmartLink{
    SmartLinkProcessBlock processBlock;
    SmartLinkSuccessBlock successBlock;
    SmartLinkFailBlock failBlock;
    SmartLinkStopBlock stopBlock;
    SmartLinkEndblock endBlock;
    //NSString * pswd;
    char pswd[200];
    int pswd_len;
    char cont[200];
    int cont_len;
    char v8Magic[4];
    char v8Prefix[4];
    char v8Data[300];
    int v8Data_len;
    int v8flyTime;
    BOOL isconnnecting;
    BOOL userStoping;
    NSInteger sendTime;
    NSMutableDictionary *deviceDic;
    Udpproxy * udp;
    BOOL withV3x;
}

+(instancetype)shareInstence{
    static HFSmartLink * me = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
         me = [[HFSmartLink alloc]init];
    });
    return me;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /**
         *  初始化 套接字
         */
//        [UdpProxy shaInstence];
        udp = [Udpproxy shareInstence];
        deviceDic = [[NSMutableDictionary alloc]init];
        self.isConfigOneDevice = true;
        self.waitTimers = 60;//15;
        withV3x=true;
    }
    return self;
}

- (int)getStringLen:(NSString*)str
{
    int strlen=0;
    char *p=(char *)[str cStringUsingEncoding:NSUnicodeStringEncoding];
    for (int i=0;i<[str lengthOfBytesUsingEncoding:NSUnicodeStringEncoding];i++)
    {
        if (*p)
        {
            p++;
            strlen++;
        }
        else
        {
            p++;
        }
    }
    return strlen;
}

-(void)startWithSSID:(NSString*)ssidStr Key:(NSString*)pswdStr UserStr:(NSString *)userStr withV3x:(BOOL)v3x processblock:(SmartLinkProcessBlock)pblock successBlock:(SmartLinkSuccessBlock)sblock failBlock:(SmartLinkFailBlock)fblock endBlock:(SmartLinkEndblock)eblock

{
    NSLog(@"to send...");
    withV3x=v3x;
    if(udp){
        [udp CreateBindSocket];
    }else{
        udp = [Udpproxy shareInstence];
        [udp CreateBindSocket];
    }

    [self v8byteConvertSsid:ssidStr Key:pswdStr UserStr:userStr];
    
    int ssidLen=[self getStringLen:ssidStr];
    int pswdLen=[self getStringLen:pswdStr];
    int ustrLen=[self getStringLen:userStr];
    
    unsigned char buf[33];
    memset(buf, 0, 33);
    pbkdf2_sha1([pswdStr UTF8String], [ssidStr UTF8String], ssidLen, 4096, buf, 32);
    
    char contC[200];
    int contC_len=0;
    memset(contC,0,200);
    contC[contC_len++]=[self getStringLen:ssidStr];//[ssidStr length];
    contC[contC_len++]=[self getStringLen:pswdStr];//[pswdStr length];
    if (pswdLen!=0)
        contC[contC_len++]=32;
    else
        contC[contC_len++]=0;
    if (ustrLen==0)
    {
        contC[contC_len++]= 0;
    }
    else
    {
#ifdef GIZWITS
        contC[contC_len++]=ustrLen+2;
#else
        contC[contC_len++]=ustrLen;
#endif
    }
    sprintf(&(contC[contC_len]), "%s", [ssidStr UTF8String]);
    contC_len+=ssidLen;//[ssidStr length];
    sprintf(&(contC[contC_len]), "%s", [pswdStr UTF8String]);
    contC_len+=pswdLen;//[pswdStr length];
    if (pswdLen/*[pswdStr length]*/!=0)
    {
        memcpy(&(contC[contC_len]), buf, 32);
        contC_len+=32;
    }
    if (ustrLen>0)
    {
#ifdef GIZWITS
        contC[contC_len++]= 0x00;
        contC[contC_len++]= 0x1b;
#endif
        sprintf(&(contC[contC_len]), "%s", [userStr UTF8String]);
        contC_len+=ustrLen;
    }
    
    if (contC_len % 2!=0){
        contC_len++;
    }
    
 //   pswd=pswdStr;
    memset(pswd, 0, 200);
    sprintf(pswd, "%s", [pswdStr UTF8String]);
    pswd_len= pswdLen;
    if (ustrLen>0)
    {
#ifdef GIZWITS
        pswd[pswd_len++]= 0x00;
#endif
        pswd[pswd_len++]= 0x1b;
        sprintf(&(pswd[pswd_len]), "%s", [userStr UTF8String]);
        pswd_len+=ustrLen;
    }
    memcpy(cont, contC, contC_len);
    cont_len=contC_len;
    // print content
    NSLog(@"***To Print Content***");
    char output[500];
    memset(output, 0, 500);
    for (int i=0;i<cont_len;i++){
        sprintf(output, "%s %X", output, (unsigned char)cont[i]);
    }
    NSLog(@"%s", output);
    processBlock = pblock;
    successBlock = sblock;
    failBlock = fblock;
    endBlock = eblock;
    sendTime = 0;
    userStoping = false;
    [deviceDic removeAllObjects];
    if(isconnnecting){
        failBlock(@"is connecting ,please stop frist!");
        return ;
    }
    isconnnecting = true;
    //开始配置线程
    [[[NSOperationQueue alloc]init]addOperationWithBlock:^(){
        [self connectV70];
    }];
    
    [[[NSOperationQueue alloc]init]addOperationWithBlock:^(){
        [self doProcess];
    }];
}

- (void)doProcess
{
    NSLog(@"start waitting module msg ");
    NSInteger waitCount = 0;
    while (waitCount < self.waitTimers&&isconnnecting) {
        [udp sendSmartLinkFind];
        sleep(1);
        waitCount++;
        NSLog(@"waitCount=%ld", (long)waitCount);
        processBlock(waitCount*100/self.waitTimers);
    }
    isconnnecting = false;
}

-(void)stopWithBlock:(SmartLinkStopBlock)block{
    stopBlock = block;
    isconnnecting = false;
    userStoping = true;
}
-(void)closeWithBlock:(SmartLinkCloseBlock)block{
    if(isconnnecting){
        dispatch_async(dispatch_get_main_queue(), ^(){
            block(@"please stop connect frist",false);
        });
    }
    
    if(udp){
        [udp close];
        dispatch_async(dispatch_get_main_queue(), ^(){
            block(@"close Ok",true);
        });
    }else{
        dispatch_async(dispatch_get_main_queue(), ^(){
            block(@"udp sock is Closed,on need Close more",false);
        });
    }
}

#pragma Send and Rcv
-(void)connectV70{
    //开始接收线程
    [[[NSOperationQueue alloc]init]addOperationWithBlock:^(){
        NSLog(@"start recv");
        [self recvNewModule];
    }];

    int flyTime=0;      // unit:10ms
    while (isconnnecting) {
        char cip[20];
        char c[100];
        memset(c, 0, 100);
        int sn=0;
        
        for (int i=0;i<sn+30;i++){
            c[i]='a';
        }
        
        for (int i=0;i<5;i++){
            [udp sendMCast:c withAddr:"239.48.0.0" andSN:0];
            usleep(10000);
            [self sendSmtlkV30:flyTime];
            flyTime++;
        }
        
        while (isconnnecting&&(sn*2<cont_len)) {
            memset(cip, 0, 20);
            sprintf(cip, "239.46.%d.%d",(unsigned char)cont[sn*2],(unsigned char)cont[sn*2+1]);
//            NSLog(@"%X %X", (unsigned char)cont[sn*2],(unsigned char)cont[sn*2+1]);
            [udp sendMCast:c withAddr:cip andSN:0];
            usleep(10000);
            [self sendSmtlkV30:flyTime];
            flyTime++;
            c[sn+30]='a';
            sn++;
        }

        for (int i=0;i<5;i++){
            usleep(10000);
            [self sendSmtlkV30:flyTime];
            flyTime++;
        }
        
//        if (isconnnecting){
//            sendTime++;
//            NSLog(@"send time %d",sendTime);
//            dispatch_async(dispatch_get_main_queue(), ^(){
//                processBlock(sendTime);
//            });
//        }
    }
}

- (void) sendSmtlkV30:(int)ft
{
    if (withV3x==false)
    {
        [self sendV8Data:ft];
        return;
    }
    
    while (ft>= 200+(3+pswd_len+6)*5){
        ft-=200+(3+pswd_len+6)*5;
    }
    
    if (ft< 200){
        [self sendOnePackageByLen:SMTV30_BASELEN];
    }else if (ft % 5 == 0){
        int ft5=(ft-200)/5;
        if (ft5<3){
            [self sendOnePackageByLen:SMTV30_BASELEN+SMTV30_STARTCODE];
        }else if (ft5<3+pswd_len){
            int code=SMTV30_BASELEN+ pswd[ft5-3];//[pswd characterAtIndex:(ft5-3)];
            [self sendOnePackageByLen:code];
            NSLog(@"code:%X", (unsigned char)pswd[ft5-3]);//[pswd characterAtIndex:(ft5-3)]);
        }else if (ft5<3+pswd_len+3){
            [self sendOnePackageByLen:SMTV30_BASELEN+SMTV30_STOPCODE];
        }else if (ft5< 3+pswd_len+6){
            [self sendOnePackageByLen:SMTV30_BASELEN+pswd_len+256];
        }
    }
}

-(void)sendOnePackageByLen:(NSInteger)len{
    char data[len+1];
    memset(data, 5, len);
    data[len]='\0';
    [udp send:data];
}
-(void)recvNewModule{
    while (isconnnecting) {
        HFSmartLinkDeviceInfo * dev = [udp recv:V8_RANDOM_NUM];
        if(dev == nil){
            continue;
        }
        
        if([deviceDic objectForKey:dev.mac] != nil){
            continue;
        }

        [deviceDic setObject:dev forKey:dev.mac];
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            successBlock(dev);
        });
        
        if (self.isConfigOneDevice) {
            NSLog(@"end config once");
            isconnnecting = false;
            dispatch_async(dispatch_get_main_queue(), ^(){
                endBlock(deviceDic);
            });
            [udp close];
            return ;
        }
    }
    
    if(userStoping){
        dispatch_async(dispatch_get_main_queue(), ^(){
            stopBlock(@"stop connect ok",true);
        });
    }
    
    if(deviceDic.count <= 0&&!userStoping){
        dispatch_async(dispatch_get_main_queue(), ^(){
            failBlock(@"smartLink fail ,no device is configed");
        });
    }
    
    [udp close];
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        endBlock(deviceDic);
    });
}

- (int) getByte:(unsigned char *)bytes pos:(int)pos
{
    if (pos<20*4+4)
    {
        return bytes[pos]+1;
    }
    else
    {
        int itmp= pos- 20*4-4;
        int mod= itmp % 6;
        if (mod==0 || mod==1)
        {
            return bytes[pos]+1;
        }
        else
        {
            return bytes[pos]+0x0100+1;
        }
    }
}

int headNum= 40;
int magicNum= 20;
int prefixNum= 20;
int dataLoops= 15;

- (void) sendV8Data:(int)ft
{
    int bsend[10];
    static int tm= 0;
    tm++;
    if (tm>=5)
    {
        tm=0;
        int len= [self getByteRet:bsend rLen:10];
        v8flyTime++;
        if (len<=0)
        {
            v8flyTime= 0;
            NSLog(@"Restart Airkiss");
        }
        else
            for (int i=0; i<len; i++)
            {
                NSLog(@"Send:%d, 0x%02X\n", bsend[i], bsend[i]);
                if (bsend[i]==0)
                    bsend[i]= 8;
                [self sendOnePackageByLen:bsend[i]];
                usleep(5000);
            }
    }
}

- (int) getByteRet:(int *)ret rLen:(int)len
{
    NSLog(@"flyTime:%d\n", v8flyTime);
    if (v8flyTime<headNum)
    {
        memset(ret, 0, len);
        for (int i=0; i<4; i++)
            ret[i]= i+1;
        return 4;
    }
    else if (v8flyTime < headNum+magicNum)
    {
        memset(ret, 0, len);
        for (int i=0; i<4; i++)
            ret[i]= (v8Magic[i] & 0x0FF);
        return 4;
    }
    else if (v8flyTime < headNum+magicNum+prefixNum)
    {
        memset(ret, 0, len);
        for (int i=0; i<4; i++)
            ret[i]= (v8Prefix[i] & 0x0FF);
        return 4;
    }
    else
    {
        int blocks= v8Data_len /6;
        if (blocks * 6 < v8Data_len)
            blocks++;
        int loop= (v8flyTime-headNum-magicNum-prefixNum) / blocks;
        if (loop >= dataLoops)
            return -1;
        else
        {
            int blockIdx= (v8flyTime - headNum-magicNum-prefixNum) % blocks;
            int pos= blockIdx * 6;
            int len= 6;
            if (pos+len > v8Data_len)
                len= v8Data_len- pos;
            memset(ret, 0, len);
            ret[0]= v8Data[pos] & 0x0FF;
            ret[1]= v8Data[pos+1] & 0x0FF;
            for (int i=2; i<len; i++)
                ret[i]= (v8Data[pos+i] & 0x0FF) + 0x0100;
            return len;
        }
    }
}

- (void) v8byteConvertSsid:(NSString*)ssidStr Key:(NSString*)pswdStr UserStr:(NSString *)userStr
{
    int bPwdUsrLen= (int)[self getStringLen:pswdStr];
    if ([self getStringLen:userStr]>0)
        bPwdUsrLen+= [self getStringLen:userStr]+1;
    else
    {
#ifdef GIZWITS
        bPwdUsrLen+=2;
#else
        bPwdUsrLen+=1;
#endif
    }
    int dLen= bPwdUsrLen+1+(int)[self getStringLen:ssidStr];
    char bData[200];
    memset(bData, 0, 200);
    int pos= 0;
    sprintf(&(bData[pos]), "%s", [pswdStr UTF8String]);
    pos+= [self getStringLen:pswdStr];
#ifdef GIZWITS
    bData[pos++]= 0x00;
#endif
    bData[pos++]= 0x1b;
    if ([self getStringLen:userStr]>0)
    {
        sprintf(&(bData[pos]), "%s", [userStr UTF8String]);
        pos+= [self getStringLen:userStr];
    }
    bData[pos++]= V8_RANDOM_NUM;         // this is the random num
    sprintf(&(bData[pos]), "%s", [ssidStr UTF8String]);
    pos+= [self getStringLen:ssidStr];
    
    char tmp[64];
    memset(tmp, 0, 64);
    sprintf(tmp, "%s", [ssidStr UTF8String]);
    int ssidCrc= [self crc8:(unsigned char *)tmp len:(int)[self getStringLen:ssidStr]];
    [self getMagicBytes:dLen ssidCrc:ssidCrc Ret:v8Magic];
    
    int pLen=bPwdUsrLen;
    memset(tmp, 0, 64);
    int plbLen= [self itob:pLen Ret:tmp];
    int plCrc= [self crc8:(unsigned char *)tmp len:plbLen];
    [self getPrefixBytes:pLen plCrc:plCrc Ret:v8Prefix];
    
    int dblocks= dLen/4;
    if (dblocks*4 < dLen)
    {
        dblocks++;
    }
    v8Data_len= 0;
    pos= 0;
    for (int i=0; i<dblocks; i++)
    {
        v8Data_len+=[self getBlockBytes:bData pos:&pos len:dLen Ret:&(v8Data[v8Data_len])];
    }
    v8flyTime= 0;
}

- (int) getBlockBytes:(char *)data pos:(int *)pos len:(int)dlen Ret:(char *)ret
{
    int len=dlen- *pos;
    if (len>4){
        len= 4;
    }
    int retLen=len+2;
    memset(ret, 0, retLen);
    ret[1]= (*pos/4);
    for (int i=0; i<len; i++)
    {
        ret[2+i]= *(data+*pos+i);
    }
    int crc= [self crc8:(unsigned char *)&(ret[1]) len:len+1];
    ret[0]= 0x80 | (crc & 0x7F);
    ret[1]= 0x80 | ret[1];
    NSLog(@"Block pos=%d:", *pos);
    for (int i=0; i<retLen; i++)
    {
        NSLog(@"%02X ", (unsigned char)ret[i]);
    }
    NSLog(@"\n");
    (*pos)+=len;
    return retLen;
}

- (int) getMagicBytes:(int)dLen ssidCrc:(int)ssidCrc Ret:(char *)ret
{
    int retLen= 4;
    memset(ret, 0, retLen);
    ret[0]= 0x000 | ((dLen>>4)&0x0F);
    ret[1]= 0x010 | ((dLen>>0)&0x0F);
    ret[2]= 0x020 | ((ssidCrc>>4)&0x0F);
    ret[3]= 0x030 | ((ssidCrc>>0)&0x0F);
    NSLog(@"Magic:%02X %02X %02X %02X\n", ret[0], ret[1], ret[2], ret[3]);
    return retLen;
}

- (int) getPrefixBytes:(int)pLen plCrc:(int)plCrc Ret:(char *)ret
{
    int retLen= 4;
    memset(ret, 0, retLen);
    ret[0]= 0x040 | ((pLen>>4)&0x0F);
    ret[1]= 0x050 | ((pLen>>0)&0x0F);
    ret[2]= 0x060 | ((plCrc>>4)&0x0F);
    ret[3]= 0x070 | ((plCrc>>0)&0x0F);
    NSLog(@"Prefix:%02X %02X %02X %02X\n", ret[0], ret[1], ret[2], ret[3]);
    return retLen;
}

- (int) itob:(int)i Ret:(char *)ret
{
    int bLen= 0;
    if (i > 0x0FFFFFF)
        bLen= 4;
    else if (i > 0x0FFFF)
        bLen= 3;
    else if (i > 0x0FF)
        bLen= 2;
    else
        bLen= 1;
    for (int n=0; n<bLen; n++)
    {
        ret[n]= (i>>(8*n))&0x0FF;
    }
    return bLen;
}

- (int) crc8:(unsigned char *)ptr len:(int)len
{
    unsigned char crc;
    unsigned char i, data;
    crc= 0;
    while (len--) {
        data= (*ptr)&0xff;
        crc ^= data;
        for (i=0; i<8; i++)
        {
            if (crc & 0x01)
            {
                crc= (crc>>1)^0x8c;
            }
            else
            {
                crc >>=1;
            }
        }
        ptr++;
    }
    return crc;
}
@end
