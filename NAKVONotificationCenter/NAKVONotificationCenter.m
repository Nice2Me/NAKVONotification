//
//  NAKVONotificationCenter.m
//  NAObserver
//
//  Created by zuopengl on 3/27/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "NAKVONotificationCenter.h"
#import <objc/message.h>
#import <objc/runtime.h>




/******************************************************************************/
static const char * const NAKVONotificationCenter_HelpersKey = "NAKVONotificationCenter_HelpersKey";
static NSMutableSet *NAKVONotificationCenter_swizzledClasses = nil;




/******************************************************************************/
@interface NAKVONotification () {
    NSDictionary *_change;
}
@property (nonatomic, copy, readwrite) NSString *keyPath;
@property (nonatomic, strong, readwrite) id observer, object;
@end

@implementation NAKVONotification

- (instancetype)initWithObserver:(id)observer object:(id)object keyPath:(NSString *)keyPath change:(NSDictionary *)change {
    if ((self = [super init])) {
        _change = change;
        
        self.observer = observer;
        self.object   = object;
        self.keyPath  = keyPath;
    }
    return self;
}

- (NSKeyValueChange)kind {
    return [[_change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue];
}

- (id)oldValue {
    return [_change objectForKey:NSKeyValueChangeOldKey];
}

- (id)newValue {
    return [_change objectForKey:NSKeyValueChangeNewKey];
}

- (NSIndexSet *)indexes {
    return [_change objectForKey:NSKeyValueChangeIndexesKey];
}

- (BOOL)isPrior {
    return [_change objectForKey:NSKeyValueChangeNotificationIsPriorKey];
}
@end




/******************************************************************************/
@interface NAKVONotificationHelper : NSObject
<
NAKVOObservation
> {
@public
    id __unsafe_unretained     _observer;
    id __unsafe_unretained     _target;
    NSSet                     *_keyPaths;
    NSKeyValueObservingOptions _options;
    SEL                        _selector;	// NULL for block-based
    id	                       _userInfo;	// block for block-based
}

- (id)initWithObserver:(id)observer target:(id)target keyPaths:(NSSet *)keyPaths selector:(SEL)selector userInfo:(id)userInfo options:(NSKeyValueObservingOptions)options;

- (void)_removeObserver;
@end

@implementation NAKVONotificationHelper

static char NAKVONotificationHelperMagicContext = 0;

- (id)initWithObserver:(id)observer target:(id)target keyPaths:(NSSet *)keyPaths selector:(SEL)selector userInfo:(id)userInfo options:(NSKeyValueObservingOptions)options {
    if ((self = [super init])) {
        _observer = observer;
        _target   = target;
        _keyPaths = keyPaths;
        _selector = selector;
        _userInfo = userInfo;
        _options  = options;
        
        // Pass only Apple's options to Apple's code.
        options &= ~(NAKeyValueObservingOptionUnregisterManually);
        
        for (NSString *keyPath in keyPaths) {
            if ([_target isKindOfClass:[NSArray class]]) {
                [_target addObserver:self toObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [(NSArray *)_target count])] forKeyPath:keyPath options:_options context:&NAKVONotificationHelperMagicContext];
            } else {
                [_target addObserver:self forKeyPath:keyPath options:_options context:&NAKVONotificationHelperMagicContext];
            }
        }
        
        NSMutableSet *observerHelpers = nil, *targetHelpers = nil;
        if (_observer) {
            @synchronized (_observer) {
                if (!(observerHelpers = objc_getAssociatedObject(_observer, &NAKVONotificationCenter_HelpersKey)))
                    objc_setAssociatedObject(_observer, &NAKVONotificationCenter_HelpersKey, observerHelpers = [NSMutableSet set], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            @synchronized (observerHelpers) {
                [observerHelpers addObject:self];
            }
        }
        
        if (_target) { // _target must be not nil
            @synchronized (_target) {
                if (!(targetHelpers = objc_getAssociatedObject(_target, &NAKVONotificationCenter_HelpersKey)))
                    objc_setAssociatedObject(_target, &NAKVONotificationCenter_HelpersKey, targetHelpers = [NSMutableSet set], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            @synchronized (targetHelpers) {
                [targetHelpers addObject:self];
            }
        }
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (context == &NAKVONotificationHelperMagicContext) {
#if NS_BLOCKS_AVAILABLE
        if (_selector) {
#endif
            ((void (*)(id, SEL, NSString *, id, NSDictionary *, id))objc_msgSend)(_observer, _selector, keyPath, object, change, _userInfo);
#if NS_BLOCKS_AVAILABLE
        } else {
            NAKVONotification *notification = [[NAKVONotification alloc] initWithObserver:_observer object:object keyPath:keyPath change:change];
            ((void (^)(NAKVONotification *))_userInfo)(notification);
        }
#endif
    }  else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)_removeObserver {
    if ([_target isKindOfClass:[NSArray class]]) {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [(NSArray *)_target count])];
        
        for (NSString *keyPath in _keyPaths)
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0 || __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_7
            [_target removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:keyPath context:&NAKVONotificationHelperMagicContext];
#else
        [_target removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:keyPath];
#endif
    } else {
        for (NSString *keyPath in _keyPaths)
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0 || __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_7
            [_target removeObserver:self forKeyPath:keyPath context:&NAKVONotificationHelperMagicContext];
#else
        [_target removeObserver:self forKeyPath:keyPath];
#endif
    }
    
    if (_observer) {
        NSMutableSet *observerHelpers = objc_getAssociatedObject(_observer, &NAKVONotificationCenter_HelpersKey);
        @synchronized (observerHelpers) {
            [observerHelpers removeObject:self];
        }
    }
    
    NSMutableSet *targetHelpers = objc_getAssociatedObject(_target, &NAKVONotificationCenter_HelpersKey);
    @synchronized (targetHelpers) {
        [targetHelpers removeObject:self];
    } // if during dealloc, this will happen momentarily anyway
    
    // Protect against multiple invocations
    _observer = nil;
    _target = nil;
    _keyPaths = nil;
}

#pragma mark - delegate for NAKVOObservation

- (BOOL)isValid {
    return (_target != nil);
}

- (void)remove {
    [self _removeObserver];
}
@end




/******************************************************************************/
@implementation NAKVONotificationCenter

+ (void)initialize {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        NAKVONotificationCenter_swizzledClasses = [NSMutableSet set];
    });
}

