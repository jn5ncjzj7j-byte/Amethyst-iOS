#import <Foundation/Foundation.h>
#import "PLLogOutputView.h"
#import "SurfaceViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import "mach_excServer.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <libgen.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "external/fishhook/fishhook.h"

mach_port_t excPort;
void *hooked_dlopen_26_ppl(const char *path, int mode);

void (*orig_abort)();
void (*orig_exit)(int code);
void* (*orig_dlopen)(const char* path, int mode);
void* (*orig_dlsym)(void* handle, const char* name);
int (*orig_open)(const char *path, int oflag, ...);

void handle_fatal_exit(int code) {
    if (NSThread.isMainThread) {
        return;
    }

    if (![PLLogOutputView handleExitCode:code]) {
        return;
    }

    if (fatalExitGroup != nil) {
        // Likely other threads are crashing, put them to sleep
        sleep(INT_MAX);
    }
    fatalExitGroup = dispatch_group_create();
    dispatch_group_enter(fatalExitGroup);
    dispatch_group_wait(fatalExitGroup, DISPATCH_TIME_FOREVER);
}

void hooked_abort() {
    NSLog(@"abort() called");
    handle_fatal_exit(SIGABRT);
    orig_abort();
}

void hooked___assert_rtn(const char* func, const char* file, int line, const char* failedexpr)
{
    if (func == NULL) {
        fprintf(stderr, "Assertion failed: (%s), file %s, line %d.\n", failedexpr, file, line);
    } else {
        fprintf(stderr, "Assertion failed: (%s), function %s, file %s, line %d.\n", failedexpr, func, file, line);
    }
    hooked_abort();
}

void hooked_exit(int code) {
    NSLog(@"exit(%d) called", code);
    if (code == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication.sharedApplication performSelector:@selector(suspend)];
        });
        usleep(100*1000);
        orig_exit(0);
        return;
    }
    handle_fatal_exit(code);

    orig_exit(code);
}

// mcopt's macOS libmcmetal won't load on iOS, hand it the one we bundle
static int mcmetalOK(const char *theirs, const char *ours, char *missing, size_t cap) {
    const char *m[2] = {0};
    size_t n[2] = {0};
    const char *paths[2] = {theirs, ours};
    int ok = 1;
    for (int k = 0; k < 2; k++) {
        int fd = open(paths[k], O_RDONLY);
        struct stat st;
        if (fd < 0 || fstat(fd, &st) || st.st_size <= 0) { ok = 0; if (fd >= 0) close(fd); continue; }
        void *p = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
        close(fd);
        if (p == MAP_FAILED) { ok = 0; continue; }
        m[k] = p; n[k] = st.st_size;
    }
    // every _mc_ name in theirs has to be in ours too
    for (size_t i = 1; ok && i + 4 < n[0]; i++) {
        if (m[0][i - 1] || memcmp(m[0] + i, "_mc_", 4)) continue;
        size_t len = strnlen(m[0] + i, n[0] - i);
        if (i + len >= n[0] || len > 250) { i += len; continue; }
        char key[256] = {0};
        memcpy(key + 1, m[0] + i, len);
        if (!memmem(m[1], n[1], key, len + 2)) { strlcpy(missing, m[0] + i, cap); ok = 0; }
        i += len;
    }
    for (int k = 0; k < 2; k++) if (m[k]) munmap((void *)m[k], n[k]);
    return ok;
}

static const char *mcmetalPath(const char *path) {
    if (!path) return NULL;
    const char *base = strrchr(path, '/');
    if (strcmp(base ? base + 1 : path, "libmcmetal.dylib")) return NULL;

    static char ours[PATH_MAX];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @autoreleasepool {
            NSString *p = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libmcmetal.dylib"];
            if (access(p.fileSystemRepresentation, R_OK) == 0) strlcpy(ours, p.fileSystemRepresentation, sizeof(ours));
        }
    });
    if (!ours[0] || !strcmp(path, ours)) return NULL;

    char missing[256] = "";
    if (!mcmetalOK(path, ours, missing, sizeof(missing))) {
        NSLog(@"[Amethyst] mcopt: not using bundled libmcmetal, %s", missing[0] ? missing : "couldn't read it");
        return NULL;
    }
    NSLog(@"[Amethyst] mcopt: using bundled libmcmetal for %s", path);
    return ours;
}

