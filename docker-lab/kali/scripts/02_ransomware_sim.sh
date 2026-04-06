#!/bin/bash
echo "=== RANSOMWARE SIMULATION (SAFE) ==="
DIR="/root/data/ransom_sim"
mkdir -p $DIR
echo "Sample data" > $DIR/doc1.txt
echo "Financial report" > $DIR/finance.docx
for f in $DIR/*; do mv $f $f.encrypted 2>/dev/null; done
echo "!!! YOUR FILES ARE ENCRYPTED !!!" > $DIR/RANSOM_NOTE.txt
echo "(This is a simulation)" >> $DIR/RANSOM_NOTE.txt
echo "Files in: $DIR"
