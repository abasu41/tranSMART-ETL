# This Rscript reads the input files for clincal data to be uploaded 
# into TranSMART (ColumnMapFile, DataFile and the optional WordMapFile).
#
# It produces one output file, which can be directly
# uploaded into landing-zone of the transmart-database.
#
# The stored procedure "i2b2_load_clincial_data" takes this data from
# the landing zone and distributes this into the transmart database.

###############################################################################
# Read the Word-Map-File
###############################################################################

options(warn=1)

readWordMapFile <- function(local_wordMapFile) {

  colNames   <- c("filename" , "columnNr", "oldVal"   , "newVal")
  colClasses <- c("character", "numeric" , "character", "character")

  # somehow "local_wordMapFile" always exists
  # if (exists("local_wordMapFile") == TRUE) {
  if (exists("wordMapFile") == TRUE) {
  
      wordMapTable <- read.csv( local_wordMapFile, header=TRUE, sep="\t",
    			        col.names  = colNames,
			        colClasses = colClasses,
				strip.white=TRUE
                              )

      print(paste("Word Map File:", local_wordMapFile, "read", sep=" "))
  
  } else {

      wordMapTable <- data.frame(c("", "", "", ""), col.names=colNames)  

  }

  return(wordMapTable)
}


###############################################################################
# Read the Column-Map-File
###############################################################################
readColumnMapFile <- function(columnMapFile) {

  colNames   <- c( "filename" , "categoryCode"   , "columnNr", 
                   "dataLabel", "dataLabelSource", "controlledVocabCode")

  colClasses <- c( "character", "character"      , "numeric",
                   "character", "character"      , "character")

  columnMapTable <- read.csv( columnMapFile, header=TRUE, sep="\t", 
			      col.names  = colNames,
			      colClasses = colClasses,
			      strip.white=TRUE
                            )

  print(paste("Column Map File:", columnMapFile, "read", sep=" "))
  
  return(columnMapTable)
}

###############################################################################
# Read the Data-File
###############################################################################
readDataFile <- function(dataFile) {
      
    dataTable <- read.csv( dataFile, header=TRUE, sep="\t", 
                           colClasses="character", strip.white=TRUE)
    
    # Do some obvious check's
    if (!"SUBJ_ID" %in% columnMapTable$dataLabel) {
	stop(paste("Mandatory dataLabel 'SUBJ_ID' not find in data-filer:",
                    dataFile))
    }

    print(paste("Data File: ", dataFile, "read", sep=" "))

    return(dataTable)
}

###############################################################################
# unitsMap 
###############################################################################
getUnitsMap <- function(columnMapTable) {

  index <- which(columnMapTable$dataLabel == "UNITS")
  unitsMapTable <- as.table(matrix( c( columnMapTable$columnNr[index], 
                                       columnMapTable$dataLabelSource[index]
                                    ), 
                                    ncol=2
                                  )
                           )
  colnames(unitsMapTable) <- c("units", "values")

  return(unitsMapTable)
}

###############################################################################
# timeMap 
###############################################################################
getDateMap <- function(columnMapTable) {

  index <- which(columnMapTable$dataLabel == "DATE")
  timeMapTable <- as.table( matrix( c( columnMapTable$columnNr[index], 
                                       columnMapTable$dataLabelSource[index]
                                    ), 
                                    ncol=2
                                  )
                          )
  colnames(timeMapTable) <- c("times", "values")

  return(timeMapTable)
}


###############################################################################
# Apply the wordMap to the dataMap 
###############################################################################
applyWordMap <- function(wordMapTable, dataFile, dataTable, columnr) {
 
    for (i in which(wordMapTable$filename == dataFile & 
                    wordMapTable$columnNr == columnr)) {
        

	index <- which(dataTable[,columnr] == wordMapTable$oldVal[i])
	if (sum(index) > 0) dataTable[index,columnr] <- wordMapTable$newVal[i]

        print(paste( "    ", 
                     wordMapTable$oldVal[i], " -> ", wordMapTable$newVal[i], 
                     " (instances changed: ", length(index), ")",
                     " (row in wordmapfile: ", i, ")",
                     " (column in datafile: ", columnr, ")",
                     sep=""
                   )
             )

    }

    return(dataTable)
}

