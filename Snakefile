SAMPLES = ["SRR2584403_1", "SRR2584404_1", "SRR2584405_1", "SRR2584857_1", "SRR2584857_2"]

GENOME = ["ecoli-rel606"]

VARIANTS = VARIANTS = [920514, 4141016, 1329520, 238917, 806308, 1329520, 649522, 708118, 1733754, 2103887, 3762120, 3931002, 4141441, 4202391, 4530767, 4530767]

rule make_vcf:
    input:
        expand("outputs/{sample}.x.{genome}.vcf",
               sample=SAMPLES, genome=GENOME),
        expand("outputs/variant-closest-{variant}.gene-report.txt",
               variant=VARIANTS),

rule uncompress_genome:
    input: "{genome}.fa.gz"
    output: "outputs/{genome}.fa"
    shell: """
        gunzip -c {input} > {output}
    """

rule map_reads:
    input:
        reads="{reads}.fastq",
        ref="outputs/{genome}.fa"
    output: "outputs/{reads}.x.{genome}.sam"
    shell: """
        minimap2 -ax sr {input.ref} {input.reads} > {output}
    """

rule sam_to_bam:
    input: "outputs/{reads}.x.{genome}.sam",
    output: "outputs/{reads}.x.{genome}.bam",
    shell: """
        samtools view -b {input} > {output}
     """

rule sort_bam:
    input: "outputs/{reads}.x.{genome}.bam"
    output: "outputs/{reads}.x.{genome}.bam.sorted"
    shell: """
        samtools sort {input} > {output}
    """

rule index_bam:
    input: "outputs/{reads}.x.{genome}.bam.sorted"
    output: "outputs/{reads}.x.{genome}.bam.sorted.bai"
    shell: """
        samtools index {input}
    """

rule call_variants:
    input:
        ref="outputs/{genome}.fa",
        bam="outputs/{reads}.x.{genome}.bam.sorted",
        bai="outputs/{reads}.x.{genome}.bam.sorted.bai",
    output:
        pileup="outputs/{reads}.x.{genome}.pileup",
        bcf="outputs/{reads}.x.{genome}.bcf",
        vcf="outputs/{reads}.x.{genome}.vcf",
    shell: """
        bcftools mpileup -Ou -f {input.ref} {input.bam} > {output.pileup}
        bcftools call -mv -Ob {output.pileup} -o {output.bcf} --ploidy 1
        bcftools view {output.bcf} > {output.vcf}
    """

rule sort_gff:
    input: "ecoli-rel606.gff.gz"
    output: "outputs/ecoli-rel606.sorted.gff"
    shell: """
       bedtools sort -i {input} > {output}
    """

rule select_genes:
    input: "outputs/ecoli-rel606.sorted.gff"
    output: "outputs/ecoli-rel606.gene.gff"
    shell: """
        awk -F'\t' '$3 == "gene"' {input} > {output}
    """

rule closest_by_variant:
    input:
        gff="outputs/ecoli-rel606.gene.gff"
    output:
        bed="outputs/variant-{variant}.bed",
        report="outputs/variant-closest-{variant}.gene-report.txt"
    params:
        variant_end = lambda w: int(w.variant) + 1
    shell: """
       # create BED file
       echo -e "ecoli\\t{wildcards.variant}\\t{params.variant_end}\\tvariant{wildcards.variant}" > {output.bed}

       bedtools closest -a {output.bed} -b {input.gff} -wb -d > {output.report}
    """
