
TASK := spmxv
SRCDIRS := . utils
SRCEXT := cpp
SOURCES := $(wildcard $(addsuffix /*.${SRCEXT}, ${SRCDIRS}))
OBJECTS := $(SOURCES:%.${SRCEXT}=%.o)
DEPENDENCIES := $(OBJECTS:%.o=%.d)
EXECUTABLE := ${TASK}.exe
DIRNAME := $(notdir ${CURDIR})

# MAT_DIR needs to be set according to your local file placement
MAT_DIR := input-matrix

CC ?= icx
CXX ?= icpx
COMPILER = ${CXX}
ifeq (${CC}, icx)
	FLAGS_OPENMP = -fiopenmp
else ifeq (${CC}, scorep-icx)
	FLAGS_OPENMP = -fiopenmp
else
	FLAGS_OPENMP = -fopenmp
endif
FLAGS = -g ${FLAGS_OPENMP} -march=native
FLAGS_FAST = -O3
FLAGS_DEBUG = -O0 -Wall -Wextra
INCLUDES = $(addprefix -I, ${SRCDIRS})

GROUP ?= X

MFORMAT ?= csr

N_THREADS ?= 72

# set default build target
build: release

# build for debugging
debug: FLAGS += ${FLAGS_DEBUG}
debug: ${EXECUTABLE}

# build for performance
release: FLAGS += ${FLAGS_FAST}
release: ${EXECUTABLE}

likwid: LIKWID_FLAGS = -DLIKWID_PERFMON
likwid: LDLIBS = -llikwid
likwid: release

${EXECUTABLE}: ${OBJECTS}
	${COMPILER} ${FLAGS} -o $@ $^ ${LIKWID_FLAGS} ${LDLIBS}

%.o: %.${SRCEXT}
	${COMPILER} ${INCLUDES} -MMD -MP ${FLAGS} ${LIKWID_FLAGS} -c -o $@ $<

run-small: REP ?= 100000
run-small: release
	OMP_NUM_THREADS=${N_THREADS} OMP_PROC_BIND=true OMP_PLACES=cores ./${EXECUTABLE} -t ${N_THREADS} -c -f ${MAT_DIR}/mat_dim_59319.txt -r ${REP} -m ${MFORMAT}

run-large: REP ?= 100000
run-large: release
	OMP_NUM_THREADS=${N_THREADS} OMP_PROC_BIND=true OMP_PLACES=cores ./${EXECUTABLE} -t ${N_THREADS} -c -f ${MAT_DIR}/mat_dim_493039.txt -r ${REP} -m ${MFORMAT}

run-verylarge: REP ?= 100000
run-verylarge: release
	OMP_NUM_THREADS=${N_THREADS} OMP_PROC_BIND=true OMP_PLACES=cores ./${EXECUTABLE} -t ${N_THREADS} -c -f ${MAT_DIR}/mat_dim_986078.txt -r ${REP} -m ${MFORMAT}

run-noL3: REP ?= 100000
run-noL3: release
	OMP_NUM_THREADS=${N_THREADS} OMP_PROC_BIND=true OMP_PLACES=cores ./${EXECUTABLE} -t ${N_THREADS} -c -f ${MAT_DIR}/mat_noL3.txt -r ${REP} -m ${MFORMAT}


# prints out the usage of the command line feature
help: build
	./${EXECUTABLE} -h

archive: clean
	find . -maxdepth 1 -type f -exec tar --transform 's|^|${DIRNAME}-group-${GROUP}/|g' -cvzf ${DIRNAME}-group-${GROUP}.tar.gz {} +

.PHONY: clean build debug release run-small run-large archive help
clean:
	${RM} ${EXECUTABLE}
	${RM} ${OBJECTS}
	${RM} ${DEPENDENCIES}

-include ${DEPENDENCIES}
