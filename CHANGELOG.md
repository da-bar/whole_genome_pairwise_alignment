# da-bar/wgpa: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0dev - [unreleased]

Rewrite of v1.0.0 (commit `0280044`) on the [nf-core](https://nf-co.re/) template (nf-core/tools 4.1.0). v2 runs the programs that v1.0.0 ran through the CNEr R wrappers directly, with the same command lines. On the v1.0.0 yeast test pair all v1.0.0 outputs are reproduced byte for byte (after decompression; the MAF differs in one header comment line).

### `Added`

- Samplesheet input (`--input`): any number of genome pairs, columns `id`, `target`, `query` and optional `preset`.
- All three CNEr presets (`near`, `medium`, `far`), per pair or with `--preset` (default `near`), with their scoring matrices in `assets/matrices`.
- UCSC liftOver chains, `<target>To<Query>.over.chain.gz` (`--liftover`, default `true`).
- Genome files (2bit, sizes) and LAST indexes are made once per distinct FASTA and shared between pairs; a genome can be the target of one pair and the query of another.
- Gzipped FASTA input.
- Published outputs that v1.0.0 did not keep: axtChain chains, target net, query net, LAST alignment statistics.
- Local modules for the UCSC kent utilities: `faToTwoBit`, `twoBitInfo`, `axtChain`, `chainMergeSort`, `chainPreNet`, `chainNet`, `netSyntenic`, `netToAxt`, `axtSort`, `netChainSubset`, `chainStitchId`, each with nf-test tests against v1-made fixtures (`tests/data/yeast_small`).
- nf-core modules `last/lastdb`, `last/lastal` and `last/mafconvert`.
- Subworkflows `prepare_genomes`, `pairwise_align`, `chain_net` and `liftover_chains`.
- Test profiles: `test` (the v1.0.0 yeast pair, near) and `test_full` (all presets and the reverse pair). The pipeline nf-test checks the outputs against the v1.0.0 checksums in `tests/data/yeast/v1.0.0_md5.txt`.

### `Changed`

- Outputs are gzipped with `gzip -n` (reproducible bytes) and sorted into `<outdir>/<id>/{alignment,chains,nets,axt,liftover}/` and `<outdir>/genomes/`.
- No R or CNEr is needed at run time; every tool has its own conda environment and container.
- `lastal` runs with one thread (as in v1.0.0), because `lastal -P` > 1 changes the order of the alignments from run to run and hence the chains and nets.

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
