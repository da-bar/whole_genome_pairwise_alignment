# da-bar/wgpa: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0dev - [unreleased]

Rewrite of v1.0.0 (commit `0280044`) on the [nf-core](https://nf-co.re/) template (nf-core/tools 4.1.0). v2 runs the programs that v1.0.0 ran through the CNEr R wrappers directly, with the same command lines. On the v1.0.0 yeast test pair all v1.0.0 outputs, the MAF included, are reproduced byte for byte (after decompression).

### `Added`

- Samplesheet input (`--input`): any number of genome pairs, columns `id`, `target`, `query` and optional `preset`.
- All three CNEr presets (`near`, `medium`, `far`), per pair or with `--preset` (default `near`), with their scoring matrices in `assets/matrices`.
- UCSC liftOver chains, `<target>To<Query>.over.chain.gz` (`--liftover`, default `true`).
- Genome files (2bit, sizes) and LAST indexes are made once per distinct FASTA and shared between pairs; a genome can be the target of one pair and the query of another.
- Gzipped FASTA input.
- Self-alignments (the same FASTA file as target and query) run to the end, with a warning that the outputs contain the trivial self-alignment.
- A warning for each pair when a custom config gives LAST_LASTAL more than one cpu (`lastal -P` > 1 makes the outputs change from run to run).
- Published outputs that v1.0.0 did not keep: axtChain chains, target net, query net, LAST alignment statistics.
- Local modules for the UCSC kent utilities: `faToTwoBit`, `twoBitInfo`, `axtChain`, `chainMergeSort`, `chainPreNet`, `chainNet`, `netSyntenic`, `netToAxt`, `axtSort`, `netChainSubset`, `chainStitchId`, each with nf-test tests against v1-made fixtures (`tests/data/yeast_small`).
- nf-core modules `last/lastdb`, `last/lastal` and `last/mafconvert`.
- Subworkflows `prepare_genomes`, `pairwise_align`, `chain_net` and `liftover_chains`.
- Test profiles: `test` (the v1.0.0 yeast pair, near) and `test_full` (all presets and the reverse pair). The pipeline nf-test checks the outputs against the v1.0.0 checksums in `tests/data/yeast/v1.0.0_md5.txt`.

### `Changed`

- Outputs are gzipped with `gzip -n` (reproducible bytes) and sorted into `<outdir>/<id>/{alignment,chains,nets,axt,liftover}/` and `<outdir>/genomes/`.
- No R or CNEr is needed at run time; every tool has its own conda environment and container.
- `lastal` runs with one thread (as in v1.0.0), because `lastal -P` > 1 changes the order of the alignments from run to run and hence the chains and nets. `lastdb` also runs with one thread, as in v1.0.0.
- LAST_LASTAL asks for 36 GB of memory (72 GB on a retry) instead of the 72 GB of the `process_high` label, so that the pipeline runs on a 64 GB workstation.
- The nf-core `last/lastal` module is patched (`modules/nf-core/last/lastal/last-lastal.diff`) to call lastal with the bare index name, so that the MAF header names the LAST database as v1.0.0 did (`# S_cerevisiae`, not `# lastdb/S_cerevisiae`).
- Pair ids can only contain letters, digits, `.`, `_` and `-`, and must start with a letter or digit; `genomes` and `pipeline_info` are reserved. Pair ids, and genome names, must differ in more than case, so that no two pairs or genomes share output files on a case-insensitive file system.

### `Fixed`

- The malformed `-linearGapmedium` flag that CNEr adds to axtChain (and axtChain ignores) is no longer passed.
- Boolean parameters given on the command line, such as `--liftover false`, failed validation with the template's nf-schema 2.5.1, because the Nextflow 26.04 strict syntax parser passes them as strings. nf-schema 2.7.2 casts them to the schema types, and the pipeline reads `--liftover` as a boolean.

### `Dependencies`

| Dependency                    | Old version (v1.0.0, through CNEr 1.46.0) | New version |
| ----------------------------- | ----------------------------------------- | ----------- |
| `last`                        | 1652                                      | 1652        |
| `ucsc-*` kent utilities       | 482                                       | 482         |
| `bioconductor-cner`           | 1.46.0                                    | not used    |
| `nf-schema` (Nextflow plugin) | 2.5.1 (template)                          | 2.7.2       |

### `Deprecated`

- The v1.0.0 parameters `--reference`, `--query` and `--output` are replaced by the samplesheet and `--outdir`.
