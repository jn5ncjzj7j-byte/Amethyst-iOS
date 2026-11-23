#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define VK_EXPORT __attribute__((visibility("default")))
#define VK_SUCCESS 0
#define VK_ERROR_INITIALIZATION_FAILED (-3)
#define VK_SUBOPTIMAL_KHR 1000001003

typedef int32_t VkResult;
typedef void (*PFN_voidFunction)(void);
typedef VkResult (*PFN_createInstance)(const void *, const void *, void **);
typedef VkResult (*PFN_enumerateVersion)(uint32_t *);
typedef VkResult (*PFN_enumerateExtensions)(const char *, uint32_t *, void *);
typedef PFN_voidFunction (*PFN_getInstanceProcAddr)(void *, const char *);
typedef PFN_voidFunction (*PFN_getDeviceProcAddr)(void *, const char *);
typedef VkResult (*PFN_queuePresent)(void *, const void *);
typedef void (*PFN_recordRenderedFrame)(void);

static pthread_once_t driverOnce = PTHREAD_ONCE_INIT;
static pthread_once_t frameCallbackOnce = PTHREAD_ONCE_INIT;
static void *driverLib;
static PFN_createInstance realCreateInstance;
static PFN_enumerateVersion realEnumerateVersion;
static PFN_enumerateExtensions realEnumerateExtensions;
static PFN_getInstanceProcAddr realGetInstanceProcAddr;
static PFN_getDeviceProcAddr realGetDeviceProcAddr;
static PFN_queuePresent realQueuePresent;
static PFN_recordRenderedFrame recordRenderedFrame;

static void ensureDriver(void);
static void loadFrameCallback(void);

static void loadFrameCallback(void) {
    recordRenderedFrame = (PFN_recordRenderedFrame)(uintptr_t)dlsym(RTLD_MAIN_ONLY, "amethystRecordRenderedFrame");
}

static VkResult wrappedQueuePresent(void *queue, const void *presentInfo) {
    PFN_queuePresent present = __atomic_load_n(&realQueuePresent, __ATOMIC_ACQUIRE);
    if (!present) return VK_ERROR_INITIALIZATION_FAILED;
    VkResult result = present(queue, presentInfo);
    if (result == VK_SUCCESS || result == VK_SUBOPTIMAL_KHR) {
        pthread_once(&frameCallbackOnce, loadFrameCallback);
        if (recordRenderedFrame) {
            recordRenderedFrame();
        } else {
            static int warned;
            if (!__atomic_exchange_n(&warned, 1, __ATOMIC_RELAXED)) {
                fputs("[AmethystVulkan] Frame counter callback is not exported by the host executable\n", stderr);
            }
        }
    }
    return result;
}

static PFN_voidFunction wrapQueuePresent(PFN_voidFunction fn, const char *name) {
    if (fn && name && !strcmp(name, "vkQueuePresentKHR")) {
        __atomic_store_n(&realQueuePresent, (PFN_queuePresent)(uintptr_t)fn, __ATOMIC_RELEASE);
        return (PFN_voidFunction)wrappedQueuePresent;
    }
    return fn;
}

VK_EXPORT PFN_voidFunction vkGetDeviceProcAddr(void *device, const char *name) {
    ensureDriver();
    if (!realGetDeviceProcAddr) return NULL;
    PFN_voidFunction fn = realGetDeviceProcAddr(device, name);
    return wrapQueuePresent(fn, name);
}

static void *driverSymbol(const char *name) {
    return driverLib ? dlsym(driverLib, name) : NULL;
}

static char loaderAnchor;

