#!/usr/bin/env bash
#
# make_platform_fixtures.sh: make the platform-dependent test references of da-bar/wgpa
#
# axtChain, and so the kent steps that follow it, do not give byte-identical files on every platform: on
# macOS arm64 and Linux x86_64, chains of equal score come out in a different order (most likely because the
# C library's sort orders ties differently), which changes chain ids and a few net choices, and on large
# genomes a few chains differ. The 2bit, sizes, MAF and PSL files do not depend on the platform. The tests
# therefore compare the chain, net, axt and liftOver files with references made on the same platform, and
# this script makes them, with the v1.0.0 command lines (the commands that v1.0.0 ran through CNEr 1.46.0),
# from the platform-independent inputs in tests/data:
#
#   tests/data/yeast_small/platform/<platform>/
#       small.chain            axtChain -psl -minScore=5000 -linearGap=medium -scoreScheme=near.axtchain.mat
#                              small.psl scer_small.2bit seub_small.2bit
#       small.all.chain        chainMergeSort -inputList=<list of small.chain>
#       small.all.pre.chain    chainPreNet small.all.chain scer_small.sizes seub_small.sizes
#       small.target.net       chainNet small.all.pre.chain scer_small.sizes seub_small.sizes
#       small.query.net            small.target.net small.query.net
#       small.noClass.net      netSyntenic small.target.net
#       small.unsorted.axt     netToAxt small.noClass.net small.all.pre.chain scer_small.2bit seub_small.2bit
#       small.net.axt          axtSort small.unsorted.axt
#       small.subset.chain     netChainSubset -verbose=0 small.noClass.net small.all.chain
#       small.over.chain       chainStitchId small.subset.chain (liftOver chain, as UCSC doBlastzChainNet.pl)
#       md5.txt                md5 of other platform-dependent test outputs, made with the same commands:
#                              axtChain without -scoreScheme, chainMergeSort of small.chain split in three,
#                              and the pairs seub_small->scer_small and scer_small->scer_small (self), aligned
#                              with the v1.0.0 lastdb/lastal/maf-convert commands
#   tests/data/yeast/platform/<platform>/
#       v1.0.0_md5.txt         md5 of the platform-dependent v1.0.0 outputs of the v1.0.0 test pair
#                              (all.chain, all.pre.chain, noClass.net, net.axt), aligned with lastal
#       md5.txt                md5 of the platform-dependent files that v2 publishes and v1.0.0 did not keep
#                              (target and query nets, liftOver chain)
#
# The platform-independent references stay shared: tests/data/yeast_small/{scer_small,seub_small}.{fa,2bit,sizes},
# small.maf.gz, small.psl, and tests/data/yeast/v1.0.0_md5.txt (MAF, PSL, 2bit). The script remakes them on
# the way and stops if they differ from the shared ones: the platform then differs before axtChain.
#
# <platform> is `uname -s`-`uname -m` in lower case (darwin-arm64, linux-x86_64, linux-aarch64, ...). The tests
# compute the same key from the JVM (tests/lib/PlatformReferences.groovy) or read it from WGPA_TEST_PLATFORM.
#
# Usage:
#   tests/data/make_platform_fixtures.sh [--platform <key>] [--outdir <dir>] [--small-only] [--workdir <dir>]
#
#   --platform <key>   platform key to write (default: from uname)
#   --outdir <dir>     where to write the <dataset>/platform/<key>/ folders (default: tests/data of this repository)
#   --small-only       only yeast_small (the full yeast pair aligns two 12 Mb genomes with lastal; about a minute)
#   --workdir <dir>    keep the intermediate files in <dir> (default: a temporary folder, removed at the end)
#
# Needs on PATH: LAST 1652 (lastdb, lastal, maf-convert) and the UCSC kent utilities 482 (faToTwoBit,
# twoBitInfo, axtChain, chainMergeSort, chainPreNet, chainNet, netSyntenic, netToAxt, axtSort,
# netChainSubset, chainStitchId), e.g. from a conda environment with the versions of modules/*/environment.yml.
# Other versions can give other files. See tests/data/README.md.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
data="$repo/tests/data"
matrices="$repo/assets/matrices"

