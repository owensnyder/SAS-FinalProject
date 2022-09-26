/*Programmed by: Owen Snyder
Programmed on: 2021-11-30
Programmed to: Create solution to Final Project
Programmed for: ST555 001

Modified by: N/A
Modified on: N/A
Modified to: N/A*/

/*Gradescope has been making the spacing of my lines appear messy*/

/*Set required paths, filrefs, librefs*/
x "cd L:\st555\Data\BookData\BeverageCompanyCaseStudy";
libname InputDS ".";
filename RawData ".";

x "cd L:\st555\Data";
libname InputFmt ".";

x "cd S:\FinalOwen";
libname Final ".";
filename Final "."; 

/* Set required options and outputs*/
ods listing close;
ods pdf file = "Snyder Final Report.pdf" dpi = 300;
ods graphics on / width = 6.0in;
options nodate;
/*ods _all_ close;*/

/*Retrieve info from Access, store as new data set*/
ods select members;
proc contents data = InputDS._all_ nods;
run;

proc print data = InputDS."Counties"n ;
run;

data Final.Counties;
  set InputDS."Counties"n;
run;

libname InputDS clear;

/*Read in Non-Cola South*/ 
data Final.NonColaSouth;
  length Size  $ 200; 
  infile RawData("Non-Cola--NC,SC,GA.dat") dlm = ' ' dsd firstobs = 7;
  input stateFIPS 1-2 countyFIPS 3-5 ProductName $ 20. Size $ 26-35 ContainerUnit 36-38 
        _Date $ 39-48 UnitsSold 49-55;
run;

/*Read in Energy South*/
data Final.EnergySouth;
  infile RawData("Energy--NC,SC,GA.txt") dlm = '09'x firstobs = 2;
  input stateFIPS countyFIPS ProductName : $ 20. Size : $ 200.  ContainerUnit 
        _Date : $ 9. UnitsSold;
run;

/*Read in Other South*/
data Final.OtherSouth;
  infile RawData("Other--NC,SC,GA.csv") dlm = ',' firstobs = 2;
  input stateFIPS countyFIPS ProductName : $ 50. Size : $ 200. ContainerUnit _Date : $ 9. UnitsSold;
run;

/*Read in Non-Cola North*/
data Final.NonColaNorth;
  infile RawData("Non-Cola--DC-MD-VA.dat") dlm = ' ' dsd  firstobs = 5 ;
  input stateFIPS 2. countyFIPS 3. ProductCode $ 14. @31 _Date :  $ 10. @44 UnitsSold 4.;
run;

/*Read in Energy North*/
data Final.EnergyNorth;
  infile RawData("Energy--DC-MD-VA.txt") dlm = '09'x firstobs = 2;
  input stateFIPS countyFIPS ProductCode : $ 14. _Date : $ 10. UnitsSold;
run; 

/*Read in Other North*/
data Final.OtherNorth;
  infile RawData("Other--DC-MD-VA.csv") dlm = ',' firstobs = 2 dsd;
  input stateFIPS countyFIPS ProductCode : $ 14. _Date : $ 25. UnitsSold;
run;

/*Read in Sodas dataset*/
data Final.Sodas;
infile RawData("Sodas.csv") dlm = ',' dsd firstobs = 6 missover;
input Number ProductName : $ Size : $ Quantity $ Code $ ;
run;