void* hooked_dlopen(const char* path, int mode) {
    const char *mc = mcmetalPath(path);
    if (mc) return orig_dlopen(mc, mode);
    BOOL shouldUseDyldBypass26PPL = NO;
    if (DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED)) {
        shouldUseDyldBypass26PPL = hwRedirectOrig[0] && !DeviceHasJITFlags(JIT_FLAG_HAS_TXM);
    }
    // Only patch Mach-O and use dyld bypass dylib is in the home dir
    // or tmp dir: LiveContainer makes a symlink to its own tmp dir so checking home dir alone would fail
    const char *home = getenv("HOME");
    const char *tmp = getenv("TMPDIR");
    char fullpath[PATH_MAX];
    BOOL shouldUseDyldBypass = path && realpath(path, fullpath) && (strstr(fullpath, home) || strstr(fullpath, tmp));
    shouldUseDyldBypass26PPL &= shouldUseDyldBypass;
    if (shouldUseDyldBypass) {
        PLPatchMachOPlatformForFile(path);
    }
    if (shouldUseDyldBypass26PPL) {
        __attribute__((musttail)) return hooked_dlopen_26_ppl(path, mode);
    } else if (shouldUseDyldBypass) {
        /// Special case for LiveContainer multitask mode where it hooks dlopen to hook mmap, which will break this dyld bypass, so we redirect calls to the original dlopen.
        static void *(*sys_dlopen)(const char *, int);
        if(!sys_dlopen) sys_dlopen = dlsym(RTLD_NEXT, "dlopen");
        __attribute__((musttail)) return sys_dlopen(path, mode);
    } else {
        __attribute__((musttail)) return orig_dlopen(path, mode);
    }
}
// hack dlopen for non-TXM 26.x
void *exception_handler(void *unused) {
    mach_msg_server(mach_exc_server, sizeof(union __RequestUnion__catch_mach_exc_subsystem), excPort, MACH_MSG_OPTION_NONE);
    abort();
}
void *hooked_dlopen_26_ppl(const char *path, int mode) {
    if (!excPort) {
        mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &excPort);
        mach_port_insert_right(mach_task_self(), excPort, excPort, MACH_MSG_TYPE_MAKE_SEND);
        pthread_t thread;
        pthread_create(&thread, NULL, exception_handler, NULL);
    }
    
    // save old thread states
    exception_mask_t mask = EXC_MASK_BREAKPOINT;
    mach_msg_type_number_t masksCnt = 1;
    exception_handler_t handler = excPort;
    exception_behavior_t behavior = EXCEPTION_STATE | MACH_EXCEPTION_CODES;
    thread_state_flavor_t flavor = ARM_THREAD_STATE64;
    arm_debug_state64_t origDebugState;
    mach_port_t thread = mach_thread_self();
    thread_get_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&origDebugState, &(mach_msg_type_number_t){ARM_DEBUG_STATE64_COUNT});
    thread_swap_exception_ports(thread, mask, handler, behavior, flavor, &mask, &masksCnt, &handler, &behavior, &flavor);
    assert(masksCnt == 1);
    
    // hook stuff. this will overwrite LiveContainer private container multitask's hook, we will load __TEXT using JIT inside
    arm_debug_state64_t hookDebugState = {0};
    for(int i = 0; i < 6 && hwRedirectOrig[i]; i++) {
        hookDebugState.__bvr[i] = (uint64_t)hwRedirectOrig[i];
        hookDebugState.__bcr[i] = 0x1e5;
    }
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&hookDebugState, ARM_DEBUG_STATE64_COUNT);
    
    // fixup @loader_path since we cannot use musttail here
    void *result;
    void *callerAddr = __builtin_return_address(0);
    struct dl_info info;
    if (path && !strncmp(path, "@loader_path/", 13) && dladdr(callerAddr, &info)) {
        char resolvedPath[PATH_MAX];
        snprintf(resolvedPath, sizeof(resolvedPath), "%s/%s", dirname((char *)info.dli_fname), path + 13);
        result = orig_dlopen(resolvedPath, mode);
    } else {
        result = orig_dlopen(path, mode);
    }
    
    // restore old thread states
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&origDebugState, ARM_DEBUG_STATE64_COUNT);
    thread_swap_exception_ports(thread, mask, handler, behavior, flavor, &mask, &masksCnt, &handler, &behavior, &flavor);
    
    return result;
}
kern_return_t catch_mach_exception_raise_state( mach_port_t exception_port, exception_type_t exception, const mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, const thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    arm_thread_state64_t *old = (arm_thread_state64_t *)old_state;
    arm_thread_state64_t *new = (arm_thread_state64_t *)new_state;
    uint64_t pc = arm_thread_state64_get_pc(*old);
    
    for(int i = 0; i < 6 && hwRedirectOrig[i]; i++) {
        if(pc == (uint64_t)hwRedirectOrig[i]) {
            *new = *old;
            *new_stateCnt = old_stateCnt;
            arm_thread_state64_set_pc_fptr(*new, hwRedirectTarget[i]);
            return KERN_SUCCESS;
        }
    }
    NSLog(@"[DyldLVBypass] Unknown breakpoint at pc: %p", (void*)pc);
    return KERN_FAILURE;
}
kern_return_t catch_mach_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt) {
    abort();
}
kern_return_t catch_mach_exception_raise_state_identity(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, mach_exception_data_t code, mach_msg_type_number_t codeCnt, int *flavor, thread_state_t old_state, mach_msg_type_number_t old_stateCnt, thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    abort();
}

