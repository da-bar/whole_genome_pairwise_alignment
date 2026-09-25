# Whole Genome Pairwise Alignment Pipeline

## Introduction

This pipeline is a comprehensive tool for whole genome pairwise alignment using `lastal`. It is designed to facilitate alignment, chaining, and netting of genomic data. The primary objective is to provide an efficient and user-friendly approach to comparative genomics, specifically for aligning entire genomes.

## Requirements

- **Nextflow**: Workflow management that allows the pipeline to be run across multiple compute infrastructures in a portable manner.
- **R**: The pipeline requires R to be installed, along with the `CNEr` package, which is used for handling genomic alignment data.
- **lastal**: A tool used for the alignment step of the pipeline.
- **kentUtils**: A collection of command-line tools for manipulating, analyzing, and visualizing genomic datasets.

## Installation

To install the pipeline, clone the repository from GitHub:

    git clone https://github.com/da-bar/whole_genome_pairwise_alignment.git

## Usage

To run the pipeline, use the following command:

    nextflow run main.nf -c nextflow.config

### Configuration

Configure the pipeline by editing the `nextflow.config` file. A typical configuration might look like this:

    params {
        reference = '/path/to/reference/reference.fasta'
        query = '/path/to/query/query.fasta'
        output = '/path/to/output_folder'
    }

## Parameters

Details about the parameters used in the pipeline will be provided (TBA).

## Process Description

1. **Aligning with lastal**: Performs whole genome alignments using the `lastal` tool.
2. **Chaining the Alignment**: Chains the alignment data for better genomic alignment interpretation.
3. **Netting the Chains**: Applies a netting process on the chained data to filter and refine alignments.
4. **Export in axt Format**: The final alignments are exported in the `axt` file format for further analysis.

## Output

The pipeline produces several outputs, including:

- Alignment in MAF (Multiple Alignment Format) file.
- Alignment in PSL (Pairwise Sequence Alignment) format.
- Chained alignment files.
- Filtered chains and syntenic nets.
- Final netted alignment in AXT format.

## Example

An example Nextflow config, along with test genomes of _S. cerevisiae_ and _S. eubayanus_, will be included in the GitHub repository.

## Contributing

Contributions to the pipeline are welcome. Please raise an issue or a pull request on the GitHub repository. For direct communication, contact the author via email.

## License

This software is available under the MIT license. Please refer to the [LICENSE](LICENSE) file in the repository for more details.

## Third-party software

This pipeline relies on external tools: CNEr, kentUtils, and the LAST aligner. It does not distribute these tools or incorporate their source code. Users are responsible for obtaining them and complying with their licences independently:

- **CNEr** is used for handling genomic alignment data. Users should adhere to the terms and conditions set forth by the authors of CNEr.
- **kentUtils** is a suite of biological analysis and web display programs developed by the UCSC Genome Bioinformatics Group and Jim Kent. Use of these utilities through this pipeline should comply with their licensing terms.
- **LAST** is used for sequence alignment. Users should comply with the licensing terms of the LAST aligner.

Users intending to use this pipeline for commercial purposes should consult and adhere to the licensing terms of CNEr, kentUtils, and the LAST aligner, as this pipeline operates in conjunction with these tools.

## Citation

If you use this pipeline in your research, please cite the CNEr paper:

https://doi.org/10.1371/journal.pcbi.1006940
