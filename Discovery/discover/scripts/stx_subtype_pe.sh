tooldir="$1";
fastqfile1="$2";
fastqfile2="$3";
fastafile="$4";

# ASSEMBLY
mkdir stxdir;
skesa --fastq $fastqfile1 $fastqfile2 --contigs_out stxdir/skesa.fasta;
cp $fastafile stxdir/spades.fasta;
rm -r output_dir;

# FILTER + ASSEMBLY
$tooldir/discover/scripts/duk/duk -m stxdir/filtered1STX.fq -k 23 $tooldir/discover/data/stx.fasta $fastqfile1;
$tooldir/discover/scripts/duk/duk -m stxdir/filtered2STX.fq -k 23 $tooldir/discover/data/stx.fasta $fastqfile2;
$tooldir/discover/scripts/fastq-pair-master/build/fastq_pair stxdir/filtered1STX.fq stxdir/filtered2STX.fq;
$tooldir/discover/scripts/fastq-pair-master/build/fastq_pair stxdir/filtered1STX.fq.single.fq $fastqfile2;
$tooldir/discover/scripts/fastq-pair-master/build/fastq_pair stxdir/filtered2STX.fq.single.fq $fastqfile1;
cat stxdir/filtered1STX.fq.paired.fq > stxdir/filtered1STX_paired.fq;
cat stxdir/filtered1STX.fq.single.fq.paired.fq >> stxdir/filtered1STX_paired.fq;
cat trimmed1.paired.fq >> stxdir/filtered1STX_paired.fq;
#cat $fastqfile1 >> stxdir/filtered1STX_paired.fq;
cat stxdir/filtered2STX.fq.paired.fq > stxdir/filtered2STX_paired.fq;
cat trimmed2.paired.fq >> stxdir/filtered2STX_paired.fq;
#cat $fastqfile2 >> stxdir/filtered2STX_paired.fq;
cat stxdir/filtered2STX.fq.single.fq.paired.fq >> stxdir/filtered2STX_paired.fq;
dukstx1filesize=$(wc -c "stxdir/filtered1STX_paired.fq" | awk '{print $1}');
dukstx2filesize=$(wc -c "stxdir/filtered2STX_paired.fq" | awk '{print $1}');
if [ $dukstx1filesize -gt 0 ] && [ $dukstx2filesize -gt 0 ]
then
  skesa --fastq stxdir/filtered1STX_paired.fq stxdir/filtered2STX_paired.fq --contigs_out stxdir/duk_skesa.fasta;
  perl $tooldir/discover/scripts/spades.pl duk_spades_contigs duk_spades_contig_stats duk_spades_scaffolds duk_spades_scaffold_stats duk_spades_log NODE spades.py --disable-gzip-output --isolate -t 8 --pe1-ff --pe1-1 stxdir/filtered1STX_paired.fq --pe1-2 stxdir/filtered2STX_paired.fq
  mv duk_spades_contigs stxdir/duk_spades.fasta;
  rm -r output_dir;
  blastn -query stxdir/duk_skesa.fasta -db $tooldir/discover/data/stx -task blastn -evalue 0.001 -out stxdir/duk_skesa_seqs -outfmt '6 qseqid sseqid sframe qseq' -num_threads 8 -strand both -dust yes -max_target_seqs 1 -perc_identity 95.0;
  blastn -query stxdir/duk_spades.fasta -db $tooldir/discover/data/stx -task blastn -evalue 0.001 -out stxdir/duk_spades_seqs -outfmt '6 qseqid sseqid sframe qseq' -num_threads 8 -strand both -dust yes -max_target_seqs 1 -perc_identity 95.0;
else
  touch stxdir/duk_skesa_seqs;
  touch stxdir/duk_spades_seqs;
fi

