package com.wjingxi.reactnative.blemanager;

import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class UUIDHelper {

    //长UUID模板
    public static final String UUID_BASE = "0000XXXX-0000-1000-8000-00805f9b34fb";

    /**
     * 通过 UUID 获取 String
     * @param uuid
     * @return
     */
    public static UUID uuidFromString(String uuid) {

        //获得的UUID是 16 bit 的，则转换为128 bit
        if (uuid.length() == 4) {
            uuid = UUID_BASE.replace("XXXX", uuid);
        }

        return UUID.fromString(uuid);
    }

    // return 16 bit UUIDs where possible

    /**
     * 返回 16 bit UUID
     * @param uuid
     * @return
     */
    public static String uuidToString(UUID uuid) {
        String longUUID = uuid.toString();
        Pattern pattern = Pattern.compile("0000(.{4})-0000-1000-8000-00805f9b34fb", Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(longUUID);
        if (matcher.matches()) {
            // 16 bit UUID
            return matcher.group(1);
        } else {
            return longUUID;
        }
    }
}