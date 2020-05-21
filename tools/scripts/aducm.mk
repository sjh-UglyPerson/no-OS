#------------------------------------------------------------------------------
#                     PLATFORM SPECIFIC INITIALIZATION                               
#------------------------------------------------------------------------------
# Initialize copy_fun and remove_fun
# Initialize CCES_HOME to default, if directory not found show error
#	WINDOWS
ifeq ($(OS), Windows_NT)
copy_fun = powershell Copy-Item $(1) $(2)
remove_fun = powershell Remove-Item -Confirm:\$$false -Force -Recurse -ErrorAction \
	Ignore -Path $(1)
CCES_HOME ?= $(wildcard C:/Analog\ Devices/CrossCore*)
ifeq ($(CCES_HOME),)
$(error $(NEWLINE)$(NEWLINE)CCES_HOME not found at c:/Analog Devices/[CrossCore...]\
		$(NEWLINE)$(NEWLINE)\
Please run command "set CCES_HOME=c:\Analog Devices\[CrossCore...]"$(NEWLINE)\
Ex: set CCES_HOME=c:\Analog Devices\[CrossCore...] Embedded Studio 2.8.0$(NEWLINE)$(NEWLINE))
endif
#	LINUX
else
copy_fun = cp $(1) $(2)
remove_fun = rm -rf $(1)
CCES_HOME ?= $(wildcard /opt/analog/cces/*)
ifeq ($(CCES_HOME),)
$(error $(NEWLINE)$(NEWLINE)CCES_HOME not found at /opt/analog/cces/[version_number]\
		$(NEWLINE)$(NEWLINE)\
		Please run command "export CCES_HOME=[cces_path]"$(NEWLINE)\
		Ex: export CCES_HOME=/opt/analog/cces/2.9.2$(NEWLINE)$(NEWLINE))
endif
endif

#Set PATH variables where used binaries are found
OPENOCD_SCRIPTS = $(CCES_HOME)/ARM/openocd/share/openocd/scripts
OPENOCD_BIN = $(CCES_HOME)/ARM/openocd/bin
CCES_EXE = $(CCES_HOME)/Eclipse
export PATH := $(CCES_EXE):$(OPENOCD_SCRIPTS):$(OPENOCD_BIN):$(PATH)

#------------------------------------------------------------------------------
#                           ENVIRONMENT VARIABLES                              
#------------------------------------------------------------------------------
PLATFORM	= aducm3029
PROJECT_NAME	= $(notdir $(CURDIR))
PROJECT_PATH	= project
NO-OS		= $(realpath ../..)
SCRIPTS_DIR	= $(NO-OS)/tools/scripts
SCRIPTS_PATH	= $(SCRIPTS_DIR)/platform/$(PLATFORM)
BINARY		= $(PROJECT_PATH)/Release/$(PROJECT_NAME)
WORKSPACE	= ..
CREATE_PROJECT_TARGET = $(PROJECT_PATH)/.cproject

PROJECT		= $(NO-OS)/projects/$(PROJECT_NAME)
DRIVERS		= $(NO-OS)/drivers

define NEWLINE


endef

#------------------------------------------------------------------------------
#                           MAKEFILE SOURCES                              
#------------------------------------------------------------------------------
include src.mk


INCLUDE_SRC_PATTERN = -append-switch compiler -I=$(src_folder)
#Include all sourcefile directories
INCLUDES = $(foreach src_folder, $(SRC_FOLDERS),$(INCLUDE_SRC_PATTERN))
#Include all include directories added by each makefile
INCLUDES += $(foreach src_folder, $(INCLUDE_FOLDERS),$(INCLUDE_SRC_PATTERN))
#Include app_directory
INCLUDES +=  $(foreach src_folder, $(PROJECT)/$(APP_SRCS),$(INCLUDE_SRC_PATTERN))

LINK_SRC_PATTERN = -link $(src_folder) $(patsubst $(NO-OS)/%,noos/%,$(src_folder))
#Link all src directories
SOURCES = $(foreach src_folder, $(SRC_FOLDERS),$(LINK_SRC_PATTERN))
#link app src_folder
SOURCES += -link $(PROJECT)/$(APP_SRCS) app_src

#------------------------------------------------------------------------------
#                           RULES                              
#------------------------------------------------------------------------------

# Build project Release Configuration
PHONY := all
all: update
	cces -nosplash -application com.analog.crosscore.headlesstools \
	-data $(WORKSPACE) \
	-project $(PROJECT_PATH) \
	-build Release

# Update project with the source folders form src.mk
PHONY += update
update: $(CREATE_PROJECT_TARGET) 
	cces -nosplash -application com.analog.crosscore.headlesstools \
		-data $(WORKSPACE) \
		-project $(PROJECT_PATH) \
		$(INCLUDES) $(SOURCES)

# Upload binary to target
PHONY += run
run: all
#This way will not work if the rest button is press or if a printf is executed
	-openocd \
	-s $(OPENOCD_SCRIPTS) -f interface/cmsis-dap.cfg \
	-s $(SCRIPTS_PATH) -f aducm3029.cfg \
	-c init \
	-c "program  $(subst \,/,$(BINARY)) verify" \
	-c "arm semihosting enable" \
	-c "reset run" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c exit

#Command when semihosting bug is fixed: https://labrea.ad.analog.com/browse/CCES-22274
#	openocd \
#	-f interface\cmsis-dap.cfg \
#	-s $(SCRIPTS_PATH) -f aducm3029.cfg \
#	-c "program  $(subst \,/,$(BINARY)) verify reset exit"

#Create new project with platform driver and utils source folders linked
$(CREATE_PROJECT_TARGET):
	cces -nosplash -application com.analog.crosscore.headlesstools \
	-command projectcreate \
	-data $(WORKSPACE) \
	-project $(PROJECT_PATH) \
	-project-name $(PROJECT_NAME) \
	-processor ADuCM3029 \
	-type Executable \
	-revision any \
	-language C \
 	-link $(NO-OS)/include noos/include \
 	-link $(NO-OS)/drivers/platform/aducm3029 noos/platform_drivers \
 	-link $(NO-OS)/util noos/util \
 	-append-switch compiler -I=$(NO-OS)/include \
 	-append-switch compiler -I=$(NO-OS)/drivers/platform/aducm3029 \
 	-config Release \
 	-remove-switch linker -specs=rdimon.specs
#Overwrite system.rteconfig file with one that enables all DFP feautres neede by noos
	$(call copy_fun, $(SCRIPTS_PATH)/system.rteconfig, $(PROJECT_PATH))
#Adding pinmux plugin (Did not work to add it in the first command) and update project
	cces -nosplash -application com.analog.crosscore.headlesstools \
 	-command addaddin \
 	-data $(WORKSPACE) \
 	-project $(PROJECT_PATH) \
 	-id com.analog.crosscore.ssldd.pinmux.component \
	-version latest \
	-regensrc
#The default startup_ADuCM3029.c has compiling errors
	$(call copy_fun, $(SCRIPTS_PATH)/startup_ADuCM3029.c, \
			$(PROJECT_PATH)/RTE/Device/ADuCM3029 )
#Remove default files from projectsrc
	$(call remove_fun, $(PROJECT_PATH)/src)

# Remove workspace data and project directory
PHONY += clean_all
clean_all:	
	$(call remove_fun, $(PROJECT_PATH))
	$(call remove_fun, $(WORKSPACE)/.metadata)

# Remove project binaries
PHONY += clean
clean:
	cces -nosplash -application com.analog.crosscore.headlesstools \
 	-data $(WORKSPACE) \
 	-project $(PROJECT_PATH) \
 	-cleanOnly all

# Rebuild porject. SHould we delete project and workspace or just a binary clean?
PHONY += re
#re: clean_all all
re: clean all

.PHONY: $(PHONY)