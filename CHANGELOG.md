# da-bar/wgpa: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0dev - [unreleased]

Rewrite of v1.0.0 (commit `0280044`) on the [nf-core](https://nf-co.re/) template (nf-core/tools 4.1.0). v2 runs the programs that v1.0.0 ran through the CNEr R wrappers directly, with the same command lines. On the v1.0.0 yeast test pair all v1.0.0 outputs, the MAF included, are reproduced byte for byte (after decompression) on the same platform, on macOS arm64 as on Linux x86_64. The `axtChain` output, and hence the chains, nets, axt files and liftOver chains, differs slightly between macOS and Linux, for v1.0.0 as for v2: on the yeast pair, chains of equal score come in a different order; on a pair of carp chromosomes, some chains differ, by 0.0024% of the aligned bases. Linux x86_64 is the reference platform for production runs and CI.

### `Added`

- Samplesheet input (`--input`): any number of genome pairs, columns `id`, `target`, `query` and optional `preset`.
- All three CNEr presets (`near`, `medium`, `far`), per pair or with `--preset` (default `near`), with their scoring matrices in `assets/matrices`.
- UCSC liftOver chains, `<target>To<Query>.over.chain.gz` (`--liftover`, default `true`).
- Genome files (2bit, sizes) and LAST indexes are made once per distinct FASTA and shared between pairs; a genome can be the target of one pair and the query of another.
- Gzipped FASTA input.
- Self-alignments (the same FASTA file as target and query) run to the end, with a warning that the outputs contain the trivial self-alignment.
- A warning for each pair when a custom config gives LAST_LASTAL more than one cpu (`lastal -P` > 1 makes the outputs change from run to run).
- Published outputs that v1.0.0 did not keep: axtChain chains, target net, query net, LAST alignment statistics.
- Local modules for the UCSC kent utilities: `faToTwoBit`, `twoBitInfo`, `axtChain`, `chainMergeSort`, `chainPreNet`, `chainNet`, `netSyntenic`, `netToAxt`, `axtSort`, `netChainSubset`, `chainStitchId`, each with nf-test tests against v1-made fixtures (`tests/data/yeast_small`, the chain, net and axt fixtures per platform).
- nf-core modules `last/lastdb`, `last/lastal` and `last/mafconvert`.
- Subworkflows `prepare_genomes`, `pairwise_align`, `chain_net` and `liftover_chains`.
- Test profiles: `test` (the v1.0.0 yeast pair, near) and `test_full` (all presets and the reverse pair). The pipeline nf-test checks the outputs against the v1.0.0 checksums in `tests/data/yeast/v1.0.0_md5.txt` and `tests/data/yeast/platform/<platform>/v1.0.0_md5.txt`.
- Pairs can start from an existing alignment instead of the pipeline's LAST alignment: optional samplesheet column `alignment`, a MAF or PSL file of the query aligned to the target (optionally gzipped), for example the many-to-many MAF (`*.m2m.maf.gz`) of nf-core/pairgenomealign run with `--m2m`. Such a pair skips `lastdb` and `lastal` (a LAST index is only made for targets that another pair aligns to with LAST); a MAF is converted with `maf-convert psl`, a PSL goes to `axtChain` as it is. The target and query FASTA files are still required, and the preset still sets the `axtChain` options and score scheme. MAF blocks with the target on the `-` strand (pairgenomealign's default `--strand both`) are handled by `maf-convert psl`. See the usage docs for pairgenomealign (target choice for polyploid genomes, `--m2m`).
- Local module `check/alignment` (CHECK_ALIGNMENT): checks that the target and query sequence names and lengths of an alignment input are those of the pair's FASTA files, and stops the pipeline with a list of the sequences that do not fit, saying when target and query look swapped.
- Tests for alignment inputs (`tests/alignment_input.nf.test`): a MAF input (`tests/data/yeast_small/small.maf.gz`, made with the v1.0.0 lastal command), a PSL input and a MAF with the target on the `-` strand each reproduce every yeast_small fixture byte for byte; target and query swapped fails in the check; a samplesheet mixing a LAST pair and a MAF pair makes one LAST index only.
- Platform-dependent test references for macOS arm64 (`darwin-arm64`) and Linux x86_64 (`linux-x86_64`): the chain, net, axt and liftOver files that `axtChain` and the kent steps after it make, which differ between the two platforms, are in `tests/data/yeast/platform/<platform>/` and `tests/data/yeast_small/platform/<platform>/`. `tests/data/make_platform_fixtures.sh` makes them with the v1.0.0 command lines, from the platform-independent inputs, so that another platform can be added; the Linux ones were made on a Debian 13 x86_64 server, where v1.0.0 itself gives the same md5s on the yeast test pair. The tests pick the references of the platform they run on (`tests/lib/PlatformReferences.groovy`, override with `WGPA_TEST_PLATFORM`), and fail with a message pointing to the script on a platform that has none. See `tests/data/README.md`.

