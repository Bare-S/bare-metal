ASM = nasm
ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/..
FW_DIR = $(ROOT_DIR)/framework
SRC_DIR = $(ROOT_DIR)/src
OUT_DIR = $(ROOT_DIR)/.out

INC_DIRS := $(shell find $(FW_DIR) -type d) $(shell find $(SRC_DIR) -type d 2>/dev/null)
INC_FLAGS := $(foreach dir, $(INC_DIRS), -I$(dir)/)
ASMFLAGS = -f elf64 $(INC_FLAGS)

FW_SOURCES = $(shell find $(FW_DIR) -name '*.asm' -not -path '*/example/*')
APP_SOURCES = $(shell find $(SRC_DIR) -name '*.asm' 2>/dev/null)

FW_OBJECTS = $(FW_SOURCES:$(FW_DIR)/%.asm=$(OUT_DIR)/fw/%.o)
APP_OBJECTS = $(APP_SOURCES:$(SRC_DIR)/%.asm=$(OUT_DIR)/app/%.o)

OBJECTS = $(FW_OBJECTS) $(APP_OBJECTS)

.PHONY: all clean

all: $(OUT_DIR)/server

debug: ASMFLAGS += -DSYSCALL_DEBUG
debug: clean all

$(OUT_DIR)/server: $(OBJECTS)
	ld $(OBJECTS) -o $(OUT_DIR)/server

$(OUT_DIR)/fw/%.o: $(FW_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@

$(OUT_DIR)/app/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@

clean:
	rm -rf $(OUT_DIR)
