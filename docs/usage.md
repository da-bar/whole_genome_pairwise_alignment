# da-bar/wgpa: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

da-bar/wgpa aligns genome pairs with LAST and chains and nets the alignments with the UCSC kent utilities, using the CNEr presets. Each row of the samplesheet is one pair: a target (reference) genome and a query genome. The target is the genome that the chains, nets, axt files and liftOver chains are referenced to; the query is aligned to it.

## Samplesheet input

You will need to create a samplesheet with information about the genome pairs you would like to align before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 or 4 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

```csv title="samplesheet.csv"
id,target,query,preset
scer_vs_seub,/data/genomes/S_cerevisiae.fa,/data/genomes/S_eubayanus.fa,near
scer_vs_spar,/data/genomes/S_cerevisiae.fa,/data/genomes/S_paradoxus.fa.gz,
seub_vs_scer,/data/genomes/S_eubayanus.fa,/data/genomes/S_cerevisiae.fa,near
```

| Column   | Description                                                                                                                   |
| -------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `id`     | Unique name of the pair (see the notes below for the allowed names). The outputs of the pair are written to `<outdir>/<id>/`. |
| `target` | Target genome FASTA file, with the extension `.fa`, `.fasta` or `.fna`, optionally followed by `.gz`.                         |
| `query`  | Query genome FASTA file, same formats as `target`.                                                                            |
| `preset` | Optional. `near`, `medium` or `far` (see [Presets](#presets)). Leave it empty, or leave the column out, to use `--preset`.    |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

Notes:

- Pair ids can contain letters, digits, `.`, `_` and `-`, and must start with a letter or digit. `genomes` and `pipeline_info` (in any case) are not allowed, because they are the pipeline's own output folders. Two ids must differ in more than case (`pairA` and `paira` are rejected), because on a case-insensitive file system, such as the macOS default, they would share one folder.
- The genome name is the FASTA file name without `.fa`, `.fasta` or `.fna` (and `.gz`), as in v1.0.0. The output files of a pair are named `<target name>_<query name>.*`, and the 2bit and sizes files `<genome name>.2bit` and `.sizes`. Two different FASTA files with the same name (for example `/a/genome.fa` and `/b/genome.fa`), or with names that differ only in case (`genome.fa` and `Genome.fa`), are therefore rejected; rename one of them.
- A FASTA file can appear in any number of rows, as target in one pair and as query in another. The pipeline makes its 2bit and sizes files once, and one LAST index per distinct target FASTA.
- Lowercase (soft-masked) bases are kept in the 2bit files and are excluded from the initial LAST matches (`lastdb -c`), so soft-mask repeats before running the pipeline, as for v1.0.0.
- The sequence names are the first word of each FASTA header.
- A genome can be aligned to itself (the same file as target and query). The pipeline then prints a warning, because the chains, nets, axt files and liftOver chains contain the trivial alignment of each sequence to itself (the diagonal). The pipeline does not remove it; UCSC self-alignments need extra steps that the pipeline does not do.

## Presets

The presets are the `distance` settings of CNEr's `lastal()` and `axtChain()` functions. Each preset sets the lastal options and scoring matrix (`lastal -p`) and the axtChain options and score scheme (`axtChain -scoreScheme`):

| Preset   | Scoring matrix | lastal                            | axtChain                           |
| -------- | -------------- | --------------------------------- | ---------------------------------- |
| `near`   | CNEr near      | `-a 600 -b 150 -e 3000 -s 2 -f 1` | `-minScore=5000 -linearGap=medium` |
| `medium` | HOXD70         | `-a 400 -b 30 -e 4500 -s 2 -f 1`  | `-minScore=3000 -linearGap=medium` |
| `far`    | HOXD55         | `-a 400 -b 30 -e 6000 -s 2 -f 1`  | `-minScore=5000 -linearGap=loose`  |

The matrices are in [`assets/matrices`](../assets/matrices) (`<preset>.lastal.mat` and `<preset>.axtchain.mat`); they are the matrices that CNEr 1.46.0 `scoringMatrix()` writes. The target is always indexed with `lastdb -c`.

`--preset` (default `near`, the only preset of v1.0.0) sets the preset of the pairs whose `preset` value is empty.

## liftOver chains

With `--liftover true` (the default) the pipeline also makes UCSC liftOver chains for each pair, `<target>To<Query>.over.chain.gz` (the first letter of the query name is capitalised, as in UCSC file names such as `hg38ToMm10.over.chain.gz`). They are the chains of the syntenic net, made as in UCSC `doBlastzChainNet.pl`:

```bash
netChainSubset -verbose=0 T_Q.noClass.net T_Q.all.chain stdout | chainStitchId stdin T_Q.over.chain
```

They lift coordinates from the target genome to the query genome with UCSC `liftOver`. Use `--liftover false` to skip them.

## lastal threads and reproducibility

The nf-core LAST_LASTAL module runs `lastal -P <task.cpus>`. The pipeline sets `cpus = 1` for LAST_LASTAL (in `conf/base.config`), which is what v1.0.0 did (CNEr `mc.cores = 1`), because more threads make the results depend on the run:

- With `-P` > 1, lastal writes the alignments of different query sequences in a different order in every run. The alignments themselves are the same: sorted, the MAF records of `-P 1` and `-P 4` are identical, and the alignments of each query sequence stay together and in the same order.
- The chaining steps depend on that order. On the yeast test pair, a `-P 4` MAF gave the same set of chains as `-P 1`, but with different chain IDs and a different order of equal-scoring chains, and chainNet then picked different chains, so the nets and axt files differed too. Two `-P 4` runs also differed from each other.

`lastdb` also runs with one thread (`cpus = 1` for LAST_LASTDB), as in v1.0.0. Indexes made with more threads have a different `.suf` file. On the yeast pair, indexes made with 1, 2, 4 and 8 threads gave byte-identical MAF files, but this has not been checked on whole vertebrate genomes, and indexing takes much less time than the alignment.

If lastal is too slow for large genomes, you can raise its threads in a custom config, at the cost of reproducibility. The pipeline then prints a warning for each pair:

```groovy title="lastal_threads.config"
process {
    withName: 'LAST_LASTAL' {
        cpus = 16
    }
}
```

## Test profiles

- `-profile test` runs the v1.0.0 test pair: _S. cerevisiae_ (target) and _S. eubayanus_ (query), preset `near`. The FASTA files are downloaded from the v1.0.0 commit on GitHub; identical copies are in `tests/data/yeast/`. The outputs match the v1.0.0 checksums in `tests/data/yeast/v1.0.0_md5.txt`.
- `-profile test_full` runs the same pair with each preset, and the reverse pair (_S. eubayanus_ as target). It checks that genome files and LAST indexes are shared between pairs.

The nf-test tests (`nf-test test`) use the copies in `tests/data/` and run offline.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run da-bar/whole_genome_pairwise_alignment -r dev --input ./samplesheet.csv --outdir ./results -profile docker
```

(`da-bar/wgpa` is the pipeline name; the GitHub repository is `da-bar/whole_genome_pairwise_alignment`. You can also run a local clone with `nextflow run /path/to/whole_genome_pairwise_alignment ...`.)

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run da-bar/whole_genome_pairwise_alignment -r dev -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull da-bar/whole_genome_pairwise_alignment
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [da-bar/wgpa releases page](https://github.com/da-bar/whole_genome_pairwise_alignment/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing: the v1.0.0 yeast pair (see [Test profiles](#test-profiles))
  - Includes links to test data so needs no other parameters
- `test_full`
  - The yeast pair with all three presets, and the reverse pair
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow `24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with one of the error codes listed in [`conf/base.config`](../conf/base.config) (`errorStrategy`: 130-145, 104 and 175-177, which include the codes for running out of memory or time), it is resubmitted once, with twice the original request (`maxRetries = 1`; the cpus of LAST_LASTDB, LAST_LASTAL and the single-threaded steps stay at 1). If it fails again, the pipeline execution is stopped.

With the local executor, Nextflow does not start a task that asks for more cpus or memory than the machine has. The largest first requests are 6 cpus and 36 GB of memory (the `process_medium` label, e.g. UCSC_AXTCHAIN), doubled on a retry; LAST_LASTDB and LAST_LASTAL ask for 1 cpu and 36 GB. On a workstation, cap the requests at what the machine has, for example for 16 cores and 64 GB of memory:

```groovy title="workstation.config"
process {
    resourceLimits = [ cpus: 16, memory: '60.GB' ]
}
```

and add `-c workstation.config` to the command line. Requests above the limits are lowered to the limits.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