+ (id)defaultCenter {
    static dispatch_once_t onceToken = 0;
    static NAKVONotificationCenter *inst = nil;
    dispatch_once(&onceToken, ^{
        inst = [NAKVONotificationCenter new];
    });
    return inst;
}

- (id<NAKVOObservation>)na_addObserver:(id)observer
                                target:(id)target
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                              selector:(SEL)selector
                              userInfo:(id)userInfo
                               options:(NSKeyValueObservingOptions)options {
    
    [self _swizzleObjectClassIfNeeded:observer];
    [self _swizzleObjectClassIfNeeded:target];
    
    NSMutableSet *keyPaths = [NSMutableSet set];
    for (NSString *path in [keyPath na_keyPathsAsSetOfStrings]) {
        [keyPaths addObject:path];
    }
    
    return [[NAKVONotificationHelper alloc] initWithObserver:observer target:target keyPaths:keyPaths selector:selector userInfo:userInfo options:options];
}

- (void)_swizzleObjectClassIfNeeded:(id)object {
    if (!object) {
        return;
    }
    
    @synchronized(NAKVONotificationCenter_swizzledClasses) {
        Class class = [object class];
        if ([NAKVONotificationCenter_swizzledClasses containsObject:class]) {
            return;
        }
        SEL deallocSel = NSSelectorFromString(@"dealloc");
        Method deallocMethod = class_getInstanceMethod(class, deallocSel);
        IMP originalImpl = method_getImplementation(deallocMethod);
        IMP newImpl = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0 || __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_8
        newImpl = imp_implementationWithBlock(^ (void *obj) {
            for (NAKVONotificationHelper *helper in objc_getAssociatedObject((__bridge id)(obj), NAKVONotificationCenter_HelpersKey)) {
                if (!(helper->_options & NAKeyValueObservingOptionUnregisterManually))
                    [helper _removeObserver];
            }
            
            ((void (*)(void *, SEL))originalImpl)(obj, deallocSel);
        });
#else
        newImpl = imp_implementationWithBlock((__bridge void *)^ (void *obj) {
            for (NAKVONotificationHelper *helper in objc_getAssociatedObject((__bridge id)(obj), NAKVONotificationCenter_HelpersKey)) {
                if (!(helper->_options & NAKeyValueObservingOptionUnregisterManually))
                    [helper _removeObserver];
            }
            
            ((void (*)(void *, SEL))originalImpl)(obj, deallocSel);
        });
#endif
        class_replaceMethod(class, deallocSel, newImpl, method_getTypeEncoding(deallocMethod));
        
        [NAKVONotificationCenter_swizzledClasses addObject:class];
    }
}


#if NS_BLOCKS_AVAILABLE

- (id<NAKVOObservation>)na_addObserver:(id)observer
                                target:(id)target
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                               options:(NSKeyValueObservingOptions)options
                                 block:(void (^)(NAKVONotification *notification))block {
    return [self na_addObserver:observer target:target keyPath:keyPath selector:NULL userInfo:block options:options];
}

#endif

