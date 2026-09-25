process UCSC_CHAINMERGESORT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-chainmergesort:482--h0b57e2e_0' :
        'quay.io/biocontainers/ucsc-chainmergesort:482--h0b57e2e_0' }"

    input:
    tuple val(meta), path(chains)

    output:
    tuple val(meta), path("*.chain.gz"), emit: chain
    tuple val("${task.process}"), val('ucsc'), val('482'), topic: versions, emit: versions_ucsc
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // chainMergeSort breaks score ties by input order, so pass the files sorted by name to keep the output
    // independent of the order in which they arrive on the channel. It reads plain or gzipped chains directly.
    def chain_files = [chains].flatten().sort { f -> f.name }
    if (chain_files.any { f -> f.name == "${prefix}.chain.gz" }) error "Input and output names are the same, use \"task.ext.prefix\" to disambiguate!"
    """
    chainMergeSort \\
        $args \\
        ${chain_files.join(' ')} \\
        | gzip -n > ${prefix}.chain.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '' | gzip -n > ${prefix}.chain.gz
    """
}
