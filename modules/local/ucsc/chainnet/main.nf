process UCSC_CHAINNET {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-chainnet:482--h0b57e2e_0' :
        'quay.io/biocontainers/ucsc-chainnet:482--h0b57e2e_0' }"

    input:
    // Target and query are staged in separate folders, so that a self-alignment (the same sizes file twice) does not collide
    tuple val(meta), path(chain), path(target_sizes, stageAs: 'target/*'), path(query_sizes, stageAs: 'query/*')

    output:
    tuple val(meta), path("*.target.net.gz"), emit: target_net
    tuple val(meta), path("*.query.net.gz") , emit: query_net
    tuple val("${task.process}"), val('ucsc'), val('482'), topic: versions, emit: versions_ucsc
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    chainNet \\
        $args \\
        $chain \\
        $target_sizes \\
        $query_sizes \\
        stdout \\
        ${prefix}.query.net \\
        | gzip -n > ${prefix}.target.net.gz

    gzip -n ${prefix}.query.net
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '' | gzip -n > ${prefix}.target.net.gz
    printf '' | gzip -n > ${prefix}.query.net.gz
    """
}
