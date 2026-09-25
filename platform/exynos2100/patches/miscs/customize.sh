LOG_STEP_IN "- Setting FUSE passthrough"
SET_PROP "vendor" "persist.sys.fuse.passthrough.enable" "true"
LOG_STEP_OUT

LOG_STEP_IN "- Enabling Vulkan"

# Remove ro.hwui.use_vulkan= from vendor/build.prop
VENDOR_BUILD_PROP="$WORK_DIR/vendor/build.prop"
if [ -f "$VENDOR_BUILD_PROP" ]; then
    LOG "- Removing \"ro.hwui.use_vulkan=\" from vendor/build.prop"
    EVAL "sed -i '/^ro\.hwui\.use_vulkan=$/d' \"$VENDOR_BUILD_PROP\""
fi

SET_PROP "vendor" "ro.hwui.use_vulkan" "true"
SET_PROP "vendor" "debug.hwui.use_hint_manager" "true"
SET_PROP "system" "# Enhanced Vulkan" "max speed"
SET_PROP "system" "debug.hwui.skia_atrace_enabled" "false"
SET_PROP "system" "debug.hwui.renderer" "skiavk"
SET_PROP "system" "debug.renderengine.backend" "skiavkthreaded"
SET_PROP "system" "renderthread.skia.reduceopstasksplitting" "true"
LOG_STEP_OUT

LOG "- Disabling encryption"
# Encryption
LINE=$(sed -n "/^\/dev\/block\/by-name\/userdata/=" "$WORK_DIR/vendor/etc/fstab.exynos2100")
sed -i "${LINE}s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" "$WORK_DIR/vendor/etc/fstab.exynos2100"

# ODE
sed -i -e "/ODE/d" -e "/keydata/d" -e "/keyrefuge/d" "$WORK_DIR/vendor/etc/fstab.exynos2100"

LOG_STEP_IN "- Fixing vendor display props"
# DPI
LCD_DENSITY="$(GET_PROP "vendor" "ro.sf.lcd_density")"
if [ "$LCD_DENSITY" ]; then
    SET_PROP "vendor" "ro.sf.init.lcd_density" "$LCD_DENSITY"
else
    ABORT "ro.sf.lcd_density prop not found in vendor"
fi
LOG_STEP_OUT

LOG_STEP_IN "- Removing unsupported Qualcomm location/QCC stack"
GET_SYSTEM_EXT()
{
    if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
        echo "system_ext"
    else
        echo "system/system/system_ext"
    fi
}

_SED_DELETE_IF_EXISTS()
{
    [ -f "$1" ] || return 0
    sed -i "$2" "$1"
}

_FOR_EACH_EXYNOS_INIT()
{
    local SED_EXPR="$1"
    local INIT_RC

    for INIT_RC in \
        "$WORK_DIR/vendor/etc/init/init.exynos2100.rc"; do
        _SED_DELETE_IF_EXISTS "$INIT_RC" "$SED_EXPR"
    done
}

_DISABLE_PERFETTO_TRACED()
{
    local PERFETTO_RC="$WORK_DIR/system/system/etc/init/perfetto.rc"

    [ -f "$PERFETTO_RC" ] || return 0

    LOG "- Disabling Perfetto traced daemon for legacy Exynos kernel"
    sed -i \
        -e 's/^\([[:space:]]*\)setprop persist\.traced\.enable 1$/\1# setprop persist.traced.enable 1/g' \
        -e 's/^\([[:space:]]*\)start traced$/\1# start traced/g' \
        -e 's/^\([[:space:]]*\)start traced_relay$/\1# start traced_relay/g' \
        -e 's/^\([[:space:]]*\)start traced_probes$/\1# start traced_probes/g' \
        -e 's/^\([[:space:]]*\)wait_for_prop sys\.trace\.traced_started 1$/\1# wait_for_prop sys.trace.traced_started 1/g' \
        "$PERFETTO_RC"
    SET_PROP_IF_DIFF "system" "persist.traced.enable" "0"
}

_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/netbpfload.rc" "/reboot_on_failure[[:space:]][[:space:]]*reboot,netbpfload-missing/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/vold.rc" "/reboot_on_failure[[:space:]][[:space:]]*reboot,vold-failed/d"



_SED_DELETE_IF_EXISTS "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/sysconfig/qti_whitelist_system_ext.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/sysconfig/qti_whitelist.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/deviceidle/reviewed_allowlist.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/permissions/platform.xml" "/com\.qualcomm\.location/d"

LOG_STEP_IN "- Removing invalid vendor property sets"
_SED_DELETE_IF_EXISTS "$WORK_DIR/vendor/build.prop" "/^\(net\.dns1\|net\.dns2\|persist\.demo\.hdmirotationlock\|ro\.em\.version\|vendor\.hwc\.exynos\.vsync_mode\|ro\.smps\.enable\|security\.securehw\.available\|security\.securenvm\.available\|ro\.apk_verity\.mode\)=/d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.rmnet\.mux /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.rmnet\.data\.enable /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.wda\.enable /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.df\.agg\.dl_pkt /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.df\.agg\.dl_size /d"
_FOR_EACH_EXYNOS_INIT "/setprop ro\.crypto\.fuse_sdcard /d"
_DISABLE_PERFETTO_TRACED
LOG_STEP_OUT

unset -f GET_SYSTEM_EXT _SED_DELETE_IF_EXISTS _FOR_EACH_EXYNOS_INIT _DISABLE_PERFETTO_TRACED
LOG_STEP_OUT