/*Created two custom formats to apply to ProductName*/
proc format library=Final;
  value $prodnamefmtOther
       '1' = 'Non-Soda Ades-Lemonade'
       '2' = 'Non-Soda Ades-Diet Lemonade'
       '3' = 'Non-Soda Ades-Orangeade'
       '4' = 'Non-Soda Ades-Diet Orangeade'
       '5' = 'Nutritional Water-Orange'
       '6' = 'Nutritional Water-Grape'
       '7' = 'Diet Nutritional Water-Orange'
       '8' = 'Diet Nutritional Water-Grape'
  ;
  value $prodnamefmtEnergy
       '1' = 'Zip-Orange'
       '2' = 'Zip-Berry'
       '3' = 'Zip-Grape'
       '4' = 'Diet Zip-Orange'
       '5' = 'Diet Zip-Berry'
       '6' = 'Diet Zip-Grape'
       '7' = 'Big Zip-Berry'
       '8' = 'Big Zip-Grape'
       '9' = 'Diet Big Zip-Berry'
       '10' = 'Diet Big Zip-Grape'
       '11' = 'Mega Zip-Orange'
       '12' = 'Mega Zip-Berry'
       '13' = 'Diet Mega Zip-Orange'
       '14' = 'Diet Mega Zip-Berry'
  ;
run;

/*Concatenate the above data sets with the two SAS files to create AllDrinks*/
options fmtsearch = (InputFmt);
data Final.AllDrinks;
  attrib ProductCategory length = $ 30
         Flavor          length = $ 30
	     ProductCode     length = $ 200
         ;
  set 
     Final.OtherNorth   (in = OtherNorth)
     Final.NonColaNorth (in = NonColaN)
     Final.OtherSouth   (in = OtherSouth)  
     Final.NonColaSouth (in = NonColaS)
     Final.EnergySouth  (in = EnergyS)
	 Final.EnergyNorth  (in = EnergyN)
     InputDS.ColaDCMDVA (in = ColaSASnorth rename = (code = ProductCode))
	 InputDS.ColaNCSCGA (in = ColaSASsouth) 
     ;
  if index(_Date,'/') gt 0 then Date = input(_Date,mmddyy10.);
     else Date = input(_Date, anydtdte.); /*format Date date9.;*/
  if OtherNorth or NonColaN or EnergyN then Region = "North" ;
       else Region = "South";
  if ProductCode ne "" then ProductNumber = substr(ProductCode, 3 , find(ProductCode, '-' , 3) - 3);
  /*Used SAS Documentation to figure out FIND syntax*/
  ProductName = propcase(ProductName);
  if OtherSouth then do;
     if index(ProductName,"Water") gt 1 then ProductCategory = 'Nutritional Water';
       else ProductCategory = 'Non-Soda Ades';
       ProductName = put(ProductNumber,$prodnamefmtOther.); 
       end;
  if ProductCategory = 'Non-Soda Ades' then Flavor = scan(ProductName, -1);
  if EnergyS or EnergyN   then do;
       ProductCategory = 'Energy';
       ProductName = put(ProductNumber, $prodnamefmtEnergy.);
       Flavor = scan(ProductName, -1);
       end;
  if NonColaN or NonColaS then do;
      ProductCategory = 'Soda: Non-Cola';
      Flavor = scan(ProductName, -1);
      end;
  if ColaSASnorth or ColaSASsouth then do;
      ProductCategory = 'Soda: Cola'; 
      ProductName = put(ProductNumber, $prodnames.);
      Flavor = scan(ProductName, -2);
      end;
run;

/*Sort data in preparation for merge*/
proc sort data = Final.AllDrinks;
  by stateFIPS countyFIPS;
run;

proc sort data = InputDS.Counties out = Final.Counties99;
  by stateFIPS countyFIPS;
run;

