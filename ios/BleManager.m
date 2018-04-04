#import "BleManager.h"
#import "React/RCTConvert.h"
#import "React/RCTEventDispatcher.h"
#import "NSData+Conversion.h"
#import "CBPeripheral+Extensions.h"
#import "BLECommandContext.h"

@interface BleManager ()

@property(atomic) BOOL hasListeners;

@end




@implementation BleManager

RCT_EXPORT_MODULE();

#pragma mark -
#pragma mark - 单例 -
static BleManager *instance;
+ (BleManager *)getInstance {
    return instance;
}



#pragma mark -
#pragma mark - RN -
- (instancetype)init {
    if (self = [super init]) {
        instance = self;

        _peripherals                = [NSMutableSet set];
        _connectCallbacks           = [NSMutableDictionary new];
        _retrieveServicesLatches    = [NSMutableDictionary new];
        _readCallbacks              = [NSMutableDictionary new];
        _readRSSICallbacks          = [NSMutableDictionary new];
        _retrieveServicesCallbacks  = [NSMutableDictionary new];
        _writeCallbacks             = [NSMutableDictionary new];
        _writeQueue                 = [NSMutableArray array];
        _notificationCallbacks      = [NSMutableDictionary new];
        _stopNotificationCallbacks  = [NSMutableDictionary new];
        _managerOptions             = [NSMutableDictionary new];

        NSLog(@"BleManager created");
    }

    return self;
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

/**
 在第一个监听时触发
 */
- (void)startObserving {
    _hasListeners = YES;
}


/**
 在最后一个监听取消时触发
 */
- (void)stopObserving {
    _hasListeners = NO;
}


/**
 支持的事件
 */
- (NSArray<NSString *> *)supportedEvents {
    return @[
             @"BleManagerDidUpdateValueForCharacteristic",
             @"BleManagerStopScan",
             @"BleManagerDiscoverPeripheral",
             @"BleManagerConnectPeripheral",
             @"BleManagerDisconnectPeripheral",
             @"BleManagerDidUpdateState",
             ];
}



#pragma mark -
#pragma mark - 状态 转换为 字符串 -
- (NSString *)centralManagerStateToString:(int)state {
    switch (state) {
        case CBCentralManagerStateUnknown:
            return @"unknown";
        case CBCentralManagerStateResetting:
            return @"resetting";
        case CBCentralManagerStateUnsupported:
            return @"unsupported";
        case CBCentralManagerStateUnauthorized:
            return @"unauthorized";
        case CBCentralManagerStatePoweredOff:
            return @"off";
        case CBCentralManagerStatePoweredOn:
            return @"on";
        default:
            return @"unknown";
    }

    return @"unknown";
}

- (NSString *)periphalStateToString:(int)state {
    switch (state) {
        case CBPeripheralStateDisconnected:
            return @"disconnected";
        case CBPeripheralStateDisconnecting:
            return @"disconnecting";
        case CBPeripheralStateConnected:
            return @"connected";
        case CBPeripheralStateConnecting:
            return @"connecting";
        default:
            return @"unknown";
    }

    return @"unknown";
}

- (NSString *)periphalManagerStateToString:(int)state {
    switch (state) {
        case CBPeripheralManagerStateUnknown:
            return @"Unknown";
        case CBPeripheralManagerStatePoweredOn:
            return @"PoweredOn";
        case CBPeripheralManagerStatePoweredOff:
            return @"PoweredOff";
        default:
            return @"unknown";
    }

    return @"unknown";
}


#pragma mark -
#pragma mark - 数据查找分析 -
- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {

    CBPeripheral *peripheral = nil;

    @synchronized(self) {
        for (CBPeripheral *p in self.peripherals) {

            NSString* other = p.identifier.UUIDString;

            if ([uuid isEqualToString:other]) {
                peripheral = p;
                break;
            }
        }
    }
    return peripheral;
}

- (CBService *)findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p {
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }

    return nil; //Service not found on this peripheral
}

- (int)compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];

    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

