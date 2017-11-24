package com.wjingxi.reactnative.blemanager;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.util.Log;

import com.facebook.react.bridge.*;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

/**
 * 低版本扫描管理
 */
public class LegacyScanManager extends ScanManager {

    LegacyScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
        super(reactContext, bleManager);
    }

    @Override
    public void stopScan(Callback callback) {
        // 更新scanSessionId，避免扫描超时停止掉下一次的蓝牙扫描
        scanSessionId.incrementAndGet();

        getBluetoothAdapter().stopLeScan(mLeScanCallback);
        callback.invoke();
    }

    private BluetoothAdapter.LeScanCallback mLeScanCallback =
            new BluetoothAdapter.LeScanCallback() {


                @Override
                public void onLeScan(final BluetoothDevice device, final int rssi,
                                     final byte[] scanRecord) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            Log.i(bleManager.LOG_TAG, "扫描到设备，设备名: " + device.getName() + "，Mac: " + device.getAddress());
                            String address = device.getAddress();
                            Peripheral peripheral;

                            if (!bleManager.peripherals.containsKey(address)) {
                                peripheral = new Peripheral(device, rssi, scanRecord, reactContext);
                                bleManager.peripherals.put(device.getAddress(), peripheral);
                            } else {
                                peripheral = bleManager.peripherals.get(address);
                                peripheral.updateRssi(rssi);
                                peripheral.updateData(scanRecord);
                            }

                            WritableMap map = peripheral.asWritableMap();
                            bleManager.sendEvent("BleManagerDiscoverPeripheral", map);
                        }
                    });
                }


            };

    @Override
    public void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options, Callback callback) {
        if (serviceUUIDs.size() > 0) {
            Log.d(bleManager.LOG_TAG, "过滤器不能在早于lollipop的设备生效");
        }

        getBluetoothAdapter().startLeScan(mLeScanCallback);

        if (scanSeconds > 0) {
            Thread thread = new Thread() {
                //计算一个比当前扫描session id + 1 的值
                private int currentScanSession = scanSessionId.incrementAndGet();

                @Override
                public void run() {

                    //延迟指定时间秒
                    try {
                        Thread.sleep(scanSeconds * 1000);
                    } catch (InterruptedException ignored) {
                    }

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            BluetoothAdapter btAdapter = getBluetoothAdapter();

                            // 检查当前扫描没有停止
                            if (scanSessionId.intValue() == currentScanSession) {
                                //检查当前蓝牙是否开启，开启则停止扫描
                                if (btAdapter.getState() == BluetoothAdapter.STATE_ON) {
                                    btAdapter.stopLeScan(mLeScanCallback);
                                }
                                WritableMap map = Arguments.createMap();
                                bleManager.sendEvent("BleManagerStopScan", map);
                            }
                        }
                    });

                }

            };
            thread.start();
        }
        callback.invoke();
    }
}
