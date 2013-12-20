PlotGenome
==========
use:

Default also looks for <varscan.called>.homdels so enable the homdels output
 - perl $0 -d \<human.dict\> \<varscan.called\>

By region
 - perl $0 -d \<human.dict\> -r 1,1,1000000 \<varscan.called\>

Also plot f/z vals:
 - perl $0 -d \<human.dict\> \<varscan.called\> \<vcf.table\>

note: actual use example

 <code> {GATK best practices alignment using BWA}
 
 <code> samtools mpileup \\ <br>-R -q 40 -f human_g1k_v37.fasta Normal.human_g1k_v37.merged.bam Tumor.human_g1k_v37.merged.bam | \\ <br>java -Xmx2g -jar ${HOME}/software/VarScan.v2.3.2/VarScan.v2.3.2.jar copynumber \\ <br>- tumor --mpileup --min-segment-size 200  --max-segment-size 500;<br> java -jar -Xmx2g -jar ${HOME}/software/VarScan.v2.3.2/VarScan.v2.3.2.jar copyCaller \\ <br> tumor.copynumber  --output-file tumor.called;<br> perl PlotFloatsOnInterVals0.0.3.pl -v Snps.GatkVariantsToTable.table tumor.called > tumor.called.Rscript; <br> Rscript tumor.called.Rscript ; <br>

==========

Prereqisites
==========
- VCF file: calculate F values with script in perlIncludeVcf.pm repository
- Varscan analysis has to be performed ("http://varscan.sourceforge.net/")
- R(script) + DNAcopy library to be installed and working 
  - start R and paste
  - <code>source("http://bioconductor.org/biocLite.R");biocLite("DNAcopy")