platform="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | tr '[:upper:]' '[:lower:]')"
outdir="$data"
small_only=false
workdir=""

while [ $# -gt 0 ]; do
    case "$1" in
        --platform)   platform="$2"; shift 2 ;;
        --outdir)     outdir="$2"; shift 2 ;;
        --small-only) small_only=true; shift ;;
        --workdir)    workdir="$2"; shift 2 ;;
        -h|--help)    sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&3; exit 1; }
exec 3>&2

for tool in lastdb lastal maf-convert faToTwoBit twoBitInfo axtChain chainMergeSort chainPreNet chainNet \
            netSyntenic netToAxt axtSort netChainSubset chainStitchId gzip awk; do
    command -v "$tool" > /dev/null || die "$tool is not on PATH"
done
[ "$(lastal --version)" = "lastal 1652" ] || die "LAST 1652 is needed, found '$(lastal --version)'"

if command -v md5sum > /dev/null; then
    md5() { md5sum "$1" | cut -d' ' -f1; }
else
    md5() { command md5 -q "$1"; }
fi
# md5 of a MAF without its '#' lines
maf_body_md5() { grep -v '^#' "$1" > "$1.body"; md5 "$1.body"; rm -f "$1.body"; }
same() { [ "$(md5 "$1")" = "$(md5 "$2")" ] || die "${3:-$1 differs from $2: the platform-independent files are not the same on $platform}"; }

if [ -n "$workdir" ]; then
    mkdir -p "$workdir"
    work=$(cd "$workdir" && pwd)
else
    work=$(mktemp -d "${TMPDIR:-/tmp}/wgpa_fixtures.XXXXXX")
    # close the log in the work dir before removing it (an open file keeps an NFS directory from being removed)
    trap 'exec 2>&3; trap - ERR; rm -rf "$work"' EXIT
fi

echo "Platform: $platform"
echo "Tools:    $(command -v axtChain) ($(lastal --version))"
echo "Work dir: $work (tool messages in $work/tools.log)"
# The tools' progress messages go to the log; errors of this script go to the terminal (fd 3)
exec 2>> "$work/tools.log"
trap 'echo "ERROR: a command failed, see $work/tools.log" >&3' ERR

# The v1.0.0 alignment commands (CNEr lastal(), distance "near", one thread), then maf-convert psl.
# $1 target FASTA, $2 query FASTA, $3 output stem; the LAST database is named after the target, as in v1.0.0.
align() {
    local target_fa=$1 query_fa=$2 stem=$3 db
    db=$(basename "$target_fa" .fa)
    [ -e "$db.prj" ] || lastdb -c "$db" "$target_fa"
    lastal -a 600 -b 150 -e 3000 -p "$matrices/near.lastal.mat" -s 2 -f 1 "$db" "$query_fa" > "$stem.maf"
    maf-convert psl "$stem.maf" > "$stem.psl"
}

