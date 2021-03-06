#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
#use List::Util qw(sum);
my %opts;
my $Rdir = '~/../../../../tools/R-3.0.2/bin/';
my $use = <<"END";
use:
perl $0 -d <human.dict> <varscan.called> #default also looks for <varscan.called>.homdels so enable the homdels output
perl $0 -d <human.dict> -r 1,1,1000000 <varscan.called> #by region
perl $0 -d <human.dict> <varscan.called> <vcf.table> #also plot f/z vals
#note: the 
my actual use:
terpstramm\@Biolinux:~/Documents/gccclusterdata/data/projects/exomeseq/privsmeta/privsmeta/CNV\$ 
for i in $(ls S12_193_*.called);
	do perl /home/terpstramm/workspace/PlotGenome/PlotFloatsOnInterVals.pl -v ../../forGerard/s12-193.refilter.snps.Z.vcf.table \$i > S12_193_14.called.Rscript;
	Rscript \$i.Rscript ;
done
END

#R needs to be installed
$opts{'d'} =
'/home/terpstramm/Documents/gccclusterdata/data/resources/gatkbundle2.5/b37/human_g1k_v37.dict';

#$ARGV[0] = '/home/terpstramm/Documents/gccclusterdata/data/projects/exomeseq/privsmeta/privsmeta/CNV/S12_193_3.called';
getopts( 'r:d:v:', \%opts );

my $Dict = $opts{'d'};

my %ChrLenData = ReadDict($Dict);
my $interval   = $opts{'r'};

if ( not($interval) && $opts{'v'} && -e $opts{'v'} && -e $ARGV[0] ) {
	MakeVarscanDataTable( $ARGV[0], %ChrLenData );
	my $segtable = DoMedianNormalisationAndDNAcopy($ARGV[0], %ChrLenData);
	MakeVCFDataTable( $opts{'v'}, %ChrLenData );
	MakePDFrscriptWithVCF2( $ARGV[0], $opts{'v'}, $segtable,  %ChrLenData);

}
elsif ( not($interval) && -e $ARGV[0] ) {
	MakeVarscanDataTable( $ARGV[0], %ChrLenData );
	my $segtable = DoMedianNormalisationAndDNAcopy($ARGV[0], %ChrLenData);
	MakePDFrscript2( $ARGV[0], $segtable );
}
elsif ( -e $ARGV[0] ) {
	MakeVarscanDataTable( $ARGV[0], %ChrLenData );
	MakeVarscanDataTableByInterval( $ARGV[0], $interval );
	my $segtable = DoMedianNormalisationAndDNAcopy($ARGV[0], %ChrLenData);
	MakePDFrscriptByInterval( $ARGV[0], $interval );
}
else {
	$use && die;
}
#MakeVarscanDataTable($ARGV[0], %ChrLenData);
#my $segtable = DoMedianNormalisationAndDNAcopy($ARGV[0], %ChrLenData);
#MakePDFrscript2($ARGV[0], $segtable);
#MakePDFrscriptWithVCF2($ARGV[0], $segtable, $opts{'v'});
#MakePDFrscriptByInterval2( $ARGV[0],$segtable, $interval );

sub ReadDict {
	open( my $DictHandle, '<', $_[0] )
	  or die "cannot read dictionary file '$_[0]' ";
	my %ChrLenData;
	my $RefIndex = 0;
	my $OffSet   = 1;
	while ( my $line = <$DictHandle> ) {
		if ( $line =~ m/^\@SQ/ ) {
			my @tabdelim = split( "\t", $line );
			my @SN       = split( ':',  $tabdelim[1] );
			my @LN       = split( ':',  $tabdelim[2] );
			$ChrLenData{'ChrLen'}{ $SN[1] } = $LN[1];

			$ChrLenData{'ChrOff'}{ $SN[1] } = $OffSet;
			$OffSet = $OffSet + $LN[1];

			$ChrLenData{'order'}{$RefIndex} = $SN[1];
			$RefIndex++;
		}

	}
	$ChrLenData{'len'}=$OffSet;
	$ChrLenData{'REFcount'} = $RefIndex;
	close($DictHandle);
	return %ChrLenData;
}

