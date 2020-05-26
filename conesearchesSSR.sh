# !/bin/bash


if [[ $# -eq 0 ]] ; then
    echo 'input file missing'
    echo 'run: sh conesearchesSSR.sh input_file.csv config mode'
    echo 'input_file format: CODE|SB_name|Band|Config|[Epoch]'
    echo 'modes:'
    echo '1 : SSR for all compatible SBs, and HardCode for SBs with no SSR results'
    echo '2 : SSR and HardCode for all SBs'
    echo '3 : SSR only'
    
    exit 1
fi


this_file=$0

YMD=$(date +%FT%H%M%S)


# input list file of SBs

SB_list_file=$1

config=$2

mode=$3

echo "SB list file = $SB_list_file"

echo "config = $config"

echo "mode = $mode"


mkdir conesearch_${config}_${YMD}_mode_${mode}


# old environment, no coordinates error in results
# source ~ahirota/setupEnvC7.sh

# new environment

source /users/ahirota/setupEnvC7.sh
source /users/ahirota/setupEnvC7_sccb1040.sh


# set catalog

# export SOURCECAT_URL=sourcecat.osf.alma.cl
export SOURCECAT_URL=asa.alma.cl
#export SOURCECAT_URL=2020apr.asa-test.alma.cl


# name of file with input parameters

input_params=input_params_${YMD}.txt

touch $input_params

# save script full name and input params

echo $0 $@ > $input_params


# name for file with list of SBs that match the requested configuration 

SBs_config_file=SBs_${config}_${SB_list_file}

touch $SBs_config_file


# name for file with calibrators and info for SBs:

CS_calibs_file=CS_simulateSB_SSR_${config}_${SB_list_file}.txt

touch $CS_calibs_file


# name for file with lists of SBs with no SSR results:

no_calibs_file=No_SSR_calibs_${config}_${SB_list_file}

touch $no_calibs_file


# name for file with lists of SBs for HC search:

SB_list_HC_file=SBs_forHC_${config}_${SB_list_file}

touch $SB_list_HC_file


# name for file with hardcoded calibrators and info for SBs:

CS_calibs_HC_file=CS_simulateSB_HC_${config}_${SB_list_file}.txt

touch $CS_calibs_HC_file


# name for file with lists of SBs with no HC results

no_calibs_HC_file=No_HC_calibs_${config}_${SB_list_file}

touch $no_calibs_HC_file



# name of file with quick sourcelist

CS_sourcelist_file=CS_sourcelist_${config}_${SB_list_file}.txt 

touch $CS_sourcelist_file



# header of files with results

echo "ProjectCode|SB_name|Band|Nom_Conf|Run_Conf|Calib_type|Calib_name|Flux|Separation|SNR|Date|dDays|uvMax|uvMin|dRA|dDEC|rank|Epoch|params|script_run_date"  > $CS_calibs_file

echo "ProjectCode|SB_name|Band|Nom_Conf|Run_Conf|Calib_type|Calib_name|Flux|Separation|SNR|Date|dDays|uvMax|uvMin|dRA|dDEC|rank|Epoch|params|script_run_date"  > $CS_calibs_HC_file



# directories to save files:

mkdir results

mkdir OSS_files

mkdir summary_files

mkdir scan_list_files

mkdir gCC_files

mkdir xml_files

mkdir scripts



# read input list of SBs

while IFS='|' read -r col1 col2 col3 col4 col5 col6
do 
    
    CODE=$col1
    SB_name=$col2
    Band=$col3
    conf=$col4
    Epoch=$col5
    
    if [ "$Epoch" == "" ] ; then
	
	Epoch="TRANSIT-1h"
    fi
    
    # only select the SBs that match the requested configuration
    
    if [[ $conf == *$config* ]]; then
	
	
        # save SB info in file with list of SBs that match the requested configuration 
	    
	echo ""
	
	echo "$col1|$col2|$col3|$col4|$col5"
	
	echo "$col1|$col2|$col3|$col4|$col5" >> $SBs_config_file
	
	
        # run calibrator search for SB
	
        # define special mixed ACA configurations
 	
	if [ $config == "7M1PM" ] ; then
	    
	    conf_run="/users/ahirota/etc/aca.cm10.pm1.cfg"
	    
	elif [ $config == "7M2PM" ] ; then
	    
	    conf_run="/users/ahirota/etc/aca.cm10.pm2.cfg"
	    
	elif [ $config == "7M3PM" ] ; then
	    
	    conf_run="/users/ahirota/etc/aca.cm10.pm3.cfg"
	    
	elif [ $config == "7M4PM" ] ; then
	    
	    conf_run="/users/ahirota/etc/aca.cm10.pm4.cfg"
	    
	else
	    
	    conf_run=$config
	    
	fi
	
	
	command="simulateSB.py $CODE $SB_name $Epoch -C $conf_run"
	
	echo "$command"
	
	$command
	
	
        # file name for summary results:
	
	summary_file=log_${CODE}_${SB_name}.xml_OSS_summary.txt
	
        # file name for  detailed results:
	
	OSS_file=log_${CODE}_${SB_name}.xml_OSS.txt
	
        # check if calibrator search was succesful
	
	if test -f "$summary_file"; then
	    
	    
           # check if SB already has hardcoded calibrators
	    
	    grep "revertHardcodedSources" $OSS_file > hardcod_${OSS_file}
	    
	    
            # if hardcod file is not empty, save hardcoded calibs in quick-ourcelist and put SB in No-Calibs list
	    
	    if [[ -s hardcod_${OSS_file} ]] ; then
		
		
                # parse hardcoded cal file and save calibrators in sourcelist file
		
		
		while read line;
                do
		    
                    # extract hardcoded calibrator name
		    
		    
		    OIFS=$IFS
		    
		    IFS='=' read -r -a array <<< $line
		    
		    calib=${array[1]:0:10}
		    
		    IFS=$OIFS
		    
		    
		    # write fardcoded calib in sourcelist file
		    
		    echo "$calib 1 1" >> $CS_sourcelist_file
		    
                done < hardcod_${OSS_file}
		
		
	        # put SB in No-Calibs list
		
		echo "$col1|$col2|$col3|$col4|$col5" >> $no_calibs_file
		
	    else
		
		
	        # SEARCH FOR CALIBRATORS FROM simulateSB OUTPUT
		
                # extract phase cal info from OSS file
		
	        # get the first three calibrator candidates
		
		grep -A 6 "Listing ranked candidate list... \[phase" $OSS_file > phase_${OSS_file}
		
		
                # extract check source info from OSS file
		
	        # get the first three calibrator candidates
		
		grep -A 6 "Listing ranked candidate list... \[check" $OSS_file > check_${OSS_file}
		
	    	
                # parse and save results from phase cal file
		
	        # calib candidate line counter
		
		
		i=0
		
		calib_type='phase'
		
		while read line;
		do
		    if echo $line | grep -q "\[J" ; then
			
		       	
			OIFS=$IFS
			
			IFS='|' read -r -a array <<< $line
			
			calib=${array[1]:1:10}
			
			flux=${array[10]}
			
			SNR=${array[11]}
			
			sep=${array[12]}
			
			date=${array[9]}
			
			days=${array[16]}
			
			UVmax=${array[17]}
			
			UVmin=${array[18]}
			
			dRA=${array[4]}
			
			dDEC=${array[5]}
			
			score=${array[19]}
			
			
			# save valid results
			
			if   ! echo $score | grep -q "-"    ; then
			    
			    echo "$CODE|$SB_name|$Band|$conf|$config|$calib_type|$calib|$flux|$sep|$SNR|$date|$days|$UVmax|$UVmin|$dRA|$dDEC|$i|$Epoch|SSR|$YMD"  >> $CS_calibs_file
			    
                        fi
			
			
			# save best calibrators in quick sourcelist file
			
			if [ $i -eq 0 ] ; then
			    
			    echo "$calib 1 1" >> $CS_sourcelist_file
			    
			fi
			
			IFS=$OIFS
			
			i=$(( $i + 1 ))
			
		    fi
		done < phase_${OSS_file}
		
		
                # parse and save results from check source file
		
                # calib candidate line counter
		
                i=0
		
		calib_type='check'
		
                while read line;
                do
		    if echo $line | grep -q "\[J" ; then
			
                        OIFS=$IFS
			
                        IFS='|' read -r -a array <<< $line
			
                        calib=${array[1]:1:10}
			
                        flux=${array[10]}
			
                        SNR=${array[11]}
			
                        sep=${array[12]}
			
                        date=${array[9]}
			
                        days=${array[16]}
			
                        UVmax=${array[17]}
			
                        UVmin=${array[18]}
			
                        dRA=${array[4]}
			
                        dDEC=${array[5]}
			
			score=${array[19]}
			
			
                        # save valid results                                                                                                                                                                                                                                    
			
                        if   ! echo $score | grep -q "-"    ; then
			    
			    echo "$CODE|$SB_name|$Band|$conf|$config|$calib_type|$calib|$flux|$sep|$SNR|$date|$days|$UVmax|$UVmin|$dRA|$dDEC|$i|$Epoch|SSR|$YMD"  >> $CS_calibs_file
			    
                        fi
			
			
                        # save best calibrators in quick sourcelist file                                                                                                                                                                                                        
			
                        if [ $i -eq 0 ] ; then
			    
			    echo "$calib 1 1" >> $CS_sourcelist_file
			    
                        fi
			
                        IFS=$OIFS
			
			
                        i=$(( $i + 1 ))
			
		    fi
                done < check_${OSS_file}
		

	    fi
	    
        # add SB in no-calibs-file  if no results found
	    
	else
	    
	    echo "$col1|$col2|$col3|$col4|$col5" >> $no_calibs_file
	    
	fi
	
    fi
    
done < $SB_list_file



# remove whitespaces in results file

sed -r -i 's/\s+//g'  $CS_calibs_file


# clean up                                                                                                                                                                                                         



mv *OSS.txt OSS_files/.

mv *OSS_summary.txt summary_files/.

mv *scan_list.txt scan_list_files/.




# search for hardcoded calibrators  (HC)


# run HC search only for modes 1 and 2                                                                                                                                                                                                    


if [ "$mode" == "1" -o "$mode" == "2" ] ; then

    
    echo ""
    
    echo "HARDCODING SEARCH"
    
    echo ""

    # by default search calibs for SBs without SSR results

    cp  $no_calibs_file $SB_list_HC_file


    # search calibs for all SBs if mode == 2 

    if [ "$mode" == "2" ] ; then


	cp  $SBs_config_file $SB_list_HC_file 

    fi

    while IFS='|' read -r col1 col2 col3 col4 col5 col6
    do
	
	CODE=$col1
	SB_name=$col2
	Band=$col3
	conf=$col4
	Epoch=$col5
	
	xml_filename=${CODE}_${SB_name}.xml
	

       # check if xml file exists
	
	if test -f "$xml_filename"; then
	    
	    
	    
	    if [ "$Epoch" == "" ] ; then
		
		Epoch="TRANSIT-1h"
	    fi
	
	    
            # only select the SBs that match the requested configuration                                                                                                                                                                                                                                                                                                                             
	    
	    if [[ $conf == *$config* ]]; then
		
		
		
		echo ""
		
		echo "$col1|$col2|$col3|$col4|$col5"
	    
		
                # run calibrator search for SB                                                                                                                                                                                                                                                                                                                                                       
		extra_params=""
	    
  	    # select hardcod search-parameters based on band and configurations
		
		
		if [ "$config" == "7M"  -o "$config" == "7M1PM"  -o "$config" == "7M2PM"  -o "$config" == "7M3PM"  -o "$config" == "7M4PM" ] ; then
		    
		    tint=60
		    
		    radius=20
	    	    
		elif [ "$config" == "C43-1" -o "$config" == "C43-2" -o "$config" == "C43-3" -o "$config" == "C43-4" -o "$config" == "C43-5" -o "$config" == "C43-6" ] ; then
		    
		    
		    tint=60
		    
		    radius=15
		    
		    
		elif [ "$config" == "C43-7" ] ; then
		    
		    tint=18
		    
		    radius=12
		    
		    
		    if [ "$Band" == "ALMA_RB_08" -o "$Band" == "ALMA_RB_09" -o "$Band" == "ALMA_RB_10" ] ; then
			
			tint=54
			
			radius=7
			
		    fi
		    
		elif [ "$config" == "C43-8" -o "$config" == "C43-9" -o "$config" == "C43-10" ] ; then
		    
		    tint=18
		    
		    radius=12
		    
		    if [ "$Band" == "ALMA_RB_07" -o "$Band" == "ALMA_RB_08" -o "$Band" == "ALMA_RB_09" -o "$Band" == "ALMA_RB_10" ] ; then
			
		    # Band to Band option for longest baselines and higher frequencies 
			
			tint=18
			
			radius=5.75
			
			extra_params=" --spectralSpec=calsurvey,3 "
			
			
		    fi
		    
		fi
		
		
	    # reset best HC phase calib
		
		best_phase_calib=''
		
	    # run getCalibratorCandidates.py script to get phase calibrator
		
            # define special mixed ACA configurations                                                                                                                                                                  
		
		if [ $config == "7M1PM" ] ; then
		    
		    conf_run="/users/ahirota/etc/aca.cm10.pm1.cfg"
		    
		elif [ $config == "7M2PM" ] ; then
		    
		    conf_run="/users/ahirota/etc/aca.cm10.pm2.cfg"
		    
		elif [ $config == "7M3PM" ] ; then
		    
		    conf_run="/users/ahirota/etc/aca.cm10.pm3.cfg"
		    
		elif [ $config == "7M4PM" ] ; then
		    
		    conf_run="/users/ahirota/etc/aca.cm10.pm4.cfg"
		    
		else
		    
		    conf_run=$config
		    
		fi
		
		echo "getCalibratorCandidates.py $xml_filename  --workaroundForICT10449 -c phase  -t $tint -r $radius  -C $conf_run  -e $Epoch  > log_phase_gCC_${CODE}_${SB_name}.txt"
		
		getCalibratorCandidates.py $xml_filename --workaroundForICT10449  $extra_params -c phase  -t $tint -r $radius  -C $conf_run  -e $Epoch  > log_phase_gCC_${CODE}_${SB_name}.txt
		
		
	    # extract phase cal info from log_gCC file
		
            # get the first three calibrator candidates                                                                                                                                                                                                                                                                                                                                  
		
		grep -A 6 "Listing ranked candidate list... \[phase" log_phase_gCC_${CODE}_${SB_name}.txt  > phase_gCC_${CODE}_${SB_name}.txt
		
		
            # parse and save results from phase cal file                                                                                                                                                                                                                                                                                                                                                                                                                                
		
            # calib candidate line counter                                                                                                                                                                                                                                                                                                                                                                                                                                              
		
		i=0
		
		calib_type='phase'
		
		
		while read line;
		do
		    if echo $line | grep -q "\[J" ; then
        		
			
			OIFS=$IFS
			
			IFS='|' read -r -a array <<< $line
			
			
			calib=${array[1]:1:10}
			
			flux=${array[10]}
			
			SNR=${array[11]}
			
			sep=${array[12]}
			
			date=${array[9]}
			
			days=${array[16]}
			
			UVmax=${array[17]}
			
			UVmin=${array[18]}
			
			dRA=${array[4]}
			
			dDEC=${array[5]}
			
			score=${array[19]}
			
			
                    # save valid results                                                                                                                                                                                                                                                                                                                                                                                                                                                
			
			if   ! echo $score | grep -q "-"    ; then
			    
			    echo "$CODE|$SB_name|$Band|$conf|$config|$calib_type|$calib|$flux|$sep|$SNR|$date|$days|$UVmax|$UVmin|$dRA|$dDEC|$i|$Epoch|SPWAVG_t${tint}_r${radius} $extra_params|$YMD"  >> $CS_calibs_HC_file
			    
			    
                        # save best calibrators in quick sourcelist file                                                                                                                                                                                                                                                                                                                                                                                                                            
			    
			    if [ $i -eq 0 ] ; then
				
				echo "$calib 1 1" >> $CS_sourcelist_file
				
			    # save best phase calib if valid, to use in check source search
				
				best_phase_calib=$calib
				
				
			    fi
			    
			    
			fi
			
			
			IFS=$OIFS
			
			i=$(( $i + 1 ))
			
		    fi
		done < phase_gCC_${CODE}_${SB_name}.txt	
		
		
		
	    # If phase calibrator search is succesfull look for check source
		
		
	    # reset best HC check source
		
		best_check_calib=''
		
		
		if [ "$best_phase_calib" != "" ] ; then
		    
                # run getCalibratorCandidates.py script to get check source
		    
		    
		    echo "getCalibratorCandidates.py $xml_filename  --workaroundForICT10449 -c check  -t 30 -r $radius  -C $conf_run  -e $Epoch --src $best_phase_calib  > log_check_gCC_${CODE}_${SB_name}.txt"
		    
		    getCalibratorCandidates.py $xml_filename --workaroundForICT10449  $extra_params -c check  -t 30 -r $radius  -C $conf_run  -e $Epoch --src $best_phase_calib  > log_check_gCC_${CODE}_${SB_name}.txt
		    
		    
		    
	        # extract check source info from log_gCC file
		    
                # get the first three calibrator candidates
		    
		    grep -A 6 "Listing ranked candidate list... \[check" log_check_gCC_${CODE}_${SB_name}.txt  > check_gCC_${CODE}_${SB_name}.txt
		    
		    
                # parse and save results from check src file
		    
                # calib candidate line counter
		    
		    i=0
		    
		    calib_type='check'
		    
		    while read line;
		    do
			if echo $line | grep -q "\[J" ; then
        		    
			    
			    OIFS=$IFS
			    
			    IFS='|' read -r -a array <<< $line
			    
			    
			    calib=${array[1]:1:10}
			    
			    flux=${array[10]}
			    
			    SNR=${array[11]}
			    
			    sep=${array[12]}
			    
			    date=${array[9]}
			    
			    days=${array[16]}
			    
			    UVmax=${array[17]}
			    
			    UVmin=${array[18]}
			    
			    dRA=${array[4]}
			    
			    dDEC=${array[5]}
			    
			    score=${array[19]}
			    
			    
                        # save valid results
			    
			    if   ! echo $score | grep -q "-"    ; then
				
				echo "$CODE|$SB_name|$Band|$conf|$config|$calib_type|$calib|$flux|$sep|$SNR|$date|$days|$UVmax|$UVmin|$dRA|$dDEC|$i|$Epoch|SPWAVG_t30_r${radius} $extra_params|$YMD"  >> $CS_calibs_HC_file
				
				
                            # save best calibrators in quick sourcelist file
				
				if [ $i -eq 0 ] ; then
				    
				    echo "$calib 1 1" >> $CS_sourcelist_file
				    
                                # save best check calib if valid
				    
				    best_check_calib=$calib
			    	    
				fi
				
				
			    fi
			    
			    
			    IFS=$OIFS
			    
			    i=$(( $i + 1 ))
			    
			fi
			
		    done < check_gCC_${CODE}_${SB_name}.txt
		    
		    
		fi
		
		
            # save SBs without hardcoded calibs, noting the missing type of calib and the search params
		
		if [ "$best_phase_calib" == "" ] ; then
		    
		    echo "$col1|$col2|$col3|$col4|$col5|no_phase|SPWAVG_t${tint}_r${radius}|$YMD" >> $no_calibs_HC_file 
		    
		elif [ "$best_check_calib" == "" ] ; then

		    echo "$col1|$col2|$col3|$col4|$col5|no_check|SPWAVG_t30_r${radius}|$YMD" >> $no_calibs_HC_file

		fi
		
	    fi
	    
	else
	    
	# save SBs without xml file in No_HC calibs file
	    
	    echo "$col1|$col2|$col3|$col4|$col5|no_xml||$YMD" >> $no_calibs_HC_file
	    
	fi
	
    done < $SB_list_HC_file
   
 
    mv *gCC*.txt gCC_files/.

fi


# remove whitespaces in results file

sed -r -i 's/\s+//g'  $CS_calibs_HC_file


# clean up                                                                                                                                                                                                                                   

touch $SBs_config_file

mv $SBs_config_file results/.


touch $CS_calibs_file

mv $CS_calibs_file results/.


touch $no_calibs_file
    
mv $no_calibs_file results/.


touch $SB_list_HC_file

mv $SB_list_HC_file results/.

    
touch $CS_calibs_HC_file
    
mv $CS_calibs_HC_file results/.

    
touch $no_calibs_HC_file
    
mv $no_calibs_HC_file results/.

    

    
# remove duplicates in quick sourcelist file

sort $CS_sourcelist_file | uniq > uniq_${CS_sourcelist_file}

touch $CS_sourcelist_file

touch "uniq_${CS_sourcelist_file}"



# more cleanup                         

mv $CS_sourcelist_file uniq_${CS_sourcelist_file} results/.

mv *.xml xml_files/.


cp $this_file $SB_list_file  scripts/.

mv $input_params scripts/.

mv  OSS_files  summary_files  scan_list_files  gCC_files results  xml_files  scripts conesearch_${config}_${YMD}_mode_${mode}/.

