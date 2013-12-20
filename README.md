PlotGenome
==========
use:
perl $0 -d <human.dict> <varscan.called> #default also looks for <varscan.called>.homdels so enable the homdels output
perl $0 -d <human.dict> -r 1,1,1000000 <varscan.called> #by region
perl $0 -d <human.dict> <varscan.called> <vcf.table> #also plot f/z vals
#note: the 
my actual use:
{GATK best practices alignment using BWA}
samtools mpileup \
 -R -q 40 -f human_g1k_v37.fasta \
 Normal.human_g1k_v37.merged.bam Tumor.human_g1k_v37.merged.bam | \
java -Xmx2g -jar ${HOME}/software/VarScan.v2.3.2/VarScan.v2.3.2.jar copynumber \
 - tumor --mpileup --min-segment-size 200 --max-segment-size 500
java -jar -Xmx2g -jar ${HOME}/software/VarScan.v2.3.2/VarScan.v2.3.2.jar copyCaller tumor.copynumber --output-file tumor.called
perl /home/terpstramm/workspace/PlotGenome/PlotFloatsOnInterVals0.0.3.pl -v Snps.GatkVariantsToTable.table tumor.called > tumor.called.Rscript;
Rscript \$i.Rscript ;


#needs Rscript to be installed and working
Notes for installing required R library (Needs DNAcopy for installing):
==========
R
source("http://bioconductor.org/biocLite.R")
biocLite("DNAcopy")

#Varscan Download from Sourceforge
http://varscan.sourceforge.net/