/*Merge AllDrinks with Counties to produce AllData*/
data Final.AllData;
  attrib
         StateName          length = $ 50   format = $50.     label = 'State Name'
	     stateFIPS                          format = best12.  label = 'State FIPS'
         countyName         length = $ 50   format = $50.     label = 'County Name'
         countyFIPS                         format = best12.  label = 'County FIPS'
         region             length = $ 8    format = $8.      label = 'Region'
	     popestimate2016                    format = comma10. label = 'Estimated Population in 2016'
         popestimate2017                    format = comma10. label = 'Estimated Population in 2017'
	     ProductName        length = $ 50                     label = 'Beverage Name'
	     type               length = $ 8                      label = 'Beverage Type'
	     flavor             length = $ 30                     label = 'Beverage Flavor'
	     ProductCategory    length = $ 30                     label = 'Product Category'
	     ProductSubCategory length = $ 30                     label = 'Product Sub-Category'
	     size               length = $ 200                    label = 'Beverage Volume'
	     unitSize                           format = best12.  label = 'Beverage Quantity'
	     container          length = $6                       label = 'Beverage Container'
	     /*Date                             format = date9.   label = 'Sales Date' */
	     UnitsSold                          format = comma7.  label = 'Units Sold'
	     SalesPerThousand                   format = 7.4      label = 'Sales per 1,000'
         ; 
		 /*spacing of ATTRIB appears to be off when viewing in Gradescope*/
  merge  Final.AllDrinks (in =AllD) 
         Final.Counties99 (in = County);
         by stateFIPS countyFIPS;
  if index(productName, 'Diet') gt 0 then Type = 'Diet';
      else Type = 'Non-Diet';
  if (POPESTIMATE2017-POPESTIMATE2016) = 0 then SalesPerThousand = .;
      else SalesPerThousand = UnitsSold /((POPESTIMATE2017-POPESTIMATE2016)/2)*1000;
  /*ProductName = put(ProductNumber, $prodnames.);*/
  /*format ProductName prodnamefmt.; */
  if ProductName ne "" then ProductSubCategory = substr(ProductName, 1,4);
  if ProductName ne "" then Flavor = scan(ProductName, -2);
      else Flavor = scan(ProductName, -1);
  if ProductCategory = 'Energy' then  ProductSubCategory = scan(ProductName, 2);
      else ProductSubCategory = 'Zip';
  if StateName = 'Maryland' then ContainerUnit = scan(ProductCode, -1);
  Size = lowcase(Size);
  Size = tranwrd(Size, 'ounces', 'oz'); 
  Size = tranwrd(Size, 'liters', 'liter');
  if Size = substr(Size, 3, 2)  then container = 'Can';
      else container = 'Bottle';
  drop ProductNumber;
  /*Unfortunately there is still some missing data that I could not derive...
    which led to 0 observations produced in some areas below*/
run;

/*Commented out PROC CONTENTS, used to display metadata in pdf;
/*
ods pdf exclude none;
proc contents data = Final.AllData varnum;
run;

proc contents data = Final.Sodas varnum;
run; */

/*used PROC MEANS to display output for #3*/
title 'Activity 2.1';
title2 'Summary of Units Sold';
title3 'Single Unit Packages';
footnote 'Minimum and maximum Sales are within any county for any week';
proc means data = Final.AllData sum min max nonobs;
  where ContainerUnit eq 1;
  var UnitsSold;
  class StateFIPS ProductName Size ContainerUnit;
run;
title;
footnote;

/*used PROC FREQ to display output for #5 */
title 'Activity 2.3';
title2 'Cross Tabulation of Single Unit Product Sales in Various States';
proc freq data = Final.AllData;
  where ProductName eq "Cherry Cola" and "Cola";
  table stateFIPS*Size;
run;
title; 

/*PROC SGPLOT to create graph for #12*/
title 'Activity 3.1';
title2 'Single-Unit 12 oz Sales';
title3 'Regular, Non-Cola Sodas';
proc sgplot data = Final.AllData;
  where ProductCategory = 'Soda: Non-Cola' and ContainerUnit eq 1 and Type = 'Non-Diet'
        and Size = "12 oz" and StateName in ('Georgia' 'North Carolina' 'South Carolina');
  hbar StateName / response = UnitsSold 
  group = ProductName groupdisplay = cluster;
  xaxis label = 'Total Sold';
  yaxis display = (nolabel);
  keylegend / position = bottomright location = inside down = 3;
run; 
title;

/*PROC SGPLOT to create graph for #15*/
title 'Activity 3.3';
title2 'Average Weekly Sales, Non-Diet Energy Drinks';
title3 'For 8 oz cans in Georgia';
proc sgplot data = Final.AllData;
  where Type = 'Non-Diet' and ProductCategory = 'Energy' and Size = '8 oz' 
        and Container = 'Can' and StateName in ('Georgia');
  vbar ProductName / response = SalesPerThousand dataskin = sheen
                     outlineattrs = (color = black)
                     group = UnitSize groupdisplay = cluster;
