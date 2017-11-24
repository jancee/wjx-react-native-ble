package com.wjingxi.reactnative.blemanager;


import android.annotation.TargetApi;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Intent;
import android.os.Build;
import android.os.ParcelUuid;
import android.support.annotation.Nullable;
import android.util.Log;

import com.facebook.react.bridge.*;

import java.util.ArrayList;
import java.util.List;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

/**
 * 高版本扫描管理
 */
@TargetApi(Build.VERSION_CODES.LOLLIPOP)
public class LollipopScanManager extends ScanManager {

    private static final String LOG_TAG = "LollipopScanManager";
    private static final int ENABLE_REQUEST = 539;

    private ReadableArray lastSettingsServiceUUIDs;
    private int lastSettingsScanSeconds;
    private ReadableMap lastSettingsOptions;

    LollipopScanManager(ReactApplicationContext reactContext, BleManager bleManager) {
        super(reactContext, bleManager);
    }

    @Override
    public void stopScan(Callback callback) {
        // update scanSessionId to prevent stopping next scan by running timeout thread
        scanSessionId.incrementAndGet();

        getBluetoothAdapter().getBluetoothLeScanner().stopScan(mScanCallback);
        callback.invoke();
    }

    @Override
    public void scan(ReadableArray serviceUUIDs, final int scanSeconds, ReadableMap options, @Nullable Callback callback) {
        this.lastSettingsServiceUUIDs = serviceUUIDs;
        this.lastSettingsScanSeconds = scanSeconds;
        this.lastSettingsOptions = options;

        ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
        List<ScanFilter> filters = new ArrayList<>();

        scanSettingsBuilder.setScanMode(options.getInt("scanMode"));

        //版本大于Marshmallow，设置硬件匹配器
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            scanSettingsBuilder.setNumOfMatches(options.getInt("numberOfMatches"));
            scanSettingsBuilder.setMatchMode(options.getInt("matchMode"));
        }

        //如果指定了扫描过滤的服务UUID，准备筛选数组
        if (serviceUUIDs.size() > 0) {
            for (int i = 0; i < serviceUUIDs.size(); i++) {
                //整理filters
                ScanFilter filter = new ScanFilter.Builder().setServiceUuid(new ParcelUuid(UUIDHelper.uuidFromString(serviceUUIDs.getString(i)))).build();
                filters.add(filter);

                Log.d(bleManager.LOG_TAG, "Filter service: " + serviceUUIDs.getString(i));
            }
        }

        //开始扫描
        getBluetoothAdapter()
                .getBluetoothLeScanner()
                .startScan(filters, scanSettingsBuilder.build(), mScanCallback);

        //如果指定了扫描时间，则定时
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
                                    btAdapter.getBluetoothLeScanner().stopScan(mScanCallback);
                                }

                                //发送事件
                                WritableMap map = Arguments.createMap();
                                bleManager.sendEvent("BleManagerStopScan", map);
                            }
                        }
                    });

                }

            };
            thread.start();
        }

        //完成处理回调
        if (callback != null) {
            callback.invoke();
        }
    }

    private ScanCallback mScanCallback = new ScanCallback() {
        @Override
        public void onScanResult(final int callbackType, final ScanResult result) {

            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    String address = result.getDevice().getAddress();
                    Peripheral peripheral = null;

                    Log.i(bleManager.LOG_TAG, "扫描到设备，设备名: " + result.getDevice().getName() + "，Mac: " + address);

                    if (!bleManager.peripherals.containsKey(address)) { //该设备未记录，添加记录
                        peripheral = new Peripheral(result.getDevice(), result.getRssi(), result.getScanRecord().getBytes(), reactContext);
                        bleManager.peripherals.put(address, peripheral);
                    } else { //该设备已记录，更新记录
                        peripheral = bleManager.peripherals.get(address);
                        peripheral.updateRssi(result.getRssi());
                        peripheral.updateData(result.getScanRecord().getBytes());
                    }

                    //发送事件
                    WritableMap map = peripheral.asWritableMap();
                    bleManager.sendEvent("BleManagerDiscoverPeripheral", map);
                }
            });
        }

        @Override
        public void onBatchScanResults(final List<ScanResult> results) {
        }

        @Override
        public void onScanFailed(final int errorCode) {
            Log.e(LOG_TAG, "开启扫描失败, errorCode: " + errorCode);
            Log.e(LOG_TAG, "将关闭蓝牙重新开启");

//            WritableMap map = Arguments.createMap();
//            bleManager.sendEvent("BleManagerStopScan", map);

            // 一旦发生错误，除了重启蓝牙再没有其它解决办法
            if (getBluetoothAdapter() != null) {
                getBluetoothAdapter().disable();
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        while (true) { //每0.5s检测一次蓝牙是否已经彻底关闭，如果已关闭则打开
                            //延迟0.5s
                            try {
                                Thread.sleep(500);
                            } catch (InterruptedException e) {
                                e.printStackTrace();
                            }

                            Log.e(LOG_TAG, "检查蓝牙是否已经彻底关闭");

                            //要等待蓝牙彻底关闭，然后再打开，才能实现重启效果
                            if (getBluetoothAdapter().getState() == BluetoothAdapter.STATE_OFF) {
                                Log.e(LOG_TAG, "蓝牙已经彻底关闭，重新打开");

                                //开启蓝牙
                                getBluetoothAdapter().enable();

                                //等待蓝牙开启后，开始扫描，打开扫描
                                new Thread(new Runnable() {
                                    @Override
                                    public void run() {
                                        while (true) {
                                            try {
                                                Thread.sleep(500);
                                            } catch (InterruptedException e) {
                                                e.printStackTrace();
                                            }

                                            Log.e(LOG_TAG, "检查蓝牙是否已经重新打开");
                                            if (getBluetoothAdapter().getState() == BluetoothAdapter.STATE_ON) {
                                                Log.e(LOG_TAG, "重新开启蓝牙扫描");
                                                scan(lastSettingsServiceUUIDs, lastSettingsScanSeconds, lastSettingsOptions, null);
                                                break;
                                            }
                                        }
                                    }
                                }).start();

                                break;
                            }
                        }
                    }

                }).start();
            }

        }
    };
}
