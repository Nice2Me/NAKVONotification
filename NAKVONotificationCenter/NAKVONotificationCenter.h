//
//  NAKVONotificationCenter.h
//  NAObserver
//
//  Created by zuopengl on 3/27/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>


enum
{
    // These constants are technically unsafe to use, as Apple could add options
    //	with identical values in the future. I'm hoping the highest possible
    //	bits are high enough for them not to bother with before a point in time
    //	where it won't matter anymore. Only 32 bits are used, as the definition
    //	of NSUInteger is 32 bits on iOS.
    
    // Pass this flag to disable automatic de-registration of observers at
    //	dealloc-time of observer or target. This avoids some swizzling hackery
    //	on the observer and target objects.
    // WARNING: Manual de-registration of observations has the same caveats as
    //	stardard KVO - deallocating the target or observer objects without
    //	removing the observation WILL throw KVO errors to the console and cause
    //	crashes!
    NAKeyValueObservingOptionUnregisterManually		= 0x80000000,
};



/******************************************************************************/
// An object adopting this protocol can be passed as a key path, and every key
//	path returned from the required method will be observed. Strings, arrays,
//	sets, and ordered sets automatically get this support, as does anything else
//	that can be used with for (... in ...)
@protocol NAKVOKeyPathSet <NSObject>
@required
- (id<NSFastEnumeration>)na_keyPathsAsSetOfStrings;
@end




/******************************************************************************/
// An object representing a (potentially) active observation.
@protocol NAKVOObservation <NSObject>
@required
- (BOOL)isValid;	// returns NO if the observation has been unregistered by any means
- (void)remove;
@end




/******************************************************************************/
// An object representing an instance of observation
@interface NAKVONotification : NSObject
@property (nonatomic, strong, readonly) id               observer, object;
@property (nonatomic, assign, readonly) NSKeyValueChange kind;
@property (nonatomic, copy, readonly) NSString          *keyPath;
@property (nonatomic, strong, readonly) id               oldValue;
@property (nonatomic, strong, readonly) id               newValue;
@property (nonatomic, strong, readonly)	NSIndexSet      *indexes;
@property (nonatomic, assign, readonly)	BOOL		     isPrior;
@end



/******************************************************************************/
@interface NSObject (NAKVONotification)

- (id<NAKVOObservation>)na_addObserver:(id)observer
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                              selector:(SEL)selector
                              userInfo:(id)userInfo
                               options:(NSKeyValueObservingOptions)options;

- (id<NAKVOObservation>)na_observeTarget:(id)target
                                 keyPath:(id<NAKVOKeyPathSet>)keyPath
                                selector:(SEL)selector
                                userInfo:(id)userInfo
                                 options:(NSKeyValueObservingOptions)options;

#if NS_BLOCKS_AVAILABLE

- (id<NAKVOObservation>)na_addObservationKeyPath:(id<NAKVOKeyPathSet>)keyPath
                                         options:(NSKeyValueObservingOptions)options
                                           block:(void (^)(NAKVONotification *notification))block;

- (id<NAKVOObservation>)na_addObserver:(id)observer
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                               options:(NSKeyValueObservingOptions)options
                                 block:(void (^)(NAKVONotification *notification))block;

- (id<NAKVOObservation>)na_observeTarget:(id)target
                                 keyPath:(id<NAKVOKeyPathSet>)keyPath
                                 options:(NSKeyValueObservingOptions)options
                                   block:(void (^)(NAKVONotification *notification))block;

#endif

- (void)na_removeAllObservers;
- (void)na_stopObservingAllTargets;

- (void)na_removeObserver:(id)observer keyPath:(id<NAKVOKeyPathSet>)keyPath;
- (void)na_stopObserving:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath;

- (void)na_removeObserver:(id)observer keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector;
- (void)na_stopObserving:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector;

@end




/******************************************************************************/
@interface NAKVONotificationCenter : NSObject

+ (id)defaultCenter;

- (id<NAKVOObservation>)na_addObserver:(id)observer
                                target:(id)target
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                              selector:(SEL)selector
                              userInfo:(id)userInfo
                               options:(NSKeyValueObservingOptions)options;

#if NS_BLOCKS_AVAILABLE

- (id<NAKVOObservation>)na_addObserver:(id)observer
                                target:(id)target
                               keyPath:(id<NAKVOKeyPathSet>)keyPath
                               options:(NSKeyValueObservingOptions)options
                                 block:(void (^)(NAKVONotification *notification))block;

#endif

- (void)na_removeObserver:(id)observer target:(id)target keyPath:(id<NAKVOKeyPathSet>)keyPath selector:(SEL)selector;
- (void)na_removeObservation:(id<NAKVOObservation>)observation;

@end



/******************************************************************************/
@interface NSString (NAKeyPath) <NAKVOKeyPathSet>
@end



/******************************************************************************/
@interface NSArray (NAKeyPath) <NAKVOKeyPathSet>
@end



/******************************************************************************/
@interface NSSet (NAKeyPath) <NAKVOKeyPathSet>
@end