run;
title;

/*used PROC MEANS to set up data for the next graph*/
ods output summary = Final.MeanMedActivity19;
proc means data = Final.AllData mean median;
  where ProductCategory = 'Nutritional Water' and StateName in ('Georgia' 'North Carolina' 'South Carolina') 
        and ContainerUnit eq 1;
  class ProductCategory;
  var SalesPerThousand;
  output mean = SalesPerThousand_Mean median = SalesPerThousand_Median;
run;

/*PROC SGPLOT using mean&median data produced from ALLData to complete #19*/
title 'Activity 3.6';
title2 'Weekly Average Sales, Nutritional Water';
title3 'Single-Unit Packages';
proc sgplot data = Final.MeanMedActivity19;
  hbar ProductCategory / response = SalesPerThousand_Mean 
       fillattrs = (color = blue) legendlabel = 'Mean' barwidth = 0.6;
  hbar ProductCategory / response = SalesPerThousand_Median 
       fillattrs = (transparency = 0.4 color = red) legendlabel = 'Median';
  xaxis label = 'Georgia, North Carolina, South Carolina';
  yaxis display = (nolabel);
  keylegend / position = topright location = inside across = 1
              title = 'Weekly Sales' noborder;
run;
title;

/*used PROC MEANS to display data for #22*/
title 'Activity 4.1';
title2 'Weekly Sales Summaries';
title3 'Cola Products, 20 oz Bottles, Individual Units';
footnote 'All States';
proc means data = Final.AllData mean median q1 q3 nonobs;
  where ProductCategory = 'Soda: Cola' and Size = '20 oz' and container = 'Bottle' and ContainerUnit eq 1;
  var UnitsSold;
  class region type flavor;
run;  
title; 
footnote;

/*PROC SGPANEL to create graphs for #23*/
title 'Activity 4.2';
title2 'Weekly Sales Distributions';
title3 'Cola Products, 12 Packs of 12 oz Bottles';
footnote 'All States';
proc sgpanel data = Final.AllData;
  where ProductCategory = 'Soda: Cola' and Size = '20 oz' and unitSize eq 12 and container = 'Bottle';
  panelby Region Type / novarname;
  histogram UnitsSold / scale = proportion;
  rowaxis display = (nolabel) valuesformat = percent7.;
run;
title;
footnote;

/*PROC SGPANEL to create graphs for #25*/
title 'Activity 4.4';
title2 'Sales Inter-Quartile Ranges';
title3 'Cola: 20 oz Bottles, Individual Units';
footnote 'All States'; 
proc sgpanel data = Final.AllData;
  where ProductCategory = 'Soda: Cola' and size = '20 oz' and container = 'Bottle' and ContainerUnit eq 1;
  panelby Region Type / novarname;
  histogram Date;
  rowaxis label = 'Q1-Q3' interval = month;
  colaxis label = 'Date';
run;
title;
footnote;

/*PROC SORT to set up the table in #28*/
proc sort data = Final.AllData;
by ProductCategory ProductSubCategory productName type container Flavor size;
run; 

/*PROC PRINT to produce Activity #28*/
proc print data = Final.AllData (obs = 1000);
by ProductCategory ProductSubCategory productName type container Flavor size;
var productName type ProductCategory ProductSubCategory Flavor size;
run;

/*PROC SGPANEL to create graph for #33*/
title 'Activity 5.5';
title2 'North and South Carolina Sales in August';
title3 '12 oz, Single-Unit, Cola Flavor';
proc sgpanel data = Final.AllData;
  where StateName in ('North Carolina', 'South Carolina') and Size = '12 oz' 
        and ContainerUnit eq 1 and Flavor = 'Cola';
  panelby Type / novarname;
  hbar _Date;
  rowaxis type = linear display = (nolabel);
  colaxis label = 'Sales';
