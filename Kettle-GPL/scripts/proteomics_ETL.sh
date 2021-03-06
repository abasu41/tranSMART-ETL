#! /bin/bash
./data-integration/kitchen.sh \
-norep=Y \
-file=/load_proteomics_data.kjb \
-log=load_proteomics_pivot_data.log \
-param:DATA_LOCATION=../data/proteomics \
-param:STUDY_ID=GSE8581 \
-param:MAP_FILENAME=proteomics_sub_sam_data.txt \
-param:DATA_TYPE='R' \
-param:SORT_DIR=/tmp \
-param:TOP_NODE='\Public Studies\GSE8581' \
-param:COLUMN_MAPPING_FILE=proteomics_column_mapping.txt \
-param:LOAD_TYPE=I \
-param:DATA_FILE_PREFIX=pp-Peptide-report_prepared
