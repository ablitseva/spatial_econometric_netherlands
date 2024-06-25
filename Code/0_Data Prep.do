clear all
set more off
cd "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Data"

***Preprocess Provinces***
***STEP 1 - Unzip shapefile***
unzipfile "mygeodata.zip", replace

***Create shapefile (.dta format)***
spshape2dta "netherlands_provinces-polygon", replace

***Explore data***
use "netherlands_provinces-polygon", clear
describe
list

***Preprocess Prosumers***
***STEP 2 - Transform CBS data from csv. to dta. format ***
clear all
import delimited "Prosumers.csv"
describe
rename _id _ID
sort _ID
drop if pv_numb==.
save "Prosumers.dta", replace
describe
asdoc sum, save(sumstattable)

***Data cleaning: clean nonnumeric characters***
foreach var in price_gas owned_share single_share emission {
    replace `var' = subinstr(`var', ",", ".", .)
    destring `var', replace
}

sort _ID
describe

save "Prosumers.dta", replace

