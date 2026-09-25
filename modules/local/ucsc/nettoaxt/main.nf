process UCSC_NETTOAXT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-nettoaxt:482--h0b57e2e_0' :
        'quay.io/biocontainers/ucsc-nettoaxt:482--h0b57e2e_0' }"

    input:
    tuple val(meta), path(net), path(chain), path(target_twobit), path(query_twobit)

    output:
    tuple val(meta), path("*.axt.gz"), emit: axt
    tuple val("${task.process}"), val('ucsc'), val('482'), topic: versions, emit: versions_ucsc
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    netToAxt \\
        $args \\
        $net \\
        $chain \\
        $target_twobit \\
        $query_twobit \\
        stdout \\
        | gzip -n > ${prefix}.axt.gz
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '' | gzip -n > ${prefix}.axt.gz
    """

}
