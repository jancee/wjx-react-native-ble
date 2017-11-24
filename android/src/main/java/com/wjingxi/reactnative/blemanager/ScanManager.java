package com.wjingxi.reactnative.blemanager;

/**
 * 扫描管理抽象
 */

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.content.Context;

import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;

import java.util.concurrent.atomic.AtomicInteger;

public abstract class ScanManager {

    protected BluetoothAdapter bluetoothAdapter;
    protected Context context;
    protected ReactContext reactContext;
    protected BleManager bleManager;

    //扫描的Session Id
    protected AtomicInteger scanSessionId = new AtomicInteger();

    public ScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
        context = reactContext;
        this.reactContext = reactContext;
        this.bleManager = bleManager;
    }

    protected BluetoothAdapter getBluetoothAdapter() {
        if (bluetoothAdapter == null) { //如果没有bluetoothAdapter，则新建
            BluetoothManager manager = (BluetoothManager)context.getSystemService(Context.BLUETOOTH_SERVICE);
            bluetoothAdapter = manager.getAdapter();
        }
        
        return bluetoothAdapter;
    }

    public abstract void stopScan(Callback callback);

    public abstract void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options, Callback callback);
}
