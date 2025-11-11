<h1 align="center">
  <img src="https://raw.githubusercontent.com/bsc-es/pwrloc/main/docs/img/pwrloc_logo_rectangle.png" width="500">
</h1><br>

The Portable Power Locality (pwrloc) tool acts as an interface for energy profilers.
There are multiple energy profiling backends available, each with a different spatial and temporal resolution.
What backend is best depends fully on your use case.
However, not all systems come with the backends or tools that you want to use, and often system administrators are reluctant to install new ones.
The pwrloc tool makes it easy to detect and target different energy profiling tools and backends.
It is fully portable and ready to be used on any POSIX-compliant operating system.

## Supported profilers

Currently, pwrloc supports the following energy profiling tools:

- [SLURM](https://github.com/SchedMD/slurm)
- [perf](https://github.com/torvalds/linux/tree/master/tools/perf)
- [PAPI](https://github.com/icl-utk-edu/papi)
- [NVML](https://developer.nvidia.com/management-library-nvml)
- [rocm-smi](https://github.com/ROCm/rocm_smi_lib)

## How to use

```console
Usage: ./pwrloc.sh [-l] [-p profiler] [-v] [--] [bin] [args]

Options:
  -l            List availability of the supported profilers
  -p profiler   Profile using provided profiler
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

## Contributing

Great that you're interested in contributing to the project!
This project is meant to cover as many tools and systems as possible, making your help essential.
Please take a look at the [CONTRIBUTING.md](CONTRIBUTING.md) file which contains instructions on how you can contribute.

## License

This project is licensed with the LGPLv3 license, which you can find in the [LICENSE](LICENSE) and [LICENSE.LESSER](LICENSE.LESSER) files.
