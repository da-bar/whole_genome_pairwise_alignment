# da-bar/wgpa

[![GitHub Actions CI Status](https://github.com/da-bar/whole_genome_pairwise_alignment/actions/workflows/nf-test.yml/badge.svg)](https://github.com/da-bar/whole_genome_pairwise_alignment/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/da-bar/whole_genome_pairwise_alignment/actions/workflows/linting.yml/badge.svg)](https://github.com/da-bar/whole_genome_pairwise_alignment/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.1.0-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.1.0)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**da-bar/wgpa** (whole-genome pairwise alignment) aligns whole genomes pair by pair and turns the alignments into the chains, nets and liftOver files used for comparative genomics. It takes a samplesheet of genome pairs (target and query FASTA files), aligns each query to its target with [LAST](https://gitlab.com/mcfrith/last), and then chains and nets the alignments with the [UCSC kent utilities](https://genome.ucsc.edu/goldenPath/help/chain.html), using the alignment presets of the Bioconductor package [CNEr](https://bioconductor.org/packages/CNEr/). Calling conserved non-coding elements (CNEs) will be added in a later release.

Version 2 is a rewrite of [v1.0.0](https://github.com/da-bar/whole_genome_pairwise_alignment/tree/0280044394116c215d12f91ad8d257a77d72dc1e) on the [nf-core](https://nf-co.re/) template. v1.0.0 was a small Nextflow script that called the CNEr R wrappers for one genome pair. v2 runs the same programs with the same command lines, without R. On the v1.0.0 test pair (_Saccharomyces cerevisiae_ target, _S. eubayanus_ query), every file that v1.0.0 also made is byte-identical to the v1.0.0 file once it is decompressed, apart from one comment line in the MAF header (see [Relation to v1.0.0](#relation-to-v100)).

For each genome pair, the pipeline runs these steps:

1. Genome preparation, once per distinct FASTA file: `faToTwoBit` makes a 2bit file (soft-masking is kept) and `twoBitInfo` makes a sizes file.
2. Alignment: `lastdb -c` indexes the target genome, once per distinct target FASTA. `lastal` aligns the query with the preset's options and scoring matrix (MAF output). `maf-convert psl` converts the MAF to PSL.
3. Chaining and netting: `axtChain` (preset options and score scheme), `chainMergeSort`, `chainPreNet`, `chainNet`, and `netSyntenic` on the target net.
4. Net alignments: `netToAxt` on the syntenic net and the pre-net chains, then `axtSort`.
5. liftOver chains (`--liftover`, on by default): `netChainSubset` and `chainStitchId` on the syntenic net and all chains, as in UCSC `doBlastzChainNet.pl`.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/get_started/environment_setup/overview) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/get_started/run-your-first-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with one row per genome pair:

`samplesheet.csv`:

```csv
id,target,query,preset
scer_vs_seub,/path/to/S_cerevisiae.fa,/path/to/S_eubayanus.fa,near
scer_vs_spar,/path/to/S_cerevisiae.fa,/path/to/S_paradoxus.fa.gz,
```

| Column   | Description                                                                                                     |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| `id`     | Unique name of the pair, without spaces or `/`. The outputs of the pair go to `<outdir>/<id>/`.                 |
| `target` | Target (reference) genome FASTA: `.fa`, `.fasta` or `.fna`, optionally gzipped (`.gz`).                         |
| `query`  | Query genome FASTA, same formats as `target`.                                                                   |
| `preset` | Optional: `near`, `medium` or `far` (see [Presets](#presets)). An empty value uses `--preset` (default `near`). |

A genome can be used in any number of pairs, and as the target of one pair and the query of another; its 2bit, sizes and LAST index files are made only once. The output files are named after the FASTA file names without the extension, as in v1.0.0 (`<target>_<query>.*`), so two different FASTA files must not have the same name.

Now, you can run the pipeline using:

```bash
nextflow run da-bar/whole_genome_pairwise_alignment \
   -r dev \
   -profile <docker/singularity/conda/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

For more details and further functionality, please refer to the [usage documentation](docs/usage.md) and the [parameter documentation](nextflow_schema.json).

### Presets

The presets are the `distance` settings of CNEr (`lastal()` and `axtChain()`). The matrices are in [`assets/matrices`](assets/matrices).

| Preset   | Scoring matrix                    | lastal options                    | axtChain options                   |
| -------- | --------------------------------- | --------------------------------- | ---------------------------------- |
| `near`   | CNEr near (A/A 90, A/C -330, ...) | `-a 600 -b 150 -e 3000 -s 2 -f 1` | `-minScore=5000 -linearGap=medium` |
| `medium` | HOXD70                            | `-a 400 -b 30 -e 4500 -s 2 -f 1`  | `-minScore=3000 -linearGap=medium` |
| `far`    | HOXD55                            | `-a 400 -b 30 -e 6000 -s 2 -f 1`  | `-minScore=5000 -linearGap=loose`  |

Use `near` for closely related genomes and `far` for distant ones. For comparison, UCSC uses the near matrix for human-chimpanzee, HOXD70 (the BLASTZ default) for human-mouse and HOXD55 for more distant pairs such as human-chicken. `lastdb` always runs with `-c` (lowercase, soft-masked sequence is not used for initial matches). v1.0.0 always used `near`.

## Pipeline output

For each pair, `<outdir>/<id>/` holds `alignment/` (MAF, PSL), `chains/`, `nets/`, `axt/` and `liftover/`; `<outdir>/genomes/` holds the 2bit and sizes files. The alignment, chain, net and axt files are gzipped with `gzip -n` (no time stamp), so repeated runs give byte-identical files. For more details about the output files and reports, please refer to the [output documentation](docs/output.md).

## Relation to v1.0.0

v1.0.0 ([commit `0280044`](https://github.com/da-bar/whole_genome_pairwise_alignment/tree/0280044394116c215d12f91ad8d257a77d72dc1e)) ran these commands through CNEr 1.46.0 (LAST 1652, kent 482), always with the `near` preset (T = target, Q = query):

```bash
lastdb -c T T.fa
lastal -a 600 -b 150 -e 3000 -p <near matrix> -s 2 -f 1 T Q.fa > T_Q.maf
maf-convert psl T_Q.maf > T_Q.psl
faToTwoBit T.fa T.2bit
faToTwoBit Q.fa Q.2bit
axtChain -psl -minScore=5000 -linearGap=medium -scoreScheme=<near matrix> T_Q.psl T.2bit Q.2bit T_Q.chain
chainMergeSort -inputList=<file listing T_Q.chain> > T_Q.all.chain
chainPreNet T_Q.all.chain T.sizes Q.sizes T_Q.all.pre.chain
chainNet T_Q.all.pre.chain T.sizes Q.sizes target.net query.net
netSyntenic target.net T_Q.noClass.net
netToAxt T_Q.noClass.net T_Q.all.pre.chain T.2bit Q.2bit unsorted.axt
axtSort unsorted.axt T_Q.net.axt
```

v2 runs the same commands. The pipeline test ([`tests/default.nf.test`](tests/default.nf.test), run with `nf-test` on the test profile) checks that the decompressed v2 outputs have the md5 sums of the v1.0.0 outputs in [`tests/data/yeast/v1.0.0_md5.txt`](tests/data/yeast/v1.0.0_md5.txt): the PSL, all.chain, all.pre.chain, noClass.net and net.axt files, both 2bit files, and the MAF alignment records. The only difference in the MAF is one header comment, which names the LAST database (`# lastdb/S_cerevisiae` instead of `# S_cerevisiae`). When v2 was written, the medium and far presets, and the pair with target and query swapped, were also checked against CNEr 1.46.0 run by hand, with the same result.

What changed from v1.0.0:

- Any number of genome pairs, from a samplesheet, each with its own preset (v1.0.0: one pair, set in `nextflow.config`, always `near`).
- All three CNEr presets.
- UCSC liftOver chains (`<target>To<Query>.over.chain.gz`).
- The query net (`.query.net`), which v1.0.0 discarded, and the target net and axtChain chains, which v1.0.0 did not keep, are published.
- Outputs are gzipped and sorted into subfolders (see [output](docs/output.md)); gzipped FASTA input is accepted.
- No R: the tools run directly, each in its own conda environment or container.
- `lastal` runs with one thread, as v1.0.0 did. With `lastal -P` > 1 the order of the alignments, and hence the chains, nets and axt files, can change from run to run (see [usage](docs/usage.md#lastal-threads-and-reproducibility)).

## Credits

da-bar/wgpa was originally written by Damir Baranasic.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](docs/CONTRIBUTING.md).

## Third-party software

This pipeline relies on external tools: LAST, the UCSC kent utilities and, for its presets, CNEr. It does not distribute these tools or incorporate their source code; conda environments and containers fetch them from Bioconda and BioContainers. Users are responsible for complying with their licences:

- **LAST** is used for sequence alignment. Users should comply with the licensing terms of the LAST aligner.
- **kent utilities** (faToTwoBit, twoBitInfo, axtChain, chainMergeSort, chainPreNet, chainNet, netSyntenic, netToAxt, axtSort, netChainSubset, chainStitchId) are developed by the UCSC Genome Browser group and Jim Kent. Their use, especially commercial use, must comply with the [UCSC licence terms](https://genome.ucsc.edu/license/).
- **CNEr** supplied the alignment presets and scoring matrices. Users should adhere to the terms set by the authors of CNEr.

## Citations

<!-- If you use da-bar/wgpa for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

If you use da-bar/wgpa, please cite the tools it runs:

- LAST: Kiełbasa SM, Wan R, Sato K, Horton P, Frith MC. Adaptive seeds tame genomic sequence comparison. _Genome Res._ 2011;21(3):487-493. doi: [10.1101/gr.113985.110](https://doi.org/10.1101/gr.113985.110).
- Chains and nets: Kent WJ, Baertsch R, Hinrichs A, Miller W, Haussler D. Evolution's cauldron: duplication, deletion, and rearrangement in the mouse and human genomes. _Proc Natl Acad Sci USA._ 2003;100(20):11484-11489. doi: [10.1073/pnas.1932072100](https://doi.org/10.1073/pnas.1932072100).
- CNEr (presets): Tan G, Polychronopoulos D, Lenhard B. CNEr: A toolkit for exploring extreme noncoding conservation. _PLoS Comput Biol._ 2019;15(8):e1006940. doi: [10.1371/journal.pcbi.1006940](https://doi.org/10.1371/journal.pcbi.1006940).

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
