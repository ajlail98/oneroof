#!/usr/bin/env nextflow

include { VALIDATE_PRIMER_BED      } from "../modules/validate"
include { REPORT_REFERENCES        } from "../modules/reporting"
include { RESPLICE_PRIMERS         } from "../modules/resplice_primers"
include { SPLIT_PRIMER_COMBOS      } from "../modules/split_primer_combos"
include { GET_PRIMER_PATTERNS      } from "../modules/primer_patterns"
include { GET_PRIMER_SEQS          } from "../modules/bedtools"
include { TRIM_ENDS_TO_PRIMERS     } from "../modules/cutadapt"
include { FAIDX                    } from "../modules/samtools"
include { ORIENT_READS             } from "../modules/vsearch"
include {
    FIND_COMPLETE_AMPLICONS ;
    MERGE_BY_SAMPLE ;
    AMPLICON_STATS
} from "../modules/seqkit"
include { FILTER_WITH_CHOPPER      } from "../modules/chopper"
include { RASUSA_READ_DOWNSAMPLING } from "../modules/rasusa"


workflow PRIMER_HANDLING {
    take:
    ch_basecalls
    ch_primer_bed
    ch_refseq

    main:

    VALIDATE_PRIMER_BED(
        ch_primer_bed
    )

    REPORT_REFERENCES(
        VALIDATE_PRIMER_BED.out
    )

    RESPLICE_PRIMERS(
        VALIDATE_PRIMER_BED.out
    )

    SPLIT_PRIMER_COMBOS(
        RESPLICE_PRIMERS.out
    )

    GET_PRIMER_SEQS(
        SPLIT_PRIMER_COMBOS.out.flatten(),
        ch_refseq,
    )

    GET_PRIMER_PATTERNS(
        GET_PRIMER_SEQS.out
    )

    ORIENT_READS(
        ch_basecalls.map { barcode, fastq -> tuple(barcode, file(fastq), file(fastq).countFastq()) }.filter { it[2] > 100 }.map { barcode, fastq, _read_count -> tuple(barcode, file(fastq)) },
        ch_refseq,
    )

    FIND_COMPLETE_AMPLICONS(
        ORIENT_READS.out.map { _barcode, fastq -> fastq }.combine(GET_PRIMER_PATTERNS.out)
    )

    TRIM_ENDS_TO_PRIMERS(
        FIND_COMPLETE_AMPLICONS.out
    )

    FILTER_WITH_CHOPPER(
        TRIM_ENDS_TO_PRIMERS.out.map { id, fastq -> tuple(id, fastq, file(fastq).countFastq()) }.filter { it[2] > 0 }.map { id, fastq, _read_count -> tuple(id, file(fastq)) }
    )

    FAIDX(
        FILTER_WITH_CHOPPER.out.map { id, fastq -> tuple(id, fastq, file(fastq).countFastq()) }.filter { it[2] > 0 }.map { id, fastq, _read_count -> tuple(id, file(fastq)) }
    )

    RASUSA_READ_DOWNSAMPLING(
        FAIDX.out
    )

    AMPLICON_STATS(
        RASUSA_READ_DOWNSAMPLING.out.groupTuple(by: 0)
    )

    MERGE_BY_SAMPLE(
        RASUSA_READ_DOWNSAMPLING.out.groupTuple(by: 0)
    )

    emit:
    MERGE_BY_SAMPLE.out
}
