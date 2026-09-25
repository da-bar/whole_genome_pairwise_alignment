/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_wgpa_pipeline'
include { PREPARE_GENOMES        } from '../subworkflows/local/prepare_genomes'
include { PAIRWISE_ALIGN         } from '../subworkflows/local/pairwise_align'
include { CHAIN_NET              } from '../subworkflows/local/chain_net'
include { LIFTOVER_CHAINS        } from '../subworkflows/local/liftover_chains'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow WGPA {

    take:
    ch_samplesheet // channel: [ val(meta), path(target_fasta), path(query_fasta) ], meta = [ id, preset, target_name, query_name ]
    outdir         //  string: output directory
    liftover       // boolean: make liftOver chains

    main:

    def ch_versions = channel.empty()

    //
    // Scoring matrices of each pair's preset (CNEr near/medium/far), from assets/matrices
    //
    def ch_matrices = ch_samplesheet
        .map { meta, _target, _query ->
            [
                meta,
                file("${projectDir}/assets/matrices/${meta.preset}.lastal.mat", checkIfExists: true),
                file("${projectDir}/assets/matrices/${meta.preset}.axtchain.mat", checkIfExists: true),
            ]
        }

    //
    // SUBWORKFLOW: 2bit and sizes, once per distinct genome FASTA
    //
    PREPARE_GENOMES ( ch_samplesheet )

    //
    // SUBWORKFLOW: LAST alignment of the query to the target, MAF and PSL
    //
    PAIRWISE_ALIGN (
        ch_samplesheet,
        ch_matrices.map { meta, lastal_matrix, _axtchain_matrix -> [ meta, lastal_matrix ] }
    )

    //
    // SUBWORKFLOW: chains, nets and net alignments (axt)
    //
    CHAIN_NET (
        PAIRWISE_ALIGN.out.psl,
        PREPARE_GENOMES.out.genomes,
        ch_matrices.map { meta, _lastal_matrix, axtchain_matrix -> [ meta, axtchain_matrix ] }
    )

    //
    // SUBWORKFLOW: liftOver chains
    //
    if (liftover) {
        LIFTOVER_CHAINS (
            CHAIN_NET.out.net,
            CHAIN_NET.out.all_chain
        )
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'wgpa_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )
    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
