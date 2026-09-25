//
// Subworkflow with functionality specific to the da-bar/wgpa pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { paramsHelp                } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet
    preset            //  string: Default preset for pairs whose preset column is empty
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //

    def before_text = ""
    def after_text = ""
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        null  // cast CLI parameters to their schema types (nf-schema default with the strict syntax parser), so that e.g. --liftover false is a boolean
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //

    // One row per genome pair: [ meta, target_fasta, query_fasta ] with
    // meta = [ id, preset, target_name, query_name ]
    def pairs = samplesheetToList(input, "${projectDir}/assets/schema_input.json")
        .collect { row -> createPairMeta(row, preset) }
    validateInputSamplesheet(pairs)

    ch_samplesheet = channel.fromList(pairs)

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)

    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Genome name used in output file names: the FASTA file name without .fa/.fasta/.fna(.gz), as in v1.0.0
//
def genomeName(fasta) {
    return fasta.name.replaceFirst(/\.(fa|fasta|fna)(\.gz)?$/, '')
}

//
// Build the pair meta map from a samplesheet row
//
def createPairMeta(row, default_preset) {
    def (meta, target, query) = row
    def pair_meta = [
        id          : meta.id,
        preset      : meta.preset ?: default_preset,
        target_name : genomeName(target),
        query_name  : genomeName(query),
    ]
    return [ pair_meta, target, query ]
}

//
// Validate the genome pairs from the input samplesheet
//
def validateInputSamplesheet(pairs) {
    // Output files (genomes/<name>.2bit, <target_name>_<query_name>.*) are named after the FASTA files,
    // so two different FASTA files must not share a name. The same file may appear in any number of pairs.
    def files_by_name = [:]
    pairs.each { meta, target, query ->
        files_by_name.get(meta.target_name, [] as Set) << target.toUriString()
        files_by_name.get(meta.query_name, [] as Set) << query.toUriString()
        if (target.toUriString() == query.toUriString()) {
            log.warn("Pair '${meta.id}' aligns ${target.name} to itself: the chains will contain the trivial self-alignment")
        }
    }
    def clashes = files_by_name.findAll { _name, files -> files.size() > 1 }
    if (clashes) {
        def details = clashes.collect { name, files -> "  ${name}: ${files.sort().join(', ')}" }.join('\n')
        error("Please check input samplesheet -> different FASTA files give the same genome name, rename them so that each name is unique:\n${details}")
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // In-text citations of the tools used by the pipeline (the pipeline does not run MultiQC)
    def citation_text = [
            "Tools used in the workflow included:",
            "LAST (Kiełbasa et al. 2011),",
            "the UCSC kent utilities for chains and nets (Kent et al. 2003)",
            "with the alignment presets of CNEr (Tan et al. 2019)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    def reference_text = [
            "<li>Kiełbasa SM, Wan R, Sato K, Horton P, Frith MC (2011). Adaptive seeds tame genomic sequence comparison. Genome Research, 21(3), 487-493. doi: 10.1101/gr.113985.110</li>",
            "<li>Kent WJ, Baertsch R, Hinrichs A, Miller W, Haussler D (2003). Evolution's cauldron: duplication, deletion, and rearrangement in the mouse and human genomes. Proceedings of the National Academy of Sciences, 100(20), 11484-11489. doi: 10.1073/pnas.1932072100</li>",
            "<li>Tan G, Polychronopoulos D, Lenhard B (2019). CNEr: A toolkit for exploring extreme noncoding conservation. PLoS Computational Biology, 15(8), e1006940. doi: 10.1371/journal.pcbi.1006940</li>",
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