int hooked_open(const char *path, int oflag, ...) {
    va_list args;
    va_start(args, oflag);
    mode_t mode = va_arg(args, int);
    va_end(args);
    if (path && !strcmp(path, "/etc/resolv.conf")) {
        return orig_open([NSString stringWithFormat:@"%s/resolv.conf", getenv("AME_HOME")].UTF8String, oflag, mode);
    }

    return orig_open(path, oflag, mode);
}



typedef struct VkZInstance_T* VkZInstance;
typedef struct VkZPhysicalDevice_T* VkZPhysicalDevice;
typedef struct VkZDevice_T* VkZDevice;
typedef struct VkZPipelineCache_T* VkZPipelineCache;
typedef struct VkZPipeline_T* VkZPipeline;

typedef struct {
    uint32_t binding;
    uint32_t stride;
    int32_t inputRate;
} VkZVertexInputBindingDescription;

typedef struct {
    uint32_t location;
    uint32_t binding;
    int32_t format;
    uint32_t offset;
} VkZVertexInputAttributeDescription;

typedef struct {
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    uint32_t vertexBindingDescriptionCount;
    const VkZVertexInputBindingDescription *pVertexBindingDescriptions;
    uint32_t vertexAttributeDescriptionCount;
    const VkZVertexInputAttributeDescription *pVertexAttributeDescriptions;
} VkZPipelineVertexInputStateCreateInfo;

typedef struct {
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    uint32_t stageCount;
    const void *pStages;
    const VkZPipelineVertexInputStateCreateInfo *pVertexInputState;
    const void *pInputAssemblyState;
    const void *pTessellationState;
    const void *pViewportState;
    const void *pRasterizationState;
    const void *pMultisampleState;
    const void *pDepthStencilState;
    const void *pColorBlendState;
    const void *pDynamicState;
    void *layout;
    void *renderPass;
    uint32_t subpass;
    VkZPipeline basePipelineHandle;
    int32_t basePipelineIndex;
} VkZGraphicsPipelineCreateInfo;

