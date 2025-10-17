[//]: # (TODO: Add logo.)
[//]: # (TODO: Add shields.)

The Portable Power Locality (pwrloc) tool acts as an interface for energy profilers.
There are multiple energy profiling backends available, each different in their spatial and temporal resolution.
What backend is best depends fully on your use case.
However, not all systems come with the backends or tools that you want to use, and often sysadmins are reluctant to install new ones.
The pwrloc tool makes it easy to detect and target different energy profiling tools and backends.

## Supported Profilers

Currently, pwrloc supports the following energy profiling tools:

- [SLURM](https://github.com/SchedMD/slurm)
- [perf](https://github.com/torvalds/linux/tree/master/tools/perf)
- [PAPI](https://github.com/icl-utk-edu/papi)
- [NVML](https://developer.nvidia.com/management-library-nvml)
- [rocm-smi](https://github.com/ROCm/rocm_smi_lib)

## How to Use

```console
Usage: ./pwrloc.sh [-p profiler][-l] [-v] [--] [bin] [args]

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
  ./pwrloc.sh -l
  ./pwrloc.sh -p slurm <slurm_job_id>
  ./pwrloc.sh -p perf echo "Hello world"
  ./pwrloc.sh -p perf -- echo "Foo Bar rules!"
```