- (NSString *)keyForPeripheral:(CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic {
    @synchronized(self) {
        return [NSString stringWithFormat:@"%@|%@", [peripheral uuidAsString], [characteristic UUID]];
    }
}



/**************** RN：对外暴露方法 *******************/
#pragma mark -
#pragma mark - RN：对外暴露方法 -
#pragma mark 获取所有发现的设备
RCT_EXPORT_METHOD(getDiscoveredPeripherals:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"获取所有发现的设备");
    NSMutableArray *discoveredPeripherals = [NSMutableArray array];
    @synchronized(self) {
        for(CBPeripheral *peripheral in self.peripherals) {
            NSDictionary * obj = [peripheral asDictionary];
            [discoveredPeripherals addObject:obj];
        }
    }
    callback(@[[NSNull null], [NSArray arrayWithArray:discoveredPeripherals]]);
}

#pragma mark 获取所有（或者给定数组中）已连接的设备
RCT_EXPORT_METHOD(getConnectedPeripherals:(NSArray *)serviceUUIDStrings callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"获取所有（或者给定数组中）已连接的设备");
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    for(NSString *uuidString in serviceUUIDStrings){
        CBUUID *serviceUUID =[CBUUID UUIDWithString:uuidString];
        [serviceUUIDs addObject:serviceUUID];
    }

    NSMutableArray *foundedPeripherals = [NSMutableArray array];
    if ([serviceUUIDs count] == 0) {
        @synchronized(self) {
            for(CBPeripheral *peripheral in self.peripherals) {
                if([peripheral state] == CBPeripheralStateConnected) {
                    NSDictionary *obj = [peripheral asDictionary];
                    [foundedPeripherals addObject:obj];
                }
            }
        }
    } else {
        NSArray *connectedPeripherals = [_manager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
        for(CBPeripheral *peripheral in connectedPeripherals) {
            NSDictionary * obj = [peripheral asDictionary];
            [foundedPeripherals addObject:obj];
            [self.peripherals addObject:peripheral];
        }
    }

    callback(@[[NSNull null], [NSArray arrayWithArray:foundedPeripherals]]);
}

#pragma mark 开启服务
RCT_EXPORT_METHOD(start:(NSDictionary *)options callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"BleManager初始化");

    //准备配置信息
    _managerOptions = [[NSMutableDictionary alloc] init];

    //在没有开启蓝牙时，弹出提示框
    if ([[options allKeys] containsObject:@"showAlert"]){
        @synchronized(self) {
            [self.managerOptions setObject:[NSNumber numberWithBool:[[options valueForKey:@"showAlert"] boolValue]]
                                forKey:CBCentralManagerOptionShowPowerAlertKey];
        }
    }

    //恢复Manager
    if ([[options allKeys] containsObject:@"restoreIdentifierKey"]) {

        @synchronized(self) {
            [self.managerOptions setObject:[options valueForKey:@"restoreIdentifierKey"]
                                forKey:CBCentralManagerOptionRestoreIdentifierKey];
        }

        if (_sharedManager) {
            _manager = _sharedManager;
            _manager.delegate = self;
        } else {
            _manager = [[CBCentralManager alloc] initWithDelegate:self
                                                            queue:dispatch_get_main_queue()
                                                          options:self.managerOptions];
            _sharedManager = _manager;
        }
    } else {
        _manager = [[CBCentralManager alloc] initWithDelegate:self
                                                        queue:dispatch_get_main_queue()
                                                      options:self.managerOptions];
    }

    callback(@[]);
}

/**
 重新初始化

 一、断开所有设备
 二、新建CBCentralManager
 三、清空所有属性
 */
#pragma mark 重新初始化
RCT_EXPORT_METHOD(reinit:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"BleManager重新初始化");

    if(_manager) {
        //找到所有已连接、正在连接设备
        NSMutableArray *foundedPeripherals = [NSMutableArray array];

        @synchronized(self) {
            for(CBPeripheral *peripheral in self.peripherals) {
                if([peripheral state] == CBPeripheralStateConnected || [peripheral state] == CBPeripheralStateConnecting) {
                    [foundedPeripherals addObject:peripheral];

                    NSLog(@"断开设备 %@",[peripheral uuidAsString]);

                    //断开这些设备
                    [_manager cancelPeripheralConnection:peripheral];

                    //事件通知
                    if (_hasListeners) {
                        [self sendEventWithName:@"BleManagerDisconnectPeripheral"
                                           body:@{@"peripheral": [peripheral uuidAsString]}];
                    }
                }
            }
        }

        //新建 manager
        _manager = [[CBCentralManager alloc] initWithDelegate:self
                                                        queue:dispatch_get_main_queue()
                                                      options:self.managerOptions];
        _sharedManager = _manager;

        _peripherals                = [NSMutableSet        set];
        _connectCallbacks           = [NSMutableDictionary new];
        _retrieveServicesLatches    = [NSMutableDictionary new];
        _readCallbacks              = [NSMutableDictionary new];
        _readRSSICallbacks          = [NSMutableDictionary new];
        _retrieveServicesCallbacks  = [NSMutableDictionary new];
        _writeCallbacks             = [NSMutableDictionary new];
        _writeQueue                 = [NSMutableArray      array];
        _notificationCallbacks      = [NSMutableDictionary new];
        _stopNotificationCallbacks  = [NSMutableDictionary new];
    } else {

    }

    callback(@[]);
}

