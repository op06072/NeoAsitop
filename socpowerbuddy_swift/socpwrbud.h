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
/*
 * Typedefs
 */

/* raw data form the ioreport */
typedef struct {
    /* data for Energy Model*/
    IOReportSubscriptionRef pwrsub;
    CFMutableDictionaryRef  pwrsubchn;
    CFMutableDictionaryRef  pwrchn_eng;
    CFMutableDictionaryRef  pwrchn_pmp;

    /* datat for CPU/GPU Stats */
    IOReportSubscriptionRef cpusub;
    CFMutableDictionaryRef  cpusubchn;
    CFMutableDictionaryRef  cpuchn_cpu;
    CFMutableDictionaryRef  cpuchn_gpu;
    
    /* data for CLPC Stats*/
    IOReportSubscriptionRef clpcsub;
    CFMutableDictionaryRef  clpcsubchn;
    CFMutableDictionaryRef  clpcchn;
} iorep_data;

typedef struct {
    NSArray* complex_pwr_channels;
    NSArray* core_pwr_channels;
    
    NSArray* complex_freq_channels;
    NSArray* core_freq_channels;
    
    NSMutableArray* dvfm_states_holder;
    NSArray* dvfm_states;
    NSMutableArray* cluster_core_counts;
    int gpu_core_count;
    
    NSMutableArray* extra;
} static_data;

typedef struct {
    /* data for freqs, dvfm, and res */
    NSMutableArray* cluster_sums;
    NSMutableArray* cluster_residencies;
    NSMutableArray* cluster_freqs;
    NSMutableArray* cluster_use;

    NSMutableArray* core_sums;
    NSMutableArray* core_residencies;
    NSMutableArray* core_freqs;
    NSMutableArray* core_use;
    
    /* data for power draw */
    NSMutableArray* cluster_pwrs;
    NSMutableArray* core_pwrs;
    
    /* data for instructions and cycles  */
    NSMutableArray* cluster_instrcts_ret;
    NSMutableArray* cluster_instrcts_clk;
//
//    unsigned long package_instrcts_ret;
//    unsigned long package_instrcts_clk;
} variating_data;

/* for cmd opts */
typedef struct cmd_data {
    float        power_measure;
    float        freq_measure;
    const char*  power_measure_un;
    const char*  freq_measure_un;
    
    unsigned int interval;
    int          samples;
    NSArray*     metrics;
    NSArray*     hide_units;
    
    bool  plist;
    FILE * file_out;
} cmd_data;

/* for units/metrics args */
typedef struct {
    /* units */
    bool ecpu;
    bool pcpu;
    bool gpu;
//    bool ane;
    /* metrics */
    bool res;
    bool idle;
    bool freq;
    bool cores;
    bool dvfm;
    bool dvfm_ms;
    bool power;
    bool intstrcts;
    bool cycles;
} bool_data;

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


/*
 * Function declarations
 */
void error(int, const char*, ...);
void textOutput(iorep_data*, static_data*, variating_data*, bool_data*, cmd_data*, unsigned int);
void plistOutput(iorep_data*, static_data*, variating_data*, bool_data*, cmd_data*, unsigned int);

void sample(iorep_data*, static_data*, variating_data*, cmd_data*);
void format(static_data*, variating_data*);

void generateDvfmTable(static_data*);
void generateCoreCounts(static_data*);
void generateProcessorName(static_data*);
void generateSiliconsIds(static_data*);
void generateMicroArchs(static_data*);

/* Function for sensor */
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t , int32_t, int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#endif /* socpwrbud_h */
