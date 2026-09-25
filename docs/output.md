# da-bar/wgpa: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

In the file names, `<target>` and `<query>` are the genome names: the FASTA file names without `.fa`, `.fasta` or `.fna` (and `.gz`). `<id>` is the pair id from the samplesheet. The file stems are those of v1.0.0 (`<target>_<query>.psl`, `.all.chain`, ...). Text outputs are gzipped with `gzip -n`, which leaves out the time stamp, so repeated runs give byte-identical files.

```
<outdir>/
├── genomes/
│   ├── <genome>.2bit
│   └── <genome>.sizes
├── <id>/
│   ├── alignment/
│   │   ├── <target>_<query>.maf.gz
│   │   ├── <target>_<query>.psl.gz
│   │   └── <target>_<query>.tsv
│   ├── chains/
│   │   ├── <target>_<query>.chain.gz
│   │   ├── <target>_<query>.all.chain.gz
│   │   └── <target>_<query>.all.pre.chain.gz
│   ├── nets/
│   │   ├── <target>_<query>.target.net.gz
│   │   ├── <target>_<query>.query.net.gz
│   │   └── <target>_<query>.noClass.net.gz
│   ├── axt/
│   │   └── <target>_<query>.net.axt.gz
│   └── liftover/
│       └── <target>To<Query>.over.chain.gz
└── pipeline_info/
```

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Genomes](#genomes) - 2bit and sizes files of each genome
- [Alignment](#alignment) - LAST alignments in MAF and PSL format
- [Chains](#chains) - axtChain chains, merged and filtered
- [Nets](#nets) - chainNet nets and the syntenic net
- [Net alignments](#net-alignments) - alignments of the syntenic net in axt format
- [liftOver chains](#liftover-chains) - UCSC liftOver chain files
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### Genomes

<details markdown="1">
<summary>Output files</summary>

- `genomes/`
  - `<genome>.2bit`: the genome in UCSC 2bit format, made with `faToTwoBit`. Lowercase (soft-masked) bases are kept.
  - `<genome>.sizes`: sequence names and lengths (`name<TAB>length`), in 2bit order, made with `twoBitInfo`.

</details>

Each distinct FASTA file gives one pair of files, however many pairs use it. The 2bit files are the ones v1.0.0 published.

### Alignment

<details markdown="1">
<summary>Output files</summary>

- `<id>/alignment/`
  - `<target>_<query>.maf.gz`: LAST alignments of the query to the target, in [MAF](https://genome.ucsc.edu/FAQ/FAQformat.html#format5) format. The header comments record the LAST version, the options, the name of the LAST index (the target genome name, as in v1.0.0) and the scoring matrix.
  - `<target>_<query>.psl.gz`: the same alignments in [PSL](https://genome.ucsc.edu/FAQ/FAQformat.html#format2) format (`maf-convert psl`), the input of axtChain.
  - `<target>_<query>.tsv`: alignment statistics from the nf-core LAST_LASTAL module (total alignment length, percent identity, and the number and total length of the target and query sequences).

</details>

### Chains

<details markdown="1">
<summary>Output files</summary>

- `<id>/chains/`
  - `<target>_<query>.chain.gz`: [chains](https://genome.ucsc.edu/goldenPath/help/chain.html) made by `axtChain` from the PSL alignments, with the preset's options and score scheme.
  - `<target>_<query>.all.chain.gz`: all chains, merged and sorted by score with `chainMergeSort` (with one axtChain file this is the same content as the `.chain` file).
  - `<target>_<query>.all.pre.chain.gz`: the chains that can take part in a net, from `chainPreNet`. These are the chains that `netToAxt` uses.

</details>

### Nets

<details markdown="1">
<summary>Output files</summary>

- `<id>/nets/`
  - `<target>_<query>.target.net.gz`: the [net](https://genome.ucsc.edu/goldenPath/help/net.html) on the target genome, from `chainNet`.
  - `<target>_<query>.query.net.gz`: the net on the query genome, from the same `chainNet` run (v1.0.0 discarded it).
  - `<target>_<query>.noClass.net.gz`: the target net with synteny information added by `netSyntenic`. It is the input of the net alignments and the liftOver chains. The name follows UCSC: the net has not been through `netClass`.

</details>

### Net alignments

<details markdown="1">
<summary>Output files</summary>

- `<id>/axt/`
  - `<target>_<query>.net.axt.gz`: the alignments of the syntenic net in [axt](https://genome.ucsc.edu/goldenPath/help/axt.html) format, made with `netToAxt` from the syntenic net and the pre-net chains and sorted by target position with `axtSort`. In CNEr, this is the input for calling conserved non-coding elements.

</details>

### liftOver chains

<details markdown="1">
<summary>Output files</summary>

- `<id>/liftover/`
  - `<target>To<Query>.over.chain.gz`: chains for UCSC `liftOver` from target to query coordinates, e.g. `S_cerevisiaeToS_eubayanus.over.chain.gz`. They are the chains of the syntenic net (`netChainSubset -verbose=0` on the noClass net and the all chains) with the chain fragments joined again by `chainStitchId`, as in UCSC `doBlastzChainNet.pl`.

</details>

Only made with `--liftover true` (the default).

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.html`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `wgpa_software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://docs.seqera.io/platform-cloud/reports/overview) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
