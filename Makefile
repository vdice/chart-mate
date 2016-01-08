# makeup-managed:begin
include makeup.mk
# makeup-managed:end

include $(MAKEUP_DIR)/makeup-kit-info/main.mk

build:
	@./build.sh
