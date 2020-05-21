################################################################################
#									       #
#     Shared variables:							       #
#	- PROJECT							       #
#	- DRIVERS							       #
#	- INCLUDE							       #
#	- PLATFORM_DRIVERS						       #
#	- NO-OS								       #
#									       #
################################################################################

#In aducm projects the name of the source dir should be different from src
#Direcory where app srcs are stored
APP_SRCS = app_src

SRC_FOLDERS +=	$(DRIVERS)/accel/adxl345
#		$(NO-OS)/network 	 \
		$(DRIVERS)/sd-card	 \
		$(NO-OS)/libraries/fatfs

#Include makefiles from each source directory if they exist
DIRECORIES_WITH_MAKEFILES = $(wildcard $(foreach dir,$(SRC_FOLDERS),$(dir)\src.mk))
include $(DIRECORIES_WITH_MAKEFILES)

#For the folders with no makefiles include all *.c and *.h
REMAINING_DIRECORIES = $(filter-out, $(DIRECORIES_WITH_MAKEFILES), $(SRC_FOLDERS))
SRCS += $(foreach dir, $(REMAINING_DIRECORIES), $(wildcard $(dir)/*.c))
INCS += $(foreach dir, $(REMAINING_DIRECORIES), $(wildcard $(dir)/*.h))