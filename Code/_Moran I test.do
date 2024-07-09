clear all
set more off
cd "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Data"

use "Merged_Prosumers_Provincies.dta", clear

spset
xtset

*** Preparation of panel data****
***Verify that _ID and year jointly identify the observations
assert _ID!=.
assert year!=.
bysort _ID year: assert _N==1

***xtset the data and verify that coordinates (_CX and _CY) are constant within panel
xtset _ID year
bysort _ID (year): assert _CX == _CX[1]
bysort _ID (year): assert _CY == _CY[1]

spmatrix create contiguity W if year == 2013, normalize(row) replace
spmatrix export W using "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.csv", replace
import delimited "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.csv", clear delimiter(space)
drop if v2==.
drop v1
save "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix", replace


use "Merged_Prosumers_Provincies.dta", replace

***Data cleaning: clean nonnumeric characters***
foreach var in price_gas owned_share single_share emission {
    replace `var' = subinstr(`var', ",", ".", .)
    destring `var', replace
}

spmatrix dir
spmatrix summarize W

xtmoran pv_numb, wname("/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.dta") morani(2013 2014 2015 2016 2017 2018 2019 2020 2021 2022)

***SAVE RESULTS - doc.**
asdoc xtmoran pv_numb, wname(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.dta) morani(2013 2014 2015 2016 2017 2018 2019 2020 2021 2022) save(XTMORANTEST)

asdoc xtmoran emission, wname(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.dta) save(XTMORANTEST_emiss)

***SAVE RESULTS - png.**
xtmoran pv_numb, wname("/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/weights_matrix.dta") morani(2013 2014 2015 2016 2017 2018 2019 2020 2021 2022) graph symbol(_ID)

graph export "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Pictures/pv_installations_map_2022.png", replace