#pragma mark 扫描
RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings
                  timeoutSeconds:(nonnull NSNumber *)timeoutSeconds
                  allowDuplicates:(BOOL)allowDuplicates
                  options:(nonnull NSDictionary*)scanningOptions
                  callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"scan with timeout %@", timeoutSeconds);
    NSArray * services = [RCTConvert NSArray:serviceUUIDStrings];
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    NSDictionary *options = nil;
    if (allowDuplicates){
        options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    }

    for (int i = 0; i < [services count]; i++) {
        CBUUID *serviceUUID =[CBUUID UUIDWithString:[serviceUUIDStrings objectAtIndex: i]];
        [serviceUUIDs addObject:serviceUUID];
    }
    [_manager scanForPeripheralsWithServices:serviceUUIDs options:options];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:[timeoutSeconds floatValue] target:self selector:@selector(stopScanTimer:) userInfo: nil repeats:NO];
    });
    callback(@[]);
}

#pragma mark 停止扫描
RCT_EXPORT_METHOD(stopScan:(nonnull RCTResponseSenderBlock)callback) {
    if (self.scanTimer) {
        [self.scanTimer invalidate];
        self.scanTimer = nil;
    }
    [_manager stopScan];
    callback(@[[NSNull null]]);
}

#pragma mark 连接设备
RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"Connect");
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral == nil) {
        // Try to retrieve the peripheral
        NSLog(@"Retrieving peripheral with UUID : %@", peripheralUUID);
        NSUUID *uuid = [[NSUUID alloc]initWithUUIDString:peripheralUUID];
        if (uuid != nil) {
            NSArray<CBPeripheral *> *peripheralArray = [_manager retrievePeripheralsWithIdentifiers:@[uuid]];
            if([peripheralArray count] > 0){
                peripheral = [peripheralArray objectAtIndex:0];
                [self.peripherals addObject:peripheral];
                NSLog(@"Successfull retrieved peripheral with UUID : %@", peripheralUUID);
            }
        } else {
            NSString *error = [NSString stringWithFormat:@"Wrong UUID format %@", peripheralUUID];
            callback(@[error, [NSNull null]]);
            return;
        }
    }
    if (peripheral) {
        NSLog(@"Connecting to peripheral with UUID : %@", peripheralUUID);

        @synchronized(self) {
            [self.connectCallbacks setObject:callback forKey:[peripheral uuidAsString]];
        }

        [_manager connectPeripheral:peripheral options:nil];

    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error, [NSNull null]]);
    }
}

#pragma makr 解除绑定（仅android）
RCT_EXPORT_METHOD(removeBond:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}


#pragma mark 断开连接设备
RCT_EXPORT_METHOD(disconnect:(NSString *)peripheralUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Disconnecting from peripheral with UUID : %@", peripheralUUID);

        if (peripheral.services != nil) {
            for (CBService *service in peripheral.services) {
                if (service.characteristics != nil) {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if (characteristic.isNotifying) {
                            NSLog(@"Remove notification from: %@", characteristic.UUID);
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }

        [_manager cancelPeripheralConnection:peripheral];
        callback(@[]);

    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error]);
    }
}

/**
 检查蓝牙状态
 */
#pragma mark 检查蓝牙状态
RCT_EXPORT_METHOD(checkState) {
    if (_manager != nil){
        [self centralManagerDidUpdateState:_manager];
    }
}


