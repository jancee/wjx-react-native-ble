package com.wjingxi.reactnative.blemanager;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.support.annotation.Nullable;
import android.util.Log;

import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;

import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;

import static android.app.Activity.RESULT_OK;
import static android.os.Build.VERSION_CODES.LOLLIPOP;


/**
 * 蓝牙管理
 */
class BleManager extends ReactContextBaseJavaModule implements ActivityEventListener {

    public static final String LOG_TAG = "BleManager";
    private static final int ENABLE_REQUEST = 539;

    //RN上下文
    private Context context;
    private ReactApplicationContext reactContext;

    //蓝牙句柄
    private BluetoothAdapter bluetoothAdapter;

    //开启蓝牙回调
    private Callback enableBluetoothCallback;

    //扫描器
    private ScanManager scanManager;

    //所有扫描到的设备
    //Mac => Peripheral
    Map<String, Peripheral> peripherals = new LinkedHashMap<>();


    BleManager(ReactApplicationContext reactContext) {
        super(reactContext);

        this.context = reactContext;
        this.reactContext = reactContext;

        reactContext.addActivityEventListener(this);

        Log.d(LOG_TAG, "BleManager组件已创建");
    }


    @Override
    public String getName() {
        return "BleManager";
    }

    // 获得BluetoothAdapter
    private BluetoothAdapter getBluetoothAdapter() {
        if (bluetoothAdapter == null) {
            BluetoothManager manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
            bluetoothAdapter = manager.getAdapter();
        }
        return bluetoothAdapter;
    }

    void sendEvent(String eventName, @Nullable WritableMap params) {
        getReactApplicationContext()
                .getJSModule(RCTNativeAppEventEmitter.class)
                .emit(eventName, params);
    }

    /**
     * 蓝牙状态改变 监听接收
     */
    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d(LOG_TAG, "蓝牙监听接收");