sub MakeVarscanDataTable {
	open( my $Varscan2CopyCallerHandle, '<', $_[0] )
	  or die "cannot read Varscan2CopyCaller file '$_[0]' ";
	open( my $Varscan2CopyCallerHomsHandle, '<', $_[0] . '.homdels' )
	  or die "cannot read <Varscan2CopyCaller>.homdels file '$_[0]' ";
	open( my $Varscan2CopyCallerOutHandle, '>', $_[0] . '.table' );
	shift @_;
	my %ChrLenData = @_;
	my $header     = <$Varscan2CopyCallerHandle>;
	print $Varscan2CopyCallerOutHandle 'offset' . "\t" . $header;

	#die Dumper(\%ChrLenData);
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHandle> ) ) {

	  #warn "$tabdelim[0]\t$tabdelim[1]\t$ChrLenData{'ChrOff'}{$tabdelim[0]}\n";
		print $Varscan2CopyCallerOutHandle join(
			"\t",
			(
				( $ChrLenData{'ChrOff'}{ $tabdelim[0] } + $tabdelim[1] ),
				@tabdelim
			)
		);
	}
	<$Varscan2CopyCallerHomsHandle>;    #skips header
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHomsHandle> ) ) {
		print $Varscan2CopyCallerOutHandle join( "\t",
			( $ChrLenData{'ChrOff'}{ $tabdelim[0] } + $tabdelim[1], @tabdelim )
		);
	}
}

sub MakeVarscanDataTableWithFloatingMean {
	open( my $Varscan2CopyCallerHandle, '<', $_[0] )
	  or die "cannot read Varscan2CopyCaller file '$_[0]' ";
	open( my $Varscan2CopyCallerHomsHandle, '<', $_[0] . '.homdels' )
	  or die "cannot read <Varscan2CopyCaller>.homdels file '$_[0]' ";
	open( my $Varscan2CopyCallerOutHandle, '>', $_[0] . '.table' );
	shift @_;
	my %ChrLenData = @_;
	my $header     = <$Varscan2CopyCallerHandle>;
	print $Varscan2CopyCallerOutHandle 'offset' . "\t" . $header;
	
	#lineindex
		#offset
		#Chrom
		#Pos
		#other
		#AdjustedRatio
		#floatingmeanAdjustedRatio
	
	my %cnvdata;my $lineIndex = 0;
	#die Dumper(\%ChrLenData);
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHandle> ) ) {

	  #warn "$tabdelim[0]\t$tabdelim[1]\t$ChrLenData{'ChrOff'}{$tabdelim[0]}\n";
	#	$cnvdata{$lineIndex}{'offset'} = $ChrLenData{'ChrOff'}{ $tabdelim[0] } + $tabdelim[1];
	#	$cnvdata{$lineIndex}{'Chrom'} = $tabdelim[0];
	#	$cnvdata{$lineIndex}{'Pos'} = $tabdelim[1];
	#	$cnvdata{$lineIndex}{'AdjustedRatio'} = $tabdelim[6];
	#	$cnvdata{$lineIndex}{'other'} = join("\t", @tabdelim[2..9]);
	#	$lineIndex++;
	}
	<$Varscan2CopyCallerHomsHandle>;    #skips header
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHomsHandle> ) ) {
		print $Varscan2CopyCallerOutHandle join( "\t",
			( $ChrLenData{'ChrOff'}{ $tabdelim[0] } + $tabdelim[1], @tabdelim )
		);
	}
}
sub DoMedianNormalisationAndDNAcopy{
	
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called//g;

	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)

#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanDat\$adjusted_log_ratio <- VarscanDat\$adjusted_log_ratio - median

#source("http://bioconductor.org/biocLite.R")
#biocLite("DNAcopy")
library(DNAcopy)


VarscanDat.CNA.object <- CNA(cbind(VarscanDat\$adjusted_log_ratio),
VarscanDat\$chrom,VarscanDat\$chr_start,
data.type="logratio",sampleid="$shortname")
smoothed.VarscanDat.CNA.object <- smooth.CNA(VarscanDat.CNA.object)
segment.smoothed.VarscanDat.CNA.object <- segment(smoothed.VarscanDat.CNA.object, min.width=2, weights=(VarscanDat\$normal_depth-VarscanDat\$tumor_depth), verbose=1, undo.splits="sdundo", undo.SD=1)
#, undo.splits="sdundo", undo.SD=2
#
write.table(segment.smoothed.VarscanDat.CNA.object\$out, file="$shortname.seg",  sep="\\t", row.names=FALSE)
END
	open(my $out,">","$shortname.rscript");
	print $out $rscript;
	close $out;
	warn "running DNAcopy...\n".`$Rdir/Rscript $shortname.rscript`;
