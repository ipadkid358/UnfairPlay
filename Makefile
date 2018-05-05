ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = unfairplay
unfairplay_FILES = main.m
unfairplay_CFLAGS = -fobjc-arc
unfairplay_FRAMEWORKS = MobileCoreServices
unfairplay_CODESIGN_FLAGS = -Sent.plist -Icom.ipadkid.appdump

TWEAK_NAME = UnfairPlay
UnfairPlay_FILES = Tweak.m
UnfairPlay_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