# The v1.0.0 chain and net commands (CNEr axtChain(), chainMergeSort(), chainPreNet(), chainNetSyntenic() and
# netToAxt(), distance "near"; CNEr also passes the malformed flag '-linearGapmedium', which axtChain ignores),
# then the liftOver chain as in UCSC doBlastzChainNet.pl.
# $1 PSL, $2 target 2bit, $3 query 2bit, $4 target sizes, $5 query sizes, $6 output stem, $7 liftOver chain name.
chain_net() {
    local psl=$1 t2bit=$2 q2bit=$3 tsizes=$4 qsizes=$5 stem=$6 over=$7
    axtChain -psl -minScore=5000 -linearGap=medium -scoreScheme="$matrices/near.axtchain.mat" \
        "$psl" "$t2bit" "$q2bit" "$stem.chain"
    echo "$stem.chain" > "$stem.chain.list"
    chainMergeSort -inputList="$stem.chain.list" > "$stem.all.chain"
    chainPreNet "$stem.all.chain" "$tsizes" "$qsizes" "$stem.all.pre.chain"
    chainNet "$stem.all.pre.chain" "$tsizes" "$qsizes" "$stem.target.net" "$stem.query.net"
    netSyntenic "$stem.target.net" "$stem.noClass.net"
    netToAxt "$stem.noClass.net" "$stem.all.pre.chain" "$t2bit" "$q2bit" "$stem.unsorted.axt"
    axtSort "$stem.unsorted.axt" "$stem.net.axt"
    netChainSubset -verbose=0 "$stem.noClass.net" "$stem.all.chain" "$stem.subset.chain"
    chainStitchId "$stem.subset.chain" "$over"
    # the pipeline pipes the two liftOver steps; the result must be the same
    netChainSubset -verbose=0 "$stem.noClass.net" "$stem.all.chain" stdout | chainStitchId stdin "$over.piped"
    same "$over.piped" "$over" "netChainSubset | chainStitchId differs from the two steps with a file in between"
    rm -f "$over.piped" "$stem.chain.list"
}

# "<md5>  <name>" for each file given, named as in the pipeline outputs
md5_lines() { local f; for f in "$@"; do echo "$(md5 "$f")  $f"; done; }

header() {
    echo "# $1"
    echo "# Platform $platform, made by tests/data/make_platform_fixtures.sh with the v1.0.0 command lines"
    echo "# (LAST 1652, kent 482). md5 of the uncompressed files: \"<md5>  <file name>\"."
}

# ---------------------------------------------------------------------------------------------------------
# yeast_small: target scer_small, query seub_small, preset near
# ---------------------------------------------------------------------------------------------------------
small="$data/yeast_small"
small_out="$outdir/yeast_small/platform/$platform"
mkdir -p "$work/yeast_small" "$small_out"
cd "$work/yeast_small"
echo "== yeast_small -> $small_out"

cp "$small/scer_small.fa" "$small/seub_small.fa" .
for g in scer_small seub_small; do
    faToTwoBit "$g.fa" "$g.2bit"
    twoBitInfo "$g.2bit" "$g.sizes"
    same "$g.2bit" "$small/$g.2bit"
    same "$g.sizes" "$small/$g.sizes"
done

# scer_small -> seub_small: the alignment is the shared small.maf.gz / small.psl
align scer_small.fa seub_small.fa small
gzip -dc "$small/small.maf.gz" > small.shared.maf
same small.maf small.shared.maf
same small.psl "$small/small.psl"
chain_net small.psl scer_small.2bit seub_small.2bit scer_small.sizes seub_small.sizes small small.over.chain

for f in small.chain small.all.chain small.all.pre.chain small.target.net small.query.net small.noClass.net \
         small.unsorted.axt small.net.axt small.subset.chain small.over.chain; do
    cp "$f" "$small_out/$f"
done

# Module test "psl - default score scheme": axtChain without -scoreScheme (its built-in matrix)
axtChain -psl -minScore=5000 -linearGap=medium small.psl scer_small.2bit seub_small.2bit small.noScoreScheme.chain

# Module test "three chains": small.chain split round-robin into three files (each keeps the '#' lines),
# merged with chainMergeSort in file name order, as tests/../chainmergesort/tests/main.nf.test does
for i in 0 1 2; do
    { grep '^#' small.chain || true; awk -v i="$i" '/^#/ { next } /^chain/ { n++ } n && (n - 1) % 3 == i' small.chain; } > "part$i.chain"
done
chainMergeSort part0.chain part1.chain part2.chain > small.3parts.all.chain

# Pipeline tests: seub_small -> scer_small (tests/alignment_input.nf.test, mixed samplesheet) and
# scer_small -> scer_small (tests/samplesheet.nf.test, self-alignment)
align seub_small.fa scer_small.fa seub_small_scer_small
chain_net seub_small_scer_small.psl seub_small.2bit scer_small.2bit seub_small.sizes scer_small.sizes \
    seub_small_scer_small seub_smallToScer_small.over.chain