#	$shortname.seg;
	open( my $SegHandle, '<', "$shortname.seg" )
	  or die "cannot read DNAcopy.seg file '$shortname.seg' ";
	open( my $SegOutHandle, '>', "$shortname.seg" . '.table' );
	#shift @_;
	my %ChrLenData = @_;
	my $header     = <$SegHandle>;
	my $headerString = 'start' . "\t" .'end' . "\t" . $header;
	$headerString =~ s/"//g;
	print $SegOutHandle $headerString;
	while ( my @tabdelim = split( "\t", <$SegHandle> ) ) {
		my $ref = $tabdelim[1];
		$ref =~ s/"//g;
		my $datastring = join( "\t",
			( $ChrLenData{'ChrOff'}{ $ref } + $tabdelim[2],$ChrLenData{'ChrOff'}{ $ref } + $tabdelim[3], @tabdelim )
		);
		$datastring =~ s/"//g;
		print $SegOutHandle $datastring;
	}
	return "$shortname.seg.table";
}
sub MakePDFrscript {
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called//g;

	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)

#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanDat\$adjusted_log_ratio <- VarscanDat\$adjusted_log_ratio - median
#truncate CNV values
truncate.CNV <- function(x){ if(x < -3) { return(-3) } else if(x > 2) {return(2)} else {return(x) }}
VarscanDat\$adjusted_log_ratio<-apply(X=t(VarscanDat\$adjusted_log_ratio),MARGIN=2,FUN=truncate.CNV)
########################################^why the t() funtion ?????????????!.... should i learn R explicitly instead of grabbing codes from the webs????
#pdf open
pdf(file="$dataTable.pdf", width=20, height=6, useDingbats=F)
#plot
plot(VarscanDat\$offset, VarscanDat\$adjusted_log_ratio, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="$shortname" , ylim = c(-3,2))
abline(a=log(x=2,base=2),b=0, col="red")
abline(a=log(x=1.5,base=2),b=0, col="orange")
abline(a=log(x=1,base=2),b=0, col="green")
abline(a=log(x=0.5,base=2),b=0, col="blue")
abline(a=log(x=0.25,base=2),b=0, col="black")
legend("bottomright", title="copynumber relative to normal",c("4n","3n","2n","1n","0n"), fill=c("red","orange","green","blue","black"), horiz=TRUE)
END
	my $i = 0;
	my @at;
	my @labels;
	while ( $i < $ChrLenData{'REFcount'} ) {
		push( @labels, $ChrLenData{'order'}{$i} );
		push( @at,     $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{$i} } );
		$i++;
	}
	$rscript =
	    $rscript
	  . 'axis(1, at=c("'
	  . join( '","', @at )
	  . '"),labels=c("'
	  . join( '","', @labels )
	  . '"), las=2)';
	$rscript = $rscript . <<"END";

#pdf close
dev.off()


END
	print $rscript;
}
sub MakePDFrscript2 {
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called//g;
	my $segTable = shift @_;

	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)
DNAcopySegDat <- read.table("$segTable", sep="\\t", header=TRUE)

#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanDat\$adjusted_log_ratio <- VarscanDat\$adjusted_log_ratio - median
#truncate CNV values
truncate.CNV <- function(x){ if(x < -3) { return(-3) } else if(x > 2) {return(2)} else {return(x) }}
VarscanDat\$adjusted_log_ratio<-apply(X=t(VarscanDat\$adjusted_log_ratio),MARGIN=2,FUN=truncate.CNV)
########################################^why the t() funtion ?????????????!.... should i learn R explicitly instead of grabbing codes from the webs????
#pdf open
pdf(file="$dataTable.pdf", width=20, height=6, useDingbats=F)
#plot
plot(VarscanDat\$offset, VarscanDat\$adjusted_log_ratio, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="$shortname" , ylim = c(-3,2))
abline(a=log(x=2,base=2),b=0, col="red")
abline(a=log(x=1.5,base=2),b=0, col="orange")
abline(a=log(x=1,base=2),b=0, col="green")
abline(a=log(x=0.5,base=2),b=0, col="blue")
abline(a=log(x=0.25,base=2),b=0, col="black")
segments(DNAcopySegDat\$start,DNAcopySegDat\$seg.mean,DNAcopySegDat\$end,DNAcopySegDat\$seg.mean, col="grey")
###i'm here^^^^^^^^^^^
#

