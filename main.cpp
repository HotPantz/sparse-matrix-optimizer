//Code from laboratory liparad :  https://www.liparad.uvsq.fr/

// C header
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <unistd.h>

// utility header
#include "ooo_cmdline.h"

#ifdef LIKWID_PERFMON
#include <likwid-marker.h>
#else
#define LIKWID_MARKER_INIT
#define LIKWID_MARKER_THREADINIT
#define LIKWID_MARKER_SWITCH
#define LIKWID_MARKER_REGISTER(regionTag)
#define LIKWID_MARKER_START(regionTag)
#define LIKWID_MARKER_STOP(regionTag)
#define LIKWID_MARKER_CLOSE
#define LIKWID_MARKER_GET(regionTag, nevents, events, time, count)
#endif

#define CHUNK_SIZE 200 // optimal value depends on number of threads and matrix structure

void spmxv_ellpack(ooo_options *tOptions, ooo_input *tInput)
{
	int iNumRepetitions = tOptions->iNumRepetitions; // set with -r <numrep>

	int maxValsPerRow = -1;
	for(int i = 0; i < tInput->stNumRows; ++i) {
		int rowbeg = tInput->row[i];
		int rowend = tInput->row[i+1];
		if(rowend - rowbeg > maxValsPerRow) maxValsPerRow = rowend - rowbeg;
	}

	/*
	// compute next power of 2
	maxValsPerRow--;
	maxValsPerRow |= maxValsPerRow >> 1;
	maxValsPerRow |= maxValsPerRow >> 2;
	maxValsPerRow |= maxValsPerRow >> 4;
	maxValsPerRow |= maxValsPerRow >> 8;
	maxValsPerRow |= maxValsPerRow >> 16;
	maxValsPerRow++;

	printf("maxValsPerRow: %d\n", maxValsPerRow);
	*/

	// setup data structures
	double *y = (double*) calloc(tInput->stNumRows, sizeof(double)); // result
	double *Aval = (double*) calloc((tInput->stNumRows) * maxValsPerRow, sizeof(double)); // values
    int *Acol = (int*) calloc((tInput->stNumRows) * maxValsPerRow, sizeof(int)); // column indices
    double *x = (double*) malloc(sizeof(double) * (tInput->stNumRows)); // RHS
	
	// allocate helper data
	timespan *timings = (timespan*) malloc(sizeof(timespan) * iNumRepetitions);
	double t1, t2;

	int i, rep;

	// initialize data structures
	#pragma omp parallel for schedule(static, CHUNK_SIZE) num_threads(tOptions->iNumThreads)
	for (i = 0; i < tInput->stNumRows; i++)
	{
		x[i] = tInput->x[i];

		int rowbeg = tInput->row[i];
		int rowend = tInput->row[i+1];

		int nz;
		int ecol = 0;
		for (nz = rowbeg; nz < rowend; nz++)
		{
			Acol[i * maxValsPerRow + ecol] = tInput->col[nz];
			Aval[i * maxValsPerRow + ecol] = tInput->val[nz];
			ecol++;
		}

		while(ecol < maxValsPerRow) {
			Acol[i * maxValsPerRow + ecol] = tInput->col[rowend - 1];
			ecol++;
		}
	}

	// take the time: start
	t1 = omp_get_wtime();

	LIKWID_MARKER_INIT;
	LIKWID_MARKER_START("Compute");

	// run kernel iNumRepetitions times
	for (rep = 0; rep < iNumRepetitions; rep++)
	{
		timings[rep].dBegin = omp_get_wtime();

		// yAx-kernel
		#pragma omp parallel for schedule(static, CHUNK_SIZE) num_threads(tOptions->iNumThreads)
		for (i = 0; i < tInput->stNumRows; i++)
		{
			double sum = 0.0;
			for (int ecol = 0; ecol < maxValsPerRow; ecol++)
			{
				sum += Aval[i * maxValsPerRow + ecol] * x[ Acol[i * maxValsPerRow + ecol] ];
			}
			y[i] = sum;
		}

		timings[rep].dEnd = omp_get_wtime();
	}

	LIKWID_MARKER_STOP("Compute");
	LIKWID_MARKER_CLOSE;

	// take the time: end
	t2 = omp_get_wtime();

	// error check
	print_error_check(y, tInput, tOptions);

	// process_results
	print_performance_results(tOptions, t1, t2, timings, tInput);

	// cleanup
	free(y);
	free(Aval);
	free(Acol);
	free(x);
	free(timings);

} // end loop