typedef int32_t (*PFN_ZCreateGraphicsPipelines)(VkZDevice, VkZPipelineCache, uint32_t, const VkZGraphicsPipelineCreateInfo *, const void *, VkZPipeline *);
typedef void *(*PFN_ZGetInstanceProcAddr)(VkZInstance, const char *);
typedef void *(*PFN_ZGetDeviceProcAddr)(VkZDevice, const char *);

static PFN_ZGetInstanceProcAddr g_realZGetInstanceProcAddr;
static PFN_ZGetDeviceProcAddr g_realZGetDeviceProcAddr;
static PFN_ZCreateGraphicsPipelines g_realZCreateGraphicsPipelines;

static int32_t zinkSignedFormat(int32_t format) {
    switch (format) {
        case 9: return 10;
        case 11: return 12;
        case 13: return 14;
        case 42: return 43;
        case 76: return 77;
        case 78: return 79;
        case 80: return 81;
        case 82: return 83;
        case 96: return 97;
        case 98: return 99;
        case 100: return 101;
        case 102: return 103;
        default: return format;
    }
}

static BOOL zinkHasUnsignedAttributes(uint32_t count, const VkZGraphicsPipelineCreateInfo *infos) {
    for (uint32_t i = 0; i < count; i++) {
        const VkZPipelineVertexInputStateCreateInfo *state = infos[i].pVertexInputState;
        if (!state || !state->pVertexAttributeDescriptions) continue;
        for (uint32_t j = 0; j < state->vertexAttributeDescriptionCount; j++) {
            if (zinkSignedFormat(state->pVertexAttributeDescriptions[j].format) != state->pVertexAttributeDescriptions[j].format) return YES;
        }
    }
    return NO;
}

static int32_t amethyst_vkCreateGraphicsPipelines(VkZDevice device, VkZPipelineCache cache, uint32_t count, const VkZGraphicsPipelineCreateInfo *infos, const void *allocator, VkZPipeline *pipelines) {
    if (!g_realZCreateGraphicsPipelines) return -3;
    int32_t result = g_realZCreateGraphicsPipelines(device, cache, count, infos, allocator, pipelines);
    if (result != -3 || !infos || !pipelines || !zinkHasUnsignedAttributes(count, infos)) return result;

    VkZGraphicsPipelineCreateInfo *retryInfos = calloc(count, sizeof(*retryInfos));
    VkZPipelineVertexInputStateCreateInfo *retryStates = calloc(count, sizeof(*retryStates));
    VkZVertexInputAttributeDescription **retryAttributes = calloc(count, sizeof(*retryAttributes));
    if (!retryInfos || !retryStates || !retryAttributes) {
        free(retryInfos);
        free(retryStates);
        free(retryAttributes);
        return result;
    }

    memcpy(retryInfos, infos, sizeof(*retryInfos) * count);
    BOOL allocationFailed = NO;
    for (uint32_t i = 0; i < count; i++) {
        const VkZPipelineVertexInputStateCreateInfo *state = infos[i].pVertexInputState;
        if (!state) continue;
        retryStates[i] = *state;
        if (state->vertexAttributeDescriptionCount && state->pVertexAttributeDescriptions) {
            size_t bytes = sizeof(VkZVertexInputAttributeDescription) * state->vertexAttributeDescriptionCount;
            retryAttributes[i] = malloc(bytes);
            if (!retryAttributes[i]) {
                allocationFailed = YES;
                break;
            }
            memcpy(retryAttributes[i], state->pVertexAttributeDescriptions, bytes);
            for (uint32_t j = 0; j < state->vertexAttributeDescriptionCount; j++) {
                retryAttributes[i][j].format = zinkSignedFormat(retryAttributes[i][j].format);
            }
            retryStates[i].pVertexAttributeDescriptions = retryAttributes[i];
        }
        retryInfos[i].pVertexInputState = &retryStates[i];
    }

    if (!allocationFailed) {
        for (uint32_t i = 0; i < count; i++) pipelines[i] = NULL;
        NSLog(@"[ZinkFormatFix] Retrying failed graphics pipeline with signed integer vertex formats");
        result = g_realZCreateGraphicsPipelines(device, cache, count, retryInfos, allocator, pipelines);
        NSLog(@"[ZinkFormatFix] Signed-format retry result: %d", result);
    }

    for (uint32_t i = 0; i < count; i++) free(retryAttributes[i]);
    free(retryAttributes);
    free(retryStates);
    free(retryInfos);
    return result;
}

