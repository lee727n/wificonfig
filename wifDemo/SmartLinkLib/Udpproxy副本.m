//
//  udpproxy.m
//  smartlinklib_7x
//
//  Created by Peter on 16/5/20.
//  Copyright © 2016年 Peter. All rights reserved.
//

#import "Udpproxy.h"
#import "HFSmartLinkDeviceInfo.h"

#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <err.h>
#include <ifaddrs.h>

#define PORT 49999 /* Port that will be opened */
#define MPORT 45999 /* Port that will be opened */
#define MAXDATASIZE 100 /* Max number of bytes of data */

@implementation Udpproxy
{
    int sockfd; /* socket descriptors */
    int sockMCast;

    struct addrinfo *localAdd; /* server's address information */
    struct addrinfo *remoteAdd;
    struct addrinfo *findAdd;

    int num;
    char recvmsg[MAXDATASIZE]; /* buffer for message */
    char sendmsg[MAXDATASIZE];
}

+(instancetype)shareInstence
{
    static Udpproxy *me = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        me = [[Udpproxy alloc]init];
    });
    return me;
}

-(void)CreateBindSocket
{
    struct addrinfo hints;
    
    hints.ai_family=AF_INET;
    hints.ai_socktype=SOCK_DGRAM;
    hints.ai_protocol=IPPROTO_UDP;
    hints.ai_flags=AI_NUMERICHOST;
    int rc=getaddrinfo("0.0.0.0", "49999", &hints, &localAdd);
    
    if ((sockfd = socket(hints.ai_family, hints.ai_socktype, 0)) == -1) {
        /* handle exception */
        NSLog(@"Creating socket failed.");
        return;
    }
    if (bind(sockfd, localAdd->ai_addr, localAdd->ai_addrlen)) {
        NSLog(@"Bind error");
        return;
    }
    
    int i=1;
    socklen_t len = sizeof(i);
    setsockopt(sockfd,SOL_SOCKET,SO_BROADCAST,&i,len);
    struct timeval timeout={1,0};
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    int set=1;
    setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, (char *)&set, sizeof(set));

    memset(&hints,0,sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    hints.ai_flags= AI_NUMERICHOST;
    rc=getaddrinfo([self localBroadCastIP].UTF8String, "48899", &hints, &findAdd);
    rc=getaddrinfo([self localBroadCastIP].UTF8String, "49999", &hints, &remoteAdd);
    
    if ((sockMCast = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
        /* handle exception */
        NSLog(@"Creating socket failed.");
        return;
    }
    memset(&hints,0,sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    hints.ai_flags= AI_NUMERICHOST;
    
    rc=getaddrinfo("0.0.0.0", "45999", &hints, &localAdd);
    if (bind(sockMCast, localAdd->ai_addr, localAdd->ai_addrlen)) {
        NSLog(@"Bind error");
        return;
    }
    char loop=0, ttl=255, reuse=1;
    int ret=setsockopt(sockMCast, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    ret=setsockopt(sockMCast, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, sizeof(loop));
    ret=setsockopt(sockMCast, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl));
    
    struct ip_mreq mcast;
    mcast.imr_interface.s_addr=htonl (INADDR_ANY);
    char *strIp="224.0.0.251";
    struct in_addr s;
    inet_pton(AF_INET, strIp, (void *)&s);
    mcast.imr_multiaddr.s_addr=s.s_addr;
    if (setsockopt(sockMCast, IPPROTO_IP, IP_ADD_MEMBERSHIP, (char *)&mcast, sizeof(mcast))<0){
        NSLog(@"add membership error");
        return;
    }
}

-(void)send:(char*)shit
{
    NSInteger len = sendto(sockfd, shit, strlen(shit), 0, remoteAdd->ai_addr, remoteAdd->ai_addrlen);
    if(len<0){
        NSLog(@"send errr");
    }
    return ;
}
-(void)sendMCast:(char*)shit withAddr:(char *)addr andSN:(int)sn
{
//    struct addrinfo hints,*sendAddr;
//    memset(&hints,0,sizeof(hints));
//    hints.ai_family = AF_INET;
//    hints.ai_socktype = SOCK_DGRAM;
//    hints.ai_protocol = IPPROTO_UDP;
//    hints.ai_flags= AI_NUMERICHOST;
//    int rc=getaddrinfo(addr, "49999", &hints, &sendAddr);
//
//    NSInteger len = sendto(sockfd, shit, strlen(shit), 0, sendAddr->ai_addr, sendAddr->ai_addrlen);
//    if(len<0){
//        NSLog(@"send MCast errr");
//    }
    return ;
}

-(void)sendSmartLinkFind
{
//    char data[] = "smartlinkfind1";           // for Ali
    char data[] = "smartlinkfind";
    sendto(sockfd, data, strlen(data), 0, findAdd->ai_addr, findAdd->ai_addrlen);
}

-(HFSmartLinkDeviceInfo *)recv{
    char recvbuf[512]={0};
    struct sockaddr clientAdd;
    socklen_t recv_addr_len = sizeof(clientAdd);
    NSInteger len  = recvfrom(sockfd,recvbuf,512,0,(struct sockaddr*)&clientAdd,&recv_addr_len);
    
    if(len < 0){
        return nil;
    }
    
    NSString *s= [[NSString alloc] initWithBytes:recvbuf length:len encoding:NSASCIIStringEncoding];
    NSArray *a= [s componentsSeparatedByString:@" "];
    if (a.count>=2)
    {
        char caddr[30]={0};
        NSString * ip =[NSString stringWithFormat:@"%s",inet_ntop(clientAdd.sa_family,clientAdd.sa_data+2,caddr,clientAdd.sa_len)];
        NSString * mac = [a objectAtIndex:1];
        
        {
            HFSmartLinkDeviceInfo *dev=[[HFSmartLinkDeviceInfo alloc] init];
            dev.mac = mac;
            dev.ip = ip;
            return dev;
        }
    }
    
    return nil;
}

-(void)close
{
    close(sockfd);
    close(sockMCast);
}

-(NSString *)localBroadCastIP
{
    NSString *address = @"error";
    struct ifaddrs *interface = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    UInt32 uip,umask,ubroadip;
    
    success = getifaddrs(&interface);
    
    if(success == 0){
        temp_addr = interface;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name]isEqualToString:@"en0"]) {
                    uip = NTOHL(((struct sockaddr_in *)(temp_addr->ifa_addr))->sin_addr.s_addr);
                    umask = NTOHL((((struct sockaddr_in *)(temp_addr->ifa_netmask))->sin_addr).s_addr);
                    ubroadip = (uip&umask)+(0XFFFFFFFF&(~umask));
                    struct in_addr inadd;
                    inadd.s_addr = HTONL(ubroadip);
                    char caddr[30]={0};
                    address=[NSString stringWithUTF8String:inet_ntop(AF_INET,(char *)&inadd,caddr,16)];
                    break;
                }
            }else if (temp_addr->ifa_addr->sa_family == AF_INET6){
                
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interface);
    return address;
}

@end