static void loadDriver(void) {
    const char *path = getenv("AME_VULKAN_DRIVER");
    char buf[1024];

    if (!path || !*path) {
        Dl_info info;
        if (!dladdr(&loaderAnchor, &info) || !info.dli_fname) return;
        const char *slash = strrchr(info.dli_fname, '/');
        size_t dirLen = slash ? (size_t)(slash - info.dli_fname) + 1 : 0;
        const char *name = "libvulkan.dylib";
        if (dirLen + strlen(name) + 1 > sizeof(buf)) return;
        memcpy(buf, info.dli_fname, dirLen);
        strcpy(buf + dirLen, name);
        path = buf;
    }

    driverLib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!driverLib) return;

    realCreateInstance = (PFN_createInstance)(uintptr_t)driverSymbol("vkCreateInstance");
    realEnumerateVersion = (PFN_enumerateVersion)(uintptr_t)driverSymbol("vkEnumerateInstanceVersion");
    realEnumerateExtensions = (PFN_enumerateExtensions)(uintptr_t)driverSymbol("vkEnumerateInstanceExtensionProperties");
    realGetInstanceProcAddr = (PFN_getInstanceProcAddr)(uintptr_t)driverSymbol("vkGetInstanceProcAddr");
}

static void ensureDriver(void) {
    pthread_once(&driverOnce, loadDriver);
}

VK_EXPORT VkResult vkCreateInstance(const void *createInfo, const void *allocator, void **instance) {
    ensureDriver();
    if (!realCreateInstance) return VK_ERROR_INITIALIZATION_FAILED;
    VkResult result = realCreateInstance(createInfo, allocator, instance);
    if (result == VK_SUCCESS && instance && *instance && realGetInstanceProcAddr) {
        realGetDeviceProcAddr = (PFN_getDeviceProcAddr)(uintptr_t)realGetInstanceProcAddr(*instance, "vkGetDeviceProcAddr");
    }
    return result;
}

VK_EXPORT VkResult vkEnumerateInstanceVersion(uint32_t *apiVersion) {
    ensureDriver();
    if (!realEnumerateVersion) return VK_ERROR_INITIALIZATION_FAILED;
    return realEnumerateVersion(apiVersion);
}

VK_EXPORT VkResult vkEnumerateInstanceExtensionProperties(const char *layerName, uint32_t *count, void *properties) {
    ensureDriver();
    if (!realEnumerateExtensions) return VK_ERROR_INITIALIZATION_FAILED;
    return realEnumerateExtensions(layerName, count, properties);
}

// No layers exist on iOS. Reporting zero is what a loader with no layer manifests does.
VK_EXPORT VkResult vkEnumerateInstanceLayerProperties(uint32_t *count, void *properties) {
    (void)properties;
    if (!count) return VK_ERROR_INITIALIZATION_FAILED;
    *count = 0;
    return VK_SUCCESS;
}

VK_EXPORT VkResult vkEnumerateDeviceLayerProperties(void *physicalDevice, uint32_t *count, void *properties) {
    (void)physicalDevice;
    (void)properties;
    if (!count) return VK_ERROR_INITIALIZATION_FAILED;
    *count = 0;
    return VK_SUCCESS;
}

VK_EXPORT PFN_voidFunction vkGetInstanceProcAddr(void *instance, const char *name) {
    ensureDriver();
    if (!name) return NULL;
    if (!strcmp(name, "vkGetDeviceProcAddr")) {
        if (realGetInstanceProcAddr) {
            realGetDeviceProcAddr = (PFN_getDeviceProcAddr)(uintptr_t)realGetInstanceProcAddr(instance, name);
        }
        return (PFN_voidFunction)vkGetDeviceProcAddr;
    }
    if (!strcmp(name, "vkEnumerateInstanceLayerProperties"))
        return (PFN_voidFunction)vkEnumerateInstanceLayerProperties;
    if (!strcmp(name, "vkEnumerateDeviceLayerProperties"))
        return (PFN_voidFunction)vkEnumerateDeviceLayerProperties;
    if (!realGetInstanceProcAddr) return NULL;
    PFN_voidFunction fn = realGetInstanceProcAddr(instance, name);
    return wrapQueuePresent(fn, name);
}
