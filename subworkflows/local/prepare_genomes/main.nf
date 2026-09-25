//
// Convert every distinct genome FASTA to 2bit and sizes, then attach them to each pair
//

include { UCSC_FATOTWOBIT } from '../../../modules/local/ucsc/fatotwobit'
include { UCSC_TWOBITINFO } from '../../../modules/local/ucsc/twobitinfo'

workflow PREPARE_GENOMES {

    take:
    ch_pairs // channel: [ val(meta), path(target_fasta), path(query_fasta) ]

    main:

    //
    // A genome can be the target of one pair and the query of another, and can appear in any number of
    // pairs: convert each distinct FASTA file (keyed by its absolute path) only once
    //
    def ch_fasta = ch_pairs
        .flatMap { meta, target, query ->
            [
                [ [ id: meta.target_name ], target ],
                [ [ id: meta.query_name ], query ],
            ]
        }
        .unique { _meta, fasta -> fasta.toUriString() }

    UCSC_FATOTWOBIT ( ch_fasta )
    UCSC_TWOBITINFO ( UCSC_FATOTWOBIT.out.twobit )

    //
    // Join the genome files back to each pair. PIPELINE_INITIALISATION has checked that every genome
    // name belongs to exactly one FASTA file, so the name is a safe join key.
    //
    def ch_genomes = UCSC_FATOTWOBIT.out.twobit
        .join(UCSC_TWOBITINFO.out.sizes, failOnDuplicate: true)
        .map { meta, twobit, sizes -> [ meta.id, twobit, sizes ] }

    def ch_pair_genomes = ch_pairs
        .map { meta, _target, _query -> [ meta.target_name, meta ] }
        .combine(ch_genomes, by: 0)
        .map { _name, meta, target_twobit, target_sizes -> [ meta.query_name, meta, target_twobit, target_sizes ] }
        .combine(ch_genomes, by: 0)
        .map { _name, meta, target_twobit, target_sizes, query_twobit, query_sizes ->
            [ meta, target_twobit, target_sizes, query_twobit, query_sizes ]
        }

    emit:
    twobit  = UCSC_FATOTWOBIT.out.twobit // channel: [ val(meta), path(2bit) ], one per distinct FASTA
    sizes   = UCSC_TWOBITINFO.out.sizes  // channel: [ val(meta), path(sizes) ], one per distinct FASTA
    genomes = ch_pair_genomes            // channel: [ val(meta), path(target_2bit), path(target_sizes), path(query_2bit), path(query_sizes) ], one per pair
}