/**
 带响应写数据

 @param NSString
 @return
 */
#pragma mark 带响应写数据
RCT_EXPORT_METHOD(write:(NSString *)deviceUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  message:(NSArray*)message
                  maxByteSize:(NSInteger)maxByteSize
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"带响应写数据");

    //整理成 将要发送数据的目的上下文
    BLECommandContext *context = [self getData:deviceUUID
                             serviceUUIDString:serviceUUID
                      characteristicUUIDString:characteristicUUID
                                          prop:CBCharacteristicPropertyWrite callback:callback];

    //按照数据的字节数，申请一块内存bytes
    unsigned long c = [message count];
    uint8_t *bytes = malloc(sizeof(*bytes) * c);

    //填充数据到bytes
    unsigned i;
    for (i = 0; i < c; i++)
    {
        NSNumber *number = [message objectAtIndex:i];
        int byte = [number intValue];
        bytes[i] = byte;
    }

    //将数据数组转换成 NSData
    NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes
                                               length:c
                                         freeWhenDone:YES];

    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];

        //存储回调方法
        NSString *key = [self keyForPeripheral:peripheral
                             andCharacteristic:characteristic];

        @synchronized(self) {
            [self.writeCallbacks setObject:callback forKey:key];
        }

        RCTLogInfo(@"写数据(%lu): %@ ", (unsigned long)[message count], message);
        RCTLogInfo(@"写数据(%lu):%@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);

        if ([dataMessage length] > maxByteSize) { //分条发送
            int dataLength = (int)dataMessage.length;
            int count = 0;

            NSData* firstMessage;
            while(count < dataLength && (dataLength - count > maxByteSize)){
                if (count == 0){
                    firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                } else {
                    NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                    [self.writeQueue addObject:splitMessage];
                }
                count += maxByteSize;
            }

            if (count < dataLength) {
                NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, dataLength - count)];
                [self.writeQueue addObject:splitMessage];
            }

            NSLog(@"队列分割消息: %lu", (unsigned long)[self.writeQueue count]);

            //发送数据
            [peripheral writeValue:firstMessage
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithResponse];
        } else { //单条发送
            [peripheral writeValue:dataMessage
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithResponse];
        }
    }
}


/**
 无响应写数据

 @param NSString
 @return
 */
#pragma mark 无响应写数据
RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  message:(NSArray*)message
                  maxByteSize:(NSInteger)maxByteSize
                  queueSleepTime:(NSInteger)queueSleepTime
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"无响应写数据");

    //整理成 将要发送数据的目的上下文
    BLECommandContext *context = [self getData:deviceUUID
                             serviceUUIDString:serviceUUID
                      characteristicUUIDString:characteristicUUID
                                          prop:CBCharacteristicPropertyWriteWithoutResponse
                                      callback:callback];

    //按照数据的字节数，申请一块内存bytes
    unsigned long c = [message count];
    uint8_t *bytes = malloc(sizeof(*bytes) * c);

    //填充数据到bytes
    unsigned i;
    for (i = 0; i < c; i++) {
        NSNumber *number = [message objectAtIndex:i];
        int byte = [number intValue];
        bytes[i] = byte;
    }

    //将数据数组转换成 NSData
    NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes
                                               length:c
                                         freeWhenDone:YES];

    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];

        if ([dataMessage length] > maxByteSize) { //数据长度大于最大长度
            NSUInteger length = [dataMessage length];
            NSUInteger offset = 0;

            //分条发送数据
            do {
                //计算本次发送的数据长度
                NSUInteger thisChunkSize = length - offset > maxByteSize ? maxByteSize : length - offset;

                //截取本次发送的数据内容
                NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[dataMessage bytes] + offset
                                                     length:thisChunkSize
                                               freeWhenDone:NO];

                //发送数据
                [peripheral writeValue:chunk
                     forCharacteristic:characteristic
                                  type:CBCharacteristicWriteWithoutResponse];

                //线程延迟
                [NSThread sleepForTimeInterval:(queueSleepTime / 1000)];

                //指针偏移增加
                offset += thisChunkSize;
            } while (offset < length);

            NSLog(@"写数据(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            callback(@[]);
        } else { //单条数据能够发送完
            NSLog(@"写数据(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            [peripheral writeValue:dataMessage
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithoutResponse];
            callback(@[]);
        }
    }
}