align scer_small.fa scer_small.fa scer_small_scer_small
chain_net scer_small_scer_small.psl scer_small.2bit scer_small.2bit scer_small.sizes scer_small.sizes \
    scer_small_scer_small scer_smallToScer_small.over.chain

{
    header "Platform-dependent outputs of the yeast_small tests that are not kept as files here."
    echo "# small.noScoreScheme.chain: axtChain as small.chain, without -scoreScheme."
    echo "# small.3parts.all.chain: chainMergeSort of small.chain split round-robin into three files."
    echo "# seub_small_scer_small.*, scer_small_scer_small.*: the pairs seub_small->scer_small and scer_small->scer_small."
    md5_lines small.noScoreScheme.chain small.3parts.all.chain
    for stem in seub_small_scer_small scer_small_scer_small; do
        md5_lines $stem.chain $stem.all.chain $stem.all.pre.chain $stem.target.net $stem.query.net $stem.noClass.net $stem.net.axt
    done
    md5_lines seub_smallToScer_small.over.chain scer_smallToScer_small.over.chain
} > "$small_out/md5.txt"

# ---------------------------------------------------------------------------------------------------------
# yeast: the v1.0.0 test pair, target S_cerevisiae, query S_eubayanus, preset near
# ---------------------------------------------------------------------------------------------------------
if [ "$small_only" = false ]; then
    yeast_out="$outdir/yeast/platform/$platform"
    mkdir -p "$work/yeast" "$yeast_out"
    cd "$work/yeast"
    echo "== yeast -> $yeast_out"
    stem=S_cerevisiae_S_eubayanus

    cp "$data/yeast/S_cerevisiae.fa" "$data/yeast/S_eubayanus.fa" .
    for g in S_cerevisiae S_eubayanus; do
        faToTwoBit "$g.fa" "$g.2bit"
        twoBitInfo "$g.2bit" "$g.sizes"
    done
    align S_cerevisiae.fa S_eubayanus.fa $stem
    # The platform-independent v1.0.0 md5s (tests/data/yeast/v1.0.0_md5.txt)
    shared_md5() { awk -v f="$1" '!/^#/ && $2 == f { print $1 }' "$data/yeast/v1.0.0_md5.txt"; }
    for check in "$stem.maf:$(md5 $stem.maf)" "$stem.maf.body:$(maf_body_md5 $stem.maf)" "$stem.psl:$(md5 $stem.psl)" \
                 "S_cerevisiae.2bit:$(md5 S_cerevisiae.2bit)" "S_eubayanus.2bit:$(md5 S_eubayanus.2bit)"; do
        name=${check%%:*}
        [ "${check#*:}" = "$(shared_md5 "$name")" ] || die "$name differs from tests/data/yeast/v1.0.0_md5.txt: the platform-independent files are not the same on $platform"
    done
    chain_net $stem.psl S_cerevisiae.2bit S_eubayanus.2bit S_cerevisiae.sizes S_eubayanus.sizes $stem S_cerevisiaeToS_eubayanus.over.chain

    {
        header "Platform-dependent v1.0.0 outputs of the v1.0.0 test pair (S_cerevisiae target, S_eubayanus query, near)."
        echo "# The platform-independent ones (MAF, PSL, 2bit) are in tests/data/yeast/v1.0.0_md5.txt."
        md5_lines $stem.all.chain $stem.all.pre.chain $stem.noClass.net $stem.net.axt
    } > "$yeast_out/v1.0.0_md5.txt"
    {
        header "Platform-dependent outputs of the v1.0.0 test pair that v2 publishes and v1.0.0 did not keep."
        echo "# $stem.chain (axtChain) is the same file as $stem.all.chain (v1.0.0_md5.txt)."
        md5_lines $stem.target.net $stem.query.net S_cerevisiaeToS_eubayanus.over.chain
    } > "$yeast_out/md5.txt"
fi

echo "Done. Platform-dependent references for $platform are in $outdir/*/platform/$platform/"
