DEBUG = 0

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

ARCHS = armv7 armv7s arm64
TARGET = iphone:latest:8.0

include /opt/theos/makefiles/common.mk

TWEAK_NAME = ReChat
ReChat_FILES = Tweak.xm

include /opt/theos/makefiles/tweak.mk

after-install::
	install.exec "killall -9 WeChat"

