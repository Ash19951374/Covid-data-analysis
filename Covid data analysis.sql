--Data Exploration of covid deaths
Select * from CovidProject..coviddeaths
order by location, date

select location, date, total_cases, new_cases, total_deaths, population
from CovidProject..coviddeaths
order by location, date

--Percentage of deaths relative to total cases in Iran
select location, date, total_cases, total_deaths, cast((total_deaths/total_cases)*100 as decimal(5,2)) as 'Percent Dead'
from CovidProject..coviddeaths where location='Iran'
order by location, date

--Percentage of population infected for every nation
select location, max(population) as 'Population', max(total_cases) as 'Total cases to date', cast((max(total_cases)/max(population))*100 as decimal(5,2)) as 'Percent Infected'
from CovidProject..coviddeaths
where continent is not null
--where location='Iran'
group by location
order by 'Percent Infected' desc

--Countries with the highest death count per capita
select location, max(population) as 'Population', max(total_deaths) as 'Total deaths to date', cast((max(cast(total_deaths as int))/max(population))*100 as decimal(5,2)) as 'Death per Capita x100'
from CovidProject..coviddeaths
where continent is not null
group by location
order by 'Death per Capita x100' desc

--Cases and deaths regardless of country at any recorded time
select date, sum(new_cases) as 'Total Cases', sum(cast(new_deaths as int)) 'Total Deaths', cast(sum(cast(new_deaths as int))/sum(new_cases)*100 as decimal (5,2)) as 'Percent Dead Globally'
from CovidProject..coviddeaths
where continent is not null
group by date
order by date

--Data exploration of covid vaccinations
Select * from CovidProject..covidvaccinations
order by location, date

Select * from CovidProject..coviddeaths as dea
	join CovidProject..covidvaccinations as vac
	on dea.location=vac.location
	and dea.date=vac.date
where dea.continent is not null

-- Total population vs Vaccination
Select dea.location, dea.date, dea.population, vac.new_vaccinations 
, sum(convert(bigint,vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as 'People Vaccinated'
from CovidProject..coviddeaths as dea
	join CovidProject..covidvaccinations as vac
	on dea.location=vac.location
	and dea.date=vac.date
where dea.continent is not null
order by dea.location, dea.date

--Creating the CTE to show the percentage of population vaccinated

with PopvsVac (Location, Date, Population, New_Vaccinations, People_Vaccinated)
as
(
Select dea.location, dea.date, dea.population, vac.new_vaccinations 
, sum(convert(bigint,vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as 'People Vaccinated'
from CovidProject..coviddeaths as dea
	join CovidProject..covidvaccinations as vac
	on dea.location=vac.location
	and dea.date=vac.date
where dea.continent is not null
)
select *, cast((People_Vaccinated/Population)*100 as float) as 'Percentage of population vaccinated'
from PopvsVac 
-- where location='Canada'
/*This data counts all the vaccine doses that are administered meaning that people who have received 
multiple doses will be counted multiple times*/


--Temp Table for showing the percentage of population that is vaccinated
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated (
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
People_Vaccinated numeric)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations 
, sum(convert(bigint,vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as 'People Vaccinated'
from CovidProject..coviddeaths as dea
	join CovidProject..covidvaccinations as vac
	on dea.location=vac.location
	and dea.date=vac.date
where dea.continent is not null

Select *, (People_Vaccinated/Population)*100 from #PercentPopulationVaccinated

--View to store data for visualization later
Drop View if exists PercentPopulationVaccinated
Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations 
, sum(convert(bigint,vac.new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) as 'People Vaccinated'
from CovidProject..coviddeaths as dea
	join CovidProject..covidvaccinations as vac
	on dea.location=vac.location
	and dea.date=vac.date
where dea.continent is not null


Select * from PercentPopulationVaccinated


-- Analysis of demographic data
Select dd.location, avg(cast(dd.extreme_poverty as decimal (5,2))) as 'Percentage in extreme povert',
max(cast(cd.total_deaths_per_million as float)) as 'Total Deaths per Million', max(cast(cd.total_cases_per_million as float)) as 'Total Cases per Million'
from CovidProject..DemographicData as dd
	join CovidProject..coviddeaths as cd on dd.location=cd.location
	where dd.continent is not null and dd.extreme_poverty is not null and (dd.extreme_poverty>20.0 or cast(dd.extreme_poverty as float)<1.0)
	group by dd.location
/* Nations with a high extreme poverty rate appear to report lower deaths and lower number of cases compared to
 nations with low extreme poverty and cases are probably under-reported and deaths attributed to other causes */


Select dd.location, avg(dd.gdp_per_capita) as 'GDP per capita',
max(cast(cd.total_deaths_per_million as float)) as 'Total Deaths per Million', max(cast(cd.total_cases_per_million as float)) as 'Total Cases per Million'
from CovidProject..DemographicData as dd
	join CovidProject..coviddeaths as cd on dd.location=cd.location
	where dd.continent is not null
	group by dd.location


-- Temp table to categorize nations based on economic status and the median age of the population
DROP Table if exists #WealthStatus
Create Table #WealthStatus (
location nvarchar(255),
gdp_per_capita float,
total_deaths_per_million float,
total_cases_per_million float,
economic_status nvarchar(255),
median_age float)

Insert into #WealthStatus
Select dd.location, avg(round(dd.gdp_per_capita,2)) as 'GDP per capita',
max(cast(cd.total_deaths_per_million as float)) as 'Total Deaths per Million', max(cast(cd.total_cases_per_million as float)) as 'Total Cases per Million',
case
	when avg(dd.gdp_per_capita) <8000 then 'Poor'
	when 8000 <= avg(dd.gdp_per_capita) and avg(dd.gdp_per_capita) <12000 then 'Lower middle income'
	when 12000 <= avg(dd.gdp_per_capita) and avg(dd.gdp_per_capita) <20000 then 'Middle income'
	when 20000 <= avg(dd.gdp_per_capita) and avg(dd.gdp_per_capita) <28000 then 'Higher middle income'
	when avg(dd.gdp_per_capita) >= 28000 then 'Rich'
	end as 'Economic status',
round(avg(dd.median_age),2) as 'Media age'
from CovidProject..DemographicData as dd
	join CovidProject..coviddeaths as cd on dd.location=cd.location
	where dd.continent is not null and dd.median_age is not null
	group by dd.location


-- 
Select ws.location, avg(round(ws.gdp_per_capita,2)) as 'GDP per capita', max(ws.total_deaths_per_million) as 'Total deaths per million',
max(ws.total_cases_per_million) as 'Total cases per million', ws.economic_status as ' Economic status', ws.median_age as 'Median age', 
round(max(dd.extreme_poverty),2) as 'Extreme poverty rate'
from #WealthStatus as ws
join CovidProject..DemographicData as dd on ws.location=dd.location
where dd.extreme_poverty is not null
group by ws.location, ws.economic_status, ws.median_age

/* It seems poorer nations with high extreme poverty also have a younger population explaining
to some degree the lower deaths and cases per million */