void spmxv_csr(ooo_options *tOptions, ooo_input *tInput)
{
	int iNumRepetitions = tOptions->iNumRepetitions; // set with -r <numrep>

	// setup data structures
	double *y = (double*) malloc(sizeof(double) * (tInput->stNumRows)); // result
	double *Aval = (double*) malloc(sizeof(double) * (tInput->stNumNonzeros)); // values
    int *Acol = (int*) malloc(sizeof(int) * (tInput->stNumNonzeros)); // column indices
	int *Arow = (int*) malloc(sizeof(int) * (tInput->stNumRows + 1)); // begin of each row
    double *x = (double*) malloc(sizeof(double) * (tInput->stNumRows)); // RHS
	

	// allocate helper data
	timespan *timings = (timespan*) malloc(sizeof(timespan) * iNumRepetitions);
	double t1, t2;

	// initialize data structures
	#pragma omp parallel for schedule(static, CHUNK_SIZE) num_threads(tOptions->iNumThreads)
	for (int i = 0; i < tInput->stNumRows; i++)
	{
		Arow[i] = tInput->row[i];
		y[i] = 0.0;
		x[i] = tInput->x[i];
		// x[i] = 1;
	}
	Arow[tInput->stNumRows] = tInput->stNumNonzeros;

	#pragma omp parallel for schedule(static, CHUNK_SIZE) num_threads(tOptions->iNumThreads)
	for (int i = 0; i < tInput->stNumRows; i++)
	{
		int rowbeg = Arow[i];
		int rowend = Arow[i+1];

		int nz;
		for (nz = rowbeg; nz < rowend; nz++)
		{
			Aval[nz] = tInput->val[nz];
			Acol[nz] = tInput->col[nz];
		}
	}

	LIKWID_MARKER_INIT;
	#pragma omp parallel num_threads(tOptions->iNumThreads)
	{
		LIKWID_MARKER_REGISTER("Compute");
	}

	// take the time: start
	t1 = omp_get_wtime();

	#pragma omp parallel num_threads(tOptions->iNumThreads)
	{
		LIKWID_MARKER_START("Compute");


		// run kernel iNumRepetitions times
		for (int rep = 0; rep < iNumRepetitions; rep++)
		{
			timings[rep].dBegin = omp_get_wtime();

			// yAx-kernel
				
			#pragma omp for schedule(static, CHUNK_SIZE) 
			for (int i = 0; i < tInput->stNumRows; i++)
			{
				double sum = 0.0;
				int rowbeg = Arow[i];
				int rowend = Arow[i+1];
				int nz;
				for (nz = rowbeg; nz < rowend; nz++)
				{
					sum += Aval[nz] * x[ Acol[nz] ];
				}
				y[i] = sum;
			}
			
			timings[rep].dEnd = omp_get_wtime();
		}
		LIKWID_MARKER_STOP("Compute");
	}

	// take the time: end
	t2 = omp_get_wtime();
	LIKWID_MARKER_CLOSE;

	// error check
	print_error_check(y, tInput, tOptions);

	// process_results
	print_performance_results(tOptions, t1, t2, timings, tInput);

	// cleanup
	free(y);
	free(Aval);
	free(Acol);
	free(Arow);
	free(x);
	free(timings);

} // end loop

int main(int argc, char* argv[])
{

#ifdef LIKWID_PERFMON
	printf("Measuring compute kernel with likwid.\n");
#endif

	int ps = getpagesize();
	printf("Pagesize: %d MiB\n", ps/1024);
	
	// parse command line
	ooo_options tOptions;
	if (! parseCmdLine(&tOptions, argc, argv))
	{
		return EXIT_FAILURE;
	}

	ooo_input tInput;
	if(tOptions.createMat){
		createMatrix(&tOptions, &tInput);
	} 
	else
	{
		// load filename
		if (! loadInputFile_4SMXV(&tOptions, &tInput))
		{
			return EXIT_FAILURE;
		}
	}


	randomRHS(&tInput);

	std::cout << "Loaded Matrix and random RHS" << std::endl;

	// SpMXV-Kernel
	switch (tOptions.mformat)
	{
	case MFORMAT_CSR:
		std::cout << "Using CSR format" << std::endl;
		spmxv_csr(&tOptions, &tInput);
		break;
	case MFORMAT_ELLPACK:
		std::cout << "Using ELLPACK format" << std::endl;
		spmxv_ellpack(&tOptions, &tInput);
	
	default:
		break;
	}

	return EXIT_SUCCESS;
}
