//
// Align each query genome to its target genome with LAST and convert the alignments to PSL
//

include { LAST_LASTDB     } from '../../../modules/nf-core/last/lastdb'
include { LAST_LASTAL     } from '../../../modules/nf-core/last/lastal'
include { LAST_MAFCONVERT } from '../../../modules/nf-core/last/mafconvert'

workflow PAIRWISE_ALIGN {

    take:
    ch_pairs         // channel: [ val(meta), path(target_fasta), path(query_fasta) ]
    ch_lastal_matrix // channel: [ val(meta), path(lastal_matrix) ], the preset's scoring matrix for lastal -p

    main:

    //
    // Build one LAST index per distinct (target FASTA, lastdb arguments)
    //
    def ch_lastdb_in = ch_pairs
        .map { meta, target, _query ->
            [ [ id: meta.target_name, lastdb_args: lastdbArgs(meta.preset) ], target ]
        }
        .unique { meta, target -> [ target.toUriString(), meta.lastdb_args ] }

    LAST_LASTDB ( ch_lastdb_in )

    //
    // LAST_LASTAL takes the query and the index as two separate inputs. Build one combined channel per
    // pair and split it with multiMap so that the two inputs stay in lockstep.
    // The target name is unique per FASTA file (checked in PIPELINE_INITIALISATION).
    //
    def ch_index = LAST_LASTDB.out.index
        .map { meta, index -> [ [ meta.id, meta.lastdb_args ], index ] }

    def ch_lastal_in = ch_pairs
        .join(ch_lastal_matrix, failOnDuplicate: true)
        .map { meta, _target, query, matrix -> [ [ meta.target_name, lastdbArgs(meta.preset) ], meta, query, matrix ] }
        .combine(ch_index, by: 0)
        .multiMap { _key, meta, query, matrix, index ->
            query: [ meta, query, matrix ]
            index: index
        }

    LAST_LASTAL ( ch_lastal_in.query, ch_lastal_in.index )

    //
    // MAF to PSL, the input of axtChain (no reference files are needed for PSL)
    //
    LAST_MAFCONVERT (
        LAST_LASTAL.out.maf.map { meta, maf -> [ meta, maf, 'psl' ] },
        [ [:], [], [], [], [], [] ]
    )

    emit:
    maf   = LAST_LASTAL.out.maf              // channel: [ val(meta), path(maf.gz) ]
    stats = LAST_LASTAL.out.multiqc          // channel: [ val(meta), path(tsv) ]
    psl   = LAST_MAFCONVERT.out.alignment    // channel: [ val(meta), path(psl.gz) ]
}

//
// lastdb arguments for a preset. CNEr indexes the target with 'lastdb -c' for every preset (lowercase,
// i.e. soft-masked, bases are excluded from initial matches), so pairs with the same target FASTA share
// one index whatever their preset. The value is passed to LAST_LASTDB as meta.lastdb_args
// (conf/modules.config) because it is part of the key that decides which pairs share an index.
//
def lastdbArgs(preset) {
    def args = [
        near   : '-c',
        medium : '-c',
        far    : '-c',
    ]
    if (!args.containsKey(preset)) {
        error("Unknown preset '${preset}': expected one of ${args.keySet().join(', ')}")
    }
    return args[preset]
}