legend("bottomright", title="copynumber relative to normal",c("4n","3n","2n","1n","0n","detected"), fill=c("red","orange","green","blue","black","grey"), horiz=TRUE)
END
	my $i = 0;
	my @at;
	my @labels;
	while ( $i < $ChrLenData{'REFcount'} ) {
		push( @labels, $ChrLenData{'order'}{$i} );
		push( @at,     $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{$i} } );
		$i++;
	}
	$rscript =
	    $rscript
	  . 'axis(1, at=c("'
	  . join( '","', @at )
	  . '"),labels=c("'
	  . join( '","', @labels )
	  . '"), las=2)';
	$rscript = $rscript . <<"END";

#pdf close
dev.off()
END
	print $rscript;
}

sub MakeVarscanDataTableByInterval {
	open( my $Varscan2CopyCallerHandle, '<', $_[0] )
	  or die "cannot read Varscan2CopyCaller file '$_[0]' ";
	open( my $Varscan2CopyCallerHomsHandle, '<', $_[0] . '.homdels' )
	  or die "cannot read Varscan2CopyCaller file '$_[0]' ";
	open( my $Varscan2CopyCallerOutIntervalHandle,
		'>', $_[0] . '.interval.table' );
	shift @_;
	my ( $chrom, $start, $end ) = split( ',', shift(@_) );

	#my %ChrLenData = @_;
	my $header = <$Varscan2CopyCallerHandle>;
	print $Varscan2CopyCallerOutIntervalHandle 'offset' . "\t" . $header;

	#die Dumper(\%ChrLenData);
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHandle> ) ) {

	  #warn "$tabdelim[0]\t$tabdelim[1]\t$ChrLenData{'ChrOff'}{$tabdelim[0]}\n";
		if (   $tabdelim[0] eq $chrom
			&& $tabdelim[1] > $start
			&& $tabdelim[1] < $end )
		{
			print $Varscan2CopyCallerOutIntervalHandle
			  join( "\t", ( ( $tabdelim[1] - $start ), @tabdelim ) );
		}
	}
	<$Varscan2CopyCallerHomsHandle>;    #skips header
	while ( my @tabdelim = split( "\t", <$Varscan2CopyCallerHomsHandle> ) ) {
		if (   $tabdelim[0] eq $chrom
			&& $tabdelim[1] > $start
			&& $tabdelim[1] < $end )
		{
			print $Varscan2CopyCallerOutIntervalHandle
			  join( "\t", ( ( $tabdelim[1] - $start ), @tabdelim ) );
		}
	}
}

sub MakePDFrscriptByInterval {
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called//g;
	my ( $chrom, $start, $end ) = split( ',', shift(@_) );
	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)
VarscanIntervalDat <- read.table("$dataTable.interval.table", sep="\\t", header=TRUE)

#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanIntervalDat\$adjusted_log_ratio <- VarscanIntervalDat\$adjusted_log_ratio - median
#pdf open
pdf(file="$dataTable.pdf", width=20, height=6, useDingbats=F)
#plot
plot(VarscanIntervalDat\$offset, VarscanIntervalDat\$adjusted_log_ratio, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="$shortname")
abline(a=log(x=2,base=2),b=0, col="red")
abline(a=log(x=1.5,base=2),b=0, col="orange")
abline(a=log(x=1,base=2),b=0, col="green")
abline(a=log(x=0.5,base=2),b=0, col="blue")
abline(a=log(x=0.25,base=2),b=0, col="black")
legend("bottomright", title="copynumber relative to normal",c("4n","3n","2n","1n","0n"), fill=c("red","orange","green","blue","black"), horiz=TRUE)
END
	my $i = 0;
	my @at;
	my @labels;
	$rscript =
	    $rscript 
	  . 'axis(1, at=c("'
	  . join(
		'","',
		(
			1,
			sprintf( '%.0f', ( $end - $start ) / 10 * 1 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 2 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 3 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 4 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 5 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 6 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 7 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 8 ),
			sprintf( '%.0f', ( $end - $start ) / 10 * 9 ),
			$end - $start
		)
	  )
	  . '"),labels=c("'
	  . join(
		'","',
		(
			$start,
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 1 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 2 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 3 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 4 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 5 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 6 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 7 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 8 ),
			sprintf( '%.0f', $start + ( $end - $start ) / 10 * 9 ),
			$end
		)
	  ) . '"), las=2)' . "\n";
	$rscript = $rscript . <<"END";