/**
 读数据

 @param NSString
 @return
 */
#pragma mark 读数据
RCT_EXPORT_METHOD(read:(NSString *)deviceUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"read");

    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyRead callback:callback];
    if (context) {

        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];

        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];

        @synchronized(self) {
            [self.readCallbacks setObject:callback forKey:key];
        }

        [peripheral readValueForCharacteristic:characteristic];  // callback sends value
    }

}

RCT_EXPORT_METHOD(enableBluetooth:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(getBondedPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(createBond:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(removePeripheral:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(requestMTU:(NSString *)deviceUUID mtu:(NSInteger)mtu callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}


/**
 读RSSI

 @param NSString
 @return
 */
#pragma mark 读RSSI
RCT_EXPORT_METHOD(readRSSI:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"readRSSI");

    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUID];

    if (peripheral && peripheral.state == CBPeripheralStateConnected) {
        @synchronized(self) {
            [self.readRSSICallbacks setObject:callback forKey:[peripheral uuidAsString]];
        }
        [peripheral readRSSI];
    } else {
        callback(@[@"Peripheral not found or not connected"]);
    }

}

/**
 检索服务（同时检索特征）

 @param NSString
 @return
 */
#pragma mark 检索服务（同时检索特征）
RCT_EXPORT_METHOD(retrieveServices:(NSString *)deviceUUID
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"retrieveServices");

    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUID];

    if (peripheral && peripheral.state == CBPeripheralStateConnected) {
        @synchronized(self) {
            [self.retrieveServicesCallbacks setObject:callback forKey:[peripheral uuidAsString]];
        }
        [peripheral discoverServices:nil];
    } else {
        callback(@[@"Peripheral not found or not connected"]);
    }

}


/**
 开启notify

 @param NSString
 @return
 */
#pragma 开启notify
RCT_EXPORT_METHOD(startNotification:(NSString *)deviceUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"startNotification");

    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];

    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];

        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        @synchronized(self) {
            [_notificationCallbacks setObject: callback forKey: key];
        }

        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }

}


/**
 关闭notify

 @param NSString
 @return
 */
#pragma mark 关闭notify
RCT_EXPORT_METHOD(stopNotification:(NSString *)deviceUUID
                  serviceUUID:(NSString*)serviceUUID
                  characteristicUUID:(NSString*)characteristicUUID
                  callback:(nonnull RCTResponseSenderBlock)callback) {
    NSLog(@"stopNotification");

    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];

    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];

        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];

        if ([characteristic isNotifying]) {
            NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
            @synchronized(self) {
                [self.stopNotificationCallbacks setObject: callback forKey: key];
            }

            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            NSLog(@"Characteristic stopped notifying");
        } else {
            NSLog(@"Characteristic is not notifying");
            callback(@[]);
        }

    }

}



#pragma mark -
#pragma mark - CBCentralManager Delegate -
/**
 发现设备

 @param central
 @param peripheral
 @param advertisementData
 @param RSSI
 */
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    @synchronized(self) {
        [self.peripherals addObject:peripheral];
        [peripheral setAdvertisementData:advertisementData RSSI:RSSI];

        //NSLog(@"Discover peripheral: %@", [peripheral name]);
        if (_hasListeners) {
            [self sendEventWithName:@"BleManagerDiscoverPeripheral" body:[peripheral asDictionary]];
        }
    }
}

/**
 连接失败

 @param central
 @param peripheral
 @param error
 */
- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    NSLog(@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]);

    @synchronized(self) {
        NSString *errorStr = [NSString stringWithFormat:@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]];
        NSLog(@"%@", errorStr);
        RCTResponseSenderBlock connectCallback = [self.connectCallbacks valueForKey:[peripheral uuidAsString]];

        if (connectCallback) {
            connectCallback(@[errorStr]);
            [self.connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
        }
    }
}

