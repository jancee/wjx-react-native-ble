[![npm version](https://badge.fury.io/js/wjx-react-native-ble.svg)](https://badge.fury.io/js/wjx-react-native-ble)

## wjx-react-native-ble


## 兼容
- iOS 8+
- Android (API 19+)

## 安装

### Link Libaray 
```
npm install --save wjx-react-native-ble
react-native link
```

### （Android）再进行以下步骤
打开 `android/app/build.gradle`
确保 `minSdkVersion` 最小为18，如果不是，请改为18。

## 例子
参考 [example](https://github.com/innoveit/wjx-react-native-ble/tree/master/example)

## 方法

### start(options)
返回：`Promise` Object.
参数：
- `options` - `JSON`

`options`的可选参数:
- `showAlert` - `Boolean` - [仅iOS] 当蓝牙被关闭时，是否显示弹窗提示
- `restoreIdentifierKey` - `String` - [仅iOS] 指定 CoreBluetooth 指定的Unique key作为状态恢复
- `forceLegacy` - `Boolean` - [仅Android] 强制使用新式API LegacyScanManager

### scan(serviceUUIDs, seconds, allowDuplicates, scanningOptions)
Scan for availables peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for. On Android the filter works only for 5.0 or newer.
- `seconds` - `Integer` - the amount of seconds to scan.
- `allowDuplicates` - `Boolean` - [iOS only] allow duplicates in device scanning
- `scanningOptions` - `JSON` - [Android only] after Android 5.0, user can control specific ble scan behaviors:
  - `numberOfMatches` - `Number` - corresponding to [`setNumOfMatches`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setNumOfMatches(int))
  - `matchMode` - `Number` - corresponding to [`setMatchMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setMatchMode(int))
  - `scanMode` - `Number` - corresponding to [`setScanMode`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder.html#setScanMode(int))


__Examples__
```js
BleManager.scan([], 5, true)
  .then(() => {
    // Success code
    console.log('Scan started');
  });

```

### stopScan()
Stop the scanning.
Returns a `Promise` object.

__Examples__
```js
BleManager.stopScan()
  .then(() => {
    // Success code
    console.log('Scan stopped');
  });

```

### connect(peripheralId)
Attempts to connect to a peripheral. In many case if you can't connect you have to scan for the peripheral before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral to connect.

__Examples__
```js
BleManager.connect('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Connected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### disconnect(peripheralId)
Disconnect from a peripheral.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral to disconnect.

__Examples__
```js
BleManager.disconnect('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Disconnected');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### enableBluetooth() [Android only]
Create the request to the user to activate the bluetooth.
Returns a `Promise` object.

__Examples__
```js
BleManager.enableBluetooth()
  .then(() => {
    // Success code
    console.log('The bluetooh is already enabled or the user confirm');
  })
  .catch((error) => {
    // Failure code
    console.log('The user refuse to enable bluetooth');
  });
```

### checkState()
Force the module to check the state of BLE and trigger a BleManagerDidUpdateState event.

__Examples__
```js
BleManager.checkState();
```

### startNotification(peripheralId, serviceUUID, characteristicUUID)
Start the notification on the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

__Examples__
```js
BleManager.startNotification('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then(() => {
    // Success code
    console.log('Notification started');
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### stopNotification(peripheralId, serviceUUID, characteristicUUID)
Stop the notification on the specified characteristic.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

### read(peripheralId, serviceUUID, characteristicUUID)
Read the current value of the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.

__Examples__
```js
BleManager.read('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((readData) => {
    // Success code
    console.log('Read: ' + readData);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### write(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize)
Write with response to the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `Byte array` - the data to write.
- `maxByteSize` - `Integer` - specify the max byte size before splitting message

__Data preparation__

If your data is not in byte array format you should convert it first. For strings you can use `convert-string` or other npm package in order to achieve that.
Install the package first:
```shell
npm install convert-string
```
Then use it in your application:
```js
// Import/require in the beginning of the file
import { stringToBytes } from 'convert-string';
// Convert data to byte array before write/writeWithoutResponse
const data = stringToBytes(yourStringData);
```
Feel free to use other packages or google how to convert into byte array if your data has other format.

__Examples__
```js
BleManager.write('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', data)
  .then(() => {
    // Success code
    console.log('Write: ' + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### writeWithoutResponse(peripheralId, serviceUUID, characteristicUUID, data, maxByteSize, queueSleepTime)
Write without response to the specified characteristic, you need to call `retrieveServices` method before.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.
- `serviceUUID` - `String` - the UUID of the service.
- `characteristicUUID` - `String` - the UUID of the characteristic.
- `data` - `Byte array` - the data to write.
- `maxByteSize` - `Integer` - (Optional) specify the max byte size
- `queueSleepTime` - `Integer` - (Optional) specify the wait time before each write if the data is greater than maxByteSize

__Data preparation__

If your data is not in byte array format check info for the write function above.

__Example__
```js
BleManager.writeWithoutResponse('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', data)
  .then(() => {
    // Success code
    console.log('Writed: ' + data);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### readRSSI(peripheralId)
Read the current value of the RSSI.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

__Examples__
```js
BleManager.readRSSI('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((rssi) => {
    // Success code
    console.log('Current RSSI: ' + rssi);
  })
  .catch((error) => {
    // Failure code
    console.log(error);
  });
```

### retrieveServices(peripheralId)
Retrieve the peripheral's services and characteristics.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

__Examples__
```js
BleManager.retrieveServices('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
  .then((peripheralInfo) => {
    // Success code
    console.log('Peripheral info:', peripheralInfo);
  });  
```

### getConnectedPeripherals(serviceUUIDs)
Return the connected peripherals.
Returns a `Promise` object.

__Arguments__
- `serviceUUIDs` - `Array of String` - the UUIDs of the services to looking for.

__Examples__
```js
BleManager.getConnectedPeripherals([])
  .then((peripheralsArray) => {
    // Success code
    console.log('Connected peripherals: ' + peripheralsArray.length);
  });

```

### getDiscoveredPeripherals()
Return the discovered peripherals after a scan.
Returns a `Promise` object.

__Examples__
```js
BleManager.getDiscoveredPeripherals([])
  .then((peripheralsArray) => {
    // Success code
    console.log('Discovered peripherals: ' + peripheralsArray.length);
  });

```

### removePeripheral(peripheralId)
Removes a disconnected peripheral from the cached list.
It is useful if the device is turned off, because it will be re-discovered upon turning on again.
Returns a `Promise` object.

__Arguments__
- `peripheralId` - `String` - the id/mac address of the peripheral.

### isPeripheralConnected(peripheralId, serviceUUIDs)
Check whether a specific peripheral is connected and return `true` or `false`.
Returns a `Promise` object.

__Examples__
```js
BleManager.isPeripheralConnected('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', [])
  .then((isConnected) => {
    if (isConnected) {
      console.log('Peripheral is connected!');
    } else {
      console.log('Peripheral is NOT connected!');
    }
  });

```

## Events
### BleManagerStopScan
The scanning for peripherals is ended.

__Arguments__
- `none`

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerStopScan',
    () => {
        // Scanning is stopped
    }
);
```

###  BleManagerDidUpdateState
The BLE change state.

__Arguments__
- `state` - `String` - the new BLE state ('on'/'off').

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerDidUpdateState',
    (args) => {
        // The new state: args.state
    }
);
```

###  BleManagerDiscoverPeripheral
The scanning find a new peripheral.

__Arguments__
- `id` - `String` - the id of the peripheral
- `name` - `String` - the name of the peripheral
- `rssi` - ` Number` - the RSSI value
- `advertising` - `JSON` - the advertising payload, according to platforms:
    - [Android] contains the raw `bytes` and  `data` (Base64 encoded string)
    - [iOS] contains a JSON object with different keys according to [Apple's doc](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/advertisement_data_retrieval_keys?language=objc), here are some examples:
      - `kCBAdvDataChannel` - `Number`
      - `kCBAdvDataIsConnectable` - `Number`
      - `kCBAdvDataLocalName` - `String`
      - `kCBAdvDataManufacturerData` - `JSON` - contains the raw `bytes` and  `data` (Base64 encoded string)

__Examples__
```js
bleManagerEmitter.addListener(
    'BleManagerDiscoverPeripheral',
    (args) => {
        // The id: args.id
        // The name: args.name
    }
);
```

###  BleManagerDidUpdateValueForCharacteristic
A characteristic notify a new value.

__Arguments__
- `peripheral` - `String` - the id of the peripheral
- `characteristic` - `String` - the UUID of the characteristic
- `value` - `String` - the read value in Hex format

###  BleManagerConnectPeripheral
A peripheral was connected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral

###  BleManagerDisconnectPeripheral
A peripheral was disconnected.

__Arguments__
- `peripheral` - `String` - the id of the peripheral