#pdf close
dev.off()
END
	print $rscript;
}

sub MakeVCFDataTable {
	open( my $VcfTableHandle, '<', $_[0] )
	  or die "cannot read Snv table file '$_[0]' ";

#open(my $VcfTableHandle,'<',$_[0].'.indels.table') or die "cannot read indels file '$_[0]' ";
	open( my $VcfTableHandleOutHandle, '>', $_[0] . '.table' );
	shift @_;
	my %ChrLenData = @_;
	my $header     = <$VcfTableHandle>;
	print $VcfTableHandleOutHandle 'Offsets' . "\t" . $header;

	#die Dumper(\%ChrLenData);
	while ( my @tabdelim = split( "\t", <$VcfTableHandle> ) ) {

	  #warn "$tabdelim[0]\t$tabdelim[1]\t$ChrLenData{'ChrOff'}{$tabdelim[0]}\n";
		print $VcfTableHandleOutHandle join(
			"\t",
			(
				( $ChrLenData{'ChrOff'}{ $tabdelim[0] } + $tabdelim[1] ),
				@tabdelim
			)
		);
	}

#<$VcfTableHandle>;#skips header
#while(my @tabdelim = split("\t",<$VcfTableHandle>)){
#	print $VcfTableHandleOutHandle join("\t",($ChrLenData{'ChrOff'}{$tabdelim[0]}+$tabdelim[1],@tabdelim));
#}
}

sub MakePDFrscriptWithVCF {
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called//g;
	my $variantTable = shift @_;

	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)
VariantDat <- read.table("$variantTable.table", sep="\\t", header=TRUE)

#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanDat\$adjusted_log_ratio <- VarscanDat\$adjusted_log_ratio - median
#pdf open
pdf(file="$dataTable.pdf", width=20, height=8, useDingbats=F)
#plot
layout(matrix(c(1,2,3), 3, 1, byrow = TRUE),
    heights=c(2,1,1))
plot(VarscanDat\$offset, VarscanDat\$adjusted_log_ratio, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="$shortname" , ylim = c(-3,2))
abline(a=log(x=2,base=2),b=0, col="red")
abline(a=log(x=1.5,base=2),b=0, col="orange")
abline(a=log(x=1,base=2),b=0, col="green")
abline(a=log(x=0.5,base=2),b=0, col="blue")
abline(a=log(x=0.25,base=2),b=0, col="black")
legend("bottomright", title="copynumber relative to normal",c("4n","3n","2n","1n","0n"), fill=c("red","orange","green","blue","black"), horiz=TRUE)

END
	my $i = 0;
	my @at;
	my @labels;
	while ( $i < $ChrLenData{'REFcount'} ) {
		push( @labels, $ChrLenData{'order'}{$i} );
		push( @at,     $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{$i} } );
		$i++;
	}
	$rscript =
	    $rscript
	  . 'axis(1, at=c("'
	  . join( '","', @at )
	  . '"),labels=c("'
	  . join( '","', @labels )
	  . '"), las=2)';
	$rscript = $rscript . <<"END";

plot(VariantDat\$Offsets,VariantDat\$${shortname}.F, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="F vals")
abline(a=1,b=0, col="red")
abline(a=0,b=0, col="red")
abline(a=.5,b=0, col="green")
plot(VariantDat\$Offsets,VariantDat\$${shortname}.Z, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="Z vals")
abline(a=0,b=0, col="green")

