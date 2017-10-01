DEBUG = 0
ARCHS = armv7 arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = sinfoolicons
sinfoolicons_FRAMEWORKS = UIKit MobileCoreServices
sinfoolicons_FILES = main.m
sinfoolicons_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