# SEQUENCE SEARCH
blastn -query stxdir/skesa.fasta -db $tooldir/discover/data/stx -task blastn -evalue 0.001 -out stxdir/skesa_seqs -outfmt '6 qseqid sseqid sframe qseq' -num_threads 8 -strand both -dust yes -max_target_seqs 1 -perc_identity 95.0;
blastn -query stxdir/spades.fasta -db $tooldir/discover/data/stx -task blastn -evalue 0.001 -out stxdir/spades_seqs -outfmt '6 qseqid sseqid sframe qseq' -num_threads 8 -strand both -dust yes -max_target_seqs 1 -perc_identity 95.0;
# DIVIDE STX1 FROM STX2
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx1") print $1,$3,$4}' stxdir/skesa_seqs > stxdir/stx1_skesa_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx2") print $1,$3,$4}' stxdir/skesa_seqs > stxdir/stx2_skesa_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx1") print $1,$3,$4}' stxdir/duk_skesa_seqs > stxdir/dukstx1_skesa_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx2") print $1,$3,$4}' stxdir/duk_skesa_seqs > stxdir/dukstx2_skesa_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx1") print $1,$3,$4}' stxdir/spades_seqs > stxdir/stx1_spades_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx2") print $1,$3,$4}' stxdir/spades_seqs > stxdir/stx2_spades_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx1") print $1,$3,$4}' stxdir/duk_spades_seqs > stxdir/dukstx1_spades_seqs;
awk 'BEGIN { OFS="\t" }!seen[$1]++ {if (substr($2,1,4)=="stx2") print $1,$3,$4}' stxdir/duk_spades_seqs > stxdir/dukstx2_spades_seqs;
# CREATE COMBINED MULTIFASTA FROM SEQUENCES
perl $tooldir/discover/scripts/MultifastaFromBlast.pl "stxdir/stx1_skesa_seqs,stxdir/dukstx1_skesa_seqs,stxdir/stx1_spades_seqs,stxdir/dukstx1_spades_seqs" "stxdir/multiassembly_stx1.fasta";
perl $tooldir/discover/scripts/MultifastaFromBlast.pl "stxdir/stx2_skesa_seqs,stxdir/dukstx2_skesa_seqs,stxdir/stx2_spades_seqs,stxdir/dukstx2_spades_seqs" "stxdir/multiassembly_stx2.fasta";

# ALIGN AND GET CONSENSUS
stx1filesize=$(wc -c "stxdir/multiassembly_stx1.fasta" | awk '{print $1}');
if [ $stx1filesize -eq 0 ]
then
  touch stxdir/multiassembly_stx1_consensus.fasta;
else
  cat $tooldir/discover/data/stx1.fa >> stxdir/multiassembly_stx1.fasta;
  muscle -in stxdir/multiassembly_stx1.fasta -out stxdir/multiassembly_stx1_aligned.fasta;
  awk 'BEGIN {RS=">" ; ORS=""} substr($1,1,4)!="stx1" {print ">"$0}' stxdir/multiassembly_stx1_aligned.fasta > stxdir/multiassembly_stx1_aligned_clean.fasta;
  awk '/^>/ {printf("%s%s\n",(N>0?"\n":""),$0);N++;next;} {printf("%s",$0);} END {printf("\n");}' stxdir/multiassembly_stx1_aligned_clean.fasta > stxdir/multiassembly_stx1_aligned_linear.fasta;
  python $tooldir/discover/scripts/GetConsensus.py -i stxdir/multiassembly_stx1_aligned_linear.fasta -o stxdir/multiassembly_stx1_consensus.fasta;
fi

stx2filesize=$(wc -c "stxdir/multiassembly_stx2.fasta" | awk '{print $1}');
if [ $stx2filesize -eq 0 ]
then
  touch stxdir/multiassembly_stx2_consensus.fasta;
else
  cat $tooldir/discover/data/stx2.fa >> stxdir/multiassembly_stx2.fasta;
  muscle -in stxdir/multiassembly_stx2.fasta -out stxdir/multiassembly_stx2_aligned.fasta;
  awk 'BEGIN {RS=">" ; ORS=""} substr($1,1,4)!="stx2" {print ">"$0}' stxdir/multiassembly_stx2_aligned.fasta > stxdir/multiassembly_stx2_aligned_clean.fasta;
  awk '/^>/ {printf("%s%s\n",(N>0?"\n":""),$0);N++;next;} {printf("%s",$0);} END {printf("\n");}' stxdir/multiassembly_stx2_aligned_clean.fasta > stxdir/multiassembly_stx2_aligned_linear.fasta;
  python $tooldir/discover/scripts/GetConsensus.py -i stxdir/multiassembly_stx2_aligned_linear.fasta -o stxdir/multiassembly_stx2_consensus.fasta;
fi
cat stxdir/multiassembly_stx1_consensus.fasta > stx.fasta;
cat stxdir/multiassembly_stx2_consensus.fasta >> stx.fasta;