            final String action = intent.getAction();
            if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) { //蓝牙状态改变
                String stringState = "";

                final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
                switch (state) {
                    case BluetoothAdapter.STATE_OFF:
                        stringState = "off";
                        break;
                    case BluetoothAdapter.STATE_TURNING_OFF:
                        stringState = "turning_off";
                        break;
                    case BluetoothAdapter.STATE_ON:
                        stringState = "on";
                        break;
                    case BluetoothAdapter.STATE_TURNING_ON:
                        stringState = "turning_on";
                        break;
                }

                //发送事件
                WritableMap map = Arguments.createMap();
                map.putString("state", stringState);
                sendEvent("BleManagerDidUpdateState", map);

                Log.d(LOG_TAG, "state: " + stringState);
            }

        }
    };

    /**
     * 重置蓝牙
     * 对于Android来说，目前没用
     *
     * @param callback Callback
     */
    @ReactMethod
    public void reinit(Callback callback) {
        Log.d(LOG_TAG, "重新初始化，但是对于Android来说，什么都不需要做");
    }

    /**
     * 开启蓝牙
     *
     * @param options  ReadableMap
     * @param callback Callback
     */
    @ReactMethod
    public void start(ReadableMap options, Callback callback) {
        Log.d(LOG_TAG, "start");

        //注册监听 蓝牙状态改变
        IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        context.registerReceiver(mReceiver, filter);

        //没有获得BluetoothAdapter，不支持蓝牙
        if (getBluetoothAdapter() == null) {
            Log.d(LOG_TAG, "No bluetooth support");
            callback.invoke("No bluetooth support");
            return;
        }

        //按照配置，是否强制低版本的蓝牙SDK
        boolean forceLegacy = false;
        if (options.hasKey("forceLegacy")) {
            forceLegacy = options.getBoolean("forceLegacy");
        }
        //新建扫描器，LOLLIPOP以及以上系统版本，和以下系统版本用的包不同
        if (Build.VERSION.SDK_INT >= LOLLIPOP && !forceLegacy) {
            scanManager = new LollipopScanManager(reactContext, this);
        } else {
            scanManager = new LegacyScanManager(reactContext, this);
        }

        //成功回调
        callback.invoke();

        Log.d(LOG_TAG, "BleManager initialized");
    }

    /**
     * 开启蓝牙
     * 仅Android需要
     *
     * @param callback Callback
     */
    @ReactMethod
    public void enableBluetooth(Callback callback) {
        //不支持蓝牙
        if (getBluetoothAdapter() == null) {
            Log.d(LOG_TAG, "No bluetooth support");
            callback.invoke("No bluetooth support");
            return;
        }

        if (!getBluetoothAdapter().isEnabled()) { //蓝牙适配器未开启
            enableBluetoothCallback = callback;

            if (getCurrentActivity() == null) { //获取RN的Activity失败
                callback.invoke("Current activity not available");
            } else { //正常获取RN的Activity
                //提示请求用户开启蓝牙
                Intent intentEnable = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                getCurrentActivity().startActivityForResult(intentEnable, ENABLE_REQUEST);
            }
        } else { //蓝牙适配器已开启
            //回调成功
            callback.invoke();
        }
    }

    /**
     * 扫描蓝牙
     *
     * @param serviceUUIDs    ReadableArray
     * @param scanSeconds     int
     * @param allowDuplicates boolean
     * @param options         ReadableMap
     * @param callback        Callback
     */
    @ReactMethod
    public void scan(ReadableArray serviceUUIDs, final int scanSeconds, boolean allowDuplicates, ReadableMap options, Callback callback) {
        Log.d(LOG_TAG, "开启蓝牙扫描");

        //不支持蓝牙
        if (getBluetoothAdapter() == null) {
            Log.d(LOG_TAG, "No bluetooth support");
            callback.invoke("No bluetooth support");
            return;
        }

        //蓝牙适配器未开启
        if (!getBluetoothAdapter().isEnabled())
            return;

        //没有连接的设备从所有设备中移除？
        synchronized (this) {
            for (Iterator<Map.Entry<String, Peripheral>> iterator = peripherals.entrySet().iterator(); iterator.hasNext(); ) {
                Map.Entry<String, Peripheral> entry = iterator.next();
                if (!entry.getValue().isConnected()) {
                    iterator.remove();
                }
            }
        }
        synchronized (this) {
            if (scanManager != null)
                scanManager.scan(serviceUUIDs, scanSeconds, options, callback);
            else
                callback.invoke("bluetooth not init");
        }
    }

    /**
     * 停止扫描
     *
     * @param callback Callback
     */
    @ReactMethod
    public void stopScan(Callback callback) {
        Log.d(LOG_TAG, "停止蓝牙扫描");

        //不支持蓝牙
        if (getBluetoothAdapter() == null) {
            Log.d(LOG_TAG, "No bluetooth support");
            callback.invoke("No bluetooth support");
            return;
        }

        //蓝牙适配器未开启
        if (!getBluetoothAdapter().isEnabled()) {
            callback.invoke("Bluetooth not enabled");
            return;
        }

        scanManager.stopScan(callback);
    }

    /**
     * 连接设备
     *
     * @param peripheralUUID String
     * @param callback       Callback
     */
    @ReactMethod
    public void connect(String peripheralUUID, Callback callback) {
        Log.d(LOG_TAG, "Connect to: " + peripheralUUID);

        // 检查是否存在该设备的Peripheral
        synchronized (this) {
            Peripheral peripheral = peripherals.get(peripheralUUID);
            if (peripheral == null) { //不存在Peripheral，则生成Peripheral
                //peripheralUUID转换为大写
                if (peripheralUUID != null) {
                    peripheralUUID = peripheralUUID.toUpperCase();
                }

                // 检查设备地址是否有效
                if (BluetoothAdapter.checkBluetoothAddress(peripheralUUID)) {  //有效
                    // 以给定的MAC地址去创建一个 BluetoothDevice 类实例(代表远程蓝牙实例)。
                    // 即使该蓝牙地址不可见，也会产生一个BluetoothDevice 类实例
                    BluetoothDevice device = bluetoothAdapter.getRemoteDevice(peripheralUUID);

                    // 将BluetoothDevice整理成Peripheral，并放到扫描到的设备列表中
                    peripheral = new Peripheral(device, reactContext);
                    peripherals.put(peripheralUUID, peripheral);
                } else { // 无效
                    callback.invoke("Invalid peripheral uuid");
                    return;
                }
            }

            //调用peripheral中的设备连接
            peripheral.connect(callback, getCurrentActivity());
        }
    }

    /**
     * 断开设备连接
     *
     * @param peripheralUUID String
     * @param callback       Callback
     */
    @ReactMethod
    public void disconnect(String peripheralUUID, Callback callback) {
        Log.d(LOG_TAG, "Disconnect from: " + peripheralUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(peripheralUUID);
            if (peripheral != null) {
                peripheral.disconnect();
                callback.invoke();
            } else
                callback.invoke("Peripheral not found");
        }
    }

    /**
     * 开启notify
     *
     * @param deviceUUID         String
     * @param serviceUUID        String
     * @param characteristicUUID String
     * @param callback           Callback
     */
    @ReactMethod
    public void startNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback callback) {
        Log.d(LOG_TAG, "startNotification");

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                peripheral.registerNotify(UUIDHelper.uuidFromString(serviceUUID), UUIDHelper.uuidFromString(characteristicUUID), callback);
            } else
                callback.invoke("Peripheral not found");
        }
    }

    /**
     * 失能notify
     *
     * @param deviceUUID         String
     * @param serviceUUID        String
     * @param characteristicUUID String
     * @param callback           Callback
     */
    @ReactMethod
    public void stopNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback callback) {
        Log.d(LOG_TAG, "stopNotification");

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                peripheral.removeNotify(UUIDHelper.uuidFromString(serviceUUID), UUIDHelper.uuidFromString(characteristicUUID), callback);
            } else
                callback.invoke("Peripheral not found");
        }
    }

    /**
     * 写数据
     *
     * @param deviceUUID         String
     * @param serviceUUID        String
     * @param characteristicUUID String
     * @param message            ReadableArray
     * @param maxByteSize        Integer
     * @param callback           Callback
     */
    @ReactMethod
    public void write(String deviceUUID, String serviceUUID, String characteristicUUID, ReadableArray message, Integer maxByteSize, Callback callback) {
        Log.d(LOG_TAG, "Write to: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                byte[] decoded = new byte[message.size()];
                for (int i = 0; i < message.size(); i++) {
                    decoded[i] = new Integer(message.getInt(i)).byteValue();
                }
                Log.d(LOG_TAG, "Message(" + decoded.length + "): " + bytesToHex(decoded));
                peripheral.write(UUIDHelper.uuidFromString(serviceUUID), UUIDHelper.uuidFromString(characteristicUUID), decoded, maxByteSize, null, callback, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
            } else {
                callback.invoke("Peripheral not found");
            }
        }
    }

    /**
     * 无响应写数据
     *
     * @param deviceUUID         String
     * @param serviceUUID        String
     * @param characteristicUUID String
     * @param message            ReadableArray
     * @param maxByteSize        Integer
     * @param queueSleepTime     Integer
     * @param callback           Callback
     */
    @ReactMethod
    public void writeWithoutResponse(String deviceUUID, String serviceUUID, String characteristicUUID, ReadableArray message, Integer maxByteSize, Integer queueSleepTime, Callback callback) {
        Log.d(LOG_TAG, "Write without response to: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                byte[] decoded = new byte[message.size()];
                for (int i = 0; i < message.size(); i++) {
                    decoded[i] = new Integer(message.getInt(i)).byteValue();
                }
                Log.d(LOG_TAG, "Message(" + decoded.length + "): " + bytesToHex(decoded));
                peripheral.write(UUIDHelper.uuidFromString(serviceUUID), UUIDHelper.uuidFromString(characteristicUUID), decoded, maxByteSize, queueSleepTime, callback, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
            } else {
                callback.invoke("Peripheral not found");
            }
        }
    }

    /**
     * 读数据
     *
     * @param deviceUUID         StringMac
     * @param serviceUUID        String
     * @param characteristicUUID String
     * @param callback           Callback
     */
    @ReactMethod
    public void read(String deviceUUID, String serviceUUID, String characteristicUUID, Callback callback) {
        Log.d(LOG_TAG, "Read from: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                peripheral.read(UUIDHelper.uuidFromString(serviceUUID), UUIDHelper.uuidFromString(characteristicUUID), callback);
            } else
                callback.invoke("Peripheral not found", null);
        }
    }

    /**
     * 搜索服务和特征
     *
     * @param deviceUUID String Mac
     * @param callback   Callback
     */
    @ReactMethod
    public void retrieveServices(String deviceUUID, Callback callback) {
        Log.d(LOG_TAG, "Retrieve services from: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                peripheral.retrieveServices(callback);
            } else
                callback.invoke("Peripheral not found", null);
        }
    }

    /**
     * 读取RSSI
     *
     * @param deviceUUID String Mac
     * @param callback   Callback
     */
    @ReactMethod
    public void readRSSI(String deviceUUID, Callback callback) {
        Log.d(LOG_TAG, "Read RSSI from: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                peripheral.readRSSI(callback);
            } else
                callback.invoke("Peripheral not found", null);
        }
    }

    /**
     * 检查蓝牙状态
     * <p>
     * RN对外方法
     */
    @ReactMethod
    public void checkState() {
        Log.d(LOG_TAG, "checkState");

        synchronized (this) {
            //获取蓝牙适配器状态
            BluetoothAdapter adapter = getBluetoothAdapter();
            String state = "off";
            if (adapter != null) {
                if (adapter.getState() == BluetoothAdapter.STATE_ON) {
                    state = "on";
                } else if (adapter.getState() == BluetoothAdapter.STATE_OFF) {
                    state = "off";
                }
            }

            //发送事件
            WritableMap map = Arguments.createMap();
            map.putString("state", state);
            sendEvent("BleManagerDidUpdateState", map);

            Log.d(LOG_TAG, "state:" + state);
        }
    }

    /**
     * 获取搜索到的设备
     *
     * @param callback Callback
     */
    @ReactMethod
    public void getDiscoveredPeripherals(Callback callback) {
        Log.d(LOG_TAG, "获取搜索到的设备");

        synchronized (this) {
            WritableArray map = Arguments.createArray();
            Map<String, Peripheral> peripheralsCopy = new LinkedHashMap<>(peripherals);
            for (Map.Entry<String, Peripheral> entry : peripheralsCopy.entrySet()) {
                Peripheral peripheral = entry.getValue();
                WritableMap jsonBundle = peripheral.asWritableMap();
                map.pushMap(jsonBundle);
            }
            callback.invoke(null, map);
        }
    }

    /**
     * 获取已连接设备
     *
     * @param serviceUUIDs String Mac
     * @param callback     Callback
     */
    @ReactMethod
    public void getConnectedPeripherals(ReadableArray serviceUUIDs, Callback callback) {
        Log.d(LOG_TAG, "获取已连接的设备");

        synchronized (this) {
            WritableArray map = Arguments.createArray();
            Map<String, Peripheral> peripheralsCopy = new LinkedHashMap<>(peripherals);
            for (Map.Entry<String, Peripheral> entry : peripheralsCopy.entrySet()) {
                Peripheral peripheral = entry.getValue();
                Boolean accept = false;

                if (serviceUUIDs != null && serviceUUIDs.size() > 0) {
                    for (int i = 0; i < serviceUUIDs.size(); i++) {
                        accept = peripheral.hasService(UUIDHelper.uuidFromString(serviceUUIDs.getString(i)));
                    }
                } else {
                    accept = true;
                }

                if (peripheral.isConnected() && accept) {
                    WritableMap jsonBundle = peripheral.asWritableMap();
                    map.pushMap(jsonBundle);
                }
            }
            callback.invoke(null, map);
        }
    }

    /**
     * 从设备列表中移除设备
     *
     * @param deviceUUID String Mac
     * @param callback   Callback
     */
    @ReactMethod
    public void removePeripheral(String deviceUUID, Callback callback) {
        Log.d(LOG_TAG, "Removing from list: " + deviceUUID);

        synchronized (this) {
            Peripheral peripheral = peripherals.get(deviceUUID);
            if (peripheral != null) {
                if (peripheral.isConnected()) {
                    callback.invoke("Peripheral can not be removed while connected");
                } else {
                    peripherals.remove(deviceUUID);
                }
            } else
                callback.invoke("Peripheral not found");
        }
    }

    //字节数组转16进制字符串
    private final static char[] hexArray = "0123456789ABCDEF".toCharArray();

    static String bytesToHex(byte[] bytes) {
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    //字节数组转RN数组
    static WritableArray bytesToWritableArray(byte[] bytes) {
        WritableArray value = Arguments.createArray();
        for (int i = 0; i < bytes.length; i++)
            value.pushInt((bytes[i] & 0xFF));
        return value;
    }

    @Override
    public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
        Log.d(LOG_TAG, "onActivityResult");

        synchronized (this) {
            if (requestCode == ENABLE_REQUEST && enableBluetoothCallback != null) {
                if (resultCode == RESULT_OK) {
                    enableBluetoothCallback.invoke();
                } else {
                    enableBluetoothCallback.invoke("User refused to enable");
                }
                enableBluetoothCallback = null;
            }
        }
    }

    @Override
    public void onNewIntent(Intent intent) {

    }

}
