# Test data

The tests check that v2 gives the files of v1.0.0 (commit `0280044`) byte for byte, after decompression. The
2bit, sizes, MAF and PSL files are the same on every platform. The files that `axtChain` and the kent steps after
it make (chains, nets, axt files, liftOver chains) are not: on the v1.0.0 yeast pair, macOS arm64 and Linux x86_64
give the same chains, but chains of equal score come in a different order, which changes the chain ids and a few
choices of the nets. v1.0.0 itself gives these different files on the two platforms, and v2 gives the v1.0.0 files
of the platform it runs on. So the tests compare these files with references made on the same platform, and keep
them out of the nf-test snapshots. (On `yeast_small`, the kent steps after `axtChain` give the same files on both
platforms from the same input: the difference starts in `axtChain`.)

## Layout

Shared by all platforms:

- `yeast/S_cerevisiae.fa`, `yeast/S_eubayanus.fa`: the v1.0.0 test pair (the FASTA files of v1.0.0), used by
  `tests/default.nf.test`.
- `yeast/v1.0.0_md5.txt`: md5 of the v1.0.0 MAF (the whole file, and without its `#` lines), PSL and 2bit files.
- `yeast_small/*.fa`, `*.2bit`, `*.sizes`: a small subset of the pair, `scer_small` (2 _S. cerevisiae_ chromosomes,
  the target) and `seub_small` (3 _S. eubayanus_ chromosomes, the query).
- `yeast_small/small.maf.gz`, `small.psl`: the v1.0.0 alignment of `scer_small` and `seub_small` (`lastdb -c`,
  `lastal`, `maf-convert psl`).

One folder per platform, `<platform>` being `darwin-arm64` or `linux-x86_64`:

- `yeast/platform/<platform>/v1.0.0_md5.txt`: md5 of the v1.0.0 `all.chain`, `all.pre.chain`, `noClass.net` and
  `net.axt`.
- `yeast/platform/<platform>/md5.txt`: md5 of the target and query nets, which v1.0.0 made but did not keep, and of
  the liftOver chain.
- `yeast_small/platform/<platform>/small.*`: the v1.0.0 chain and net commands on `small.psl`: `small.chain`,
  `small.all.chain`, `small.all.pre.chain`, `small.target.net`, `small.query.net`, `small.noClass.net`,
  `small.unsorted.axt` and `small.net.axt`, and the liftOver steps: `small.subset.chain`, `small.over.chain`.
  The module tests of the kent steps take them as inputs and as expected outputs.
- `yeast_small/platform/<platform>/md5.txt`: md5 of other platform-dependent test outputs: `axtChain` without
  `-scoreScheme`, `chainMergeSort` of `small.chain` split into three files, and every chain, net, axt and liftOver
  file of the pairs `seub_small`→`scer_small` and `scer_small`→`scer_small` (self-alignment).

`make_platform_fixtures.sh` makes the platform folders.

The platforms are `darwin-arm64` (macOS on Apple silicon) and `linux-x86_64`. Their references were made with
`make_platform_fixtures.sh`, with LAST 1652 and the kent 482 utilities from Bioconda, on macOS 15 (arm64) and on
Debian 13 (x86_64). On both, the v1.0.0 md5s are also those of v1.0.0 itself (through CNEr 1.46.0) run on the same
machine, and the script remade every shared file of this folder unchanged. Linux x86_64 is the reference platform
for production runs and CI.

## How the tests pick the platform

`tests/lib/PlatformReferences.groovy` (on the class path of every nf-test test) makes the platform key from the
JVM's `os.name` and `os.arch`, as `uname -s`-`uname -m` in lower case: `darwin-arm64`, `linux-x86_64`,
`linux-aarch64`, and so on. The environment variable `WGPA_TEST_PLATFORM` overrides it, for tools that run in
containers of another platform (for example `-profile docker` on macOS runs the `linux/amd64` containers:
`WGPA_TEST_PLATFORM=linux-x86_64`).

There is no fallback: on a platform without references, every test that needs them fails with a message that
points to `make_platform_fixtures.sh`.

## Adding a platform

On the new platform, with LAST 1652 and the kent 482 utilities on `PATH` (for example a conda environment with the
versions of `modules/*/*/environment.yml`):

```bash
tests/data/make_platform_fixtures.sh
```

It runs the v1.0.0 command lines (`lastdb -c`; `lastal -a 600 -b 150 -e 3000 -p near.lastal.mat -s 2 -f 1`;
`maf-convert psl`; `faToTwoBit`; `twoBitInfo`; `axtChain -psl -minScore=5000 -linearGap=medium
-scoreScheme=near.axtchain.mat`; `chainMergeSort`; `chainPreNet`; `chainNet`; `netSyntenic`; `netToAxt`; `axtSort`)
and the liftOver commands (`netChainSubset -verbose=0`, `chainStitchId`) on both pairs, and writes
`yeast/platform/<platform>/` and `yeast_small/platform/<platform>/` (about a minute). It stops if a file that should
be the same on every platform (2bit, sizes, MAF, PSL) differs from the one here. Run on a platform that already has
references, it must leave them unchanged (`git status`). Then run the tests (`nf-test test`) and commit the new
folders. `--help` lists the options (`--platform`, `--outdir`, `--small-only`, `--workdir`).
