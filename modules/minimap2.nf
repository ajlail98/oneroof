process ALIGN_WITH_PRESET {

    tag "${barcode}, ${platform}"

	errorStrategy { task.attempt < 3 ? 'retry' : 'ignore' }
	maxRetries 2

    input:
    tuple val(barcode), path(fastq)
    each path(refseq)
    each path(platform)

    output:
    tuple val(barcode), path("${barcode}.sam")

    script:
    preset = platform == "ont" ? "map-ont" : "sr"
    """
    minimap2 -ax ${preset} ${refseq} <(zcat ${fastq}) > ${barcode}.sam
    """

}