###############################################################################
# Apply the wordMap to the dataMap (for MODIFIER_CD columns)
###############################################################################
applyWordMapAs <- function(wordMapTable, dataFile, dataTable, columnr, org_columnr) {

    for (i in which(wordMapTable$filename == dataFile & 
                    wordMapTable$columnNr == org_columnr)) {
        
	index <- which(dataTable[,columnr] == wordMapTable$oldVal[i])
	if (sum(index) > 0) dataTable[index,columnr] <- wordMapTable$newVal[i]

        print(paste( "    ", 
                     wordMapTable$oldVal[i], " -> ", wordMapTable$newVal[i], 
                     " (instances changed*: ", length(index), ")",
                     " (row in wordmapfile: ", i, ")",
                     " (column in datafile: ", columnr, ")",
                     sep=""
                   )
             )
	

    }

    return(dataTable)
}

###############################################################################
###############################################################################
getTimestampsForColumn <- function(columnMapTable, dataTable, columnNr) {
    
    date_timestamp <- character(length(dataTable[,1]))
    dateRows       <- which( columnMapTable$filename  == dataFile &
        	             columnMapTable$dataLabel == "TIMESTAMP" )

    dateRow <- c()
    for (iter in dateRows) {
 	if (columnNr %in% as.numeric(unlist(strsplit(columnMapTable$dataLabelSource[iter], ',')))) {
                dateRow <- c(dateRow, iter)
        }
    }

    if (length(dateRow) == 1) {
	dateColumn     <- columnMapTable$columnNr[dateRow]
	date_timestamp <- dataTable[, dateColumn]
	print(paste( "    Timestamp definition found for column: ", columnNr))
    }
    date_timestamp[which(date_timestamp == "")] <- "infinity"
    return(date_timestamp)
}

###############################################################################
###############################################################################
# Returns the units-column for "columnNr" in "dataTable" (could be empty column)

getUnitsForColumn <- function(columnMapTable, dataTable, columnNr) {

    units_cd <- character(length(subject_id))
    unitRows <- which( columnMapTable$filename  == dataFile &
	  	       columnMapTable$dataLabel == "UNITS"   )

    unitRow <- c()
    for (iter in unitRows) {
	if (columnNr %in% as.numeric(unlist(strsplit(columnMapTable$dataLabelSource[iter], ',')))) {
		unitRow <- c(unitRow, iter)
	}
    }

    if (length(unitRow) == 1) {
	unitColumn <- columnMapTable$columnNr[unitRow]
	units_cd   <- dataTable[, unitColumn]
	print(paste( "    Units definition found for column: ", columnNr))
    }
 
    return(units_cd)
}

###############################################################################
###############################################################################
# Adds derived concepts from a longitudinal variable (concept)

addLongitudinalDerivedConcepts <- function(long_out, firstWrite) {
  long_out <- long_out[long_out$data_value != "", ]
  if (is.numeric(type.convert(as.character(long_out$data_value)))) {
	long_out$data_value <- type.convert(as.character(long_out$data_value))
	addLongitudinalDerivedConceptsNumeric(long_out, firstWrite)
  } else {
	addLongitudinalDerivedConceptsFactor(long_out, firstWrite)
  }
}

