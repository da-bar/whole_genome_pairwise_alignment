process CHECK_ALIGNMENT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a1/a125c778baf3865331101a104b60d249ee15fe1dca13bdafd888926cc5490a34/data' :
        'community.wave.seqera.io/library/gawk:5.3.1--e09efb5dfc4b8156' }"

    input:
    // Target and query are staged in separate folders, so that a self-alignment (the same sizes file twice) does not collide
    tuple val(meta), path(alignment), path(target_sizes, stageAs: 'target/*'), path(query_sizes, stageAs: 'query/*')

    output:
    // The alignment, unchanged, once it has passed the check
    tuple val(meta), path(alignment, includeInputs: true), emit: alignment
    tuple val("${task.process}"), val('gawk'), eval("awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//'"), topic: versions, emit: versions_gawk

    when:
    task.ext.when == null || task.ext.when

    script:
    // MAF: the first sequence of each block is the target, the second the query (name and length: fields 2 and 6).
    // PSL: the query is in columns 10-11 (qName, qSize) and the target in columns 14-15 (tName, tSize); the first
    // 5 lines may be a psLayout header. Plain or gzipped input. The check fails if an alignment sequence is not
    // in the pair's sizes file or has another length there, and says when target and query look swapped.
    def format = alignment.name =~ /\.maf(\.gz)?$/ ? 'maf' : 'psl'
    """
    gzip -cdf $alignment \\
        | awk \\
            -v pair='${meta.id}' \\
            -v format='${format}' \\
            -v target_name='${meta.target_name}' \\
            -v query_name='${meta.query_name}' \\
            -v target_sizes='${target_sizes}' \\
            -v query_sizes='${query_sizes}' \\
            '
            function add(list, item) { return list == "" ? item : list ", " item }
            function seen(role, name, len) {
                if (role == "t" && !(name in t_len)) { t_n++; t_names[t_n] = name; t_len[name] = len }
                if (role == "q" && !(name in q_len)) { q_n++; q_names[q_n] = name; q_len[name] = len }
            }
            BEGIN {
                while ((getline line < target_sizes) > 0) { split(line, f, "\\t"); t_size[f[1]] = f[2] }
                while ((getline line < query_sizes) > 0)  { split(line, f, "\\t"); q_size[f[1]] = f[2] }
            }
            format == "maf" && \$1 == "a" { row = 0; next }
            format == "maf" && \$1 == "s" {
                if (NF != 7) { error = "line " NR " of the MAF file is not a valid s line"; exit 1 }
                row++
                if (row == 1) { seen("t", \$2, \$6); records++ }
                else if (row == 2) seen("q", \$2, \$6)
                else { error = "line " NR " of the MAF file is a third sequence in one alignment block; only pairwise MAF files are supported"; exit 1 }
                next
            }
            format == "psl" && NF == 21 && \$1 ~ /^[0-9]+\$/ { seen("q", \$10, \$11); seen("t", \$14, \$15); records++; next }
            format == "psl" && NR > 5 && NF > 0 { error = "line " NR " of the PSL file is not a PSL record (21 tab-separated columns)"; exit 1 }
            END {
                if (error == "" && records == 0) error = "the alignment file contains no alignments"
                if (error != "") {
                    print "ERROR: Pair \\x27" pair "\\x27: " error "." > "/dev/stderr"
                    exit 1
                }
                for (i = 1; i <= t_n; i++) {
                    n = t_names[i]
                    if (!(n in t_size)) { t_missing++; if (t_missing <= 5) t_missing_list = add(t_missing_list, n) }
                    else if (t_size[n] != t_len[n]) { t_diff++; if (t_diff <= 5) t_diff_list = add(t_diff_list, n " (" t_len[n] " in the alignment, " t_size[n] " in the FASTA)") }
                    if (!(n in q_size) || q_size[n] != t_len[n]) t_not_query++
                }
                for (i = 1; i <= q_n; i++) {
                    n = q_names[i]
                    if (!(n in q_size)) { q_missing++; if (q_missing <= 5) q_missing_list = add(q_missing_list, n) }
                    else if (q_size[n] != q_len[n]) { q_diff++; if (q_diff <= 5) q_diff_list = add(q_diff_list, n " (" q_len[n] " in the alignment, " q_size[n] " in the FASTA)") }
                    if (!(n in t_size) || t_size[n] != q_len[n]) q_not_target++
                }
                if (t_missing + t_diff + q_missing + q_diff == 0) exit 0

                print "ERROR: Pair \\x27" pair "\\x27: the sequences of its alignment (samplesheet column \\x27alignment\\x27) are not those of its target and query FASTA files." > "/dev/stderr"
                if (t_missing) print "  " t_missing " of the " t_n " target sequences of the alignment are not in the target FASTA (" target_name "), e.g. " t_missing_list > "/dev/stderr"
                if (t_diff)    print "  " t_diff " of the " t_n " target sequences of the alignment have another length in the target FASTA (" target_name "), e.g. " t_diff_list > "/dev/stderr"
                if (q_missing) print "  " q_missing " of the " q_n " query sequences of the alignment are not in the query FASTA (" query_name "), e.g. " q_missing_list > "/dev/stderr"
                if (q_diff)    print "  " q_diff " of the " q_n " query sequences of the alignment have another length in the query FASTA (" query_name "), e.g. " q_diff_list > "/dev/stderr"
                if (t_not_query == 0 && q_not_target == 0) {
                    print "  Target and query look swapped: the target sequences of the alignment are those of " query_name " and its query sequences those of " target_name "." > "/dev/stderr"
                    print "  The alignment must have the samplesheet target as its reference. Swap target and query in the samplesheet if " query_name " should be the target, or align again with " target_name " as the target." > "/dev/stderr"
                } else {
                    print "  Check that the alignment was made from these two FASTA files, with the samplesheet target as the reference (the first sequence of each MAF block, PSL columns 14-15) and the query as the second sequence (PSL columns 10-11)." > "/dev/stderr"
                }
                exit 1
            }
            '
    """

    stub:
    """
    # The stub passes the alignment through unchecked
    """
}
