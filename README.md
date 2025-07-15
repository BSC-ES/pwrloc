# Energy Profiler

The energy profiler is a portable tool for measuring the energy consumption of 
applications. Not all systems support all energy profiling backends, and thus
the energy profiler allows you to check what is available and target the
available backend you are interested in.

## Available profilers

Currently, the energy profiler supports the following energy profiling tools:

 - SLURM
 - perf
 - PAPI

## Usage

```console
Usage: ./energy-profiler.sh [-p profiler][-l] [-v] [--] [bin] [args]  

Options:  
  -p profiler   Profile using provided profiler  
  -l            List availability of the supported profilers  
  -v            Enable verbose mode  
  -h            Show this help message and exit 

Application:  
  [bin] [args]  Application (with arguments) to profile.  
                SLURM notes:  
                    - [bin] should be a SLURM job id.  
                    - The dependency job id will be used if [bin] is not given.  

Example:  
  ./energy-profiler.sh -p slurm <slurm_job_id>  
  ./energy-profiler.sh -p perf echo "Hello world"  
  ./energy-profiler.sh -p perf -- echo "Foo Bar rules!"  
```