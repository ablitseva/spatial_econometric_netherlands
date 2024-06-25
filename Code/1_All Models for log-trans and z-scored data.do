clear all
set more off
cd "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Data"

***STEP1:Preprocess Prosumers***
***Transform CBS data from csv. to dta. format***
clear all
import delimited "Prosumers.csv"
describe
drop if pv_numb == .
rename _id _ID
sort _ID
save "Prosumers.dta", replace

***Explore data***
describe

*** Data cleaning: clean nonnumeric characters ***
foreach var in price_gas owned_share single_share emission {
    replace `var' = subinstr(`var', ",", ".", .)
    destring `var', replace
}

***Declare panel data settings****
xtset _ID year 

save "Prosumers.dta", replace
***LOG_RANSFORMED AND Z-SCORE VARIABLES****
///Generate log transformations
local vars pv_numb density emission housing_stock
foreach var in `vars' {
    gen ln_`var' = ln(`var')
}

***Data normalization: z-score standardization of variables**
foreach var of varlist income_av higheduc_rate unemploym  price_electr consump_electr owned_share single_share {
    summarize `var'
    local mean_`var' = r(mean)
    summarize `var'
    local sd_`var' = r(sd)
    gen z_`var' = (`var' - `mean_`var'') / `sd_`var''
}

****VIF: multicolliniarity test***
reg ln_pv_numb z_income_av ln_density z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock z_owned_share z_single_share ln_emission
asdoc estat vif, save(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/VIFTEST)

///generate composed variable from z_single_share and z_owned_share
generate z_compos = (z_owned_share + z_single_share) / 2

reg ln_pv_numb z_income_av ln_density z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock z_compos ln_emission
asdoc estat vif, save(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/VIFTEST_2)

///drop: z_compos and ln_density
reg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock ln_emission
asdoc estat vif, save(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/VIFTEST_2)

///Hausman tests: to determine if a fixed effects or random effects regression is more appropriate.
xtreg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock ln_emission, fe
estimates store fixed
xtreg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock ln_emission, re
estimates store random
hausman fixed random, sigmamore
***p<0.05 indncates that Fixed-effect is more appropriate 

****MODEL 1: Fixed-Effect model (FE)
eststo: xtreg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, fe

****MODEL 1.1: Fixed-Effect model (FE) +Time fixed effect
eststo: xtreg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission i.year, fe

****TEST FOR DUMMIES***
// creates a dummy variable per year
quietly tabulate year, generate(dyr)
xtreg ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_price_electr z_consump_electr ln_housing_stock ln_emission dyr2-dyr8, fe
* We can test if dummy year variables are jointly signficant
test (dyr2 dyr3 dyr4 dyr5 dyr6 dyr7 dyr8) // Result: The p-value (0.0000) is less than the common significance level of 0.05. Therefore, you reject the null hypothesis that all the year dummy coefficients are jointly zero.

///Compare models above
esttab, star(* 0.10 ** 0.05 *** 0.01)  r2(4) ar2(4)
asdoc esttab, star(* 0.10 ** 0.05 *** 0.01) se(4), save(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/FE_TABLE)

clear all
cd "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Data"

use "netherlands_provinces-polygon.dta", clear
***Create inverse distance matrix W where _CX and _CY are coordinates of centroids***
// INVERSE DISTANCE MATRIX
// spmat idistance W  _CX _CY, id(_ID) normalize(row)

// CONTIGUITY MATRIX
shp2dta using netherlands_provinces-polygon, database(provinces) coordinates(provincesxy) genid(id) gencentroids(c) replace
spmat contiguity W using provincesxy, id(_ID) normalize(row)

***Analyze W matrix***
spmat graph W
graph export "/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Pictures/spmat.png", replace
spmat summarize W // make sure that W of spmat is same as for spmatrix

//Display W matrix
spmat getmatrix W mymat
mata:  mymat

///Load data of prosumers
use "Prosumers.dta", clear

xtset _ID year
spbalance

***LOG_RANSFORMED AND Z-SCORE VARIABLES****
///Generate log transformations
local vars pv_numb density emission housing_stock
foreach var in `vars' {
    gen ln_`var' = ln(`var')
}

***Data normalization: z-score standardization of variables**
foreach var of varlist income_av higheduc_rate unemploym price_gas price_electr consump_gas consump_electr owned_share single_share {
    summarize `var'
    local mean_`var' = r(mean)
    summarize `var'
    local sd_`var' = r(sd)
    gen z_`var' = (`var' - `mean_`var'') / `sd_`var''
}

****MODEL 2: Spatial-AutoRegressive model(SAR)
eststo: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) model(sar) fe dlag(3) type(ind) nolog

****MODEL 3: Spatial-Error model(SEM)
eststo: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, emat(W) model(sem) fe type(ind) nolog


****MODEL 4: Spatial Durbin model (SDM)
eststo: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) model(sdm) dlag(3) fe durbin(z_income_av z_higheduc_rate ln_emission) type(ind) nolog 

eststo: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) model(sdm) dlag(3) fe durbin(z_income_av z_higheduc_rate ln_emission) type(ind) effects nolog 

esttab, star(* 0.10 ** 0.05 *** 0.01)  r2(4) ar2(4)
asdoc esttab, star(* 0.10 ** 0.05 *** 0.01) r2(4) ar2(4) se(4), save(/Users/ablitseva/Documents/Stata/1_Thesis/6_STATA/Results/SPAT_TABLE)


xsmle ln_pv_numb ln_density z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) ematrix(W) model(sac) fe type(both) nolog

//Analysis SAR SDM SEM
*** xsmle - A Command to Estimate Spatial Panel Models in Stata***
** wmat() - accepts the contiguity weight matrix (W in our case)***
** model(name) - specifies the spatial model to be estimated. May be sar for the Spatial-AutoRegressive model, sdm for the Spatial Durbin Model, sem for the Spatial-Error Model, sac for the Spatial-Autoregressive with Spatially Autocorrelated Errors Model, gspre for the Generalised Spatial Random Effects Model.***
***re - use the random effects estimator; the default. This option cannot be specified when model(sac).
** fe - fe use the fixed effects estimator. This option cannot be specified when model(gspre); 
****type(ind) SAR with spatial fixed-effects; fe type(time) SAR with time fixed-effects
** nolog
***dlag(dlag) defines the structure of the spatiotemporal model. When dlag is equal to 1, only the time-lagged dependent variable is included; when dlag is equal to 2, only the space-time-lagged dependent variable is included; when dlag is equal to 3, both the time-lagged and space-time-lagged dependent variables are included.
///Wx:  changes in dependent variable affected by independent variable in neighbouring province. Example:  normalized_income_av= 1.888932, means that 1 Standard Deviation(std)  increase in income of neighbouring province leads to 1.888 std increase in numbers of PV.


////The Likelihood Ratio (LR) test is a statistical test used to compare the goodness-of-fit of two nested models. 
quietly: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) model(sar) fe dlag(3) type(ind) nolog
estimates store null_model

quietly: xsmle ln_pv_numb z_income_av z_higheduc_rate z_unemploym z_consump_electr ln_housing_stock ln_emission, wmat(W) model(sdm) dlag(3) fe durbin(z_income_av z_higheduc_rate ln_emission) type(ind) nolog
estimates store alternative_model
lrtest null_model alternative_model
estat ic
///The Akaike Information Criterion (AIC) and Bayesian Information Criterion (BIC) values for the alternative model.
estat ic