/**
 收到数据

 @param peripheral
 @param characteristic
 @param error
 */
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    @synchronized(self) {
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        RCTResponseSenderBlock readCallback = [self.readCallbacks objectForKey:key];

        if (error) {
            NSLog(@"Error %@ :%@", characteristic.UUID, error);
            if (readCallback != NULL) {
                readCallback(@[error, [NSNull null]]);
                [self.readCallbacks removeObjectForKey:key];
            }
            return;
        }
        NSLog(@"Read value [%@]: (%lu) %@", characteristic.UUID, [characteristic.value length], characteristic.value);

        if (readCallback != NULL) {
            readCallback(@[[NSNull null], ([characteristic.value length] > 0) ? [characteristic.value toArray] : [NSNull null]]);

            [self.readCallbacks removeObjectForKey:key];
        } else {
            if (_hasListeners) {
                [self sendEventWithName:@"BleManagerDidUpdateValueForCharacteristic"
                                   body:@{
                                          @"peripheral": peripheral.uuidAsString,
                                          @"characteristic":characteristic.UUID.UUIDString,
                                          @"service":characteristic.service.UUID.UUIDString,
                                          @"value": ([characteristic.value length] > 0) ? [characteristic.value toArray] : [NSNull null]
                                          }];
            }
        }
    }
}


/**
 已连接

 @param central
 @param peripheral
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    @synchronized(self) {
        NSLog(@"Peripheral Connected: %@", [peripheral uuidAsString]);
        peripheral.delegate = self;

        // The state of the peripheral isn't necessarily updated until a small delay after didConnectPeripheral is called
        // and in the meantime didFailToConnectPeripheral may be called
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.002 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^(void){
                           // didFailToConnectPeripheral should have been called already if not connected by now

                           RCTResponseSenderBlock connectCallback = [self.connectCallbacks valueForKey:[peripheral uuidAsString]];

                           if (connectCallback) {
                               connectCallback(@[[NSNull null], [peripheral asDictionary]]);
                               [self.connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
                           }

                           if (self.hasListeners) {
                               [self sendEventWithName:@"BleManagerConnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
                           }
                       });

    }
}


/**
 已断开

 @param central
 @param peripheral
 @param error
 */
- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    @synchronized(self) {
        NSLog(@"Peripheral Disconnected: %@", [peripheral uuidAsString]);
        if (error) {
            NSLog(@"Error: %@", error);
        }


        NSString *peripheralUUIDString = [peripheral uuidAsString];
        NSString *errorStr = [NSString stringWithFormat:@"Peripheral did disconnect: %@", peripheralUUIDString];

        RCTResponseSenderBlock connectCallback = [self.connectCallbacks valueForKey:peripheralUUIDString];
        if (connectCallback) {
            connectCallback(@[errorStr]);
            [self.connectCallbacks removeObjectForKey:peripheralUUIDString];
        }

        RCTResponseSenderBlock readRSSICallback = [self.readRSSICallbacks valueForKey:peripheralUUIDString];
        if (readRSSICallback) {
            readRSSICallback(@[errorStr]);
            [self.readRSSICallbacks removeObjectForKey:peripheralUUIDString];
        }

        RCTResponseSenderBlock retrieveServicesCallback = [self.retrieveServicesCallbacks valueForKey:peripheralUUIDString];
        if (retrieveServicesCallback) {
            retrieveServicesCallback(@[errorStr]);
            [self.retrieveServicesCallbacks removeObjectForKey:peripheralUUIDString];
        }

        for (id key in self.readCallbacks) {
            if ([key hasPrefix:peripheralUUIDString]) {
                RCTResponseSenderBlock callback = [self.readCallbacks objectForKey:key];
                callback(@[errorStr]);
                [self.readCallbacks removeObjectForKey:peripheralUUIDString];
            }
        }

        for (id key in self.writeCallbacks) {
            if ([key hasPrefix:peripheralUUIDString]) {
                RCTResponseSenderBlock callback = [self.writeCallbacks objectForKey:key];
                callback(@[errorStr]);
                [self.writeCallbacks removeObjectForKey:peripheralUUIDString];
            }
        }

        for (id key in self.notificationCallbacks) {
            if ([key hasPrefix:peripheralUUIDString]) {
                RCTResponseSenderBlock callback = [self.notificationCallbacks objectForKey:key];
                callback(@[errorStr]);
                [self.notificationCallbacks removeObjectForKey:peripheralUUIDString];
            }
        }

        for (id key in self.stopNotificationCallbacks) {
            if ([key hasPrefix:peripheralUUIDString]) {
                RCTResponseSenderBlock callback = [self.stopNotificationCallbacks objectForKey:key];
                callback(@[errorStr]);
                [self.stopNotificationCallbacks removeObjectForKey:peripheralUUIDString];
            }
        }

        if (_hasListeners) {
            [self sendEventWithName:@"BleManagerDisconnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
        }
    }
}