addLongitudinalDerivedConceptsNumeric <- function(long_out, firstWrite) {

  # Handle the collected longitudinal data. Show derived data (min, max, mean, std-dev, ...)
  subjects <- unique(long_out$subject_id)
  for (subject_id in subjects) {
	rows       <- which( long_out$subject_id == subject_id)
	#print(long_out[rows,])
        values     <- long_out[rows, 'data_value']
	node_label <- paste(long_out[rows[1], 'category_cd'], '+', long_out[rows[1], 'data_label'], '_serie', sep='')
	# first value
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'first'
	modifier_cd     <- '@'
	data_value      <- long_out[rows[1], 'data_value']
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- long_out[rows[1], 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	firstWrite <- FALSE
	# last value
	last_row <- rows[length(rows)]
	site_id         <- long_out[last_row, 'site_id']
	visit_name      <- long_out[last_row, 'visit_name']
	data_label      <- 'last'
	modifier_cd     <- '@'
	data_value      <- long_out[last_row, 'data_value']
	units_cd        <- long_out[last_row, 'units_cd']
	date_timestamp  <- long_out[last_row, 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[last_row, 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# mean value
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'mean'
	modifier_cd     <- '@'
	data_value      <- mean(as.numeric(as.character(values)))
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Median
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'median'
	modifier_cd     <- '@'
	data_value      <- median(as.numeric(as.character(values)))
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Min value
	row             <- which(long_out$data_value == min(as.numeric(as.character(values))) &
			         long_out$subject_id == subject_id )
	site_id         <- long_out[row[1], 'site_id']
	visit_name      <- long_out[row[1], 'visit_name']
	data_label      <- 'minimum'
	modifier_cd     <- '@'
	data_value      <- long_out[row[1], 'data_value']
	units_cd        <- long_out[row[1], 'units_cd']
	date_timestamp  <- long_out[row[1], 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[row[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Max value
	row             <- which(long_out$data_value == max(as.numeric(as.character(values))) &
				 long_out$subject_id == subject_id )
	site_id         <- long_out[row[1], 'site_id']
	visit_name      <- long_out[row[1], 'visit_name']
	data_label      <- 'maximum'
	modifier_cd     <- '@'
	data_value      <- long_out[row[1], 'data_value']
	units_cd        <- long_out[row[1], 'units_cd']
	date_timestamp  <- long_out[row[1], 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[row[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# St-dev
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'std-dev'
	modifier_cd     <- '@'
	data_value      <- sd(as.numeric(as.character(values)))
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Number
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'number'
	modifier_cd     <- '@'
	data_value      <- length(values)
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Summation
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'sum'
	modifier_cd     <- '@'
	data_value      <- sum(as.numeric(as.character(values)))
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
  	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
  }
}

addLongitudinalDerivedConceptsFactor <- function(long_out, firstWrite) {
  
  # Handle the collected longitudinal data. Show derived data (first, last, number, freq, factor, ...)
  subjects <- unique(long_out$subject_id)
  for (subject_id in subjects) {
	rows       <- which( long_out$subject_id == subject_id)
        values     <- long_out[rows, 'data_value']
	node_label <- paste(long_out[rows[1], 'category_cd'], '+', long_out[rows[1], 'data_label'], '_serie', sep='')
	# first value
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'first'
	modifier_cd     <- '@'
	data_value      <- long_out[rows[1], 'data_value']
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- long_out[rows[1], 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	firstWrite <- FALSE
	# last value
	last_row <- rows[length(rows)]
	site_id         <- long_out[last_row, 'site_id']
	visit_name      <- long_out[last_row, 'visit_name']
	data_label      <- 'last'
	modifier_cd     <- '@'
	data_value      <- long_out[last_row, 'data_value']
	units_cd        <- long_out[last_row, 'units_cd']
	date_timestamp  <- long_out[last_row, 'date_timestamp']
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[last_row, 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Number
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	data_label      <- 'number'
	modifier_cd     <- '@'
	data_value      <- as.character(length(values))
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
	output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                             data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                             "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
	write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                    row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
	# Fraction
	site_id         <- long_out[rows[1], 'site_id']
	visit_name      <- long_out[rows[1], 'visit_name']
	modifier_cd     <- '@'
	units_cd        <- long_out[rows[1], 'units_cd']
	date_timestamp  <- ''
	category_cd     <- node_label
	ctrl_vocab_code <- long_out[rows[1], 'ctrl_vocab_code']
        for ( fact in levels(values)) {
	    if (length(values[values==fact]) > 0 ) {
	        data_value      <- as.character(length(values[values==fact]) / length(values))
	        data_label      <- paste('fraction_', fact, sep="")
	        flush.console()
	        output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                                   data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                                   "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
		write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                            row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
            }
 	} 
  }
}

###############################################################################
# Here it begins.
###############################################################################

# The "default" outputFile
outputFile <- "output.tsv"

# Get arguments and assign values
args   <- commandArgs(trailingOnly = TRUE)
argmat <- sapply(strsplit(args, '='), identity)
for (i in seq.int(length=ncol(argmat))) {
      assign(argmat[1, i], argmat[2, i])
}  

if ( exists("studyID")       == FALSE |
     exists("columnMapFile") == FALSE  ) 
{
   print("Usage: Rscript load_clinical_data.R studyID=<identifier>")
   print("                                    columnMapFile=<filename>")
   print("                                    [wordMapFile=<filename>]")
   print("                                    [outputFile=<filename>]")
   stop("Please specify mandatory aruments")
}


columnMapTable <- readColumnMapFile(columnMapFile) 
wordMapTable   <- readWordMapFile(wordMapFile)

# Get the filenames with observations from "columnMap"
  dataFiles <- unique(columnMapTable$filename)

  firstWrite <- TRUE
  for (dataFile in dataFiles) {
     
      dataTable <- readDataFile(dataFile)
      nRowsDataTable <- length(dataTable[,1]) 
      
      # Find column with "SUBJ_ID" in dataTable
      subjectIDrow = which( columnMapTable$filename  == dataFile & 
                            columnMapTable$dataLabel == "SUBJ_ID"  )
      subjectIDcolumn = columnMapTable$columnNr[subjectIDrow]      
      subject_id <- dataTable[,subjectIDcolumn]
      
      # Get studyID
      study_id <- studyID

      # Get siteIDs
      site_id <- character(length(subject_id))
      siteIDrow = which(columnMapTable$filename  == dataFile & 
                        columnMapTable$dataLabel == "SITE_ID" )
                        
      if (length(siteIDrow) == 1) {
	  siteIDcolumn <- columnMapTable$columnNr[siteIDrow]
	  site_id      <- dataTable[, siteIDcolumn]
      }

      # Get visitNames
      visit_name = character(length(subject_id))
      visitNameRow = which(columnMapTable$filename  == dataFile &
                           columnMapTable$dataLabel == "VISIT_NAME" )

      if (length(visitNameRow) == 1) {
          visitNameColumn <- columnMapTable$columnNr[visitNameRow]
          visit_name      <- dataTable[, visitNameColumn]
      }

      # Find the columns with a Data Label that's not a reserved word
      index <- which( columnMapTable$dataLabel != "SUBJ_ID"    & 
                      columnMapTable$dataLabel != "UNITS"      & 
                      columnMapTable$dataLabel != "MODIFIER"   & 
                      columnMapTable$dataLabel != "TIMESTAMP"  & 
                      columnMapTable$dataLabel != "OMIT"       & 
                      columnMapTable$dataLabel != "SITE_ID"    & 
                      columnMapTable$dataLabel != "VISIT_NAME" & 
                      columnMapTable$dataLabel != "DATA_LABEL" &
                      columnMapTable$filename  == dataFile
                    )
      # Iterate over these rows in columnMapTable-file
      for ( i in index ) {
          
          # Get category_cd (concept_cd) for these observations 
          category_cd <- rep(columnMapTable$categoryCode[i], nRowsDataTable)

          # Get the label for these observations
          data_label <- rep(columnMapTable$dataLabel[i], nRowsDataTable)
          print(paste("  Observation: ", category_cd[1], " + ", data_label[1]))

          # Apply wordmap to this column
          dataTable <- applyWordMap(wordMapTable, dataFile, dataTable, columnMapTable$columnNr[i])

          # set MODIFIER_CD
          modifier_cd <- "@"

          # Get the UNITS if available
          units_cd <- getUnitsForColumn(columnMapTable, dataTable, columnMapTable$columnNr[i])
          
          # Get the TIMESTAMP if available
          date_timestamp <- getTimestampsForColumn(columnMapTable, dataTable, columnMapTable$columnNr[i])
        
          # Get ctrl_vocab_code for these observations
	  ctrl_vocab_code <- columnMapTable$controlledVocabCode[i] 

	  # Handle references to DATA LABEL columns (clumbsy, who can do better?)
          if (grepl("^[\\]"           , columnMapTable$dataLabel[i])       &
              grepl("[0-9]+(,[0-9]+)*", columnMapTable$dataLabelSource[i])   ) 
          {
                if (grepl("%", category_cd[1]) | grepl("%", data_label[1]))
		{
			dl_columns <- strsplit(columnMapTable$dataLabelSource[i], ',')
			count <- 1
	                for (pos in as.numeric(unlist(dl_columns))) 
        	        {
				for (row in c(1:nRowsDataTable)) 
                        	{
					category_cd[row] <- gsub(paste("%", count, sep=""), 
        	                                               dataTable[row,as.numeric(pos)], 
                	                                       category_cd[row] )
 				}
			
				for (row in c(1:nRowsDataTable)) 
        	                {
					data_label[row] <- gsub(paste("%", count, sep=""), 
                        	                               dataTable[row,as.numeric(pos)], 
                                	                       data_label[row] )
	 			}
				count <- count + 1
			}
		}
		else 		# add to end of data_label (backwards compatibility)
    		{
			data_label <- paste(data_label, "\\", dataTable[,as.numeric(columnMapTable$dataLabelSource[i])], sep="")
			print("    Depricated functionality.")
			print("    Please specify '%1' in 'catogory_code' or 'data_label' to insert label column next time")
		}
	  }

	  # Are there MODIFIERS for this concept? If there are MODIFIERS we do not write the original
          # data we only write derived data
          modRow <- which( columnMapTable$filename  == dataFile &
                           columnMapTable$dataLabel == "MODIFIER" &
                           columnMapTable$dataLabelSource == columnMapTable$columnNr[i])

	  # Write Concept
          data_value <- dataTable[, columnMapTable$columnNr[i]]
	  index <- which(data_value != "")
          tmp_output <- data.frame(study_id, site_id, subject_id, visit_name, "", 
                                   data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                                   "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
	  output <- tmp_output[index, ]
	  #write.table(output, file=outputFile, append=!firstWrite, sep="\t",
          #          row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
          #firstWrite <- FALSE
          # now write_table should be done. We only write it if no modifiers exist for this concept

          # Write optional MODIFIER data
	  long_out <- output   # collect longitudinal data (dataLabel == MODIFIER)
          modNr  <- 1
          for (modNr in modRow) {
		print(paste("    MODIFIER found in column: ", columnMapTable$columnNr[modNr]))
		# Apply wordmap to this column
                dataTable <- applyWordMap(wordMapTable, dataFile, dataTable, columnMapTable$columnNr[modNr])
                dataTable <- applyWordMapAs(wordMapTable, dataFile, dataTable, 
                                               columnMapTable$columnNr[modNr], columnMapTable$columnNr[i])

                # set MODIFIER_CD
                modifier_cd <- columnMapTable$controlledVocabCode[modNr]
		if (nchar(modifier_cd) == 0) { modifier_cd <- paste("SERIES", ":", modNr, sep="")}

                # Get the UNITS if available
                units_cd <- getUnitsForColumn(columnMapTable, dataTable, columnMapTable$columnNr[modNr])

                # Get the TIMESTAMP if available
                date_timestamp <- getTimestampsForColumn(columnMapTable, dataTable, columnMapTable$columnNr[modNr])

                data_value <- dataTable[, columnMapTable$columnNr[modNr]]
		index <- which(data_value != "") 
                tmp_output <- data.frame(study_id, site_id, subject_id, visit_name, "",
                                         data_label, data_value, category_cd, "", "", "", units_cd, "", "", "",
                                         "", "", "", "", "", date_timestamp, ctrl_vocab_code, modifier_cd, "")
            	output <- tmp_output[index,]
                #write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                #            row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
		#firstWrite <- FALSE

		long_out <- rbind(long_out, output)   # Add to already collected longitudinal data

          }

	  if (length(modRow) > 0) { 
		addLongitudinalDerivedConcepts(long_out, firstWrite)
		firstWrite <- FALSE 
	  } else {
		write.table(output, file=outputFile, append=!firstWrite, sep="\t",
                      row.names=FALSE, col.names=firstWrite, quote=FALSE, na="")
                firstWrite <- FALSE
	  }
      }
  }



  # To see warnings: uncomment the following line
   warnings()