### `Changed`

- Outputs are gzipped with `gzip -n` (reproducible bytes) and sorted into `<outdir>/<id>/{alignment,chains,nets,axt,liftover}/` and `<outdir>/genomes/`.
- No R or CNEr is needed at run time; every tool has its own conda environment and container.
- `lastal` runs with one thread (as in v1.0.0), because `lastal -P` > 1 changes the order of the alignments from run to run and hence the chains and nets. `lastdb` also runs with one thread, as in v1.0.0.
- LAST_LASTAL asks for 36 GB of memory (72 GB on a retry) instead of the 72 GB of the `process_high` label, so that the pipeline runs on a 64 GB workstation.
- The nf-core `last/lastal` module is patched (`modules/nf-core/last/lastal/last-lastal.diff`) to call lastal with the bare index name, so that the MAF header names the LAST database as v1.0.0 did (`# S_cerevisiae`, not `# lastdb/S_cerevisiae`).
- Pair ids can only contain letters, digits, `.`, `_` and `-`, and must start with a letter or digit; `genomes` and `pipeline_info` are reserved. Pair ids, and genome names, must differ in more than case, so that no two pairs or genomes share output files on a case-insensitive file system.
- The nf-test snapshots no longer hold md5s that depend on the platform: they keep the versions, the output file names and the md5s of the MAF, PSL, LAST statistics, 2bit and sizes files. Every chain, net, axt and liftOver file is checked against the references of the platform instead, and every test checks that no such file is left unchecked. `tests/data/yeast/v1.0.0_md5.txt` now holds only the platform-independent v1.0.0 md5s (MAF, PSL, 2bit).
- nf-core subworkflows `utils_nextflow_pipeline` and `utils_nfcore_pipeline` updated to `6ef220fd` (`dumpParametersToJSON` writes paths, durations and memory units as plain values; meta.yml fixes).
- The pre-commit hooks `trailing-whitespace` and `end-of-file-fixer` skip `tests/data/yeast` and `tests/data/yeast_small`: the chain and axt fixtures end with an empty line, which `end-of-file-fixer` removed.

### `Fixed`

- The malformed `-linearGapmedium` flag that CNEr adds to axtChain (and axtChain ignores) is no longer passed.
- `-profile conda` stopped at startup when there was no `conda` executable on `PATH` (for example with only micromamba and `conda.useMicromamba = true`): the conda channel check of the nf-core `utils_nextflow_pipeline` subworkflow passed the exception to `log.debug`, which has no such method. The subworkflow is patched (`subworkflows/nf-core/utils_nextflow_pipeline/utils_nextflow_pipeline.diff`) to log the message, so the pipeline warns "Could not verify conda channel configuration." and runs.
- Boolean parameters given on the command line, such as `--liftover false`, failed validation with the template's nf-schema 2.5.1, because the Nextflow 26.04 strict syntax parser passes them as strings. nf-schema 2.7.2 casts them to the schema types, and the pipeline reads `--liftover` as a boolean.

### `Dependencies`

| Dependency                     | Old version (v1.0.0, through CNEr 1.46.0) | New version |
| ------------------------------ | ----------------------------------------- | ----------- |
| `last`                         | 1652                                      | 1652        |
| `ucsc-*` kent utilities        | 482                                       | 482         |
| `bioconductor-cner`            | 1.46.0                                    | not used    |
| `nf-schema` (Nextflow plugin)  | 2.5.1 (template)                          | 2.7.2       |
| `gawk` (alignment input check) | not used                                  | 5.3.1       |

### `Deprecated`

- The v1.0.0 parameters `--reference`, `--query` and `--output` are replaced by the samplesheet and `--outdir`.
