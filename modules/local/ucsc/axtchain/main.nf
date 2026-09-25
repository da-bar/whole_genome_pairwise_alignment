process UCSC_AXTCHAIN {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-axtchain:482--h0b57e2e_2' :
        'quay.io/biocontainers/ucsc-axtchain:482--h0b57e2e_2' }"

    input:
    // Target and query are staged in separate folders, so that a self-alignment (the same 2bit file twice) does not collide
    tuple val(meta), path(psl), path(target_twobit, stageAs: 'target/*'), path(query_twobit, stageAs: 'query/*')
    path(score_scheme)

    output:
    tuple val(meta), path("*.chain.gz"), emit: chain
    tuple val("${task.process}"), val('ucsc'), val('482'), topic: versions, emit: versions_ucsc
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def score_scheme_arg = score_scheme ? "-scoreScheme=${score_scheme}" : ''
    // axtChain reads plain or gzipped PSL directly and writes the chains to stdout; progress messages go to stderr.
    // ext.args must include -linearGap=<loose|medium|file>: without it axtChain exits 255 ("Must specify linear gap costs").
    """
    axtChain \\
        -psl \\
        $args \\
        $score_scheme_arg \\
        $psl \\
        $target_twobit \\
        $query_twobit \\
        stdout \\
        | gzip -n > ${prefix}.chain.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '' | gzip -n > ${prefix}.chain.gz
    """
}
