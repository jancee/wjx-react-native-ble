#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>



@interface BleManager : RCTEventEmitter <RCTBridgeModule, CBCentralManagerDelegate, CBPeripheralDelegate>



//CBCentralManager
@property (strong, atomic) CBCentralManager     *manager;           //当前应用的CBCentralManager
@property (strong, atomic) CBCentralManager     *sharedManager;     //恢复的CBCentralManager（没什么用）
@property (strong, atomic) NSMutableDictionary  *managerOptions; //CBCentralManager的配置信息


//设备
@property (strong, atomic) NSMutableSet *peripherals;           //所有设备



//回调
@property (strong, atomic) NSMutableDictionary *connectCallbacks;           //连接结果回调
@property (strong, atomic) NSMutableDictionary *readCallbacks;              //读数据结果回调
@property (strong, atomic) NSMutableDictionary *writeCallbacks;             //写响应结果回调
@property (strong, atomic) NSMutableDictionary *readRSSICallbacks;          //读RSSI结果回调
@property (strong, atomic) NSMutableDictionary *retrieveServicesCallbacks;  //发现服务结果回调
@property (strong, atomic) NSMutableDictionary *notificationCallbacks;      //开启广播结果回调
@property (strong, atomic) NSMutableDictionary *stopNotificationCallbacks;  //关闭广播结果回调



//逻辑
@property (strong, atomic) NSMutableArray      *writeQueue;              //有响应的写数据排序队列
@property (strong, atomic) NSMutableDictionary *retrieveServicesLatches; //遗留未发现服务的特征记录
@property (weak, atomic)   NSTimer             *scanTimer;               //扫描定时器





+ (BleManager *)getInstance;





@end





