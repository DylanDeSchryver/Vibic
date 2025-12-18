#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.vibic.app.player";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "LaunchBackground" asset catalog image resource.
static NSString * const ACImageNameLaunchBackground AC_SWIFT_PRIVATE = @"LaunchBackground";

/// The "LaunchIcon" asset catalog image resource.
static NSString * const ACImageNameLaunchIcon AC_SWIFT_PRIVATE = @"LaunchIcon";

#undef AC_SWIFT_PRIVATE