static void *amethyst_vkGetInstanceProcAddr(VkZInstance instance, const char *name) {
    if (!g_realZGetInstanceProcAddr) return NULL;
    if (name && strcmp(name, "vkGetDeviceProcAddr") == 0) {
        g_realZGetDeviceProcAddr = (PFN_ZGetDeviceProcAddr)g_realZGetInstanceProcAddr(instance, name);
        return (void *)amethyst_vkGetDeviceProcAddr;
    }
    if (name && strcmp(name, "vkCreateGraphicsPipelines") == 0) {
        g_realZCreateGraphicsPipelines = (PFN_ZCreateGraphicsPipelines)g_realZGetInstanceProcAddr(instance, name);
        return (void *)amethyst_vkCreateGraphicsPipelines;
    }
    return g_realZGetInstanceProcAddr(instance, name);
}

static void *amethyst_vkGetDeviceProcAddr(VkZDevice device, const char *name) {
    if (!g_realZGetDeviceProcAddr) return NULL;
    if (name && strcmp(name, "vkCreateGraphicsPipelines") == 0) {
        g_realZCreateGraphicsPipelines = (PFN_ZCreateGraphicsPipelines)g_realZGetDeviceProcAddr(device, name);
        return (void *)amethyst_vkCreateGraphicsPipelines;
    }
    return g_realZGetDeviceProcAddr(device, name);
}

void *hooked_dlsym(void *handle, const char *name) {
    void *symbol = orig_dlsym ? orig_dlsym(handle, name) : NULL;
    if (!name || !symbol) return symbol;
    if (strcmp(name, "vkGetInstanceProcAddr") == 0) {
        g_realZGetInstanceProcAddr = (PFN_ZGetInstanceProcAddr)symbol;
        return (void *)amethyst_vkGetInstanceProcAddr;
    }
    if (strcmp(name, "vkGetDeviceProcAddr") == 0) {
        g_realZGetDeviceProcAddr = (PFN_ZGetDeviceProcAddr)symbol;
        return (void *)amethyst_vkGetDeviceProcAddr;
    }
    if (strcmp(name, "vkCreateGraphicsPipelines") == 0) {
        g_realZCreateGraphicsPipelines = (PFN_ZCreateGraphicsPipelines)symbol;
        return (void *)amethyst_vkCreateGraphicsPipelines;
    }
    return symbol;
}

void init_hookFunctions() {
    struct rebinding rebindings[] = (struct rebinding[]){
        {"abort", hooked_abort, (void *)&orig_abort},
        {"__assert_rtn", hooked___assert_rtn, NULL},
        {"exit", hooked_exit, (void *)&orig_exit},
        {"dlopen", hooked_dlopen, (void *)&orig_dlopen},
        {"dlsym", hooked_dlsym, (void *)&orig_dlsym},
        {"open", hooked_open, (void *)&orig_open}
    };
    rebind_symbols(rebindings, sizeof(rebindings)/sizeof(struct rebinding));
}