/**
 CBCentralManager 将要恢复状态

 @param central
 @param dict
 */
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict {
    NSLog(@"centralManager willRestoreState");
}


/**
 CBCentralManager 状态更新

 @param central
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    @synchronized(self) {
        NSString *stateName = [self centralManagerStateToString:central.state];
        if (_hasListeners) {
            [self sendEventWithName:@"BleManagerDidUpdateState" body:@{@"state":stateName}];
        }
    }
}



#pragma mark -
#pragma mark - CBPeripheral Delegate -
/**
 收到广播消息

 @param peripheral
 @param characteristic
 @param error
 */
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {

    @synchronized(self) {
        if (error) {
            NSLog(@"Error in didUpdateNotificationStateForCharacteristic: %@", error);
            return;
        }

        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];

        if (characteristic.isNotifying) {
            NSLog(@"Notification began on %@", characteristic.UUID);
            RCTResponseSenderBlock notificationCallback = [_notificationCallbacks objectForKey:key];
            notificationCallback(@[]);
            [_notificationCallbacks removeObjectForKey:key];
        } else {
            // Notification has stopped
            NSLog(@"Notification ended on %@", characteristic.UUID);
            RCTResponseSenderBlock stopNotificationCallback = [self.stopNotificationCallbacks objectForKey:key];
            stopNotificationCallback(@[]);

            [self.stopNotificationCallbacks removeObjectForKey:key];
        }
    }
}


/**
 已发送数据

 @param peripheral
 @param characteristic
 @param error
 */
- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    @synchronized(self) {
        NSLog(@"已发送数据");

        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        RCTResponseSenderBlock writeCallback = [self.writeCallbacks objectForKey:key];

        if (writeCallback) {
            if (error) {
                NSLog(@"%@", error);
                [self.writeCallbacks removeObjectForKey:key];
                writeCallback(@[error.localizedDescription]);
            } else {
                if ([self.writeQueue count] == 0) {
                    [self.writeCallbacks removeObjectForKey:key];
                    writeCallback(@[]);
                } else {
                    // Remove and write the queud message
                    NSData *message = [self.writeQueue objectAtIndex:0];
                    [self.writeQueue removeObjectAtIndex:0];
                    [peripheral writeValue:message forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                }

            }
        }
    }

}

/**
 读取到RSSI

 @param peripheral
 @param rssi
 @param error
 */
- (void)peripheral:(CBPeripheral*)peripheral didReadRSSI:(NSNumber*)rssi error:(NSError*)error {

    @synchronized(self) {
        NSLog(@"读到RSSI %@", rssi);
        NSString *key = [peripheral uuidAsString];
        RCTResponseSenderBlock readRSSICallback = [self.readRSSICallbacks objectForKey: key];
        if (readRSSICallback) {
            readRSSICallback(@[[NSNull null], [NSNumber numberWithInteger:[rssi integerValue]]]);
            [self.readRSSICallbacks removeObjectForKey:key];
        }
    }
}

/**
 发现服务

 @param peripheral
 @param error
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error {
    @synchronized(self) {
        if (error) {
            NSLog(@"发现服务失败: %@", error);
            return;
        }
        NSLog(@"发现服务成功");

        NSMutableSet *servicesForPeriperal = [NSMutableSet new];
        [servicesForPeriperal addObjectsFromArray:peripheral.services];

        @synchronized(self) {
            [self.retrieveServicesLatches setObject:servicesForPeriperal forKey:[peripheral uuidAsString]];
        }
        for (CBService *service in peripheral.services) {
            NSLog(@"服务 UUID：%@  Description：%@", service.UUID, service.description);
            [peripheral discoverCharacteristics:nil forService:service]; // discover all is slow
        }
    }
}

/**
 发现某个服务中的特征

 @param peripheral
 @param service
 @param error
 */
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
    @synchronized(self) {
        if (error) {
            NSLog(@"发现服务的特征错误: %@", error);
            return;
        }
        NSLog(@"发现服务的特征");

        NSString *peripheralUUIDString = [peripheral uuidAsString];

        //减少一个待获取的服务的特征
        NSMutableSet *latch = [self.retrieveServicesLatches valueForKey:peripheralUUIDString];
        [latch removeObject:service];

        if ([latch count] == 0) { //所以需要获取的服务都找到了
            // Call success callback for connect
            RCTResponseSenderBlock retrieveServiceCallback = [self.retrieveServicesCallbacks valueForKey:peripheralUUIDString];
            if (retrieveServiceCallback) {
                retrieveServiceCallback(@[[NSNull null], [peripheral asDictionary]]);
                [self.retrieveServicesCallbacks removeObjectForKey:peripheralUUIDString];
            }
            [self.retrieveServicesCallbacks removeObjectForKey:peripheralUUIDString];
        }
    }
}


