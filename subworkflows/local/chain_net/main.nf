//
// Chain and net the pairwise alignments with the UCSC kent tools, as CNEr (and v1.0.0) does
//

include { UCSC_AXTCHAIN       } from '../../../modules/local/ucsc/axtchain'
include { UCSC_CHAINMERGESORT } from '../../../modules/local/ucsc/chainmergesort'
include { UCSC_CHAINPRENET    } from '../../../modules/local/ucsc/chainprenet'
include { UCSC_CHAINNET       } from '../../../modules/local/ucsc/chainnet'
include { UCSC_NETSYNTENIC    } from '../../../modules/local/ucsc/netsyntenic'
include { UCSC_NETTOAXT       } from '../../../modules/local/ucsc/nettoaxt'
include { UCSC_AXTSORT        } from '../../../modules/local/ucsc/axtsort'

workflow CHAIN_NET {

    take:
    ch_psl          // channel: [ val(meta), path(psl) ]
    ch_genomes      // channel: [ val(meta), path(target_2bit), path(target_sizes), path(query_2bit), path(query_sizes) ]
    ch_score_scheme // channel: [ val(meta), path(axtchain_matrix) ], the preset's matrix for axtChain -scoreScheme

    main:

    def ch_twobits = ch_genomes
        .map { meta, target_twobit, _target_sizes, query_twobit, _query_sizes -> [ meta, target_twobit, query_twobit ] }
    def ch_sizes = ch_genomes
        .map { meta, _target_twobit, target_sizes, _query_twobit, query_sizes -> [ meta, target_sizes, query_sizes ] }

    //
    // PSL -> chains. UCSC_AXTCHAIN takes the score scheme as a separate input: split one combined
    // channel with multiMap so that each pair gets its own preset's matrix.
    //
    def ch_axtchain_in = ch_psl
        .join(ch_twobits, failOnDuplicate: true)
        .join(ch_score_scheme, failOnDuplicate: true)
        .multiMap { meta, psl, target_twobit, query_twobit, score_scheme ->
            psl: [ meta, psl, target_twobit, query_twobit ]
            score_scheme: score_scheme
        }

    UCSC_AXTCHAIN ( ch_axtchain_in.psl, ch_axtchain_in.score_scheme )

    // <target>_<query>.all.chain
    UCSC_CHAINMERGESORT ( UCSC_AXTCHAIN.out.chain )

    // <target>_<query>.all.pre.chain
    UCSC_CHAINPRENET (
        UCSC_CHAINMERGESORT.out.chain.join(ch_sizes, failOnDuplicate: true)
    )

    // <target>_<query>.target.net and .query.net
    UCSC_CHAINNET (
        UCSC_CHAINPRENET.out.chain.join(ch_sizes, failOnDuplicate: true)
    )

    // <target>_<query>.noClass.net: the target-referenced net with synteny information
    UCSC_NETSYNTENIC ( UCSC_CHAINNET.out.target_net )

    // <target>_<query>.net.axt: the alignments of the net, sorted by target position
    UCSC_NETTOAXT (
        UCSC_NETSYNTENIC.out.net
            .join(UCSC_CHAINPRENET.out.chain, failOnDuplicate: true)
            .join(ch_twobits, failOnDuplicate: true)
    )
    UCSC_AXTSORT ( UCSC_NETTOAXT.out.axt )

    emit:
    chain      = UCSC_AXTCHAIN.out.chain       // channel: [ val(meta), path(chain.gz) ]
    all_chain  = UCSC_CHAINMERGESORT.out.chain // channel: [ val(meta), path(all.chain.gz) ]
    pre_chain  = UCSC_CHAINPRENET.out.chain    // channel: [ val(meta), path(all.pre.chain.gz) ]
    target_net = UCSC_CHAINNET.out.target_net  // channel: [ val(meta), path(target.net.gz) ]
    query_net  = UCSC_CHAINNET.out.query_net   // channel: [ val(meta), path(query.net.gz) ]
    net        = UCSC_NETSYNTENIC.out.net      // channel: [ val(meta), path(noClass.net.gz) ]
    axt        = UCSC_AXTSORT.out.axt          // channel: [ val(meta), path(net.axt.gz) ]
}
