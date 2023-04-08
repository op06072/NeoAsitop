//
//  socpwrbud.h
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/14.
//

#ifndef socpwrbud_h
#define socpwrbud_h

#include <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <CoreFoundation/CoreFoundation.h>
/* header for read sensor */
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>

/*
 * Extern declarations
 */
enum {
    kIOReportIterOk,
    kIOReportIterFailed,
    kIOReportIterSkipped
};

typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;
typedef CFDictionaryRef IOReportSampleRef;

extern IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef desiredChannels, CFMutableDictionaryRef* subbedChannels, uint64_t channel_id, CFTypeRef b);
extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef iorsub, CFMutableDictionaryRef subbedChannels, CFTypeRef a);
extern CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef prev, CFDictionaryRef current, CFTypeRef a);

extern CFMutableDictionaryRef IOReportCopyChannelsInGroup(NSString*, NSString*, uint64_t, uint64_t, uint64_t);

typedef int (^ioreportiterateblock)(IOReportSampleRef ch);
extern void IOReportIterate(CFDictionaryRef samples, ioreportiterateblock);

extern int IOReportStateGetCount(CFDictionaryRef);
extern uint64_t IOReportStateGetResidency(CFDictionaryRef, int);
extern uint64_t IOReportArrayGetValueAtIndex(CFDictionaryRef, int);
extern long IOReportSimpleGetIntegerValue(CFDictionaryRef, int);
extern NSString* IOReportChannelGetChannelName(CFDictionaryRef);
extern NSString* IOReportChannelGetSubGroup(CFDictionaryRef);
extern NSString* IOReportStateGetNameForIndex(CFDictionaryRef, int);

extern void IOReportMergeChannels(CFMutableDictionaryRef, CFMutableDictionaryRef, CFTypeRef);
extern NSString* IOReportChannelGetGroup(CFDictionaryRef);

extern CFMutableDictionaryRef IOReportCopyAllChannels(uint64_t, uint64_t);
extern int IOReportChannelGetFormat(CFDictionaryRef samples);

/* typedef for sensor */
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

#define IOHIDEventFieldBase(type)   (type << 16)
#define kIOHIDEventTypeTemperature  15
#define kIOHIDEventTypePower        25

/* Function for sensor */
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t , int32_t, int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);
NSDictionary*appleSiliconSensors(int page, int usage, int32_t type);

#endif /* socpwrbud_h */