#pragma mark -
#pragma mark - 其他回调 -
/**
 扫描定时时间到

 @param timer
 */
- (void)stopScanTimer:(NSTimer *)timer {
    NSLog(@"停止扫描");
    self.scanTimer = nil;
    [_manager stopScan];

    if (_hasListeners) {
        [self sendEventWithName:@"BleManagerStopScan" body:@{}];
    }
}

/**
 发现一个指定服务中的指定UUID的特征，携带一个特定的属性

 @param UUID
 @param service
 @param prop
 @return
 */
- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID
                                         service:(CBService*)service
                                            prop:(CBCharacteristicProperties)prop {
    @synchronized(self) {
        NSLog(@"Looking for %@ with properties %lu", UUID, (unsigned long)prop);
        for(int i=0; i < service.characteristics.count; i++)
        {
            CBCharacteristic *c = [service.characteristics objectAtIndex:i];
            if ((c.properties & prop) != 0x0 && [c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
                NSLog(@"Found %@", UUID);
                return c;
            }
        }
        return nil; //Characteristic with prop not found on this service
    }
}

/**
 发现一个指定服务中的指定UUID特征

 @param UUID
 @param service
 @return
 */
- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    @synchronized(self) {
        NSLog(@"Looking for %@", UUID);
        for(int i=0; i < service.characteristics.count; i++)
        {
            CBCharacteristic *c = [service.characteristics objectAtIndex:i];
            if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
                NSLog(@"Found %@", UUID);
                return c;
            }
        }
        return nil; //Characteristic not found on this service
    }
}

/**
 整理出 将要发送数据的目的上下文

 @param deviceUUIDString
 @param serviceUUIDString
 @param characteristicUUIDString
 @param prop
 @param callback
 @return
 */
- (BLECommandContext *)getData:(NSString *)deviceUUIDString
             serviceUUIDString:(NSString *)serviceUUIDString
      characteristicUUIDString:(NSString *)characteristicUUIDString
                          prop:(CBCharacteristicProperties)prop
                      callback:(nonnull RCTResponseSenderBlock)callback {
    @synchronized(self) {
        CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
        CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];

        CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];

        if (!peripheral) {
            NSString* err = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
            NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);
            callback(@[err]);

            return nil;
        }

        CBService *service = [self findServiceFromUUID:serviceUUID p:peripheral];

        if (!service)
        {
            NSString* err = [NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@",
                             serviceUUIDString,
                             peripheral.identifier.UUIDString];
            NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
                  serviceUUIDString,
                  peripheral.identifier.UUIDString);
            callback(@[err]);
            return nil;
        }

        CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:prop];

        // Special handling for INDICATE. If charateristic with notify is not found, check for indicate.
        if (prop == CBCharacteristicPropertyNotify && !characteristic) {
            characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:CBCharacteristicPropertyIndicate];
        }

        // As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
        if (!characteristic) {
            characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
        }

        if (!characteristic)
        {
            NSString* err = [NSString stringWithFormat:@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", characteristicUUIDString,serviceUUIDString, peripheral.identifier.UUIDString];
            NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
                  characteristicUUIDString,
                  serviceUUIDString,
                  peripheral.identifier.UUIDString);
            callback(@[err]);
            return nil;
        }

        BLECommandContext *context = [[BLECommandContext alloc] init];
        [context setPeripheral:peripheral];
        [context setService:service];
        [context setCharacteristic:characteristic];
        return context;
    }
}


@end