// remove all observations registered by observer on target with keypath using
//	selector. nil for any parameter is a wildcard. One of observer or target
//	must be non-nil. The only way to deregister a specific block is to
//	remove its particular MAKVOObservation.
- (void)na_removeObserver:(id)observer target:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector {
    NSParameterAssert(observer || target);
    
    @autoreleasepool {
        NSMutableSet *observerHelpers = objc_getAssociatedObject(observer, &NAKVONotificationCenter_HelpersKey) ? : [NSMutableSet set];
        NSMutableSet *targetHelpers = objc_getAssociatedObject(target, &NAKVONotificationCenter_HelpersKey) ? : [NSMutableSet set];
        NSMutableSet *allHelpers = [NSMutableSet set], *keyPaths = [NSMutableSet set];
        for (NSString *path in [keyPath na_keyPathsAsSetOfStrings]) {
            [keyPaths addObject:path];
        }
        
        @synchronized (observerHelpers) {
            [allHelpers unionSet:observerHelpers];
        }
        @synchronized (targetHelpers) {
            [allHelpers unionSet:targetHelpers];
        }
        
        for (NAKVONotificationHelper *helper in allHelpers) {
            if ((!observer || helper->_observer == observer) &&
                (!target || helper->_target == target) &&
                (!keyPath || [helper->_keyPaths isEqualToSet:keyPaths]) &&
                (!selector || helper->_selector == selector)) {
                [helper _removeObserver];
            }
        }
    }
}

// remove specific registered observation
- (void)na_removeObservation:(id<NAKVOObservation>)observation {
    [observation remove];
}

@end




/******************************************************************************/
@implementation NSObject (NAKVONotification)

- (id<NAKVOObservation>)na_addObserver:(id)observer
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                              selector:(SEL)selector
                              userInfo:(id)userInfo
                               options:(NSKeyValueObservingOptions)options {
    return [[NAKVONotificationCenter defaultCenter] na_addObserver:observer target:self keyPath:keyPath selector:selector userInfo:userInfo options:options];
}

- (id<NAKVOObservation>)na_observeTarget:(id)target
                                 keyPath:(id<NAKVOKeyPathSet>)keyPath
                                selector:(SEL)selector
                                userInfo:(id)userInfo
                                 options:(NSKeyValueObservingOptions)options {
    return [[NAKVONotificationCenter defaultCenter] na_addObserver:self target:target keyPath:keyPath selector:selector userInfo:userInfo options:options];
}

#if NS_BLOCKS_AVAILABLE

- (id<NAKVOObservation>)na_addObservationKeyPath:(id<NAKVOKeyPathSet>)keyPath
                                         options:(NSKeyValueObservingOptions)options
                                           block:(void (^)(NAKVONotification *notification))block {
    return [[NAKVONotificationCenter defaultCenter] na_addObserver:nil target:self keyPath:keyPath options:options block:block];
}

- (id<NAKVOObservation>)na_addObserver:(id)observer
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                               options:(NSKeyValueObservingOptions)options
                                 block:(void (^)(NAKVONotification *notification))block {
    return [[NAKVONotificationCenter defaultCenter] na_addObserver:observer target:self keyPath:keyPath options:options block:block];
}

- (id<NAKVOObservation>)na_observeTarget:(id)target
                                 keyPath:(id<NAKVOKeyPathSet>)keyPath
                                 options:(NSKeyValueObservingOptions)options
                                   block:(void (^)(NAKVONotification *notification))block {
    return [[NAKVONotificationCenter defaultCenter] na_addObserver:self target:target keyPath:keyPath options:options block:block];
}

#endif

/**
 *  remove all observers that target is `self`
 */
- (void)na_removeAllObservers {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:nil target:self keyPath:nil selector:NULL];
}

/**
 *  remove all observers that is observed by `self`
 */
- (void)na_stopObservingAllTargets {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:self target:nil keyPath:nil selector:NULL];
}

/**
 *  remove appointed observers
 *
 *  @param observer observer
 *  @param keyPath  keyPath
 */
- (void)na_removeObserver:(id)observer keyPath:(id<NAKVOKeyPathSet>)keyPath {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:observer target:self keyPath:keyPath selector:NULL];
}

- (void)na_stopObserving:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:self target:target keyPath:keyPath selector:NULL];
}

- (void)na_removeObserver:(id)observer keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:observer target:self keyPath:keyPath selector:selector];
}

- (void)na_stopObserving:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector {
    [[NAKVONotificationCenter defaultCenter] na_removeObserver:self target:target keyPath:keyPath selector:selector];
}

@end


/******************************************************************************/
@implementation NSString (NAKeyPath)
- (id<NSFastEnumeration>)na_keyPathsAsSetOfStrings {
    return [NSSet setWithObject:self];
}
@end

@implementation NSArray (NAKeyPath)
- (id<NSFastEnumeration>)na_keyPathsAsSetOfStrings {
    return self;
}
@end

@implementation NSSet (NAKeyPath)
- (id<NSFastEnumeration>)na_keyPathsAsSetOfStrings {
    return self;
}
@end