#pdf close
dev.off()
END
	print $rscript;
}
sub MakePDFrscriptWithVCF2 {
	my $dataTable = shift @_;
	my $shortname = $dataTable;
	$shortname =~ s/.called|.table//g;
	my $variantTable = shift @_;
	my $segTable = shift @_;
	my %ChrLenData = @_;
	
	my $rscript = <<"END";
#load data
VarscanDat <- read.table("$dataTable.table", sep="\\t", header=TRUE)
VariantDat <- read.table("$variantTable.table", sep="\\t", header=TRUE)
DNAcopySegDat <- read.table("$segTable", sep="\\t", header=TRUE)


#median centering
median <- quantile(VarscanDat\$adjusted_log_ratio, .5)
VarscanDat\$adjusted_log_ratio <- VarscanDat\$adjusted_log_ratio - median
#truncate CNV values
truncate.CNV <- function(x){ if(x < -3) { return(-3) } else if(x > 2) {return(2)} else {return(x) }}
VarscanDat\$adjusted_log_ratio<-apply(X=t(VarscanDat\$adjusted_log_ratio),MARGIN=2,FUN=truncate.CNV)
#VarscanDatOutOfNormalrange<-subset(VarscanDat, adjusted_log_ratio == 2| adjusted_log_ratio == -3 , select=c(offset,adjusted_log_ratio))
#truncate Segment values
DNAcopySegDat\$seg.mean<-apply(X=t(DNAcopySegDat\$seg.mean),MARGIN=2,FUN=truncate.CNV)
#DNAcopySegDatOutOfNormalrange<-subset(DNAcopySegDat, seg.mean == 2| seg.mean == -3 , select=c(offset,seg.mean))
#pdf open
pdf(file="$dataTable.pdf", width=20, height=8, useDingbats=F)
#plot
layout(matrix(c(1,2), 2, 1, byrow = TRUE),
    heights=c(2,1,1))


plot(VarscanDat\$offset, VarscanDat\$adjusted_log_ratio, pch='.', lty=3, xlab="", ylab="log2(tumor/normal)", xaxt="n", main="$shortname" , ylim = c(-3,2), xlim = c(1,$ChrLenData{'len'}))
abline(a=log(x=2,base=2),b=0, col="red")
abline(a=log(x=1.5,base=2),b=0, col="orange")
abline(a=log(x=1,base=2),b=0, col="green")
abline(a=log(x=0.5,base=2),b=0, col="blue")
abline(a=log(x=0.25,base=2),b=0, col="black")
segments(DNAcopySegDat\$start,DNAcopySegDat\$seg.mean,DNAcopySegDat\$end,DNAcopySegDat\$seg.mean, col="grey")

legend("bottomright", title="copynumber relative to normal",c("4n","3n","2n","1n","0n","detected"), fill=c("red","orange","green","blue","black","grey"), horiz=TRUE)

END
	my $i = 0;
	my @at;
	my @labels;
	my @atMinorTicks;
	my @labelsMinorTicks;
	while ( $i < $ChrLenData{'REFcount'} ) {
		push( @labels, $ChrLenData{'order'}{$i} );
		push( @at,     $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{$i} } );
		my $minorTicksOffset = 25000000;
		my $minorTickPos = $minorTicksOffset ;
		while($minorTickPos < $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{($i + 1)} }){
			push( @labelsMinorTicks, "" );
			push( @atMinorTicks,     $ChrLenData{'ChrOff'}{ $ChrLenData{'order'}{$i} } + $minorTickPos);
			$minorTickPos += $minorTicksOffset;
		}
		$i++;
	}
	$rscript =
	    $rscript
	  . 'axis(1, at=c("'
	  . join( '","', @at )
	  . '"),labels=c("'
	  . join( '","', @labels )
	  . '"), las=2)';
	 $rscript =
	    $rscript
	  . 'axis(1, at=c("'
	  . join( '","', @atMinorTicks )
	  . '"),labels=c("'
	  . join( '","', @labelsMinorTicks )
	  . '"), las=2,tck=-0.008 )';
	
	my $rscriptTail= <<"END";

plot(VariantDat\$Offsets,VariantDat\$${shortname}.F, pch='.', lty=3, xlab="", ylab="F", xaxt="n", main="Observed Alternate Allele Balance", xlim = c(1,$ChrLenData{'len'}))
abline(a=1,b=0, col="red")
abline(a=0,b=0, col="red")
abline(a=.5,b=0, col="green")
#pdf close
dev.off()
pdf()
plot(DNAcopySegDat\$loc.end,DNAcopySegDat\$seg.mean)
segments(DNAcopySegDat\$loc.start,DNAcopySegDat\$seg.mean,DNAcopySegDat\$loc.end,DNAcopySegDat\$seg.mean, col="grey")
dev.off()
END
	$rscript = $rscript . $rscriptTail;
	print $rscript;
}
