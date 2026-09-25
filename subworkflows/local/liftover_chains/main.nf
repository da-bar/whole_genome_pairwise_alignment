//
// Make UCSC liftOver chains (<target>To<Query>.over.chain.gz) from the syntenic net, as UCSC
// doBlastzChainNet.pl does: netChainSubset -verbose=0 noClass.net all.chain stdout | chainStitchId stdin stdout
//

include { UCSC_NETCHAINSUBSET } from '../../../modules/local/ucsc/netchainsubset'
include { UCSC_CHAINSTITCHID  } from '../../../modules/local/ucsc/chainstitchid'

workflow LIFTOVER_CHAINS {

    take:
    ch_net       // channel: [ val(meta), path(noClass.net) ], syntenic net of each pair
    ch_all_chain // channel: [ val(meta), path(all.chain) ], all chains of each pair (before chainPreNet)

    main:

    UCSC_NETCHAINSUBSET (
        ch_net.join(ch_all_chain, failOnDuplicate: true)
    )
    UCSC_CHAINSTITCHID ( UCSC_NETCHAINSUBSET.out.chain )

    emit:
    over_chain = UCSC_CHAINSTITCHID.out.chain // channel: [ val(meta), path(over.chain.gz) ]
}
