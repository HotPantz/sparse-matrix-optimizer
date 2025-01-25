# Makefile

TASK := spmxv
SRCDIRS := . utils
SRCEXT := cpp
SOURCES := $(wildcard $(addsuffix /*.$(SRCEXT), $(SRCDIRS)))
OBJECTS := $(SOURCES:%.cpp=%.o)
DEPENDENCIES := $(OBJECTS:%.o=%.d)
DIRNAME := $(notdir $(CURDIR))

# Matrices directory
MAT_DIR := input-matrix

# Compilers
GCC_COMPILER := gcc
ICPX_COMPILER := icpx

# GCC Flags
GCC_FLAGS_O3 := -O3 -fno-omit-frame-pointer -march=native -lstdc++ -fopenmp
GCC_FLAGS_Ofast := -Ofast -fno-omit-frame-pointer -march=native -lstdc++ -fopenmp

# ICPX Flags
ICPX_FLAGS_O3 := -O3 -fno-omit-frame-pointer -march=native -lstdc++ -qopenmp
ICPX_FLAGS_Fast := -Ofast -fno-omit-frame-pointer -march=native -lstdc++ -qopenmp

# Common flags
FLAGS_OPENMP := -fopenmp
INCLUDES := $(addprefix -I, $(SRCDIRS))

# Executable names
EXECUTABLE_GCC_O3 := $(TASK)-gcc-O3.exe
EXECUTABLE_GCC_Ofast := $(TASK)-gcc-Ofast.exe
EXECUTABLE_ICPX_O3 := $(TASK)-icpx-O3.exe
EXECUTABLE_ICPX_Fast := $(TASK)-icpx-Ofast.exe

# Thread counts
THREADS := 1 2 3 4 6

.PHONY: all clean build-gcc-O3 build-gcc-Ofast build-icpx-O3 build-icpx-Ofast run all-runs

all: build-gcc-O3 build-gcc-Ofast build-icpx-O3 build-icpx-Ofast

# GCC O3 Build
build-gcc-O3: $(EXECUTABLE_GCC_O3)

$(EXECUTABLE_GCC_O3): $(OBJECTS)
	$(GCC_COMPILER) $(GCC_FLAGS_O3) -o $@ $^ $(INCLUDES)

# GCC Ofast Build
build-gcc-Ofast: $(EXECUTABLE_GCC_Ofast)

$(EXECUTABLE_GCC_Ofast): $(OBJECTS)
	$(GCC_COMPILER) $(GCC_FLAGS_Ofast) -o $@ $^ $(INCLUDES)

# ICPX O3 Build
build-icpx-O3: $(EXECUTABLE_ICPX_O3)

$(EXECUTABLE_ICPX_O3): $(OBJECTS)
	$(ICPX_COMPILER) $(ICPX_FLAGS_O3) -o $@ $^ $(INCLUDES)

# ICPX Fast Build
build-icpx-Ofast: $(EXECUTABLE_ICPX_Fast)

$(EXECUTABLE_ICPX_Fast): $(OBJECTS)
	$(ICPX_COMPILER) $(ICPX_FLAGS_Fast) -o $@ $^ $(INCLUDES)

# Compile source files
%.o: %.cpp
	$(GCC_COMPILER) -c $(GCC_FLAGS_O3) $(INCLUDES) -o $@ $<

# Run targets with specific thread counts
define RUN_TEMPLATE
run-gcc-O3-$(1):
	OMP_PLACES=cores OMP_PROC_BIND=close ./$(EXECUTABLE_GCC_O3) -f $(MAT_DIR)/mat_dim_493039.txt -t $(1) -r 20000

run-gcc-Ofast-$(1):
	OMP_PLACES=cores OMP_PROC_BIND=close ./$(EXECUTABLE_GCC_Ofast) -f $(MAT_DIR)/mat_dim_493039.txt -t $(1) -r 20000

run-icpx-O3-$(1):
	OMP_PLACES=cores OMP_PROC_BIND=close ./$(EXECUTABLE_ICPX_O3) -f $(MAT_DIR)/mat_dim_493039.txt -t $(1) -r 20000

run-icpx-Ofast-$(1):
	OMP_PLACES=cores OMP_PROC_BIND=close ./$(EXECUTABLE_ICPX_Fast) -f $(MAT_DIR)/mat_dim_493039.txt -t $(1) -r 20000
endef

$(foreach thread,$(THREADS),$(eval $(call RUN_TEMPLATE,$(thread))))

# Run all tests
all-runs: $(foreach thread,$(THREADS), \
	run-gcc-O3-$(thread) \
	run-gcc-Ofast-$(thread) \
	run-icpx-O3-$(thread) \
	run-icpx-Ofast-$(thread)))

# Clean build artifacts
clean:
	rm -f $(EXECUTABLE_GCC_O3) $(EXECUTABLE_GCC_Ofast) $(EXECUTABLE_ICPX_O3) $(EXECUTABLE_ICPX_Fast) $(OBJECTS) $(DEPENDENCIES)