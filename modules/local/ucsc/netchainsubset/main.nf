process UCSC_NETCHAINSUBSET {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-netchainsubset:482--h0b57e2e_0' :
        'quay.io/biocontainers/ucsc-netchainsubset:482--h0b57e2e_0' }"

    input:
    tuple val(meta), path(net), path(chain)

    output:
    tuple val(meta), path("*.chain.gz"), emit: chain
    tuple val("${task.process}"), val('ucsc'), val('482'), topic: versions, emit: versions_ucsc
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$chain" == "${prefix}.chain.gz") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    """
    netChainSubset \\
        $args \\
        $net \\
        $chain \\
        stdout \\
        | gzip -n > ${prefix}.chain.gz
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$chain" == "${prefix}.chain.gz") error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    """
    printf '' | gzip -n > ${prefix}.chain.gz
    """

}