run;
title;

/*PROC REPORT to create output for #36*/
title 'Activity 6.2';
title2 'Quarterly Sales Summaries for 12oz Single-Unit Products';
title3 'Maryland Only';
proc report data = Final.AllData;
  where size = '12 oz' and ContainerUnit eq 1 and StateName in ('Georgia');
  /*Used Georgia because no output produced from Maryland data*/
  column type=ProductType ProductName=Name Date=Quarter SalesPerThousand=Median 
         SalesPerThousand=Total SalesPerThousand=Lowest SalesPerThousand=Highest;
  define ProductType / group 'Product Type';
  define Name / group 'Name';
  define Quarter /  'Quarter' format = qtrr.;
  define Median / median 'Median Weekly Sales';
  define Total / n 'Total Sales';
  define Lowest / min 'Lowest Weekly Sales';
  define Highest / max 'Highest Weekly Sales';
run;
title;

/*PROC REPORT to create output using Sodas dataset for #44 */
title 'Product Code Mapping for Sodas';
title2 'Created in Activity 7.1';
proc report data = Final.Sodas;
  column Number=ProductNumber ProductName=ProductName Size=Size 
         Quantity=Qty Code=Code;
  define ProductNumber / 'Product Number';
  define ProductName / 'Product Name';
  define Size / 'Individual Container Size';
  define Qty / 'Retail Unit Size';
  define Code / 'Product Code';
  /*need compute blocks */
run;
title;

/*PROC REPORT to create output for #40*/
title 'Activity 7.4';
title2 'Quarterly Sales Summaries for 12oz Single-Unit Products';
title3 'Maryland Only';
proc report data = Final.AllData
  style(header) = [backgroundcolor=gray55 color=blue]
  style(column) = [backgroundcolor=graydd]  
  style(summary) = [backgroundcolor=black color=white];
  where size = '12 oz' and ContainerUnit eq 1 and StateName in ('North Carolina');
  column type=ProductType ProductName=Name Date=Quarter SalesPerThousand=Median 
         SalesPerThousand=Total SalesPerThousand=Lowest SalesPerThousand=Highest;
  define ProductType / group 'Product Type';
  define Name / group 'Name';
  define Quarter /  'Quarter' format = qtrr.;
  define Median / median 'Median Weekly Sales';
  define Total / n 'Total Sales';
  define Lowest / min 'Lowest Weekly Sales';
  define Highest / max 'Highest Weekly Sales';
  /*break after Name / summarize; */
run;
title;

/*PROC FORMAT used for next REPORT to create custom color options*/
proc format library=Final;
value dietRed    0 - 7.5 = cxFF0000;
value nondietRed 0 - 30  = cxFF0000;
run;

/*PROC REPORT to create output for #41 */
title 'Activity 7.5';
title2 'Quarterly Per-Capita Sales Summaries';
title3 '12oz Single-Unit Lemonade';
title4 'Maryland Only';
footnote 'Flagged Rows: Sales Less Than 7.5 per 1000 for Diet; 
          Less Than 30 per 1000 for Non-Diet';
proc report data = Final.AllData
  style(header) = [backgroundcolor=gray44 color=blue];
  where StateName in ('Georgia') and Size = '12 oz' and ContainerUnit eq 1;
  /*Used Georgia again because no output produced from Maryland data*/
  column countyName=County type=ProductType Date=Quarter UnitsSold=TotalSales 
         SalesPerThousand=SalesPer1000;
  rbreak after / summarize;
  define County / group 'County';
  define ProductType / group 'Product Type';
  define Quarter / 'Quarter' format = qtrr.;
  define TotalSales / 'Total Sales';
  define SalesPer1000 / 'Sales per 1000' style(column) = [color=nondietRed.];
  /*break after County / summarize; */
run;
title;
footnote;

/*Close destinations*/
ods graphics off;
ods pdf close;
ods listing;
quit;
